extends Control
## Menus built from Godot Controls with a code-made theme: title, how-to-play,
## pause, crafting, chest and the win / lose screens.

const D = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")

var g: Node = null
var dim: ColorRect
var center: CenterContainer
var panel: PanelContainer
var box: VBoxContainer
var mode := ""
var refresh_t := 0.0
var craft_rows: Array = []
var title_deco: Control

class IconRect extends Control:
	var id := ""
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.3))
		Art.icon(self, id, size * 0.5, size.x * 0.8)

class TitleDeco extends Control:
	var g: Node
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var vs := get_viewport_rect().size
		var t: float = g.title_t if g else 0.0
		# drifting embers
		for i in 40:
			var x := fmod(i * 97.3 + t * (12.0 + i % 7 * 4.0), vs.x + 40.0) - 20.0
			var y := vs.y - fmod(i * 53.1 + t * (30.0 + i % 5 * 9.0), vs.y + 40.0)
			draw_circle(Vector2(x + sin(t + i) * 12.0, y), 1.5 + i % 3, Color(1.0, 0.55 + (i % 4) * 0.08, 0.2, 0.55))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.07, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	title_deco = TitleDeco.new()
	title_deco.g = g
	title_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_deco)
	center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	hide_all()

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.16, 0.94)
	sb.border_color = Color("ff8a3d")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	th.set_stylebox("panel", "PanelContainer", sb)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color("2a2f45")
	bn.set_corner_radius_all(10)
	bn.set_content_margin_all(10)
	bn.border_color = Color(1, 1, 1, 0.12)
	bn.set_border_width_all(1)
	var bh := bn.duplicate()
	bh.bg_color = Color("3b4262")
	bh.border_color = Color("ffb36a")
	var bp := bn.duplicate()
	bp.bg_color = Color("ff8a3d")
	var bd := bn.duplicate()
	bd.bg_color = Color(0.16, 0.17, 0.22, 0.8)
	th.set_stylebox("normal", "Button", bn)
	th.set_stylebox("hover", "Button", bh)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("disabled", "Button", bd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color("fff2dc"))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	th.set_color("font_color", "Label", Color("f2e8d8"))
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	th.set_constant("outline_size", "Label", 0)
	return th

func _process(delta: float) -> void:
	if mode == "craft":
		refresh_t -= delta
		if refresh_t <= 0.0:
			refresh_t = 0.3
			_refresh_craft()

func hide_all() -> void:
	mode = ""
	dim.visible = false
	title_deco.visible = false
	if panel:
		center.remove_child(panel)
		panel.queue_free()
		panel = null
	if g and g.hud:
		g.hud.reset_touch()

func _open(w: float) -> VBoxContainer:
	if panel:
		center.remove_child(panel)
		panel.queue_free()
	var vs := get_viewport_rect().size
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(w, vs.x - 24), 0)
	center.add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	dim.visible = true
	return box

func _label(t: String, size := 18, col := Color("f2e8d8"), align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	box.add_child(l)
	return l

func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func():
		g.sfx.play("ui")
		cb.call())
	box.add_child(b)
	return b

# ---------------------------------------------------------------- screens
func show_title() -> void:
	hide_all()
	mode = "title"
	title_deco.visible = true
	_open(520)
	dim.color = Color(0.02, 0.03, 0.07, 0.35)
	var t := _label("ISLE OF EMBERS", 50, Color("ffb36a"))
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", Color("3a1206"))
	_label("Stranded. Survive the nights. Light the beacon.", 17, Color("cfd6ea"))
	if g.has_save():
		_button("Continue", func(): g.load_game())
	_button("New Game", func(): g.new_game())
	_button("How to Play", show_howto)
	var sb := _button("Sound: " + ("On" if g.sfx.enabled else "Off"), func(): pass)
	sb.pressed.connect(func():
		g.sfx.enabled = not g.sfx.enabled
		sb.text = "Sound: " + ("On" if g.sfx.enabled else "Off"))
	var bt := "Best: day %d" % g.best.day
	if g.best.wins > 0:
		bt += "  ·  Rescued %d time%s" % [g.best.wins, "" if g.best.wins == 1 else "s"]
	_label(bt, 15, Color("ffd27a"))
	_label("Made by Jaineil Rana (JaKing) · JaiGod", 13, Color(1, 1, 1, 0.45))

func show_howto() -> void:
	var back := mode
	mode = "howto"
	_open(640)
	_label("How to Play", 30, Color("ffb36a"))
	var lines := [
		"[Goal] Build a Signal Beacon and keep it burning for 60 seconds to be rescued.",
		"[Survive] Watch Health, Hunger, Thirst and Warmth. Eat (F), drink at water (E), stay near campfires at night.",
		"[Gather] Hit trees, boulders, bushes and iron veins. Tools gather faster; iron needs a pickaxe.",
		"[Craft] Press C. Some recipes need a Workbench, Furnace or Campfire nearby.",
		"[Build] Select a building in the hotbar and click a tile to place it. Walls stop night raiders.",
		"[Bosses] The Thornback hunts from night 3: dodge its charge and hit it while stunned. The Cinder Wyrm sleeps in the volcano.",
		"[Keys] WASD move · Mouse aim · Left click use · Right click / E interact · 1-9 / wheel hotbar · Esc pause · M sound",
		"[Touch] Left stick moves · USE attacks / places · ACT interacts · tap hotbar slots",
	]
	for l in lines:
		_label(l, 15, Color("e6ecf8"), HORIZONTAL_ALIGNMENT_LEFT)
	_button("Back", func():
		if back == "paused" or g.state == "paused":
			show_pause()
		else:
			show_title())

