extends "res://tests/smoke_test_base.gd"

const GEOMETRY_SUITE_SCRIPT = preload(
	"res://tests/studio_building_geometry_test_suite.gd"
)
const SOUND_STAGE_SUITE_SCRIPT = preload(
	"res://tests/studio_sound_stage_test_suite.gd"
)
const FACILITY_SUITE_SCRIPT = preload(
	"res://tests/studio_building_facility_test_suite.gd"
)
const EMPLOYEE_SUITE_SCRIPT = preload(
	"res://tests/studio_building_employee_test_suite.gd"
)

var _active_suites: Array[RefCounted] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_run_suite(GEOMETRY_SUITE_SCRIPT.new())
	_run_suite(SOUND_STAGE_SUITE_SCRIPT.new())
	_run_suite(FACILITY_SUITE_SCRIPT.new())
	_run_suite(EMPLOYEE_SUITE_SCRIPT.new())
	_finish_test("StudioBuildingInteriorSmokeTest")


func _run_suite(suite: RefCounted) -> void:
	_active_suites.append(suite)
	suite.call("run", self)
	_expect(
		get_nodes_in_group("studio_building").is_empty(),
		"Interior test fixtures must be released between suites to avoid overlapping wall collisions."
	)
