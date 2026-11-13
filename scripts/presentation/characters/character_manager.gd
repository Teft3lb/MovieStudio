extends Node3D
class_name CharacterManager

signal employees_changed
signal facility_usage_changed

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

const STAR_HOUSING_POPULARITY_THRESHOLD: float = 70.0
const FITNESS_TRAINING_START_HOUR: int = 17
const FITNESS_TRAINING_END_HOUR: int = 19
const STUDIO_LOUNGE_START_HOUR: int = 19
const STUDIO_LOUNGE_END_HOUR: int = 21
const DEFAULT_FITNESS_TRAINING_CAPACITY: int = 4
const DEFAULT_STUDIO_LOUNGE_CAPACITY: int = 6
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const CHARACTER_NEEDS_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_needs_system.gd"
)
const EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_management_system.gd"
)
const EMPLOYEE_WORK_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_work_system.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)
const CHARACTER_AGING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_aging_system.gd"
)
const EMPLOYEE_ROSTER_PANEL_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/characters/employee_roster_panel_controller.gd"
)
const EMPLOYEE_SKILL_PROGRESS_VIEW_SCRIPT = preload(
	"res://scripts/presentation/characters/employee_skill_progress_view.gd"
)
const EMPLOYEE_PROFILE_PANEL_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/characters/employee_profile_panel_controller.gd"
)
const DEVELOPER_EMPLOYEE_PANEL_SCRIPT = preload(
	"res://scripts/presentation/ui/developer_employee_panel.gd"
)
const CHARACTER_DEV_TUNING_SCRIPT = preload(
	"res://scripts/domain/characters/character_dev_tuning.gd"
)
const SKILL_PROGRESSION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_skill_progression_system.gd"
)

const INITIAL_PROFESSIONS: Array[String] = [
	"actor",
	"actor",
	"director",
	"screenwriter",
	"camera_operator",
	"producer",
]

var employees: Array = []
var market_candidates: Array = []
var _generator: RefCounted
var _needs_system: RefCounted
var _aging_system: RefCounted
var _skill_progression_system: RefCounted
var _employment_system: Variant
var _game_clock: Node
var _studio_hud: Node
var _workplace_system: RefCounted
var _studio_building_manager: Node
var _workplace_assignments: Dictionary = {}
var _employee_task_overrides: Dictionary = {}
var _manual_workplace_dispatches: Dictionary = {}
var _manual_workplace_assignments: Dictionary = {}

var _employee_actors: Dictionary = {}
var _employee_roster_view: RefCounted
var _employee_skill_progress_view: RefCounted
var _employee_profile_view: RefCounted
var _developer_employee_panel: RefCounted
var _selected_employee_id: String = ""
var _selected_market_candidate_id: String = ""


var _detail_skills_container: VBoxContainer

func _ready() -> void:
	_game_clock = get_node("../GameClock")
	_studio_hud = get_node_or_null("../StudioHUD")
	_employee_roster_view = EMPLOYEE_ROSTER_PANEL_CONTROLLER_SCRIPT.new()
	_employee_roster_view.call(
		"setup",
		_studio_hud,
		Callable(self, "_on_roster_employee_pressed"),
		Callable(self, "_toggle_market_panel"),
		Callable(self, "_close_market_panel"),
		Callable(self, "_on_market_candidate_pressed"),
		Callable(self, "_get_roster_work_state_title")
	)
	_employee_profile_view = EMPLOYEE_PROFILE_PANEL_CONTROLLER_SCRIPT.new()
	_employee_profile_view.call(
		"setup",
		Callable(self, "_on_contract_type_selected"),
		Callable(self, "_on_hire_button_pressed"),
		Callable(self, "_on_dismiss_button_pressed"),
		Callable(self, "_confirm_dismiss_employee"),
		Callable(self, "_on_workplace_dispatch_button_pressed"),
		Callable(self, "_on_workplace_assignment_selected"),
		Callable(self, "_on_publicity_event_requested")
	)
	_needs_system = CHARACTER_NEEDS_SYSTEM_SCRIPT.new()
	_aging_system = CHARACTER_AGING_SYSTEM_SCRIPT.new()
	_skill_progression_system = SKILL_PROGRESSION_SYSTEM_SCRIPT.new()
	_game_clock.minute_advanced.connect(_on_game_minute_advanced)
	_game_clock.day_advanced.connect(_on_game_day_advanced)
	_game_clock.manual_advance_finished.connect(_on_manual_advance_finished)

	_spawn_initial_roster()
	_build_roster_panel()
	_build_detail_panel()
	_build_developer_employee_panel()

	for employee in employees:
		_needs_system.call(
			"refresh_work_state", employee, int(_game_clock.current_hour)
		)

	if not employees.is_empty():
		_select_employee(str(employees[0].id))
	else:
		_refresh_detail_panel()

func get_employee_count() -> int:
	return employees.size()

func get_employees() -> Array:
	return employees.duplicate()

func get_selected_employee_id() -> String:
	return _selected_employee_id

func get_employee_actor(employee_id: String) -> Node:
	var actor: Variant = _employee_actors.get(employee_id)
	if actor == null or not is_instance_valid(actor):
		return null
	return actor as Node

func is_employee_at_scene_mark(employee_id: String) -> bool:
	var actor: Node = get_employee_actor(employee_id)
	if actor == null:
		return false
	return bool(actor.call("is_at_scene_mark"))

func _is_active_production_participant(employee_id: String) -> bool:
	if not is_instance_valid(_studio_building_manager):
		return false
	return bool(
		_studio_building_manager.call(
			"is_employee_in_active_production",
			employee_id
		)
	)

func _is_active_editing_participant(employee_id: String) -> bool:
	if (
		not is_instance_valid(_studio_building_manager)
		or not _studio_building_manager.has_method("is_employee_in_active_editing")
	):
		return false
	return bool(
		_studio_building_manager.call(
			"is_employee_in_active_editing",
			employee_id
		)
	)

func _should_auto_dispatch_to_workplace(
	employee_id: String,
	assignment: Dictionary
) -> bool:
	if assignment.is_empty():
		return false
	if _manual_workplace_dispatches.has(employee_id):
		return true
	match str(assignment.get("building_type_id", "")):
		"sound_stage":
			return _is_active_production_participant(employee_id)
		"editing_suite":
			return _is_active_editing_participant(employee_id)
		_:
			return true

func _is_employee_off_camera(employee_id: String) -> bool:
	if (
		not is_instance_valid(_studio_building_manager)
		or not _studio_building_manager.has_method("is_employee_off_camera")
	):
		return false
	return bool(
		_studio_building_manager.call(
			"is_employee_off_camera",
			employee_id
		)
	)

func _should_leave_workplace(
	employee_id: String,
	work_state: String,
	assignment_is_empty: bool
) -> bool:
	if assignment_is_empty:
		return true
	if _is_employee_off_camera(employee_id):
		return false
	if work_state == "working":
		return false
	return not _is_active_production_participant(employee_id)

func is_employee_assigned_to_building(
	employee_id: String,
	building_type_id: String
) -> bool:
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	return (
		not assignment.is_empty()
		and str(assignment.get("building_type_id", "")) == building_type_id
	)

func set_employee_task(employee_id: String, task_title: String) -> void:
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return
	_employee_task_overrides[employee_id] = task_title
	if str(employee.current_task) == task_title:
		return
	employee.current_task = task_title
	if not _game_clock.is_manual_fast_forward:
		_refresh_roster()
		_refresh_detail_panel()

func clear_employee_task(employee_id: String) -> void:
	_employee_task_overrides.erase(employee_id)
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return
	employee.current_task = PROFESSION_CATALOG_SCRIPT.get_default_task(
		str(employee.profession_id)
	)
	if not _game_clock.is_manual_fast_forward:
		_refresh_roster()
		_refresh_detail_panel()

func set_employee_production_action(
	employee_id: String,
	action_id: String
) -> void:
	var actor: Node = get_employee_actor(employee_id)
	if actor == null:
		return
	actor.call("set_production_action", action_id)

func initialize_workplaces(building_manager: Node) -> void:
	_studio_building_manager = building_manager
	_workplace_system = EMPLOYEE_WORK_SYSTEM_SCRIPT.new()
	if (
		is_instance_valid(_studio_building_manager)
		and _studio_building_manager.has_signal("buildings_changed")
	):
		var callback: Callable = Callable(
			self,
			"_refresh_workplace_assignments"
		)
		if not _studio_building_manager.is_connected(
			"buildings_changed",
			callback
		):
			_studio_building_manager.connect(
				"buildings_changed",
				callback
			)
	_refresh_workplace_assignments()

func get_employees_assigned_to_building(building_id: String) -> Array:
	var result: Array = []
	for employee in employees:
		var assignment: Dictionary = _workplace_assignments.get(
			str(employee.id),
			{}
		)
		if str(assignment.get("building_id", "")) == building_id:
			result.append(employee)
	return result

func get_employees_using_facility(building_id: String) -> Array:
	var result: Array = []
	for employee in employees:
		var actor: Node = get_employee_actor(str(employee.id))
		if actor == null or not bool(actor.call("is_in_facility")):
			continue
		if str(actor.call("get_facility_building_id")) == building_id:
			result.append(employee)
	return result

