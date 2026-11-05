extends Control
## Heads-up display drawn in code: survival bars, clock, materials, hotbar,
## minimap, boss bar, toasts and the on-screen touch controls.

const D = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")

var g: Node = null
var font: Font
var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var atk_index := -1
var pressed_btn := ""
var pressed_t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

func _vs() -> Vector2:
	return get_viewport_rect().size

func _text(p: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string_outline(font, p, s, align, w, size, 5, Color(0, 0, 0, 0.75 * col.a))
	draw_string(font, p, s, align, w, size, col)

func _panel(r: Rect2, a := 0.55) -> void:
	draw_rect(r, Color(0.05, 0.06, 0.1, a))
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)

# ---------------------------------------------------------------- layout
func _hotbar_rect() -> Rect2:
	var vs := _vs()
	var slot := 60.0
	var w := slot * 9 + 8 * 6
	var y := vs.y - slot - 14
	if g.touch_mode:
		if vs.x - 620 < w:
			y = vs.y - 330
		else:
			y = vs.y - slot - 10
	return Rect2(Vector2((vs.x - w) * 0.5, y), Vector2(w, slot))

func _slot_rect(i: int) -> Rect2:
	var hr := _hotbar_rect()
	return Rect2(hr.position + Vector2(i * 66.0, 0), Vector2(60, 60))

func _buttons() -> Dictionary:
	var vs := _vs()
	return {
		"atk": [Vector2(vs.x - 110, vs.y - 120), 62.0, "USE"],
		"act": [Vector2(vs.x - 250, vs.y - 80), 44.0, "ACT"],
		"eat": [Vector2(vs.x - 80, vs.y - 270), 38.0, "EAT"],
		"craft": [Vector2(vs.x - 215, vs.y - 215), 40.0, "CRAFT"],
		"pause": [Vector2(vs.x - 38, 38), 26.0, "II"],
	}

# ---------------------------------------------------------------- touch
func handle_touch(e: InputEvent) -> bool:
	var vs := _vs()
	var p: Vector2 = e.position
	if e is InputEventScreenTouch:
		if e.pressed:
			for i in 9:
				if _slot_rect(i).grow(3).has_point(p):
					g.select_slot(i)
					return true
			var bs := _buttons()
			for k in bs:
				if p.distance_to(bs[k][0]) < bs[k][1] + 10.0:
					pressed_btn = k
					pressed_t = 0.15
					match k:
						"atk":
							atk_index = e.index
							g.attack_held = true
						"act": g.interact()
						"eat": g.eat()
						"craft": g.open_craft()
						"pause": g.pause()
					return true
			if p.x < vs.x * 0.5 and joy_index < 0:
				joy_index = e.index
				joy_origin = p
				joy_pos = p
				return true
		else:
			if e.index == joy_index:
				joy_index = -1
				g.joy_vec = Vector2.ZERO
				return true
			if e.index == atk_index:
				atk_index = -1
				g.attack_held = false
				return true
	elif e is InputEventScreenDrag:
		if e.index == joy_index:
			joy_pos = p
			var v := (joy_pos - joy_origin) / 70.0
			g.joy_vec = v.limit_length(1.0)
			return true
	return false

func reset_touch() -> void:
	joy_index = -1
	atk_index = -1
	g.joy_vec = Vector2.ZERO
	g.attack_held = false

# ---------------------------------------------------------------- draw
func _process(delta: float) -> void:
	pressed_t = maxf(0.0, pressed_t - delta)

