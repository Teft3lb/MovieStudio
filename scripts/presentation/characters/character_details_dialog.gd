extends Control
class_name CharacterDetailsDialog

const PROFESSION_CATALOG = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)

var _name_label: Label
var _profession_label: Label
var _status_label: Label
var _initials_label: Label
var _biography_label: Label
var _career_goal_label: Label
var _contract_label: Label
var _personality_label: Label
var _metric_values: Dictionary = {}
var _need_values: Dictionary = {}
var _need_bars: Dictionary = {}
var _skill_list: VBoxContainer
var _growth_label: Label
var _modal_panel: PanelContainer


func _ready() -> void:
	name = "CharacterDetailsDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 50
	_build_dialog()


func open_profile(profile_data: Dictionary) -> void:
	_refresh_profile(profile_data)
	visible = true


func refresh_profile(profile_data: Dictionary) -> void:
	if visible:
		_refresh_profile(profile_data)


func close_dialog() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _build_dialog() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "ModalBackdrop"
	backdrop.color = Color(0.018, 0.014, 0.019, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)
	_modal_panel = PanelContainer.new()
	_modal_panel.name = "CharacterProfileWindow"
	_modal_panel.custom_minimum_size = Vector2(760.0, 550.0)
	_modal_panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(_modal_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_modal_panel.add_child(layout)
	_build_header(layout)
	layout.add_child(_make_separator())
	var scroll := ScrollContainer.new()
	scroll.name = "ProfileScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(scroll)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_build_career_column(body)
	_build_skills_column(body)
	layout.add_child(_make_separator())
	_biography_label = Label.new()
	_biography_label.name = "Biography"
	_biography_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_biography_label.add_theme_color_override("font_color", Color(0.83, 0.78, 0.69, 1.0))
	layout.add_child(_biography_label)
	_career_goal_label = Label.new()
	_career_goal_label.name = "CareerGoal"
	_career_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_career_goal_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.42, 1.0))
	layout.add_child(_career_goal_label)


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 13)
	parent.add_child(header)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(68.0, 68.0)
	portrait.add_theme_stylebox_override("panel", _make_portrait_style())
	header.add_child(portrait)
	_initials_label = Label.new()
	_initials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initials_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initials_label.add_theme_font_size_override("font_size", 25)
	_initials_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.57, 1.0))
	portrait.add_child(_initials_label)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 3)
	header.add_child(title_stack)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(0.97, 0.87, 0.68, 1.0))
	title_stack.add_child(_name_label)
	_profession_label = Label.new()
	_profession_label.add_theme_font_size_override("font_size", 13)
	_profession_label.add_theme_color_override("font_color", Color(0.79, 0.68, 0.56, 1.0))
	title_stack.add_child(_profession_label)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.54, 0.77, 0.59, 1.0))
	title_stack.add_child(_status_label)
	var close_button := Button.new()
	close_button.name = "CloseProfileButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38.0, 38.0)
	close_button.pressed.connect(close_dialog)
	header.add_child(close_button)


func _build_career_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(330.0, 0.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	_add_section_heading(column, "КАРЬЕРА И СОСТОЯНИЕ")
	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.add_theme_constant_override("h_separation", 8)
	metrics.add_theme_constant_override("v_separation", 7)
	column.add_child(metrics)
	for metric in [
		["age", "ВОЗРАСТ"],
		["experience", "ОПЫТ"],
		["popularity", "ПОПУЛЯРНОСТЬ"],
		["recognition", "ИЗВЕСТНОСТЬ"],
		["salary", "СТАВКА / ДЕНЬ"],
		["growth", "ПОТЕНЦИАЛ"],
	]:
		_add_metric_card(metrics, str(metric[0]), str(metric[1]))
	_add_section_heading(column, "СОСТОЯНИЕ")
	for need_id in ["energy", "morale", "stress", "fitness"]:
		_add_need_row(column, need_id)


func _build_skills_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	_add_section_heading(column, "ПРОФЕССИОНАЛЬНЫЕ НАВЫКИ")
	_growth_label = Label.new()
	_growth_label.add_theme_font_size_override("font_size", 10)
	_growth_label.add_theme_color_override("font_color", Color(0.72, 0.65, 0.55, 1.0))
	column.add_child(_growth_label)
	_skill_list = VBoxContainer.new()
	_skill_list.add_theme_constant_override("separation", 7)
	column.add_child(_skill_list)
	_add_section_heading(column, "ЛИЧНОСТЬ")
	_personality_label = Label.new()
	_personality_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_personality_label.add_theme_font_size_override("font_size", 11)
	column.add_child(_personality_label)
	_contract_label = Label.new()
	_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contract_label.add_theme_font_size_override("font_size", 10)
	_contract_label.add_theme_color_override("font_color", Color(0.76, 0.68, 0.57, 1.0))
	column.add_child(_contract_label)


func _add_metric_card(parent: GridContainer, metric_id: String, title: String) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(145.0, 55.0)
	card.add_theme_stylebox_override("panel", _make_card_style())
	parent.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	card.add_child(stack)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 9)
	title_label.add_theme_color_override("font_color", Color(0.69, 0.60, 0.49, 1.0))
	stack.add_child(title_label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", Color(0.96, 0.87, 0.70, 1.0))
	stack.add_child(value_label)
	_metric_values[metric_id] = value_label


func _add_need_row(parent: VBoxContainer, need_id: String) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	parent.add_child(stack)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	stack.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 9.0)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.12, 0.085, 0.09, 1.0)))
	var fill_color := Color(0.43, 0.73, 0.55, 1.0)
	if need_id == "stress":
		fill_color = Color(0.78, 0.37, 0.31, 1.0)
	elif need_id == "morale":
		fill_color = Color(0.65, 0.62, 0.83, 1.0)
	elif need_id == "fitness":
		fill_color = Color(0.78, 0.60, 0.30, 1.0)
	bar.add_theme_stylebox_override("fill", _make_bar_style(fill_color))
	stack.add_child(bar)
	_need_values[need_id] = label
	_need_bars[need_id] = bar


