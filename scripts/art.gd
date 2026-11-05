extends RefCounted
## Code-drawn art: item icons and building sprites. Shared by the world renderer
## (buildings, drops) and the HUD (hotbar, crafting list).

const D = preload("res://scripts/data.gd")

static func icon(ci: CanvasItem, id: String, c: Vector2, s: float) -> void:
	var u := s / 16.0
	var col: Color = D.ITEMS.get(id, {}).get("col", Color.WHITE)
	match id:
		"wood":
			ci.draw_rect(Rect2(c + Vector2(-6, -3) * u, Vector2(12, 6) * u), Color("8a5a2b"))
			ci.draw_circle(c + Vector2(6, 0) * u, 3.2 * u, Color("d9a86a"))
			ci.draw_circle(c + Vector2(6, 0) * u, 1.4 * u, Color("8a5a2b"))
		"stone":
			ci.draw_colored_polygon(_pts(c, u, [-6, 3, -4, -4, 3, -6, 7, 0, 4, 5]), Color("8a9099"))
			ci.draw_colored_polygon(_pts(c, u, [-3, -2, 2, -4, 4, -1]), Color("c3c8cf"))
		"fiber":
			for i in 3:
				var x := (i - 1) * 3.0
				ci.draw_line(c + Vector2(x, 6) * u, c + Vector2(x * 1.6, -6) * u, Color("7fb648"), 1.6 * u)
			ci.draw_line(c + Vector2(-5, 1) * u, c + Vector2(5, 1) * u, Color("d8c07a"), 1.4 * u)
		"ore":
			ci.draw_colored_polygon(_pts(c, u, [-6, 3, -4, -4, 3, -6, 7, 0, 4, 5]), Color("6c6670"))
			ci.draw_circle(c + Vector2(-2, -1) * u, 1.6 * u, Color("e09a63"))
			ci.draw_circle(c + Vector2(3, 1) * u, 1.3 * u, Color("e09a63"))
		"iron":
			ci.draw_colored_polygon(_pts(c, u, [-7, 3, -4, -3, 4, -3, 7, 3]), Color("b8bec7"))
			ci.draw_colored_polygon(_pts(c, u, [-4, -3, 4, -3, 3, -1, -3, -1]), Color("eef1f5"))
		"hide":
			ci.draw_colored_polygon(_pts(c, u, [-6, -5, 6, -5, 7, 0, 5, 6, -5, 6, -7, 0]), Color("a8744f"))
			ci.draw_circle(c + Vector2(-2, -1) * u, 1.2 * u, Color("7c5034"))
			ci.draw_circle(c + Vector2(2, 2) * u, 1.0 * u, Color("7c5034"))
		"arrow":
			ci.draw_line(c + Vector2(-6, 6) * u, c + Vector2(6, -6) * u, Color("c9a26a"), 1.5 * u)
			ci.draw_colored_polygon(_pts(c, u, [7, -7, 3, -6, 6, -3]), Color("d0d4da"))
			ci.draw_line(c + Vector2(-6, 6) * u, c + Vector2(-6, 2) * u, Color("e8e8e8"), 1.4 * u)
		"ember_shard":
			ci.draw_colored_polygon(_pts(c, u, [0, -7, 4, 0, 0, 7, -4, 0]), Color("ff8a3d"))
			ci.draw_colored_polygon(_pts(c, u, [0, -4, 2, 0, 0, 4, -2, 0]), Color("ffe08a"))
		"ember_heart":
			ci.draw_circle(c + Vector2(-2.5, -1.5) * u, 3.6 * u, Color("ff4f2e"))
			ci.draw_circle(c + Vector2(2.5, -1.5) * u, 3.6 * u, Color("ff4f2e"))
			ci.draw_colored_polygon(_pts(c, u, [-6, 0, 6, 0, 0, 7]), Color("ff4f2e"))
			ci.draw_circle(c + Vector2(-2, -2) * u, 1.3 * u, Color("ffd27a"))
		"berries":
			for p in [Vector2(-3, 1), Vector2(3, 1), Vector2(0, -3), Vector2(0, 4)]:
				ci.draw_circle(c + p * u, 2.8 * u, Color("c8304d"))
				ci.draw_circle(c + (p + Vector2(-0.8, -0.8)) * u, 0.8 * u, Color("ff9aa8"))
			ci.draw_line(c + Vector2(0, -6) * u, c + Vector2(2, -8) * u, Color("4f8a2e"), 1.2 * u)
		"meat_raw", "meat_cooked":
			var mc := Color("e0707a") if id == "meat_raw" else Color("a65a2e")
			ci.draw_circle(c + Vector2(-1, -1) * u, 5.2 * u, mc)
			ci.draw_line(c + Vector2(3, 3) * u, c + Vector2(7, 7) * u, Color("f2eadc"), 2.2 * u)
			ci.draw_circle(c + Vector2(7, 7) * u, 1.6 * u, Color("f2eadc"))
			ci.draw_circle(c + Vector2(-2, -2) * u, 2.0 * u, mc.lightened(0.25))
		"hand":
			ci.draw_circle(c, 5 * u, Color("f0c39a"))
			ci.draw_rect(Rect2(c + Vector2(-5, -6) * u, Vector2(10, 4) * u), Color("f0c39a"))
			for i in 4:
				ci.draw_line(c + Vector2(-4 + i * 2.7, -6) * u, c + Vector2(-4 + i * 2.7, -3) * u, Color("c89a74"), 0.8 * u)
		"axe_stone", "pick_stone":
			ci.draw_line(c + Vector2(-5, 7) * u, c + Vector2(4, -5) * u, Color("8a5a2b"), 2.2 * u)
			if id == "axe_stone":
				ci.draw_colored_polygon(_pts(c, u, [1, -8, 8, -6, 7, 1, 2, -3]), Color("9aa0a8"))
			else:
				ci.draw_colored_polygon(_pts(c, u, [-4, -7, 3, -8, 9, -3, 4, -5]), Color("9aa0a8"))
		"spear":
			ci.draw_line(c + Vector2(-7, 7) * u, c + Vector2(4, -4) * u, Color("8a5a2b"), 1.8 * u)
			ci.draw_colored_polygon(_pts(c, u, [8, -8, 2, -5, 5, -2]), Color("c3c8cf"))
			ci.draw_line(c + Vector2(1, -1) * u, c + Vector2(3, -3) * u, Color("9ccf5b"), 2.0 * u)
		"sword_iron":
			ci.draw_line(c + Vector2(-4, 4) * u, c + Vector2(7, -7) * u, Color("e6eaef"), 2.6 * u)
			ci.draw_line(c + Vector2(-6, 1) * u, c + Vector2(-1, 6) * u, Color("c9a23a"), 2.0 * u)
			ci.draw_line(c + Vector2(-4, 4) * u, c + Vector2(-7, 7) * u, Color("6b3f22"), 2.2 * u)
		"bow":
			ci.draw_arc(c + Vector2(-3, 3) * u, 8 * u, -PI * 0.5, 0.0, 10, Color("a0682f"), 2.0 * u)
			ci.draw_line(c + Vector2(-3, -5) * u, c + Vector2(5, 3) * u, Color("eeeeee"), 0.8 * u)
		"fire_staff":
			ci.draw_line(c + Vector2(-6, 7) * u, c + Vector2(3, -3) * u, Color("5a3a22"), 2.0 * u)
			ci.draw_circle(c + Vector2(4, -4) * u, 3.4 * u, Color("ff6a2e"))
			ci.draw_circle(c + Vector2(4, -4) * u, 1.8 * u, Color("ffe08a"))
		"hide_armor", "iron_armor":
			var ac := Color("a8744f") if id == "hide_armor" else Color("b8bec7")
			ci.draw_colored_polygon(_pts(c, u, [-7, -5, -3, -7, 3, -7, 7, -5, 5, 0, 5, 7, -5, 7, -5, 0]), ac)
			ci.draw_line(c + Vector2(0, -6) * u, c + Vector2(0, 6) * u, ac.darkened(0.3), 1.0 * u)
		_:
			building(ci, id, c + Vector2(0, 3) * u, s * 0.8, 1.0, 0.0)

