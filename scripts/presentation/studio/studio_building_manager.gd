extends Node3D
class_name StudioBuildingManager

const DEFAULT_FILM_SHIFT_START_HOUR: int = 8
const DEFAULT_FILM_SHIFT_END_HOUR: int = 17

signal buildings_changed

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const PLACEMENT_RULES_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_placement_rules.gd"
)
const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const SCRIPT_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/script_department/script_generator.gd"
)
const SCRIPT_WRITING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/script_department/script_writing_system.gd"
)
const FILM_PRODUCTION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_system.gd"
)
const SKILL_PROGRESSION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_skill_progression_system.gd"
)
const FILM_EDITING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_editing/film_editing_system.gd"
)
const FILM_EDITING_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/film_editing_controller.gd"
)
const FILM_PRODUCTION_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/film_production_controller.gd"
)
const FILM_CREW_CATALOG_SCRIPT = preload(
	"res://scripts/domain/film_production/film_crew_catalog.gd"
)
const REQUIRED_STAGE_PROFESSIONS = FILM_CREW_CATALOG_SCRIPT.REQUIRED_STAGE_PROFESSIONS
const FILM_CREW_ROLE_CONFIG = FILM_CREW_CATALOG_SCRIPT.FILM_CREW_ROLE_CONFIG
const FILM_TECHNICIAN_ROLE_IDS = FILM_CREW_CATALOG_SCRIPT.FILM_TECHNICIAN_ROLE_IDS
const MAX_BACKGROUND_PERFORMERS = FILM_CREW_CATALOG_SCRIPT.MAX_BACKGROUND_PERFORMERS
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)
const NAVIGATION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)
const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)
const SET_INVENTORY_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_inventory.gd"
)
const SET_LOGISTICS_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_set_logistics_controller.gd"
)
const BUILDING_PLACEMENT_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_placement_controller.gd"
)

const SCRIPT_DEPARTMENT_START_POSITION: Vector3 = Vector3(-16.0, 0.0, -16.0)
const SOUND_STAGE_START_POSITION: Vector3 = Vector3(0.0, 0.0, 0.0)
const PROP_WAREHOUSE_START_POSITION: Vector3 = Vector3(20.0, 0.0, 10.0)
var _game_clock: Node
var _character_manager: Node
var _script_writing_system: RefCounted
var _film_production_system: RefCounted
var _skill_progression_system: RefCounted
var _film_editing_system: RefCounted
var _navigation_system: RefCounted
var _set_inventory: Variant
var _decor_shop_group_id: String = ""
var _decor_shop_group_option: OptionButton
var _decor_shop_budget_label: Label
var _decor_shop_items: VBoxContainer
var _active_production_technician_ids: Array[String]:
	get:
		return _get_film_production_controller().call("get_active_production_technician_ids")
	set(value):
		_get_film_production_controller().call("set_active_production_technician_ids", value)
var _set_logistics_controller: RefCounted
var _film_editing_controller: RefCounted
var _film_production_controller: RefCounted
var _building_placement_controller: RefCounted

var _set_logistics_phase: String:
	get:
		return str(_get_set_logistics_controller().call("get_phase"))
	set(value):
		_get_set_logistics_controller().call("set_phase", value)

var _set_logistics_scene_key: String:
	get:
		return str(_get_set_logistics_controller().call("get_scene_key"))
	set(value):
		_get_set_logistics_controller().call("set_scene_key", value)

var _set_logistics_pending_prop_ids: Array[String]:
	get:
		return _get_set_logistics_controller().call("get_pending_prop_ids")
	set(value):
		_get_set_logistics_controller().call("set_pending_prop_ids", value)

var _set_logistics_worker_ids: Array[String]:
	get:
		return _get_set_logistics_controller().call("get_worker_ids")
	set(value):
		_get_set_logistics_controller().call("set_worker_ids", value)

var _set_logistics_worker_tasks: Dictionary:
	get:
		return _get_set_logistics_controller().call("get_worker_tasks")
	set(value):
		_get_set_logistics_controller().call("set_worker_tasks", value)

var _set_logistics_blocked: bool:
	get:
		return bool(_get_set_logistics_controller().call("is_blocked"))
	set(value):
		_get_set_logistics_controller().call("set_blocked", value)

var _active_writing_project: Variant
var _active_film_project: Variant:
	get:
		return _get_film_production_controller().call("get_active_project")
	set(value):
		_get_film_production_controller().call("set_active_project", value)

var _active_film_script: Variant:
	get:
		return _get_film_production_controller().call("get_active_script")
	set(value):
		_get_film_production_controller().call("set_active_script", value)

var _active_editing_project: Variant:
	get:
		return _get_film_editing_controller().call("get_active_project")
	set(value):
		_get_film_editing_controller().call("set_active_project", value)

var _film_editing_editor_id: String:
	get:
		return str(_get_film_editing_controller().call("get_editor_id"))
	set(value):
		_get_film_editing_controller().call("set_editor_id", value)

var _completed_film_archive: Array = []
var _buildings: Array = []
var _building_actors: Dictionary = {}
var _selected_building_id: String = ""
var _next_building_sequence: int = 1
var _next_script_sequence: int = 1
var _latest_script: Variant

var _building_detail_panel: PanelContainer
var _building_detail_layout: VBoxContainer

var _script_writer_option: OptionButton
var _script_genre_option: OptionButton
var _script_scene_count: SpinBox
var _script_role_count: SpinBox
var _script_generate_button: Button
var _script_progress_bar: ProgressBar
var _script_progress_label: Label
var _script_result_label: Label



func setup(game_clock: Node, character_manager: Node) -> void:
	_game_clock = game_clock
	_character_manager = character_manager
	_script_writing_system = SCRIPT_WRITING_SYSTEM_SCRIPT.new()
	_film_production_system = FILM_PRODUCTION_SYSTEM_SCRIPT.new()
	_skill_progression_system = SKILL_PROGRESSION_SYSTEM_SCRIPT.new()
	_film_editing_system = FILM_EDITING_SYSTEM_SCRIPT.new()
	_get_film_editing_controller()
	_navigation_system = NAVIGATION_SYSTEM_SCRIPT.new()
	_set_inventory = SET_INVENTORY_SCRIPT.new()
	_get_set_logistics_controller()
	_get_film_production_controller()
	_get_building_placement_controller()
	_game_clock.minute_advanced.connect(_on_game_minute_advanced)

	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if (
		studio_hud != null
		and studio_hud.has_signal("developer_funds_requested")
	):
		var funds_callback := Callable(
			self,
			"_on_developer_funds_requested"
		)
		if not studio_hud.is_connected(
			"developer_funds_requested",
			funds_callback
		):
			studio_hud.connect(
				"developer_funds_requested",
			funds_callback
			)
	if _character_manager.has_signal("facility_usage_changed"):
		var facility_callback := Callable(
			self,
			"_on_facility_usage_changed"
		)
		if not _character_manager.is_connected(
			"facility_usage_changed",
			facility_callback
		):
			_character_manager.connect(
				"facility_usage_changed",
				facility_callback
			)
	if _character_manager.has_signal("employees_changed"):
		var roster_callback: Callable = Callable(
			self,
			"_on_employee_roster_changed"
		)
		if not _character_manager.is_connected(
			"employees_changed",
			roster_callback
		):
			_character_manager.connect(
				"employees_changed",
			roster_callback
			)

	_spawn_initial_buildings()
	_build_ui()
	if studio_hud != null:
		studio_hud.call(
			"set_developer_funds_status",
			"Бюджет декораций: %d." % int(_set_inventory.budget)
		)
	_refresh_build_status()

func _get_set_logistics_controller() -> RefCounted:
	if _set_logistics_controller == null:
		_set_logistics_controller = SET_LOGISTICS_CONTROLLER_SCRIPT.new()
		_set_logistics_controller.call(
			"setup",
			self,
			_character_manager,
			_navigation_system,
			_set_inventory
		)
	return _set_logistics_controller


func _get_film_editing_controller() -> RefCounted:
	if _film_editing_controller == null:
		_film_editing_controller = FILM_EDITING_CONTROLLER_SCRIPT.new()
		_film_editing_controller.call(
			"setup",
			self,
			_character_manager,
			_film_editing_system,
			_game_clock
		)
	return _film_editing_controller


func _get_film_production_controller() -> RefCounted:
	if _film_production_controller == null:
		_film_production_controller = FILM_PRODUCTION_CONTROLLER_SCRIPT.new()
	_film_production_controller.call(
		"setup",
		self,
		_character_manager,
		_film_production_system,
		_skill_progression_system,
		_game_clock,
		_set_inventory
	)
	return _film_production_controller


