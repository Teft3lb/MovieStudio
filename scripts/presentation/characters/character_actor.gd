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
var _name_tag: Label3D
var _scene_dialogue_label: Label3D
var _scene_path: Array[Vector3] = []
var _scene_path_index: int = 0
var _scene_performance_active: bool = false
var _scene_returning_to_workplace: bool = false
var _scene_hold_active: bool = false
var _scene_is_moving: bool = false
var _scene_target_position: Vector3 = Vector3.ZERO
var _scene_focus_position: Vector3 = Vector3.ZERO
var _scene_action_id: String = ""
var _scene_dialogue: String = ""
var _workplace_building_id: String = ""
var _workplace_path: Array[Vector3] = []
var _workplace_commute_path: Array[Vector3] = []
var _workplace_path_index: int = 0
var _workplace_work_style: String = ""
var _production_action_id: String = ""
var _has_workplace_destination: bool = false
var _is_at_workplace: bool = false
var _is_leaving_workplace: bool = false
var _facility_active: bool = false
var _facility_is_moving: bool = false
var _facility_is_leaving: bool = false
var _facility_building_id: String = ""
var _facility_type_id: String = ""
var _facility_slot_index: int = -1
var _facility_route: Array[Vector3] = []
var _facility_route_index: int = 0
var _facility_action_id: String = ""


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
	_visual.name = "CharacterVisual"
	var character_payload: Dictionary = data.call("to_dict")
	_visual.call("setup", character_payload)
	add_child(_visual)

	_create_name_tag()
	_create_scene_dialogue_label()
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

	if _facility_active:
		_process_facility_movement(simulation_delta)
		return

	if _scene_performance_active:
		_process_scene_performance(simulation_delta)
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


func _process_facility_movement(simulation_delta: float) -> void:
	if _facility_is_moving:
		while (
			_facility_route_index < _facility_route.size()
			and global_position.distance_to(
				_facility_route[_facility_route_index]
			) <= 0.18
		):
			_facility_route_index += 1

		if _facility_route_index >= _facility_route.size():
			global_position = _facility_route.back()
			_facility_is_moving = false
			_set_walking(false)
			if _facility_is_leaving:
				_finish_facility_leave()
			else:
				_face_facility()
				if is_instance_valid(_visual):
					_visual.call("set_performance_action", _facility_action_id)
			_advance_visual(simulation_delta)
			return

		var target: Vector3 = _facility_route[_facility_route_index]
		var direction: Vector3 = target - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			direction = direction.normalized()
			global_position = global_position.move_toward(
				target,
				_move_speed * simulation_delta
			)
			look_at(global_position + direction, Vector3.UP)
		_set_walking(true)
		_advance_visual(simulation_delta)
		return

	_set_walking(false)
	if is_instance_valid(_visual):
		_visual.call("set_performance_action", _facility_action_id)
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
	global_position = global_position.move_toward(
		target,
		_move_speed * simulation_delta
	)
	look_at(global_position + direction, Vector3.UP)
	_set_walking(true)
	_advance_visual(simulation_delta)


func start_scene_performance(
	target_position: Vector3,
	focus_position: Vector3,
	action_id: String,
	dialogue_text: String = "",
	movement_path: Array[Vector3] = []
) -> void:
	_clear_facility_route()
	if not _has_workplace_destination:
		return

	var target_changed: bool = (
		not _scene_performance_active
		or _scene_returning_to_workplace
		or _scene_target_position.distance_to(target_position) > 0.2
	)
	_scene_performance_active = true
	_scene_returning_to_workplace = false
	_scene_hold_active = false
	_scene_target_position = target_position
	_scene_focus_position = focus_position
	_scene_action_id = action_id
	_scene_dialogue = dialogue_text
	_set_scene_dialogue(dialogue_text)

	if target_changed:
		_scene_is_moving = global_position.distance_to(target_position) > 0.25
		_scene_path = movement_path.duplicate()
		if _scene_path.is_empty():
			_scene_path.append(target_position)
		_scene_path_index = 0
		while (
			_scene_path_index < _scene_path.size()
			and global_position.distance_to(
				_scene_path[_scene_path_index]
			) <= 0.25
		):
			_scene_path_index += 1
		_is_at_workplace = not _scene_is_moving
	if _scene_is_moving:
		_set_walking(true)
	else:
		_apply_scene_pose()


