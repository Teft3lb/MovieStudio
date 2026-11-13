extends RefCounted
class_name FilmProductionController

const DEFAULT_FILM_SHIFT_START_HOUR: int = 8
const DEFAULT_FILM_SHIFT_END_HOUR: int = 17
const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)
const FILM_CREW_CATALOG_SCRIPT = preload(
	"res://scripts/domain/film_production/film_crew_catalog.gd"
)
const FILM_PRODUCTION_ASSIGNMENT_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/film_production_assignment_controller.gd"
)
const FILM_SCENE_PERFORMANCE_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/film_scene_performance_controller.gd"
)

var _manager: Node
var _character_manager: Node
var _film_production_system: RefCounted
var _skill_progression_system: RefCounted
var _game_clock: Node
var _set_inventory: Variant
var _detail_layout: VBoxContainer
var _assignment_controller: RefCounted
var _scene_performance_controller: RefCounted

var _active_film_project: Variant
var _active_film_script: Variant
var _active_production_technician_ids: Array[String] = []
var _film_phase_actions_pending: bool = false
var _last_scene_setup_refresh_key: String = ""

var _film_production_status_label: Label
var _film_production_progress_bar: ProgressBar
var _film_production_detail_label: Label
var _film_production_start_button: Button


func setup(
	manager: Node,
	character_manager: Node,
	film_production_system: RefCounted,
	skill_progression_system: RefCounted,
	game_clock: Node,
	set_inventory: Variant
) -> void:
	_manager = manager
	_character_manager = character_manager
	_film_production_system = film_production_system
	_skill_progression_system = skill_progression_system
	_game_clock = game_clock
	_set_inventory = set_inventory


func _get_assignment_controller() -> RefCounted:
	if _assignment_controller == null:
		_assignment_controller = FILM_PRODUCTION_ASSIGNMENT_CONTROLLER_SCRIPT.new()
	_assignment_controller.call(
		"setup",
		_manager,
		_film_production_system
	)
	return _assignment_controller


func _get_scene_performance_controller() -> RefCounted:
	if _scene_performance_controller == null:
		_scene_performance_controller = FILM_SCENE_PERFORMANCE_CONTROLLER_SCRIPT.new()
	_scene_performance_controller.call(
		"setup",
		_manager,
		_character_manager,
		_film_production_system,
		_game_clock
	)
	return _scene_performance_controller


func get_active_project() -> Variant:
	return _active_film_project


func set_active_project(project: Variant) -> void:
	_active_film_project = project


func get_active_script() -> Variant:
	return _active_film_script


func set_active_script(script: Variant) -> void:
	_active_film_script = script


func get_active_production_technician_ids() -> Array[String]:
	return _active_production_technician_ids


func set_active_production_technician_ids(employee_ids: Array[String]) -> void:
	_active_production_technician_ids = employee_ids


func build_detail(detail_layout: VBoxContainer, assigned_staff: Array) -> void:
	_detail_layout = detail_layout
	_reset_ui_references()
	if not is_instance_valid(_detail_layout):
		return
	_build_sound_stage_detail(assigned_staff)


func _reset_ui_references() -> void:
	_film_production_status_label = null
	_film_production_progress_bar = null
	_film_production_detail_label = null
	_film_production_start_button = null


func _get_latest_script() -> Variant:
	if not is_instance_valid(_manager):
		return null
	if _manager.has_method("get_script_for_production"):
		return _manager.call("get_script_for_production")
	return _manager.call("get_latest_script")


func _get_active_writing_project() -> Variant:
	if not is_instance_valid(_manager):
		return null
	return _manager.call("get_active_writing_project")


func _get_active_editing_project() -> Variant:
	if not is_instance_valid(_manager):
		return null
	return _manager.call("get_active_film_editing_project")


func _get_next_script_sequence() -> int:
	if not is_instance_valid(_manager):
		return 1
	return int(_manager.call("get_next_script_sequence"))


func _get_sound_stage_building_id() -> String:
	if not is_instance_valid(_manager):
		return ""
	return str(_manager.call("get_preferred_stage_building_id"))


func _get_required_stage_size_tier() -> int:
	if not is_instance_valid(_manager):
		return 1
	if _manager.has_method("get_required_stage_size_tier_for_script"):
		return int(_manager.call(
			"get_required_stage_size_tier_for_script",
			_get_latest_script()
		))
	return int(_manager.call("get_required_stage_size_tier"))


func _get_stage_size_requirement_message() -> String:
	if _get_latest_script() == null:
		return ""
	var stage: Variant = _find_building(_get_sound_stage_building_id())
	if stage == null:
		return ""
	var required_tier: int = _get_required_stage_size_tier()
	var actual_tier: int = int(stage.stage_size_tier)
	if actual_tier >= required_tier:
		return ""
	var required_size: Vector2 = BUILDING_CATALOG_SCRIPT.get_stage_footprint(
		required_tier
	)
	return (
		"Для сценария нужен %s павильон (%.0f × %.0f м). "
		+ "Сейчас доступен %s. Построй павильон нужного размера."
	) % [
		BUILDING_CATALOG_SCRIPT.get_stage_size_title(required_tier).to_lower(),
		required_size.x,
		required_size.y,
		BUILDING_CATALOG_SCRIPT.get_stage_size_title(actual_tier).to_lower(),
	]

func _can_start_film_production() -> bool:
	return _get_film_production_blocker().is_empty()


func _get_film_production_blocker() -> String:
	var script: Variant = _get_latest_script()
	if script == null:
		return "Нет готового сценария. Заверши работу в сценарном отделе."
	if _active_film_project != null:
		if str(_active_film_project.status) != "completed":
			return "Предыдущий фильм ещё снимается."
		var editing_project: Variant = _get_active_editing_project()
		if editing_project == null or str(editing_project.status) != "completed":
			return "Сначала доставь отснятый материал в монтажную и закончи предыдущий фильм."
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return "Построй съёмочный павильон."
	var stage_size_message: String = _get_stage_size_requirement_message()
	if not stage_size_message.is_empty():
		return stage_size_message
	if (
		_manager.has_method("is_film_script_staged")
		and not bool(_manager.call(
			"is_film_script_staged", str(script.id), stage_id
		))
	):
		return (
			"Доставь папку сценария «%s» из сценарного отдела "
			+ "в выбранный съёмочный павильон (перетащи мышью по 3D-миру)."
		) % str(script.title)
	if (
		_active_film_project != null
		and _manager.has_method("is_prior_film_released")
		and not bool(_manager.call("is_prior_film_released"))
	):
		return "Закончи выпуск предыдущего фильма: перенеси готовые катушки из монтажной в пункт «РЕЛИЗ»."
	var assigned_staff: Array = _get_assigned_staff(stage_id)
	var assignment_controller: RefCounted = _get_assignment_controller()
	var crew_assignments: Dictionary = assignment_controller.call(
		"get_film_crew_assignments", assigned_staff
	)
	var cast_assignments: Dictionary = assignment_controller.call(
		"get_cast_assignments"
	)
	if not bool(assignment_controller.call(
		"has_complete_production_assignments",
		crew_assignments,
		cast_assignments,
		assigned_staff
	)):
		return str(assignment_controller.call(
			"get_assignment_blocker",
			crew_assignments,
			cast_assignments,
			assigned_staff
		))
	return ""

func _find_employee(employee_id: String) -> Variant:
	if not is_instance_valid(_character_manager):
		return null
	var employees: Array = _character_manager.call("get_employees")
	for employee in employees:
		if str(employee.id) == employee_id:
			return employee
	return null


func _find_building(building_id: String) -> Variant:
	if not is_instance_valid(_manager):
		return null
	return _manager.call("get_building_by_id", building_id)


func _get_assigned_staff(building_id: String) -> Array:
	if not is_instance_valid(_manager):
		return []
	return _manager.call("get_assigned_staff_for_building", building_id)


func _get_profession_title(profession_id: String) -> String:
	return PROFESSION_CATALOG_SCRIPT.get_profession_title(profession_id)


func _format_stars(star_count: int) -> String:
	var result: String = ""
	for index in range(5):
		result += "★" if index < star_count else "☆"
	return result