func _get_facility_assignment(
	employee_id: String,
	facility_type_id: String
) -> Dictionary:
	if not is_instance_valid(_studio_building_manager):
		return {}
	var buildings: Array = _studio_building_manager.call("get_buildings")
	var facility_slots: Array[Dictionary] = []
	for building in buildings:
		if (
			str(building.building_type_id) != facility_type_id
			or not bool(building.is_operational)
		):
			continue
		var capacity: int = BUILDING_CATALOG_SCRIPT.get_facility_capacity(
			facility_type_id
		)
		for slot_index in range(capacity):
			facility_slots.append({
				"building_id": str(building.id),
				"slot_index": slot_index,
			})

	if facility_slots.is_empty():
		return {}

	var reserved_slots: Dictionary = {}
	for employee in employees:
		var actor: Node = get_employee_actor(str(employee.id))
		if actor == null or not bool(actor.call("is_in_facility")):
			continue
		if str(actor.call("get_facility_type_id")) != facility_type_id:
			continue
		var reserved_key: String = "%s:%d" % [
				str(actor.call("get_facility_building_id")),
				int(actor.call("get_facility_slot_index")),
			]
		reserved_slots[reserved_key] = true

	for facility_slot in facility_slots:
		var slot_key: String = "%s:%d" % [
			str(facility_slot.get("building_id", "")),
			int(facility_slot.get("slot_index", -1)),
		]
		if not reserved_slots.has(slot_key):
			return facility_slot

	return {}

func _route_employee_to_facility(
	employee_id: String,
	facility_type_id: String
) -> bool:
	if not is_instance_valid(_studio_building_manager):
		return false
	var actor: Node3D = get_employee_actor(employee_id) as Node3D
	if actor == null:
		return false
	if bool(actor.call("is_in_facility")):
		return str(actor.call("get_facility_type_id")) == facility_type_id
	if (
		bool(actor.call("is_in_scene_performance"))
		or bool(actor.call("is_returning_to_workplace"))
	):
		return false
	var facility_assignment: Dictionary = _get_facility_assignment(
		employee_id,
		facility_type_id
	)
	if facility_assignment.is_empty():
		return false
	var workplace_assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	var source_building_id: String = str(
		actor.call("get_workplace_building_id")
	)
	var source_slot_index: int = int(
		workplace_assignment.get("slot_index", 0)
	)
	var facility_building_id: String = str(
		facility_assignment.get("building_id", "")
	)
	var facility_slot_index: int = int(
		facility_assignment.get("slot_index", 0)
	)
	var route: Array[Vector3] = _studio_building_manager.call(
		"get_facility_path_from",
		facility_building_id,
		facility_slot_index,
		actor.global_position,
		source_building_id,
		source_slot_index
	)
	if route.is_empty():
		return false
	var action_id: String = "sleeping"
	match facility_type_id:
		"cafeteria":
			action_id = "eating"
		"fitness_center":
			action_id = "training"
		"studio_lounge":
			action_id = "socializing"
	var facing_direction: Vector3 = Vector3.ZERO
	if (
		facility_type_id in [
			"cafeteria",
			"fitness_center",
			"studio_lounge",
			"staff_housing",
			"star_bungalow",
		]
		and _studio_building_manager.has_method(
			"get_workplace_facing_direction"
		)
	):
		facing_direction = _studio_building_manager.call(
			"get_workplace_facing_direction",
			facility_building_id,
			facility_slot_index
		)
	if not bool(actor.call(
		"assign_facility_route",
		facility_building_id,
		facility_type_id,
		facility_slot_index,
		route,
		action_id,
		facing_direction
	)):
		return false
	if (
		is_instance_valid(_game_clock)
		and bool(_game_clock.is_manual_fast_forward)
	):
		actor.call("snap_to_facility")
	facility_usage_changed.emit()
	return true

func is_employee_at_workplace(
	employee_id: String,
	building_type_id: String = ""
) -> bool:
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	if assignment.is_empty():
		return false
	if (
		not building_type_id.is_empty()
		and str(assignment.get("building_type_id", "")) != building_type_id
	):
		return false

	var actor: Variant = _employee_actors.get(employee_id)
	if actor == null or not is_instance_valid(actor):
		return false
	var employee: Variant = _find_employee(employee_id)
	if (
		actor.has_method("is_off_camera")
		and bool(actor.call("is_off_camera"))
	):
		return bool(actor.call("is_at_scene_hold_mark"))
	if (
		actor.has_method("is_returning_to_workplace")
		and bool(actor.call("is_returning_to_workplace"))
	):
		return false
	if (
		_game_clock.is_manual_fast_forward
		and employee != null
		and (
			str(employee.work_state) == "working"
			or _is_active_production_participant(employee_id)
		)
	):
		return true
	return bool(actor.call("is_at_workplace"))

func is_employee_ready_for_production(
	employee_id: String,
	building_type_id: String
) -> bool:
	if not is_employee_assigned_to_building(employee_id, building_type_id):
		return false
	var actor: Node = get_employee_actor(employee_id)
	if actor == null:
		return false
	if bool(actor.call("is_returning_to_workplace")):
		return false
	if bool(actor.call("is_in_scene_performance")):
		return (
			bool(actor.call("is_at_scene_mark"))
			or bool(actor.call("is_at_scene_hold_mark"))
		)
	return bool(actor.call("is_at_workplace"))

func dispatch_employee_to_workplace(employee_id: String) -> bool:
	if not is_instance_valid(_studio_building_manager):
		return false
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	var actor: Node3D = get_employee_actor(employee_id) as Node3D
	if actor == null:
		return false
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return false
	var manual_fast_forward: bool = (
		is_instance_valid(_game_clock)
		and bool(_game_clock.is_manual_fast_forward)
	)
	if assignment.is_empty():
		if (
			not bool(actor.call("is_in_facility"))
			or not bool(actor.call("is_at_facility"))
		):
			return false
		var facility_building_id: String = str(
			actor.call("get_facility_building_id")
		)
		var facility_slot_index: int = int(
			actor.call("get_facility_slot_index")
		)
		var exit_route: Array[Vector3] = []
		if _studio_building_manager.has_method("get_exit_path_from"):
			exit_route = _studio_building_manager.call(
				"get_exit_path_from",
				facility_building_id,
				actor.global_position,
				facility_slot_index
			)
		if exit_route.is_empty():
			exit_route = _studio_building_manager.call(
				"get_workplace_path",
				facility_building_id,
				facility_slot_index
			)
			if exit_route.is_empty():
				return false
			exit_route.reverse()
		if exit_route.front().distance_to(actor.global_position) > 0.2:
			exit_route.insert(0, actor.global_position)
		if not bool(actor.call("leave_facility", exit_route)):
			return false
		facility_usage_changed.emit()
		if manual_fast_forward:
			actor.call("snap_outside_facility")
			return true
		return false

	var building_id: String = str(assignment.get("building_id", ""))
	if building_id.is_empty():
		return false
	var slot_index: int = int(assignment.get("slot_index", 0))
	var profession_id: String = str(employee.profession_id)
	if bool(actor.call("is_in_facility")):
		# A new work shift cancels an unfinished trip to a rest facility.
		# Replan from the actor's actual position, including the facility exit.
		var source_building_id: String = str(
			actor.call("get_facility_building_id")
		)
		var source_slot_index: int = int(
			actor.call("get_facility_slot_index")
		)
		var return_route: Array[Vector3] = _studio_building_manager.call(
			"get_workplace_path_from",
			building_id,
			slot_index,
			actor.global_position,
			source_building_id,
			source_slot_index
		)
		if return_route.is_empty():
			return false
		if str(actor.call("get_workplace_building_id")) != building_id:
			var workplace_exit_route: Array[Vector3] = _studio_building_manager.call(
				"get_workplace_path",
				building_id,
				slot_index
			)
			if workplace_exit_route.is_empty():
				return false
			actor.call(
				"assign_workplace_route",
				building_id,
				return_route,
				profession_id,
				workplace_exit_route,
				slot_index
			)
		else:
			actor.call("return_to_workplace", return_route)
		facility_usage_changed.emit()
		if manual_fast_forward:
			actor.call("snap_to_workplace")
			return true
		return false

	var current_building_id: String = str(
		actor.call("get_workplace_building_id")
	)
	if current_building_id == building_id:
		if (
			actor.has_method("is_off_camera")
			and bool(actor.call("is_off_camera"))
		):
			return (
				bool(actor.call("is_at_scene_hold_mark"))
				or _is_active_production_participant(employee_id)
			)
		if bool(actor.call("is_returning_to_workplace")):
			return false
		if bool(actor.call("is_at_workplace")):
			return true
		if bool(actor.call("is_leaving_workplace")):
			var workplace_position: Vector3 = _studio_building_manager.call(
				"get_workplace_position",
				building_id,
				slot_index
			)
			var return_route: Array[Vector3] = _studio_building_manager.call(
				"get_scene_path",
				building_id,
				actor.global_position,
				workplace_position
			)
			if return_route.is_empty():
				return false
			var workplace_exit_route: Array[Vector3] = _studio_building_manager.call(
				"get_workplace_path",
				building_id,
				slot_index
			)
			if workplace_exit_route.is_empty():
				return false
			actor.call(
				"assign_workplace_route",
				building_id,
				return_route,
				profession_id,
				workplace_exit_route,
				slot_index
			)
		if manual_fast_forward:
			actor.call("snap_to_workplace")
			return true
		return false

	if not current_building_id.is_empty():
		if manual_fast_forward:
			actor.call("snap_outside_workplace")
		else:
			if not bool(actor.call("is_leaving_workplace")):
				_leave_actor_from_workplace(actor)
			return false

	var route: Array[Vector3] = _studio_building_manager.call(
		"get_workplace_path_from",
		building_id,
		slot_index,
		actor.global_position
	)
	if route.is_empty():
		return false
	var workplace_exit_route: Array[Vector3] = _studio_building_manager.call(
		"get_workplace_path",
		building_id,
		slot_index
	)
	if workplace_exit_route.is_empty():
		return false
	actor.call(
		"assign_workplace_route",
		building_id,
		route,
		profession_id,
		workplace_exit_route,
		slot_index
	)
	if manual_fast_forward:
		actor.call("snap_to_workplace")
		return true
	return false