func set_carrying_prop(value: bool) -> void:
	if is_instance_valid(_visual):
		_visual.call("set_carrying_prop", value)


func set_scene_performance_action(
	action_id: String,
	dialogue_text: String = ""
) -> void:
	if not _scene_performance_active or _scene_returning_to_workplace:
		return
	_scene_action_id = action_id
	_scene_dialogue = dialogue_text
	_set_scene_dialogue(dialogue_text)
	if not _scene_is_moving:
		_apply_scene_pose()


func move_to_scene_hold(
	target_position: Vector3,
	movement_path: Array[Vector3] = []
) -> void:
	_clear_facility_route()
	if not _has_workplace_destination:
		return
	if (
		_scene_hold_active
		and not _scene_returning_to_workplace
		and _scene_target_position.distance_to(target_position) <= 0.2
	):
		return
	_scene_performance_active = true
	_scene_returning_to_workplace = false
	_scene_hold_active = true
	_scene_target_position = target_position
	_scene_focus_position = target_position + Vector3.RIGHT
	_scene_action_id = ""
	_scene_dialogue = ""
	_set_scene_dialogue("")
	_scene_is_moving = global_position.distance_to(target_position) > 0.25
	_scene_path = movement_path.duplicate()
	if _scene_path.is_empty():
		_scene_path.append(target_position)
	_scene_path_index = 0
	while (
		_scene_path_index < _scene_path.size()
		and global_position.distance_to(_scene_path[_scene_path_index]) <= 0.25
	):
		_scene_path_index += 1
	_is_at_workplace = not _scene_is_moving
	if _scene_is_moving:
		_set_walking(true)
	else:
		_set_walking(false)
		if is_instance_valid(_visual):
			_visual.call("set_performance_action", "")


func snap_to_scene_hold_mark() -> void:
	if not _scene_hold_active or _scene_returning_to_workplace:
		return
	global_position = _scene_target_position
	_scene_is_moving = false
	_is_at_workplace = true
	_set_walking(false)
	if is_instance_valid(_visual):
		_visual.call("set_performance_action", "")


func is_off_camera() -> bool:
	return _scene_hold_active and not _scene_returning_to_workplace


func is_at_scene_hold_mark() -> bool:
	return (
		_scene_hold_active
		and not _scene_returning_to_workplace
		and not _scene_is_moving
	)


func set_production_action(action_id: String) -> void:
	_production_action_id = action_id
	if _facility_active:
		return
	if not is_instance_valid(_visual):
		return
	if _scene_performance_active:
		return
	if _is_at_workplace:
		if _production_action_id.is_empty():
			_set_working(true)
		else:
			_visual.call("set_performance_action", _production_action_id)


func return_to_workplace(movement_path: Array[Vector3] = []) -> void:
	if not _has_workplace_destination or _workplace_commute_path.is_empty():
		_cancel_scene_performance()
		return
	_clear_facility_route()
	if _scene_returning_to_workplace:
		return

	var last_index: int = _workplace_commute_path.size() - 1
	_scene_performance_active = true
	_scene_returning_to_workplace = true
	_scene_hold_active = false
	_scene_is_moving = true
	_scene_target_position = _workplace_commute_path[last_index]
	_scene_path = movement_path.duplicate()
	if _scene_path.is_empty():
		_scene_path.append(_scene_target_position)
	_scene_path_index = 0
	while (
		_scene_path_index < _scene_path.size()
		and global_position.distance_to(_scene_path[_scene_path_index]) <= 0.25
	):
		_scene_path_index += 1
	_scene_action_id = ""
	_scene_dialogue = ""
	_set_scene_dialogue("")
	_is_at_workplace = false
	if global_position.distance_to(_scene_target_position) <= 0.25:
		global_position = _scene_target_position
		_finish_scene_return()
	else:
		_set_walking(true)

