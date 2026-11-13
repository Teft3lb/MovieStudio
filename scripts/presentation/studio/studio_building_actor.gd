extends Node3D
class_name StudioBuildingActor

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const NAVIGATION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)
const BUILDING_NAVIGATION_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_navigation_controller.gd"
)
const BUILDING_MARKER_PROVIDER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_marker_provider.gd"
)
const SET_PROP_VISUAL_BUILDER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_set_prop_visual_builder.gd"
)
const VISUAL_FACTORY_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_visual_factory.gd"
)
const INTERIOR_LIGHTING_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_interior_lighting_controller.gd"
)
const SOUND_STAGE_VISUAL_BUILDER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_sound_stage_visual_builder.gd"
)
const TV_STUDIO_VISUAL_BUILDER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_tv_studio_visual_builder.gd"
)
const OFFICE_VISUAL_BUILDER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_office_visual_builder.gd"
)
const FACILITY_VISUAL_BUILDER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_facility_visual_builder.gd"
)

const CUTAWAY_DISTANCE: float = 36.0
const WALL_THICKNESS: float = 0.28

var building_data: Variant
var _selection_marker: Node3D
var _is_selected: bool = false
var _roof_assembly: Node3D
var _wall_groups: Dictionary = {}
var _interior_root: Node3D
var _production_slate_label: Label3D
var _production_phase_label: Label3D
var _camera_rigs: Array[Node3D] = []
var _workplace_points: Array[Vector3] = []
var _entrance_inside: Vector3 = Vector3.ZERO
var _entrance_outside: Vector3 = Vector3.ZERO
var _set_dressing_root: Node3D
var _active_set_scene_key: String = ""
var _warehouse_inventory_root: Node3D
var _warehouse_storage_positions: Array[Vector3] = []
var _navigation_system: RefCounted
var _navigation_controller: RefCounted
var _marker_provider: RefCounted
var _set_prop_visual_builder: RefCounted
var _visual_factory: RefCounted
var _interior_lighting: RefCounted

func setup(data: Variant) -> void:
	building_data = data
	_navigation_system = NAVIGATION_SYSTEM_SCRIPT.new()
	_visual_factory = VISUAL_FACTORY_SCRIPT.new()
	_set_prop_visual_builder = SET_PROP_VISUAL_BUILDER_SCRIPT.new()
	_set_prop_visual_builder.call("setup", _visual_factory)
	name = "Building_%s" % str(data.id).replace("-", "_")
	position = data.position
	rotation_degrees.y = float(data.rotation_degrees)
	add_to_group("studio_building")
	_build_visual()
	_interior_lighting = INTERIOR_LIGHTING_SCRIPT.new()
	_interior_lighting.call(
		"setup",
		self,
		_interior_root,
		BUILDING_CATALOG_SCRIPT.get_footprint(
			str(building_data.building_type_id),
			0.0,
			int(building_data.stage_size_tier)
		),
		BUILDING_CATALOG_SCRIPT.get_building_height(
			str(building_data.building_type_id),
			int(building_data.stage_size_tier)
		),
		str(building_data.building_type_id)
	)
	_navigation_controller = BUILDING_NAVIGATION_CONTROLLER_SCRIPT.new()
	_navigation_controller.call(
		"setup",
		building_data,
		_interior_root,
		_navigation_system,
		_workplace_points,
		_entrance_inside,
		_entrance_outside,
		_set_dressing_root
	)
	_marker_provider = BUILDING_MARKER_PROVIDER_SCRIPT.new()
	_marker_provider.call(
		"setup",
		building_data,
		_interior_root,
		_workplace_points,
		_warehouse_storage_positions
	)
	_create_hitbox()
	_create_selection_marker()
	_create_name_tag()

func _process(delta: float) -> void:
	_update_cutaway()
	if _interior_lighting != null:
		_interior_lighting.call("advance", delta)


func is_interior_occupied() -> bool:
	return (
		_interior_lighting != null
		and bool(_interior_lighting.call("is_occupied"))
	)

func get_building_id() -> String:
	if building_data == null:
		return ""
	return str(building_data.id)

func set_selected(value: bool) -> void:
	_is_selected = value
	if is_instance_valid(_selection_marker):
		_selection_marker.visible = value
	_update_cutaway()