func _get_building_placement_controller() -> RefCounted:
	if _building_placement_controller == null:
		_building_placement_controller = BUILDING_PLACEMENT_CONTROLLER_SCRIPT.new()
		_building_placement_controller.call("setup", self, _buildings)
		_building_placement_controller.connect(
			"building_placement_requested",
			Callable(self, "_on_building_placement_requested")
		)
	return _building_placement_controller


func _on_developer_funds_requested(amount: int) -> void:
	if _set_inventory == null:
		return
	if not bool(_set_inventory.call("add_funds", amount)):
		var studio_hud: Node = get_node_or_null("../StudioHUD")
		if studio_hud != null:
			studio_hud.call(
				"set_developer_funds_status",
				"Не удалось пополнить бюджет декораций."
			)
		return
	_refresh_decor_shop_panel()
	var hud: Node = get_node_or_null("../StudioHUD")
	if hud != null:
		hud.call(
			"set_developer_funds_status",
			"Добавлено %d. Бюджет декораций: %d."
			% [amount, int(_set_inventory.budget)]
		)


func _on_facility_usage_changed() -> void:
	var building: Variant = _find_building(_selected_building_id)
	if building == null:
		return
	if BUILDING_CATALOG_SCRIPT.get_facility_capacity(
		str(building.building_type_id)
	) > 0:
		_refresh_building_detail()


func _on_employee_roster_changed() -> void:
	if not _selected_building_id.is_empty():
		_refresh_building_detail()


func _process(_delta: float) -> void:
	_get_building_placement_controller().call("process")


func is_placing_building() -> bool:
	return bool(_get_building_placement_controller().call("is_placing_building"))


func get_buildings() -> Array:
	return _buildings.duplicate()


func get_workplace_path(
	building_id: String,
	slot_index: int
) -> Array[Vector3]:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return []
	var path: Array[Vector3] = actor.call(
		"get_workplace_path",
		slot_index
	)
	return path


func get_exit_path_from(
	building_id: String,
	start_world_position: Vector3,
	slot_index: int = -1
) -> Array[Vector3]:
	var actor: Variant = _building_actors.get(building_id)
	if (
		actor == null
		or not is_instance_valid(actor)
		or not actor.has_method("get_exit_path_from")
	):
		return []
	return actor.call(
		"get_exit_path_from",
		start_world_position,
		slot_index
	)


func get_roaming_route(
	start_position: Vector3,
	base_route: Array[Vector3]
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if _navigation_system == null or base_route.size() < 2:
		return result

	var obstacles: Array[Dictionary] = _get_building_navigation_obstacles()
	var route_start: Vector3 = start_position
	for building in _buildings:
		var footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
			str(building.building_type_id),
			float(building.rotation_degrees),
			int(building.stage_size_tier)
		)
		var inside_building: bool = (
			absf(start_position.x - building.position.x) <= footprint.x * 0.5
			and absf(start_position.z - building.position.z) <= footprint.y * 0.5
		)
		if not inside_building:
			continue
		var building_actor: Variant = _building_actors.get(str(building.id))
		if building_actor == null or not is_instance_valid(building_actor):
			return result
		var exit_path: Array[Vector3] = building_actor.call(
			"get_exit_path_from",
			start_position
		)
		if exit_path.is_empty():
			return result
		result.append_array(exit_path)
		route_start = exit_path.back()
		break

	if result.is_empty():
		result.append(route_start)

	var safe_waypoints: Array[Vector3] = []
	for waypoint in base_route:
		var safe_waypoint: Vector3 = _get_safe_roaming_waypoint(
			waypoint,
			obstacles
		)
		if _is_roaming_point_blocked(
			Vector2(safe_waypoint.x, safe_waypoint.z),
			obstacles,
			0.0
		):
			return []
		safe_waypoints.append(safe_waypoint)

	var current_position: Vector3 = route_start
	for waypoint_index in range(safe_waypoints.size() + 1):
		var target_position: Vector3 = safe_waypoints[
			posmod(waypoint_index, safe_waypoints.size())
		]
		if current_position.distance_to(target_position) <= 0.2:
			current_position = target_position
			continue

		var segment: Array[Vector3] = _navigation_system.call(
			"build_path",
			current_position,
			target_position,
			obstacles,
			0.75,
			Rect2(Vector2(-47.0, -47.0), Vector2(94.0, 94.0))
		)
		if segment.is_empty():
			return []
		for point in segment:
			if result.back().distance_to(point) > 0.2:
				result.append(point)
		current_position = target_position

	return result


func _get_safe_roaming_waypoint(
	waypoint: Vector3,
	obstacles: Array[Dictionary]
) -> Vector3:
	var candidate: Vector2 = Vector2(waypoint.x, waypoint.z)
	for _attempt in range(16):
		var blocking_obstacle: Dictionary = {}
		for obstacle in obstacles:
			var center: Vector2 = obstacle.get("center", Vector2.ZERO)
			var half_extents: Vector2 = obstacle.get(
				"half_extents",
				Vector2.ONE
			)
			var clearance: float = float(
				obstacle.get("clearance", 0.62)
			) + 0.9
			if (
				absf(candidate.x - center.x) <= half_extents.x + clearance
				and absf(candidate.y - center.y) <= half_extents.y + clearance
			):
				blocking_obstacle = obstacle
				break
		if blocking_obstacle.is_empty():
			break

		var center: Vector2 = blocking_obstacle.get("center", Vector2.ZERO)
		var half_extents: Vector2 = blocking_obstacle.get(
			"half_extents",
			Vector2.ONE
		)
		var clearance: float = float(
			blocking_obstacle.get("clearance", 0.62)
		) + 0.9
		var candidates: Array[Vector2] = [
			Vector2(center.x - half_extents.x - clearance, candidate.y),
			Vector2(center.x + half_extents.x + clearance, candidate.y),
			Vector2(candidate.x, center.y - half_extents.y - clearance),
			Vector2(candidate.x, center.y + half_extents.y + clearance),
		]
		var best_candidate: Vector2 = candidate
		var best_distance: float = INF
		for candidate_value in candidates:
			var bounded_candidate: Vector2 = Vector2(
				clampf(candidate_value.x, -46.0, 46.0),
				clampf(candidate_value.y, -46.0, 46.0)
			)
			if _is_roaming_point_blocked(
				bounded_candidate,
				obstacles,
				0.15
			):
				continue
			var distance: float = candidate.distance_squared_to(
				bounded_candidate
			)
			if distance < best_distance:
				best_distance = distance
				best_candidate = bounded_candidate
		if best_distance == INF:
			return waypoint
		candidate = best_candidate

	return Vector3(candidate.x, waypoint.y, candidate.y)


func _is_roaming_point_blocked(
	point: Vector2,
	obstacles: Array[Dictionary],
	extra_clearance: float
) -> bool:
	for obstacle in obstacles:
		var center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var half_extents: Vector2 = obstacle.get(
			"half_extents",
			Vector2.ONE
		)
		var clearance: float = float(
			obstacle.get("clearance", 0.62)
		) + extra_clearance
		if (
			absf(point.x - center.x) <= half_extents.x + clearance
			and absf(point.y - center.y) <= half_extents.y + clearance
		):
			return true
	return false


