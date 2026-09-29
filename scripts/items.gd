class_name Items
extends RefCounted
## Diablo-style loot: rarities, random affixes, legendary powers, naming and tooltips.
## Items are plain Dictionaries so they save straight to JSON.

const SLOTS := ["weapon", "helm", "chest", "gloves", "boots", "amulet", "ring1", "ring2"]
const SLOT_NAMES := {"weapon": "Arma", "helm": "Elmo", "chest": "Peitoral", "gloves": "Luvas", "boots": "Botas", "amulet": "Amuleto", "ring1": "Anel", "ring2": "Anel", "ring": "Anel"}
const DROP_SLOTS := ["weapon", "helm", "chest", "gloves", "boots", "amulet", "ring"]

const RARITY_NAMES := ["Comum", "Mágico", "Raro", "Lendário", "Ancestral"]
const RARITY_COLORS := [Color(0.92, 0.9, 0.86), Color(0.45, 0.62, 1.0), Color(1.0, 0.88, 0.3), Color(1.0, 0.55, 0.12), Color(1.0, 0.35, 0.55)]

const BASES := {
	"weapon": ["Espada Longa", "Lâmina Rúnica", "Machado de Guerra", "Cajado Antigo", "Adaga Curva", "Montante", "Foice Lunar", "Martelo de Batalha"],
	"helm": ["Elmo de Ferro", "Capuz de Couro", "Coroa de Ossos", "Elmo Alado", "Tiara de Prata"],
	"chest": ["Cota de Malha", "Armadura de Placas", "Manto Encantado", "Couraça Élfica", "Túnica de Seda"],
	"gloves": ["Manoplas", "Luvas de Couro", "Braçadeiras", "Luvas Rúnicas"],
	"boots": ["Botas de Viagem", "Grevas", "Sandálias Aladas", "Botas Rúnicas"],
	"amulet": ["Amuleto", "Talismã", "Colar de Pérolas", "Pingente de Âmbar"],
	"ring": ["Anel de Ouro", "Anel de Prata", "Anel de Ônix", "Aliança Rúnica"],
}

## key: [label template, value at ilvl 1, growth per ilvl, allowed slots, is percent]
const AFFIXES := {
	"atk": ["+%d de Ataque", 3.0, 0.9, ["weapon", "gloves", "ring", "amulet"], false],
	"mag": ["+%d de Magia", 3.0, 0.9, ["weapon", "helm", "ring", "amulet"], false],
	"hp": ["+%d de Vida", 12.0, 3.5, ["helm", "chest", "boots", "amulet", "ring"], false],
	"mp": ["+%d de Mana", 6.0, 1.2, ["helm", "amulet", "ring"], false],
	"armor": ["+%d de Armadura", 10.0, 3.0, ["helm", "chest", "gloves", "boots"], false],
	"crit": ["+%d%% de Chance Crítica", 3.0, 0.08, ["helm", "gloves", "ring", "amulet"], true],
	"critdmg": ["+%d%% de Dano Crítico", 15.0, 0.6, ["weapon", "gloves", "ring", "amulet"], true],
	"aspd": ["+%d%% de Velocidade de Ataque", 5.0, 0.12, ["weapon", "gloves", "ring", "amulet"], true],
	"move": ["+%d%% de Velocidade de Movimento", 6.0, 0.12, ["boots"], true],
	"leech": ["%d%% do dano vira vida", 1.0, 0.04, ["weapon", "ring", "amulet"], true],
	"regen": ["+%d de Vida por segundo", 1.0, 0.25, ["chest", "amulet", "ring"], false],
	"fire": ["+%d%% de Dano de Fogo", 10.0, 0.4, ["weapon", "helm", "amulet", "ring"], true],
	"ice": ["+%d%% de Dano de Gelo", 10.0, 0.4, ["weapon", "helm", "amulet", "ring"], true],
	"bolt": ["+%d%% de Dano de Raio", 10.0, 0.4, ["weapon", "helm", "amulet", "ring"], true],
	"cost": ["-%d%% de Custo de Mana", 5.0, 0.1, ["helm", "amulet"], true],
	"gold": ["+%d%% de Ouro Encontrado", 12.0, 0.5, ["helm", "boots", "ring", "amulet"], true],
	"mf": ["+%d%% de Achado Mágico", 8.0, 0.35, ["helm", "boots", "ring", "amulet"], true],
	"thorns": ["+%d de Espinhos", 6.0, 2.0, ["chest", "gloves"], false],
	"area": ["+%d%% de Área de Efeito", 8.0, 0.2, ["weapon", "amulet"], true],
	"elite": ["+%d%% de Dano contra Elites", 8.0, 0.3, ["weapon", "helm", "amulet", "ring"], true],
}

