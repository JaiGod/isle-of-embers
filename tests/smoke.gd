extends SceneTree
## Headless smoke test: boots the game, plays through survival, crafting,
## building, both bosses, save/load and the beacon win. Prints SMOKE OK.

var g
var fails := 0

func check(c: bool, msg: String) -> void:
	if c:
		print("  ok  ", msg)
	else:
		print("  FAIL ", msg)
		fails += 1

func step(n: int, dt: float = 1.0 / 60.0) -> void:
	for i in n:
		g._process(dt)

func _initialize() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	g = scene
	await process_frame
	await process_frame
	if g.get_script() == null or g.get("state") == null:
		print("SMOKE FAILED (game script did not load)")
		quit(1)
		return
	check(g.state == "title", "boots to title")
	g.new_game()
	check(g.state == "play", "new game starts")
	check(g.world.tiles.size() == 128 * 128, "island generated")
	check(g.world.res.size() > 500, "resources placed: %d" % g.world.res.size())
	check(g.world.walkable_tile(g.world.to_tile(g.ppos)), "spawn is walkable")
	var w0 = g.ppos
	Input.action_press("up")
	step(30)
	Input.action_release("up")
	step(10)
	check(g.ppos != w0, "player moves")
	# gather: teleport next to a tree and swing
	var tree := Vector2i(-1, -1)
	for c in g.world.res:
		if g.world.res[c][0] == 1:
			tree = c
			break
	g.ppos = g.world.tile_center(tree) + Vector2(0, 30)
	g.aim = Vector2.UP
	g.mouse_active = false
	for i in 20:
		g.atk_cd = 0
		g._swing("hand", g.D.ITEMS.hand)
	check(not g.world.res.has(tree), "tree chopped down")
	step(90)
	check(g.count("wood") >= 3, "wood collected via drops: %d" % g.count("wood"))
	# crafting
	g.add_item("wood", 60, false); g.add_item("stone", 40, false); g.add_item("fiber", 40, false)
	g.add_item("hide", 10, false); g.add_item("ore", 60, false); g.add_item("wood", 40, false); g.add_item("stone", 30, false); g.add_item("berries", 5, false)
	var R = g.D.RECIPES
	check(g.craft(R[0]), "craft stone axe")
	check(g.usable().has("axe_stone"), "axe added to hotbar")
	check(g.craft(R[3]), "craft workbench")
	check(not g.can_craft(R[5]), "spear needs a workbench")
	g.sel_id = "workbench"
	g.ppos = g.world.tile_center(g.world.spawn_tile)
	g.aim = Vector2.RIGHT
	g._update_player(0.016)
	var gt = g.ghost_tile
	check(gt.x >= 0, "ghost tile shown")
	g.world.res.erase(gt)
	g.atk_cd = 0
	g.use_item()
	check(g.world.builds.has(gt) and g.world.builds[gt].id == "workbench", "workbench placed")
	check(g.can_craft(R[5]), "spear craftable near workbench")
	for i in [5, 6, 7, 8, 9, 10, 11, 12, 1]:
		check(g.craft(R[i]), "craft " + R[i].id)
	check(g.armor == "hide_armor", "armor auto-equipped")
	# place furnace one tile below workbench
	var fc = gt + Vector2i(0, 1)
	g.world.res.erase(fc)
	g.world.builds[fc] = {"id": "furnace", "hp": 140.0, "t": 0.0, "inv": {}, "lit": 0.0}
	g.take("furnace", 1)
	for i in 8:
		g.craft(R[13])
	check(g.count("iron") >= 8, "smelted iron: %d" % g.count("iron"))
	check(g.craft(R[14]), "craft iron sword")
	check(not g.craft(R[17]), "fire staff locked without shard")
	# bow + arrows
	g.sel_id = "bow"
	var before = g.count("arrow")
	g.atk_cd = 0
	g.use_item()
	check(g.count("arrow") == before - 1 and g.projs.size() > 0, "bow fires an arrow")
	# night + raid
	g.tod = 0.65
	step(60 * 4, 0.05)
	check(g.is_night(), "night falls")
	step(60 * 6, 0.05)
	var hostile := 0
	for m in g.mobs:
		if g.D.MOBS[m.type].hostile and m.type != "wyrm": hostile += 1
	check(hostile > 0, "night raid spawned %d" % hostile)
	# boss 1 on night 3
	g.day = 3
	g.tod = 0.5
	g.boss1_spawned = false
	g.hp = 100
	g.tod = 0.655
	step(60, 0.05)
	var tb = null
	for m in g.mobs:
		if m.type == "thornback": tb = m
	check(tb != null, "thornback spawned on night 3")
	if tb:
		step(120, 0.05)
		g.hp = 100
		tb.state = "stun"
		tb.t = 2.0
		g.hurt_mob(tb, 500, Vector2.RIGHT)
	check(g.boss1_dead, "thornback defeated")
	# collect its drops
	for d in g.drops:
		d.p = g.ppos
		d.age = 1.0
	g._update_drops(0.016)
	check(g.count("ember_shard") == 1, "ember shard collected")
	g.ppos = g.world.tile_center(fc) + Vector2(32, 0)
	check(g.craft(R[17]), "craft fire staff")
	g.sel_id = "fire_staff"
	g.atk_cd = 0
	g.use_item()
	check(g.projs.size() > 0, "fire staff shoots")
	# save / load
	check(g.save_game(), "save game")
	var inv_wood = g.count("wood")
	var nb = g.world.builds.size()
	g.state = "title"
	check(g.load_game(), "load game")
	check(g.count("wood") == inv_wood and g.world.builds.size() == nb, "save round-trip (wood %d, builds %d)" % [inv_wood, nb])
	check(g.boss1_dead, "boss flag restored")
	# wyrm
	var wy = null
	for m in g.mobs:
		if m.type == "wyrm": wy = m
	check(wy != null and wy.state == "sleep", "wyrm sleeps in crater")
	g.ppos = g.world.tile_center(g.world.crater) + Vector2(0, 150)
	g.hp = 100
	step(40, 0.05)
	check(wy.state == "fight", "wyrm wakes")
	g.hp = 100
	step(80, 0.05)
	g.hp = 100
	g.hurt_mob(wy, 9999, Vector2.UP)
	check(g.boss2_dead, "wyrm slain")
	for d in g.drops:
		d.p = g.ppos
		d.age = 1.0
	g._update_drops(0.016)
	check(g.count("ember_heart") == 1, "ember heart collected")
	g.ppos = g.world.tile_center(fc) + Vector2(32, 0)
	g.add_item("iron", 10, false); g.add_item("wood", 30, false); g.add_item("stone", 20, false)
	check(g.craft(R[18]), "craft beacon")
	# place beacon two tiles right of furnace
	var bc = fc + Vector2i(3, 0)
	g.world.res.erase(bc)
	g.world.tiles[bc.y * 128 + bc.x] = 3
	g._place("beacon", bc)
	check(g.world.builds.has(bc), "beacon placed")
	g.ppos = g.world.tile_center(bc) + Vector2(-30, 0)
	g.aim = Vector2.RIGHT
	g.interact()
	check(g.beacon_t >= 0.0, "beacon lit")
	for i in 70:
		g.hp = 100
		g.food = 100
		g.water = 100
		step(20, 0.05)
		if g.state == "won": break
	check(g.state == "won", "rescue = win state")
	# death path
	g.new_game()
	g.damage_player(500, false)
	check(g.state == "dead", "death -> game over")
	g.new_game()
	check(g.state == "play", "restart works")
	# HUD / UI draw paths
	g.open_craft()
	step(10)
	check(g.ui.craft_rows.size() == R.size(), "craft menu lists recipes")
	g.close_menu()
	g.pause()
	g.resume()
	print("SMOKE ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)
