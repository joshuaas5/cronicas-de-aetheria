extends Level
## Taverna do Javali Dourado — log walls, fire, candlelight and moonlight through the window.

var flicker: Array[OmniLight3D] = []
var _t := 0.0


func _init() -> void:
	id = "tavern"
	display_name = "Taverna do Javali Dourado"
	music = "tavern"
	ambience = "tavern"
	land = "village"
	bounds = Rect2(-8.5, -5.4, 17.3, 10.9)
	cam_bounds = Rect2(-1.5, -0.5, 3.0, 1.5)
	cam_offset = Vector3(0, 10.5, 13.5)
	cam_fov = 38.0
	cam_look_height = 0.5
	spawns = {"default": [Vector3(7.5, 0, 2.9), -PI * 0.5]}
	exits = [{"rect": Rect2(8.4, 1.5, 2.5, 2.8), "to": "village", "spawn": "tavern_door"}]


func build() -> void:
	env = Env.environment(self, {
		"hdri": "warm_restaurant_night",
		"sky_energy": 0.5,
		"exposure": 1.0,
		"ambient": 0.35,
		"sun_color": Color(0.55, 0.65, 1.0),
		"sun_energy": 0.35,
		"sun_rot": Vector3(-55, 160, 0),
		"fog_density": 0.0,
		"vol_density": 0.035,
		"vol_color": Color(1.0, 0.85, 0.7),
		"vol_ambient": 0.05,
		"saturation": 1.15,
		"dof_far": 30.0,
		"sdfgi": false,
		"glow": 0.9,
	})
	var e: Environment = env["env"]
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.0, 0.0)
	e.fog_enabled = false
	var floor_m := Env.pbr("worn_planks", 0.35, Color(1.0, 0.9, 0.8), true)
	var logs := Env.pbr("wood_trunk_wall", 0.3, Color(1.0, 0.88, 0.75), true)
	var wood := Env.pbr("medieval_wood", 0.8, Color(0.62, 0.46, 0.34), true)
	var light_wood := Env.pbr("medieval_wood", 0.8, Color(0.85, 0.66, 0.48), true)
	var stone := Env.pbr("medieval_blocks_02", 0.8, Color(0.85, 0.82, 0.8), true)
	# shell
	Build.box(self, Vector3(0, -0.1, 0), Vector3(18.4, 0.2, 12.4), floor_m)
	Build.box(self, Vector3(0, 2.6, -6.2), Vector3(18.8, 5.4, 0.4), logs)
	Build.box(self, Vector3(-9.2, 2.6, 0), Vector3(0.4, 5.4, 12.8), logs)
	Build.box(self, Vector3(9.2, 2.6, -2.35), Vector3(0.4, 5.4, 7.7), logs)
	Build.box(self, Vector3(9.2, 2.6, 5.3), Vector3(0.4, 5.4, 1.8), logs)
	Build.box(self, Vector3(9.2, 4.1, 2.9), Vector3(0.4, 2.4, 3.0), logs)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		Build.box(self, Vector3(x, 2.6, -5.9), Vector3(0.45, 5.4, 0.45), wood)
	Build.box(self, Vector3(0, 5.2, -5.8), Vector3(18.6, 0.45, 0.6), wood)
	Build.box(self, Vector3(-8.9, 5.2, 0), Vector3(0.6, 0.45, 12.4), wood)
	# door, slightly open onto the warm street
	Build.box(self, Vector3(9.35, 1.45, 2.9), Vector3(0.1, 2.9, 2.8), Env.emissive(Color(1.0, 0.7, 0.4), 0.6))
	Build.box(self, Vector3(8.5, 1.45, 1.9), Vector3(0.12, 2.8, 1.4), wood, Vector3(0, -1.0, 0))
	# counter + shelves behind it
	Build.box(self, Vector3(-6.0, 0.55, -1.2), Vector3(1.0, 1.1, 6.0), wood)
	Build.box(self, Vector3(-6.0, 1.15, -1.2), Vector3(1.3, 0.12, 6.3), light_wood)
	Env.wall(self, Vector3(-6.0, 1, -1.2), Vector3(1.3, 2, 6.3))
	for z in [-4.2, -1.5, 1.2]:
		Env.prop(self, "Shelf_01", Vector3(-8.85, 0, z), 1.2, PI * 0.5)
		for k in 7:
			var bot := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.035
			cm.bottom_radius = 0.07
			cm.height = 0.3
			bot.mesh = cm
			var bm := StandardMaterial3D.new()
			bm.albedo_color = [Color(0.2, 0.55, 0.3, 0.8), Color(0.55, 0.15, 0.15, 0.8), Color(0.25, 0.3, 0.6, 0.8), Color(0.75, 0.55, 0.2, 0.8)][k % 4]
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.roughness = 0.05
			bm.metallic = 0.2
			bm.emission_enabled = true
			bm.emission = bm.albedo_color
			bm.emission_energy_multiplier = 0.25
			bot.material_override = bm
			bot.position = Vector3(-8.72, 1.02 + (k % 2) * 0.62, z - 0.4 + k * 0.13)
			add_child(bot)
	for p in [Vector3(-6.0, 1.2, -3.0), Vector3(-6.1, 1.2, 0.4)]:
		var mug: Node3D = load("res://assets/characters/adventurers/mug_full.gltf").instantiate()
		mug.position = p + Vector3(0, 0.12, 0)
		mug.scale = Vector3.ONE * 0.45
		add_child(mug)
	# barrels
	for p in [Vector3(-7.9, 0, -5.2), Vector3(-7.1, 0, -5.3), Vector3(-7.5, 0.95, -5.25), Vector3(-8.0, 0, 4.9), Vector3(-7.2, 0, 5.2)]:
		Env.prop(self, "Barrel_01" if int(p.x * 10) % 2 == 0 else "Barrel_02", p, 1.15, randf() * TAU)
	Env.pillar(self, Vector3(-7.5, 0, -5.2), 1.0)
	Env.pillar(self, Vector3(-7.6, 0, 5.0), 1.0)
	# fireplace
	Build.box(self, Vector3(4.0, 1.6, -5.5), Vector3(3.6, 3.2, 1.2), stone)
	Build.box(self, Vector3(4.0, 0.8, -4.95), Vector3(2.0, 1.5, 0.2), Env.emissive(Color(0.05, 0.02, 0.01), 0.0))
	Build.box(self, Vector3(4.0, 3.3, -4.8), Vector3(4.0, 0.25, 0.6), light_wood)
	Build.box(self, Vector3(4.0, 4.6, -5.8), Vector3(1.4, 2.4, 0.8), stone)
	var fire := Fx.emitter(self, Color(3.2, 1.3, 0.35), 90, 0.9, 0.35, 1.6, 2.5, Vector3(0.6, 0.1, 0.15))
	fire.position = Vector3(4.0, 0.25, -4.8)
	var embers := Fx.emitter(self, Color(3.0, 1.0, 0.2), 20, 2.4, 0.06, 1.2, 1.5, Vector3(0.6, 0.1, 0.2))
	embers.position = Vector3(4.0, 0.5, -4.7)
	for i in 3:
		var lg := Build.cyl(self, Vector3(3.5 + i * 0.5, 0.18, -4.75), 0.1, 0.1, 1.1, Env.pbr("bark_brown_02", 1.0, Color.WHITE))
		lg.rotation = Vector3(0, 0.4 * i, PI * 0.5)
	Env.wall(self, Vector3(4.0, 1.5, -5.3), Vector3(3.8, 3, 1.4))
	_light(Vector3(4.0, 1.0, -4.0), Color(1.0, 0.55, 0.2), 3.2, 10.0, true)
	# window with moonlight
	Build.box(self, Vector3(-3.0, 2.9, -5.95), Vector3(1.8, 1.8, 0.2), wood)
	Build.box(self, Vector3(-3.0, 2.9, -5.9), Vector3(1.5, 1.5, 0.1), Env.emissive(Color(0.45, 0.6, 1.0), 1.6))
	Build.box(self, Vector3(-3.0, 2.9, -5.82), Vector3(0.08, 1.5, 0.06), wood)
	Build.box(self, Vector3(-3.0, 2.9, -5.82), Vector3(1.5, 0.08, 0.06), wood)
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.55, 0.7, 1.0)
	moon.light_energy = 6.0
	moon.spot_range = 14.0
	moon.spot_angle = 22.0
	moon.light_volumetric_fog_energy = 3.0
	moon.shadow_enabled = true
	moon.position = Vector3(-3.0, 3.2, -5.6)
	moon.rotation_degrees = Vector3(-38, 0, 0)
	add_child(moon)
	# stairs to the rooms upstairs
	for s in 9:
		var sh := 0.36 + s * 0.36
		Build.box(self, Vector3(6.2 + s * 0.32, sh * 0.5, -5.35), Vector3(0.34, sh, 1.3), light_wood)
	Env.wall(self, Vector3(7.5, 1.5, -5.3), Vector3(3.4, 3, 1.4))
	# tables with candles
	for tp in [Vector3(0.0, 0, -2.0), Vector3(4.2, 0, 1.2), Vector3(-2.0, 0, 3.0)]:
		_table(tp)
	# chandelier
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.05
	ring.mesh = tm
	ring.material_override = wood
	ring.position = Vector3(1.0, 4.4, 0.0)
	add_child(ring)
	for k in 8:
		var a := TAU * k / 8
		var c := Vector3(1.0 + cos(a) * 0.98, 4.55, sin(a) * 0.98)
		Build.cyl(self, c, 0.04, 0.04, 0.22, Env.emissive(Color(1.0, 0.95, 0.85), 0.3), 8)
		var f := Fx.glow_sphere(0.045, Color(1.0, 0.7, 0.3), 5.0)
		f.position = c + Vector3(0, 0.17, 0)
		f.scale = Vector3(1, 1.6, 1)
		add_child(f)
	_light(Vector3(1.0, 4.0, 0.0), Color(1.0, 0.72, 0.4), 2.6, 13.0, Env.quality >= 2)
	var dust := Fx.emitter(self, Color(1.2, 1.0, 0.8, 0.5), 60, 8.0, 0.05, 0.08, 0.02, Vector3(8, 2.5, 5))
	dust.position = Vector3(0, 2.5, 0)
	build_walls()
	# people
	var borin := Npc.new().setup("Borin", "Barbarian", Story.innkeeper, PI * 0.5, ["Mug"])
	borin.position = Vector3(-7.4, 0, -1.2)
	borin.interact_radius = 2.8
	add_child(borin)
	var bard := Npc.new().setup("Tomé, o bardo", "Rogue_Hooded", Story.bard, 0.3)
	bard.position = Vector3(1.6, 0, -4.3)
	add_child(bard)
	var nix := Npc.new().setup("Nix", "fairy", Story.fairy, 0.0)
	nix.position = Vector3(-4.2, 0, 3.6)
	add_child(nix)


