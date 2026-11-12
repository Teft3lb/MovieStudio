extends RefCounted
class_name StudioOfficeVisualBuilder

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
	_create_box(
		_actor,
		"EditingBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
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
	var desk_color: Color = Color(0.22, 0.24, 0.26)
	var metal_color: Color = Color(0.15, 0.17, 0.19)
	var screen_color: Color = Color(0.08, 0.28, 0.36)
	var mixer_color: Color = Color(0.31, 0.34, 0.35)

	for slot_index in range(3):
		var desk_x: float = float(slot_index - 1) * 3.0
		_create_box(
			_interior_root,
			"EditingDesk_%d" % slot_index,
			Vector3(2.45, 0.16, 0.95),
			desk_color,
			Vector3(desk_x, 0.82, -0.55)
		)
		for leg_x in [-1.02, 1.02]:
			for leg_z in [-0.34, 0.34]:
				_create_box(
					_interior_root,
					"EditingDeskLeg_%d_%d_%d" % [
						slot_index,
						roundi(leg_x * 100.0),
						roundi(leg_z * 100.0),
					],
					Vector3(0.09, 0.78, 0.09),
					metal_color,
					Vector3(desk_x + leg_x, 0.40, -0.55 + leg_z)
				)
		_create_box(
			_interior_root,
			"EditingMonitor_%d" % slot_index,
			Vector3(0.78, 0.54, 0.08),
			screen_color,
			Vector3(desk_x - 0.43, 1.25, -0.93)
		)
		_create_box(
			_interior_root,
			"EditingPreviewMonitor_%d" % slot_index,
			Vector3(0.78, 0.54, 0.08),
			Color(0.12, 0.24, 0.30),
			Vector3(desk_x + 0.43, 1.25, -0.93)
		)
		_create_box(
			_interior_root,
			"EditingKeyboard_%d" % slot_index,
			Vector3(0.72, 0.04, 0.22),
			metal_color,
			Vector3(desk_x - 0.22, 0.93, -0.12)
		)
		_create_box(
			_interior_root,
			"AudioMixer_%d" % slot_index,
			Vector3(0.58, 0.18, 0.42),
			mixer_color,
			Vector3(desk_x + 0.76, 0.95, -0.12)
		)
		_create_cylinder(
			_interior_root,
			"EditingChairSeat_%d" % slot_index,
			0.32,
			0.12,
			metal_color,
			Vector3(desk_x, 0.48, 0.82)
		)
		_create_box(
			_interior_root,
			"EditingChairBack_%d" % slot_index,
			Vector3(0.62, 0.68, 0.12),
			Color(0.12, 0.15, 0.18),
			Vector3(desk_x, 0.86, 1.08)
		)

	_create_box(
		_interior_root,
		"EditingReferenceDisplay",
		Vector3(3.4, 1.8, 0.12),
		Color(0.07, 0.17, 0.22),
		Vector3(0.0, 2.25, -depth * 0.5 + 0.18)
	)
	_create_box(
		_interior_root,
		"AudioEquipmentRack",
		Vector3(0.82, 1.85, 0.72),
		metal_color,
		Vector3(width * 0.5 - 0.55, 0.93, -2.55)
	)
	_workplace_points = [
		Vector3(-3.0, 0.0, 1.55),
		Vector3(0.0, 0.0, 1.55),
		Vector3(3.0, 0.0, 1.55),
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
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"OfficeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)

	_create_box(
		_actor,
		"OfficeBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
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