func dispatch_employee_to_workplace_manually(employee_id: String) -> bool:
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	var building_type_id: String = str(
		assignment.get("building_type_id", "")
	)
	if (
		assignment.is_empty()
		or building_type_id not in ["sound_stage", "editing_suite"]
		or _is_active_production_participant(employee_id)
		or _is_active_editing_participant(employee_id)
	):
		return false
	var actor: Node3D = get_employee_actor(employee_id) as Node3D
	if actor == null:
		return false
	if (
		bool(actor.call("is_in_facility"))
		and not bool(actor.call("is_at_facility"))
	):
		return false

	_manual_workplace_dispatches[employee_id] = true
	dispatch_employee_to_workplace(employee_id)
	var target_building_id: String = str(assignment.get("building_id", ""))
	if (
		bool(actor.call("is_in_facility"))
		or str(actor.call("get_workplace_building_id")) != target_building_id
	):
		_manual_workplace_dispatches.erase(employee_id)
		return false

	var is_at_workplace: bool = bool(actor.call("is_at_workplace"))
	var task_title: String = ""
	if building_type_id == "sound_stage":
		task_title = (
			"На площадке по вызову"
			if is_at_workplace
			else "Идёт на площадку по вызову"
		)
	else:
		task_title = (
			"Работает в монтажной"
			if is_at_workplace
			else "Идёт в монтажную"
		)
	set_employee_task(employee_id, task_title)
	return true

func release_employee_from_workplace_manually(employee_id: String) -> void:
	_manual_workplace_dispatches.erase(employee_id)
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	var actor: Node3D = get_employee_actor(employee_id) as Node3D
	if (
		actor != null
		and not _is_active_production_participant(employee_id)
		and not assignment.is_empty()
		and str(actor.call("get_workplace_building_id"))
			== str(assignment.get("building_id", ""))
		and not bool(actor.call("is_leaving_workplace"))
	):
		_leave_actor_from_workplace(actor)
	clear_employee_task(employee_id)

func can_reassign_employee_workplace(employee_id: String) -> bool:
	return (
		_find_employee(employee_id) != null
		and not _is_active_production_participant(employee_id)
		and not _is_active_editing_participant(employee_id)
	)


func set_employee_workplace_assignment(
	employee_id: String,
	building_id: String
) -> bool:
	if _workplace_system == null or not is_instance_valid(_studio_building_manager):
		return false
	if not can_reassign_employee_workplace(employee_id):
		return false
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return false
	var previous: String = str(_manual_workplace_assignments.get(employee_id, ""))
	if building_id.is_empty():
		_manual_workplace_assignments.erase(employee_id)
	else:
		_manual_workplace_assignments[employee_id] = building_id
	var buildings: Array = _studio_building_manager.call("get_buildings")
	var preferred_stage: String = ""
	if _studio_building_manager.has_method("get_preferred_stage_building_id"):
		preferred_stage = str(
			_studio_building_manager.call("get_preferred_stage_building_id")
		)
	var candidate_assignments: Dictionary = _workplace_system.call(
		"build_assignments",
		employees,
		buildings,
		preferred_stage,
		_manual_workplace_assignments
	)
	var proposed: Dictionary = candidate_assignments.get(employee_id, {})
	if not building_id.is_empty() and str(proposed.get("building_id", "")) != building_id:
		if previous.is_empty():
			_manual_workplace_assignments.erase(employee_id)
		else:
			_manual_workplace_assignments[employee_id] = previous
		return false
	_manual_workplace_dispatches.erase(employee_id)
	_refresh_workplace_assignments()
	return true


func _on_workplace_assignment_selected(building_id: String) -> void:
	if _selected_employee_id.is_empty():
		return
	if not set_employee_workplace_assignment(_selected_employee_id, building_id):
		_show_employee_message(
			"Нельзя перевести сотрудника: проверь профессию, свободные места "
			+ "или участие в текущем производстве."
		)
	_refresh_detail_panel()


func _refresh_employee_workplace_options(employee_id: String) -> void:
	if _employee_profile_view == null or not is_instance_valid(_studio_building_manager):
		return
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return
	var selected_building_id: String = str(
		_manual_workplace_assignments.get(employee_id, "")
	)
	var actual_assignment: Dictionary = _workplace_assignments.get(
		employee_id, {}
	)
	var active: bool = (
		_is_active_production_participant(employee_id)
		or _is_active_editing_participant(employee_id)
	)
	var choices: Array[Dictionary] = []
	for building in _studio_building_manager.call("get_buildings"):
		if not bool(building.is_operational):
			continue
		if not BUILDING_CATALOG_SCRIPT.accepts_profession(
			str(building.building_type_id), str(employee.profession_id)
		):
			continue
		var assigned_here: int = get_employees_assigned_to_building(
			str(building.id)
		).size()
		var capacity: int = BUILDING_CATALOG_SCRIPT.get_workplace_capacity_for_building(
			building
		)
		var is_current: bool = (
			str(actual_assignment.get("building_id", "")) == str(building.id)
		)
		choices.append({
			"id": str(building.id),
			"title": "%s (%d/%d)" % [
				str(building.display_name), assigned_here, capacity
			],
			"disabled": active or (assigned_here >= capacity and not is_current),
		})
	_employee_profile_view.call(
		"set_workplace_assignment_options",
		choices,
		selected_building_id,
		str(actual_assignment.get("building_id", "")),
		not active
	)


func refresh_workplace_assignments() -> void:
	_refresh_workplace_assignments()

func _refresh_workplace_assignments() -> void:
	if (
		_workplace_system == null
		or not is_instance_valid(_studio_building_manager)
	):
		return
	var buildings: Array = _studio_building_manager.call("get_buildings")
	var preferred_stage_building_id: String = ""
	if _studio_building_manager.has_method("get_preferred_stage_building_id"):
		preferred_stage_building_id = str(
			_studio_building_manager.call("get_preferred_stage_building_id")
		)
	_workplace_assignments = _workplace_system.call(
		"build_assignments",
		employees,
		buildings,
		preferred_stage_building_id,
		_manual_workplace_assignments
	)
	for employee in employees:
		var employee_id: String = str(employee.id)
		var actor: Variant = _employee_actors.get(employee_id)
		if actor == null or not is_instance_valid(actor):
			continue
		var assignment: Dictionary = _workplace_assignments.get(employee_id, {})
		if _is_active_production_participant(employee_id):
			_manual_workplace_dispatches.erase(employee_id)
			continue
		if _manual_workplace_dispatches.has(employee_id):
			if (
				assignment.is_empty()
				or str(assignment.get("building_type_id", ""))
					not in ["sound_stage", "editing_suite"]
			):
				_manual_workplace_dispatches.erase(employee_id)
			else:
				var manual_building_id: String = str(assignment.get("building_id", ""))
				var current_manual_building_id: String = str(
					actor.call("get_workplace_building_id")
				)
				if (
					current_manual_building_id != manual_building_id
					or bool(actor.call("is_in_facility"))
					or bool(actor.call("is_leaving_workplace"))
				):
					dispatch_employee_to_workplace(employee_id)
				continue
		if (
			bool(actor.call("is_in_facility"))
			or bool(actor.call("is_returning_to_workplace"))
		):
			continue
		if _should_leave_workplace(
			employee_id,
			str(employee.work_state),
			assignment.is_empty()
		):
			_leave_actor_from_workplace(actor)
			continue
		var building_id: String = str(assignment.get("building_id", ""))
		var current_building_id: String = str(actor.call("get_workplace_building_id"))
		if not _should_auto_dispatch_to_workplace(employee_id, assignment):
			if (
				not current_building_id.is_empty()
				and not bool(actor.call("is_leaving_workplace"))
			):
				_leave_actor_from_workplace(actor)
			continue
		if current_building_id != building_id:
			if not current_building_id.is_empty():
				if not bool(actor.call("is_leaving_workplace")):
					_leave_actor_from_workplace(actor)
				continue
			if bool(actor.call("is_leaving_workplace")):
				continue
			var route: Array[Vector3] = _studio_building_manager.call(
				"get_workplace_path_from",
				building_id,
				int(assignment.get("slot_index", 0)),
				actor.global_position
			)
			if route.is_empty():
				continue
			var workplace_exit_route: Array[Vector3] = _studio_building_manager.call(
				"get_workplace_path",
				building_id,
				int(assignment.get("slot_index", 0))
			)
			if workplace_exit_route.is_empty():
				continue
			actor.call(
				"assign_workplace_route",
				building_id,
				route,
				str(employee.profession_id),
				workplace_exit_route,
				int(assignment.get("slot_index", 0))
			)
	_refresh_roaming_routes()
	if _employee_roster_view != null:
		_refresh_roster()
		_refresh_detail_panel()