func _draw() -> void:
	if g == null or g.state == "title":
		return
	var vs := _vs()
	_draw_bars()
	_draw_clock(vs)
	_draw_mats()
	_draw_minimap(vs)
	_draw_hotbar()
	_draw_boss(vs)
	if g.toast_t > 0.0:
		var a: float = clamp(g.toast_t / 0.4, 0.0, 1.0)
		var tw := font.get_string_size(g.toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 40
		tw = minf(tw, vs.x - 24)
		var r := Rect2(Vector2((vs.x - tw) * 0.5, vs.y * 0.2), Vector2(tw, 40))
		_panel(r, 0.6 * a)
		_text(r.position + Vector2(0, 27), g.toast, 20 if tw < vs.x - 30 else 15, Color(1, 0.95, 0.8, a), HORIZONTAL_ALIGNMENT_CENTER, tw)
	if g.touch_mode and g.state == "play":
		_draw_touch()
	if g.state == "play" and not g.touch_mode:
		_text(Vector2(12, vs.y - 12), "WASD move · Click use · RMB/E interact · F eat · C craft · 1-8 slots · Esc pause", 13, Color(1, 1, 1, 0.45))

func _draw_bars() -> void:
	var stats := [
		["Health", g.hp, Color("e8524a"), "heart"],
		["Hunger", g.food, Color("e3a23a"), "food"],
		["Thirst", g.water, Color("3fa7e0"), "drop"],
		["Warmth", g.warm, Color("ff7a3a"), "fire"],
	]
	var x := 14.0
	var y := 14.0
	_panel(Rect2(Vector2(x - 6, y - 6), Vector2(236, 4 * 26 + 6)))
	for i in stats.size():
		var s: Array = stats[i]
		var v: float = s[1]
		var yy := y + i * 26
		var ic := Vector2(x + 10, yy + 9)
		_stat_icon(s[3], ic, s[2])
		var r := Rect2(Vector2(x + 26, yy + 2), Vector2(190, 14))
		draw_rect(r, Color(0, 0, 0, 0.5))
		var col: Color = s[2]
		if v < 25.0 and int(g.title_t * 4.0) % 2 == 0:
			col = col.lightened(0.4)
		draw_rect(Rect2(r.position, Vector2(r.size.x * v / 100.0, r.size.y)), col)
		draw_rect(Rect2(r.position, Vector2(r.size.x * v / 100.0, 4)), Color(1, 1, 1, 0.2))
		_text(r.position + Vector2(6, 12), "%s %d" % [s[0], int(v)], 12, Color(1, 1, 1, 0.9))
	# objective
	var obj: String = g.objective()
	var ow := font.get_string_size(obj, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 34
	_panel(Rect2(Vector2(x - 6, y + 4 * 26 + 6), Vector2(ow, 26)), 0.5)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 2, y + 116), Vector2(x + 12, y + 122), Vector2(x + 2, y + 128)]), Color("ffd27a"))
	_text(Vector2(x + 18, y + 128), obj, 15, Color("ffe9b8"))

func _stat_icon(kind: String, c: Vector2, col: Color) -> void:
	match kind:
		"heart":
			draw_circle(c + Vector2(-3, -2), 4, col)
			draw_circle(c + Vector2(3, -2), 4, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(7, 0), c + Vector2(0, 7)]), col)
		"food":
			draw_circle(c + Vector2(-1, -1), 6, col)
			draw_line(c + Vector2(3, 3), c + Vector2(7, 7), Color.WHITE, 2.0)
		"drop":
			draw_circle(c + Vector2(0, 2), 5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-4.5, 0), c + Vector2(0, -8), c + Vector2(4.5, 0)]), col)
		"fire":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 6), c + Vector2(-4, -2), c + Vector2(0, -8), c + Vector2(4, -2), c + Vector2(6, 6)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 6), c + Vector2(0, -2), c + Vector2(3, 6)]), Color("ffe08a"))

