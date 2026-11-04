extends Node3D
class_name CharacterManager

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
var _workplace_system: RefCounted
var _studio_building_manager: Node
var _workplace_assignments: Dictionary = {}

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


func employee_work_state(employee_id: String) -> String:
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return ""
	return str(employee.work_state)


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
	if (
		_game_clock.is_manual_fast_forward
		and str(employee_work_state(employee_id)) == "working"
	):
		return true
	return bool(actor.call("is_at_workplace"))


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
		if assignment.is_empty() or str(employee.work_state) == "off_duty":
			actor.call("clear_workplace")
			continue

		var building_id: String = str(assignment.get("building_id", ""))
		var destination: Vector3 = _studio_building_manager.call(
			"get_workplace_position",
			building_id,
			int(assignment.get("slot_index", 0))
		)
		actor.call("assign_workplace", building_id, destination)


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
	var canvas := CanvasLayer.new()
	canvas.name = "EmployeeManagementHUD"
	canvas.layer = 6
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.name = "EmployeeRosterPanel"
	panel.position = Vector2(16.0, 220.0)
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	canvas.add_child(panel)

	var layout := VBoxContainer.new()
	panel.add_child(layout)

	_roster_header = Label.new()
	_roster_header.add_theme_font_size_override("font_size", 16)
	layout.add_child(_roster_header)

	var hint := Label.new()
	hint.text = "Выбери сотрудника для просмотра карточки"
	hint.add_theme_font_size_override("font_size", 11)
	layout.add_child(hint)

	_market_toggle_button = Button.new()
	_market_toggle_button.text = "КАДРОВЫЙ РЫНОК"
	_market_toggle_button.pressed.connect(_toggle_market_panel)
	layout.add_child(_market_toggle_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310.0, 600.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_employee_list = VBoxContainer.new()
	_employee_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	button.custom_minimum_size = Vector2(305.0, 72.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(_on_roster_employee_pressed.bind(employee_id))
	_employee_list.add_child(button)
	_roster_buttons[employee_id] = button


func _build_market_panel() -> void:
	var canvas := get_node_or_null("EmployeeManagementHUD") as CanvasLayer
	if canvas == null:
		return

	_market_panel = PanelContainer.new()
	_market_panel.name = "EmployeeMarketPanel"
	_market_panel.position = Vector2(360.0, 220.0)
	_market_panel.custom_minimum_size = Vector2(370.0, 0.0)
	_market_panel.visible = false
	canvas.add_child(_market_panel)

	var layout := VBoxContainer.new()
	_market_panel.add_child(layout)

	var top_row := HBoxContainer.new()
	layout.add_child(top_row)

	_market_header = Label.new()
	_market_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_header.add_theme_font_size_override("font_size", 16)
	top_row.add_child(_market_header)

	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.pressed.connect(_close_market_panel)
	top_row.add_child(close_button)

	_market_status_label = Label.new()
	_market_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_market_status_label.add_theme_font_size_override("font_size", 11)
	layout.add_child(_market_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350.0, 600.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_market_list = VBoxContainer.new()
	_market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_market_list)

	_refresh_market_panel()


func _toggle_market_panel() -> void:
	if not is_instance_valid(_market_panel):
		return
	_market_panel.visible = not _market_panel.visible
	if _market_panel.visible:
		_refresh_market_panel()


func _close_market_panel() -> void:
	if is_instance_valid(_market_panel):
		_market_panel.visible = false


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
		"Новые специалисты появляются каждые 7 игровых дней. До обновления: %d дн."
		% days_until_refresh
	)

	for child in _market_list.get_children():
		_market_list.remove_child(child)
		child.queue_free()

	for candidate in market_candidates:
		var candidate_id: String = str(candidate.id)
		var button := Button.new()
		button.name = "Candidate_%s" % candidate_id
		button.custom_minimum_size = Vector2(345.0, 64.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		var candidate_role_title: String = candidate.get_profession_title()
		var candidate_specialization: String = candidate.get_specialization_title()
		if not candidate_specialization.is_empty():
			candidate_role_title += " · " + candidate_specialization
		button.text = "%s — %s\n%s · %s: %d / 100  ·  Запрос: %d ед. / день" % [
			candidate.get_full_name(),
			candidate_role_title,
			candidate.get_department_title(),
			candidate.get_primary_skill_title(),
			roundi(candidate.get_primary_skill_value()),
			candidate.daily_salary,
		]
		button.pressed.connect(
			_on_market_candidate_pressed.bind(candidate_id)
		)
		_market_list.add_child(button)

	_market_toggle_button.text = "КАДРОВЫЙ РЫНОК  ·  %d" % market_candidates.size()

func _build_detail_panel() -> void:
	var canvas := get_node_or_null("EmployeeManagementHUD") as CanvasLayer
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "EmployeeManagementHUD"
		canvas.layer = 6
		add_child(canvas)

	var panel := PanelContainer.new()
	panel.name = "EmployeeDetailPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -370.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	panel.offset_bottom = -16.0
	panel.custom_minimum_size = Vector2(350.0, 0.0)
	canvas.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)

	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(_detail_name_label)

	_detail_profession_label = Label.new()
	_detail_profession_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(_detail_profession_label)

	_detail_biography_label = Label.new()
	_detail_biography_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_biography_label)

	layout.add_child(HSeparator.new())

	_detail_stats_label = Label.new()
	_detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_stats_label)

	_detail_task_label = Label.new()
	_detail_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_task_label)

	_detail_schedule_label = Label.new()
	layout.add_child(_detail_schedule_label)

	_detail_contract_label = Label.new()
	_detail_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_contract_label)

	_contract_type_option = OptionButton.new()
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
	canvas.add_child(_dismiss_dialog)

	layout.add_child(HSeparator.new())

	var needs_heading := Label.new()
	needs_heading.text = "СОСТОЯНИЕ"
	needs_heading.add_theme_font_size_override("font_size", 14)
	layout.add_child(needs_heading)

	_energy_label = Label.new()
	layout.add_child(_energy_label)
	_energy_bar = _create_progress_bar(layout)

	_morale_label = Label.new()
	layout.add_child(_morale_label)
	_morale_bar = _create_progress_bar(layout)

	_stress_label = Label.new()
	layout.add_child(_stress_label)
	_stress_bar = _create_progress_bar(layout)

	layout.add_child(HSeparator.new())

	var skills_heading := Label.new()
	skills_heading.text = "ПРОФЕССИОНАЛЬНЫЕ НАВЫКИ"
	skills_heading.add_theme_font_size_override("font_size", 14)
	layout.add_child(skills_heading)

	_detail_skills_label = Label.new()
	_detail_skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_skills_label)

	layout.add_child(HSeparator.new())

	var personality_heading := Label.new()
	personality_heading.text = "ЛИЧНОСТЬ"
	personality_heading.add_theme_font_size_override("font_size", 14)
	layout.add_child(personality_heading)

	_detail_personality_label = Label.new()
	_detail_personality_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_detail_personality_label)


