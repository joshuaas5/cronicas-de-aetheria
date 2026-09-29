extends Node
## Global game state: hero stats, classes, the Mana Tree skill tree, story flags,
## planted lands, save file and input map.

signal stats_changed
signal toast(text: String)
signal class_changed

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
	"bolt": {"name": "Relâmpago", "cost": 12, "color": Color(0.85, 0.8, 1.0)},
}

## Vocations. `keep` lists the weapon meshes shown on the model.
const CLASSES := {
	"knight": {
		"name": "Cavaleiro", "model": "Knight", "keep": ["1H_Sword", "Round_Shield"],
		"speed": 5.4, "hp": 1.0, "mp": 1.0, "atk": 1.0, "mag": 1.0, "reach": 0.0, "crit": 0.0,
		"attacks": ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Stab"],
		"attack_speed": 1.55, "spell_cost": 1.0, "dodge_cd": 0.55,
		"desc": "Equilibrado. Espada e escudo, bom em tudo.",
	},
	"rogue": {
		"name": "Ladina", "model": "Rogue", "keep": ["Knife", "Knife_Offhand"],
		"speed": 6.5, "hp": 0.85, "mp": 1.0, "atk": 0.78, "mag": 0.9, "reach": -0.2, "crit": 0.18,
		"attacks": ["Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Stab", "Dualwield_Melee_Attack_Chop", "Dualwield_Melee_Attack_Stab"],
		"attack_speed": 2.0, "spell_cost": 1.0, "dodge_cd": 0.3,
		"desc": "Rápida e letal. Adagas duplas, críticos frequentes, esquiva quase sem espera.",
	},
	"barbarian": {
		"name": "Bárbaro", "model": "Barbarian", "keep": ["2H_Axe"],
		"speed": 4.8, "hp": 1.35, "mp": 0.75, "atk": 1.6, "mag": 0.7, "reach": 0.5, "crit": 0.05,
		"attacks": ["2H_Melee_Attack_Slice", "2H_Melee_Attack_Chop", "2H_Melee_Attack_Spin", "2H_Melee_Attack_Stab"],
		"attack_speed": 1.2, "spell_cost": 1.3, "dodge_cd": 0.7,
		"desc": "Força bruta. Machado de duas mãos, muita vida, golpes lentos e devastadores.",
	},
	"mage": {
		"name": "Mago", "model": "Mage", "keep": ["2H_Staff"],
		"speed": 5.2, "hp": 0.8, "mp": 1.6, "atk": 0.65, "mag": 1.6, "reach": 0.2, "crit": 0.0,
		"attacks": ["2H_Melee_Attack_Slice", "2H_Melee_Attack_Chop", "2H_Melee_Attack_Stab", "2H_Melee_Attack_Spin"],
		"attack_speed": 1.45, "spell_cost": 0.7, "dodge_cd": 0.55,
		"desc": "Mestre da mana. Magias mais fortes e mais baratas, corpo frágil.",
	},
}