func _draw_clock(vs: Vector2) -> void:
	var w := 220.0
	var x := (vs.x - w) * 0.5
	if vs.x < 900:
		x = 260.0 if vs.x > 560 else (vs.x - w) * 0.5
	var y := 12.0
	if vs.x <= 560:
		y = 150.0
	_panel(Rect2(Vector2(x, y), Vector2(w, 46)))
	var night: bool = g.is_night()
	var label := ("Night %d" if night else "Day %d") % g.day
	_text(Vector2(x + 40, y + 22), label, 18, Color("c9d6ff") if night else Color("ffe9a8"))
	var ic := Vector2(x + 20, y + 16)
	if night:
		draw_circle(ic, 9, Color("dfe6ff"))
		draw_circle(ic + Vector2(4, -3), 8, Color(0.08, 0.09, 0.16))
	else:
		draw_circle(ic, 8, Color("ffd24a"))
		for i in 8:
			var a: float = TAU * i / 8.0 + g.title_t
			draw_line(ic + Vector2.from_angle(a) * 10, ic + Vector2.from_angle(a) * 13, Color("ffd24a"), 2.0)
	var br := Rect2(Vector2(x + 10, y + 32), Vector2(w - 20, 6))
	draw_rect(br, Color("6fb3e8"))
	draw_rect(Rect2(br.position + Vector2(br.size.x * D.NIGHT_START, 0), Vector2(br.size.x * (D.NIGHT_END - D.NIGHT_START), 6)), Color("1d2350"))
	var mx: float = br.position.x + br.size.x * g.tod
	draw_rect(Rect2(Vector2(mx - 2, br.position.y - 3), Vector2(4, 12)), Color.WHITE)
	if not night and g.tod > D.NIGHT_START - 0.12:
		_text(Vector2(x + 112, y + 22), "dusk soon", 13, Color("ffb38a"))
	if g.beacon_t >= 0.0:
		_text(Vector2(x + 112, y + 22), "SIGNAL %ds" % int(60.0 - g.beacon_t), 14, Color("ff9a4a"))

func _draw_mats() -> void:
	var list := []
	for k in ["wood", "stone", "fiber", "ore", "iron", "hide", "arrow", "berries", "meat_raw", "meat_cooked", "ember_shard", "ember_heart"]:
		if g.count(k) > 0:
			list.append(k)
	if list.is_empty():
		return
	var x := 8.0
	var y := 160.0
	var cols := 4
	var rows := int(ceil(list.size() / float(cols)))
	_panel(Rect2(Vector2(x, y), Vector2(cols * 58 + 4, rows * 30 + 4)), 0.45)
	for i in list.size():
		var p := Vector2(x + 4 + (i % cols) * 58, y + 4 + (i / cols) * 30)
		Art.icon(self, list[i], p + Vector2(13, 13), 22)
		_text(p + Vector2(27, 20), str(g.count(list[i])), 14, Color.WHITE)
	if g.armor != "":
		var ap := Vector2(x, y + rows * 30 + 10)
		_panel(Rect2(ap, Vector2(150, 28)), 0.45)
		Art.icon(self, g.armor, ap + Vector2(15, 14), 20)
		_text(ap + Vector2(30, 19), D.ITEMS[g.armor].name, 13, Color("dfe6ff"))

func _draw_minimap(vs: Vector2) -> void:
	var tex: Texture2D = g.world.terrain_tex
	if tex == null:
		return
	var s := 150.0 if vs.x > 800 else 112.0
	var r := Rect2(Vector2(vs.x - s - 12, 12), Vector2(s, s))
	if g.touch_mode:
		r.position.x -= 56
	_panel(r.grow(4), 0.6)
	draw_texture_rect(tex, r, false)
	var k := s / float(D.MAP * D.TILE)
	if g.beacon_tile.x >= 0:
		draw_circle(r.position + Vector2(g.beacon_tile.x + 0.5, g.beacon_tile.y + 0.5) * D.TILE * k, 4, Color("ffcf4a"))
	for c in g.world.builds:
		if g.world.builds[c].id in ["campfire", "workbench", "furnace"]:
			draw_rect(Rect2(r.position + Vector2(c.x, c.y) * D.TILE * k - Vector2(1.5, 1.5), Vector2(3, 3)), Color("ffb36a"))
	for m in g.mobs:
		if D.MOBS[m.type].get("boss", false) and m.state != "sleep":
			draw_circle(r.position + m.p * k, 4, Color("ff3a2a"))
	if not g.boss2_dead:
		var cp: Vector2 = r.position + (Vector2(g.world.crater) + Vector2(0.5, 0.5)) * D.TILE * k
		draw_arc(cp, 6, 0, TAU, 12, Color(1, 0.4, 0.2, 0.6 + 0.4 * sin(g.title_t * 4.0)), 2.0)
	var pp: Vector2 = r.position + g.ppos * k
	draw_circle(pp, 4, Color.WHITE)
	draw_circle(pp, 2.5, Color("2f7fb0"))