func _get_set_logistics_phase() -> String:
	if not is_instance_valid(_manager):
		return ""
	return str(_manager.call("get_set_logistics_phase"))


func _get_current_set_logistics_scene_key() -> String:
	if not is_instance_valid(_manager):
		return ""
	return str(_manager.call("get_set_logistics_scene_key"))


func _get_set_logistics_worker_ids() -> Array[String]:
	if not is_instance_valid(_manager):
		return []
	return _manager.call("get_set_logistics_worker_ids")


func _is_set_logistics_blocked() -> bool:
	if not is_instance_valid(_manager):
		return false
	return bool(_manager.call("is_set_logistics_blocked"))


func _are_set_logistics_tasks_complete() -> bool:
	if not is_instance_valid(_manager):
		return true
	return bool(_manager.call("are_set_logistics_tasks_complete"))


func _are_set_logistics_workers_ready() -> bool:
	if not is_instance_valid(_manager):
		return true
	return bool(_manager.call("are_set_logistics_workers_ready"))


func _begin_set_logistics(
	phase: String,
	setup_data: Dictionary,
	stage_id: String,
	scene_key: String
) -> void:
	if not is_instance_valid(_manager):
		return
	_manager.call("begin_set_logistics", phase, setup_data, stage_id, scene_key)


func _process_set_logistics_tasks(stage_id: String) -> void:
	if not is_instance_valid(_manager):
		return
	_manager.call("process_set_logistics_tasks", stage_id)


func _reset_set_logistics() -> void:
	if not is_instance_valid(_manager):
		return
	_manager.call("reset_set_logistics")


func _build_sound_stage_detail(assigned_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "ПРОИЗВОДСТВЕННАЯ ПЛОЩАДКА"
	heading.add_theme_font_size_override("font_size", 14)
	_detail_layout.add_child(heading)

	var project_label := Label.new()
	project_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if (
		_get_active_writing_project() != null
		and str(_get_active_writing_project().status) == "in_progress"
	):
		project_label.text = (
			"Сейчас пишется сценарий: %s\nПрогресс: %.0f%%"
			% [
				str(_get_active_writing_project().writer_name),
				float(_get_active_writing_project().get_progress_percent()),
			]
		)
	elif _get_latest_script() == null:
		project_label.text = "Нет готового сценария. Создай заказ в сценарном отделе."
	else:
		project_label.text = (
			"Последний сценарий: %s\n%s · %d сцен · потенциал %s"
			% [
				str(_get_latest_script().title),
				str(_get_latest_script().genre_title),
				int(_get_latest_script().scene_count),
				_format_stars(int(_get_latest_script().potential_stars)),
			]
		)
	_detail_layout.add_child(project_label)

	_detail_layout.add_child(HSeparator.new())
	var crew_heading := Label.new()
	crew_heading.text = "ГОТОВНОСТЬ СЪЁМОЧНОЙ КОМАНДЫ"
	crew_heading.add_theme_font_size_override("font_size", 14)
	_detail_layout.add_child(crew_heading)

	var ready_positions: int = 0
	var crew_lines: Array[String] = []
	for profession_id in FILM_CREW_CATALOG_SCRIPT.REQUIRED_STAGE_PROFESSIONS:
		var matching_staff: Array[String] = []
		for employee in assigned_staff:
			var employee_profession: String = str(employee.profession_id)
			var matches_position: bool = (
				employee_profession == profession_id
				or (
					profession_id == "actor"
					and employee_profession == "extra"
				)
			)
			if matches_position:
				matching_staff.append(str(employee.get_full_name()))
		if not matching_staff.is_empty():
			ready_positions += 1
		crew_lines.append(
			"%s: %s" % [
				_get_profession_title(profession_id),
				", ".join(matching_staff) if not matching_staff.is_empty() else "не хватает",
			]
		)

	crew_lines.push_front(
		"Обязательные позиции: %d / %d" % [
			ready_positions,
			FILM_CREW_CATALOG_SCRIPT.REQUIRED_STAGE_PROFESSIONS.size(),
		]
	)
	var crew_label := Label.new()
	crew_label.text = "\n".join(crew_lines)
	crew_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_layout.add_child(crew_label)

	if _get_latest_script() != null:
		_get_assignment_controller().call(
			"build_controls",
			_detail_layout,
			assigned_staff
		)
	else:
		var no_script_label := Label.new()
		no_script_label.text = "Сначала заверши сценарий в сценарном отделе."
		no_script_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_layout.add_child(no_script_label)

	_film_production_status_label = Label.new()
	_film_production_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_film_production_status_label.add_theme_font_size_override("font_size", 14)
	_detail_layout.add_child(_film_production_status_label)

	_film_production_progress_bar = ProgressBar.new()
	_film_production_progress_bar.min_value = 0.0
	_film_production_progress_bar.max_value = 100.0
	_film_production_progress_bar.show_percentage = true
	_film_production_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_layout.add_child(_film_production_progress_bar)

	_film_production_detail_label = Label.new()
	_film_production_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_layout.add_child(_film_production_detail_label)

	_film_production_start_button = Button.new()
	_film_production_start_button.text = "НАЧАТЬ СЪЁМКИ"
	_film_production_start_button.pressed.connect(
		_on_start_film_production_pressed
	)
	_detail_layout.add_child(_film_production_start_button)

	var production_note := Label.new()
	production_note.text = (
		"Каждая сцена проходит подготовку, монтаж декораций, репетицию, "
		+ "съёмку и просмотр. Пока техник готовит площадку, актёры гуляют "
		+ "по студии и возвращаются на репетицию по вызову. Покупки до начала "
		+ "установки учитываются в текущей сцене; позднее — в следующих. "
		+ "Реквизит переиспользуется, а его отсутствие снижает качество. "
		+ "Физическую папку сценария перетащи к павильону мышью, "
		+ "а после съёмок отвези катушки в монтажную."
	)
	production_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	production_note.add_theme_font_size_override("font_size", 10)
	_detail_layout.add_child(production_note)

	_update_film_production_ui()

func _refresh_active_scene_set_dressing_if_unstarted() -> void:
	if (
		_active_film_project == null
		or _active_film_script == null
		or str(_active_film_project.status) != "in_production"
	):
		return
	var current_phase: String = str(_active_film_project.current_phase)
	if current_phase == "set_dressing" and not _get_set_logistics_phase().is_empty():
		return
	if (
		current_phase != "preparation"
		and not (
			current_phase == "set_dressing"
			and int(_active_film_project.phase_minutes_elapsed) == 0
		)
	):
		return
	_film_production_system.call(
		"refresh_current_scene_setup",
		_active_film_project,
		_active_film_script,
		_set_inventory.get_owned_prop_ids()
	)
	_last_scene_setup_refresh_key = _get_scene_setup_refresh_key()
	_sync_film_set_dressing()
	_update_film_production_ui()
func _build_film_crew_assignment_controls(assigned_staff: Array) -> void:
	_get_assignment_controller().call(
		"build_crew_assignment_controls",
		_detail_layout,
		assigned_staff
	)
func _on_film_crew_role_selected(selected_index: int, role_id: String, role_option: OptionButton) -> void:
	_get_assignment_controller().call(
		"_on_film_crew_role_selected",
		selected_index,
		role_id,
		role_option
	)
func _get_max_background_performer_count() -> int:
	return int(_get_assignment_controller().call("_get_max_background_performer_count"))
func _build_film_background_assignment_controls(assigned_staff: Array) -> void:
	_get_assignment_controller().call(
		"build_background_assignment_controls",
		_detail_layout,
		assigned_staff
	)
func _on_film_background_performer_toggled(enabled: bool, employee_id: String, checkbox: CheckBox) -> void:
	_get_assignment_controller().call(
		"_on_film_background_performer_toggled",
		enabled,
		employee_id,
		checkbox
	)
func _build_film_cast_assignment_controls(assigned_staff: Array) -> void:
	_get_assignment_controller().call(
		"build_cast_assignment_controls",
		_detail_layout,
		assigned_staff
	)
func _on_film_cast_role_selected(selected_index: int, role_id: String, role_option: OptionButton) -> void:
	_get_assignment_controller().call(
		"_on_film_cast_role_selected",
		selected_index,
		role_id,
		role_option
	)
func _get_film_crew_assignments(assigned_staff: Array) -> Dictionary:
	return _get_assignment_controller().call(
		"get_film_crew_assignments",
		assigned_staff
	)
func _has_complete_production_assignments(crew_assignments: Dictionary, cast_assignments: Dictionary, assigned_staff: Array) -> bool:
	return bool(_get_assignment_controller().call(
		"has_complete_production_assignments",
		crew_assignments,
		cast_assignments,
		assigned_staff
	))

func _on_start_film_production_pressed() -> void:
	var blocker: String = _get_film_production_blocker()
	if not blocker.is_empty():
		if is_instance_valid(_film_production_status_label):
			_film_production_status_label.text = blocker
		return
	if _get_latest_script() == null:
		return
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		_film_production_status_label.text = "Не найден съёмочный павильон."
		return

	var stage_size_message: String = _get_stage_size_requirement_message()
	if not stage_size_message.is_empty():
		_film_production_status_label.text = stage_size_message
		return
	var assigned_staff: Array = _get_assigned_staff(stage_id)
	var assignment_controller: RefCounted = _get_assignment_controller()
	var crew_assignments: Dictionary = assignment_controller.call(
		"get_film_crew_assignments",
		assigned_staff
	)
	var cast_assignments: Dictionary = assignment_controller.call(
		"get_cast_assignments"
	)
	var background_performer_ids: Array[String] = assignment_controller.call(
		"get_background_performer_ids"
	)
	if not bool(assignment_controller.call(
		"has_complete_production_assignments",
		crew_assignments,
		cast_assignments,
		assigned_staff
	)):
		_film_production_status_label.text = (
			"Не хватает назначенных сотрудников. Проверь режиссёра, "
			+ "оператора, техника и актёров на все роли."
		)
		return

	var project_id: String = "FILM-%04d" % _get_next_script_sequence()
	var seed: int = (
		int(_game_clock.current_day) * 100000
		+ int(_game_clock.current_hour) * 1000
		+ int(_game_clock.current_minute) * 10
		+ _get_next_script_sequence()
	)
	_active_production_technician_ids = assignment_controller.call(
		"get_stage_technician_ids",
		crew_assignments
	)
	var technician_count: int = clampi(
		maxi(_active_production_technician_ids.size(), 1),
		1,
		8
	)
	var scene_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		_get_latest_script().scenes,
		_set_inventory.get_owned_prop_ids(),
		str(_get_latest_script().genre_id),
		technician_count
	)
	var production_shift: Vector2i = _get_film_production_shift_for_assignments(
		crew_assignments,
		cast_assignments,
		background_performer_ids
	)
	var production_shift_minutes_per_day: int = maxi(
		(production_shift.y - production_shift.x) * 60,
		60
	)
	var project: Variant = _film_production_system.call(
		"start_project",
		_get_latest_script(),
		crew_assignments,
		cast_assignments,
		project_id,
		seed,
		int(_game_clock.current_day),
		int(_game_clock.current_hour),
		int(_game_clock.current_minute),
		scene_setups,
		technician_count,
		background_performer_ids,
		production_shift_minutes_per_day
	)
	if project == null:
		_active_production_technician_ids.clear()
		_film_production_status_label.text = (
			"Не удалось запустить производство. Проверь сценарий, роли и команду."
		)
		return

	_manager.call("archive_completed_film_chain")
	_manager.call("reset_active_film_editing")

	_manager.call("increment_script_sequence")
	_active_film_project = project
	_active_film_script = _get_latest_script()
	if (
		is_instance_valid(_manager)
		and _manager.has_method("on_film_production_started")
	):
		_manager.call(
			"on_film_production_started",
			str(_active_film_script.id),
			stage_id
		)
	_get_scene_performance_controller().call("clear_active_scene_performers")
	_reset_set_logistics()
	_last_scene_setup_refresh_key = ""
	if is_film_production_work_hour(int(_game_clock.current_hour)):
		_dispatch_film_crew_to_stage()
		_apply_film_crew_actions()
		_sync_film_scene_performance()
		_sync_film_set_dressing()
	else:
		_film_phase_actions_pending = true
		var next_shift: Vector2i = get_film_production_shift()
		_active_film_project.pause_reason = (
			"Съёмочная смена завершена. Продолжение в %02d:00."
			% next_shift.x
		)
		_active_film_project.last_activity_message = (
			_active_film_project.pause_reason
		)
	_update_film_stage_slate()
	_update_film_production_ui()

