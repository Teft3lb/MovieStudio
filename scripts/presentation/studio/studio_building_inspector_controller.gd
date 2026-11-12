extends RefCounted
class_name StudioBuildingInspectorController

signal script_generation_requested(
	writer_id: String,
	genre_id: String,
	scene_count: int,
	role_count: int
)

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const PLACEMENT_RULES_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_placement_rules.gd"
)
const SCRIPT_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/script_department/script_generator.gd"
)

var _manager: Node
var _character_manager: Node
var _studio_hud: Node
var _selected_building_id: String = ""

var _detail_panel: PanelContainer
var _detail_layout: VBoxContainer

var _script_writer_option: OptionButton
var _script_genre_option: OptionButton
var _script_scene_count: SpinBox
var _script_role_count: SpinBox
var _script_generate_button: Button
var _script_progress_bar: ProgressBar
var _script_progress_label: Label
var _script_result_label: Label


func setup(manager: Node, character_manager: Node) -> void:
	_manager = manager
	_character_manager = character_manager


func get_selected_building_id() -> String:
	return _selected_building_id


func set_selected_building_id(building_id: String) -> void:
	_selected_building_id = building_id


func build_panel(studio_hud: Node) -> PanelContainer:
	_studio_hud = studio_hud
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "BuildingDetailPanel"
	_detail_panel.custom_minimum_size = Vector2(0.0, 0.0)
	_detail_panel.visible = false
	if not is_instance_valid(_studio_hud):
		push_error("StudioBuildingInspectorController: StudioHUD node is missing.")
		return _detail_panel
	_studio_hud.call(
		"register_inspector_panel",
		"building",
		"Выбранное здание",
		_detail_panel
	)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 0.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_studio_hud.call("configure_scroll_container", scroll)
	_detail_panel.add_child(scroll)

	_detail_layout = VBoxContainer.new()
	_detail_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_layout.add_theme_constant_override("separation", 9)
	scroll.add_child(_detail_layout)
	return _detail_panel


func select_building(building_id: String) -> void:
	_selected_building_id = building_id
	if _get_selected_building() == null:
		_selected_building_id = ""
		hide_inspector()
		return
	if is_instance_valid(_studio_hud):
		_studio_hud.call("show_workspace_panel", "studio")
	refresh_selected_building()
	if is_instance_valid(_studio_hud):
		_studio_hud.call("show_inspector_panel", "building", true)


func hide_inspector() -> void:
	if is_instance_valid(_detail_panel):
		_detail_panel.visible = false
	if is_instance_valid(_studio_hud):
		_studio_hud.call("show_inspector_panel", "building", false)


func _get_selected_building() -> Variant:
	if _selected_building_id.is_empty() or not is_instance_valid(_manager):
		return null
	return _manager.call("get_building_by_id", _selected_building_id)


func _reset_script_ui_references() -> void:
	_script_writer_option = null
	_script_genre_option = null
	_script_scene_count = null
	_script_role_count = null
	_script_generate_button = null
	_script_progress_bar = null
	_script_progress_label = null
	_script_result_label = null


func _on_generate_script_pressed() -> void:
	if (
		not is_instance_valid(_script_writer_option)
		or not is_instance_valid(_script_genre_option)
		or not is_instance_valid(_script_scene_count)
		or not is_instance_valid(_script_role_count)
	):
		return
	if (
		_script_writer_option.disabled
		or _script_writer_option.selected < 0
		or _script_genre_option.selected < 0
	):
		return
	if is_instance_valid(_manager):
		var active_project: Variant = _manager.call("get_active_writing_project")
		if active_project != null and str(active_project.status) == "in_progress":
			return
	var writer_id: String = str(
		_script_writer_option.get_item_metadata(_script_writer_option.selected)
	)
	var genre_id: String = str(
		_script_genre_option.get_item_metadata(_script_genre_option.selected)
	)
	script_generation_requested.emit(
		writer_id,
		genre_id,
		roundi(_script_scene_count.value),
		roundi(_script_role_count.value)
	)


