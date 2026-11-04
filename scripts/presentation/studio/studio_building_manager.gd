extends Node3D
class_name StudioBuildingManager

signal buildings_changed

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const PLACEMENT_RULES_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_placement_rules.gd"
)
const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const SCRIPT_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/script_department/script_generator.gd"
)
const SCRIPT_WRITING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/script_department/script_writing_system.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)

const GRID_SIZE: float = 2.0
const SCRIPT_DEPARTMENT_START_POSITION: Vector3 = Vector3(-16.0, 0.0, -16.0)
const SOUND_STAGE_START_POSITION: Vector3 = Vector3(0.0, 0.0, 0.0)
const REQUIRED_STAGE_PROFESSIONS: Array[String] = [
	"director",
	"actor",
	"camera_operator",
	"technician",
]

var _game_clock: Node
var _character_manager: Node
var _script_writing_system: RefCounted
var _active_writing_project: Variant

var _buildings: Array = []
var _building_actors: Dictionary = {}
var _selected_building_id: String = ""
var _placing_building_type_id: String = ""
var _placement_rotation_degrees: float = 0.0
var _next_building_sequence: int = 1
var _next_script_sequence: int = 1
var _latest_script: Variant

var _build_canvas: CanvasLayer
var _build_status_label: Label
var _placement_hint_label: Label
var _building_detail_panel: PanelContainer
var _building_detail_layout: VBoxContainer

var _script_writer_option: OptionButton
var _script_genre_option: OptionButton
var _script_scene_count: SpinBox
var _script_role_count: SpinBox
var _script_generate_button: Button
var _script_progress_bar: ProgressBar
var _script_progress_label: Label
var _script_result_label: Label

var _preview_mesh: MeshInstance3D
var _preview_material: StandardMaterial3D


func setup(game_clock: Node, character_manager: Node) -> void:
	_game_clock = game_clock
	_character_manager = character_manager
	_script_writing_system = SCRIPT_WRITING_SYSTEM_SCRIPT.new()
	_game_clock.minute_advanced.connect(_on_game_minute_advanced)

	_spawn_initial_buildings()
	_build_ui()
	_refresh_build_status()


func _process(_delta: float) -> void:
	if not _placing_building_type_id.is_empty():
		_update_placement_preview(get_viewport().get_mouse_position())


func is_placing_building() -> bool:
	return not _placing_building_type_id.is_empty()


func get_buildings() -> Array:
	return _buildings.duplicate()


