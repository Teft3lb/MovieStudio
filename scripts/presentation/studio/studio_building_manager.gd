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
const FILM_PRODUCTION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_system.gd"
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
var _film_production_system: RefCounted
var _active_writing_project: Variant
var _active_film_project: Variant
var _active_film_script: Variant
var _film_cast_assignments: Dictionary = {}
var _cast_assignment_script_id: String = ""
var _active_scene_performer_ids: Array[String] = []

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

var _film_cast_options: Dictionary = {}
var _film_production_status_label: Label
var _film_production_progress_bar: ProgressBar
var _film_production_detail_label: Label
var _film_production_start_button: Button

var _preview_mesh: MeshInstance3D
var _preview_material: StandardMaterial3D


func setup(game_clock: Node, character_manager: Node) -> void:
	_game_clock = game_clock
	_character_manager = character_manager
	_script_writing_system = SCRIPT_WRITING_SYSTEM_SCRIPT.new()
	_film_production_system = FILM_PRODUCTION_SYSTEM_SCRIPT.new()
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


func get_workplace_path(
	building_id: String,
	slot_index: int
) -> Array[Vector3]:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return []
	var path: Array[Vector3] = actor.call(
		"get_workplace_path",
		slot_index
	)
	return path


func get_workplace_position(building_id: String, slot_index: int) -> Vector3:
	var path: Array[Vector3] = get_workplace_path(building_id, slot_index)
	if path.is_empty():
		return Vector3.ZERO
	return path[path.size() - 1]

func get_scene_mark(
	building_id: String,
	slot_index: int,
	phase_id: String = "preparation",
	scene_index: int = 0
) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call(
		"get_scene_mark",
		slot_index,
		phase_id,
		scene_index
	)


func get_scene_focus_point(building_id: String) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call("get_scene_focus_point")


func set_production_scene(
	building_id: String,
	scene_number: int,
	scene_title: String,
	phase_title: String
) -> void:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return
	actor.call(
		"set_production_scene",
		scene_number,
		scene_title,
		phase_title
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
	var assigned_staff: Array = _get_assigned_staff(str(building.id))
	var assigned_names: Array[String] = []
	for employee in assigned_staff:
		assigned_names.append(
			"%s — %s" % [
				employee.get_full_name(),
				_get_profession_title(str(employee.profession_id)),
			]
		)
	var assigned_text: String = (
		", ".join(assigned_names)
		if not assigned_names.is_empty()
		else "пока нет"
	)
	var staff_summary := Label.new()
	staff_summary.text = (
		"Рабочие места: %d  ·  Назначено: %d\nСотрудники: %s\n"
		+ "Подходят по профессии: %d  ·  Участок: %.0f × %.0f м"
	) % [
		capacity,
		assigned_staff.size(),
		assigned_text,
		eligible_staff.size(),
		footprint.x,
		footprint.y,
	]
	staff_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(staff_summary)

	if str(building.building_type_id) == "script_department":
		_build_script_department_detail(assigned_staff)
	elif str(building.building_type_id) == "sound_stage":
		_build_sound_stage_detail(assigned_staff)


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
		_active_writing_project != null
		and str(_active_writing_project.status) == "in_progress"
	):
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

	_advance_film_production()


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


