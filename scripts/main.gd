extends Node
## Game flow: title, level loading with fades, camera, exits, dialogs, pause,
## defeat, ending and the world map.
##
## Test flags (after `--`): --level=<id> --spawn=<name> --q=<0..2> --shot=<png> --frames=<n>
##   --cam=x,y,z --fov=<deg> --dx=<m> --dz=<m> --flags=a,b --arts=seed,tear --say=<npc>

const LEVELS := {
	"village": "res://scripts/levels/village.gd",
	"tavern": "res://scripts/levels/tavern.gd",
	"forest1": "res://scripts/levels/forest.gd",
	"forest2": "res://scripts/levels/forest.gd",
	"sanctuary": "res://scripts/levels/sanctuary.gd",
	"map": "res://scripts/levels/worldmap.gd",
	"rift": "res://scripts/levels/rift.gd",
}

var ui: GameUI
var level: Level
var player: Player
var camera: Camera3D
var state := "boot"       # boot | title | play | map | busy
var paused := false
var trauma := 0.0
var exit_cd := 0.0
var cam_focus := Vector3.ZERO
var title_t := 0.0
var fp := false
var fp_pitch := -0.1
var viewmodel: Node3D
var vm_swing := 0.0
var streak := 0
var streak_t := 0.0
var streak_xp := 0
var args := {}


func _ready() -> void:
	add_to_group("main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	Story.main = self
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Env.quality = int(args.get("q", str(_saved_quality())))
	ui = GameUI.new()
	add_child(ui)
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	player = Player.new()
	player.main = self
	player.died.connect(_on_player_died)
	if args.has("level"):
		_test_boot()
	else:
		_to_title()
		if args.has("shot"):
			_take_shot()


func _saved_quality() -> int:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		return int(cf.get_value("video", "quality", 2))
	return 2


func _save_quality() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "quality", Env.quality)
	cf.save("user://settings.cfg")


# ---------------------------------------------------------------- flow

func _to_title() -> void:
	state = "busy"
	_load_level("forest1", "", false)
	player.visible = false
	player.frozen = true
	ui.mode = "title"
	_title_menu()
	Sfx.music("title")
	Sfx.ambience("forest")
	state = "title"
	ui.fade = 1.0
	create_tween().tween_property(ui, "fade", 0.0, 1.5)


func _title_menu() -> void:
	var items := []
	if Game.has_save():
		items.append({"id": "continue", "label": "Continuar"})
	items.append({"id": "new", "label": "Novo jogo"})
	items.append({"id": "quality", "label": "Qualidade: " + ["Baixa", "Alta", "Ultra"][Env.quality]})
	items.append({"id": "quit", "label": "Sair"})
	ui.open_menu("", items)


func _start(cont: bool) -> void:
	state = "busy"
	if cont and Game.load_game():
		var lid := Game.current_level
		if lid == "map":
			lid = "village"
		go(lid, "")
	else:
		Game.new_game()
		go("village", "start", func(): Story.intro())