func _dispatch_film_crew_to_stage() -> void:
	if (
		_active_film_project == null
		or not is_instance_valid(_character_manager)
	):
		return
	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	for role_id in [
		"director",
		"camera_operator",
		"technician",
		"producer",
		"production_designer",
		"costume_designer",
		"makeup_artist",
	]:
		var employee_id: String = str(crew_assignments.get(role_id, ""))
		if employee_id.is_empty():
			continue
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if (
			actor != null
			and is_instance_valid(actor)
			and bool(actor.call("is_in_scene_performance"))
		):
			continue
		_character_manager.call(
			"dispatch_employee_to_workplace",
			employee_id
		)

	var primary_technician_id: String = str(
		crew_assignments.get("technician", "")
	)
	for technician_id in _active_production_technician_ids:
		if technician_id == primary_technician_id:
			continue
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			technician_id
		)
		if (
			actor != null
			and is_instance_valid(actor)
			and bool(actor.call("is_in_scene_performance"))
		):
			continue
		_character_manager.call(
			"dispatch_employee_to_workplace",
			technician_id
		)

func get_film_production_shift() -> Vector2i:
	if _active_film_project == null:
		return Vector2i(
			DEFAULT_FILM_SHIFT_START_HOUR,
			DEFAULT_FILM_SHIFT_END_HOUR
		)
	return _get_film_production_shift_for_assignments(
		_active_film_project.crew_assignments,
		_active_film_project.cast_assignments,
		_active_film_project.background_performer_ids
)

func _get_film_production_shift_for_assignments(
	crew_assignments: Dictionary,
	cast_assignments: Dictionary,
	background_performer_ids: Array[String]
) -> Vector2i:
	var start_hour: int = DEFAULT_FILM_SHIFT_START_HOUR
	var end_hour: int = DEFAULT_FILM_SHIFT_END_HOUR
	var participant_ids: Array[String] = []
	for employee_id_value in crew_assignments.values():
		var employee_id: String = str(employee_id_value)
		if not employee_id.is_empty() and not participant_ids.has(employee_id):
			participant_ids.append(employee_id)
	for employee_id_value in cast_assignments.values():
		var employee_id: String = str(employee_id_value)
		if not employee_id.is_empty() and not participant_ids.has(employee_id):
			participant_ids.append(employee_id)
	for employee_id in background_performer_ids:
		if not employee_id.is_empty() and not participant_ids.has(employee_id):
			participant_ids.append(employee_id)

	var found_participant: bool = false
	for employee_id in participant_ids:
		var employee: Variant = _find_employee(employee_id)
		if employee == null:
			continue
		if not found_participant:
			start_hour = int(employee.shift_start_hour)
			end_hour = int(employee.shift_end_hour)
			found_participant = true
		else:
			start_hour = maxi(start_hour, int(employee.shift_start_hour))
			end_hour = mini(end_hour, int(employee.shift_end_hour))
	if end_hour <= start_hour:
		return Vector2i(
			DEFAULT_FILM_SHIFT_START_HOUR,
			DEFAULT_FILM_SHIFT_END_HOUR
		)
	return Vector2i(start_hour, end_hour)

func is_film_production_work_hour(hour: int) -> bool:
	var shift: Vector2i = get_film_production_shift()
	return hour >= shift.x and hour < shift.y