func _build_sound_stage_detail(assigned_staff: Array) -> void:
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
		project_label.text = "Нет готового сценария. Создай заказ в сценарном отделе."
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
		for employee in assigned_staff:
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

	if _latest_script != null:
		_build_film_cast_assignment_controls(assigned_staff)
	else:
		var no_script_label := Label.new()
		no_script_label.text = "Сначала заверши сценарий в сценарном отделе."
		no_script_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_building_detail_layout.add_child(no_script_label)

	_film_production_status_label = Label.new()
	_film_production_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_film_production_status_label.add_theme_font_size_override("font_size", 14)
	_building_detail_layout.add_child(_film_production_status_label)

	_film_production_progress_bar = ProgressBar.new()
	_film_production_progress_bar.min_value = 0.0
	_film_production_progress_bar.max_value = 100.0
	_film_production_progress_bar.show_percentage = true
	_film_production_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_detail_layout.add_child(_film_production_progress_bar)

	_film_production_detail_label = Label.new()
	_film_production_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(_film_production_detail_label)

	_film_production_start_button = Button.new()
	_film_production_start_button.text = "НАЧАТЬ СЪЁМКИ"
	_film_production_start_button.pressed.connect(
		_on_start_film_production_pressed
	)
	_building_detail_layout.add_child(_film_production_start_button)

	var production_note := Label.new()
	production_note.text = (
		"Каждая сцена проходит подготовку, репетицию, съёмку и просмотр. "
		+ "Качество зависит от сценария, актёров и съёмочной группы. "
		+ "При необходимости режиссёр назначает пересъёмку."
	)
	production_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	production_note.add_theme_font_size_override("font_size", 10)
	_building_detail_layout.add_child(production_note)

	_update_film_production_ui()


func _build_film_cast_assignment_controls(assigned_staff: Array) -> void:
	var heading := Label.new()
	heading.text = "РАСПРЕДЕЛЕНИЕ РОЛЕЙ"
	heading.add_theme_font_size_override("font_size", 14)
	_building_detail_layout.add_child(heading)

	var actor_candidates: Array = []
	for employee in assigned_staff:
		var profession_id: String = str(employee.profession_id)
		if profession_id == "actor" or profession_id == "extra":
			actor_candidates.append(employee)

	_film_cast_options.clear()
	if actor_candidates.is_empty():
		var missing_label := Label.new()
		missing_label.text = "Для съёмок нужен хотя бы один актёр или актёр массовки."
		missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_building_detail_layout.add_child(missing_label)
		return

	if _cast_assignment_script_id != str(_latest_script.id):
		_film_cast_assignments.clear()
		_cast_assignment_script_id = str(_latest_script.id)

	for role_index in range(_latest_script.cast.size()):
		var cast_member: Dictionary = _latest_script.cast[role_index]
		var role_id: String = str(cast_member.get("role_id", ""))
		var role_title: String = str(cast_member.get("role_title", "Роль"))
		var character_name: String = str(
			cast_member.get("character_name", "Персонаж")
		)

		var role_label := Label.new()
		role_label.text = "%s — %s" % [role_title, character_name]
		_building_detail_layout.add_child(role_label)

		var role_option := OptionButton.new()
		role_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var selected_index: int = -1
		var saved_employee_id: String = str(
			_film_cast_assignments.get(role_id, "")
		)
		for actor_index in range(actor_candidates.size()):
			var actor_employee: Variant = actor_candidates[actor_index]
			role_option.add_item(
				"%s · %s" % [
					actor_employee.get_full_name(),
					actor_employee.get_profession_title(),
				]
			)
			role_option.set_item_metadata(
				actor_index,
				str(actor_employee.id)
			)
			if str(actor_employee.id) == saved_employee_id:
				selected_index = actor_index

		if selected_index < 0:
			selected_index = posmod(role_index, actor_candidates.size())
		role_option.select(selected_index)
		role_option.disabled = (
			_active_film_project != null
			and str(_active_film_project.status) == "in_production"
		)
		_film_cast_assignments[role_id] = str(
			role_option.get_item_metadata(selected_index)
		)
		role_option.item_selected.connect(
			_on_film_cast_role_selected.bind(role_id, role_option)
		)
		_film_cast_options[role_id] = role_option
		_building_detail_layout.add_child(role_option)


func _on_film_cast_role_selected(
	selected_index: int,
	role_id: String,
	role_option: OptionButton
) -> void:
	if selected_index < 0 or selected_index >= role_option.get_item_count():
		return
	_film_cast_assignments[role_id] = str(
		role_option.get_item_metadata(selected_index)
	)