func _refresh_profile(data: Dictionary) -> void:
	_name_label.text = str(data.get("name", "Сотрудник"))
	_profession_label.text = str(data.get("profession", ""))
	_status_label.text = str(data.get("status", ""))
	_initials_label.text = str(data.get("initials", "★"))
	_biography_label.text = str(data.get("biography", ""))
	_career_goal_label.text = "ЦЕЛЬ: %s" % str(data.get("career_goal", "Не указана"))
	_personality_label.text = str(data.get("personality", ""))
	_contract_label.text = str(data.get("contract", ""))
	_growth_label.text = "Остаток очков развития: %.0f / %.0f" % [
		float(data.get("growth_remaining", 0.0)),
		float(data.get("growth_total", 0.0)),
	]
	var metric_text: Dictionary = {
		"age": "%d лет" % int(data.get("age", 0)),
		"experience": "%.1f лет" % float(data.get("experience", 0.0)),
		"popularity": "%.0f / 100" % float(data.get("popularity", 0.0)),
		"recognition": "%.0f / 100" % float(data.get("recognition", 0.0)),
		"salary": "%d" % int(data.get("salary", 0)),
		"growth": "%.0f" % float(data.get("growth_remaining", 0.0)),
	}
	for metric_id in _metric_values:
		var label: Label = _metric_values[metric_id] as Label
		label.text = str(metric_text.get(metric_id, "—"))
	var needs: Dictionary = data.get("needs", {})
	for need_id in _need_values:
		var value: float = float(
			data.get("fitness", 0.0)
			if need_id == "fitness"
			else needs.get(need_id, 0.0)
		)
		var visible_need: bool = need_id != "fitness" or bool(data.get("show_fitness", false))
		var label: Label = _need_values[need_id] as Label
		var bar: ProgressBar = _need_bars[need_id] as ProgressBar
		label.visible = visible_need
		bar.visible = visible_need
		label.text = "%s  ·  %.0f%%" % [_need_title(need_id), value]
		bar.value = clampf(value, 0.0, 100.0)
	_refresh_skills(data)


func _refresh_skills(data: Dictionary) -> void:
	for child in _skill_list.get_children():
		_skill_list.remove_child(child)
		child.queue_free()
	var skill_ids: Array[String] = PROFESSION_CATALOG.get_profession_skill_ids(
		str(data.get("profession_id", "")),
		str(data.get("specialization_id", ""))
	)
	var skills: Dictionary = data.get("skills", {})
	var caps: Dictionary = data.get("skill_caps", {})
	for skill_id in skill_ids:
		var value: float = clampf(float(skills.get(skill_id, 0.0)), 0.0, 100.0)
		var cap: float = clampf(float(caps.get(skill_id, 100.0)), 1.0, 100.0)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_skill_list.add_child(row)
		var header := HBoxContainer.new()
		row.add_child(header)
		var title := Label.new()
		title.text = PROFESSION_CATALOG.get_skill_title(skill_id)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 10)
		header.add_child(title)
		var value_label := Label.new()
		value_label.text = "%.0f / %.0f" % [value, cap]
		value_label.add_theme_font_size_override("font_size", 10)
		value_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.48, 1.0))
		header.add_child(value_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0.0, 8.0)
		bar.min_value = 0.0
		bar.max_value = cap
		bar.value = minf(value, cap)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.12, 0.085, 0.09, 1.0)))
		bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.74, 0.56, 0.31, 1.0)))
		row.add_child(bar)


func _add_section_heading(parent: VBoxContainer, text_value: String) -> void:
	var heading := Label.new()
	heading.text = text_value
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color(0.88, 0.68, 0.36, 1.0))
	parent.add_child(heading)


func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_color_override("font_color", Color(0.52, 0.36, 0.20, 0.8))
	return separator


func _need_title(need_id: String) -> String:
	match need_id:
		"energy":
			return "Энергия"
		"morale":
			return "Настроение"
		"stress":
			return "Стресс"
		"fitness":
			return "Физическая форма"
		_:
			return need_id


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.055, 0.061, 0.99)
	style.border_color = Color(0.73, 0.53, 0.28, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(17)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 18
	style.content_margin_left = 18.0
	style.content_margin_top = 16.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 16.0
	return style


func _make_portrait_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.23, 0.15, 0.12, 1.0)
	style.border_color = Color(0.88, 0.66, 0.35, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.105, 0.10, 0.98)
	style.border_color = Color(0.39, 0.28, 0.19, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 9.0
	style.content_margin_top = 7.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 7.0
	return style


func _make_bar_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_corner_radius_all(5)
	return style


func _on_backdrop_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if is_instance_valid(_modal_panel) and _modal_panel.get_global_rect().has_point(
		mouse_event.position
	):
		return
	close_dialog()


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		visible
		and event is InputEventKey
		and (event as InputEventKey).pressed
		and (event as InputEventKey).keycode == KEY_ESCAPE
	):
		close_dialog()
		get_viewport().set_input_as_handled()
