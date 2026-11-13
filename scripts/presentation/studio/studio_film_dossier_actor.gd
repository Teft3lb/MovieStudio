extends Node3D
class_name StudioFilmDossierActor

const DOSSIER_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_dossier.gd"
)

const PICKING_LAYER: int = 32

var dossier: Variant
var _visual_root: Node3D
var _status_label: Label3D
var _dragged: bool = false


func setup(production_dossier: Variant) -> void:
	dossier = production_dossier
	name = "FilmDossier_%s" % str(dossier.script_id).replace("-", "_")
	add_to_group("film_dossier")

	var body := StaticBody3D.new()
	body.name = "DossierHitbox"
	body.collision_layer = PICKING_LAYER
	body.collision_mask = 0
	body.input_ray_pickable = true
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.1, 1.5)
	collision.shape = shape
	collision.position.y = 0.65
	body.add_child(collision)
	add_child(body)

	_visual_root = Node3D.new()
	_visual_root.name = "DocumentVisual"
	add_child(_visual_root)

	_status_label = Label3D.new()
	_status_label.name = "DossierTitle"
	_status_label.position = Vector3(0.0, 1.45, 0.0)
	_status_label.font_size = 24
	_status_label.pixel_size = 0.006
	_status_label.outline_size = 6
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	add_child(_status_label)
	refresh_appearance()


func _make_box(
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	part.material_override = material
	_visual_root.add_child(part)


func _make_reel(node_name: String, local_position: Vector3) -> void:
	var reel := MeshInstance3D.new()
	reel.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.46
	mesh.bottom_radius = 0.46
	mesh.height = 0.18
	reel.mesh = mesh
	reel.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.18, 0.22)
	material.metallic = 0.65
	material.roughness = 0.42
	reel.material_override = material
	_visual_root.add_child(reel)


func refresh_appearance() -> void:
	if not is_instance_valid(_visual_root) or dossier == null:
		return
	for child in _visual_root.get_children():
		_visual_root.remove_child(child)
		child.free()

	var phase: String = str(dossier.phase)
	if phase in [
		DOSSIER_SCRIPT.AT_WRITERS, DOSSIER_SCRIPT.AT_STAGE, DOSSIER_SCRIPT.IN_PRODUCTION
	]:
		_make_box(
			"ScreenplayPages",
			Vector3(1.48, 0.20, 1.1),
			Color(0.92, 0.87, 0.73),
			Vector3(0.0, 0.56, 0.0)
		)
		_make_box(
			"ScreenplayCover",
			Vector3(1.55, 0.10, 1.16),
			Color(0.18, 0.40, 0.51),
			Vector3(0.0, 0.69, 0.0)
		)
		_make_box(
			"ScreenplayBinder",
			Vector3(0.14, 0.18, 1.17),
			Color(0.82, 0.62, 0.30),
			Vector3(-0.69, 0.66, 0.0)
		)
	else:
		_make_reel("FilmReelLeft", Vector3(-0.35, 0.6, 0.0))
		_make_reel("FilmReelRight", Vector3(0.35, 0.6, 0.0))
		_make_box(
			"FilmCanister",
			Vector3(1.55, 0.10, 1.2),
			Color(0.31, 0.36, 0.41),
			Vector3(0.0, 0.35, 0.0)
		)
		if phase in [DOSSIER_SCRIPT.MASTER_READY, DOSSIER_SCRIPT.RELEASED]:
			_make_box(
				"MasterGoldLabel",
				Vector3(1.1, 0.05, 0.5),
				Color(0.89, 0.70, 0.30),
				Vector3(0.0, 0.76, 0.0)
			)
	_status_label.text = "%s\n%s" % [
		str(dossier.title),
		str(dossier.get_destination_title()),
	]
	_status_label.modulate = (
		Color(1.0, 0.86, 0.35)
		if dossier.is_movable()
		else Color(0.68, 0.88, 0.94)
	)
	scale = Vector3.ONE * (1.15 if _dragged else 1.0)


func set_dragged(value: bool) -> void:
	_dragged = value
	scale = Vector3.ONE * (1.15 if value else 1.0)


func get_script_id() -> String:
	return str(dossier.script_id)
