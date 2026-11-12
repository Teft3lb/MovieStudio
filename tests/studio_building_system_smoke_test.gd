extends "res://tests/smoke_test_base.gd"

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const PLACEMENT_RULES_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_placement_rules.gd"
)
const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const STUDIO_BUILDING_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_manager.gd"
)
const NAVIGATION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_catalogue()
	_test_building_serialization()
	_test_facility_buildings()
	_test_facility_navigation()
	_test_placement_validation()

	_finish_test("StudioBuildingSystemSmokeTest")


func _test_catalogue() -> void:
	var building_ids: Array[String] = (
		BUILDING_CATALOG_SCRIPT.get_building_type_ids()
	)
	_expect(
		building_ids.size() == 7
		and building_ids[0] == "cafeteria"
		and building_ids[1] == "editing_suite"
		and building_ids[2] == "prop_warehouse"
		and building_ids[3] == "script_department"
		and building_ids[4] == "sound_stage"
		and building_ids[5] == "staff_housing"
		and building_ids[6] == "star_bungalow",
		"The building catalogue must expose all production and staff facility buildings."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("script_department") == 3,
		"The script department must expose three workplace slots."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("sound_stage") == 8
		and BUILDING_CATALOG_SCRIPT.get_stage_workplace_capacity(1) == 6
		and BUILDING_CATALOG_SCRIPT.get_stage_workplace_capacity(3) == 12,
		"The default sound stage must expose eight slots, with six and twelve slots for small and large tiers."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_stage_footprint(1) == Vector2(10.0, 8.0)
		and BUILDING_CATALOG_SCRIPT.get_stage_footprint(2) == Vector2(14.0, 12.0)
		and BUILDING_CATALOG_SCRIPT.get_stage_footprint(3) == Vector2(22.0, 18.0),
		"Sound stage tiers must expose their configured construction footprints."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("editing_suite") == 3,
		"The Editing Suite must expose three editor workstations."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("prop_warehouse") == 0
		and not BUILDING_CATALOG_SCRIPT.accepts_profession(
			"prop_warehouse",
			"technician"
		),
		"The prop warehouse must be a storage building, not a competing technician workplace."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("cafeteria") == 0
		and BUILDING_CATALOG_SCRIPT.get_facility_capacity("cafeteria") == 12
		and not BUILDING_CATALOG_SCRIPT.accepts_profession(
			"cafeteria",
			"actor"
		),
		"The cafeteria must provide twelve visitor places without becoming a staff workplace."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("staff_housing") == 0
		and BUILDING_CATALOG_SCRIPT.get_facility_capacity("staff_housing") == 8
		and not BUILDING_CATALOG_SCRIPT.accepts_profession(
			"staff_housing",
			"actor"
		),
		"Staff housing must provide eight beds without becoming a staff workplace."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_facility_capacity("star_bungalow") == 1
		and BUILDING_CATALOG_SCRIPT.get_workplace_capacity("star_bungalow") == 0,
		"A star bungalow must provide one private bed without becoming a workplace."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.accepts_profession(
			"script_department",
			"screenwriter"
		),
		"The script department must accept screenwriters."
	)
	_expect(
		not BUILDING_CATALOG_SCRIPT.accepts_profession(
			"script_department",
			"actor"
		),
		"The script department must not accept unrelated professions."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.accepts_profession(
			"sound_stage",
			"camera_operator"
		),
		"The sound stage must accept camera operators."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.accepts_profession(
			"editing_suite",
			"film_editor"
		),
		"The Editing Suite must accept film editors."
	)
	_expect(
		not BUILDING_CATALOG_SCRIPT.accepts_profession(
			"editing_suite",
			"technician"
		),
		"The Editing Suite must reject unrelated production roles."
	)

func _test_building_serialization() -> void:
	var building: Variant = BUILDING_DATA_SCRIPT.new()
	building.id = "BLD-TEST-01"
	building.building_type_id = "sound_stage"
	building.display_name = "Тестовый павильон"
	building.position = Vector3(12.0, 0.0, -8.0)
	building.rotation_degrees = 90.0
	building.is_operational = true
	building.stage_size_tier = 3

	var restored: Variant = BUILDING_DATA_SCRIPT.from_dict(building.to_dict())
	_expect(restored.id == building.id, "Building ID must survive serialization.")
	_expect(
		restored.building_type_id == building.building_type_id,
		"Building type must survive serialization."
	)
	_expect(
		restored.position.is_equal_approx(building.position),
		"Building position must survive serialization."
	)
	_expect(
		is_equal_approx(restored.rotation_degrees, 90.0),
		"Building rotation must survive serialization."
	)
	_expect(
		restored.stage_size_tier == 3,
		"Sound stage size tier must survive serialization."
	)