func _is_film_lunch_break(hour: int) -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or not is_film_production_work_hour(hour)
	):
		return false
	var participants: Dictionary = {}
	for employee_id_value in _active_film_project.crew_assignments.values():
		participants[str(employee_id_value)] = true
	for employee_id_value in _active_film_project.cast_assignments.values():
		participants[str(employee_id_value)] = true
	for employee_id in _active_film_project.background_performer_ids:
		participants[employee_id] = true
	for employee_id_value in participants.keys():
		var employee_id: String = str(employee_id_value)
		if employee_id.is_empty():
			continue
		var employee: Variant = _find_employee(employee_id)
		if employee == null:
			continue
		if (
			hour >= int(employee.break_start_hour)
			and hour < int(employee.break_end_hour)
		):
			return true
	return false


func should_release_production_employee_for_off_hours(hour: int) -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
	):
		return false
	if is_film_production_work_hour(hour) and not _is_film_lunch_break(hour):
		return false

	var phase: String = str(_active_film_project.current_phase)
	if (
		phase in ["set_dressing", "set_strike"]
		and not _are_set_logistics_tasks_complete()
	):
		if not _get_set_logistics_worker_ids().is_empty():
			return false
		if not _is_set_logistics_blocked():
			return false
	return true
func _pause_film_scene_for_off_hours() -> void:
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return
	_get_scene_performance_controller().call("pause_for_off_hours", stage_id)

func _apply_staged_film_assignments() -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or str(_active_film_project.current_phase) != "preparation"
		or int(_active_film_project.phase_minutes_elapsed) != 0
	):
		return false
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return false
	var assigned_staff: Array = _get_assigned_staff(stage_id)
	var editor: RefCounted = _get_assignment_controller()
	var proposed_crew: Dictionary = editor.call(
		"get_film_crew_assignments", assigned_staff
	)
	var proposed_cast: Dictionary = editor.call("get_cast_assignments")
	var proposed_background: Array[String] = editor.call(
		"get_background_performer_ids"
	)
	if (
		proposed_crew == _active_film_project.crew_assignments
		and proposed_cast == _active_film_project.cast_assignments
		and proposed_background == _active_film_project.background_performer_ids
	):
		return false
	if not bool(editor.call(
		"has_complete_production_assignments",
		proposed_crew,
		proposed_cast,
		assigned_staff
	)):
		return false
	# Only commit complete substitutions between scenes. Never interrupt a
	# live take or a technician carrying a physical set piece.
	_reset_film_crew_actions()
	_pause_film_scene_for_off_hours()
	_active_film_project.crew_assignments = proposed_crew.duplicate(true)
	_active_film_project.cast_assignments = proposed_cast.duplicate(true)
	_active_film_project.background_performer_ids = proposed_background.duplicate()
	_active_production_technician_ids = editor.call(
		"get_stage_technician_ids", proposed_crew
	)
	var shift: Vector2i = _get_film_production_shift_for_assignments(
		proposed_crew, proposed_cast, proposed_background
	)
	_active_film_project.production_shift_minutes_per_day = maxi(
		(shift.y - shift.x) * 60, 60
	)
	_film_phase_actions_pending = true
	_active_film_project.last_activity_message = (
		"Состав съёмочной группы обновлён перед новой сценой."
	)
	return true


func _advance_film_production(hour: int = -1) -> void:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
	):
		return
	var resolved_hour: int = hour
	if resolved_hour < 0:
		resolved_hour = DEFAULT_FILM_SHIFT_START_HOUR
	var current_phase: String = str(_active_film_project.current_phase)
	if _is_film_lunch_break(resolved_hour):
		_film_phase_actions_pending = true
		var logistics_pending: bool = (
			current_phase in ["set_dressing", "set_strike"]
			and not _are_set_logistics_tasks_complete()
		)
		if logistics_pending:
			_sync_film_set_dressing()
		if not logistics_pending or _are_set_logistics_tasks_complete():
			_pause_film_scene_for_off_hours()
			_active_film_project.pause_reason = (
				"Обеденный перерыв. Съёмки продолжатся после возвращения команды."
			)
		else:
			_active_film_project.pause_reason = (
				"Обед. Техники завершают перевозку декораций."
			)
		_active_film_project.last_activity_message = _active_film_project.pause_reason
		_update_film_stage_slate()
		_update_film_production_ui()
		return
	if not is_film_production_work_hour(resolved_hour):
		_film_phase_actions_pending = true
		var logistics_pending: bool = (
			current_phase in ["set_dressing", "set_strike"]
			and not _are_set_logistics_tasks_complete()
		)
		if logistics_pending:
			_sync_film_set_dressing()
			var logistics_complete: bool = _are_set_logistics_tasks_complete()
			var blocked_without_active_workers: bool = (
				_is_set_logistics_blocked()
				and _get_set_logistics_worker_ids().is_empty()
			)
			if logistics_complete or blocked_without_active_workers:
				_pause_film_scene_for_off_hours()
				if logistics_complete:
					_active_film_project.pause_reason = (
						"Съёмочная смена завершена. Продолжение в %02d:00."
						% get_film_production_shift().x
					)
				else:
					_active_film_project.pause_reason = (
						"Смена завершена. Логистика заблокирована; персонал отправлен отдыхать."
					)
			else:
				_active_film_project.pause_reason = (
					"Смена завершена. Техники завершают логистику декораций; "
					+ "производственные часы остановлены."
				)
		else:
			_pause_film_scene_for_off_hours()
			_active_film_project.pause_reason = (
				"Съёмочная смена завершена. Продолжение в %02d:00."
				% get_film_production_shift().x
			)
		_active_film_project.last_activity_message = (
			_active_film_project.pause_reason
		)
		_update_film_stage_slate()
		_update_film_production_ui()
		return

	_apply_staged_film_assignments()
	if _film_phase_actions_pending:
		_apply_film_crew_actions()
		_film_phase_actions_pending = false
		_active_film_project.pause_reason = ""
		_active_film_project.last_activity_message = "Съёмочная смена возобновлена."
	elif not str(_active_film_project.pause_reason).is_empty():
		_active_film_project.last_activity_message = "Съёмочная смена возобновлена."
	_active_film_project.pause_reason = ""
	_dispatch_film_crew_to_stage()
	var cast_ready: bool = _sync_film_scene_performance()
	_sync_film_set_dressing()
	var crew_ready: bool = _are_film_crew_ready()
	if (
		crew_ready
		and _get_set_logistics_phase() == "set_dressing"
		and _are_set_logistics_tasks_complete()
	):
		_active_film_project.last_activity_message = "Декорации установлены. Съёмочная группа готовится к репетиции."
	elif (
		crew_ready
		and _get_set_logistics_phase() == "set_strike"
		and _are_set_logistics_tasks_complete()
	):
		_active_film_project.last_activity_message = "Реквизит возвращён на склад. Площадка готова к следующей сцене."
	var phase_for_skill_progression: String = str(
		_active_film_project.current_phase
	)
	var phase_duration_for_skill_progression: int = maxi(
		int(_active_film_project.phase_duration_minutes),
		1
	)
	var snapshot: Dictionary = _build_film_performance_snapshot()
	var result: Dictionary = _film_production_system.call(
		"advance_minute",
		_active_film_project,
		_active_film_script,
		crew_ready,
		cast_ready,
		snapshot
	)
	if bool(result.get("advanced", false)):
		_award_film_skill_progression(
			phase_for_skill_progression,
			phase_duration_for_skill_progression
		)
	if not bool(result.get("advanced", false)):
		if _is_set_logistics_blocked():
			_active_film_project.pause_reason = "Логистика реквизита остановлена: проверь склад и маршруты техников."
		elif _get_set_logistics_phase() == "set_dressing" and not _are_set_logistics_tasks_complete():
			_active_film_project.pause_reason = "Техники доставляют декорации со склада и устанавливают их на площадке."
		elif _get_set_logistics_phase() == "set_strike" and not _are_set_logistics_tasks_complete():
			_active_film_project.pause_reason = "Техники снимают декорации и возвращают их на склад."
		_active_film_project.last_activity_message = _active_film_project.pause_reason
	if bool(result.get("phase_changed", false)):
		var next_phase: String = str(_active_film_project.current_phase)
		if (
			next_phase in ["rehearsal", "shooting", "review"]
			and not is_film_production_work_hour(resolved_hour)
		):
			_film_phase_actions_pending = true
			_pause_film_scene_for_off_hours()
			var next_shift: Vector2i = get_film_production_shift()
			_active_film_project.pause_reason = (
				"Съёмочная смена завершена. Продолжение в %02d:00."
				% next_shift.x
			)
			_active_film_project.last_activity_message = (
				_active_film_project.pause_reason
			)
			_update_film_stage_slate()
			_update_film_production_ui()
			return
		_apply_film_crew_actions()
		if str(_active_film_project.current_phase) == "preparation":
			_refresh_active_scene_set_dressing_if_unstarted()
		_sync_film_set_dressing()
		_sync_film_scene_performance()
	if bool(result.get("completed", false)):
		if (
			is_instance_valid(_manager)
			and _manager.has_method("on_film_production_completed")
		):
			_manager.call(
				"on_film_production_completed",
				str(_active_film_script.id)
			)
		_sync_film_scene_performance()
		_reset_film_crew_actions()
		_active_production_technician_ids.clear()
		_reset_set_logistics()
		_last_scene_setup_refresh_key = ""
	_update_film_stage_slate()
	_update_film_production_ui()

