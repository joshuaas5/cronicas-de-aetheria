class_name Story
extends RefCounted
## Every conversation in the game. `main` exposes ui.say() and a few game actions.

static var main: Node

const FARM_TIPS := [
	"Aperte L para esquivar. Durante a esquiva, nada te acerta.",
	"O terceiro golpe seguido de espada é o mais forte. Tente J, J, J!",
	"Os esqueletos magos atacam de longe. Chegue perto e não dê trégua.",
	"Q e E trocam de magia. A Geada deixa os inimigos lentos.",
	"O Borin, da taverna, vende poções. Aperte R para beber uma.",
]


static func say(entries: Array, done := Callable()) -> void:
	main.ui.say(entries, done)


static func elder() -> void:
	var F := Game.flags
	if not F.get("met_elder", false):
		F["met_elder"] = true
		say([
			{"n": "Ancião Bram", "t": "Kael! Que bom que acordou. A Árvore de Mana está enfraquecendo, e as terras de Aetheria voltam a dormir dentro de seus artefatos."},
			{"n": "Ancião Bram", "t": "Uma sombra corrompeu o Carvalho Ancião, guardião do Bosque Sussurrante. E os mortos do bosque despertaram com ela."},
			{"n": "Ancião Bram", "t": "Leve esta Semente Verdejante. Plante-a no mapa do mundo e o bosque despertará. A estrada a leste leva até o mapa."},
		], func(): Game.give_artifact("seed"))
	elif F.get("boss_defeated", false) and not F.get("got_heal", false):
		F["got_heal"] = true
		say([
			{"n": "Ancião Bram", "t": "Sinto o bosque respirar outra vez! Você libertou o Carvalho Ancião."},
			{"n": "Ancião Bram", "t": "Aceite o que um velho ainda sabe ensinar: a magia da Cura. E a Lágrima da Lua que você trouxe... plante-a. Ela mostrará o Santuário de Mana."},
		], func(): Game.learn("heal"))
	elif F.get("ending", false):
		say([{"n": "Ancião Bram", "t": "A Árvore de Mana floresce como nos contos da minha avó. Aetheria deve tudo a você, Kael."}])
	elif F.get("boss_defeated", false):
		say([{"n": "Ancião Bram", "t": "Plante a Lágrima da Lua no mapa. A Árvore de Mana espera por você no Santuário."}])
	elif not Game.lands.has("forest"):
		say([{"n": "Ancião Bram", "t": "Siga a estrada a leste para abrir o mapa do mundo. Escolha um espaço vazio e plante a Semente Verdejante."}])
	else:
		say([{"n": "Ancião Bram", "t": "Dizem que o Carvalho Ancião teme o fogo. Use a Chama, mas cuidado com as raízes que brotam do chão."}])


static func farmer() -> void:
	if not Game.flags.get("met_farmer", false):
		Game.flags["met_farmer"] = true
		say([
			{"n": "Lina", "t": "As abóboras cresceram tanto este ano! Meu avô diz que é a mana do solo."},
			{"n": "Lina", "t": FARM_TIPS[0]},
		])
	else:
		say([{"n": "Lina", "t": FARM_TIPS[randi() % FARM_TIPS.size()]}])


static func innkeeper() -> void:
	say([{"n": "Borin", "t": "Bem-vindo ao Javali Dourado! O que vai ser?", "ch": [
		{"l": "Descansar (10 ouro)", "f": _rest},
		{"l": "Poção (15 ouro)", "f": _buy_potion},
		{"l": "Nada, obrigado", "f": _nothing},
	]}])


static func _rest() -> void:
	if Game.gold < 10:
		say([{"n": "Borin", "t": "Hmm, faltam moedas. Volte quando tiver 10 de ouro."}])
		return
	Game.gold -= 10
	Game.hp = Game.max_hp
	Game.mp = Game.max_mp
	Game.stats_changed.emit()
	Sfx.play("heal")
	Game.save_game()
	say([{"n": "Borin", "t": "Durma bem! ...Pronto, você parece novo em folha."}])


static func _buy_potion() -> void:
	if Game.gold < 15:
		say([{"n": "Borin", "t": "Uma poção custa 15 de ouro, amigo."}])
		return
	Game.gold -= 15
	Game.potions += 1
	Game.stats_changed.emit()
	Sfx.play("coin")
	Game.save_game()
	say([{"n": "Borin", "t": "Aqui está. Você tem %d poções agora." % Game.potions}])


static func _nothing() -> void:
	pass


static func bard() -> void:
	say([
		{"n": "Tomé, o bardo", "t": "♪ Sob a lua de prata, a espada canta, e a semente dorme até que alguém a plante... ♪"},
		{"n": "Tomé, o bardo", "t": "Já estou compondo uma balada sobre sua vitória no bosque!" if Game.flags.get("boss_defeated", false) else "O Carvalho Ancião foi o primeiro guardião. Se ele caiu na sombra, ninguém está seguro."},
	])


static func fairy() -> void:
	if not Game.spells.has("ice"):
		say([
			{"n": "Nix", "t": "Psiu! Sou Nix, uma sprite de orvalho. Você sente? A mana pulsa mais forte perto de você."},
			{"n": "Nix", "t": "Deixe-me te ensinar a Geada. Três lascas de gelo que deixam qualquer criatura lenta!"},
		], func(): Game.learn("ice"))
	else:
		say([{"n": "Nix", "t": "A Árvore floresceu! Sinto cócegas nas asas de tanta mana." if Game.flags.get("ending", false) else "Magia gasta mana, a barra azul. Ela se recupera sozinha, devagarinho."}])


static func sign_road() -> void:
	say([{"n": "Placa", "t": "→ Estrada para o Mapa do Mundo. Artefatos plantados ali despertam novas terras."}])


static func well() -> void:
	say([{"n": "Poço antigo", "t": "Você joga uma pedrinha. O eco responde de muito longe: \"...Aetheria...\""}])


static func mana_tree() -> void:
	if Game.flags.get("ending", false):
		say([{"n": "Árvore de Mana", "t": "Obrigada, pequeno guardião. Enquanto você lembrar de mim, eu florescerei."}])
		return
	say([
		{"n": "Árvore de Mana", "t": "...Kael. Eu ouvi seus passos desde a vila. Cada terra que você plantou devolveu um pouco da minha luz."},
		{"n": "Árvore de Mana", "t": "A sombra se alimentava do esquecimento. Você lembrou de nós, e isso bastou."},
		{"n": "Árvore de Mana", "t": "Receba minha bênção. Que Aetheria floresça outra vez!"},
	], func(): main.start_ending())


static func intro() -> void:
	say([
		{"n": "", "t": "Em Aetheria, as terras dormem dentro de artefatos. Quem os planta no mapa do mundo faz a terra renascer."},
		{"n": "", "t": "Mas a Árvore de Mana, coração de todas elas, começou a murchar..."},
		{"n": "", "t": "Fale com o Ancião Bram, perto da casinha de telhado azul."},
	])


static func boss_defeated() -> void:
	say([{"n": "", "t": "A sombra se dissolve em luz. O Carvalho Ancião volta a dormir em paz, e algo cintilante cai de seus galhos."}], func(): Game.give_artifact("tear"))