func _get_film_crew_assignments(assigned_staff: Array) -> Dictionary:
	var result: Dictionary = {}
	for profession_id in REQUIRED_STAGE_PROFESSIONS:
		for employee in assigned_staff:
			if str(employee.profession_id) == profession_id:
				result[profession_id] = str(employee.id)
				break
	for employee in assigned_staff:
		if str(employee.profession_id) == "producer":
			result["producer"] = str(employee.id)
			break
	return result


func _are_production_assignments_ready(
	crew_assignments: Dictionary,
	cast_assignments: Dictionary
) -> bool:
	var employee_ids: Array[String] = []
	for profession_id in ["director", "camera_operator", "technician"]:
		var employee_id: String = str(
			crew_assignments.get(profession_id, "")
		)
		if employee_id.is_empty():
			return false
		if not employee_ids.has(employee_id):
			employee_ids.append(employee_id)

	for employee_id_value in cast_assignments.values():
		var employee_id: String = str(employee_id_value)
		if employee_id.is_empty():
			return false
		if not employee_ids.has(employee_id):
			employee_ids.append(employee_id)

	for employee_id in employee_ids:
		var employee: Variant = _find_employee(employee_id)
		if employee == null or str(employee.work_state) != "working":
			return false
		if not bool(
			_character_manager.call(
				"is_employee_at_workplace",
				employee_id,
				"sound_stage"
			)
		):
			return false
	return not employee_ids.is_empty()


func _on_start_film_production_pressed() -> void:
	if _latest_script == null:
		return
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		_film_production_status_label.text = "Не найден съёмочный павильон."
		return

	var assigned_staff: Array = _get_assigned_staff(stage_id)
	var crew_assignments: Dictionary = _get_film_crew_assignments(
		assigned_staff
	)
	var cast_assignments: Dictionary = _film_cast_assignments.duplicate(true)
	if not _are_production_assignments_ready(
		crew_assignments,
		cast_assignments
	):
		_film_production_status_label.text = (
			"Команда должна быть на смене и находиться внутри павильона. "
			+ "Проверь назначение всех ролей."
		)
		return

	var project_id: String = "FILM-%04d" % _next_script_sequence
	var seed: int = (
		int(_game_clock.current_day) * 100000
		+ int(_game_clock.current_hour) * 1000
		+ int(_game_clock.current_minute) * 10
		+ _next_script_sequence
	)
	var project: Variant = _film_production_system.call(
		"start_project",
		_latest_script,
		crew_assignments,
		cast_assignments,
		project_id,
		seed,
		int(_game_clock.current_day),
		int(_game_clock.current_hour),
		int(_game_clock.current_minute)
	)
	if project == null:
		_film_production_status_label.text = (
			"Не удалось запустить производство. Проверь сценарий, роли и команду."
		)
		return

	_next_script_sequence += 1
	_active_film_project = project
	_active_film_script = _latest_script
	_active_scene_performer_ids.clear()
	_sync_film_scene_performance()
	_apply_film_crew_actions()
	_update_film_stage_slate()
	_update_film_production_ui()


func _get_sound_stage_building_id() -> String:
	for building in _buildings:
		if str(building.building_type_id) == "sound_stage":
			return str(building.id)
	return ""


func _advance_film_production() -> void:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
	):
		return

	var cast_ready: bool = _sync_film_scene_performance()
	var crew_ready: bool = _are_film_crew_ready()
	var snapshot: Dictionary = _build_film_performance_snapshot()
	var result: Dictionary = _film_production_system.call(
		"advance_minute",
		_active_film_project,
		_active_film_script,
		crew_ready,
		cast_ready,
		snapshot
	)

	if bool(result.get("phase_changed", false)):
		_sync_film_scene_performance()
		_apply_film_crew_actions()
	if bool(result.get("completed", false)):
		_sync_film_scene_performance()
		_reset_film_crew_actions()
	_update_film_stage_slate()
	_update_film_production_ui()


