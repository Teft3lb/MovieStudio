extends RefCounted
class_name StudioSetPropVisualBuilder

var _visual_factory: RefCounted


func setup(visual_factory: RefCounted) -> void:
	_visual_factory = visual_factory


func build(parent: Node3D, prop_id: String) -> void:
	var wood: Color = Color(0.38, 0.25, 0.16)
	var dark_wood: Color = Color(0.20, 0.13, 0.09)
	var metal: Color = Color(0.27, 0.31, 0.34)
	var accent: Color = Color(0.63, 0.48, 0.27)
	var glass: Color = Color(0.10, 0.29, 0.36)
	match prop_id:
		"street_storefront":
			_create_box(parent, "Facade", Vector3(1.8, 2.6, 0.34), Color(0.53, 0.43, 0.32), Vector3(0.0, 1.3, 0.0))
			_create_box(parent, "Awning", Vector3(1.95, 0.25, 0.72), Color(0.64, 0.25, 0.18), Vector3(0.0, 2.0, -0.22))
			_create_box(parent, "ShopWindow", Vector3(0.9, 0.95, 0.06), glass, Vector3(-0.35, 1.15, -0.2))
			_create_box(parent, "Door", Vector3(0.42, 1.75, 0.08), dark_wood, Vector3(0.68, 0.88, -0.2))
		"street_lamp":
			_create_cylinder(parent, "LampPost", 0.07, 2.9, metal, Vector3(0.0, 1.45, 0.0))
			_create_box(parent, "LampHead", Vector3(0.55, 0.34, 0.48), Color(0.86, 0.77, 0.53), Vector3(0.0, 2.95, -0.12))
		"street_bench":
			_create_box(parent, "BenchSeat", Vector3(1.55, 0.16, 0.48), wood, Vector3(0.0, 0.55, 0.0))
			_create_box(parent, "BenchBack", Vector3(1.55, 0.72, 0.14), wood, Vector3(0.0, 0.95, 0.18))
			for leg_x in [-0.58, 0.58]:
				_create_box(parent, "BenchLeg", Vector3(0.12, 0.52, 0.12), metal, Vector3(leg_x, 0.27, 0.0))
		"home_sofa":
			_create_box(parent, "SofaBase", Vector3(1.65, 0.52, 0.78), Color(0.35, 0.22, 0.25), Vector3(0.0, 0.48, 0.0))
			_create_box(parent, "SofaBack", Vector3(1.65, 0.82, 0.22), Color(0.42, 0.27, 0.30), Vector3(0.0, 1.0, 0.28))
			for arm_x in [-0.82, 0.82]:
				_create_box(parent, "SofaArm", Vector3(0.22, 0.62, 0.78), Color(0.39, 0.24, 0.27), Vector3(arm_x, 0.63, 0.0))
		"home_coffee_table":
			_create_box(parent, "TableTop", Vector3(1.25, 0.12, 0.72), wood, Vector3(0.0, 0.62, 0.0))
			for leg_x in [-0.48, 0.48]:
				for leg_z in [-0.24, 0.24]:
					_create_box(parent, "TableLeg", Vector3(0.08, 0.58, 0.08), dark_wood, Vector3(leg_x, 0.29, leg_z))
		"home_floor_lamp":
			_create_cylinder(parent, "LampStand", 0.045, 1.8, metal, Vector3(0.0, 0.9, 0.0))
			_create_cylinder(parent, "LampShade", 0.34, 0.38, accent, Vector3(0.0, 1.75, 0.0))
		"forest_trees":
			_create_cylinder(parent, "TreeTrunk", 0.18, 2.0, dark_wood, Vector3(0.0, 1.0, 0.0))
			var canopy := _create_sphere(parent, "TreeCanopy", 0.9, Color(0.16, 0.32, 0.19), Vector3(0.0, 2.2, 0.0))
			canopy.scale = Vector3(1.0, 1.2, 1.0)
			_create_cylinder(parent, "TreeTrunkSmall", 0.13, 1.5, dark_wood, Vector3(0.8, 0.75, -0.15))
			_create_sphere(parent, "TreeCanopySmall", 0.65, Color(0.21, 0.39, 0.22), Vector3(0.8, 1.65, -0.15))
		"forest_rocks":
			var rock_a := _create_sphere(parent, "RockA", 0.55, Color(0.38, 0.40, 0.39), Vector3(-0.35, 0.35, 0.0))
			rock_a.scale = Vector3(1.4, 0.8, 1.0)
			var rock_b := _create_sphere(parent, "RockB", 0.42, Color(0.45, 0.46, 0.43), Vector3(0.38, 0.25, -0.1))
			rock_b.scale = Vector3(1.0, 0.65, 1.0)
		"forest_trail_sign":
			_create_cylinder(parent, "SignPost", 0.07, 1.8, dark_wood, Vector3(0.0, 0.9, 0.0))
			_create_box(parent, "TrailSign", Vector3(1.15, 0.48, 0.12), wood, Vector3(0.0, 1.45, -0.05))
		"lighthouse_console":
			_create_box(parent, "ConsoleDesk", Vector3(1.55, 0.9, 0.75), dark_wood, Vector3(0.0, 0.48, 0.0))
			_create_box(parent, "ConsolePanel", Vector3(1.35, 0.52, 0.12), metal, Vector3(0.0, 1.15, -0.22))
			_create_box(parent, "ConsoleScreen", Vector3(0.72, 0.34, 0.05), glass, Vector3(-0.22, 1.18, -0.30))
		"lighthouse_beacon":
			_create_cylinder(parent, "BeaconTower", 0.42, 2.6, Color(0.72, 0.68, 0.55), Vector3(0.0, 1.3, 0.0))
			_create_cylinder(parent, "BeaconLens", 0.48, 0.58, Color(0.83, 0.69, 0.34), Vector3(0.0, 2.35, 0.0))
			_create_cylinder(parent, "BeaconCap", 0.55, 0.16, metal, Vector3(0.0, 2.72, 0.0))
		"lighthouse_rail":
			for rail_x in [-0.75, 0.0, 0.75]:
				_create_cylinder(parent, "RailPost", 0.055, 1.1, metal, Vector3(rail_x, 0.55, 0.0))
			_create_box(parent, "RailTop", Vector3(1.65, 0.08, 0.08), metal, Vector3(0.0, 1.0, 0.0))
			_create_box(parent, "RailBottom", Vector3(1.65, 0.08, 0.08), metal, Vector3(0.0, 0.42, 0.0))
		"industrial_crates":
			_create_box(parent, "CrateA", Vector3(0.85, 0.85, 0.85), wood, Vector3(-0.38, 0.43, 0.0))
			_create_box(parent, "CrateB", Vector3(0.75, 0.75, 0.75), accent, Vector3(0.42, 0.38, -0.12))
			_create_box(parent, "CrateC", Vector3(0.62, 0.62, 0.62), dark_wood, Vector3(0.0, 1.13, 0.0))
		"industrial_pipes":
			for pipe_x in [-0.48, 0.0, 0.48]:
				_create_cylinder(parent, "PipeStack", 0.13, 2.2, metal, Vector3(pipe_x, 1.1, 0.0))
			_create_box(parent, "PipeRack", Vector3(1.25, 0.12, 0.72), dark_wood, Vector3(0.0, 0.18, 0.0))
		"industrial_work_light":
			_create_cylinder(parent, "WorkLightStand", 0.06, 2.0, metal, Vector3(0.0, 1.0, 0.0))
			_create_box(parent, "WorkLightHead", Vector3(0.85, 0.58, 0.28), Color(0.82, 0.73, 0.48), Vector3(0.0, 2.05, -0.12))
		"office_desk":
			_create_box(parent, "OfficeDeskTop", Vector3(1.5, 0.14, 0.78), dark_wood, Vector3(0.0, 0.82, 0.0))
			for leg_x in [-0.62, 0.62]:
				for leg_z in [-0.28, 0.28]:
					_create_box(parent, "OfficeDeskLeg", Vector3(0.08, 0.78, 0.08), metal, Vector3(leg_x, 0.39, leg_z))
		"office_bookshelf":
			_create_box(parent, "ShelfBack", Vector3(1.35, 2.25, 0.12), dark_wood, Vector3(0.0, 1.12, 0.0))
			for shelf_y in [0.35, 0.95, 1.55, 2.15]:
				_create_box(parent, "Shelf", Vector3(1.4, 0.08, 0.42), wood, Vector3(0.0, shelf_y, -0.16))
		"office_evidence_board":
			_create_box(parent, "EvidenceBoard", Vector3(1.55, 1.45, 0.12), Color(0.39, 0.34, 0.25), Vector3(0.0, 1.55, 0.0))
			for note_x in [-0.42, 0.0, 0.42]:
				_create_box(parent, "EvidenceNote", Vector3(0.22, 0.28, 0.035), Color(0.82, 0.78, 0.61), Vector3(note_x, 1.65, -0.09))
		"scifi_lab_console":
			_create_box(parent, "LabConsoleBase", Vector3(1.55, 0.85, 0.72), metal, Vector3(0.0, 0.44, 0.0))
			_create_box(parent, "LabConsoleScreen", Vector3(1.2, 0.65, 0.1), Color(0.10, 0.54, 0.66), Vector3(0.0, 1.15, -0.22))
		"scifi_reactor":
			_create_cylinder(parent, "ReactorCore", 0.42, 2.5, Color(0.16, 0.42, 0.50), Vector3(0.0, 1.25, 0.0))
			_create_cylinder(parent, "ReactorRingTop", 0.68, 0.14, accent, Vector3(0.0, 2.0, 0.0))
			_create_cylinder(parent, "ReactorRingBottom", 0.68, 0.14, accent, Vector3(0.0, 0.55, 0.0))
		"scifi_holo_display":
			_create_box(parent, "HoloBase", Vector3(1.2, 0.22, 0.7), metal, Vector3(0.0, 0.12, 0.0))
			_create_cylinder(parent, "HoloProjector", 0.08, 1.15, Color(0.13, 0.65, 0.75), Vector3(0.0, 0.72, 0.0))
			_create_box(parent, "HoloImage", Vector3(0.9, 0.75, 0.08), Color(0.15, 0.63, 0.75), Vector3(0.0, 1.48, 0.0))
		_:
			_create_box(parent, "NeutralProp", Vector3(0.8, 0.8, 0.8), wood, Vector3(0.0, 0.4, 0.0))


func _create_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	return _visual_factory.call(
		"create_box",
		parent,
		node_name,
		size,
		color,
		local_position
	) as MeshInstance3D


func _create_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	return _visual_factory.call(
		"create_cylinder",
		parent,
		node_name,
		radius,
		height,
		color,
		local_position
	) as MeshInstance3D


func _create_sphere(
	parent: Node3D,
	node_name: String,
	radius: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	return _visual_factory.call(
		"create_sphere",
		parent,
		node_name,
		radius,
		color,
		local_position
	) as MeshInstance3D
