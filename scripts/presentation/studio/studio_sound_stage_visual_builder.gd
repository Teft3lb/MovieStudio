extends RefCounted
class_name StudioSoundStageVisualBuilder

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

var _actor: Node3D
var _interior_root: Node3D
var _visual_factory: RefCounted
var _roof_assembly: Node3D
var _set_dressing_root: Node3D
var _production_slate_label: Label3D
var _production_phase_label: Label3D
var _camera_rigs: Array[Node3D] = []
var _workplace_points: Array[Vector3] = []


func build(
	actor: Node3D,
	interior_root: Node3D,
	visual_factory: RefCounted,
	footprint: Vector2,
	height: float,
	definition: Dictionary,
	stage_size_tier: int
) -> Dictionary:
	_actor = actor
	_interior_root = interior_root
	_visual_factory = visual_factory
	_roof_assembly = null
	_set_dressing_root = null
	_production_slate_label = null
	_production_phase_label = null
	_camera_rigs.clear()
	_workplace_points.clear()

	match BUILDING_CATALOG_SCRIPT.get_stage_size_tier(stage_size_tier):
		1:
			_build_small_sound_stage(footprint, height, definition)
		3:
			_build_large_sound_stage(footprint, height, definition)
		_:
			_build_medium_sound_stage(footprint, height, definition)

	return {
		"roof_assembly": _roof_assembly,
		"set_dressing_root": _set_dressing_root,
		"production_slate_label": _production_slate_label,
		"production_phase_label": _production_phase_label,
		"camera_rigs": _camera_rigs,
		"workplace_points": _workplace_points,
	}


func _create_light_stand(
	local_position: Vector3,
	metal_color: Color
) -> void:
	_visual_factory.call(
		"create_light_stand",
		_interior_root,
		local_position,
		metal_color
	)


func _create_film_slate() -> void:
	var labels: Dictionary = _visual_factory.call(
		"create_film_slate",
		_interior_root
	)
	_production_slate_label = labels.get("scene_label") as Label3D
	_production_phase_label = labels.get("phase_label") as Label3D


