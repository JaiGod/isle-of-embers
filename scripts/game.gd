extends Node2D
## Isle of Embers: game state, simulation, input and saving.
## World rendering lives in world.gd, the HUD in hud.gd, menus in ui.gd.

const D = preload("res://scripts/data.gd")
const WorldScript = preload("res://scripts/world.gd")
const HudScript = preload("res://scripts/hud.gd")
const UiScript = preload("res://scripts/ui.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const SAVE_PATH := "user://isle_save.json"
const BEST_PATH := "user://isle_best.json"
const T := D.TILE

var world: Node2D
var hud: Control
var ui: Control
var sfx: Node
var cam: Camera2D
var night_rect: ColorRect
var night_mat: ShaderMaterial
var rng := RandomNumberGenerator.new()

var state := "title"         # title, play, paused, craft, chest, dead, won
var ppos := Vector2.ZERO
var pvel := Vector2.ZERO
var aim := Vector2.DOWN
var walk_t := 0.0
var hp := 100.0
var food := 100.0
var water := 100.0
var warm := 100.0
var inv := {}
const HOTBAR_ORDER := ["hand", "axe_stone", "pick_stone", "spear", "sword_iron", "bow", "fire_staff",
	"campfire", "workbench", "wall_wood", "wall_stone", "chest", "farm", "furnace", "beacon",
	"meat_cooked", "berries", "meat_raw"]
const SLOTS := 9
var sel_id := "hand"
var armor := ""
var atk_cd := 0.0
var swing_t := 0.0
var hurt_t := 0.0
var day := 1
var tod := 0.12              # time of day 0..1
var was_night := false
var raid_t := 0.0
var animal_t := 0.0
var boss1_dead := false
var boss1_spawned := false
var boss2_dead := false
var beacon_t := -1.0         # >= 0 while the beacon burns
var beacon_tile := Vector2i(-1, -1)
var kills := 0
var crafted := 0
var autosave_t := 0.0
var chest_tile := Vector2i(-1, -1)
var ghost_tile := Vector2i(-1, -1)
var shake_amt := 0.0
var toast := ""
var toast_t := 0.0
var best := {"day": 0, "wins": 0}

var mobs: Array = []
var projs: Array = []
var parts: Array = []
var floats: Array = []
var drops: Array = []

# input state
var touch_mode := false
var mouse_world := Vector2.ZERO
var mouse_active := false
var attack_held := false
var joy_vec := Vector2.ZERO
var title_t := 0.0

func _ready() -> void:
	rng.randomize()
	_setup_input()
	sfx = SfxScript.new()
	add_child(sfx)
	world = WorldScript.new()
	world.g = self
	add_child(world)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	add_child(cam)
	cam.make_current()
	var night_layer := CanvasLayer.new()
	night_layer.layer = 1
	add_child(night_layer)
	night_rect = ColorRect.new()
	night_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = NIGHT_SHADER
	night_mat.shader = sh
	night_rect.material = night_mat
	night_layer.add_child(night_rect)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud = HudScript.new()
	hud.g = self
	hud_layer.add_child(hud)
	ui = UiScript.new()
	ui.g = self
	hud_layer.add_child(ui)
	_load_best()
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()
	# title screen shows a live island in the background
	world.generate(rng.randi() % 100000)
	ppos = WorldScript.tile_center(world.crater) + Vector2(0, 600)
	cam.position = ppos
	cam.reset_smoothing()
	ui.show_title()
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search")
		if typeof(q) == TYPE_STRING and q.begins_with("?demo="):
			_demo(int(q.substr(6)))

## Screenshot / showcase scenarios: play/?demo=1 (base at night), 2 (Thornback), 3 (Wyrm).
func _demo(n: int) -> void:
	new_game()
	for k in ["wood", "stone", "fiber", "iron", "hide", "arrow", "berries", "meat_cooked"]:
		add_item(k, 12, false)
	for k in ["axe_stone", "pick_stone", "spear", "bow", "sword_iron", "wall_wood", "campfire"]:
		add_item(k, 1 if not k.begins_with("wall") else 6, false)
	add_item("hide_armor", 1, false)
	var c: Vector2i = world.spawn_tile
	for oy in range(-4, 5):
		for ox in range(-4, 5):
			world.res.erase(c + Vector2i(ox, oy))
	for b in [[Vector2i(-2, -1), "campfire"], [Vector2i(2, -2), "workbench"], [Vector2i(3, -2), "furnace"], [Vector2i(-3, 1), "chest"], [Vector2i(1, 2), "farm"]]:
		world.builds[c + b[0]] = {"id": b[1], "hp": float(D.ITEMS[b[1]].hp), "t": 1.0, "inv": {}, "lit": 0.0}
	for x in range(-4, 5):
		if world.tile(c + Vector2i(x, -4)) > D.T_SHALLOW:
			world.builds[c + Vector2i(x, -4)] = {"id": "wall_wood" if x % 3 else "wall_stone", "hp": 90.0, "t": 0.0, "inv": {}, "lit": 0.0}
	sel_id = "sword_iron"
	day = 3
	if n == 1:
		tod = 0.72
		was_night = true
		for i in 5:
			_spawn_near_player("ashling" if i % 2 else "brute", 260.0)
	elif n == 2:
		tod = 0.5
		boss1_spawned = true
		_spawn_near_player("thornback", 220.0)
		add_item("fire_staff", 1, false)
		sel_id = "fire_staff"
	elif n == 3:
		boss1_dead = true
		add_item("fire_staff", 1, false)
		sel_id = "fire_staff"
		ppos = WorldScript.tile_center(world.crater) + Vector2(0, 230)
		tod = 0.6
	cam.position = ppos
	cam.reset_smoothing()

const NIGHT_SHADER := """
shader_type canvas_item;
uniform float dark = 0.0;
uniform vec4 tint : source_color = vec4(0.03, 0.05, 0.16, 1.0);
uniform vec2 size = vec2(1280.0, 720.0);
uniform int count = 0;
uniform vec4 lights[24];
void fragment() {
	vec2 p = UV * size;
	float lit = 0.0;
	for (int i = 0; i < 24; i++) {
		if (i >= count) { break; }
		vec4 L = lights[i];
		float d = length(p - L.xy);
		lit = max(lit, L.w * (1.0 - smoothstep(L.z * 0.3, L.z, d)));
	}
	float a = dark * (1.0 - lit * 0.92);
	vec3 col = mix(tint.rgb, vec3(1.0, 0.5, 0.15), lit * 0.35);
	COLOR = vec4(col, a);
}
"""

func _on_resize() -> void:
	var s := get_tree().root.size
	if s.y > s.x:
		get_tree().root.content_scale_size = Vector2i(720, 1280)
	else:
		get_tree().root.content_scale_size = Vector2i(1280, 720)

func _setup_input() -> void:
	var map := {
		"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E], "eat": [KEY_F], "craft": [KEY_C, KEY_TAB], "pause": [KEY_ESCAPE, KEY_P],
		"sound": [KEY_M], "attack": [KEY_SPACE, KEY_J], "drop_sel": [KEY_Q],
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

# ================================================================ new / load
func new_game() -> void:
	world.generate(rng.randi() % 1000000)
	ppos = WorldScript.tile_center(world.spawn_tile)
	hp = 100.0; food = 100.0; water = 100.0; warm = 100.0
	inv = {}
	sel_id = "hand"
	armor = ""
	day = 1; tod = 0.12; was_night = false
	boss1_dead = false; boss1_spawned = false; boss2_dead = false
	beacon_t = -1.0; beacon_tile = Vector2i(-1, -1)
	kills = 0; crafted = 0
	_clear_entities()
	_spawn_wyrm()
	cam.position = ppos
	cam.reset_smoothing()
	state = "play"
	ui.hide_all()
	show_toast("Day 1. Gather wood and stone. Press C to craft.")
	sfx.play("dawn")

func _clear_entities() -> void:
	mobs.clear(); projs.clear(); parts.clear(); floats.clear(); drops.clear()

func _spawn_wyrm() -> void:
	if boss2_dead:
		return
	var m := _make_mob("wyrm", WorldScript.tile_center(world.crater))
	m.state = "sleep"
	mobs.append(m)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	if state in ["dead", "won", "title"]:
		return false
	var r := []
	for c in world.res:
		var v: Array = world.res[c]
		r.append_array([c.x, c.y, v[0], v[1]])
	var b := []
	for c in world.builds:
		var d: Dictionary = world.builds[c]
		b.append({"x": c.x, "y": c.y, "id": d.id, "hp": d.hp, "t": d.get("t", 0.0), "inv": d.get("inv", {}), "lit": d.get("lit", 0.0)})
	var data := {
		"v": 1, "seed": world.seed_val, "day": day, "tod": tod, "px": ppos.x, "py": ppos.y,
		"hp": hp, "food": food, "water": water, "warm": warm, "inv": inv, "sel": sel_id,
		"armor": armor, "b1": boss1_dead, "b1s": boss1_spawned, "b2": boss2_dead, "beacon_t": beacon_t,
		"bx": beacon_tile.x, "by": beacon_tile.y, "kills": kills, "crafted": crafted, "res": r, "builds": b,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("seed"):
		return false
	world.generate(int(data.seed))
	world.res.clear()
	var r: Array = data.get("res", [])
	for i in range(0, r.size() - 3, 4):
		world.res[Vector2i(int(r[i]), int(r[i + 1]))] = [int(r[i + 2]), int(r[i + 3])]
	world.builds.clear()
	for bd in data.get("builds", []):
		var ninv := {}
		for k in bd.get("inv", {}):
			ninv[k] = int(bd.inv[k])
		world.builds[Vector2i(int(bd.x), int(bd.y))] = {"id": str(bd.id), "hp": float(bd.hp), "t": float(bd.get("t", 0.0)), "inv": ninv, "lit": float(bd.get("lit", 0.0))}
	day = int(data.day); tod = float(data.tod)
	ppos = Vector2(float(data.px), float(data.py))
	hp = float(data.hp); food = float(data.food); water = float(data.water); warm = float(data.warm)
	inv = {}
	for k in data.inv:
		inv[k] = int(data.inv[k])
	sel_id = str(data.get("sel", "hand")) if typeof(data.get("sel")) == TYPE_STRING else "hand"
	armor = str(data.armor)
	boss1_dead = bool(data.b1); boss1_spawned = bool(data.get("b1s", false)); boss2_dead = bool(data.b2)
	beacon_t = float(data.get("beacon_t", -1.0))
	beacon_tile = Vector2i(int(data.get("bx", -1)), int(data.get("by", -1)))
	kills = int(data.get("kills", 0)); crafted = int(data.get("crafted", 0))
	was_night = is_night()
	_clear_entities()
	_spawn_wyrm()
	if boss1_spawned and not boss1_dead:
		_spawn_near_player("thornback", 520.0)
	cam.position = ppos
	cam.reset_smoothing()
	state = "play"
	ui.hide_all()
	show_toast("Welcome back. Day %d." % day)
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _load_best() -> void:
	if FileAccess.file_exists(BEST_PATH):
		var f := FileAccess.open(BEST_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				best.day = int(d.get("day", 0)); best.wins = int(d.get("wins", 0))
			f.close()

func _save_best() -> void:
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(best))
		f.close()

# ================================================================ inventory
func count(id: String) -> int:
	return int(inv.get(id, 0))

func add_item(id: String, n: int, show: bool = true) -> void:
	inv[id] = count(id) + n
	var kind: String = D.ITEMS[id].kind
	if kind == "armor":
		var cur: float = D.ITEMS[armor].armor if armor != "" else 0.0
		if D.ITEMS[id].armor > cur:
			armor = id
			show_toast("Equipped %s." % D.ITEMS[id].name)
	if show:
		floats.append({"p": ppos + Vector2(randf_range(-10, 10), -46), "text": "+%d %s" % [n, D.ITEMS[id].name], "col": Color("ffe9a8"), "life": 1.1})

func take(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	inv[id] = count(id) - n
	if inv[id] <= 0:
		inv.erase(id)
		if sel_id == id:
			sel_id = "hand"
	return true

func sel_item() -> String:
	if sel_id != "hand" and count(sel_id) <= 0:
		return "hand"
	return sel_id

## Every usable item the player owns, in a stable order (the hotbar).
func usable() -> Array:
	var out := []
	for id in HOTBAR_ORDER:
		if id == "hand" or count(id) > 0:
			out.append(id)
	return out

## [first visible index, visible items] for the hotbar window.
func hotbar_view() -> Array:
	var u := usable()
	var i := maxi(0, u.find(sel_item()))
	var start := clampi(i - SLOTS / 2, 0, maxi(0, u.size() - SLOTS))
	return [start, u.slice(start, start + SLOTS)]

func select_slot(k: int) -> void:
	var v := hotbar_view()
	if k < v[1].size():
		sel_id = v[1][k]
		sfx.play("ui")

func cycle_sel(d: int) -> void:
	var u := usable()
	var i := maxi(0, u.find(sel_item()))
	sel_id = u[(i + d + u.size()) % u.size()]

func station_near(st: String) -> bool:
	if st == "":
		return true
	return world.near_build(ppos, st, T * 3.5).x >= 0

func can_craft(rec: Dictionary) -> bool:
	if not station_near(rec.st):
		return false
	for k in rec.cost:
		if count(k) < rec.cost[k]:
			return false
	return true

func craft(rec: Dictionary) -> bool:
	if not can_craft(rec):
		sfx.play("hurt", 1.6, -6.0)
		return false
	for k in rec.cost:
		take(k, rec.cost[k])
	add_item(rec.id, rec.n)
	crafted += 1
	sfx.play("craft")
	burst(ppos + Vector2(0, -20), Color("ffd27a"), 14, 120.0)
	return true

# ================================================================ main loop
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	title_t += delta
	if toast_t > 0.0:
		toast_t -= delta
	match state:
		"title":
			var c := WorldScript.tile_center(world.crater)
			ppos = c + Vector2(cos(title_t * 0.05), sin(title_t * 0.05)) * 900.0
			cam.position = ppos
			tod = 0.3
		"play":
			_update_play(delta)
		"craft", "chest":
			# the world keeps running while menus are open (it's survival!)
			_update_play(delta * 0.35)
	_update_fx(delta if state != "paused" else 0.0)
	_update_night()
	# screen shake
	if shake_amt > 0.0:
		shake_amt = maxf(0.0, shake_amt - delta * 30.0)
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	else:
		cam.offset = Vector2.ZERO
	hud.queue_redraw()

func is_night() -> bool:
	return tod >= D.NIGHT_START and tod < D.NIGHT_END

func darkness() -> float:
	# 0 at day, ramps up at dusk and down at dawn
	var a := 0.0
	if tod > D.NIGHT_START - 0.06 and tod < D.NIGHT_START:
		a = (tod - (D.NIGHT_START - 0.06)) / 0.06
	elif is_night():
		a = 1.0
	elif tod >= D.NIGHT_END:
		a = 1.0 - (tod - D.NIGHT_END) / (1.0 - D.NIGHT_END)
	return clamp(a, 0.0, 1.0) * 0.82

func _update_play(delta: float) -> void:
	_update_time(delta)
	_update_player(delta)
	_update_stats(delta)
	_update_mobs(delta)
	_update_projs(delta)
	_update_drops(delta)
	_update_spawns(delta)
	_update_builds(delta)
	autosave_t += delta
	if autosave_t > 60.0:
		autosave_t = 0.0
		save_game()

func _update_time(delta: float) -> void:
	tod += delta / D.DAY_LEN
	if tod >= 1.0:
		tod -= 1.0
		day += 1
		show_toast("Day %d. The sun rises." % day)
		sfx.play("dawn")
		world.regrow(rng, ppos, 50)
		if day > best.day:
			best.day = day
			_save_best()
		save_game()
	var n := is_night()
	if n and not was_night:
		show_toast("Night %d falls. Creatures stir in the dark..." % day)
		sfx.play("night")
		raid_t = 4.0
		if day >= 3 and not boss1_dead and not boss1_spawned:
			boss1_spawned = true
			_spawn_near_player("thornback", 640.0)
			show_toast("The THORNBACK is hunting you!")
			sfx.play("roar", 0.8)
			shake_amt = 10.0
	if not n and was_night:
		for m in mobs:
			if m.type in ["ashling", "brute"]:
				m.burn = true
	was_night = n

func _update_player(delta: float) -> void:
	var dir := Input.get_vector("left", "right", "up", "down")
	if joy_vec.length() > 0.1:
		dir = joy_vec.limit_length(1.0)
	var speed := 150.0
	var t: int = world.tile(WorldScript.to_tile(ppos))
	if t == D.T_SHALLOW:
		speed *= 0.6
	if food <= 0.0 or water <= 0.0:
		speed *= 0.8
	pvel = pvel.lerp(dir * speed, minf(1.0, delta * 14.0))
	_move_circle(self, "ppos", pvel * delta, 9.0)
	if pvel.length() > 10.0:
		walk_t += delta
	# aiming
	if touch_mode or not mouse_active:
		if dir.length() > 0.2:
			aim = dir.normalized()
		var tgt := _auto_target()
		if tgt != Vector2.INF:
			aim = (tgt - ppos).normalized()
	else:
		mouse_world = get_global_mouse_position()
		var v := mouse_world - (ppos + Vector2(0, -14))
		if v.length() > 4.0:
			aim = v.normalized()
	atk_cd = maxf(0.0, atk_cd - delta)
	swing_t = maxf(0.0, swing_t - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	# building ghost
	ghost_tile = Vector2i(-1, -1)
	var id := sel_item()
	if D.ITEMS[id].kind == "build" and count(id) > 0:
		var gt: Vector2i
		if not touch_mode and mouse_active and mouse_world.distance_to(ppos) < T * 4.0:
			gt = WorldScript.to_tile(mouse_world)
		else:
			gt = WorldScript.to_tile(ppos + aim * T * 1.2)
		ghost_tile = gt
	if attack_held or Input.is_action_pressed("attack"):
		use_item()
	cam.position = ppos + Vector2(0, -10)
	# ember ground burns
	if t == D.T_EMBER:
		damage_player(4.0 * delta, false)
		if rng.randf() < delta * 8.0:
			spark(ppos + Vector2(randf_range(-8, 8), 0), Color(1, 0.5, 0.15), Vector2(0, -60), 0.6, 3.0)

func _move_circle(obj: Object, prop: String, mv: Vector2, r: float) -> bool:
	var p: Vector2 = obj.get(prop) if prop != "" else Vector2.ZERO
	var blocked := false
	var nx := p + Vector2(mv.x, 0)
	if not world.blocked_at(nx, r):
		p = nx
	else:
		blocked = true
	var ny := p + Vector2(0, mv.y)
	if not world.blocked_at(ny, r):
		p = ny
	else:
		blocked = true
	p.x = clamp(p.x, T, (D.MAP - 1) * T)
	p.y = clamp(p.y, T, (D.MAP - 1) * T)
	obj.set(prop, p)
	return blocked

func _auto_target() -> Vector2:
	var best_d := 150.0
	var out := Vector2.INF
	for m in mobs:
		if not D.MOBS[m.type].hostile and m.type != "tusker" and m.type != "crab":
			continue
		if m.get("state", "") == "sleep":
			continue
		var d: float = m.p.distance_to(ppos)
		if d < best_d:
			best_d = d
			out = m.p + Vector2(0, -10)
	return out

func _update_stats(delta: float) -> void:
	var near_fire: bool = world.near_build(ppos, "campfire", T * 3.2).x >= 0
	var t: int = world.tile(WorldScript.to_tile(ppos))
	food = maxf(0.0, food - delta * 0.30)
	water = maxf(0.0, water - delta * 0.42)
	if is_night():
		var cold: float = 0.75 * (1.0 - (D.ITEMS[armor].cold if armor != "" else 0.0))
		warm -= delta * cold
	else:
		warm += delta * 0.6
	if near_fire:
		warm += delta * 4.0
	if t == D.T_ASH or t == D.T_EMBER:
		warm += delta * 2.0
	warm = clamp(warm, 0.0, 100.0)
	var starving := 0
	if food <= 0.0: starving += 1
	if water <= 0.0: starving += 1
	if warm <= 0.0: starving += 1
	if starving > 0:
		damage_player(delta * 1.6 * starving, false)
	elif food > 45.0 and water > 45.0 and warm > 30.0:
		hp = minf(100.0, hp + delta * (0.8 if near_fire else 0.4))

func damage_player(n: float, knock: bool, from: Vector2 = Vector2.INF) -> void:
	if state != "play" and state != "craft" and state != "chest":
		return
	if knock:
		if hurt_t > 0.0:
			return
		var a: float = D.ITEMS[armor].armor if armor != "" else 0.0
		n *= (1.0 - a)
		hurt_t = 0.6
		shake_amt = maxf(shake_amt, 7.0)
		sfx.play("hurt")
		burst(ppos + Vector2(0, -16), Color("ff5a4a"), 8, 120.0)
		floats.append({"p": ppos + Vector2(0, -50), "text": "-%d" % int(round(n)), "col": Color("ff6a5a"), "life": 0.9})
		if from != Vector2.INF:
			pvel += (ppos - from).normalized() * 320.0
	hp -= n
	if hp <= 0.0:
		hp = 0.0
		_die()

func _die() -> void:
	state = "dead"
	sfx.play("die")
	burst(ppos + Vector2(0, -14), Color("ff5a4a"), 30, 200.0)
	if day > best.day:
		best.day = day
	_save_best()
	delete_save()
	ui.hide_all()
	ui.show_end(false)

func win() -> void:
	state = "won"
	sfx.play("win")
	best.wins += 1
	if day > best.day:
		best.day = day
	_save_best()
	delete_save()
	for i in 6:
		burst(ppos + Vector2(randf_range(-200, 200), randf_range(-150, 50)), Color.from_hsv(randf(), 0.6, 1.0), 20, 220.0)
	ui.hide_all()
	ui.show_end(true)

# ================================================================ actions
func use_item() -> void:
	if atk_cd > 0.0 or state != "play":
		return
	var id := sel_item()
	var info: Dictionary = D.ITEMS[id]
	match info.kind:
		"build":
			if ghost_tile.x >= 0 and world.can_place(ghost_tile, ppos):
				_place(id, ghost_tile)
			else:
				atk_cd = 0.2
		"food":
			eat(id)
			atk_cd = 0.4
		"ranged":
			_shoot(id, info)
		_:
			_swing(id, info)

func _place(id: String, c: Vector2i) -> void:
	if not take(id, 1):
		return
	world.builds[c] = {"id": id, "hp": float(D.ITEMS[id].hp), "t": 0.0, "inv": {}, "lit": 0.0}
	atk_cd = 0.25
	sfx.play("place")
	burst(WorldScript.tile_center(c) + Vector2(0, 8), Color("c8b48a"), 10, 90.0)
	if id == "beacon":
		beacon_tile = c
		show_toast("Beacon built! Press E next to it to light the signal fire.")
	elif id == "workbench":
		show_toast("Workbench placed. New recipes unlocked nearby (C).")
	elif id == "furnace":
		show_toast("Furnace placed. Smelt iron and forge gear nearby.")

func _swing(id: String, info: Dictionary) -> void:
	atk_cd = info.cd
	swing_t = 0.22
	sfx.play("swing")
	var reach: float = info.reach
	var origin := ppos + Vector2(0, -12)
	var hit_any := false
	for m in mobs:
		var to: Vector2 = (m.p + Vector2(0, -10)) - origin
		var r: float = D.MOBS[m.type].r
		if to.length() < reach + r and (to.length() < r + 8 or to.normalized().dot(aim) > 0.35):
			hurt_mob(m, info.dmg, aim)
			hit_any = true
	if hit_any:
		return
	# gather: best resource tile in front
	var best_c := Vector2i(-1, -1)
	var bd := 1e9
	var pt := WorldScript.to_tile(ppos)
	for y in range(-2, 3):
		for x in range(-2, 3):
			var c := pt + Vector2i(x, y)
			if not world.res.has(c):
				continue
			var cc := WorldScript.tile_center(c) + Vector2(0, 4)
			var to2 := cc - origin
			var d := to2.length()
			if d < reach + 20.0 and (d < 26.0 or to2.normalized().dot(aim) > 0.3):
				var score := d - to2.normalized().dot(aim) * 20.0
				if score < bd:
					bd = score
					best_c = c
	if best_c.x >= 0:
		_hit_res(best_c, info)

func _hit_res(c: Vector2i, info: Dictionary) -> void:
	var r: Array = world.res[c]
	var rd: Dictionary = D.RES[r[0]]
	var pos := WorldScript.tile_center(c)
	var power := 1
	if rd.tool == "axe":
		power = maxi(1, info.get("axe", 1))
	elif rd.tool == "pick":
		power = maxi(1, info.get("pick", 0))
		if r[0] == D.R_ORE and info.get("pick", 0) < 3:
			show_toast("Iron veins need a pickaxe.")
			sfx.play("mine", 0.6, -6.0)
			world.shake[c] = 0.15
			return
	r[1] -= power
	world.shake[c] = 0.2
	if r[0] in [D.R_ROCK, D.R_ORE]:
		sfx.play("mine")
		burst(pos, Color("b9bec6"), 6, 110.0)
	else:
		sfx.play("chop")
		burst(pos + Vector2(0, -14), Color("5cb84f") if r[0] != D.R_BUSH else Color("7cc35a"), 6, 110.0)
	if r[1] <= 0:
		world.res.erase(c)
		for k in rd.drop:
			_drop(k, rd.drop[k], pos)
		for k in rd.bonus:
			if rng.randf() < 0.6:
				_drop(k, rd.bonus[k], pos)
		shake_amt = maxf(shake_amt, 3.0)
		burst(pos, Color("d9b98a"), 12, 160.0)

func _drop(id: String, n: int, at: Vector2) -> void:
	drops.append({"id": id, "n": n, "p": at, "v": Vector2(randf_range(-80, 80), randf_range(-120, -40)), "age": 0.0})

func _shoot(id: String, info: Dictionary) -> void:
	var ammo: String = info.ammo
	if ammo != "" and not take(ammo, 1):
		show_toast("No arrows! Craft some at a workbench.")
		atk_cd = 0.4
		return
	atk_cd = info.cd
	swing_t = 0.12
	var kind := "arrow" if id == "bow" else "fire"
	sfx.play("shoot" if kind == "arrow" else "fire")
	projs.append({"p": ppos + Vector2(0, -14) + aim * 14.0, "v": aim * info.speed, "dmg": info.dmg, "kind": kind, "enemy": false, "life": 1.3})

func interact() -> void:
	if state != "play":
		return
	var front := ppos + aim * 20.0
	var c: Vector2i = world.near_build(front, "", T * 1.6)
	if c.x >= 0:
		var b: Dictionary = world.builds[c]
		match b.id:
			"chest":
				chest_tile = c
				state = "chest"
				ui.show_chest()
				sfx.play("ui")
				return
			"beacon":
				if beacon_t < 0.0:
					beacon_t = 0.0
					beacon_tile = c
					b.lit = 1.0
					show_toast("The signal fire blazes! Survive until the rescue ship arrives!")
					sfx.play("fire", 0.7)
					sfx.play("roar", 1.4, -4.0)
					shake_amt = 8.0
					raid_t = 2.0
				else:
					show_toast("Hold on! Rescue in %d s." % int(60.0 - beacon_t))
				return
			"farm":
				if b.t >= 1.0:
					b.t = 0.0
					_drop("berries", 4, WorldScript.tile_center(c))
					_drop("fiber", 1, WorldScript.tile_center(c))
					sfx.play("pickup")
					return
				elif b.t <= 0.0:
					if take("berries", 1):
						b.t = 0.01
						show_toast("Planted berries. They grow in about a minute.")
						sfx.play("place")
					else:
						show_toast("You need berries to plant.")
					return
				else:
					show_toast("Growing... %d%%" % int(b.t * 100.0))
					return
			"campfire":
				if count("meat_raw") > 0:
					var n := count("meat_raw")
					take("meat_raw", n)
					add_item("meat_cooked", n)
					sfx.play("fire")
					return
	if world.near_water(ppos, 30.0):
		water = minf(100.0, water + 35.0)
		sfx.play("drink")
		burst(ppos + aim * 18.0, Color("8fd0e6"), 8, 80.0)
		floats.append({"p": ppos + Vector2(0, -46), "text": "+Water", "col": Color("8fd0e6"), "life": 1.0})
		return
	show_toast("Nothing to use here. (Water, chest, farm, campfire or beacon)")

func eat(pref: String = "") -> void:
	var order := ["meat_cooked", "berries", "meat_raw"]
	var id := ""
	if pref != "" and D.ITEMS[pref].kind == "food" and count(pref) > 0:
		id = pref
	else:
		for o in order:
			if count(o) > 0:
				id = o
				break
	if id == "":
		show_toast("No food. Pick berries from bushes or hunt tuskers.")
		return
	if food >= 99.0 and D.ITEMS[id].hp <= 0:
		show_toast("You're full.")
		return
	take(id, 1)
	var it: Dictionary = D.ITEMS[id]
	food = minf(100.0, food + it.food)
	water = minf(100.0, water + it.water)
	hp = clamp(hp + it.hp, 0.0, 100.0)
	sfx.play("eat")
	floats.append({"p": ppos + Vector2(0, -46), "text": "+%d Food" % it.food, "col": Color("ffd27a"), "life": 1.0})
	if hp <= 0.0:
		_die()

func chest_deposit() -> void:
	if not world.builds.has(chest_tile):
		return
	var ch: Dictionary = world.builds[chest_tile].inv
	for k in inv.keys():
		if D.ITEMS[k].kind == "mat" or D.ITEMS[k].kind == "food":
			ch[k] = int(ch.get(k, 0)) + count(k)
			take(k, count(k))
	sfx.play("place")

func chest_withdraw() -> void:
	if not world.builds.has(chest_tile):
		return
	var ch: Dictionary = world.builds[chest_tile].inv
	for k in ch.keys():
		add_item(k, int(ch[k]), false)
	ch.clear()
	sfx.play("pickup")

# ================================================================ mobs
func _make_mob(type: String, p: Vector2) -> Dictionary:
	var info: Dictionary = D.MOBS[type]
	var hpv: float = info.hp * (1.0 + (day - 1) * 0.08 if info.hostile and not info.get("boss", false) else 1.0)
	var m := {"type": type, "p": p, "v": Vector2.ZERO, "hp": hpv, "maxhp": hpv, "state": "idle", "t": 0.0,
		"cd": 1.0, "hit_t": 0.0, "face": 1.0, "seed": rng.randf() * 10.0, "wander": Vector2.ZERO, "flee": 0.0, "burn": false, "phase": 0}
	if type == "wyrm":
		var segs := []
		for i in 10:
			segs.append(p + Vector2(0, (i + 1) * 16))
		m.segs = segs
		m.home = p
	return m

func _spawn_near_player(type: String, dist: float) -> bool:
	for i in 40:
		var a := rng.randf() * TAU
		var p := ppos + Vector2(cos(a), sin(a)) * dist * rng.randf_range(0.9, 1.15)
		var c := WorldScript.to_tile(p)
		var t: int = world.tile(c)
		if world.walkable_tile(c) and t >= D.T_SAND and t != D.T_EMBER:
			if type in ["tusker"] and not (t == D.T_GRASS or t == D.T_FOREST):
				continue
			if type == "crab" and t != D.T_SAND:
				continue
			mobs.append(_make_mob(type, WorldScript.tile_center(c)))
			return true
	return false

func hurt_mob(m: Dictionary, dmg: float, dir: Vector2) -> void:
	if m.state == "sleep":
		_wake_wyrm(m)
	var mult := 2.0 if m.state == "stun" else 1.0
	m.hp -= dmg * mult
	m.hit_t = 0.12
	if not D.MOBS[m.type].get("boss", false):
		m.v += dir * 260.0
	m.flee = 3.0
	sfx.play("hit", 1.0 if not D.MOBS[m.type].get("boss", false) else 0.7)
	burst(m.p + Vector2(0, -12), Color("ffffff"), 5, 120.0)
	floats.append({"p": m.p + Vector2(0, -D.MOBS[m.type].r * 2.0 - 20), "text": str(int(dmg * mult)), "col": Color("ffffff") if mult == 1.0 else Color("ffd24a"), "life": 0.8})
	shake_amt = maxf(shake_amt, 2.5)
	if m.hp <= 0.0:
		_kill_mob(m, true)

func _kill_mob(m: Dictionary, give: bool) -> void:
	if m.get("dead", false):
		return
	m.dead = true
	var info: Dictionary = D.MOBS[m.type]
	burst(m.p + Vector2(0, -12), Color("2a2230") if info.hostile else Color("c88a6a"), 16 if not info.get("boss", false) else 60, 180.0)
	if give:
		kills += 1
		for k in info.drop:
			_drop(k, info.drop[k], m.p)
	sfx.play("die", 1.4 if not info.get("boss", false) else 0.6)
	if m.type == "thornback":
		boss1_dead = true
		shake_amt = 14.0
		show_toast("Thornback defeated! It dropped an Ember Shard. Forge a Fire Staff.")
	elif m.type == "wyrm":
		boss2_dead = true
		shake_amt = 18.0
		show_toast("The Cinder Wyrm falls! Take its Ember Heart and build the beacon.")

func _wake_wyrm(m: Dictionary) -> void:
	if m.state != "sleep":
		return
	m.state = "fight"
	m.cd = 1.5
	sfx.play("roar", 0.6)
	shake_amt = 16.0
	show_toast("The CINDER WYRM awakens!")

func _update_mobs(delta: float) -> void:
	for m in mobs:
		if m.get("dead", false):
			continue
		m.hit_t = maxf(0.0, m.hit_t - delta)
		m.cd -= delta
		m.flee = maxf(0.0, m.flee - delta)
		var info: Dictionary = D.MOBS[m.type]
		var to: Vector2 = ppos - m.p
		var dist := to.length()
		if m.burn:
			m.hp -= delta * 14.0
			if rng.randf() < delta * 20.0:
				spark(m.p + Vector2(randf_range(-8, 8), -10), Color(1, 0.55, 0.2), Vector2(0, -70), 0.6, 3.0)
			if m.hp <= 0.0:
				_kill_mob(m, false)
				continue
		match m.type:
			"wyrm":
				_wyrm_ai(m, delta, to, dist)
				continue
			"thornback":
				_thornback_ai(m, delta, to, dist)
				continue
		var want := Vector2.ZERO
		if info.hostile:
			if dist < 900.0:
				want = to.normalized() * info.spd
		else:
			if m.flee > 0.0:
				want = -to.normalized() * info.spd * 1.5
				if m.type == "crab" and dist < 40.0:
					want = to.normalized() * info.spd
			else:
				m.t -= delta
				if m.t <= 0.0:
					m.t = rng.randf_range(1.5, 4.0)
					m.wander = Vector2.from_angle(rng.randf() * TAU) * info.spd * 0.5 if rng.randf() < 0.7 else Vector2.ZERO
				want = m.wander
		m.v = m.v.lerp(want, minf(1.0, delta * 5.0))
		if absf(m.v.x) > 2.0:
			m.face = sign(m.v.x)
		var blocked := _move_mob(m, m.v * delta, info.r * 0.6)
		if blocked and info.hostile:
			# chew through walls in the way
			var bc: Vector2i = world.building_at(m.p + m.v.normalized() * (info.r + 6.0), 4.0)
			if bc.x >= 0 and m.cd <= 0.0:
				m.cd = 0.9
				_hurt_build(bc, info.dmg)
			elif m.t <= 0.0:
				m.t = 0.6
				m.v = m.v.rotated(PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
			m.t -= delta
		# melee
		var dmg_on: bool = info.hostile or (m.type == "crab" and m.flee > 0.0)
		if dmg_on and dist < info.r + 14.0 and m.cd <= 0.0:
			m.cd = 1.0
			damage_player(info.dmg, true, m.p)
	# cleanup dead + far-away animals
	var keep: Array = []
	for m in mobs:
		if m.get("dead", false):
			continue
		if not D.MOBS[m.type].hostile and m.p.distance_to(ppos) > 1800.0:
			continue
		keep.append(m)
	mobs = keep

func _move_mob(m: Dictionary, mv: Vector2, r: float) -> bool:
	var p: Vector2 = m.p
	var blocked := false
	var nx := p + Vector2(mv.x, 0)
	if not world.blocked_at(nx, r): p = nx
	else: blocked = true
	var ny := p + Vector2(0, mv.y)
	if not world.blocked_at(ny, r): p = ny
	else: blocked = true
	m.p = p
	return blocked

func _thornback_ai(m: Dictionary, delta: float, to: Vector2, dist: float) -> void:
	var info: Dictionary = D.MOBS.thornback
	match m.state:
		"idle", "walk":
			m.state = "walk"
			m.v = m.v.lerp(to.normalized() * info.spd, minf(1.0, delta * 3.0))
			_move_mob(m, m.v * delta, 14.0)
			if absf(to.x) > 4.0: m.face = sign(to.x)
			if m.cd <= 0.0 and dist < 420.0:
				m.state = "windup"
				m.t = 0.8
				sfx.play("roar", 1.2, -4.0)
		"windup":
			m.t -= delta
			if absf(to.x) > 4.0: m.face = sign(to.x)
			if m.t <= 0.0:
				m.state = "charge"
				m.t = 0.95
				m.v = to.normalized() * 360.0
		"charge":
			m.t -= delta
			if rng.randf() < delta * 30.0:
				spark(m.p + Vector2(randf_range(-20, 20), 0), Color("c8b48a"), -m.v * 0.2, 0.5, 4.0)
			var bc: Vector2i = world.building_at(m.p + m.v.normalized() * 30.0, 6.0)
			if bc.x >= 0:
				_hurt_build(bc, 90.0)
			var blocked := _move_mob(m, m.v * delta, 14.0)
			if blocked:
				m.state = "stun"
				m.t = 1.6
				shake_amt = 9.0
				sfx.play("mine", 0.5)
				show_toast("Thornback is stunned! Strike now for double damage!")
			elif m.t <= 0.0:
				m.state = "walk"
				m.cd = 2.6
		"stun":
			m.t -= delta
			if m.t <= 0.0:
				m.state = "walk"
				m.cd = 2.2
	if dist < info.r + 16.0 and m.state != "stun":
		damage_player(info.dmg * (1.3 if m.state == "charge" else 0.7), true, m.p)

func _wyrm_ai(m: Dictionary, delta: float, to: Vector2, dist: float) -> void:
	var info: Dictionary = D.MOBS.wyrm
	var home: Vector2 = m.home
	if m.state == "sleep":
		if dist < T * 7.0:
			_wake_wyrm(m)
		return
	# slither around the crater, keeping between home and the player
	m.t += delta
	var enraged: bool = m.hp < m.maxhp * 0.5
	var orbit := home + Vector2.from_angle(m.t * (0.8 if not enraged else 1.3)) * T * 3.0
	var target := orbit.lerp(ppos, 0.25)
	if target.distance_to(home) > T * 8.0:
		target = home + (target - home).normalized() * T * 8.0
	m.v = m.v.lerp((target - m.p).limit_length(info.spd * (1.6 if enraged else 1.0)), minf(1.0, delta * 2.5))
	m.p += m.v * delta
	m.face = sign(to.x) if absf(to.x) > 2.0 else m.face
	var segs: Array = m.segs
	var prev: Vector2 = m.p
	for i in segs.size():
		var s: Vector2 = segs[i]
		var d := s - prev
		if d.length() > 15.0:
			s = prev + d.normalized() * 15.0
		segs[i] = s
		prev = s
	if m.cd <= 0.0:
		m.phase += 1
		m.cd = 2.4 if not enraged else 1.6
		var base_a := to.angle()
		if m.phase % 4 == 0:
			for i in 3:
				var a := rng.randf() * TAU
				var mm := _make_mob("ashling", m.p + Vector2.from_angle(a) * 50.0)
				mobs.append(mm)
			show_toast("The Wyrm calls its ashlings!")
		elif enraged and m.phase % 3 == 0:
			for i in 14:
				var a2 := TAU * i / 14.0
				projs.append({"p": m.p + Vector2(0, -14), "v": Vector2.from_angle(a2) * 220.0, "dmg": 12.0, "kind": "spit", "enemy": true, "life": 2.2})
			shake_amt = 8.0
		else:
			for i in 5:
				var a3 := base_a + (i - 2) * 0.22
				projs.append({"p": m.p + Vector2(0, -14), "v": Vector2.from_angle(a3) * 260.0, "dmg": 11.0, "kind": "spit", "enemy": true, "life": 2.2})
		sfx.play("fire", 0.6)
	if dist < info.r + 14.0:
		damage_player(info.dmg, true, m.p)
	for s2 in segs.slice(0, 6):
		if (s2 as Vector2).distance_to(ppos) < 22.0:
			damage_player(info.dmg * 0.5, true, s2)
			break

func _hurt_build(c: Vector2i, dmg: float) -> void:
	if not world.builds.has(c):
		return
	var b: Dictionary = world.builds[c]
	b.hp -= dmg
	b.hit = 0.15
	sfx.play("chop", 0.7, -4.0)
	burst(WorldScript.tile_center(c), Color("b07a45"), 5, 90.0)
	if b.hp <= 0.0:
		world.builds.erase(c)
		burst(WorldScript.tile_center(c), Color("8a5a2b"), 16, 160.0)
		show_toast("Your %s was destroyed!" % D.ITEMS[b.id].name)
		if b.id == "beacon":
			beacon_t = -1.0
			beacon_tile = Vector2i(-1, -1)

func _update_builds(delta: float) -> void:
	for c in world.builds:
		var b: Dictionary = world.builds[c]
		if b.get("hit", 0.0) > 0.0:
			b.hit = b.hit - delta
		if b.id == "farm" and b.t > 0.0 and b.t < 1.0:
			b.t = minf(1.0, b.t + delta / 60.0)
	if beacon_t >= 0.0:
		beacon_t += delta
		if beacon_t >= 60.0:
			win()

func _update_spawns(delta: float) -> void:
	var hostile := 0
	var animals := 0
	for m in mobs:
		if D.MOBS[m.type].hostile and not D.MOBS[m.type].get("boss", false):
			hostile += 1
		elif not D.MOBS[m.type].hostile:
			animals += 1
	if is_night() or beacon_t >= 0.0:
		raid_t -= delta
		var cap := mini(26, 5 + day * 2 + (8 if beacon_t >= 0.0 else 0))
		if raid_t <= 0.0 and hostile < cap:
			raid_t = maxf(1.4, 5.5 - day * 0.45) * (0.5 if beacon_t >= 0.0 else 1.0)
			var group := 1 + rng.randi() % (1 + mini(day, 4))
			for i in group:
				var type := "brute" if day >= 2 and rng.randf() < 0.18 + day * 0.03 else "ashling"
				_spawn_near_player(type, 660.0)
	else:
		animal_t -= delta
		if animal_t <= 0.0 and animals < 9:
			animal_t = 3.0
			_spawn_near_player("tusker" if rng.randf() < 0.65 else "crab", 700.0)

func _update_projs(delta: float) -> void:
	var keep: Array = []
	for p in projs:
		p.life -= delta
		p.p += p.v * delta
		var dead: bool = p.life <= 0.0
		if p.kind == "fire" and rng.randf() < 0.6:
			spark(p.p, Color(1, 0.55, 0.15), -p.v * 0.1, 0.35, 3.5)
		if p.enemy:
			if p.p.distance_to(ppos + Vector2(0, -12)) < 16.0:
				damage_player(p.dmg, true, p.p)
				dead = true
		else:
			for m in mobs:
				if m.get("dead", false):
					continue
				if p.p.distance_to(m.p + Vector2(0, -12)) < D.MOBS[m.type].r + 6.0:
					hurt_mob(m, p.dmg, p.v.normalized())
					if p.kind == "fire":
						burst(p.p, Color(1, 0.5, 0.15), 12, 150.0)
					dead = true
					break
			if not dead and world.res.has(WorldScript.to_tile(p.p + Vector2(0, 12))):
				var rt: int = world.res[WorldScript.to_tile(p.p + Vector2(0, 12))][0]
				if rt == D.R_ROCK or rt == D.R_ORE:
					dead = true
		if not dead:
			keep.append(p)
		elif p.kind != "arrow":
			burst(p.p, Color(1, 0.5, 0.15), 6, 90.0)
	projs = keep

func _update_drops(delta: float) -> void:
	var keep: Array = []
	for d in drops:
		d.age += delta
		var to: Vector2 = ppos - d.p
		if d.age > 0.45 and to.length() < 110.0:
			d.v = d.v.lerp(to.normalized() * 420.0, minf(1.0, delta * 8.0))
		else:
			d.v = d.v.lerp(Vector2.ZERO, minf(1.0, delta * 4.0))
		d.p += d.v * delta
		if d.age > 0.45 and to.length() < 14.0:
			add_item(d.id, d.n)
			sfx.play("pickup", 1.0 + randf() * 0.2)
			continue
		keep.append(d)
	drops = keep

# ================================================================ fx
func spark(p: Vector2, col: Color, v: Vector2, life: float, size: float) -> void:
	if parts.size() > 420:
		return
	parts.append({"p": p, "v": v + Vector2(randf_range(-15, 15), randf_range(-15, 15)), "life": life, "max": life, "col": col, "size": size, "gv": 0.0})

func burst(p: Vector2, col: Color, n: int, spd: float) -> void:
	for i in n:
		if parts.size() > 420:
			return
		var a := randf() * TAU
		var s := randf_range(0.3, 1.0) * spd
		var l := randf_range(0.3, 0.7)
		parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * s + Vector2(0, -40), "life": l, "max": l, "col": col, "size": randf_range(2.0, 4.0), "gv": 260.0})

func _update_fx(delta: float) -> void:
	var keep: Array = []
	for p in parts:
		p.life -= delta
		if p.life <= 0.0:
			continue
		p.v.y += p.gv * delta
		p.v *= 1.0 - delta * 2.0
		p.p += p.v * delta
		keep.append(p)
	parts = keep
	var fk: Array = []
	for f in floats:
		f.life -= delta
		f.p.y -= delta * 30.0
		if f.life > 0.0:
			fk.append(f)
	floats = fk

func show_toast(t: String) -> void:
	toast = t
	toast_t = 3.5

func _update_night() -> void:
	var dk := darkness() if state != "title" else 0.0
	var vs := get_viewport_rect().size
	night_mat.set_shader_parameter("dark", dk)
	night_mat.set_shader_parameter("size", vs)
	var lights: Array = []
	if dk > 0.01:
		var xf := get_viewport().get_canvas_transform()
		lights.append(Vector4((xf * (ppos + Vector2(0, -14))).x, (xf * (ppos + Vector2(0, -14))).y, 150.0, 0.75))
		for c in world.builds:
			var id: String = world.builds[c].id
			if id in ["campfire", "furnace", "beacon"] and lights.size() < 22:
				var sp: Vector2 = xf * (WorldScript.tile_center(c) + Vector2(0, -6))
				if sp.x > -400 and sp.y > -400 and sp.x < vs.x + 400 and sp.y < vs.y + 400:
					var fl := 1.0 + sin(title_t * 9.0 + c.x) * 0.04
					var rad := 260.0 if id == "campfire" else (200.0 if id == "furnace" else (520.0 if world.builds[c].lit > 0.0 else 120.0))
					lights.append(Vector4(sp.x, sp.y, rad * fl, 1.0))
		for p in projs:
			if p.kind != "arrow" and lights.size() < 23:
				var sp2: Vector2 = xf * p.p
				lights.append(Vector4(sp2.x, sp2.y, 90.0, 0.8))
		if world.crater.x >= 0 and lights.size() < 24:
			var cs: Vector2 = xf * WorldScript.tile_center(world.crater)
			lights.append(Vector4(cs.x, cs.y, 300.0, 0.7))
	var n := lights.size()
	while lights.size() < 24:
		lights.append(Vector4.ZERO)
	night_mat.set_shader_parameter("count", n)
	night_mat.set_shader_parameter("lights", lights)

# ================================================================ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			mouse_active = true
			touch_mode = false
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		touch_mode = false
		mouse_active = true
		if state == "play":
			if event.button_index == MOUSE_BUTTON_LEFT:
				attack_held = event.pressed
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				interact()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				cycle_sel(-1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				cycle_sel(1)
	if event.is_action_pressed("pause"):
		if state == "play":
			pause()
		elif state == "paused":
			resume()
		elif state in ["craft", "chest"]:
			close_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("sound"):
		toggle_sound()
	if event.is_action_pressed("craft"):
		if state == "play":
			open_craft()
		elif state == "craft":
			close_menu()
		get_viewport().set_input_as_handled()
		return
	if state != "play":
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("eat"):
		eat()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			select_slot(k - KEY_1)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_mode = true
		mouse_active = false
		if state == "play" and hud.handle_touch(event):
			get_viewport().set_input_as_handled()

func pause() -> void:
	state = "paused"
	attack_held = false
	ui.show_pause()

func resume() -> void:
	state = "play"
	ui.hide_all()

func open_craft() -> void:
	state = "craft"
	attack_held = false
	joy_vec = Vector2.ZERO
	ui.show_craft()
	sfx.play("ui")

func close_menu() -> void:
	state = "play"
	ui.hide_all()
	sfx.play("ui")

func toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	show_toast("Sound " + ("on" if sfx.enabled else "off"))

func quit_to_title() -> void:
	save_game()
	state = "title"
	_clear_entities()
	ui.show_title()

## Goal hint shown on the HUD: guides the player through the progression.
func objective() -> String:
	if beacon_t >= 0.0:
		return "Survive! Rescue arrives in %d s" % int(maxf(0.0, 60.0 - beacon_t))
	if count("beacon") > 0:
		return "Place the Signal Beacon and light it (E)"
	if beacon_tile.x >= 0 and world.builds.has(beacon_tile):
		return "Light the Signal Beacon (E)"
	if count("ember_heart") > 0:
		return "Build the Signal Beacon at a furnace"
	if boss2_dead:
		return "Pick up the Ember Heart"
	if count("axe_stone") == 0 and count("sword_iron") == 0:
		return "Craft a Stone Axe (C)"
	if not _has_build("workbench") and count("workbench") == 0:
		return "Craft and place a Workbench"
	if not _has_build("campfire") and count("campfire") == 0:
		return "Build a Campfire before night"
	if count("pick_stone") == 0:
		return "Craft a Stone Pickaxe"
	if not _has_build("furnace") and count("furnace") == 0:
		return "Build a Furnace at the workbench"
	if count("sword_iron") == 0 and count("fire_staff") == 0:
		return "Mine iron ore and forge an Iron Sword"
	if not boss1_dead:
		return "Defeat the Thornback (arrives night 3)"
	if count("fire_staff") == 0:
		return "Forge a Fire Staff with the Ember Shard"
	return "Slay the Cinder Wyrm in the volcano crater"

func _has_build(id: String) -> bool:
	for c in world.builds:
		if world.builds[c].id == id:
			return true
	return false
