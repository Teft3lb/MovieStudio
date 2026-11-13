extends RefCounted
class_name StudioSetLogisticsController

const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)

var _manager: Node
var _character_manager: Node
var _navigation_system: RefCounted
var _set_inventory: Variant
var _active_film_project: Variant
var _active_production_technician_ids: Array[String] = []

var _set_logistics_phase: String = ""
var _set_logistics_scene_key: String = ""
var _set_logistics_pending_prop_ids: Array[String] = []
var _set_logistics_worker_ids: Array[String] = []
var _set_logistics_worker_tasks: Dictionary = {}
var _set_logistics_blocked: bool = false


func setup(
	manager: Node,
	character_manager: Node,
	navigation_system: RefCounted,
	set_inventory: Variant
) -> void:
	_manager = manager
	_character_manager = character_manager
	_navigation_system = navigation_system
	_set_inventory = set_inventory


func begin(
	phase: String,
	setup_data: Dictionary,
	stage_id: String,
	scene_key: String,
	active_film_project: Variant,
	active_technician_ids: Array[String]
) -> void:
	_active_film_project = active_film_project
	_active_production_technician_ids = active_technician_ids.duplicate()
	_begin_set_logistics(phase, setup_data, stage_id, scene_key)


func process_tasks(stage_id: String, active_film_project: Variant) -> void:
	_active_film_project = active_film_project
	_process_set_logistics_tasks(stage_id)


func are_tasks_complete() -> bool:
	return _are_set_logistics_tasks_complete()


func are_workers_ready() -> bool:
	return _are_set_logistics_workers_ready()


func reset() -> void:
	_reset_set_logistics()


func get_phase() -> String:
	return _set_logistics_phase


func set_phase(value: String) -> void:
	_set_logistics_phase = value


func get_scene_key() -> String:
	return _set_logistics_scene_key


func set_scene_key(value: String) -> void:
	_set_logistics_scene_key = value


func get_pending_prop_ids() -> Array[String]:
	return _set_logistics_pending_prop_ids


func set_pending_prop_ids(value: Array[String]) -> void:
	_set_logistics_pending_prop_ids = value


func get_worker_ids() -> Array[String]:
	return _set_logistics_worker_ids


func set_worker_ids(value: Array[String]) -> void:
	_set_logistics_worker_ids = value


func get_worker_tasks() -> Dictionary:
	return _set_logistics_worker_tasks


func set_worker_tasks(value: Dictionary) -> void:
	_set_logistics_worker_tasks = value


func is_blocked() -> bool:
	return _set_logistics_blocked


func set_blocked(value: bool) -> void:
	_set_logistics_blocked = value


func _begin_set_logistics(
	phase: String,
	setup: Dictionary,
	stage_id: String,
	scene_key: String
) -> void:
	var warehouse_id: String = str(_manager.call("get_prop_warehouse_building_id"))
	if warehouse_id.is_empty():
		_set_logistics_phase = phase
		_set_logistics_scene_key = scene_key
		_set_logistics_blocked = true
		push_error("StudioSetLogisticsController: prop warehouse is missing.")
		return

	_set_logistics_phase = phase
	_set_logistics_scene_key = scene_key
	_set_logistics_blocked = false
	_set_logistics_pending_prop_ids.clear()

	if phase == "set_dressing":
		if not bool(_manager.call("prepare_scene_set_dressing", stage_id, setup)):
			_set_logistics_blocked = true
			push_error(
				"StudioSetLogisticsController: previous set dressing has not been returned to the warehouse."
			)
			return
		for prop_id_value in setup.get("prop_ids", []):
			var prop_id: String = str(prop_id_value)
			if (
				prop_id.is_empty()
				or str(_set_inventory.call("get_prop_location", prop_id)) != "warehouse"
			):
				_set_logistics_blocked = true
				push_error(
					"StudioSetLogisticsController: prop %s is not available in warehouse stock."
					% prop_id
				)
				return
			_set_logistics_pending_prop_ids.append(prop_id)
	else:
		var raw_stage_prop_ids: Variant = _set_inventory.call("get_props_on_stage")
		if raw_stage_prop_ids is Array:
			for prop_id_value in raw_stage_prop_ids:
				var prop_id: String = str(prop_id_value)
				if not setup.get("prop_ids", []).has(prop_id):
					_set_logistics_blocked = true
					push_error(
						"StudioSetLogisticsController: unexpected prop %s remains on stage."
						% prop_id
					)
					return
				_set_logistics_pending_prop_ids.append(prop_id)
		if _set_logistics_pending_prop_ids.is_empty():
			_manager.call("clear_scene_set_dressing", stage_id)

	var worker_count: int = mini(
		_set_logistics_pending_prop_ids.size(),
		_active_production_technician_ids.size()
	)
	if not _set_logistics_pending_prop_ids.is_empty() and worker_count <= 0:
		_set_logistics_blocked = true
		push_error("StudioSetLogisticsController: no technicians are available for set logistics.")
		return

	for worker_index in range(worker_count):
		var worker_id: String = _active_production_technician_ids[worker_index]
		if _set_logistics_worker_ids.has(worker_id):
			continue
		_set_logistics_worker_ids.append(worker_id)
	for worker_id in _set_logistics_worker_ids:
		_assign_next_set_logistics_task(
			worker_id,
			"stage",
			stage_id,
			warehouse_id
		)



