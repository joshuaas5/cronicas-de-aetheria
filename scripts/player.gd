class_name Player
extends CharacterBody3D
## Kael, the knight. Sword combo, spells, dodge roll, potions.

signal died

const SPEED := 5.4
const ATTACKS := ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"]

var model: Node3D
var ap: AnimationPlayer
var main: Node
var frozen := false
var state := "idle"
var state_t := 0.0
var state_len := 0.0
var facing := Vector3(0, 0, 1)
var combo := 0
var combo_timer := 0.0
var queued := false
var hit_done := false
var inv := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector3.ZERO
var knock := Vector3.ZERO
var cast_done := false
var _anim := ""


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	model = load("res://assets/characters/adventurers/Knight.glb").instantiate()
	model.scale = Vector3.ONE * 0.75
	add_child(model)
	ap = model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["Idle", "Running_A", "Walking_A", "Cheer", "Spellcasting"]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")


func _play(name: String, blend := 0.15, speed := 1.0) -> void:
	if _anim == name and ap.is_playing() and ap.get_animation(name).loop_mode != Animation.LOOP_NONE:
		return
	_anim = name
	ap.play(name, blend, speed)


func _anim_len(name: String, speed := 1.0) -> float:
	return ap.get_animation(name).length / speed


func _set_state(s: String, length := 0.0) -> void:
	state = s
	state_t = 0.0
	state_len = length


func face(dir: Vector3) -> void:
	dir.y = 0
	if dir.length() > 0.01:
		facing = dir.normalized()


func _physics_process(dt: float) -> void:
	inv = max(0.0, inv - dt)
	dodge_cd -= dt
	combo_timer -= dt
	state_t += dt
	Game.mp = min(Game.max_mp, Game.mp + dt * 1.3)
	knock = knock.lerp(Vector3.ZERO, 1.0 - exp(-dt * 8.0))
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := Vector3(input.x, 0, input.y)
	var vel := Vector3.ZERO
	if state == "dead":
		velocity = knock
		move_and_slide()
		return
	if frozen:
		if state in ["idle", "move"]:
			_play("Idle")
		velocity = knock
		move_and_slide()
		_turn(dt)
		return
	match state:
		"idle", "move":
			if move.length() > 0.1:
				vel = move * SPEED
				face(move)
				_play("Running_A", 0.12, 1.1)
				state = "move"
			else:
				_play("Idle", 0.2)
				state = "idle"
			_handle_actions(move)
		"attack":
			var k := state_t / state_len
			if k < 0.35:
				vel = facing * 3.2 * (1.0 - k / 0.35)
			if not hit_done and k >= 0.38:
				hit_done = true
				_resolve_hit()
			if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact"):
				queued = true
			if k >= 0.62 and queued and combo < 3:
				queued = false
				_start_attack()
			elif k >= 1.0:
				_set_state("idle")
			elif k > 0.7 and move.length() > 0.1:
				_set_state("idle")
		"cast":
			var k := state_t / state_len
			if not cast_done and k >= 0.45:
				cast_done = true
				_release_spell()
			if k >= 1.0:
				_set_state("idle")
		"dodge":
			var k := state_t / state_len
			vel = dodge_dir * 11.0 * (1.0 - k * 0.8)
			if randf() < 0.5:
				Fx.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color(0.75, 0.68, 0.55, 0.5), 2, 1.0, 0.6, 0.4, 0.5, false)
			if k >= 1.0:
				_set_state("idle")
		"hurt":
			if state_t >= state_len:
				_set_state("idle")
		"potion":
			if state_t >= state_len:
				_set_state("idle")
	velocity = vel + knock
	velocity.y = 0
	move_and_slide()
	global_position.y = 0
	_turn(dt)


func _turn(dt: float) -> void:
	var target := atan2(facing.x, facing.z)
	model.rotation.y = lerp_angle(model.rotation.y, target, 1.0 - exp(-dt * 18.0))


func _handle_actions(move: Vector3) -> void:
	if Input.is_action_just_pressed("interact"):
		if main and main.try_interact():
			return
		_start_attack()
		return
	if Input.is_action_just_pressed("attack"):
		_start_attack()
	elif Input.is_action_just_pressed("magic"):
		_start_cast()
	elif Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0:
		dodge_dir = move.normalized() if move.length() > 0.1 else facing
		face(dodge_dir)
		dodge_cd = 0.55
		inv = 0.45
		var n := "Dodge_Forward"
		_set_state("dodge", _anim_len(n, 1.6))
		_play(n, 0.05, 1.6)
		Sfx.play("dash")
	elif Input.is_action_just_pressed("spell_next") and Game.spells.size() > 1:
		Game.spell_idx = (Game.spell_idx + 1) % Game.spells.size()
		Game.stats_changed.emit()
		Sfx.play("blip")
	elif Input.is_action_just_pressed("spell_prev") and Game.spells.size() > 1:
		Game.spell_idx = (Game.spell_idx + Game.spells.size() - 1) % Game.spells.size()
		Game.stats_changed.emit()
		Sfx.play("blip")
	elif Input.is_action_just_pressed("potion"):
		_drink()


# ---------------------------------------------------------------- sword

func _nearest_target(max_d: float, cone: float) -> Node3D:
	var best: Node3D = null
	var bd := max_d
	var targets := get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("boss")
	for e in targets:
		if not e.is_alive():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		var dist := d.length()
		if dist < bd and d.normalized().dot(facing) > cone:
			bd = dist
			best = e
	return best