func _test_boot() -> void:
	Game.new_game()
	for f in String(args.get("flags", "")).split(",", false):
		Game.flags[f] = true
	for a in String(args.get("arts", "")).split(",", false):
		Game.arts.append(a)
	if args.has("lands"):
		Game.lands["forest"] = Vector2i(3, 0)
		Game.lands["sanctuary"] = Vector2i(2, 2)
	if args.has("spells"):
		Game.spells = ["fire", "ice", "heal", "bolt"]
	if args.has("cls"):
		Game.classes = Game.CLASSES.keys()
		Game.cls = args["cls"]
	if args.has("allskills"):
		Game.skills = Game.SKILLS.keys()
	Game.recalc()
	Game.hp = Game.max_hp
	Game.mp = Game.max_mp
	if args.has("savetest"):
		for i in 12:
			Game.add_item(Items.generate(10, i % 5))
		Game.equip(3)
		Game.dust = 42
		Game.torment = 2
		Game.best_rift = 7
		var before := [Game.inventory.size(), Game.equipment.size(), int(Game.atk), int(Game.max_hp)]
		Game.save_game()
		Game.new_game()
		var ok := Game.load_game()
		print("SAVETEST ok=%s before=%s after=%s dust=%d torment=%d best=%d" % [ok, before, [Game.inventory.size(), Game.equipment.size(), int(Game.atk), int(Game.max_hp)], Game.dust, Game.torment, Game.best_rift])
		get_tree().quit()
		return
	if args.has("rift"):
		Game.rift_level = int(args["rift"])
	_load_level(args["level"], args.get("spawn", ""), true)
	state = "map" if args["level"] == "map" else "play"
	ui.mode = "map" if state == "map" else "play"
	if args.has("gold"):
		Game.gold = int(args["gold"])
	if args.has("lvl"):
		Game.lvl = int(args["lvl"])
		Game.recalc()
	if args.has("say"):
		Callable(Story, args["say"]).call()
	if args.has("strong"):
		Game.lvl = 16
		Game.essence = 30
		Game.recalc()
		Game.hp = Game.max_hp
	if args.has("loot"):
		for i in 30:
			Game.add_item(Items.generate(Game.lvl + 8, [0, 1, 1, 2, 2, 2, 3, 3][i % 8]))
		Game.equip(6)
		Game.equip(3)
		Game.dust = 57
	if args.has("inv"):
		_open_inventory()
		ui.inv_sel = 14
	if args.has("fp"):
		set_first_person(true)
	if args.has("god"):
		player.god = true
	if args.has("elites"):
		var pp := player.global_position
		_spawn("warrior", pp + Vector3(4, 0, -3), "rare", Game.lvl, ["molten", "shielded"])
		for i in 3:
			_spawn("minion", pp + Vector3(6 + i, 0, -2), "champion", Game.lvl, ["fast"])
		for i in 4:
			drop_item(pp + Vector3(-3 + i * 2, 0, 2), Game.lvl, 5.0, [1, 2, 3, 4][i])
	if args.has("tree"):
		Game.essence = 5
		Game.skills = ["s_edge", "s_crit", "m_flow", "v_root", "v_potion"]
		ui.tree_sel = "m_blaze"
		_open_tree()
	if args.has("shot"):
		_take_shot()
	elif args.has("seconds"):
		await get_tree().create_timer(float(args["seconds"])).timeout
		if level and level.id == "rift":
			print("RIFT progress=%.0f guardian=%s finished=%s time=%.0f ghp=%s atk=%d" % [level.rift_progress, level.guardian_spawned, level.finished, level.time_left, str(level.guardian.hp) + "/" + str(level.guardian.max_hp) if is_instance_valid(level.guardian) else "-", Game.atk])
		for b in get_tree().get_nodes_in_group("boss"):
			print("BOSS hp=", b.hp, " state=", b.state, " pos=", b.global_position, " player=", player.global_position)
		print("AUTOPLAY END level=%s hp=%d lvl=%d xp=%d gold=%d enemies=%d flags=%s arts=%s lands=%s cls=%s classes=%s tier=%d skills=%d rift_best=%d inv=%s" % [Game.current_level, Game.hp, Game.lvl, Game.xp, Game.gold, get_tree().get_nodes_in_group("enemies").size(), str(Game.flags), str(Game.arts), str(Game.lands), Game.cls, str(Game.classes), Game.weapon_tier, Game.skills.size(), Game.best_rift, str(Game.inventory.map(func(it): return int(it["rarity"])))])
		get_tree().quit()