func get_workplace_path(slot_index: int) -> Array[Vector3]:
	if _navigation_controller == null:
		return []
	return _navigation_controller.call("get_workplace_path", slot_index)

func get_exit_path_from(
	start_world_position: Vector3,
	slot_index: int = -1
) -> Array[Vector3]:
	if _navigation_controller == null:
		return []
	return _navigation_controller.call(
		"get_exit_path_from",
		start_world_position,
		slot_index
	)

func get_workplace_position(slot_index: int) -> Vector3:
	if _navigation_controller == null:
		return global_position
	return _navigation_controller.call("get_workplace_position", slot_index)

func get_workplace_facing_direction(slot_index: int) -> Vector3:
	if _marker_provider == null:
		return Vector3.ZERO
	return _marker_provider.call("get_workplace_facing_direction", slot_index)

func get_scene_mark(
	slot_index: int,
	phase_id: String = "preparation",
	scene_index: int = 0
) -> Vector3:
	if _marker_provider == null:
		return Vector3.ZERO
	return _marker_provider.call(
		"get_scene_mark",
		slot_index,
		phase_id,
		scene_index
	)

func get_scene_hold_mark(slot_index: int) -> Vector3:
	if _marker_provider == null:
		return Vector3.ZERO
	return _marker_provider.call("get_scene_hold_mark", slot_index)

func get_scene_focus_point() -> Vector3:
	if _marker_provider == null:
		return Vector3.ZERO
	return _marker_provider.call("get_scene_focus_point")

func get_set_dressing_mark(prop_index: int) -> Vector3:
	if _marker_provider == null:
		return Vector3.ZERO
	return _marker_provider.call("get_set_dressing_mark", prop_index)

func _get_set_dressing_positions() -> Array[Vector3]:
	if _marker_provider == null:
		return []
	return _marker_provider.call("get_set_dressing_positions")

func get_storage_mark(prop_index: int) -> Vector3:
	if _marker_provider == null:
		return global_position
	return _marker_provider.call("get_storage_mark", prop_index)

func get_scene_path(
	start_world_position: Vector3,
	target_world_position: Vector3
) -> Array[Vector3]:
	if _navigation_controller == null:
		return []
	return _navigation_controller.call(
		"get_scene_path",
		start_world_position,
		target_world_position
	)

func get_set_dressing_prop_count() -> int:
	if not is_instance_valid(_set_dressing_root):
		return 0
	return _set_dressing_root.get_child_count()

func prepare_scene_set_dressing(setup: Dictionary) -> bool:
	if not is_instance_valid(_set_dressing_root):
		return false
	var raw_prop_ids: Variant = setup.get("prop_ids", [])
	var prop_ids: Array = []
	if raw_prop_ids is Array:
		prop_ids = raw_prop_ids
	var prop_signature: String = ""
	for prop_id_value in prop_ids:
		if not prop_signature.is_empty():
			prop_signature += ","
		prop_signature += str(prop_id_value)
	var scene_key: String = "%s:%s:%s" % [
		str(setup.get("scene_id", "")),
		str(setup.get("set_id", "neutral")),
		prop_signature,
	]
	if scene_key == _active_set_scene_key:
		return true
	if _set_dressing_root.get_child_count() > 0:
		push_warning(
			"StudioBuildingActor: refusing to replace set dressing before strike is complete."
		)
		return false
	_active_set_scene_key = scene_key
	var positions: Array[Vector3] = _get_set_dressing_positions()
	for prop_index in range(mini(prop_ids.size(), positions.size())):
		var prop_id: String = str(prop_ids[prop_index])
		var prop_root := Node3D.new()
		prop_root.name = "SetProp_%s" % prop_id
		prop_root.position = positions[prop_index]
		_build_set_prop_visual(prop_root, prop_id)
		_set_dressing_root.add_child(prop_root)
		prop_root.visible = false
	return true

func install_set_prop(prop_id: String) -> bool:
	var prop_node: Node3D = _find_set_prop(prop_id)
	if prop_node == null:
		return false
	prop_node.visible = true
	return true

func remove_set_prop(prop_id: String) -> bool:
	var prop_node: Node3D = _find_set_prop(prop_id)
	if prop_node == null:
		return false
	prop_node.visible = false
	return true

func clear_scene_set_dressing() -> void:
	if not is_instance_valid(_set_dressing_root):
		return
	for child in _set_dressing_root.get_children():
		_set_dressing_root.remove_child(child)
		child.queue_free()
	_active_set_scene_key = ""