func snap_to_scene_mark() -> void:
	if (
		not _scene_performance_active
		or _scene_returning_to_workplace
		or _scene_hold_active
	):
		return
	global_position = _scene_target_position
	_scene_is_moving = false
	_is_at_workplace = true
	_face_scene_focus()
	_apply_scene_pose()


func is_at_scene_mark() -> bool:
	return (
		_scene_performance_active
		and not _scene_returning_to_workplace
		and not _scene_hold_active
		and not _scene_is_moving
	)


func is_in_scene_performance() -> bool:
	return (
		_scene_performance_active
		and not _scene_returning_to_workplace
		and not _scene_hold_active
	)


func _process_scene_performance(simulation_delta: float) -> void:
	if _scene_is_moving:
		while (
			_scene_path_index < _scene_path.size()
			and global_position.distance_to(
				_scene_path[_scene_path_index]
			) <= 0.18
		):
			_scene_path_index += 1
		if _scene_path_index >= _scene_path.size():
			global_position = _scene_target_position
			_scene_is_moving = false
			if _scene_returning_to_workplace:
				_finish_scene_return()
			elif _scene_hold_active:
				_is_at_workplace = true
				_set_walking(false)
				if is_instance_valid(_visual):
					_visual.call("set_performance_action", "")
			else:
				_is_at_workplace = true
				_face_scene_focus()
				_apply_scene_pose()
			_advance_visual(simulation_delta)
			return

		var movement_target: Vector3 = _scene_path[_scene_path_index]
		var direction: Vector3 = movement_target - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			direction = direction.normalized()
			global_position = global_position.move_toward(
				movement_target,
				_move_speed * simulation_delta
			)
			look_at(global_position + direction, Vector3.UP)
		_set_walking(true)
		_advance_visual(simulation_delta)
		return

	if _scene_returning_to_workplace:
		_finish_scene_return()
		_advance_visual(simulation_delta)
		return

	if _scene_hold_active:
		_is_at_workplace = true
		_set_walking(false)
		if is_instance_valid(_visual):
			_visual.call("set_performance_action", "")
		_advance_visual(simulation_delta)
		return

	_is_at_workplace = true
	_face_scene_focus()
	_apply_scene_pose()
	_advance_visual(simulation_delta)


func _finish_scene_return() -> void:
	_scene_performance_active = false
	_scene_returning_to_workplace = false
	_scene_hold_active = false
	_scene_is_moving = false
	_scene_path.clear()
	_scene_path_index = 0
	_is_at_workplace = true
	_set_scene_dialogue("")
	_face_workplace()
	if (
		not _production_action_id.is_empty()
		and is_instance_valid(_visual)
	):
		_visual.call("set_performance_action", _production_action_id)
	else:
		_set_working(true)


func _face_scene_focus() -> void:
	var direction: Vector3 = _scene_focus_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		look_at(global_position + direction.normalized(), Vector3.UP)


func _apply_scene_pose() -> void:
	_set_walking(false)
	if is_instance_valid(_visual):
		_visual.call("set_performance_action", _scene_action_id)


func _set_scene_dialogue(dialogue_text: String) -> void:
	if not is_instance_valid(_scene_dialogue_label):
		return
	_scene_dialogue_label.text = dialogue_text
	_scene_dialogue_label.visible = not dialogue_text.is_empty()


func _cancel_scene_performance() -> void:
	_scene_performance_active = false
	_scene_returning_to_workplace = false
	_scene_hold_active = false
	_scene_is_moving = false
	_scene_path.clear()
	_scene_path_index = 0
	_scene_action_id = ""
	_scene_dialogue = ""
	_set_scene_dialogue("")
	if is_instance_valid(_visual):
		_visual.call("set_performance_action", "")


func _finish_workplace_arrival() -> void:
	_is_at_workplace = true
	_is_leaving_workplace = false
	_face_workplace()
	_set_walking(false)
	_set_working(true)


func _face_workplace() -> void:
	if _workplace_path.size() < 2:
		return
	var last_index: int = _workplace_path.size() - 1
	var direction: Vector3 = (
		_workplace_path[last_index] - _workplace_path[last_index - 1]
	)
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		look_at(global_position + direction.normalized(), Vector3.UP)


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