func _take_shot() -> void:
	if args.has("dx") or args.has("dz"):
		player.global_position += Vector3(float(args.get("dx", "0")), 0, float(args.get("dz", "0")))
	if args.has("cam"):
		var c: PackedStringArray = args["cam"].split(",")
		level.cam_offset = Vector3(float(c[0]), float(c[1]), float(c[2]))
	if args.has("fov"):
		level.cam_fov = float(args["fov"])
	_snap_camera()
	for i in int(args.get("frames", "120")):
		await get_tree().process_frame
	var tm := Time.get_ticks_usec()
	for i in 30:
		await get_tree().process_frame
	var avg := (Time.get_ticks_usec() - tm) / 30000.0
	var img := get_viewport().get_texture().get_image()
	img.save_png(args["shot"])
	print("SHOT avg frame %.1f ms (%.0f fps) size %s prims %d" % [avg, 1000.0 / avg, str(img.get_size()), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()


## Fade out, swap level, fade in.
func go(id: String, spawn := "", after := Callable()) -> void:
	print("GO ", id, " from ", player.global_position if player.is_inside_tree() else Vector3.ZERO)
	state = "busy"
	player.frozen = true
	var tw := create_tween()
	tw.tween_property(ui, "fade", 1.0, 0.45)
	await tw.finished
	_load_level(id, spawn, true)
	state = "map" if id == "map" else "play"
	ui.mode = "map" if id == "map" else "play"
	if id != "map":
		player.frozen = false
		ui.banner(level.display_name)
	var tw2 := create_tween()
	tw2.tween_property(ui, "fade", 0.0, 0.6)
	if after.is_valid():
		after.call()


func _load_level(id: String, spawn: String, with_player: bool) -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	get_tree().call_group("projectiles", "queue_free")
	if level:
		level.queue_free()
		level = null
	if id != "rift":
		Game.rift_level = 0
	var script = load(LEVELS[id])
	if id == "forest1" or id == "forest2":
		level = script.new(id == "forest2")
	else:
		level = script.new()
	add_child(level)
	level.build()
	camera.fov = level.cam_fov
	camera.attributes = level.env.get("cam_attr")
	ui.boss = null
	exit_cd = 0.6
	if id != "map":
		Game.current_level = id
		if level.land != "":
			Game.map_here = level.land
	if with_player and id != "map":
		var sp: Array = level.spawns.get(spawn, level.spawns.get("default"))
		level.add_child(player)
		player.global_position = sp[0]
		player.face(Vector3(sin(sp[1]), 0, cos(sp[1])))
		player.model.rotation.y = sp[1]
		player.visible = true
		player.revive()
	if with_player and not args.has("peace"):
		level.on_enter()
	Sfx.music(level.music)
	Sfx.ambience(level.get("ambience") if level.get("ambience") != null else "")
	_snap_camera()
	if id != "map":
		Game.save_game()


func _snap_camera() -> void:
	cam_focus = _focus_target()
	_place_camera(0.0)


# ---------------------------------------------------------------- per frame

func _autoplay(dt: float) -> void:
	# test-only bot: chase enemies, swing, cast, dodge and click through dialogs
	title_t += dt
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "magic", "dodge", "interact", "spell_next"]:
		Input.action_release(a)
	if ui.dialog_active() or ui.mode in ["gameover", "ending"]:
		if int(title_t * 4.0) % 2 == 0:
			Input.action_press("interact")
		return
	if state == "map" and level and level.has_method("map_input"):
		if level.cursor != Vector2i(3, 0):
			level.cursor = Vector2i(3, 0)
		elif Game.arts.size() > 0 and int(title_t * 2.0) % 2 == 0:
			Input.action_press("interact")
		return
	if player.get_parent() == null:
		return
	if fmod(title_t, 4.0) < dt:
		for i in range(Game.inventory.size() - 1, -1, -1):
			var it: Dictionary = Game.inventory[i]
			var cur = Game.equipped_for(it)
			if cur == null or Items.score(it) > Items.score(cur):
				Game.equip(i)
				break
	var targets := get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("boss")
	var best: Node3D = null
	var bd := 1e9
	for e in targets:
		if e.is_alive():
			var d: float = e.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = e
	if best == null:
		return
	var dir: Vector3 = best.global_position - player.global_position
	dir.y = 0
	if bd > 2.2:
		Input.action_press("move_right" if dir.x > 0 else "move_left", clamp(abs(dir.x) / dir.length(), 0.0, 1.0))
		Input.action_press("move_down" if dir.z > 0 else "move_up", clamp(abs(dir.z) / dir.length(), 0.0, 1.0))
	elif int(title_t * 6.0) % 2 == 0:
		Input.action_press("attack")
	if fmod(title_t, 3.0) < dt:
		Input.action_press("magic")
	if fmod(title_t, 7.0) < dt:
		Input.action_press("spell_next")
	if fmod(title_t, 5.0) < dt:
		Input.action_press("dodge")


func _process(dt: float) -> void:
	if args.has("autoplay"):
		_autoplay(dt)
	match state:
		"title":
			_title_update(dt)
		"play":
			_play_update(dt)
		"map":
			if ui.dialog_active():
				ui.dialog_input()
			elif level and level.has_method("map_input"):
				level.map_input()
	if Input.is_action_just_pressed("mute"):
		Sfx.toggle_mute()
		ui.toast("Som desligado" if Sfx.muted else "Som ligado")
	if level and state != "title":
		cam_focus = cam_focus.lerp(_focus_target(), 1.0 - exp(-dt * 5.0))
		_place_camera(dt)
	_update_grass()


func _title_update(dt: float) -> void:
	title_t += dt
	cam_focus = Vector3(-4.0 + sin(title_t * 0.06) * 5.0, 0, 0.5)
	_place_camera(dt)
	var c := ui.menu_input()
	match c:
		"continue":
			_start(true)
		"new":
			_start(false)
		"quality":
			Env.quality = (Env.quality + 1) % 3
			_save_quality()
			_title_menu()
			ui.menu_sel = ui.menu_items.size() - 2
			ui.toast("Qualidade aplicada ao carregar a próxima área")
		"quit":
			get_tree().quit()


func _play_update(dt: float) -> void:
	if ui.mode == "gameover":
		if ui.gameover_t > 1.2 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
			Game.hp = Game.max_hp
			Game.mp = Game.max_mp
			Game.gold = Game.gold / 2
			ui.mode = "play"
			go("village", "start")
		return
	if ui.mode == "ending":
		player.frozen = true
		if ui.ending_t > 8.0 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
			ui.mode = "play"
			player.frozen = false
			ui.banner("Aetheria floresce")
		return
	if ui.mode == "tree":
		_tree_update()
		return
	if ui.mode == "inv":
		_inv_update()
		return
	if paused:
		var c := ui.menu_input()
		if Input.is_action_just_pressed("pause") or c == "resume":
			_set_paused(false)
		elif c == "quality":
			Env.quality = (Env.quality + 1) % 3
			_save_quality()
			_pause_menu()
			ui.menu_sel = 2
			ui.toast("Qualidade aplicada ao carregar a próxima área")
		elif c == "title":
			Game.save_game()
			_set_paused(false)
			_to_title()
		elif c == "tree":
			_open_tree()
		return
	if ui.dialog_active():
		player.frozen = true
		ui.dialog_input()
		if not ui.dialog_active() and state == "play" and ui.mode == "play":
			player.frozen = false
		return
	if Input.is_action_just_pressed("pause"):
		_set_paused(true)
		return
	if Input.is_action_just_pressed("tree"):
		_open_tree()
		return
	if Input.is_action_just_pressed("inventory"):
		_open_inventory()
		return
	if Input.is_action_just_pressed("view"):
		set_first_person(not fp)
	if streak_t > 0.0:
		streak_t -= dt
		ui.streak = streak
		if streak_t <= 0.0:
			if streak >= 5:
				var bonus := int(streak_xp * 0.05 * streak / 5.0)
				ui.toast("Massacre x%d  ·  +%d XP" % [streak, bonus])
				if Game.gain_xp(bonus):
					_level_up_fx()
			streak = 0
			streak_xp = 0
			ui.streak = 0
	if fp and viewmodel:
		vm_swing = max(0.0, vm_swing - dt * 4.0)
	# interaction prompt
	var t := _nearest_talkable()
	ui.prompt = ("Espaço — " + ("Falar com " if t is Npc else "Examinar ") + t.display_name) if t else ""
	# exits
	exit_cd -= dt
	if exit_cd <= 0.0 and not level.exits_locked and player.state == "move":
		var p := Vector2(player.global_position.x, player.global_position.z)
		for x in level.exits:
			if (x["rect"] as Rect2).has_point(p):
				exit_cd = 1.0
				go(x["to"], x["spawn"])
				break


func _set_paused(v: bool) -> void:
	paused = v
	get_tree().paused = v
	ui.mode = "pause" if v else "play"
	if v:
		_pause_menu()
	Sfx.play("blip")


func _pause_menu() -> void:
	ui.open_menu("", [
		{"id": "resume", "label": "Continuar"},
		{"id": "tree", "label": "Árvore de Mana"},
		{"id": "quality", "label": "Qualidade: " + ["Baixa", "Alta", "Ultra"][Env.quality]},
		{"id": "title", "label": "Salvar e voltar ao título"},
	])


func _nearest_talkable() -> Node:
	if player.get_parent() == null:
		return null
	var best: Node = null
	var bd := 1e9
	for n in get_tree().get_nodes_in_group("talkable"):
		if n.can_talk(player.global_position):
			var d: float = n.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = n
	return best


func try_interact() -> bool:
	var t := _nearest_talkable()
	if t == null:
		return false
	var d: Vector3 = t.global_position - player.global_position
	player.face(d)
	t.interact()
	return true


# ---------------------------------------------------------------- camera

func _focus_target() -> Vector3:
	if player.get_parent() and player.visible:
		return player.global_position
	return level.spawns.get("default", [Vector3.ZERO, 0])[0] if level else Vector3.ZERO


func _place_camera(dt: float) -> void:
	if fp and player.get_parent() and state == "play":
		_place_fp_camera(dt)
		return
	var b := level.cam_bounds
	var f: Vector3 = Vector3(clamp(cam_focus.x, b.position.x, b.end.x), 0, clamp(cam_focus.z, b.position.y, b.end.y))
	if state == "title":
		f = cam_focus
	var target := f + Vector3(0, level.cam_look_height, 0)
	var pos := target + level.cam_offset
	trauma = max(0.0, trauma - dt * 1.8)
	var s := trauma * trauma
	var t := Time.get_ticks_msec() / 1000.0
	var shake := Vector3(sin(t * 47.0), sin(t * 53.0 + 1.3), sin(t * 41.0 + 2.1)) * s * 0.35
	camera.global_position = pos + shake
	camera.look_at(target + shake * 0.5, Vector3.UP)
	camera.fov = level.cam_fov


func shake(amount: float) -> void:
	trauma = min(1.0, trauma + amount)


func hitstop(d: float) -> void:
	Engine.time_scale = 0.06
	await get_tree().create_timer(d, true, false, true).timeout
	Engine.time_scale = 1.0


func _update_grass() -> void:
	if level == null or player.get_parent() == null:
		return
	for m in level.grass_materials:
		m.set_shader_parameter("player_pos", player.global_position)


# ---------------------------------------------------------------- combat events

func spawn_enemy(type: String, pos: Vector3, elite := false) -> Enemy:
	var e := Enemy.new().setup(type, elite)
	level.add_child(e)
	e.global_position = pos
	return e


func on_enemy_killed(e: Enemy) -> void:
	Game.kills += 1
	var t: Dictionary = Enemy.TYPES[e.type]
	var rank_gold: float = {"normal": 1.0, "minion": 1.5, "champion": 4.0, "rare": 7.0, "goblin": 12.0}[e.rank]
	var g: int = int(randi_range(t["gold"][0], t["gold"][1]) * rank_gold * (1.0 + e.mlvl * 0.15))
	var coins: int = clamp(g / 6, 1, 14 if e.rank == "goblin" else 5)
	for i in coins:
		_drop("coin", e.global_position, int(ceil(float(g) / coins)))
	if randf() < (0.35 if Game.has_skill("v_potion") else 0.2):
		_drop("heart", e.global_position)
	elif randf() < 0.2:
		_drop("mana", e.global_position)
	# items
	var luck := Game.magic_find()
	var count = 1 if randf() < 0.2 else 0
	match e.rank:
		"minion":
			count = 1 if randf() < 0.35 else 0
		"champion":
			count = 1 + (1 if randf() < 0.4 else 0)
			luck += 1.5
		"rare":
			count = 2 + (1 if randf() < 0.5 else 0)
			luck += 2.5
		"goblin":
			count = randi_range(4, 7)
			luck += 3.0
	if e.elite and Game.legend("crown"):
		count += 1
	for i in count:
		drop_item(e.global_position, e.mlvl, luck)
	if Game.legend("corpse"):
		Fx.burst(level, e.global_position + Vector3(0, 0.8, 0), Color(0.95, 0.92, 0.85), 30, 7.0, 0.6, 0.12, -10.0, false)
		for o in get_tree().get_nodes_in_group("enemies"):
			if o.is_alive() and o.global_position.distance_to(e.global_position) < 3.2:
				player.deal(o, Game.atk * 0.8, (o.global_position - e.global_position).normalized() * 6.0, "sword", false)
	if level.has_method("on_kill"):
		level.on_kill(e)
	# kill streak
	streak += 1
	streak_t = 2.2
	streak_xp += e.xp
	if Game.gain_xp(e.xp):
		_level_up_fx()


## Drops a random item scaled to `ilvl`.
func drop_item(pos: Vector3, ilvl: int, luck: float, rarity := -1, slot := "") -> void:
	var r = rarity if rarity >= 0 else Items.roll_rarity(luck)
	var it := Items.generate(ilvl, r, slot)
	var l := Loot.new().setup(it)
	level.add_child(l)
	l.global_position = pos + Vector3(0, 1.0, 0)


## Spawns a pack at `pos`: plain monsters, a champion pack, or a rare with escorts.
func spawn_pack(pos: Vector3, mlvl: int, types: Array) -> void:
	var roll := randf()
	var tm := float(Game.torment)
	var champ_chance := 0.14 + tm * 0.02
	var rare_chance := 0.08 + tm * 0.015
	var keys := Enemy.AFFIX_NAMES.keys()
	if roll < rare_chance:
		keys.shuffle()
		var aff = keys.slice(0, 2 + (1 if tm >= 3 else 0))
		_spawn(types[randi() % types.size()], pos, "rare", mlvl, aff)
		for i in 3:
			_spawn(types[randi() % types.size()], pos + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)), "minion", mlvl, [])
	elif roll < rare_chance + champ_chance:
		keys.shuffle()
		var aff = keys.slice(0, 1 + (1 if tm >= 2 else 0))
		var ty: String = types[randi() % types.size()]
		for i in 3:
			_spawn(ty, pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), "champion", mlvl, aff)
	else:
		for i in randi_range(3, 5):
			_spawn(types[randi() % types.size()], pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), "normal", mlvl, [])
	if randf() < 0.05 + tm * 0.005:
		_spawn("goblin", pos + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), "goblin", mlvl, [])