func _table(p: Vector3) -> void:
	Env.prop(self, "WoodenTable_01", p, 1.35, randf_range(-0.2, 0.2))
	var wood := Env.pbr("medieval_wood", 0.8, Color(0.62, 0.46, 0.34), true)
	for side in [-1, 1]:
		Build.box(self, p + Vector3(0, 0.26, side * 0.85), Vector3(2.1, 0.1, 0.4), wood)
		for sx in [-0.85, 0.85]:
			Build.box(self, p + Vector3(sx, 0.12, side * 0.85), Vector3(0.1, 0.24, 0.35), wood)
	Env.prop(self, "brass_candleholders", p + Vector3(0.1, 0.74, 0), 0.6, randf() * TAU)
	_light(p + Vector3(0.1, 1.3, 0), Color(1.0, 0.65, 0.3), 1.3, 4.5, false)
	Env.pillar(self, p, 1.4, 1.2)


func _light(pos: Vector3, col: Color, energy: float, rng: float, shadows: bool) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 1.5
	l.position = pos
	add_child(l)
	flicker.append(l)
	l.set_meta("base", energy)


func _process(dt: float) -> void:
	_t += dt
	for i in flicker.size():
		var l := flicker[i]
		var base: float = l.get_meta("base")
		l.light_energy = base * (0.85 + 0.1 * sin(_t * 9.0 + i * 1.7) + 0.06 * sin(_t * 23.0 + i))
