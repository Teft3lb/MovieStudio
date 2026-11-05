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
const FILM_EDITING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_editing/film_editing_system.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)
const NAVIGATION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)
const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)
const SET_INVENTORY_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_inventory.gd"
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
var _film_editing_system: RefCounted
var _navigation_system: RefCounted
var _set_inventory: Variant
var _off_camera_employee_ids: Array[String] = []
var _decor_shop_group_id: String = ""
var _decor_shop_group_option: OptionButton
var _decor_shop_budget_label: Label
var _decor_shop_items: VBoxContainer
var _active_set_dressing_technician_id: String = ""
var _active_writing_project: Variant
var _active_film_project: Variant
var _active_film_script: Variant
var _active_editing_project: Variant
var _completed_film_archive: Array = []
var _next_film_editing_sequence: int = 1
var _film_editing_editor_id: String = ""
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

var _preview_mesh: MeshInstance3D
var _preview_material: StandardMaterial3D


func setup(game_clock: Node, character_manager: Node) -> void:
	_game_clock = game_clock
	_character_manager = character_manager
	_script_writing_system = SCRIPT_WRITING_SYSTEM_SCRIPT.new()
	_film_production_system = FILM_PRODUCTION_SYSTEM_SCRIPT.new()
	_film_editing_system = FILM_EDITING_SYSTEM_SCRIPT.new()
	_navigation_system = NAVIGATION_SYSTEM_SCRIPT.new()
	_set_inventory = SET_INVENTORY_SCRIPT.new()
	_game_clock.minute_advanced.connect(_on_game_minute_advanced)
	if _character_manager.has_signal("employees_changed"):
		var roster_callback: Callable = Callable(
			self,
			"_on_employee_roster_changed"
		)
		if not _character_manager.is_connected(
			"employees_changed",
			roster_callback
		):
			_character_manager.connect(
				"employees_changed",
				roster_callback
			)

	_spawn_initial_buildings()
	_build_ui()
	_refresh_build_status()


func _on_employee_roster_changed() -> void:
	if not _selected_building_id.is_empty():
		_refresh_building_detail()


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


func get_workplace_path_from(
	building_id: String,
	slot_index: int,
	start_position: Vector3
) -> Array[Vector3]:
	var workplace_path: Array[Vector3] = get_workplace_path(
		building_id,
		slot_index
	)
	if workplace_path.is_empty():
		return []
	var travel_path: Array[Vector3] = _navigation_system.call(
		"build_path",
		start_position,
		workplace_path[0],
		_get_building_navigation_obstacles(),
		0.75,
		Rect2(Vector2(-47.0, -47.0), Vector2(94.0, 94.0))
	)
	if travel_path.is_empty():
		return []
	var result: Array[Vector3] = []
	for point in travel_path:
		if result.is_empty() or result.back().distance_to(point) > 0.2:
			result.append(point)
	for index in range(1, workplace_path.size()):
		if result.is_empty() or result.back().distance_to(workplace_path[index]) > 0.2:
			result.append(workplace_path[index])
	return result


func _get_building_navigation_obstacles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in _buildings:
		var footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
			str(building.building_type_id),
			float(building.rotation_degrees)
		)
		result.append({
			"center": Vector2(building.position.x, building.position.z),
			"half_extents": Vector2(
				footprint.x * 0.5,
				footprint.y * 0.5
			),
			"clearance": 0.62,
		})
	return result


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


func get_scene_path(
	building_id: String,
	start_position: Vector3,
	target_position: Vector3
) -> Array[Vector3]:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return []
	return actor.call(
		"get_scene_path",
		start_position,
		target_position
	)


func set_scene_set_dressing(
	building_id: String,
	setup: Dictionary,
	progress: float
) -> void:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return
	actor.call("set_scene_set_dressing", setup, progress)


func get_set_dressing_prop_count(building_id: String) -> int:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return 0
	return int(actor.call("get_set_dressing_prop_count"))


func get_set_dressing_mark(building_id: String, prop_index: int) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call("get_set_dressing_mark", prop_index)


func get_scene_hold_mark(building_id: String, slot_index: int) -> Vector3:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return Vector3.ZERO
	return actor.call("get_scene_hold_mark", slot_index)


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


func set_stage_camera_target(
	building_id: String,
	target_position: Vector3,
	active: bool
) -> void:
	var actor: Variant = _building_actors.get(building_id)
	if actor == null or not is_instance_valid(actor):
		return
	actor.call("set_camera_target", target_position, active)


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
	var build_panel := PanelContainer.new()
	build_panel.name = "BuildingPalettePanel"
	build_panel.custom_minimum_size = Vector2(0.0, 0.0)
	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if studio_hud == null:
		push_error("StudioBuildingManager: StudioHUD node is missing.")
		return
	studio_hud.call(
		"register_workspace_panel",
		"studio",
		"Студия",
		build_panel
	)

	var build_layout := VBoxContainer.new()
	build_layout.add_theme_constant_override("separation", 9)
	build_panel.add_child(build_layout)

	var heading := Label.new()
	heading.text = "СТРОИТЕЛЬСТВО"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override(
		"font_color",
		Color(0.48, 0.82, 0.72, 1.0)
	)
	build_layout.add_child(heading)

	var script_button := Button.new()
	script_button.text = "＋ Сценарный отдел"
	script_button.tooltip_text = "Построить сценарный отдел"
	script_button.custom_minimum_size = Vector2(0.0, 42.0)
	script_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	script_button.pressed.connect(
		_begin_placement.bind("script_department")
	)
	build_layout.add_child(script_button)

	var stage_button := Button.new()
	stage_button.text = "＋ Съёмочный павильон"
	stage_button.tooltip_text = "Построить съёмочный павильон"
	stage_button.custom_minimum_size = Vector2(0.0, 42.0)
	stage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_button.pressed.connect(
		_begin_placement.bind("sound_stage")
	)
	build_layout.add_child(stage_button)

	var editing_button := Button.new()
	editing_button.text = "＋ Монтажный отдел"
	editing_button.tooltip_text = "Построить монтажный отдел"
	editing_button.custom_minimum_size = Vector2(0.0, 42.0)
	editing_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editing_button.pressed.connect(
		_begin_placement.bind("editing_suite")
	)
	build_layout.add_child(editing_button)

	_build_status_label = Label.new()
	_build_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_status_label.add_theme_font_size_override("font_size", 11)
	_build_status_label.add_theme_color_override(
		"font_color",
		Color(0.60, 0.80, 0.78, 1.0)
	)
	build_layout.add_child(_build_status_label)

	_placement_hint_label = Label.new()
	_placement_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placement_hint_label.add_theme_font_size_override("font_size", 11)
	_placement_hint_label.visible = false
	build_layout.add_child(_placement_hint_label)

	_build_building_detail_panel()
	_build_decor_shop_panel(studio_hud)