func _create_progress_bar(parent: VBoxContainer) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0.0, 14.0)
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

		if assignment.is_empty() or str(employee.work_state) == "off_duty":
			actor.call("clear_workplace")
			continue

		var building_id: String = str(assignment.get("building_id", ""))
		if str(actor.call("get_workplace_building_id")) != building_id:
			if is_instance_valid(_studio_building_manager):
				var destination: Vector3 = _studio_building_manager.call(
					"get_workplace_position",
					building_id,
					int(assignment.get("slot_index", 0))
				)
				actor.call("assign_workplace", building_id, destination)

		var is_at_workplace: bool = bool(
			actor.call("is_at_workplace")
		)
		if _game_clock.is_manual_fast_forward:
			is_at_workplace = true

		if (
			str(employee.work_state) == "working"
			and is_at_workplace
		):
			_workplace_system.call(
				"advance_work_minute",
				employee,
				assignment
			)

	if not _game_clock.is_manual_fast_forward:
		_refresh_roster()
		_refresh_detail_panel()


func _on_game_day_advanced(day: int) -> void:
	var result: Dictionary = _employment_system.call("advance_day", day)

	for expired_employee in result.get("expired_employees", []):
		var expired_id: String = str(expired_employee.id)
		_remove_employee_actor(expired_id)
		if _selected_employee_id == expired_id:
			_selected_employee_id = ""

	if bool(result.get("market_refreshed", false)):
		if not _selected_market_candidate_id.is_empty():
			if _find_market_candidate(_selected_market_candidate_id) == null:
				_selected_market_candidate_id = ""
		_refresh_market_panel()

	_refresh_workplace_assignments()
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
		if str(employee.work_state) != "off_duty":
			var actor: Variant = _employee_actors.get(str(employee.id))
			if actor != null and is_instance_valid(actor):
				actor.call("snap_to_workplace")

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


func _refresh_roster() -> void:
	if is_instance_valid(_roster_header):
		_roster_header.text = "ПЕРСОНАЛ СТУДИИ  ·  %d" % employees.size()

	for employee in employees:
		var employee_id: String = str(employee.id)
		var button: Button = _roster_buttons.get(employee_id) as Button
		if not is_instance_valid(button):
			continue

		var needs: Dictionary = employee.needs
		button.text = "%s — %s\n%s · Энергия %d%% · Настроение %d%%\n%s" % [
			employee.get_full_name(),
			employee.get_profession_title(),
			employee.get_work_state_title(),
			roundi(float(needs.get("energy", 1.0)) * 100.0),
			roundi(float(needs.get("morale", 0.75)) * 100.0),
			employee.current_task,
		]
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
		_detail_task_label.text = "СЕЙЧАС: %s\nСтатус: %s" % [
			employee.current_task,
			employee.get_work_state_title(),
		]
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


func _show_employee_message(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Управление персоналом"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()
