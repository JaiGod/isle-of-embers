extends RefCounted
## Static game data: items, recipes, creatures. Everything is plain dictionaries
## so the save file and the UI can read them without extra classes.

const TILE := 32
const MAP := 128
const DAY_LEN := 240.0          # seconds per full day/night cycle
const NIGHT_START := 0.66       # fraction of the day when night begins
const NIGHT_END := 0.97

# Terrain ids
const T_DEEP := 0
const T_SHALLOW := 1
const T_SAND := 2
const T_GRASS := 3
const T_FOREST := 4
const T_ROCK := 5
const T_ASH := 6
const T_EMBER := 7

# Resource node ids
const R_TREE := 1
const R_ROCK := 2
const R_BUSH := 3
const R_ORE := 4
const R_PALM := 5

const RES := {
	R_TREE: {"name": "Tree", "hp": 6, "drop": {"wood": 3}, "bonus": {"fiber": 1}, "tool": "axe"},
	R_PALM: {"name": "Palm", "hp": 4, "drop": {"wood": 2}, "bonus": {"fiber": 2}, "tool": "axe"},
	R_ROCK: {"name": "Boulder", "hp": 8, "drop": {"stone": 3}, "bonus": {}, "tool": "pick"},
	R_BUSH: {"name": "Berry bush", "hp": 2, "drop": {"fiber": 2, "berries": 2}, "bonus": {}, "tool": ""},
	R_ORE: {"name": "Iron vein", "hp": 12, "drop": {"ore": 2, "stone": 1}, "bonus": {}, "tool": "pick"},
}

# kind: mat, tool, weapon, ranged, build, food, armor
const ITEMS := {
	"wood": {"name": "Wood", "kind": "mat", "col": Color("b07a45")},
	"stone": {"name": "Stone", "kind": "mat", "col": Color("9aa0a8")},
	"fiber": {"name": "Fiber", "kind": "mat", "col": Color("9ccf5b")},
	"ore": {"name": "Iron Ore", "kind": "mat", "col": Color("c98b62")},
	"iron": {"name": "Iron Ingot", "kind": "mat", "col": Color("d9dde3")},
	"hide": {"name": "Hide", "kind": "mat", "col": Color("a8744f")},
	"arrow": {"name": "Arrow", "kind": "mat", "col": Color("e8d9b0")},
	"ember_shard": {"name": "Ember Shard", "kind": "mat", "col": Color("ff8a3d")},
	"ember_heart": {"name": "Ember Heart", "kind": "mat", "col": Color("ff4f2e")},
	"berries": {"name": "Berries", "kind": "food", "col": Color("d3415a"), "food": 12, "water": 5, "hp": 0},
	"meat_raw": {"name": "Raw Meat", "kind": "food", "col": Color("e0707a"), "food": 10, "water": 0, "hp": -6},
	"meat_cooked": {"name": "Roast Meat", "kind": "food", "col": Color("a65a2e"), "food": 38, "water": 0, "hp": 8},
	"hand": {"name": "Bare Hands", "kind": "tool", "dmg": 2, "axe": 1, "pick": 0, "reach": 44, "cd": 0.38},
	"axe_stone": {"name": "Stone Axe", "kind": "tool", "dmg": 4, "axe": 3, "pick": 1, "reach": 50, "cd": 0.36},
	"pick_stone": {"name": "Stone Pickaxe", "kind": "tool", "dmg": 3, "axe": 1, "pick": 3, "reach": 50, "cd": 0.38},
	"spear": {"name": "Spear", "kind": "weapon", "dmg": 7, "axe": 1, "pick": 1, "reach": 74, "cd": 0.42},
	"sword_iron": {"name": "Iron Sword", "kind": "weapon", "dmg": 13, "axe": 2, "pick": 1, "reach": 58, "cd": 0.3},
	"bow": {"name": "Bow", "kind": "ranged", "dmg": 9, "ammo": "arrow", "speed": 560.0, "cd": 0.5},
	"fire_staff": {"name": "Fire Staff", "kind": "ranged", "dmg": 16, "ammo": "", "speed": 420.0, "cd": 0.55},
	"hide_armor": {"name": "Hide Armor", "kind": "armor", "armor": 0.25, "cold": 0.6},
	"iron_armor": {"name": "Iron Armor", "kind": "armor", "armor": 0.45, "cold": 0.8},
	"campfire": {"name": "Campfire", "kind": "build", "hp": 60, "solid": true},
	"workbench": {"name": "Workbench", "kind": "build", "hp": 80, "solid": true},
	"wall_wood": {"name": "Wood Wall", "kind": "build", "hp": 90, "solid": true},
	"wall_stone": {"name": "Stone Wall", "kind": "build", "hp": 220, "solid": true},
	"chest": {"name": "Chest", "kind": "build", "hp": 70, "solid": true},
	"furnace": {"name": "Furnace", "kind": "build", "hp": 140, "solid": true},
	"farm": {"name": "Farm Plot", "kind": "build", "hp": 40, "solid": false},
	"beacon": {"name": "Signal Beacon", "kind": "build", "hp": 400, "solid": true},
}