func _build_building_detail_panel() -> void:
	_building_detail_panel = PanelContainer.new()
	_building_detail_panel.name = "BuildingDetailPanel"
	_building_detail_panel.custom_minimum_size = Vector2(0.0, 0.0)
	_building_detail_panel.visible = false
	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if studio_hud == null:
		push_error("StudioBuildingManager: StudioHUD node is missing.")
		return
	studio_hud.call(
		"register_inspector_panel",
		"building",
		"Выбранное здание",
		_building_detail_panel
	)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 0.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	studio_hud.call("configure_scroll_container", scroll)
	_building_detail_panel.add_child(scroll)

	_building_detail_layout = VBoxContainer.new()
	_building_detail_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_detail_layout.add_theme_constant_override("separation", 9)
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
	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if studio_hud != null:
		studio_hud.call("show_inspector_panel", "building", false)
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
	var studio_hud: Node = get_node_or_null("../StudioHUD")
	if building == null:
		_building_detail_panel.visible = false
		if studio_hud != null:
			studio_hud.call("show_inspector_panel", "building", false)
		return

	if studio_hud != null:
		studio_hud.call("show_workspace_panel", "studio")
	var actor: Variant = _building_actors.get(_selected_building_id)
	if actor != null and is_instance_valid(actor):
		actor.call("set_selected", true)
	_refresh_building_detail()
	if studio_hud != null:
		studio_hud.call("show_inspector_panel", "building", true)


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
		var studio_hud: Node = get_node_or_null("../StudioHUD")
		if studio_hud != null:
			studio_hud.call("show_inspector_panel", "building", false)
		return

	for child in _building_detail_layout.get_children():
		_building_detail_layout.remove_child(child)
		child.queue_free()

	_building_detail_panel.visible = true
	var title := Label.new()
	title.text = str(building.display_name).to_upper()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override(
		"font_color",
		Color(0.78, 0.94, 0.88, 1.0)
	)
	_building_detail_layout.add_child(title)

	var description := Label.new()
	description.text = BUILDING_CATALOG_SCRIPT.get_description(
		str(building.building_type_id)
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override(
		"font_color",
		Color(0.62, 0.77, 0.79, 1.0)
	)
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
			"%s · %s" % [
				employee.get_full_name(),
				_get_profession_title(str(employee.profession_id)),
			]
		)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 3
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 6)
	stats_grid.add_theme_constant_override("v_separation", 6)
	_building_detail_layout.add_child(stats_grid)
	stats_grid.add_child(
		_create_building_stat_card(
			"РАБОЧИЕ МЕСТА",
			str(capacity),
			Color(0.50, 0.86, 0.73, 1.0)
		)
	)
	stats_grid.add_child(
		_create_building_stat_card(
			"НАЗНАЧЕНО",
			"%d / %d" % [assigned_staff.size(), capacity],
			Color(0.50, 0.78, 0.90, 1.0)
		)
	)
	stats_grid.add_child(
		_create_building_stat_card(
			"УЧАСТОК",
			"%.0f × %.0f м" % [footprint.x, footprint.y],
			Color(0.72, 0.87, 0.84, 1.0)
		)
	)

	var crew_heading := Label.new()
	crew_heading.text = "КОМАНДА · %d" % assigned_staff.size()
	crew_heading.add_theme_font_size_override("font_size", 11)
	crew_heading.add_theme_color_override(
		"font_color",
		Color(0.50, 0.82, 0.74, 1.0)
	)
	_building_detail_layout.add_child(crew_heading)

	var staff_summary := Label.new()
	staff_summary.text = (
		"\n".join(assigned_names)
		if not assigned_names.is_empty()
		else "Пока никто не назначен."
	)
	staff_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(staff_summary)

	var eligible_summary := Label.new()
	eligible_summary.text = (
		"Ещё подходят по профессии: %d" % eligible_staff.size()
	)
	eligible_summary.add_theme_font_size_override("font_size", 10)
	eligible_summary.add_theme_color_override(
		"font_color",
		Color(0.58, 0.76, 0.79, 1.0)
	)
	_building_detail_layout.add_child(eligible_summary)

	if str(building.building_type_id) == "script_department":
		_build_script_department_detail(assigned_staff)
	elif str(building.building_type_id) == "sound_stage":
		_build_sound_stage_detail(assigned_staff)
	elif str(building.building_type_id) == "editing_suite":
		_build_film_editing_detail(assigned_staff)

	_apply_inspector_width_constraints(_building_detail_layout)


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
	_building_detail_layout.add_child(heading)

	var writer_heading := Label.new()
	writer_heading.text = "Сценарист"
	_building_detail_layout.add_child(writer_heading)

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
	_building_detail_layout.add_child(_script_writer_option)

	var genre_heading := Label.new()
	genre_heading.text = "Жанр"
	_building_detail_layout.add_child(genre_heading)

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
	_advance_film_editing()


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
			var employee_profession: String = str(employee.profession_id)
			var matches_position: bool = (
				employee_profession == profession_id
				or (
					profession_id == "actor"
					and employee_profession == "extra"
				)
			)
			if matches_position:
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
		"Каждая сцена проходит подготовку, монтаж декораций, репетицию, "
		+ "съёмку и просмотр. Пока техник готовит площадку, актёры гуляют "
		+ "по студии и возвращаются на репетицию по вызову. Покупки до начала "
		+ "установки учитываются в текущей сцене; позднее — в следующих. "
		+ "Реквизит переиспользуется, а его отсутствие снижает качество."
	)
	production_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	production_note.add_theme_font_size_override("font_size", 10)
	_building_detail_layout.add_child(production_note)

	_update_film_production_ui()


