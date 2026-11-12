extends RefCounted
class_name StudioFacilityVisualBuilder

var _actor: Node3D
var _interior_root: Node3D
var _visual_factory: RefCounted
var _roof_assembly: Node3D
var _workplace_points: Array[Vector3] = []
var _warehouse_inventory_root: Node3D
var _warehouse_storage_positions: Array[Vector3] = []


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
	_warehouse_inventory_root = null
	_warehouse_storage_positions.clear()

	match building_type_id:
		"prop_warehouse":
			_build_prop_warehouse(footprint, height, definition)
		"fitness_center":
			_build_fitness_center(footprint, height, definition)
		"studio_lounge":
			_build_studio_lounge(footprint, height, definition)
		"cafeteria":
			_build_cafeteria(footprint, height, definition)
		"staff_housing":
			_build_staff_housing(footprint, height, definition)
		"star_bungalow":
			_build_star_bungalow(footprint, height, definition)

	return {
		"roof_assembly": _roof_assembly,
		"workplace_points": _workplace_points,
		"warehouse_inventory_root": _warehouse_inventory_root,
		"warehouse_storage_positions": _warehouse_storage_positions,
	}


func _build_prop_warehouse(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.42, 0.38, 0.32)
	var roof_color: Color = Color(0.22, 0.23, 0.23)
	var trim_color: Color = Color(0.16, 0.17, 0.17)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.48, 0.38, 0.25)
	)

	_create_floor(
		footprint,
		Color(0.30, 0.27, 0.22),
		"WarehouseFloor"
	)
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		2.2,
		2.65
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"WarehouseRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_actor,
		"WarehouseBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		_actor,
		"WarehouseSign",
		Vector3(4.6, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.05, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"WarehouseSignText",
		"СКЛАД РЕКВИЗИТА",
		Vector3(0.0, 3.05, depth * 0.5 + 0.32),
		18
	)

	var rack_color: Color = Color(0.20, 0.22, 0.22)
	var shelf_color: Color = Color(0.39, 0.31, 0.22)
	for side in [-1.0, 1.0]:
		_create_box(
			_interior_root,
			"WarehouseRackFrame_%d" % int(side),
			Vector3(0.22, 3.75, 6.0),
			rack_color,
			Vector3(side * 4.2, 1.88, -0.25)
		)
		for shelf_level in range(3):
			_create_box(
				_interior_root,
				"WarehouseShelf_%d_%d" % [int(side), shelf_level],
				Vector3(1.0, 0.14, 6.0),
				shelf_color,
				Vector3(
					side * 3.75,
					0.55 + float(shelf_level) * 1.12,
					-0.25
				)
			)
		for support_index in range(2):
			var support_z: float = -3.0 + float(support_index) * 5.5
			_create_box(
				_interior_root,
				"WarehouseSupport_%d_%d" % [int(side), support_index],
				Vector3(0.12, 3.6, 0.12),
				rack_color,
				Vector3(side * 3.75, 1.8, support_z)
			)

	_warehouse_storage_positions = [
		Vector3(-2.55, 0.0, -2.1),
		Vector3(-0.85, 0.0, -2.1),
		Vector3(0.85, 0.0, -2.1),
		Vector3(2.55, 0.0, -2.1),
		Vector3(-2.55, 0.0, 0.45),
		Vector3(-0.85, 0.0, 0.45),
		Vector3(0.85, 0.0, 0.45),
		Vector3(2.55, 0.0, 0.45),
	]
	_workplace_points = _warehouse_storage_positions.duplicate()
	_warehouse_inventory_root = Node3D.new()
	_warehouse_inventory_root.name = "WarehouseInventory"
	_interior_root.add_child(_warehouse_inventory_root)