func get_workplace_position(building_id: String, slot_index: int) -> Vector3:
	var building: Variant = _find_building(building_id)
	if building == null:
		return Vector3.ZERO

	var building_type_id: String = str(building.building_type_id)
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		building_type_id
	)
	var footprint: Vector2 = definition.get(
		"footprint",
		Vector2(8.0, 6.0)
	)
	var capacity: int = maxi(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity(building_type_id),
		1
	)
	var normalized_slot: int = clampi(slot_index, 0, capacity - 1)
	var lateral_offset: float = (
		float(normalized_slot) - float(capacity - 1) * 0.5
	) * 1.25
	var local_position: Vector3 = Vector3(
		lateral_offset,
		0.0,
		footprint.y * 0.5 + 1.8
	)
	return building.position + local_position.rotated(
		Vector3.UP,
		deg_to_rad(float(building.rotation_degrees))
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _placing_building_type_id.is_empty():
		_handle_placement_input(event)
		return

	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var building_actor: Node = _get_building_actor_at(mouse_event.position)
	if building_actor != null:
		_select_building(str(building_actor.call("get_building_id")))
		get_viewport().set_input_as_handled()
	elif not _selected_building_id.is_empty():
		_select_building("")


func _spawn_initial_buildings() -> void:
	_create_building(
		"script_department",
		SCRIPT_DEPARTMENT_START_POSITION,
		0.0,
		"Сценарный отдел",
		false
	)
	_create_building(
		"sound_stage",
		SOUND_STAGE_START_POSITION,
		0.0,
		"Съёмочный павильон №1",
		false
	)


func _create_building(
	building_type_id: String,
	world_position: Vector3,
	rotation_degrees: float,
	display_name: String = "",
	is_player_placed: bool = true
) -> Variant:
	if not BUILDING_CATALOG_SCRIPT.has_building_type(building_type_id):
		return null

	var building_data: Variant = BUILDING_DATA_SCRIPT.new()
	building_data.id = "BLD-%04d" % _next_building_sequence
	building_data.building_type_id = building_type_id
	building_data.display_name = (
		display_name
		if not display_name.is_empty()
		else "%s %d" % [
			BUILDING_CATALOG_SCRIPT.get_title(building_type_id),
			_next_building_sequence,
		]
	)
	building_data.position = world_position
	building_data.rotation_degrees = fposmod(rotation_degrees, 360.0)
	_next_building_sequence += 1

	_buildings.append(building_data)
	var actor: Variant = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", building_data)
	add_child(actor)
	_building_actors[building_data.id] = actor

	if is_player_placed:
		_refresh_build_status()
		buildings_changed.emit()
	return building_data


func _build_ui() -> void:
	_build_canvas = CanvasLayer.new()
	_build_canvas.name = "StudioBuildingHUD"
	_build_canvas.layer = 5
	add_child(_build_canvas)

	var build_panel := PanelContainer.new()
	build_panel.name = "BuildingPalettePanel"
	build_panel.position = Vector2(360.0, 16.0)
	build_panel.custom_minimum_size = Vector2(300.0, 0.0)
	_build_canvas.add_child(build_panel)

	var build_layout := VBoxContainer.new()
	build_panel.add_child(build_layout)

	var heading := Label.new()
	heading.text = "СТУДИЯ  |  СТРОИТЕЛЬСТВО"
	heading.add_theme_font_size_override("font_size", 15)
	build_layout.add_child(heading)

	var economy_note := Label.new()
	economy_note.text = "Тестовый этап: строительство пока бесплатно."
	economy_note.add_theme_font_size_override("font_size", 10)
	economy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_layout.add_child(economy_note)

	var script_button := Button.new()
	script_button.text = "Построить сценарный отдел"
	script_button.pressed.connect(
		_begin_placement.bind("script_department")
	)
	build_layout.add_child(script_button)

	var stage_button := Button.new()
	stage_button.text = "Построить съёмочный павильон"
	stage_button.pressed.connect(
		_begin_placement.bind("sound_stage")
	)
	build_layout.add_child(stage_button)

	_build_status_label = Label.new()
	_build_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_status_label.add_theme_font_size_override("font_size", 11)
	build_layout.add_child(_build_status_label)

	_placement_hint_label = Label.new()
	_placement_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placement_hint_label.add_theme_font_size_override("font_size", 11)
	_placement_hint_label.visible = false
	build_layout.add_child(_placement_hint_label)

	_build_building_detail_panel()


func _build_building_detail_panel() -> void:
	_building_detail_panel = PanelContainer.new()
	_building_detail_panel.name = "BuildingDetailPanel"
	_building_detail_panel.position = Vector2(760.0, 210.0)
	_building_detail_panel.custom_minimum_size = Vector2(430.0, 0.0)
	_building_detail_panel.visible = false
	_build_canvas.add_child(_building_detail_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(410.0, 560.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_building_detail_panel.add_child(scroll)

	_building_detail_layout = VBoxContainer.new()
	_building_detail_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_building_detail_layout)


func _refresh_build_status() -> void:
	if not is_instance_valid(_build_status_label):
		return
	_build_status_label.text = "Построено зданий: %d" % _buildings.size()


func _begin_placement(building_type_id: String) -> void:
	if not BUILDING_CATALOG_SCRIPT.has_building_type(building_type_id):
		return

	_placing_building_type_id = building_type_id
	_placement_rotation_degrees = 0.0
	_building_detail_panel.visible = false
	_create_placement_preview()
	_placement_hint_label.visible = true
	_placement_hint_label.text = (
		"Размещение: %s\nЛКМ — построить · R — повернуть · ПКМ/Esc — отменить"
		% BUILDING_CATALOG_SCRIPT.get_title(building_type_id)
	)
	_update_placement_preview(get_viewport().get_mouse_position())


func _create_placement_preview() -> void:
	if is_instance_valid(_preview_mesh):
		_preview_mesh.queue_free()

	var footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
		_placing_building_type_id,
		_placement_rotation_degrees
	)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(footprint.x, 0.12, footprint.y)

	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.name = "BuildingPlacementPreview"
	_preview_mesh.mesh = mesh
	_preview_mesh.position.y = 0.08

	_preview_material = StandardMaterial3D.new()
	_preview_material.albedo_color = Color(0.2, 0.85, 0.42, 0.38)
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview_mesh.material_override = _preview_material
	add_child(_preview_mesh)


func _update_placement_preview(screen_position: Vector2) -> void:
	if not is_instance_valid(_preview_mesh):
		return

	var ground_position: Vector3 = _get_ground_position(screen_position)
	if absf(ground_position.x) > 5000.0:
		_preview_mesh.visible = false
		return

	var snapped_position := Vector3(
		roundf(ground_position.x / GRID_SIZE) * GRID_SIZE,
		0.08,
		roundf(ground_position.z / GRID_SIZE) * GRID_SIZE
	)
	_preview_mesh.position = snapped_position
	_preview_mesh.visible = true

	var validation: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		_placing_building_type_id,
		Vector3(snapped_position.x, 0.0, snapped_position.z),
		_placement_rotation_degrees,
		_buildings
	)
	_preview_material.albedo_color = (
		Color(0.2, 0.85, 0.42, 0.38)
		if bool(validation.get("valid", false))
		else Color(0.92, 0.2, 0.16, 0.42)
	)


