extends SceneTree

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
	_test_catalogue()
	_test_building_serialization()
	_test_placement_validation()

	print("StudioBuildingSystemSmokeTest: PASS")
	quit(0)


func _test_catalogue() -> void:
	var building_ids: Array[String] = (
		BUILDING_CATALOG_SCRIPT.get_building_type_ids()
	)
	assert(
		building_ids == ["script_department", "sound_stage"],
		"The first building slice must expose the script department and sound stage."
	)
	assert(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("script_department") == 3,
		"The script department must expose three workplace slots."
	)
	assert(
		BUILDING_CATALOG_SCRIPT.get_workplace_capacity("sound_stage") == 8,
		"The sound stage must expose eight workplace slots."
	)
	assert(
		BUILDING_CATALOG_SCRIPT.accepts_profession(
			"script_department",
			"screenwriter"
		),
		"The script department must accept screenwriters."
	)
	assert(
		not BUILDING_CATALOG_SCRIPT.accepts_profession(
			"script_department",
			"actor"
		),
		"The script department must not accept unrelated professions."
	)
	assert(
		BUILDING_CATALOG_SCRIPT.accepts_profession(
			"sound_stage",
			"camera_operator"
		),
		"The sound stage must accept camera operators."
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
	assert(restored.id == building.id, "Building ID must survive serialization.")
	assert(
		restored.building_type_id == building.building_type_id,
		"Building type must survive serialization."
	)
	assert(
		restored.position.is_equal_approx(building.position),
		"Building position must survive serialization."
	)
	assert(
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
	assert(
		bool(valid_result.get("valid", false)),
		"Initial script department and sound stage positions must not overlap."
	)

	var overlap_result: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"script_department",
		Vector3(-14.0, 0.0, -8.0),
		0.0,
		[existing]
	)
	assert(
		not bool(overlap_result.get("valid", true)),
		"Buildings must not be placed on top of an existing building."
	)

	var bounds_result: Dictionary = PLACEMENT_RULES_SCRIPT.can_place(
		"sound_stage",
		Vector3(50.0, 0.0, 50.0),
		0.0,
		[]
	)
	assert(
		not bool(bounds_result.get("valid", true)),
		"Buildings must stay inside the studio plot."
	)

	var rotated_footprint: Vector2 = PLACEMENT_RULES_SCRIPT.get_footprint(
		"script_department",
		90.0
	)
	assert(
		rotated_footprint == Vector2(6.0, 8.0),
		"Rotating a building by 90 degrees must swap its placement footprint."
	)