func assign_facility_route(
	building_id: String,
	facility_type_id: String,
	slot_index: int,
	route: Array[Vector3],
	action_id: String
) -> bool:
	if route.is_empty() or _scene_performance_active:
		return false
	if (
		_facility_active
		and not _facility_is_leaving
		and _facility_building_id == building_id
		and _facility_type_id == facility_type_id
	):
		return true

	_clear_facility_route()
	_facility_active = true
	_facility_is_leaving = false
	_facility_building_id = building_id
	_facility_type_id = facility_type_id
	_facility_slot_index = slot_index
	_facility_route = route.duplicate()
	_facility_route_index = 0
	_facility_action_id = action_id
	while (
		_facility_route_index < _facility_route.size()
		and global_position.distance_to(
			_facility_route[_facility_route_index]
		) <= 0.18
	):
		_facility_route_index += 1
	_facility_is_moving = (
		_facility_route_index < _facility_route.size()
	)
	_is_at_workplace = false
	_is_leaving_workplace = false
	_set_working(false)
	if _facility_is_moving:
		_set_walking(true)
	else:
		global_position = _facility_route.back()
		_set_walking(false)
		if is_instance_valid(_visual):
			_visual.call("set_performance_action", _facility_action_id)
	return true


func snap_to_facility() -> void:
	if not _facility_active or _facility_route.is_empty():
		return
	global_position = _facility_route.back()
	_facility_route_index = _facility_route.size()
	_facility_is_moving = false
	_facility_is_leaving = false
	_is_at_workplace = false
	_set_walking(false)
	_face_facility()
	if is_instance_valid(_visual):
		_visual.call("set_performance_action", _facility_action_id)
	_update_name_tag_visibility()


func leave_facility(route: Array[Vector3]) -> bool:
	if (
		not _facility_active
		or _facility_is_moving
		or route.is_empty()
	):
		return false
	_facility_route = route.duplicate()
	_facility_route_index = 0
	_facility_is_leaving = true
	_facility_action_id = ""
	while (
		_facility_route_index < _facility_route.size()
		and global_position.distance_to(
			_facility_route[_facility_route_index]
		) <= 0.18
	):
		_facility_route_index += 1
	_facility_is_moving = _facility_route_index < _facility_route.size()
	_set_working(false)
	if _facility_is_moving:
		_set_walking(true)
	else:
		global_position = _facility_route.back()
		_finish_facility_leave()
	return true


func snap_outside_facility() -> void:
	if not _facility_active or _facility_route.is_empty():
		return
	global_position = _facility_route.back()
	_finish_facility_leave()


func _finish_facility_leave() -> void:
	_facility_active = false
	_facility_is_moving = false
	_facility_is_leaving = false
	_facility_building_id = ""
	_facility_type_id = ""
	_facility_slot_index = -1
	_facility_route.clear()
	_facility_route_index = 0
	_facility_action_id = ""
	_is_at_workplace = false
	_set_walking(false)
	_set_working(false)
	_update_name_tag_visibility()


func _face_facility() -> void:
	match _facility_type_id:
		"cafeteria":
			var is_front_row: bool = posmod(_facility_slot_index, 4) < 2
			var facing_direction: Vector3 = (
				Vector3.BACK if is_front_row else Vector3.FORWARD
			)
			look_at(global_position + facing_direction, Vector3.UP)
		"staff_housing":
			rotation.y = 0.0


func is_in_facility() -> bool:
	return _facility_active


func is_at_facility(facility_type_id: String = "") -> bool:
	return (
		_facility_active
		and not _facility_is_moving
		and (
			facility_type_id.is_empty()
			or _facility_type_id == facility_type_id
		)
	)


func get_facility_building_id() -> String:
	return _facility_building_id


func get_facility_type_id() -> String:
	return _facility_type_id


func get_facility_slot_index() -> int:
	return _facility_slot_index


