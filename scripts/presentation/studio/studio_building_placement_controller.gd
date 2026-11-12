extends RefCounted
class_name StudioBuildingPlacementController

signal placement_mode_requested(building_type_id: String)
signal building_placement_requested(
	building_type_id: String,
	world_position: Vector3,
	rotation_degrees: float,
	stage_size_tier: int
)

const GRID_SIZE: float = 2.0
const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const PLACEMENT_RULES_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_placement_rules.gd"
)

var _manager: Node
var _buildings: Array = []

var _placing_building_type_id: String = ""
var _placement_rotation_degrees: float = 0.0
var _placement_stage_size_tier: int = 2

var _stage_size_option: OptionButton
var _stage_size_label: Label
var _build_status_label: Label
var _placement_hint_label: Label

var _preview_mesh: MeshInstance3D
var _preview_material: StandardMaterial3D


func setup(manager: Node, buildings: Array) -> void:
	_manager = manager
	_buildings = buildings


func build_palette() -> PanelContainer:
	var build_panel := PanelContainer.new()
	build_panel.name = "BuildingPalettePanel"
	build_panel.custom_minimum_size = Vector2(0.0, 0.0)

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
	script_button.pressed.connect(_request_placement.bind("script_department"))
	build_layout.add_child(script_button)

	var stage_button := Button.new()
	stage_button.text = "＋ Съёмочный павильон"
	stage_button.tooltip_text = "Построить съёмочный павильон"
	stage_button.custom_minimum_size = Vector2(0.0, 42.0)
	stage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_button.pressed.connect(_request_placement.bind("sound_stage"))
	build_layout.add_child(stage_button)

	_stage_size_label = Label.new()
	_stage_size_label.text = "РАЗМЕР ПАВИЛЬОНА"
	_stage_size_label.add_theme_font_size_override("font_size", 10)
	_stage_size_label.visible = false
	build_layout.add_child(_stage_size_label)

	_stage_size_option = OptionButton.new()
	_stage_size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tier in range(1, 4):
		var size: Vector2 = BUILDING_CATALOG_SCRIPT.get_stage_footprint(tier)
		_stage_size_option.add_item(
			"%s · %.0f × %.0f м" % [
				BUILDING_CATALOG_SCRIPT.get_stage_size_title(tier),
				size.x,
				size.y,
			]
		)
		_stage_size_option.set_item_metadata(tier - 1, tier)
	_stage_size_option.select(1)
	_stage_size_option.visible = false
	_stage_size_option.item_selected.connect(_on_stage_size_selected)
	build_layout.add_child(_stage_size_option)

	var tv_studio_button := Button.new()
	tv_studio_button.text = "＋ Телевизионная студия"
	tv_studio_button.tooltip_text = "Построить отдельный павильон для сериалов и ток-шоу"
	tv_studio_button.custom_minimum_size = Vector2(0.0, 42.0)
	tv_studio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv_studio_button.pressed.connect(_request_placement.bind("tv_studio"))
	build_layout.add_child(tv_studio_button)

	var warehouse_button := Button.new()
	warehouse_button.text = "＋ Склад реквизита"
	warehouse_button.tooltip_text = "Построить дополнительный склад съёмочного инвентаря"
	warehouse_button.custom_minimum_size = Vector2(0.0, 42.0)
	warehouse_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warehouse_button.pressed.connect(_request_placement.bind("prop_warehouse"))
	build_layout.add_child(warehouse_button)

	var editing_button := Button.new()
	editing_button.text = "＋ Монтажный отдел"
	editing_button.tooltip_text = "Построить монтажный отдел"
	editing_button.custom_minimum_size = Vector2(0.0, 42.0)
	editing_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editing_button.pressed.connect(_request_placement.bind("editing_suite"))
	build_layout.add_child(editing_button)

	var cafeteria_button := Button.new()
	cafeteria_button.text = "＋ Столовая"
	cafeteria_button.tooltip_text = "Построить столовую для обеденных перерывов персонала"
	cafeteria_button.custom_minimum_size = Vector2(0.0, 42.0)
	cafeteria_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cafeteria_button.pressed.connect(_request_placement.bind("cafeteria"))
	build_layout.add_child(cafeteria_button)

	var housing_button := Button.new()
	housing_button.text = "＋ Домик персонала"
	housing_button.tooltip_text = "Построить жилой домик для отдыха сотрудников после смены"
	housing_button.custom_minimum_size = Vector2(0.0, 42.0)
	housing_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	housing_button.pressed.connect(_request_placement.bind("staff_housing"))
	build_layout.add_child(housing_button)

	var star_housing_button := Button.new()
	star_housing_button.text = "＋ Звёздный домик"
	star_housing_button.tooltip_text = "Построить отдельное жильё с одной кроватью для популярного актёра"
	star_housing_button.custom_minimum_size = Vector2(0.0, 42.0)
	star_housing_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	star_housing_button.pressed.connect(_request_placement.bind("star_bungalow"))
	build_layout.add_child(star_housing_button)

	var fitness_button := Button.new()
	fitness_button.text = "＋ Фитнес-центр"
	fitness_button.tooltip_text = "Построить зал для физической подготовки актёров"
	fitness_button.custom_minimum_size = Vector2(0.0, 42.0)
	fitness_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fitness_button.pressed.connect(_request_placement.bind("fitness_center"))
	build_layout.add_child(fitness_button)

	var lounge_button := Button.new()
	lounge_button.text = "＋ Клуб студии"
	lounge_button.tooltip_text = "Построить место отдыха и общения сотрудников"
	lounge_button.custom_minimum_size = Vector2(0.0, 42.0)
	lounge_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lounge_button.pressed.connect(_request_placement.bind("studio_lounge"))
	build_layout.add_child(lounge_button)

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

	return build_panel


