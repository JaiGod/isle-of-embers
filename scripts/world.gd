extends Node2D
## The island: procedural terrain, resource nodes, buildings, collision queries,
## and the y-sorted renderer that draws everything living on the island.

const D = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const T := D.TILE
const M := D.MAP
const PX := 4   # terrain texture pixels per tile

var g: Node = null          # game (set by game.gd)
var seed_val := 1
var tiles := PackedByteArray()
var res := {}               # Vector2i -> [type, hp]
var builds := {}            # Vector2i -> {"id", "hp", "t", "inv", "lit"}
var shake := {}             # Vector2i -> seconds of wobble left
var spawn_tile := Vector2i(64, 110)
var crater := Vector2i(64, 64)
var terrain_tex: ImageTexture
var terrain_sprite: Sprite2D
var time := 0.0

const COLS := {
	0: [Color("1b4f8a"), Color("17457a")],
	1: [Color("2f86b8"), Color("3592c4")],
	2: [Color("e6cf8f"), Color("dcc282")],
	3: [Color("5fa545"), Color("579a3f")],
	4: [Color("3f7f3a"), Color("3a7535")],
	5: [Color("7d7a80"), Color("716e75")],
	6: [Color("4a4247"), Color("413a3f")],
	7: [Color("6b2a1c"), Color("7a3220")],
}

func _ready() -> void:
	terrain_sprite = Sprite2D.new()
	terrain_sprite.centered = false
	terrain_sprite.scale = Vector2(T / PX, T / PX)
	terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_sprite.z_index = -10
	add_child(terrain_sprite)

static func h2(x: int, y: int, s: int) -> int:
	var h := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)

func idx(x: int, y: int) -> int:
	return y * M + x

