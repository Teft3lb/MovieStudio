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
	_test_prop_warehouse()
	_test_fitness_center()
	_test_studio_lounge()
	_test_cafeteria()
	_test_staff_housing()
	_test_star_bungalow()
	_finish_test("StudioFacilityVisualBuilderSmokeTest")


func _create_facility(building_type_id: String) -> Node3D:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-FACILITY-%s-TEST" % building_type_id.to_upper()
	data.building_type_id = building_type_id
	data.display_name = "Test %s" % building_type_id
	data.position = Vector3.ZERO
	data.rotation_degrees = 0.0
	data.stage_size_tier = 2
	var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", data)
	root.add_child(actor)
	return actor


func _test_prop_warehouse() -> void:
	var actor: Node3D = _create_facility("prop_warehouse")
	var interior: Node3D = actor.get_node("Interior") as Node3D
	_expect(
		interior.get_node_or_null("WarehouseFloor") is MeshInstance3D
		and interior.get_node_or_null("WarehouseShelf_-1_0") is MeshInstance3D
		and interior.get_node_or_null("WarehouseShelf_1_2") is MeshInstance3D
		and interior.get_node_or_null("WarehouseInventory") is Node3D,
		"Prop Warehouse must retain its floor, storage racks and live inventory root."
	)
	var storage_mark: Vector3 = actor.call("get_storage_mark", 3)
	var local_storage_mark: Vector3 = actor.to_local(storage_mark)
	_expect(
		absf(local_storage_mark.x) <= 3.0
		and local_storage_mark.z >= -2.2
		and local_storage_mark.z <= 0.6,
		"Warehouse storage marks must remain inside the central pickup aisle."
	)
	actor.call(
		"set_warehouse_inventory",
		["lighthouse_console", "lighthouse_beacon"]
	)
	var inventory_root: Node3D = interior.get_node("WarehouseInventory") as Node3D
	_expect(
		inventory_root.get_child_count() == 2
		and inventory_root.get_node_or_null("StoredProp_lighthouse_console") != null,
		"Warehouse inventory must still create visible reusable prop representations."
	)
	actor.call("set_warehouse_inventory", [])
	_expect(
		inventory_root.get_child_count() == 0,
		"Returning props to stock must clear the warehouse display."
	)
	var workplace_path: Array[Vector3] = actor.call("get_workplace_path", 0)
	_expect(
		workplace_path.size() == 4,
		"Warehouse pickup routes must pass through the building entrance."
	)
	actor.queue_free()


func _test_fitness_center() -> void:
	var actor: Node3D = _create_facility("fitness_center")
	var interior: Node3D = actor.get_node("Interior") as Node3D
	_expect(
		interior.get_node_or_null("FitnessFloor") is MeshInstance3D
		and interior.get_node_or_null("FitnessMirror_0") is MeshInstance3D
		and interior.get_node_or_null("FitnessTreadmillBase_0") is MeshInstance3D
		and interior.get_node_or_null("FitnessTreadmillConsole_3") is MeshInstance3D
		and actor.get_node_or_null("RoofAssembly/FitnessCenterSkylight") is MeshInstance3D,
		"Fitness Center must retain its mirrors, four cardio stations and roof skylight."
	)
	var all_routes_valid: bool = true
	for slot_index in range(4):
		var route: Array[Vector3] = actor.call("get_workplace_path", slot_index)
		if route.size() < 4:
			all_routes_valid = false
	_expect(
		all_routes_valid,
		"Every fitness station must have a complete entrance and interior route."
	)
	actor.queue_free()


func _test_studio_lounge() -> void:
	var actor: Node3D = _create_facility("studio_lounge")
	var interior: Node3D = actor.get_node("Interior") as Node3D
	_expect(
		interior.get_node_or_null("LoungeCoffeeCounter") is MeshInstance3D
		and interior.get_node_or_null("LoungeCoffeeTable") is MeshInstance3D
		and interior.get_node_or_null("LoungeSofaBaseLeft") is MeshInstance3D
		and interior.get_node_or_null("LoungeSofaBaseRight") is MeshInstance3D
		and interior.get_node_or_null("LoungePlantLeft") is MeshInstance3D,
		"Studio Lounge must retain its coffee area, two seating zones and decorative plants."
	)
	var first_route: Array[Vector3] = actor.call("get_workplace_path", 0)
	var last_route: Array[Vector3] = actor.call("get_workplace_path", 5)
	_expect(
		first_route.size() >= 4
		and last_route.size() >= 4
		and first_route.back().distance_to(last_route.back()) > 3.0,
		"Studio Lounge must retain six separated social positions."
	)
	# The lounge's outermost social positions must remain independently reachable.
	actor.queue_free()


