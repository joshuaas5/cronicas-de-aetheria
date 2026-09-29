class_name Build
extends RefCounted
## Procedural medieval architecture dressed with scanned PBR textures.


static func box(parent: Node, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, pos: Vector3, r_top: float, r_bottom: float, h: float, mat: Material, sides := 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func window_glass(energy := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.62, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.62, 0.28)
	m.emission_energy_multiplier = energy
	m.roughness = 0.15
	return m


## A timber-framed house. Front faces +Z. Returns the root node.
## o: w, d, h (wall height), roof_tint, wall_tint, door (bool), chimney (bool), windows (int), sign (String)
static func house(parent: Node, pos: Vector3, yaw := 0.0, o := {}) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var w: float = o.get("w", 9.0)
	var d: float = o.get("d", 6.0)
	var h: float = o.get("h", 3.6)
	var stone := Env.pbr("medieval_blocks_02", 0.6, Color(0.95, 0.93, 0.9), true)
	var plaster = Env.pbr("plastered_wall_04", 0.45, o.get("wall_tint", Color(1.0, 0.97, 0.92)), true)
	var wood := Env.pbr("medieval_wood", 0.8, Color(0.75, 0.6, 0.48), true)
	var roof = Env.pbr("roof_tiles_14", 0.55, o.get("roof_tint", Color(1.0, 0.8, 0.7)), true)
	var base_h := 0.7
	box(root, Vector3(0, base_h * 0.5, 0), Vector3(w + 0.4, base_h, d + 0.4), stone)
	box(root, Vector3(0, base_h + h * 0.5, 0), Vector3(w, h, d), plaster)
	# timber frame on all sides
	var bt := 0.2
	for y in [base_h + 0.1, base_h + h * 0.52, base_h + h - 0.1]:
		box(root, Vector3(0, y, d * 0.5 + 0.06), Vector3(w + 0.1, bt, 0.16), wood)
		box(root, Vector3(0, y, -d * 0.5 - 0.06), Vector3(w + 0.1, bt, 0.16), wood)
		box(root, Vector3(w * 0.5 + 0.06, y, 0), Vector3(0.16, bt, d + 0.1), wood)
		box(root, Vector3(-w * 0.5 - 0.06, y, 0), Vector3(0.16, bt, d + 0.1), wood)
	var posts := int(w / 1.8)
	for i in posts + 1:
		var x := -w * 0.5 + w * i / posts
		box(root, Vector3(x, base_h + h * 0.5, d * 0.5 + 0.07), Vector3(bt, h, 0.16), wood)
		box(root, Vector3(x, base_h + h * 0.5, -d * 0.5 - 0.07), Vector3(bt, h, 0.16), wood)
		if i < posts and i % 2 == 0:
			var seg := w / posts
			var diag := sqrt(seg * seg + h * h * 0.25)
			box(root, Vector3(x + seg * 0.5, base_h + h * 0.76, d * 0.5 + 0.08), Vector3(diag, 0.14, 0.12), wood, Vector3(0, 0, atan2(h * 0.46, seg)))
	for sx in [-1, 1]:
		box(root, Vector3(sx * (w * 0.5 + 0.07), base_h + h * 0.5, 0), Vector3(0.16, h, bt), wood)
	# gable attic + roof slabs (ridge runs along X)
	var rh: float = o.get("roof_h", d * 0.62)
	var attic := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(d, rh, w)
	attic.mesh = pm
	attic.material_override = plaster
	attic.position = Vector3(0, base_h + h + rh * 0.5, 0)
	attic.rotation.y = PI * 0.5
	root.add_child(attic)
	var over := 0.7
	var slope := atan2(rh, d * 0.5)
	var slab_len := sqrt(rh * rh + d * d * 0.25) + over
	for sz in [-1, 1]:
		box(root, Vector3(0, base_h + h + rh * 0.5 + 0.08, sz * (d * 0.25 + over * 0.2)), Vector3(w + over * 2, 0.22, slab_len), roof, Vector3(sz * slope, 0, 0))
	box(root, Vector3(0, base_h + h + rh + 0.05, 0), Vector3(w + over * 2 + 0.1, 0.28, 0.4), wood)
	# windows
	var glass = window_glass(o.get("window_energy", 1.4))
	var nwin: int = o.get("windows", 2)
	for i in nwin:
		var x := -w * 0.5 + w * (i + 0.5) / nwin
		if o.get("door", true) and abs(x) < 1.2:
			x += 2.2 * sign(x if x != 0.0 else 1.0)
		for y in [base_h + h * 0.27, base_h + h * 0.76]:
			if y < base_h + h * 0.5 and o.get("door", true) and abs(x) < 1.8:
				continue
			box(root, Vector3(x, y, d * 0.5 + 0.05), Vector3(1.1, 1.0, 0.12), wood)
			box(root, Vector3(x, y, d * 0.5 + 0.1), Vector3(0.86, 0.78, 0.05), glass, Vector3.ZERO, false)
			box(root, Vector3(x, y, d * 0.5 + 0.13), Vector3(0.08, 0.8, 0.04), wood, Vector3.ZERO, false)
			box(root, Vector3(x, y, d * 0.5 + 0.13), Vector3(0.88, 0.08, 0.04), wood, Vector3.ZERO, false)
			box(root, Vector3(x, y - 0.56, d * 0.5 + 0.2), Vector3(1.3, 0.1, 0.3), wood)
	# door
	if o.get("door", true):
		var dark := Env.pbr("medieval_wood", 1.2, Color(0.5, 0.36, 0.26), true)
		box(root, Vector3(0, base_h + 1.2, d * 0.5 + 0.05), Vector3(2.0, 2.5, 0.2), wood)
		box(root, Vector3(0, base_h + 1.12, d * 0.5 + 0.12), Vector3(1.55, 2.2, 0.12), dark)
		var knob := Fx.glow_sphere(0.05, Color(1, 0.8, 0.4), 1.0)
		knob.position = Vector3(0.5, base_h + 1.1, d * 0.5 + 0.22)
		root.add_child(knob)
		for s in 3:
			box(root, Vector3(0, base_h - 0.12 - s * 0.24, d * 0.5 + 0.45 + s * 0.4), Vector3(2.6 + s * 0.3, 0.24, 0.45), stone)
		for sx in [-1.3, 1.3]:
			var lan := Env.prop(root, "Lantern_01", Vector3(sx, base_h + 2.2, d * 0.5 + 0.35), 2.6)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.68, 0.35)
			l.light_energy = 1.4
			l.omni_range = 5.5
			l.position = Vector3(sx, base_h + 2.45, d * 0.5 + 0.5)
			root.add_child(l)
	if o.get("chimney", true):
		box(root, Vector3(w * 0.3, base_h + h + rh + 0.4, -d * 0.18), Vector3(0.8, 2.6, 0.8), stone)
		var smoke := Fx.emitter(root, Color(0.75, 0.75, 0.75, 0.35), 24, 4.0, 1.2, 0.6, 0.35, Vector3(0.2, 0.1, 0.2))
		smoke.position = Vector3(w * 0.3, base_h + h + rh + 1.8, -d * 0.18)
		smoke.draw_pass_1.material = Fx.particle_mat(false)
	if o.has("sign"):
		box(root, Vector3(w * 0.5 - 0.6, base_h + h * 0.62, d * 0.5 + 0.7), Vector3(0.12, 0.12, 1.3), wood)
		var board := box(root, Vector3(w * 0.5 - 0.6, base_h + h * 0.62 - 0.7, d * 0.5 + 1.15), Vector3(0.1, 0.9, 1.4), wood)
		var lbl := Label3D.new()
		lbl.text = o["sign"]
		lbl.font = Fx.font()
		lbl.font_size = 36
		lbl.modulate = Color(1.0, 0.85, 0.45)
		lbl.outline_size = 6
		lbl.outline_modulate = Color(0.15, 0.08, 0.02)
		lbl.pixel_size = 0.006
		lbl.width = 200
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.position = Vector3(0.07, 0, 0)
		lbl.rotation.y = PI * 0.5
		board.add_child(lbl)
	Env.wall(root, Vector3(0, 2, 0), Vector3(w + 0.4, 4, d + 0.4))
	return root


