extends Level
## Santuário de Mana: moonlit glade around the scanned Mana Tree, crystals and a mirror pool.

var tree_lights: Array[OmniLight3D] = []
var blossoms: GPUParticles3D
var _noise := FastNoiseLite.new()
var _t := 0.0
const POOL := Vector2(-9.0, 4.0)


func _init() -> void:
	id = "sanctuary"
	display_name = "Santuário de Mana"
	music = "sanctuary"
	ambience = "night"
	land = "sanctuary"
	bounds = Rect2(-22, -6, 44, 18)
	cam_bounds = Rect2(-9, -1, 18, 6)
	cam_offset = Vector3(0, 7.5, 21.0)
	cam_fov = 34.0
	cam_look_height = 3.0
	_noise.seed = 4242
	_noise.frequency = 0.06
	spawns = {"south": [Vector3(0, 0, 8.5), PI], "default": [Vector3(0, 0, 8.5), PI]}
	exits = [{"rect": Rect2(-4, 11.2, 8, 3), "to": "map", "spawn": ""}]


func height_at(x: float, z: float) -> float:
	var b := bounds.grow(2.0)
	var back: float = max(0.0, b.position.y - z - 4.0)
	var side: float = max(0.0, max(b.position.x - x, x - b.end.x))
	var rise: float = pow(min(back / 12.0, 1.5), 1.6) * 7.0 + pow(min(side / 10.0, 1.4), 1.6) * 6.0
	var p := Vector2(x, z)
	var pool: float = -0.6 * clamp(1.0 - (p.distance_to(POOL) - 2.6) / 1.2, 0.0, 1.0)
	return rise * (0.8 + _noise.get_noise_2d(x, z) * 0.4) + pool