func _update_film_stage_slate() -> void:
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return
	if _active_film_project == null:
		_manager.call("set_production_scene",
			stage_id,
			0,
			"СЪЁМКИ НЕ ИДУТ",
			"ПАВИЛЬОН ГОТОВ"
		)
		return
	if str(_active_film_project.status) == "completed":
		_manager.call("set_production_scene",
			stage_id,
			0,
			"ФИЛЬМ ГОТОВ",
			"МАТЕРИАЛ ПЕРЕДАН НА МОНТАЖ"
		)
		return
	var scene: Dictionary = _film_production_system.call(
		"get_current_scene",
		_active_film_script,
		_active_film_project
	)
	var phase_title: String = str(
		_active_film_project.get_phase_title()
	)
	if not str(_active_film_project.pause_reason).is_empty():
		phase_title = "ПАУЗА: %s" % str(_active_film_project.pause_reason)
	var slate_title: String = "%s · %s" % [
		str(scene.get("beat", "Съёмочная сцена")),
		str(scene.get("location", "Павильон")),
	]
	_manager.call("set_production_scene",
		stage_id,
		int(scene.get("scene_number", _active_film_project.current_scene_index + 1)),
		slate_title,
		phase_title
	)

func _are_film_crew_ready() -> bool:
	if (
		_get_set_logistics_phase() in ["set_dressing", "set_strike"]
		and not _are_set_logistics_workers_ready()
	):
		return false
	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	var checked_ids: Dictionary = {}
	for employee_id_value in crew_assignments.values():
		var employee_id: String = str(employee_id_value)
		if employee_id.is_empty() or checked_ids.has(employee_id):
			continue
		checked_ids[employee_id] = true
		var employee: Variant = _find_employee(employee_id)
		if employee == null:
			return false
		var ready: bool = bool(
			_character_manager.call(
				"is_employee_ready_for_production",
				employee_id,
				"sound_stage"
			)
		)
		if ready:
			continue
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if (
			actor != null
			and is_instance_valid(actor)
			and not bool(actor.call("is_in_scene_performance"))
			and not bool(actor.call("is_returning_to_workplace"))
		):
			_character_manager.call(
				"dispatch_employee_to_workplace",
				employee_id
			)
		return false
	return true
func _sync_film_scene_performance() -> bool:
	return bool(_get_scene_performance_controller().call(
		"sync_scene_performance",
		_active_film_project,
		_active_film_script
	))
func _release_cast_for_scene_preparation(stage_id: String, phase: String) -> void:
	_get_scene_performance_controller().call(
		"release_cast_for_scene_preparation",
		_active_film_project,
		stage_id,
		phase
	)
func _should_move_stage_employee_off_camera(employee_id: String, performer_ids: Array, crew_ids: Array) -> bool:
	return bool(_get_scene_performance_controller().call(
		"_should_move_stage_employee_off_camera",
		employee_id,
		performer_ids,
		crew_ids
	))
func _move_stage_bystanders_off_camera(stage_id: String, performer_ids: Array) -> bool:
	return bool(_get_scene_performance_controller().call(
		"move_stage_bystanders_off_camera",
		_active_film_project,
		stage_id,
		performer_ids
	))
func _restore_off_camera_staff(stage_id: String) -> void:
	_get_scene_performance_controller().call("restore_off_camera_staff", stage_id)
func is_employee_off_camera(employee_id: String) -> bool:
	return bool(_get_scene_performance_controller().call(
		"is_employee_off_camera",
		employee_id
	))

func _sync_film_set_dressing() -> void:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
	):
		return
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return

	var phase: String = str(_active_film_project.current_phase)
	if phase == "preparation":
		_refresh_film_scene_setup_if_needed()
	if phase not in ["set_dressing", "set_strike"]:
		if (
			not _get_set_logistics_phase().is_empty()
			and _are_set_logistics_tasks_complete()
		):
			_reset_set_logistics()
		return

	var setup: Dictionary = _active_film_project.get_current_scene_setup()
	var scene_key: String = _get_set_logistics_scene_key(phase, setup)
	if scene_key != _get_current_set_logistics_scene_key():
		if (
			not _get_set_logistics_phase().is_empty()
			and not _are_set_logistics_tasks_complete()
		):
			return
		_reset_set_logistics()
		_begin_set_logistics(phase, setup, stage_id, scene_key)

	_process_set_logistics_tasks(stage_id)
	if (
		phase == "set_strike"
		and _are_set_logistics_tasks_complete()
		and _set_inventory.call("get_props_on_stage").is_empty()
	):
		_manager.call("clear_scene_set_dressing", stage_id)
func _get_cast_production_task(phase: String, scene_number: int) -> String:
	return str(_get_scene_performance_controller().call(
		"get_cast_production_task",
		phase,
		scene_number
	))
func _get_scene_actor_action(phase: String, scene: Dictionary, is_speaker: bool) -> String:
	return str(_get_scene_performance_controller().call(
		"get_scene_actor_action",
		phase,
		scene,
		is_speaker
	))

