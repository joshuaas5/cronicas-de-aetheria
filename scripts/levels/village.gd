extends Level
## Vila Lumen: the tavern with its tower, Bram's cottage, the well and Lina's pumpkin field.

var paths := []
var field := Rect2(-28.5, 4.2, 15.5, 9.5)
var _noise := FastNoiseLite.new()


func _init() -> void:
	id = "village"
	display_name = "Vila Lumen"
	music = "village"
	ambience = "village"
	land = "village"
	bounds = Rect2(-31, -6, 62, 19)
	cam_bounds = Rect2(-17, -2.5, 34, 8)
	cam_offset = Vector3(0, 10.0, 24.0)
	cam_fov = 31.0
	cam_look_height = 1.8
	_noise.seed = 77
	_noise.frequency = 0.05
	paths = [
		[Vector2(40, 3.5), Vector2(24, 2.6), Vector2(14, 0.5), Vector2(9, -3.5), Vector2(8, -6)],
		[Vector2(14, 0.5), Vector2(4, 1.5), Vector2(-3, 1.0), Vector2(-9, -2.5), Vector2(-12.5, -6)],
		[Vector2(-3, 1.0), Vector2(-6, 5.0), Vector2(-11, 8.5)],
	]
	spawns = {
		"start": [Vector3(0, 0, 6), 0.0],
		"road": [Vector3(27, 0, 3), -PI * 0.5],
		"tavern_door": [Vector3(8, 0, -3.8), 0.0],
		"default": [Vector3(0, 0, 6), 0.0],
	}
	exits = [
		{"rect": Rect2(29.5, -3, 4, 12), "to": "map", "spawn": ""},
		{"rect": Rect2(6.9, -6.4, 2.2, 1.3), "to": "tavern", "spawn": "default"},
	]


func _path_dist(p: Vector2) -> float:
	var best := 1e9
	for pts in paths:
		best = min(best, dist_to_path(p, pts))
	return best


func height_at(x: float, z: float) -> float:
	var b := bounds.grow(2.0)
	var back: float = max(0.0, b.position.y - z - 6.0)
	var side: float = max(0.0, max(b.position.x - x, x - b.end.x))
	var front: float = max(0.0, z - b.end.y)
	var rise: float = pow(min(back / 14.0, 1.5), 1.7) * 9.0 + pow(min(side / 12.0, 1.4), 1.6) * 5.0 + min(front / 10.0, 1.0) * 1.0
	var n := _noise.get_noise_2d(x, z)
	return rise * (0.8 + n * 0.4) + n * 0.1