func get_workplace_path_from(
	building_id: String,
	slot_index: int,
	start_position: Vector3,
	source_building_id: String = "",
	source_slot_index: int = 0
) -> Array[Vector3]:
	var workplace_path: Array[Vector3] = get_workplace_path(
		building_id,
		slot_index
	)
	if workplace_path.is_empty():
		return []

	var path_start: Vector3 = start_position
	var source_exit_path: Array[Vector3] = []
	if not source_building_id.is_empty():
		var source_path: Array[Vector3] = get_workplace_path(
			source_building_id,
			source_slot_index
		)
		var source_actor: Variant = _building_actors.get(
			source_building_id
		)
		if (
			source_path.size() > 1
			and source_actor != null
			and is_instance_valid(source_actor)
		):
			var local_start: Vector3 = source_actor.to_local(start_position)
			var source_type_id: String = str(
				source_actor.building_data.building_type_id
			)
			var source_footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
				source_type_id,
				0.0,
				int(source_actor.building_data.stage_size_tier)
			)
			var is_inside_source: bool = (
				absf(local_start.x) <= source_footprint.x * 0.5 + 0.7
				and absf(local_start.z) <= source_footprint.y * 0.5 + 0.7
			)
			if is_inside_source:
				if source_actor.has_method("get_exit_path_from"):
					source_exit_path = source_actor.call(
						"get_exit_path_from",
						start_position,
						source_slot_index
					)
				if source_exit_path.is_empty():
					source_exit_path.append(start_position)
					if start_position.distance_to(source_path.back()) > 0.2:
						source_exit_path.append(source_path.back())
					for index in range(source_path.size() - 2, -1, -1):
						var exit_point: Vector3 = source_path[index]
						if (
							source_exit_path.is_empty()
							or source_exit_path.back().distance_to(exit_point) > 0.2
						):
							source_exit_path.append(exit_point)
				if not source_exit_path.is_empty():
					path_start = source_exit_path.back()

	var travel_path: Array[Vector3] = _navigation_system.call(
		"build_path",
		path_start,
		workplace_path[0],
		_get_building_navigation_obstacles(),
		0.75,
		Rect2(Vector2(-47.0, -47.0), Vector2(94.0, 94.0))
	)
	if travel_path.is_empty():
		return []

	var result: Array[Vector3] = []
	for point in source_exit_path:
		if result.is_empty() or result.back().distance_to(point) > 0.2:
			result.append(point)
	for point in travel_path:
		if result.is_empty() or result.back().distance_to(point) > 0.2:
			result.append(point)
	for index in range(1, workplace_path.size()):
		if result.is_empty() or result.back().distance_to(workplace_path[index]) > 0.2:
			result.append(workplace_path[index])
	return result


func get_facility_path_from(
	building_id: String,
	slot_index: int,
	start_position: Vector3,
	source_building_id: String = "",
	source_slot_index: int = 0
) -> Array[Vector3]:
	return get_workplace_path_from(
		building_id,
		slot_index,
		start_position,
		source_building_id,
		source_slot_index
	)

func get_total_facility_capacity(building_type_id: String) -> int:
	var total_capacity: int = 0
	for building in _buildings:
		if (
			str(building.building_type_id) == building_type_id
			and bool(building.is_operational)
		):
			total_capacity += BUILDING_CATALOG_SCRIPT.get_facility_capacity(
				building_type_id
			)
	return total_capacity

func _get_building_navigation_obstacles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in _buildings:
		var footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
			str(building.building_type_id),
			float(building.rotation_degrees),
			int(building.stage_size_tier)
		)
		result.append({
			"center": Vector2(building.position.x, building.position.z),
			"half_extents": Vector2(
				footprint.x * 0.5,
				footprint.y * 0.5
			),
			"clearance": 0.62,
		})
	return result


func get_building_navigation_obstacles() -> Array[Dictionary]:
	return _get_building_navigation_obstacles()


func get_workplace_facing_direction(
	building_id: String,
	slot_index: int
) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call("get_workplace_facing_direction", slot_index)


func get_workplace_position(building_id: String, slot_index: int) -> Vector3:
	var path: Array[Vector3] = get_workplace_path(building_id, slot_index)
	if path.is_empty():
		return Vector3.ZERO
	return path[path.size() - 1]

func get_scene_mark(
	building_id: String,
	slot_index: int,
	phase_id: String = "preparation",
	scene_index: int = 0
) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call(
		"get_scene_mark",
		slot_index,
		phase_id,
		scene_index
	)


func get_scene_path(
	building_id: String,
	start_position: Vector3,
	target_position: Vector3
) -> Array[Vector3]:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return []
	return actor.call(
		"get_scene_path",
		start_position,
		target_position
	)


func set_scene_set_dressing(
	building_id: String,
	setup: Dictionary,
	progress: float
) -> void:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return
	actor.call("set_scene_set_dressing", setup, progress)


func get_set_dressing_prop_count(building_id: String) -> int:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return 0
	return int(actor.call("get_set_dressing_prop_count"))


func get_set_dressing_mark(building_id: String, prop_index: int) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call("get_set_dressing_mark", prop_index)


func get_scene_hold_mark(building_id: String, slot_index: int) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call("get_scene_hold_mark", slot_index)


func get_scene_focus_point(building_id: String) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call("get_scene_focus_point")


func set_production_scene(
	building_id: String,
	scene_number: int,
	scene_title: String,
	phase_title: String
) -> void:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return
	actor.call(
		"set_production_scene",
		scene_number,
		scene_title,
		phase_title
	)


func set_stage_camera_target(
	building_id: String,
	target_position: Vector3,
	active: bool
) -> void:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return
	actor.call("set_camera_target", target_position, active)


func _unhandled_input(event: InputEvent) -> void:
	if is_placing_building():
		_get_building_placement_controller().call("handle_input", event)
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if (
		is_instance_valid(_character_manager)
		and _character_manager.has_method("try_select_employee_from_screen")
		and bool(_character_manager.call("try_select_employee_from_screen", mouse_event.position))
	):
		get_viewport().set_input_as_handled()
		return
	var building_actor: Node = _get_building_actor_at(mouse_event.position)
	if building_actor != null:
		_select_building(str(building_actor.call("get_building_id")))
		get_viewport().set_input_as_handled()
	elif not _selected_building_id.is_empty():
		_select_building("")


func _spawn_initial_buildings() -> void:
	_create_building(
		"script_department",
		SCRIPT_DEPARTMENT_START_POSITION,
		0.0,
		"Сценарный отдел",
		false
	)
	_create_building(
		"sound_stage",
		SOUND_STAGE_START_POSITION,
		0.0,
		"Съёмочный павильон №1",
		false
	)
	_create_building(
		"prop_warehouse",
		PROP_WAREHOUSE_START_POSITION,
		0.0,
		"Склад съёмочного реквизита",
		false
	)


func _create_building(
	building_type_id: String,
	world_position: Vector3,
	rotation_degrees: float,
	display_name: String = "",
	is_player_placed: bool = true,
	stage_size_tier: int = 2
) -> Variant:
	if not BUILDING_CATALOG_SCRIPT.has_building_type(building_type_id):
		return null
	var building_data: Variant = BUILDING_DATA_SCRIPT.new()
	building_data.id = "BLD-%04d" % _next_building_sequence
	building_data.building_type_id = building_type_id
	building_data.display_name = (
		display_name
		if not display_name.is_empty()
		else "%s %d" % [
			BUILDING_CATALOG_SCRIPT.get_title(building_type_id),
			_next_building_sequence,
		]
	)
	building_data.position = world_position
	building_data.rotation_degrees = fposmod(rotation_degrees, 360.0)
	building_data.stage_size_tier = (
		BUILDING_CATALOG_SCRIPT.get_stage_size_tier(stage_size_tier)
		if BUILDING_CATALOG_SCRIPT.is_sound_stage(building_type_id)
		else 2
	)
	_next_building_sequence += 1
	_buildings.append(building_data)
	var actor: Variant = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", building_data)
	add_child(actor)
	_building_actors[building_data.id] = actor
	if building_type_id == "prop_warehouse":
		actor.call(
			"set_warehouse_inventory",
			_set_inventory.call("get_props_in_warehouse")
		)
	if is_player_placed:
		_refresh_build_status()
		buildings_changed.emit()
		if is_instance_valid(_character_manager):
			if _character_manager.has_method("refresh_navigation_routes"):
				_character_manager.call("refresh_navigation_routes")
			if _character_manager.has_method("refresh_workplace_assignments"):
				_character_manager.call("refresh_workplace_assignments")
	return building_data


func _build_ui() -> void:
	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if studio_hud == null:
		push_error("StudioBuildingManager: StudioHUD node is missing.")
		return
	var build_panel: PanelContainer = _get_building_placement_controller().call(
		"build_palette"
	)
	studio_hud.call(
		"register_workspace_panel",
		"studio",
		"Студия",
		build_panel
	)
	_build_building_detail_panel()
	_build_decor_shop_panel(studio_hud)


func _build_building_detail_panel() -> void:
	_building_detail_panel = PanelContainer.new()
	_building_detail_panel.name = "BuildingDetailPanel"
	_building_detail_panel.custom_minimum_size = Vector2(0.0, 0.0)
	_building_detail_panel.visible = false
	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if studio_hud == null:
		push_error("StudioBuildingManager: StudioHUD node is missing.")
		return
	studio_hud.call(
		"register_inspector_panel",
		"building",
		"Выбранное здание",
		_building_detail_panel
	)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 0.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	studio_hud.call("configure_scroll_container", scroll)
	_building_detail_panel.add_child(scroll)

	_building_detail_layout = VBoxContainer.new()
	_building_detail_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_detail_layout.add_theme_constant_override("separation", 9)
	scroll.add_child(_building_detail_layout)


func _refresh_build_status() -> void:
	_get_building_placement_controller().call(
		"refresh_build_status",
		_buildings.size()
	)


