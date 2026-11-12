extends RefCounted
class_name FilmEditingController

var _manager: Node
var _character_manager: Node
var _film_editing_system: RefCounted
var _game_clock: Node
var _detail_layout: VBoxContainer

var _active_editing_project: Variant
var _film_editing_editor_id: String = ""
var _next_film_editing_sequence: int = 1

var _film_editing_editor_option: OptionButton
var _film_editing_timeline_option: OptionButton
var _film_editing_status_label: Label
var _film_editing_progress_bar: ProgressBar
var _film_editing_detail_label: Label
var _film_editing_create_button: Button
var _film_editing_start_button: Button
var _film_editing_cancel_button: Button
var _film_editing_replacement_option: OptionButton
var _film_editing_replace_button: Button
var _film_editing_move_up_button: Button
var _film_editing_move_down_button: Button


func setup(
	manager: Node,
	character_manager: Node,
	film_editing_system: RefCounted,
	game_clock: Node
) -> void:
	_manager = manager
	_character_manager = character_manager
	_film_editing_system = film_editing_system
	_game_clock = game_clock


func get_active_project() -> Variant:
	return _active_editing_project


func set_active_project(project: Variant) -> void:
	_active_editing_project = project


func get_editor_id() -> String:
	return _film_editing_editor_id


func set_editor_id(editor_id: String) -> void:
	_film_editing_editor_id = editor_id


func is_employee_in_active_editing(employee_id: String) -> bool:
	if (
		_active_editing_project == null
		or employee_id.is_empty()
		or str(_active_editing_project.status) not in ["draft", "in_editing"]
	):
		return false
	return str(_active_editing_project.editor_id) == employee_id


func build_detail(detail_layout: VBoxContainer, assigned_staff: Array) -> void:
	_detail_layout = detail_layout
	_reset_ui_references()
	if not is_instance_valid(_detail_layout):
		return
	_build_film_editing_detail(assigned_staff)


func _get_active_film_project() -> Variant:
	if not is_instance_valid(_manager):
		return null
	return _manager.call("get_active_film_project")


func _find_employee(employee_id: String) -> Variant:
	if not is_instance_valid(_character_manager):
		return null
	var employees: Array = _character_manager.call("get_employees")
	for employee in employees:
		if str(employee.id) == employee_id:
			return employee
	return null


func _reset_ui_references() -> void:
	_film_editing_editor_option = null
	_film_editing_timeline_option = null
	_film_editing_status_label = null
	_film_editing_progress_bar = null
	_film_editing_detail_label = null
	_film_editing_create_button = null
	_film_editing_start_button = null
	_film_editing_cancel_button = null
	_film_editing_replacement_option = null
	_film_editing_replace_button = null
	_film_editing_move_up_button = null
	_film_editing_move_down_button = null


func advance() -> void:
	if _active_editing_project == null:
		return
	if str(_active_editing_project.status) != "in_editing":
		if (
			str(_active_editing_project.status) == "draft"
			and is_instance_valid(_film_editing_start_button)
		):
			_film_editing_start_button.disabled = not _is_film_editor_ready(
				str(_active_editing_project.editor_id)
			)
		return
	var editor_ready: bool = _is_film_editor_ready(
		str(_active_editing_project.editor_id)
	)
	var result: Dictionary = _film_editing_system.call(
		"advance_minute",
		_active_editing_project,
		editor_ready
	)
	_update_film_editing_ui()
	if bool(result.get("completed", false)):
		_manager.call("on_film_editing_completed")


func _is_film_editor_ready(editor_id: String) -> bool:
	var editor: Variant = _find_employee(editor_id)
	if editor == null or str(editor.work_state) != "working":
		return false
	return bool(
		_character_manager.call(
			"is_employee_at_workplace",
			editor_id,
			"editing_suite"
		)
	)