func _build_decor_shop_panel(studio_hud: Node) -> void:
	var panel := PanelContainer.new()
	panel.name = "DecorShopPanel"
	studio_hud.call(
		"register_workspace_panel",
		"decor_shop",
		"Магазин декораций",
		panel
	)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	studio_hud.call("configure_scroll_container", scroll)
	panel.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 9)
	scroll.add_child(layout)

	var heading := Label.new()
	heading.text = "МАГАЗИН ДЕКОРАЦИЙ"
	heading.add_theme_font_size_override("font_size", 15)
	layout.add_child(heading)

	var description := Label.new()
	description.text = (
		"Покупай элементы для разных типов сцен. "
		+ "Декорации не расходуются и используются повторно в следующих фильмах."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)

	_decor_shop_budget_label = Label.new()
	_decor_shop_budget_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_decor_shop_budget_label)

	_decor_shop_group_option = OptionButton.new()
	_decor_shop_group_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_decor_shop_group_option)
	var group_ids: Array[String] = SET_CATALOG_SCRIPT.get_group_ids()
	for group_id in group_ids:
		_decor_shop_group_option.add_item(
			SET_CATALOG_SCRIPT.get_group_title(group_id)
		)
	if not group_ids.is_empty():
		_decor_shop_group_id = group_ids[0]
		_decor_shop_group_option.select(0)
	_decor_shop_group_option.item_selected.connect(
		_on_decor_shop_group_selected
	)

	_decor_shop_items = VBoxContainer.new()
	_decor_shop_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decor_shop_items.add_theme_constant_override("separation", 7)
	layout.add_child(_decor_shop_items)
	_refresh_decor_shop_panel()


func _on_decor_shop_group_selected(selected_index: int) -> void:
	var group_ids: Array[String] = SET_CATALOG_SCRIPT.get_group_ids()
	if selected_index < 0 or selected_index >= group_ids.size():
		return
	_decor_shop_group_id = group_ids[selected_index]
	_refresh_decor_shop_panel()


func _refresh_decor_shop_panel() -> void:
	if not is_instance_valid(_decor_shop_items):
		return
	_decor_shop_budget_label.text = (
		"Бюджет декораций: %d усл. ед. · купленные элементы доступны без ограничений."
		% int(_set_inventory.budget)
	)
	for child in _decor_shop_items.get_children():
		_decor_shop_items.remove_child(child)
		child.queue_free()

	for prop_id in SET_CATALOG_SCRIPT.get_prop_ids_for_group(
		_decor_shop_group_id
	):
		var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(
			prop_id
		)
		var row := PanelContainer.new()
		var row_layout := HBoxContainer.new()
		row_layout.add_theme_constant_override("separation", 8)
		row.add_child(row_layout)

		var prop_label := Label.new()
		prop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prop_label.text = "%s\nКачество сцены: +%d\nЦена: %d усл. ед." % [
			str(definition.get("title", prop_id)),
			int(definition.get("quality_bonus", 0)),
			int(definition.get("price", 0)),
		]
		row_layout.add_child(prop_label)

		var purchase_button := Button.new()
		purchase_button.custom_minimum_size = Vector2(104.0, 38.0)
		if _set_inventory.is_owned(prop_id):
			purchase_button.text = "КУПЛЕНО"
			purchase_button.disabled = true
		else:
			purchase_button.text = "КУПИТЬ"
			purchase_button.disabled = (
				int(_set_inventory.budget)
				< int(definition.get("price", 0))
			)
			purchase_button.pressed.connect(
				_on_buy_set_prop_pressed.bind(prop_id)
			)
		row_layout.add_child(purchase_button)
		_decor_shop_items.add_child(row)





func _on_buy_set_prop_pressed(prop_id: String) -> void:
	var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(prop_id)
	if definition.is_empty():
		return
	var purchased: bool = bool(_set_inventory.call(
		"purchase",
		prop_id,
		int(definition.get("price", 0))
	))
	if purchased:
		_refresh_active_scene_set_dressing_if_unstarted()
		_refresh_decor_shop_panel()


func _refresh_active_scene_set_dressing_if_unstarted() -> void:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or _active_film_script == null
	):
		return
	var current_phase: String = str(_active_film_project.current_phase)
	if (
		current_phase != "preparation"
		and not (
			current_phase == "set_dressing"
			and int(_active_film_project.phase_minutes_elapsed) == 0
		)
	):
		return
	var refreshed_setup: Dictionary = _film_production_system.call(
		"refresh_current_scene_setup",
		_active_film_project,
		_active_film_script,
		_set_inventory.get_owned_prop_ids()
	)
	if refreshed_setup.is_empty():
		return
	_sync_film_set_dressing()
	_update_film_stage_slate()
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
	_update_film_production_ui()


func _get_film_crew_assignments(assigned_staff: Array) -> Dictionary:
	var result: Dictionary = {}
	for profession_id in REQUIRED_STAGE_PROFESSIONS:
		for employee in assigned_staff:
			var employee_profession: String = str(employee.profession_id)
			var matches_position: bool = (
				employee_profession == profession_id
				or (
					profession_id == "actor"
					and employee_profession == "extra"
				)
			)
			if matches_position:
				result[profession_id] = str(employee.id)
				break
	for employee in assigned_staff:
		if str(employee.profession_id) == "producer":
			result["producer"] = str(employee.id)
			break
	return result


func _has_complete_production_assignments(
	crew_assignments: Dictionary,
	cast_assignments: Dictionary,
	assigned_staff: Array
) -> bool:
	if _latest_script == null:
		return false
	if not bool(
		_film_production_system.call(
			"can_start_project",
			_latest_script,
			crew_assignments,
			cast_assignments
		)
	):
		return false
	var assigned_employee_ids: Dictionary = {}
	for employee in assigned_staff:
		assigned_employee_ids[str(employee.id)] = true
	for employee_id_value in crew_assignments.values():
		if not assigned_employee_ids.has(str(employee_id_value)):
			return false
	for employee_id_value in cast_assignments.values():
		if not assigned_employee_ids.has(str(employee_id_value)):
			return false
	return true


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
	if not _has_complete_production_assignments(
		crew_assignments,
		cast_assignments,
		assigned_staff
	):
		_film_production_status_label.text = (
			"Не хватает назначенных сотрудников. Проверь режиссёра, "
			+ "оператора, техника и актёров на все роли."
		)
		return

	var project_id: String = "FILM-%04d" % _next_script_sequence
	var seed: int = (
		int(_game_clock.current_day) * 100000
		+ int(_game_clock.current_hour) * 1000
		+ int(_game_clock.current_minute) * 10
		+ _next_script_sequence
	)
	var scene_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		_latest_script.scenes,
		_set_inventory.get_owned_prop_ids(),
		str(_latest_script.genre_id)
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
		int(_game_clock.current_minute),
		scene_setups
	)
	if project == null:
		_film_production_status_label.text = (
			"Не удалось запустить производство. Проверь сценарий, роли и команду."
		)
		return

	if (
		_active_film_project != null
		and _active_editing_project != null
		and str(_active_editing_project.status) == "completed"
	):
		_completed_film_archive.append({
			"production": _active_film_project.to_dict(),
			"editing": _active_editing_project.to_dict(),
		})
	_active_editing_project = null
	_film_editing_editor_id = ""

	_next_script_sequence += 1
	_active_film_project = project
	_active_film_script = _latest_script
	_active_scene_performer_ids.clear()
	_active_set_dressing_technician_id = ""
	_dispatch_film_crew_to_stage()
	_apply_film_crew_actions()
	_sync_film_scene_performance()
	_sync_film_set_dressing()
	_update_film_stage_slate()
	_update_film_production_ui()