## Legendary powers. `slot` is where the power can roll.
const LEGENDS := {
	"phoenix": {"name": "Coração da Fênix", "slot": "amulet", "text": "A Chama explode duas vezes."},
	"storm": {"name": "Tempestade Engarrafada", "slot": "ring", "text": "O Relâmpago salta entre até 9 inimigos."},
	"trail": {"name": "Botas do Rastro Ardente", "slot": "boots", "text": "A esquiva deixa um rastro de fogo que queima inimigos."},
	"hunger": {"name": "Lâmina Faminta", "slot": "weapon", "text": "Golpes críticos curam 3% da vida."},
	"corpse": {"name": "Elmo do Necromante", "slot": "helm", "text": "Inimigos explodem em estilhaços de osso ao morrer."},
	"thunder": {"name": "Manoplas do Trovão", "slot": "gloves", "text": "Todo quinto golpe dispara um Relâmpago gratuito."},
	"winter": {"name": "Anel do Inverno Eterno", "slot": "ring", "text": "A Geada sempre congela."},
	"brambles": {"name": "Peitoral de Espinhos Vivos", "slot": "chest", "text": "Espinhos causam o triplo de dano."},
	"stars": {"name": "Cajado da Chuva Estelar", "slot": "weapon", "text": "Cada magia faz cair três meteoros perto do alvo."},
	"echo": {"name": "Colar do Eco Infinito", "slot": "amulet", "text": "50% de chance de uma magia não gastar mana."},
	"quake": {"name": "Machado do Terremoto", "slot": "weapon", "text": "O terceiro golpe do combo racha o chão numa onda de choque."},
	"twin": {"name": "Adagas da Sombra Dupla", "slot": "weapon", "text": "Golpes de espada acertam duas vezes."},
	"collector": {"name": "Anel do Colecionador", "slot": "ring", "text": "Dobra o ouro encontrado, e cada moeda cura um pouco."},
	"hermes": {"name": "Botas de Hermes", "slot": "boots", "text": "+30% de velocidade e esquiva sem tempo de recarga."},
	"crown": {"name": "Coroa do Rei Esqueleto", "slot": "helm", "text": "+50% de dano contra elites, que largam um item a mais."},
	"vampire": {"name": "Luvas do Vampiro", "slot": "gloves", "text": "8% de todo dano causado vira vida."},
}

const RARE_A := ["Presságio", "Lamento", "Fúria", "Sussurro", "Juramento", "Eclipse", "Brasa", "Aurora", "Ruína", "Vigília", "Tormenta", "Espinho"]
const RARE_B := ["Sombrio", "Rubro", "Eterno", "Selvagem", "Arcano", "Gélido", "Dourado", "Esquecido", "Feroz", "Sagrado", "Faminto", "Veloz"]
const SUFFIX := {
	"atk": "da Fúria", "mag": "do Sábio", "hp": "do Urso", "mp": "da Coruja", "armor": "da Muralha", "crit": "da Precisão",
	"critdmg": "do Carrasco", "aspd": "do Vento", "move": "do Viajante", "leech": "do Vampiro", "regen": "da Seiva", "fire": "das Brasas",
	"ice": "do Inverno", "bolt": "da Tempestade", "cost": "do Monge", "gold": "da Cobiça", "mf": "da Sorte", "thorns": "do Ouriço",
	"area": "da Vastidão", "elite": "do Caçador",
}

static var _next_id := 1


static func affix_value(key: String, ilvl: int, quality := 1.0) -> int:
	var a: Array = AFFIXES[key]
	var v: float = (a[1] + a[2] * ilvl) * randf_range(0.7, 1.15) * quality
	return max(1, int(round(v)))


## Rolls a rarity. `luck` adds from magic find, difficulty and elites.
static func roll_rarity(luck: float) -> int:
	var r := randf() * 100.0
	var legendary := 1.2 + luck * 1.4
	var rare := 9.0 + luck * 5.0
	var magic := 32.0 + luck * 4.0
	if r < legendary:
		return 3
	if r < legendary + rare:
		return 2
	if r < legendary + rare + magic:
		return 1
	return 0


