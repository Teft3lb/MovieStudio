extends RefCounted
class_name StudioFacilityVisualBuilder

const FURNITURE = preload("res://scripts/presentation/studio/studio_office_furniture.gd")

var _actor: Node3D
var _interior_root: Node3D
var _visual_factory: RefCounted
var _roof_assembly: Node3D
var _workplace_points: Array[Vector3] = []
var _warehouse_inventory_root: Node3D
var _warehouse_storage_positions: Array[Vector3] = []
var _wardrobe_inventory_root: Node3D


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
	_wardrobe_inventory_root = null

	match building_type_id:
		"film_promotion":
			_build_film_promotion(footprint, height, definition)
		"costume_wardrobe":
			_build_costume_wardrobe(footprint, height, definition)
		"prop_exchange":
			_build_prop_exchange(footprint, height, definition)
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
		"wardrobe_inventory_root": _wardrobe_inventory_root,
	}


func _build_film_promotion(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	_create_floor(footprint, Color(0.32, 0.28, 0.25), "PromotionFloor")
	_create_perimeter_walls(
		width, depth, wall_height, Color(0.55, 0.43, 0.36), 2.4, 2.7
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"PromotionRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		Color(0.24, 0.22, 0.24),
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_actor,
		"PromotionSign",
		Vector3(5.8, 0.62, 0.16),
		definition.get("accent_color", Color(0.68, 0.38, 0.28)),
		Vector3(0.0, 3.0, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"PromotionSignText",
		"РЕКЛАМНЫЙ ОТДЕЛ",
		Vector3(0.0, 3.0, depth * 0.5 + 0.32),
		18
	)
	var poster_assets := ["PosterPremiere", "PosterSummit", "PosterMidnight"]
	var poster_titles := ["ПРЕМЬЕРА", "ВЫШЕ ОБЛАКОВ", "ПОСЛЕ ПОЛУНОЧИ"]
	for poster_index in range(poster_assets.size()):
		var poster_x: float = -3.8 + float(poster_index) * 3.8
		_create_box(_interior_root, "PromotionPosterFrame_%d" % poster_index,
			Vector3(2.45, 2.9, 0.12), Color(0.16, 0.17, 0.19), Vector3(poster_x, 2.05, -4.55))
		FURNITURE.place(_interior_root, poster_assets[poster_index], "PromotionPoster_%d" % poster_index,
			Vector3(poster_x, 2.05, -4.44))
		_create_label(_interior_root, "PromotionPosterTitle_%d" % poster_index, poster_titles[poster_index],
			Vector3(poster_x, 1.12, -4.37), 16)
	FURNITURE.place(_interior_root, "ConferenceTable", "PromotionConferenceTable", Vector3(0, 0, 1.25))
	for side in [-1, 1]:
		for column in range(3):
			FURNITURE.place(_interior_root, "OfficeChair", "PromotionChair_%d_%d" % [side, column],
				Vector3((column - 1) * 1.27, 0, 1.25 + side * 1.13)).rotation.y = PI if side < 0 else 0.0
	FURNITURE.place(_interior_root, "FloorPlant", "PromotionPlant", Vector3(5.3, 0, 3.4))
	FURNITURE.place(_interior_root, "PreviewWall", "PromotionPresentationScreen",
		Vector3(width * .5 - .24, 2.15, 1.22)).rotation.y = -PI * .5

	FURNITURE.floor_zone(_interior_root, "RestInset", "CampaignMeetingZone", Vector2(0, 1.26), Vector2(5.45, 3.49))
	for side in [-1, 1]:
		var x: float = side * 2.31
		FURNITURE.place(_interior_root, "WriterDesk", "CampaignDesk_%d" % side, Vector3(x, 0, -2.67))
		FURNITURE.place(_interior_root, "OfficeMonitor", "CampaignMonitor_%d" % side, Vector3(x, .90, -2.87))
		FURNITURE.place(_interior_root, "OfficeKeyboard", "CampaignKeyboard_%d" % side, Vector3(x, .90, -2.42))
		FURNITURE.place(_interior_root, "OfficeChair", "CampaignSeat_%d" % side, Vector3(x, 0, -1.75))
	FURNITURE.place(_interior_root, "PrintStation", "CampaignPlotter", Vector3(4.58, 0, -3.40)).rotation.y = -PI * .5
	FURNITURE.place(_interior_root, "ServiceCredenza", "CampaignMockupArchive", Vector3(-4.79, 0, -1.65)).rotation.y = PI * .5
	FURNITURE.place(_interior_root, "ScriptFolio", "CampaignProofs", Vector3(-4.79, .90, -1.37)).rotation.y = PI * .39
	FURNITURE.place(_get_wall_group("left"), "StoryBoard", "CampaignPlan", Vector3(-5.72, 1.90, 1.45)).rotation.y = PI * .5


func _build_costume_wardrobe(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	_create_floor(footprint, Color(0.43, 0.36, 0.34), "WardrobeFloor")
	_create_perimeter_walls(
		width, depth, wall_height, Color(0.62, 0.53, 0.48), 2.4, 2.7
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"WardrobeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		Color(0.25, 0.22, 0.25),
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_actor,
		"WardrobeSign",
		Vector3(5.2, 0.62, 0.16),
		definition.get("accent_color", Color(0.47, 0.34, 0.46)),
		Vector3(0.0, 3.0, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"WardrobeSignText",
		"ГАРДЕРОБНАЯ",
		Vector3(0.0, 3.0, depth * 0.5 + 0.32),
		19
	)
	for side in [-1.0, 1.0]:
		_create_box(
			_interior_root,
			"WardrobeRackFrame_%d" % int(side),
			Vector3(0.16, 0.23, 5.7),
			Color(0.22, 0.24, 0.25),
			Vector3(side * 4.65, 0.17, -0.2)
		)
		_create_box(
			_interior_root,
			"WardrobeRackBar_%d" % int(side),
			Vector3(0.08, 0.08, 5.6),
			Color(0.72, 0.67, 0.57),
			Vector3(side * 4.65, 2.25, -0.2)
		)
		for support_index in range(2):
			var support_z: float = -2.82 + float(support_index) * 5.25
			_create_box(
				_interior_root,
				"WardrobeRackFoot_%d_%d" % [int(side), support_index],
				Vector3(0.82, 0.12, 0.12),
				Color(0.20, 0.21, 0.22),
				Vector3(
					side * 4.65,
					0.08,
					support_z
				)
			)
			_create_box(_interior_root, "WardrobeRackPost_%d_%d" % [int(side), support_index],
				Vector3(.087, 2.21, .095), Color(.25, .28, .29),
				Vector3(side * 4.65, 1.12, support_z))
	FURNITURE.place(_interior_root, "FittingMirror", "WardrobeFittingMirror", Vector3(0, 1.48, -4.76))
	FURNITURE.place(_interior_root, "PrivacyScreen", "WardrobeFittingScreen",
		Vector3(1.24, 0, -3.93), true).rotation.y = PI * .5
	FURNITURE.floor_zone(_interior_root, "RestInset", "WardrobeFittingMat", Vector2(0, -3.68), Vector2(2.75, 1.85))
	FURNITURE.place(_interior_root, "ClubChair", "WardrobeFittingSeat", Vector3(.37, 0, -3.39))
	FURNITURE.place(_interior_root, "DressForm", "WardrobeFittingMannequin", Vector3(-1.66, 0, -4.04))
	FURNITURE.place(_interior_root, "TailorBench", "WardrobeTailorStation", Vector3(-2.74, 0, -.57), true)
	FURNITURE.place(_interior_root, "IronStation", "WardrobeIronStation", Vector3(3.01, 0, -3.80), true)
	FURNITURE.place(_interior_root, "LaundryHamper", "WardrobeLaundry", Vector3(4.41, 0, -4.28))
	for side in [-1, 1]:
		FURNITURE.place(_interior_root, "CostumeRail", "WardrobeSampleRail_%d" % side,
			Vector3(side * 6.07, 0, -1.42)).rotation.y = -side * PI * .5
		FURNITURE.place(_interior_root, "Wardrobe", "WardrobeSupplyCabinet_%d" % side,
			Vector3(side * 6.03, 0, 3.48)).rotation.y = -side * PI * .5
		FURNITURE.place(_get_wall_group("back"), "WallSconce", "WardrobeSconce_%d" % side,
			Vector3(side * 1.58, 2.62, -depth * .5 + .23))
	FURNITURE.place(_interior_root, "ServiceCredenza", "WardrobeTextileTable", Vector3(2.92, 0, .14)).rotation.y = -PI * .5
	FURNITURE.place(_interior_root, "WardrobeNotions", "WardrobeSwatches", Vector3(2.92, .90, .08)).rotation.y = -PI * .5
	FURNITURE.floor_zone(_interior_root, "TechnicalInset", "WardrobeSewingMat", Vector2(-2.74, -.42), Vector2(2.10, 1.67))
	_wardrobe_inventory_root = Node3D.new()
	_wardrobe_inventory_root.name = "WardrobeInventory"
	_wardrobe_inventory_root.position = Vector3(0.0, 0.0, 0.0)
	_interior_root.add_child(_wardrobe_inventory_root)


func _build_prop_exchange(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	_create_floor(footprint, Color(0.38, 0.33, 0.27), "PropExchangeFloor")
	_create_perimeter_walls(
		width, depth, wall_height, Color(0.57, 0.49, 0.38), 2.6, 2.7
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"PropExchangeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		Color(0.24, 0.23, 0.20),
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_actor,
		"PropExchangeSign",
		Vector3(6.2, 0.62, 0.16),
		definition.get("accent_color", Color(0.55, 0.42, 0.25)),
		Vector3(0.0, 3.0, depth * 0.5 + 0.22)
	)
	_create_label(
		_actor,
		"PropExchangeSignText",
		"СКУПКА РЕКВИЗИТА",
		Vector3(0.0, 3.0, depth * 0.5 + 0.32),
		18
	)
	_create_box(
		_interior_root,
		"PropExchangeCounter",
		Vector3(7.4, 0.92, 1.0),
		Color(0.30, 0.22, 0.16),
		Vector3(0.0, 0.55, -4.25)
	)
	_create_box(
		_interior_root,
		"PropExchangeCounterTop",
		Vector3(7.65, 0.14, 1.12),
		Color(0.68, 0.57, 0.39),
		Vector3(0.0, 1.08, -4.25)
	)
	for side in [-1.0, 1.0]:
		_create_box(
			_interior_root,
			"PropExchangeShelf_%d" % int(side),
			Vector3(0.72, 2.25, 5.7),
			Color(0.25, 0.24, 0.21),
			Vector3(side * 5.4, 1.12, -0.15)
		)
		for shelf_index in range(3):
			_create_box(
				_interior_root,
				"PropExchangeShelfBoard_%d_%d" % [int(side), shelf_index],
				Vector3(1.0, 0.12, 5.8),
				Color(0.43, 0.32, 0.22),
				Vector3(
					side * 5.15,
					0.45 + float(shelf_index) * 0.78,
					-0.15
				)
			)
	for display_index in range(3):
		_create_box(
			_interior_root,
			"PropExchangeDisplay_%d" % display_index,
			Vector3(1.35, 0.72, 1.05),
			Color(0.48, 0.38, 0.27),
			Vector3(
				-3.0 + float(display_index) * 3.0,
				0.36,
				1.45
			)
		)

	FURNITURE.place(_interior_root, "OfficeMonitor", "ExchangeRegister", Vector3(2.53, 1.15, -4.31))
	FURNITURE.place(_interior_root, "CupService", "ExchangeDeskCups", Vector3(-2.93, 1.15, -4.18))
	FURNITURE.floor_zone(_interior_root, "DiningInset", "ExchangeDisplayArea", Vector2(0, 1.45), Vector2(8.32, 2.05))
	FURNITURE.place(_get_wall_group("back"), "StoryBoard", "ExchangeIntakeBoard", Vector3(0, 2.26, -depth * .5 + .23))
	for display_index in range(3):
		FURNITURE.place(_interior_root, "PropStock", "ExchangeSamples_%d" % display_index,
			Vector3(-3 + display_index * 3, .72, 1.45)).scale = Vector3.ONE * .65
	for side in [-1, 1]:
		FURNITURE.place(_interior_root, "FlightCaseCart", "ExchangeTransferCart_%d" % side,
			Vector3(side * 5.71, 0, 3.55)).rotation.y = -side * PI * .5
		for shelf_index in range(3):
			var stock := FURNITURE.place(_interior_root, "PropStock", "ExchangeShelfStock_%d_%d" % [side, shelf_index],
				Vector3(side * 4.96, .51 + shelf_index * .78, -1.77 + shelf_index * 1.68))
			stock.rotation.y = -side * PI * .5
			stock.scale = Vector3.ONE * .78


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
	_build_base_trim(width, depth, trim_color, "WarehouseBaseTrim")
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

	for side in [-1, 1]:
		_create_box(_interior_root, "WarehouseReserveShelf_%d" % side,
			Vector3(.98, .14, 5.9), shelf_color, Vector3(side * 3.75, 3.55, -.25))
		for bay in range(2):
			var stock := FURNITURE.place(_interior_root, "PropStock", "WarehouseReserveStock_%d_%d" % [side, bay],
				Vector3(side * 3.75, 3.62, -1.97 + bay * 3.47))
			stock.rotation.y = -side * PI * .5
			stock.scale = Vector3.ONE * .85
	FURNITURE.place(_interior_root, "WorkshopBench", "WarehouseSortingBench", Vector3(0, 0, -3.31), true)
	FURNITURE.place(_interior_root, "EquipmentRack", "WarehouseToolStorage", Vector3(-2.23, 0, -3.44), true)
	FURNITURE.place(_interior_root, "FlightCaseCart", "WarehouseReceivingCart", Vector3(3.44, 0, 3.0), true)
	FURNITURE.floor_zone(_interior_root, "TechnicalInset", "WarehouseSortingFloor", Vector2(0, -3.18), Vector2(4.2, 1.35))
	FURNITURE.place(_get_wall_group("back"), "StoryBoard", "WarehouseIntakeBoard", Vector3(0, 2.11, -depth * .5 + .23))
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
		var station := Vector3(station_x, 0, -2.1)
		FURNITURE.place(_interior_root, "TreadmillDeck", "FitnessTreadmillBase_%d" % station_index, station)
		FURNITURE.place(_interior_root, "TreadmillConsole", "FitnessTreadmillConsole_%d" % station_index, station)
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
	FURNITURE.floor_zone(_interior_root, "TechnicalInset", "FitnessCardioArea", Vector2(0, -2.32), Vector2(9.12, 2.63))
	FURNITURE.floor_zone(_interior_root, "RestInset", "FitnessRecoveryMat", Vector2(4.63, 2.68), Vector2(2.25, 2.75))
	for mat_index in range(2):
		FURNITURE.floor_zone(_interior_root, "RestInset", "FitnessStretchMat_%d" % mat_index,
			Vector2(-2.50 + mat_index * 4.62, 2.36), Vector2(1.35, 2.03))
	FURNITURE.place(_interior_root, "GymWeights", "FitnessFreeWeights", Vector3(-5.01, 0, 2.89), true)
	FURNITURE.place(_interior_root, "WaterCooler", "FitnessHydration", Vector3(5.28, 0, 3.62))
	FURNITURE.place(_get_wall_group("back"), "WallClock", "FitnessIntervalClock", Vector3(0, 3.55, -depth * .5 + .23))
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
		_get_wall_group("front"),
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
	FURNITURE.place(_interior_root, "CoffeeMachine", "LoungeCoffeeMachine", Vector3(-1.55, 1.12, -4.35))
	FURNITURE.place(_interior_root, "ClubTable", "LoungeCoffeeTable", Vector3(0, 0, 0.15))
	_create_box(_interior_root, "LoungeAreaRug", Vector3(4.2, 0.034, 2.4),
		Color(0.33, 0.23, 0.19), Vector3(0.0, 0.044, 0.15))
	for side in [-1, 1]:
		var suffix := "Left" if side < 0 else "Right"
		FURNITURE.place(_interior_root, "ClubSofa", "LoungeSofaBase" + suffix,
			Vector3(side * 4.5, 0.0, 0.2)).rotation.y = -side * PI * 0.5
		FURNITURE.place(_interior_root, "FloorPlant", "LoungePlant" + suffix,
			Vector3(side * 5.8, 0.0, -3.0))
	FURNITURE.place(_interior_root, "WaterCooler", "LoungeWaterCooler", Vector3(3.0, 0, -4.45))
	FURNITURE.place(_interior_root, "CupService", "LoungeCupService", Vector3(-0.67, 1.12, -4.34))
	FURNITURE.place(_interior_root, "ServiceCredenza", "LoungeRefreshmentStorage", Vector3(4.53, 0, -4.63))
	FURNITURE.place(_interior_root, "CanteenTray", "LoungeSnackTray", Vector3(4.31, .90, -4.58))
	FURNITURE.place(_interior_root, "ScriptFolio", "LoungeReadingFolio", Vector3(.46, .65, .34)).rotation.y = -.32
	FURNITURE.place(_get_wall_group("back"), "StoryboardFrames", "LoungeFilmStills", Vector3(0, 2.20, -depth * 0.5 + 0.23))
	FURNITURE.place(_get_wall_group("back"), "WallClock", "LoungeClock", Vector3(2.2, 2.5, -depth * 0.5 + 0.22))
	for side in [-1, 1]:
		FURNITURE.floor_zone(_interior_root, "RestInset", "LoungeSeatingRug_%d" % side,
			Vector2(side * 4.42, 0.20), Vector2(2.15, 2.55))
		FURNITURE.place(_get_wall_group("back"), "WallSconce", "LoungeSconce_%d" % side,
			Vector3(side * 3.45, 2.56, -depth * 0.5 + 0.22))
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
	_build_base_trim(width, depth, trim_color, "CafeteriaBaseTrim")
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
	for position_x in [-2.22, -.06]:
		FURNITURE.place(_interior_root, "ServingLine", "ServingTrays_%s" % position_x,
			Vector3(position_x, 1.16, -4.38))
	FURNITURE.place(_interior_root, "CoffeeMachine", "CafeteriaCoffeeMachine", Vector3(2.64, 1.16, -4.43))
	FURNITURE.place(_interior_root, "WaterCooler", "CafeteriaWaterCooler",
		Vector3(width * 0.5 - 0.63, 0, -4.31)).rotation.y = -PI * 0.5
	FURNITURE.place(_interior_root, "WasteStation", "CafeteriaWasteStation",
		Vector3(-width * 0.5 + 0.62, 0, 3.5)).rotation.y = PI * 0.5
	for side in [-1, 1]:
		var end_x: float = side * (width * 0.5 - 1.45)
		FURNITURE.place(_interior_root, "ClubTable", "CafeteriaBreakTable_%d" % side,
			Vector3(end_x, 0, 3.94))
		FURNITURE.place(_interior_root, "CanteenTray", "CafeteriaBreakTray_%d" % side,
			Vector3(end_x - .42, .65, 4.15)).rotation.y = side * .25
		FURNITURE.place(_interior_root, "ClubChair", "CafeteriaBreakChair_%d" % side,
			Vector3(end_x, 0, 2.94))

	FURNITURE.place(_get_wall_group("back"), "CafeMenu", "CafeteriaMenu",
		Vector3(0, 3.13, -depth * 0.5 + 0.23))
	FURNITURE.place(_interior_root, "KitchenFridge", "ColdStorage", Vector3(-5.35, 0, -5.08), true)
	FURNITURE.place(_interior_root, "KitchenSink", "KitchenWashStation", Vector3(4.48, 0, -5.02), true)
	FURNITURE.place(_interior_root, "CupService", "CafeteriaCupService", Vector3(3.42, 1.16, -4.40))
	FURNITURE.place(_interior_root, "WasteStation", "KitchenWasteSorting", Vector3(-6.30, 0, -3.64)).rotation.y = PI * 0.5
	for side in [-1, 1]:
		var suffix := str(side)
		FURNITURE.place(_interior_root, "FloorPlant", "CafeteriaPlant" + suffix, Vector3(side * 6.34, 0, 4.95))
		FURNITURE.place(_get_wall_group("back"), "WallSconce", "CafeteriaSconce" + suffix,
			Vector3(side * 2.24, 3.25, -depth * 0.5 + 0.22))
		FURNITURE.floor_zone(_interior_root, "DiningInset", "CafeteriaBreakout" + suffix,
			Vector2(side * 5.54, 3.70), Vector2(2.22, 2.68))
	for table_index in range(3):
		FURNITURE.floor_zone(_interior_root, "DiningInset", "DiningBay_%d" % table_index,
			Vector2((table_index - 1) * 4.0, 0.35), Vector2(2.76, 3.78))

	var seat_positions: Array[Vector3] = []
	var table_centers: Array[float] = [-4.0, 0.0, 4.0]
	var table_center_z: float = 0.35
	for table_index in range(table_centers.size()):
		var center_x: float = table_centers[table_index]
		FURNITURE.place(_interior_root, "DiningTable", "CafeteriaTable_%d" % table_index,
			Vector3(center_x, 0.0, table_center_z))
		var table_seats: Array[Vector3] = [
			Vector3(center_x - 0.55, 0.0, table_center_z - 1.3),
			Vector3(center_x + 0.55, 0.0, table_center_z - 1.3),
			Vector3(center_x - 0.55, 0.0, table_center_z + 1.3),
			Vector3(center_x + 0.55, 0.0, table_center_z + 1.3),
		]
		for seat_index in range(table_seats.size()):
			var seat_position: Vector3 = table_seats[seat_index]
			seat_positions.append(seat_position)
			var chair := FURNITURE.place(_interior_root, "DiningChair",
				"CafeteriaChair_%d_%d" % [table_index, seat_index], seat_position)
			var front_row: bool = seat_position.z < table_center_z
			chair.rotation.y = PI if front_row else 0.0
			FURNITURE.place(_interior_root, "DiningChairBack",
				"CafeteriaChairBack_%d_%d" % [table_index, seat_index],
				seat_position + Vector3(0.0, 0.853, -0.31 if front_row else 0.31))
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
	_build_base_trim(width, depth, trim_color, "StaffHousingBaseTrim")
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


	var bed_z_positions: Array[float] = [-3.5, -1.2, 1.2, 3.5]
	var sleeping_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for bed_index in range(bed_z_positions.size()):
			var bed_z: float = bed_z_positions[bed_index]
			var bed_position := Vector3(side * 5.15, 0.0, bed_z)
			var suffix: String = "_%d_%d" % [int(side), bed_index]
			FURNITURE.place(_interior_root, "BedFrame", "StaffBedFrame" + suffix, bed_position)
			FURNITURE.place(_interior_root, "BedMattress", "StaffBedMattress" + suffix,
				bed_position + Vector3.UP * 0.40)
			FURNITURE.place(_interior_root, "BedPillow", "StaffBedPillow" + suffix,
				bed_position + Vector3(0, 0.56, -0.55))
			sleeping_positions.append(
				Vector3(bed_position.x, 0.0, bed_z + 0.75)
			)
		for panel_index in range(3):
			var divider_z: float = (bed_z_positions[panel_index] + bed_z_positions[panel_index + 1]) * 0.5
			FURNITURE.place(_interior_root, "PrivacyScreen", "BedPrivacy_%d_%d" % [int(side), panel_index],
				Vector3(side * 5.44, 0, divider_z), true)
		var wall_group := _get_wall_group("left" if side < 0 else "right")
		for bed_index in bed_z_positions.size():
			var sconce := FURNITURE.place(wall_group, "WallSconce", "DormSconce_%d" % bed_index,
				Vector3(side * (width * 0.5 - 0.19), 2.10, bed_z_positions[bed_index]))
			sconce.rotation.y = -side * PI * 0.5
		FURNITURE.floor_zone(_interior_root, "RestInset", "DormitoryBedBay_%d" % int(side),
			Vector2(side * 5.16, 0), Vector2(2.26, 9.45))
		FURNITURE.place(_interior_root, "Locker", "StaffLocker_%d" % int(side),
			Vector3(side * 6.42, 0, 0.0)).rotation.y = -side * PI * 0.5
		FURNITURE.place(_interior_root, "Nightstand", "StaffBedside_%d" % int(side),
			Vector3(side * 3.91, 0, 0), true)
		FURNITURE.place(_interior_root, "TaskLamp", "StaffBedsideLamp_%d" % int(side),
			Vector3(side * 3.91, 0.70, 0))
		FURNITURE.place(_interior_root, "FloorPlant", "StaffPlant_%d" % int(side),
			Vector3(side * 2.65, 0, -depth * 0.5 + 0.75))
	FURNITURE.floor_zone(_interior_root, "RestInset", "DormitoryRunner",
		Vector2(0, 0), Vector2(1.65, depth - 2.80))
	FURNITURE.place(_get_wall_group("back"), "StoryboardFrames", "DormitoryGallery",
		Vector3(0, 1.89, -depth * 0.5 + 0.24))
	FURNITURE.place(_interior_root, "LaundryHamper", "DormitoryLaundry", Vector3(6.03, 0, 4.98))
	FURNITURE.place(_interior_root, "ClubSofa", "DormitoryBench", Vector3(0, 0, -depth * 0.5 + 0.74))
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
	_build_base_trim(width, depth, trim_color, "StarBungalowBaseTrim")
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


	var bed_position := Vector3(0.0, 0.0, -1.3)
	var frame := FURNITURE.place(_interior_root, "BedFrame", "StarBedFrame", bed_position)
	frame.scale = Vector3(1.32, 1.0, 1.21)
	var mattress := FURNITURE.place(_interior_root, "BedMattress", "StarBedMattress",
		bed_position + Vector3.UP * 0.41)
	mattress.scale = Vector3(1.35, 1.0, 1.21)
	var pillow := FURNITURE.place(_interior_root, "BedPillow", "StarBedPillow",
		bed_position + Vector3(0, 0.56, -0.72))
	pillow.scale.x = 1.22
	FURNITURE.place(_interior_root, "Wardrobe", "StarWardrobe", Vector3(-3.35, 0, -1.25))
	FURNITURE.place(_interior_root, "Nightstand", "StarNightstand", Vector3(2.65, 0, -1.3))
	FURNITURE.place(_interior_root, "TaskLamp", "StarBedsideLamp", Vector3(2.65, 0.70, -1.3))
	FURNITURE.place(_interior_root, "ClubChair", "StarLoungeChair", Vector3(2.65, 0, 1.05)).rotation.y = -PI * 0.5
	FURNITURE.place(_interior_root, "FloorPlant", "StarPlant", Vector3(-3.32, 0, 1.63))
	FURNITURE.floor_zone(_interior_root, "RestInset", "BungalowBedRug", Vector2(0, -1.2), Vector2(3.4, 3.0))
	FURNITURE.place(_interior_root, "ClubTable", "BungalowReadingTable", Vector3(3.6, 0, 2.25), true).scale = Vector3(0.66, 0.84, 0.72)
	FURNITURE.place(_get_wall_group("back"), "StoryboardFrames", "BungalowPhotoWall", Vector3(0, 2.17, -depth * 0.5 + 0.24))
	FURNITURE.place(_get_wall_group("back"), "WallSconce", "BungalowSconce", Vector3(3.15, 2.3, -depth * 0.5 + 0.23))
	_workplace_points = [Vector3(0.0, 0.0, -1.3)]


func _build_base_trim(width: float, depth: float, color: Color, node_name: String) -> void:
	for side in [-1, 1]:
		_create_box(_get_wall_group("left" if side < 0 else "right"), node_name + "Side",
			Vector3(.14, .26, depth), color, Vector3(side * width * .5, .13, 0))
	_create_box(_get_wall_group("back"), node_name + "Back",
		Vector3(width, .26, .14), color, Vector3(0, .13, -depth * .5))


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
