extends Node3D
class_name CharacterManager

signal employees_changed

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
var _employment_system: Variant
var _game_clock: Node
var _studio_hud: Node
var _workplace_system: RefCounted
var _studio_building_manager: Node
var _workplace_assignments: Dictionary = {}
var _employee_task_overrides: Dictionary = {}

var _employee_actors: Dictionary = {}
var _roster_buttons: Dictionary = {}
var _selected_employee_id: String = ""
var _selected_market_candidate_id: String = ""

var _roster_header: Label
var _employee_list: VBoxContainer
var _market_toggle_button: Button
var _market_panel: PanelContainer
var _market_header: Label
var _market_status_label: Label
var _market_list: VBoxContainer

var _detail_contract_label: Label
var _contract_type_option: OptionButton
var _hire_button: Button
var _dismiss_button: Button
var _dismiss_dialog: ConfirmationDialog

var _detail_name_label: Label
var _detail_profession_label: Label
var _detail_biography_label: Label
var _detail_stats_label: Label
var _detail_task_label: Label
var _detail_schedule_label: Label
var _detail_skills_label: Label
var _detail_personality_label: Label

var _energy_label: Label
var _morale_label: Label
var _stress_label: Label
var _energy_bar: ProgressBar
var _morale_bar: ProgressBar
var _stress_bar: ProgressBar


func _ready() -> void:
	_game_clock = get_node("../GameClock")
	_studio_hud = get_node_or_null("../StudioHUD")
	_needs_system = CHARACTER_NEEDS_SYSTEM_SCRIPT.new()
	_game_clock.minute_advanced.connect(_on_game_minute_advanced)
	_game_clock.day_advanced.connect(_on_game_day_advanced)
	_game_clock.manual_advance_finished.connect(_on_manual_advance_finished)

	_spawn_initial_roster()
	_build_roster_panel()
	_build_detail_panel()

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