# station: "" (hands), "workbench", "furnace", "campfire"
const RECIPES := [
	{"id": "axe_stone", "n": 1, "st": "", "cost": {"wood": 3, "stone": 2, "fiber": 2}},
	{"id": "pick_stone", "n": 1, "st": "", "cost": {"wood": 3, "stone": 3, "fiber": 2}},
	{"id": "campfire", "n": 1, "st": "", "cost": {"wood": 5, "stone": 3}},
	{"id": "workbench", "n": 1, "st": "", "cost": {"wood": 10, "stone": 4}},
	{"id": "meat_cooked", "n": 1, "st": "campfire", "cost": {"meat_raw": 1}},
	{"id": "spear", "n": 1, "st": "workbench", "cost": {"wood": 4, "stone": 2, "fiber": 3}},
	{"id": "bow", "n": 1, "st": "workbench", "cost": {"wood": 5, "fiber": 6}},
	{"id": "arrow", "n": 6, "st": "workbench", "cost": {"wood": 2, "stone": 1}},
	{"id": "wall_wood", "n": 2, "st": "workbench", "cost": {"wood": 5}},
	{"id": "chest", "n": 1, "st": "workbench", "cost": {"wood": 8, "fiber": 2}},
	{"id": "farm", "n": 1, "st": "workbench", "cost": {"wood": 3, "fiber": 2, "berries": 1}},
	{"id": "hide_armor", "n": 1, "st": "workbench", "cost": {"hide": 4, "fiber": 4}},
	{"id": "furnace", "n": 1, "st": "workbench", "cost": {"stone": 12, "wood": 4}},
	{"id": "iron", "n": 1, "st": "furnace", "cost": {"ore": 2, "wood": 1}},
	{"id": "sword_iron", "n": 1, "st": "furnace", "cost": {"iron": 3, "wood": 2}},
	{"id": "wall_stone", "n": 2, "st": "furnace", "cost": {"stone": 6, "iron": 1}},
	{"id": "iron_armor", "n": 1, "st": "furnace", "cost": {"iron": 5, "hide": 2}},
	{"id": "fire_staff", "n": 1, "st": "furnace", "cost": {"wood": 4, "iron": 2, "ember_shard": 1}},
	{"id": "beacon", "n": 1, "st": "furnace", "cost": {"iron": 8, "wood": 20, "stone": 10, "ember_heart": 1}},
]

const STATION_NAMES := {"": "Hands", "workbench": "Workbench", "furnace": "Furnace", "campfire": "Campfire"}

# Creatures. hostile creatures chase the player; passive ones wander and flee.
const MOBS := {
	"tusker": {"name": "Tusker", "hp": 18, "spd": 70.0, "dmg": 0, "hostile": false, "r": 13.0, "drop": {"meat_raw": 2, "hide": 1}},
	"crab": {"name": "Shore Crab", "hp": 8, "spd": 55.0, "dmg": 4, "hostile": false, "r": 10.0, "drop": {"meat_raw": 1}},
	"ashling": {"name": "Ashling", "hp": 12, "spd": 98.0, "dmg": 6, "hostile": true, "r": 10.0, "drop": {"fiber": 1}},
	"brute": {"name": "Gloom Brute", "hp": 44, "spd": 56.0, "dmg": 14, "hostile": true, "r": 16.0, "drop": {"hide": 1, "stone": 2}},
	"thornback": {"name": "Thornback", "hp": 260, "spd": 64.0, "dmg": 20, "hostile": true, "r": 28.0, "boss": true,
		"drop": {"ember_shard": 1, "meat_raw": 5, "hide": 5}},
	"wyrm": {"name": "Cinder Wyrm", "hp": 560, "spd": 46.0, "dmg": 22, "hostile": true, "r": 32.0, "boss": true,
		"drop": {"ember_heart": 1, "iron": 3}},
}

const TIPS := [
	"Punch trees and boulders to gather wood and stone.",
	"Press C to craft. A Stone Axe and Pickaxe gather much faster.",
	"Drink by pressing E next to water. Eat with F.",
	"Night is cold and dangerous. Build a campfire and some walls.",
	"Craft a Workbench to unlock weapons, walls, chests and farms.",
	"Iron ore needs a pickaxe. Smelt it at a Furnace.",
	"On night 3 the Thornback hunts. Its shard powers a Fire Staff.",
	"The Cinder Wyrm sleeps in the volcano crater. Its heart lights the beacon.",
]