func _get_sound_stage_building_id() -> String:
	for building in _buildings:
		if str(building.building_type_id) == "sound_stage":
			return str(building.id)
	return ""


func _dispatch_film_crew_to_stage() -> void:
	if (
		_active_film_project == null
		or not is_instance_valid(_character_manager)
	):
		return
	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	for profession_id in [
		"director",
		"camera_operator",
		"technician",
		"producer",
	]:
		var employee_id: String = str(
			crew_assignments.get(profession_id, "")
		)
		if not employee_id.is_empty():
			_character_manager.call(
				"dispatch_employee_to_workplace",
				employee_id
			)


func _advance_film_production() -> void:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
	):
		return

	if str(_active_film_project.current_phase) == "preparation":
		_dispatch_film_crew_to_stage()

	var cast_ready: bool = _sync_film_scene_performance()
	_sync_film_set_dressing()
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
		_apply_film_crew_actions()
		if str(_active_film_project.current_phase) == "preparation":
			_refresh_active_scene_set_dressing_if_unstarted()
		_sync_film_set_dressing()
		_sync_film_scene_performance()
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
	var slate_title: String = "%s · %s" % [
		str(scene.get("beat", "Съёмочная сцена")),
		str(scene.get("location", "Павильон")),
	]
	set_production_scene(
		stage_id,
		int(scene.get("scene_number", _active_film_project.current_scene_index + 1)),
		slate_title,
		phase_title
	)


func _are_film_crew_ready() -> bool:
	var crew_assignments: Dictionary = _active_film_project.crew_assignments
	for profession_id in ["director", "camera_operator", "technician"]:
		var employee_id: String = str(
			crew_assignments.get(profession_id, "")
		)
		var employee: Variant = _find_employee(employee_id)
		if employee == null:
			return false
		if (
			profession_id == "technician"
			and employee_id == _active_set_dressing_technician_id
			and str(_active_film_project.current_phase) == "set_dressing"
		):
			var technician_actor: Variant = _character_manager.call(
				"get_employee_actor",
				employee_id
			)
			if (
				technician_actor != null
				and is_instance_valid(technician_actor)
				and bool(technician_actor.call("is_in_scene_performance"))
			):
				if bool(technician_actor.call("is_at_scene_mark")):
					continue
				return false
		var at_workplace: bool = bool(
			_character_manager.call(
				"dispatch_employee_to_workplace",
				employee_id
			)
		)
		if not at_workplace:
			return false
	return true


