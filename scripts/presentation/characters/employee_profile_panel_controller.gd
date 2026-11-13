extends RefCounted
class_name EmployeeProfilePanelController

var _studio_hud: Node
var _on_contract_type_selected: Callable
var _on_hire_requested: Callable
var _on_dismiss_requested: Callable
var _on_dismiss_confirmed: Callable
var _on_workplace_dispatch_requested: Callable
var _on_workplace_assignment_requested: Callable

var _detail_name_label: Label
var _detail_profession_label: Label
var _detail_biography_label: Label
var _detail_stats_label: Label
var _detail_task_label: Label
var _detail_schedule_label: Label
var _detail_contract_label: Label
var _detail_personality_label: Label
var _contract_type_option: OptionButton
var _hire_button: Button
var _dismiss_button: Button
var _dismiss_dialog: ConfirmationDialog
var _workplace_dispatch_button: Button
var _workplace_assignment_label: Label
var _workplace_assignment_option: OptionButton
var _energy_label: Label
var _energy_bar: ProgressBar
var _morale_label: Label
var _morale_bar: ProgressBar
var _stress_label: Label
var _stress_bar: ProgressBar
var _skill_container: VBoxContainer


func setup(
	on_contract_type_selected: Callable,
	on_hire_requested: Callable,
	on_dismiss_requested: Callable,
	on_dismiss_confirmed: Callable,
	on_workplace_dispatch_requested: Callable,
	on_workplace_assignment_requested: Callable = Callable()
) -> void:
	_on_contract_type_selected = on_contract_type_selected
	_on_hire_requested = on_hire_requested
	_on_dismiss_requested = on_dismiss_requested
	_on_dismiss_confirmed = on_dismiss_confirmed
	_on_workplace_dispatch_requested = on_workplace_dispatch_requested
	_on_workplace_assignment_requested = on_workplace_assignment_requested


func build(studio_hud: Node) -> void:
	if studio_hud == null:
		push_error("EmployeeProfilePanelController: StudioHUD node is missing.")
		return
	_studio_hud = studio_hud

	var panel := PanelContainer.new()
	panel.name = "EmployeeDetailPanel"
	panel.custom_minimum_size = Vector2(0.0, 0.0)
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

	_workplace_dispatch_button = Button.new()
	_workplace_dispatch_button.text = "ВЫЗВАТЬ НА ПЛОЩАДКУ"
	_workplace_dispatch_button.visible = false
	if _on_workplace_dispatch_requested.is_valid():
		_workplace_dispatch_button.pressed.connect(
			_on_workplace_dispatch_requested
		)
	layout.add_child(_workplace_dispatch_button)

	_workplace_assignment_label = Label.new()
	_workplace_assignment_label.text = "НАЗНАЧИТЬ В ЗДАНИЕ"
	_workplace_assignment_label.visible = false
	layout.add_child(_workplace_assignment_label)
	_workplace_assignment_option = OptionButton.new()
	_workplace_assignment_option.fit_to_longest_item = false
	_workplace_assignment_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workplace_assignment_option.visible = false
	_workplace_assignment_option.item_selected.connect(
		_on_workplace_assignment_item_selected
	)
	layout.add_child(_workplace_assignment_option)

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
	if _on_contract_type_selected.is_valid():
		_contract_type_option.item_selected.connect(
			_on_contract_type_selected
		)
	_contract_type_option.visible = false
	layout.add_child(_contract_type_option)

	_hire_button = Button.new()
	_hire_button.text = "НАНЯТЬ СОТРУДНИКА"
	_hire_button.visible = false
	if _on_hire_requested.is_valid():
		_hire_button.pressed.connect(_on_hire_requested)
	layout.add_child(_hire_button)

	_dismiss_button = Button.new()
	_dismiss_button.text = "УВОЛИТЬ СОТРУДНИКА"
	_dismiss_button.visible = false
	if _on_dismiss_requested.is_valid():
		_dismiss_button.pressed.connect(_on_dismiss_requested)
	layout.add_child(_dismiss_button)

	_dismiss_dialog = ConfirmationDialog.new()
	_dismiss_dialog.title = "Подтверждение увольнения"
	if _on_dismiss_confirmed.is_valid():
		_dismiss_dialog.confirmed.connect(_on_dismiss_confirmed)
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

	_skill_container = VBoxContainer.new()
	_skill_container.name = "SkillProgressList"
	_skill_container.add_theme_constant_override("separation", 5)
	layout.add_child(_skill_container)

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

	clear()


func is_built() -> bool:
	return is_instance_valid(_detail_name_label)


func get_skill_container() -> VBoxContainer:
	return _skill_container