func _find_set_prop(prop_id: String) -> Node3D:
	if not is_instance_valid(_set_dressing_root):
		return null
	return _set_dressing_root.get_node_or_null(
		"SetProp_%s" % prop_id
	) as Node3D

func set_scene_set_dressing(setup: Dictionary, progress: float) -> void:
	if not prepare_scene_set_dressing(setup):
		return
	var visible_count: int = clampi(
		floori(
			clampf(progress, 0.0, 1.0)
			* float(_set_dressing_root.get_child_count())
			+ 0.0001
		),
		0,
		_set_dressing_root.get_child_count()
	)
	for prop_index in range(_set_dressing_root.get_child_count()):
		var prop_node: Node3D = _set_dressing_root.get_child(
			prop_index
		) as Node3D
		prop_node.visible = prop_index < visible_count

func set_warehouse_inventory(prop_ids: Array) -> void:
	if not is_instance_valid(_warehouse_inventory_root):
		return
	for child in _warehouse_inventory_root.get_children():
		_warehouse_inventory_root.remove_child(child)
		child.queue_free()
	var shelf_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for shelf_level in range(3):
			for column in range(4):
				shelf_positions.append(Vector3(
					side * 3.75,
					0.62 + float(shelf_level) * 1.12,
					-2.55 + float(column) * 1.55
				))
	for prop_index in range(prop_ids.size()):
		var prop_id: String = str(prop_ids[prop_index])
		var prop_root := Node3D.new()
		prop_root.name = "StoredProp_%s" % prop_id
		prop_root.position = shelf_positions[
			posmod(prop_index, shelf_positions.size())
		]
		prop_root.scale = Vector3.ONE * 0.22
		_build_set_prop_visual(prop_root, prop_id)
		_warehouse_inventory_root.add_child(prop_root)

func _build_set_prop_visual(parent: Node3D, prop_id: String) -> void:
	if _set_prop_visual_builder == null:
		return
	_set_prop_visual_builder.call("build", parent, prop_id)

func set_production_scene(
	scene_number: int,
	scene_title: String,
	phase_title: String
) -> void:
	if is_instance_valid(_production_slate_label):
		if scene_number > 0:
			_production_slate_label.text = (
				"СЦЕНА %02d · %s" % [scene_number, scene_title]
			)
		else:
			_production_slate_label.text = scene_title
	if is_instance_valid(_production_phase_label):
		_production_phase_label.text = phase_title

func set_camera_target(target_position: Vector3, active: bool) -> void:
	for camera_rig in _camera_rigs:
		if not is_instance_valid(camera_rig):
			continue
		if active:
			camera_rig.look_at(target_position, Vector3.UP)
		else:
			camera_rig.rotation = Vector3.ZERO

func _build_visual() -> void:
	var building_type_id: String = str(building_data.building_type_id)
	var stage_size_tier: int = int(building_data.stage_size_tier)
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		building_type_id
	)
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		building_type_id,
		0.0,
		stage_size_tier
	)
	var height: float = BUILDING_CATALOG_SCRIPT.get_building_height(
		building_type_id,
		stage_size_tier
	)
	_create_interior_root()
	if BUILDING_CATALOG_SCRIPT.is_sound_stage(building_type_id):
		_build_sound_stage(footprint, height, definition)
		return
	match building_type_id:
		"editing_suite":
			_build_office_building(
				"editing_suite",
				footprint,
				height,
				definition
			)
		"prop_warehouse":
			_build_facility(
				"prop_warehouse",
				footprint,
				height,
				definition
			)
		"cafeteria":
			_build_facility(
				"cafeteria",
				footprint,
				height,
				definition
			)
		"staff_housing":
			_build_facility(
				"staff_housing",
				footprint,
				height,
				definition
			)
		"star_bungalow":
			_build_facility(
				"star_bungalow",
				footprint,
				height,
				definition
			)
		"fitness_center":
			_build_facility(
				"fitness_center",
				footprint,
				height,
				definition
			)
		"studio_lounge":
			_build_facility(
				"studio_lounge",
				footprint,
				height,
				definition
			)
		"tv_studio":
			_build_tv_studio(footprint, height, definition)
		_:
			_build_office_building(
				"script_department",
				footprint,
				height,
				definition
			)