func _handle_placement_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			_cancel_placement()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_R:
			_placement_rotation_degrees = fposmod(
				_placement_rotation_degrees + 90.0,
				360.0
			)
			_create_placement_preview()
			_update_placement_preview(get_viewport().get_mouse_position())
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_placement()
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_try_place_building(mouse_event.position)
		get_viewport().set_input_as_handled()


func _try_place_building(screen_position: Vector2) -> void:
	var ground_position: Vector3 = _get_ground_position(screen_position)
	if absf(ground_position.x) > 5000.0:
		_set_placement_message("Не удалось определить точку на территории.")
		return

	var snapped_position := Vector3(
		roundf(ground_position.x / GRID_SIZE) * GRID_SIZE,
		0.0,
		roundf(ground_position.z / GRID_SIZE) * GRID_SIZE
	)
	var validation: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		_placing_building_type_id,
		snapped_position,
		_placement_rotation_degrees,
		_buildings
	)
	if not bool(validation.get("valid", false)):
		_set_placement_message(str(validation.get("reason", "Здесь нельзя строить.")))
		return

	var display_name: String = "%s %d" % [
		BUILDING_CATALOG_SCRIPT.get_title(_placing_building_type_id),
		_next_building_sequence - 1,
	]
	var building: Variant = _create_building(
		_placing_building_type_id,
		snapped_position,
		_placement_rotation_degrees,
		display_name
	)
	if building != null:
		_select_building(str(building.id))
		_set_placement_message("Здание размещено. Можно построить ещё одно.")


func _set_placement_message(message: String) -> void:
	if is_instance_valid(_placement_hint_label):
		_placement_hint_label.text = (
			"Размещение: %s\n%s\nЛКМ — построить · R — повернуть · ПКМ/Esc — отменить"
			% [
				BUILDING_CATALOG_SCRIPT.get_title(_placing_building_type_id),
				message,
			]
		)


func _cancel_placement() -> void:
	_placing_building_type_id = ""
	_placement_rotation_degrees = 0.0
	if is_instance_valid(_preview_mesh):
		_preview_mesh.queue_free()
	_preview_mesh = null
	_preview_material = null
	if is_instance_valid(_placement_hint_label):
		_placement_hint_label.visible = false
	_refresh_build_status()


func _get_ground_position(screen_position: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(9999.0, 0.0, 9999.0)

	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) <= 0.0001:
		return Vector3(9999.0, 0.0, 9999.0)

	var distance: float = -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return Vector3(9999.0, 0.0, 9999.0)
	return ray_origin + ray_direction * distance


func _get_building_actor_at(screen_position: Vector2) -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var ray_end: Vector3 = ray_origin + ray_direction * 300.0
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		4
	)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var candidate: Node = hit.get("collider") as Node
	while candidate != null and not candidate.is_in_group("studio_building"):
		candidate = candidate.get_parent()
	return candidate


