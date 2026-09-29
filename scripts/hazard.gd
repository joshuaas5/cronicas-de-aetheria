class_name Hazard
extends Node3D
## Ground effects: burning patches, delayed blasts and frost rings.
## team "enemy" hurts the player, team "player" hurts monsters.

var kind := "fire"      # fire | blast | frost
var team := "enemy"
var radius := 1.2
var damage := 5.0
var life := 3.0
var delay := 0.0
var attacker: Node = null
var _tick := 0.0
var _t := 0.0
var _fired := false
var _fx: GPUParticles3D


func setup(p_kind: String, p_team: String, p_radius: float, p_damage: float, p_life := 3.0, p_delay := 0.0) -> Hazard:
	kind = p_kind
	team = p_team
	radius = p_radius
	damage = p_damage
	life = p_life
	delay = p_delay
	return self


func _ready() -> void:
	match kind:
		"fire":
			_fx = Fx.emitter(self, Color(3.0, 1.1, 0.25), int(24 * radius), 0.8, 0.3, 1.0, 1.8, Vector3(radius * 0.7, 0.05, radius * 0.7))
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.5, 0.2)
			l.light_energy = 1.0
			l.omni_range = radius * 3.0
			l.position.y = 0.5
			add_child(l)
		"blast":
			Fx.ring(get_parent(), global_position, radius, Color(2.2, 0.6, 0.3, 0.9), delay)
		"frost":
			Fx.ring(get_parent(), global_position, radius, Color(0.6, 1.4, 2.4, 0.9), delay)


func _physics_process(dt: float) -> void:
	_t += dt
	if kind == "fire":
		_tick -= dt
		if _tick <= 0.0:
			_tick = 0.5
			_hit_area(damage, "burn")
		if _t >= life:
			_end()
		return
	if not _fired and _t >= delay:
		_fired = true
		if kind == "blast":
			Fx.burst(get_parent(), global_position + Vector3(0, 0.4, 0), Color(3.0, 1.2, 0.35), 50, 7.0, 0.7, 0.3, -2.0)
			Fx.flash(get_parent(), global_position + Vector3(0, 1, 0), Color(1, 0.6, 0.3), 6.0, 8.0, 0.4)
			Sfx.play("boom", -3.0)
			_hit_area(damage, "fire")
		else:
			Fx.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color(1.5, 2.2, 3.0), 40, 4.0, 0.9, 0.2, -3.0)
			Sfx.play("ice", -3.0)
			_hit_area(damage, "ice")
		queue_free()


func _hit_area(dmg: float, dkind: String) -> void:
	var here := Vector2(global_position.x, global_position.z)
	if team == "enemy":
		var p: Node3D = get_tree().get_first_node_in_group("player")
		if p and p.get_parent() and here.distance_to(Vector2(p.global_position.x, p.global_position.z)) < radius + 0.3:
			if p.hurt(dmg, global_position, attacker) and dkind == "ice" and p.has_method("stun"):
				p.stun(1.0)
	else:
		var pl: Node = get_tree().get_first_node_in_group("player")
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and here.distance_to(Vector2(e.global_position.x, e.global_position.z)) < radius + e.radius:
				if pl and pl.has_method("deal"):
					pl.deal(e, dmg, Vector3.ZERO, dkind, false)
				else:
					e.take_damage(dmg, Vector3.ZERO, dkind)


func _end() -> void:
	if _fx:
		_fx.emitting = false
	set_physics_process(false)
	get_tree().create_timer(1.0).timeout.connect(queue_free)