func _begin_placement(building_type_id: String) -> void:
	if is_instance_valid(_building_detail_panel):
		_building_detail_panel.visible = false
	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if studio_hud != null:
		studio_hud.call("show_inspector_panel", "building", false)
	_get_building_placement_controller().call(
		"begin_placement",
		building_type_id
	)


func _on_building_placement_requested(
	building_type_id: String,
	world_position: Vector3,
	rotation_degrees: float,
	stage_size_tier: int
) -> void:
	var display_name: String = "%s %d" % [
		BUILDING_CATALOG_SCRIPT.get_title(building_type_id),
		_next_building_sequence,
	]
	var building: Variant = _create_building(
		building_type_id,
		world_position,
		rotation_degrees,
		display_name,
		true,
		stage_size_tier
	)
	if building == null:
		return
	_select_building(str(building.id))
	_get_building_placement_controller().call(
		"set_placement_message",
		"Здание размещено. Можно построить ещё одно."
	)


func _get_building_actor_at(screen_position: Vector2) -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var ray_end: Vector3 = ray_origin + ray_direction * 300.0
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		4
	)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var candidate: Node = hit.get("collider") as Node
	while candidate != null and not candidate.is_in_group("studio_building"):
		candidate = candidate.get_parent()
	return candidate


func _select_building(building_id: String) -> void:
	var previous_actor: Variant = _building_actors.get(_selected_building_id)
	if previous_actor != null and is_instance_valid(previous_actor):
		previous_actor.call("set_selected", false)

	var building: Variant = _find_building(building_id)
	_selected_building_id = str(building.id) if building != null else ""
	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if building == null:
		_building_detail_panel.visible = false
		if studio_hud != null:
			studio_hud.call("show_inspector_panel", "building", false)
		return

	if studio_hud != null:
		studio_hud.call("show_workspace_panel", "studio")
	var actor: Variant = _building_actors.get(_selected_building_id)
	if actor != null and is_instance_valid(actor):
		actor.call("set_selected", true)
	_refresh_building_detail()
	if studio_hud != null:
		studio_hud.call("show_inspector_panel", "building", true)


func _find_building(building_id: String) -> Variant:
	for building in _buildings:
		if str(building.id) == building_id:
			return building
	return null


func get_building_by_id(building_id: String) -> Variant:
	return _find_building(building_id)


func get_assigned_staff_for_building(building_id: String) -> Array:
	return _get_assigned_staff(building_id)


func refresh_film_production_ui() -> void:
	_update_film_production_ui()


func refresh_building_detail() -> void:
	_refresh_building_detail()


func on_film_editing_completed() -> void:
	_update_film_production_ui()
	var selected_building: Variant = _find_building(_selected_building_id)
	if (
		selected_building != null
		and str(selected_building.building_type_id) == "editing_suite"
	):
		_refresh_building_detail()


func _refresh_building_detail() -> void:
	if not is_instance_valid(_building_detail_layout):
		return
	var building: Variant = _find_building(_selected_building_id)
	if building == null:
		_building_detail_panel.visible = false
		var studio_hud: Node = get_node_or_null("../StudioHUD")
		if studio_hud != null:
			studio_hud.call("show_inspector_panel", "building", false)
		return
	for child in _building_detail_layout.get_children():
		_building_detail_layout.remove_child(child)
		child.queue_free()
	_building_detail_panel.visible = true
	var building_type_id: String = str(building.building_type_id)
	var is_facility: bool = (
		BUILDING_CATALOG_SCRIPT.get_facility_capacity(building_type_id) > 0
	)
	var title := Label.new()
	title.text = str(building.display_name).to_upper()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.78, 0.94, 0.88, 1.0))
	_building_detail_layout.add_child(title)
	var description := Label.new()
	description.text = BUILDING_CATALOG_SCRIPT.get_description(building_type_id)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.62, 0.77, 0.79, 1.0))
	_building_detail_layout.add_child(description)
	var footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
		building_type_id,
		float(building.rotation_degrees),
		int(building.stage_size_tier)
	)
	var capacity: int = (
		BUILDING_CATALOG_SCRIPT.get_facility_capacity(building_type_id)
		if is_facility
		else BUILDING_CATALOG_SCRIPT.get_workplace_capacity_for_building(building)
	)
	if BUILDING_CATALOG_SCRIPT.is_sound_stage(building_type_id):
		var stage_note := Label.new()
		var stage_architecture_title: String = ""
		match BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
			int(building.stage_size_tier)
		):
			1:
				stage_architecture_title = "одноэтажная студия с двускатной крышей"
			3:
				stage_architecture_title = "высокий производственный ангар с фермами"
			_:
				stage_architecture_title = "классический прямоугольный павильон"
		stage_note.text = "%s · %s · рабочих мест: %d" % [
			BUILDING_CATALOG_SCRIPT.get_stage_size_title(
				int(building.stage_size_tier)
			),
			stage_architecture_title,
			capacity,
		]
		stage_note.add_theme_font_size_override("font_size", 11)
		stage_note.add_theme_color_override("font_color", Color(0.62, 0.82, 0.78, 1.0))
		_building_detail_layout.add_child(stage_note)
	var eligible_staff: Array = [] if is_facility else _get_eligible_staff(building_type_id)
	var assigned_staff: Array = (
		_character_manager.call("get_employees_using_facility", str(building.id))
		if is_facility
		else _get_assigned_staff(str(building.id))
	)
	var assigned_names: Array[String] = []
	for employee in assigned_staff:
		assigned_names.append("%s · %s" % [
			employee.get_full_name(),
			_get_profession_title(str(employee.profession_id)),
		])
	var stats_grid := GridContainer.new()
	stats_grid.columns = 3
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 6)
	stats_grid.add_theme_constant_override("v_separation", 6)
	_building_detail_layout.add_child(stats_grid)
	stats_grid.add_child(_create_building_stat_card(
		"МЕСТА" if is_facility else "РАБОЧИЕ МЕСТА",
		str(capacity),
		Color(0.50, 0.86, 0.73, 1.0)
	))
	stats_grid.add_child(_create_building_stat_card(
		"ЗАНЯТО" if is_facility else "НАЗНАЧЕНО",
		"%d / %d" % [assigned_staff.size(), capacity],
		Color(0.50, 0.78, 0.90, 1.0)
	))
	stats_grid.add_child(_create_building_stat_card(
		"УЧАСТОК",
		"%.0f × %.0f м" % [footprint.x, footprint.y],
		Color(0.72, 0.87, 0.84, 1.0)
	))
	var crew_heading := Label.new()
	crew_heading.text = (
		"ПЕРСОНАЛ В ЗДАНИИ · %d" % assigned_staff.size()
		if is_facility
		else "КОМАНДА · %d" % assigned_staff.size()
	)
	crew_heading.add_theme_font_size_override("font_size", 11)
	crew_heading.add_theme_color_override("font_color", Color(0.50, 0.82, 0.74, 1.0))
	_building_detail_layout.add_child(crew_heading)
	var staff_summary := Label.new()
	staff_summary.text = (
		"\n".join(assigned_names)
		if not assigned_names.is_empty()
		else ("Сейчас здесь никого нет." if is_facility else "Пока никто не назначен.")
	)
	staff_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(staff_summary)
	if is_facility:
		var facility_note := Label.new()
		facility_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		facility_note.add_theme_font_size_override("font_size", 11)
		facility_note.add_theme_color_override("font_color", Color(0.60, 0.80, 0.78, 1.0))
		match building_type_id:
			"cafeteria":
				facility_note.text = (
					"Сотрудники приходят сюда в свой обеденный перерыв. "
					+ "Во время еды энергия восстанавливается быстрее, а стресс снижается."
				)
			"star_bungalow":
				facility_note.text = (
					"Отдельный домик доступен одному популярному актёру. "
					+ "Сон здесь восстанавливает энергию и снижает стресс быстрее."
				)
			"fitness_center":
				facility_note.text = (
					"Актёры посещают зал с 17:00 до 19:00. "
					+ "Тренировки постепенно повышают физическую форму, "
					+ "но расходуют энергию. Одновременно тренируются до четырёх человек."
				)
			"studio_lounge":
				facility_note.text = (
					"Сотрудники приходят сюда с 19:00 до 21:00. "
					+ "Общение снижает стресс, улучшает настроение и укрепляет "
					+ "взаимоотношения между присутствующими."
				)
			_:
				facility_note.text = (
					"После окончания смены сотрудники занимают свободные спальные места. "
					+ "Сон ускоряет восстановление энергии и снижает стресс."
				)
		_building_detail_layout.add_child(facility_note)
		_apply_inspector_width_constraints(_building_detail_layout)
		return
	var eligible_summary := Label.new()
	eligible_summary.text = "Ещё подходят по профессии: %d" % eligible_staff.size()
	eligible_summary.add_theme_font_size_override("font_size", 10)
	eligible_summary.add_theme_color_override("font_color", Color(0.58, 0.76, 0.79, 1.0))
	_building_detail_layout.add_child(eligible_summary)
	if building_type_id == "script_department":
		_build_script_department_detail(assigned_staff)
	elif building_type_id == "sound_stage":
		_build_sound_stage_detail(assigned_staff)
	elif building_type_id == "tv_studio":
		_build_tv_studio_detail(eligible_staff)
	elif building_type_id == "editing_suite":
		_build_film_editing_detail(assigned_staff)
	_apply_inspector_width_constraints(_building_detail_layout)


