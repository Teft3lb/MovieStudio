extends CanvasLayer

const SECTION_ORDER: Array[String] = [
	"studio",
	"employees",
	"market",
	"developer",
]

var _game_clock: Node
var _root: Control
var _navigation_list: HBoxContainer
var _workspace_heading: Label
var _workspace_content: VBoxContainer
var _inspector_frame: PanelContainer
var _inspector_heading: Label
var _inspector_content: VBoxContainer
var _clock_label: Label
var _speed_label: Label
var _fast_forward_status_label: Label

var _workspace_panels: Dictionary = {}
var _workspace_titles: Dictionary = {}
var _navigation_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _inspector_panels: Dictionary = {}
var _inspector_titles: Dictionary = {}
var _active_workspace_id: String = ""
var _active_inspector_id: String = ""


func _ready() -> void:
	layer = 10
	_build_shell()
	_build_developer_panel()


func setup(game_clock: Node) -> void:
	_game_clock = game_clock
	if not is_instance_valid(_game_clock):
		return

	var minute_callback := Callable(self, "_on_minute_advanced")
	if (
		_game_clock.has_signal("minute_advanced")
		and not _game_clock.is_connected("minute_advanced", minute_callback)
	):
		_game_clock.connect("minute_advanced", minute_callback)

	var fast_forward_callback := Callable(
		self,
		"_on_manual_advance_finished"
	)
	if (
		_game_clock.has_signal("manual_advance_finished")
		and not _game_clock.is_connected(
			"manual_advance_finished",
			fast_forward_callback
		)
	):
		_game_clock.connect(
			"manual_advance_finished",
			fast_forward_callback
		)

	_refresh_clock()


func _build_shell() -> void:
	_root = Control.new()
	_root.name = "StudioHUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _build_ui_theme()
	add_child(_root)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_root.add_child(margin)

	var shell := VBoxContainer.new()
	shell.name = "StudioShell"
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_theme_constant_override("separation", 8)
	margin.add_child(shell)

	var top_bar := PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.custom_minimum_size = Vector2(0.0, 58.0)
	_apply_panel_style(top_bar, 0.96)
	shell.add_child(top_bar)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_row)

	var brand := Label.new()
	brand.text = "MOVIESTUDIO"
	brand.add_theme_font_size_override("font_size", 19)
	brand.add_theme_color_override("font_color", Color(0.72, 0.91, 0.86, 1.0))
	top_row.add_child(brand)

	var edition := Label.new()
	edition.text = "УПРАВЛЕНИЕ КИНОСТУДИЕЙ"
	edition.add_theme_font_size_override("font_size", 10)
	edition.modulate = Color(0.68, 0.72, 0.76, 1.0)
	top_row.add_child(edition)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 16)
	top_row.add_child(_clock_label)

	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 11)
	_speed_label.modulate = Color(0.72, 0.76, 0.79, 1.0)
	top_row.add_child(_speed_label)

	var speed_buttons := HBoxContainer.new()
	speed_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_buttons.add_theme_constant_override("separation", 4)
	top_row.add_child(speed_buttons)
	_add_speed_button(speed_buttons, "Ⅱ", GameClock.SpeedMode.PAUSED)
	_add_speed_button(speed_buttons, "1×", GameClock.SpeedMode.NORMAL)
	_add_speed_button(speed_buttons, "3×", GameClock.SpeedMode.FAST)
	_add_speed_button(speed_buttons, "6×", GameClock.SpeedMode.VERY_FAST)

	var body := HBoxContainer.new()
	body.name = "MainLayout"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	shell.add_child(body)

	var workspace_frame := PanelContainer.new()
	workspace_frame.name = "WorkspacePanel"
	workspace_frame.custom_minimum_size = Vector2(320.0, 0.0)
	workspace_frame.size_flags_horizontal = Control.SIZE_FILL
	_apply_panel_style(workspace_frame, 0.93)
	body.add_child(workspace_frame)

	var workspace_layout := VBoxContainer.new()
	workspace_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workspace_layout.add_theme_constant_override("separation", 8)
	workspace_frame.add_child(workspace_layout)

	_workspace_heading = Label.new()
	_workspace_heading.add_theme_font_size_override("font_size", 17)
	_workspace_heading.add_theme_color_override("font_color", Color(0.82, 0.94, 0.92, 1.0))
	workspace_layout.add_child(_workspace_heading)

	var workspace_separator := HSeparator.new()
	workspace_layout.add_child(workspace_separator)

	_workspace_content = VBoxContainer.new()
	_workspace_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_workspace_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_layout.add_child(_workspace_content)

	_inspector_frame = PanelContainer.new()
	_inspector_frame.name = "ContextInspector"
	var body_spacer := Control.new()
	body_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(body_spacer)

	_inspector_frame.custom_minimum_size = Vector2(330.0, 0.0)
	_inspector_frame.size_flags_horizontal = Control.SIZE_FILL
	_inspector_frame.visible = false
	_apply_panel_style(_inspector_frame, 0.95)
	body.add_child(_inspector_frame)

	var inspector_layout := VBoxContainer.new()
	inspector_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector_layout.add_theme_constant_override("separation", 8)
	_inspector_frame.add_child(inspector_layout)

	var inspector_header_row := HBoxContainer.new()
	inspector_header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector_layout.add_child(inspector_header_row)

	_inspector_heading = Label.new()
	_inspector_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_heading.add_theme_font_size_override("font_size", 17)
	_inspector_heading.add_theme_color_override("font_color", Color(0.82, 0.94, 0.92, 1.0))
	inspector_header_row.add_child(_inspector_heading)

	var close_inspector_button := Button.new()
	close_inspector_button.text = "×"
	close_inspector_button.tooltip_text = "Скрыть панель"
	close_inspector_button.custom_minimum_size = Vector2(30.0, 30.0)
	close_inspector_button.pressed.connect(_on_close_inspector_pressed)
	inspector_header_row.add_child(close_inspector_button)

	inspector_layout.add_child(HSeparator.new())

	_inspector_content = VBoxContainer.new()
	_inspector_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspector_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_layout.add_child(_inspector_content)

	_build_bottom_navigation(shell)