func _build_film_performance_snapshot() -> Dictionary:
	var performer_ids: Array = _film_production_system.call(
		"get_scene_performer_ids",
		_active_film_script,
		_active_film_project
	)
	var background_ids: Array[String] = (
		_active_film_project.background_performer_ids
	)
	var acting_total: float = 0.0
	var acting_count: int = 0
	var background_acting_total: float = 0.0
	var background_acting_count: int = 0
	for employee_id_value in performer_ids:
		var employee_id: String = str(employee_id_value)
		var employee: Variant = _find_employee(employee_id)
		if employee == null:
			continue
		if background_ids.has(employee_id):
			background_acting_total += float(employee.skills.get("acting", 45.0))
			background_acting_count += 1
		else:
			acting_total += float(employee.skills.get("acting", 45.0))
			acting_count += 1

	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	var director: Variant = _find_employee(
		str(crew_assignments.get("director", ""))
	)
	var camera_operator: Variant = _find_employee(
		str(crew_assignments.get("camera_operator", ""))
	)
	var producer: Variant = _find_employee(
		str(crew_assignments.get("producer", ""))
	)

	var technical_total: float = 0.0
	var technical_count: int = 0
	for role_id in FILM_CREW_CATALOG_SCRIPT.FILM_TECHNICIAN_ROLE_IDS:
		var technician_id: String = str(crew_assignments.get(role_id, ""))
		var technician: Variant = _find_employee(technician_id)
		if technician == null:
			continue
		technical_total += float(technician.skills.get("technical", 45.0))
		technical_count += 1

	var lighting_technician: Variant = _find_employee(
		str(crew_assignments.get("lighting_technician", ""))
	)
	var sound_technician: Variant = _find_employee(
		str(crew_assignments.get("sound_technician", ""))
	)
	var production_designer: Variant = _find_employee(
		str(crew_assignments.get("production_designer", ""))
	)
	var costume_designer: Variant = _find_employee(
		str(crew_assignments.get("costume_designer", ""))
	)
	var makeup_artist: Variant = _find_employee(
		str(crew_assignments.get("makeup_artist", ""))
	)

	var participants: Array[String] = []
	for employee_id_value in performer_ids:
		var employee_id: String = str(employee_id_value)
		if not employee_id.is_empty() and not participants.has(employee_id):
			participants.append(employee_id)
	for employee_id_value in crew_assignments.values():
		var employee_id: String = str(employee_id_value)
		if not employee_id.is_empty() and not participants.has(employee_id):
			participants.append(employee_id)

	var energy_total: float = 0.0
	var morale_total: float = 0.0
	var stress_total: float = 0.0
	var condition_count: int = 0
	for employee_id in participants:
		var employee: Variant = _find_employee(employee_id)
		if employee == null:
			continue
		energy_total += float(employee.needs.get("energy", 0.75))
		morale_total += float(employee.needs.get("morale", 0.75))
		stress_total += float(employee.needs.get("stress", 0.15))
		condition_count += 1

	var divisor: float = float(maxi(condition_count, 1))
	return {
		"acting_average": (
			acting_total / float(maxi(acting_count, 1))
			if acting_count > 0 else 45.0
		),
		"background_acting": (
			background_acting_total / float(maxi(background_acting_count, 1))
			if background_acting_count > 0 else 45.0
		),
		"directing": (
			float(director.skills.get("directing", 45.0))
			if director != null else 45.0
		),
		"camera_work": (
			float(camera_operator.skills.get("camera_work", 45.0))
			if camera_operator != null else 45.0
		),
		"technical": (
			technical_total / float(maxi(technical_count, 1))
			if technical_count > 0 else 45.0
		),
		"lighting": (
			float(lighting_technician.skills.get("lighting", 45.0))
			if lighting_technician != null else 45.0
		),
		"sound": (
			float(sound_technician.skills.get("sound", 45.0))
			if sound_technician != null else 45.0
		),
		"set_design": (
			float(production_designer.skills.get("set_design", 45.0))
			if production_designer != null else 45.0
		),
		"costume_design": (
			float(costume_designer.skills.get("costume_design", 45.0))
			if costume_designer != null else 45.0
		),
		"makeup": (
			float(makeup_artist.skills.get("makeup", 45.0))
			if makeup_artist != null else 45.0
		),
		"management": (
			float(producer.skills.get("management", 45.0))
			if producer != null else 45.0
		),
		"energy": energy_total / divisor,
		"morale": morale_total / divisor,
		"stress": stress_total / divisor,
	}

func _award_employee_skill_experience(
	employee_id: String,
	skill_id: String,
	amount: float
) -> void:
	if amount <= 0.0 or _skill_progression_system == null:
		return
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return
	_skill_progression_system.call(
		"award_skill_experience",
		employee,
		skill_id,
		amount
	)

func _award_film_skill_progression(
	phase: String,
	phase_duration_minutes: int
) -> void:
	if _active_film_project == null:
		return
	var normalized_duration: int = maxi(phase_duration_minutes, 1)
	var performers: Array = _film_production_system.call(
		"get_scene_performer_ids",
		_active_film_script,
		_active_film_project
	)
	if phase == "rehearsal" or phase == "shooting":
		for employee_id_value in performers:
			var employee_id: String = str(employee_id_value)
			_award_phase_skill_experience(
				employee_id,
				"acting",
				2.0 if phase == "rehearsal" else 1.2,
				normalized_duration
			)
			_award_phase_skill_experience(
				employee_id,
				"movement",
				0.35 if phase == "rehearsal" else 0.15,
				normalized_duration
			)
			if phase == "rehearsal":
				_award_phase_skill_experience(
					employee_id, "improvisation", 0.35, normalized_duration
				)
				_award_phase_skill_experience(
					employee_id, "diction", 0.30, normalized_duration
				)

	var crew: Dictionary = _active_film_project.crew_assignments
	for role_id in FILM_CREW_CATALOG_SCRIPT.FILM_CREW_ROLE_CONFIG:
		var crew_role_id: String = str(role_id.get("id", ""))
		var employee_id: String = str(crew.get(crew_role_id, ""))
		if employee_id.is_empty():
			continue
		match crew_role_id:
			"director":
				if phase == "rehearsal":
					_award_phase_skill_experience(
						employee_id, "actor_direction", 1.0, normalized_duration
					)
					_award_phase_skill_experience(
						employee_id, "directing", 0.5, normalized_duration
					)
				elif phase == "shooting" or phase == "review":
					_award_phase_skill_experience(
						employee_id, "directing", 0.5, normalized_duration
					)
			"camera_operator":
				if phase == "rehearsal":
					_award_phase_skill_experience(
						employee_id, "composition", 0.25, normalized_duration
					)
				elif phase == "shooting":
					_award_phase_skill_experience(
						employee_id, "camera_work", 1.0, normalized_duration
					)
					_award_phase_skill_experience(
						employee_id, "composition", 0.4, normalized_duration
					)
				elif phase == "review":
					_award_phase_skill_experience(
						employee_id, "camera_work", 0.25, normalized_duration
					)
			"technician", "technician_assistant_1", "technician_assistant_2":
				if phase == "set_dressing":
					_award_phase_skill_experience(
						employee_id, "technical", 0.75, normalized_duration
					)
					_award_phase_skill_experience(
						employee_id, "prop_design", 0.35, normalized_duration
					)
				elif phase == "shooting":
					_award_phase_skill_experience(
						employee_id, "technical", 0.3, normalized_duration
					)
				elif phase == "set_strike":
					_award_phase_skill_experience(
						employee_id, "technical", 0.4, normalized_duration
					)
			"lighting_technician":
				if phase == "set_dressing":
					_award_phase_skill_experience(
						employee_id, "lighting", 0.3, normalized_duration
					)
				elif phase == "shooting":
					_award_phase_skill_experience(
						employee_id, "lighting", 0.75, normalized_duration
					)
			"sound_technician":
				if phase == "shooting":
					_award_phase_skill_experience(
						employee_id, "sound", 0.75, normalized_duration
					)
			"equipment_technician":
				if phase == "set_dressing":
					_award_phase_skill_experience(
						employee_id, "equipment", 0.5, normalized_duration
					)
				elif phase == "shooting":
					_award_phase_skill_experience(
						employee_id, "equipment", 0.25, normalized_duration
					)
			"production_designer":
				if phase == "set_dressing":
					_award_phase_skill_experience(
						employee_id, "set_design", 0.9, normalized_duration
					)
				elif phase == "shooting":
					_award_phase_skill_experience(
						employee_id, "set_design", 0.2, normalized_duration
					)
			"costume_designer":
				if phase == "rehearsal" or phase == "shooting":
					_award_phase_skill_experience(
						employee_id, "costume_design", 0.35, normalized_duration
					)
			"makeup_artist":
				if phase == "rehearsal" or phase == "shooting":
					_award_phase_skill_experience(
						employee_id, "makeup", 0.35, normalized_duration
					)
			"producer":
				if phase == "review":
					_award_phase_skill_experience(
						employee_id, "management", 0.4, normalized_duration
					)
				else:
					_award_phase_skill_experience(
						employee_id, "management", 0.15, normalized_duration
					)

func _award_phase_skill_experience(
	employee_id: String,
	skill_id: String,
	phase_total_experience: float,
	phase_duration_minutes: int
) -> void:
	if phase_total_experience <= 0.0:
		return
	_award_employee_skill_experience(
		employee_id,
		skill_id,
		phase_total_experience / float(maxi(phase_duration_minutes, 1))
	)

