extends RefCounted

const LIBRARY: PackedScene = preload("res://assets/models/furniture/office_furniture.glb")
const SMALL_DETAILS: Array[String] = ["CableRun", "StoryBoard", "TaskLamp", "PreviewWall", "ServingLine"]

static var _meshes: Dictionary[String, Mesh] = {}


static func place(parent: Node3D, asset: String, node_name: String, location: Vector3) -> MeshInstance3D:
	if _meshes.is_empty():
		var library := LIBRARY.instantiate()
		for part in library.find_children("*", "MeshInstance3D", true, false):
			_meshes[part.name] = part.mesh
		library.free()
	var piece := MeshInstance3D.new()
	piece.name = node_name
	piece.mesh = _meshes[asset]
	piece.position = location
	if asset in SMALL_DETAILS:
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)
	return piece