func refresh_selected_building() -> void:
	if not is_instance_valid(_detail_layout):
		return
	_reset_script_ui_references()
	var building: Variant = _get_selected_building()
	if building == null:
		_detail_panel.visible = false
		var studio_hud: Node = _studio_hud
		if studio_hud != null:
			studio_hud.call("show_inspector_panel", "building", false)
		return
	for child in _detail_layout.get_children():
		_detail_layout.remove_child(child)
		child.queue_free()
	_detail_panel.visible = true
	var building_type_id: String = str(building.building_type_id)
	var is_facility: bool = (
		BUILDING_CATALOG_SCRIPT.get_facility_capacity(building_type_id) > 0
	)
	var title := Label.new()
	title.text = str(building.display_name).to_upper()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.78, 0.94, 0.88, 1.0))
	_detail_layout.add_child(title)
	var description := Label.new()
	description.text = BUILDING_CATALOG_SCRIPT.get_description(building_type_id)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.62, 0.77, 0.79, 1.0))
	_detail_layout.add_child(description)
	var footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
		building_type_id,
		float(building.rotation_degrees),
		int(building.stage_size_tier)
	)
	var capacity: int = (
		BUILDING_CATALOG_SCRIPT.get_facility_capacity(building_type_id)
		if is_facility
		else BUILDING_CATALOG_SCRIPT.get_workplace_capacity_for_building(building)
	)
	if BUILDING_CATALOG_SCRIPT.is_sound_stage(building_type_id):
		var stage_note := Label.new()
		var stage_architecture_title: String = ""
		match BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
			int(building.stage_size_tier)
		):
			1:
				stage_architecture_title = "одноэтажная студия с двускатной крышей"
			3:
				stage_architecture_title = "высокий производственный ангар с фермами"
			_:
				stage_architecture_title = "классический прямоугольный павильон"
		stage_note.text = "%s · %s · рабочих мест: %d" % [
			BUILDING_CATALOG_SCRIPT.get_stage_size_title(
				int(building.stage_size_tier)
			),
			stage_architecture_title,
			capacity,
		]
		stage_note.add_theme_font_size_override("font_size", 11)
		stage_note.add_theme_color_override("font_color", Color(0.62, 0.82, 0.78, 1.0))
		_detail_layout.add_child(stage_note)
	var eligible_staff: Array = [] if is_facility else _manager.call("get_eligible_staff_for_building", building_type_id)
	var assigned_staff: Array = (
		_character_manager.call("get_employees_using_facility", str(building.id))
		if is_facility
		else _manager.call("get_assigned_staff_for_building", str(building.id))
	)
	var assigned_names: Array[String] = []
	for employee in assigned_staff:
		assigned_names.append("%s · %s" % [
			employee.get_full_name(),
			_manager.call("get_profession_title", str(employee.profession_id)),
		])
	var stats_grid := GridContainer.new()
	stats_grid.columns = 3
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 6)
	stats_grid.add_theme_constant_override("v_separation", 6)
	_detail_layout.add_child(stats_grid)
	stats_grid.add_child(_create_building_stat_card(
		"МЕСТА" if is_facility else "РАБОЧИЕ МЕСТА",
		str(capacity),
		Color(0.50, 0.86, 0.73, 1.0)
	))
	stats_grid.add_child(_create_building_stat_card(
		"ЗАНЯТО" if is_facility else "НАЗНАЧЕНО",
		"%d / %d" % [assigned_staff.size(), capacity],
		Color(0.50, 0.78, 0.90, 1.0)
	))
	stats_grid.add_child(_create_building_stat_card(
		"УЧАСТОК",
		"%.0f × %.0f м" % [footprint.x, footprint.y],
		Color(0.72, 0.87, 0.84, 1.0)
	))
	var crew_heading := Label.new()
	crew_heading.text = (
		"ПЕРСОНАЛ В ЗДАНИИ · %d" % assigned_staff.size()
		if is_facility
		else "КОМАНДА · %d" % assigned_staff.size()
	)
	crew_heading.add_theme_font_size_override("font_size", 11)
	crew_heading.add_theme_color_override("font_color", Color(0.50, 0.82, 0.74, 1.0))
	_detail_layout.add_child(crew_heading)
	var staff_summary := Label.new()
	staff_summary.text = (
		"\n".join(assigned_names)
		if not assigned_names.is_empty()
		else ("Сейчас здесь никого нет." if is_facility else "Пока никто не назначен.")
	)
	staff_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_layout.add_child(staff_summary)
	if is_facility:
		var facility_note := Label.new()
		facility_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		facility_note.add_theme_font_size_override("font_size", 11)
		facility_note.add_theme_color_override("font_color", Color(0.60, 0.80, 0.78, 1.0))
		match building_type_id:
			"cafeteria":
				facility_note.text = (
					"Сотрудники приходят сюда в свой обеденный перерыв. "
					+ "Во время еды энергия восстанавливается быстрее, а стресс снижается."
				)
			"star_bungalow":
				facility_note.text = (
					"Отдельный домик доступен одному популярному актёру. "
					+ "Сон здесь восстанавливает энергию и снижает стресс быстрее."
				)
			"fitness_center":
				facility_note.text = (
					"Актёры посещают зал с 17:00 до 19:00. "
					+ "Тренировки постепенно повышают физическую форму, "
					+ "но расходуют энергию. Одновременно тренируются до четырёх человек."
				)
			"studio_lounge":
				facility_note.text = (
					"Сотрудники приходят сюда с 19:00 до 21:00. "
					+ "Общение снижает стресс, улучшает настроение и укрепляет "
					+ "взаимоотношения между присутствующими."
				)
			_:
				facility_note.text = (
					"После окончания смены сотрудники занимают свободные спальные места. "
					+ "Сон ускоряет восстановление энергии и снижает стресс."
				)
		_detail_layout.add_child(facility_note)
		_apply_inspector_width_constraints(_detail_layout)
		return
	var eligible_summary := Label.new()
	eligible_summary.text = "Ещё подходят по профессии: %d" % eligible_staff.size()
	eligible_summary.add_theme_font_size_override("font_size", 10)
	eligible_summary.add_theme_color_override("font_color", Color(0.58, 0.76, 0.79, 1.0))
	_detail_layout.add_child(eligible_summary)
	if building_type_id == "script_department":
		_build_script_department_detail(assigned_staff)
	elif building_type_id == "sound_stage":
		_manager.call("build_film_production_detail", _detail_layout, assigned_staff)
	elif building_type_id == "tv_studio":
		_build_tv_studio_detail(eligible_staff)
	elif building_type_id == "editing_suite":
		_manager.call("build_film_editing_detail", _detail_layout, assigned_staff)
	_apply_inspector_width_constraints(_detail_layout)


