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
		Game.spells = ["fire", "ice", "heal"]
	_load_level(args["level"], args.get("spawn", ""), true)
	state = "map" if args["level"] == "map" else "play"
	ui.mode = "map" if state == "map" else "play"
	if args.has("say"):
		Callable(Story, args["say"]).call()
	if args.has("strong"):
		Game.atk = 40
		Game.mag = 40
		Game.max_hp = 500
		Game.hp = 500
	if args.has("shot"):
		_take_shot()
	elif args.has("seconds"):
		await get_tree().create_timer(float(args["seconds"])).timeout
		for b in get_tree().get_nodes_in_group("boss"):
			print("BOSS hp=", b.hp, " state=", b.state, " pos=", b.global_position, " player=", player.global_position)
		print("AUTOPLAY END level=%s hp=%d lvl=%d xp=%d gold=%d enemies=%d flags=%s arts=%s lands=%s" % [Game.current_level, Game.hp, Game.lvl, Game.xp, Game.gold, get_tree().get_nodes_in_group("enemies").size(), str(Game.flags), str(Game.arts), str(Game.lands)])
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
	if paused:
		var c := ui.menu_input()
		if Input.is_action_just_pressed("pause") or c == "resume":
			_set_paused(false)
		elif c == "quality":
			Env.quality = (Env.quality + 1) % 3
			_save_quality()
			_pause_menu()
			ui.menu_sel = 1
			ui.toast("Qualidade aplicada ao carregar a próxima área")
		elif c == "title":
			Game.save_game()
			_set_paused(false)
			_to_title()
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
	var b := level.cam_bounds
	var f := Vector3(clamp(cam_focus.x, b.position.x, b.end.x), 0, clamp(cam_focus.z, b.position.y, b.end.y))
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
	var t: Dictionary = Enemy.TYPES[e.type]
	var g: int = randi_range(t["gold"][0], t["gold"][1]) * (2 if e.elite else 1)
	var coins: int = min(g, 4)
	for i in coins:
		_drop("coin", e.global_position, int(ceil(float(g) / coins)))
	if randf() < 0.2:
		_drop("heart", e.global_position)
	elif randf() < 0.2:
		_drop("mana", e.global_position)
	if Game.gain_xp(e.xp):
		_level_up_fx()


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
	Game.flags["boss_defeated"] = true
	Game.gold += 60
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
	Game.max_hp += 20
	Game.max_mp += 10
	Game.hp = Game.max_hp
	Game.mp = Game.max_mp
	Game.save_game()
	Game.stats_changed.emit()
	Sfx.play("bloom")
	ui.mode = "ending"
	ui.ending_t = 0.0
	if level.has_method("bloom"):
		level.bloom()