func _apply_film_crew_actions() -> void:
	if _active_film_project == null:
		return
	var phase: String = str(_active_film_project.current_phase)
	var scene_number: int = int(_active_film_project.current_scene_index) + 1
	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	var task_by_role: Dictionary = {
		"director": "Руководит сценой %d" % scene_number,
		"camera_operator": "Снимает сцену %d" % scene_number,
		"technician": "Обслуживает оборудование сцены %d" % scene_number,
		"producer": "Координирует съёмки фильма",
		"lighting_technician": "Настраивает свет сцены %d" % scene_number,
		"sound_technician": "Настраивает звук сцены %d" % scene_number,
		"equipment_technician": "Проверяет оборудование сцены %d" % scene_number,
		"technician_assistant_1": "Помогает техникам на сцене %d" % scene_number,
		"technician_assistant_2": "Помогает техникам на сцене %d" % scene_number,
		"production_designer": "Отвечает за оформление сцены %d" % scene_number,
		"costume_designer": "Готовит костюмы актёров",
		"makeup_artist": "Готовит грим актёров",
	}
	var action_by_role: Dictionary = {
		"director": "directing",
		"camera_operator": "operating_camera",
		"technician": "checking_equipment",
		"producer": "coordinating",
		"lighting_technician": "checking_equipment",
		"sound_technician": "checking_equipment",
		"equipment_technician": "checking_equipment",
		"technician_assistant_1": "checking_equipment",
		"technician_assistant_2": "checking_equipment",
		"production_designer": "checking_equipment",
		"costume_designer": "reviewing",
		"makeup_artist": "reviewing",
	}
	if phase == "set_dressing":
		var setup: Dictionary = _active_film_project.get_current_scene_setup()
		var raw_props: Variant = setup.get("prop_ids", [])
		var has_props: bool = raw_props is Array and not raw_props.is_empty()
		for role_id in [
			"technician",
			"technician_assistant_1",
			"technician_assistant_2",
			"production_designer",
		]:
			task_by_role[role_id] = (
				"Расставляет декорации сцены %d" % scene_number
				if has_props
				else "Готовит нейтральную площадку сцены %d" % scene_number
			)
			action_by_role[role_id] = (
				"placing_set_piece" if has_props else "checking_equipment"
			)
	elif phase == "review":
		task_by_role["director"] = "Просматривает дубль сцены %d" % scene_number
		task_by_role["camera_operator"] = "Проверяет снятый материал"
		action_by_role["director"] = "reviewing"
		action_by_role["camera_operator"] = "reviewing"
	elif phase == "preparation":
		task_by_role["director"] = "Готовит постановку сцены %d" % scene_number
		task_by_role["camera_operator"] = "Выставляет кадр сцены %d" % scene_number
		action_by_role["technician"] = "checking_equipment"

	for role_config in FILM_CREW_CATALOG_SCRIPT.FILM_CREW_ROLE_CONFIG:
		var role_id: String = str(role_config.get("id", ""))
		var employee_id: String = str(crew_assignments.get(role_id, ""))
		if employee_id.is_empty():
			continue
		_character_manager.call(
			"set_employee_task",
			employee_id,
			str(task_by_role.get(role_id, "Работает над фильмом"))
		)
		_character_manager.call(
			"set_employee_production_action",
			employee_id,
			str(action_by_role.get(role_id, ""))
		)

	var cast_participant_ids: Array[String] = []
	for cast_employee_id_value in _active_film_project.cast_assignments.values():
		var cast_employee_id: String = str(cast_employee_id_value)
		if not cast_employee_id.is_empty() and not cast_participant_ids.has(cast_employee_id):
			cast_participant_ids.append(cast_employee_id)
	for background_employee_id in _active_film_project.background_performer_ids:
		if not cast_participant_ids.has(background_employee_id):
			cast_participant_ids.append(background_employee_id)
	for cast_employee_id in cast_participant_ids:
		_character_manager.call(
			"set_employee_task",
			cast_employee_id,
			"Участвует в съёмках фильма"
		)

func _reset_film_crew_actions() -> void:
	_film_phase_actions_pending = false
	if _active_film_project == null:
		return
	var participant_ids: Array[String] = []
	for crew_employee_id_value in _active_film_project.crew_assignments.values():
		var crew_employee_id: String = str(crew_employee_id_value)
		if (
			not crew_employee_id.is_empty()
			and not participant_ids.has(crew_employee_id)
		):
			participant_ids.append(crew_employee_id)
	for cast_employee_id_value in _active_film_project.cast_assignments.values():
		var cast_employee_id: String = str(cast_employee_id_value)
		if (
			not cast_employee_id.is_empty()
			and not participant_ids.has(cast_employee_id)
		):
			participant_ids.append(cast_employee_id)
	for background_employee_id in _active_film_project.background_performer_ids:
		if not background_employee_id.is_empty() and not participant_ids.has(background_employee_id):
			participant_ids.append(background_employee_id)
	for participant_id in participant_ids:
		if _find_employee(participant_id) == null:
			continue
		_character_manager.call("clear_employee_task", participant_id)
		_character_manager.call(
			"set_employee_production_action",
			participant_id,
			""
		)

func _format_set_prop_titles(prop_ids: Array) -> String:
	var titles: Array[String] = []
	for prop_id_value in prop_ids:
		var prop_id: String = str(prop_id_value)
		var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(prop_id)
		titles.append(str(definition.get("title", prop_id)))
	return ", ".join(titles)

func _get_script_set_dressing_preview(script: Variant) -> Dictionary:
	if script == null:
		return {}
	var scene_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		script.scenes,
		_set_inventory.get_owned_prop_ids(),
		str(script.genre_id)
	)
	var missing_lookup: Dictionary = {}
	var fully_dressed_scene_count: int = 0
	for setup in scene_setups:
		var missing_prop_ids: Array = setup.get("missing_prop_ids", [])
		if missing_prop_ids.is_empty():
			fully_dressed_scene_count += 1
		for prop_id_value in missing_prop_ids:
			missing_lookup[str(prop_id_value)] = true
	var missing_prop_ids: Array[String] = []
	for prop_id_value in missing_lookup.keys():
		missing_prop_ids.append(str(prop_id_value))
	missing_prop_ids.sort()
	return {
		"scene_count": scene_setups.size(),
		"fully_dressed_scene_count": fully_dressed_scene_count,
		"missing_prop_ids": missing_prop_ids,
	}

