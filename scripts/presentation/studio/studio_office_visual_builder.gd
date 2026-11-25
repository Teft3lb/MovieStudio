extends RefCounted
class_name StudioOfficeVisualBuilder

const FURNITURE = preload("res://scripts/presentation/studio/studio_office_furniture.gd")

var _actor: Node3D
var _interior_root: Node3D
var _visual_factory: RefCounted
var _roof_assembly: Node3D
var _workplace_points: Array[Vector3] = []


func build(
	actor: Node3D,
	interior_root: Node3D,
	visual_factory: RefCounted,
	building_type_id: String,
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> Dictionary:
	_actor = actor
	_interior_root = interior_root
	_visual_factory = visual_factory
	_roof_assembly = null
	_workplace_points.clear()
	match building_type_id:
		"editing_suite":
			_build_editing_suite(footprint, height, definition)
		_:
			_build_script_department(footprint, height, definition)
	return {
		"roof_assembly": _roof_assembly,
		"workplace_points": _workplace_points,
	}


func _build_editing_suite(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.37, 0.42, 0.45)
	var roof_color: Color = Color(0.19, 0.23, 0.26)
	var trim_color: Color = Color(0.13, 0.17, 0.19)
	var glass_color: Color = Color(0.14, 0.31, 0.38)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.34, 0.48, 0.52)
	)

	_create_floor(
		footprint,
		Color(0.24, 0.27, 0.29),
		"EditingFloor"
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
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"EditingRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_build_base_trim(width, depth, trim_color)
	_create_box(
		_get_wall_group("front"),
		"EditingWindowLeft",
		Vector3(1.45, 1.15, 0.12),
		glass_color,
		Vector3(-3.0, 3.7, depth * 0.5 + 0.22)
	)
	_create_box(
		_get_wall_group("front"),
		"EditingWindowRight",
		Vector3(1.45, 1.15, 0.12),
		glass_color,
		Vector3(3.0, 3.7, depth * 0.5 + 0.22)
	)
	_create_box(
		_actor,
		"EditingSuiteSign",
		Vector3(4.8, 0.55, 0.16),
		accent_color,
		Vector3(0.0, 2.85, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"EditingSuiteSignText",
		"МОНТАЖНЫЙ ОТДЕЛ",
		Vector3(0.0, 2.85, depth * 0.5 + 0.32),
		18
	)

	_build_editing_suite_interior(width, depth)

func _build_editing_suite_interior(width: float, depth: float) -> void:
	var reels: Array[Transform3D] = []
	for slot_index in range(3):
		var desk_x: float = float(slot_index - 1) * 3.0
		var keyboard := Vector3(desk_x, 0.9, -0.17)
		FURNITURE.place(_interior_root, "EditingDesk", "EditingDesk_%d" % slot_index,
			Vector3(desk_x, 0, -0.55))
		FURNITURE.place(_interior_root, "OfficeMonitor", "EditingMonitor_%d" % slot_index,
			Vector3(desk_x - 0.43, 0.9, -0.84))
		FURNITURE.place(_interior_root, "OfficeMonitor", "EditingPreviewMonitor_%d" % slot_index,
			Vector3(desk_x + 0.43, 0.9, -0.84))
		FURNITURE.place(_interior_root, "OfficeKeyboard", "EditingKeyboard_%d" % slot_index, keyboard)
		FURNITURE.place(_interior_root, "AudioMixer", "AudioMixer_%d" % slot_index,
			Vector3(desk_x + 0.77, 0.9, -0.31))
		if slot_index != 0:
			reels.append(Transform3D(Basis.IDENTITY, Vector3(desk_x - .71, .90, -.30)))
		for side in [-1, 1]:
			FURNITURE.place(_interior_root, "StudioSpeaker", "EditingSpeaker_%d_%d" % [slot_index, side],
				Vector3(desk_x + side * 1.02, 0.9, -0.87))
		if slot_index != 1:
			FURNITURE.place(_interior_root, "TaskLamp", "EditingLamp_%d" % slot_index,
				Vector3(desk_x - 0.91, 0.9, -0.68))
		_add_workstation(slot_index, Vector3(desk_x, 0, 0.47), keyboard)
	FURNITURE.place_batch(_interior_root, "FoleyReels", "EditingReels", reels, 38.0)

	FURNITURE.place(_interior_root, "PreviewWall", "EditingReferenceDisplay",
		Vector3(0.0, 2.25, -depth * 0.5 + 0.25))
	FURNITURE.place(_interior_root, "EquipmentRack", "AudioEquipmentRack",
		Vector3(width * 0.5 - 0.72, 0, -2.55))
	FURNITURE.place(_interior_root, "ServiceCredenza", "EditingMediaStorage", Vector3(-3.64, 0, -3.25))
	FURNITURE.place(_interior_root, "MediaArchive", "EditingMasterArchive", Vector3(2.67, 0, -3.45), true)
	FURNITURE.place(_interior_root, "MediaArchive", "EditingSourceArchive", Vector3(-1.59, 0, -3.45), true)
	for side in [-1, 1]:
		FURNITURE.place(_get_wall_group("back"), "AcousticBaffles", "EditingBaffles_%d" % side,
			Vector3(side * 2.8, 2.31, -depth * 0.5 + 0.22))
	FURNITURE.floor_zone(_interior_root, "TechnicalInset", "EditingConsoleFloor", Vector2(0, -.38), Vector2(8.6, 2.65))
	FURNITURE.floor_zone(_interior_root, "RestInset", "EditingReviewFloor", Vector2(3.68, 2.58), Vector2(2.16, 2.08))
	FURNITURE.place(_get_wall_group("right"), "PreviewWall", "EditingScreeningDisplay", Vector3(4.77, 1.81, 2.0)).rotation.y = -PI * 0.5
	FURNITURE.place(_interior_root, "ClubChair", "EditingReviewSeat", Vector3(3.68, 0, 2.58), true).rotation.y = PI * 0.5
	FURNITURE.place(_interior_root, "ClubSofa", "EditingBreakSofa", Vector3(-3.61, 0, 3.19), true).rotation.y = PI
	var cable := FURNITURE.place(_interior_root, "CableRun", "EditingCableChannel", Vector3(0, 0, -1.45))
	cable.scale.z = 3.5
	cable.rotation.y = PI * 0.5

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
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"OfficeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)

	_build_base_trim(width, depth, trim_color)
	_create_box(
		_get_wall_group("front"),
		"OfficeFrontWindowLeft",
		Vector3(1.55, 1.25, 0.12),
		glass_color,
		Vector3(-2.35, 3.75, depth * 0.5 + 0.22)
	)
	_create_box(
		_get_wall_group("front"),
		"OfficeFrontWindowRight",
		Vector3(1.55, 1.25, 0.12),
		glass_color,
		Vector3(2.35, 3.75, depth * 0.5 + 0.22)
	)
	_create_box(
		_actor,
		"OfficeSign",
		Vector3(4.6, 0.52, 0.16),
		accent_color,
		Vector3(0.0, 2.85, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"OfficeSignText",
		"СЦЕНАРНЫЙ ОТДЕЛ",
		Vector3(0.0, 2.85, depth * 0.5 + 0.32),
		18
	)

	_build_script_department_interior(width, depth)

func _build_script_department_interior(width: float, depth: float) -> void:
	var drafts: Array[Transform3D] = []
	for slot_index in range(3):
		var desk_x: float = float(slot_index - 1) * 2.35
		var desk_name: String = "WriterDesk" if slot_index == 0 else "WriterDesk%d" % (slot_index + 1)
		var keyboard := Vector3(desk_x, 0.9, -0.60)
		var monitor_name: String = "ComputerMonitor" if slot_index == 0 else "ComputerMonitor%d" % (slot_index + 1)
		FURNITURE.place(_interior_root, "WriterDesk", desk_name, Vector3(desk_x, 0, -0.95))
		FURNITURE.place(_interior_root, "OfficeMonitor", monitor_name,
			Vector3(desk_x, 0.9, -1.20))
		FURNITURE.place(_interior_root, "OfficeKeyboard", "WriterKeyboard_%d" % slot_index, keyboard)
		FURNITURE.place(_interior_root, "TaskLamp", "WriterLamp_%d" % slot_index,
			Vector3(desk_x - 0.63, 0.9, -1.13))
		if slot_index != 1:
			var heading := Basis(Vector3.UP, .16 * (slot_index - 1))
			drafts.append(Transform3D(heading, Vector3(desk_x + .62, .90, -.71)))
		_add_workstation(slot_index, Vector3(desk_x, 0, 0.04), keyboard)
	FURNITURE.place_batch(_interior_root, "ScriptFolio", "WriterDrafts", drafts, 38.0)

	FURNITURE.place(_interior_root, "ScriptLibrary", "Bookshelf",
		Vector3(-width * 0.5 + 0.46, 0, -0.72)).rotation.y = PI / 2.0
	FURNITURE.place(_interior_root, "StoryBoard", "ResearchBoard",
		Vector3(width * 0.5 - 1.28, 1.92, -depth * 0.5 + 0.23))
	FURNITURE.place(_interior_root, "ClubTable", "ScriptReviewTable",
		Vector3(width * 0.5 - 1.52, 0, depth * 0.5 - 1.75), true)
	FURNITURE.place(_interior_root, "ClubChair", "ScriptReviewChair",
		Vector3(width * 0.5 - 1.52, 0, depth * 0.5 - 0.45)).rotation.y = PI
	FURNITURE.floor_zone(_interior_root, "RestInset", "ScriptReviewRug", Vector2(2.47, 1.73), Vector2(2.28, 2.25))
	FURNITURE.place(_get_wall_group("back"), "StoryboardFrames", "ScriptShotStudies", Vector3(-1.82, 2.08, -depth * 0.5 + 0.24))
	FURNITURE.place(_get_wall_group("back"), "WallClock", "ScriptClock", Vector3(.39, 3.17, -depth * 0.5 + 0.24))
	FURNITURE.place(_get_wall_group("back"), "ProjectWall", "ScriptContinuityWall",
		Vector3(.49, 2.06, -depth * .5 + .24)).scale.x = .88
	FURNITURE.place(_interior_root, "ServiceCredenza", "ScriptContinuityStorage", Vector3(.49, 0, -2.49))
	FURNITURE.place(_get_wall_group("right"), "WallSconce", "ScriptReviewLight", Vector3(width * 0.5 - .23, 2.47, 1.55)).rotation.y = -PI * .5
	var coffee := Vector3(-width * .5 + .54, 0, 1.97)
	FURNITURE.place(_interior_root, "ServiceCredenza", "ScriptCoffeeStation", coffee, true).rotation.y = PI * .5
	FURNITURE.place(_interior_root, "CoffeeMachine", "ScriptCoffeeMaker", coffee + Vector3(0, .9, .31)).rotation.y = PI * .5
	FURNITURE.place(_interior_root, "CupService", "ScriptCoffeeCups", coffee + Vector3(0, .9, -.38)).rotation.y = PI * .5
	FURNITURE.place(_interior_root, "WasteStation", "ScriptWaste", Vector3(-3.48, 0, .74)).rotation.y = PI * .5
	FURNITURE.place(_interior_root, "FloorPlant", "ScriptPlant", Vector3(-3.42, 0, -2.42)).scale = Vector3.ONE * .75


func _add_workstation(index: int, seat: Vector3, keyboard: Vector3) -> void:
	var station := OfficeInteractionSlot.new()
	station.setup(str(_actor.call("get_building_id")), index, seat, keyboard)
	_interior_root.add_child(station)
	_workplace_points.append(seat)
	FURNITURE.place(_interior_root, "OfficeChair", "OfficeChair_%d" % index, seat)


func _build_base_trim(width: float, depth: float, color: Color) -> void:
	var front_panel_width := (width - 1.8) * 0.5
	for side in [-1, 1]:
		var name: String = "left" if side < 0 else "right"
		_create_box(_get_wall_group(name), "SideBaseTrim", Vector3(0.14, 0.28, depth + 0.12),
			color, Vector3(side * width * 0.5, 0.14, 0.0))
		_create_box(_get_wall_group("front"), "FrontBaseTrim_%d" % side,
			Vector3(front_panel_width, 0.28, 0.14), color,
			Vector3(side * (0.90 + front_panel_width * 0.5), 0.14, depth * 0.5))
	_create_box(_get_wall_group("back"), "BackBaseTrim", Vector3(width, 0.28, 0.14),
		color, Vector3(0.0, 0.14, -depth * 0.5))


func _create_floor(
	footprint: Vector2,
	color: Color,
	node_name: String
) -> void:
	_visual_factory.call(
		"create_floor",
		_interior_root,
		footprint,
		color,
		node_name
	)


func _create_perimeter_walls(
	width: float,
	depth: float,
	wall_height: float,
	wall_color: Color,
	door_width: float,
	door_height: float
) -> void:
	_actor.call(
		"_create_perimeter_walls",
		width,
		depth,
		wall_height,
		wall_color,
		door_width,
		door_height
	)


func _get_wall_group(group_id: String) -> Node3D:
	return _actor.call(
		"get_wall_group_for_visual_builder",
		group_id
	) as Node3D


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


func _create_label(
	parent: Node3D,
	node_name: String,
	label_text: String,
	local_position: Vector3,
	font_size: int
) -> void:
	_visual_factory.call(
		"create_label",
		parent,
		node_name,
		label_text,
		local_position,
		font_size
	)


func _create_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	cylinder_height: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	return _visual_factory.call(
		"create_cylinder",
		parent,
		node_name,
		radius,
		cylinder_height,
		color,
		local_position
	) as MeshInstance3D