## The Mana Tree. `pos` places each node on the tree screen (1920x1080 canvas).
const SKILLS := {
	"s_edge": {"name": "Fio Afiado", "desc": "+4 de ataque.", "branch": "sword", "cost": 1, "req": [], "pos": Vector2(560, 760)},
	"s_crit": {"name": "Golpe Certeiro", "desc": "15% de chance de acerto crítico (dano dobrado).", "branch": "sword", "cost": 1, "req": ["s_edge"], "pos": Vector2(430, 610)},
	"s_spin": {"name": "Redemoinho", "desc": "O terceiro golpe do combo vira um giro que acerta tudo ao redor.", "branch": "sword", "cost": 2, "req": ["s_edge"], "pos": Vector2(640, 580)},
	"s_dash": {"name": "Investida", "desc": "Atacar durante a esquiva faz um avanço cortante com dano alto.", "branch": "sword", "cost": 2, "req": ["s_crit"], "pos": Vector2(360, 440)},
	"s_combo": {"name": "Quarto Golpe", "desc": "Acrescenta um quarto golpe ao combo, com empurrão enorme.", "branch": "sword", "cost": 2, "req": ["s_spin"], "pos": Vector2(600, 400)},
	"m_flow": {"name": "Fluxo de Mana", "desc": "+8 de mana máxima e recuperação de mana 50% mais rápida.", "branch": "magic", "cost": 1, "req": [], "pos": Vector2(960, 700)},
	"m_blaze": {"name": "Chama Voraz", "desc": "A explosão da Chama fica 50% maior e deixa os inimigos em brasa.", "branch": "magic", "cost": 2, "req": ["m_flow"], "pos": Vector2(840, 540)},
	"m_frost": {"name": "Nevasca", "desc": "A Geada dispara 5 lascas e pode congelar inimigos por um instante.", "branch": "magic", "cost": 2, "req": ["m_flow"], "pos": Vector2(1080, 540)},
	"m_bolt": {"name": "Relâmpago", "desc": "Nova magia: um raio que salta entre até 4 inimigos.", "branch": "magic", "cost": 2, "req": ["m_blaze|m_frost"], "pos": Vector2(960, 380)},
	"m_echo": {"name": "Eco Arcano", "desc": "25% de chance de uma magia não gastar mana.", "branch": "magic", "cost": 2, "req": ["m_bolt"], "pos": Vector2(960, 230)},
	"v_root": {"name": "Raízes Firmes", "desc": "+20 de vida máxima.", "branch": "life", "cost": 1, "req": [], "pos": Vector2(1360, 760)},
	"v_regen": {"name": "Seiva", "desc": "Recupera vida lentamente com o tempo.", "branch": "life", "cost": 1, "req": ["v_root"], "pos": Vector2(1490, 610)},
	"v_potion": {"name": "Herbalismo", "desc": "Poções curam 60% a mais e inimigos soltam mais corações.", "branch": "life", "cost": 2, "req": ["v_root"], "pos": Vector2(1280, 580)},
	"v_thorns": {"name": "Casca de Espinhos", "desc": "Devolve 30% do dano corpo a corpo recebido.", "branch": "life", "cost": 2, "req": ["v_regen"], "pos": Vector2(1560, 440)},
	"v_phoenix": {"name": "Renascer", "desc": "Uma vez por área, ao cair, você se levanta com metade da vida.", "branch": "life", "cost": 3, "req": ["v_potion"], "pos": Vector2(1320, 400)},
}

const TORMENT := [
	{"name": "Normal", "hp": 1.0, "dmg": 1.0, "xp": 0.0, "luck": 0.0},
	{"name": "Difícil", "hp": 2.0, "dmg": 1.3, "xp": 0.5, "luck": 0.4},
	{"name": "Especialista", "hp": 3.2, "dmg": 1.6, "xp": 1.0, "luck": 0.8},
	{"name": "Mestre", "hp": 5.0, "dmg": 2.0, "xp": 1.6, "luck": 1.3},
	{"name": "Tormento I", "hp": 8.0, "dmg": 2.5, "xp": 2.5, "luck": 2.0},
	{"name": "Tormento II", "hp": 12.0, "dmg": 3.1, "xp": 3.5, "luck": 2.7},
	{"name": "Tormento III", "hp": 18.0, "dmg": 3.8, "xp": 5.0, "luck": 3.5},
	{"name": "Tormento IV", "hp": 27.0, "dmg": 4.6, "xp": 7.0, "luck": 4.4},
	{"name": "Tormento V", "hp": 40.0, "dmg": 5.5, "xp": 9.0, "luck": 5.4},
	{"name": "Tormento VI", "hp": 60.0, "dmg": 6.5, "xp": 12.0, "luck": 6.5},
]
const MAX_LEVEL := 70
const INV_SIZE := 48

