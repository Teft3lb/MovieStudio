extends Node3D
class_name StudioBuildingActor

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

const CUTAWAY_DISTANCE: float = 36.0
const WALL_THICKNESS: float = 0.28

var building_data: Variant
var _selection_marker: Node3D
var _roof_assembly: Node3D
var _wall_groups: Dictionary = {}
var _interior_root: Node3D
var _workplace_points: Array[Vector3] = []
var _entrance_inside: Vector3 = Vector3.ZERO
var _entrance_outside: Vector3 = Vector3.ZERO


func setup(data: Variant) -> void:
	building_data = data
	name = "Building_%s" % str(data.id).replace("-", "_")
	position = data.position
	rotation_degrees.y = float(data.rotation_degrees)
	add_to_group("studio_building")
	_build_visual()
	_create_hitbox()
	_create_selection_marker()
	_create_name_tag()


func _process(_delta: float) -> void:
	_update_cutaway()


func get_building_id() -> String:
	if building_data == null:
		return ""
	return str(building_data.id)


func set_selected(value: bool) -> void:
	if is_instance_valid(_selection_marker):
		_selection_marker.visible = value


func get_workplace_path(slot_index: int) -> Array[Vector3]:
	var path: Array[Vector3] = []
	if _workplace_points.is_empty():
		return path

	var normalized_slot: int = clampi(slot_index, 0, _workplace_points.size() - 1)
	var slot_offset: float = (
		float(normalized_slot) - float(_workplace_points.size() - 1) * 0.5
	) * 0.22
	var outside: Vector3 = _entrance_outside + Vector3(slot_offset, 0.0, 0.0)
	var inside: Vector3 = _entrance_inside + Vector3(slot_offset, 0.0, 0.0)
	var corridor: Vector3 = Vector3(
		_workplace_points[normalized_slot].x,
		0.0,
		_entrance_inside.z - 1.0
	)

	path.append(to_global(outside))
	path.append(to_global(inside))
	path.append(to_global(corridor))
	path.append(to_global(_workplace_points[normalized_slot]))
	return path


func get_workplace_position(slot_index: int) -> Vector3:
	var path: Array[Vector3] = get_workplace_path(slot_index)
	if path.is_empty():
		return global_position
	return path[path.size() - 1]


func _build_visual() -> void:
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		str(building_data.building_type_id)
	)
	var footprint: Vector2 = definition.get("footprint", Vector2(8.0, 6.0))
	var height: float = float(definition.get("building_height", 6.0))
	_create_interior_root()

	if str(building_data.building_type_id) == "sound_stage":
		_build_sound_stage(footprint, height, definition)
	else:
		_build_script_department(footprint, height, definition)


func _create_interior_root() -> void:
	_interior_root = Node3D.new()
	_interior_root.name = "Interior"
	add_child(_interior_root)


func _build_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.43, 0.40, 0.36)
	var roof_color: Color = Color(0.22, 0.24, 0.26)
	var trim_color: Color = Color(0.16, 0.18, 0.20)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.53, 0.43, 0.33)
	)

	_create_floor(
		footprint,
		Color(0.19, 0.20, 0.21),
		"StageFloor"
	)
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		4.6,
		4.0
	)

	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"StageRoof",
		Vector3(width + 0.45, 0.55, depth + 0.45),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_roof_assembly,
		"VentilationUnit",
		Vector3(2.4, 0.7, 1.8),
		trim_color,
		Vector3(width * 0.26, height + 0.35, -depth * 0.18)
	)

	_create_box(
		self,
		"RollDoorRaisedPanel",
		Vector3(4.4, 0.35, 0.16),
		trim_color,
		Vector3(0.0, 4.35, depth * 0.5 + 0.12)
	)
	_create_box(
		self,
		"FrontSign",
		Vector3(5.2, 0.72, 0.18),
		accent_color,
		Vector3(0.0, 5.0, depth * 0.5 + 0.12)
	)
	_create_label(
		self,
		"StageSignText",
		"СЪЁМОЧНЫЙ ПАВИЛЬОН",
		Vector3(0.0, 5.0, depth * 0.5 + 0.23),
		20
	)

	_build_sound_stage_interior(width, depth)