func _clear_facility_route() -> void:
	if not _facility_active:
		return
	_facility_active = false
	_facility_is_moving = false
	_facility_is_leaving = false
	_facility_building_id = ""
	_facility_type_id = ""
	_facility_slot_index = -1
	_facility_route.clear()
	_facility_route_index = 0
	_facility_action_id = ""
	if is_instance_valid(_visual):
		_visual.call("set_performance_action", "")


func assign_workplace_route(
	building_id: String,
	route: Array[Vector3],
	work_style: String
) -> void:
	_clear_facility_route()
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
	_clear_facility_route()
	_cancel_scene_performance()
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
	_clear_facility_route()
	_cancel_scene_performance()
	_workplace_building_id = ""
	_workplace_path.clear()
	_workplace_commute_path.clear()
	_workplace_path_index = 0
	_has_workplace_destination = false
	_is_at_workplace = false
	_is_leaving_workplace = false
	_set_walking(false)
	_set_working(false)


func snap_to_workplace() -> void:
	_clear_facility_route()
	_cancel_scene_performance()
	if not _has_workplace_destination or _workplace_commute_path.is_empty():
		return
	_workplace_path = _workplace_commute_path.duplicate()
	global_position = _workplace_commute_path[
		_workplace_commute_path.size() - 1
	]
	_workplace_path_index = _workplace_path.size() - 1
	_is_at_workplace = true
	_is_leaving_workplace = false
	_face_workplace()
	_set_walking(false)
	_set_working(true)


func snap_outside_workplace() -> void:
	_cancel_scene_performance()
	if _has_workplace_destination and not _workplace_commute_path.is_empty():
		global_position = _workplace_commute_path[0]
	_finish_leaving_workplace()


func get_workplace_building_id() -> String:
	return _workplace_building_id


func get_workplace_position() -> Vector3:
	if _workplace_commute_path.is_empty():
		return global_position
	return _workplace_commute_path.back()


func is_returning_to_workplace() -> bool:
	return _scene_returning_to_workplace


func is_at_workplace() -> bool:
	return _is_at_workplace


func is_leaving_workplace() -> bool:
	return _is_leaving_workplace


func is_work_animation_active() -> bool:
	if not is_instance_valid(_visual):
		return false
	return bool(_visual.call("is_working"))


func is_scene_animation_active() -> bool:
	if not is_instance_valid(_visual):
		return false
	return bool(_visual.call("is_performing"))


func set_selected(value: bool) -> void:
	if is_instance_valid(_selection_ring):
		_selection_ring.visible = value


func _advance_visual(simulation_delta: float) -> void:
	if is_instance_valid(_visual):
		_visual.call("advance_simulation", simulation_delta)
	_update_name_tag_visibility()


func _update_name_tag_visibility() -> void:
	if is_instance_valid(_name_tag):
		_name_tag.visible = not bool(is_at_facility("staff_housing"))


func _set_walking(value: bool) -> void:
	if is_instance_valid(_visual):
		_visual.call("set_walking", value)


func _set_working(value: bool) -> void:
	if not is_instance_valid(_visual):
		return
	if value and not _production_action_id.is_empty():
		_visual.call("set_performance_action", _production_action_id)
	else:
		_visual.call(
			"set_working",
			value,
			_workplace_work_style
		)


func _create_name_tag() -> void:
	var summary: Dictionary = character_data.call("get_ui_summary")

	var label := Label3D.new()
	label.name = "NameTag"
	_name_tag = label
	label.text = str(summary.get("full_name", "Employee"))
	label.position = Vector3(0.0, 2.58, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 7
	label.modulate = Color(1.0, 0.96, 0.86)
	label.no_depth_test = true
	add_child(label)


func _create_scene_dialogue_label() -> void:
	_scene_dialogue_label = Label3D.new()
	_scene_dialogue_label.name = "SceneDialogue"
	_scene_dialogue_label.position = Vector3(0.0, 3.08, 0.0)
	_scene_dialogue_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_scene_dialogue_label.font_size = 22
	_scene_dialogue_label.outline_size = 7
	_scene_dialogue_label.modulate = Color(1.0, 0.96, 0.82)
	_scene_dialogue_label.no_depth_test = true
	_scene_dialogue_label.visible = false
	add_child(_scene_dialogue_label)


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