func _update_film_stage_slate() -> void:
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return
	if _active_film_project == null:
		set_production_scene(
			stage_id,
			0,
			"СЪЁМКИ НЕ ИДУТ",
			"ПАВИЛЬОН ГОТОВ"
		)
		return
	if str(_active_film_project.status) == "completed":
		set_production_scene(
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
	set_production_scene(
		stage_id,
		int(scene.get("scene_number", _active_film_project.current_scene_index + 1)),
		str(scene.get("beat", "Съёмочная сцена")),
		phase_title
	)


func _are_film_crew_ready() -> bool:
	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	for profession_id in ["director", "camera_operator", "technician"]:
		var employee_id: String = str(
			crew_assignments.get(profession_id, "")
		)
		var employee: Variant = _find_employee(employee_id)
		if employee == null or str(employee.work_state) != "working":
			return false
		if not bool(
			_character_manager.call(
				"is_employee_at_workplace",
				employee_id,
				"sound_stage"
			)
		):
			return false
	return true


func _sync_film_scene_performance() -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or _active_film_script == null
	):
		for employee_id in _active_scene_performer_ids:
			var actor: Variant = _character_manager.call(
				"get_employee_actor",
				employee_id
			)
			if actor != null and is_instance_valid(actor):
				actor.call("return_to_workplace")
		_active_scene_performer_ids.clear()
		return false

	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return false

	var performer_ids: Array = _film_production_system.call(
		"get_scene_performer_ids",
		_active_film_script,
		_active_film_project
	)
	var scene: Dictionary = _film_production_system.call(
		"get_current_scene",
		_active_film_script,
		_active_film_project
	)
	var marks: Array[Vector3] = []
	for mark_index in range(performer_ids.size()):
		marks.append(
			get_scene_mark(
				stage_id,
				mark_index,
				str(_active_film_project.current_phase),
				int(_active_film_project.current_scene_index)
			)
		)

	var focus_point: Vector3 = get_scene_focus_point(stage_id)
	var new_active_ids: Array[String] = []
	var all_at_marks: bool = not performer_ids.is_empty()
	for performer_index in range(performer_ids.size()):
		var employee_id: String = str(performer_ids[performer_index])
		var employee: Variant = _find_employee(employee_id)
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if (
			employee == null
			or actor == null
			or str(employee.work_state) != "working"
			or not bool(
				_character_manager.call(
					"is_employee_assigned_to_building",
					employee_id,
					"sound_stage"
				)
			)
		):
			all_at_marks = false
			continue

		var already_performing: bool = bool(
			actor.call("is_in_scene_performance")
		)
		var at_workplace: bool = bool(
			_character_manager.call(
				"is_employee_at_workplace",
				employee_id,
				"sound_stage"
			)
		)
		if not already_performing and not at_workplace:
			all_at_marks = false
			continue

		var actor_focus: Vector3 = focus_point
		if performer_ids.size() > 1:
			var focus_total: Vector3 = Vector3.ZERO
			var focus_count: int = 0
			for other_index in range(marks.size()):
				if other_index == performer_index:
					continue
				focus_total += marks[other_index]
				focus_count += 1
			if focus_count > 0:
				actor_focus = focus_total / float(focus_count)

		var dialogue_text: String = ""
		if str(_active_film_project.current_phase) == "shooting":
			dialogue_text = str(
				_film_production_system.call(
					"get_scene_dialogue_for_employee",
					_active_film_script,
					_active_film_project,
					employee_id
				)
			)
		var action_id: String = _get_scene_actor_action(
			str(_active_film_project.current_phase),
			scene,
			not dialogue_text.is_empty()
		)
		actor.call(
			"start_scene_performance",
			marks[performer_index],
			actor_focus,
			action_id,
			dialogue_text
		)
		if _game_clock.is_manual_fast_forward:
			actor.call("snap_to_scene_mark")
		if not bool(actor.call("is_at_scene_mark")):
			all_at_marks = false
		new_active_ids.append(employee_id)

	for previous_id in _active_scene_performer_ids:
		if new_active_ids.has(previous_id):
			continue
		var previous_employee: Variant = _find_employee(previous_id)
		var previous_actor: Variant = _character_manager.call(
			"get_employee_actor",
			previous_id
		)
		if (
			previous_employee != null
			and str(previous_employee.work_state) == "working"
			and previous_actor != null
			and is_instance_valid(previous_actor)
		):
			previous_actor.call("return_to_workplace")

	_active_scene_performer_ids = new_active_ids
	return all_at_marks