func _spawn(type: String, pos: Vector3, rank: String, mlvl: int, aff: Array) -> Enemy:
	var b := level.bounds.grow(-1.0)
	pos.x = clamp(pos.x, b.position.x, b.end.x)
	pos.z = clamp(pos.z, b.position.y, b.end.y)
	var e := Enemy.new().setup(type, false, rank, mlvl, aff)
	level.add_child(e)
	e.global_position = pos
	return e


func _drop(kind: String, pos: Vector3, value := 1) -> void:
	var p := Pickup.new().setup(kind, value)
	level.add_child(p)
	p.global_position = pos + Vector3(0, 0.8, 0)


func _level_up_fx() -> void:
	Sfx.play("level")
	Fx.number(level, player.global_position + Vector3(0, 2.6, 0), "NÍVEL %d!" % Game.lvl, Color(1.0, 0.88, 0.45), 90)
	Fx.burst(level, player.global_position + Vector3(0, 0.2, 0), Color(2.6, 2.1, 0.9), 80, 4.0, 1.4, 0.16, 2.0, true, 35.0)
	Fx.flash(level, player.global_position + Vector3(0, 1.5, 0), Color(1, 0.9, 0.6), 5.0, 8.0, 1.0)


func on_boss_spawned(b: Boss) -> void:
	ui.boss = b
	level.exits_locked = true
	Sfx.music("boss")
	b.defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	ui.boss = null
	level.exits_locked = false
	var first_kill: bool = not Game.flags.get("boss_defeated", false)
	var bpos := Vector3(0, 0, -2.5)
	for i in 5:
		drop_item(bpos, Game.monster_level(4), Game.magic_find() + 4.0, 3 if (i == 0 and first_kill) else -1)
	Game.flags["boss_defeated"] = true
	Game.flags["boss_torment"] = Game.torment
	Game.gold += 60
	Game.essence += 2
	ui.toast("+2 Essência de Mana")
	if Game.gain_xp(160):
		_level_up_fx()
	Sfx.music(level.music)
	player.celebrate()
	Story.boss_defeated()


