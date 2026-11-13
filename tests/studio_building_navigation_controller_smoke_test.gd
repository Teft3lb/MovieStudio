extends "res://tests/smoke_test_base.gd"

const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_rotated_office_routes()
	_test_sound_stage_tiers()
	_test_tv_studio_routes()
	_test_facility_routes()
	_test_housing_live_exit_resolution()
	_finish_test("StudioBuildingNavigationControllerSmokeTest")


func _create_building(
	building_type_id: String,
	stage_size_tier: int = 2,
	rotation_degrees: float = 0.0
) -> Node3D:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-NAV-%s-%d" % [
		building_type_id.to_upper(),
		stage_size_tier,
	]
	data.building_type_id = building_type_id
	data.display_name = "Navigation Test %s" % building_type_id
	data.position = Vector3(18.0, 0.0, -12.0)
	data.rotation_degrees = rotation_degrees
	data.stage_size_tier = stage_size_tier
	var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", data)
	root.add_child(actor)
	return actor


func _assert_route_contract(
	actor: Node3D,
	slot_index: int,
	building_label: String
) -> void:
	var route: Array[Vector3] = actor.call("get_workplace_path", slot_index)
	_expect(
		route.size() >= 4,
		"%s workplace %d must have a complete entrance route." % [
			building_label,
			slot_index,
		]
	)
	if route.size() < 4:
		return

	var local_outside: Vector3 = actor.to_local(route.front())
	var local_inside: Vector3 = actor.to_local(route[1])
	_expect(
		local_outside.z > local_inside.z
		and route.front().distance_to(route[1]) > 1.0,
		"%s workplace %d must preserve the outside-to-inside doorway transition." % [
			building_label,
			slot_index,
		]
	)

	var exit_route: Array[Vector3] = actor.call(
		"get_exit_path_from",
		route.back(),
		slot_index
	)
	_expect(
		exit_route.size() >= 2
		and exit_route.front().distance_to(route.back()) <= 0.1
		and exit_route.back().distance_to(route.front()) <= 0.1,
		"%s workplace %d must preserve the reverse route to the same entrance." % [
			building_label,
			slot_index,
		]
	)


func _test_rotated_office_routes() -> void:
	var actor: Node3D = _create_building("script_department", 2, 90.0)
	_assert_route_contract(actor, 0, "Rotated Script Department")
	_assert_route_contract(actor, 2, "Rotated Script Department")
	actor.queue_free()


func _test_sound_stage_tiers() -> void:
	var expected_slots: Array[int] = [6, 8, 12]
	var stage_tiers: Array[int] = [1, 2, 3]
	for stage_tier in stage_tiers:
		var actor: Node3D = _create_building(
			"sound_stage",
			stage_tier,
			float(stage_tier) * 90.0
		)
		var slot_count: int = expected_slots[stage_tier - 1]
		_assert_route_contract(actor, 0, "Sound Stage tier %d" % stage_tier)
		_assert_route_contract(actor, slot_count - 1, "Sound Stage tier %d" % stage_tier)
		actor.queue_free()


func _test_tv_studio_routes() -> void:
	var actor: Node3D = _create_building("tv_studio", 2, 180.0)
	for slot_index in range(10):
		_assert_route_contract(actor, slot_index, "TV Studio")
	actor.queue_free()


func _test_facility_routes() -> void:
	var facility_slots: Dictionary = {
		"cafeteria": 12,
		"fitness_center": 4,
		"studio_lounge": 6,
		"staff_housing": 8,
		"star_bungalow": 1,
		"prop_warehouse": 8,
	}
	var facility_types: Array[String] = [
		"cafeteria",
		"fitness_center",
		"studio_lounge",
		"staff_housing",
		"star_bungalow",
		"prop_warehouse",
	]
	for building_type_id in facility_types:
		var actor: Node3D = _create_building(building_type_id, 2, 270.0)
		var slot_count: int = int(facility_slots[building_type_id])
		_assert_route_contract(actor, 0, building_type_id)
		if slot_count > 1:
			_assert_route_contract(actor, slot_count - 1, building_type_id)
		actor.queue_free()


func _test_housing_live_exit_resolution() -> void:
	var actor: Node3D = _create_building("staff_housing", 2, 90.0)
	var route: Array[Vector3] = actor.call("get_workplace_path", 7)
	_expect(not route.is_empty(), "Staff Housing must provide a route to the last bed.")
	if route.is_empty():
		actor.queue_free()
		return
	var exit_route: Array[Vector3] = actor.call("get_exit_path_from", route.back())
	_expect(
		exit_route.size() >= 2
		and exit_route.front().distance_to(route.back()) <= 0.1
		and exit_route.back().distance_to(route.front()) <= 0.1,
		"An exit request without a bed slot must resolve the nearest occupied bed."
	)
	actor.queue_free()