static func _pts(c: Vector2, u: float, a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size(), 2):
		out.append(c + Vector2(a[i], a[i + 1]) * u)
	return out

## Draws a building centred at the bottom-middle of its tile. s ~ tile size.
static func building(ci: CanvasItem, id: String, c: Vector2, s: float, alpha: float, t: float, extra: float = 0.0) -> void:
	var u := s / 32.0
	var a := alpha
	match id:
		"campfire":
			for i in 6:
				var ang := TAU * i / 6.0
				ci.draw_circle(c + Vector2(cos(ang) * 11, sin(ang) * 6 - 6) * u, 3.4 * u, Color(0.55, 0.56, 0.6, a))
			ci.draw_line(c + Vector2(-9, -3) * u, c + Vector2(9, -9) * u, Color(0.45, 0.28, 0.14, a), 4 * u)
			ci.draw_line(c + Vector2(-9, -9) * u, c + Vector2(9, -3) * u, Color(0.52, 0.32, 0.16, a), 4 * u)
			var fl := 1.0 + sin(t * 13.0) * 0.12 + sin(t * 7.3) * 0.08
			ci.draw_colored_polygon(_pts(c, u * fl, [-6, -6, 0, -22, 6, -6]), Color(1.0, 0.45, 0.12, 0.95 * a))
			ci.draw_colored_polygon(_pts(c, u * fl, [-3, -6, 0, -15, 3, -6]), Color(1.0, 0.86, 0.4, a))
		"workbench":
			ci.draw_rect(Rect2(c + Vector2(-14, -18) * u, Vector2(28, 7) * u), Color(0.62, 0.42, 0.22, a))
			ci.draw_rect(Rect2(c + Vector2(-12, -11) * u, Vector2(4, 11) * u), Color(0.45, 0.29, 0.14, a))
			ci.draw_rect(Rect2(c + Vector2(8, -11) * u, Vector2(4, 11) * u), Color(0.45, 0.29, 0.14, a))
			ci.draw_rect(Rect2(c + Vector2(-14, -18) * u, Vector2(28, 2) * u), Color(0.78, 0.58, 0.34, a))
			ci.draw_line(c + Vector2(-6, -22) * u, c + Vector2(2, -19) * u, Color(0.6, 0.62, 0.66, a), 2.5 * u)
			ci.draw_rect(Rect2(c + Vector2(4, -23) * u, Vector2(6, 5) * u), Color(0.6, 0.62, 0.66, a))
		"wall_wood":
			for i in 4:
				var x := -15 + i * 7.5
				ci.draw_rect(Rect2(c + Vector2(x, -30) * u, Vector2(7, 30) * u), Color(0.55, 0.36, 0.18, a).lightened(0.06 * (i % 2)))
				ci.draw_colored_polygon(_pts(c, u, [x, -30, x + 3.5, -35, x + 7, -30]), Color(0.62, 0.42, 0.22, a))
			ci.draw_rect(Rect2(c + Vector2(-16, -20) * u, Vector2(32, 3) * u), Color(0.38, 0.24, 0.12, a))
			_damage(ci, c, u, extra, a)
		"wall_stone":
			ci.draw_rect(Rect2(c + Vector2(-16, -32) * u, Vector2(32, 32) * u), Color(0.5, 0.52, 0.58, a))
			for r in 4:
				for k in 3:
					var off := 0.0 if r % 2 == 0 else 5.0
					ci.draw_rect(Rect2(c + Vector2(-15 + k * 10.5 + off * 0.5, -31 + r * 8) * u, Vector2(9.5, 7) * u), Color(0.62, 0.64, 0.7, a))
			_damage(ci, c, u, extra, a)
		"chest":
			ci.draw_rect(Rect2(c + Vector2(-12, -16) * u, Vector2(24, 15) * u), Color(0.6, 0.38, 0.18, a))
			ci.draw_rect(Rect2(c + Vector2(-12, -20) * u, Vector2(24, 6) * u), Color(0.7, 0.46, 0.22, a))
			ci.draw_rect(Rect2(c + Vector2(-12, -14) * u, Vector2(24, 2) * u), Color(0.85, 0.7, 0.3, a))
			ci.draw_rect(Rect2(c + Vector2(-2, -15) * u, Vector2(4, 5) * u), Color(0.95, 0.82, 0.35, a))
		"furnace":
			ci.draw_colored_polygon(_pts(c, u, [-14, 0, -12, -26, 12, -26, 14, 0]), Color(0.45, 0.43, 0.46, a))
			ci.draw_rect(Rect2(c + Vector2(-5, -36) * u, Vector2(10, 12) * u), Color(0.38, 0.36, 0.4, a))
			var g := 0.75 + sin(t * 6.0) * 0.15
			ci.draw_rect(Rect2(c + Vector2(-7, -14) * u, Vector2(14, 10) * u), Color(1.0, 0.45 * g + 0.2, 0.1, a))
			ci.draw_rect(Rect2(c + Vector2(-7, -14) * u, Vector2(14, 3) * u), Color(0.2, 0.18, 0.2, a))
		"farm":
			ci.draw_rect(Rect2(c + Vector2(-15, -30) * u, Vector2(30, 29) * u), Color(0.36, 0.23, 0.13, a))
			for r in 3:
				ci.draw_line(c + Vector2(-13, -25 + r * 9) * u, c + Vector2(13, -25 + r * 9) * u, Color(0.27, 0.17, 0.09, a), 2 * u)
			if extra > 0.0:
				var g2: float = clamp(extra, 0.0, 1.0)
				for r in 3:
					for k in 3:
						var p := c + Vector2(-9 + k * 9, -24 + r * 9) * u
						ci.draw_line(p, p + Vector2(0, -6 * g2) * u, Color(0.35, 0.7, 0.25, a), 2 * u)
						if g2 >= 1.0:
							ci.draw_circle(p + Vector2(0, -6) * u, 2.4 * u, Color(0.85, 0.2, 0.3, a))
		"beacon":
			ci.draw_colored_polygon(_pts(c, u, [-14, 0, -6, -50, 6, -50, 14, 0]), Color(0.42, 0.3, 0.2, a))
			ci.draw_line(c + Vector2(-10, -14) * u, c + Vector2(10, -14) * u, Color(0.3, 0.2, 0.12, a), 3 * u)
			ci.draw_line(c + Vector2(-8, -32) * u, c + Vector2(8, -32) * u, Color(0.3, 0.2, 0.12, a), 3 * u)
			ci.draw_rect(Rect2(c + Vector2(-10, -56) * u, Vector2(20, 7) * u), Color(0.75, 0.78, 0.82, a))
			if extra > 0.0:
				var fl2 := 1.0 + sin(t * 11.0) * 0.15
				ci.draw_colored_polygon(_pts(c + Vector2(0, -56) * u, u * fl2 * 1.6, [-7, 0, 0, -22, 7, 0]), Color(1.0, 0.5, 0.15, a))
				ci.draw_colored_polygon(_pts(c + Vector2(0, -56) * u, u * fl2, [-5, 0, 0, -18, 5, 0]), Color(1.0, 0.9, 0.5, a))
		_:
			ci.draw_rect(Rect2(c + Vector2(-10, -20) * u, Vector2(20, 20) * u), Color(1, 0, 1, a))

static func _damage(ci: CanvasItem, c: Vector2, u: float, dmg: float, a: float) -> void:
	if dmg > 0.35:
		ci.draw_line(c + Vector2(-8, -24) * u, c + Vector2(-2, -14) * u, Color(0.1, 0.06, 0.04, a), 1.5 * u)
	if dmg > 0.65:
		ci.draw_line(c + Vector2(6, -28) * u, c + Vector2(2, -8) * u, Color(0.1, 0.06, 0.04, a), 1.5 * u)