func _update_film_production_ui() -> void:
	if not is_instance_valid(_film_production_status_label):
		return
	if not is_instance_valid(_film_production_progress_bar):
		return
	if not is_instance_valid(_film_production_detail_label):
		return

	if _active_film_project == null:
		_film_production_progress_bar.value = 0.0
		var can_start: bool = _can_start_film_production()
		if _get_latest_script() == null:
			_film_production_status_label.text = "ОЖИДАЕТ ГОТОВЫЙ СЦЕНАРИЙ"
			_film_production_detail_label.text = (
				"Заверши сценарий в сценарном отделе, затем назначь актёров "
				+ "на роли и съёмочную группу."
			)
		elif can_start:
			_film_production_status_label.text = "ГОТОВО К СЪЁМКАМ"
			_film_production_detail_label.text = (
				"Сценарий и команда назначены. Нажми «НАЧАТЬ СЪЁМКИ»: "
				+ "группа сама соберётся на площадке, а фильм пройдёт сцены "
				+ "по общей рабочей смене, с паузами на ночь."
			)
		else:
			var stage_size_message: String = _get_stage_size_requirement_message()
			if not stage_size_message.is_empty():
				_film_production_status_label.text = "НУЖЕН БОЛЕЕ КРУПНЫЙ ПАВИЛЬОН"
				_film_production_detail_label.text = stage_size_message
			else:
				_film_production_status_label.text = "СЪЁМКИ ПОКА НЕДОСТУПНЫ"
				_film_production_detail_label.text = _get_film_production_blocker()
		if _get_latest_script() != null:
			var set_preview: Dictionary = _get_script_set_dressing_preview(
				_get_latest_script()
			)
			var missing_prop_ids: Array = set_preview.get(
				"missing_prop_ids",
				[]
			)
			var set_preview_text: String = (
				"Комплекты декораций: %d/%d сцен полностью обеспечены."
				% [
					int(set_preview.get("fully_dressed_scene_count", 0)),
					int(set_preview.get("scene_count", 0)),
				]
			)
			if not missing_prop_ids.is_empty():
				set_preview_text += (
					"\nНе хватает: %s. Съёмки не блокируются, "
					+ "но отсутствие нужных декораций снизит качество сцен."
				) % _format_set_prop_titles(missing_prop_ids)
			else:
				set_preview_text += "\nВсе необходимые декорации уже куплены."
			_film_production_detail_label.text += "\n\n" + set_preview_text

		if is_instance_valid(_film_production_start_button):
			_film_production_start_button.text = "НАЧАТЬ СЪЁМКИ"
			_film_production_start_button.disabled = not can_start
			_film_production_start_button.tooltip_text = (
				"" if can_start else _get_film_production_blocker()
			)
		return

	var project: Variant = _active_film_project
	_film_production_progress_bar.value = float(project.get_progress_percent())
	if str(project.status) == "in_production":
		var scene: Dictionary = _film_production_system.call(
			"get_current_scene",
			_active_film_script,
			project
		)
		var pause_text: String = str(project.pause_reason)
		_film_production_status_label.text = (
			"ПАУЗА: %s" % pause_text
			if not pause_text.is_empty()
			else "%s · сцена %d / %d · %s" % [
				project.get_status_title(),
				int(project.current_scene_index) + 1,
				int(project.total_scene_count),
				project.get_phase_title(),
			]
		)
		var dialogue: String = str(scene.get("dialogue", ""))
		var setup: Dictionary = project.get_current_scene_setup()
		var setup_props: Array = setup.get("prop_ids", [])
		var required_props: Array = setup.get("required_prop_ids", setup_props)
		var missing_props: Array = setup.get("missing_prop_ids", [])
		var installed_prop_count: int = setup_props.size()
		var phase: String = str(project.current_phase)
		installed_prop_count = 0
		if phase != "preparation":
			for prop_id_value in setup_props:
				if str(_set_inventory.call(
					"get_prop_location",
					str(prop_id_value)
				)) == "on_stage":
					installed_prop_count += 1
		var prop_coverage_text: String = (
			"%d/%d" % [installed_prop_count, required_props.size()]
			if not required_props.is_empty()
			else "не требуется"
		)
		var prop_quality_text: String = "Качество декораций: %d/100" % roundi(
			float(setup.get("set_dressing_quality", 45.0))
		)
		if not missing_props.is_empty():
			prop_quality_text += "\nНе хватает: %s" % _format_set_prop_titles(
				missing_props
			)
			if (
				phase == "set_dressing"
				and int(project.phase_minutes_elapsed) > 0
			) or phase in ["rehearsal", "shooting", "review", "set_strike"]:
				prop_quality_text += (
					"\nНовые покупки будут доступны со следующей сцены."
				)
		_film_production_detail_label.text = (
			"Фильм: %s\nСцена %d: %s · %s\n"
			+ "Декорации: %s · реквизит %s\n%s\n"
			+ "%s\n%s\n"
			+ "Событие: %s\n"
			+ "Этап: %d / %d мин · Прошло: %.1f / %.1f рабочих дней · Осталось: ~%.1f рабочих дней\n"
			+ "Пересъёмок текущей сцены: %d"
		) % [
			str(project.film_title),
			int(scene.get("scene_number", project.current_scene_index + 1)),
			str(scene.get("beat", "")),
			str(scene.get("location", "")),
			str(setup.get("set_title", "Нейтральная площадка")),
			prop_coverage_text,
			prop_quality_text,
			str(scene.get("action", "")),
			dialogue,
			str(project.last_activity_message),
			int(project.phase_minutes_elapsed),
			int(project.phase_duration_minutes),
			float(project.get_elapsed_work_days()),
			float(project.get_estimated_work_days()),
			float(project.get_remaining_work_days()),
			int(project.current_scene_retakes),
		]
		if is_instance_valid(_film_production_start_button):
			_film_production_start_button.text = "СЪЁМКИ ИДУТ"
			_film_production_start_button.disabled = true
	else:
		var result_lines: Array[String] = [
			"Фильм: %s" % str(project.film_title),
			"Итоговое качество: %d / 100" % int(project.final_quality),
			"Снято сцен: %d / %d" % [
				int(project.completed_scene_count),
				int(project.total_scene_count),
			],
			"Сценарный потенциал: %d / 100" % int(project.script_potential_score),
			"Съёмочный период: %.1f рабочих дней" % float(project.get_elapsed_work_days()),
			"Следующий этап: перенеси катушки со съёмочной площадки в монтажный отдел.",
			"Результаты сцен:",
		]
		for scene_result in project.scene_results:
			result_lines.append(
				"Сцена %02d · качество %d/100 · пересъёмок: %d"
				% [
					int(scene_result.get("scene_number", 0)),
					int(scene_result.get("quality", 0)),
					int(scene_result.get("retakes", 0)),
				]
			)
		_film_production_status_label.text = "СТАТУС: СЪЁМКИ ЗАВЕРШЕНЫ"
		_film_production_detail_label.text = "\n".join(result_lines)
		if is_instance_valid(_film_production_start_button):
			var editing_completed: bool = (
				_get_active_editing_project() != null
				and str(_get_active_editing_project().status) == "completed"
			)
			_film_production_start_button.text = (
				"СНЯТЬ ФИЛЬМ ПО НОВОМУ СЦЕНАРИЮ"
				if editing_completed
				else "ОЖИДАЕТСЯ МОНТАЖ"
			)
			var next_film_blocker: String = _get_film_production_blocker()
			_film_production_start_button.disabled = not next_film_blocker.is_empty()
			_film_production_start_button.tooltip_text = next_film_blocker
			if editing_completed and not next_film_blocker.is_empty():
				_film_production_detail_label.text += (
					"\n\nСледующий фильм: %s" % next_film_blocker
				)

func is_employee_in_active_production(employee_id: String) -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or employee_id.is_empty()
	):
		return false
	for assigned_id in _active_film_project.crew_assignments.values():
		if str(assigned_id) == employee_id:
			return true
	for assigned_id in _active_film_project.cast_assignments.values():
		if str(assigned_id) == employee_id:
			return true
	return _active_film_project.background_performer_ids.has(employee_id)

func is_employee_waiting_for_scene(employee_id: String) -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or _active_film_script == null
		or employee_id.is_empty()
	):
		return false
	var is_cast_member: bool = (
		_active_film_project.background_performer_ids.has(employee_id)
	)
	if not is_cast_member:
		for assigned_id in _active_film_project.cast_assignments.values():
			if str(assigned_id) == employee_id:
				is_cast_member = true
				break
	if not is_cast_member:
		return false

	var phase: String = str(_active_film_project.current_phase)
	if phase in ["preparation", "set_dressing"]:
		return true
	if phase in ["rehearsal", "shooting", "review"]:
		var current_performer_ids: Array = _film_production_system.call(
			"get_scene_performer_ids",
			_active_film_script,
			_active_film_project
		)
		return not current_performer_ids.has(employee_id)
	return false

func _get_scene_setup_refresh_key() -> String:
	if _active_film_project == null:
		return ""
	return "%s:%d" % [
		str(_active_film_project.id),
		int(_active_film_project.current_scene_index),
	]

func _refresh_film_scene_setup_if_needed() -> void:
	var refresh_key: String = _get_scene_setup_refresh_key()
	if refresh_key.is_empty() or refresh_key == _last_scene_setup_refresh_key:
		return
	_film_production_system.call(
		"refresh_current_scene_setup",
		_active_film_project,
		_active_film_script,
		_set_inventory.get_owned_prop_ids()
	)
	_last_scene_setup_refresh_key = refresh_key
func _get_stage_technician_ids(crew_assignments: Dictionary) -> Array[String]:
	return _get_assignment_controller().call(
		"get_stage_technician_ids",
		crew_assignments
	)

func _get_set_logistics_scene_key(
	phase: String,
	setup: Dictionary
) -> String:
	var prop_signature: String = ""
	for prop_id_value in setup.get("prop_ids", []):
		if not prop_signature.is_empty():
			prop_signature += ","
		prop_signature += str(prop_id_value)
	return "%s:%s:%s:%s" % [
		phase,
		str(setup.get("scene_id", "")),
		str(setup.get("set_id", "neutral")),
		prop_signature,
	]
