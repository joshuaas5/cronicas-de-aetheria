class_name Fx
extends RefCounted
## One-shot visual effects: particle bursts, light flashes, slash arcs, damage numbers.

static var _dot_tex: GradientTexture2D
static var _mats := {}
static var _font: FontVariation


static func dot_tex() -> GradientTexture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.8))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_dot_tex = t
	return _dot_tex


static func particle_mat(additive := true) -> StandardMaterial3D:
	var key := "p%s" % additive
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = dot_tex()
		m.disable_receive_shadows = true
		_mats[key] = m
	return _mats[key]


static func font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = load("res://assets/fonts/Alegreya.ttf")
		_font.variation_opentype = {"wght": 800}
	return _font


static func _fade_ramp(color: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A one-shot burst of glowing particles.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 24, speed := 4.0, life := 0.6, size := 0.12, gravity := -5.0, additive := true, spread := 180.0, dir := Vector3.UP) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.randomness = 0.5
	var m := ParticleProcessMaterial.new()
	m.direction = dir
	m.spread = spread
	m.initial_velocity_min = speed * 0.35
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, gravity, 0)
	m.damping_min = 1.0
	m.damping_max = 3.0
	m.scale_min = 0.6
	m.scale_max = 1.4
	m.color = color
	m.color_ramp = _fade_ramp(Color.WHITE)
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_mat(additive)
	p.draw_pass_1 = q
	p.local_coords = false
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)
	return p


## A continuous emitter that follows its parent (trails, auras). Caller owns it.
static func emitter(parent: Node3D, color: Color, amount := 30, life := 0.6, size := 0.12, speed := 0.6, gravity := 0.5, box := Vector3(0.1, 0.1, 0.1)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = box
	m.direction = Vector3.UP
	m.spread = 180
	m.initial_velocity_min = speed * 0.3
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, gravity, 0)
	m.scale_min = 0.5
	m.scale_max = 1.2
	m.color = color
	m.color_ramp = _fade_ramp(Color.WHITE)
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_mat(true)
	p.draw_pass_1 = q
	p.local_coords = false
	parent.add_child(p)
	return p


static func flash(parent: Node, pos: Vector3, color: Color, energy := 4.0, rng := 6.0, dur := 0.35) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


static func number(parent: Node, pos: Vector3, text: String, color: Color, size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font()
	l.font_size = size
	l.outline_size = 14
	l.outline_modulate = Color(0.08, 0.04, 0.02, 0.9)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.1, 0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


## Glowing crescent for sword swings. `yaw` faces the swing direction.
static func slash(parent: Node, pos: Vector3, yaw: float, color: Color, big := false, flip := false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sweep := 2.2 if big else 1.7
	var r0 := 0.6
	var r1 := 2.2 if big else 1.8
	var segs := 20
	for i in segs + 1:
		var t := float(i) / segs
		var a := -sweep * 0.5 + sweep * t
		var alpha := sin(t * PI) * (t if not flip else 1.0 - t) * 1.6
		var c := Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))
		st.set_color(Color(c.r, c.g, c.b, 0.0))
		st.add_vertex(Vector3(sin(a) * r0, 0, cos(a) * r0))
		st.set_color(c)
		st.add_vertex(Vector3(sin(a) * r1, 0, cos(a) * r1))
	for i in segs:
		var k := i * 2
		st.add_index(k); st.add_index(k + 1); st.add_index(k + 2)
		st.add_index(k + 1); st.add_index(k + 3); st.add_index(k + 2)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(2.2, 2.0, 1.6)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation = Vector3(deg_to_rad(randf_range(-12, 12)), yaw, deg_to_rad(randf_range(-20, 20)))
	mi.scale = Vector3.ONE * 0.8
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.15, 0.22)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(mi.queue_free)


## Ground ring used to telegraph attacks.
static func ring(parent: Node, pos: Vector3, radius: float, color: Color, dur: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius * 0.86
	tm.outer_radius = radius
	tm.rings = 48
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	mi.material_override = m
	mi.scale = Vector3(1, 0.05, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.05, 0)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", color.a * 0.3, dur * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "albedo_color:a", color.a, dur * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(mi.queue_free)
	return mi


static func glow_sphere(radius: float, color: Color, energy := 3.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color * energy
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