func _refresh_roaming_routes() -> void:
	if (
		not is_instance_valid(_studio_building_manager)
		or not _studio_building_manager.has_method("get_roaming_route")
	):
		return
	for index in range(employees.size()):
		var employee_id: String = str(employees[index].id)
		var actor: Node = get_employee_actor(employee_id)
		if actor == null:
			continue
		var start_position: Vector3 = actor.call(
			"get_roaming_resume_position"
		)
		var base_route: Array[Vector3] = _route_for(index)
		var safe_route: Array[Vector3] = _studio_building_manager.call(
			"get_roaming_route",
			start_position,
			base_route
		)
		# The first leg may be a one-time trip from inside a building
		# through its door. After that, only loop the outdoor patrol.
		var loop_start_index: int = 0
		if _studio_building_manager.has_method("get_roaming_loop_start_index"):
			loop_start_index = int(_studio_building_manager.call(
				"get_roaming_loop_start_index", safe_route, base_route
			))
		# Never keep the old unsanitized route when a new building blocks it.
		actor.call("set_roaming_route", safe_route, loop_start_index)

func refresh_navigation_routes() -> void:
	_refresh_roaming_routes()

func _spawn_initial_roster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	_generator = CHARACTER_GENERATOR_SCRIPT.new()

	for index in range(INITIAL_PROFESSIONS.size()):
		var employee_id: String = "EMP-%04d" % (index + 1)
		var profession_id: String = INITIAL_PROFESSIONS[index]
		var data: Variant = _generator.call(
			"generate", rng, employee_id, profession_id, true
		)
		employees.append(data)

	_employment_system = EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT.new()
	_employment_system.call(
		"initialize",
		employees,
		int(_game_clock.current_day),
		20261104 + 104729,
		8
	)
	market_candidates = _employment_system.market_candidates

	for index in range(employees.size()):
		_spawn_employee_actor(employees[index], index)

func _spawn_employee_actor(employee: Variant, index: int) -> void:
	var employee_id: String = str(employee.id)
	if _employee_actors.has(employee_id):
		return

	var actor: Variant = CHARACTER_ACTOR_SCRIPT.new()
	actor.name = "Employee_%s" % employee_id.replace("-", "_")
	actor.call(
		"setup",
		employee,
		_route_for(index),
		_game_clock,
		1.0 + float(index % 5) * 0.09
	)
	add_child(actor)
	_employee_actors[employee_id] = actor

func _remove_employee_actor(employee_id: String) -> void:
	_employee_task_overrides.erase(employee_id)
	_manual_workplace_dispatches.erase(employee_id)
	_manual_workplace_assignments.erase(employee_id)
	var actor: Variant = _employee_actors.get(employee_id)
	if actor != null and is_instance_valid(actor):
		actor.queue_free()
	_employee_actors.erase(employee_id)

	if _employee_roster_view != null:
		_employee_roster_view.call("remove_employee", employee_id)

func _route_for(index: int) -> Array[Vector3]:
	var route: Array[Vector3] = []

	match index % 6:
		0:
			route = [
				Vector3(-8.0, 0.0, 9.0),
				Vector3(-3.0, 0.0, 9.0),
				Vector3(4.0, 0.0, 9.0),
				Vector3(8.0, 0.0, 9.0),
				Vector3(8.0, 0.0, 12.0),
				Vector3(-8.0, 0.0, 12.0),
			]
		1:
			route = [
				Vector3(-8.0, 0.0, -9.0),
				Vector3(0.0, 0.0, -9.0),
				Vector3(8.0, 0.0, -9.0),
				Vector3(8.0, 0.0, -12.0),
				Vector3(-8.0, 0.0, -12.0),
			]
		2:
			route = [
				Vector3(-17.0, 0.0, 8.0),
				Vector3(-17.0, 0.0, 0.0),
				Vector3(-17.0, 0.0, -10.0),
				Vector3(-14.0, 0.0, -10.0),
				Vector3(-14.0, 0.0, 8.0),
			]
		3:
			route = [
				Vector3(14.0, 0.0, -10.0),
				Vector3(14.0, 0.0, 0.0),
				Vector3(14.0, 0.0, 10.0),
				Vector3(11.0, 0.0, 10.0),
				Vector3(11.0, 0.0, -10.0),
			]
		4:
			route = [
				Vector3(-8.0, 0.0, 16.0),
				Vector3(0.0, 0.0, 16.0),
				Vector3(8.0, 0.0, 16.0),
				Vector3(8.0, 0.0, 19.0),
				Vector3(-8.0, 0.0, 19.0),
			]
		_:
			route = [
				Vector3(-8.0, 0.0, -16.0),
				Vector3(0.0, 0.0, -16.0),
				Vector3(8.0, 0.0, -16.0),
				Vector3(8.0, 0.0, -13.0),
				Vector3(-8.0, 0.0, -13.0),
			]

	var route_group: int = floori(float(index) / 6.0)
	if route_group > 0:
		var lane_offset: Vector3 = Vector3(0.0, 0.0, float(route_group) * 3.5)
		for waypoint_index in range(route.size()):
			route[waypoint_index] += lane_offset

	return route

func _build_roster_panel() -> void:
	if _employee_roster_view == null:
		return
	_employee_roster_view.call(
		"build",
		employees,
		market_candidates,
		_selected_employee_id,
		_get_market_days_until_refresh()
	)

func _add_roster_button(employee: Variant) -> void:
	if _employee_roster_view == null:
		return
	_employee_roster_view.call("add_employee", employee)

func _toggle_market_panel() -> void:
	if (
		_employee_roster_view == null
		or not bool(_employee_roster_view.call("has_market_panel"))
		or _studio_hud == null
	):
		return
	_refresh_market_panel()
	_studio_hud.call("show_workspace_panel", "market")

func _close_market_panel() -> void:
	if _studio_hud != null:
		_studio_hud.call("show_workspace_panel", "employees")

func _refresh_market_panel() -> void:
	if _employee_roster_view == null:
		return
	_employee_roster_view.call(
		"refresh_market_panel",
		market_candidates,
		_get_market_days_until_refresh()
	)

func _get_market_days_until_refresh() -> int:
	if _employment_system == null or _game_clock == null:
		return 0
	return int(
		_employment_system.call(
			"get_market_days_until_refresh",
			int(_game_clock.current_day)
		)
	)

func _build_detail_panel() -> void:
	if _employee_profile_view == null:
		return
	_employee_profile_view.call("build", _studio_hud)
	_detail_skills_container = _employee_profile_view.call(
		"get_skill_container"
	) as VBoxContainer
	_ensure_skill_progress_view()

func _build_developer_employee_panel() -> void:
	if (
		not is_instance_valid(_studio_hud)
		or not _studio_hud.has_method("get_developer_tools_layout")
	):
		return
	var layout: VBoxContainer = _studio_hud.call(
		"get_developer_tools_layout"
	) as VBoxContainer
	if not is_instance_valid(layout):
		return
	_developer_employee_panel = DEVELOPER_EMPLOYEE_PANEL_SCRIPT.new()
	_developer_employee_panel.call("build", layout, self)


func developer_change_employee_stat(
	employee_id: String,
	stat_id: String,
	amount: float,
	is_absolute: bool = false
) -> bool:
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return false
	var tuning: RefCounted = CHARACTER_DEV_TUNING_SCRIPT.new()
	var success: bool = bool(
		tuning.call("set_stat", employee, stat_id, amount)
		if is_absolute
		else tuning.call("adjust_stat", employee, stat_id, amount)
	)
	if success:
		_refresh_detail_panel()
		_refresh_roster()
	return success


func _on_publicity_event_requested(employee_id: String, event_id: String) -> void:
	if (
		not is_instance_valid(_studio_building_manager)
		or not _studio_building_manager.has_method("request_publicity_event")
	):
		_show_employee_message("Публичные мероприятия пока недоступны.")
		return
	var result: Dictionary = _studio_building_manager.call(
		"request_publicity_event", employee_id, event_id
	)
	if not bool(result.get("success", false)):
		_show_employee_message(str(result.get("message", "")))
	_refresh_detail_panel()


func _on_roster_employee_pressed(employee_id: String) -> void:
	_select_employee(employee_id)

func _leave_actor_from_workplace(actor: Variant) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var building_id: String = str(actor.call("get_workplace_building_id"))
	if building_id.is_empty():
		actor.call("leave_workplace")
		return

	var employee_id: String = str(actor.call("get_character_id"))
	var assignment: Dictionary = _workplace_assignments.get(employee_id, {})
	var slot_index: int = -1
	if str(assignment.get("building_id", "")) == building_id:
		slot_index = int(assignment.get("slot_index", -1))

	var exit_route: Array[Vector3] = []
	if (
		is_instance_valid(_studio_building_manager)
		and _studio_building_manager.has_method("get_exit_path_from")
	):
		exit_route = _studio_building_manager.call(
			"get_exit_path_from",
			building_id,
			actor.global_position,
			slot_index
		)
	if exit_route.is_empty():
		actor.call("leave_workplace")
	else:
		actor.call("leave_workplace", exit_route)