const WEAPON_TIERS := [
	{"name": "Lâmina de Ferro", "cost": 0},
	{"name": "Lâmina de Aço", "cost": 40},
	{"name": "Lâmina de Mithril", "cost": 90},
	{"name": "Lâmina de Cristal de Mana", "cost": 180},
	{"name": "Lâmina Ancestral", "cost": 320},
]

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
var cls := "knight"
var classes: Array = ["knight"]
var skills: Array = []
var essence := 0
var weapon_tier := 0
var inventory: Array = []
var equipment := {}
var dust := 0
var torment := 0
var torment_unlocked := 1
var gear := {}
var kills := 0
var best_rift := 0
var rift_level := 0


func _ready() -> void:
	_setup_input()
	recalc()


func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"attack": [KEY_J, KEY_Z], "magic": [KEY_K, KEY_X], "dodge": [KEY_L, KEY_SHIFT, KEY_C],
		"interact": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "spell_next": [KEY_E, KEY_TAB], "spell_prev": [KEY_Q],
		"potion": [KEY_R], "pause": [KEY_ESCAPE, KEY_P], "mute": [KEY_M], "tree": [KEY_T],
		"inventory": [KEY_I, KEY_B], "view": [KEY_V], "salvage": [KEY_X, KEY_DELETE], "salvage_all": [KEY_G],
	}
	var pads := {
		"attack": [JOY_BUTTON_X], "magic": [JOY_BUTTON_Y], "dodge": [JOY_BUTTON_B], "interact": [JOY_BUTTON_A],
		"spell_next": [JOY_BUTTON_RIGHT_SHOULDER], "spell_prev": [JOY_BUTTON_LEFT_SHOULDER],
		"potion": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START], "tree": [JOY_BUTTON_LEFT_STICK], "view": [JOY_BUTTON_RIGHT_STICK],
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
	for pair in [["attack", MOUSE_BUTTON_LEFT], ["magic", MOUSE_BUTTON_RIGHT]]:
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)


# ---------------------------------------------------------------- derived stats

func has_skill(id: String) -> bool:
	return skills.has(id)


func class_data() -> Dictionary:
	return CLASSES[cls]


## Rebuilds every derived stat from level, class, skills and weapon.
func recalc() -> void:
	var c := class_data()
	var ending = 1 if flags.get("ending", false) else 0
	gear = {}
	for s in Items.SLOTS:
		if equipment.get(s) != null:
			Items.add_stats(gear, equipment[s])
	var hp_base = 60.0 + 8.0 * (lvl - 1) + (20.0 if has_skill("v_root") else 0.0) + 20.0 * ending + stat("hp")
	var mp_base = 30.0 + 4.0 * (lvl - 1) + (8.0 if has_skill("m_flow") else 0.0) + 10.0 * ending + stat("mp")
	var old_max_hp := max_hp
	var old_max_mp := max_mp
	max_hp = round(hp_base * c["hp"])
	max_mp = round(mp_base * c["mp"])
	atk = (9.0 + 2.0 * (lvl - 1) + weapon_tier * 3.0 + (4.0 if has_skill("s_edge") else 0.0) + stat("atk")) * c["atk"]
	mag = (10.0 + 2.0 * (lvl - 1) + stat("mag")) * c["mag"]
	# keep the same fraction of health/mana when the maximum changes
	if old_max_hp > 0.0:
		hp = clamp(hp * max_hp / old_max_hp, 1.0 if hp > 0.0 else 0.0, max_hp)
	if old_max_mp > 0.0:
		mp = clamp(mp * max_mp / old_max_mp, 0.0, max_mp)
	stats_changed.emit()


func stat(k: String) -> float:
	return float(gear.get(k, 0.0))


func legend(k: String) -> bool:
	return gear.has("legend_" + k)


func crit_chance() -> float:
	return min(0.75, class_data()["crit"] + (0.15 if has_skill("s_crit") else 0.0) + stat("crit") / 100.0)