func _apply_inspector_width_constraints(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.custom_minimum_size.x = 0.0
		elif child is OptionButton:
			_configure_compact_option_button(child as OptionButton)
		elif child is SpinBox:
			var spin_box := child as SpinBox
			spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin_box.custom_minimum_size.x = 0.0
		elif child is Container:
			var container := child as Container
			container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_inspector_width_constraints(child)


func _create_building_stat_card(
	caption: String,
	value: String,
	value_color: Color
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.15, 0.17, 1.0)
	style.border_color = Color(0.16, 0.36, 0.38, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	card.add_child(content)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", 9)
	caption_label.add_theme_color_override(
		"font_color",
		Color(0.60, 0.77, 0.78, 1.0)
	)
	content.add_child(caption_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", value_color)
	content.add_child(value_label)
	return card


func _configure_compact_option_button(option: OptionButton) -> void:
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(0.0, 0.0)
	option.fit_to_longest_item = false


func _build_script_department_detail(eligible_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "СОЗДАНИЕ СЦЕНАРИЯ"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.48, 0.82, 0.72, 1.0))
	_building_detail_layout.add_child(heading)

	var writer_heading := Label.new()
	writer_heading.text = "Сценарист"
	_building_detail_layout.add_child(writer_heading)

	_script_writer_option = OptionButton.new()
	var writer_count: int = 0
	for employee in eligible_staff:
		if str(employee.profession_id) != "screenwriter":
			continue
		_script_writer_option.add_item(
			"%s · %d/100" % [
				employee.get_full_name(),
				roundi(float(employee.skills.get("writing", 0.0))),
			]
		)
		_script_writer_option.set_item_metadata(
			_script_writer_option.get_item_count() - 1,
			str(employee.id)
		)
		writer_count += 1
	if writer_count == 0:
		_script_writer_option.add_item("Нет сценариста в штате")
		_script_writer_option.disabled = true
	else:
		_script_writer_option.select(0)
	_building_detail_layout.add_child(_script_writer_option)

	var genre_heading := Label.new()
	genre_heading.text = "Жанр"
	_building_detail_layout.add_child(genre_heading)

	_script_genre_option = OptionButton.new()
	for genre_id in SCRIPT_GENERATOR_SCRIPT.get_genre_ids():
		_script_genre_option.add_item(
			SCRIPT_GENERATOR_SCRIPT.get_genre_title(genre_id)
		)
		_script_genre_option.set_item_metadata(
			_script_genre_option.get_item_count() - 1,
			genre_id
		)
	_script_genre_option.select(0)
	_building_detail_layout.add_child(_script_genre_option)

	var parameters_row := HBoxContainer.new()
	_building_detail_layout.add_child(parameters_row)

	var scenes_column := VBoxContainer.new()
	scenes_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parameters_row.add_child(scenes_column)
	var scenes_label := Label.new()
	scenes_label.text = "Сцен"
	scenes_column.add_child(scenes_label)
	_script_scene_count = SpinBox.new()
	_script_scene_count.min_value = 3
	_script_scene_count.max_value = 20
	_script_scene_count.step = 1
	_script_scene_count.value = 8
	_script_scene_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_scene_count.custom_minimum_size = Vector2(0.0, 0.0)
	scenes_column.add_child(_script_scene_count)

	var roles_column := VBoxContainer.new()
	roles_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parameters_row.add_child(roles_column)
	var roles_label := Label.new()
	roles_label.text = "Ролей"
	roles_column.add_child(roles_label)
	_script_role_count = SpinBox.new()
	_script_role_count.min_value = 1
	_script_role_count.max_value = 8
	_script_role_count.step = 1
	_script_role_count.value = 3
	_script_role_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_role_count.custom_minimum_size = Vector2(0.0, 0.0)
	roles_column.add_child(_script_role_count)

	_script_generate_button = Button.new()
	_script_generate_button.text = "НАЧАТЬ НАПИСАНИЕ"
	_script_generate_button.disabled = writer_count == 0
	_script_generate_button.pressed.connect(_on_generate_script_pressed)
	_building_detail_layout.add_child(_script_generate_button)

	_script_progress_bar = ProgressBar.new()
	_script_progress_bar.min_value = 0.0
	_script_progress_bar.max_value = 100.0
	_script_progress_bar.show_percentage = true
	_script_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_detail_layout.add_child(_script_progress_bar)

	_script_progress_label = Label.new()
	_script_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_progress_label.add_theme_font_size_override("font_size", 11)
	_building_detail_layout.add_child(_script_progress_label)

	var generation_note := Label.new()
	generation_note.text = (
		"Написание занимает игровое время. Количество сцен, ролей, навыки "
		+ "и надёжность сценариста влияют на срок. Возможны звонки и творческие паузы. "
		+ "Итоговый рейтинг зависит от навыков и жанра, но не гарантирует кассовый успех."
	)
	generation_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	generation_note.add_theme_font_size_override("font_size", 10)
	_building_detail_layout.add_child(generation_note)

	_script_result_label = Label.new()
	_script_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_result_label.custom_minimum_size = Vector2(0.0, 120.0)
	_building_detail_layout.add_child(_script_result_label)
	_update_script_writing_ui()


func _on_generate_script_pressed() -> void:
	if not is_instance_valid(_script_writer_option):
		return
	if _script_writer_option.disabled or _script_writer_option.selected < 0:
		return
	if (
		_active_writing_project != null
		and str(_active_writing_project.status) == "in_progress"
	):
		return

	var writer_id: String = str(
		_script_writer_option.get_item_metadata(
			_script_writer_option.selected
		)
	)
	var writer: Variant = _find_employee(writer_id)
	if writer == null:
		_show_script_generation_error(
			"Выбранный сценарист больше не работает в студии."
		)
		return

	var genre_id: String = str(
		_script_genre_option.get_item_metadata(
			_script_genre_option.selected
		)
	)
	var script_id: String = "SCR-%04d" % _next_script_sequence
	var project_id: String = "WRK-%04d" % _next_script_sequence
	var seed: int = (
		int(_game_clock.current_day) * 100000
		+ int(_game_clock.current_hour) * 1000
		+ int(_game_clock.current_minute) * 10
		+ _next_script_sequence
	)
	_next_script_sequence += 1

	_active_writing_project = _script_writing_system.call(
		"start_project",
		writer,
		genre_id,
		roundi(_script_scene_count.value),
		roundi(_script_role_count.value),
		seed,
		project_id,
		script_id,
		int(_game_clock.current_day),
		int(_game_clock.current_hour),
		int(_game_clock.current_minute)
	)
	if _active_writing_project == null:
		_show_script_generation_error(
			"Не удалось начать работу. Проверьте профессию выбранного сотрудника."
		)
		return

	_update_script_writing_ui()


func _on_game_minute_advanced(_day: int, hour: int, _minute: int) -> void:
	if (
		_active_writing_project != null
		and str(_active_writing_project.status) == "in_progress"
	):
		var writer_id: String = str(_active_writing_project.writer_id)
		var writer: Variant = _find_employee(writer_id)
		var at_workplace: bool = false
		if writer != null and is_instance_valid(_character_manager):
			at_workplace = bool(_character_manager.call("is_employee_at_workplace", writer_id, "script_department"))
		var result: Dictionary = _script_writing_system.call(
			"advance_minute",
			_active_writing_project,
			writer,
			at_workplace
		)
		if bool(result.get("completed", false)):
			_latest_script = result.get("script")
		elif bool(result.get("failed", false)):
			_show_script_generation_error(str(_active_writing_project.last_activity_message))
		_update_script_writing_ui()
	_advance_film_production(hour)
	_advance_film_editing()


func get_latest_script() -> Variant:
	return _latest_script


func get_active_writing_project() -> Variant:
	return _active_writing_project


func get_next_script_sequence() -> int:
	return _next_script_sequence


func increment_script_sequence() -> void:
	_next_script_sequence += 1


func archive_completed_film_chain() -> void:
	if (
		_active_film_project != null
		and _active_editing_project != null
		and str(_active_editing_project.status) == "completed"
	):
		_completed_film_archive.append({
			"production": _active_film_project.to_dict(),
			"editing": _active_editing_project.to_dict(),
		})


func reset_active_film_editing() -> void:
	_active_editing_project = null
	_film_editing_editor_id = ""


func _update_script_writing_ui() -> void:
	if not is_instance_valid(_script_progress_bar):
		return
	if not is_instance_valid(_script_progress_label):
		return
	if not is_instance_valid(_script_result_label):
		return

	if _active_writing_project == null:
		_script_progress_bar.value = 0.0
		_script_progress_label.text = "Сценарий ещё не заказан."
		_script_result_label.text = _format_script_summary(_latest_script)
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "НАЧАТЬ НАПИСАНИЕ СЦЕНАРИЯ"
			_script_generate_button.disabled = (
				not is_instance_valid(_script_writer_option)
				or _script_writer_option.disabled
			)
		return

	var project: Variant = _active_writing_project
	_script_progress_bar.value = float(project.get_progress_percent())
	var remaining_minutes: int = int(project.get_remaining_work_minutes())
	var remaining_hours: float = float(remaining_minutes) / 60.0
	var remaining_shifts: int = ceili(float(remaining_minutes) / 480.0)
	var progress_text: String = (
		"Рабочее время: %d / %d минут · осталось около %.1f ч (%d смен)"
		% [
			int(project.completed_work_minutes),
			int(project.required_work_minutes),
			remaining_hours,
			remaining_shifts,
		]
	)
	var interruption_text: String = (
		"Прерываний за проект: %d" % int(project.interruption_count)
	)

	if str(project.status) == "in_progress":
		_script_progress_label.text = (
			"%s\n%s\n%s"
			% [
				str(project.last_activity_message),
				progress_text,
				interruption_text,
			]
		)
		_script_result_label.text = (
			"Сценарист: %s\nЖанр: %s · %d сцен · %d ролей\n"
			+ "Сценарий пока находится в разработке."
		) % [
			str(project.writer_name),
			SCRIPT_GENERATOR_SCRIPT.get_genre_title(str(project.genre_id)),
			int(project.scene_count),
			int(project.role_count),
		]
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "СЦЕНАРИЙ В РАБОТЕ"
			_script_generate_button.disabled = true
		if is_instance_valid(_script_writer_option):
			_script_writer_option.disabled = true
		if is_instance_valid(_script_genre_option):
			_script_genre_option.disabled = true
		if is_instance_valid(_script_scene_count):
			_script_scene_count.editable = false
		if is_instance_valid(_script_role_count):
			_script_role_count.editable = false
	elif str(project.status) == "completed":
		_script_progress_label.text = (
			"Сценарий завершён.\n%s\n%s"
			% [progress_text, interruption_text]
		)
		_script_result_label.text = _format_script_summary(_latest_script)
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "НАЧАТЬ НОВЫЙ СЦЕНАРИЙ"
			_script_generate_button.disabled = (
				not is_instance_valid(_script_writer_option)
				or _script_writer_option.get_item_count() == 0
			)
		if is_instance_valid(_script_writer_option):
			_script_writer_option.disabled = false
		if is_instance_valid(_script_genre_option):
			_script_genre_option.disabled = false
		if is_instance_valid(_script_scene_count):
			_script_scene_count.editable = true
		if is_instance_valid(_script_role_count):
			_script_role_count.editable = true
	else:
		_script_progress_label.text = str(project.last_activity_message)
		_script_result_label.text = "Проект сценария остановлен."
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "НАЧАТЬ НОВЫЙ СЦЕНАРИЙ"
			_script_generate_button.disabled = (
				not is_instance_valid(_script_writer_option)
				or _script_writer_option.get_item_count() == 0
			)
		if is_instance_valid(_script_writer_option):
			_script_writer_option.disabled = false
		if is_instance_valid(_script_genre_option):
			_script_genre_option.disabled = false
		if is_instance_valid(_script_scene_count):
			_script_scene_count.editable = true
		if is_instance_valid(_script_role_count):
			_script_role_count.editable = true


func _show_script_generation_error(message: String) -> void:
	if is_instance_valid(_script_result_label):
		_script_result_label.text = message


func _format_script_summary(script: Variant) -> String:
	if script == null:
		return "Сценарии ещё не создавались."

	var lines: Array[String] = [
		"ПОСЛЕДНИЙ СЦЕНАРИЙ",
		str(script.title),
		"%s  ·  %d сцен  ·  %d ролей" % [
			str(script.genre_title),
			int(script.scene_count),
			int(script.role_count),
		],
		"Потенциал: %s  (%d/100)" % [
			_format_stars(int(script.potential_stars)),
			int(script.potential_score),
		],
		"Коэффициент потенциала популярности: ×%.2f" % float(
			script.popularity_modifier
		),
		"Сценарист: %s" % str(script.writer_name),
		str(script.logline),
		"Персонажи:",
	]
	for cast_member in script.cast:
		lines.append(
			"• %s — %s" % [
				str(cast_member.get("role_title", "Роль")),
				str(cast_member.get("character_name", "Персонаж")),
			]
		)
	lines.append("ПЛАН СЦЕН")
	for scene in script.scenes:
		lines.append(
			"%02d. %s · %s" % [
				int(scene.get("scene_number", 0)),
				str(scene.get("beat", "")),
				str(scene.get("location", "")),
			]
		)
		lines.append("   %s" % str(scene.get("action", "")))
		lines.append("   %s" % str(scene.get("dialogue", "")))
	return "\n".join(lines)


func _format_stars(star_count: int) -> String:
	var result: String = ""
	for index in range(5):
		result += "★" if index < star_count else "☆"
	return result


func _build_tv_studio_detail(eligible_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "ТЕЛЕВИЗИОННОЕ ПРОИЗВОДСТВО"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override(
		"font_color",
		Color(0.40, 0.78, 0.91, 1.0)
	)
	_building_detail_layout.add_child(heading)

	var description := Label.new()
	description.text = (
		"Павильон предназначен для многокамерной записи сериалов и ток-шоу. "
		+ "Ведущие, актёры и съёмочная группа вызываются сюда по телевизионному "
		+ "расписанию и не занимают постоянные рабочие места в здании."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(description)

	var eligible_label := Label.new()
	eligible_label.text = (
		"Потенциальный пул специалистов: %d сотрудников"
		% eligible_staff.size()
	)
	eligible_label.add_theme_font_size_override("font_size", 11)
	eligible_label.add_theme_color_override(
		"font_color",
		Color(0.60, 0.82, 0.87, 1.0)
	)
	_building_detail_layout.add_child(eligible_label)

	var workflow_label := Label.new()
	workflow_label.text = (
		"Съёмочный цикл: подготовка площадки → репетиция → запись → "
		+ "постпродакшен → эфир. Конфликты занятости с кинопроизводством "
		+ "проверяются перед началом телевизионного эпизода."
	)
	workflow_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workflow_label.add_theme_font_size_override("font_size", 11)
	_building_detail_layout.add_child(workflow_label)


func _build_sound_stage_detail(assigned_staff: Array) -> void:
	_get_film_production_controller().call(
		"build_detail",
		_building_detail_layout,
		assigned_staff
	)

func _build_decor_shop_panel(studio_hud: Node) -> void:
	var panel := PanelContainer.new()
	panel.name = "DecorShopPanel"
	studio_hud.call(
		"register_workspace_panel",
		"decor_shop",
		"Магазин декораций",
		panel
	)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	studio_hud.call("configure_scroll_container", scroll)
	panel.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 9)
	scroll.add_child(layout)

	var heading := Label.new()
	heading.text = "МАГАЗИН ДЕКОРАЦИЙ"
	heading.add_theme_font_size_override("font_size", 15)
	layout.add_child(heading)

	var description := Label.new()
	description.text = (
		"Покупай элементы для разных типов сцен. "
		+ "Техники забирают их со склада, устанавливают в павильоне и возвращают после съёмки."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)

	_decor_shop_budget_label = Label.new()
	_decor_shop_budget_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_decor_shop_budget_label)

	_decor_shop_group_option = OptionButton.new()
	_decor_shop_group_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_decor_shop_group_option)
	var group_ids: Array[String] = SET_CATALOG_SCRIPT.get_group_ids()
	for group_id in group_ids:
		_decor_shop_group_option.add_item(
			SET_CATALOG_SCRIPT.get_group_title(group_id)
		)
	if not group_ids.is_empty():
		_decor_shop_group_id = group_ids[0]
		_decor_shop_group_option.select(0)
	_decor_shop_group_option.item_selected.connect(
		_on_decor_shop_group_selected
	)

	_decor_shop_items = VBoxContainer.new()
	_decor_shop_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decor_shop_items.add_theme_constant_override("separation", 7)
	layout.add_child(_decor_shop_items)
	_refresh_decor_shop_panel()


func _on_decor_shop_group_selected(selected_index: int) -> void:
	var group_ids: Array[String] = SET_CATALOG_SCRIPT.get_group_ids()
	if selected_index < 0 or selected_index >= group_ids.size():
		return
	_decor_shop_group_id = group_ids[selected_index]
	_refresh_decor_shop_panel()


func _refresh_decor_shop_panel() -> void:
	if not is_instance_valid(_decor_shop_items):
		return
	var warehouse_count: int = _set_inventory.call(
		"get_props_in_warehouse"
	).size()
	var stage_count: int = _set_inventory.call(
		"get_props_on_stage"
	).size()
	_decor_shop_budget_label.text = (
		"Бюджет реквизита: %d  ·  На складе: %d  ·  На площадке: %d"
		% [_set_inventory.budget, warehouse_count, stage_count]
	)
	for child in _decor_shop_items.get_children():
		_decor_shop_items.remove_child(child)
		child.queue_free()

	for prop_id in SET_CATALOG_SCRIPT.get_prop_ids_for_group(
		_decor_shop_group_id
	):
		var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(
			prop_id
		)
		var row := PanelContainer.new()
		var row_layout := HBoxContainer.new()
		row_layout.add_theme_constant_override("separation", 8)
		row.add_child(row_layout)

		var prop_label := Label.new()
		prop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prop_label.text = "%s\nГабарит: %s · павильон: %s+\nКачество сцены: +%d\nЦена: %d усл. ед." % [
			str(definition.get("title", prop_id)),
			SET_CATALOG_SCRIPT.get_size_class_title(
				str(definition.get("size_class", "medium"))
			),
			BUILDING_CATALOG_SCRIPT.get_stage_size_title(
				int(definition.get("required_stage_tier", 1))
			).to_lower(),
			int(definition.get("quality_bonus", 0)),
			int(definition.get("price", 0)),
		]
		row_layout.add_child(prop_label)

		var purchase_button := Button.new()
		purchase_button.custom_minimum_size = Vector2(104.0, 38.0)
		if _set_inventory.is_owned(prop_id):
			purchase_button.text = "КУПЛЕНО"
			purchase_button.disabled = true
		else:
			purchase_button.text = "КУПИТЬ"
			purchase_button.disabled = (
				int(_set_inventory.budget)
				< int(definition.get("price", 0))
			)
			purchase_button.pressed.connect(
				_on_buy_set_prop_pressed.bind(prop_id)
			)
		row_layout.add_child(purchase_button)
		_decor_shop_items.add_child(row)





func _on_buy_set_prop_pressed(prop_id: String) -> void:
	var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(prop_id)
	if definition.is_empty():
		return
	var purchased: bool = bool(_set_inventory.call(
		"purchase",
		prop_id,
		int(definition.get("price", 0))
	))
	if purchased:
		_refresh_warehouse_inventory_visuals()
		_refresh_active_scene_set_dressing_if_unstarted()
		_refresh_decor_shop_panel()


func _refresh_active_scene_set_dressing_if_unstarted() -> void:
	_get_film_production_controller().call(
		"_refresh_active_scene_set_dressing_if_unstarted"
	)

func _build_film_crew_assignment_controls(assigned_staff: Array) -> void:
	_get_film_production_controller().call("_build_film_crew_assignment_controls", assigned_staff)

func _on_film_crew_role_selected(selected_index: int, role_id: String, role_option: OptionButton) -> void:
	_get_film_production_controller().call("_on_film_crew_role_selected", selected_index, role_id, role_option)

func _get_max_background_performer_count() -> int:
	return int(_get_film_production_controller().call("_get_max_background_performer_count"))

func _build_film_background_assignment_controls(assigned_staff: Array) -> void:
	_get_film_production_controller().call("_build_film_background_assignment_controls", assigned_staff)

func _on_film_background_performer_toggled(enabled: bool, employee_id: String, checkbox: CheckBox) -> void:
	_get_film_production_controller().call("_on_film_background_performer_toggled", enabled, employee_id, checkbox)

func _build_film_cast_assignment_controls(assigned_staff: Array) -> void:
	_get_film_production_controller().call("_build_film_cast_assignment_controls", assigned_staff)

func _on_film_cast_role_selected(selected_index: int, role_id: String, role_option: OptionButton) -> void:
	_get_film_production_controller().call("_on_film_cast_role_selected", selected_index, role_id, role_option)

func _get_film_crew_assignments(assigned_staff: Array) -> Dictionary:
	return _get_film_production_controller().call("_get_film_crew_assignments", assigned_staff)

func _has_complete_production_assignments(crew_assignments: Dictionary, cast_assignments: Dictionary, assigned_staff: Array) -> bool:
	return bool(_get_film_production_controller().call("_has_complete_production_assignments", crew_assignments, cast_assignments, assigned_staff))

func _on_start_film_production_pressed() -> void:
	_get_film_production_controller().call("_on_start_film_production_pressed")

func get_preferred_stage_building_id() -> String:
	return _get_sound_stage_building_id()


func _get_sound_stage_building_id() -> String:
	var required_tier: int = _get_required_stage_size_tier()
	var best_suitable_id: String = ""
	var best_suitable_tier: int = 4
	var largest_available_id: String = ""
	var largest_available_tier: int = 0
	for building in _buildings:
		if (
			str(building.building_type_id) != "sound_stage"
			or not bool(building.is_operational)
		):
			continue
		var tier: int = BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
			int(building.stage_size_tier)
		)
		if tier > largest_available_tier:
			largest_available_tier = tier
			largest_available_id = str(building.id)
		if tier >= required_tier and tier < best_suitable_tier:
			best_suitable_tier = tier
			best_suitable_id = str(building.id)
	if not best_suitable_id.is_empty():
		return best_suitable_id
	return largest_available_id