static func tower(parent: Node, pos: Vector3, r := 1.8, h := 9.0, roof_tint := Color(0.75, 0.62, 0.95)) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	cyl(root, Vector3(0, 0.5, 0), r + 0.25, r + 0.35, 1.0, Env.pbr("medieval_blocks_02", 0.6, Color.WHITE, true))
	cyl(root, Vector3(0, h * 0.5, 0), r, r + 0.05, h, Env.pbr("plastered_wall_04", 0.45, Color(0.95, 0.92, 1.0), true))
	cyl(root, Vector3(0, h + 0.1, 0), r + 0.25, r + 0.2, 0.3, Env.pbr("medieval_wood", 0.8, Color(0.7, 0.55, 0.45), true))
	cyl(root, Vector3(0, h + 2.3, 0), 0.0, r + 0.7, 4.4, Env.pbr("roof_tiles_14", 0.5, roof_tint, true), 16)
	var glass := window_glass(1.8)
	for a in [0.0, 1.6]:
		var wpos := Vector3(sin(a) * (r + 0.02), h * 0.62, cos(a) * (r + 0.02))
		box(root, wpos, Vector3(0.7, 1.1, 0.1), glass, Vector3(0, a, 0), false)
	Env.pillar(root, Vector3.ZERO, r + 0.3, 4.0)
	return root