func _sync_film_scene_performance() -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or _active_film_script == null
	):
		var idle_stage_id: String = _get_sound_stage_building_id()
		if not idle_stage_id.is_empty():
			set_stage_camera_target(idle_stage_id, Vector3.ZERO, false)
			_restore_off_camera_staff(idle_stage_id)
		for employee_id in _active_scene_performer_ids:
			var actor: Variant = _character_manager.call(
				"get_employee_actor",
				employee_id
			)
			if actor != null and is_instance_valid(actor):
				var return_path: Array[Vector3] = []
				if not idle_stage_id.is_empty():
					return_path = get_scene_path(
						idle_stage_id,
						actor.global_position,
						actor.call("get_workplace_position")
					)
				if not return_path.is_empty():
					actor.call("return_to_workplace", return_path)
		_active_scene_performer_ids.clear()
		if not _active_set_dressing_technician_id.is_empty():
			var technician_actor: Variant = _character_manager.call(
				"get_employee_actor",
				_active_set_dressing_technician_id
			)
			if technician_actor != null and is_instance_valid(technician_actor):
				var technician_return_path: Array[Vector3] = []
				if not idle_stage_id.is_empty():
					technician_return_path = get_scene_path(
						idle_stage_id,
						technician_actor.global_position,
						technician_actor.call("get_workplace_position")
					)
				if not technician_return_path.is_empty():
					technician_actor.call(
						"return_to_workplace",
						technician_return_path
					)
			_active_set_dressing_technician_id = ""
		return false

	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return false

	var current_phase: String = str(_active_film_project.current_phase)
	if current_phase in ["preparation", "set_dressing"]:
		_restore_off_camera_staff(stage_id)
		_release_cast_for_scene_preparation(stage_id, current_phase)
		set_stage_camera_target(
			stage_id,
			get_scene_focus_point(stage_id),
			false
		)
		return true

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
	var camera_target: Vector3 = focus_point
	if not marks.is_empty():
		camera_target = Vector3.ZERO
		for mark in marks:
			camera_target += mark
		camera_target /= float(marks.size())
		camera_target.y += 1.2
	var camera_active: bool = (
		str(_active_film_project.current_phase) == "rehearsal"
		or str(_active_film_project.current_phase) == "shooting"
		or str(_active_film_project.current_phase) == "review"
	)
	set_stage_camera_target(stage_id, camera_target, camera_active)
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
		var at_workplace: bool = false
		if not already_performing:
			at_workplace = bool(
				_character_manager.call(
					"dispatch_employee_to_workplace",
					employee_id
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
		var movement_path: Array[Vector3] = get_scene_path(
			stage_id,
			actor.global_position,
			marks[performer_index]
		)
		if movement_path.is_empty():
			all_at_marks = false
			continue
		actor.call(
			"start_scene_performance",
			marks[performer_index],
			actor_focus,
			action_id,
			dialogue_text,
			movement_path
		)
		_character_manager.call(
			"set_employee_task",
			employee_id,
			_get_cast_production_task(
				str(_active_film_project.current_phase),
				int(_active_film_project.current_scene_index) + 1
			)
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
			and previous_actor != null
			and is_instance_valid(previous_actor)
		):
			_character_manager.call(
				"set_employee_task",
				previous_id,
				"Участвует в съёмках фильма"
			)
			var previous_return_path: Array[Vector3] = get_scene_path(
				stage_id,
				previous_actor.global_position,
				previous_actor.call("get_workplace_position")
			)
			if not previous_return_path.is_empty():
				previous_actor.call("return_to_workplace", previous_return_path)

	_active_scene_performer_ids = new_active_ids
	var bystanders_ready: bool = _move_stage_bystanders_off_camera(
		stage_id,
		performer_ids
	)
	return all_at_marks and bystanders_ready


func _release_cast_for_scene_preparation(
	stage_id: String,
	phase: String
) -> void:
	if (
		_active_film_project == null
		or not is_instance_valid(_character_manager)
	):
		return

	var scene_number: int = int(_active_film_project.current_scene_index) + 1
	var processed_ids: Dictionary = {}
	var crew_ids: Array = _active_film_project.crew_assignments.values()
	for assigned_id_value in _active_film_project.cast_assignments.values():
		var employee_id: String = str(assigned_id_value)
		if employee_id.is_empty() or processed_ids.has(employee_id):
			continue
		processed_ids[employee_id] = true
		if crew_ids.has(employee_id):
			continue

		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if actor == null or not is_instance_valid(actor):
			continue

		if (
			bool(actor.call("is_returning_to_workplace"))
			or bool(actor.call("is_leaving_workplace"))
		):
			pass
		elif not str(actor.call("get_workplace_building_id")).is_empty():
			actor.call("leave_workplace")

		_character_manager.call(
			"set_employee_task",
			employee_id,
			_get_cast_production_task(phase, scene_number)
		)

	_active_scene_performer_ids.clear()


func _move_stage_bystanders_off_camera(
	stage_id: String,
	performer_ids: Array
) -> bool:
	if not is_instance_valid(_character_manager):
		return false
	var all_clear: bool = true
	var current_off_camera_ids: Array[String] = []
	var hold_slot: int = 0
	var cast_ids: Array = _active_film_project.cast_assignments.values()
	var crew_ids: Array = _active_film_project.crew_assignments.values()
	for employee in _get_assigned_staff(stage_id):
		var employee_id: String = str(employee.id)
		var is_cast_only: bool = (
			cast_ids.has(employee_id)
			and not crew_ids.has(employee_id)
		)
		if (
			employee_id.is_empty()
			or performer_ids.has(employee_id)
			or is_cast_only
		):
			continue
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if actor == null or not is_instance_valid(actor):
			continue
		if str(actor.call("get_workplace_building_id")) != stage_id:
			continue

		var hold_mark: Vector3 = get_scene_hold_mark(stage_id, hold_slot)
		hold_slot += 1
		current_off_camera_ids.append(employee_id)
		var already_at_mark: bool = (
			bool(actor.call("is_at_scene_hold_mark"))
			and actor.global_position.distance_to(hold_mark) <= 0.25
		)
		if not already_at_mark and not bool(actor.call("is_off_camera")):
			var movement_path: Array[Vector3] = get_scene_path(
				stage_id,
				actor.global_position,
				hold_mark
			)
			if movement_path.is_empty():
				all_clear = false
				continue
			actor.call("move_to_scene_hold", hold_mark, movement_path)
			_character_manager.call(
				"set_employee_task",
				employee_id,
				"Уходит за кадр перед съёмкой"
			)

		if _game_clock.is_manual_fast_forward:
			actor.call("snap_to_scene_hold_mark")
		if not bool(actor.call("is_at_scene_hold_mark")):
			all_clear = false
		else:
			_character_manager.call(
				"set_employee_task",
				employee_id,
				"За кадром во время съёмки"
			)

	for previous_id in _off_camera_employee_ids:
		if current_off_camera_ids.has(previous_id):
			continue
		var previous_actor: Variant = _character_manager.call(
			"get_employee_actor",
			previous_id
		)
		if (
			previous_actor == null
			or not is_instance_valid(previous_actor)
			or not bool(previous_actor.call("is_off_camera"))
		):
			continue
		if str(previous_actor.call("get_workplace_building_id")) != stage_id:
			previous_actor.call("leave_workplace")
		else:
			var return_path: Array[Vector3] = get_scene_path(
				stage_id,
				previous_actor.global_position,
				previous_actor.call("get_workplace_position")
			)
			if return_path.is_empty():
				previous_actor.call("leave_workplace")
			else:
				previous_actor.call("return_to_workplace", return_path)
		_character_manager.call("clear_employee_task", previous_id)

	_off_camera_employee_ids = current_off_camera_ids
	return all_clear


func _restore_off_camera_staff(stage_id: String) -> void:
	if _off_camera_employee_ids.is_empty():
		return
	if not is_instance_valid(_character_manager):
		_off_camera_employee_ids.clear()
		return
	for employee_id in _off_camera_employee_ids:
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if (
			actor == null
			or not is_instance_valid(actor)
			or not bool(actor.call("is_off_camera"))
		):
			continue
		if str(actor.call("get_workplace_building_id")) != stage_id:
			actor.call("leave_workplace")
		else:
			var return_path: Array[Vector3] = get_scene_path(
				stage_id,
				actor.global_position,
				actor.call("get_workplace_position")
			)
			if return_path.is_empty():
				actor.call("leave_workplace")
			else:
				actor.call("return_to_workplace", return_path)
		_character_manager.call("clear_employee_task", employee_id)
	_off_camera_employee_ids.clear()


func is_employee_off_camera(employee_id: String) -> bool:
	if not is_instance_valid(_character_manager):
		return false
	var actor: Node = _character_manager.call(
		"get_employee_actor",
		employee_id
	)
	if actor == null or not actor.has_method("is_off_camera"):
		return false
	return bool(actor.call("is_off_camera"))


func _sync_film_set_dressing() -> void:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
	):
		return
	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return

	var setup: Dictionary = _active_film_project.get_current_scene_setup()
	var phase: String = str(_active_film_project.current_phase)
	var progress: float = -1.0
	if phase == "preparation":
		progress = 0.0
	elif phase == "set_dressing":
		progress = float(_active_film_project.get_phase_progress_percent()) / 100.0
	elif phase in ["rehearsal", "shooting", "review"]:
		progress = 1.0
	if progress >= 0.0:
		set_scene_set_dressing(stage_id, setup, progress)

	var technician_id: String = str(
		_active_film_project.crew_assignments.get("technician", "")
	)
	var technician_actor: Variant = _character_manager.call(
		"get_employee_actor",
		technician_id
	)
	if technician_actor == null or not is_instance_valid(technician_actor):
		return
	if phase != "set_dressing":
		if (
			technician_id == _active_set_dressing_technician_id
			and bool(technician_actor.call("is_in_scene_performance"))
		):
			technician_actor.call(
				"set_scene_performance_action",
				"checking_equipment"
			)
		return

	var prop_count: int = get_set_dressing_prop_count(stage_id)
	if prop_count <= 0:
		if (
			technician_id == _active_set_dressing_technician_id
			and bool(technician_actor.call("is_in_scene_performance"))
		):
			technician_actor.call(
				"set_scene_performance_action",
				"checking_equipment"
			)
		return

	var prop_index: int = clampi(
		floori(progress * float(prop_count)),
		0,
		prop_count - 1
	)
	var target_position: Vector3 = get_set_dressing_mark(
		stage_id,
		prop_index
	)
	var focus_position: Vector3 = get_scene_focus_point(stage_id)
	var movement_path: Array[Vector3] = get_scene_path(
		stage_id,
		technician_actor.global_position,
		target_position
	)
	if movement_path.is_empty():
		return
	technician_actor.call(
		"start_scene_performance",
		target_position,
		focus_position,
		"placing_set_piece",
		"",
		movement_path
	)
	_active_set_dressing_technician_id = technician_id
	_character_manager.call(
		"set_employee_task",
		technician_id,
		"Устанавливает декорации сцены %d" % (
			int(_active_film_project.current_scene_index) + 1
		)
	)
	if _game_clock.is_manual_fast_forward:
		technician_actor.call("snap_to_scene_mark")


func _get_cast_production_task(phase: String, scene_number: int) -> String:
	match phase:
		"preparation":
			return "Гуляет по студии, пока готовят сцену %d" % scene_number
		"set_dressing":
			return "Гуляет по студии, пока монтируют декорации сцены %d" % scene_number
		"rehearsal":
			return "Репетирует сцену %d" % scene_number
		"shooting":
			return "Снимается в сцене %d" % scene_number
		"review":
			return "Ожидает просмотра сцены %d" % scene_number
		_:
			return "Участвует в съёмках фильма"


func _get_scene_actor_action(
	phase: String,
	scene: Dictionary,
	is_speaker: bool
) -> String:
	match phase:
		"preparation":
			return "rehearsing"
		"set_dressing":
			return "waiting"
		"rehearsal":
			return "rehearsing"
		"review":
			return "reviewing"
		"shooting":
			if is_speaker:
				return "speaking"
			var beat: String = str(scene.get("beat", ""))
			var action_text: String = str(scene.get("action", "")).to_lower()
			if (
				beat.contains("Кульминация")
				or beat.contains("Поворот")
				or action_text.contains("противостоя")
				or action_text.contains("спор")
				or action_text.contains("обвин")
			):
				return "dramatic"
			if (
				action_text.contains("обнаруж")
				or action_text.contains("наход")
				or action_text.contains("улику")
				or action_text.contains("карту")
			):
				return "pointing"
			if (
				action_text.contains("встреч")
				or action_text.contains("возвращ")
				or action_text.contains("привет")
			):
				return "greeting"
			if (
				action_text.contains("ищ")
				or action_text.contains("след")
				or action_text.contains("исслед")
			):
				return "searching"
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
	if phase == "set_dressing":
		var setup: Dictionary = _active_film_project.get_current_scene_setup()
		var raw_props: Variant = setup.get("prop_ids", [])
		var has_props: bool = raw_props is Array and not raw_props.is_empty()
		task_by_profession["technician"] = (
			"Расставляет декорации сцены %d" % scene_number
			if has_props
			else "Готовит нейтральную площадку сцены %d" % scene_number
		)
		action_by_profession["technician"] = (
			"placing_set_piece" if has_props else "checking_equipment"
		)
	elif phase == "review":
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

	for cast_employee_id_value in _active_film_project.cast_assignments.values():
		var cast_employee_id: String = str(cast_employee_id_value)
		if not cast_employee_id.is_empty():
			_character_manager.call(
				"set_employee_task",
				cast_employee_id,
				"Участвует в съёмках фильма"
			)


func _reset_film_crew_actions() -> void:
	if _active_film_project == null:
		return
	var participant_ids: Array[String] = []
	for crew_employee_id_value in _active_film_project.crew_assignments.values():
		var crew_employee_id: String = str(crew_employee_id_value)
		if (
			not crew_employee_id.is_empty()
			and not participant_ids.has(crew_employee_id)
		):
			participant_ids.append(crew_employee_id)
	for cast_employee_id_value in _active_film_project.cast_assignments.values():
		var cast_employee_id: String = str(cast_employee_id_value)
		if (
			not cast_employee_id.is_empty()
			and not participant_ids.has(cast_employee_id)
		):
			participant_ids.append(cast_employee_id)
	for participant_id in participant_ids:
		if _find_employee(participant_id) == null:
			continue
		_character_manager.call("clear_employee_task", participant_id)
		_character_manager.call(
			"set_employee_production_action",
			participant_id,
			""
		)


func _advance_film_editing() -> void:
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
		_update_film_production_ui()
		var selected_building: Variant = _find_building(_selected_building_id)
		if (
			selected_building != null
			and str(selected_building.building_type_id) == "editing_suite"
		):
			_refresh_building_detail()


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
	_building_detail_layout.add_child(heading)

	if _active_film_project == null:
		var empty_label := Label.new()
		empty_label.text = "Готовых съёмок пока нет. Сначала заверши производство фильма в съёмочном павильоне."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_building_detail_layout.add_child(empty_label)
		return
	if str(_active_film_project.status) != "completed":
		var waiting_label := Label.new()
		waiting_label.text = "Монтаж станет доступен после завершения съёмок всех сцен."
		waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_building_detail_layout.add_child(waiting_label)
		return

	var editor_candidates: Array = []
	for employee in assigned_staff:
		if str(employee.profession_id) == "film_editor":
			editor_candidates.append(employee)

	if _active_editing_project == null:
		var editor_heading := Label.new()
		editor_heading.text = "ОТВЕТСТВЕННЫЙ МОНТАЖЁР"
		_building_detail_layout.add_child(editor_heading)

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
		_building_detail_layout.add_child(_film_editing_editor_option)

		var create_note := Label.new()
		create_note.text = "Сначала подготовь проект и проверь порядок сцен. После начала монтажа таймлайн будет заблокирован."
		create_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_building_detail_layout.add_child(create_note)

		_film_editing_create_button = Button.new()
		_film_editing_create_button.text = "ПОДГОТОВИТЬ МОНТАЖ"
		_film_editing_create_button.disabled = _film_editing_editor_id.is_empty()
		_film_editing_create_button.pressed.connect(
			_on_create_film_editing_project_pressed
		)
		_building_detail_layout.add_child(_film_editing_create_button)
		return

	var project: Variant = _active_editing_project
	_film_editing_status_label = Label.new()
	_film_editing_status_label.add_theme_font_size_override("font_size", 14)
	_film_editing_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(_film_editing_status_label)

	_film_editing_progress_bar = ProgressBar.new()
	_film_editing_progress_bar.min_value = 0.0
	_film_editing_progress_bar.max_value = 100.0
	_film_editing_progress_bar.show_percentage = true
	_film_editing_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_detail_layout.add_child(_film_editing_progress_bar)

	_film_editing_detail_label = Label.new()
	_film_editing_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(_film_editing_detail_label)

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
		_building_detail_layout.add_child(_film_editing_start_button)

		_film_editing_cancel_button = Button.new()
		_film_editing_cancel_button.text = "ОТМЕНИТЬ ПОДГОТОВКУ"
		_film_editing_cancel_button.pressed.connect(
			_on_cancel_film_editing_draft_pressed
		)
		_building_detail_layout.add_child(_film_editing_cancel_button)
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
	_building_detail_layout.add_child(heading)

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
	_building_detail_layout.add_child(_film_editing_timeline_option)

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
	_building_detail_layout.add_child(movement_row)

	var timeline_note := Label.new()
	timeline_note.text = (
		"Это меняет порядок сцен в готовом фильме, а не порядок съёмок."
	)
	timeline_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timeline_note.add_theme_font_size_override("font_size", 10)
	_building_detail_layout.add_child(timeline_note)


func _build_film_editing_replacement_controls(
	assigned_staff: Array
) -> void:
	var note := Label.new()
	note.text = (
		"Назначенный монтажёр больше не работает в этом отделе. "
		+ "Выбери сотрудника для продолжения проекта."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_building_detail_layout.add_child(note)

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
	_building_detail_layout.add_child(_film_editing_replacement_option)

	_film_editing_replace_button = Button.new()
	_film_editing_replace_button.text = "ПЕРЕНАЗНАЧИТЬ МОНТАЖЁРА"
	_film_editing_replace_button.disabled = (
		_film_editing_replacement_option.disabled
	)
	_film_editing_replace_button.pressed.connect(
		_on_replace_film_editor_pressed
	)
	_building_detail_layout.add_child(_film_editing_replace_button)


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
		_refresh_building_detail()


func _on_cancel_film_editing_draft_pressed() -> void:
	if (
		_active_editing_project == null
		or str(_active_editing_project.status) != "draft"
	):
		return
	_active_editing_project = null
	_film_editing_editor_id = ""
	_refresh_building_detail()


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
		_active_film_project == null
		or str(_active_film_project.status) != "completed"
		or _film_editing_editor_id.is_empty()
	):
		return
	var editor: Variant = _find_employee(_film_editing_editor_id)
	if editor == null:
		return
	var project_id: String = "EDIT-%04d" % _next_film_editing_sequence
	var project: Variant = _film_editing_system.call(
		"create_project",
		_active_film_project,
		_film_editing_editor_id,
		float(editor.skills.get("editing", 0.0)),
		project_id,
		int(_game_clock.current_day),
		int(_game_clock.current_hour),
		int(_game_clock.current_minute)
	)
	if project == null:
		return
	_next_film_editing_sequence += 1
	_active_editing_project = project
	_refresh_building_detail()


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
		_refresh_building_detail()


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
		_refresh_building_detail()


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
			+ "Монтажёр: %s\nОриентировочное время: %d игровых минут"
		) % [
			str(project.film_title),
			int(project.source_quality),
			editor_name,
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
			+ "Прошло: %d мин · Осталось примерно: %d мин\n%s"
		) % [
			str(project.film_title),
			project.get_phase_title(),
			int(project.phase_minutes_elapsed),
			int(project.phase_duration_minutes),
			int(project.total_elapsed_minutes),
			int(project.get_remaining_work_minutes()),
			str(project.last_activity_message),
		]
	else:
		_film_editing_status_label.text = "СТАТУС: ФИЛЬМ СМОНТИРОВАН"
		_film_editing_detail_label.text = (
			"Фильм: %s\nИтоговое качество: %d/100\n"
			+ "Качество исходного материала: %d/100\n"
			+ "Навык монтажёра: %d/100\nСвязность таймлайна: %d/100\n"
			+ "Затрачено: %d игровых минут\nФильм готов к выпуску."
		) % [
			str(project.film_title),
			int(project.final_quality),
			int(project.source_quality),
			roundi(float(project.editor_skill)),
			int(project.continuity_score),
			int(project.total_elapsed_minutes),
		]