func _on_player_died() -> void:
	ui.mode = "gameover"
	ui.gameover_t = 0.0
	Sfx.music("")
	Sfx.play("die")


func start_ending() -> void:
	Game.flags["ending"] = true
	Game.essence += 2
	Game.recalc()
	Game.hp = Game.max_hp
	Game.mp = Game.max_mp
	Game.save_game()
	Game.stats_changed.emit()
	Sfx.play("bloom")
	ui.mode = "ending"
	ui.ending_t = 0.0
	if level.has_method("bloom"):
		level.bloom()


# ---------------------------------------------------------------- Mana Tree

func _open_tree() -> void:
	paused = true
	get_tree().paused = true
	ui.mode = "tree"
	Sfx.play("select")


func _tree_update() -> void:
	for pair in [["move_left", Vector2.LEFT], ["move_right", Vector2.RIGHT], ["move_up", Vector2.UP], ["move_down", Vector2.DOWN]]:
		if Input.is_action_just_pressed(pair[0]):
			ui.tree_move(pair[1])
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		var id := ui.tree_sel
		if Game.buy_skill(id):
			Sfx.play("bloom")
			ui.toast("Aprendido: " + Game.SKILLS[id]["name"])
		else:
			Sfx.play("blip")
	if Input.is_action_just_pressed("tree") or Input.is_action_just_pressed("pause"):
		paused = false
		get_tree().paused = false
		ui.mode = "play"
		Sfx.play("blip")