static func well(parent: Node, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var stone := Env.pbr("medieval_blocks_02", 1.4, Color.WHITE, true)
	var wood := Env.pbr("medieval_wood", 1.0, Color(0.7, 0.55, 0.42), true)
	cyl(root, Vector3(0, 0.45, 0), 1.0, 1.05, 0.9, stone)
	var water := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 0.8
	cm.height = 0.05
	water.mesh = cm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.12, 0.18)
	wm.roughness = 0.05
	wm.metallic = 0.3
	water.material_override = wm
	water.position.y = 0.8
	root.add_child(water)
	for sx in [-0.9, 0.9]:
		box(root, Vector3(sx, 1.4, 0), Vector3(0.16, 1.9, 0.16), wood)
	box(root, Vector3(0, 2.1, 0), Vector3(2.0, 0.12, 0.12), wood)
	var roof := Env.pbr("roof_tiles_14", 1.0, Color(1.0, 0.8, 0.7), true)
	box(root, Vector3(0, 2.55, 0.42), Vector3(2.5, 0.1, 1.1), roof, Vector3(0.7, 0, 0))
	box(root, Vector3(0, 2.55, -0.42), Vector3(2.5, 0.1, 1.1), roof, Vector3(-0.7, 0, 0))
	Env.prop(root, "Barrel_02", Vector3(0.1, 1.55, 0), 0.5, 0.0)
	Env.pillar(root, Vector3.ZERO, 1.1, 2.0)
	return root


static func fence(parent: Node, a: Vector3, b: Vector3, spacing := 2.0) -> void:
	var wood := Env.pbr("medieval_wood", 1.0, Color(0.7, 0.56, 0.44), true)
	var dir := b - a
	var n := int(dir.length() / spacing)
	var yaw := atan2(dir.x, dir.z)
	for i in n + 1:
		var p := a + dir * float(i) / n
		box(parent, p + Vector3(0, 0.55, 0), Vector3(0.14, 1.1, 0.14), wood, Vector3(0, yaw + randf_range(-0.1, 0.1), randf_range(-0.06, 0.06)))
	for y in [0.45, 0.85]:
		box(parent, (a + b) * 0.5 + Vector3(0, y, 0), Vector3(0.08, 0.1, dir.length()), wood, Vector3(0, yaw, 0))
	var c := (a + b) * 0.5
	var body := StaticBody3D.new()
	body.position = c + Vector3(0, 1, 0)
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.3, 2, dir.length())
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)


