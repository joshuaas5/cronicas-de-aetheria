extends Level
## The world map: a candle-lit tabletop where artifacts are planted as floating island dioramas.

const COLS := 5
const ROWS := 3
var cursor := Vector2i(1, 1)
var islands := {}
var cursor_ring: MeshInstance3D
var cursor_arrow: MeshInstance3D
var marker: Node3D
var marker_ap: AnimationPlayer
var busy := false
var _t := 0.0


func _init() -> void:
	id = "map"
	display_name = "Mapa do Mundo"
	music = "map"
	ambience = "tavern"
	cam_offset = Vector3(0, 13.5, 12.0)
	cam_fov = 36.0
	cam_look_height = 0.0
	cam_bounds = Rect2(0, 0.6, 0, 0)
	spawns = {"default": [Vector3(0, 0, 0.6), 0.0]}


static func slot_pos(c: Vector2i) -> Vector3:
	return Vector3(-6.4 + c.x * 3.2, 0.0, -3.2 + c.y * 3.2)


func build() -> void:
	env = Env.environment(self, {
		"hdri": "warm_restaurant_night",
		"sky_energy": 0.6,
		"exposure": 1.1,
		"ambient": 0.5,
		"sun_color": Color(1.0, 0.82, 0.6),
		"sun_energy": 1.4,
		"sun_rot": Vector3(-58, -30, 0),
		"fog_density": 0.0,
		"vol_density": 0.012,
		"vol_color": Color(1.0, 0.85, 0.65),
		"saturation": 1.2,
		"dof_far": 20.0,
		"dof_near": 12.0,
		"dof_amount": 0.12,
		"sdfgi": false,
	})
	var e: Environment = env["env"]
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.015, 0.01)
	e.fog_enabled = false
	# table and parchment board
	Build.box(self, Vector3(0, -0.6, 0), Vector3(40, 1.0, 28), Env.pbr("worn_planks", 0.25, Color(0.75, 0.55, 0.4), true))
	Build.box(self, Vector3(0, -0.05, 0), Vector3(18.5, 0.12, 11.5), Env.pbr("plastered_wall_04", 0.18, Color(1.0, 0.86, 0.62), true))
	var trim := Env.pbr("medieval_wood", 0.6, Color(0.55, 0.38, 0.25), true)
	for sz in [-1, 1]:
		Build.box(self, Vector3(0, 0.05, sz * 5.85), Vector3(18.9, 0.2, 0.3), trim)
	for sx in [-1, 1]:
		Build.box(self, Vector3(sx * 9.35, 0.05, 0), Vector3(0.3, 0.2, 12.0), trim)
	# empty slots
	var ring_m := StandardMaterial3D.new()
	ring_m.albedo_color = Color(0.45, 0.3, 0.15, 0.6)
	ring_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for r in ROWS:
		for c in COLS:
			var mi := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 1.0
			tm.outer_radius = 1.08
			mi.mesh = tm
			mi.material_override = ring_m
			mi.position = slot_pos(Vector2i(c, r)) + Vector3(0, 0.02, 0)
			mi.scale = Vector3(1, 0.1, 1)
			add_child(mi)
	# globe, candle and a quill for atmosphere
	var globe := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 2.2
	globe.mesh = sm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/forest_leaves_02/albedo.jpg")
	gm.albedo_color = Color(0.5, 0.8, 0.7)
	gm.metallic = 0.3
	gm.roughness = 0.2
	gm.clearcoat_enabled = true
	globe.material_override = gm
	globe.position = Vector3(-12.5, 1.4, -5.5)
	add_child(globe)
	Build.cyl(self, Vector3(-12.5, 0.1, -5.5), 0.3, 0.6, 0.3, Env.pbr("medieval_wood", 1.0, Color(0.6, 0.45, 0.3), true))
	var candle_root := Vector3(12.0, 0, -5.0)
	Env.prop(self, "brass_candleholders", candle_root, 1.4, 0.3)
	var cl := OmniLight3D.new()
	cl.light_color = Color(1.0, 0.65, 0.3)
	cl.light_energy = 3.0
	cl.omni_range = 16.0
	cl.shadow_enabled = true
	cl.position = candle_root + Vector3(0, 1.8, 0.3)
	add_child(cl)
	for i in 3:
		var mote := Fx.emitter(self, Color(2.0, 1.7, 0.9), 30, 4.0, 0.05, 0.2, 0.15, Vector3(9, 1, 6))
		mote.position = Vector3(0, 1.0, 0)
	# islands
	for k in Game.lands:
		_spawn_island(k, false)
	# cursor
	cursor_ring = MeshInstance3D.new()
	var ct := TorusMesh.new()
	ct.inner_radius = 1.3
	ct.outer_radius = 1.45
	cursor_ring.mesh = ct
	cursor_ring.material_override = Env.emissive(Color(1.0, 0.85, 0.45), 3.0)
	cursor_ring.scale = Vector3(1, 0.15, 1)
	add_child(cursor_ring)
	cursor_arrow = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.0
	cm.height = 0.6
	cursor_arrow.mesh = cm
	cursor_arrow.material_override = Env.emissive(Color(1.0, 0.9, 0.55), 2.5)
	add_child(cursor_arrow)
	marker = load("res://assets/characters/adventurers/Knight.glb").instantiate()
	marker.scale = Vector3.ONE * 0.32
	add_child(marker)
	marker_ap = marker.find_children("*", "AnimationPlayer", true, false)[0]
	marker_ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	marker_ap.play("Idle")
	var here: String = Game.map_here if Game.lands.has(Game.map_here) else "village"
	cursor = Game.lands[here]