func tile(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= M or c.y >= M:
		return D.T_DEEP
	return tiles[c.y * M + c.x]

func generate(sd: int) -> void:
	seed_val = sd
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var n1 := FastNoiseLite.new()
	n1.seed = sd
	n1.frequency = 0.045
	n1.fractal_octaves = 4
	var n2 := FastNoiseLite.new()
	n2.seed = sd + 7
	n2.frequency = 0.08
	var n3 := FastNoiseLite.new()
	n3.seed = sd + 13
	n3.frequency = 0.06
	tiles.resize(M * M)
	var half := M * 0.5
	for y in M:
		for x in M:
			var dx := (x - half) / half
			var dy := (y - half) / half
			var d := sqrt(dx * dx + dy * dy)
			var cd := Vector2(x - crater.x, y - crater.y).length()
			var v: float = max(0.0, 1.0 - cd / 20.0)
			var h := 1.0 - d * 1.18 + n1.get_noise_2d(x, y) * 0.42 + v * 0.5
			var t := D.T_DEEP
			if h < 0.06:
				t = D.T_DEEP
			elif h < 0.16:
				t = D.T_SHALLOW
			elif h < 0.25:
				t = D.T_SAND
			else:
				t = D.T_GRASS
				if n3.get_noise_2d(x, y) > 0.08:
					t = D.T_FOREST
				if n2.get_noise_2d(x, y) > 0.42 or v > 0.5:
					t = D.T_ROCK
				if cd < 9.5:
					t = D.T_ASH
				if cd < 4.6:
					t = D.T_EMBER
			tiles[idx(x, y)] = t
	# spawn: walk up from the south edge to the first sand tile, then a bit inland
	spawn_tile = Vector2i(int(half), M - 2)
	for y in range(M - 2, int(half), -1):
		if tiles[idx(int(half), y)] >= D.T_SAND:
			spawn_tile = Vector2i(int(half), y)
			# walk further inland to solid grass so we never start in a lagoon
			for yy in range(y, maxi(y - 14, 0), -1):
				var tt: int = tiles[idx(int(half), yy)]
				if tt == D.T_GRASS or tt == D.T_FOREST:
					spawn_tile = Vector2i(int(half), yy - 1)
					break
			break
	# resources
	res.clear()
	builds.clear()
	for y in M:
		for x in M:
			var t: int = tiles[idx(x, y)]
			var r := rng.randf()
			var cd := Vector2(x - crater.x, y - crater.y).length()
			var kind := 0
			match t:
				D.T_FOREST:
					if r < 0.32: kind = D.R_TREE
					elif r < 0.37: kind = D.R_BUSH
					elif r < 0.39: kind = D.R_ROCK
				D.T_GRASS:
					if r < 0.06: kind = D.R_TREE
					elif r < 0.10: kind = D.R_BUSH
					elif r < 0.13: kind = D.R_ROCK
				D.T_SAND:
					if r < 0.045: kind = D.R_PALM
					elif r < 0.055: kind = D.R_ROCK
				D.T_ROCK:
					if r < 0.18: kind = D.R_ROCK
					elif r < 0.18 + (0.05 + max(0.0, 0.1 - cd * 0.004)): kind = D.R_ORE
				D.T_ASH:
					if r < 0.06: kind = D.R_ORE
					elif r < 0.12: kind = D.R_ROCK
			if kind != 0:
				res[Vector2i(x, y)] = [kind, D.RES[kind].hp]
	for oy in range(-3, 4):
		for ox in range(-3, 4):
			res.erase(spawn_tile + Vector2i(ox, oy))
	# guarantee a few ore veins reachable outside the crater ring
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 4000:
		tries += 1
		var c := Vector2i(rng.randi_range(8, M - 8), rng.randi_range(8, M - 8))
		if tile(c) == D.T_ROCK and not res.has(c):
			res[c] = [D.R_ORE, D.RES[D.R_ORE].hp]
			placed += 1
	build_texture()

func build_texture() -> void:
	var w := M * PX
	var data := PackedByteArray()
	data.resize(w * w * 3)
	var i := 0
	for py in w:
		var ty := py / PX
		for px in w:
			var tx := px / PX
			var t: int = tiles[ty * M + tx]
			var hh := h2(px, py, seed_val)
			var c: Color = COLS[t][(hh >> 3) & 1]
			var sh := float((hh >> 5) & 15) / 15.0
			c = c.lightened(sh * 0.05) if sh > 0.5 else c.darkened((1.0 - sh) * 0.05)
			if t == D.T_SAND:
				# foam / wet sand next to water
				var lx := px % PX
				var ly := py % PX
				var near := false
				if lx == 0 and tile(Vector2i(tx - 1, ty)) <= D.T_SHALLOW: near = true
				if lx == PX - 1 and tile(Vector2i(tx + 1, ty)) <= D.T_SHALLOW: near = true
				if ly == 0 and tile(Vector2i(tx, ty - 1)) <= D.T_SHALLOW: near = true
				if ly == PX - 1 and tile(Vector2i(tx, ty + 1)) <= D.T_SHALLOW: near = true
				if near:
					c = Color("f6f1dc")
			elif t == D.T_SHALLOW:
				if tile(Vector2i(tx, ty + 1)) == D.T_SAND and py % PX == PX - 1:
					c = Color("8fd0e6")
			elif t == D.T_EMBER:
				if ((hh >> 7) & 7) == 0:
					c = Color("ff9a3c")
				elif ((hh >> 7) & 7) == 1:
					c = Color("d9542a")
			elif t == D.T_ASH and ((hh >> 9) & 31) == 0:
				c = Color("8a3a22")
			elif t == D.T_GRASS and ((hh >> 9) & 63) == 0:
				c = Color("f2e46a") if (hh & 1) == 0 else Color("e88ab4")
			data[i] = int(c.r8)
			data[i + 1] = int(c.g8)
			data[i + 2] = int(c.b8)
			i += 3
	var img := Image.create_from_data(w, w, false, Image.FORMAT_RGB8, data)
	terrain_tex = ImageTexture.create_from_image(img)
	terrain_sprite.texture = terrain_tex

# ---------------------------------------------------------------- queries
func walkable_tile(c: Vector2i) -> bool:
	var t := tile(c)
	if t == D.T_DEEP:
		return false
	if res.has(c):
		return false
	if builds.has(c) and D.ITEMS[builds[c].id].solid:
		return false
	return true

func blocked_at(p: Vector2, r: float) -> bool:
	for o in [Vector2(-r, -r * 0.5), Vector2(r, -r * 0.5), Vector2(-r, r * 0.5), Vector2(r, r * 0.5)]:
		var c := Vector2i(floori((p.x + o.x) / T), floori((p.y + o.y) / T))
		if not walkable_tile(c):
			return true
	return false

## First solid building touched by a circle, or Vector2i(-1,-1).
func building_at(p: Vector2, r: float) -> Vector2i:
	for o in [Vector2(-r, 0), Vector2(r, 0), Vector2(0, -r * 0.5), Vector2(0, r * 0.5)]:
		var c := Vector2i(floori((p.x + o.x) / T), floori((p.y + o.y) / T))
		if builds.has(c) and D.ITEMS[builds[c].id].solid:
			return c
	return Vector2i(-1, -1)

static func to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))

