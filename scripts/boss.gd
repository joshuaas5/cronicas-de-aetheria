class_name Boss
extends Node3D
## Carvalho Ancião Corrompido — a scanned dead trunk stood upright, with root base,
## swinging branch arms, glowing eyes and a corrupted crown.

signal defeated

var max_hp := 420.0
var hp := 420.0
var phase := 1
var state := "intro"
var state_t := 0.0
var state_len := 2.2
var cd := 2.5
var arm_angle := 0.9
var dead := false
var radius := 1.6
var arm_l: Node3D
var arm_r: Node3D
var eyes: Array[MeshInstance3D] = []
var eye_light: OmniLight3D
var aura: GPUParticles3D
var body: Node3D
var bark_mats: Array[StandardMaterial3D] = []
var _flash := 0.0
var _level: Node


func _ready() -> void:
	add_to_group("boss")
	_level = get_parent()
	body = Node3D.new()
	add_child(body)
	# trunk: the scanned log lies along +X, stand it up
	var trunk := Env.prop(body, "dead_tree_trunk_02", Vector3(0, 0, 0), 2.3, 0.0)
	trunk.rotation = Vector3(0, 0, PI * 0.5)
	trunk.position = Vector3(0.0, 1.92 * 2.3 - 0.4, 0)
	Env.prop(body, "root_cluster_01", Vector3(0, -0.15, 0), 1.5, 0.4)
	Env.prop(body, "root_cluster_01", Vector3(0.3, -0.2, -0.4), 1.2, 2.6)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var base = mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var dup: StandardMaterial3D = base.duplicate()
				dup.albedo_color = Color(0.62, 0.52, 0.62)
				dup.emission_enabled = true
				dup.emission = Color(0.5, 0.1, 0.8)
				dup.emission_energy_multiplier = 0.15
				mi.set_surface_override_material(s, dup)
				bark_mats.append(dup)
	# crown of corrupted leaves
	var batch := Env.FoliageBatch.new(Env.foliage_mat("leaf_cluster_b", Color(0.7, 0.45, 0.95), Color(0.12, 0.0, 0.2)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	var crown := Vector3(0, 8.4, 0)
	for i in 220:
		var off := Vector3(rng.randfn(0, 1), rng.randfn(0, 0.6), rng.randfn(0, 1)).normalized() * 3.2 * pow(rng.randf(), 0.5)
		var p := crown + off
		var outward := (p - crown).normalized()
		var v := rng.randf_range(0.7, 1.05)
		batch.add(Env._card_xf(rng, p, outward, rng.randf_range(1.3, 2.0)), crown, Color(v, v, v))
	batch.build(body)
	# arms
	arm_l = _make_arm(-1)
	arm_r = _make_arm(1)
	# face
	for sx in [-0.42, 0.42]:
		var e := Fx.glow_sphere(0.16, Color(0.95, 0.5, 1.0), 6.0)
		e.position = Vector3(sx, 5.1, 0.95)
		body.add_child(e)
		eyes.append(e)
	var mouth := Fx.glow_sphere(0.1, Color(0.7, 0.2, 1.0), 3.0)
	mouth.scale = Vector3(4.0, 0.8, 1.0)
	mouth.position = Vector3(0, 4.35, 0.95)
	body.add_child(mouth)
	eye_light = OmniLight3D.new()
	eye_light.light_color = Color(0.8, 0.35, 1.0)
	eye_light.light_energy = 3.0
	eye_light.omni_range = 9.0
	eye_light.position = Vector3(0, 5.0, 1.6)
	body.add_child(eye_light)
	aura = Fx.emitter(body, Color(1.2, 0.4, 2.2), 90, 2.2, 0.3, 0.8, 0.8, Vector3(1.8, 3.5, 1.8))
	aura.position = Vector3(0, 3.5, 0)
	body.position.y = -9.0
	Sfx.play("roar")


func _make_arm(side: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(1.0 * side, 6.1, 0.2)
	body.add_child(pivot)
	# the log lies along +X; hang it downward from the shoulder
	var arm := Env.prop(pivot, "dead_tree_trunk", Vector3.ZERO, 1.9, 0.0)
	arm.rotation = Vector3(0, 0, -PI * 0.5 if side > 0 else PI * 0.5)
	arm.position = Vector3(0.0, -1.4 * 1.9, 0.0)
	for mi in arm.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var base = mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var dup: StandardMaterial3D = base.duplicate()
				dup.albedo_color = Color(0.6, 0.5, 0.6)
				mi.set_surface_override_material(s, dup)
				bark_mats.append(dup)
	return pivot


func is_alive() -> bool:
	return not dead and state != "intro" and state != "dying"


func can_be_hit() -> bool:
	return is_alive()


func hit_test(p: Vector3, r: float) -> bool:
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	return d < radius + r + 0.6 and p.y < 9.0


func _physics_process(dt: float) -> void:
	state_t += dt
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.7 + 0.3 * sin(t * 5.0)
	for e in eyes:
		(e.material_override as StandardMaterial3D).albedo_color = (Color(1.0, 0.3, 0.55) if phase == 2 else Color(0.95, 0.5, 1.0)) * (4.0 + pulse * 4.0)
	eye_light.light_energy = 2.0 + pulse * 2.5
	if _flash > 0.0:
		_flash -= dt
	for m in bark_mats:
		m.emission_energy_multiplier = (1.2 if _flash > 0.0 else (0.15 + (0.25 * pulse if phase == 2 else 0.0)))
		m.emission = Color(1, 1, 1) if _flash > 0.0 else Color(0.5, 0.1, 0.8)
	var sway := sin(t * 1.4) * 0.08
	match state:
		"intro":
			body.position.y = lerp(-9.0, 0.0, ease(clamp(state_t / state_len, 0.0, 1.0), 0.4))
			if state_t > 0.2 and randf() < 0.6:
				Fx.burst(_level, global_position + Vector3(randf_range(-2, 2), 0.1, randf_range(-2, 2)), Color(0.4, 0.3, 0.22, 0.8), 6, 4.0, 1.0, 0.5, -8.0, false, 50.0)
			if state_t >= state_len:
				body.position.y = 0.0
				state = "idle"
				Sfx.play("roar")
				var main := get_tree().get_first_node_in_group("main")
				if main:
					main.shake(0.8)
		"idle":
			arm_angle = lerp(arm_angle, 0.9 + sway, dt * 3.0)
			if player == null or player.frozen or player.state == "dead":
				pass
			else:
				cd -= dt * (1.45 if phase == 2 else 1.0)
				if cd <= 0.0:
					_choose(player)
		"wind":
			arm_angle = lerp(0.9, 2.7, clamp(state_t / state_len, 0.0, 1.0))
			if state_t >= state_len:
				state = "slam"
				state_t = 0.0
				_slam(player)
		"slam":
			arm_angle = lerp(arm_angle, 0.15, dt * 22.0)
			if state_t > 0.5:
				state = "idle"
		"dying":
			body.position.y -= dt * 1.2
			body.rotation.z = sin(state_t * 12.0) * 0.03
			if randf() < 0.7:
				Fx.burst(_level, global_position + Vector3(randf_range(-2, 2), randf_range(1, 8), randf_range(-1, 1.5)), Color(2.2, 1.6, 2.6), 14, 3.0, 0.9, 0.2, 0.5)
			if state_t > 3.2 and not dead:
				dead = true
				defeated.emit()
				queue_free()
	arm_l.rotation.z = -arm_angle
	arm_r.rotation.z = arm_angle
	arm_l.rotation.x = sin(t * 1.1) * 0.1
	arm_r.rotation.x = sin(t * 1.3 + 1.0) * 0.1


func _choose(player: Node3D) -> void:
	var to_p := player.global_position - global_position
	to_p.y = 0
	var d := to_p.length()
	if d < 5.5:
		state = "wind"
		state_t = 0.0
		state_len = 0.55 if phase == 2 else 0.8
		Fx.ring(_level, global_position + Vector3(0, 0, 1.8), 5.0, Color(2.0, 0.3, 0.3, 0.8), state_len)
		cd = 1.8
		return
	var r := randf()
	var skeletons := get_tree().get_nodes_in_group("enemies").size()
	if r < 0.4:
		var n := 13 if phase == 2 else 9
		var base := atan2(to_p.x, to_p.z)
		for i in n:
			var a := base + (i - (n - 1) * 0.5) * 0.14
			var p := Projectile.new().setup("thorn", "enemy", Vector3(sin(a), 0, cos(a)) * 8.0, 8.0)
			p.life = 3.5
			_level.add_child(p)
			p.global_position = global_position + Vector3(0, 1.3, 1.4)
		Sfx.play("orb")
		cd = 2.0
	elif r < 0.78 or skeletons >= 3:
		var n := 5 if phase == 2 else 3
		for i in n:
			var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-3, 3), 0, randf_range(-2, 2))
			_root_spike(player.global_position + off)
		cd = 2.3
	else:
		for i in 2:
			var e := Enemy.new().setup("minion", true)
			_level.add_child(e)
			e.global_position = global_position + Vector3(randf_range(-4, 4), 0, randf_range(2.5, 4.0))
		cd = 2.4


func _root_spike(pos: Vector3) -> void:
	pos.y = 0
	var warn := 0.85
	Fx.ring(_level, pos, 1.1, Color(1.6, 0.4, 2.4, 0.9), warn)
	var tw := create_tween()
	tw.tween_interval(warn)
	tw.tween_callback(func():
		if not is_instance_valid(_level):
			return
		var spike := Env.prop(_level, "pine_roots", pos, 1.0, randf() * TAU)
		spike.scale = Vector3(1.2, 0.1, 1.2)
		var st := spike.create_tween()
		st.tween_property(spike, "scale", Vector3(1.2, 7.0, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		st.tween_interval(0.5)
		st.tween_property(spike, "scale", Vector3(1.2, 0.05, 1.2), 0.3)
		st.tween_callback(spike.queue_free)
		Fx.burst(_level, pos + Vector3(0, 0.2, 0), Color(0.45, 0.35, 0.25, 0.9), 18, 5.0, 0.8, 0.3, -10.0, false, 45.0)
		Fx.burst(_level, pos + Vector3(0, 0.4, 0), Color(1.6, 0.5, 2.4), 16, 3.0, 0.6, 0.15, 0.0)
		Sfx.play("hit", -4.0)
		var pl: Node3D = get_tree().get_first_node_in_group("player")
		if pl and Vector2(pl.global_position.x - pos.x, pl.global_position.z - pos.z).length() < 1.2:
			pl.hurt(13.0 if phase == 2 else 10.0, pos)
	)


func _slam(player: Node3D) -> void:
	Sfx.play("boom")
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.shake(0.9)
	var front := global_position + Vector3(0, 0, 1.8)
	Fx.burst(_level, front, Color(0.45, 0.35, 0.25, 0.9), 60, 9.0, 1.0, 0.45, -12.0, false, 70.0)
	Fx.burst(_level, front + Vector3(0, 0.3, 0), Color(2.0, 0.6, 2.6), 40, 7.0, 0.7, 0.2, -2.0, true, 80.0)
	if player:
		var d := Vector2(player.global_position.x - front.x, player.global_position.z - front.z).length()
		if d < 5.0:
			player.hurt(16.0 if phase == 2 else 12.0, global_position)


func take_damage(amount: float, _push: Vector3, kind: String) -> void:
	if not is_alive():
		return
	if kind == "fire":
		amount *= 1.5
	hp -= amount
	_flash = 0.1
	var col := Color(1, 0.65, 0.3) if kind == "fire" else Color(0.9, 0.8, 1.0)
	Fx.number(_level, global_position + Vector3(randf_range(-1.5, 1.5), randf_range(3.5, 6.0), 1.5), ("%d!" if kind == "fire" else "%d") % amount, col, 80 if kind == "fire" else 64)
	Sfx.play("hit")
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		Sfx.play("roar")
		Game.toast.emit("O Carvalho Ancião enfurece!")
		aura.amount = 180
		for i in 3:
			var e := Enemy.new().setup("minion", true)
			_level.add_child(e)
			e.global_position = global_position + Vector3(randf_range(-5, 5), 0, randf_range(2.5, 5.0))
	if hp <= 0.0:
		hp = 0
		state = "dying"
		state_t = 0.0
		for e in get_tree().get_nodes_in_group("enemies"):
			e.take_damage(999, Vector3.ZERO, "sword")
		for p in get_tree().get_nodes_in_group("projectiles"):
			p.queue_free()
		Sfx.play("roar")
