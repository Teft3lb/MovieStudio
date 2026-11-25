extends RefCounted

const LIBRARY: PackedScene = preload("res://assets/models/furniture/office_furniture.glb")
const SMALL_DETAILS: Array[String] = [
	"CableRun", "StoryBoard", "TaskLamp", "PreviewWall", "ServingLine", "WallClock", "CupService",
	"DiningInset", "RestInset", "TechnicalInset", "StoryboardFrames", "CafeMenu", "WallSconce",
	"AcousticBaffles", "StudioSpeaker",
	"ScriptFolio", "WardrobeNotions", "CanteenTray", "FoleyReels", "StageReadinessBoard",
	"OfficeKeyboard", "AudioMixer",
]

static var _meshes: Dictionary[String, Mesh] = {}


static func _get_mesh(asset: String) -> Mesh:
	if _meshes.is_empty():
		var library := LIBRARY.instantiate()
		for part in library.find_children("*", "MeshInstance3D", true, false):
			_meshes[part.name] = part.mesh
		library.free()
	return _meshes[asset]


static func place(
	parent: Node3D, asset: String, node_name: String, location: Vector3, blocks_passage: bool = false
) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = node_name
	piece.mesh = _get_mesh(asset)
	piece.position = location
	if asset in SMALL_DETAILS:
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if blocks_passage:
		piece.set_meta("blocks_passage", true)
	parent.add_child(piece)
	return piece


static func place_batch(
	parent: Node3D, asset: String, node_name: String, transforms: Array[Transform3D], visible_distance: float = 0
) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _get_mesh(asset)
	batch.instance_count = transforms.size()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
	var piece := MultiMeshInstance3D.new()
	piece.name = node_name
	piece.multimesh = batch
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.visibility_range_end = visible_distance
	piece.visibility_range_end_margin = 2.0
	parent.add_child(piece)


static func floor_zone(
	parent: Node3D, asset: String, node_name: String, center: Vector2, size: Vector2
) -> void:
	var piece := place(parent, asset, node_name, Vector3(center.x, 0, center.y))
	piece.scale = Vector3(size.x, 1.0, size.y)
