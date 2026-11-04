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

const INITIAL_PROFESSIONS: Array[String] = [
	"actor",
	"actor",
	"director",
	"screenwriter",
	"camera_operator",
	"producer",
]

const SKILL_TITLES: Dictionary = {
	"acting": "Актёрское мастерство",
	"directing": "Режиссура",
	"writing": "Сценарное мастерство",
	"camera_work": "Работа с камерой",
	"management": "Управление",
	"technical": "Технические навыки",
	"creativity": "Креативность",
	"reliability": "Надёжность",
}

var employees: Array = []
var _generator: RefCounted
var _needs_system: RefCounted
var _game_clock: Node

var _employee_actors: Dictionary = {}
var _roster_buttons: Dictionary = {}
var _selected_employee_id: String = ""

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


func get_selected_employee_id() -> String:
	return _selected_employee_id


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

		var actor: Variant = CHARACTER_ACTOR_SCRIPT.new()
		actor.name = "Employee_%02d" % (index + 1)
		actor.call(
			"setup",
			data,
			_route_for(index),
			_game_clock,
			rng.randf_range(1.0, 1.45)
		)
		add_child(actor)
		_employee_actors[employee_id] = actor


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

	return route


func _build_roster_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "EmployeeManagementHUD"
	canvas.layer = 6
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.name = "EmployeeRosterPanel"
	panel.position = Vector2(16.0, 154.0)
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	canvas.add_child(panel)

	var layout := VBoxContainer.new()
	panel.add_child(layout)

	var header := Label.new()
	header.text = "ПЕРСОНАЛ СТУДИИ  ·  %d" % employees.size()
	header.add_theme_font_size_override("font_size", 16)
	layout.add_child(header)

	var hint := Label.new()
	hint.text = "Выбери сотрудника для просмотра карточки"
	hint.add_theme_font_size_override("font_size", 11)
	layout.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310.0, 390.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var employee_list := VBoxContainer.new()
	employee_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(employee_list)

	for employee in employees:
		var employee_id: String = str(employee.id)
		var button := Button.new()
		button.name = "Roster_%s" % employee_id
		button.custom_minimum_size = Vector2(305.0, 56.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_roster_employee_pressed.bind(employee_id))
		employee_list.add_child(button)
		_roster_buttons[employee_id] = button


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

	_refresh_roster()
	_refresh_detail_panel()


func _unhandled_input(event: InputEvent) -> void:
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


func _find_employee(employee_id: String) -> Variant:
	for employee in employees:
		if str(employee.id) == employee_id:
			return employee
	return null


func _refresh_roster() -> void:
	for employee in employees:
		var employee_id: String = str(employee.id)
		var button: Button = _roster_buttons.get(employee_id) as Button
		if not is_instance_valid(button):
			continue

		var needs: Dictionary = employee.needs
		button.text = "%s — %s\n%s · Энергия %d%% · Настроение %d%%" % [
			employee.get_full_name(),
			employee.get_profession_title(),
			employee.get_work_state_title(),
			roundi(float(needs.get("energy", 1.0)) * 100.0),
			roundi(float(needs.get("morale", 0.75)) * 100.0),
		]
		button.button_pressed = employee_id == _selected_employee_id


func _refresh_detail_panel() -> void:
	if not is_instance_valid(_detail_name_label):
		return

	var employee: Variant = _find_employee(_selected_employee_id)
	if employee == null:
		_detail_name_label.text = "ВЫБЕРИ СОТРУДНИКА"
		_detail_profession_label.text = "Кликни по персонажу на карте или по строке в списке."
		_detail_biography_label.text = ""
		_detail_stats_label.text = ""
		_detail_task_label.text = ""
		_detail_schedule_label.text = ""
		_detail_skills_label.text = ""
		_detail_personality_label.text = ""
		_energy_label.text = "Энергия"
		_morale_label.text = "Настроение"
		_stress_label.text = "Стресс"
		_energy_bar.value = 0.0
		_morale_bar.value = 0.0
		_stress_bar.value = 0.0
		return

	var needs: Dictionary = employee.needs
	var skills: Dictionary = employee.skills
	var personality: Dictionary = employee.personality

	_detail_name_label.text = employee.get_full_name().to_upper()
	_detail_profession_label.text = "%s  ·  Возраст: %d" % [
		employee.get_profession_title(),
		employee.age,
	]
	_detail_biography_label.text = employee.biography
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
	for skill_id in SKILL_TITLES.keys():
		skill_lines.append("%s: %d / 100" % [
			SKILL_TITLES[skill_id],
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