func dispatch_employee_to_workplace(employee_id: String) -> bool:
	if not is_instance_valid(_studio_building_manager):
		return false
	var assignment: Dictionary = _workplace_assignments.get(
		employee_id,
		{}
	)
	if assignment.is_empty():
		return false
	var actor: Node3D = get_employee_actor(employee_id) as Node3D
	if actor == null:
		return false
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return false

	var building_id: String = str(assignment.get("building_id", ""))
	if building_id.is_empty():
		return false
	var slot_index: int = int(assignment.get("slot_index", 0))
	var profession_id: String = str(employee.profession_id)
	var manual_fast_forward: bool = (
		is_instance_valid(_game_clock)
		and bool(_game_clock.is_manual_fast_forward)
	)
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
			actor.call(
				"assign_workplace_route",
				building_id,
				return_route,
				profession_id
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
				actor.call("leave_workplace")
			return false

	var route: Array[Vector3] = _studio_building_manager.call(
		"get_workplace_path_from",
		building_id,
		slot_index,
		actor.global_position
	)
	if route.is_empty():
		return false
	actor.call(
		"assign_workplace_route",
		building_id,
		route,
		profession_id
	)
	if manual_fast_forward:
		actor.call("snap_to_workplace")
		return true
	return false


func _refresh_workplace_assignments() -> void:
	if (
		_workplace_system == null
		or not is_instance_valid(_studio_building_manager)
	):
		return

	var buildings: Array = _studio_building_manager.call("get_buildings")
	_workplace_assignments = _workplace_system.call(
		"build_assignments",
		employees,
		buildings
	)

	for employee in employees:
		var employee_id: String = str(employee.id)
		var actor: Variant = _employee_actors.get(employee_id)
		if actor == null or not is_instance_valid(actor):
			continue

		var assignment: Dictionary = _workplace_assignments.get(
			employee_id,
			{}
		)
		if _is_active_production_participant(employee_id):
			continue
		if _should_leave_workplace(
			employee_id,
			str(employee.work_state),
			assignment.is_empty()
		):
			actor.call("leave_workplace")
			continue

		var building_id: String = str(assignment.get("building_id", ""))
		var current_building_id: String = str(
			actor.call("get_workplace_building_id")
		)
		if current_building_id != building_id:
			if not current_building_id.is_empty():
				if not bool(actor.call("is_leaving_workplace")):
					actor.call("leave_workplace")
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
			actor.call(
				"assign_workplace_route",
				building_id,
				route,
				str(employee.profession_id)
			)

	if is_instance_valid(_roster_header):
		_refresh_roster()
		_refresh_detail_panel()


func _spawn_initial_roster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	_generator = CHARACTER_GENERATOR_SCRIPT.new()

	for index in range(INITIAL_PROFESSIONS.size()):
		var employee_id: String = "EMP-%04d" % (index + 1)
		var profession_id: String = INITIAL_PROFESSIONS[index]
		var data: Variant = _generator.call(
			"generate", rng, employee_id, profession_id
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
	var actor: Variant = _employee_actors.get(employee_id)
	if actor != null and is_instance_valid(actor):
		actor.queue_free()
	_employee_actors.erase(employee_id)

	var roster_button: Variant = _roster_buttons.get(employee_id)
	if roster_button != null and is_instance_valid(roster_button):
		roster_button.queue_free()
	_roster_buttons.erase(employee_id)


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
	var panel := PanelContainer.new()
	panel.name = "EmployeeRosterPanel"
	panel.custom_minimum_size = Vector2(0.0, 0.0)
	if _studio_hud == null:
		push_error("CharacterManager: StudioHUD node is missing.")
		return
	_studio_hud.call(
		"register_workspace_panel",
		"employees",
		"Персонал студии",
		panel
	)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var roster_header_row := HBoxContainer.new()
	roster_header_row.add_theme_constant_override("separation", 8)
	layout.add_child(roster_header_row)

	_roster_header = Label.new()
	_roster_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_header.add_theme_font_size_override("font_size", 12)
	_roster_header.add_theme_color_override(
		"font_color",
		Color(0.48, 0.82, 0.72, 1.0)
	)
	roster_header_row.add_child(_roster_header)

	_market_toggle_button = Button.new()
	_market_toggle_button.text = "РЫНОК"
	_market_toggle_button.custom_minimum_size = Vector2(94.0, 32.0)
	_market_toggle_button.pressed.connect(_toggle_market_panel)
	roster_header_row.add_child(_market_toggle_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 0.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_studio_hud.call("configure_scroll_container", scroll)
	layout.add_child(scroll)

	_employee_list = VBoxContainer.new()
	_employee_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_employee_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_employee_list)

	for employee in employees:
		_add_roster_button(employee)

	_build_market_panel()
	_refresh_roster()


func _add_roster_button(employee: Variant) -> void:
	if not is_instance_valid(_employee_list):
		return

	var employee_id: String = str(employee.id)
	if _roster_buttons.has(employee_id):
		return

	var button := Button.new()
	button.name = "Roster_%s" % employee_id
	button.custom_minimum_size = Vector2(0.0, 60.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.add_theme_constant_override("h_separation", 8)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(_on_roster_employee_pressed.bind(employee_id))
	_employee_list.add_child(button)
	_roster_buttons[employee_id] = button


func _build_market_panel() -> void:
	if _studio_hud == null:
		return

	_market_panel = PanelContainer.new()
	_market_panel.name = "EmployeeMarketPanel"
	_market_panel.custom_minimum_size = Vector2(0.0, 0.0)
	_market_panel.visible = false
	_studio_hud.call(
		"register_workspace_panel",
		"market",
		"Кадровый рынок",
		_market_panel
	)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_market_panel.add_child(layout)

	var top_row := HBoxContainer.new()
	layout.add_child(top_row)

	_market_header = Label.new()
	_market_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_header.add_theme_font_size_override("font_size", 13)
	_market_header.add_theme_color_override(
		"font_color",
		Color(0.48, 0.82, 0.72, 1.0)
	)
	top_row.add_child(_market_header)

	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.pressed.connect(_close_market_panel)
	top_row.add_child(close_button)

	_market_status_label = Label.new()
	_market_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_market_status_label.add_theme_font_size_override("font_size", 11)
	_market_status_label.add_theme_color_override(
		"font_color",
		Color(0.58, 0.76, 0.79, 1.0)
	)
	layout.add_child(_market_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 0.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_studio_hud.call("configure_scroll_container", scroll)
	layout.add_child(scroll)

	_market_list = VBoxContainer.new()
	_market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_market_list)

	_refresh_market_panel()


func _toggle_market_panel() -> void:
	if not is_instance_valid(_market_panel) or _studio_hud == null:
		return
	_refresh_market_panel()
	_studio_hud.call("show_workspace_panel", "market")


func _close_market_panel() -> void:
	if _studio_hud != null:
		_studio_hud.call("show_workspace_panel", "employees")


func _refresh_market_panel() -> void:
	if not is_instance_valid(_market_list):
		return

	_market_header.text = "КАДРОВЫЙ РЫНОК  ·  %d" % market_candidates.size()
	var days_until_refresh: int = int(
		_employment_system.call(
			"get_market_days_until_refresh",
			int(_game_clock.current_day)
		)
	)
	_market_status_label.text = (
		"Обновление рынка через %d дн." % days_until_refresh
	)

	for child in _market_list.get_children():
		_market_list.remove_child(child)
		child.queue_free()

	for candidate in market_candidates:
		var candidate_id: String = str(candidate.id)
		var button := Button.new()
		button.name = "Candidate_%s" % candidate_id
		button.custom_minimum_size = Vector2(0.0, 60.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		var candidate_role_title: String = candidate.get_profession_title()
		var candidate_specialization: String = candidate.get_specialization_title()
		if not candidate_specialization.is_empty():
			candidate_role_title += " · " + candidate_specialization
		button.text = "%s\n%s · %d ед. / день" % [
			candidate.get_full_name(),
			candidate_role_title,
			candidate.daily_salary,
		]
		button.tooltip_text = (
			"%s · %s: %d / 100"
			% [
				candidate.get_department_title(),
				candidate.get_primary_skill_title(),
				roundi(candidate.get_primary_skill_value()),
			]
		)
		button.pressed.connect(
			_on_market_candidate_pressed.bind(candidate_id)
		)
		_market_list.add_child(button)

	_market_toggle_button.text = "РЫНОК · %d" % market_candidates.size()

func _build_detail_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "EmployeeDetailPanel"
	panel.custom_minimum_size = Vector2(0.0, 0.0)
	if _studio_hud == null:
		push_error("CharacterManager: StudioHUD node is missing.")
		return
	_studio_hud.call(
		"register_inspector_panel",
		"employee",
		"Карточка сотрудника",
		panel
	)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_studio_hud.call("configure_scroll_container", scroll)
	panel.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 9)
	scroll.add_child(layout)

	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_size_override("font_size", 20)
	_detail_name_label.add_theme_color_override(
		"font_color",
		Color(0.80, 0.95, 0.91, 1.0)
	)
	layout.add_child(_detail_name_label)

	_detail_profession_label = Label.new()
	_detail_profession_label.add_theme_font_size_override("font_size", 13)
	_detail_profession_label.add_theme_color_override(
		"font_color",
		Color(0.62, 0.79, 0.82, 1.0)
	)
	layout.add_child(_detail_profession_label)

	_detail_biography_label = Label.new()
	_detail_biography_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_biography_label.add_theme_color_override(
		"font_color",
		Color(0.74, 0.77, 0.76, 1.0)
	)
	layout.add_child(_detail_biography_label)

	layout.add_child(HSeparator.new())

	_detail_stats_label = Label.new()
	_detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_stats_label)

	_detail_task_label = Label.new()
	_detail_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_task_label)

	_detail_schedule_label = Label.new()
	_detail_schedule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_schedule_label)

	_detail_contract_label = Label.new()
	_detail_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_contract_label)

	_contract_type_option = OptionButton.new()
	_contract_type_option.fit_to_longest_item = false
	_contract_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contract_type_option.add_item("Бессрочный")
	_contract_type_option.set_item_metadata(0, "permanent")
	_contract_type_option.add_item("Срочный · 30 дней")
	_contract_type_option.set_item_metadata(1, "fixed_30_days")
	_contract_type_option.add_item("Срочный · 90 дней")
	_contract_type_option.set_item_metadata(2, "fixed_90_days")
	_contract_type_option.select(0)
	_contract_type_option.item_selected.connect(_on_contract_type_selected)
	_contract_type_option.visible = false
	layout.add_child(_contract_type_option)

	_hire_button = Button.new()
	_hire_button.text = "НАНЯТЬ СОТРУДНИКА"
	_hire_button.pressed.connect(_on_hire_button_pressed)
	_hire_button.visible = false
	layout.add_child(_hire_button)

	_dismiss_button = Button.new()
	_dismiss_button.text = "УВОЛИТЬ СОТРУДНИКА"
	_dismiss_button.pressed.connect(_on_dismiss_button_pressed)
	_dismiss_button.visible = false
	layout.add_child(_dismiss_button)

	_dismiss_dialog = ConfirmationDialog.new()
	_dismiss_dialog.title = "Подтверждение увольнения"
	_dismiss_dialog.confirmed.connect(_confirm_dismiss_employee)
	var overlay_root: Node = _studio_hud.call("get_overlay_root")
	overlay_root.add_child(_dismiss_dialog)

	layout.add_child(HSeparator.new())

	var needs_heading := Label.new()
	needs_heading.text = "СОСТОЯНИЕ"
	needs_heading.add_theme_font_size_override("font_size", 12)
	needs_heading.add_theme_color_override(
		"font_color",
		Color(0.48, 0.82, 0.72, 1.0)
	)
	layout.add_child(needs_heading)

	_energy_label = Label.new()
	layout.add_child(_energy_label)
	_energy_bar = _create_progress_bar(
		layout,
		Color(0.39, 0.68, 0.60, 1.0)
	)

	_morale_label = Label.new()
	layout.add_child(_morale_label)
	_morale_bar = _create_progress_bar(
		layout,
		Color(0.42, 0.69, 0.84, 1.0)
	)

	_stress_label = Label.new()
	layout.add_child(_stress_label)
	_stress_bar = _create_progress_bar(
		layout,
		Color(0.72, 0.39, 0.34, 1.0)
	)

	layout.add_child(HSeparator.new())

	var skills_heading := Label.new()
	skills_heading.text = "ПРОФЕССИОНАЛЬНЫЕ НАВЫКИ"
	skills_heading.add_theme_font_size_override("font_size", 12)
	skills_heading.add_theme_color_override(
		"font_color",
		Color(0.48, 0.82, 0.72, 1.0)
	)
	layout.add_child(skills_heading)

	_detail_skills_label = Label.new()
	_detail_skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_skills_label)

	layout.add_child(HSeparator.new())

	var personality_heading := Label.new()
	personality_heading.text = "ЛИЧНОСТЬ"
	personality_heading.add_theme_font_size_override("font_size", 12)
	personality_heading.add_theme_color_override(
		"font_color",
		Color(0.48, 0.82, 0.72, 1.0)
	)
	layout.add_child(personality_heading)

	_detail_personality_label = Label.new()
	_detail_personality_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_personality_label)


