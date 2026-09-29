class_name Player
extends CharacterBody3D
## Kael. Four vocations, sword combos, spells, dodge roll, potions and every
## Mana Tree skill.

signal died

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
var phoenix_used := false
var _anim := ""
var _dash_hits := []


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
	_build_model()
	Game.class_changed.connect(_on_class_changed)


func _build_model() -> void:
	var yaw := model.rotation.y if model else 0.0
	if model:
		model.queue_free()
	var c := Game.class_data()
	model = Chars.instance(c["model"], c["keep"])
	add_child(model)
	model.rotation.y = yaw
	ap = model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["Idle", "Running_A", "Walking_A", "Cheer", "Spellcasting", "2H_Melee_Idle"]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_anim = ""
	_play("Idle")


func _on_class_changed() -> void:
	_build_model()
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(2.4, 2.0, 1.0), 70, 4.0, 1.0, 0.16, 1.0)
	Fx.flash(get_parent(), global_position + Vector3(0, 1.5, 0), Color(1, 0.9, 0.6), 5.0, 7.0, 0.8)
	Sfx.play("level")
	celebrate()


func _play(name: String, blend := 0.15, speed := 1.0) -> void:
	if not ap.has_animation(name):
		return
	if _anim == name and ap.is_playing() and ap.get_animation(name).loop_mode != Animation.LOOP_NONE:
		return
	_anim = name
	ap.play(name, blend, speed)


func _anim_len(name: String, speed := 1.0) -> float:
	return ap.get_animation(name).length / speed if ap.has_animation(name) else 0.6


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
	var c := Game.class_data()
	Game.mp = min(Game.max_mp, Game.mp + dt * 1.3 * (1.5 if Game.has_skill("m_flow") else 1.0))
	if Game.has_skill("v_regen") and state != "dead":
		Game.hp = min(Game.max_hp, Game.hp + dt * (0.6 + Game.max_hp * 0.004))
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
				vel = move * c["speed"]
				face(move)
				_play("Running_A", 0.12, 1.1 * c["speed"] / 5.4)
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
			if k >= 0.62 and queued and combo < _max_combo():
				queued = false
				_start_attack()
			elif k >= 1.0:
				_set_state("idle")
			elif k > 0.7 and move.length() > 0.1:
				_set_state("idle")
		"dash_strike":
			var k := state_t / state_len
			vel = facing * 15.0 * (1.0 - k * 0.7)
			_dash_damage()
			if k >= 1.0:
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
			if Game.has_skill("s_dash") and Input.is_action_just_pressed("attack"):
				_start_dash_strike()
			elif k >= 1.0:
				_set_state("idle")
		"hurt", "potion":
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
		dodge_cd = Game.class_data()["dodge_cd"]
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

func _max_combo() -> int:
	return 4 if Game.has_skill("s_combo") else 3


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
		if dist < bd and (dist < 0.5 or d.normalized().dot(facing) > cone):
			bd = dist
			best = e
	return best


func _start_attack() -> void:
	combo = combo + 1 if combo_timer > 0.0 and combo < _max_combo() else 1
	combo_timer = 0.9
	var t := _nearest_target(4.0, 0.2)
	if t:
		face(t.global_position - global_position)
	var c := Game.class_data()
	var n: String = c["attacks"][combo - 1]
	if combo == 3 and Game.has_skill("s_spin"):
		n = "2H_Melee_Attack_Spin"
	var spd: float = c["attack_speed"] * (1.0 if combo < 3 else 0.85)
	_set_state("attack", _anim_len(n, spd))
	_play(n, 0.06, spd)
	hit_done = false
	queued = false
	Sfx.play("swing")


func _roll_damage(mult: float) -> Array:
	var crit := randf() < Game.crit_chance()
	return [Game.atk * randf_range(0.9, 1.1) * mult * (2.0 if crit else 1.0), crit]


