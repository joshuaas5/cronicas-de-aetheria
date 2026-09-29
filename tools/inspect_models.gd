# Prints bounds and triangle counts of every imported model.
# godot --headless --path . --script res://tools/inspect_models.gd
extends SceneTree

func _init() -> void:
	var dirs := ["res://assets/models", "res://assets/characters/adventurers", "res://assets/characters/skeletons"]
	for base in dirs:
		for f in _list(base):
			if not (f.ends_with(".gltf") or f.ends_with(".glb")):
				continue
			var ps = load(f)
			if ps == null:
				print("FAIL ", f)
				continue
			var n: Node = ps.instantiate()
			var aabb := AABB()
			var tris := 0
			var first := true
			var mats := {}
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = mi.mesh
				if m == null:
					continue
				for s in m.get_surface_count():
					var arr = m.surface_get_arrays(s)
					var idx = arr[Mesh.ARRAY_INDEX]
					tris += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
					var mat = m.surface_get_material(s)
					if mat:
						mats[mat.resource_name] = mat.get_class()
				var xf: Transform3D = _global_xf(mi)
				var b: AABB = xf * m.get_aabb()
				aabb = b if first else aabb.merge(b)
				first = false
			print("%-70s size=(%.2f, %.2f, %.2f) pos=(%.2f, %.2f, %.2f) tris=%d mats=%s" % [f, aabb.size.x, aabb.size.y, aabb.size.z, aabb.position.x, aabb.position.y, aabb.position.z, tris, str(mats.keys())])
			n.free()
	quit()

func _global_xf(node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := node
	while cur and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _list(path: String) -> Array:
	var out := []
	var d := DirAccess.open(path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				out.append_array(_list(path + "/" + f))
		else:
			out.append(path + "/" + f)
		f = d.get_next()
	return out