func crit_mult() -> float:
	return 2.0 + stat("critdmg") / 100.0


func attack_speed() -> float:
	return 1.0 + stat("aspd") / 100.0


func move_speed() -> float:
	return 1.0 + stat("move") / 100.0 + (0.3 if legend("hermes") else 0.0)


func leech() -> float:
	return stat("leech") / 100.0 + (0.08 if legend("vampire") else 0.0)


func element_mult(kind: String) -> float:
	if kind in ["fire", "burn"]:
		return 1.0 + stat("fire") / 100.0
	if kind == "ice":
		return 1.0 + stat("ice") / 100.0
	if kind == "bolt":
		return 1.0 + stat("bolt") / 100.0
	return 1.0


## Fraction of incoming damage removed by armor against a monster of `mlvl`.
func damage_reduction(mlvl: int) -> float:
	var a := stat("armor") + weapon_tier * 4.0
	return min(0.75, a / (a + 40.0 + mlvl * 14.0))


func magic_find() -> float:
	return stat("mf") / 100.0 + TORMENT[torment]["luck"]


func spell_cost(id: String) -> int:
	return int(ceil(SPELLS[id]["cost"] * class_data()["spell_cost"] * max(0.4, 1.0 - stat("cost") / 100.0)))


## Monsters scale with the hero so loot always stays relevant.
func monster_level(area_min: int) -> int:
	return max(area_min, lvl)


func xp_next() -> int:
	return int(round(18.0 * pow(lvl, 1.55)))


## Returns true when the hero levels up.
func gain_xp(n: int) -> bool:
	xp += int(n * (1.0 + TORMENT[torment]["xp"]))
	var leveled := false
	while xp >= xp_next() and lvl < MAX_LEVEL:
		xp -= xp_next()
		lvl += 1
		essence += 1
		leveled = true
	if leveled:
		recalc()
		hp = max_hp
		mp = max_mp
	stats_changed.emit()
	return leveled


# ---------------------------------------------------------------- skill tree

func skill_state(id: String) -> String:
	if has_skill(id):
		return "owned"
	for r in SKILLS[id]["req"]:
		var ok := false
		for alt in String(r).split("|"):
			if has_skill(alt):
				ok = true
		if not ok:
			return "locked"
	return "available"


func buy_skill(id: String) -> bool:
	if skill_state(id) != "available" or essence < SKILLS[id]["cost"]:
		return false
	essence -= SKILLS[id]["cost"]
	skills.append(id)
	if id == "m_bolt" and not spells.has("bolt"):
		spells.append("bolt")
	recalc()
	save_game()
	return true


# ---------------------------------------------------------------- classes

func unlock_class(id: String) -> void:
	if classes.has(id):
		return
	classes.append(id)
	toast.emit("Nova vocação: " + CLASSES[id]["name"])
	Sfx.play("item")
	save_game()


func set_class(id: String) -> void:
	if not classes.has(id) or id == cls:
		return
	cls = id
	recalc()
	class_changed.emit()
	save_game()


func upgrade_weapon() -> bool:
	if weapon_tier >= WEAPON_TIERS.size() - 1:
		return false
	var cost: int = WEAPON_TIERS[weapon_tier + 1]["cost"]
	if gold < cost:
		return false
	gold -= cost
	weapon_tier += 1
	recalc()
	save_game()
	return true