func _select_building(building_id: String) -> void:
	var previous_actor: Variant = _building_actors.get(_selected_building_id)
	if previous_actor != null and is_instance_valid(previous_actor):
		previous_actor.call("set_selected", false)

	var building: Variant = _find_building(building_id)
	_selected_building_id = str(building.id) if building != null else ""
	if building == null:
		_building_detail_panel.visible = false
		return

	var actor: Variant = _building_actors.get(_selected_building_id)
	if actor != null and is_instance_valid(actor):
		actor.call("set_selected", true)
	_refresh_building_detail()


func _find_building(building_id: String) -> Variant:
	for building in _buildings:
		if str(building.id) == building_id:
			return building
	return null


func _refresh_building_detail() -> void:
	if not is_instance_valid(_building_detail_layout):
		return
	var building: Variant = _find_building(_selected_building_id)
	if building == null:
		_building_detail_panel.visible = false
		return

	for child in _building_detail_layout.get_children():
		_building_detail_layout.remove_child(child)
		child.queue_free()

	_building_detail_panel.visible = true
	var title := Label.new()
	title.text = str(building.display_name).to_upper()
	title.add_theme_font_size_override("font_size", 18)
	_building_detail_layout.add_child(title)

	var description := Label.new()
	description.text = BUILDING_CATALOG_SCRIPT.get_description(
		str(building.building_type_id)
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(description)

	var footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
		str(building.building_type_id),
		float(building.rotation_degrees)
	)
	var capacity: int = BUILDING_CATALOG_SCRIPT.get_workplace_capacity(
		str(building.building_type_id)
	)
	var eligible_staff: Array = _get_eligible_staff(
		str(building.building_type_id)
	)
	var staff_summary := Label.new()
	staff_summary.text = (
		"Рабочие места: %d  ·  Сотрудники подходящих профессий: %d\nРазмер участка: %.0f × %.0f м"
		% [capacity, eligible_staff.size(), footprint.x, footprint.y]
	)
	_building_detail_layout.add_child(staff_summary)

	if str(building.building_type_id) == "script_department":
		_build_script_department_detail(eligible_staff)
	elif str(building.building_type_id) == "sound_stage":
		_build_sound_stage_detail(eligible_staff)


