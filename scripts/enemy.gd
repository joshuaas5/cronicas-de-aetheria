class_name Enemy
extends CharacterBody3D
## Skeleton foes that scale with the hero. Ranks: normal, champion (blue packs),
## rare (yellow, named, with minions), minion (a rare's escort) and goblin (loot thief).

const TYPES := {
	"minion": {"model": "Skeleton_Minion", "hp": 30, "dmg": 7, "speed": 3.3, "xp": 8, "gold": [2, 5], "weapon": "Skeleton_Blade", "range": 1.7},
	"rogue": {"model": "Skeleton_Rogue", "hp": 24, "dmg": 6, "speed": 4.4, "xp": 9, "gold": [2, 6], "weapon": "Skeleton_Blade", "range": 1.6},
	"warrior": {"model": "Skeleton_Warrior", "hp": 64, "dmg": 12, "speed": 2.7, "xp": 16, "gold": [4, 9], "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Small_A", "range": 1.9},
	"mage": {"model": "Skeleton_Mage", "hp": 34, "dmg": 9, "speed": 2.8, "xp": 14, "gold": [3, 8], "weapon": "Skeleton_Staff", "range": 9.0},
	"goblin": {"model": "Skeleton_Rogue", "hp": 90, "dmg": 0, "speed": 5.2, "xp": 30, "gold": [40, 80], "weapon": "", "range": 0.0},
}

const AFFIX_NAMES := {
	"fast": "Veloz", "vampiric": "Vampírico", "explosive": "Explosivo", "frozen": "Congelante", "shielded": "Blindado",
	"teleporter": "Teleportador", "molten": "Incendiário", "summoner": "Invocador", "arcane": "Arcano",
}
const RARE_FIRST := ["Crânio", "Ossário", "Mandíbula", "Tíbia", "Cinzento", "Rangedor", "Vértebra", "Fêmur", "Marrow", "Sepulcro", "Carcaça", "Lápide"]
const RARE_EPITHET := ["o Faminto", "o Eterno", "a Praga", "o Profanador", "o Sem-Alma", "a Sombra", "o Rachado", "o Uivante", "o Esquecido", "o Tirano"]

var type := "minion"
var rank := "normal"
var mlvl := 1
var affixes: Array = []
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
var burn := 0.0
var burn_tick := 0.0
var stun := 0.0
var knock := Vector3.ZERO
var hit_done := false
var elite := false
var display := ""
var model: Node3D
var ap: AnimationPlayer
var hpbar: Node3D
var hpfill: MeshInstance3D
var _mats: Array[StandardMaterial3D] = []
var _flash := 0.0
var _anim := ""
var _aff_cd := {}
var _shield: MeshInstance3D
var _orb: Node3D
var _orb_hit_cd := 0.0
var _goblin_t := 0.0


