extends Node3D
class_name StudioBuildingActor

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

var building_data: Variant
var _selection_marker: Node3D


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


func get_building_id() -> String:
	if building_data == null:
		return ""
	return str(building_data.id)


func set_selected(value: bool) -> void:
	if is_instance_valid(_selection_marker):
		_selection_marker.visible = value


func _build_visual() -> void:
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		str(building_data.building_type_id)
	)
	var footprint: Vector2 = definition.get("footprint", Vector2(8.0, 6.0))
	var height: float = float(definition.get("building_height", 6.0))
	if str(building_data.building_type_id) == "sound_stage":
		_build_sound_stage(footprint, height, definition)
	else:
		_build_script_department(footprint, height, definition)


func _build_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_color: Color = Color(0.43, 0.40, 0.36)
	var roof_color: Color = Color(0.22, 0.24, 0.26)
	var trim_color: Color = Color(0.16, 0.18, 0.20)
	var door_color: Color = Color(0.12, 0.14, 0.16)
	var accent_color: Color = definition.get("accent_color", Color(0.53, 0.43, 0.33))

	_create_box(
		"StageWalls",
		Vector3(width, height - 0.55, depth),
		wall_color,
		Vector3(0.0, (height - 0.55) * 0.5, 0.0)
	)
	_create_box(
		"StageRoof",
		Vector3(width + 0.45, 0.55, depth + 0.45),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		"FrontRollDoor",
		Vector3(4.4, 3.8, 0.18),
		door_color,
		Vector3(0.0, 1.9, depth * 0.5 + 0.10)
	)
	_create_box(
		"RollDoorHeader",
		Vector3(4.8, 0.22, 0.25),
		trim_color,
		Vector3(0.0, 3.95, depth * 0.5 + 0.12)
	)
	_create_box(
		"FrontSign",
		Vector3(5.2, 0.72, 0.18),
		accent_color,
		Vector3(0.0, 5.0, depth * 0.5 + 0.12)
	)
	_create_box(
		"SideWindowStrip",
		Vector3(0.16, 1.0, depth * 0.62),
		Color(0.20, 0.31, 0.36),
		Vector3(width * 0.5 + 0.09, 4.1, 0.0)
	)
	_create_box(
		"VentilationUnit",
		Vector3(2.4, 0.7, 1.8),
		trim_color,
		Vector3(width * 0.26, height + 0.35, -depth * 0.18)
	)
	_create_label(
		"StageSignText",
		"СЪЁМОЧНЫЙ ПАВИЛЬОН",
		Vector3(0.0, 5.0, depth * 0.5 + 0.23),
		20
	)


func _build_script_department(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_color: Color = Color(0.48, 0.51, 0.53)
	var roof_color: Color = Color(0.25, 0.28, 0.31)
	var trim_color: Color = Color(0.19, 0.22, 0.25)
	var glass_color: Color = Color(0.18, 0.31, 0.39)
	var accent_color: Color = definition.get("accent_color", Color(0.43, 0.48, 0.54))

	_create_box(
		"OfficeWalls",
		Vector3(width, height - 0.55, depth),
		wall_color,
		Vector3(0.0, (height - 0.55) * 0.5, 0.0)
	)
	_create_box(
		"OfficeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		"OfficeBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		"OfficeFrontDoor",
		Vector3(1.35, 2.45, 0.14),
		trim_color,
		Vector3(0.0, 1.225, depth * 0.5 + 0.09)
	)
	_create_box(
		"OfficeFrontWindowLeft",
		Vector3(1.55, 1.25, 0.12),
		glass_color,
		Vector3(-2.35, 3.75, depth * 0.5 + 0.09)
	)
	_create_box(
		"OfficeFrontWindowRight",
		Vector3(1.55, 1.25, 0.12),
		glass_color,
		Vector3(2.35, 3.75, depth * 0.5 + 0.09)
	)
	_create_box(
		"OfficeUpperWindowLeft",
		Vector3(1.4, 0.95, 0.12),
		glass_color,
		Vector3(-2.25, 5.05, depth * 0.5 + 0.09)
	)
	_create_box(
		"OfficeUpperWindowRight",
		Vector3(1.4, 0.95, 0.12),
		glass_color,
		Vector3(2.25, 5.05, depth * 0.5 + 0.09)
	)
	_create_box(
		"OfficeSign",
		Vector3(4.6, 0.52, 0.16),
		accent_color,
		Vector3(0.0, 2.65, depth * 0.5 + 0.11)
	)
	_create_label(
		"OfficeSignText",
		"СЦЕНАРНЫЙ ОТДЕЛ",
		Vector3(0.0, 2.65, depth * 0.5 + 0.22),
		18
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
		marker, "Front", Vector3(footprint.x, thickness, thickness),
		Vector3(0.0, 0.0, footprint.y * 0.5)
	)
	_create_marker_strip(
		marker, "Back", Vector3(footprint.x, thickness, thickness),
		Vector3(0.0, 0.0, -footprint.y * 0.5)
	)
	_create_marker_strip(
		marker, "Left", Vector3(thickness, thickness, footprint.y),
		Vector3(-footprint.x * 0.5, 0.0, 0.0)
	)
	_create_marker_strip(
		marker, "Right", Vector3(thickness, thickness, footprint.y),
		Vector3(footprint.x * 0.5, 0.0, 0.0),
		material
	)


func _create_marker_strip(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	material: StandardMaterial3D = null
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.78, 0.22)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = material
	parent.add_child(instance)


func _create_name_tag() -> void:
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		str(building_data.building_type_id)
	)
	var footprint: Vector2 = definition.get("footprint", Vector2(8.0, 6.0))
	var height: float = float(definition.get("building_height", 6.0))
	_create_label(
		"BuildingName",
		str(building_data.display_name),
		Vector3(0.0, height + 0.55, 0.0),
		26
	)


func _create_label(
	node_name: String,
	text: String,
	local_position: Vector3,
	font_size: int
) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = local_position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.outline_size = 6
	label.modulate = Color(0.97, 0.95, 0.88)
	label.no_depth_test = true
	add_child(label)


func _create_box(
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
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	instance.material_override = material
	add_child(instance)
	return instance