func _build_bottom_navigation(shell: VBoxContainer) -> void:
	var navigation_panel := PanelContainer.new()
	navigation_panel.name = "BottomNavigationPanel"
	navigation_panel.custom_minimum_size = Vector2(0.0, 52.0)
	_apply_panel_style(navigation_panel, 0.98)
	var navigation_style := navigation_panel.get_theme_stylebox(
		"panel"
	) as StyleBoxFlat
	navigation_style.content_margin_top = 4.0
	navigation_style.content_margin_bottom = 4.0
	shell.add_child(navigation_panel)

	var navigation_layout := HBoxContainer.new()
	navigation_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_layout.add_theme_constant_override("separation", 12)
	navigation_panel.add_child(navigation_layout)

	var navigation_heading := Label.new()
	navigation_heading.text = "РАЗДЕЛЫ"
	navigation_heading.add_theme_font_size_override("font_size", 10)
	navigation_heading.add_theme_color_override(
		"font_color",
		Color(0.58, 0.76, 0.79, 1.0)
	)
	navigation_layout.add_child(navigation_heading)

	var divider := VSeparator.new()
	navigation_layout.add_child(divider)

	_navigation_list = HBoxContainer.new()
	_navigation_list.name = "NavigationButtons"
	_navigation_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_navigation_list.add_theme_constant_override("separation", 6)
	navigation_layout.add_child(_navigation_list)

	var navigation_spacer := Control.new()
	navigation_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_layout.add_child(navigation_spacer)

	var footer_label := Label.new()
	footer_label.text = "MOVIESTUDIO  /  MANAGEMENT"
	footer_label.add_theme_font_size_override("font_size", 9)
	footer_label.add_theme_color_override(
		"font_color",
		Color(0.43, 0.61, 0.65, 1.0)
	)
	navigation_layout.add_child(footer_label)


