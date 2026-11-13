extends RefCounted
class_name EmployeeRosterPanelController

var _studio_hud: Node
var _on_employee_selected: Callable
var _on_market_toggled: Callable
var _on_market_closed: Callable
var _on_market_candidate_selected: Callable
var _employee_status_provider: Callable

var _roster_header: Label
var _employee_list: VBoxContainer
var _market_toggle_button: Button
var _market_panel: PanelContainer
var _market_header: Label
var _market_status_label: Label
var _market_list: VBoxContainer
var _roster_buttons: Dictionary = {}


func setup(
	studio_hud: Node,
	on_employee_selected: Callable,
	on_market_toggled: Callable,
	on_market_closed: Callable,
	on_market_candidate_selected: Callable,
	employee_status_provider: Callable
) -> void:
	_studio_hud = studio_hud
	_on_employee_selected = on_employee_selected
	_on_market_toggled = on_market_toggled
	_on_market_closed = on_market_closed
	_on_market_candidate_selected = on_market_candidate_selected
	_employee_status_provider = employee_status_provider


func build(
	employees: Array,
	market_candidates: Array,
	selected_employee_id: String,
	days_until_refresh: int
) -> void:
	if _studio_hud == null:
		push_error("EmployeeRosterPanelController: StudioHUD node is missing.")
		return
	var panel := PanelContainer.new()
	panel.name = "EmployeeRosterPanel"
	panel.custom_minimum_size = Vector2(0.0, 0.0)
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
	if _on_market_toggled.is_valid():
		_market_toggle_button.pressed.connect(_on_market_toggled)
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
		add_employee(employee)

	_build_market_panel()
	refresh_roster(employees, selected_employee_id)
	refresh_market_panel(market_candidates, days_until_refresh)


func add_employee(employee: Variant) -> void:
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
	if _on_employee_selected.is_valid():
		button.pressed.connect(_on_employee_selected.bind(employee_id))
	_employee_list.add_child(button)
	_roster_buttons[employee_id] = button


func remove_employee(employee_id: String) -> void:
	var roster_button: Variant = _roster_buttons.get(employee_id)
	if roster_button != null and is_instance_valid(roster_button):
		roster_button.queue_free()
	_roster_buttons.erase(employee_id)


func has_market_panel() -> bool:
	return is_instance_valid(_market_panel)


func refresh_roster(
	employees: Array,
	selected_employee_id: String
) -> void:
	if is_instance_valid(_roster_header):
		_roster_header.text = "СОСТАВ СТУДИИ  ·  %d" % employees.size()

	for employee in employees:
		var employee_id: String = str(employee.id)
		var button: Button = _roster_buttons.get(employee_id) as Button
		if not is_instance_valid(button):
			continue

		var needs: Dictionary = employee.needs
		var work_state_title: String = employee.get_work_state_title()
		if _employee_status_provider.is_valid():
			work_state_title = str(_employee_status_provider.call(employee))
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
		button.button_pressed = employee_id == selected_employee_id


func refresh_market_panel(
	market_candidates: Array,
	days_until_refresh: int
) -> void:
	if not is_instance_valid(_market_list):
		return

	_market_header.text = "КАДРОВЫЙ РЫНОК  ·  %d" % market_candidates.size()
	_market_status_label.text = "Обновление рынка через %d дн." % days_until_refresh

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
		if _on_market_candidate_selected.is_valid():
			button.pressed.connect(
				_on_market_candidate_selected.bind(candidate_id)
			)
		_market_list.add_child(button)

	if is_instance_valid(_market_toggle_button):
		_market_toggle_button.text = "РЫНОК · %d" % market_candidates.size()


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
	close_button.name = "MarketCloseButton"
	close_button.text = "Закрыть"
	if _on_market_closed.is_valid():
		close_button.pressed.connect(_on_market_closed)
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