func _build_small_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.49, 0.47, 0.43)
	var roof_color: Color = Color(0.26, 0.19, 0.17)
	var trim_color: Color = Color(0.18, 0.20, 0.22)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.53, 0.43, 0.33)
	)
	_visual_factory.call("create_floor", _interior_root, footprint, Color(0.20, 0.21, 0.22), "SmallStageFloor")
	_actor.call("_create_perimeter_walls",
		width,
		depth,
		wall_height,
		wall_color,
		3.2,
		3.2
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	var left_roof: MeshInstance3D = _visual_factory.call("create_box",
		_roof_assembly,
		"SmallStageGableRoofLeft",
		Vector3(width + 0.55, 0.28, depth * 0.64),
		roof_color,
		Vector3(0.0, height - 0.55, -depth * 0.20)
	) as MeshInstance3D
	left_roof.rotation.x = -0.42
	var right_roof: MeshInstance3D = _visual_factory.call("create_box",
		_roof_assembly,
		"SmallStageGableRoofRight",
		Vector3(width + 0.55, 0.28, depth * 0.64),
		roof_color,
		Vector3(0.0, height - 0.55, depth * 0.20)
	) as MeshInstance3D
	right_roof.rotation.x = 0.42
	_visual_factory.call("create_box",
		_roof_assembly,
		"SmallStageRidgeBeam",
		Vector3(width + 0.7, 0.28, 0.34),
		trim_color,
		Vector3(0.0, height + 0.05, 0.0)
	)
	_visual_factory.call("create_box",
		_actor,
		"SmallStageLoadingCanopy",
		Vector3(4.0, 0.18, 1.0),
		trim_color,
		Vector3(0.0, 3.55, depth * 0.5 + 0.45)
	)
	_visual_factory.call("create_box",
		_actor,
		"SmallStageSign",
		Vector3(4.8, 0.58, 0.18),
		accent_color,
		Vector3(0.0, 4.25, depth * 0.5 + 0.24)
	)
	_visual_factory.call("create_label",
		_actor,
		"SmallStageSignText",
		"МАЛАЯ СТУДИЯ",
		Vector3(0.0, 4.25, depth * 0.5 + 0.34),
		18
	)
	_visual_factory.call("create_box",
		_actor.call("get_wall_group_for_visual_builder", "front"),
		"SmallStageFrontWindow",
		Vector3(1.45, 0.95, 0.12),
		Color(0.18, 0.34, 0.39),
		Vector3(-3.75, 3.55, depth * 0.5 + 0.22)
	)
	_build_small_sound_stage_interior()

func _build_medium_sound_stage(
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
	_visual_factory.call("create_floor", _interior_root, footprint, Color(0.19, 0.20, 0.21), "StageFloor")
	_actor.call("_create_perimeter_walls",
		width,
		depth,
		wall_height,
		wall_color,
		4.6,
		4.0
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_visual_factory.call("create_box",
		_roof_assembly,
		"StageRoof",
		Vector3(width + 0.45, 0.55, depth + 0.45),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_visual_factory.call("create_box",
		_roof_assembly,
		"VentilationUnit",
		Vector3(2.4, 0.7, 1.8),
		trim_color,
		Vector3(width * 0.26, height + 0.35, -depth * 0.18)
	)
	_visual_factory.call("create_box",
		_actor,
		"RollDoorRaisedPanel",
		Vector3(4.4, 0.35, 0.16),
		trim_color,
		Vector3(0.0, 4.35, depth * 0.5 + 0.24)
	)
	_visual_factory.call("create_box",
		_actor,
		"FrontSign",
		Vector3(5.2, 0.72, 0.18),
		accent_color,
		Vector3(0.0, 5.0, depth * 0.5 + 0.24)
	)
	_visual_factory.call("create_label",
		_actor,
		"StageSignText",
		"СЪЁМОЧНЫЙ ПАВИЛЬОН",
		Vector3(0.0, 5.0, depth * 0.5 + 0.34),
		20
	)
	_build_medium_sound_stage_interior()

func _build_large_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.34, 0.39, 0.42)
	var roof_color: Color = Color(0.17, 0.21, 0.25)
	var truss_color: Color = Color(0.24, 0.29, 0.33)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.53, 0.43, 0.33)
	)
	_visual_factory.call("create_floor", _interior_root, footprint, Color(0.17, 0.19, 0.21), "HighBayStageFloor")
	_actor.call("_create_perimeter_walls",
		width,
		depth,
		wall_height,
		wall_color,
		7.0,
		5.6
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_visual_factory.call("create_box",
		_roof_assembly,
		"HighBayRoofDeck",
		Vector3(width + 0.8, 0.65, depth + 0.8),
		roof_color,
		Vector3(0.0, height - 0.325, 0.0)
	)
	for beam_x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_visual_factory.call("create_box",
			_roof_assembly,
			"HighBayRoofTruss_%d" % roundi(beam_x + 8.0),
			Vector3(0.24, 1.15, depth + 0.3),
			truss_color,
			Vector3(beam_x, height - 1.0, 0.0)
		)
	for skylight_x in [-4.0, 4.0]:
		_visual_factory.call("create_box",
			_roof_assembly,
			"HighBaySkylight_%d" % roundi(skylight_x + 4.0),
			Vector3(2.6, 0.16, depth - 2.0),
			Color(0.30, 0.43, 0.48),
			Vector3(skylight_x, height + 0.025, 0.0)
		)
	_visual_factory.call("create_box",
		_actor,
		"HighBayLoadingDoorHeader",
		Vector3(7.2, 0.32, 0.2),
		truss_color,
		Vector3(0.0, 5.85, depth * 0.5 + 0.25)
	)
	_visual_factory.call("create_box",
		_actor,
		"HighBayFrontSign",
		Vector3(8.2, 0.82, 0.2),
		accent_color,
		Vector3(0.0, 6.8, depth * 0.5 + 0.25)
	)
	_visual_factory.call("create_label",
		_actor,
		"HighBayFrontSignText",
		"БОЛЬШОЙ СЪЁМОЧНЫЙ АНГАР",
		Vector3(0.0, 6.8, depth * 0.5 + 0.36),
		22
	)
	_visual_factory.call("create_box",
		_actor.call("get_wall_group_for_visual_builder", "front"),
		"HighBayControlRoomWindow",
		Vector3(3.8, 1.35, 0.12),
		Color(0.13, 0.30, 0.38),
		Vector3(-7.0, 6.4, depth * 0.5 + 0.22)
	)
	_visual_factory.call("create_box",
		_actor.call("get_wall_group_for_visual_builder", "right"),
		"HighBayServiceWindow",
		Vector3(0.12, 1.2, 2.8),
		Color(0.13, 0.30, 0.38),
		Vector3(width * 0.5 + 0.22, 6.2, 0.0)
	)
	_build_large_sound_stage_interior()

func _build_small_sound_stage_interior() -> void:
	var set_color: Color = Color(0.29, 0.31, 0.32)
	var equipment_color: Color = Color(0.11, 0.13, 0.15)
	var metal_color: Color = Color(0.34, 0.36, 0.38)
	var tape_color: Color = Color(0.88, 0.69, 0.24)
	_set_dressing_root = Node3D.new()
	_set_dressing_root.name = "SetDressing"
	_interior_root.add_child(_set_dressing_root)
	_visual_factory.call("create_wall_panel",
		_interior_root,
		"SmallSetBackdrop",
		Vector3(5.8, 3.3, 0.22),
		set_color,
		Vector3(0.0, 1.7, -3.3)
	)
	_visual_factory.call("create_box",
		_interior_root,
		"SmallSetPlatform",
		Vector3(5.8, 0.16, 2.8),
		Color(0.29, 0.28, 0.25),
		Vector3(0.0, 0.12, -2.35)
	)
	for side in [-1.0, 1.0]:
		_visual_factory.call("create_wall_panel",
			_interior_root,
			"SmallSetSideWallLeft" if side < 0.0 else "SmallSetSideWallRight",
			Vector3(0.18, 2.6, 2.4),
			Color(0.34, 0.32, 0.29),
			Vector3(side * 2.8, 1.35, -2.15)
		)
	for mark_x in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		_visual_factory.call("create_box",
			_interior_root,
			"SmallStageFloorMark_%d" % roundi(mark_x + 2.0),
			Vector3(0.08, 0.025, 1.2),
			tape_color,
			Vector3(mark_x, 0.055, -0.4)
		)
	_camera_rigs.clear()
	_camera_rigs.append(
		_visual_factory.call(
			"create_camera_rig",
			_interior_root,
			_camera_rigs.size(),
			Vector3(3.15, 0.0, -0.15),
			metal_color,
			equipment_color
		) as Node3D
	)
	_create_light_stand( Vector3(-3.5, 0.0, -3.0), metal_color)
	_create_light_stand( Vector3(3.5, 0.0, -3.0), metal_color)
	_visual_factory.call("create_box",
		_interior_root,
		"SmallStageEquipmentRack",
		Vector3(0.85, 1.45, 0.55),
		equipment_color,
		Vector3(3.75, 0.72, 2.55)
	)
	_visual_factory.call("create_box",
		_interior_root,
		"SmallStageDirectorDesk",
		Vector3(1.25, 0.78, 0.58),
		Color(0.23, 0.20, 0.18),
		Vector3(-3.65, 0.42, 2.55)
	)
	_create_film_slate()
	_workplace_points = [
		Vector3(-1.35, 0.0, -1.1),
		Vector3(1.35, 0.0, -1.1),
		Vector3(-3.55, 0.0, 1.45),
		Vector3(-3.45, 0.0, -0.15),
		Vector3(3.45, 0.0, -0.15),
		Vector3(3.55, 0.0, 1.45),
	]

func _build_medium_sound_stage_interior() -> void:
	var set_color: Color = Color(0.26, 0.29, 0.31)
	var equipment_color: Color = Color(0.11, 0.13, 0.15)
	var metal_color: Color = Color(0.34, 0.36, 0.38)
	var tape_color: Color = Color(0.88, 0.69, 0.24)
	_set_dressing_root = Node3D.new()
	_set_dressing_root.name = "SetDressing"
	_interior_root.add_child(_set_dressing_root)
	_visual_factory.call("create_wall_panel",
		_interior_root,
		"MainSetBackdrop",
		Vector3(8.2, 4.0, 0.24),
		set_color,
		Vector3(0.0, 2.0, -5.0)
	)
	_visual_factory.call("create_box",
		_interior_root,
		"SetPlatform",
		Vector3(8.2, 0.16, 3.2),
		Color(0.29, 0.28, 0.25),
		Vector3(0.0, 0.12, -2.6)
	)
	_visual_factory.call("create_wall_panel",
		_interior_root,
		"SetSideWallLeft",
		Vector3(0.18, 3.0, 2.8),
		Color(0.34, 0.32, 0.29),
		Vector3(-3.9, 1.6, -2.3)
	)
	_visual_factory.call("create_wall_panel",
		_interior_root,
		"SetSideWallRight",
		Vector3(0.18, 3.0, 2.8),
		Color(0.34, 0.32, 0.29),
		Vector3(3.9, 1.6, -2.3)
	)
	for mark_x in [-4.5, -1.5, 1.5, 4.5]:
		_visual_factory.call("create_box",
			_interior_root,
			"FloorMark",
			Vector3(0.10, 0.025, 2.0),
			tape_color,
			Vector3(mark_x, 0.055, 0.0)
		)
	_camera_rigs.clear()
	_camera_rigs.append(
		_visual_factory.call(
			"create_camera_rig",
			_interior_root,
			_camera_rigs.size(),
			Vector3(-5.0, 0.0, -0.6),
			metal_color,
			equipment_color
		) as Node3D
	)
	_camera_rigs.append(
		_visual_factory.call(
			"create_camera_rig",
			_interior_root,
			_camera_rigs.size(),
			Vector3(5.0, 0.0, -0.6),
			metal_color,
			equipment_color
		) as Node3D
	)
	_create_light_stand( Vector3(-5.6, 0.0, -4.1), metal_color)
	_create_light_stand( Vector3(5.6, 0.0, -4.1), metal_color)
	_visual_factory.call("create_box",
		_interior_root,
		"TechnicalEquipmentRack",
		Vector3(1.3, 1.8, 0.65),
		equipment_color,
		Vector3(6.0, 0.9, 5.0)
	)
	_visual_factory.call("create_box",
		_interior_root,
		"DirectorMonitorDesk",
		Vector3(1.8, 0.9, 0.65),
		Color(0.23, 0.20, 0.18),
		Vector3(-5.9, 0.48, 5.0)
	)
	_visual_factory.call("create_box",
		_interior_root,
		"DirectorMonitor",
		Vector3(0.85, 0.48, 0.08),
		Color(0.10, 0.25, 0.30),
		Vector3(-5.9, 1.18, 5.0)
	)
	_create_film_slate()
	_workplace_points = [
		Vector3(-1.8, 0.0, -1.6),
		Vector3(1.8, 0.0, -1.6),
		Vector3(-5.8, 0.0, 4.3),
		Vector3(-5.0, 0.0, 0.8),
		Vector3(-3.7, 0.0, 4.3),
		Vector3(4.9, 0.0, 4.7),
		Vector3(-4.2, 0.0, 1.8),
		Vector3(4.2, 0.0, 1.8),
		Vector3(-2.2, 0.0, 4.5),
		Vector3(0.0, 0.0, 4.5),
		Vector3(2.2, 0.0, 4.5),
		Vector3(0.0, 0.0, 2.2),
	]

func _build_large_sound_stage_interior() -> void:
	var set_color: Color = Color(0.24, 0.29, 0.32)
	var equipment_color: Color = Color(0.09, 0.12, 0.15)
	var metal_color: Color = Color(0.38, 0.42, 0.45)
	var tape_color: Color = Color(0.91, 0.72, 0.25)
	_set_dressing_root = Node3D.new()
	_set_dressing_root.name = "SetDressing"
	_interior_root.add_child(_set_dressing_root)
	_visual_factory.call("create_wall_panel",
		_interior_root,
		"HighBayMainSetBackdrop",
		Vector3(13.2, 5.0, 0.28),
		set_color,
		Vector3(0.0, 2.5, -7.2)
	)
	_visual_factory.call("create_box",
		_interior_root,
		"HighBaySetPlatform",
		Vector3(13.2, 0.18, 5.4),
		Color(0.27, 0.29, 0.30),
		Vector3(0.0, 0.13, -4.45)
	)
	for side in [-1.0, 1.0]:
		_visual_factory.call("create_wall_panel",
			_interior_root,
			"HighBaySetSideWallLeft" if side < 0.0 else "HighBaySetSideWallRight",
			Vector3(0.22, 4.2, 4.8),
			Color(0.32, 0.35, 0.37),
			Vector3(side * 6.4, 2.1, -4.85)
		)
	for mark_x in [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]:
		_visual_factory.call("create_box",
			_interior_root,
			"HighBayFloorMark_%d" % roundi(mark_x + 7.5),
			Vector3(0.10, 0.025, 3.0),
			tape_color,
			Vector3(mark_x, 0.055, -2.2)
		)
	_camera_rigs.clear()
	for camera_x in [-7.6, 0.0, 7.6]:
		_camera_rigs.append(
		_visual_factory.call(
			"create_camera_rig",
			_interior_root,
			_camera_rigs.size(),
			Vector3(camera_x, 0.0, -1.5),
			metal_color,
			equipment_color
		) as Node3D
	)
	for light_x in [-8.0, -2.7, 2.7, 8.0]:
		_create_light_stand(
			Vector3(light_x, 0.0, -6.1 if absf(light_x) > 4.0 else -1.0),
			metal_color
		)
	_visual_factory.call("create_box",
		_interior_root,
		"HighBayTechnicalEquipmentRack",
		Vector3(1.7, 2.1, 0.8),
		equipment_color,
		Vector3(9.2, 1.05, 6.8)
	)
	_visual_factory.call("create_box",
		_interior_root,
		"HighBayDirectorControlDesk",
		Vector3(2.5, 1.0, 0.85),
		Color(0.20, 0.22, 0.24),
		Vector3(-9.2, 0.55, 6.8)
	)
	_visual_factory.call("create_box",
		_interior_root,
		"HighBayDirectorControlMonitor",
		Vector3(1.35, 0.72, 0.08),
		Color(0.10, 0.29, 0.37),
		Vector3(-9.2, 1.38, 6.8)
	)
	_create_film_slate()
	_workplace_points = [
		Vector3(-4.0, 0.0, -3.0),
		Vector3(0.0, 0.0, -3.0),
		Vector3(4.0, 0.0, -3.0),
		Vector3(-9.0, 0.0, 6.0),
		Vector3(9.0, 0.0, 6.0),
		Vector3(-8.5, 0.0, 1.0),
		Vector3(8.5, 0.0, 1.0),
		Vector3(-5.5, 0.0, 6.5),
		Vector3(-2.0, 0.0, 6.5),
		Vector3(2.0, 0.0, 6.5),
		Vector3(5.5, 0.0, 6.5),
		Vector3(0.0, 0.0, 3.8),
	]