static func generate(ilvl: int, rarity: int, slot := "", legend := "") -> Dictionary:
	if slot == "":
		slot = DROP_SLOTS[randi() % DROP_SLOTS.size()]
	var ancient := false
	if rarity >= 3:
		if legend == "":
			var options := []
			for k in LEGENDS:
				if LEGENDS[k]["slot"] == slot:
					options.append(k)
			if options.is_empty():
				rarity = 2
			else:
				legend = options[randi() % options.size()]
		if rarity >= 3 and Game.torment >= 3 and randf() < 0.12:
			ancient = true
			rarity = 4
	var quality = 1.3 if ancient else 1.0
	var item = {"id": _next_id, "slot": slot, "rarity": rarity, "ilvl": ilvl, "base": BASES[slot][randi() % BASES[slot].size()], "affixes": [], "legend": legend}
	_next_id += 1
	if slot == "weapon":
		item["dmg"] = int(round((6.0 + ilvl * 1.6) * randf_range(0.85, 1.15) * quality * (1.0 + rarity * 0.12)))
	elif slot in ["helm", "chest", "gloves", "boots"]:
		var base_armor: float = {"helm": 8.0, "chest": 14.0, "gloves": 6.0, "boots": 6.0}[slot]
		item["armor"] = int(round((base_armor + ilvl * base_armor * 0.25) * randf_range(0.85, 1.15) * quality))
	var count: int = [0, randi_range(1, 2), randi_range(3, 4), 4, 5][rarity]
	var pool := []
	for k in AFFIXES:
		if slot in AFFIXES[k][3]:
			pool.append(k)
	pool.shuffle()
	for i in min(count, pool.size()):
		item["affixes"].append({"k": pool[i], "v": affix_value(pool[i], ilvl, quality)})
	item["name"] = _make_name(item)
	return item


static func _make_name(item: Dictionary) -> String:
	match int(item["rarity"]):
		0:
			return item["base"]
		1:
			var aff: Array = item["affixes"]
			return item["base"] + " " + SUFFIX[aff[0]["k"]] if aff.size() > 0 else item["base"]
		2:
			return RARE_A[randi() % RARE_A.size()] + " " + RARE_B[randi() % RARE_B.size()]
		_:
			var n: String = LEGENDS[item["legend"]]["name"]
			return ("Ancestral: " + n) if item["rarity"] == 4 else n


static func color(item: Dictionary) -> Color:
	return RARITY_COLORS[int(item["rarity"])]


static func slot_of(item: Dictionary) -> String:
	return item["slot"]


## Tooltip rows: [text, Color]
static func lines(item: Dictionary) -> Array:
	var out := []
	out.append([item["name"], color(item)])
	out.append(["%s %s  ·  Nível %d" % [RARITY_NAMES[int(item["rarity"])], SLOT_NAMES[item["slot"]], item["ilvl"]], Color(0.75, 0.7, 0.6)])
	if item.has("dmg"):
		out.append(["%d de Dano de Arma" % item["dmg"], Color(1, 1, 1)])
	if item.has("armor"):
		out.append(["%d de Armadura" % item["armor"], Color(1, 1, 1)])
	for a in item["affixes"]:
		out.append([AFFIXES[a["k"]][0] % a["v"], Color(0.55, 0.7, 1.0)])
	if item.get("legend", "") != "":
		out.append([LEGENDS[item["legend"]]["text"], Color(1.0, 0.62, 0.2)])
	return out


## Adds an item's numbers into a stats dictionary.
static func add_stats(stats: Dictionary, item: Dictionary) -> void:
	if item.has("dmg"):
		stats["atk"] = stats.get("atk", 0.0) + item["dmg"]
		stats["mag"] = stats.get("mag", 0.0) + item["dmg"] * 0.6
	if item.has("armor"):
		stats["armor"] = stats.get("armor", 0.0) + item["armor"]
	for a in item["affixes"]:
		stats[a["k"]] = stats.get(a["k"], 0.0) + a["v"]
	if item.get("legend", "") != "":
		stats["legend_" + item["legend"]] = 1.0


## Rough power score used to compare items and to sort.
static func score(item: Dictionary) -> float:
	var s = float(item.get("dmg", 0)) * 2.0 + float(item.get("armor", 0)) * 0.6
	for a in item["affixes"]:
		var base: float = AFFIXES[a["k"]][1] + AFFIXES[a["k"]][2] * float(item["ilvl"])
		s += 10.0 * float(a["v"]) / max(base, 1.0)
	if item.get("legend", "") != "":
		s += 25.0
	return s


static func salvage_value(item: Dictionary) -> int:
	return [1, 3, 8, 25, 60][int(item["rarity"])]


static func sell_value(item: Dictionary) -> int:
	return int((4 + item["ilvl"] * 1.5) * [1, 2, 4, 10, 20][int(item["rarity"])])
