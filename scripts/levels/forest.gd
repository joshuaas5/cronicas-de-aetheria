extends Level
## Bosque Sussurrante (entrance) and Clareira do Carvalho (boss clearing).

var clearing := false
var path_pts := []
var _noise := FastNoiseLite.new()


func _init(is_clearing := false) -> void:
	clearing = is_clearing
	_noise.seed = 31 if not clearing else 57
	_noise.frequency = 0.05
	if clearing:
		id = "forest2"
		display_name = "Clareira do Carvalho"
		bounds = Rect2(-22, -10, 44, 22)
		cam_bounds = Rect2(-10, -2, 20, 6)
		path_pts = [Vector2(-40, 3), Vector2(-18, 3), Vector2(-8, 4), Vector2(0, 4.5), Vector2(8, 3), Vector2(20, 1)]
		spawns = {"west": [Vector3(-19, 0, 3), PI * 0.5], "default": [Vector3(0, 0, 8), PI]}
		exits = [{"rect": Rect2(-24, -2, 3, 10), "to": "forest1", "spawn": "east", "arrow": Vector3(-21, 0, 3)}]
	else:
		id = "forest1"
		display_name = "Bosque Sussurrante"
		bounds = Rect2(-32, -8, 64, 18)
		cam_bounds = Rect2(-22, -3, 44, 8)
		path_pts = [Vector2(-44, 5), Vector2(-24, 4.2), Vector2(-10, 2.5), Vector2(4, 0.8), Vector2(16, 0), Vector2(28, -0.6), Vector2(44, -1)]
		spawns = {"west": [Vector3(-29, 0, 4.5), PI * 0.5], "east": [Vector3(29, 0, -0.5), -PI * 0.5], "default": [Vector3(-26, 0, 4.2), PI * 0.5]}
		exits = [
			{"rect": Rect2(-34, 0, 3, 9), "to": "map", "spawn": "", "arrow": Vector3(-31, 0, 4.5)},
			{"rect": Rect2(31, -5, 3, 9), "to": "forest2", "spawn": "west", "arrow": Vector3(31, 0, -0.5)},
		]
	music = "forest"
	ambience = "forest"
	land = "forest"
	cam_offset = Vector3(0, 9.0, 23.0)
	cam_fov = 30.0
	cam_look_height = 1.6


func height_at(x: float, z: float) -> float:
	var b := bounds.grow(1.5)
	var back: float = max(0.0, b.position.y - z)
	var side: float = max(0.0, max(b.position.x - x, x - b.end.x))
	var front: float = max(0.0, z - b.end.y)
	var rise: float = pow(min(back / 12.0, 1.4), 1.6) * 7.0 + pow(min(side / 10.0, 1.4), 1.6) * 6.0 + min(front / 10.0, 1.0) * 1.2
	var n := _noise.get_noise_2d(x, z)
	return rise * (0.75 + n * 0.5) + n * 0.12


func _weights(x: float, z: float) -> Color:
	var d := dist_to_path(Vector2(x, z), path_pts)
	var path_w: float = clamp(1.0 - (d - 1.0) / 1.2, 0.0, 1.0)
	var h := height_at(x, z)
	var rock: float = clamp((h - 2.5) / 2.0, 0.0, 1.0) * clamp(abs(_noise.get_noise_2d(x * 3.0, z * 3.0)) * 3.0, 0.0, 1.0)
	var moss: float = clamp(0.75 + _noise.get_noise_2d(x * 0.7 + 40.0, z * 0.7) * 1.2, 0.0, 1.0)
	var rest: float = max(0.0, 1.0 - path_w - rock)
	return Color(rest * (1.0 - moss), rest * moss, path_w, rock)