func _build_developer_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "DeveloperToolsPanel"
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "ИНСТРУМЕНТЫ РАЗРАБОТЧИКА"
	heading.add_theme_font_size_override("font_size", 16)
	layout.add_child(heading)

	var description := Label.new()
	description.text = (
		"Тестовая перемотка изменяет игровое время даже при остановленной симуляции."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	layout.add_child(description)

	var fast_forward_buttons := HBoxContainer.new()
	fast_forward_buttons.add_theme_constant_override("separation", 6)
	layout.add_child(fast_forward_buttons)
	_add_fast_forward_button(fast_forward_buttons, "+1 час", 60)
	_add_fast_forward_button(fast_forward_buttons, "+1 день", 24 * 60)
	_add_fast_forward_button(fast_forward_buttons, "+7 дней", 7 * 24 * 60)
	_add_fast_forward_button(fast_forward_buttons, "+30 дней", 30 * 24 * 60)

	_fast_forward_status_label = Label.new()
	_fast_forward_status_label.add_theme_font_size_override("font_size", 11)
	_fast_forward_status_label.modulate = Color(0.72, 0.76, 0.79, 1.0)
	layout.add_child(_fast_forward_status_label)

	register_workspace_panel(
		"developer",
		"Инструменты разработчика",
		panel
	)


func register_workspace_panel(
	section_id: String,
	title: String,
	panel: Control
) -> void:
	if (
		_workspace_content == null
		or panel == null
		or section_id.is_empty()
	):
		return

	if _workspace_panels.has(section_id):
		push_warning("StudioHUD: workspace section already registered: %s" % section_id)
		return

	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.visible = false
	_workspace_content.add_child(panel)
	_workspace_panels[section_id] = panel
	_workspace_titles[section_id] = title

	var navigation_button := Button.new()
	navigation_button.name = "Navigation_%s" % section_id
	navigation_button.text = _get_navigation_label(section_id, title)
	navigation_button.tooltip_text = title
	navigation_button.custom_minimum_size = Vector2(
		64.0 if section_id == "developer" else 112.0,
		34.0
	)
	navigation_button.toggle_mode = true
	navigation_button.pressed.connect(
		_on_navigation_button_pressed.bind(section_id)
	)
	_navigation_list.add_child(navigation_button)
	_navigation_buttons[section_id] = navigation_button
	_sort_navigation_buttons()


func register_inspector_panel(
	owner_id: String,
	title: String,
	panel: Control
) -> void:
	if (
		_inspector_content == null
		or panel == null
		or owner_id.is_empty()
	):
		return

	if _inspector_panels.has(owner_id):
		push_warning("StudioHUD: inspector already registered: %s" % owner_id)
		return

	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.visible = false
	_inspector_content.add_child(panel)
	_inspector_panels[owner_id] = panel
	_inspector_titles[owner_id] = title


func show_workspace_panel(section_id: String) -> void:
	if not _workspace_panels.has(section_id):
		push_warning("StudioHUD: unknown workspace section: %s" % section_id)
		return

	var section_changed: bool = _active_workspace_id != section_id
	for registered_id in _workspace_panels:
		var registered_panel: Control = _workspace_panels[registered_id]
		registered_panel.visible = registered_id == section_id

	_active_workspace_id = section_id
	_workspace_heading.text = str(_workspace_titles.get(section_id, section_id))

	for registered_id in _navigation_buttons:
		var navigation_button: Button = _navigation_buttons[registered_id]
		navigation_button.button_pressed = registered_id == section_id

	if section_changed:
		show_inspector_panel("", false)


func show_inspector_panel(owner_id: String, should_show: bool) -> void:
	for registered_id in _inspector_panels:
		var registered_panel: Control = _inspector_panels[registered_id]
		registered_panel.visible = should_show and registered_id == owner_id

	if not should_show or not _inspector_panels.has(owner_id):
		_active_inspector_id = ""
		_inspector_frame.visible = false
		return

	_active_inspector_id = owner_id
	_inspector_heading.text = str(_inspector_titles.get(owner_id, owner_id))
	_inspector_frame.visible = true


func get_overlay_root() -> Node:
	return self


func _get_navigation_label(section_id: String, fallback_title: String) -> String:
	match section_id:
		"studio":
			return "СТУДИЯ"
		"employees":
			return "ПЕРСОНАЛ"
		"market":
			return "РЫНОК"
		"developer":
			return "DEV"
		_:
			return fallback_title.to_upper()


func _sort_navigation_buttons() -> void:
	var ordered_ids: Array[String] = []
	for section_id in SECTION_ORDER:
		if _navigation_buttons.has(section_id):
			ordered_ids.append(section_id)

	for section_id in _navigation_buttons:
		if not ordered_ids.has(str(section_id)):
			ordered_ids.append(str(section_id))

	for index in range(ordered_ids.size()):
		var navigation_button: Button = _navigation_buttons[ordered_ids[index]]
		_navigation_list.move_child(navigation_button, index)


func _on_navigation_button_pressed(section_id: String) -> void:
	show_workspace_panel(section_id)


func _on_close_inspector_pressed() -> void:
	show_inspector_panel("", false)


func _add_speed_button(
	parent: HBoxContainer,
	button_text: String,
	mode: int
) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(40.0, 34.0)
	button.tooltip_text = "Скорость симуляции: %s" % button_text
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_on_speed_button_pressed.bind(mode))
	parent.add_child(button)
	_speed_buttons[mode] = button