func _format_set_prop_titles(prop_ids: Array) -> String:
	var titles: Array[String] = []
	for prop_id_value in prop_ids:
		var prop_id: String = str(prop_id_value)
		var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(prop_id)
		titles.append(str(definition.get("title", prop_id)))
	return ", ".join(titles)


func _get_script_set_dressing_preview(script: Variant) -> Dictionary:
	if script == null:
		return {}
	var scene_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		script.scenes,
		_set_inventory.get_owned_prop_ids(),
		str(script.genre_id)
	)
	var missing_lookup: Dictionary = {}
	var fully_dressed_scene_count: int = 0
	for setup in scene_setups:
		var missing_prop_ids: Array = setup.get("missing_prop_ids", [])
		if missing_prop_ids.is_empty():
			fully_dressed_scene_count += 1
		for prop_id_value in missing_prop_ids:
			missing_lookup[str(prop_id_value)] = true
	var missing_prop_ids: Array[String] = []
	for prop_id_value in missing_lookup.keys():
		missing_prop_ids.append(str(prop_id_value))
	missing_prop_ids.sort()
	return {
		"scene_count": scene_setups.size(),
		"fully_dressed_scene_count": fully_dressed_scene_count,
		"missing_prop_ids": missing_prop_ids,
	}


func _update_film_production_ui() -> void:
	if not is_instance_valid(_film_production_status_label):
		return
	if not is_instance_valid(_film_production_progress_bar):
		return
	if not is_instance_valid(_film_production_detail_label):
		return

	if _active_film_project == null:
		_film_production_progress_bar.value = 0.0
		var can_start: bool = _can_start_film_production()
		if _latest_script == null:
			_film_production_status_label.text = "ОЖИДАЕТ ГОТОВЫЙ СЦЕНАРИЙ"
			_film_production_detail_label.text = (
				"Заверши сценарий в сценарном отделе, затем назначь актёров "
				+ "на роли и съёмочную группу."
			)
		elif can_start:
			_film_production_status_label.text = "ГОТОВО К СЪЁМКАМ"
			_film_production_detail_label.text = (
				"Сценарий и команда назначены. Нажми «НАЧАТЬ СЪЁМКИ»: "
				+ "группа сама соберётся на площадке, а фильм пройдёт сцены "
				+ "без остановок на обед и конец смены."
			)
		else:
			_film_production_status_label.text = "НЕ ХВАТАЕТ КОМАНДЫ"
			_film_production_detail_label.text = (
				"Назначь режиссёра, оператора и техника, затем распредели "
				+ "актёров по всем ролям сценария."
			)
		if _latest_script != null:
			var set_preview: Dictionary = _get_script_set_dressing_preview(
				_latest_script
			)
			var missing_prop_ids: Array = set_preview.get(
				"missing_prop_ids",
				[]
			)
			var set_preview_text: String = (
				"Комплекты декораций: %d/%d сцен полностью обеспечены."
				% [
					int(set_preview.get("fully_dressed_scene_count", 0)),
					int(set_preview.get("scene_count", 0)),
				]
			)
			if not missing_prop_ids.is_empty():
				set_preview_text += (
					"\nНе хватает: %s. Съёмки не блокируются, "
					+ "но отсутствие нужных декораций снизит качество сцен."
				) % _format_set_prop_titles(missing_prop_ids)
			else:
				set_preview_text += "\nВсе необходимые декорации уже куплены."
			_film_production_detail_label.text += "\n\n" + set_preview_text

		if is_instance_valid(_film_production_start_button):
			_film_production_start_button.text = "НАЧАТЬ СЪЁМКИ"
			_film_production_start_button.disabled = not can_start
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
		var setup: Dictionary = project.get_current_scene_setup()
		var setup_props: Array = setup.get("prop_ids", [])
		var required_props: Array = setup.get("required_prop_ids", setup_props)
		var missing_props: Array = setup.get("missing_prop_ids", [])
		var installed_prop_count: int = setup_props.size()
		var phase: String = str(project.current_phase)
		if phase == "preparation":
			installed_prop_count = 0
		elif phase == "set_dressing":
			installed_prop_count = floori(
				float(project.get_phase_progress_percent()) / 100.0
				* float(setup_props.size())
			)
		var prop_coverage_text: String = (
			"%d/%d" % [installed_prop_count, required_props.size()]
			if not required_props.is_empty()
			else "не требуется"
		)
		var prop_quality_text: String = "Качество декораций: %d/100" % roundi(
			float(setup.get("set_dressing_quality", 45.0))
		)
		if not missing_props.is_empty():
			prop_quality_text += "\nНе хватает: %s" % _format_set_prop_titles(
				missing_props
			)
			if (
				phase == "set_dressing"
				and int(project.phase_minutes_elapsed) > 0
			) or phase in ["rehearsal", "shooting", "review"]:
				prop_quality_text += (
					"\nНовые покупки будут доступны со следующей сцены."
				)
		_film_production_detail_label.text = (
			"Фильм: %s\nСцена %d: %s · %s\n"
			+ "Декорации: %s · реквизит %s\n%s\n"
			+ "%s\n%s\n"
			+ "Событие: %s\n"
			+ "Этап: %d / %d мин · Всего прошло: %d мин · Осталось примерно: %d мин\n"
			+ "Пересъёмок текущей сцены: %d"
		) % [
			str(project.film_title),
			int(scene.get("scene_number", project.current_scene_index + 1)),
			str(scene.get("beat", "")),
			str(scene.get("location", "")),
			str(setup.get("set_title", "Нейтральная площадка")),
			prop_coverage_text,
			prop_quality_text,
			str(scene.get("action", "")),
			dialogue,
			str(project.last_activity_message),
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
			"Следующий этап: монтаж в монтажном отделе.",
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
			var editing_completed: bool = (
				_active_editing_project != null
				and str(_active_editing_project.status) == "completed"
			)
			_film_production_start_button.text = (
				"СНЯТЬ ФИЛЬМ ПО НОВОМУ СЦЕНАРИЮ"
				if editing_completed
				else "ОЖИДАЕТСЯ МОНТАЖ"
			)
			_film_production_start_button.disabled = not _can_start_film_production()


func _can_start_film_production() -> bool:
	if _latest_script == null:
		return false
	if _active_film_project != null:
		if str(_active_film_project.status) != "completed":
			return false
		if (
			_active_editing_project == null
			or str(_active_editing_project.status) != "completed"
		):
			return false

	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return false
	var assigned_staff: Array = _get_assigned_staff(stage_id)
	var crew_assignments: Dictionary = _get_film_crew_assignments(
		assigned_staff
	)
	return _has_complete_production_assignments(
		crew_assignments,
		_film_cast_assignments,
		assigned_staff
	)

func is_employee_in_active_production(employee_id: String) -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or employee_id.is_empty()
	):
		return false
	for assigned_id in _active_film_project.crew_assignments.values():
		if str(assigned_id) == employee_id:
			return true
	for assigned_id in _active_film_project.cast_assignments.values():
		if str(assigned_id) == employee_id:
			return true
	return false


func is_employee_waiting_for_scene(employee_id: String) -> bool:
	if (
		_active_film_project == null
		or str(_active_film_project.status) != "in_production"
		or _active_film_script == null
		or employee_id.is_empty()
	):
		return false
	var is_cast_member: bool = false
	for assigned_id in _active_film_project.cast_assignments.values():
		if str(assigned_id) == employee_id:
			is_cast_member = true
			break
	if not is_cast_member:
		return false

	var phase: String = str(_active_film_project.current_phase)
	if phase in ["preparation", "set_dressing"]:
		return true
	if phase in ["rehearsal", "shooting", "review"]:
		var current_performer_ids: Array = _film_production_system.call(
			"get_scene_performer_ids",
			_active_film_script,
			_active_film_project
		)
		return not current_performer_ids.has(employee_id)
	return false


func get_active_film_project() -> Variant:
	return _active_film_project


func get_active_film_editing_project() -> Variant:
	return _active_editing_project


func get_completed_film_archive() -> Array:
	return _completed_film_archive.duplicate(true)




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
