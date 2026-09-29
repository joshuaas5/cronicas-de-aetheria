class_name Npc
extends StaticBody3D
## A villager (KayKit model) or a sprite of light. Turns to face the player when spoken to.

var display_name := ""
var model_name := ""
var talk: Callable
var idle_anim := "Idle"
var is_fairy := false
var keep: Array = []
var interact_radius := 2.4
var model: Node3D
var ap: AnimationPlayer
var _label: Label3D
var _yaw := 0.0
var _t := 0.0


func setup(p_name: String, p_model: String, p_talk: Callable, yaw := 0.0, p_keep: Array = []) -> Npc:
	display_name = p_name
	model_name = p_model
	keep = p_keep
	talk = p_talk
	_yaw = yaw
	is_fairy = p_model == "fairy"
	return self


func _ready() -> void:
	add_to_group("talkable")
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 0.45
	c.height = 1.8
	cs.shape = c
	cs.position.y = 0.9
	add_child(cs)
	if is_fairy:
		model = Node3D.new()
		add_child(model)
		var core := Fx.glow_sphere(0.14, Color(0.7, 0.9, 1.0), 6.0)
		model.add_child(core)
		for s in [-1, 1]:
			var wing := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.35, 0.5)
			wing.mesh = q
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.4, 1.8, 2.4, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			wing.material_override = m
			wing.position = Vector3(0.2 * s, 0.1, 0)
			wing.rotation.y = 0.5 * s
			wing.name = "wing%d" % s
			model.add_child(wing)
		Fx.emitter(model, Color(1.4, 2.0, 2.8), 40, 1.4, 0.08, 0.3, -0.3, Vector3(0.1, 0.1, 0.1))
		var l := OmniLight3D.new()
		l.light_color = Color(0.6, 0.85, 1.0)
		l.light_energy = 1.5
		l.omni_range = 4.0
		model.add_child(l)
		model.position.y = 1.4
	else:
		model = Chars.instance(model_name, keep)
		add_child(model)
		ap = model.find_children("*", "AnimationPlayer", true, false)[0]
		for a in [idle_anim, "Sit_Chair_Idle", "Idle"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		ap.play(idle_anim if ap.has_animation(idle_anim) else "Idle")
		ap.seek(randf() * 2.0, true)
	model.rotation.y = _yaw
	_label = Label3D.new()
	_label.text = display_name
	_label.font = Fx.font()
	_label.font_size = 42
	_label.outline_size = 12
	_label.outline_modulate = Color(0.06, 0.04, 0.02, 0.0)
	_label.modulate = Color(1.0, 0.92, 0.7, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.006
	_label.position.y = 2.35
	add_child(_label)


func _process(dt: float) -> void:
	_t += dt
	var p: Node3D = get_tree().get_first_node_in_group("player")
	var near := p != null and p.global_position.distance_to(global_position) < interact_radius + 1.0
	_label.modulate.a = lerp(_label.modulate.a, 1.0 if near else 0.0, dt * 6.0)
	_label.outline_modulate.a = _label.modulate.a * 0.85
	_label.visible = _label.modulate.a > 0.02
	if is_fairy:
		model.position.y = 1.4 + sin(_t * 2.2) * 0.18
		model.position.x = sin(_t * 0.7) * 0.25
		for s in [-1, 1]:
			var w: Node3D = model.get_node("wing%d" % s)
			w.rotation.y = s * (0.3 + abs(sin(_t * 24.0)) * 0.9)
	if near:
		var d := p.global_position - global_position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(d.x, d.z), dt * 4.0)
	else:
		model.rotation.y = lerp_angle(model.rotation.y, _yaw, dt * 2.0)


func can_talk(from: Vector3) -> bool:
	return from.distance_to(global_position) < interact_radius


func interact() -> void:
	if ap and ap.has_animation("Interact") and randf() < 0.5:
		ap.play("Interact", 0.2)
		ap.queue(idle_anim if ap.has_animation(idle_anim) else "Idle")
	talk.call()