func _dispatch_film_crew_to_stage() -> void:
	_get_film_production_controller().call("_dispatch_film_crew_to_stage")

func get_film_production_shift() -> Vector2i:
	return _get_film_production_controller().call("get_film_production_shift")

func _get_film_production_shift_for_assignments(crew_assignments: Dictionary, cast_assignments: Dictionary, background_performer_ids: Array[String]) -> Vector2i:
	return _get_film_production_controller().call("_get_film_production_shift_for_assignments", crew_assignments, cast_assignments, background_performer_ids)

func is_film_production_work_hour(hour: int) -> bool:
	return bool(_get_film_production_controller().call("is_film_production_work_hour", hour))

func should_release_production_employee_for_off_hours(hour: int) -> bool:
	return bool(_get_film_production_controller().call("should_release_production_employee_for_off_hours", hour))

func _pause_film_scene_for_off_hours() -> void:
	_get_film_production_controller().call("_pause_film_scene_for_off_hours")

func _advance_film_production(hour: int = -1) -> void:
	_get_film_production_controller().call("_advance_film_production", hour)

func _update_film_stage_slate() -> void:
	_get_film_production_controller().call("_update_film_stage_slate")

func _are_film_crew_ready() -> bool:
	return bool(_get_film_production_controller().call("_are_film_crew_ready"))

