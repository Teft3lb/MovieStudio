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


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_catalogue()
	_test_building_serialization()
	_test_placement_validation()

	_finish_test("StudioBuildingSystemSmokeTest")


func _test_catalogue() -> void:
	var building_ids: Array[String] = (
		BUILDING_CATALOG_SCRIPT.get_building_type_ids()
	)
	_expect(
		building_ids.size() == 3
		and building_ids[0] == "editing_suite"
		and building_ids[1] == "script_department"
		and building_ids[2] == "sound_stage",
		"The building catalogue must expose the Editing Suite, Script Department and Sound Stage."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("script_department") == 3,
		"The script department must expose three workplace slots."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("sound_stage") == 8,
		"The sound stage must expose eight workplace slots."
	)
	_expect(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("editing_suite") == 3,
		"The Editing Suite must expose three editor workstations."
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