static func tile_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T * 0.5, c.y * T + T * 0.5)

func near_water(p: Vector2, dist: float) -> bool:
	var c := to_tile(p)
	var r := int(ceil(dist / T))
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var cc := c + Vector2i(x, y)
			if tile(cc) <= D.T_SHALLOW and tile_center(cc).distance_to(p) < dist + T * 0.5:
				return true
	return false

func near_build(p: Vector2, id: String, dist: float) -> Vector2i:
	var c := to_tile(p)
	var r := int(ceil(dist / T))
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var cc := c + Vector2i(x, y)
			if builds.has(cc) and (id == "" or builds[cc].id == id):
				var d := tile_center(cc).distance_to(p)
				if d <= dist and d < bd:
					bd = d
					best = cc
	return best

func can_place(c: Vector2i, player_p: Vector2) -> bool:
	var t := tile(c)
	if t <= D.T_SHALLOW or t == D.T_EMBER:
		return false
	if res.has(c) or builds.has(c):
		return false
	var r := Rect2(Vector2(c.x * T, c.y * T), Vector2(T, T)).grow(6)
	if r.has_point(player_p):
		return false
	return true

func regrow(rng: RandomNumberGenerator, around: Vector2, count: int) -> void:
	var n := 0
	var tries := 0
	while n < count and tries < count * 30:
		tries += 1
		var c := Vector2i(rng.randi_range(2, M - 3), rng.randi_range(2, M - 3))
		if res.has(c) or builds.has(c) or tile_center(c).distance_to(around) < 360:
			continue
		var t := tile(c)
		var kind := 0
		if t == D.T_FOREST: kind = D.R_TREE if rng.randf() < 0.8 else D.R_BUSH
		elif t == D.T_GRASS: kind = [D.R_TREE, D.R_BUSH, D.R_ROCK][rng.randi() % 3]
		elif t == D.T_SAND: kind = D.R_PALM
		elif t == D.T_ROCK: kind = D.R_ROCK if rng.randf() < 0.7 else D.R_ORE
		if kind != 0:
			res[c] = [kind, D.RES[kind].hp]
			n += 1