func _sync_film_scene_performance() -> bool:
	return bool(_get_film_production_controller().call("_sync_film_scene_performance"))

func _release_cast_for_scene_preparation(stage_id: String, phase: String) -> void:
	_get_film_production_controller().call("_release_cast_for_scene_preparation", stage_id, phase)

func _should_move_stage_employee_off_camera(employee_id: String, performer_ids: Array, crew_ids: Array) -> bool:
	return bool(_get_film_production_controller().call("_should_move_stage_employee_off_camera", employee_id, performer_ids, crew_ids))

func _move_stage_bystanders_off_camera(stage_id: String, performer_ids: Array) -> bool:
	return bool(_get_film_production_controller().call("_move_stage_bystanders_off_camera", stage_id, performer_ids))

func _restore_off_camera_staff(stage_id: String) -> void:
	_get_film_production_controller().call("_restore_off_camera_staff", stage_id)

func is_employee_off_camera(employee_id: String) -> bool:
	return bool(_get_film_production_controller().call("is_employee_off_camera", employee_id))

func _sync_film_set_dressing() -> void:
	_get_film_production_controller().call("_sync_film_set_dressing")

func _get_cast_production_task(phase: String, scene_number: int) -> String:
	return str(_get_film_production_controller().call("_get_cast_production_task", phase, scene_number))