func _release_employee_to_free_roam(actor: Variant) -> void:
	if bool(actor.call("is_in_facility")):
		if (
			not bool(actor.call("is_at_facility"))
			or not is_instance_valid(_studio_building_manager)
		):
			return
		var facility_building_id: String = str(
			actor.call("get_facility_building_id")
		)
		var facility_slot_index: int = int(
			actor.call("get_facility_slot_index")
		)
		var exit_route: Array[Vector3] = []
		if _studio_building_manager.has_method("get_exit_path_from"):
			exit_route = _studio_building_manager.call(
				"get_exit_path_from",
				facility_building_id,
				actor.global_position,
				facility_slot_index
			)
		if exit_route.is_empty():
			exit_route = _studio_building_manager.call(
				"get_workplace_path",
				facility_building_id,
				facility_slot_index
			)
			if exit_route.is_empty():
				return
			exit_route.reverse()
		if exit_route.front().distance_to(actor.global_position) > 0.2:
			exit_route.insert(0, actor.global_position)
		if not bool(actor.call("leave_facility", exit_route, true)):
			return
		facility_usage_changed.emit()
		if (
			is_instance_valid(_game_clock)
			and bool(_game_clock.is_manual_fast_forward)
		):
			actor.call("snap_outside_facility")
		return

	if (
		str(actor.call("get_workplace_building_id")).is_empty()
		or bool(actor.call("is_leaving_workplace"))
	):
		return
	_leave_actor_from_workplace(actor)
	if (
		is_instance_valid(_game_clock)
		and bool(_game_clock.is_manual_fast_forward)
	):
		actor.call("snap_outside_workplace")

func _get_total_facility_capacity(
	facility_type_id: String,
	default_capacity: int
) -> int:
	if (
		is_instance_valid(_studio_building_manager)
		and _studio_building_manager.has_method("get_total_facility_capacity")
	):
		return int(
			_studio_building_manager.call(
				"get_total_facility_capacity",
				facility_type_id
			)
		)
	return default_capacity if is_instance_valid(_studio_building_manager) else 0

func _is_employee_in_rotating_facility_group(
	employee_id: String,
	employee_ids: Array[String],
	capacity: int,
	day: int
) -> bool:
	if employee_ids.is_empty() or capacity <= 0:
		return false
	if employee_ids.size() <= capacity:
		return employee_ids.has(employee_id)
	var first_index: int = posmod(day * capacity, employee_ids.size())
	for slot_index in range(capacity):
		var candidate_index: int = posmod(
			first_index + slot_index,
			employee_ids.size()
		)
		if employee_ids[candidate_index] == employee_id:
			return true
	return false

func _get_free_time_facility_type(
	employee: Variant,
	hour: int,
	day: int
) -> String:
	if (
		hour >= FITNESS_TRAINING_START_HOUR
		and hour < FITNESS_TRAINING_END_HOUR
		and str(employee.profession_id) == "actor"
	):
		var training_actor_ids: Array[String] = []
		for candidate in employees:
			if (
				str(candidate.profession_id) == "actor"
				and float(candidate.physical_fitness) < 98.0
			):
				training_actor_ids.append(str(candidate.id))
		var training_capacity: int = _get_total_facility_capacity(
			"fitness_center",
			DEFAULT_FITNESS_TRAINING_CAPACITY
		)
		if (
			float(employee.physical_fitness) < 98.0
			and _is_employee_in_rotating_facility_group(
				str(employee.id),
				training_actor_ids,
				training_capacity,
				day
			)
		):
			return "fitness_center"
	if (
		hour >= STUDIO_LOUNGE_START_HOUR
		and hour < STUDIO_LOUNGE_END_HOUR
	):
		var social_employee_ids: Array[String] = []
		for candidate in employees:
			social_employee_ids.append(str(candidate.id))
		var social_capacity: int = _get_total_facility_capacity(
			"studio_lounge",
			DEFAULT_STUDIO_LOUNGE_CAPACITY
		)
		if _is_employee_in_rotating_facility_group(
			str(employee.id),
			social_employee_ids,
			social_capacity,
			day
		):
			return "studio_lounge"
	return ""

func _update_social_relationships() -> void:
	var attendees_by_building: Dictionary = {}
	for employee in employees:
		var actor: Node = get_employee_actor(str(employee.id))
		if (
			actor == null
			or not bool(actor.call("is_at_facility", "studio_lounge"))
		):
			continue
		var building_id: String = str(
			actor.call("get_facility_building_id")
		)
		if not attendees_by_building.has(building_id):
			attendees_by_building[building_id] = []
		attendees_by_building[building_id].append(employee)
	for building_id_value in attendees_by_building.keys():
		var attendees: Array = attendees_by_building[building_id_value]
		for first_index in range(attendees.size()):
			for second_index in range(first_index + 1, attendees.size()):
				var first: Variant = attendees[first_index]
				var second: Variant = attendees[second_index]
				var first_id: String = str(first.id)
				var second_id: String = str(second.id)
				var first_sociability: float = clampf(
					float(first.personality.get("sociability", 0.5)),
					0.0,
					1.0
				)
				var second_sociability: float = clampf(
					float(second.personality.get("sociability", 0.5)),
					0.0,
					1.0
				)
				var average_sociability: float = (
					first_sociability + second_sociability
				) * 0.5
				var ambition_gap: float = absf(
					float(first.personality.get("ambition", 0.5))
					- float(second.personality.get("ambition", 0.5))
				)
				var discipline_gap: float = absf(
					float(first.personality.get("discipline", 0.5))
					- float(second.personality.get("discipline", 0.5))
				)
				var compatibility: float = clampf(
					1.0 - ambition_gap * 0.75 - discipline_gap * 0.45,
					0.0,
					1.0
				)
				var relationship_gain: float = (
					0.006
					* (0.75 + average_sociability * 0.5)
					* compatibility
				)
				if compatibility < 0.35 or average_sociability < 0.22:
					relationship_gain = -0.0025
				var first_relationships: Dictionary = first.relationships.duplicate(true)
				var second_relationships: Dictionary = second.relationships.duplicate(true)
				first_relationships[second_id] = clampf(
					float(first_relationships.get(second_id, 0.0))
					+ relationship_gain,
					-100.0,
					100.0
				)
				second_relationships[first_id] = clampf(
					float(second_relationships.get(first_id, 0.0))
					+ relationship_gain,
					-100.0,
					100.0
				)
				first.relationships = first_relationships
				second.relationships = second_relationships

func _get_relationship_summary(employee: Variant) -> String:
	var relationship_ids: Array[String] = []
	var relationship_scores: Array[float] = []
	for relationship_id_value in employee.relationships.keys():
		var relationship_id: String = str(relationship_id_value)
		var relationship_target: Variant = _find_employee(relationship_id)
		if relationship_target == null:
			continue
		var candidate_score: float = clampf(
			float(employee.relationships[relationship_id_value]),
			-100.0,
			100.0
		)
		if absf(candidate_score) < 5.0:
			continue
		relationship_ids.append(relationship_id)
		relationship_scores.append(candidate_score)
	var summary_lines: Array[String] = []
	for rank in range(mini(3, relationship_ids.size())):
		var best_index: int = rank
		for candidate_index in range(rank + 1, relationship_ids.size()):
			if (
				absf(relationship_scores[candidate_index])
				> absf(relationship_scores[best_index])
			):
				best_index = candidate_index
		if best_index != rank:
			var swapped_id: String = relationship_ids[rank]
			relationship_ids[rank] = relationship_ids[best_index]
			relationship_ids[best_index] = swapped_id
			var swapped_score: float = relationship_scores[rank]
			relationship_scores[rank] = relationship_scores[best_index]
			relationship_scores[best_index] = swapped_score
		var selected_relationship_target: Variant = _find_employee(
			relationship_ids[rank]
		)
		if selected_relationship_target == null:
			continue
		var selected_score: float = relationship_scores[rank]
		var relationship_title: String = "Знакомство"
		if selected_score >= 25.0:
			relationship_title = "Дружба"
		elif selected_score <= -25.0:
			relationship_title = "Конфликт"
		summary_lines.append(
			"%s · %s %d" % [
				selected_relationship_target.get_full_name(),
				relationship_title,
				roundi(absf(selected_score)),
			]
		)
	if summary_lines.is_empty():
		return "Отношения: пока нет сложившихся связей"
	return "Отношения:\n" + "\n".join(summary_lines)

