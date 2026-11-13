extends RefCounted
class_name FilmProductionAssignmentController

const FILM_CREW_CATALOG_SCRIPT = preload(
	"res://scripts/domain/film_production/film_crew_catalog.gd"
)

var _manager: Node
var _film_production_system: RefCounted
var _detail_layout: VBoxContainer

var _film_cast_assignments: Dictionary = {}
var _film_crew_assignments: Dictionary = {}
var _film_crew_options: Dictionary = {}
var _film_background_performer_ids: Array[String] = []
var _film_background_options: Dictionary = {}
var _cast_assignment_script_id: String = ""
var _film_cast_options: Dictionary = {}
var _bound_active_project_id: String = ""


func setup(manager: Node, film_production_system: RefCounted) -> void:
	_manager = manager
	_film_production_system = film_production_system


func build_controls(detail_layout: VBoxContainer, assigned_staff: Array) -> void:
	_sync_from_active_project_if_needed()
	_detail_layout = detail_layout
	_build_film_crew_assignment_controls(assigned_staff)
	_build_film_cast_assignment_controls(assigned_staff)
	_build_film_background_assignment_controls(assigned_staff)


func build_crew_assignment_controls(
	detail_layout: VBoxContainer,
	assigned_staff: Array
) -> void:
	_sync_from_active_project_if_needed()
	_detail_layout = detail_layout
	_build_film_crew_assignment_controls(assigned_staff)


func build_cast_assignment_controls(
	detail_layout: VBoxContainer,
	assigned_staff: Array
) -> void:
	_sync_from_active_project_if_needed()
	_detail_layout = detail_layout
	_build_film_cast_assignment_controls(assigned_staff)


func build_background_assignment_controls(
	detail_layout: VBoxContainer,
	assigned_staff: Array
) -> void:
	_sync_from_active_project_if_needed()
	_detail_layout = detail_layout
	_build_film_background_assignment_controls(assigned_staff)


func get_film_crew_assignments(assigned_staff: Array) -> Dictionary:
	return _get_film_crew_assignments(assigned_staff)


func get_cast_assignments() -> Dictionary:
	return _film_cast_assignments.duplicate(true)


func get_background_performer_ids() -> Array[String]:
	var result: Array[String] = _film_background_performer_ids.duplicate()
	return result


func get_stage_technician_ids(crew_assignments: Dictionary) -> Array[String]:
	return _get_stage_technician_ids(crew_assignments)


func has_complete_production_assignments(
	crew_assignments: Dictionary,
	cast_assignments: Dictionary,
	assigned_staff: Array
) -> bool:
	return _has_complete_production_assignments(
		crew_assignments,
		cast_assignments,
		assigned_staff
	)


func _get_latest_script() -> Variant:
	if not is_instance_valid(_manager):
		return null
	if _manager.has_method("get_active_film_script"):
		var active_script: Variant = _manager.call("get_active_film_script")
		if active_script != null:
			return active_script
	if _manager.has_method("get_script_for_production"):
		return _manager.call("get_script_for_production")
	return _manager.call("get_latest_script")


func _get_active_film_project() -> Variant:
	if not is_instance_valid(_manager):
		return null
	return _manager.call("get_active_film_project")


func _sync_from_active_project_if_needed() -> void:
	var project: Variant = _get_active_film_project()
	if project == null or str(project.status) != "in_production":
		_bound_active_project_id = ""
		return
	var project_id: String = str(project.id)
	if project_id == _bound_active_project_id:
		return
	_bound_active_project_id = project_id
	_film_crew_assignments = project.crew_assignments.duplicate(true)
	_film_cast_assignments = project.cast_assignments.duplicate(true)
	_film_background_performer_ids = project.background_performer_ids.duplicate()
	_cast_assignment_script_id = str(project.script_id)


func _refresh_production_ui() -> void:
	if is_instance_valid(_manager):
		_manager.call("refresh_film_production_ui")