func setup(p_type: String, p_elite := false, p_rank := "normal", p_mlvl := 1, p_affixes: Array = []) -> Enemy:
	type = p_type
	rank = p_rank
	mlvl = p_mlvl
	affixes = p_affixes
	elite = p_elite or rank in ["champion", "rare"]
	var t: Dictionary = TYPES[type]
	var tm: Dictionary = Game.TORMENT[Game.torment]
	var rank_hp: float = {"normal": 1.0, "minion": 1.3, "champion": 3.2, "rare": 4.8, "goblin": 1.0}[rank]
	var rank_dmg: float = {"normal": 1.0, "minion": 1.1, "champion": 1.35, "rare": 1.55, "goblin": 0.0}[rank]
	var rank_xp: float = {"normal": 1.0, "minion": 1.5, "champion": 3.5, "rare": 6.0, "goblin": 4.0}[rank]
	if p_elite and rank == "normal":
		rank_hp = 1.35
		rank_dmg = 1.2
	var rift_hp := pow(1.17, Game.rift_level - 1) if Game.rift_level > 0 else 1.0
	var rift_dmg := pow(1.085, Game.rift_level - 1) if Game.rift_level > 0 else 1.0
	max_hp = t["hp"] * pow(1.11, mlvl - 1) * tm["hp"] * rank_hp * rift_hp
	hp = max_hp
	dmg = t["dmg"] * pow(1.075, mlvl - 1) * tm["dmg"] * rank_dmg * rift_dmg
	speed = t["speed"] * (1.55 if affixes.has("fast") else 1.0)
	xp = int(t["xp"] * (1.0 + (mlvl - 1) * 0.35) * rank_xp)
	attack_range = t["range"]
	if rank == "rare":
		display = RARE_FIRST[randi() % RARE_FIRST.size()] + ", " + RARE_EPITHET[randi() % RARE_EPITHET.size()]
	elif rank == "champion":
		display = "Campeão " + ["Ossudo", "Profano", "Sombrio", "Rúnico"][randi() % 4]
	elif rank == "goblin":
		display = "Duende Ganancioso"
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
	var sc := 0.72
	if rank == "champion":
		sc = 0.86
	elif rank == "rare":
		sc = 0.95
	elif rank == "goblin":
		sc = 0.5
	model.scale = Vector3.ONE * sc
	add_child(model)
	radius = 0.55 * sc / 0.72
	ap = model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["Idle_Combat", "Running_C", "Walking_D_Skeletons", "Running_A", "Spellcasting", "Running_B"]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	if t["weapon"] != "":
		_attach(sk, "handslot.r", t["weapon"])
	if t.has("shield"):
		_attach(sk, "handslot.l", t["shield"])
	var tint := Color(1, 1, 1)
	match rank:
		"champion": tint = Color(0.6, 0.75, 1.3)
		"rare": tint = Color(1.25, 1.05, 0.55)
		"goblin": tint = Color(1.6, 1.25, 0.4)
		"minion": tint = Color(1.05, 1.0, 0.85)
	if elite and rank == "normal":
		tint = Color(0.85, 0.7, 1.0)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var base = mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var dup: StandardMaterial3D = base.duplicate()
				if String(base.resource_name) == "skeleton":
					dup.albedo_color = tint
					if rank == "goblin":
						dup.metallic = 0.9
						dup.roughness = 0.2
				mi.set_surface_override_material(s, dup)
				_mats.append(dup)
	_make_hpbar()
	if rank in ["champion", "rare", "goblin"]:
		var aura_col = {"champion": Color(0.8, 1.2, 3.0), "rare": Color(3.0, 2.4, 0.6), "goblin": Color(3.0, 2.4, 0.5)}[rank]
		var aura := Fx.emitter(self, aura_col, 30, 1.2, 0.1, 0.6, 1.0, Vector3(0.4, 0.8, 0.4))
		aura.position.y = 0.9
		var lbl := Label3D.new()
		var aff_names := []
		for a in affixes:
			aff_names.append(AFFIX_NAMES[a])
		lbl.text = display + ("\n" + " · ".join(aff_names) if aff_names.size() > 0 else "")
		lbl.font = Fx.font()
		lbl.font_size = 50
		lbl.modulate = {"champion": Color(0.55, 0.7, 1.0), "rare": Color(1.0, 0.85, 0.3), "goblin": Color(1.0, 0.8, 0.3)}[rank]
		lbl.outline_size = 10
		lbl.outline_modulate = Color(0.02, 0.01, 0.0, 0.9)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.pixel_size = 0.006
		lbl.position.y = 2.7 if rank != "goblin" else 1.9
		add_child(lbl)
	if affixes.has("shielded"):
		_shield = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.1
		sm.height = 2.2
		_shield.mesh = sm
		var shm := StandardMaterial3D.new()
		shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		shm.albedo_color = Color(0.4, 0.7, 1.4, 0.18)
		_shield.material_override = shm
		_shield.position.y = 1.0
		add_child(_shield)
	if affixes.has("arcane"):
		_orb = Node3D.new()
		add_child(_orb)
		var o := Fx.glow_sphere(0.28, Color(0.9, 0.4, 1.0), 5.0)
		o.position = Vector3(2.6, 1.0, 0)
		_orb.add_child(o)
		var ol := OmniLight3D.new()
		ol.light_color = Color(0.8, 0.4, 1.0)
		ol.light_energy = 1.5
		ol.omni_range = 3.0
		ol.position = o.position
		_orb.add_child(ol)
	for a in affixes:
		_aff_cd[a] = randf_range(2.0, 4.0)
	if rank == "goblin":
		_set_state("chase")
		_play("Running_B" if ap.has_animation("Running_B") else "Running_A", 0.0)
		Sfx.play("goblin")
		return
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
	hpbar.position = Vector3(0, 2.15 if rank != "rare" else 2.4, 0)
	add_child(hpbar)
	var w = 0.9 if not elite else 1.5
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, 0.09 if not elite else 0.13)
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
	q2.size = Vector2(w - 0.04, 0.06 if not elite else 0.09)
	q2.center_offset = Vector3((w - 0.04) * 0.5, 0, 0)
	hpfill.mesh = q2
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.6, 0.35, 0.25) if not elite else (Color(2.0, 1.6, 0.3) if rank == "rare" else Color(0.6, 0.9, 2.0))
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.no_depth_test = true
	fm.render_priority = 2
	hpfill.material_override = fm
	hpfill.position.x = -(w - 0.04) * 0.5
	hpbar.add_child(hpfill)
	hpbar.visible = elite