func _on_speed_button_pressed(mode: int) -> void:
	if not is_instance_valid(_game_clock):
		return
	_game_clock.call("set_speed_mode", mode)
	_refresh_clock()


func _add_fast_forward_button(
	parent: HBoxContainer,
	button_text: String,
	minutes: int
) -> void:
	var button := Button.new()
	button.text = button_text
	button.tooltip_text = "Перемотать игровое время на %d минут" % minutes
	button.pressed.connect(_on_fast_forward_button_pressed.bind(minutes))
	parent.add_child(button)


func _on_fast_forward_button_pressed(minutes: int) -> void:
	if is_instance_valid(_game_clock):
		_game_clock.call("advance_minutes", minutes)


func _on_minute_advanced(_day: int, _hour: int, _minute: int) -> void:
	if (
		is_instance_valid(_game_clock)
		and not bool(_game_clock.get("is_manual_fast_forward"))
	):
		_refresh_clock()


func _on_manual_advance_finished(minutes_advanced: int) -> void:
	if is_instance_valid(_fast_forward_status_label):
		_fast_forward_status_label.text = (
			"Перемотано на %d игровых минут." % minutes_advanced
		)
	_refresh_clock()


func _refresh_clock() -> void:
	if not is_instance_valid(_game_clock):
		return
	if is_instance_valid(_clock_label):
		_clock_label.text = str(_game_clock.call("get_clock_text"))
	if is_instance_valid(_speed_label):
		_speed_label.text = str(_game_clock.call("get_speed_text"))
	var active_speed_mode: int = int(_game_clock.get("speed_mode"))
	for mode in _speed_buttons:
		var speed_button: Button = _speed_buttons[mode]
		speed_button.button_pressed = int(mode) == active_speed_mode