static func pumpkin(parent: Node, pos: Vector3, s := 0.4) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = s
	sm.height = s * 1.5
	sm.radial_segments = 24
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.45, 0.08)
	m.roughness = 0.55
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/farm_soil/normal.jpg")
	m.normal_scale = 0.4
	mi.material_override = m
	mi.position = pos + Vector3(0, s * 0.6, 0)
	mi.rotation.y = randf() * TAU
	parent.add_child(mi)
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.05
	cm.height = s * 0.5
	stem.mesh = cm
	var sm2 := StandardMaterial3D.new()
	sm2.albedo_color = Color(0.3, 0.45, 0.12)
	stem.material_override = sm2
	stem.position = pos + Vector3(0, s * 1.3, 0)
	stem.rotation.z = 0.3
	parent.add_child(stem)


## Storybook giant mushroom. `glow` > 0 makes the cap luminous.
static func mushroom(parent: Node, pos: Vector3, s := 1.0, cap := Color(0.9, 0.12, 0.08), glow := 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(randf_range(-0.12, 0.12), randf() * TAU, randf_range(-0.12, 0.12))
	parent.add_child(root)
	var stem_m := StandardMaterial3D.new()
	stem_m.albedo_color = Color(0.95, 0.9, 0.78)
	stem_m.roughness = 0.7
	stem_m.normal_enabled = true
	stem_m.normal_texture = load("res://assets/textures/bark_willow_02/normal.jpg")
	stem_m.normal_scale = 0.3
	stem_m.backlight_enabled = true
	stem_m.backlight = Color(0.4, 0.35, 0.25)
	cyl(root, Vector3(0, 0.55 * s, 0), 0.16 * s, 0.24 * s, 1.1 * s, stem_m, 16)
	var cap_mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.62 * s
	sm.height = 0.62 * s
	sm.is_hemisphere = true
	sm.radial_segments = 32
	cap_mi.mesh = sm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = cap
	cm.roughness = 0.35
	cm.clearcoat_enabled = true
	cm.clearcoat = 0.6
	cm.rim_enabled = true
	cm.rim = 0.4
	if glow > 0.0:
		cm.emission_enabled = true
		cm.emission = cap
		cm.emission_energy_multiplier = glow
	cap_mi.material_override = cm
	cap_mi.position.y = 1.05 * s
	cap_mi.scale = Vector3(1, 0.75, 1)
	root.add_child(cap_mi)
	var under := cyl(root, Vector3(0, 1.04 * s, 0), 0.58 * s, 0.2 * s, 0.06 * s, stem_m, 24)
	var dot_m := StandardMaterial3D.new()
	dot_m.albedo_color = Color(1.0, 0.97, 0.9)
	dot_m.roughness = 0.6
	if glow > 0.0:
		dot_m.emission_enabled = true
		dot_m.emission = Color(1, 1, 0.9)
		dot_m.emission_energy_multiplier = glow * 0.6
	for i in 9:
		var a := randf() * TAU
		var r := randf_range(0.15, 0.5) * s
		var dot := MeshInstance3D.new()
		var ds := SphereMesh.new()
		ds.radius = randf_range(0.04, 0.08) * s
		ds.height = ds.radius * 1.2
		dot.mesh = ds
		dot.material_override = dot_m
		var y = 1.05 * s + sqrt(max(0.0, (0.62 * s) * (0.62 * s) - r * r)) * 0.75
		dot.position = Vector3(cos(a) * r, y, sin(a) * r)
		root.add_child(dot)
	if glow > 0.0:
		var l := OmniLight3D.new()
		l.light_color = cap
		l.light_energy = glow
		l.omni_range = 4.0 * s
		l.position.y = 0.9 * s
		root.add_child(l)
	Env.pillar(parent, pos, 0.3 * s, 2.0)