func _play(name: String, blend := 0.15, spd := 1.0) -> void:
	if not ap.has_animation(name):
		return
	if _anim == name and ap.is_playing() and ap.get_animation(name).loop_mode != Animation.LOOP_NONE:
		return
	_anim = name
	ap.play(name, blend, spd * (1.4 if affixes.has("fast") else 1.0))


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


func apply_burn(t: float) -> void:
	burn = max(burn, t)


func apply_stun(t: float) -> void:
	if not is_alive():
		return
	stun = max(stun, t * (0.5 if elite else 1.0))
	ap.speed_scale = 0.0


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
	if burn > 0.0 and is_alive():
		burn -= dt
		burn_tick -= dt
		if randf() < 0.4:
			Fx.burst(get_parent(), global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.5, 1.6), 0), Color(3.0, 1.2, 0.3), 2, 1.0, 0.4, 0.14, 2.0)
		if burn_tick <= 0.0:
			burn_tick = 0.5
			take_damage(Game.mag * 0.25 * Game.element_mult("fire"), Vector3.ZERO, "burn")
	if stun > 0.0:
		stun -= dt
		if stun <= 0.0 and state != "dead":
			ap.speed_scale = 1.0
		velocity = knock
		move_and_slide()
		global_position.y = 0
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var vel := Vector3.ZERO
	var spd = speed * (0.45 if slow > 0.0 else 1.0)
	var to_p := Vector3.ZERO
	var dist := 99.0
	if player and player.get_parent():
		to_p = player.global_position - global_position
		to_p.y = 0
		dist = to_p.length()
	var frozen: bool = player == null or player.frozen or player.state == "dead" or player.get_parent() == null
	if is_alive() and not frozen:
		_affix_update(dt, player, to_p, dist)
	if rank == "goblin" and is_alive():
		_goblin(dt, to_p, dist)
		return
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
					_play("Running_C" if type == "rogue" or affixes.has("fast") else "Walking_D_Skeletons", 0.2, 1.4 if type != "rogue" else 1.0)
				else:
					_play("Idle_Combat", 0.2)
				_face(to_p)
				if dist < attack_range and cd <= 0.0:
					var n = "1H_Melee_Attack_Chop" if type != "rogue" else "1H_Melee_Attack_Stab"
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
					if player.hurt(dmg, global_position, self) and affixes.has("vampiric"):
						hp = min(max_hp, hp + dmg * 1.5)
						Fx.burst(get_parent(), global_position + Vector3(0, 1.2, 0), Color(2.4, 0.3, 0.4), 12, 2.0, 0.6, 0.1, 1.0)
						hpfill.scale.x = max(0.0, hp / max_hp)
				Sfx.play("swing", -6.0)
			if k >= 1.0:
				cd = randf_range(0.9, 1.6) * (0.7 if affixes.has("fast") else 1.0)
				_set_state("chase")
		"cast":
			var k := state_t / state_len
			_face(to_p)
			if not hit_done and k >= 0.45:
				hit_done = true
				var p := Projectile.new().setup("orb", "enemy", to_p.normalized() * 7.5, dmg)
				p.attacker = self
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


func _goblin(dt: float, to_p: Vector3, dist: float) -> void:
	_goblin_t += dt
	var away = -to_p.normalized() if dist < 9.0 else Vector3(sin(_goblin_t * 0.7), 0, cos(_goblin_t * 0.9))
	velocity = away * speed * (0.45 if slow > 0.0 else 1.0) + knock
	velocity.y = 0
	_face(away)
	move_and_slide()
	global_position.y = 0
	if randf() < 0.3:
		Fx.burst(get_parent(), global_position + Vector3(0, 0.6, 0), Color(3.0, 2.4, 0.6), 1, 0.5, 0.8, 0.1, 1.0)
	if _goblin_t > 18.0:
		Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(2.4, 2.0, 0.6), 80, 5.0, 1.0, 0.2, 0.0)
		Fx.flash(get_parent(), global_position + Vector3(0, 1.0, 0), Color(1, 0.85, 0.4), 6.0, 8.0, 0.6)
		Game.toast.emit("O Duende Ganancioso fugiu por um portal!")
		Sfx.play("orb")
		queue_free()


