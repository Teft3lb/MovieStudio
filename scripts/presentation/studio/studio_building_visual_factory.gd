extends RefCounted
class_name StudioBuildingVisualFactory

const STAGE_EQUIPMENT: PackedScene = preload("res://assets/models/equipment/stage_equipment.glb")
const CAMERA_PIVOT_HEIGHT: float = 1.52
const PALETTE = preload("res://scripts/presentation/studio/studio_surface_palette.gd")

static var _equipment_meshes: Dictionary[String, Mesh] = {}


func create_floor(
	interior_root: Node3D,
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
	var hard_floor := node_name.contains("Stage") or node_name.contains("Warehouse") or node_name.contains("Editing")
	instance.material_override = PALETTE.finish(color, "concrete" if hard_floor else "wood")
	interior_root.add_child(instance)


func create_film_slate(interior_root: Node3D) -> Dictionary:
	create_box(
		interior_root,
		"FilmSlateBody",
		Vector3(2.0, 1.05, 0.16),
		Color(0.075, 0.085, 0.095),
		Vector3(0.0, 1.15, 2.55)
	)
	create_box(
		interior_root,
		"FilmSlateClapper",
		Vector3(2.08, 0.14, 0.2),
		Color(0.72, 0.70, 0.62),
		Vector3(0.0, 1.75, 2.55)
	)
	var scene_label := Label3D.new()
	scene_label.name = "ProductionSceneSlate"
	scene_label.position = Vector3(0.0, 1.28, 2.43)
	scene_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	scene_label.font_size = 15
	scene_label.outline_size = 5
	scene_label.modulate = Color(0.97, 0.95, 0.88)
	scene_label.no_depth_test = true
	scene_label.text = "СЪЁМКИ НЕ ИДУТ"
	interior_root.add_child(scene_label)

	var phase_label := Label3D.new()
	phase_label.name = "ProductionPhaseSlate"
	phase_label.position = Vector3(0.0, 0.91, 2.43)
	phase_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	phase_label.font_size = 11
	phase_label.outline_size = 4
	phase_label.modulate = Color(0.82, 0.86, 0.88)
	phase_label.no_depth_test = true
	phase_label.text = "ПАВИЛЬОН ГОТОВ"
	interior_root.add_child(phase_label)
	return {"scene_label": scene_label, "phase_label": phase_label}


func create_camera_rig(
	interior_root: Node3D,
	rig_index: int,
	local_position: Vector3,
	_metal_color: Color,
	_equipment_color: Color
) -> Node3D:
	var rig := Node3D.new()
	rig.name = "CameraRig_%d" % rig_index
	rig.position = local_position + Vector3.UP * CAMERA_PIVOT_HEIGHT
	interior_root.add_child(rig)
	_add_equipment_mesh(rig, "CinemaCameraBody", Vector3.ZERO)
	_add_equipment_mesh(interior_root, "CameraTripodBase", local_position)
	return rig


func create_light_stand(
	interior_root: Node3D,
	local_position: Vector3,
	_metal_color: Color
) -> void:
	_add_equipment_mesh(interior_root, "LightStand", local_position)
	_add_equipment_mesh(interior_root, "StudioLight", local_position)


func attach_tv_camera(rig: Node3D) -> void:
	_add_equipment_mesh(rig, "CinemaCameraBody", Vector3.UP * CAMERA_PIVOT_HEIGHT).name = "TVStudioCameraBody"
	_add_equipment_mesh(rig, "CameraTripodBase", Vector3.ZERO).name = "TVStudioCameraTripod"


func _add_equipment_mesh(parent: Node3D, mesh_name: String, local_position: Vector3) -> MeshInstance3D:
	if _equipment_meshes.is_empty():
		var equipment := STAGE_EQUIPMENT.instantiate()
		for node in equipment.find_children("*", "MeshInstance3D", true, false):
			var part := node as MeshInstance3D
			_equipment_meshes[part.name] = part.mesh
		equipment.free()
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = _equipment_meshes[mesh_name]
	instance.position = local_position
	parent.add_child(instance)
	return instance


func create_wall_panel(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> void:
	create_box(parent, node_name, size, color, local_position).material_override = PALETTE.finish(color, "wall")
	create_wall_collision(parent, node_name, size, local_position)


func create_wall_collision(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	local_position: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	body.position = local_position
	body.collision_layer = 8
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func create_label(
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


func create_box(
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
	instance.material_override = make_material(color)
	parent.add_child(instance)
	return instance


func create_cylinder(
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
	instance.material_override = make_material(color)
	parent.add_child(instance)
	return instance


func create_sphere(
	parent: Node3D,
	node_name: String,
	radius: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = make_material(color)
	parent.add_child(instance)
	return instance


func make_material(color: Color) -> StandardMaterial3D:
	return PALETTE.finish(color)