func _test_facility_buildings() -> void:
	for building_type_id in ["cafeteria", "staff_housing", "star_bungalow"]:
		var building: Variant = BUILDING_DATA_SCRIPT.new()
		building.id = "BLD-%s" % building_type_id.to_upper()
		building.building_type_id = building_type_id
		building.display_name = BUILDING_CATALOG_SCRIPT.get_title(
			building_type_id
		)
		building.position = Vector3.ZERO
		var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
		root.add_child(actor)
		actor.call("setup", building)
		var facility_path: Array[Vector3] = actor.call(
			"get_workplace_path",
			0
		)
		_expect(
			facility_path.size() == 4,
			"%s must expose an entrance route and an interior facility point."
			% building_type_id
		)
		actor.free()


func _test_facility_navigation() -> void:
	var source_building: Variant = BUILDING_DATA_SCRIPT.new()
	source_building.id = "BLD-FACILITY-SOURCE"
	source_building.building_type_id = "script_department"
	source_building.position = Vector3(-16.0, 0.0, -16.0)
	var target_building: Variant = BUILDING_DATA_SCRIPT.new()
	target_building.id = "BLD-FACILITY-TARGET"
	target_building.building_type_id = "cafeteria"
	target_building.position = Vector3(-32.0, 0.0, -16.0)

	var source_actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	var target_actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	root.add_child(source_actor)
	root.add_child(target_actor)
	source_actor.call("setup", source_building)
	target_actor.call("setup", target_building)

	var manager: Node3D = STUDIO_BUILDING_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.set("_navigation_system", NAVIGATION_SYSTEM_SCRIPT.new())
	manager.set("_buildings", [source_building, target_building])
	manager.set("_building_actors", {
		source_building.id: source_actor,
		target_building.id: target_actor,
	})
	var start_position: Vector3 = source_actor.call(
		"get_workplace_position",
		0
	)
	var target_position: Vector3 = target_actor.call(
		"get_workplace_position",
		0
	)
	var facility_route: Array[Vector3] = manager.call(
		"get_facility_path_from",
		target_building.id,
		0,
		start_position,
		source_building.id,
		0
	)
	_expect(
		facility_route.size() > 6
		and facility_route.front().is_equal_approx(start_position)
		and facility_route.back().is_equal_approx(target_position),
		"Facility navigation must exit the source building, use outdoor pathfinding and enter the destination."
	)

	manager.free()
	source_actor.free()
	target_actor.free()


func _test_placement_validation() -> void:
	var existing: Variant = BUILDING_DATA_SCRIPT.new()
	existing.id = "BLD-EXISTING"
	existing.building_type_id = "script_department"
	existing.position = Vector3(-14.0, 0.0, -8.0)

	var valid_result: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"sound_stage",
		Vector3(0.0, 0.0, 0.0),
		0.0,
		[existing]
	)
	_expect(
		bool(valid_result.get("valid", false)),
		"Initial script department and sound stage positions must not overlap."
	)
	var warehouse_result: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"prop_warehouse",
		Vector3(20.0, 0.0, 10.0),
		0.0,
		[existing]
	)
	_expect(
		bool(warehouse_result.get("valid", false)),
		"The initial prop warehouse position must remain clear of buildings and the access road."
	)

	var cafeteria_placement: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"cafeteria",
		Vector3(-30.0, 0.0, 20.0),
		0.0,
		[]
	)
	var housing_placement: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"staff_housing",
		Vector3(30.0, 0.0, 20.0),
		0.0,
		[]
	)
	_expect(
		bool(cafeteria_placement.get("valid", false))
		and bool(housing_placement.get("valid", false)),
		"Staff facilities must use the standard plot and road placement rules."
	)

	var overlap_result: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"script_department",
		Vector3(-14.0, 0.0, -8.0),
		0.0,
		[existing]
	)
	_expect(
		not bool(overlap_result.get("valid", true)),
		"Buildings must not be placed on top of an existing building."
	)

	var large_stage_bounds_result: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"sound_stage",
		Vector3(-30.0, 0.0, 35.0),
		0.0,
		[],
		PLACEMENT_RULES_SCRIPT.DEFAULT_PLOT_HALF_SIZE,
		3
	)
	_expect(
		bool(large_stage_bounds_result.get("valid", false)),
		"A large stage must be placeable when its complete footprint fits the plot."
	)
	var bounds_result: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"sound_stage",
		Vector3(50.0, 0.0, 50.0),
		0.0,
		[]
	)
	_expect(
		not bool(bounds_result.get("valid", true)),
		"Buildings must stay inside the studio plot."
	)

	var road_result: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"script_department",
		Vector3(10.0, 0.0, 0.0),
		0.0,
		[]
	)
	_expect(
		not bool(road_result.get("valid", true)),
		"Buildings must not obstruct the existing access road."
	)

	var rotated_footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
		"script_department",
		90.0
	)
	_expect(
		rotated_footprint == Vector2(6.0, 8.0),
		"Rotating a building by 90 degrees must swap its placement footprint."
	)
	var rotated_editing_footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
		"editing_suite",
		90.0
	)
	_expect(
		rotated_editing_footprint == Vector2(8.0, 10.0),
		"The Editing Suite must use its own rotated placement footprint."
	)