func _request_placement(building_type_id: String) -> void:
	placement_mode_requested.emit(building_type_id)


func process() -> void:
	if is_placing_building():
		_update_placement_preview(_manager.get_viewport().get_mouse_position())


func is_placing_building() -> bool:
	return not _placing_building_type_id.is_empty()


func refresh_build_status(building_count: int) -> void:
	if not is_instance_valid(_build_status_label):
		return
	_build_status_label.text = "Построено зданий: %d" % building_count


func begin_placement(building_type_id: String) -> void:
	if not BUILDING_CATALOG_SCRIPT.has_building_type(building_type_id):
		return
	_placing_building_type_id = building_type_id
	_placement_rotation_degrees = 0.0
	if building_type_id == "sound_stage" and is_instance_valid(_stage_size_option):
		if _stage_size_option.selected >= 0:
			_placement_stage_size_tier = int(
				_stage_size_option.get_item_metadata(_stage_size_option.selected)
			)
	if is_instance_valid(_stage_size_label):
		_stage_size_label.visible = building_type_id == "sound_stage"
	if is_instance_valid(_stage_size_option):
		_stage_size_option.visible = building_type_id == "sound_stage"
	_create_placement_preview()
	if is_instance_valid(_placement_hint_label):
		_placement_hint_label.visible = true
	_set_placement_message("Выбери точку на территории.")
	_update_placement_preview(_manager.get_viewport().get_mouse_position())


func _on_stage_size_selected(selected_index: int) -> void:
	if selected_index < 0 or selected_index >= _stage_size_option.get_item_count():
		return
	_placement_stage_size_tier = int(
		_stage_size_option.get_item_metadata(selected_index)
	)
	if _placing_building_type_id == "sound_stage":
		_create_placement_preview()
		_update_placement_preview(_manager.get_viewport().get_mouse_position())
		_set_placement_message("Размер павильона изменён.")


func get_stage_size_tier() -> int:
	return _placement_stage_size_tier


func _create_placement_preview() -> void:
	if is_instance_valid(_preview_mesh):
		_preview_mesh.queue_free()
	var footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
		_placing_building_type_id,
		_placement_rotation_degrees,
		_placement_stage_size_tier
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
	_manager.add_child(_preview_mesh)


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
		_buildings,
		PLACEMENT_RULES_SCRIPT.DEFAULT_PLOT_HALF_SIZE,
		_placement_stage_size_tier
	)
	_preview_material.albedo_color = (
		Color(0.2, 0.85, 0.42, 0.38)
		if bool(validation.get("valid", false))
		else Color(0.92, 0.2, 0.16, 0.42)
	)


func handle_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			cancel_placement()
			_manager.get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_R:
			_placement_rotation_degrees = fposmod(
				_placement_rotation_degrees + 90.0,
				360.0
			)
			_create_placement_preview()
			_update_placement_preview(_manager.get_viewport().get_mouse_position())
			_manager.get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_placement()
		_manager.get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_try_place_building(mouse_event.position)
		_manager.get_viewport().set_input_as_handled()


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
		_buildings,
		PLACEMENT_RULES_SCRIPT.DEFAULT_PLOT_HALF_SIZE,
		_placement_stage_size_tier
	)
	if not bool(validation.get("valid", false)):
		_set_placement_message(str(validation.get("reason", "Здесь нельзя строить.")))
		return
	building_placement_requested.emit(
		_placing_building_type_id,
		snapped_position,
		_placement_rotation_degrees,
		_placement_stage_size_tier
	)


func set_placement_message(message: String) -> void:
	_set_placement_message(message)


func _set_placement_message(message: String) -> void:
	if not is_instance_valid(_placement_hint_label):
		return
	var title: String = BUILDING_CATALOG_SCRIPT.get_title(
		_placing_building_type_id
	)
	if _placing_building_type_id == "sound_stage":
		var size: Vector2 = BUILDING_CATALOG_SCRIPT.get_stage_footprint(
			_placement_stage_size_tier
		)
		title += " · %s · %.0f × %.0f м" % [
			BUILDING_CATALOG_SCRIPT.get_stage_size_title(
				_placement_stage_size_tier
			),
			size.x,
			size.y,
		]
	_placement_hint_label.text = (
		"Размещение: %s\n%s\nЛКМ — построить · R — повернуть · ПКМ/Esc — отменить"
		% [title, message]
	)


func cancel_placement() -> void:
	_placing_building_type_id = ""
	_placement_rotation_degrees = 0.0
	if is_instance_valid(_stage_size_label):
		_stage_size_label.visible = false
	if is_instance_valid(_stage_size_option):
		_stage_size_option.visible = false
	if is_instance_valid(_preview_mesh):
		_preview_mesh.queue_free()
	_preview_mesh = null
	_preview_material = null
	if is_instance_valid(_placement_hint_label):
		_placement_hint_label.visible = false
	refresh_build_status(_buildings.size())


func _get_ground_position(screen_position: Vector2) -> Vector3:
	var camera: Camera3D = _manager.get_viewport().get_camera_3d()
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
