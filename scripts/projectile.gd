class_name Projectile
extends Node3D
## Spells and enemy bolts. Hits are resolved with distance checks on the ground plane.

var velocity := Vector3.ZERO
var damage := 5.0
var team := "enemy"   # "player" projectiles hit enemies/boss, "enemy" ones hit the player
var radius := 0.35
var life := 2.5
var kind := "orb"     # fire, ice, orb, thorn
var slow := 0.0
var _trail: GPUParticles3D
var _light: OmniLight3D


func setup(p_kind: String, p_team: String, p_vel: Vector3, p_damage: float) -> Projectile:
	kind = p_kind
	team = p_team
	velocity = p_vel
	damage = p_damage
	return self


func _ready() -> void:
	add_to_group("projectiles")
	var col := Color(1, 0.55, 0.2)
	match kind:
		"fire":
			col = Color(1.0, 0.5, 0.15)
			add_child(Fx.glow_sphere(0.18, Color(1, 0.8, 0.4), 4.0))
			_trail = Fx.emitter(self, Color(3.0, 1.2, 0.3), 60, 0.45, 0.35, 0.8, 1.5, Vector3(0.12, 0.12, 0.12))
			radius = 0.5
		"ice":
			col = Color(0.55, 0.85, 1.0)
			var mi := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.18, 0.7, 0.18)
			mi.mesh = pm
			mi.rotation = Vector3(PI * 0.5, 0, 0)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.7, 0.9, 1.0, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color(0.5, 0.85, 1.0)
			m.emission_energy_multiplier = 2.5
			m.roughness = 0.1
			mi.material_override = m
			add_child(mi)
			_trail = Fx.emitter(self, Color(1.2, 2.0, 2.6), 30, 0.3, 0.12, 0.3, 0.0)
			look_at_dir()
		"thorn":
			col = Color(0.7, 0.3, 1.0)
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.09
			cm.height = 0.6
			mi.mesh = cm
			mi.rotation = Vector3(PI * 0.5, 0, 0)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.15, 0.08, 0.1)
			m.emission_enabled = true
			m.emission = Color(0.7, 0.2, 1.0)
			m.emission_energy_multiplier = 1.5
			mi.material_override = m
			add_child(mi)
			_trail = Fx.emitter(self, Color(1.4, 0.5, 2.4), 20, 0.3, 0.1, 0.2, 0.0)
			look_at_dir()
		_:
			col = Color(0.6, 0.35, 1.0)
			add_child(Fx.glow_sphere(0.16, Color(0.8, 0.5, 1.0), 3.5))
			_trail = Fx.emitter(self, Color(1.6, 0.8, 3.0), 40, 0.4, 0.22, 0.4, 0.3)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 2.5 if kind == "fire" else 1.2
	_light.omni_range = 5.0
	add_child(_light)


func look_at_dir() -> void:
	if velocity.length() > 0.01:
		rotation.y = atan2(velocity.x, velocity.z)


func _physics_process(dt: float) -> void:
	global_position += velocity * dt
	life -= dt
	var here := Vector2(global_position.x, global_position.z)
	if team == "player":
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and here.distance_to(Vector2(e.global_position.x, e.global_position.z)) < radius + e.radius:
				_hit(e)
				return
		for b in get_tree().get_nodes_in_group("boss"):
			if b.can_be_hit() and b.hit_test(global_position, radius):
				_hit(b)
				return
	else:
		for p in get_tree().get_nodes_in_group("player"):
			if here.distance_to(Vector2(p.global_position.x, p.global_position.z)) < radius + 0.45 and p.hurt(damage, global_position):
				_explode(null)
				return
	if life <= 0.0:
		_explode(null)


func _hit(target: Node) -> void:
	if kind == "fire":
		_explode(target)
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, velocity.normalized() * 4.0, kind)
		if kind == "ice" and target.has_method("apply_slow"):
			target.apply_slow(2.5)
	_explode(null)


func _explode(_direct: Node) -> void:
	var parent := get_parent()
	if kind == "fire":
		Sfx.play("boom")
		Fx.burst(parent, global_position, Color(3.0, 1.3, 0.35), 60, 7.0, 0.7, 0.35, -2.0)
		Fx.burst(parent, global_position, Color(0.25, 0.22, 0.2, 0.6), 20, 2.0, 1.4, 0.8, 1.0, false)
		Fx.flash(parent, global_position, Color(1, 0.6, 0.25), 8.0, 9.0, 0.5)
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.shake(0.35)
		var here := Vector2(global_position.x, global_position.z)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and here.distance_to(Vector2(e.global_position.x, e.global_position.z)) < 2.4 + e.radius:
				var d: Vector3 = (e.global_position - global_position)
				d.y = 0
				e.take_damage(damage, d.normalized() * 7.0, "fire")
		for b in get_tree().get_nodes_in_group("boss"):
			if b.can_be_hit() and b.hit_test(global_position, 2.4):
				b.take_damage(damage, Vector3.ZERO, "fire")
	elif kind == "ice":
		Fx.burst(parent, global_position, Color(1.2, 2.0, 2.6), 16, 3.0, 0.4, 0.12, -6.0)
	else:
		Fx.burst(parent, global_position, Color(1.6, 0.8, 3.0), 16, 3.0, 0.4, 0.15, -3.0)
	if _trail:
		# let the trail finish fading instead of popping out
		_trail.emitting = false
		var t := _trail
		remove_child(t)
		parent.add_child(t)
		t.global_position = global_position
		t.get_tree().create_timer(1.0).timeout.connect(t.queue_free)
	queue_free()
