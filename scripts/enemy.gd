class_name Enemy
extends CharacterBody3D
## Skeleton foes. Types: minion (sword), warrior (axe + shield), rogue (fast), mage (ranged bolts).

const TYPES := {
	"minion": {"model": "Skeleton_Minion", "hp": 30, "dmg": 7, "speed": 3.3, "xp": 8, "gold": [2, 5], "weapon": "Skeleton_Blade", "range": 1.7},
	"rogue": {"model": "Skeleton_Rogue", "hp": 24, "dmg": 6, "speed": 4.4, "xp": 9, "gold": [2, 6], "weapon": "Skeleton_Blade", "range": 1.6},
	"warrior": {"model": "Skeleton_Warrior", "hp": 64, "dmg": 12, "speed": 2.7, "xp": 16, "gold": [4, 9], "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Small_A", "range": 1.9},
	"mage": {"model": "Skeleton_Mage", "hp": 34, "dmg": 9, "speed": 2.8, "xp": 14, "gold": [3, 8], "weapon": "Skeleton_Staff", "range": 9.0},
}

var type := "minion"
var hp := 30.0
var max_hp := 30.0
var dmg := 7.0
var speed := 3.3
var xp := 8
var radius := 0.55
var attack_range := 1.7
var state := "spawn"
var state_t := 0.0
var state_len := 0.0
var cd := 1.0
var slow := 0.0
var knock := Vector3.ZERO
var hit_done := false
var elite := false
var model: Node3D
var ap: AnimationPlayer
var hpbar: Node3D
var hpfill: MeshInstance3D
var _mats: Array[StandardMaterial3D] = []
var _flash := 0.0
var _anim := ""


func setup(p_type: String, p_elite := false) -> Enemy:
	type = p_type
	elite = p_elite
	var t: Dictionary = TYPES[type]
	var m := 1.35 if elite else 1.0
	max_hp = t["hp"] * m
	hp = max_hp
	dmg = t["dmg"] * m
	speed = t["speed"]
	xp = int(t["xp"] * m)
	attack_range = t["range"]
	return self


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	add_child(cs)
	var t: Dictionary = TYPES[type]
	model = load("res://assets/characters/skeletons/%s.glb" % t["model"]).instantiate()
	model.scale = Vector3.ONE * 0.72
	add_child(model)
	ap = model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["Idle_Combat", "Running_C", "Walking_D_Skeletons", "Running_A", "Spellcasting"]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_attach(sk, "handslot.r", t["weapon"])
	if t.has("shield"):
		_attach(sk, "handslot.l", t["shield"])
	# per-instance materials so hits can flash white
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var base = mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var dup: StandardMaterial3D = base.duplicate()
				if elite and String(base.resource_name) == "skeleton":
					dup.albedo_color = Color(0.85, 0.7, 1.0)
				mi.set_surface_override_material(s, dup)
				_mats.append(dup)
	_make_hpbar()
	_set_state("spawn", _anim_len("Spawn_Ground_Skeletons"))
	_play("Spawn_Ground_Skeletons", 0.0)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color(0.45, 0.36, 0.25, 0.8), 30, 3.0, 0.9, 0.35, -6.0, false, 60.0)
	Sfx.play("spawn", -4.0)


func _attach(sk: Skeleton3D, bone: String, item: String) -> void:
	if sk.find_bone(bone) < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var w: Node3D = load("res://assets/characters/skeletons/%s.gltf" % item).instantiate()
	ba.add_child(w)


func _make_hpbar() -> void:
	hpbar = Node3D.new()
	hpbar.position = Vector3(0, 2.15, 0)
	add_child(hpbar)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.09)
	bg.mesh = q
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.05, 0.03, 0.02, 0.8)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.no_depth_test = true
	bm.render_priority = 1
	bg.material_override = bm
	hpbar.add_child(bg)
	hpfill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.86, 0.06)
	q2.center_offset = Vector3(0.43, 0, 0)
	hpfill.mesh = q2
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.6, 0.35, 0.25)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.no_depth_test = true
	fm.render_priority = 2
	hpfill.material_override = fm
	hpfill.position.x = -0.43
	hpbar.add_child(hpfill)
	hpbar.visible = false


func _play(name: String, blend := 0.15, spd := 1.0) -> void:
	if not ap.has_animation(name):
		return
	if _anim == name and ap.is_playing() and ap.get_animation(name).loop_mode != Animation.LOOP_NONE:
		ap.speed_scale = 1.0
		return
	_anim = name
	ap.play(name, blend, spd)


func _anim_len(name: String, spd := 1.0) -> float:
	return ap.get_animation(name).length / spd if ap.has_animation(name) else 0.8


func _set_state(s: String, length := 0.0) -> void:
	state = s
	state_t = 0.0
	state_len = length


func is_alive() -> bool:
	return state != "dead" and state != "spawn"


func apply_slow(t: float) -> void:
	slow = max(slow, t)