func _weights(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var stone: float = clamp(1.0 - (abs(p.distance_to(Vector2(0, -6)) - 6.5) - 0.8) / 0.6, 0.0, 1.0)
	var path: float = clamp(1.0 - (abs(x + sin(z * 0.3) * 1.2) - 1.2) / 0.8, 0.0, 1.0) * clamp((z + 1.0) / 2.0, 0.0, 1.0)
	var rock: float = clamp((height_at(x, z) - 2.0) / 2.0, 0.0, 1.0)
	var rest: float = max(0.0, 1.0 - stone - path - rock)
	return Color(rest, max(stone, path * 0.8), rock, 0.0)


func build() -> void:
	env = Env.environment(self, {
		"hdri": "qwantani_night_puresky",
		"sky_energy": 2.2,
		"exposure": 1.1,
		"ambient": 1.4,
		"sun_color": Color(0.6, 0.72, 1.0),
		"sun_energy": 0.9,
		"sun_rot": Vector3(-38, -20, 0),
		"fog_color": Color(0.12, 0.16, 0.35),
		"fog_density": 0.004,
		"vol_density": 0.01,
		"vol_color": Color(0.6, 0.7, 1.0),
		"vol_emission": Color(0.02, 0.01, 0.05),
		"saturation": 1.3,
		"glow": 1.1,
		"bloom": 0.12,
		"dof_far": 36.0,
	})
	Env.terrain(self, Vector2(-70, -55), Vector2(140, 90), 0.6, height_at, _weights, [
		["leafy_grass", 0.3, Color(0.6, 0.9, 1.0)],
		["cobblestone_floor_08", 0.35, Color(0.8, 0.85, 1.0)],
		["mossy_rock", 0.3, Color(0.7, 0.8, 1.0)],
		["mossy_rock", 0.3],
	], Color(0.3, 1.0, 0.85))
	# the Mana Tree: a real scanned tree, grown huge
	var tree := Env.prop(self, "island_tree_01", Vector3(0.6, -0.2, -7.0), 3.2, 0.4)
	for mi in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var base = mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var dup: StandardMaterial3D = base.duplicate()
				if String(base.resource_name).contains("leaves"):
					dup.albedo_color = Color(0.75, 0.85, 1.25)
					dup.emission_enabled = true
					dup.emission = Color(0.25, 0.35, 0.9)
					dup.emission_energy_multiplier = 0.35
				else:
					dup.albedo_color = Color(0.8, 0.78, 0.95)
				mi.set_surface_override_material(s, dup)
	Env.pillar(self, Vector3(0.0, 0, -6.6), 2.2, 6.0)
	# luminous blossom clusters through the crown
	var bloom_batch := Env.FoliageBatch.new(Env.foliage_mat("leaf_cluster_b", Color(1.05, 0.55, 1.5), Color(0.35, 0.1, 0.5)))
	var brng := RandomNumberGenerator.new()
	brng.seed = 3
	var crown := Vector3(0.6, 11.5, -7.0)
	for i in 380:
		var off := Vector3(brng.randfn(0, 1), brng.randfn(0, 0.55), brng.randfn(0, 1)).normalized() * 7.0 * pow(brng.randf(), 0.5)
		var p := crown + off
		bloom_batch.add(Env._card_xf(brng, p, (p - crown).normalized(), brng.randf_range(1.4, 2.4)), crown, Color(1, 1, 1) * brng.randf_range(0.8, 1.1))
	bloom_batch.build(self)
	for k in 5:
		var l := OmniLight3D.new()
		l.light_color = [Color(1.0, 0.55, 0.9), Color(0.5, 0.8, 1.0)][k % 2]
		l.light_energy = 2.5
		l.omni_range = 9.0
		l.position = Vector3(randf_range(-5, 5), randf_range(6, 12), -7.0 + randf_range(-3, 3))
		add_child(l)
		tree_lights.append(l)
	blossoms = Fx.emitter(self, Color(2.6, 1.3, 2.4), 160, 7.0, 0.1, 0.4, -0.35, Vector3(8, 4, 6))
	blossoms.position = Vector3(0.5, 9.0, -6.5)
	var motes := Fx.emitter(self, Color(0.9, 2.4, 2.4), 120, 5.0, 0.07, 0.3, 0.2, Vector3(18, 2, 9))
	motes.position = Vector3(0, 1.2, 3)
	# ring of standing stones
	seed(9)
	for i in 14:
		var a := TAU * i / 14.0
		var p := Vector3(cos(a) * 6.8, 0, -6.0 + sin(a) * 4.2)
		if p.z > -1.0 and abs(p.x) < 2.5:
			continue
		Env.prop(self, "rock_07", p, randf_range(5.0, 9.0), randf() * TAU)
	# crystals
	for cp in [Vector3(-8.5, 0, -2.5), Vector3(9.0, 0, -1.5), Vector3(-15, 0, 6.5), Vector3(15.5, 0, 7.5), Vector3(6.5, 0, -9.5)]:
		_crystal(cp, randf_range(0.9, 1.5))
	# mirror pool
	var water := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 3.2
	disk.bottom_radius = 3.2
	disk.height = 0.05
	disk.radial_segments = 48
	water.mesh = disk
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.03, 0.08, 0.16)
	wm.roughness = 0.02
	wm.metallic = 0.6
	wm.emission_enabled = true
	wm.emission = Color(0.1, 0.25, 0.5)
	wm.emission_energy_multiplier = 0.3
	water.material_override = wm
	water.position = Vector3(POOL.x, -0.12, POOL.y)
	add_child(water)
	Env.pillar(self, Vector3(POOL.x, 0, POOL.y), 3.0, 1.0)
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		Env.prop(self, "rock_09", Vector3(POOL.x + cos(a) * 3.35, 0, POOL.y + sin(a) * 3.35), randf_range(10, 16), randf() * TAU)
	make_batches(Color(0.55, 0.75, 1.15), Color(0.6, 0.8, 1.2), Color(0.05, 0.08, 0.2))
	var x := bounds.position.x - 8.0
	while x < bounds.end.x + 8.0:
		var z := bounds.position.y - randf_range(6.0, 14.0)
		if abs(x) > 9.0:
			Env.tree(self, Vector3(x, height_at(x, z), z), batch_leaves, {"height": randf_range(11, 15), "radius": randf_range(0.5, 0.7), "crown": randf_range(4.0, 5.2), "cards": 420, "bark_tint": Color(0.7, 0.75, 0.95)})
		x += randf_range(5, 7.5)
	for i in 36:
		var bx := randf_range(bounds.position.x - 5, bounds.end.x + 5)
		var bz = randf_range(bounds.position.y - 6, bounds.position.y + 1) if i % 3 != 0 else bounds.end.y + randf_range(0.5, 3.0)
		if abs(bx) < 7.0 and bz < 0.0:
			continue
		Env.bush(Vector3(bx, height_at(bx, bz), bz), batch_bush, randf_range(0.8, 1.5), 40)
	add_grass(Rect2(-40, -18, 80, 36), 60000, func(gx, gz):
		var p := Vector2(gx, gz)
		if p.distance_to(POOL) < 3.6 or p.distance_to(Vector2(0.4, -6.8)) < 3.0:
			return 0.0
		if abs(gx + sin(gz * 0.3) * 1.2) < 1.4 and gz > -1.0:
			return 0.0
		return clamp(0.75 + _noise.get_noise_2d(gx * 0.8, gz * 0.8), 0.2, 1.0)
	, {"tip": Color(0.35, 0.72, 0.85), "root": Color(0.03, 0.08, 0.12), "dry": Color(0.45, 0.5, 0.8), "glow": Color(0.1, 0.6, 0.6), "seed": 7})
	add_flowers(Rect2(-30, -12, 60, 26), 260, func(fx, fz):
		var p := Vector2(fx, fz)
		if p.distance_to(POOL) < 4.0 or (abs(fx) < 2.0 and fz > -1.0):
			return 0.0
		return clamp(_noise.get_noise_2d(fx * 0.4 + 9.0, fz * 0.4) * 2.0 + 0.3, 0.0, 1.0)
	, Color(0.25, 0.35, 0.6))
	finish_batches()
	build_walls()
	var talk := InteractPoint.new().setup("Árvore de Mana", Story.mana_tree, 4.2, 5.0)
	talk.position = Vector3(0.3, 0, -4.2)
	add_child(talk)