func _on_game_minute_advanced(day: int, hour: int, _minute: int) -> void:
	for employee in employees:
		var employee_id: String = str(employee.id)
		var actor: Variant = _employee_actors.get(employee_id)
		var at_cafeteria: bool = (
			actor != null
			and is_instance_valid(actor)
			and bool(actor.call("is_at_facility", "cafeteria"))
		)
		var at_staff_housing: bool = (
			actor != null
			and is_instance_valid(actor)
			and bool(actor.call("is_at_facility", "staff_housing"))
		)
		var at_star_bungalow: bool = (
			actor != null
			and is_instance_valid(actor)
			and bool(actor.call("is_at_facility", "star_bungalow"))
		)
		var at_fitness_center: bool = (
			actor != null
			and is_instance_valid(actor)
			and bool(actor.call("is_at_facility", "fitness_center"))
		)
		var at_studio_lounge: bool = (
			actor != null
			and is_instance_valid(actor)
			and bool(actor.call("is_at_facility", "studio_lounge"))
		)
		_needs_system.call(
			"advance_minute",
			employee,
			hour,
			at_cafeteria,
			at_staff_housing,
			at_star_bungalow,
			at_fitness_center,
			at_studio_lounge
		)

		if actor == null or not is_instance_valid(actor):
			continue
		# Public appearances temporarily own the actor's route and task.
		# Do not replace the invitation route with a lunch/housing/work call.
		if (
			is_instance_valid(_studio_building_manager)
			and _studio_building_manager.has_method(
				"is_employee_in_publicity_event"
			)
			and bool(_studio_building_manager.call(
				"is_employee_in_publicity_event", employee_id
			))
		):
			continue
		if _is_active_production_participant(employee_id):
			_manual_workplace_dispatches.erase(employee_id)
			var release_for_off_hours: bool = (
				is_instance_valid(_studio_building_manager)
				and _studio_building_manager.has_method(
					"should_release_production_employee_for_off_hours"
				)
				and bool(
					_studio_building_manager.call(
						"should_release_production_employee_for_off_hours",
						hour
					)
				)
			)
			if not release_for_off_hours:
				continue
		if _manual_workplace_dispatches.has(employee_id):
			var manual_assignment: Dictionary = _workplace_assignments.get(
				employee_id,
				{}
			)
			var manual_building_type: String = str(
				manual_assignment.get("building_type_id", "")
			)
			if (
				manual_assignment.is_empty()
				or manual_building_type not in ["sound_stage", "editing_suite"]
			):
				_manual_workplace_dispatches.erase(employee_id)
			else:
				var manual_building_id: String = str(
					manual_assignment.get("building_id", "")
				)
				var current_manual_building_id: String = str(
					actor.call("get_workplace_building_id")
				)
				if (
					current_manual_building_id != manual_building_id
					or bool(actor.call("is_in_facility"))
					or bool(actor.call("is_leaving_workplace"))
				):
					dispatch_employee_to_workplace(employee_id)
				var at_manual_workplace: bool = bool(
					actor.call("is_at_workplace")
				)
				if manual_building_type == "sound_stage":
					employee.current_task = (
						"На площадке по вызову"
						if at_manual_workplace
						else "Идёт на площадку по вызову"
					)
				else:
					employee.current_task = (
						"Работает в монтажной"
						if at_manual_workplace
						else "Идёт в монтажную"
					)
				continue
		if str(employee.work_state) == "free_time":
			var free_time_facility_type: String = (
				_get_free_time_facility_type(employee, hour, day)
			)
			if not free_time_facility_type.is_empty():
				if bool(actor.call("is_in_facility")):
					var current_facility_type: String = str(
						actor.call("get_facility_type_id")
					)
					if current_facility_type == free_time_facility_type:
						var is_at_free_time_facility: bool = bool(
							actor.call(
								"is_at_facility",
								free_time_facility_type
							)
						)
						if free_time_facility_type == "fitness_center":
							employee.current_task = (
								"Тренируется в фитнес-центре"
								if is_at_free_time_facility
								else "Идёт на тренировку"
							)
						else:
							employee.current_task = (
								"Общается в клубе студии"
								if is_at_free_time_facility
								else "Идёт в клуб студии"
							)
						continue
					_release_employee_to_free_roam(actor)
					continue
				if _route_employee_to_facility(
					employee_id,
					free_time_facility_type
				):
					employee.current_task = (
						"Тренируется в фитнес-центре"
						if free_time_facility_type == "fitness_center"
						else "Общается в клубе студии"
					)
					continue
			_release_employee_to_free_roam(actor)
			employee.current_task = "Свободное время"
			continue
		if bool(actor.call("is_returning_to_workplace")):
			employee.current_task = "Возвращается на рабочее место"
			continue

		var target_facility_type: String = ""
		match str(employee.work_state):
			"break":
				target_facility_type = "cafeteria"
			"off_duty":
				if bool(actor.call("is_in_facility")):
					var off_duty_facility_type: String = str(
						actor.call("get_facility_type_id")
					)
					if off_duty_facility_type in [
						"staff_housing",
						"star_bungalow",
					]:
						target_facility_type = off_duty_facility_type
					else:
						_release_employee_to_free_roam(actor)
						employee.current_task = "Покидает зону отдыха"
						continue
				elif (
					str(employee.profession_id) == "actor"
					and float(employee.popularity)
						>= STAR_HOUSING_POPULARITY_THRESHOLD
					and not _get_facility_assignment(
						employee_id,
						"star_bungalow"
					).is_empty()
				):
					target_facility_type = "star_bungalow"
				else:
					target_facility_type = "staff_housing"

		if not target_facility_type.is_empty():
			if _route_employee_to_facility(
				employee_id,
				target_facility_type
			):
				var is_at_facility: bool = bool(
					actor.call(
						"is_at_facility",
						target_facility_type
					)
				)
				if target_facility_type == "cafeteria":
					employee.current_task = (
						"Обедает в столовой"
						if is_at_facility
						else "Идёт в столовую"
					)
				elif target_facility_type == "star_bungalow":
					employee.current_task = (
						"Отдыхает в отдельном домике"
						if is_at_facility
						else "Идёт в отдельный домик"
					)
				else:
					employee.current_task = (
						"Отдыхает в домике"
						if is_at_facility
						else "Идёт в домик персонала"
					)
				continue

		if bool(actor.call("is_in_facility")):
			if not bool(actor.call("is_at_facility")):
				employee.current_task = "Выходит из бытового помещения"
				continue
			var has_workplace_assignment: bool = not _workplace_assignments.get(
				employee_id,
				{}
			).is_empty()
			dispatch_employee_to_workplace(employee_id)
			employee.current_task = (
				"Возвращается на рабочее место"
				if has_workplace_assignment
				else "Покидает бытовое помещение"
			)
			continue

		var assignment: Dictionary = _workplace_assignments.get(
			employee_id,
			{}
		)
		if _should_leave_workplace(
			employee_id,
			str(employee.work_state),
			assignment.is_empty()
		):
			_leave_actor_from_workplace(actor)
			continue

		var building_id: String = str(assignment.get("building_id", ""))
		var current_building_id: String = str(
			actor.call("get_workplace_building_id")
		)
		if not _should_auto_dispatch_to_workplace(employee_id, assignment):
			if (
				not current_building_id.is_empty()
				and not bool(actor.call("is_leaving_workplace"))
			):
				_leave_actor_from_workplace(actor)
			if str(employee.work_state) == "working":
				employee.current_task = (
					"Ожидает вызова на съёмки"
					if str(assignment.get("building_type_id", "")) == "sound_stage"
					else "Ожидает фильм для монтажа"
				)
			continue
		if (
			current_building_id != building_id
			and is_instance_valid(_studio_building_manager)
		):
			if not current_building_id.is_empty():
				if not bool(actor.call("is_leaving_workplace")):
					_leave_actor_from_workplace(actor)
				continue
			if bool(actor.call("is_leaving_workplace")):
				continue
			var route: Array[Vector3] = _studio_building_manager.call(
				"get_workplace_path_from",
				building_id,
				int(assignment.get("slot_index", 0)),
				actor.global_position
			)
			if route.is_empty():
				continue
			var workplace_exit_route: Array[Vector3] = _studio_building_manager.call(
				"get_workplace_path",
				building_id,
				int(assignment.get("slot_index", 0))
			)
			if workplace_exit_route.is_empty():
				continue
			actor.call(
				"assign_workplace_route",
				building_id,
				route,
				str(employee.profession_id),
				workplace_exit_route,
				int(assignment.get("slot_index", 0))
			)

		var is_at_workplace: bool = bool(
			actor.call("is_at_workplace")
		)
		if _game_clock.is_manual_fast_forward:
			is_at_workplace = true

		if is_at_workplace and str(employee.work_state) == "working":
			_workplace_system.call(
				"advance_work_minute",
				employee,
				assignment
			)
		if (
			_employee_task_overrides.has(employee_id)
			and (
				str(employee.work_state) == "working"
				or _is_active_production_participant(employee_id)
			)
		):
			employee.current_task = str(
				_employee_task_overrides[employee_id]
			)

	_update_social_relationships()
	if not _game_clock.is_manual_fast_forward:
		_refresh_roster()
		_refresh_detail_panel()

