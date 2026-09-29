class_name Env
extends RefCounted
## Builders for the realistic environment: materials, sky/lighting, terrain,
## grass, procedural trees with photo leaves, and scanned props.

const TEX := "res://assets/textures/"
const MODELS := "res://assets/models/"
const GEN := "res://assets/generated/"

## 0 = low (dev laptop), 1 = high, 2 = ultra (default: desktop GPUs)
static var quality := 2
static var _mats := {}
static var _noise: NoiseTexture2D
static var _scenes := {}
static var _blade_mesh: ArrayMesh
static var _card_mesh: ArrayMesh


# ---------------------------------------------------------------- materials

static func noise_tex() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.012
		n.fractal_octaves = 4
		var t := NoiseTexture2D.new()
		t.width = 512
		t.height = 512
		t.seamless = true
		t.generate_mipmaps = true
		t.noise = n
		_noise = t
	return _noise


static func pbr(name: String, scale := 1.0, tint := Color.WHITE, triplanar := false) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [name, scale, tint, triplanar]
	if _mats.has(key):
		return _mats[key]
	var d := TEX + name + "/"
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(d + "albedo.jpg")
	m.albedo_color = tint
	if ResourceLoader.exists(d + "normal.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(d + "normal.jpg")
	if ResourceLoader.exists(d + "arm.jpg"):
		var arm: Texture2D = load(d + "arm.jpg")
		m.ao_enabled = true
		m.ao_texture = arm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness_texture = arm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	elif ResourceLoader.exists(d + "rough.jpg"):
		m.roughness_texture = load(d + "rough.jpg")
	m.uv1_scale = Vector3(scale, scale, scale)
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func foliage_mat(tex_name: String, tint := Color.WHITE, glow := Color.BLACK) -> ShaderMaterial:
	var key := "leaf|%s|%s|%s" % [tex_name, tint, glow]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	m.set_shader_parameter("albedo_tex", load(GEN + tex_name + "_alb.png"))
	m.set_shader_parameter("normal_tex", load(GEN + tex_name + "_nrm.png"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("glow", glow)
	_mats[key] = m
	return m


# ---------------------------------------------------------------- sky & light

## o: hdri, sky_energy, sky_rot, exposure, ambient, sun_color, sun_energy, sun_rot (Vector3 deg),
## fog_color, fog_density, volumetric, vol_density, vol_color, saturation, dof_far, dof_near
static func environment(parent: Node, o: Dictionary) -> Dictionary:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/hdri/%s.hdr" % o.get("hdri", "forest_slope"))
	sky_mat.energy_multiplier = o.get("sky_energy", 1.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.sky_rotation = Vector3(0, deg_to_rad(o.get("sky_rot", 0.0)), 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = o.get("ambient", 1.0)
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = o.get("exposure", 1.0)
	e.ssao_enabled = true
	e.ssao_radius = 1.1
	e.ssao_intensity = 1.8
	e.ssao_power = 1.4
	e.glow_enabled = true
	e.glow_intensity = o.get("glow", 0.6)
	e.glow_bloom = o.get("bloom", 0.04)
	e.glow_hdr_threshold = 0.95
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = o.get("fog_color", Color(0.62, 0.72, 0.68))
	e.fog_density = o.get("fog_density", 0.004)
	e.fog_sky_affect = o.get("fog_sky", 0.4)
	e.fog_aerial_perspective = 0.35
	if o.get("volumetric", true):
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = o.get("vol_density", 0.018)
		e.volumetric_fog_albedo = o.get("vol_color", Color(0.85, 0.9, 0.85))
		e.volumetric_fog_emission = o.get("vol_emission", Color.BLACK)
		e.volumetric_fog_anisotropy = 0.72
		e.volumetric_fog_length = 40.0
		e.volumetric_fog_sky_affect = 0.0
		e.volumetric_fog_ambient_inject = o.get("vol_ambient", 0.25)
	if quality >= 2:
		e.ssil_enabled = true
		e.ssil_intensity = 0.8
		e.sdfgi_enabled = o.get("sdfgi", true)
		e.sdfgi_use_occlusion = true
		e.sdfgi_energy = o.get("gi_energy", 0.9)
		e.sdfgi_cascades = 4
		e.sdfgi_min_cell_size = 0.25
	if quality == 0:
		e.volumetric_fog_enabled = false
		e.ssao_enabled = false
	e.adjustment_enabled = true
	e.adjustment_saturation = o.get("saturation", 1.2)
	e.adjustment_contrast = o.get("contrast", 1.08)
	e.adjustment_color_correction = grade_lut(o.get("shadow_tint", Color(0.0, 0.035, 0.07)), o.get("high_tint", Color(1.0, 0.96, 0.86)))
	var we := WorldEnvironment.new()
	we.environment = e
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = o.get("dof_far", 24.0)
	ca.dof_blur_far_transition = 14.0
	ca.dof_blur_near_enabled = o.get("dof_near", 0.0) > 0.0
	ca.dof_blur_near_distance = o.get("dof_near", 6.0)
	ca.dof_blur_near_transition = 3.0
	ca.dof_blur_amount = o.get("dof_amount", 0.07)
	we.camera_attributes = ca
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = o.get("sun_color", Color(1.0, 0.94, 0.82))
	sun.light_energy = o.get("sun_energy", 1.6)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 42.0
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = o.get("sun_soft", 0.6) if quality >= 1 else 0.0
	sun.light_volumetric_fog_energy = o.get("sun_fog", 1.6)
	sun.rotation_degrees = o.get("sun_rot", Vector3(-48, -35, 0))
	parent.add_child(sun)
	return {"env": e, "sun": sun, "world": we, "cam_attr": ca}


## Per-channel curve: lifts shadows toward `shadow` (teal) and warms the highlights,
## with a gentle S-curve in between. Gives the saturated storybook look.
static func grade_lut(shadow: Color, high: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, shadow)
	g.set_color(1, high)
	g.add_point(0.25, Color(0.2 + shadow.r * 0.5, 0.22 + shadow.g * 0.5, 0.24 + shadow.b * 0.5))
	g.add_point(0.5, Color(0.5, 0.5, 0.49))
	g.add_point(0.78, Color(0.82 * high.r + 0.02, 0.8 * high.g + 0.02, 0.76 * high.b + 0.02))
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


# ---------------------------------------------------------------- terrain

## layers: Array of [texture_name, tiles_per_meter, tint Color]
## height_fn(x, z) -> float, weight_fn(x, z) -> Color (layer weights)
static func terrain(parent: Node, origin: Vector2, size: Vector2, step: float, height_fn: Callable, weight_fn: Callable, layers: Array, glow := Color.BLACK) -> MeshInstance3D:
	var nx := int(size.x / step) + 1
	var nz := int(size.y / step) + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nx * nz)
	cols.resize(nx * nz)
	uvs.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var x := origin.x + ix * step
			var z := origin.y + iz * step
			var i := iz * nx + ix
			verts[i] = Vector3(x, height_fn.call(x, z), z)
			cols[i] = weight_fn.call(x, z)
			uvs[i] = Vector2(x, z) * 0.25
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var k := 0
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var scales := Vector4.ONE
	for i in 4:
		var L: Array = layers[min(i, layers.size() - 1)]
		var d: String = TEX + L[0] + "/"
		mat.set_shader_parameter("l%d_alb" % i, load(d + "albedo.jpg"))
		mat.set_shader_parameter("l%d_nrm" % i, load(d + "normal.jpg"))
		if ResourceLoader.exists(d + "arm.jpg"):
			mat.set_shader_parameter("l%d_arm" % i, load(d + "arm.jpg"))
		scales[i] = L[1]
	mat.set_shader_parameter("scales", scales)
	for i in 4:
		var L: Array = layers[min(i, layers.size() - 1)]
		mat.set_shader_parameter("tint%d" % i, L[2] if L.size() > 2 else Color.WHITE)
	mat.set_shader_parameter("noise_tex", noise_tex())
	mat.set_shader_parameter("glow_color", glow)
	mat.set_shader_parameter("glow_amount", 1.0 if glow != Color.BLACK else 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func floor_collider(parent: Node) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	parent.add_child(body)


static func wall(parent: Node, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	parent.add_child(body)


static func pillar(parent: Node, pos: Vector3, radius: float, height := 3.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, height * 0.5, 0)
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	cs.shape = c
	body.add_child(cs)
	parent.add_child(body)


# ---------------------------------------------------------------- grass

static func blade_mesh() -> ArrayMesh:
	if _blade_mesh:
		return _blade_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var base := 0
	for b in 12:
		var off := Vector2(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.18, 0.18))
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := rng.randf_range(0.16, 0.44)
		var w := rng.randf_range(0.011, 0.022)
		var lean := rng.randf_range(0.05, 0.25)
		var segs := 4
		for s in segs + 1:
			var t := float(s) / segs
			var width := w * (1.0 - t * 0.92)
			var p := Vector3(off.x, 0, off.y) + dir * lean * t * t + Vector3(0, h * t, 0)
			st.set_uv(Vector2(0, t))
			st.add_vertex(p - side * width)
			st.set_uv(Vector2(1, t))
			st.add_vertex(p + side * width)
		for s in segs:
			var i := base + s * 2
			st.add_index(i); st.add_index(i + 1); st.add_index(i + 2)
			st.add_index(i + 1); st.add_index(i + 3); st.add_index(i + 2)
		base += (segs + 1) * 2
	st.generate_normals()
	_blade_mesh = st.commit()
	return _blade_mesh


## density_fn(x, z) -> 0..1 probability of keeping a clump at that spot.
static func grass(parent: Node, rect: Rect2, count: int, density_fn: Callable, height_fn: Callable, o := {}) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = o.get("seed", 1)
	var xfs := []
	var cols := []
	count = int(count * [0.35, 0.7, 1.0][quality])
	var tries := count * 3
	while xfs.size() < count and tries > 0:
		tries -= 1
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		if rng.randf() > density_fn.call(x, z):
			continue
		var s = rng.randf_range(0.7, 1.35) * o.get("scale", 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		xfs.append(Transform3D(b, Vector3(x, height_fn.call(x, z), z)))
		var v := rng.randf_range(0.8, 1.15)
		cols.append(Color(v, v * rng.randf_range(0.95, 1.05), v * 0.95))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade_mesh()
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mat.set_shader_parameter("noise_tex", noise_tex())
	mat.set_shader_parameter("root_color", o.get("root", Color(0.09, 0.14, 0.04)))
	mat.set_shader_parameter("tip_color", o.get("tip", Color(0.42, 0.58, 0.18)))
	mat.set_shader_parameter("dry_color", o.get("dry", Color(0.55, 0.5, 0.26)))
	mat.set_shader_parameter("tip_glow", o.get("glow", Color.BLACK))
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


# ---------------------------------------------------------------- foliage batches

static func card_mesh() -> ArrayMesh:
	if _card_mesh:
		return _card_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# quad pivoted at the bottom centre, where the twig starts in the texture
	var pts := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)]
	var uv := [Vector2(0, 0.95), Vector2(1, 0.95), Vector2(1, -0.05), Vector2(0, -0.05)]
	for i in 4:
		st.set_normal(Vector3(0, 0, 1))
		st.set_uv(uv[i])
		st.add_vertex(pts[i])
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_index(i)
	st.generate_tangents()
	_card_mesh = st.commit()
	return _card_mesh


class FoliageBatch:
	var mat: Material
	var xfs: Array = []
	var centers: Array = []
	var cols: Array = []

	func _init(m: Material) -> void:
		mat = m

	func add(xf: Transform3D, center: Vector3, col: Color) -> void:
		xfs.append(xf)
		centers.append(center)
		cols.append(col)

	func build(parent: Node, shadows := true) -> MultiMeshInstance3D:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = Env.card_mesh()
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, cols[i])
			var c: Vector3 = centers[i]
			mm.set_instance_custom_data(i, Color(c.x, c.y, c.z, 1.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		return mmi


static func _card_xf(rng: RandomNumberGenerator, pos: Vector3, outward: Vector3, size: float) -> Transform3D:
	# face roughly outward from the crown, with random roll and tilt
	var yaw := atan2(outward.x, outward.z) + rng.randf_range(-0.9, 0.9)
	var b := Basis(Vector3.UP, yaw)
	b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.9, 0.5))
	b = b * Basis(Vector3.BACK, rng.randf_range(-0.8, 0.8))
	return Transform3D(b.scaled(Vector3.ONE * size), pos)


# ---------------------------------------------------------------- trees

static func _tube(st: SurfaceTool, path: Array, radii: Array, sides: int, base_index: int, v_scale: float, rng: RandomNumberGenerator, bumpy: float) -> int:
	var count := 0
	var v := 0.0
	for i in path.size():
		var p: Vector3 = path[i]
		var fwd: Vector3
		if i < path.size() - 1:
			fwd = (path[i + 1] - p).normalized()
		else:
			fwd = (p - path[i - 1]).normalized()
		var side := fwd.cross(Vector3.FORWARD if abs(fwd.y) > 0.9 else Vector3.UP).normalized()
		if abs(fwd.y) > 0.9:
			side = Vector3.RIGHT
		var up := side.cross(fwd).normalized()
		if i > 0:
			v += p.distance_to(path[i - 1]) * v_scale
		for s in sides + 1:
			var a := TAU * s / sides
			var r: float = radii[i] * (1.0 + bumpy * sin(a * 3.0 + i * 1.7) * 0.5 + bumpy * rng.randf_range(-0.3, 0.3))
			var n := (side * cos(a) + up * sin(a)).normalized()
			st.set_normal(n)
			st.set_uv(Vector2(float(s) / sides * 2.0, v))
			st.add_vertex(p + n * r)
			count += 1
	for i in path.size() - 1:
		for s in sides:
			var a := base_index + i * (sides + 1) + s
			var b := a + sides + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	return count


## Builds a tree: bark trunk + branches (one mesh) and photo-leaf cards added to `batch`.
## o: height, radius, lean, crown (radius), cards, bark, seed, tint (Color), no_leaves
static func tree(parent: Node, pos: Vector3, batch: FoliageBatch, o := {}) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = o.get("seed", int(pos.x * 131 + pos.z * 71))
	var h: float = o.get("height", 11.0)
	var r: float = o.get("radius", 0.42)
	var crown_r: float = o.get("crown", 3.6)
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lean = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-0.6, 0.3)) * o.get("lean", 0.6)
	var trunk_h: float = h * o.get("trunk_frac", 0.5)
	var path := []
	var radii := []
	var rings := 12
	for i in rings + 1:
		var t := float(i) / rings
		path.append(Vector3(0, trunk_h * t, 0) + lean * t * t + Vector3(sin(t * 5.0 + rng.randf()) * 0.08, 0, cos(t * 4.0) * 0.08))
		var flare: float = 1.0 + 1.3 * pow(max(0.0, 1.0 - t * 5.0), 2.0)
		radii.append(r * lerp(1.0, 0.5, t) * flare)
	var n := _tube(st, path, radii, 14, 0, 0.35, rng, 0.12)
	# roots
	for k in 5:
		var a := TAU * k / 5 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		var rp := [Vector3(0, 0.9, 0) + d * r * 0.3, d * r * 1.2 + Vector3(0, 0.35, 0), d * r * 2.3 + Vector3(0, -0.05, 0)]
		n += _tube(st, rp, [r * 0.45, r * 0.3, r * 0.1], 6, n, 0.5, rng, 0.1)
	# branches
	var anchors := []
	var top: Vector3 = path[rings]
	anchors.append(top + Vector3(0, crown_r * 0.35, 0))
	var nb: int = o.get("branches", 6)
	for k in nb:
		var t := rng.randf_range(0.35, 0.97)
		var start: Vector3 = path[int(t * rings)]
		var a := TAU * k / nb + rng.randf_range(-0.4, 0.4)
		var d := Vector3(cos(a), rng.randf_range(0.35, 0.9), sin(a)).normalized()
		var length := crown_r * rng.randf_range(0.7, 1.1)
		var mid := start + d * length * 0.5 + Vector3(0, length * 0.12, 0)
		var end := start + d * length + Vector3(0, length * 0.25, 0)
		var br = r * lerp(0.5, 0.3, t)
		n += _tube(st, [start, mid, end], [br, br * 0.6, br * 0.2], 7, n, 0.5, rng, 0.05)
		anchors.append(end)
		anchors.append(mid + Vector3(0, 0.3, 0))
	st.generate_tangents()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = pbr(o.get("bark", "bark_willow_02"), 1.0, o.get("bark_tint", Color.WHITE))
	root.add_child(mi)
	pillar(root, Vector3.ZERO, r * 1.25, 4.0)
	if o.get("no_leaves", false) or batch == null:
		return root
	# leaf cards around every anchor, denser near the crown top
	var center := pos + top + Vector3(0, crown_r * 0.1, 0)
	var cards: int = o.get("cards", 320)
	var tint: Color = o.get("tint", Color.WHITE)
	for c in cards:
		var an: Vector3 = anchors[rng.randi() % anchors.size()]
		var off := Vector3(rng.randfn(0, 1), rng.randfn(0, 0.85), rng.randfn(0, 1)).normalized() * crown_r * pow(rng.randf(), 0.4) * 0.85
		var p := pos + an + off
		var outward := (p - center).normalized()
		var size = rng.randf_range(1.3, 2.1) * o.get("card_size", 1.0)
		var shade: float = clamp(0.62 + 0.45 * (p.y - (pos.y + trunk_h * 0.7)) / (crown_r * 1.6), 0.5, 1.12)
		var v := rng.randf_range(0.88, 1.08) * shade
		batch.add(_card_xf(rng, p, outward, size), center, Color(tint.r * v, tint.g * v, tint.b * v))
	return root


static func bush(pos: Vector3, batch: FoliageBatch, radius := 1.0, cards := 40, tint := Color.WHITE, seed := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else int(pos.x * 97 + pos.z * 53)
	var center := pos + Vector3(0, radius * 0.45, 0)
	for c in cards:
		var off := Vector3(rng.randfn(0, 1), abs(rng.randfn(0, 0.6)), rng.randfn(0, 1)).normalized() * radius * pow(rng.randf(), 0.5) * 0.8
		var p := pos + off * Vector3(1, 0.7, 1) - Vector3(0, 0.1, 0)
		var outward := (p - center + Vector3(0, 0.4, 0)).normalized()
		var v = rng.randf_range(0.75, 1.05) * clamp(0.7 + p.y - pos.y, 0.6, 1.1)
		batch.add(_card_xf(rng, p, outward, rng.randf_range(0.8, 1.3) * radius), center, Color(tint.r * v, tint.g * v, tint.b * v))


# ---------------------------------------------------------------- scanned props

static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Places a Poly Haven model. `variant` keeps only the child whose name contains it.
static func prop(parent: Node, name: String, pos: Vector3, scale := 1.0, yaw := 0.0, variant := "", shadows := true) -> Node3D:
	var ps := scene(MODELS + name + "/" + name + ".gltf")
	var n: Node3D = ps.instantiate()
	if variant != "":
		for c in n.get_children():
			if not String(c.name).contains(variant):
				c.queue_free()
			elif c is Node3D:
				(c as Node3D).position = Vector3.ZERO
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	if not shadows:
		for mi in n.find_children("*", "GeometryInstance3D", true, false):
			(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


static func variant_names(name: String) -> Array:
	var ps := scene(MODELS + name + "/" + name + ".gltf")
	var n: Node = ps.instantiate()
	var out := []
	for c in n.get_children():
		out.append(String(c.name))
	n.free()
	return out