func _assign_next_set_logistics_task(
	worker_id: String,
	last_location: String,
	stage_id: String,
	warehouse_id: String
) -> void:
	if _set_logistics_pending_prop_ids.is_empty():
		_return_set_logistics_worker_to_stage(
			worker_id,
			last_location,
			stage_id,
			warehouse_id
		)
		return
	var prop_id: String = str(_set_logistics_pending_prop_ids.pop_front())
	var setup: Dictionary = _active_film_project.get_current_scene_setup()
	var scene_prop_ids: Array = setup.get("prop_ids", [])
	var prop_index: int = scene_prop_ids.find(prop_id)
	if prop_index < 0:
		_set_logistics_blocked = true
		push_error(
			"StudioSetLogisticsController: logistics prop %s is not part of the active scene."
			% prop_id
		)
		return
	_set_logistics_worker_tasks[worker_id] = {
		"prop_id": prop_id,
		"prop_index": prop_index,
		"state": "waiting_for_stage",
		"last_location": last_location,
		"remaining_minutes": 0,
	}
	_character_manager.call(
		"set_employee_task",
		worker_id,
		"Готовится к доставке декорации «%s»"
		% SET_CATALOG_SCRIPT.get_prop_definition(prop_id).get("title", prop_id)
	)



func _start_route_for_set_logistics_task(
	worker_id: String,
	task: Dictionary,
	actor: Variant,
	stage_id: String,
	warehouse_id: String
) -> void:
	if _set_logistics_phase == "set_dressing":
		_start_route_to_warehouse(
			worker_id,
			task,
			actor,
			stage_id,
			warehouse_id,
			false
		)
	elif str(task.get("last_location", "")) == "warehouse":
		_start_route_from_warehouse_to_stage(
			worker_id,
			task,
			actor,
			stage_id,
			warehouse_id,
			"strike"
		)
	else:
		_start_route_within_stage_to_prop(
			worker_id,
			task,
			actor,
			stage_id
		)