func _physics_process(dt: float) -> void:
	state_t += dt
	cd -= dt * (0.5 if slow > 0.0 else 1.0)
	slow -= dt
	knock = knock.lerp(Vector3.ZERO, 1.0 - exp(-dt * 7.0))
	if _flash > 0.0:
		_flash -= dt
		var e := _flash > 0.0
		for m in _mats:
			m.emission_enabled = e
			if e:
				m.emission = Color(1, 1, 1)
				m.emission_energy_multiplier = 1.4
	for m in _mats:
		if slow > 0.0 and _flash <= 0.0:
			m.emission_enabled = true
			m.emission = Color(0.3, 0.6, 1.0)
			m.emission_energy_multiplier = 0.6
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var vel := Vector3.ZERO
	var spd := speed * (0.45 if slow > 0.0 else 1.0)
	var to_p := Vector3.ZERO
	var dist := 99.0
	if player:
		to_p = player.global_position - global_position
		to_p.y = 0
		dist = to_p.length()
	var frozen: bool = player == null or player.frozen or player.state == "dead"
	match state:
		"spawn":
			if state_t >= state_len * 0.9:
				_set_state("chase")
		"chase":
			if frozen:
				_play("Idle_Combat" if ap.has_animation("Idle_Combat") else "Idle")
			elif type == "mage":
				var want := 7.0
				var tangent := Vector3(-to_p.z, 0, to_p.x).normalized()
				vel = (to_p.normalized() * clamp(dist - want, -1.0, 1.0) + tangent * 0.5) * spd
				_face(to_p)
				_play("Walking_D_Skeletons" if vel.length() > 0.5 else "Idle_Combat", 0.2)
				if cd <= 0.0 and dist < 13.0:
					_set_state("cast", _anim_len("Spellcast_Shoot", 1.2))
					_play("Spellcast_Shoot", 0.1, 1.2)
					hit_done = false
			else:
				if dist > attack_range * 0.85:
					vel = to_p.normalized() * spd
					_play("Running_C" if type == "rogue" else "Walking_D_Skeletons", 0.2, 1.4 if type != "rogue" else 1.0)
				else:
					_play("Idle_Combat", 0.2)
				_face(to_p)
				if dist < attack_range and cd <= 0.0:
					var n := "1H_Melee_Attack_Chop" if type != "rogue" else "1H_Melee_Attack_Stab"
					_set_state("attack", _anim_len(n, 1.1))
					_play(n, 0.1, 1.1)
					hit_done = false
		"attack":
			var k := state_t / state_len
			if k < 0.4:
				_face(to_p)
			if not hit_done and k >= 0.48:
				hit_done = true
				if player and dist < attack_range + 0.5 and to_p.normalized().dot(_forward()) > 0.3:
					player.hurt(dmg, global_position)
				Sfx.play("swing", -6.0)
			if k >= 1.0:
				cd = randf_range(0.9, 1.6)
				_set_state("chase")
		"cast":
			var k := state_t / state_len
			_face(to_p)
			if not hit_done and k >= 0.45:
				hit_done = true
				var p := Projectile.new().setup("orb", "enemy", to_p.normalized() * 7.5, dmg)
				get_parent().add_child(p)
				p.global_position = global_position + Vector3(0, 1.3, 0) + _forward() * 0.6
				Sfx.play("orb", -4.0)
			if k >= 1.0:
				cd = randf_range(2.0, 3.0)
				_set_state("chase")
		"hurt":
			if state_t >= state_len:
				_set_state("chase")
		"dead":
			if state_t > 1.8:
				global_position.y -= dt * 0.6
			if state_t > 3.2:
				queue_free()
			velocity = Vector3.ZERO
			return
	velocity = vel + knock
	velocity.y = 0
	move_and_slide()
	global_position.y = 0


func _forward() -> Vector3:
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))


func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.2)


func take_damage(amount: float, push: Vector3, kind: String) -> void:
	if not is_alive():
		return
	hp -= amount
	knock = push
	_flash = 0.1
	var col := Color(1, 1, 1)
	if kind == "fire":
		col = Color(1, 0.65, 0.3)
	elif kind == "ice":
		col = Color(0.6, 0.85, 1)
	Fx.number(get_parent(), global_position + Vector3(0, 2.0, 0), "%d" % amount, col)
	Fx.burst(get_parent(), global_position + Vector3(0, 1.1, 0), Color(2.2, 2.0, 1.6), 12, 4.0, 0.3, 0.08, -8.0)
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(0.9, 0.88, 0.8), 6, 3.0, 0.8, 0.07, -12.0, false)
	Sfx.play("hit")
	hpbar.visible = true
	hpfill.scale.x = max(0.0, hp / max_hp)
	if hp <= 0.0:
		_die()
	elif state != "attack" or amount > max_hp * 0.25:
		_set_state("hurt", 0.35)
		_play("Hit_B", 0.05, 1.4)


func _die() -> void:
	_set_state("dead")
	hpbar.visible = false
	remove_from_group("enemies")
	collision_layer = 0
	_play("Death_C_Skeletons" if ap.has_animation("Death_C_Skeletons") else "Death_A", 0.05)
	Sfx.play("bones")
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(1.4, 0.8, 2.4), 30, 3.5, 1.0, 0.14, 1.0)
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.on_enemy_killed(self)