func _on_game_day_advanced(day: int) -> void:
	for employee in employees:
		var became_older: bool = bool(
			_aging_system.call("advance_day", employee)
		)
		if became_older:
			var actor: Node = get_employee_actor(str(employee.id))
			if actor != null and actor.has_method("set_character_age"):
				actor.call("set_character_age", int(employee.age))

	var result: Dictionary = _employment_system.call("advance_day", day)
	var employees_expired: bool = false

	for expired_employee in result.get("expired_employees", []):
		var expired_id: String = str(expired_employee.id)
		_remove_employee_actor(expired_id)
		employees_expired = true
		if _selected_employee_id == expired_id:
			_selected_employee_id = ""

	if bool(result.get("market_refreshed", false)):
		if not _selected_market_candidate_id.is_empty():
			if _find_market_candidate(_selected_market_candidate_id) == null:
				_selected_market_candidate_id = ""
		_refresh_market_panel()

	_refresh_workplace_assignments()
	if employees_expired:
		employees_changed.emit()
	if not _game_clock.is_manual_fast_forward:
		_refresh_after_staffing_day()

func _refresh_after_staffing_day() -> void:
	if _selected_employee_id.is_empty() and _selected_market_candidate_id.is_empty():
		if not employees.is_empty():
			_select_employee(str(employees[0].id))
		else:
			_refresh_roster()
			_refresh_detail_panel()
	else:
		_refresh_roster()
		_refresh_detail_panel()

func _on_manual_advance_finished(_minutes_advanced: int) -> void:
	for employee in employees:
		var employee_id: String = str(employee.id)
		var actor: Variant = _employee_actors.get(employee_id)
		if actor == null or not is_instance_valid(actor):
			continue

		var is_off_camera: bool = _is_employee_off_camera(employee_id)
		var is_active_participant: bool = _is_active_production_participant(
			employee_id
		)
		var is_waiting_for_scene: bool = (
			is_active_participant
			and is_instance_valid(_studio_building_manager)
			and _studio_building_manager.has_method(
				"is_employee_waiting_for_scene"
			)
			and bool(
				_studio_building_manager.call(
					"is_employee_waiting_for_scene",
					employee_id
				)
			)
		)
		if is_off_camera:
			actor.call("snap_to_scene_hold_mark")
		elif is_waiting_for_scene:
			actor.call("snap_outside_workplace")
		elif bool(actor.call("is_in_scene_performance")):
			actor.call("snap_to_scene_mark")
		elif (
			bool(actor.call("is_returning_to_workplace"))
			or str(employee.work_state) == "working"
			or is_active_participant
		):
			actor.call("snap_to_workplace")
		else:
			actor.call("snap_outside_workplace")

	_refresh_market_panel()
	_refresh_after_staffing_day()

func _unhandled_input(event: InputEvent) -> void:
	var building_manager: Node = get_node_or_null("../StudioBuildingManager")
	if (
		is_instance_valid(building_manager)
		and bool(building_manager.call("is_placing_building"))
	):
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if try_select_employee_from_screen(mouse_event.position):
		get_viewport().set_input_as_handled()
	else:
		_select_employee("")

func _select_from_screen(screen_position: Vector2) -> void:
	if not try_select_employee_from_screen(screen_position):
		_select_employee("")

func try_select_employee_from_screen(screen_position: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var ray_end: Vector3 = ray_origin + ray_direction * 250.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 2)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var candidate: Node = hit.get("collider") as Node
	while candidate != null and not candidate.is_in_group("studio_employee"):
		candidate = candidate.get_parent()
	if candidate == null:
		return false
	var employee_id: String = str(candidate.call("get_character_id"))
	if employee_id.is_empty():
		return false
	_select_employee(employee_id)
	return true

func _select_employee(employee_id: String) -> void:
	var previous_actor: Variant = _employee_actors.get(_selected_employee_id)
	if previous_actor != null and is_instance_valid(previous_actor):
		previous_actor.call("set_selected", false)

	_selected_market_candidate_id = ""
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		_selected_employee_id = ""
	else:
		_selected_employee_id = str(employee.id)
		var selected_actor: Variant = _employee_actors.get(_selected_employee_id)
		if selected_actor != null and is_instance_valid(selected_actor):
			selected_actor.call("set_selected", true)

	_refresh_roster()
	_refresh_detail_panel()
	if _studio_hud != null:
		if employee == null:
			_studio_hud.call("show_inspector_panel", "employee", false)
		else:
			_studio_hud.call("show_workspace_panel", "employees")
			_studio_hud.call("show_inspector_panel", "employee", true)

func _select_market_candidate(candidate_id: String) -> void:
	var previous_actor: Variant = _employee_actors.get(_selected_employee_id)
	if previous_actor != null and is_instance_valid(previous_actor):
		previous_actor.call("set_selected", false)

	_selected_employee_id = ""
	var candidate: Variant = _find_market_candidate(candidate_id)
	_selected_market_candidate_id = (
		str(candidate.id) if candidate != null else ""
	)
	_refresh_roster()
	_refresh_detail_panel()
	if _studio_hud != null and candidate != null:
		_studio_hud.call("show_workspace_panel", "market")
		_studio_hud.call("show_inspector_panel", "employee", true)

func _on_market_candidate_pressed(candidate_id: String) -> void:
	_select_market_candidate(candidate_id)

func _find_market_candidate(candidate_id: String) -> Variant:
	for candidate in market_candidates:
		if str(candidate.id) == candidate_id:
			return candidate
	return null

func _find_employee(employee_id: String) -> Variant:
	for employee in employees:
		if str(employee.id) == employee_id:
			return employee
	return null

func _get_workplace_title(employee_id: String) -> String:
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	match str(assignment.get("building_type_id", "")):
		"script_department":
			return "Сценарный отдел"
		"sound_stage":
			return "Съёмочный павильон"
		"editing_suite":
			return "Монтажный отдел"
		_:
			return "Не назначено"

func _get_production_participant_status(employee_id: String) -> String:
	var actor: Node = get_employee_actor(employee_id)
	if actor == null:
		return "Съёмочная смена"
	if _is_employee_off_camera(employee_id):
		if (
			actor.has_method("is_at_scene_hold_mark")
			and bool(actor.call("is_at_scene_hold_mark"))
		):
			return "За кадром"
		return "Уходит за кадр"
	if (
		is_instance_valid(_studio_building_manager)
		and _studio_building_manager.has_method("is_employee_waiting_for_scene")
		and bool(
			_studio_building_manager.call(
				"is_employee_waiting_for_scene",
				employee_id
			)
		)
	):
		return "Свободное время до вызова"
	if bool(actor.call("is_in_scene_performance")):
		if bool(actor.call("is_at_scene_mark")):
			return "На съёмочной позиции"
		return "Занимает позицию"
	if bool(actor.call("is_returning_to_workplace")):
		return "Возвращается на площадку"
	if bool(actor.call("is_at_workplace")):
		return "На площадке"
	return "Направляется на площадку"

func _refresh_roster() -> void:
	if _employee_roster_view == null:
		return
	_employee_roster_view.call(
		"refresh_roster",
		employees,
		_selected_employee_id
	)

func _get_roster_work_state_title(employee: Variant) -> String:
	var employee_id: String = str(employee.id)
	if (
		_is_active_production_participant(employee_id)
		or _is_employee_off_camera(employee_id)
	):
		return _get_production_participant_status(employee_id)
	return employee.get_work_state_title()

