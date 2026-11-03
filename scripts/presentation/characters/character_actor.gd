extends Node3D
class_name CharacterActor

const CHARACTER_VISUAL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_visual.gd"
)

var character_data: Variant
var _route: Array[Vector3] = []
var _route_index: int = 1
var _move_speed: float = 1.25
var _visual: Node3D


func setup(
	data: Variant,
	waypoints: Array[Vector3],
	move_speed: float = 1.25
) -> void:
	character_data = data
	_route = waypoints.duplicate()
	_move_speed = maxf(move_speed, 0.1)

	if not _route.is_empty():
		position = _route[0]

	_visual = CHARACTER_VISUAL_SCRIPT.new()
	var character_payload: Dictionary = data.call("to_dict")
	_visual.call("setup", character_payload)
	add_child(_visual)

	_create_name_tag()


func _process(delta: float) -> void:
	if _route.size() < 2:
		_set_walking(false)
		return

	var target: Vector3 = _route[_route_index]
	var direction: Vector3 = target - position
	direction.y = 0.0

	if direction.length_squared() <= 0.09:
		_route_index = (_route_index + 1) % _route.size()
		_set_walking(false)
		return

	direction = direction.normalized()
	position += direction * _move_speed * delta
	look_at(position + direction, Vector3.UP)
	_set_walking(true)


func _set_walking(value: bool) -> void:
	if is_instance_valid(_visual):
		_visual.call("set_walking", value)


func _create_name_tag() -> void:
	var summary: Dictionary = character_data.call("get_ui_summary")

	var label := Label3D.new()
	label.name = "NameTag"
	label.text = str(summary.get("full_name", "Employee"))
	label.position = Vector3(0.0, 2.58, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 7
	label.modulate = Color(1.0, 0.96, 0.86)
	label.no_depth_test = true
	add_child(label)
