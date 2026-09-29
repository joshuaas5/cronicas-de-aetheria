extends "res://scripts/levels/forest.gd"
## Fenda de Mana: a randomly generated arena. Kill monsters to fill the bar, then
## slay the Rift Guardian before time runs out to unlock the next level.

const TIME_LIMIT := 300.0

var rift_progress := 0.0
var time_left := TIME_LIMIT
var guardian: Enemy = null
var guardian_spawned := false
var finished := false
var _spawn_cd := 1.0
var _types := []
var _portal: Node3D


func _init() -> void:
	var corrupt := randf() < 0.5
	super._init(corrupt)
	id = "rift"
	display_name = "Fenda de Mana — Nível %d" % Game.rift_level
	music = "boss" if Game.rift_level >= 5 else "forest"
	land = ""
	_noise.seed = randi()
	bounds = Rect2(-24, -8, 48, 20)
	cam_bounds = Rect2(-12, -2, 24, 8)
	var y0 := randf_range(-2.0, 6.0)
	path_pts = [Vector2(-40, y0), Vector2(-15, randf_range(-3, 6)), Vector2(0, randf_range(-3, 6)), Vector2(15, randf_range(-3, 6)), Vector2(40, randf_range(-3, 6))]
	spawns = {"default": [Vector3(0, 0, 8), PI]}
	exits = []
	_types = [["minion", "rogue", "warrior"], ["minion", "mage", "warrior"], ["rogue", "mage", "warrior"], ["minion", "rogue", "mage", "warrior"]][randi() % 4]


func on_enter() -> void:
	exits_locked = true
	var m := main()
	var p: Vector3 = m.player.global_position
	for i in 3:
		m.spawn_pack(random_point(p, 10.0), Game.monster_level(1), _types)


func _process(dt: float) -> void:
	if finished:
		return
	var m := main()
	if m == null or m.state != "play" or m.ui.mode != "play":
		return
	time_left = max(0.0, time_left - dt)
	if not guardian_spawned:
		_spawn_cd -= dt
		var alive := get_tree().get_nodes_in_group("enemies").size()
		if _spawn_cd <= 0.0 and alive < 10 + min(Game.rift_level, 14):
			_spawn_cd = 2.5
			var p: Vector3 = m.player.global_position
			m.spawn_pack(random_point(p, 11.0), Game.monster_level(1), _types)


func on_kill(e: Enemy) -> void:
	if e == guardian:
		_complete()
		return
	if guardian_spawned:
		return
	var add: float = {"normal": 1.4, "minion": 2.0, "champion": 4.0, "rare": 8.0, "goblin": 6.0}[e.rank]
	rift_progress = min(100.0, rift_progress + add)
	if rift_progress >= 100.0:
		_spawn_guardian()


func _spawn_guardian() -> void:
	guardian_spawned = true
	var m := main()
	var keys := Enemy.AFFIX_NAMES.keys().filter(func(k): return k != "shielded" and k != "teleporter")
	keys.shuffle()
	var pos := random_point(m.player.global_position, 7.0)
	Fx.burst(self, pos + Vector3(0, 1, 0), Color(2.6, 0.8, 3.0), 150, 8.0, 1.2, 0.2, 0.0)
	Fx.flash(self, pos + Vector3(0, 2, 0), Color(0.8, 0.4, 1.0), 10.0, 14.0, 1.0)
	guardian = m._spawn("warrior", pos, "rare", Game.monster_level(1), keys.slice(0, 3))
	guardian.max_hp *= 2.5
	guardian.hp = guardian.max_hp
	guardian.dmg *= 1.4
	guardian.display = "Guardião da Fenda"
	guardian.model.scale *= 1.6
	guardian.radius *= 1.5
	m.ui.banner("Guardião da Fenda")
	m.shake(0.8)
	Sfx.play("roar")
	Sfx.music("boss")


func _complete() -> void:
	finished = true
	var m := main()
	var in_time := time_left > 0.0
	var pos := guardian.global_position
	var n := 4 + Game.rift_level / 3
	for i in n:
		m.drop_item(pos, Game.monster_level(1), Game.magic_find() + 3.0 + Game.rift_level * 0.3, 3 if i == 0 and Game.rift_level % 5 == 0 else -1)
	Game.dust += 5 + Game.rift_level * 2
	Game.essence += 1 if Game.rift_level % 3 == 0 else 0
	if in_time and Game.rift_level > Game.best_rift:
		Game.best_rift = Game.rift_level
		m.ui.toast("Fenda nível %d concluída! Nível %d liberado" % [Game.rift_level, Game.rift_level + 1])
	elif not in_time:
		m.ui.toast("Fenda concluída fora do tempo. O próximo nível continua trancado.")
	else:
		m.ui.toast("Fenda nível %d concluída!" % Game.rift_level)
	Game.save_game()
	Sfx.play("bloom")
	Sfx.music(music)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.take_damage(1e9, Vector3.ZERO, "sword")
	# return portal
	_portal = Node3D.new()
	add_child(_portal)
	_portal.global_position = Vector3(0, 0, 3)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.1
	tm.outer_radius = 1.35
	ring.mesh = tm
	ring.material_override = Env.emissive(Color(0.6, 0.4, 1.0), 4.0)
	ring.rotation.x = PI * 0.5
	ring.position.y = 1.5
	_portal.add_child(ring)
	var core := Fx.emitter(_portal, Color(1.4, 0.9, 3.0), 120, 1.5, 0.15, 0.5, 0.0, Vector3(0.8, 1.0, 0.1))
	core.position.y = 1.5
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.5, 1.0)
	l.light_energy = 3.0
	l.omni_range = 7.0
	l.position.y = 1.5
	_portal.add_child(l)
	var pt := InteractPoint.new().setup("Portal de Retorno", func(): m.go("village", "start"), 2.2, 3.2)
	_portal.add_child(pt)