func _refresh_detail_panel() -> void:
	if (
		_employee_profile_view == null
		or not bool(_employee_profile_view.call("is_built"))
	):
		return

	var is_market_candidate: bool = not _selected_market_candidate_id.is_empty()
	var employee: Variant = (
		_find_market_candidate(_selected_market_candidate_id)
		if is_market_candidate
		else _find_employee(_selected_employee_id)
	)
	if employee == null:
		_selected_market_candidate_id = ""
		_selected_employee_id = ""
		_employee_profile_view.call("clear")
		_clear_skill_progress_bars()
		return

	var needs: Dictionary = employee.needs
	var skills: Dictionary = employee.skills
	var personality: Dictionary = employee.personality
	var employee_role_title: String = employee.get_profession_title()
	var employee_specialization: String = employee.get_specialization_title()
	if not employee_specialization.is_empty():
		employee_role_title += " · " + employee_specialization
	var profession_line: String = "%s  ·  %s  ·  Возраст: %d" % [
		employee_role_title,
		employee.get_department_title(),
		employee.age,
	]
	var physical_fitness_line: String = (
		"\nФизическая форма: %.0f / 100" % employee.physical_fitness
		if str(employee.profession_id) == "actor"
		else ""
	)

	var stats_text: String
	var task_text: String
	var schedule_text: String
	var contract_text: String
	var show_contract_options: bool = false
	var show_hire_button: bool = false
	var show_dismiss_button: bool = false

	if is_market_candidate:
		stats_text = (
			"Опыт: %.1f лет\nПопулярность: %.0f / 100\nИзвестность: %.0f / 100%s\nОжидание: %d усл. ед. / день\nПотенциал развития: %.0f / %.0f очков\nЦель: %s"
			% [
				employee.experience,
				employee.popularity,
				employee.recognition,
				physical_fitness_line,
				employee.daily_salary,
				employee.growth_points_remaining,
				employee.growth_points_total,
				employee.career_goal,
			]
		)
		task_text = "СТАТУС: Кандидат открыт к предложениям"
		schedule_text = "График работы согласуется при найме."
		var contract_type: String = _get_selected_contract_type()
		var offer_salary: int = int(
			_employment_system.call(
				"get_offer_salary",
				str(employee.id),
				contract_type
			)
		)
		contract_text = (
			"ПРЕДЛАГАЕМЫЙ КОНТРАКТ\nТип: %s\nСтавка: %d усл. ед. / день"
			% [
				_get_contract_type_title(contract_type),
				offer_salary,
			]
		)
		show_contract_options = true
		show_hire_button = true
	else:
		stats_text = (
			"Опыт: %.1f лет\nПопулярность: %.0f / 100\nИзвестность: %.0f / 100%s\nОплата: %d усл. ед. / день\nРезерв развития: %.0f / %.0f очков\nЦель: %s"
			% [
				employee.experience,
				employee.popularity,
				employee.recognition,
				physical_fitness_line,
				employee.daily_salary,
				employee.growth_points_remaining,
				employee.growth_points_total,
				employee.career_goal,
			]
		)
		var workplace_title: String = _get_workplace_title(str(employee.id))
		var employee_work_state_title: String = (
			"На съёмках"
			if _is_active_production_participant(str(employee.id))
			else employee.get_work_state_title()
		)
		task_text = (
			"СЕЙЧАС: %s\nСтатус: %s\nРабочее место: %s"
			% [
				employee.current_task,
				employee_work_state_title,
				workplace_title,
			]
		)
		schedule_text = "Смена: %02d:00–%02d:00  ·  Перерыв: %02d:00–%02d:00" % [
			employee.shift_start_hour,
			employee.shift_end_hour,
			employee.break_start_hour,
			employee.break_end_hour,
		]
		var contract: Variant = _employment_system.call(
			"get_contract",
			str(employee.id)
		)
		if contract == null:
			contract_text = "КОНТРАКТ: данные отсутствуют"
		else:
			var end_text: String = (
				"Бессрочный"
				if int(contract.end_day) == 0
				else "до дня %d" % int(contract.end_day)
			)
			contract_text = (
				"ТРУДОВОЙ ДОГОВОР\n%s\nСтавка: %d усл. ед. / день\nНачало: день %d · %s"
				% [
					contract.get_type_title(),
					contract.daily_salary,
					contract.start_day,
					end_text,
				]
			)
		show_dismiss_button = true

	var energy: float = float(needs.get("energy", 1.0)) * 100.0
	var morale: float = float(needs.get("morale", 0.75)) * 100.0
	var stress: float = float(needs.get("stress", 0.1)) * 100.0
	var personality_text: String = (
		"Амбиции: %d%%\nОбщительность: %d%%\nДисциплина: %d%%\nКреативность: %d%%\n%s"
		% [
			roundi(float(personality.get("ambition", 0.5)) * 100.0),
			roundi(float(personality.get("sociability", 0.5)) * 100.0),
			roundi(float(personality.get("discipline", 0.5)) * 100.0),
			roundi(float(personality.get("creativity", 0.5)) * 100.0),
			_get_relationship_summary(employee),
		]
	)
	_employee_profile_view.call(
		"refresh",
		{
			"has_profile": true,
			"employee_id": str(employee.id),
			"is_employed": not is_market_candidate,
			"publicity_status": (
				str(_studio_building_manager.call("get_publicity_event_status"))
				if is_instance_valid(_studio_building_manager)
				and _studio_building_manager.has_method("get_publicity_event_status")
				else ""
			),
			"name": employee.get_full_name().to_upper(),
			"profession": profession_line,
			"biography": employee.biography,
			"stats": stats_text,
			"show_recognition": str(employee.profession_id) in ["actor", "director"],
			"recognition": float(employee.recognition),
			"task": task_text,
			"schedule": schedule_text,
			"contract": contract_text,
			"personality": personality_text,
			"needs": {
				"energy": energy,
				"morale": morale,
				"stress": stress,
			},
			"show_contract_type": show_contract_options,
			"show_hire_button": show_hire_button,
			"show_dismiss_button": show_dismiss_button,
		}
	)
	_refresh_skill_progress_bars(employee, skills)
	if not is_market_candidate:
		_refresh_workplace_dispatch_button(str(employee.id))
		_refresh_employee_workplace_options(str(employee.id))

func _clear_skill_progress_bars() -> void:
	_ensure_skill_progress_view()
	if _employee_skill_progress_view == null:
		return
	_employee_skill_progress_view.call("clear")

func _refresh_skill_progress_bars(
	employee: Variant,
	skills: Dictionary
) -> void:
	_ensure_skill_progress_view()
	if _employee_skill_progress_view == null:
		return
	_employee_skill_progress_view.call("refresh", employee, skills)

func _ensure_skill_progress_view() -> void:
	if _employee_skill_progress_view != null:
		return
	if not is_instance_valid(_detail_skills_container):
		return
	_employee_skill_progress_view = EMPLOYEE_SKILL_PROGRESS_VIEW_SCRIPT.new()
	_employee_skill_progress_view.call(
		"setup",
		_detail_skills_container,
		_skill_progression_system
	)

func _refresh_workplace_dispatch_button(employee_id: String) -> void:
	if _employee_profile_view == null:
		return
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	var building_type_id: String = str(
		assignment.get("building_type_id", "")
	)
	if (
		assignment.is_empty()
		or building_type_id not in ["sound_stage", "editing_suite"]
		or _is_active_production_participant(employee_id)
		or _is_active_editing_participant(employee_id)
	):
		_employee_profile_view.call("set_workplace_dispatch_state", false)
		return

	var is_manual: bool = _manual_workplace_dispatches.has(employee_id)
	var button_text: String
	if building_type_id == "sound_stage":
		button_text = (
			"ОТПУСТИТЬ С ПЛОЩАДКИ"
			if is_manual
			else "ВЫЗВАТЬ НА ПЛОЩАДКУ"
		)
	else:
		button_text = (
			"ОТПУСТИТЬ ИЗ МОНТАЖНОЙ"
			if is_manual
			else "ОТПРАВИТЬ В МОНТАЖНУЮ"
		)
	_employee_profile_view.call(
		"set_workplace_dispatch_state",
		true,
		button_text
	)

func _on_workplace_dispatch_button_pressed() -> void:
	var employee_id: String = _selected_employee_id
	if employee_id.is_empty():
		return
	if _manual_workplace_dispatches.has(employee_id):
		release_employee_from_workplace_manually(employee_id)
	elif not dispatch_employee_to_workplace_manually(employee_id):
		_show_employee_message(
			"Не удалось направить сотрудника на выбранное рабочее место."
		)
	_refresh_detail_panel()
	_refresh_roster()

func _on_contract_type_selected(_index: int) -> void:
	_refresh_detail_panel()

func _get_selected_contract_type() -> String:
	if _employee_profile_view == null:
		return "permanent"
	return str(_employee_profile_view.call("get_selected_contract_type"))

func _get_contract_type_title(contract_type: String) -> String:
	match contract_type:
		"fixed_30_days":
			return "Срочный · 30 дней"
		"fixed_90_days":
			return "Срочный · 90 дней"
		_:
			return "Бессрочный"

func _on_hire_button_pressed() -> void:
	if _selected_market_candidate_id.is_empty():
		return

	var result: Dictionary = _employment_system.call(
		"hire_candidate",
		_selected_market_candidate_id,
		_get_selected_contract_type(),
		int(_game_clock.current_day)
	)
	if not bool(result.get("success", false)):
		_show_employee_message(str(result.get("message", "Не удалось оформить найм.")))
		return

	var employee: Variant = result.get("employee")
	if employee == null:
		return

	_needs_system.call(
		"refresh_work_state", employee, int(_game_clock.current_hour)
	)
	_spawn_employee_actor(employee, employees.size() - 1)
	_add_roster_button(employee)
	_refresh_workplace_assignments()

	_selected_market_candidate_id = ""
	_refresh_market_panel()
	_select_employee(str(employee.id))
	_show_employee_message(str(result.get("message", "Сотрудник принят в штат.")))
	employees_changed.emit()

func _on_dismiss_button_pressed() -> void:
	if _employee_profile_view == null:
		return
	var employee: Variant = _find_employee(_selected_employee_id)
	if employee == null:
		return
	_employee_profile_view.call(
		"show_dismiss_confirmation",
		employee.get_full_name()
	)

func _confirm_dismiss_employee() -> void:
	var employee_id: String = _selected_employee_id
	if employee_id.is_empty():
		return

	var result: Dictionary = _employment_system.call(
		"dismiss_employee",
		employee_id,
		int(_game_clock.current_day)
	)
	if not bool(result.get("success", false)):
		_show_employee_message(str(result.get("message", "Не удалось уволить сотрудника.")))
		return

	_remove_employee_actor(employee_id)
	_refresh_workplace_assignments()
	_selected_employee_id = ""
	if not employees.is_empty():
		_select_employee(str(employees[0].id))
	else:
		_refresh_roster()
		_refresh_detail_panel()
	_show_employee_message(str(result.get("message", "Сотрудник уволен.")))
	employees_changed.emit()

func _show_employee_message(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Управление персоналом"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func get_employee_workplace_path(employee_id: String) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not is_instance_valid(_studio_building_manager):
		return result
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	if assignment.is_empty():
		return result
	var raw_path: Variant = _studio_building_manager.call(
		"get_workplace_path",
		str(assignment.get("building_id", "")),
		int(assignment.get("slot_index", 0))
	)
	if raw_path is Array:
		for point_value in raw_path:
			if point_value is Vector3:
				result.append(point_value)
	return result


