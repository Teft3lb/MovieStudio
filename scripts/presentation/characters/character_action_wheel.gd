extends Control
class_name CharacterActionWheel

signal action_selected(action_id: String)

const WHEEL_SIZE: Vector2 = Vector2(560.0, 560.0)
const ACTION_BUTTON_SIZE: Vector2 = Vector2(150.0, 86.0)
const ACTION_RADIUS: float = 174.0
const CENTER: Vector2 = Vector2(280.0, 280.0)

var _center_initials: Label
var _center_name: Label
var _center_profession: Label
var _center_status: Label
var _center_close: Button
var _action_buttons: Array[Button] = []


func _ready() -> void:
	name = "CharacterActionWheel"
	custom_minimum_size = WHEEL_SIZE
	size = WHEEL_SIZE
	pivot_offset = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 35
	_build_center()


func open_for_employee(
	employee_info: Dictionary,
	actions: Array[Dictionary],
	screen_position: Vector2
) -> void:
	_clear_action_buttons()
	_center_initials.text = str(employee_info.get("initials", "★"))
	_center_name.text = str(employee_info.get("name", "Сотрудник"))
	_center_profession.text = str(employee_info.get("profession", ""))
	_center_status.text = str(employee_info.get("status", ""))
	var visible_actions: Array[Dictionary] = []
	for action_index in range(mini(actions.size(), 6)):
		visible_actions.append(actions[action_index])
	var action_count: int = visible_actions.size()
	if action_count > 0:
		for index in range(action_count):
			_create_action_button(visible_actions[index], index, action_count)
	_place_near(screen_position)
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	_clear_action_buttons()


func is_open() -> bool:
	return visible


func get_action_button_count() -> int:
	return _action_buttons.size()


func _build_center() -> void:
	var center_panel := PanelContainer.new()
	center_panel.name = "CharacterCenterCard"
	center_panel.position = CENTER - Vector2(94.0, 76.0)
	center_panel.custom_minimum_size = Vector2(188.0, 152.0)
	center_panel.size = Vector2(188.0, 152.0)
	center_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_panel.add_theme_stylebox_override("panel", _make_center_style())
	add_child(center_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 3)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_panel.add_child(layout)
	_center_initials = Label.new()
	_center_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_initials.add_theme_font_size_override("font_size", 21)
	_center_initials.add_theme_color_override("font_color", Color(0.98, 0.78, 0.43, 1.0))
	layout.add_child(_center_initials)
	_center_name = Label.new()
	_center_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_name.add_theme_font_size_override("font_size", 15)
	_center_name.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1.0))
	layout.add_child(_center_name)
	_center_profession = Label.new()
	_center_profession.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_profession.add_theme_font_size_override("font_size", 11)
	_center_profession.add_theme_color_override("font_color", Color(0.81, 0.75, 0.67, 1.0))
	layout.add_child(_center_profession)
	_center_status = Label.new()
	_center_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center_status.custom_minimum_size = Vector2(150.0, 28.0)
	_center_status.add_theme_font_size_override("font_size", 10)
	_center_status.add_theme_color_override("font_color", Color(0.65, 0.79, 0.68, 1.0))
	layout.add_child(_center_status)
	_center_close = Button.new()
	_center_close.text = "ЗАКРЫТЬ"
	_center_close.custom_minimum_size = Vector2(92.0, 27.0)
	_center_close.add_theme_font_size_override("font_size", 10)
	_center_close.pressed.connect(close)
	layout.add_child(_center_close)


