extends Node
## Global game state: hero stats, story flags, planted lands, save file, input map.

signal stats_changed
signal toast(text: String)

const SAVE_PATH := "user://aetheria_save.json"

const ARTS := {
	"seed": {"name": "Semente Verdejante", "land": "forest", "color": Color(0.45, 0.9, 0.35)},
	"tear": {"name": "Lágrima da Lua", "land": "sanctuary", "color": Color(0.55, 0.85, 1.0)},
}
const LANDS := {
	"village": {"name": "Vila Lumen", "level": "village", "spawn": "road"},
	"forest": {"name": "Bosque Sussurrante", "level": "forest1", "spawn": "west"},
	"sanctuary": {"name": "Santuário de Mana", "level": "sanctuary", "spawn": "south"},
}
const SPELLS := {
	"fire": {"name": "Chama", "cost": 6, "color": Color(1.0, 0.55, 0.2)},
	"ice": {"name": "Geada", "cost": 8, "color": Color(0.55, 0.85, 1.0)},
	"heal": {"name": "Cura", "cost": 10, "color": Color(0.5, 1.0, 0.5)},
}

var hp := 60.0
var max_hp := 60.0
var mp := 30.0
var max_mp := 30.0
var atk := 9.0
var mag := 10.0
var lvl := 1
var xp := 0
var gold := 20
var potions := 3
var spells: Array = ["fire"]
var spell_idx := 0
var flags := {}
var lands := {"village": Vector2i(1, 1)}
var arts: Array = []
var current_level := "village"
var map_here := "village"


func _ready() -> void:
	_setup_input()


func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"attack": [KEY_J, KEY_Z], "magic": [KEY_K, KEY_X], "dodge": [KEY_L, KEY_SHIFT, KEY_C],
		"interact": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "spell_next": [KEY_E, KEY_TAB], "spell_prev": [KEY_Q],
		"potion": [KEY_R], "pause": [KEY_ESCAPE, KEY_P], "mute": [KEY_M],
	}
	var pads := {
		"attack": [JOY_BUTTON_X], "magic": [JOY_BUTTON_Y], "dodge": [JOY_BUTTON_B], "interact": [JOY_BUTTON_A],
		"spell_next": [JOY_BUTTON_RIGHT_SHOULDER], "spell_prev": [JOY_BUTTON_LEFT_SHOULDER],
		"potion": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START],
		"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
		"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for b in pads.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)


# ---------------------------------------------------------------- progression

func xp_next() -> int:
	return int(round(18.0 * pow(lvl, 1.45)))


## Returns true when the hero levels up.
func gain_xp(n: int) -> bool:
	xp += n
	var leveled := false
	while xp >= xp_next():
		xp -= xp_next()
		lvl += 1
		max_hp += 8
		max_mp += 4
		atk += 2
		mag += 2
		hp = max_hp
		mp = max_mp
		leveled = true
	stats_changed.emit()
	return leveled


func give_artifact(id: String) -> void:
	if not arts.has(id):
		arts.append(id)
	toast.emit("Obteve: " + ARTS[id]["name"])
	Sfx.play("item")
	save_game()


func learn(spell: String) -> void:
	if not spells.has(spell):
		spells.append(spell)
		toast.emit("Nova magia: " + SPELLS[spell]["name"])
		Sfx.play("item")
	stats_changed.emit()
	save_game()


func current_spell() -> String:
	return spells[clamp(spell_idx, 0, spells.size() - 1)]


func land_at(cell: Vector2i) -> String:
	for k in lands:
		if lands[k] == cell:
			return k
	return ""


# ---------------------------------------------------------------- save

func new_game() -> void:
	hp = 60; max_hp = 60; mp = 30; max_mp = 30; atk = 9; mag = 10
	lvl = 1; xp = 0; gold = 20; potions = 3
	spells = ["fire"]; spell_idx = 0
	flags = {}
	lands = {"village": Vector2i(1, 1)}
	arts = []
	current_level = "village"
	map_here = "village"
	stats_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var lands_out := {}
	for k in lands:
		lands_out[k] = [lands[k].x, lands[k].y]
	var data := {
		"hp": hp, "max_hp": max_hp, "mp": mp, "max_mp": max_mp, "atk": atk, "mag": mag,
		"lvl": lvl, "xp": xp, "gold": gold, "potions": potions, "spells": spells,
		"flags": flags, "lands": lands_out, "arts": arts,
		"level": "forest1" if current_level == "forest2" else current_level, "map_here": map_here,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	hp = d.get("hp", 60); max_hp = d.get("max_hp", 60); mp = d.get("mp", 30); max_mp = d.get("max_mp", 30)
	atk = d.get("atk", 9); mag = d.get("mag", 10); lvl = int(d.get("lvl", 1)); xp = int(d.get("xp", 0))
	gold = int(d.get("gold", 20)); potions = int(d.get("potions", 3))
	spells = d.get("spells", ["fire"]); spell_idx = 0
	flags = d.get("flags", {})
	lands = {}
	var lo: Dictionary = d.get("lands", {"village": [1, 1]})
	for k in lo:
		lands[k] = Vector2i(int(lo[k][0]), int(lo[k][1]))
	arts = d.get("arts", [])
	current_level = d.get("level", "village")
	map_here = d.get("map_here", "village")
	stats_changed.emit()
	return true