func build() -> void:
	var cor := clearing
	env = Env.environment(self, {
		"hdri": "sunset_forest" if cor else "forest_slope",
		"sky_energy": 0.9 if cor else 1.0,
		"exposure": 0.95,
		"ambient": 0.7,
		"sun_color": Color(1.0, 0.72, 0.62) if cor else Color(1.0, 0.88, 0.66),
		"sun_energy": 1.8 if cor else 2.6,
		"sun_rot": Vector3(-40, -48, 0) if cor else Vector3(-50, -38, 0),
		"fog_color": Color(0.5, 0.42, 0.6) if cor else Color(0.55, 0.66, 0.58),
		"fog_density": 0.005,
		"vol_density": 0.016 if cor else 0.01,
		"vol_color": Color(0.8, 0.7, 0.95) if cor else Color(0.9, 0.95, 0.88),
		"saturation": 1.15 if cor else 1.3,
		"dof_far": 26.0,
	})
	Env.terrain(self, Vector2(-70, -46), Vector2(140, 80), 0.6, height_at, _weights, [
		["forest_leaves_02", 0.35, Color(0.85, 0.8, 0.8) if cor else Color(0.95, 0.95, 0.9)],
		["leafy_grass", 0.3, Color(0.85, 0.9, 0.8)],
		["stony_dirt_path", 0.4, Color(1.35, 1.25, 1.1)],
		["mossy_rock", 0.3],
	])
	make_batches(Color(0.85, 0.7, 1.0) if cor else Color(0.95, 1.14, 0.72), Color(0.8, 0.75, 0.95) if cor else Color(0.95, 1.14, 0.78))
	_trees()
	_ground_detail()
	add_grass(Rect2(-46, -18, 92, 34), 70000, func(x, z):
		var d := dist_to_path(Vector2(x, z), path_pts)
		if d < 1.8:
			return 0.0
		var n := _noise.get_noise_2d(x * 0.8, z * 0.8)
		return clamp(0.65 + n * 1.0, 0.15, 1.0) * clamp((d - 1.8) / 1.5, 0.0, 1.0)
	, {
		"tip": Color(0.55, 0.52, 0.55) if cor else Color(0.6, 0.8, 0.22),
		"root": Color(0.08, 0.08, 0.1) if cor else Color(0.07, 0.12, 0.04),
		"seed": 3,
	})
	add_flowers(Rect2(-40, -14, 80, 28), 220 if not cor else 90, func(x, z):
		if dist_to_path(Vector2(x, z), path_pts) < 2.2:
			return 0.0
		return clamp(_noise.get_noise_2d(x * 0.5 + 30.0, z * 0.5) * 2.0 + 0.1, 0.0, 1.0)
	, Color(0.1, 0.0, 0.15) if cor else Color.BLACK)
	for mp in ([Vector3(-18, 0, -6.5), Vector3(-16.5, 0, -7.3), Vector3(12.5, 0, 8.2), Vector3(24, 0, -6.8), Vector3(-27, 0, 8.6)] if not cor else [Vector3(-15, 0, -8), Vector3(16, 0, -7.5), Vector3(-17, 0, 9), Vector3(17.5, 0, 9.5)]):
		if cor:
			Build.mushroom(self, mp, randf_range(0.9, 1.5), Color(0.55, 0.25, 1.0), 2.5)
		else:
			Build.mushroom(self, mp, randf_range(0.8, 1.6), [Color(0.92, 0.14, 0.08), Color(1.0, 0.55, 0.1)][randi() % 2])
	var flies := Fx.emitter(self, Color(2.2, 2.6, 0.9) if not cor else Color(2.0, 1.0, 2.8), 70, 6.0, 0.07, 0.25, 0.05, Vector3(28, 1.5, 9))
	flies.position = Vector3(0, 1.3, 1)
	finish_batches()
	build_walls()


func _tree_at(x: float, z: float, o := {}) -> void:
	var cor := clearing
	var opts := {"height": randf_range(13, 18), "radius": randf_range(0.55, 0.85), "crown": randf_range(4.8, 6.4), "cards": 650, "card_size": 1.35, "branches": 8}
	if cor and randf() < 0.5:
		opts["tint"] = Color(0.78, 0.62, 0.95)
	opts.merge(o, true)
	Env.tree(self, Vector3(x, height_at(x, z), z), batch_leaves, opts)