func _create_action_button(
	action: Dictionary,
	index: int,
	action_count: int
) -> void:
	var button := Button.new()
	button.name = "Action_%s" % str(action.get("id", index))
	button.custom_minimum_size = ACTION_BUTTON_SIZE
	button.size = ACTION_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	var is_disabled: bool = bool(action.get("disabled", false))
	button.disabled = is_disabled
	button.tooltip_text = str(action.get("description", ""))
	button.add_theme_stylebox_override("normal", _make_action_style(false, false))
	button.add_theme_stylebox_override("hover", _make_action_style(true, false))
	button.add_theme_stylebox_override("pressed", _make_action_style(true, true))
	button.add_theme_stylebox_override("disabled", _make_disabled_action_style())

	var content := MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 7)
	content.add_theme_constant_override("margin_top", 5)
	content.add_theme_constant_override("margin_right", 7)
	content.add_theme_constant_override("margin_bottom", 5)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(ACTION_BUTTON_SIZE.x - 14.0, 0.0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_label := Label.new()
	icon_label.name = "ActionIconLabel"
	icon_label.text = str(action.get("icon", "✦"))
	icon_label.custom_minimum_size = Vector2(0.0, 26.0)
	icon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override(
		"font_color",
		Color(0.47, 0.42, 0.37, 1.0)
		if is_disabled
		else Color(0.94, 0.73, 0.40, 1.0)
	)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon_label)

	var title_label := Label.new()
	title_label.name = "ActionTitleLabel"
	title_label.text = str(action.get("title", "Действие"))
	title_label.custom_minimum_size = Vector2(ACTION_BUTTON_SIZE.x - 22.0, 30.0)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.57, 0.52, 0.47, 1.0)
		if is_disabled
		else Color(0.95, 0.90, 0.79, 1.0)
	)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title_label)

	content.add_child(stack)
	button.add_child(content)
	button.pressed.connect(_on_action_pressed.bind(str(action.get("id", ""))))
	add_child(button)
	var angle: float = -PI * 0.5 + TAU * float(index) / float(action_count)
	var button_center: Vector2 = CENTER + Vector2(cos(angle), sin(angle)) * ACTION_RADIUS
	button.position = button_center - ACTION_BUTTON_SIZE * 0.5
	_action_buttons.append(button)

func _on_action_pressed(action_id: String) -> void:
	action_selected.emit(action_id)


func _clear_action_buttons() -> void:
	for button in _action_buttons:
		if is_instance_valid(button):
			remove_child(button)
			button.queue_free()
	_action_buttons.clear()


func _place_near(screen_position: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var available_size: Vector2 = Vector2(
		maxf(viewport_size.x - 16.0, 1.0),
		maxf(viewport_size.y - 16.0, 1.0)
	)
	var scale_factor: float = clampf(
		minf(
			available_size.x / WHEEL_SIZE.x,
			available_size.y / WHEEL_SIZE.y
		),
		0.55,
		1.0
	)
	scale = Vector2.ONE * scale_factor
	var rendered_size: Vector2 = WHEEL_SIZE * scale_factor
	var desired: Vector2 = screen_position - rendered_size * 0.5
	var max_x: float = maxf(8.0, viewport_size.x - rendered_size.x - 8.0)
	var max_y: float = maxf(8.0, viewport_size.y - rendered_size.y - 8.0)
	position = Vector2(
		clampf(desired.x, 8.0, max_x),
		clampf(desired.y, 8.0, max_y)
	)


func _draw() -> void:
	draw_circle(CENTER, 236.0, Color(0.035, 0.027, 0.032, 0.92))
	draw_arc(CENTER, 236.0, 0.0, TAU, 120, Color(0.72, 0.51, 0.27, 0.92), 2.0, true)
	draw_arc(CENTER, 126.0, 0.0, TAU, 96, Color(0.54, 0.37, 0.22, 0.78), 1.5, true)
	draw_arc(CENTER, 224.0, 0.0, TAU, 120, Color(0.90, 0.72, 0.43, 0.16), 1.0, true)
	for index in range(6):
		var angle: float = -PI * 0.5 + TAU * float(index) / 6.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(
			CENTER + direction * 130.0,
			CENTER + direction * 143.0,
			Color(0.78, 0.58, 0.31, 0.45),
			1.0,
			true
		)


func _make_center_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.075, 0.078, 0.99)
	style.border_color = Color(0.82, 0.62, 0.32, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 12
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


func _make_disabled_action_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.083, 0.084, 0.96)
	style.border_color = Color(0.25, 0.20, 0.18, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(15)
	style.content_margin_left = 7.0
	style.content_margin_top = 6.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 6.0
	return style


func _make_action_style(hovered: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.48, 0.32, 0.16, 0.99)
		if pressed
		else Color(0.20, 0.14, 0.14, 0.99)
	)
	if hovered:
		style.bg_color = Color(0.34, 0.22, 0.16, 1.0)
	style.border_color = (
		Color(0.98, 0.79, 0.43, 1.0)
		if hovered or pressed
		else Color(0.57, 0.40, 0.24, 0.96)
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 7.0
	style.content_margin_top = 6.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 6.0
	return style
