class_name Pickup
extends Node3D
## Loot dropped by enemies: gold coins, hearts and mana orbs. Drawn toward the player.

var kind := "coin"
var value := 1
var vel := Vector3.ZERO
var t := 0.0
var life := 16.0
var _mesh: MeshInstance3D


func setup(p_kind: String, p_value := 1) -> Pickup:
	kind = p_kind
	value = p_value
	vel = Vector3(randf_range(-2.5, 2.5), randf_range(4.0, 6.0), randf_range(-2.5, 2.5))
	return self


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	match kind:
		"coin":
			var c := CylinderMesh.new()
			c.top_radius = 0.16
			c.bottom_radius = 0.16
			c.height = 0.04
			c.radial_segments = 20
			_mesh.mesh = c
			_mesh.rotation.x = PI * 0.5
			m.albedo_color = Color(1.0, 0.78, 0.3)
			m.metallic = 1.0
			m.roughness = 0.25
			m.emission_enabled = true
			m.emission = Color(1.0, 0.7, 0.2)
			m.emission_energy_multiplier = 0.4
		"heart":
			var s := SphereMesh.new()
			s.radius = 0.18
			s.height = 0.36
			_mesh.mesh = s
			m.albedo_color = Color(1.0, 0.25, 0.35)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.2, 0.3)
			m.emission_energy_multiplier = 2.5
		_:
			var s := SphereMesh.new()
			s.radius = 0.16
			s.height = 0.32
			_mesh.mesh = s
			m.albedo_color = Color(0.4, 0.6, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.35, 0.6, 1.0)
			m.emission_energy_multiplier = 3.0
	_mesh.material_override = m
	add_child(_mesh)
	if kind != "coin":
		var l := OmniLight3D.new()
		l.light_color = m.emission
		l.light_energy = 1.0
		l.omni_range = 2.5
		add_child(l)


func _physics_process(dt: float) -> void:
	t += dt
	life -= dt
	vel.y -= 14.0 * dt
	position += vel * dt
	if position.y < 0.3:
		position.y = 0.3
		vel.y = abs(vel.y) * 0.35 if abs(vel.y) > 1.5 else 0.0
		vel.x *= 0.7
		vel.z *= 0.7
	_mesh.rotation.y += dt * 4.0
	if vel.y == 0.0:
		_mesh.position.y = sin(t * 3.0) * 0.08
	visible = life > 3.0 or int(life * 8.0) % 2 == 0
	if life <= 0.0:
		queue_free()
		return
	var p: Node3D = get_tree().get_first_node_in_group("player")
	if p == null or t < 0.5:
		return
	var d := p.global_position + Vector3(0, 0.5, 0) - global_position
	if d.length() < 3.0:
		position += d.normalized() * dt * 10.0
	if d.length() < 0.6:
		_collect(p)


func _collect(p: Node3D) -> void:
	match kind:
		"coin":
			var gain = int(value * (1.0 + Game.stat("gold") / 100.0) * (2.0 if Game.legend("collector") else 1.0))
			value = max(1, gain)
			Game.gold += value
			if Game.legend("collector"):
				Game.hp = min(Game.max_hp, Game.hp + Game.max_hp * 0.01)
			Sfx.play("coin")
			Fx.number(get_parent(), global_position + Vector3(0, 0.8, 0), "+%d" % value, Color(1.0, 0.85, 0.35), 40)
		"heart":
			var h := 10.0 + Game.max_hp * 0.12
			Game.hp = min(Game.max_hp, Game.hp + h)
			Sfx.play("heal")
			Fx.number(get_parent(), global_position + Vector3(0, 0.8, 0), "+%d" % h, Color(1.0, 0.5, 0.6), 44)
		_:
			Game.mp = min(Game.max_mp, Game.mp + 5.0 + Game.max_mp * 0.15)
			Sfx.play("heal")
			Fx.number(get_parent(), global_position + Vector3(0, 0.8, 0), "+10", Color(0.5, 0.7, 1.0), 44)
	Fx.burst(get_parent(), global_position, (_mesh.material_override as StandardMaterial3D).albedo_color * 2.0, 10, 2.0, 0.4, 0.08, 0.0)
	Game.stats_changed.emit()
	queue_free()