func _process_set_logistics_tasks(stage_id: String) -> void:
	if _set_logistics_blocked:
		return
	var warehouse_id: String = str(_manager.call("get_prop_warehouse_building_id"))
	var clock: Node = _manager.get("_game_clock") as Node
	var manual_fast_forward: bool = (
		is_instance_valid(clock)
		and bool(clock.get("is_manual_fast_forward"))
	)
	for worker_id in _set_logistics_worker_ids:
		if not _set_logistics_worker_tasks.has(worker_id):
			continue
		var task: Dictionary = _set_logistics_worker_tasks[worker_id]
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			worker_id
		)
		if actor == null or not is_instance_valid(actor):
			_set_logistics_blocked = true
			push_error(
				"StudioSetLogisticsController: logistics worker %s has no character actor."
				% worker_id
			)
			return
		var state: String = str(task.get("state", ""))
		# Manual clock advancement emits minutes without physics frames.
		# Complete travel legs at their intended marks, as cast members do.
		if manual_fast_forward:
			match state:
				"to_warehouse", "to_stage", "to_stage_prop", "returning_via_warehouse":
					if bool(actor.call("is_in_scene_performance")):
						actor.call("snap_to_scene_mark")
				"returning":
					if bool(actor.call("is_returning_to_workplace")):
						actor.call("snap_to_workplace")
		match state:
			"waiting_for_stage":
				var ready: bool = (
					str(task.get("last_location", "")) == "warehouse"
					or bool(
						_character_manager.call(
							"dispatch_employee_to_workplace",
						worker_id
						)
					)
				)
				if ready:
					_start_route_for_set_logistics_task(
						worker_id,
						task,
						actor,
						stage_id,
						warehouse_id
					)
			"to_warehouse":
				if bool(actor.call("is_at_scene_mark")):
					if _set_logistics_phase == "set_dressing":
						task["state"] = "picking_up"
						task["remaining_minutes"] = 1
						actor.call("set_scene_performance_action", "collecting_prop")
						_character_manager.call(
							"set_employee_task",
							worker_id,
							"Получает декорацию на складе"
						)
					else:
						task["state"] = "storing"
						task["remaining_minutes"] = 1
						actor.call("set_scene_performance_action", "storing_prop")
						_character_manager.call(
							"set_employee_task",
							worker_id,
							"Возвращает декорацию на склад"
						)
			"picking_up":
				task["remaining_minutes"] = int(task.get("remaining_minutes", 1)) - 1
				if int(task["remaining_minutes"]) <= 0:
					var pickup_prop_id: String = str(task.get("prop_id", ""))
					if not bool(_set_inventory.call(
						"set_prop_location",
						pickup_prop_id,
						"in_transit_to_stage"
					)):
						_set_logistics_blocked = true
						return
					_manager.call("refresh_warehouse_inventory_visuals")
					actor.call("set_carrying_prop", true)
					task["last_location"] = "warehouse"
					_start_route_from_warehouse_to_stage(
						worker_id,
						task,
						actor,
						stage_id,
						warehouse_id,
						"delivery"
					)
			"to_stage":
				if bool(actor.call("is_at_scene_mark")):
					task["state"] = "installing"
					task["remaining_minutes"] = 1
					actor.call("set_scene_performance_action", "placing_set_piece")
					_character_manager.call(
						"set_employee_task",
						worker_id,
						"Устанавливает декорацию на площадке"
					)
			"installing":
				task["remaining_minutes"] = int(task.get("remaining_minutes", 1)) - 1
				if int(task["remaining_minutes"]) <= 0:
					var install_prop_id: String = str(task.get("prop_id", ""))
					if not bool(_manager.call("install_set_prop", stage_id, install_prop_id)):
						_set_logistics_blocked = true
						push_error("StudioSetLogisticsController: failed to install %s." % install_prop_id)
						return
					if not bool(_set_inventory.call(
						"set_prop_location",
						install_prop_id,
						"on_stage"
					)):
						_set_logistics_blocked = true
						return
					actor.call("set_carrying_prop", false)
					task["last_location"] = "stage"
					_assign_next_set_logistics_task(
						worker_id,
						"stage",
						stage_id,
						warehouse_id
					)
					continue
			"to_stage_prop":
				if bool(actor.call("is_at_scene_mark")):
					task["state"] = "removing"
					task["remaining_minutes"] = 1
					actor.call("set_scene_performance_action", "removing_set_piece")
					_character_manager.call(
						"set_employee_task",
						worker_id,
						"Снимает декорацию со сцены"
					)
			"removing":
				task["remaining_minutes"] = int(task.get("remaining_minutes", 1)) - 1
				if int(task["remaining_minutes"]) <= 0:
					var remove_prop_id: String = str(task.get("prop_id", ""))
					if not bool(_manager.call("remove_set_prop", stage_id, remove_prop_id)):
						_set_logistics_blocked = true
						push_error("StudioSetLogisticsController: failed to remove %s." % remove_prop_id)
						return
					if not bool(_set_inventory.call(
						"set_prop_location",
						remove_prop_id,
						"in_transit_to_warehouse"
					)):
						_set_logistics_blocked = true
						return
					actor.call("set_carrying_prop", true)
					task["last_location"] = "stage"
					_start_route_to_warehouse(
						worker_id,
						task,
						actor,
						stage_id,
						warehouse_id,
						true
					)
			"storing":
				task["remaining_minutes"] = int(task.get("remaining_minutes", 1)) - 1
				if int(task["remaining_minutes"]) <= 0:
					var store_prop_id: String = str(task.get("prop_id", ""))
					if not bool(_set_inventory.call(
						"set_prop_location",
						store_prop_id,
						"warehouse"
					)):
						_set_logistics_blocked = true
						return
					_manager.call("refresh_warehouse_inventory_visuals")
					actor.call("set_carrying_prop", false)
					task["last_location"] = "warehouse"
					_assign_next_set_logistics_task(
						worker_id,
						"warehouse",
						stage_id,
						warehouse_id
					)
					continue
			"returning_via_warehouse":
				if bool(actor.call("is_at_scene_mark")):
					# The worker has already travelled from the warehouse to the
					# stage workstation; this call only closes the scene route.
					actor.call("return_to_workplace")
					task["state"] = "returning"
			"returning":
				if (
					bool(actor.call("is_at_workplace"))
					and not bool(actor.call("is_in_scene_performance"))
					and not bool(actor.call("is_returning_to_workplace"))
				):
					task["state"] = "done"
					_character_manager.call("clear_employee_task", worker_id)
					_character_manager.call(
						"set_employee_production_action",
						worker_id,
						""
					)
		_set_logistics_worker_tasks[worker_id] = task