# ---------------------------------------------------------------- misc

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
	lvl = 1; xp = 0; gold = 20; potions = 3
	spells = ["fire"]; spell_idx = 0
	flags = {}
	lands = {"village": Vector2i(1, 1)}
	arts = []
	current_level = "village"
	map_here = "village"
	cls = "knight"; classes = ["knight"]; skills = []; essence = 0; weapon_tier = 0
	inventory = []; equipment = {}; dust = 0; torment = 0; torment_unlocked = 1; kills = 0; best_rift = 0
	equipment["weapon"] = Items.generate(1, 0, "weapon")
	equipment["chest"] = Items.generate(1, 0, "chest")
	max_hp = 0.0; max_mp = 0.0
	recalc()
	hp = max_hp
	mp = max_mp
	stats_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var lands_out := {}
	for k in lands:
		lands_out[k] = [lands[k].x, lands[k].y]
	var data := {
		"hp": hp, "mp": mp, "lvl": lvl, "xp": xp, "gold": gold, "potions": potions, "spells": spells,
		"flags": flags, "lands": lands_out, "arts": arts,
		"level": {"forest2": "forest1", "rift": "village"}.get(current_level, current_level), "map_here": map_here,
		"cls": cls, "classes": classes, "skills": skills, "essence": essence, "weapon_tier": weapon_tier,
		"inventory": inventory, "equipment": equipment, "dust": dust, "torment": torment,
		"torment_unlocked": torment_unlocked, "kills": kills, "best_rift": best_rift, "next_id": Items._next_id,
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
	lvl = int(d.get("lvl", 1)); xp = int(d.get("xp", 0))
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
	cls = d.get("cls", "knight")
	classes = d.get("classes", ["knight"])
	skills = d.get("skills", [])
	essence = int(d.get("essence", lvl - 1))
	weapon_tier = int(d.get("weapon_tier", 0))
	inventory = d.get("inventory", [])
	equipment = d.get("equipment", {})
	for k in equipment.keys():
		if equipment[k] == null:
			equipment.erase(k)
	dust = int(d.get("dust", 0))
	torment = int(d.get("torment", 0))
	torment_unlocked = int(d.get("torment_unlocked", 1))
	kills = int(d.get("kills", 0))
	best_rift = int(d.get("best_rift", 0))
	Items._next_id = int(d.get("next_id", 1000))
	# JSON turns ints into floats; normalise the numbers items rely on
	for it in inventory + equipment.values():
		it["rarity"] = int(it["rarity"])
		it["ilvl"] = int(it["ilvl"])
	max_hp = 0.0; max_mp = 0.0
	recalc()
	hp = clamp(float(d.get("hp", max_hp)), 1.0, max_hp)
	mp = clamp(float(d.get("mp", max_mp)), 0.0, max_mp)
	stats_changed.emit()
	return true



# ---------------------------------------------------------------- inventory

func add_item(item: Dictionary) -> bool:
	if inventory.size() >= INV_SIZE:
		return false
	inventory.append(item)
	return true


## Equips inventory item `idx`, swapping out whatever was there.
func equip(idx: int) -> void:
	var item: Dictionary = inventory[idx]
	var slot: String = item["slot"]
	if slot == "ring":
		slot = "ring1" if equipment.get("ring1") == null or (equipment.get("ring2") != null and Items.score(equipment["ring1"]) <= Items.score(equipment["ring2"])) else "ring2"
	var old = equipment.get(slot)
	equipment[slot] = item
	inventory.remove_at(idx)
	if old != null:
		inventory.insert(idx, old)
	recalc()


func unequip(slot: String) -> void:
	if equipment.get(slot) == null or inventory.size() >= INV_SIZE:
		return
	inventory.append(equipment[slot])
	equipment[slot] = null
	recalc()


func salvage(idx: int) -> int:
	var v := Items.salvage_value(inventory[idx])
	dust += v
	inventory.remove_at(idx)
	return v


## Salvages every Common and Magic item in the bag.
func salvage_junk() -> int:
	var got := 0
	for i in range(inventory.size() - 1, -1, -1):
		if int(inventory[i]["rarity"]) <= 1:
			got += salvage(i)
	return got


func equipped_for(item: Dictionary):
	var slot: String = item["slot"]
	if slot == "ring":
		var a = equipment.get("ring1")
		var b = equipment.get("ring2")
		if a == null or b == null:
			return null
		return a if Items.score(a) <= Items.score(b) else b
	return equipment.get(slot)