func show_pause() -> void:
	mode = "paused"
	_open(420)
	dim.color = Color(0.02, 0.03, 0.07, 0.55)
	_label("Paused", 34, Color("ffb36a"))
	_label("Day %d  ·  %d creatures slain  ·  %d items crafted" % [g.day, g.kills, g.crafted], 15, Color("cfd6ea"))
	_button("Resume", func(): g.resume())
	var sv := _button("Save Game", func(): pass)
	sv.pressed.connect(func(): sv.text = "Saved!" if g.save_game() else "Save failed")
	var sb := _button("Sound: " + ("On" if g.sfx.enabled else "Off"), func(): pass)
	sb.pressed.connect(func():
		g.sfx.enabled = not g.sfx.enabled
		sb.text = "Sound: " + ("On" if g.sfx.enabled else "Off"))
	_button("How to Play", show_howto)
	_button("Save & Quit to Title", func(): g.quit_to_title())

func show_end(won: bool) -> void:
	mode = "end"
	_open(480)
	dim.color = Color(0.02, 0.03, 0.07, 0.6)
	if won:
		_label("RESCUED!", 46, Color("ffd24a"))
		_label("A ship answered your signal fire on day %d." % g.day, 18)
	else:
		_label("YOU PERISHED", 42, Color("ff6a5a"))
		_label("The island claimed you on day %d." % g.day, 18)
	_label("Creatures slain: %d  ·  Items crafted: %d" % [g.kills, g.crafted], 15, Color("cfd6ea"))
	_label("Best: day %d  ·  Rescues: %d" % [g.best.day, g.best.wins], 15, Color("ffd27a"))
	_button("Play Again", func(): g.new_game())
	_button("Title Screen", func():
		g.state = "title"
		g._clear_entities()
		show_title())

func show_chest() -> void:
	mode = "chest"
	_open(460)
	_label("Chest", 30, Color("ffb36a"))
	var ch: Dictionary = g.world.builds[g.chest_tile].inv if g.world.builds.has(g.chest_tile) else {}
	var parts := []
	for k in ch:
		parts.append("%s x%d" % [D.ITEMS[k].name, ch[k]])
	_label("Empty" if parts.is_empty() else ", ".join(parts), 15, Color("e6ecf8"))
	_button("Deposit materials & food", func():
		g.chest_deposit()
		show_chest())
	_button("Take everything", func():
		g.chest_withdraw()
		show_chest())
	_button("Close", func(): g.close_menu())

func show_craft() -> void:
	mode = "craft"
	var vs := get_viewport_rect().size
	_open(660)
	var head := HBoxContainer.new()
	box.add_child(head)
	var tl := Label.new()
	tl.text = "Crafting"
	tl.add_theme_font_size_override("font_size", 28)
	tl.add_theme_color_override("font_color", Color("ffb36a"))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close := Button.new()
	close.text = "  Close  "
	close.pressed.connect(func(): g.close_menu())
	head.add_child(close)
	var st := _label("", 14, Color("cfd6ea"))
	st.name = "Stations"
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, minf(480.0, vs.y - 200.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	craft_rows.clear()
	for rec in D.RECIPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		var ic := IconRect.new()
		ic.id = rec.id
		ic.custom_minimum_size = Vector2(44, 44)
		row.add_child(ic)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 0)
		row.add_child(vb)
		var nl := Label.new()
		nl.text = D.ITEMS[rec.id].name + (" x%d" % rec.n if rec.n > 1 else "")
		nl.add_theme_font_size_override("font_size", 17)
		vb.add_child(nl)
		var cl := Label.new()
		cl.add_theme_font_size_override("font_size", 13)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(cl)
		var b := Button.new()
		b.text = "Craft"
		b.custom_minimum_size = Vector2(84, 44)
		b.pressed.connect(func():
			g.craft(rec)
			_refresh_craft())
		row.add_child(b)
		craft_rows.append({"rec": rec, "cost": cl, "btn": b, "name": nl})
	_refresh_craft()

func _refresh_craft() -> void:
	if mode != "craft" or box == null:
		return
	var st := box.get_node_or_null("Stations")
	if st:
		var s := "Nearby:  "
		for k in ["workbench", "furnace", "campfire"]:
			s += "%s %s   " % [D.STATION_NAMES[k], "[yes]" if g.station_near(k) else "[no]"]
		st.text = s
	for r in craft_rows:
		var rec: Dictionary = r.rec
		var parts := []
		for k in rec.cost:
			parts.append("%s %d/%d" % [D.ITEMS[k].name, g.count(k), rec.cost[k]])
		var txt := " · ".join(parts)
		if rec.st != "":
			txt += "   [needs %s]" % D.STATION_NAMES[rec.st]
		r.cost.text = txt
		var ok: bool = g.can_craft(rec)
		r.btn.disabled = not ok
		r.cost.add_theme_color_override("font_color", Color("b8f0a0") if ok else Color("e0a0a0"))
		var have: int = g.count(rec.id)
		r.name.text = D.ITEMS[rec.id].name + (" x%d" % rec.n if rec.n > 1 else "") + ("   (have %d)" % have if have > 0 else "")