func _affix_update(dt: float, player: Node3D, to_p: Vector3, dist: float) -> void:
	for a in affixes:
		_aff_cd[a] = float(_aff_cd.get(a, 3.0)) - dt
	if affixes.has("molten") and _aff_cd["molten"] <= 0.0 and velocity.length() > 0.5:
		_aff_cd["molten"] = 0.55
		var h := Hazard.new().setup("fire", "enemy", 1.0, dmg * 0.35, 4.0)
		h.attacker = self
		get_parent().add_child(h)
		h.global_position = global_position
	if affixes.has("frozen") and _aff_cd["frozen"] <= 0.0 and dist < 14.0:
		_aff_cd["frozen"] = 6.0
		var h := Hazard.new().setup("frost", "enemy", 2.2, dmg * 0.8, 0.0, 1.3)
		h.attacker = self
		get_parent().add_child(h)
		h.global_position = player.global_position
	if affixes.has("teleporter") and _aff_cd["teleporter"] <= 0.0 and dist > 5.0 and dist < 25.0:
		_aff_cd["teleporter"] = 5.0
		Fx.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(1.6, 0.8, 3.0), 30, 3.0, 0.5, 0.15, 0.0)
		global_position = player.global_position - to_p.normalized() * 2.0
		Fx.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(1.6, 0.8, 3.0), 30, 3.0, 0.5, 0.15, 0.0)
		Sfx.play("dash", -4.0)
	if affixes.has("summoner") and _aff_cd["summoner"] <= 0.0 and get_tree().get_nodes_in_group("enemies").size() < 16:
		_aff_cd["summoner"] = 8.0
		for i in 2:
			var e := Enemy.new().setup("minion", false, "normal", mlvl)
			get_parent().add_child(e)
			e.global_position = global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	if _orb:
		_orb.rotation.y += dt * 1.6
		_orb_hit_cd -= dt
		var o: Node3D = _orb.get_child(0)
		if _orb_hit_cd <= 0.0 and o.global_position.distance_to(player.global_position + Vector3(0, 1, 0)) < 1.0:
			_orb_hit_cd = 0.8
			player.hurt(dmg * 0.6, o.global_position, self)
	if _shield:
		_shield.visible = hp > max_hp * 0.5
		_shield.rotation.y += dt


func _forward() -> Vector3:
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))


func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.2)


func take_damage(amount: float, push: Vector3, kind: String) -> void:
	if not is_alive():
		return
	if _shield and _shield.visible:
		amount *= 0.35
	hp -= amount
	if not elite:
		knock = push
	else:
		knock = push * 0.35
	_flash = 0.1
	var col := Color(1, 1, 1)
	var size := 64
	var txt := "%d" % amount
	match kind:
		"fire", "burn":
			col = Color(1, 0.65, 0.3)
			size = 48 if kind == "burn" else 64
		"ice":
			col = Color(0.6, 0.85, 1)
		"bolt":
			col = Color(0.85, 0.85, 1.0)
		"crit":
			col = Color(1.0, 0.85, 0.2)
			size = 92
			txt += "!"
		"thorns":
			col = Color(0.6, 1.0, 0.5)
	Fx.number(get_parent(), global_position + Vector3(0, 2.0, 0), txt, col, size)
	Fx.burst(get_parent(), global_position + Vector3(0, 1.1, 0), Color(2.2, 2.0, 1.6), 12, 4.0, 0.3, 0.08, -8.0)
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(0.9, 0.88, 0.8), 6, 3.0, 0.8, 0.07, -12.0, false)
	Sfx.play("hit")
	hpbar.visible = true
	hpfill.scale.x = max(0.0, hp / max_hp)
	if hp <= 0.0:
		_die()
	elif kind == "burn" or kind == "thorns" or rank == "goblin":
		pass
	elif elite and amount < max_hp * 0.15:
		pass
	elif state != "attack" or amount > max_hp * 0.25:
		_set_state("hurt", 0.35)
		_play("Hit_B", 0.05, 1.4)


func _die() -> void:
	ap.speed_scale = 1.0
	stun = 0.0
	burn = 0.0
	_set_state("dead")
	hpbar.visible = false
	remove_from_group("enemies")
	collision_layer = 0
	if _orb:
		_orb.queue_free()
	if _shield:
		_shield.queue_free()
	_play("Death_C_Skeletons" if ap.has_animation("Death_C_Skeletons") else "Death_A", 0.05)
	Sfx.play("bones")
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(1.4, 0.8, 2.4), 30, 3.5, 1.0, 0.14, 1.0)
	if affixes.has("explosive"):
		var h := Hazard.new().setup("blast", "enemy", 3.0, dmg * 1.6, 0.0, 1.1)
		h.attacker = self
		get_parent().add_child(h)
		h.global_position = global_position
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.on_enemy_killed(self)