func _create_interior_root() -> void:
	_interior_root = Node3D.new()
	_interior_root.name = "Interior"
	add_child(_interior_root)

func _build_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var builder: RefCounted = SOUND_STAGE_VISUAL_BUILDER_SCRIPT.new()
	var visual_state: Dictionary = builder.call(
		"build",
		self,
		_interior_root,
		_visual_factory,
		footprint,
		height,
		definition,
		int(building_data.stage_size_tier)
	)
	_apply_building_visual_state(visual_state)

func _build_tv_studio(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var builder: RefCounted = TV_STUDIO_VISUAL_BUILDER_SCRIPT.new()
	var visual_state: Dictionary = builder.call(
		"build",
		self,
		_interior_root,
		_visual_factory,
		footprint,
		height,
		definition
	)
	_apply_building_visual_state(visual_state)

func _build_office_building(
	building_type_id: String,
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var builder: RefCounted = OFFICE_VISUAL_BUILDER_SCRIPT.new()
	var visual_state: Dictionary = builder.call(
		"build",
		self,
		_interior_root,
		_visual_factory,
		building_type_id,
		footprint,
		height,
		definition
	)
	_apply_building_visual_state(visual_state)

func _apply_building_visual_state(visual_state: Dictionary) -> void:
	_roof_assembly = visual_state.get("roof_assembly") as Node3D
	_set_dressing_root = visual_state.get("set_dressing_root") as Node3D
	_production_slate_label = visual_state.get("production_slate_label") as Label3D
	_production_phase_label = visual_state.get("production_phase_label") as Label3D
	_camera_rigs.clear()
	var camera_rigs: Array = visual_state.get("camera_rigs", [])
	for camera_rig in camera_rigs:
		if camera_rig is Node3D:
			_camera_rigs.append(camera_rig)
	_workplace_points.clear()
	var workplace_points: Array = visual_state.get("workplace_points", [])
	for workplace_point in workplace_points:
		if typeof(workplace_point) == TYPE_VECTOR3:
			_workplace_points.append(workplace_point)

	_warehouse_inventory_root = visual_state.get(
		"warehouse_inventory_root"
	) as Node3D
	_warehouse_storage_positions.clear()
	var warehouse_storage_positions: Array = visual_state.get(
		"warehouse_storage_positions",
		[]
	)
	for storage_position in warehouse_storage_positions:
		if typeof(storage_position) == TYPE_VECTOR3:
			_warehouse_storage_positions.append(storage_position)

func get_wall_group_for_visual_builder(group_id: String) -> Node3D:
	return _wall_groups.get(group_id) as Node3D

func _build_facility(
	building_type_id: String,
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var builder: RefCounted = FACILITY_VISUAL_BUILDER_SCRIPT.new()
	var visual_state: Dictionary = builder.call(
		"build",
		self,
		_interior_root,
		_visual_factory,
		building_type_id,
		footprint,
		height,
		definition
	)
	_apply_building_visual_state(visual_state)

func _create_perimeter_walls(
	width: float,
	depth: float,
	wall_height: float,
	wall_color: Color,
	door_width: float,
	door_height: float
) -> void:
	var wall_y: float = wall_height * 0.5
	var half_width: float = width * 0.5
	var half_depth: float = depth * 0.5
	var back_group: Node3D = _create_wall_group("back")
	_create_wall_panel(back_group, "BackWall", Vector3(width, wall_height, WALL_THICKNESS), wall_color, Vector3(0.0, wall_y, -half_depth))
	var left_group: Node3D = _create_wall_group("left")
	_create_wall_panel(left_group, "LeftWall", Vector3(WALL_THICKNESS, wall_height, depth), wall_color, Vector3(-half_width, wall_y, 0.0))
	var right_group: Node3D = _create_wall_group("right")
	_create_wall_panel(right_group, "RightWall", Vector3(WALL_THICKNESS, wall_height, depth), wall_color, Vector3(half_width, wall_y, 0.0))
	var front_group: Node3D = _create_wall_group("front")
	var side_width: float = (width - door_width) * 0.5
	_create_wall_panel(front_group, "FrontWallLeft", Vector3(side_width, wall_height, WALL_THICKNESS), wall_color, Vector3(-(door_width * 0.5 + side_width * 0.5), wall_y, half_depth))
	_create_wall_panel(front_group, "FrontWallRight", Vector3(side_width, wall_height, WALL_THICKNESS), wall_color, Vector3(door_width * 0.5 + side_width * 0.5, wall_y, half_depth))
	var header_size: Vector3 = Vector3(door_width, maxf(wall_height - door_height, 0.25), WALL_THICKNESS)
	var header_position: Vector3 = Vector3(0.0, door_height + maxf(wall_height - door_height, 0.25) * 0.5, half_depth)
	_create_wall_panel(front_group, "DoorHeader", header_size, wall_color, header_position)
	_entrance_inside = Vector3(0.0, 0.0, half_depth - 0.8)
	_entrance_outside = Vector3(0.0, 0.0, half_depth + 1.4)

func _create_wall_group(group_id: String) -> Node3D:
	var group := Node3D.new()
	group.name = "%sWallGroup" % group_id.capitalize()
	_interior_root.add_child(group)
	_wall_groups[group_id] = group
	return group

func _create_floor(
	footprint: Vector2,
	color: Color,
	node_name: String
) -> void:
	_visual_factory.call("create_floor", _interior_root, footprint, color, node_name)

func _create_wall_panel(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> void:
	_visual_factory.call("create_wall_panel", parent, node_name, size, color, local_position)

func _create_hitbox() -> void:
	var building_type_id: String = str(building_data.building_type_id)
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		building_type_id,
		0.0,
		int(building_data.stage_size_tier)
	)
	var height: float = BUILDING_CATALOG_SCRIPT.get_building_height(
		building_type_id,
		int(building_data.stage_size_tier)
	)
	var body := StaticBody3D.new()
	body.name = "BuildingHitbox"
	body.collision_layer = 4
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint.x, height, footprint.y)
	collision.shape = shape
	collision.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(collision)
	add_child(body)

func _create_selection_marker() -> void:
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		str(building_data.building_type_id),
		0.0,
		int(building_data.stage_size_tier)
	)
	var marker := Node3D.new()
	marker.name = "SelectionMarker"
	marker.position.y = 0.035
	marker.visible = false
	add_child(marker)
	_selection_marker = marker
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.78, 0.22)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var thickness: float = 0.10
	_create_marker_strip(marker, "Front", Vector3(footprint.x, thickness, thickness), Vector3(0.0, 0.0, footprint.y * 0.5), material)
	_create_marker_strip(marker, "Back", Vector3(footprint.x, thickness, thickness), Vector3(0.0, 0.0, -footprint.y * 0.5), material)
	_create_marker_strip(marker, "Left", Vector3(thickness, thickness, footprint.y), Vector3(-footprint.x * 0.5, 0.0, 0.0), material)
	_create_marker_strip(marker, "Right", Vector3(thickness, thickness, footprint.y), Vector3(footprint.x * 0.5, 0.0, 0.0), material)