func _build_film_crew_assignment_controls(assigned_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "СЪЁМОЧНАЯ ГРУППА"
	heading.add_theme_font_size_override("font_size", 14)
	_detail_layout.add_child(heading)

	if _get_active_film_project() != null and str(_get_active_film_project().status) == "in_production":
		var pending_note := Label.new()
		pending_note.text = "Состав можно изменять во время съёмок. Замены вступят в силу при подготовке следующей сцены, без отмены текущего дубля."
		pending_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_layout.add_child(pending_note)

	_film_crew_options.clear()
	var used_employee_ids: Dictionary = {}
	var assignments_locked: bool = false # Changes are staged until a safe scene boundary.

	for role_config in FILM_CREW_CATALOG_SCRIPT.FILM_CREW_ROLE_CONFIG:
		var role_id: String = str(role_config.get("id", ""))
		var role_title: String = str(role_config.get("title", "Позиция"))
		var profession_id: String = str(role_config.get("profession_id", ""))
		var specialization_id: String = str(
			role_config.get("specialization_id", "")
		)
		var skill_id: String = str(role_config.get("skill_id", ""))
		var required: bool = bool(role_config.get("required", false))

		var role_label := Label.new()
		role_label.text = role_title + (" · обязательно" if required else " · по желанию")
		_detail_layout.add_child(role_label)

		var role_option := OptionButton.new()
		role_option.fit_to_longest_item = false
		role_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var empty_index: int = -1
		if not required:
			empty_index = role_option.get_item_count()
			role_option.add_item("— Не назначен —")
			role_option.set_item_metadata(empty_index, "")

		var candidates: Array = []
		for employee in assigned_staff:
			if str(employee.profession_id) != profession_id:
				continue
			if (
				not specialization_id.is_empty()
				and str(employee.specialization_id) != specialization_id
			):
				continue
			var employee_id: String = str(employee.id)
			if employee_id.is_empty() or used_employee_ids.has(employee_id):
				continue
			candidates.append(employee)

		var saved_employee_id: String = str(
			_film_crew_assignments.get(role_id, "")
		)
		var selected_index: int = -1
		for employee in candidates:
			var employee_id: String = str(employee.id)
			var skill_value: int = roundi(
				float(employee.skills.get(skill_id, 0.0))
			)
			var item_index: int = role_option.get_item_count()
			role_option.add_item(
				"%s · мастерство %d/100" % [
					employee.get_full_name(),
					skill_value,
				]
			)
			role_option.set_item_metadata(item_index, employee_id)
			if employee_id == saved_employee_id:
				selected_index = item_index

		if selected_index < 0:
			if required and not candidates.is_empty():
				selected_index = empty_index + 1 if empty_index >= 0 else 0
			elif role_id == "producer" and not candidates.is_empty():
				selected_index = empty_index + 1
			elif empty_index >= 0:
				selected_index = empty_index

		if role_option.get_item_count() == 0:
			role_option.add_item("Нет сотрудника подходящей профессии")
			role_option.set_item_metadata(0, "")
			selected_index = 0
			role_option.disabled = true
		elif selected_index >= 0:
			role_option.select(selected_index)

		var selected_employee_id: String = (
			str(role_option.get_item_metadata(selected_index))
			if selected_index >= 0
			else ""
		)
		_film_crew_assignments[role_id] = selected_employee_id
		if not selected_employee_id.is_empty():
			used_employee_ids[selected_employee_id] = true

		role_option.disabled = role_option.disabled or assignments_locked
		role_option.item_selected.connect(
			_on_film_crew_role_selected.bind(role_id, role_option)
		)
		_film_crew_options[role_id] = role_option
		_detail_layout.add_child(role_option)

func _on_film_crew_role_selected(
	selected_index: int,
	role_id: String,
	role_option: OptionButton
) -> void:
	if selected_index < 0 or selected_index >= role_option.get_item_count():
		return
	var selected_employee_id: String = str(
		role_option.get_item_metadata(selected_index)
	)
	var previous_employee_id: String = str(
		_film_crew_assignments.get(role_id, "")
	)
	if not selected_employee_id.is_empty():
		for other_role_id in _film_crew_assignments.keys():
			if str(other_role_id) == role_id:
				continue
			if str(_film_crew_assignments[other_role_id]) == selected_employee_id:
				for option_index in range(role_option.get_item_count()):
					if str(role_option.get_item_metadata(option_index)) == previous_employee_id:
						role_option.select(option_index)
						break
				return
	_film_crew_assignments[role_id] = selected_employee_id
	_refresh_production_ui()

func _get_max_background_performer_count() -> int:
	if _get_latest_script() == null:
		return FILM_CREW_CATALOG_SCRIPT.MAX_BACKGROUND_PERFORMERS
	return mini(
		FILM_CREW_CATALOG_SCRIPT.MAX_BACKGROUND_PERFORMERS,
		maxi(8 - _get_latest_script().cast.size(), 0)
	)

func _build_film_background_assignment_controls(assigned_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "МАССОВКА"
	heading.add_theme_font_size_override("font_size", 14)
	_detail_layout.add_child(heading)

	var cast_employee_ids: Dictionary = {}
	for employee_id_value in _film_cast_assignments.values():
		cast_employee_ids[str(employee_id_value)] = true

	var available_ids: Dictionary = {}
	var extras: Array = []
	for employee in assigned_staff:
		if str(employee.profession_id) != "extra":
			continue
		var employee_id: String = str(employee.id)
		if employee_id.is_empty() or cast_employee_ids.has(employee_id):
			continue
		available_ids[employee_id] = true
		extras.append(employee)

	var normalized_selection: Array[String] = []
	for employee_id in _film_background_performer_ids:
		if available_ids.has(employee_id) and normalized_selection.size() < _get_max_background_performer_count():
			normalized_selection.append(employee_id)
	_film_background_performer_ids = normalized_selection

	_film_background_options.clear()
	var assignments_locked: bool = false # Changes are staged until a safe scene boundary.
	for employee in extras:
		var employee_id: String = str(employee.id)
		var checkbox := CheckBox.new()
		checkbox.text = "%s · мастерство %d/100" % [
			employee.get_full_name(),
			roundi(float(employee.skills.get("acting", 0.0))),
		]
		checkbox.button_pressed = _film_background_performer_ids.has(employee_id)
		checkbox.disabled = assignments_locked
		checkbox.toggled.connect(
			_on_film_background_performer_toggled.bind(employee_id, checkbox)
		)
		_film_background_options[employee_id] = checkbox
		_detail_layout.add_child(checkbox)

	var note := Label.new()
	note.text = "Выбранные актёры массовки участвуют в каждой сцене (до %d человек)." % _get_max_background_performer_count()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	_detail_layout.add_child(note)

func _on_film_background_performer_toggled(
	enabled: bool,
	employee_id: String,
	checkbox: CheckBox
) -> void:
	if enabled:
		if (
			_film_cast_assignments.values().has(employee_id)
			or _film_background_performer_ids.size() >= _get_max_background_performer_count()
		):
			checkbox.set_pressed_no_signal(false)
			return
		if not _film_background_performer_ids.has(employee_id):
			_film_background_performer_ids.append(employee_id)
	else:
		_film_background_performer_ids.erase(employee_id)
	_refresh_production_ui()

func _build_film_cast_assignment_controls(assigned_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "РАСПРЕДЕЛЕНИЕ РОЛЕЙ"
	heading.add_theme_font_size_override("font_size", 14)
	_detail_layout.add_child(heading)

	var actor_candidates: Array = []
	for employee in assigned_staff:
		if str(employee.profession_id) in ["actor", "extra"]:
			actor_candidates.append(employee)

	_film_cast_options.clear()
	if _get_latest_script() == null:
		return
	if _cast_assignment_script_id != str(_get_latest_script().id):
		_film_cast_assignments.clear()
		_cast_assignment_script_id = str(_get_latest_script().id)

	var used_actor_ids: Dictionary = {}
	for role_index in range(_get_latest_script().cast.size()):
		var cast_member: Dictionary = _get_latest_script().cast[role_index]
		var role_id: String = str(cast_member.get("role_id", ""))
		var role_title: String = str(cast_member.get("role_title", "Роль"))
		var character_name: String = str(
			cast_member.get("character_name", "Персонаж")
		)

		var role_label := Label.new()
		role_label.text = "%s — %s" % [role_title, character_name]
		_detail_layout.add_child(role_label)

		var role_option := OptionButton.new()
		role_option.add_item("— Не назначен —")
		role_option.set_item_metadata(0, "")
		var selected_index: int = -1
		var saved_employee_id: String = str(
			_film_cast_assignments.get(role_id, "")
		)
		for actor_employee in actor_candidates:
			var actor_id: String = str(actor_employee.id)
			var item_index: int = role_option.get_item_count()
			role_option.add_item(
				"%s · %s" % [
					actor_employee.get_full_name(),
					actor_employee.get_profession_title(),
				]
			)
			role_option.set_item_metadata(item_index, actor_id)
			if actor_id == saved_employee_id and not used_actor_ids.has(actor_id):
				selected_index = item_index

		if selected_index < 0:
			for option_index in range(1, role_option.get_item_count()):
				var candidate_id: String = str(
					role_option.get_item_metadata(option_index)
				)
				if not used_actor_ids.has(candidate_id):
					selected_index = option_index
					break
		if selected_index < 0:
			selected_index = 0

		role_option.select(selected_index)
		role_option.disabled = false # A safe preparation boundary applies any changed cast.
		var assigned_actor_id: String = str(
			role_option.get_item_metadata(selected_index)
		)
		_film_cast_assignments[role_id] = assigned_actor_id
		if not assigned_actor_id.is_empty():
			used_actor_ids[assigned_actor_id] = true
		role_option.item_selected.connect(
			_on_film_cast_role_selected.bind(role_id, role_option)
		)
		_film_cast_options[role_id] = role_option
		_detail_layout.add_child(role_option)

	if actor_candidates.size() < _get_latest_script().cast.size():
		var shortage_label := Label.new()
		shortage_label.text = (
			"Не хватает исполнителей для всех ролей: %d из %d."
			% [actor_candidates.size(), _get_latest_script().cast.size()]
		)
		shortage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_layout.add_child(shortage_label)


func _on_film_cast_role_selected(
	selected_index: int,
	role_id: String,
	role_option: OptionButton
) -> void:
	if selected_index < 0 or selected_index >= role_option.get_item_count():
		return
	var selected_employee_id: String = str(
		role_option.get_item_metadata(selected_index)
	)
	var previous_employee_id: String = str(
		_film_cast_assignments.get(role_id, "")
	)
	if not selected_employee_id.is_empty():
		for other_role in _film_cast_assignments.keys():
			var other_role_id: String = str(other_role)
			if other_role_id == role_id:
				continue
			if str(_film_cast_assignments[other_role_id]) != selected_employee_id:
				continue
			_film_cast_assignments[other_role_id] = previous_employee_id
			var other_option: OptionButton = (
				_film_cast_options.get(other_role_id) as OptionButton
			)
			if is_instance_valid(other_option):
				for index in range(other_option.get_item_count()):
					if str(other_option.get_item_metadata(index)) == previous_employee_id:
						other_option.select(index)
						break
			break
	_film_cast_assignments[role_id] = selected_employee_id
	if (
		not selected_employee_id.is_empty()
		and _film_background_performer_ids.has(selected_employee_id)
	):
		_film_background_performer_ids.erase(selected_employee_id)
		var background_option: CheckBox = (
			_film_background_options.get(selected_employee_id) as CheckBox
		)
		if is_instance_valid(background_option):
			background_option.set_pressed_no_signal(false)
	_refresh_production_ui()


func get_assignment_blocker(
	crew_assignments: Dictionary,
	cast_assignments: Dictionary,
	assigned_staff: Array
) -> String:
	var script: Variant = _get_latest_script()
	if script == null:
		return "Нет готового сценария."
	var employees_by_id: Dictionary = {}
	for employee in assigned_staff:
		employees_by_id[str(employee.id)] = employee
	var used_ids: Dictionary = {}
	for role in FILM_CREW_CATALOG_SCRIPT.FILM_CREW_ROLE_CONFIG:
		var role_id: String = str(role.get("id", ""))
		var employee_id: String = str(crew_assignments.get(role_id, ""))
		if employee_id.is_empty():
			if bool(role.get("required", false)):
				return "Не назначен сотрудник: %s." % str(role.get("title", role_id))
			continue
		if not employees_by_id.has(employee_id):
			return "Сотрудник для позиции «%s» не назначен в выбранный павильон." % str(role.get("title", role_id))
		if used_ids.has(employee_id):
			return "Один сотрудник выбран на несколько позиций съёмочной группы."
		var employee: Variant = employees_by_id[employee_id]
		if str(employee.profession_id) != str(role.get("profession_id", "")):
			return "Профессия сотрудника не подходит для позиции «%s»." % str(role.get("title", role_id))
		var specialization: String = str(role.get("specialization_id", ""))
		if not specialization.is_empty() and str(employee.specialization_id) != specialization:
			return "Необходима специализация для позиции «%s»." % str(role.get("title", role_id))
		used_ids[employee_id] = true
	for cast_role in script.cast:
		var role_id: String = str(cast_role.get("role_id", ""))
		var employee_id: String = str(cast_assignments.get(role_id, ""))
		if employee_id.is_empty():
			return "Не назначен актёр на роль «%s»." % str(cast_role.get("role_title", role_id))
		if not employees_by_id.has(employee_id):
			return "Актёр роли «%s» не назначен в выбранный павильон." % str(cast_role.get("role_title", role_id))
		if used_ids.has(employee_id):
			return "Один актёр назначен на несколько ролей или одновременно в съёмочную группу. Распредели роли между разными сотрудниками."
		var actor: Variant = employees_by_id[employee_id]
		if str(actor.profession_id) not in ["actor", "extra"]:
			return "На роль «%s» нужен актёр." % str(cast_role.get("role_title", role_id))
		used_ids[employee_id] = true
	return "Проверь назначение массовки и обязательные позиции съёмочной группы."


func _get_film_crew_assignments(_assigned_staff: Array) -> Dictionary:
	var result: Dictionary = {}
	for role_config in FILM_CREW_CATALOG_SCRIPT.FILM_CREW_ROLE_CONFIG:
		var role_id: String = str(role_config.get("id", ""))
		var employee_id: String = str(
			_film_crew_assignments.get(role_id, "")
		)
		if not employee_id.is_empty():
			result[role_id] = employee_id
	return result

func _has_complete_production_assignments(
	crew_assignments: Dictionary,
	cast_assignments: Dictionary,
	assigned_staff: Array
) -> bool:
	if _get_latest_script() == null:
		return false
	if not bool(
		_film_production_system.call(
			"can_start_project",
			_get_latest_script(),
			crew_assignments,
			cast_assignments
		)
	):
		return false

	var employees_by_id: Dictionary = {}
	for employee in assigned_staff:
		employees_by_id[str(employee.id)] = employee

	var selected_crew_ids: Dictionary = {}
	for role_config in FILM_CREW_CATALOG_SCRIPT.FILM_CREW_ROLE_CONFIG:
		var role_id: String = str(role_config.get("id", ""))
		var employee_id: String = str(crew_assignments.get(role_id, ""))
		if employee_id.is_empty():
			if bool(role_config.get("required", false)):
				return false
			continue
		if not employees_by_id.has(employee_id) or selected_crew_ids.has(employee_id):
			return false
		var employee: Variant = employees_by_id[employee_id]
		if str(employee.profession_id) != str(role_config.get("profession_id", "")):
			return false
		var specialization_id: String = str(
			role_config.get("specialization_id", "")
		)
		if (
			not specialization_id.is_empty()
			and str(employee.specialization_id) != specialization_id
		):
			return false
		selected_crew_ids[employee_id] = true

	var cast_employee_ids: Dictionary = {}
	for employee_id_value in cast_assignments.values():
		var employee_id: String = str(employee_id_value)
		if (
			employee_id.is_empty()
			or not employees_by_id.has(employee_id)
			or selected_crew_ids.has(employee_id)
		):
			return false
		var cast_employee: Variant = employees_by_id[employee_id]
		if str(cast_employee.profession_id) not in ["actor", "extra"]:
			return false
		cast_employee_ids[employee_id] = true

	if _film_background_performer_ids.size() > _get_max_background_performer_count():
		return false
	var unique_background_ids: Dictionary = {}
	for employee_id in _film_background_performer_ids:
		if (
			employee_id.is_empty()
			or not employees_by_id.has(employee_id)
			or selected_crew_ids.has(employee_id)
			or cast_employee_ids.has(employee_id)
			or unique_background_ids.has(employee_id)
		):
			return false
		var background_employee: Variant = employees_by_id[employee_id]
		if str(background_employee.profession_id) != "extra":
			return false
		unique_background_ids[employee_id] = true
	return true

func _get_stage_technician_ids(
	crew_assignments: Dictionary
) -> Array[String]:
	var result: Array[String] = []
	for role_id in FILM_CREW_CATALOG_SCRIPT.FILM_TECHNICIAN_ROLE_IDS:
		var employee_id: String = str(crew_assignments.get(role_id, ""))
		if (
			not employee_id.is_empty()
			and not result.has(employee_id)
			and result.size() < 8
		):
			result.append(employee_id)
	return result