func get_selected_contract_type() -> String:
	if not is_instance_valid(_contract_type_option):
		return "permanent"
	var selected_index: int = _contract_type_option.selected
	if selected_index < 0:
		return "permanent"
	return str(_contract_type_option.get_item_metadata(selected_index))


func show_dismiss_confirmation(employee_name: String) -> void:
	if not is_instance_valid(_dismiss_dialog):
		return
	_dismiss_dialog.dialog_text = (
		"Уволить %s?\nКонтракт будет расторгнут, персонаж покинет активный штат."
		% employee_name
	)
	_dismiss_dialog.popup_centered()


func set_workplace_dispatch_state(
	should_show: bool,
	button_text: String = ""
) -> void:
	if not is_instance_valid(_workplace_dispatch_button):
		return
	_workplace_dispatch_button.visible = should_show
	if not button_text.is_empty():
		_workplace_dispatch_button.text = button_text


func _on_workplace_assignment_item_selected(index: int) -> void:
	if not _on_workplace_assignment_requested.is_valid():
		return
	if index < 0 or index >= _workplace_assignment_option.get_item_count():
		return
	_on_workplace_assignment_requested.call(
		str(_workplace_assignment_option.get_item_metadata(index))
	)


func set_workplace_assignment_options(
	choices: Array[Dictionary],
	manual_building_id: String,
	assigned_building_id: String,
	allow_changes: bool
) -> void:
	if not is_instance_valid(_workplace_assignment_option):
		return
	_workplace_assignment_label.visible = true
	_workplace_assignment_option.visible = true
	_workplace_assignment_option.disabled = not allow_changes
	_workplace_assignment_option.clear()
	var automatic_label: String = "Автоматически"
	if not assigned_building_id.is_empty():
		automatic_label += " (текущее: %s)" % assigned_building_id
	_workplace_assignment_option.add_item(automatic_label)
	_workplace_assignment_option.set_item_metadata(0, "")
	var selected_index: int = 0
	for choice in choices:
		var index: int = _workplace_assignment_option.get_item_count()
		_workplace_assignment_option.add_item(str(choice.get("title", "")))
		var building_id: String = str(choice.get("id", ""))
		_workplace_assignment_option.set_item_metadata(index, building_id)
		_workplace_assignment_option.set_item_disabled(
			index, bool(choice.get("disabled", false))
		)
		if building_id == manual_building_id:
			selected_index = index
	_workplace_assignment_option.select(selected_index)


func clear() -> void:
	if not is_built():
		return
	_detail_name_label.text = "ВЫБЕРИ СОТРУДНИКА"
	_detail_profession_label.text = "Выбери сотрудника в списке или открой кадровый рынок."
	_detail_biography_label.text = ""
	_detail_stats_label.text = ""
	_detail_task_label.text = ""
	_detail_schedule_label.text = ""
	_detail_contract_label.text = ""
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
	_workplace_dispatch_button.visible = false
	_workplace_assignment_label.visible = false
	_workplace_assignment_option.visible = false


func refresh(profile_data: Dictionary) -> void:
	if not is_built():
		return
	if not bool(profile_data.get("has_profile", false)):
		clear()
		return

	_detail_name_label.text = str(profile_data.get("name", ""))
	_detail_profession_label.text = str(profile_data.get("profession", ""))
	_detail_biography_label.text = str(profile_data.get("biography", ""))
	_detail_stats_label.text = str(profile_data.get("stats", ""))
	_detail_task_label.text = str(profile_data.get("task", ""))
	_detail_schedule_label.text = str(profile_data.get("schedule", ""))
	_detail_contract_label.text = str(profile_data.get("contract", ""))
	_detail_personality_label.text = str(profile_data.get("personality", ""))

	var needs: Dictionary = profile_data.get("needs", {})
	var energy: float = float(needs.get("energy", 0.0))
	var morale: float = float(needs.get("morale", 0.0))
	var stress: float = float(needs.get("stress", 0.0))
	_energy_label.text = "Энергия  ·  %d%%" % roundi(energy)
	_morale_label.text = "Настроение  ·  %d%%" % roundi(morale)
	_stress_label.text = "Стресс  ·  %d%%" % roundi(stress)
	_energy_bar.value = energy
	_morale_bar.value = morale
	_stress_bar.value = stress

	_contract_type_option.visible = bool(
		profile_data.get("show_contract_type", false)
	)
	_hire_button.visible = bool(profile_data.get("show_hire_button", false))
	_dismiss_button.visible = bool(profile_data.get("show_dismiss_button", false))
	_workplace_dispatch_button.visible = false


func _create_progress_bar(
	parent: VBoxContainer,
	fill_color: Color
) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0.0, 10.0)
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.12, 0.15, 0.17, 1.0)
	background_style.set_corner_radius_all(5)
	progress.add_theme_stylebox_override("background", background_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(5)
	progress.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(progress)
	return progress