func _trees() -> void:
	seed(71 if not clearing else 97)
	# back wall of forest
	var x := bounds.position.x - 6.0
	while x < bounds.end.x + 6.0:
		_tree_at(x + randf_range(-2, 2), bounds.position.y - randf_range(2.5, 9.0))
		if randf() < 0.6:
			_tree_at(x + randf_range(-2, 2), bounds.position.y - randf_range(10, 18), {"height": randf_range(14, 19)})
		x += randf_range(3.5, 5.5)
	# sides
	for s in [-1, 1]:
		for i in 4:
			var sx: float = (bounds.position.x - randf_range(3, 9)) if s < 0 else (bounds.end.x + randf_range(3, 9))
			_tree_at(sx, randf_range(bounds.position.y, bounds.end.y + 6))
	# front framing trees at the corners only, so the camera keeps a clear view
	_tree_at(bounds.position.x - 6, bounds.end.y + 9, {"height": 17})
	_tree_at(bounds.end.x + 5, bounds.end.y + 10, {"height": 18})
	if not clearing:
		_tree_at(-13, -5.5, {"height": 13})
		_tree_at(17, 7.5, {"height": 12})
	# bushes along the forest edges
	for i in 90:
		var bx := randf_range(bounds.position.x - 6, bounds.end.x + 6)
		var bz := bounds.position.y - randf_range(-0.5, 9.0) if i % 3 != 0 else bounds.end.y + randf_range(0.5, 3.5)
		Env.bush(Vector3(bx, height_at(bx, bz), bz), batch_bush, randf_range(1.2, 2.4) if i % 3 != 0 else randf_range(0.5, 0.9), 55)


func _ground_detail() -> void:
	seed(5 if not clearing else 9)
	if clearing:
		Env.prop(self, "boulder_01", Vector3(-12, 0, -5), 1.9, 0.6)
		Env.pillar(self, Vector3(-12, 0, -5), 1.4)
		Env.prop(self, "tree_stump_02", Vector3(11, 0, -4), 1.3, 1.2)
		Env.pillar(self, Vector3(11, 0, -4), 0.8)
		Env.prop(self, "namaqualand_boulder_02", Vector3(14, 0, 8), 1.3, 2.0)
		Env.pillar(self, Vector3(14, 0, 8), 1.3)
	else:
		Env.prop(self, "boulder_01", Vector3(8, 0, -5.5), 1.8, 0.4)
		Env.pillar(self, Vector3(8, 0, -5.5), 1.4)
		Env.prop(self, "namaqualand_boulder_02", Vector3(-22, 0, 7.5), 1.2, 1.1)
		Env.pillar(self, Vector3(-22, 0, 7.5), 1.2)
		Env.prop(self, "tree_stump_01", Vector3(-3, 0, 7.2), 1.2, 0.3)
		Env.pillar(self, Vector3(-3, 0, 7.2), 0.8)
		Env.prop(self, "dead_tree_trunk_02", Vector3(-4, 0.25, -7.5), 1.3, 0.15)
		Env.wall(self, Vector3(-4, 0.6, -7.5), Vector3(5.2, 1.2, 1.2))
		Env.prop(self, "root_cluster_01", Vector3(22, 0, -8.5), 1.2, 2.2)
	for i in 110:
		var fx := randf_range(bounds.position.x - 3, bounds.end.x + 3)
		var fz := randf_range(bounds.position.y - 4, bounds.end.y + 3)
		if dist_to_path(Vector2(fx, fz), path_pts) < 2.5:
			continue
		Env.prop(self, "fern_02", Vector3(fx, height_at(fx, fz), fz), randf_range(0.9, 1.5), randf() * TAU, "", false)
	for i in 20:
		var rx := randf_range(bounds.position.x, bounds.end.x)
		var rz := randf_range(bounds.position.y - 2, bounds.end.y + 2)
		Env.prop(self, "rock_07", Vector3(rx, height_at(rx, rz), rz), randf_range(2.0, 5.0), randf() * TAU, "", false)


func on_enter() -> void:
	var m := main()
	var p: Vector3 = m.player.global_position if m.player.get_parent() else Vector3.ZERO
	seed(Time.get_ticks_msec())
	if clearing:
		if not Game.flags.get("boss_defeated", false):
			var b := Boss.new()
			add_child(b)
			b.global_position = Vector3(0, 0, -4.5)
			m.on_boss_spawned(b)
		else:
			for i in 3:
				m.spawn_enemy("warrior", random_point(p, 9.0), false)
			m.spawn_enemy("mage", random_point(p, 10.0), true)
	else:
		for i in 4:
			m.spawn_enemy("minion", random_point(p, 9.0))
		m.spawn_enemy("rogue", random_point(p, 10.0))
		if Game.flags.get("boss_defeated", false):
			m.spawn_enemy("mage", random_point(p, 10.0))
