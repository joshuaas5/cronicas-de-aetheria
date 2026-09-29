class_name Level
extends Node3D
## Base class for every playable area. Subclasses fill the fields and build().

var id := ""
var display_name := ""
var music := ""
var ambience := ""
var grass_materials: Array = []
var land := ""
## Camera placement relative to the followed point, and field of view.
var cam_offset := Vector3(0, 10.5, 12.5)
var cam_fov := 34.0
var cam_look_height := 1.0
## Area the camera centre may travel over (x, z).
var cam_bounds := Rect2(-20, -4, 40, 10)
## Area the player may walk (x, z). Walls are generated on its edges.
var bounds := Rect2(-30, -8, 60, 18)
## name -> [position, facing yaw]
var spawns := {}
## Array of {rect: Rect2, to: String, spawn: String, arrow: Vector3}
var exits := []
var env := {}
var batch_leaves: Env.FoliageBatch
var batch_bush: Env.FoliageBatch
var talkables := []
var exits_locked := false


func build() -> void:
	pass


## Called once the player is in the level.
func on_enter() -> void:
	pass


func height_at(_x: float, _z: float) -> float:
	return 0.0


func add_grass(rect: Rect2, count: int, density_fn: Callable, o := {}) -> void:
	var mmi := Env.grass(self, rect, count, density_fn, height_at, o)
	grass_materials.append(mmi.material_override)


## Colourful wildflower cards scattered where density_fn allows.
func add_flowers(rect: Rect2, count: int, density_fn: Callable, glow := Color.BLACK) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rect.position.x * 7 + count)
	var warm := Env.FoliageBatch.new(Env.foliage_mat("flowers_warm", Color(1.1, 1.1, 1.1), glow))
	var cool := Env.FoliageBatch.new(Env.foliage_mat("flowers_cool", Color(1.1, 1.1, 1.1), glow))
	var placed := 0
	var tries := count * 4
	while placed < count and tries > 0:
		tries -= 1
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		if rng.randf() > density_fn.call(x, z):
			continue
		var p := Vector3(x, height_at(x, z), z)
		var batch := warm if rng.randf() < 0.55 else cool
		for k in 2:
			var b := Basis(Vector3.UP, rng.randf() * PI + k * PI * 0.5)
			var s := rng.randf_range(0.55, 0.95)
			batch.add(Transform3D(b.scaled(Vector3(s, s, s)), p), p - Vector3(0, 2.0, 0), Color.WHITE)
		placed += 1
	for b in [warm, cool]:
		if b.xfs.size() > 0:
			var mmi: MultiMeshInstance3D = b.build(self, false)
			(mmi.material_override as ShaderMaterial).set_shader_parameter("normal_bend", 0.9)


func main() -> Node:
	return get_tree().get_first_node_in_group("main")


## Random point inside `bounds`, at least `min_dist` from `avoid`.
func random_point(avoid: Vector3, min_dist := 8.0, margin := 2.0) -> Vector3:
	for i in 40:
		var p := Vector3(randf_range(bounds.position.x + margin, bounds.end.x - margin), 0, randf_range(bounds.position.y + margin, bounds.end.y - margin))
		if p.distance_to(avoid) >= min_dist:
			return p
	return Vector3(bounds.get_center().x, 0, bounds.get_center().y)


func make_batches(tint := Color.WHITE, bush_tint := Color.WHITE, glow := Color.BLACK) -> void:
	batch_leaves = Env.FoliageBatch.new(Env.foliage_mat("leaf_cluster_a", tint, glow))
	batch_bush = Env.FoliageBatch.new(Env.foliage_mat("leaf_bush", bush_tint, glow))


func finish_batches() -> void:
	if batch_leaves and batch_leaves.xfs.size() > 0:
		batch_leaves.build(self)
	if batch_bush and batch_bush.xfs.size() > 0:
		batch_bush.build(self)


## Invisible walls around `bounds`, leaving gaps where exits are.
func build_walls() -> void:
	Env.floor_collider(self)
	var b := bounds
	var t := 1.0
	Env.wall(self, Vector3(b.get_center().x, 2, b.position.y - t * 0.5), Vector3(b.size.x + 2, 4, t))
	Env.wall(self, Vector3(b.get_center().x, 2, b.end.y + t * 0.5), Vector3(b.size.x + 2, 4, t))
	Env.wall(self, Vector3(b.position.x - t * 0.5, 2, b.get_center().y), Vector3(t, 4, b.size.y + 2))
	Env.wall(self, Vector3(b.end.x + t * 0.5, 2, b.get_center().y), Vector3(t, 4, b.size.y + 2))


static func dist_to_path(p: Vector2, pts: Array) -> float:
	var best := 1e9
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t: float = clamp((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = min(best, p.distance_to(a + ab * t))
	return best
