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
var _game_clock: Node
var _selection_ring: MeshInstance3D
var _workplace_building_id: String = ""
var _workplace_path: Array[Vector3] = []
var _workplace_commute_path: Array[Vector3] = []
var _workplace_path_index: int = 0
var _workplace_work_style: String = ""
var _has_workplace_destination: bool = false
var _is_at_workplace: bool = false
var _is_leaving_workplace: bool = false


func setup(
	data: Variant,
	waypoints: Array[Vector3],
	game_clock: Node,
	move_speed: float = 1.25
) -> void:
	character_data = data
	_route = waypoints.duplicate()
	_game_clock = game_clock
	_move_speed = maxf(move_speed, 0.1)
	add_to_group("studio_employee")

	if not _route.is_empty():
		position = _route[0]

	_visual = CHARACTER_VISUAL_SCRIPT.new()
	var character_payload: Dictionary = data.call("to_dict")
	_visual.call("setup", character_payload)
	add_child(_visual)

	_create_name_tag()
	_create_selection_ring()
	_create_selection_hitbox()


func _process(delta: float) -> void:
	if not is_instance_valid(_game_clock):
		return

	var simulation_delta: float = float(
		_game_clock.call("get_simulation_delta", delta)
	)
	if is_zero_approx(simulation_delta):
		return

	if _has_workplace_destination and not _workplace_path.is_empty():
		_process_workplace_movement(simulation_delta)
		return

	if _route.size() < 2:
		_set_walking(false)
		_advance_visual(simulation_delta)
		return

	var target: Vector3 = _route[_route_index]
	var direction: Vector3 = target - global_position
	direction.y = 0.0

	if direction.length_squared() <= 0.09:
		_route_index = (_route_index + 1) % _route.size()
		_set_walking(false)
		_advance_visual(simulation_delta)
		return

	direction = direction.normalized()
	global_position += direction * _move_speed * simulation_delta
	look_at(global_position + direction, Vector3.UP)
	_set_walking(true)
	_advance_visual(simulation_delta)


func _process_workplace_movement(simulation_delta: float) -> void:
	if _workplace_path_index >= _workplace_path.size():
		_finish_workplace_arrival()
		_advance_visual(simulation_delta)
		return

	var target: Vector3 = _workplace_path[_workplace_path_index]
	var direction: Vector3 = target - global_position
	direction.y = 0.0

	if direction.length_squared() <= 0.25:
		if _workplace_path_index < _workplace_path.size() - 1:
			_workplace_path_index += 1
			_set_walking(false)
			_advance_visual(simulation_delta)
			return

		if _is_leaving_workplace:
			_finish_leaving_workplace()
		else:
			_finish_workplace_arrival()
		_advance_visual(simulation_delta)
		return

	_is_at_workplace = false
	_set_working(false)
	direction = direction.normalized()
	global_position += direction * _move_speed * simulation_delta
	look_at(global_position + direction, Vector3.UP)
	_set_walking(true)
	_advance_visual(simulation_delta)


func _finish_workplace_arrival() -> void:
	_is_at_workplace = true
	_is_leaving_workplace = false
	_set_walking(false)
	_set_working(true)


func _finish_leaving_workplace() -> void:
	_workplace_building_id = ""
	_workplace_path.clear()
	_workplace_commute_path.clear()
	_workplace_path_index = 0
	_has_workplace_destination = false
	_is_at_workplace = false
	_is_leaving_workplace = false
	_set_walking(false)
	_set_working(false)


func get_character_id() -> String:
	if character_data == null:
		return ""
	return str(character_data.id)


func assign_workplace_route(
	building_id: String,
	route: Array[Vector3],
	work_style: String
) -> void:
	if route.is_empty():
		clear_workplace()
		return

	if (
		_workplace_building_id == building_id
		and _workplace_commute_path == route
		and _has_workplace_destination
		and not _is_leaving_workplace
	):
		return

	_workplace_building_id = building_id
	_workplace_commute_path = route.duplicate()
	_workplace_path = route.duplicate()
	_workplace_path_index = 0
	_workplace_work_style = work_style
	_has_workplace_destination = true
	_is_at_workplace = false
	_is_leaving_workplace = false
	_set_working(false)


func assign_workplace(building_id: String, destination: Vector3) -> void:
	var route: Array[Vector3] = [destination]
	assign_workplace_route(building_id, route, "")


func leave_workplace() -> void:
	if _is_leaving_workplace:
		return
	if not _has_workplace_destination or _workplace_path.is_empty():
		_finish_leaving_workplace()
		return

	var exit_path: Array[Vector3] = []
	for index in range(_workplace_path_index - 1, -1, -1):
		exit_path.append(_workplace_path[index])

	if exit_path.is_empty():
		_finish_leaving_workplace()
		return

	_workplace_path = exit_path
	_workplace_path_index = 0
	_is_at_workplace = false
	_is_leaving_workplace = true
	_set_working(false)


func clear_workplace() -> void:
	_workplace_building_id = ""
	_workplace_path.clear()
	_workplace_path_index = 0
	_has_workplace_destination = false
	_is_at_workplace = false
	_is_leaving_workplace = false
	_set_walking(false)
	_set_working(false)


func snap_to_workplace() -> void:
	if not _has_workplace_destination or _workplace_commute_path.is_empty():
		return
	_workplace_path = _workplace_commute_path.duplicate()
	global_position = _workplace_commute_path[
		_workplace_commute_path.size() - 1
	]
	_workplace_path_index = _workplace_path.size() - 1
	_is_at_workplace = true
	_is_leaving_workplace = false
	_set_walking(false)
	_set_working(true)


func snap_outside_workplace() -> void:
	if _has_workplace_destination and not _workplace_commute_path.is_empty():
		global_position = _workplace_commute_path[0]
	_finish_leaving_workplace()


func get_workplace_building_id() -> String:
	return _workplace_building_id


func is_at_workplace() -> bool:
	return _is_at_workplace


func is_leaving_workplace() -> bool:
	return _is_leaving_workplace


func set_selected(value: bool) -> void:
	if is_instance_valid(_selection_ring):
		_selection_ring.visible = value


func _advance_visual(simulation_delta: float) -> void:
	if is_instance_valid(_visual):
		_visual.call("advance_simulation", simulation_delta)


func _set_walking(value: bool) -> void:
	if is_instance_valid(_visual):
		_visual.call("set_walking", value)


func _set_working(value: bool) -> void:
	if is_instance_valid(_visual):
		_visual.call(
			"set_working",
			value,
			_workplace_work_style
		)


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


func _create_selection_ring() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.48
	ring_mesh.outer_radius = 0.58
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8

	_selection_ring = MeshInstance3D.new()
	_selection_ring.name = "SelectionRing"
	_selection_ring.mesh = ring_mesh
	_selection_ring.position = Vector3(0.0, 0.035, 0.0)
	_selection_ring.visible = false

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.76, 0.2)
	ring_material.roughness = 0.45
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_ring.material_override = ring_material
	add_child(_selection_ring)


func _create_selection_hitbox() -> void:
	var hit_body := StaticBody3D.new()
	hit_body.name = "SelectionHitbox"
	hit_body.collision_layer = 2
	hit_body.collision_mask = 0

	var hit_shape := CollisionShape3D.new()
	hit_shape.name = "Capsule"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 2.65
	hit_shape.shape = capsule
	hit_shape.position = Vector3(0.0, 1.3, 0.0)

	hit_body.add_child(hit_shape)
	add_child(hit_body)