func _spawn_island(land: String, animate: bool) -> void:
	var root := Node3D.new()
	root.position = slot_pos(Game.lands[land]) + Vector3(0, 0.9, 0)
	add_child(root)
	islands[land] = root
	var rock := Env.pbr("rock_wall_08", 0.8, Color(0.85, 0.75, 0.65), true)
	var base := Build.cyl(root, Vector3(0, -0.45, 0), 1.25, 0.25, 1.1, rock, 12)
	base.rotation.y = randf() * TAU
	var top_col: Color = {"village": Color(0.95, 1.1, 0.75), "forest": Color(0.8, 1.0, 0.7), "sanctuary": Color(0.6, 0.8, 1.2)}[land]
	Build.cyl(root, Vector3(0, 0.12, 0), 1.3, 1.25, 0.12, Env.pbr("leafy_grass", 0.8, top_col, true), 24)
	var batch = Env.FoliageBatch.new(Env.foliage_mat("leaf_cluster_a", Color(0.95, 1.08, 0.8) if land != "sanctuary" else Color(0.9, 0.7, 1.2), Color(0.1, 0.05, 0.2) if land == "sanctuary" else Color.BLACK))
	match land:
		"village":
			var h := Build.house(root, Vector3(-0.2, 0.18, 0.1), 0.3, {"w": 9.0, "d": 6.0, "h": 3.6, "windows": 3, "chimney": false, "door": false})
			h.scale = Vector3.ONE * 0.12
			var h2 := Build.house(root, Vector3(0.6, 0.18, -0.5), -0.4, {"w": 7.0, "d": 5.0, "h": 3.0, "roof_tint": Color(0.62, 0.7, 1.0), "chimney": false, "door": false})
			h2.scale = Vector3.ONE * 0.1
			var tw := Build.tower(root, Vector3(-0.8, 0.18, -0.4), 1.8, 9.0)
			tw.scale = Vector3.ONE * 0.1
			Env.tree(root, Vector3(0.75, 0.18, 0.55), batch, {"height": 1.4, "radius": 0.05, "crown": 0.45, "cards": 40, "card_size": 0.22, "branches": 4})
		"forest":
			for i in 6:
				var a := TAU * i / 6.0
				Env.tree(root, Vector3(cos(a) * 0.7, 0.18, sin(a) * 0.6), batch, {"height": randf_range(1.4, 2.0), "radius": 0.06, "crown": 0.5, "cards": 45, "card_size": 0.24, "branches": 4})
			Env.tree(root, Vector3(0, 0.18, 0), batch, {"height": 2.4, "radius": 0.08, "crown": 0.6, "cards": 60, "card_size": 0.26, "branches": 5})
		"sanctuary":
			Env.tree(root, Vector3(0, 0.18, 0), batch, {"height": 2.2, "radius": 0.09, "crown": 0.75, "cards": 80, "card_size": 0.3, "branches": 5, "bark_tint": Color(0.8, 0.8, 1.0)})
			for s in [-1, 1]:
				var cr := MeshInstance3D.new()
				var cc := CylinderMesh.new()
				cc.top_radius = 0.0
				cc.bottom_radius = 0.1
				cc.height = 0.5
				cc.radial_segments = 6
				cr.mesh = cc
				cr.material_override = Env.emissive(Color(0.4, 0.85, 1.0), 3.0)
				cr.position = Vector3(s * 0.8, 0.4, 0.3)
				root.add_child(cr)
			Fx.emitter(root, Color(2.4, 1.2, 2.4), 30, 3.0, 0.05, 0.2, -0.1, Vector3(0.8, 0.6, 0.8)).position = Vector3(0, 1.6, 0)
	batch.build(root)
	var l := OmniLight3D.new()
	l.light_color = top_col
	l.light_energy = 0.6
	l.omni_range = 3.0
	l.position = Vector3(0, 1.5, 0.8)
	root.add_child(l)
	if animate:
		root.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_property(root, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(dt: float) -> void:
	_t += dt
	var c := slot_pos(cursor)
	cursor_ring.position = cursor_ring.position.lerp(c + Vector3(0, 0.08, 0), 1.0 - exp(-dt * 14.0))
	cursor_ring.rotation.y += dt * 0.8
	cursor_arrow.position = cursor_ring.position + Vector3(0, 3.4 + sin(_t * 5.0) * 0.2, 0)
	for k in islands:
		var isl: Node3D = islands[k]
		isl.position.y = 0.9 + sin(_t * 1.4 + isl.position.x) * 0.08
	var here: String = Game.map_here if islands.has(Game.map_here) else "village"
	if islands.has(here):
		var isl: Node3D = islands[here]
		marker.global_position = isl.global_position + Vector3(0.4, 0.2, 0.6)
	var ui = main().ui
	var land := Game.land_at(cursor)
	if land != "":
		ui.map_info = Game.LANDS[land]["name"] + "  —  Espaço para entrar"
	elif Game.arts.size() > 0:
		ui.map_info = "Espaço vazio  —  Espaço para plantar " + Game.ARTS[Game.arts[0]]["name"]
	else:
		ui.map_info = "Um espaço vazio. Talvez um artefato possa despertar uma terra aqui."


func map_input() -> void:
	if busy:
		return
	var moved := false
	if Input.is_action_just_pressed("move_left"):
		cursor.x = max(0, cursor.x - 1); moved = true
	if Input.is_action_just_pressed("move_right"):
		cursor.x = min(COLS - 1, cursor.x + 1); moved = true
	if Input.is_action_just_pressed("move_up"):
		cursor.y = max(0, cursor.y - 1); moved = true
	if Input.is_action_just_pressed("move_down"):
		cursor.y = min(ROWS - 1, cursor.y + 1); moved = true
	if moved:
		Sfx.play("blip", -6.0)
	if not (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
		return
	var land := Game.land_at(cursor)
	if land != "":
		Sfx.play("select")
		Game.map_here = land
		var L: Dictionary = Game.LANDS[land]
		main().go(L["level"], L["spawn"])
	elif Game.arts.size() > 0:
		var art: String = Game.arts.pop_front()
		var new_land: String = Game.ARTS[art]["land"]
		Game.lands[new_land] = cursor
		busy = true
		_spawn_island(new_land, true)
		var pos := slot_pos(cursor) + Vector3(0, 1.0, 0)
		Fx.burst(self, pos, Game.ARTS[art]["color"] * 2.5, 120, 6.0, 1.6, 0.14, -2.0)
		Fx.flash(self, pos + Vector3(0, 1, 0), Game.ARTS[art]["color"], 6.0, 10.0, 1.2)
		Sfx.play("bloom")
		main().shake(0.3)
		await get_tree().create_timer(1.5).timeout
		main().ui.toast(Game.LANDS[new_land]["name"] + " despertou!")
		Game.save_game()
		busy = false
	else:
		Sfx.play("blip")