# ---------------------------------------------------------------- first person

func set_first_person(on: bool) -> void:
	if level == null or level.id == "map":
		on = false
	fp = on
	player.fp = on
	player.model.visible = not on
	ui.fp = on
	if on:
		player.fp_yaw = player.model.rotation.y + PI
		fp_pitch = -0.08
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.attributes = null
		_make_viewmodel()
		ui.toast("Primeira pessoa  ·  mouse para olhar  ·  V para voltar")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		camera.attributes = level.env.get("cam_attr") if level else null
		if viewmodel:
			viewmodel.queue_free()
			viewmodel = null
		player.model.rotation.y = player.fp_yaw + PI


func _make_viewmodel() -> void:
	if viewmodel:
		viewmodel.queue_free()
	var path: String = {"knight": "res://assets/characters/adventurers/sword_1handed.gltf", "rogue": "res://assets/characters/adventurers/dagger.gltf", "barbarian": "res://assets/characters/skeletons/Skeleton_Axe.gltf", "mage": "res://assets/characters/adventurers/staff.gltf"}[Game.cls]
	viewmodel = Node3D.new()
	camera.add_child(viewmodel)
	var w: Node3D = load(path).instantiate()
	w.rotation_degrees = Vector3(-60, 20, -10)
	w.scale = Vector3.ONE * 0.55
	viewmodel.add_child(w)
	viewmodel.position = Vector3(0.38, -0.42, -0.75)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not player.swung.is_connected(_on_swing):
		player.swung.connect(_on_swing)