func _build_sound_stage_interior(width: float, depth: float) -> void:
	var set_color: Color = Color(0.26, 0.29, 0.31)
	var equipment_color: Color = Color(0.11, 0.13, 0.15)
	var metal_color: Color = Color(0.34, 0.36, 0.38)
	var tape_color: Color = Color(0.88, 0.69, 0.24)

	_create_box(
		_interior_root,
		"MainSetBackdrop",
		Vector3(8.2, 4.0, 0.24),
		set_color,
		Vector3(0.0, 2.0, -depth * 0.5 + 1.0)
	)
	_create_box(
		_interior_root,
		"SetPlatform",
		Vector3(8.2, 0.16, 3.2),
		Color(0.29, 0.28, 0.25),
		Vector3(0.0, 0.12, -2.6)
	)
	_create_box(
		_interior_root,
		"SetSideWallLeft",
		Vector3(0.18, 3.0, 2.8),
		Color(0.34, 0.32, 0.29),
		Vector3(-3.9, 1.6, -2.3)
	)
	_create_box(
		_interior_root,
		"SetSideWallRight",
		Vector3(0.18, 3.0, 2.8),
		Color(0.34, 0.32, 0.29),
		Vector3(3.9, 1.6, -2.3)
	)

	for mark_x in [-4.5, -1.5, 1.5, 4.5]:
		_create_box(
			_interior_root,
			"FloorMark",
			Vector3(0.10, 0.025, 2.0),
			tape_color,
			Vector3(mark_x, 0.055, 0.0)
		)

	_create_camera_rig(
		Vector3(-5.0, 0.0, -0.6),
		metal_color,
		equipment_color
	)
	_create_camera_rig(
		Vector3(5.0, 0.0, -0.6),
		metal_color,
		equipment_color
	)
	_create_light_stand(
		Vector3(-5.6, 0.0, -4.1),
		metal_color
	)
	_create_light_stand(
		Vector3(5.6, 0.0, -4.1),
		metal_color
	)
	_create_box(
		_interior_root,
		"TechnicalEquipmentRack",
		Vector3(1.3, 1.8, 0.65),
		equipment_color,
		Vector3(width * 0.5 - 1.0, 0.9, depth * 0.5 - 1.0)
	)
	_create_box(
		_interior_root,
		"DirectorMonitorDesk",
		Vector3(1.8, 0.9, 0.65),
		Color(0.23, 0.20, 0.18),
		Vector3(-width * 0.5 + 1.1, 0.48, depth * 0.5 - 1.0)
	)
	_create_box(
		_interior_root,
		"DirectorMonitor",
		Vector3(0.85, 0.48, 0.08),
		Color(0.10, 0.25, 0.30),
		Vector3(-width * 0.5 + 1.1, 1.18, depth * 0.5 - 1.0)
	)

	_workplace_points = [
		Vector3(-1.8, 0.0, -1.6),
		Vector3(1.8, 0.0, -1.6),
		Vector3(0.0, 0.0, 1.4),
		Vector3(-4.2, 0.0, 0.0),
		Vector3(-4.8, 0.0, 3.4),
		Vector3(4.8, 0.0, 3.4),
		Vector3(-4.2, 0.0, 1.8),
		Vector3(4.2, 0.0, 1.8),
	]


func _build_script_department(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.48, 0.51, 0.53)
	var roof_color: Color = Color(0.25, 0.28, 0.31)
	var trim_color: Color = Color(0.19, 0.22, 0.25)
	var glass_color: Color = Color(0.18, 0.31, 0.39)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.43, 0.48, 0.54)
	)

	_create_floor(
		footprint,
		Color(0.39, 0.34, 0.28),
		"OfficeFloor"
	)
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		1.8,
		2.65
	)

	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"OfficeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)

	_create_box(
		self,
		"OfficeBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		_wall_groups["front"],
		"OfficeFrontWindowLeft",
		Vector3(1.55, 1.25, 0.12),
		glass_color,
		Vector3(-2.35, 3.75, depth * 0.5 + 0.09)
	)
	_create_box(
		_wall_groups["front"],
		"OfficeFrontWindowRight",
		Vector3(1.55, 1.25, 0.12),
		glass_color,
		Vector3(2.35, 3.75, depth * 0.5 + 0.09)
	)
	_create_box(
		self,
		"OfficeSign",
		Vector3(4.6, 0.52, 0.16),
		accent_color,
		Vector3(0.0, 2.85, depth * 0.5 + 0.11)
	)
	_create_label(
		self,
		"OfficeSignText",
		"СЦЕНАРНЫЙ ОТДЕЛ",
		Vector3(0.0, 2.85, depth * 0.5 + 0.22),
		18
	)

	_build_script_department_interior(width, depth)