func _build_script_department_detail(eligible_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "АВТОМАТИЧЕСКОЕ СОЗДАНИЕ СЦЕНАРИЯ"
	heading.add_theme_font_size_override("font_size", 14)
	_building_detail_layout.add_child(heading)

	var writer_heading := Label.new()
	writer_heading.text = "Сценарист"
	_building_detail_layout.add_child(writer_heading)

	_script_writer_option = OptionButton.new()
	_script_writer_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var writer_count: int = 0
	for employee in eligible_staff:
		if str(employee.profession_id) != "screenwriter":
			continue
		_script_writer_option.add_item(
			"%s · сценарное мастерство %d/100" % [
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
	_building_detail_layout.add_child(_script_writer_option)

	var genre_heading := Label.new()
	genre_heading.text = "Жанр"
	_building_detail_layout.add_child(genre_heading)

	_script_genre_option = OptionButton.new()
	_script_genre_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for genre_id in SCRIPT_GENERATOR_SCRIPT.get_genre_ids():
		_script_genre_option.add_item(
			SCRIPT_GENERATOR_SCRIPT.get_genre_title(genre_id)
		)
		_script_genre_option.set_item_metadata(
			_script_genre_option.get_item_count() - 1,
			genre_id
		)
	_script_genre_option.select(0)
	_building_detail_layout.add_child(_script_genre_option)

	var parameters_row := HBoxContainer.new()
	_building_detail_layout.add_child(parameters_row)

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
	scenes_column.add_child(_script_scene_count)

	var roles_column := VBoxContainer.new()
	roles_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parameters_row.add_child(roles_column)
	var roles_label := Label.new()
	roles_label.text = "Актёров / ролей"
	roles_column.add_child(roles_label)
	_script_role_count = SpinBox.new()
	_script_role_count.min_value = 1
	_script_role_count.max_value = 8
	_script_role_count.step = 1
	_script_role_count.value = 3
	roles_column.add_child(_script_role_count)

	_script_generate_button = Button.new()
	_script_generate_button.text = "НАЧАТЬ НАПИСАНИЕ СЦЕНАРИЯ"
	_script_generate_button.disabled = writer_count == 0
	_script_generate_button.pressed.connect(_on_generate_script_pressed)
	_building_detail_layout.add_child(_script_generate_button)

	_script_progress_bar = ProgressBar.new()
	_script_progress_bar.min_value = 0.0
	_script_progress_bar.max_value = 100.0
	_script_progress_bar.show_percentage = true
	_script_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_detail_layout.add_child(_script_progress_bar)

	_script_progress_label = Label.new()
	_script_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_progress_label.add_theme_font_size_override("font_size", 11)
	_building_detail_layout.add_child(_script_progress_label)

	var generation_note := Label.new()
	generation_note.text = (
		"Написание занимает игровое время. Количество сцен, ролей, навыки "
		+ "и надёжность сценариста влияют на срок. Возможны звонки и творческие паузы. "
		+ "Итоговый рейтинг зависит от навыков и жанра, но не гарантирует кассовый успех."
	)
	generation_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	generation_note.add_theme_font_size_override("font_size", 10)
	_building_detail_layout.add_child(generation_note)

	_script_result_label = Label.new()
	_script_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_result_label.custom_minimum_size = Vector2(0.0, 120.0)
	_building_detail_layout.add_child(_script_result_label)
	_update_script_writing_ui()


func _on_generate_script_pressed() -> void:
	if not is_instance_valid(_script_writer_option):
		return
	if _script_writer_option.disabled or _script_writer_option.selected < 0:
		return
	if (
		_active_writing_project != null
		and str(_active_writing_project.status) == "in_progress"
	):
		return

	var writer_id: String = str(
		_script_writer_option.get_item_metadata(
			_script_writer_option.selected
		)
	)
	var writer: Variant = _find_employee(writer_id)
	if writer == null:
		_show_script_generation_error(
			"Выбранный сценарист больше не работает в студии."
		)
		return

	var genre_id: String = str(
		_script_genre_option.get_item_metadata(
			_script_genre_option.selected
		)
	)
	var script_id: String = "SCR-%04d" % _next_script_sequence
	var project_id: String = "WRK-%04d" % _next_script_sequence
	var seed: int = (
		int(_game_clock.current_day) * 100000
		+ int(_game_clock.current_hour) * 1000
		+ int(_game_clock.current_minute) * 10
		+ _next_script_sequence
	)
	_next_script_sequence += 1

	_active_writing_project = _script_writing_system.call(
		"start_project",
		writer,
		genre_id,
		roundi(_script_scene_count.value),
		roundi(_script_role_count.value),
		seed,
		project_id,
		script_id,
		int(_game_clock.current_day),
		int(_game_clock.current_hour),
		int(_game_clock.current_minute)
	)
	if _active_writing_project == null:
		_show_script_generation_error(
			"Не удалось начать работу. Проверьте профессию выбранного сотрудника."
		)
		return

	_update_script_writing_ui()


func _on_game_minute_advanced(_day: int, _hour: int, _minute: int) -> void:
	if (
		_active_writing_project == null
		or str(_active_writing_project.status) != "in_progress"
	):
		return

	var writer_id: String = str(_active_writing_project.writer_id)
	var writer: Variant = _find_employee(writer_id)
	var at_workplace: bool = false
	if writer != null and is_instance_valid(_character_manager):
		at_workplace = bool(
			_character_manager.call(
				"is_employee_at_workplace",
				writer_id,
				"script_department"
			)
		)

	var result: Dictionary = _script_writing_system.call(
		"advance_minute",
		_active_writing_project,
		writer,
		at_workplace
	)
	if bool(result.get("completed", false)):
		_latest_script = result.get("script")
	elif bool(result.get("failed", false)):
		_show_script_generation_error(
			str(_active_writing_project.last_activity_message)
		)

	_update_script_writing_ui()


func _update_script_writing_ui() -> void:
	if not is_instance_valid(_script_progress_bar):
		return
	if not is_instance_valid(_script_progress_label):
		return
	if not is_instance_valid(_script_result_label):
		return

	if _active_writing_project == null:
		_script_progress_bar.value = 0.0
		_script_progress_label.text = "Сценарий ещё не заказан."
		_script_result_label.text = _format_script_summary(_latest_script)
		if is_instance_valid(_script_generate_button):
			_script_generate_button.text = "НАЧАТЬ НАПИСАНИЕ СЦЕНАРИЯ"
			_script_generate_button.disabled = (
				not is_instance_valid(_script_writer_option)
				or _script_writer_option.disabled
			)
		return

	var project: Variant = _active_writing_project
	_script_progress_bar.value = float(project.get_progress_percent())
	var progress_text: String = (
		"Рабочее время: %d / %d минут · осталось: %d минут"
		% [
			int(project.completed_work_minutes),
			int(project.required_work_minutes),
			int(project.get_remaining_work_minutes()),
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
		_script_result_label.text = _format_script_summary(_latest_script)
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
			_script_generate_button.disabled = false
		if is_instance_valid(_script_writer_option):
			_script_writer_option.disabled = false
		if is_instance_valid(_script_genre_option):
			_script_genre_option.disabled = false
		if is_instance_valid(_script_scene_count):
			_script_scene_count.editable = true
		if is_instance_valid(_script_role_count):
			_script_role_count.editable = true


func _show_script_generation_error(message: String) -> void:
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


func _build_sound_stage_detail(eligible_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "ПРОИЗВОДСТВЕННАЯ ПЛОЩАДКА"
	heading.add_theme_font_size_override("font_size", 14)
	_building_detail_layout.add_child(heading)

	var project_label := Label.new()
	project_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if (
		_active_writing_project != null
		and str(_active_writing_project.status) == "in_progress"
	):
		project_label.text = (
			"Сейчас пишется сценарий: %s\nПрогресс: %.0f%%"
			% [
				str(_active_writing_project.writer_name),
				float(_active_writing_project.get_progress_percent()),
			]
		)
	elif _latest_script == null:
		project_label.text = (
			"Нет готового сценария. Создай заказ в сценарном отделе."
		)
	else:
		project_label.text = (
			"Последний сценарий: %s\n%s · %d сцен · потенциал %s"
			% [
				str(_latest_script.title),
				str(_latest_script.genre_title),
				int(_latest_script.scene_count),
				_format_stars(int(_latest_script.potential_stars)),
			]
		)
	_building_detail_layout.add_child(project_label)

	_building_detail_layout.add_child(HSeparator.new())
	var crew_heading := Label.new()
	crew_heading.text = "ГОТОВНОСТЬ СЪЁМОЧНОЙ КОМАНДЫ"
	crew_heading.add_theme_font_size_override("font_size", 14)
	_building_detail_layout.add_child(crew_heading)

	var ready_positions: int = 0
	var crew_lines: Array[String] = []
	for profession_id in REQUIRED_STAGE_PROFESSIONS:
		var matching_staff: Array[String] = []
		for employee in eligible_staff:
			if str(employee.profession_id) == profession_id:
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
			REQUIRED_STAGE_PROFESSIONS.size(),
		]
	)
	var crew_label := Label.new()
	crew_label.text = "\n".join(crew_lines)
	crew_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(crew_label)

	var status_label := Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _latest_script == null:
		status_label.text = "Статус: ожидает сценарий."
	elif ready_positions == REQUIRED_STAGE_PROFESSIONS.size():
		status_label.text = "Статус: сценарий и базовый состав команды готовы к следующему этапу производства."
	else:
		status_label.text = "Статус: не хватает специалистов для полного съёмочного состава."
	_building_detail_layout.add_child(status_label)

	var limitation := Label.new()
	limitation.text = (
		"Съёмка сцен, назначение ролей и управление камерами будут подключены в Film Production v1."
	)
	limitation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limitation.add_theme_font_size_override("font_size", 10)
	_building_detail_layout.add_child(limitation)


func _get_eligible_staff(building_type_id: String) -> Array:
	var result: Array = []
	if not is_instance_valid(_character_manager):
		return result

	var employees: Array = _character_manager.call("get_employees")
	var accepted_professions: Array[String] = (
		BUILDING_CATALOG_SCRIPT.get_accepted_professions(building_type_id)
	)
	for employee in employees:
		if accepted_professions.has(str(employee.profession_id)):
			result.append(employee)
	return result


func _find_employee(employee_id: String) -> Variant:
	if not is_instance_valid(_character_manager):
		return null
	var employees: Array = _character_manager.call("get_employees")
	for employee in employees:
		if str(employee.id) == employee_id:
			return employee
	return null


func _get_profession_title(profession_id: String) -> String:
	return PROFESSION_CATALOG_SCRIPT.get_profession_title(profession_id)