func _on_swing(big: bool) -> void:
	vm_swing = 1.0 if not big else 1.3


func _input(event: InputEvent) -> void:
	if fp and state == "play" and not paused and ui.mode == "play" and event is InputEventMouseMotion:
		player.fp_yaw -= event.relative.x * 0.0028
		fp_pitch = clamp(fp_pitch - event.relative.y * 0.0024, -1.2, 1.0)
	if ui.mode == "inv" and event is InputEventMouseMotion:
		ui.inv_hover(ui.canvas.get_local_mouse_position())
	if ui.mode == "inv" and event is InputEventMouseButton and event.pressed:
		ui.inv_hover(ui.canvas.get_local_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			_inv_activate()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_inv_salvage()


func _place_fp_camera(dt: float) -> void:
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(rx) > 0.15:
		player.fp_yaw -= rx * dt * 2.8
	if abs(ry) > 0.15:
		fp_pitch = clamp(fp_pitch - ry * dt * 2.2, -1.2, 1.0)
	trauma = max(0.0, trauma - dt * 1.8)
	var s := trauma * trauma
	var t := Time.get_ticks_msec() / 1000.0
	var bob: float = sin(t * 11.0) * 0.035 * clamp(player.velocity.length() / 5.0, 0.0, 1.0)
	camera.global_position = player.global_position + Vector3(0, 1.62 + bob, 0) + Vector3(sin(t * 47.0), sin(t * 53.0), 0) * s * 0.12
	camera.rotation = Vector3(fp_pitch, player.fp_yaw, 0)
	camera.fov = 78.0
	if viewmodel:
		var sw := vm_swing
		viewmodel.rotation = Vector3(-sw * 1.2, sw * 0.9, sw * 0.6)
		viewmodel.position = Vector3(0.38 - sw * 0.25, -0.42 + bob * 0.5 + sw * 0.1, -0.75 - sw * 0.2)


# ---------------------------------------------------------------- inventory

func _open_inventory() -> void:
	paused = true
	get_tree().paused = true
	ui.mode = "inv"
	ui.inv_sel = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("select")


func _close_inventory() -> void:
	paused = false
	get_tree().paused = false
	ui.mode = "play"
	if fp:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_make_viewmodel()
	Game.save_game()
	Sfx.play("blip")


func _inv_update() -> void:
	for pair in [["move_left", Vector2.LEFT], ["move_right", Vector2.RIGHT], ["move_up", Vector2.UP], ["move_down", Vector2.DOWN]]:
		if Input.is_action_just_pressed(pair[0]):
			ui.inv_move(pair[1])
	if Input.is_action_just_pressed("interact"):
		_inv_activate()
	if Input.is_action_just_pressed("salvage"):
		_inv_salvage()
	if Input.is_action_just_pressed("salvage_all"):
		var got := Game.salvage_junk()
		if got > 0:
			Sfx.play("coin")
			ui.toast("Itens comuns e mágicos desmontados  ·  +%d Pó de Mana" % got)
	if Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("pause"):
		_close_inventory()


func _inv_activate() -> void:
	var sel := ui.inv_selected()
	if sel.is_empty():
		return
	if sel["kind"] == "equip":
		Game.unequip(sel["slot"])
	else:
		Game.equip(sel["idx"])
		Sfx.play("equip")
		if fp:
			_make_viewmodel()


func _inv_salvage() -> void:
	var sel := ui.inv_selected()
	if sel.is_empty() or sel["kind"] != "bag":
		return
	var got := Game.salvage(sel["idx"])
	Sfx.play("coin")
	ui.toast("+%d Pó de Mana" % got)



func start_rift(lvl: int) -> void:
	Game.rift_level = max(1, lvl)
	go("rift", "default")