func _weights(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var path_w: float = clamp(1.0 - (_path_dist(p) - 1.1) / 1.0, 0.0, 1.0)
	var in_field: float = 1.0 if field.grow(-0.3).has_point(p) else 0.0
	var plaza: float = clamp(1.0 - (p.distance_to(Vector2(-2, 2)) - 3.2) / 0.8, 0.0, 1.0)
	var stone: float = max(plaza, clamp(1.0 - (p.distance_to(Vector2(8, -5.2)) - 2.2) / 0.8, 0.0, 1.0))
	var soil: float = max(in_field, 0.0)
	var rest: float = max(0.0, 1.0 - path_w - soil - stone)
	return Color(rest, max(path_w - stone, 0.0), soil, stone)


func build() -> void:
	env = Env.environment(self, {
		"hdri": "kloofendal_48d_partly_cloudy_puresky",
		"sky_energy": 1.0,
		"exposure": 1.05,
		"ambient": 0.9,
		"sun_color": Color(1.0, 0.9, 0.72),
		"sun_energy": 2.4,
		"sun_rot": Vector3(-46, -32, 0),
		"fog_color": Color(0.7, 0.82, 0.95),
		"fog_density": 0.003,
		"vol_density": 0.006,
		"vol_color": Color(1.0, 0.97, 0.9),
		"saturation": 1.22,
		"contrast": 1.08,
		"dof_far": 34.0,
	})
	Env.terrain(self, Vector2(-75, -60), Vector2(150, 90), 0.6, height_at, _weights, [
		["leafy_grass", 0.3, Color(1.0, 1.08, 0.85)],
		["stony_dirt_path", 0.4, Color(1.35, 1.25, 1.1)],
		["farm_soil", 0.35, Color(1.1, 0.95, 0.85)],
		["cobblestone_floor_08", 0.4, Color(1.1, 1.05, 1.0)],
	])
	make_batches(Color(0.95, 1.08, 0.78), Color(0.95, 1.1, 0.8))
	# architecture
	Build.house(self, Vector3(8, 0, -10), 0.0, {"w": 11.0, "d": 7.0, "h": 3.8, "windows": 3, "sign": "Taverna do\nJavali Dourado"})
	Build.tower(self, Vector3(1.0, 0, -11.2), 2.0, 9.5)
	Build.house(self, Vector3(-13, 0, -10), 0.0, {"w": 7.0, "d": 5.5, "h": 3.0, "roof_tint": Color(0.62, 0.7, 1.0), "wall_tint": Color(0.93, 0.95, 1.0), "windows": 2, "chimney": true})
	Build.house(self, Vector3(22, 0, -12.5), -0.25, {"w": 8.0, "d": 6.0, "h": 3.2, "roof_tint": Color(1.0, 0.75, 0.6), "wall_tint": Color(1.0, 0.94, 0.85), "windows": 2})
	Build.house(self, Vector3(-26, 0, -14), 0.35, {"w": 7.0, "d": 5.0, "h": 3.0, "roof_tint": Color(0.85, 0.65, 0.95), "door": false, "windows": 2})
	Build.well(self, Vector3(-2, 0, 2))
	Build.fence(self, Vector3(-28.5, 0, 3.8), Vector3(-15, 0, 3.8))
	Build.fence(self, Vector3(-12.8, 0, 3.8), Vector3(-12.8, 0, 9.0))
	seed(12)
	for i in 16:
		var p := Vector3(randf_range(field.position.x + 1, field.end.x - 1), 0, randf_range(field.position.y + 1, field.end.y - 1))
		Build.pumpkin(self, p, randf_range(0.28, 0.5))
	for row in 5:
		for k in 12:
			var x := field.position.x + 1.0 + k * 1.2 + randf_range(-0.2, 0.2)
			var z := field.position.y + 1.2 + row * 1.8
			Env.bush(Vector3(x, 0, z), batch_bush, randf_range(0.35, 0.5), 7, Color(0.9, 1.1, 0.7))
	# props
	Env.prop(self, "Barrel_01", Vector3(12.5, 0, -5.8), 1.1, 0.3)
	Env.prop(self, "Barrel_02", Vector3(13.3, 0, -5.4), 1.1, 1.2)
	Env.prop(self, "Barrel_01", Vector3(12.9, 0.95, -5.6), 1.0, 2.0)
	Env.pillar(self, Vector3(12.9, 0, -5.6), 0.9)
	Env.prop(self, "WoodenTable_01", Vector3(3.5, 0, -4.0), 1.0, 0.1)
	Env.prop(self, "WoodenChair_01", Vector3(3.0, 0, -3.2), 0.5, PI)
	Env.pillar(self, Vector3(3.5, 0, -4.0), 0.9)
	_sign(Vector3(26, 0, -0.5))
	# vegetation
	_trees()
	add_grass(Rect2(-48, -24, 96, 42), 80000, func(x, z):
		var p := Vector2(x, z)
		if _path_dist(p) < 1.6 or field.grow(0.2).has_point(p) or p.distance_to(Vector2(-2, 2)) < 3.6:
			return 0.0
		for h in [Rect2(1.5, -14.5, 14, 9.5), Rect2(-17, -13.5, 8.5, 7.5), Rect2(-1.5, -13.5, 5, 5)]:
			if (h as Rect2).has_point(p):
				return 0.0
		return clamp(0.7 + _noise.get_noise_2d(x * 0.8, z * 0.8), 0.2, 1.0)
	, {"tip": Color(0.62, 0.8, 0.26), "root": Color(0.1, 0.18, 0.04), "dry": Color(0.8, 0.75, 0.3), "seed": 5})
	add_flowers(Rect2(-40, -20, 80, 36), 520, func(x, z):
		var p := Vector2(x, z)
		if _path_dist(p) < 1.8 or field.grow(0.5).has_point(p) or p.distance_to(Vector2(-2, 2)) < 4.0:
			return 0.0
		return clamp(_noise.get_noise_2d(x * 0.35 + 50.0, z * 0.35) * 2.2 + 0.2, 0.0, 1.0)
	)
	finish_batches()
	build_walls()
	# NPCs and examinables
	add_child(Npc.new().setup("Ancião Bram", "Mage", Story.elder, 0.3))
	get_child(get_child_count() - 1).position = Vector3(-10, 0, -4.2)
	var lina := Npc.new().setup("Lina", "Rogue", Story.farmer, -1.2)
	lina.position = Vector3(-11.2, 0, 6.2)
	add_child(lina)
	var well_pt := InteractPoint.new().setup("Poço antigo", Story.well, 2.2, 2.9)
	well_pt.position = Vector3(-2, 0, 2)
	add_child(well_pt)
	var sign_pt := InteractPoint.new().setup("Placa", Story.sign_road, 2.2, 2.6)
	sign_pt.position = Vector3(26, 0, -0.5)
	add_child(sign_pt)
	_butterflies()


func _sign(pos: Vector3) -> void:
	var wood := Env.pbr("medieval_wood", 1.0, Color(0.72, 0.56, 0.42), true)
	Build.box(self, pos + Vector3(0, 1.0, 0), Vector3(0.16, 2.0, 0.16), wood)
	Build.box(self, pos + Vector3(0.45, 1.75, 0), Vector3(1.3, 0.42, 0.1), wood, Vector3(0, 0, 0.04))
	var l := Label3D.new()
	l.text = "Mapa →"
	l.font = Fx.font()
	l.font_size = 40
	l.modulate = Color(1.0, 0.9, 0.6)
	l.outline_size = 8
	l.outline_modulate = Color(0.12, 0.06, 0.02)
	l.pixel_size = 0.005
	l.position = pos + Vector3(0.45, 1.75, 0.07)
	add_child(l)
	Env.pillar(self, pos, 0.3, 2.0)


func _trees() -> void:
	seed(41)
	var x := bounds.position.x - 8.0
	while x < bounds.end.x + 8.0:
		var z := bounds.position.y - randf_range(12.0, 20.0)
		if not (x > -20 and x < 28 and z > -16):
			Env.tree(self, Vector3(x, height_at(x, z), z), batch_leaves, {"height": randf_range(12, 17), "radius": randf_range(0.5, 0.75), "crown": randf_range(4.5, 6.0), "cards": 520, "card_size": 1.3})
		x += randf_range(5, 8)
	for p in [Vector3(-22, 0, -7), Vector3(17, 0, -7.5), Vector3(-35, 0, 4), Vector3(36, 0, -6), Vector3(-36, 0, 14), Vector3(34, 0, 16), Vector3(-6, 0, -16), Vector3(30, 0, -16)]:
		Env.tree(self, Vector3(p.x, height_at(p.x, p.z), p.z), batch_leaves, {"height": randf_range(11, 15), "radius": randf_range(0.5, 0.7), "crown": randf_range(4.2, 5.5), "cards": 480, "card_size": 1.25})
	for i in 40:
		var bx := randf_range(bounds.position.x - 6, bounds.end.x + 6)
		var bz := randf_range(-16, -6.5) if i % 3 != 0 else bounds.end.y + randf_range(0.5, 3.0)
		if Rect2(1, -15, 15, 10).has_point(Vector2(bx, bz)) or Rect2(-17.5, -14, 9.5, 8.5).has_point(Vector2(bx, bz)):
			continue
		Env.bush(Vector3(bx, height_at(bx, bz), bz), batch_bush, randf_range(0.8, 1.6), 45)
	for i in 30:
		var fx := randf_range(bounds.position.x, bounds.end.x)
		var fz := randf_range(bounds.position.y - 3, bounds.end.y + 2)
		if _path_dist(Vector2(fx, fz)) < 2.5 or field.grow(1.0).has_point(Vector2(fx, fz)):
			continue
		Env.prop(self, "fern_02", Vector3(fx, height_at(fx, fz), fz), randf_range(0.8, 1.2), randf() * TAU, "", false)


func _butterflies() -> void:
	for i in 6:
		var p := Fx.emitter(self, [Color(2.4, 1.2, 1.8), Color(2.4, 2.2, 0.8), Color(1.2, 1.8, 2.6)][i % 3], 3, 3.0, 0.14, 0.8, 0.05, Vector3(6, 1.2, 4))
		p.position = Vector3(randf_range(-24, 24), 1.2, randf_range(-3, 11))