func _resolve_hit() -> void:
	var c := Game.class_data()
	var spin := combo == 3 and Game.has_skill("s_spin")
	var big := combo >= 3
	var yaw := atan2(facing.x, facing.z)
	var reach: float = (2.5 if big else 2.2) + c["reach"]
	var mult := 1.0
	if combo == 3:
		mult = 1.6
	elif combo == 4:
		mult = 2.2
	if spin:
		for k in 3:
			Fx.slash(get_parent(), global_position + Vector3(0, 1.0, 0), yaw + k * TAU / 3.0, Color(1, 0.95, 0.8), true, false)
		reach += 0.4
	else:
		Fx.slash(get_parent(), global_position + Vector3(0, 1.0, 0) + facing * 0.3, yaw, Color(1, 0.95, 0.8), big, combo == 2)
	var push := 9.0 if big else 5.0
	if combo == 4:
		push = 16.0
	var hit_any := false
	var any_crit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() < reach + e.radius and (spin or d.length() < 0.8 or d.normalized().dot(facing) > 0.1):
			var r := _roll_damage(mult)
			var dir := d.normalized() if spin else facing
			e.take_damage(r[0], dir * push, "crit" if r[1] else "sword")
			any_crit = any_crit or r[1]
			hit_any = true
	var tip := global_position + facing * 1.3 + Vector3(0, 1.0, 0)
	for b in get_tree().get_nodes_in_group("boss"):
		if b.can_be_hit() and b.hit_test(global_position if spin else tip, reach * (1.0 if spin else 0.6)):
			var r := _roll_damage(mult)
			b.take_damage(r[0], Vector3.ZERO, "crit" if r[1] else "sword")
			any_crit = any_crit or r[1]
			hit_any = true
	if hit_any and main:
		main.hitstop(0.12 if any_crit else (0.06 if not big else 0.1))
		main.shake(0.35 if any_crit else (0.15 if not big else 0.3))


func _start_dash_strike() -> void:
	var n := "1H_Melee_Attack_Stab"
	_set_state("dash_strike", 0.32)
	_play(n, 0.03, 2.0)
	_dash_hits = []
	inv = 0.4
	Sfx.play("swing")
	Fx.slash(get_parent(), global_position + Vector3(0, 1.0, 0), atan2(facing.x, facing.z), Color(1.0, 0.8, 0.5), true)


func _dash_damage() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or _dash_hits.has(e):
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() < 1.6 + e.radius:
			_dash_hits.append(e)
			var r := _roll_damage(2.0)
			e.take_damage(r[0], facing * 10.0, "crit" if r[1] else "sword")
			if main:
				main.hitstop(0.07)
				main.shake(0.25)
	for b in get_tree().get_nodes_in_group("boss"):
		if not _dash_hits.has(b) and b.can_be_hit() and b.hit_test(global_position + Vector3(0, 1, 0), 1.2):
			_dash_hits.append(b)
			b.take_damage(_roll_damage(2.0)[0], Vector3.ZERO, "sword")


# ---------------------------------------------------------------- magic

func _start_cast() -> void:
	var sp := Game.current_spell()
	var cost := Game.spell_cost(sp)
	if Game.mp < cost:
		Fx.number(get_parent(), global_position + Vector3(0, 2.2, 0), "Sem mana", Color(0.6, 0.75, 1.0), 44)
		Sfx.play("blip")
		return
	if Game.has_skill("m_echo") and randf() < 0.25:
		Fx.number(get_parent(), global_position + Vector3(0, 2.4, 0), "Eco!", Color(0.8, 0.7, 1.0), 44)
	else:
		Game.mp -= cost
	var t := _nearest_target(14.0, 0.5)
	if t:
		face(t.global_position - global_position)
	var n := "Spellcast_Shoot"
	var spd := 1.5 * (1.3 if Game.cls == "mage" else 1.0)
	_set_state("cast", _anim_len(n, spd))
	_play(n, 0.08, spd)
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
			var offs := [-0.26, 0.0, 0.26]
			if Game.has_skill("m_frost"):
				offs = [-0.4, -0.2, 0.0, 0.2, 0.4]
			for off in offs:
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
		"bolt":
			_lightning(origin)
	Game.stats_changed.emit()