func _build_fitness_center(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.42, 0.49, 0.51)
	var roof_color: Color = Color(0.20, 0.25, 0.29)
	var trim_color: Color = Color(0.14, 0.19, 0.23)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.28, 0.48, 0.55)
	)
	_create_floor(footprint, Color(0.22, 0.25, 0.27), "FitnessFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		3.0,
		2.8
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"FitnessCenterRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_roof_assembly,
		"FitnessCenterSkylight",
		Vector3(4.2, 0.16, 2.0),
		Color(0.22, 0.42, 0.48),
		Vector3(0.0, height + 0.08, -1.0)
	)
	_create_box(
		_actor,
		"FitnessCenterSign",
		Vector3(4.8, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.05, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"FitnessCenterSignText",
		"ФИТНЕС-ЦЕНТР",
		Vector3(0.0, 3.05, depth * 0.5 + 0.32),
		19
	)
	_create_box(
		_get_wall_group("front"),
		"FitnessFrontWindowLeft",
		Vector3(1.6, 1.15, 0.12),
		Color(0.15, 0.34, 0.42),
		Vector3(-4.1, 3.1, depth * 0.5 + 0.22)
	)
	_create_box(
		_get_wall_group("front"),
		"FitnessFrontWindowRight",
		Vector3(1.6, 1.15, 0.12),
		Color(0.15, 0.34, 0.42),
		Vector3(4.1, 3.1, depth * 0.5 + 0.22)
	)
	for mirror_x in [-3.2, 0.0, 3.2]:
		_create_box(
			_interior_root,
			"FitnessMirror_%d" % roundi(mirror_x + 3.2),
			Vector3(2.4, 2.3, 0.08),
			Color(0.34, 0.48, 0.52),
			Vector3(mirror_x, 2.0, -4.65)
		)
	for station_index in range(4):
		var station_x: float = -3.75 + float(station_index) * 2.5
		_create_box(
			_interior_root,
			"FitnessTreadmillBase_%d" % station_index,
			Vector3(0.92, 0.18, 1.85),
			trim_color,
			Vector3(station_x, 0.22, -2.1)
		)
		_create_box(
			_interior_root,
			"FitnessTreadmillConsole_%d" % station_index,
			Vector3(0.68, 0.78, 0.16),
			Color(0.12, 0.24, 0.29),
			Vector3(station_x, 0.92, -2.72)
		)
		_create_cylinder(
			_interior_root,
			"FitnessTreadmillHandle_%d" % station_index,
			0.045,
			0.82,
			Color(0.38, 0.43, 0.45),
			Vector3(station_x, 0.82, -1.28)
		)
	_create_box(
		_interior_root,
		"FitnessWeightRack",
		Vector3(0.65, 1.45, 3.4),
		Color(0.18, 0.22, 0.25),
		Vector3(-5.15, 0.72, 0.0)
	)
	_create_box(
		_interior_root,
		"FitnessDumbbellBench",
		Vector3(2.0, 0.32, 0.72),
		Color(0.29, 0.31, 0.33),
		Vector3(5.0, 0.48, 0.2)
	)
	_create_box(
		_interior_root,
		"FitnessMatStorage",
		Vector3(0.45, 1.6, 1.2),
		Color(0.30, 0.37, 0.36),
		Vector3(5.2, 0.8, -3.0)
	)
	_workplace_points = [
		Vector3(-3.75, 0.0, 0.15),
		Vector3(-1.25, 0.0, 0.15),
		Vector3(1.25, 0.0, 0.15),
		Vector3(3.75, 0.0, 0.15),
	]

func _build_studio_lounge(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.58, 0.56, 0.48)
	var roof_color: Color = Color(0.23, 0.27, 0.24)
	var wood_color: Color = Color(0.34, 0.25, 0.18)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.42, 0.54, 0.48)
	)
	_create_floor(footprint, Color(0.43, 0.37, 0.29), "StudioLoungeFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		3.0,
		2.8
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"StudioLoungeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_actor,
		"StudioLoungeEntranceCanopy",
		Vector3(5.2, 0.22, 1.4),
		wood_color,
		Vector3(0.0, 3.05, depth * 0.5 + 0.52)
	)
	_create_box(
		_actor,
		"StudioLoungeSign",
		Vector3(4.6, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.1, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"StudioLoungeSignText",
		"КЛУБ СТУДИИ",
		Vector3(0.0, 3.1, depth * 0.5 + 0.32),
		19
	)
	_create_box(
		_get_wall_group("front"),
		"StudioLoungeWindowLeft",
		Vector3(1.7, 1.2, 0.12),
		Color(0.19, 0.35, 0.37),
		Vector3(-4.5, 3.2, depth * 0.5 + 0.22)
	)
	_create_box(
		_get_wall_group("front"),
		"StudioLoungeWindowRight",
		Vector3(1.7, 1.2, 0.12),
		Color(0.19, 0.35, 0.37),
		Vector3(4.5, 3.2, depth * 0.5 + 0.22)
	)
	_create_box(
		_interior_root,
		"LoungeCoffeeCounter",
		Vector3(5.2, 0.92, 0.92),
		wood_color,
		Vector3(0.0, 0.52, -4.4)
	)
	_create_box(
		_interior_root,
		"LoungeCoffeeCounterTop",
		Vector3(5.45, 0.14, 1.02),
		Color(0.66, 0.57, 0.42),
		Vector3(0.0, 1.05, -4.4)
	)
	_create_box(
		_interior_root,
		"LoungeCoffeeMachine",
		Vector3(0.72, 0.78, 0.55),
		Color(0.17, 0.20, 0.22),
		Vector3(-1.55, 1.48, -4.35)
	)
	_create_box(
		_interior_root,
		"LoungeCoffeeTable",
		Vector3(1.8, 0.16, 1.1),
		wood_color,
		Vector3(0.0, 0.62, 0.15)
	)
	for sofa_index in range(2):
		var sofa_x: float = -4.5 if sofa_index == 0 else 4.5
		var sofa_suffix: String = "Left" if sofa_index == 0 else "Right"
		_create_box(
			_interior_root,
			"LoungeSofaBase" + sofa_suffix,
			Vector3(1.75, 0.55, 2.0),
			Color(0.36, 0.24, 0.27),
			Vector3(sofa_x, 0.48, 0.2)
		)
		_create_box(
			_interior_root,
			"LoungeSofaBack" + sofa_suffix,
			Vector3(1.75, 0.95, 0.24),
			Color(0.43, 0.29, 0.31),
			Vector3(sofa_x, 1.0, -0.72)
		)
		_create_box(
			_interior_root,
			"LoungeSofaArmOuter" + sofa_suffix,
			Vector3(0.22, 0.7, 1.8),
			Color(0.39, 0.27, 0.28),
			Vector3(sofa_x - 0.78, 0.65, 0.2)
		)
		_create_box(
			_interior_root,
			"LoungeSofaArmInner" + sofa_suffix,
			Vector3(0.22, 0.7, 1.8),
			Color(0.39, 0.27, 0.28),
			Vector3(sofa_x + 0.78, 0.65, 0.2)
		)
	for plant_index in range(2):
		var plant_x: float = -5.8 if plant_index == 0 else 5.8
		var plant_suffix: String = "Left" if plant_index == 0 else "Right"
		_create_cylinder(
			_interior_root,
			"LoungePlanter" + plant_suffix,
			0.42,
			0.72,
			Color(0.31, 0.25, 0.19),
			Vector3(plant_x, 0.36, -3.0)
		)
		_create_sphere(
			_interior_root,
			"LoungePlant" + plant_suffix,
			0.72,
			Color(0.18, 0.36, 0.23),
			Vector3(plant_x, 1.15, -3.0)
		)
	_workplace_points = [
		Vector3(-2.6, 0.0, -1.65),
		Vector3(0.0, 0.0, -2.15),
		Vector3(2.6, 0.0, -1.65),
		Vector3(-2.6, 0.0, 2.0),
		Vector3(0.0, 0.0, 2.4),
		Vector3(2.6, 0.0, 2.0),
	]

func _build_cafeteria(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.69, 0.61, 0.48)
	var roof_color: Color = Color(0.29, 0.25, 0.21)
	var trim_color: Color = Color(0.31, 0.24, 0.17)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.66, 0.48, 0.28)
	)

	_create_floor(footprint, Color(0.49, 0.42, 0.32), "CafeteriaFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		2.6,
		2.7
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"CafeteriaRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_actor,
		"CafeteriaBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		_actor,
		"CafeteriaSign",
		Vector3(4.0, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.05, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"CafeteriaSignText",
		"СТОЛОВАЯ",
		Vector3(0.0, 3.05, depth * 0.5 + 0.32),
		20
	)
	_create_box(
		_get_wall_group("front"),
		"CafeteriaWindowLeft",
		Vector3(1.8, 1.2, 0.12),
		Color(0.22, 0.39, 0.43),
		Vector3(-4.5, 3.25, depth * 0.5 + 0.22)
	)
	_create_box(
		_get_wall_group("front"),
		"CafeteriaWindowRight",
		Vector3(1.8, 1.2, 0.12),
		Color(0.22, 0.39, 0.43),
		Vector3(4.5, 3.25, depth * 0.5 + 0.22)
	)

	var counter_color: Color = Color(0.35, 0.25, 0.18)
	var counter_top_color: Color = Color(0.72, 0.65, 0.48)
	_create_box(
		_interior_root,
		"ServingCounter",
		Vector3(7.4, 0.95, 1.0),
		counter_color,
		Vector3(0.0, 0.55, -4.45)
	)
	_create_box(
		_interior_root,
		"ServingCounterTop",
		Vector3(7.7, 0.16, 1.12),
		counter_top_color,
		Vector3(0.0, 1.08, -4.45)
	)
	_create_box(
		_interior_root,
		"KitchenPass",
		Vector3(3.4, 1.0, 0.12),
		Color(0.16, 0.22, 0.24),
		Vector3(0.0, 2.0, -5.75)
	)
	for tray_index in range(4):
		var tray_x: float = -2.7 + float(tray_index) * 1.8
		_create_cylinder(
			_interior_root,
			"ServingTray_%d" % tray_index,
			0.28,
			0.06,
			Color(0.73, 0.72, 0.63),
			Vector3(tray_x, 1.2, -4.45)
		)

	var seat_positions: Array[Vector3] = []
	var table_centers: Array[float] = [-4.0, 0.0, 4.0]
	var table_center_z: float = 0.35
	for table_index in range(table_centers.size()):
		var center_x: float = table_centers[table_index]
		_create_box(
			_interior_root,
			"CafeteriaTable_%d" % table_index,
			Vector3(2.1, 0.16, 1.25),
			Color(0.42, 0.29, 0.19),
			Vector3(center_x, 0.82, table_center_z)
		)
		_create_box(
			_interior_root,
			"CafeteriaTableLeg_%d" % table_index,
			Vector3(0.16, 0.72, 0.16),
			trim_color,
			Vector3(center_x, 0.40, 0.35)
		)
		var table_seats: Array[Vector3] = [
			Vector3(center_x - 0.55, 0.0, table_center_z - 1.3),
			Vector3(center_x + 0.55, 0.0, table_center_z - 1.3),
			Vector3(center_x - 0.55, 0.0, table_center_z + 1.3),
			Vector3(center_x + 0.55, 0.0, table_center_z + 1.3),
		]
		for seat_index in range(table_seats.size()):
			var seat_position: Vector3 = table_seats[seat_index]
			seat_positions.append(seat_position)
			_create_cylinder(
				_interior_root,
				"CafeteriaChairSeat_%d_%d" % [table_index, seat_index],
				0.30,
				0.12,
				Color(0.23, 0.27, 0.27),
				seat_position + Vector3(0.0, 0.48, 0.0)
			)
			var chair_back_side: float = (
				-1.0 if seat_position.z < table_center_z else 1.0
			)
			_create_box(
				_interior_root,
				"CafeteriaChairBack_%d_%d" % [table_index, seat_index],
				Vector3(0.58, 0.62, 0.12),
				Color(0.23, 0.27, 0.27),
				seat_position + Vector3(0.0, 0.80, chair_back_side * 0.34)
			)
	_workplace_points = seat_positions

func _build_staff_housing(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.53, 0.48, 0.39)
	var roof_color: Color = Color(0.24, 0.29, 0.24)
	var trim_color: Color = Color(0.25, 0.29, 0.23)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.42, 0.56, 0.43)
	)

	_create_floor(footprint, Color(0.38, 0.34, 0.27), "StaffHousingFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		2.5,
		2.6
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"StaffHousingRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_actor,
		"StaffHousingBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		_actor,
		"StaffHousingSign",
		Vector3(5.0, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.0, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"StaffHousingSignText",
		"ДОМИК ПЕРСОНАЛА",
		Vector3(0.0, 3.0, depth * 0.5 + 0.32),
		18
	)
	_create_box(
		_get_wall_group("front"),
		"StaffHousingWindowLeft",
		Vector3(1.7, 1.15, 0.12),
		Color(0.20, 0.34, 0.37),
		Vector3(-4.7, 3.2, depth * 0.5 + 0.22)
	)
	_create_box(
		_get_wall_group("front"),
		"StaffHousingWindowRight",
		Vector3(1.7, 1.15, 0.12),
		Color(0.20, 0.34, 0.37),
		Vector3(4.7, 3.2, depth * 0.5 + 0.22)
	)

	var bed_frame_color: Color = Color(0.28, 0.20, 0.15)
	var mattress_color: Color = Color(0.68, 0.65, 0.56)
	var locker_color: Color = Color(0.24, 0.29, 0.28)
	var bed_z_positions: Array[float] = [-3.5, -1.2, 1.2, 3.5]
	var sleeping_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for bed_index in range(bed_z_positions.size()):
			var bed_z: float = bed_z_positions[bed_index]
			var bed_position := Vector3(side * 5.15, 0.0, bed_z)
			_create_box(
				_interior_root,
				"StaffBedFrame_%d_%d" % [int(side), bed_index],
				Vector3(1.55, 0.20, 1.95),
				bed_frame_color,
				bed_position + Vector3(0.0, 0.20, 0.0)
			)
			_create_box(
				_interior_root,
				"StaffBedMattress_%d_%d" % [int(side), bed_index],
				Vector3(1.42, 0.20, 1.82),
				mattress_color,
				bed_position + Vector3(0.0, 0.40, 0.0)
			)
			_create_box(
				_interior_root,
				"StaffBedPillow_%d_%d" % [int(side), bed_index],
				Vector3(0.78, 0.15, 0.46),
				Color(0.83, 0.82, 0.74),
				bed_position + Vector3(0.0, 0.56, -0.55)
			)
			_create_box(
				_interior_root,
				"StaffBedHeadboard_%d_%d" % [int(side), bed_index],
				Vector3(1.55, 0.82, 0.12),
				bed_frame_color,
				bed_position + Vector3(0.0, 0.58, -0.95)
			)
			sleeping_positions.append(
				Vector3(bed_position.x, 0.0, bed_z + 0.75)
			)
		_create_box(
			_interior_root,
			"StaffLocker_%d" % int(side),
			Vector3(0.78, 1.9, 1.0),
			locker_color,
			Vector3(side * 5.5, 0.95, 0.0)
		)
	_workplace_points = sleeping_positions

func _build_star_bungalow(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.63, 0.55, 0.43)
	var roof_color: Color = Color(0.20, 0.23, 0.27)
	var trim_color: Color = Color(0.28, 0.22, 0.17)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.66, 0.53, 0.32)
	)
	_create_floor(footprint, Color(0.48, 0.39, 0.29), "StarBungalowFloor")
	_create_perimeter_walls(width, depth, wall_height, wall_color, 2.4, 2.6)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"StarBungalowRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_actor,
		"StarBungalowBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		_actor,
		"StarBungalowSign",
		Vector3(4.8, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.0, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"StarBungalowSignText",
		"ЗВЁЗДНЫЙ ДОМ",
		Vector3(0.0, 3.0, depth * 0.5 + 0.32),
		18
	)
	_create_box(
		_get_wall_group("front"),
		"StarBungalowWindowLeft",
		Vector3(1.7, 1.15, 0.12),
		Color(0.20, 0.34, 0.37),
		Vector3(-3.3, 3.2, depth * 0.5 + 0.22)
	)
	_create_box(
		_get_wall_group("front"),
		"StarBungalowWindowRight",
		Vector3(1.7, 1.15, 0.12),
		Color(0.20, 0.34, 0.37),
		Vector3(3.3, 3.2, depth * 0.5 + 0.22)
	)
	var bed_frame_color: Color = Color(0.30, 0.22, 0.16)
	var mattress_color: Color = Color(0.77, 0.72, 0.63)
	var bed_position := Vector3(0.0, 0.0, -1.3)
	_create_box(_interior_root, "StarBedFrame", Vector3(2.05, 0.22, 2.35), bed_frame_color, bed_position + Vector3(0.0, 0.20, 0.0))
	_create_box(_interior_root, "StarBedMattress", Vector3(1.92, 0.20, 2.20), mattress_color, bed_position + Vector3(0.0, 0.41, 0.0))
	_create_box(_interior_root, "StarBedPillow", Vector3(0.95, 0.15, 0.48), Color(0.91, 0.88, 0.80), bed_position + Vector3(0.0, 0.56, -0.72))
	_create_box(_interior_root, "StarBedHeadboard", Vector3(2.05, 0.92, 0.14), bed_frame_color, bed_position + Vector3(0.0, 0.58, -1.12))
	_create_box(_interior_root, "StarWardrobe", Vector3(1.15, 2.15, 0.82), Color(0.28, 0.23, 0.20), Vector3(-3.35, 1.08, -1.25))
	_create_box(_interior_root, "StarNightstand", Vector3(0.78, 0.72, 0.68), Color(0.35, 0.25, 0.18), Vector3(2.65, 0.36, -1.3))
	_create_cylinder(_interior_root, "StarBedsideLamp", 0.12, 0.42, Color(0.86, 0.72, 0.48), Vector3(2.65, 0.91, -1.3))
	_create_box(_interior_root, "StarLoungeChair", Vector3(1.05, 0.78, 0.92), Color(0.34, 0.25, 0.25), Vector3(2.65, 0.42, 1.05))
	_workplace_points = [Vector3(0.0, 0.0, -1.3)]


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