# ---------------------------------------------------------------- drawing
func _process(delta: float) -> void:
	time += delta
	for k in shake.keys():
		shake[k] -= delta
		if shake[k] <= 0.0:
			shake.erase(k)
	queue_redraw()

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	if g == null or tiles.is_empty():
		return
	var cam: Camera2D = g.cam
	var vs: Vector2 = get_viewport_rect().size / cam.zoom
	var tl: Vector2 = cam.get_screen_center_position() - vs * 0.5
	var x0 := maxi(0, floori(tl.x / T) - 2)
	var y0 := maxi(0, floori(tl.y / T) - 2)
	var x1 := mini(M - 1, ceili((tl.x + vs.x) / T) + 2)
	var y1 := mini(M - 1, ceili((tl.y + vs.y) / T) + 3)
	var items: Array = []
	# ground decoration + water shimmer (drawn immediately, under everything)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var t: int = tiles[y * M + x]
			var hh := h2(x, y, seed_val + 3)
			var base := Vector2(x * T, y * T)
			if t <= D.T_SHALLOW:
				if hh % 6 == 0:
					var ph := time * 1.6 + float(hh % 100)
					var a := 0.25 + 0.25 * sin(ph)
					var o := Vector2(fmod(hh * 0.37, 20.0) + sin(ph * 0.5) * 3.0, fmod(hh * 0.11, 26.0))
					draw_line(base + o, base + o + Vector2(8, 0), Color(1, 1, 1, a), 2.0)
			elif t == D.T_GRASS or t == D.T_FOREST:
				if hh % 5 == 0:
					var gp := base + Vector2(6 + hh % 18, 10 + (hh >> 4) % 16)
					var gc := Color("7cc35a") if t == D.T_GRASS else Color("5a9a48")
					draw_line(gp, gp + Vector2(-2, -5), gc, 1.5)
					draw_line(gp, gp + Vector2(1, -6), gc, 1.5)
					draw_line(gp, gp + Vector2(3, -4), gc, 1.5)
			elif t == D.T_EMBER:
				if hh % 4 == 0:
					var gl := 0.4 + 0.4 * sin(time * 3.0 + hh)
					draw_circle(base + Vector2(8 + hh % 16, 8 + (hh >> 3) % 16), 3.0, Color(1.0, 0.6, 0.2, gl))
			var c := Vector2i(x, y)
			if res.has(c):
				items.append([y * T + T - 4.0, 0, c])
			if builds.has(c):
				items.append([y * T + T - 2.0, 1, c])
	# farm plots are flat: draw them first
	for it in items:
		if it[1] == 1 and builds[it[2]].id == "farm":
			var b: Dictionary = builds[it[2]]
			Art.building(self, "farm", Vector2(it[2].x * T + T * 0.5, it[2].y * T + T), T, 1.0, time, b.t)
	for m in g.mobs:
		items.append([m.p.y + 2.0, 2, m])
	if g.state != "title":
		items.append([g.ppos.y + 2.0, 3, null])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match it[1]:
			0: _draw_res(it[2])
			1: _draw_build(it[2])
			2: _draw_mob(it[2])
			3: _draw_player()
	# ghost preview for building placement
	if g.ghost_tile.x >= 0:
		var gid: String = g.sel_item()
		var ok: bool = can_place(g.ghost_tile, g.ppos)
		var gc := Vector2(g.ghost_tile.x * T + T * 0.5, g.ghost_tile.y * T + T)
		draw_rect(Rect2(Vector2(g.ghost_tile.x * T, g.ghost_tile.y * T), Vector2(T, T)), Color(0.4, 1, 0.5, 0.25) if ok else Color(1, 0.3, 0.3, 0.3))
		Art.building(self, gid, gc, T, 0.55, time)
	# drops
	for d in g.drops:
		var bob := sin(time * 5.0 + d.p.x) * 2.0
		_ellipse(d.p + Vector2(0, 6), 6, 2.5, Color(0, 0, 0, 0.25))
		Art.icon(self, d.id, d.p + Vector2(0, -2 + bob), 16)
	# projectiles
	for pr in g.projs:
		match pr.kind:
			"arrow":
				var dir: Vector2 = pr.v.normalized()
				draw_line(pr.p - dir * 12, pr.p, Color("e8d9b0"), 2.0)
				draw_circle(pr.p, 2.0, Color("d0d4da"))
			"fire":
				draw_circle(pr.p, 8.0, Color(1, 0.45, 0.1, 0.5))
				draw_circle(pr.p, 5.0, Color(1, 0.7, 0.2))
				draw_circle(pr.p, 2.5, Color(1, 0.95, 0.7))
			"spit":
				draw_circle(pr.p, 9.0, Color(0.9, 0.2, 0.05, 0.45))
				draw_circle(pr.p, 5.5, Color(1, 0.4, 0.1))
				draw_circle(pr.p, 2.5, Color(1, 0.85, 0.4))
	# particles
	for p in g.parts:
		var k: float = p.life / p.max
		var col: Color = p.col
		col.a *= clamp(k * 1.5, 0.0, 1.0)
		draw_circle(p.p, p.size * (0.4 + 0.6 * k), col)
	# floating text
	for f in g.floats:
		var k2: float = clamp(f.life / 1.0, 0.0, 1.0)
		var fc: Color = f.col
		fc.a = k2
		var font := ThemeDB.fallback_font
		draw_string_outline(font, f.p + Vector2(-30, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 16, 4, Color(0, 0, 0, k2 * 0.8))
		draw_string(font, f.p + Vector2(-30, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 16, fc)

func _draw_res(c: Vector2i) -> void:
	var r: Array = res[c]
	var hh := h2(c.x, c.y, seed_val + 11)
	var b := Vector2(c.x * T + T * 0.5, c.y * T + T - 4)
	var sx := 0.0
	if shake.has(c):
		sx = sin(time * 60.0) * 3.0 * shake[c] * 5.0
	var sz := 0.85 + float(hh % 30) / 100.0
	match r[0]:
		D.R_TREE:
			_ellipse(b + Vector2(0, 2), 15 * sz, 5, Color(0, 0, 0, 0.28))
			draw_rect(Rect2(b + Vector2(-4, -18), Vector2(8, 18)), Color("6b4424"))
			draw_rect(Rect2(b + Vector2(-4, -18), Vector2(3, 18)), Color("7d5230"))
			var cc := b + Vector2(sx, -30 * sz)
			draw_circle(cc + Vector2(0, 6), 17 * sz, Color("2e6b34"))
			draw_circle(cc + Vector2(-7, 0) * sz, 12 * sz, Color("3d8a3f"))
			draw_circle(cc + Vector2(7, -3) * sz, 11 * sz, Color("3d8a3f"))
			draw_circle(cc + Vector2(-2, -10) * sz, 10 * sz, Color("4ea24a"))
			draw_circle(cc + Vector2(-5, -12) * sz, 4 * sz, Color("7cc35a"))
		D.R_PALM:
			_ellipse(b + Vector2(0, 2), 12, 4, Color(0, 0, 0, 0.25))
			var top := b + Vector2(8 + sx, -40)
			draw_polyline(PackedVector2Array([b, b + Vector2(3, -14), b + Vector2(6, -28), top]), Color("9a6b3a"), 5.0)
			for i in 5:
				var ang := -PI + i * PI / 4.0 + sin(time * 1.5 + c.x) * 0.06
				var e := top + Vector2(cos(ang), sin(ang) * 0.6 + 0.35) * 22
				draw_line(top, e, Color("3f9a40"), 4.0)
				draw_line(top, (top + e) * 0.5 + Vector2(0, 3), Color("5cb84f"), 3.0)
			draw_circle(top + Vector2(-2, 4), 3, Color("7a4d22"))
			draw_circle(top + Vector2(3, 5), 3, Color("7a4d22"))
		D.R_ROCK:
			_ellipse(b + Vector2(0, 1), 14 * sz, 4, Color(0, 0, 0, 0.25))
			var o := Vector2(sx, 0)
			draw_colored_polygon(PackedVector2Array([b + o + Vector2(-14, 0) * sz, b + o + Vector2(-11, -14) * sz, b + o + Vector2(-2, -21) * sz, b + o + Vector2(10, -16) * sz, b + o + Vector2(14, 0) * sz]), Color("7f8590"))
			draw_colored_polygon(PackedVector2Array([b + o + Vector2(-9, -12) * sz, b + o + Vector2(-2, -18) * sz, b + o + Vector2(6, -14) * sz, b + o + Vector2(-2, -9) * sz]), Color("a9afb8"))
		D.R_ORE:
			_ellipse(b + Vector2(0, 1), 14, 4, Color(0, 0, 0, 0.25))
			var o2 := Vector2(sx, 0)
			draw_colored_polygon(PackedVector2Array([b + o2 + Vector2(-14, 0), b + o2 + Vector2(-12, -15), b + o2 + Vector2(0, -22), b + o2 + Vector2(12, -15), b + o2 + Vector2(14, 0)]), Color("5a5560"))
			for k in 4:
				var sp := b + o2 + Vector2(-8 + (hh >> k) % 16, -4 - ((hh >> (k + 3)) % 14))
				draw_circle(sp, 2.6, Color("e09a63"))
				draw_circle(sp + Vector2(-0.8, -0.8), 1.0, Color("ffd2a0"))
		D.R_BUSH:
			_ellipse(b + Vector2(0, 1), 12, 4, Color(0, 0, 0, 0.25))
			var bc := b + Vector2(sx, -8)
			draw_circle(bc + Vector2(-6, 0), 8, Color("3f8a3a"))
			draw_circle(bc + Vector2(6, 0), 8, Color("3f8a3a"))
			draw_circle(bc + Vector2(0, -5), 9, Color("4e9e45"))
			if r[1] >= D.RES[D.R_BUSH].hp:
				for k in 4:
					draw_circle(bc + Vector2(-7 + k * 4.5, -4 + (k % 2) * 6), 2.4, Color("d3415a"))

func _draw_build(c: Vector2i) -> void:
	var b: Dictionary = builds[c]
	if b.id == "farm":
		return
	var base := Vector2(c.x * T + T * 0.5, c.y * T + T)
	_ellipse(base + Vector2(0, -2), 16, 5, Color(0, 0, 0, 0.25))
	var dmg := 1.0 - float(b.hp) / float(D.ITEMS[b.id].hp)
	var lit := 1.0 if b.get("lit", 0.0) > 0.0 else 0.0
	Art.building(self, b.id, base, T, 1.0, time + c.x, dmg if b.id.begins_with("wall") else lit)
	if b.get("hit", 0.0) > 0.0:
		draw_rect(Rect2(base + Vector2(-16, -32), Vector2(32, 32)), Color(1, 0.3, 0.2, 0.25))
	if b.id == "campfire" and int(time * 8.0 + c.x) % 3 == 0 and g.parts.size() < 380:
		g.spark(base + Vector2(randf_range(-4, 4), -14), Color(1, 0.7, 0.3), Vector2(randf_range(-10, 10), -40), 0.8, 2.0)

func _draw_player() -> void:
	var p: Vector2 = g.ppos
	var f: Vector2 = g.aim
	var moving: bool = g.pvel.length() > 10.0
	var bob := sin(g.walk_t * 14.0) * 2.0 if moving else 0.0
	var flash: bool = g.hurt_t > 0.0 and int(g.hurt_t * 20.0) % 2 == 0
	_ellipse(p + Vector2(0, 4), 12, 4, Color(0, 0, 0, 0.3))
	var leg := sin(g.walk_t * 14.0) * 4.0 if moving else 0.0
	draw_line(p + Vector2(-4, -6), p + Vector2(-4 + leg, 3), Color("3b3a4a"), 4.0)
	draw_line(p + Vector2(4, -6), p + Vector2(4 - leg, 3), Color("3b3a4a"), 4.0)
	var body := p + Vector2(0, -14 + bob * 0.5)
	var shirt := Color("2f7fb0")
	if g.armor == "hide_armor": shirt = Color("a8744f")
	elif g.armor == "iron_armor": shirt = Color("b8bec7")
	if flash: shirt = Color(1, 0.4, 0.4)
	draw_rect(Rect2(body + Vector2(-7, -8), Vector2(14, 14)), shirt)
	draw_rect(Rect2(body + Vector2(-7, 2), Vector2(14, 3)), Color("6b4424"))
	var head := body + Vector2(0, -14)
	draw_circle(head, 7.5, Color("f0c39a") if not flash else Color(1, 0.6, 0.6))
	draw_arc(head + Vector2(0, -1), 7.5, PI, TAU, 10, Color("4a2e1a"), 4.0)
	if f.y > -0.3:
		var ex: float = f.x * 3.0
		draw_circle(head + Vector2(-2.5 + ex, 1), 1.3, Color("222222"))
		draw_circle(head + Vector2(2.5 + ex, 1), 1.3, Color("222222"))
	# held item swings around the aim direction
	var id: String = g.sel_item()
	var kind: String = D.ITEMS.get(id, {}).get("kind", "")
	var sw: float = g.swing_t
	var ang := f.angle()
	if sw > 0.0:
		ang += lerp(-1.3, 1.3, 1.0 - sw / 0.22)
	var hand := body + Vector2(cos(ang), sin(ang)) * 12.0
	if kind in ["tool", "weapon", "ranged"] and id != "hand":
		draw_set_transform(hand, ang + PI * 0.25, Vector2.ONE)
		Art.icon(self, id, Vector2.ZERO, 22)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(hand, 3.5, Color("f0c39a"))
	if sw > 0.0 and kind != "ranged":
		var reach: float = D.ITEMS.get(id, D.ITEMS.hand).get("reach", 44)
		draw_arc(body, reach * 0.75, f.angle() - 1.1, f.angle() + 1.1, 12, Color(1, 1, 1, sw * 2.0), 3.0)

func _draw_mob(m: Dictionary) -> void:
	var p: Vector2 = m.p
	var info: Dictionary = D.MOBS[m.type]
	var r: float = info.r
	var flash: bool = m.hit_t > 0.0
	var wob := sin(time * 10.0 + m.seed) * 1.5
	match m.type:
		"tusker":
			_ellipse(p + Vector2(0, 3), 14, 4, Color(0, 0, 0, 0.3))
			var bc := Color("8a5a3a") if not flash else Color.WHITE
			var dirx: float = sign(m.v.x) if absf(m.v.x) > 1.0 else m.face
			_ellipse(p + Vector2(0, -10 + wob * 0.3), 15, 10, bc)
			draw_circle(p + Vector2(dirx * 13, -12), 7, bc.lightened(0.1))
			draw_line(p + Vector2(dirx * 17, -10), p + Vector2(dirx * 21, -15), Color("f2eadc"), 2.0)
			draw_circle(p + Vector2(dirx * 15, -15), 1.4, Color.BLACK)
			for k in 4:
				draw_line(p + Vector2(-9 + k * 6, -3), p + Vector2(-9 + k * 6, 3), Color("5a3a22"), 3.0)
		"crab":
			_ellipse(p + Vector2(0, 3), 11, 3, Color(0, 0, 0, 0.3))
			var cc := Color("e0553a") if not flash else Color.WHITE
			_ellipse(p + Vector2(0, -6), 10, 6, cc)
			draw_circle(p + Vector2(-11, -10 + wob), 4, cc)
			draw_circle(p + Vector2(11, -10 - wob), 4, cc)
			draw_circle(p + Vector2(-3, -12), 1.6, Color.BLACK)
			draw_circle(p + Vector2(3, -12), 1.6, Color.BLACK)
		"ashling":
			_ellipse(p + Vector2(0, 3), 9, 3, Color(0, 0, 0, 0.3))
			var ac := Color("2a2230") if not flash else Color.WHITE
			var fl := sin(time * 16.0 + m.seed) * 2.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 0), p + Vector2(-6, -18 + fl), p + Vector2(0, -26 - fl), p + Vector2(6, -18 + fl), p + Vector2(9, 0)]), ac)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -16), p + Vector2(0, -24 - fl), p + Vector2(4, -16)]), Color(1, 0.45, 0.15, 0.8))
			draw_circle(p + Vector2(-3, -11), 2.0, Color("ffcf4a"))
			draw_circle(p + Vector2(3, -11), 2.0, Color("ffcf4a"))
		"brute":
			_ellipse(p + Vector2(0, 4), 18, 5, Color(0, 0, 0, 0.35))
			var brc := Color("3a3550") if not flash else Color.WHITE
			_ellipse(p + Vector2(0, -16 + wob * 0.4), 18, 16, brc)
			draw_circle(p + Vector2(-16, -12 + wob), 6, brc.darkened(0.2))
			draw_circle(p + Vector2(16, -12 - wob), 6, brc.darkened(0.2))
			draw_rect(Rect2(p + Vector2(-8, -24), Vector2(16, 4)), Color("201c30"))
			draw_circle(p + Vector2(-5, -22), 2.4, Color("9bf2ff"))
			draw_circle(p + Vector2(5, -22), 2.4, Color("9bf2ff"))
		"thornback":
			_ellipse(p + Vector2(0, 6), 34, 9, Color(0, 0, 0, 0.35))
			var tc := Color("5a3424")
			if m.state == "windup": tc = tc.lerp(Color("ff3a20"), 0.4 + 0.3 * sin(time * 30.0))
			if m.state == "stun": tc = tc.lerp(Color("aaaaaa"), 0.4)
			if flash: tc = Color.WHITE
			var dx: float = m.face
			var sh2 := Vector2(randf_range(-2, 2), 0) if m.state == "windup" else Vector2.ZERO
			var q := p + sh2
			_ellipse(q + Vector2(0, -20), 32, 20, tc)
			for k in 6:
				var sp := q + Vector2(-22 + k * 9, -34 - absf(sin(k * 1.3)) * 4)
				draw_colored_polygon(PackedVector2Array([sp + Vector2(-4, 4), sp + Vector2(0, -12), sp + Vector2(4, 4)]), Color("d9c6a0"))
			draw_circle(q + Vector2(dx * 28, -20), 13, tc.lightened(0.08))
			draw_line(q + Vector2(dx * 34, -16), q + Vector2(dx * 44, -28), Color("f2eadc"), 4.0)
			draw_line(q + Vector2(dx * 26, -14), q + Vector2(dx * 36, -26), Color("f2eadc"), 4.0)
			draw_circle(q + Vector2(dx * 31, -26), 2.6, Color("ffcf4a") if m.state != "stun" else Color("888888"))
			for k in 4:
				draw_line(q + Vector2(-20 + k * 13, -4), q + Vector2(-20 + k * 13, 5), Color("3a2016"), 6.0)
			if m.state == "stun":
				for k in 3:
					var sa := time * 5.0 + k * TAU / 3.0
					draw_circle(q + Vector2(dx * 28 + cos(sa) * 12, -40 + sin(sa) * 4), 2.5, Color("ffe08a"))
		"wyrm":
			var segs: Array = m.segs
			for k in range(segs.size() - 1, -1, -1):
				var sp2: Vector2 = segs[k]
				var rad := 20.0 - k * 1.1
				_ellipse(sp2 + Vector2(0, 8), rad, rad * 0.3, Color(0, 0, 0, 0.25))
				var wc := Color("3a1c1a").lerp(Color("7a2a18"), float(k % 2))
				if flash: wc = Color.WHITE
				draw_circle(sp2 + Vector2(0, -10), rad, wc)
				draw_circle(sp2 + Vector2(0, -10 - rad * 0.4), rad * 0.35, Color(1, 0.5, 0.15, 0.7))
			var hc := Color("4a201a") if not flash else Color.WHITE
			if m.state == "sleep": hc = hc.darkened(0.3)
			draw_circle(p + Vector2(0, -14), 26, hc)
			var tg: Vector2 = (g.ppos - p).normalized()
			draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -34), p + Vector2(-26, -58), p + Vector2(-8, -38)]), Color("d9c6a0"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(18, -34), p + Vector2(26, -58), p + Vector2(8, -38)]), Color("d9c6a0"))
			if m.state == "sleep":
				draw_line(p + Vector2(-12, -18), p + Vector2(-4, -18), Color("ff9a3c"), 2.0)
				draw_line(p + Vector2(4, -18), p + Vector2(12, -18), Color("ff9a3c"), 2.0)
				var font := ThemeDB.fallback_font
				draw_string(font, p + Vector2(20, -50 - fmod(time * 10.0, 20.0)), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.7))
			else:
				draw_circle(p + Vector2(-9, -18) + tg * 3.0, 4.5, Color("ffdf5a"))
				draw_circle(p + Vector2(9, -18) + tg * 3.0, 4.5, Color("ffdf5a"))
				draw_circle(p + Vector2(0, -6) + tg * 12.0, 7, Color(1, 0.45, 0.1, 0.8))
	# health bar for damaged mobs
	if m.hp < m.maxhp and not info.get("boss", false):
		var w := r * 2.0
		draw_rect(Rect2(p + Vector2(-w * 0.5, -r * 2.0 - 16), Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p + Vector2(-w * 0.5, -r * 2.0 - 16), Vector2(w * m.hp / m.maxhp, 4)), Color("e85a4a"))