func _get_scene_actor_action(
	phase: String,
	scene: Dictionary,
	is_speaker: bool
) -> String:
	match phase:
		"preparation":
			return "rehearsing"
		"rehearsal":
			return "rehearsing"
		"review":
			return "reviewing"
		"shooting":
			if is_speaker:
				return "speaking"
			var beat: String = str(scene.get("beat", ""))
			var action_text: String = str(scene.get("action", ""))
			if (
				beat.contains("Кульминация")
				or beat.contains("Поворот")
				or action_text.to_lower().contains("противостояние")
			):
				return "dramatic"
			return "reacting"
		_:
			return "rehearsing"


func _build_film_performance_snapshot() -> Dictionary:
	var performer_ids: Array = _film_production_system.call(
		"get_scene_performer_ids",
		_active_film_script,
		_active_film_project
	)
	var acting_total: float = 0.0
	var acting_count: int = 0
	for employee_id_value in performer_ids:
		var employee: Variant = _find_employee(str(employee_id_value))
		if employee == null:
			continue
		acting_total += float(employee.skills.get("acting", 45.0))
		acting_count += 1

	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	var director: Variant = _find_employee(
		str(crew_assignments.get("director", ""))
	)
	var camera_operator: Variant = _find_employee(
		str(crew_assignments.get("camera_operator", ""))
	)
	var technician: Variant = _find_employee(
		str(crew_assignments.get("technician", ""))
	)
	var participants: Array[String] = []
	for employee_id_value in performer_ids:
		var employee_id: String = str(employee_id_value)
		if not participants.has(employee_id):
			participants.append(employee_id)
	for employee_id_value in crew_assignments.values():
		var employee_id: String = str(employee_id_value)
		if not participants.has(employee_id):
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
		"directing": (
			float(director.skills.get("directing", 45.0))
			if director != null else 45.0
		),
		"camera_work": (
			float(camera_operator.skills.get("camera_work", 45.0))
			if camera_operator != null else 45.0
		),
		"technical": (
			float(technician.skills.get("technical", 45.0))
			if technician != null else 45.0
		),
		"energy": energy_total / divisor,
		"morale": morale_total / divisor,
		"stress": stress_total / divisor,
	}


func _apply_film_crew_actions() -> void:
	if _active_film_project == null:
		return
	var phase: String = str(_active_film_project.current_phase)
	var scene_number: int = int(_active_film_project.current_scene_index) + 1
	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	var task_by_profession: Dictionary = {
		"director": "Руководит сценой %d" % scene_number,
		"camera_operator": "Снимает сцену %d" % scene_number,
		"technician": "Обслуживает оборудование сцены %d" % scene_number,
		"producer": "Координирует съёмки фильма",
	}
	var action_by_profession: Dictionary = {
		"director": "directing",
		"camera_operator": "operating_camera",
		"technician": "checking_equipment",
		"producer": "coordinating",
	}
	if phase == "review":
		task_by_profession["director"] = "Просматривает дубль сцены %d" % scene_number
		task_by_profession["camera_operator"] = "Проверяет снятый материал"
		action_by_profession["director"] = "reviewing"
		action_by_profession["camera_operator"] = "reviewing"
	elif phase == "preparation":
		task_by_profession["director"] = "Готовит постановку сцены %d" % scene_number
		task_by_profession["camera_operator"] = "Выставляет кадр сцены %d" % scene_number
		action_by_profession["technician"] = "checking_equipment"

	for profession_id in ["director", "camera_operator", "technician", "producer"]:
		var employee_id: String = str(
			crew_assignments.get(profession_id, "")
		)
		if employee_id.is_empty():
			continue
		_character_manager.call(
			"set_employee_task",
			employee_id,
			str(task_by_profession.get(profession_id, "Работает над фильмом"))
		)
		_character_manager.call(
			"set_employee_production_action",
			employee_id,
			str(action_by_profession.get(profession_id, ""))
		)