func _test_cafeteria() -> void:
	var actor: Node3D = _create_facility("cafeteria")
	var interior: Node3D = actor.get_node("Interior") as Node3D
	_expect(
		interior.get_node_or_null("ServingCounter") is MeshInstance3D
		and interior.get_node_or_null("ServingCounterTop") is MeshInstance3D
		and interior.get_node_or_null("KitchenPass") is MeshInstance3D
		and interior.get_node_or_null("CafeteriaChairBack_0_0") is MeshInstance3D,
		"Cafeteria must retain its serving counter, kitchen pass and individual seating."
	)
	var front_path: Array[Vector3] = actor.call("get_workplace_path", 0)
	var second_front_path: Array[Vector3] = actor.call("get_workplace_path", 1)
	var back_path: Array[Vector3] = actor.call("get_workplace_path", 2)
	var second_back_path: Array[Vector3] = actor.call("get_workplace_path", 3)
	var front_seat: Vector3 = actor.to_local(front_path.back())
	var second_front_seat: Vector3 = actor.to_local(second_front_path.back())
	var back_seat: Vector3 = actor.to_local(back_path.back())
	var second_back_seat: Vector3 = actor.to_local(second_back_path.back())
	_expect(
		absf(front_seat.z - second_front_seat.z) < 0.01
		and absf(back_seat.z - second_back_seat.z) < 0.01
		and front_seat.z < back_seat.z
		and absf(front_seat.x - second_front_seat.x) > 0.8,
		"Cafeteria seats must stay aligned along both long sides of each table."
	)
	var front_chair_back: Node3D = actor.get_node(
		"Interior/CafeteriaChairBack_0_0"
	) as Node3D
	var back_chair_back: Node3D = actor.get_node(
		"Interior/CafeteriaChairBack_0_2"
	) as Node3D
	var front_back_position: Vector3 = actor.to_local(front_chair_back.global_position)
	var back_back_position: Vector3 = actor.to_local(back_chair_back.global_position)
	_expect(
		front_back_position.z < front_seat.z
		and back_back_position.z > back_seat.z,
		"Cafeteria chair backs must sit behind the employee on both sides of the table."
	)
	var front_back_mesh: BoxMesh = (front_chair_back as MeshInstance3D).mesh as BoxMesh
	_expect(
		front_back_mesh != null
		and absf(front_back_mesh.size.x - 0.58) < 0.01
		and absf(front_back_mesh.size.z - 0.12) < 0.01,
		"Cafeteria chair backs must retain their correct width and depth."
	)
	var front_facing: Vector3 = actor.call("get_workplace_facing_direction", 0)
	var back_facing: Vector3 = actor.call("get_workplace_facing_direction", 2)
	var front_table_direction: Vector3 = (
		actor.to_global(Vector3(-4.0, 0.0, 0.35)) - front_path.back()
	).normalized()
	var back_table_direction: Vector3 = (
		actor.to_global(Vector3(-4.0, 0.0, 0.35)) - back_path.back()
	).normalized()
	_expect(
		front_facing.dot(front_table_direction) > 0.99
		and back_facing.dot(back_table_direction) > 0.99,
		"Both cafeteria seat rows must continue facing their table."
	)
	actor.queue_free()


func _test_staff_housing() -> void:
	var actor: Node3D = _create_facility("staff_housing")
	var first_bed_path: Array[Vector3] = actor.call("get_workplace_path", 0)
	var last_bed_path: Array[Vector3] = actor.call("get_workplace_path", 7)
	var first_bed: Vector3 = actor.to_local(first_bed_path.back())
	var last_bed: Vector3 = actor.to_local(last_bed_path.back())
	_expect(
		first_bed.distance_to(Vector3(-5.15, 0.0, -2.75)) < 0.01
		and last_bed.distance_to(Vector3(5.15, 0.0, 4.25)) < 0.01,
		"Staff housing route marks must remain centered on all eight beds."
	)
	var first_exit: Array[Vector3] = actor.call(
		"get_exit_path_from",
		first_bed_path.back(),
		0
	)
	var last_exit: Array[Vector3] = actor.call(
		"get_exit_path_from",
		last_bed_path.back(),
		7
	)
	var inferred_first_exit: Array[Vector3] = actor.call(
		"get_exit_path_from",
		first_bed_path.back()
	)
	var inferred_last_exit: Array[Vector3] = actor.call(
		"get_exit_path_from",
		last_bed_path.back()
	)
	_expect(
		first_exit.size() >= 2
		and last_exit.size() >= 2
		and inferred_first_exit.size() >= 2
		and inferred_last_exit.size() >= 2
		and first_exit.front().distance_to(first_bed_path.back()) < 0.1
		and last_exit.front().distance_to(last_bed_path.back()) < 0.1
		and first_exit.back().distance_to(first_bed_path.front()) < 0.1
		and last_exit.back().distance_to(last_bed_path.front()) < 0.1
		and inferred_first_exit.front().distance_to(first_bed_path.back()) < 0.1
		and inferred_last_exit.front().distance_to(last_bed_path.back()) < 0.1,
		"Staff housing must retain explicit and inferred exit routes from occupied beds."
	)
	actor.queue_free()


func _test_star_bungalow() -> void:
	var actor: Node3D = _create_facility("star_bungalow")
	var interior: Node3D = actor.get_node("Interior") as Node3D
	_expect(
		interior.get_node_or_null("StarBedMattress") is MeshInstance3D
		and interior.get_node_or_null("StarBedPillow") is MeshInstance3D
		and interior.get_node_or_null("StarWardrobe") is MeshInstance3D
		and interior.get_node_or_null("StarLoungeChair") is MeshInstance3D
		and interior.get_node_or_null("StarBedsideLamp") is MeshInstance3D,
		"Star Bungalow must retain its private bedroom and furniture."
	)
	var route: Array[Vector3] = actor.call("get_workplace_path", 0)
	_expect(
		route.size() >= 4
		and actor.to_local(route.back()).distance_to(Vector3(0.0, 0.0, -1.3)) < 0.1,
		"Star Bungalow must retain a navigable route to its private bed."
	)
	# The single workplace mark is the private bed's arrival position.
	actor.queue_free()