func _start_route_to_warehouse(
	worker_id: String,
	task: Dictionary,
	actor: Variant,
	stage_id: String,
	warehouse_id: String,
	for_strike: bool
) -> void:
	var prop_index: int = int(task.get("prop_index", 0))
	var target_position: Vector3 = _manager.call("get_storage_mark", warehouse_id, prop_index)
	var route: Array[Vector3] = _build_route_stage_to_warehouse(
		worker_id,
		stage_id,
		warehouse_id,
		prop_index,
		actor.global_position
	)
	if route.is_empty():
		_set_logistics_blocked = true
		push_error("StudioSetLogisticsController: cannot route %s to the prop warehouse." % worker_id)
		return
	actor.call(
		"start_scene_performance",
		target_position,
		target_position + Vector3(0.0, 0.0, -1.0),
		"carrying_prop" if for_strike else "collecting_prop",
		"",
		route
	)
	task["state"] = "to_warehouse"
	_character_manager.call(
		"set_employee_task",
		worker_id,
		"Несёт декорацию на склад" if for_strike else "Идёт за декорацией на склад"
	)



func _start_route_from_warehouse_to_stage(
	worker_id: String,
	task: Dictionary,
	actor: Variant,
	stage_id: String,
	warehouse_id: String,
	logistics_kind: String
) -> void:
	var prop_index: int = int(task.get("prop_index", 0))
	var target_position: Vector3 = _manager.call("get_set_dressing_mark", stage_id, prop_index)
	var route: Array[Vector3] = _build_route_warehouse_to_stage(
		worker_id,
		stage_id,
		warehouse_id,
		prop_index,
		target_position
	)
	if route.is_empty():
		_set_logistics_blocked = true
		push_error("StudioSetLogisticsController: cannot route %s from warehouse to stage." % worker_id)
		return
	actor.call(
		"start_scene_performance",
		target_position,
		_manager.call("get_scene_focus_point", stage_id),
		"carrying_prop" if logistics_kind == "delivery" else "checking_equipment",
		"",
		route
	)
	task["state"] = "to_stage" if logistics_kind == "delivery" else "to_stage_prop"
	_character_manager.call(
		"set_employee_task",
		worker_id,
		"Несёт декорацию на съёмочную площадку"
		if logistics_kind == "delivery"
		else "Возвращается к следующей декорации"
	)



func _start_route_within_stage_to_prop(
	worker_id: String,
	task: Dictionary,
	actor: Variant,
	stage_id: String
) -> void:
	var target_position: Vector3 = _manager.call(
		"get_set_dressing_mark",
		stage_id,
		int(task.get("prop_index", 0))
	)
	var route: Array[Vector3] = _manager.call("get_scene_path", stage_id, actor.global_position, target_position)
	if route.is_empty():
		_set_logistics_blocked = true
		push_error("StudioSetLogisticsController: cannot reach a set piece inside the stage.")
		return
	actor.call(
		"start_scene_performance",
		target_position,
		_manager.call("get_scene_focus_point", stage_id),
		"removing_set_piece",
		"",
		route
	)
	task["state"] = "to_stage_prop"
	_character_manager.call(
		"set_employee_task",
		worker_id,
		"Подходит к декорации для демонтажа"
	)



func _return_set_logistics_worker_to_stage(
	worker_id: String,
	last_location: String,
	stage_id: String,
	warehouse_id: String
) -> void:
	var actor: Variant = _character_manager.call(
		"get_employee_actor",
		worker_id
	)
	if actor == null or not is_instance_valid(actor):
		_set_logistics_blocked = true
		return
	var task: Dictionary = _set_logistics_worker_tasks.get(worker_id, {})
	var workplace_position: Vector3 = actor.call("get_workplace_position")
	if last_location == "warehouse":
		var prop_index: int = int(task.get("prop_index", 0))
		var route: Array[Vector3] = _build_route_warehouse_to_stage(
			worker_id,
			stage_id,
			warehouse_id,
			prop_index,
			workplace_position
		)
		if route.is_empty():
			_set_logistics_blocked = true
			return
		actor.call(
			"start_scene_performance",
			workplace_position,
			_manager.call("get_scene_focus_point", stage_id),
			"checking_equipment",
			"",
			route
		)
		task["state"] = "returning_via_warehouse"
		task["last_location"] = "warehouse"
		_set_logistics_worker_tasks[worker_id] = task
		return

	var return_path: Array[Vector3] = _manager.call("get_scene_path", stage_id, actor.global_position, workplace_position)
	if return_path.is_empty():
		_set_logistics_blocked = true
		return
	actor.call("return_to_workplace", return_path)
	task["state"] = "returning"
	_set_logistics_worker_tasks[worker_id] = task