func _reset_film_crew_actions() -> void:
	if _active_film_project == null:
		return
	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	for profession_id in ["director", "camera_operator", "technician", "producer"]:
		var employee_id: String = str(
			crew_assignments.get(profession_id, "")
		)
		var employee: Variant = _find_employee(employee_id)
		if employee == null:
			continue
		_character_manager.call(
			"set_employee_task",
			employee_id,
			PROFESSION_CATALOG_SCRIPT.get_default_task(
				str(employee.profession_id)
			)
		)
		_character_manager.call(
			"set_employee_production_action",
			employee_id,
			""
		)


func _update_film_production_ui() -> void:
	if not is_instance_valid(_film_production_status_label):
		return
	if not is_instance_valid(_film_production_progress_bar):
		return
	if not is_instance_valid(_film_production_detail_label):
		return

	if _active_film_project == null:
		_film_production_progress_bar.value = 0.0
		_film_production_status_label.text = (
			"Статус: готов к съёмкам."
			if _latest_script != null
			else "Статус: ожидает готовый сценарий."
		)
		_film_production_detail_label.text = (
			"Назначь актёров на роли и проверь, что режиссёр, оператор и техник "
			+ "находятся на смене в павильоне."
		)
		if is_instance_valid(_film_production_start_button):
			_film_production_start_button.text = "НАЧАТЬ СЪЁМКИ"
			_film_production_start_button.disabled = not _can_start_film_production()
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
		_film_production_detail_label.text = (
			"Фильм: %s\nСцена %d: %s · %s\n%s\n%s\n"
			+ "Этап: %d / %d мин · Всего прошло: %d мин · Осталось примерно: %d мин\n"
			+ "Пересъёмок текущей сцены: %d"
		) % [
			str(project.film_title),
			int(scene.get("scene_number", project.current_scene_index + 1)),
			str(scene.get("beat", "")),
			str(scene.get("location", "")),
			str(scene.get("action", "")),
			dialogue,
			int(project.phase_minutes_elapsed),
			int(project.phase_duration_minutes),
			int(project.total_elapsed_minutes),
			int(project.get_remaining_work_minutes()),
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
			_film_production_start_button.text = "СНЯТЬ ФИЛЬМ ПО НОВОМУ СЦЕНАРИЮ"
			_film_production_start_button.disabled = not _can_start_film_production()


func _can_start_film_production() -> bool:
	if _latest_script == null or _active_film_project != null:
		if (
			_active_film_project != null
			and str(_active_film_project.status) == "completed"
		):
			pass
		else:
			return false
	if _latest_script == null:
		return false
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return false
	var assigned_staff: Array = _get_assigned_staff(stage_id)
	var crew_assignments: Dictionary = _get_film_crew_assignments(
		assigned_staff
	)
	return _are_production_assignments_ready(
		crew_assignments,
		_film_cast_assignments
	)


func get_active_film_project() -> Variant:
	return _active_film_project




func _get_assigned_staff(building_id: String) -> Array:
	if not is_instance_valid(_character_manager):
		return []
	return _character_manager.call(
		"get_employees_assigned_to_building",
		building_id
	)


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