func _draw_hotbar() -> void:
	var cur: String = g.sel_item()
	var view: Array = g.hotbar_view()
	var items: Array = view[1]
	for i in 9:
		var r := _slot_rect(i)
		var id: String = items[i] if i < items.size() else ""
		var on: bool = id == cur
		draw_rect(r, Color(0.05, 0.06, 0.1, 0.7 if on else 0.5))
		draw_rect(r, Color("ffd27a") if on else Color(1, 1, 1, 0.18), false, 3.0 if on else 1.0)
		if id != "" and (id == "hand" or g.count(id) > 0):
			Art.icon(self, id, r.get_center() + Vector2(0, -2), 34)
			var kind: String = D.ITEMS[id].kind
			if kind in ["build", "food"] or (kind != "tool" and g.count(id) > 1):
				_text(r.position + Vector2(r.size.x - 6, r.size.y - 5), str(g.count(id)), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, -1)
			if id == "bow":
				_text(r.position + Vector2(4, r.size.y - 5), str(g.count("arrow")), 12, Color("e8d9b0"))
		if not g.touch_mode:
			_text(r.position + Vector2(4, 14), str(i + 1), 11, Color(1, 1, 1, 0.5))
	var hr := _hotbar_rect()
	_text(Vector2(hr.position.x, hr.position.y - 8), D.ITEMS[cur].name, 15, Color("ffe9b8"), HORIZONTAL_ALIGNMENT_CENTER, hr.size.x)

func _draw_boss(vs: Vector2) -> void:
	for m in g.mobs:
		if not D.MOBS[m.type].get("boss", false) or m.state == "sleep":
			continue
		if m.p.distance_to(g.ppos) > 1000.0:
			continue
		var w := minf(520.0, vs.x - 40)
		var y := 76.0 if vs.x > 560 else 210.0
		if vs.x <= 900 and vs.x > 560:
			y = 70.0
		var r := Rect2(Vector2((vs.x - w) * 0.5, y), Vector2(w, 16))
		if vs.x <= 900 and vs.x > 560:
			r.position.x = 260.0
			r.size.x = minf(w, vs.x - 260 - 190)
		draw_rect(r.grow(3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(r.position, Vector2(r.size.x * maxf(0.0, m.hp) / m.maxhp, r.size.y)), Color("d8342a"))
		draw_rect(Rect2(r.position, Vector2(r.size.x * maxf(0.0, m.hp) / m.maxhp, 5)), Color(1, 1, 1, 0.25))
		_text(r.position + Vector2(0, -6), D.MOBS[m.type].name.to_upper(), 16, Color("ffb38a"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		break

func _draw_touch() -> void:
	var vs := _vs()
	# joystick
	var base := joy_origin if joy_index >= 0 else Vector2(130, vs.y - 140)
	draw_circle(base, 70, Color(1, 1, 1, 0.08))
	draw_arc(base, 70, 0, TAU, 32, Color(1, 1, 1, 0.3), 2.0)
	var knob: Vector2 = base + g.joy_vec * 60.0 if joy_index >= 0 else base
	draw_circle(knob, 30, Color(1, 1, 1, 0.28))
	var bs := _buttons()
	for k in bs:
		var b: Array = bs[k]
		var on: bool = pressed_btn == k and pressed_t > 0.0 or (k == "atk" and atk_index >= 0)
		draw_circle(b[0], b[1], Color(1, 0.82, 0.48, 0.38) if on else Color(0.05, 0.06, 0.1, 0.45))
		draw_arc(b[0], b[1], 0, TAU, 32, Color(1, 1, 1, 0.4), 2.0)
		if k == "atk":
			Art.icon(g.hud, g.sel_item(), b[0] + Vector2(0, -6), 34)
			_text(b[0] + Vector2(-40, 34), b[2], 13, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 80)
		else:
			_text(b[0] + Vector2(-40, 6), b[2], 14 if b[2].length() < 5 else 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 80)