func _are_set_logistics_tasks_complete() -> bool:
	if _set_logistics_blocked or not _set_logistics_pending_prop_ids.is_empty():
		return false
	for task_value in _set_logistics_worker_tasks.values():
		if str(task_value.get("state", "")) != "done":
			return false
	return true



func _are_set_logistics_workers_ready() -> bool:
	if not _are_set_logistics_tasks_complete():
		return false
	for worker_id in _set_logistics_worker_ids:
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			worker_id
		)
		if actor == null or not is_instance_valid(actor):
			return false
		if (
			bool(actor.call("is_in_scene_performance"))
			or bool(actor.call("is_returning_to_workplace"))
		):
			return false
		if not bool(
			_character_manager.call(
				"dispatch_employee_to_workplace",
				worker_id
			)
		):
			return false
	return true



func _build_route_stage_to_warehouse(
	worker_id: String,
	stage_id: String,
	warehouse_id: String,
	prop_index: int,
	start_position: Vector3
) -> Array[Vector3]:
	var stage_workplace_path: Array[Vector3] = _character_manager.call(
		"get_employee_workplace_path",
		worker_id
	)
	var warehouse_path: Array[Vector3] = _manager.call("get_workplace_path", warehouse_id, posmod(prop_index, 8))
	if stage_workplace_path.is_empty() or warehouse_path.is_empty():
		return []
	var stage_exit_path: Array[Vector3] = _manager.call(
		"get_scene_path",
		stage_id,
		start_position,
		stage_workplace_path[0]
	)
	var outdoor_path: Array[Vector3] = _navigation_system.call(
		"build_path",
		stage_workplace_path[0],
		warehouse_path[0],
		_manager.call("get_building_navigation_obstacles"),
		0.75,
		Rect2(Vector2(-47.0, -47.0), Vector2(94.0, 94.0))
	)
	if stage_exit_path.is_empty() or outdoor_path.is_empty():
		return []
	var result: Array[Vector3] = []
	_append_logistics_path(result, stage_exit_path)
	_append_logistics_path(result, outdoor_path)
	_append_logistics_path(result, warehouse_path)
	return result



func _build_route_warehouse_to_stage(
	worker_id: String,
	stage_id: String,
	warehouse_id: String,
	prop_index: int,
	target_position: Vector3
) -> Array[Vector3]:
	var stage_workplace_path: Array[Vector3] = _character_manager.call(
		"get_employee_workplace_path",
		worker_id
	)
	var warehouse_path: Array[Vector3] = _manager.call("get_workplace_path", warehouse_id, posmod(prop_index, 8))
	if stage_workplace_path.is_empty() or warehouse_path.is_empty():
		return []
	var warehouse_exit_path: Array[Vector3] = warehouse_path.duplicate()
	warehouse_exit_path.reverse()
	var outdoor_path: Array[Vector3] = _navigation_system.call(
		"build_path",
		warehouse_path[0],
		stage_workplace_path[0],
		_manager.call("get_building_navigation_obstacles"),
		0.75,
		Rect2(Vector2(-47.0, -47.0), Vector2(94.0, 94.0))
	)
	var stage_path: Array[Vector3] = _manager.call(
		"get_scene_path",
		stage_id,
		stage_workplace_path[0],
		target_position
	)
	if outdoor_path.is_empty() or stage_path.is_empty():
		return []
	var result: Array[Vector3] = []
	_append_logistics_path(result, warehouse_exit_path)
	_append_logistics_path(result, outdoor_path)
	_append_logistics_path(result, stage_path)
	return result



func _append_logistics_path(
	target: Array[Vector3],
	source: Array[Vector3]
) -> void:
	for point in source:
		if target.is_empty() or target.back().distance_to(point) > 0.2:
			target.append(point)



func _reset_set_logistics() -> void:
	_set_logistics_phase = ""
	_set_logistics_scene_key = ""
	_set_logistics_pending_prop_ids.clear()
	_set_logistics_worker_ids.clear()
	_set_logistics_worker_tasks.clear()
	_set_logistics_blocked = false