func _start_attack() -> void:
	combo = combo + 1 if combo_timer > 0.0 and combo < 3 else 1
	combo_timer = 0.9
	var t := _nearest_target(4.0, 0.2)
	if t:
		face(t.global_position - global_position)
	var n: String = ATTACKS[combo - 1]
	var spd := 1.55 if combo < 3 else 1.3
	_set_state("attack", _anim_len(n, spd))
	_play(n, 0.06, spd)
	hit_done = false
	queued = false
	Sfx.play("swing")


func _resolve_hit() -> void:
	var big := combo == 3
	var yaw := atan2(facing.x, facing.z)
	Fx.slash(get_parent(), global_position + Vector3(0, 1.0, 0) + facing * 0.3, yaw, Color(1, 0.95, 0.8), big, combo == 2)
	var reach := 2.5 if big else 2.2
	var dmg := Game.atk * randf_range(0.9, 1.1) * (1.6 if big else 1.0)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() < reach + e.radius and (d.length() < 0.8 or d.normalized().dot(facing) > 0.1):
			e.take_damage(dmg, facing * (9.0 if big else 5.0), "sword")
			hit_any = true
	var tip := global_position + facing * 1.3 + Vector3(0, 1.0, 0)
	for b in get_tree().get_nodes_in_group("boss"):
		if b.can_be_hit() and b.hit_test(tip, reach * 0.6):
			b.take_damage(dmg, Vector3.ZERO, "sword")
			hit_any = true
	if hit_any and main:
		main.hitstop(0.06 if not big else 0.1)
		main.shake(0.15 if not big else 0.3)


# ---------------------------------------------------------------- magic

func _start_cast() -> void:
	var sp := Game.current_spell()
	var cost: int = Game.SPELLS[sp]["cost"]
	if Game.mp < cost:
		Fx.number(get_parent(), global_position + Vector3(0, 2.2, 0), "Sem mana", Color(0.6, 0.75, 1.0), 44)
		Sfx.play("blip")
		return
	Game.mp -= cost
	var t := _nearest_target(14.0, 0.5)
	if t:
		face(t.global_position - global_position)
	var n := "Spellcast_Shoot"
	_set_state("cast", _anim_len(n, 1.5))
	_play(n, 0.08, 1.5)
	cast_done = false
	Fx.burst(get_parent(), global_position + Vector3(0, 1.2, 0), Game.SPELLS[sp]["color"] * 2.0, 20, 1.5, 0.5, 0.15, 1.0)


func _release_spell() -> void:
	var sp := Game.current_spell()
	var origin := global_position + Vector3(0, 1.15, 0) + facing * 0.7
	var parent := get_parent()
	match sp:
		"fire":
			var p := Projectile.new().setup("fire", "player", facing * 15.0, Game.mag * 1.6)
			parent.add_child(p)
			p.global_position = origin
			Sfx.play("fire")
		"ice":
			for off in [-0.26, 0.0, 0.26]:
				var dir := facing.rotated(Vector3.UP, off)
				var p := Projectile.new().setup("ice", "player", dir * 19.0, Game.mag * 0.75)
				p.life = 1.1
				parent.add_child(p)
				p.global_position = origin
			Sfx.play("ice")
		"heal":
			var amt := 20.0 + Game.mag * 1.5
			Game.hp = min(Game.max_hp, Game.hp + amt)
			Fx.number(parent, global_position + Vector3(0, 2.2, 0), "+%d" % amt, Color(0.55, 1.0, 0.55))
			Fx.burst(parent, global_position + Vector3(0, 0.3, 0), Color(0.8, 2.2, 0.9), 50, 2.5, 1.2, 0.18, 2.5, true, 40.0)
			Fx.flash(parent, global_position + Vector3(0, 1.5, 0), Color(0.5, 1, 0.6), 3.0, 6.0, 0.8)
			Sfx.play("heal")
	Game.stats_changed.emit()


func _drink() -> void:
	if Game.potions <= 0:
		Game.toast.emit("Sem poções")
		return
	if Game.hp >= Game.max_hp:
		Game.toast.emit("A vida já está cheia")
		return
	Game.potions -= 1
	Game.hp = min(Game.max_hp, Game.hp + 40)
	Fx.number(get_parent(), global_position + Vector3(0, 2.2, 0), "+40", Color(1.0, 0.55, 0.65))
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(2.4, 0.8, 1.2), 30, 2.0, 0.9, 0.14, 1.5)
	var n := "Use_Item"
	_set_state("potion", _anim_len(n, 1.4))
	_play(n, 0.1, 1.4)
	Sfx.play("heal")
	Game.stats_changed.emit()


# ---------------------------------------------------------------- damage

## Returns true if the hit landed.
func hurt(dmg: float, from: Vector3) -> bool:
	if inv > 0.0 or state == "dead" or state == "dodge" or frozen:
		return false
	Game.hp -= dmg
	inv = 1.0
	var d := global_position - from
	d.y = 0
	knock = d.normalized() * 7.0
	Fx.number(get_parent(), global_position + Vector3(0, 2.0, 0), "%d" % dmg, Color(1.0, 0.4, 0.3))
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(2.5, 0.6, 0.4), 16, 3.0, 0.4, 0.1)
	Sfx.play("hurt")
	if main:
		main.shake(0.4)
		main.hitstop(0.08)
	Game.stats_changed.emit()
	if Game.hp <= 0.0:
		Game.hp = 0
		_set_state("dead")
		_play("Death_A", 0.1)
		died.emit()
	else:
		_set_state("hurt", 0.32)
		_play("Hit_A", 0.05, 1.5)
	return true


func revive() -> void:
	_set_state("idle")
	inv = 1.5
	_anim = ""
	_play("Idle")


func celebrate() -> void:
	_play("Cheer", 0.2)
