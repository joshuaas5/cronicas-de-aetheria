class_name Loot
extends Node3D
## An item lying on the ground: glowing gem, rarity light beam and floating name.
## Walk over it to pick it up.

var item: Dictionary
var vel := Vector3.ZERO
var t := 0.0
var _gem: Node3D
var _label: Label3D
var _full_warned := false


func setup(p_item: Dictionary) -> Loot:
	item = p_item
	var a := randf() * TAU
	vel = Vector3(cos(a) * randf_range(1.5, 3.5), randf_range(5.0, 7.0), sin(a) * randf_range(1.5, 3.5))
	return self


func _ready() -> void:
	var col := Items.color(item)
	var r: int = item["rarity"]
	_gem = Node3D.new()
	add_child(_gem)
	var model_path := ""
	match String(item["slot"]):
		"weapon":
			model_path = "res://assets/characters/adventurers/sword_1handed.gltf"
		"helm", "chest", "gloves", "boots":
			model_path = "res://assets/characters/adventurers/shield_badge_color.gltf"
	if model_path != "":
		var m: Node3D = load(model_path).instantiate()
		m.scale = Vector3.ONE * 0.5
		m.rotation.z = 0.5
		_gem.add_child(m)
	else:
		var gem := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.16
		pm.height = 0.32
		pm.radial_segments = 8
		pm.rings = 4
		gem.mesh = pm
		var gm := StandardMaterial3D.new()
		gm.albedo_color = col
		gm.metallic = 0.8
		gm.roughness = 0.15
		gm.emission_enabled = true
		gm.emission = col
		gm.emission_energy_multiplier = 1.5
		gem.material_override = gm
		_gem.add_child(gem)
	var core := Fx.glow_sphere(0.12, col, 2.0 + r)
	_gem.add_child(core)
	if r >= 2:
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.28 if r >= 3 else 0.16
		cm.height = 9.0 if r >= 3 else 5.0
		cm.radial_segments = 12
		beam.mesh = cm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.albedo_color = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.55)
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = bm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position.y = cm.height * 0.5
		beam.name = "Beam"
		add_child(beam)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.5 + r * 0.5
		l.omni_range = 4.0
		l.position.y = 0.6
		add_child(l)
	if r >= 3:
		var sparks := Fx.emitter(self, Color(col.r * 2.5, col.g * 2.5, col.b * 2.5), 40, 1.6, 0.08, 0.8, 1.2, Vector3(0.3, 0.1, 0.3))
		sparks.position.y = 0.3
	_label = Label3D.new()
	_label.text = item["name"]
	_label.font = Fx.font()
	_label.font_size = 52 + r * 6
	_label.modulate = col
	_label.outline_size = 10
	_label.outline_modulate = Color(0.02, 0.01, 0.0, 0.9)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.006
	_label.position.y = 1.0
	add_child(_label)
	if r >= 3:
		Sfx.play("legendary")
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.shake(0.4)
	elif r == 2:
		Sfx.play("rare_drop", -4.0)


func _physics_process(dt: float) -> void:
	t += dt
	if vel != Vector3.ZERO:
		vel.y -= 16.0 * dt
		position += vel * dt
		if position.y <= 0.25:
			position.y = 0.25
			vel = Vector3.ZERO
			Fx.burst(get_parent(), global_position, Items.color(item) * 2.0, 12, 2.0, 0.4, 0.08, 0.0)
	_gem.rotation.y += dt * 2.0
	_gem.position.y = sin(t * 3.0) * 0.08
	var p: Node3D = get_tree().get_first_node_in_group("player")
	if p == null or t < 0.7 or p.get_parent() == null:
		return
	var d := p.global_position.distance_to(global_position)
	_label.visible = d < 16.0
	if d < 1.3:
		if Game.add_item(item):
			Sfx.play("pickup", -2.0)
			Fx.burst(get_parent(), global_position + Vector3(0, 0.4, 0), Items.color(item) * 2.2, 18, 2.5, 0.5, 0.1, 0.0)
			var main := get_tree().get_first_node_in_group("main")
			if main:
				main.ui.loot_toast(item)
			queue_free()
		elif not _full_warned:
			_full_warned = true
			Game.toast.emit("Inventário cheio — desmonte itens (I)")
	else:
		_full_warned = false