func _get_scene_actor_action(phase: String, scene: Dictionary, is_speaker: bool) -> String:
	return str(_get_film_production_controller().call("_get_scene_actor_action", phase, scene, is_speaker))

func _build_film_performance_snapshot() -> Dictionary:
	return _get_film_production_controller().call("_build_film_performance_snapshot")

func _award_employee_skill_experience(employee_id: String, skill_id: String, amount: float) -> void:
	_get_film_production_controller().call("_award_employee_skill_experience", employee_id, skill_id, amount)

func _award_film_skill_progression(phase: String, phase_duration_minutes: int) -> void:
	_get_film_production_controller().call("_award_film_skill_progression", phase, phase_duration_minutes)

func _award_phase_skill_experience(employee_id: String, skill_id: String, phase_total_experience: float, phase_duration_minutes: int) -> void:
	_get_film_production_controller().call("_award_phase_skill_experience", employee_id, skill_id, phase_total_experience, phase_duration_minutes)

func _apply_film_crew_actions() -> void:
	_get_film_production_controller().call("_apply_film_crew_actions")

func _reset_film_crew_actions() -> void:
	_get_film_production_controller().call("_reset_film_crew_actions")

func _advance_film_editing() -> void:
	_get_film_editing_controller().call("advance")


func _build_film_editing_detail(assigned_staff: Array) -> void:
	_get_film_editing_controller().call(
		"build_detail",
		_building_detail_layout,
		assigned_staff
	)


func _format_set_prop_titles(prop_ids: Array) -> String:
	return str(_get_film_production_controller().call("_format_set_prop_titles", prop_ids))

func _get_script_set_dressing_preview(script: Variant) -> Dictionary:
	return _get_film_production_controller().call("_get_script_set_dressing_preview", script)

func _update_film_production_ui() -> void:
	_get_film_production_controller().call("_update_film_production_ui")

func get_required_stage_size_tier() -> int:
	return _get_required_stage_size_tier()


func _get_required_stage_size_tier() -> int:
	if _latest_script == null:
		return 1
	var owned_prop_ids: Array[String] = _set_inventory.call("get_owned_prop_ids")
	return SET_CATALOG_SCRIPT.get_required_stage_tier(
		_latest_script.scenes,
		owned_prop_ids,
		str(_latest_script.genre_id)
	)


func _get_stage_size_requirement_message() -> String:
	return str(_get_film_production_controller().call("_get_stage_size_requirement_message"))

func _can_start_film_production() -> bool:
	return bool(_get_film_production_controller().call("_can_start_film_production"))

func is_employee_in_active_production(employee_id: String) -> bool:
	return bool(_get_film_production_controller().call("is_employee_in_active_production", employee_id))

func is_employee_in_active_editing(employee_id: String) -> bool:
	return bool(
		_get_film_editing_controller().call(
			"is_employee_in_active_editing",
			employee_id
		)
	)


func is_employee_waiting_for_scene(employee_id: String) -> bool:
	return bool(_get_film_production_controller().call("is_employee_waiting_for_scene", employee_id))

func get_active_film_project() -> Variant:
	return _get_film_production_controller().call("get_active_project")


func get_active_film_editing_project() -> Variant:
	return _get_film_editing_controller().call("get_active_project")


func get_completed_film_archive() -> Array:
	return _completed_film_archive.duplicate(true)




func _get_assigned_staff(building_id: String) -> Array:
	if not is_instance_valid(_character_manager):
		return []
	return _character_manager.call(
		"get_employees_assigned_to_building",
		building_id
	)


func _get_eligible_staff(building_type_id: String) -> Array:
	var result: Array = []
	if not is_instance_valid(_character_manager):
		return result

	var employees: Array = _character_manager.call("get_employees")
	var accepted_professions: Array[String] = (
		BUILDING_CATALOG_SCRIPT.get_accepted_professions(building_type_id)
	)
	for employee in employees:
		if accepted_professions.has(str(employee.profession_id)):
			result.append(employee)
	return result


func _find_employee(employee_id: String) -> Variant:
	if not is_instance_valid(_character_manager):
		return null
	var employees: Array = _character_manager.call("get_employees")
	for employee in employees:
		if str(employee.id) == employee_id:
			return employee
	return null


func _get_profession_title(profession_id: String) -> String:
	return PROFESSION_CATALOG_SCRIPT.get_profession_title(profession_id)

func prepare_scene_set_dressing(
	building_id: String,
	setup: Dictionary
) -> bool:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return false
	return bool(actor.call("prepare_scene_set_dressing", setup))



func install_set_prop(building_id: String, prop_id: String) -> bool:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return false
	return bool(actor.call("install_set_prop", prop_id))



func remove_set_prop(building_id: String, prop_id: String) -> bool:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return false
	return bool(actor.call("remove_set_prop", prop_id))



func clear_scene_set_dressing(building_id: String) -> void:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return
	actor.call("clear_scene_set_dressing")



func get_storage_mark(building_id: String, prop_index: int) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	var mark: Variant = actor.call("get_storage_mark", prop_index)
	if mark is Vector3:
		return mark
	return Vector3.ZERO



func _refresh_warehouse_inventory_visuals() -> void:
	var warehouse_id: String = _get_prop_warehouse_building_id()
	var actor: Variant = _building_actors.get(warehouse_id)
	if actor == null or not is_instance_valid(actor):
		return
	actor.call(
		"set_warehouse_inventory",
		_set_inventory.call("get_props_in_warehouse")
	)


func refresh_warehouse_inventory_visuals() -> void:
	_refresh_warehouse_inventory_visuals()



func _get_scene_setup_refresh_key() -> String:
	return str(_get_film_production_controller().call("_get_scene_setup_refresh_key"))

func _refresh_film_scene_setup_if_needed() -> void:
	_get_film_production_controller().call("_refresh_film_scene_setup_if_needed")

func _get_prop_warehouse_building_id() -> String:
	for building in _buildings:
		if str(building.building_type_id) == "prop_warehouse":
			return str(building.id)
	return ""


func get_prop_warehouse_building_id() -> String:
	return _get_prop_warehouse_building_id()



func _get_stage_technician_ids(crew_assignments: Dictionary) -> Array[String]:
	return _get_film_production_controller().call("_get_stage_technician_ids", crew_assignments)

func _get_set_logistics_scene_key(phase: String, setup: Dictionary) -> String:
	return str(_get_film_production_controller().call("_get_set_logistics_scene_key", phase, setup))

func _begin_set_logistics(
	phase: String,
	setup_data: Dictionary,
	stage_id: String,
	scene_key: String
) -> void:
	_get_set_logistics_controller().call(
		"begin",
		phase,
		setup_data,
		stage_id,
		scene_key,
		_active_film_project,
		_active_production_technician_ids
	)


func _process_set_logistics_tasks(stage_id: String) -> void:
	_get_set_logistics_controller().call(
		"process_tasks",
		stage_id,
		_active_film_project
	)


func _are_set_logistics_tasks_complete() -> bool:
	return bool(_get_set_logistics_controller().call("are_tasks_complete"))


func _are_set_logistics_workers_ready() -> bool:
	return bool(_get_set_logistics_controller().call("are_workers_ready"))


func _reset_set_logistics() -> void:
	_get_set_logistics_controller().call("reset")



func get_set_logistics_phase() -> String:
	return _set_logistics_phase


func get_set_logistics_scene_key() -> String:
	return _set_logistics_scene_key


func get_set_logistics_worker_ids() -> Array[String]:
	return _set_logistics_worker_ids


func is_set_logistics_blocked() -> bool:
	return _set_logistics_blocked


func begin_set_logistics(
	phase: String,
	setup_data: Dictionary,
	stage_id: String,
	scene_key: String
) -> void:
	_begin_set_logistics(phase, setup_data, stage_id, scene_key)


func process_set_logistics_tasks(stage_id: String) -> void:
	_process_set_logistics_tasks(stage_id)


func are_set_logistics_tasks_complete() -> bool:
	return _are_set_logistics_tasks_complete()


func are_set_logistics_workers_ready() -> bool:
	return _are_set_logistics_workers_ready()


func reset_set_logistics() -> void:
	_reset_set_logistics()