## Chain lightning: jumps between up to four enemies.
func _lightning(origin: Vector3) -> void:
	var parent := get_parent()
	var hit := []
	var from := origin
	var dmg := Game.mag * 1.35
	var first := _nearest_target(13.0, 0.3)
	var cur: Node3D = first
	var pts := [origin]
	for i in 4:
		if cur == null:
			break
		hit.append(cur)
		var to: Vector3 = cur.global_position + Vector3(0, 1.1, 0)
		pts.append(to)
		cur.take_damage(dmg, (to - from).normalized() * 3.0, "bolt")
		if cur.has_method("apply_stun"):
			cur.apply_stun(0.5)
		Fx.burst(parent, to, Color(2.2, 2.2, 3.2), 18, 4.0, 0.3, 0.1, 0.0)
		Fx.flash(parent, to, Color(0.8, 0.8, 1.0), 6.0, 7.0, 0.25)
		from = to
		dmg *= 0.8
		var nxt: Node3D = null
		var bd := 7.0
		for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("boss"):
			if hit.has(e) or not e.is_alive():
				continue
			var dd: float = e.global_position.distance_to(cur.global_position)
			if dd < bd:
				bd = dd
				nxt = e
		cur = nxt
	if pts.size() == 1:
		pts.append(origin + facing * 8.0)
	Fx.lightning(parent, pts)
	Sfx.play("zap")
	if main:
		main.shake(0.2)


func _drink() -> void:
	if Game.potions <= 0:
		Game.toast.emit("Sem poções")
		return
	if Game.hp >= Game.max_hp:
		Game.toast.emit("A vida já está cheia")
		return
	Game.potions -= 1
	var amt := 40.0 * (1.6 if Game.has_skill("v_potion") else 1.0)
	Game.hp = min(Game.max_hp, Game.hp + amt)
	Fx.number(get_parent(), global_position + Vector3(0, 2.2, 0), "+%d" % amt, Color(1.0, 0.55, 0.65))
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(2.4, 0.8, 1.2), 30, 2.0, 0.9, 0.14, 1.5)
	var n := "Use_Item"
	_set_state("potion", _anim_len(n, 1.4))
	_play(n, 0.1, 1.4)
	Sfx.play("heal")
	Game.stats_changed.emit()


# ---------------------------------------------------------------- damage

## Returns true if the hit landed. `attacker` receives thorn damage when set.
func hurt(dmg: float, from: Vector3, attacker: Node = null) -> bool:
	if inv > 0.0 or state == "dead" or state == "dodge" or state == "dash_strike" or frozen:
		return false
	Game.hp -= dmg
	inv = 1.0
	var d := global_position - from
	d.y = 0
	knock = d.normalized() * 7.0
	Fx.number(get_parent(), global_position + Vector3(0, 2.0, 0), "%d" % dmg, Color(1.0, 0.4, 0.3))
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(2.5, 0.6, 0.4), 16, 3.0, 0.4, 0.1)
	Sfx.play("hurt")
	if Game.has_skill("v_thorns") and attacker != null and is_instance_valid(attacker) and attacker.has_method("take_damage") and attacker.is_alive():
		attacker.take_damage(dmg * 0.3 + Game.atk * 0.3, -d.normalized() * 4.0, "thorns")
	if main:
		main.shake(0.4)
		main.hitstop(0.08)
	Game.stats_changed.emit()
	if Game.hp <= 0.0:
		if Game.has_skill("v_phoenix") and not phoenix_used:
			phoenix_used = true
			Game.hp = Game.max_hp * 0.5
			inv = 2.5
			Fx.burst(get_parent(), global_position + Vector3(0, 0.5, 0), Color(3.0, 1.6, 0.5), 120, 6.0, 1.4, 0.2, 3.0, true, 60.0)
			Fx.flash(get_parent(), global_position + Vector3(0, 1.5, 0), Color(1, 0.7, 0.3), 8.0, 10.0, 1.2)
			Fx.number(get_parent(), global_position + Vector3(0, 2.6, 0), "Renascer!", Color(1.0, 0.75, 0.35), 80)
			Sfx.play("bloom")
			Game.stats_changed.emit()
			return true
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
	phoenix_used = false
	_anim = ""
	_play("Idle")


func celebrate() -> void:
	_play("Cheer", 0.2)