func _create_progress_bar(
	parent: VBoxContainer,
	fill_color: Color
) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0.0, 10.0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(5)
	progress.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(progress)
	return progress


func _on_roster_employee_pressed(employee_id: String) -> void:
	_select_employee(employee_id)


func _on_game_minute_advanced(_day: int, hour: int, _minute: int) -> void:
	for employee in employees:
		_needs_system.call("advance_minute", employee, hour)

		var employee_id: String = str(employee.id)
		var actor: Variant = _employee_actors.get(employee_id)
		var assignment: Dictionary = _workplace_assignments.get(
			employee_id,
			{}
		)
		if actor == null or not is_instance_valid(actor):
			continue

		if _is_active_production_participant(employee_id):
			continue
		if _should_leave_workplace(
			employee_id,
			str(employee.work_state),
			assignment.is_empty()
		):
			actor.call("leave_workplace")
			continue

		var building_id: String = str(assignment.get("building_id", ""))
		var current_building_id: String = str(
			actor.call("get_workplace_building_id")
		)
		if (
			current_building_id != building_id
			and is_instance_valid(_studio_building_manager)
		):
			if not current_building_id.is_empty():
				if not bool(actor.call("is_leaving_workplace")):
					actor.call("leave_workplace")
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
			actor.call(
				"assign_workplace_route",
				building_id,
				route,
				str(employee.profession_id)
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

	if not _game_clock.is_manual_fast_forward:
		_refresh_roster()
		_refresh_detail_panel()


func _on_game_day_advanced(day: int) -> void:
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

	_select_from_screen(mouse_event.position)


func _select_from_screen(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var ray_end: Vector3 = ray_origin + ray_direction * 250.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 2)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		_select_employee("")
		return

	var candidate: Node = hit.get("collider") as Node
	while candidate != null and not candidate.is_in_group("studio_employee"):
		candidate = candidate.get_parent()

	if candidate != null:
		_select_employee(str(candidate.call("get_character_id")))
	else:
		_select_employee("")


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
	if is_instance_valid(_roster_header):
		_roster_header.text = "СОСТАВ СТУДИИ  ·  %d" % employees.size()

	for employee in employees:
		var employee_id: String = str(employee.id)
		var button: Button = _roster_buttons.get(employee_id) as Button
		if not is_instance_valid(button):
			continue

		var needs: Dictionary = employee.needs
		var work_state_title: String = employee.get_work_state_title()
		if (
			_is_active_production_participant(employee_id)
			or _is_employee_off_camera(employee_id)
		):
			work_state_title = _get_production_participant_status(
				employee_id
			)
		var energy: int = roundi(float(needs.get("energy", 1.0)) * 100.0)
		var morale: int = roundi(float(needs.get("morale", 0.75)) * 100.0)
		button.text = "%s\n%s · %s" % [
			employee.get_full_name(),
			employee.get_profession_title(),
			work_state_title,
		]
		button.tooltip_text = (
			"Энергия: %d%% · Настроение: %d%%\nЗадача: %s"
			% [energy, morale, employee.current_task]
		)
		button.button_pressed = employee_id == _selected_employee_id


func _refresh_detail_panel() -> void:
	if not is_instance_valid(_detail_name_label):
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
		_detail_name_label.text = "ВЫБЕРИ СОТРУДНИКА"
		_detail_profession_label.text = (
			"Выбери сотрудника в списке или открой кадровый рынок."
		)
		_detail_biography_label.text = ""
		_detail_stats_label.text = ""
		_detail_task_label.text = ""
		_detail_schedule_label.text = ""
		_detail_contract_label.text = ""
		_detail_skills_label.text = ""
		_detail_personality_label.text = ""
		_energy_label.text = "Энергия"
		_morale_label.text = "Настроение"
		_stress_label.text = "Стресс"
		_energy_bar.value = 0.0
		_morale_bar.value = 0.0
		_stress_bar.value = 0.0
		_contract_type_option.visible = false
		_hire_button.visible = false
		_dismiss_button.visible = false
		return

	var needs: Dictionary = employee.needs
	var skills: Dictionary = employee.skills
	var personality: Dictionary = employee.personality

	_detail_name_label.text = employee.get_full_name().to_upper()
	var employee_role_title: String = employee.get_profession_title()
	var employee_specialization: String = employee.get_specialization_title()
	if not employee_specialization.is_empty():
		employee_role_title += " · " + employee_specialization
	_detail_profession_label.text = "%s  ·  %s  ·  Возраст: %d" % [
		employee_role_title,
		employee.get_department_title(),
		employee.age,
	]
	_detail_biography_label.text = employee.biography

	if is_market_candidate:
		_detail_stats_label.text = (
			"Опыт: %.1f лет\nПопулярность: %.0f / 100\nОжидание: %d усл. ед. / день\nЦель: %s"
			% [
				employee.experience,
				employee.popularity,
				employee.daily_salary,
				employee.career_goal,
			]
		)
		_detail_task_label.text = "СТАТУС: Кандидат открыт к предложениям"
		_detail_schedule_label.text = "График работы согласуется при найме."
		var contract_type: String = _get_selected_contract_type()
		var offer_salary: int = int(
			_employment_system.call(
				"get_offer_salary",
				str(employee.id),
				contract_type
			)
		)
		_detail_contract_label.text = (
			"ПРЕДЛАГАЕМЫЙ КОНТРАКТ\nТип: %s\nСтавка: %d усл. ед. / день"
			% [
				_get_contract_type_title(contract_type),
				offer_salary,
			]
		)
		_contract_type_option.visible = true
		_hire_button.visible = true
		_dismiss_button.visible = false
	else:
		_detail_stats_label.text = (
			"Опыт: %.1f лет\nПопулярность: %.0f / 100\nОплата: %d усл. ед. / день\nЦель: %s"
			% [
				employee.experience,
				employee.popularity,
				employee.daily_salary,
				employee.career_goal,
			]
		)
		var workplace_title: String = _get_workplace_title(
			str(employee.id)
		)
		var employee_work_state_title: String = (
			"На съёмках"
			if _is_active_production_participant(str(employee.id))
			else employee.get_work_state_title()
		)
		_detail_task_label.text = (
			"СЕЙЧАС: %s\nСтатус: %s\nРабочее место: %s"
			% [
				employee.current_task,
				employee_work_state_title,
				workplace_title,
			]
		)
		_detail_schedule_label.text = "Смена: %02d:00–%02d:00  ·  Перерыв: %02d:00–%02d:00" % [
			employee.shift_start_hour,
			employee.shift_end_hour,
			employee.break_start_hour,
			employee.break_end_hour,
		]

		var contract: Variant = _employment_system.call(
			"get_contract", str(employee.id)
		)
		if contract == null:
			_detail_contract_label.text = "КОНТРАКТ: данные отсутствуют"
		else:
			var end_text: String = (
				"Бессрочный"
				if int(contract.end_day) == 0
				else "до дня %d" % int(contract.end_day)
			)
			_detail_contract_label.text = (
				"ТРУДОВОЙ ДОГОВОР\n%s\nСтавка: %d усл. ед. / день\nНачало: день %d · %s"
				% [
					contract.get_type_title(),
					contract.daily_salary,
					contract.start_day,
					end_text,
				]
			)
		_contract_type_option.visible = false
		_hire_button.visible = false
		_dismiss_button.visible = true

	var energy: float = float(needs.get("energy", 1.0)) * 100.0
	var morale: float = float(needs.get("morale", 0.75)) * 100.0
	var stress: float = float(needs.get("stress", 0.1)) * 100.0
	_energy_label.text = "Энергия  ·  %d%%" % roundi(energy)
	_morale_label.text = "Настроение  ·  %d%%" % roundi(morale)
	_stress_label.text = "Стресс  ·  %d%%" % roundi(stress)
	_energy_bar.value = energy
	_morale_bar.value = morale
	_stress_bar.value = stress

	var skill_lines: Array[String] = []
	var profession_skill_ids: Array[String] = (
		PROFESSION_CATALOG_SCRIPT.get_profession_skill_ids(
			employee.profession_id,
			employee.specialization_id
		)
	)
	for skill_id in profession_skill_ids:
		skill_lines.append("%s: %d / 100" % [
			PROFESSION_CATALOG_SCRIPT.get_skill_title(skill_id),
			roundi(float(skills.get(skill_id, 0.0))),
		])
	_detail_skills_label.text = "\n".join(skill_lines)

	_detail_personality_label.text = (
		"Амбиции: %d%%\nОбщительность: %d%%\nДисциплина: %d%%\nКреативность: %d%%"
		% [
			roundi(float(personality.get("ambition", 0.5)) * 100.0),
			roundi(float(personality.get("sociability", 0.5)) * 100.0),
			roundi(float(personality.get("discipline", 0.5)) * 100.0),
			roundi(float(personality.get("creativity", 0.5)) * 100.0),
		]
	)


func _on_contract_type_selected(_index: int) -> void:
	_refresh_detail_panel()


func _get_selected_contract_type() -> String:
	if not is_instance_valid(_contract_type_option):
		return "permanent"
	var selected_index: int = _contract_type_option.selected
	if selected_index < 0:
		return "permanent"
	return str(_contract_type_option.get_item_metadata(selected_index))


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
	var employee: Variant = _find_employee(_selected_employee_id)
	if employee == null:
		return

	_dismiss_dialog.dialog_text = (
		"Уволить %s?\nКонтракт будет расторгнут, персонаж покинет активный штат."
		% employee.get_full_name()
	)
	_dismiss_dialog.popup_centered()


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