func _apply_inspector_width_constraints(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.custom_minimum_size.x = 0.0
		elif child is OptionButton:
			_configure_compact_option_button(child as OptionButton)
		elif child is SpinBox:
			var spin_box := child as SpinBox
			spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin_box.custom_minimum_size.x = 0.0
		elif child is Container:
			var container := child as Container
			container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_inspector_width_constraints(child)


func _create_building_stat_card(
	caption: String,
	value: String,
	value_color: Color
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.15, 0.17, 1.0)
	style.border_color = Color(0.16, 0.36, 0.38, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	card.add_child(content)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", 9)
	caption_label.add_theme_color_override(
		"font_color",
		Color(0.60, 0.77, 0.78, 1.0)
	)
	content.add_child(caption_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", value_color)
	content.add_child(value_label)
	return card


func _configure_compact_option_button(option: OptionButton) -> void:
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(0.0, 0.0)
	option.fit_to_longest_item = false


func _build_script_department_detail(eligible_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "СОЗДАНИЕ СЦЕНАРИЯ"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.48, 0.82, 0.72, 1.0))
	_detail_layout.add_child(heading)

	var writer_heading := Label.new()
	writer_heading.text = "Сценарист"
	_detail_layout.add_child(writer_heading)

	_script_writer_option = OptionButton.new()
	var writer_count: int = 0
	for employee in eligible_staff:
		if str(employee.profession_id) != "screenwriter":
			continue
		_script_writer_option.add_item(
			"%s · %d/100" % [
				employee.get_full_name(),
				roundi(float(employee.skills.get("writing", 0.0))),
			]
		)
		_script_writer_option.set_item_metadata(
			_script_writer_option.get_item_count() - 1,
			str(employee.id)
		)
		writer_count += 1
	if writer_count == 0:
		_script_writer_option.add_item("Нет сценариста в штате")
		_script_writer_option.disabled = true
	else:
		_script_writer_option.select(0)
	_detail_layout.add_child(_script_writer_option)

	var genre_heading := Label.new()
	genre_heading.text = "Жанр"
	_detail_layout.add_child(genre_heading)

	_script_genre_option = OptionButton.new()
	for genre_id in SCRIPT_GENERATOR_SCRIPT.get_genre_ids():
		_script_genre_option.add_item(
			SCRIPT_GENERATOR_SCRIPT.get_genre_title(genre_id)
		)
		_script_genre_option.set_item_metadata(
			_script_genre_option.get_item_count() - 1,
			genre_id
		)
	_script_genre_option.select(0)
	_detail_layout.add_child(_script_genre_option)

	var parameters_row := HBoxContainer.new()
	_detail_layout.add_child(parameters_row)

	var scenes_column := VBoxContainer.new()
	scenes_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parameters_row.add_child(scenes_column)
	var scenes_label := Label.new()
	scenes_label.text = "Сцен"
	scenes_column.add_child(scenes_label)
	_script_scene_count = SpinBox.new()
	_script_scene_count.min_value = 3
	_script_scene_count.max_value = 20
	_script_scene_count.step = 1
	_script_scene_count.value = 8
	_script_scene_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_scene_count.custom_minimum_size = Vector2(0.0, 0.0)
	scenes_column.add_child(_script_scene_count)

	var roles_column := VBoxContainer.new()
	roles_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parameters_row.add_child(roles_column)
	var roles_label := Label.new()
	roles_label.text = "Ролей"
	roles_column.add_child(roles_label)
	_script_role_count = SpinBox.new()
	_script_role_count.min_value = 1
	_script_role_count.max_value = 8
	_script_role_count.step = 1
	_script_role_count.value = 3
	_script_role_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_role_count.custom_minimum_size = Vector2(0.0, 0.0)
	roles_column.add_child(_script_role_count)

	_script_generate_button = Button.new()
	_script_generate_button.text = "НАЧАТЬ НАПИСАНИЕ"
	_script_generate_button.disabled = writer_count == 0
	_script_generate_button.pressed.connect(_on_generate_script_pressed)
	_detail_layout.add_child(_script_generate_button)

	_script_progress_bar = ProgressBar.new()
	_script_progress_bar.min_value = 0.0
	_script_progress_bar.max_value = 100.0
	_script_progress_bar.show_percentage = true
	_script_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_layout.add_child(_script_progress_bar)

	_script_progress_label = Label.new()
	_script_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_progress_label.add_theme_font_size_override("font_size", 11)
	_detail_layout.add_child(_script_progress_label)

	var generation_note := Label.new()
	generation_note.text = (
		"Написание занимает игровое время. Количество сцен, ролей, навыки "
		+ "и надёжность сценариста влияют на срок. Возможны звонки и творческие паузы. "
		+ "Итоговый рейтинг зависит от навыков и жанра, но не гарантирует кассовый успех."
	)
	generation_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	generation_note.add_theme_font_size_override("font_size", 10)
	_detail_layout.add_child(generation_note)

	_script_result_label = Label.new()
	_script_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_result_label.custom_minimum_size = Vector2(0.0, 120.0)
	_detail_layout.add_child(_script_result_label)
	update_script_writing_ui(_manager.call("get_active_writing_project"), _manager.call("get_latest_script"))


func update_script_writing_ui(writing_project: Variant, latest_script: Variant) -> void:
	if not is_instance_valid(_script_progress_bar):
		return
	if not is_instance_valid(_script_progress_label):
		return
	if not is_instance_valid(_script_result_label):
		return

	if writing_project == null:
		_script_progress_bar.value = 0.0
		_script_progress_label.text = "Сценарий ещё не заказан."
		_script_result_label.text = _format_script_summary(latest_script)
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "НАЧАТЬ НАПИСАНИЕ СЦЕНАРИЯ"
			_script_generate_button.disabled = (
				not is_instance_valid(_script_writer_option)
				or _script_writer_option.disabled
			)
		return

	var project: Variant = writing_project
	_script_progress_bar.value = float(project.get_progress_percent())
	var remaining_minutes: int = int(project.get_remaining_work_minutes())
	var remaining_hours: float = float(remaining_minutes) / 60.0
	var remaining_shifts: int = ceili(float(remaining_minutes) / 480.0)
	var progress_text: String = (
		"Рабочее время: %d / %d минут · осталось около %.1f ч (%d смен)"
		% [
			int(project.completed_work_minutes),
			int(project.required_work_minutes),
			remaining_hours,
			remaining_shifts,
		]
	)
	var interruption_text: String = (
		"Прерываний за проект: %d" % int(project.interruption_count)
	)

	if str(project.status) == "in_progress":
		_script_progress_label.text = (
			"%s\n%s\n%s"
			% [
				str(project.last_activity_message),
				progress_text,
				interruption_text,
			]
		)
		_script_result_label.text = (
			"Сценарист: %s\nЖанр: %s · %d сцен · %d ролей\n"
			+ "Сценарий пока находится в разработке."
		) % [
			str(project.writer_name),
			SCRIPT_GENERATOR_SCRIPT.get_genre_title(str(project.genre_id)),
			int(project.scene_count),
			int(project.role_count),
		]
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "СЦЕНАРИЙ В РАБОТЕ"
			_script_generate_button.disabled = true
		if is_instance_valid(_script_writer_option):
			_script_writer_option.disabled = true
		if is_instance_valid(_script_genre_option):
			_script_genre_option.disabled = true
		if is_instance_valid(_script_scene_count):
			_script_scene_count.editable = false
		if is_instance_valid(_script_role_count):
			_script_role_count.editable = false
	elif str(project.status) == "completed":
		_script_progress_label.text = (
			"Сценарий завершён.\n%s\n%s"
			% [progress_text, interruption_text]
		)
		_script_result_label.text = _format_script_summary(latest_script)
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "НАЧАТЬ НОВЫЙ СЦЕНАРИЙ"
			_script_generate_button.disabled = (
				not is_instance_valid(_script_writer_option)
				or _script_writer_option.get_item_count() == 0
			)
		if is_instance_valid(_script_writer_option):
			_script_writer_option.disabled = false
		if is_instance_valid(_script_genre_option):
			_script_genre_option.disabled = false
		if is_instance_valid(_script_scene_count):
			_script_scene_count.editable = true
		if is_instance_valid(_script_role_count):
			_script_role_count.editable = true
	else:
		_script_progress_label.text = str(project.last_activity_message)
		_script_result_label.text = "Проект сценария остановлен."
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "НАЧАТЬ НОВЫЙ СЦЕНАРИЙ"
			_script_generate_button.disabled = (
				not is_instance_valid(_script_writer_option)
				or _script_writer_option.get_item_count() == 0
			)
		if is_instance_valid(_script_writer_option):
			_script_writer_option.disabled = false
		if is_instance_valid(_script_genre_option):
			_script_genre_option.disabled = false
		if is_instance_valid(_script_scene_count):
			_script_scene_count.editable = true
		if is_instance_valid(_script_role_count):
			_script_role_count.editable = true


func show_script_generation_error(message: String) -> void:
	if is_instance_valid(_script_result_label):
		_script_result_label.text = message


func _format_script_summary(script: Variant) -> String:
	if script == null:
		return "Сценарии ещё не создавались."

	var lines: Array[String] = [
		"ПОСЛЕДНИЙ СЦЕНАРИЙ",
		str(script.title),
		"%s  ·  %d сцен  ·  %d ролей" % [
			str(script.genre_title),
			int(script.scene_count),
			int(script.role_count),
		],
		"Потенциал: %s  (%d/100)" % [
			_format_stars(int(script.potential_stars)),
			int(script.potential_score),
		],
		"Коэффициент потенциала популярности: ×%.2f" % float(
			script.popularity_modifier
		),
		"Сценарист: %s" % str(script.writer_name),
		str(script.logline),
		"Персонажи:",
	]
	for cast_member in script.cast:
		lines.append(
			"• %s — %s" % [
				str(cast_member.get("role_title", "Роль")),
				str(cast_member.get("character_name", "Персонаж")),
			]
		)
	lines.append("ПЛАН СЦЕН")
	for scene in script.scenes:
		lines.append(
			"%02d. %s · %s" % [
				int(scene.get("scene_number", 0)),
				str(scene.get("beat", "")),
				str(scene.get("location", "")),
			]
		)
		lines.append("   %s" % str(scene.get("action", "")))
		lines.append("   %s" % str(scene.get("dialogue", "")))
	return "\n".join(lines)


func _format_stars(star_count: int) -> String:
	var result: String = ""
	for index in range(5):
		result += "★" if index < star_count else "☆"
	return result


func _build_tv_studio_detail(eligible_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "ТЕЛЕВИЗИОННОЕ ПРОИЗВОДСТВО"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override(
		"font_color",
		Color(0.40, 0.78, 0.91, 1.0)
	)
	_detail_layout.add_child(heading)

	var description := Label.new()
	description.text = (
		"Павильон предназначен для многокамерной записи сериалов и ток-шоу. "
		+ "Ведущие, актёры и съёмочная группа вызываются сюда по телевизионному "
		+ "расписанию и не занимают постоянные рабочие места в здании."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_layout.add_child(description)

	var eligible_label := Label.new()
	eligible_label.text = (
		"Потенциальный пул специалистов: %d сотрудников"
		% eligible_staff.size()
	)
	eligible_label.add_theme_font_size_override("font_size", 11)
	eligible_label.add_theme_color_override(
		"font_color",
		Color(0.60, 0.82, 0.87, 1.0)
	)
	_detail_layout.add_child(eligible_label)

	var workflow_label := Label.new()
	workflow_label.text = (
		"Съёмочный цикл: подготовка площадки → репетиция → запись → "
		+ "постпродакшен → эфир. Конфликты занятости с кинопроизводством "
		+ "проверяются перед началом телевизионного эпизода."
	)
	workflow_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workflow_label.add_theme_font_size_override("font_size", 11)
	_detail_layout.add_child(workflow_label)



