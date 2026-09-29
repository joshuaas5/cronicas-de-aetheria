class_name Chars
extends RefCounted
## Helpers for the KayKit character models, which ship with every weapon attached.

const BODY_PARTS := ["_Arm", "_Body", "_Head", "_Leg", "_Cape", "_Helmet", "_Hat"]


## Shows only the weapon meshes listed in `keep`; body parts always stay visible.
static func loadout(model: Node, keep: Array) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		var is_body := false
		for p in BODY_PARTS:
			if n.contains(p):
				is_body = true
				break
		(mi as MeshInstance3D).visible = is_body or keep.has(n)


static func instance(model_name: String, keep: Array, scale := 0.75) -> Node3D:
	var m: Node3D = load("res://assets/characters/adventurers/%s.glb" % model_name).instantiate()
	m.scale = Vector3.ONE * scale
	loadout(m, keep)
	return m