func _build_ui_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 14

	ui_theme.set_color("font_color", "Label", Color(0.86, 0.94, 0.93, 1.0))
	ui_theme.set_color("font_color", "Button", Color(0.84, 0.94, 0.92, 1.0))
	ui_theme.set_color("font_hover_color", "Button", Color(0.98, 1.0, 0.98, 1.0))
	ui_theme.set_color("font_pressed_color", "Button", Color(0.92, 1.0, 0.96, 1.0))
	ui_theme.set_color("font_disabled_color", "Button", Color(0.48, 0.62, 0.64, 1.0))
	ui_theme.set_color("font_color", "OptionButton", Color(0.84, 0.94, 0.92, 1.0))
	ui_theme.set_color("font_color", "SpinBox", Color(0.84, 0.94, 0.92, 1.0))
	ui_theme.set_font_size("font_size", "Button", 12)
	ui_theme.set_font_size("font_size", "OptionButton", 12)

	_apply_button_theme(ui_theme, "Button")
	_apply_button_theme(ui_theme, "OptionButton")

	ui_theme.set_stylebox(
		"normal",
		"LineEdit",
		_make_flat_style(
			Color(0.055, 0.12, 0.14, 1.0),
			Color(0.16, 0.35, 0.38, 1.0),
			8,
			0
		)
	)
	ui_theme.set_stylebox(
		"focus",
		"LineEdit",
		_make_flat_style(
			Color(0.06, 0.14, 0.16, 1.0),
			Color(0.34, 0.72, 0.66, 1.0),
			8,
			0
		)
	)
	ui_theme.set_stylebox(
		"panel",
		"PanelContainer",
		_make_flat_style(
			Color(0.045, 0.095, 0.11, 0.97),
			Color(0.15, 0.32, 0.36, 0.98),
			12,
			7
		)
	)
	ui_theme.set_stylebox(
		"panel",
		"PopupPanel",
		_make_flat_style(
			Color(0.055, 0.12, 0.14, 1.0),
			Color(0.22, 0.47, 0.49, 1.0),
			9,
			8
		)
	)
	ui_theme.set_stylebox(
		"panel",
		"PopupMenu",
		_make_flat_style(
			Color(0.055, 0.12, 0.14, 1.0),
			Color(0.22, 0.47, 0.49, 1.0),
			9,
			8
		)
	)
	ui_theme.set_stylebox(
		"background",
		"ProgressBar",
		_make_flat_style(
			Color(0.075, 0.16, 0.18, 1.0),
			Color(0.12, 0.28, 0.31, 1.0),
			6,
			0
		)
	)
	ui_theme.set_stylebox(
		"fill",
		"ProgressBar",
		_make_flat_style(
			Color(0.36, 0.78, 0.65, 1.0),
			Color(0.36, 0.78, 0.65, 1.0),
			6,
			0
		)
	)

	var separator_style := StyleBoxLine.new()
	separator_style.color = Color(0.18, 0.38, 0.41, 0.85)
	separator_style.thickness = 1
	ui_theme.set_stylebox("separator", "HSeparator", separator_style)
	ui_theme.set_stylebox("separator", "VSeparator", separator_style)

	var scroll_track := _make_flat_style(
		Color(0.035, 0.09, 0.105, 0.8),
		Color(0.035, 0.09, 0.105, 0.0),
		5,
		0
	)
	var scroll_grabber := _make_flat_style(
		Color(0.22, 0.48, 0.49, 0.95),
		Color(0.28, 0.60, 0.57, 0.95),
		5,
		0
	)
	var scroll_grabber_hover := _make_flat_style(
		Color(0.34, 0.70, 0.62, 1.0),
		Color(0.48, 0.82, 0.70, 1.0),
		5,
		0
	)
	for scrollbar_type in ["VScrollBar", "HScrollBar"]:
		ui_theme.set_stylebox("scroll", scrollbar_type, scroll_track)
		ui_theme.set_stylebox("grabber", scrollbar_type, scroll_grabber)
		ui_theme.set_stylebox("grabber_highlight", scrollbar_type, scroll_grabber_hover)
		ui_theme.set_stylebox("grabber_pressed", scrollbar_type, scroll_grabber_hover)
	ui_theme.set_constant("scrollbar_width", "VScrollBar", 7)
	ui_theme.set_constant("grabber_min_size", "VScrollBar", 24)
	return ui_theme


func _apply_button_theme(ui_theme: Theme, theme_type: String) -> void:
	ui_theme.set_stylebox(
		"normal",
		theme_type,
		_make_button_style(
			Color(0.075, 0.16, 0.18, 1.0),
			Color(0.16, 0.34, 0.37, 1.0)
		)
	)
	ui_theme.set_stylebox(
		"hover",
		theme_type,
		_make_button_style(
			Color(0.10, 0.22, 0.24, 1.0),
			Color(0.30, 0.63, 0.60, 1.0)
		)
	)
	ui_theme.set_stylebox(
		"pressed",
		theme_type,
		_make_button_style(
			Color(0.13, 0.29, 0.27, 1.0),
			Color(0.43, 0.79, 0.67, 1.0)
		)
	)
	ui_theme.set_stylebox(
		"hover_pressed",
		theme_type,
		_make_button_style(
			Color(0.15, 0.33, 0.30, 1.0),
			Color(0.54, 0.87, 0.74, 1.0)
		)
	)
	ui_theme.set_stylebox(
		"disabled",
		theme_type,
		_make_button_style(
			Color(0.055, 0.11, 0.125, 1.0),
			Color(0.11, 0.23, 0.26, 1.0)
		)
	)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus_style.border_color = Color(0.48, 0.84, 0.72, 0.95)
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(10)
	ui_theme.set_stylebox("focus", theme_type, focus_style)


func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


func _make_flat_style(
	background: Color,
	border: Color,
	radius: int,
	shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _apply_panel_style(panel: PanelContainer, alpha: float) -> void:
	var style := _make_flat_style(
		Color(0.035, 0.085, 0.10, alpha),
		Color(0.15, 0.32, 0.36, 0.98),
		12,
		8
	)
	style.content_margin_left = 12.0
	style.content_margin_top = 11.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 11.0
	panel.add_theme_stylebox_override("panel", style)


func configure_scroll_container(scroll_container: ScrollContainer) -> void:
	if not is_instance_valid(scroll_container):
		return
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.follow_focus = true
	scroll_container.clip_contents = true
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
