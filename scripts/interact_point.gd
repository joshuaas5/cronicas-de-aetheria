class_name InteractPoint
extends Node3D
## Something the player can examine: signs, wells, the Mana Tree.

var display_name := ""
var talk: Callable
var interact_radius := 2.4
var _label: Label3D


func setup(p_name: String, p_talk: Callable, radius := 2.4, label_height := 2.0) -> InteractPoint:
	display_name = p_name
	talk = p_talk
	interact_radius = radius
	_label = Label3D.new()
	_label.text = p_name
	_label.font = Fx.font()
	_label.font_size = 40
	_label.outline_size = 12
	_label.outline_modulate = Color(0.06, 0.04, 0.02, 0.0)
	_label.modulate = Color(1.0, 0.92, 0.7, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.006
	_label.position.y = label_height
	add_child(_label)
	return self


func _ready() -> void:
	add_to_group("talkable")


func _process(dt: float) -> void:
	var p: Node3D = get_tree().get_first_node_in_group("player")
	var near := p != null and p.global_position.distance_to(global_position) < interact_radius + 0.8
	_label.modulate.a = lerp(_label.modulate.a, 1.0 if near else 0.0, dt * 6.0)
	_label.outline_modulate.a = _label.modulate.a * 0.85
	_label.visible = _label.modulate.a > 0.02


func can_talk(from: Vector3) -> bool:
	var d := from - global_position
	d.y = 0
	return d.length() < interact_radius


func interact() -> void:
	talk.call()