func _build_script_department_interior(width: float, depth: float) -> void:
	var desk_color: Color = Color(0.34, 0.23, 0.16)
	var metal_color: Color = Color(0.17, 0.19, 0.21)
	var screen_color: Color = Color(0.10, 0.27, 0.32)

	for slot_index in range(3):
		var desk_x: float = float(slot_index - 1) * 2.35
		_create_box(
			_interior_root,
			"WriterDesk",
			Vector3(1.75, 0.16, 0.85),
			desk_color,
			Vector3(desk_x, 0.82, -0.95)
		)
		for leg_x in [-0.72, 0.72]:
			for leg_z in [-0.30, 0.30]:
				_create_box(
					_interior_root,
					"DeskLeg",
					Vector3(0.09, 0.78, 0.09),
					metal_color,
					Vector3(desk_x + leg_x, 0.40, -0.95 + leg_z)
				)
		_create_box(
			_interior_root,
			"ComputerMonitor",
			Vector3(0.72, 0.48, 0.08),
			screen_color,
			Vector3(desk_x, 1.16, -1.23)
		)
		_create_box(
			_interior_root,
			"Keyboard",
			Vector3(0.58, 0.035, 0.20),
			metal_color,
			Vector3(desk_x, 0.92, -0.56)
		)
		_create_cylinder(
			_interior_root,
			"OfficeChairSeat",
			0.32,
			0.12,
			metal_color,
			Vector3(desk_x + 0.82, 0.48, 0.72)
		)
		_create_box(
			_interior_root,
			"OfficeChairBack",
			Vector3(0.58, 0.65, 0.12),
			Color(0.15, 0.18, 0.21),
			Vector3(desk_x + 0.82, 0.85, 0.97)
		)

	_workplace_points = [
		Vector3(-2.35, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(2.35, 0.0, 0.0),
	]
	_create_box(
		_interior_root,
		"Bookshelf",
		Vector3(0.55, 2.1, 2.2),
		Color(0.28, 0.20, 0.15),
		Vector3(-width * 0.5 + 0.45, 1.08, -0.55)
	)
	_create_box(
		_interior_root,
		"ResearchBoard",
		Vector3(2.1, 1.3, 0.10),
		Color(0.38, 0.40, 0.36),
		Vector3(width * 0.5 - 1.2, 2.0, -depth * 0.5 + 0.12)
	)


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
	_create_box(
		back_group,
		"BackWall",
		Vector3(width, wall_height, WALL_THICKNESS),
		wall_color,
		Vector3(0.0, wall_y, -half_depth)
	)

	var left_group: Node3D = _create_wall_group("left")
	_create_box(
		left_group,
		"LeftWall",
		Vector3(WALL_THICKNESS, wall_height, depth),
		wall_color,
		Vector3(-half_width, wall_y, 0.0)
	)

	var right_group: Node3D = _create_wall_group("right")
	_create_box(
		right_group,
		"RightWall",
		Vector3(WALL_THICKNESS, wall_height, depth),
		wall_color,
		Vector3(half_width, wall_y, 0.0)
	)

	var front_group: Node3D = _create_wall_group("front")
	var side_width: float = (width - door_width) * 0.5
	_create_box(
		front_group,
		"FrontWallLeft",
		Vector3(side_width, wall_height, WALL_THICKNESS),
		wall_color,
		Vector3(
			-(door_width * 0.5 + side_width * 0.5),
			wall_y,
			half_depth
		)
	)
	_create_box(
		front_group,
		"FrontWallRight",
		Vector3(side_width, wall_height, WALL_THICKNESS),
		wall_color,
		Vector3(
			door_width * 0.5 + side_width * 0.5,
			wall_y,
			half_depth
		)
	)
	_create_box(
		front_group,
		"DoorHeader",
		Vector3(door_width, maxf(wall_height - door_height, 0.25), WALL_THICKNESS),
		wall_color,
		Vector3(
			0.0,
			door_height + maxf(wall_height - door_height, 0.25) * 0.5,
			half_depth
		)
	)

	_entrance_inside = Vector3(0.0, 0.0, half_depth - 0.8)
	_entrance_outside = Vector3(0.0, 0.0, half_depth + 1.4)


func _create_wall_group(group_id: String) -> Node3D:
	var group := Node3D.new()
	group.name = "%sWallGroup" % group_id.capitalize()
	add_child(group)
	_wall_groups[group_id] = group
	return group


func _create_floor(
	footprint: Vector2,
	color: Color,
	node_name: String
) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(
		maxf(footprint.x - 0.4, 1.0),
		maxf(footprint.y - 0.4, 1.0)
	)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position.y = 0.02
	instance.material_override = _make_material(color)
	_interior_root.add_child(instance)


func _create_camera_rig(
	local_position: Vector3,
	metal_color: Color,
	equipment_color: Color
) -> void:
	_create_cylinder(
		_interior_root,
		"CameraTripodBase",
		0.38,
		0.10,
		metal_color,
		local_position + Vector3(0.0, 0.10, 0.0)
	)
	_create_cylinder(
		_interior_root,
		"CameraTripodColumn",
		0.075,
		1.25,
		metal_color,
		local_position + Vector3(0.0, 0.72, 0.0)
	)
	_create_box(
		_interior_root,
		"CinemaCameraBody",
		Vector3(0.68, 0.48, 0.82),
		equipment_color,
		local_position + Vector3(0.0, 1.45, -0.18)
	)
	_create_cylinder(
		_interior_root,
		"CameraLens",
		0.19,
		0.42,
		Color(0.08, 0.10, 0.12),
		local_position + Vector3(0.0, 1.45, -0.78)
	)


func _create_light_stand(
	local_position: Vector3,
	metal_color: Color
) -> void:
	_create_cylinder(
		_interior_root,
		"LightStand",
		0.055,
		2.5,
		metal_color,
		local_position + Vector3(0.0, 1.25, 0.0)
	)
	_create_box(
		_interior_root,
		"StudioLight",
		Vector3(1.05, 0.65, 0.28),
		Color(0.73, 0.68, 0.53),
		local_position + Vector3(0.0, 2.55, -0.10)
	)


func _create_hitbox() -> void:
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		str(building_data.building_type_id)
	)
	var footprint: Vector2 = definition.get("footprint", Vector2(8.0, 6.0))
	var height: float = float(definition.get("building_height", 6.0))

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
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		str(building_data.building_type_id)
	)
	var footprint: Vector2 = definition.get("footprint", Vector2(8.0, 6.0))
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
	_create_marker_strip(
		marker,
		"Front",
		Vector3(footprint.x, thickness, thickness),
		Vector3(0.0, 0.0, footprint.y * 0.5),
		material
	)
	_create_marker_strip(
		marker,
		"Back",
		Vector3(footprint.x, thickness, thickness),
		Vector3(0.0, 0.0, -footprint.y * 0.5),
		material
	)
	_create_marker_strip(
		marker,
		"Left",
		Vector3(thickness, thickness, footprint.y),
		Vector3(-footprint.x * 0.5, 0.0, 0.0),
		material
	)
	_create_marker_strip(
		marker,
		"Right",
		Vector3(thickness, thickness, footprint.y),
		Vector3(footprint.x * 0.5, 0.0, 0.0),
		material
	)


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
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		str(building_data.building_type_id)
	)
	var height: float = float(definition.get("building_height", 6.0))
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
	var label := Label3D.new()
	label.name = node_name
	label.text = label_text
	label.position = local_position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.outline_size = 6
	label.modulate = Color(0.97, 0.95, 0.88)
	label.no_depth_test = true
	parent.add_child(label)


func _create_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance


func _create_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _update_cutaway() -> void:
	if not is_instance_valid(_roof_assembly):
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var is_close: bool = (
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