func _crystal(pos: Vector3, s: float) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.9, 1.0, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.1
	m.emission_enabled = true
	m.emission = Color(0.3, 0.8, 1.0)
	m.emission_energy_multiplier = 2.2
	m.rim_enabled = true
	m.rim = 0.8
	for k in 5:
		var h := randf_range(1.2, 3.2) * s
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(0.18, 0.34) * s
		cm.height = h
		cm.radial_segments = 6
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = m
		mi.position = Vector3(randf_range(-0.4, 0.4) * s, h * 0.45, randf_range(-0.4, 0.4) * s)
		mi.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
		root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.85, 1.0)
	l.light_energy = 2.4
	l.omni_range = 7.0
	l.position = Vector3(0, 1.5 * s, 0)
	root.add_child(l)
	tree_lights.append(l)
	Env.pillar(self, pos, 0.8 * s, 3.0)


func on_enter() -> void:
	if Game.flags.get("ending", false):
		bloom()
		return
	var m := main()
	var p: Vector3 = m.player.global_position if m.player.get_parent() else Vector3.ZERO
	for i in 4:
		m.spawn_pack(random_point(p, 9.0), Game.monster_level(8), ["mage", "warrior", "rogue"])


func bloom() -> void:
	blossoms.amount = 400
	for l in tree_lights:
		l.set_meta("base", float(l.get_meta("base", l.light_energy)) * 1.6)
	Fx.burst(self, Vector3(0.5, 8.0, -6.5), Color(2.8, 1.8, 2.6), 300, 8.0, 3.0, 0.14, -0.6, true, 180.0)


func _process(dt: float) -> void:
	_t += dt
	for i in tree_lights.size():
		var l := tree_lights[i]
		if not l.has_meta("base"):
			l.set_meta("base", l.light_energy)
		l.light_energy = float(l.get_meta("base")) * (1.0 + sin(_t * 1.3 + i) * 0.12)