func _build_film_editing_detail(assigned_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "ПОСТПРОДАКШН · МОНТАЖ ФИЛЬМА"
	heading.add_theme_font_size_override("font_size", 14)
	_detail_layout.add_child(heading)

	if _get_active_film_project() == null:
		var empty_label := Label.new()
		empty_label.text = "Готовых съёмок пока нет. Сначала заверши производство фильма в съёмочном павильоне."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_layout.add_child(empty_label)
		return
	if str(_get_active_film_project().status) != "completed":
		var waiting_label := Label.new()
		waiting_label.text = "Монтаж станет доступен после завершения съёмок всех сцен."
		waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_layout.add_child(waiting_label)
		return

	var editor_candidates: Array = []
	for employee in assigned_staff:
		if str(employee.profession_id) == "film_editor":
			editor_candidates.append(employee)

	if _active_editing_project == null:
		var editor_heading := Label.new()
		editor_heading.text = "ОТВЕТСТВЕННЫЙ МОНТАЖЁР"
		_detail_layout.add_child(editor_heading)

		_film_editing_editor_option = OptionButton.new()
		var selected_index: int = -1
		for index in range(editor_candidates.size()):
			var editor: Variant = editor_candidates[index]
			_film_editing_editor_option.add_item(
				"%s · монтаж %d" % [
					editor.get_full_name(),
					roundi(float(editor.skills.get("editing", 0.0))),
				]
			)
			_film_editing_editor_option.set_item_metadata(
				index,
				str(editor.id)
			)
			if str(editor.id) == _film_editing_editor_id:
				selected_index = index
		if selected_index < 0 and not editor_candidates.is_empty():
			selected_index = 0
		if selected_index >= 0:
			_film_editing_editor_option.select(selected_index)
			_film_editing_editor_id = str(
				_film_editing_editor_option.get_item_metadata(selected_index)
			)
		else:
			_film_editing_editor_option.add_item(
				"Нет монтажёра в штате монтажного отдела"
			)
			_film_editing_editor_option.disabled = true
			_film_editing_editor_id = ""
		_film_editing_editor_option.item_selected.connect(
			_on_film_editing_editor_selected.bind(
				_film_editing_editor_option
			)
		)
		_detail_layout.add_child(_film_editing_editor_option)

		var create_note := Label.new()
		create_note.text = "Сначала подготовь проект и проверь порядок сцен. После начала монтажа таймлайн будет заблокирован."
		create_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_layout.add_child(create_note)

		_film_editing_create_button = Button.new()
		_film_editing_create_button.text = "ПОДГОТОВИТЬ МОНТАЖ"
		_film_editing_create_button.disabled = _film_editing_editor_id.is_empty()
		_film_editing_create_button.pressed.connect(
			_on_create_film_editing_project_pressed
		)
		_detail_layout.add_child(_film_editing_create_button)
		return

	var project: Variant = _active_editing_project
	_film_editing_status_label = Label.new()
	_film_editing_status_label.add_theme_font_size_override("font_size", 14)
	_film_editing_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_layout.add_child(_film_editing_status_label)

	_film_editing_progress_bar = ProgressBar.new()
	_film_editing_progress_bar.min_value = 0.0
	_film_editing_progress_bar.max_value = 100.0
	_film_editing_progress_bar.show_percentage = true
	_film_editing_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_layout.add_child(_film_editing_progress_bar)

	_film_editing_detail_label = Label.new()
	_film_editing_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_layout.add_child(_film_editing_detail_label)

	if str(project.status) == "draft":
		_build_film_editing_timeline_controls(project)
		_film_editing_start_button = Button.new()
		_film_editing_start_button.text = "НАЧАТЬ МОНТАЖ"
		_film_editing_start_button.disabled = not _is_film_editor_ready(
			str(project.editor_id)
		)
		_film_editing_start_button.pressed.connect(
			_on_start_film_editing_pressed
		)
		_detail_layout.add_child(_film_editing_start_button)

		_film_editing_cancel_button = Button.new()
		_film_editing_cancel_button.text = "ОТМЕНИТЬ ПОДГОТОВКУ"
		_film_editing_cancel_button.pressed.connect(
			_on_cancel_film_editing_draft_pressed
		)
		_detail_layout.add_child(_film_editing_cancel_button)
	elif str(project.status) == "in_editing":
		var editor_is_assigned: bool = false
		for employee in assigned_staff:
			if str(employee.id) == str(project.editor_id):
				editor_is_assigned = true
				break
		if not editor_is_assigned:
			_build_film_editing_replacement_controls(assigned_staff)

	_update_film_editing_ui()


func _build_film_editing_timeline_controls(project: Variant) -> void:
	var heading := Label.new()
	heading.text = "ТАЙМЛАЙН · ПОРЯДОК СЦЕН"
	heading.add_theme_font_size_override("font_size", 13)
	_detail_layout.add_child(heading)

	_film_editing_timeline_option = OptionButton.new()
	var ordered_scenes: Array = _film_editing_system.call(
		"get_ordered_scene_results",
		project
	)
	for timeline_position in range(ordered_scenes.size()):
		var scene_result: Dictionary = ordered_scenes[timeline_position]
		_film_editing_timeline_option.add_item(
			"%02d · Сцена %02d · %d/100" % [
				timeline_position + 1,
				int(scene_result.get("scene_number", 0)),
				int(scene_result.get("quality", 0)),
			]
		)
	_film_editing_timeline_option.select(0)
	_film_editing_timeline_option.item_selected.connect(
		_on_film_editing_timeline_selected
	)
	_detail_layout.add_child(_film_editing_timeline_option)

	var movement_row := HBoxContainer.new()
	_film_editing_move_up_button = Button.new()
	_film_editing_move_up_button.text = "↑ РАНЬШЕ"
	_film_editing_move_up_button.tooltip_text = (
		"Переместить выбранную сцену на одну позицию раньше в финальном фильме."
	)
	_film_editing_move_up_button.disabled = true
	_film_editing_move_up_button.pressed.connect(
		_on_film_editing_move_scene_pressed.bind(-1)
	)
	movement_row.add_child(_film_editing_move_up_button)

	_film_editing_move_down_button = Button.new()
	_film_editing_move_down_button.text = "↓ ПОЗЖЕ"
	_film_editing_move_down_button.tooltip_text = (
		"Переместить выбранную сцену на одну позицию позже в финальном фильме."
	)
	_film_editing_move_down_button.disabled = ordered_scenes.size() < 2
	_film_editing_move_down_button.pressed.connect(
		_on_film_editing_move_scene_pressed.bind(1)
	)
	movement_row.add_child(_film_editing_move_down_button)
	_detail_layout.add_child(movement_row)

	var timeline_note := Label.new()
	timeline_note.text = (
		"Это меняет порядок сцен в готовом фильме, а не порядок съёмок."
	)
	timeline_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timeline_note.add_theme_font_size_override("font_size", 10)
	_detail_layout.add_child(timeline_note)


func _build_film_editing_replacement_controls(
	assigned_staff: Array
) -> void:
	var note := Label.new()
	note.text = (
		"Назначенный монтажёр больше не работает в этом отделе. "
		+ "Выбери сотрудника для продолжения проекта."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_layout.add_child(note)

	_film_editing_replacement_option = OptionButton.new()
	for employee in assigned_staff:
		if str(employee.profession_id) != "film_editor":
			continue
		_film_editing_replacement_option.add_item(
			"%s · монтаж %d" % [
				employee.get_full_name(),
				roundi(float(employee.skills.get("editing", 0.0))),
			]
		)
		_film_editing_replacement_option.set_item_metadata(
			_film_editing_replacement_option.get_item_count() - 1,
			str(employee.id)
		)
	if _film_editing_replacement_option.get_item_count() > 0:
		_film_editing_replacement_option.select(0)
	else:
		_film_editing_replacement_option.add_item(
			"Нет монтажёров в штате монтажного отдела"
		)
		_film_editing_replacement_option.disabled = true
	_detail_layout.add_child(_film_editing_replacement_option)

	_film_editing_replace_button = Button.new()
	_film_editing_replace_button.text = "ПЕРЕНАЗНАЧИТЬ МОНТАЖЁРА"
	_film_editing_replace_button.disabled = (
		_film_editing_replacement_option.disabled
	)
	_film_editing_replace_button.pressed.connect(
		_on_replace_film_editor_pressed
	)
	_detail_layout.add_child(_film_editing_replace_button)


func _on_replace_film_editor_pressed() -> void:
	if (
		_active_editing_project == null
		or not is_instance_valid(_film_editing_replacement_option)
		or _film_editing_replacement_option.selected < 0
	):
		return
	var editor_id: String = str(
		_film_editing_replacement_option.get_item_metadata(
			_film_editing_replacement_option.selected
		)
	)
	var editor: Variant = _find_employee(editor_id)
	if editor == null:
		return
	if _film_editing_system.call(
		"reassign_editor",
		_active_editing_project,
		editor_id,
		float(editor.skills.get("editing", 0.0))
	):
		_manager.call("refresh_building_detail")


func _on_cancel_film_editing_draft_pressed() -> void:
	if (
		_active_editing_project == null
		or str(_active_editing_project.status) != "draft"
	):
		return
	_active_editing_project = null
	_film_editing_editor_id = ""
	_manager.call("refresh_building_detail")


func _on_film_editing_editor_selected(
	selected_index: int,
	editor_option: OptionButton
) -> void:
	if (
		selected_index < 0
		or selected_index >= editor_option.get_item_count()
	):
		return
	_film_editing_editor_id = str(
		editor_option.get_item_metadata(selected_index)
	)
	if is_instance_valid(_film_editing_create_button):
		_film_editing_create_button.disabled = _film_editing_editor_id.is_empty()


func _on_create_film_editing_project_pressed() -> void:
	if (
		_get_active_film_project() == null
		or str(_get_active_film_project().status) != "completed"
		or _film_editing_editor_id.is_empty()
	):
		return
	var editor: Variant = _find_employee(_film_editing_editor_id)
	if editor == null:
		return
	var editor_shift_hours: int = maxi(
		int(editor.shift_end_hour) - int(editor.shift_start_hour),
		1
	)
	var editor_break_hours: int = maxi(
		int(editor.break_end_hour) - int(editor.break_start_hour),
		0
	)
	var editor_work_minutes_per_day: int = maxi(
		(editor_shift_hours - editor_break_hours) * 60,
		60
	)
	var project_id: String = "EDIT-%04d" % _next_film_editing_sequence
	var project: Variant = _film_editing_system.call(
		"create_project",
		_get_active_film_project(),
		_film_editing_editor_id,
		float(editor.skills.get("editing", 0.0)),
		project_id,
		int(_game_clock.current_day),
		int(_game_clock.current_hour),
		int(_game_clock.current_minute),
		editor_work_minutes_per_day
	)
	if project == null:
		return
	_next_film_editing_sequence += 1
	_active_editing_project = project
	_manager.call("refresh_building_detail")


func _on_film_editing_timeline_selected(selected_index: int) -> void:
	if is_instance_valid(_film_editing_move_up_button):
		_film_editing_move_up_button.disabled = selected_index <= 0
	if is_instance_valid(_film_editing_move_down_button):
		var timeline_size: int = (
			_active_editing_project.timeline_order.size()
			if _active_editing_project != null
			else 0
		)
		_film_editing_move_down_button.disabled = (
			selected_index < 0 or selected_index >= timeline_size - 1
		)


func _on_film_editing_move_scene_pressed(direction: int) -> void:
	if (
		_active_editing_project == null
		or str(_active_editing_project.status) != "draft"
		or not is_instance_valid(_film_editing_timeline_option)
	):
		return
	var from_position: int = _film_editing_timeline_option.selected
	var to_position: int = from_position + direction
	if _film_editing_system.call(
		"move_scene",
		_active_editing_project,
		from_position,
		to_position
	):
		_manager.call("refresh_building_detail")


func _on_start_film_editing_pressed() -> void:
	if _active_editing_project == null:
		return
	if not _is_film_editor_ready(str(_active_editing_project.editor_id)):
		if is_instance_valid(_film_editing_status_label):
			_film_editing_status_label.text = (
				"ОЖИДАНИЕ: монтажёр должен быть на смене и находиться в монтажном отделе."
			)
		return
	if _film_editing_system.call("start_editing", _active_editing_project):
		_manager.call("refresh_building_detail")


func _update_film_editing_ui() -> void:
	if (
		_active_editing_project == null
		or not is_instance_valid(_film_editing_status_label)
		or not is_instance_valid(_film_editing_progress_bar)
		or not is_instance_valid(_film_editing_detail_label)
	):
		return
	var project: Variant = _active_editing_project
	_film_editing_progress_bar.value = float(project.get_progress_percent())
	var editor_name: String = str(project.editor_id)
	var editor: Variant = _find_employee(str(project.editor_id))
	if editor != null:
		editor_name = str(editor.get_full_name())
	if str(project.status) == "draft":
		_film_editing_status_label.text = (
			"ТАЙМЛАЙН ПОДГОТОВЛЕН · %d СЦЕН" % project.scene_results.size()
		)
		_film_editing_detail_label.text = (
			"Фильм: %s\nИсходное качество материала: %d/100\n"
			+ "Монтажёр: %s\nОриентировочное время: %.1f рабочих дней (%d игровых минут)"
		) % [
			str(project.film_title),
			int(project.source_quality),
			editor_name,
			float(project.get_estimated_work_days()),
			int(project.estimated_total_minutes),
		]
	elif str(project.status) == "in_editing":
		var pause_text: String = str(project.pause_reason)
		_film_editing_status_label.text = (
			"ПАУЗА: %s" % pause_text
			if not pause_text.is_empty()
			else "%s · %s" % [
				project.get_status_title(),
				project.get_phase_title(),
			]
		)
		_film_editing_detail_label.text = (
			"Фильм: %s\nЭтап: %s\nПрогресс этапа: %d / %d мин\n"
			+ "Прошло: %.1f / %.1f рабочих дней · Осталось: ~%.1f рабочих дней\n%s"
		) % [
			str(project.film_title),
			project.get_phase_title(),
			int(project.phase_minutes_elapsed),
			int(project.phase_duration_minutes),
			float(project.get_elapsed_work_days()),
			float(project.get_estimated_work_days()),
			float(project.get_remaining_work_days()),
			str(project.last_activity_message),
		]
	else:
		_film_editing_status_label.text = "СТАТУС: ФИЛЬМ СМОНТИРОВАН"
		_film_editing_detail_label.text = (
			"Фильм: %s\nИтоговое качество: %d/100\n"
			+ "Качество исходного материала: %d/100\n"
			+ "Навык монтажёра: %d/100\nСвязность таймлайна: %d/100\n"
			+ "Затрачено: %.1f рабочих дней\nФильм готов к выпуску."
		) % [
			str(project.film_title),
			int(project.final_quality),
			int(project.source_quality),
			roundi(float(project.editor_skill)),
			int(project.continuity_score),
			float(project.get_elapsed_work_days()),
		]