func _create_marker_strip(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	material: StandardMaterial3D
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)

func _create_name_tag() -> void:
	var height: float = BUILDING_CATALOG_SCRIPT.get_building_height(
		str(building_data.building_type_id),
		int(building_data.stage_size_tier)
	)
	_create_label(
		self,
		"BuildingName",
		str(building_data.display_name),
		Vector3(0.0, height + 0.55, 0.0),
		26
	)

func _create_label(
	parent: Node3D,
	node_name: String,
	label_text: String,
	local_position: Vector3,
	font_size: int
) -> void:
	_visual_factory.call("create_label", parent, node_name, label_text, local_position, font_size)

func _make_material(color: Color) -> StandardMaterial3D:
	return _visual_factory.call("make_material", color) as StandardMaterial3D

func _update_cutaway() -> void:
	if not is_instance_valid(_roof_assembly):
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var is_close: bool = _is_selected or (
		camera.global_position.distance_to(global_position)
		<= CUTAWAY_DISTANCE
	)
	_roof_assembly.visible = not is_close

	var visible_wall: String = ""
	if is_close:
		var camera_local: Vector3 = to_local(camera.global_position)
		if absf(camera_local.x) > absf(camera_local.z):
			visible_wall = "right" if camera_local.x > 0.0 else "left"
		else:
			visible_wall = "front" if camera_local.z > 0.0 else "back"

	for wall_id in _wall_groups:
		var wall_group: Node3D = _wall_groups[wall_id]
		wall_group.visible = not is_close or str(wall_id) != visible_wall
