extends "res://tests/studio_building_interior_test_suite_base.gd"

const CHARACTER_VISUAL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_visual.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const GAME_CLOCK_SCRIPT = preload(
	"res://scripts/core/game_clock.gd"
)


func _run_tests() -> void:
	_run_case(Callable(self, "_test_fitness_center_interior"))
	_run_case(Callable(self, "_test_studio_lounge_interior"))
	_run_case(Callable(self, "_test_cafeteria_seating_layout"))
	_run_case(Callable(self, "_test_staff_housing_beds"))
	_run_case(Callable(self, "_test_rotated_housing_sleep_alignment"))
	_run_case(Callable(self, "_test_star_bungalow_interior"))
	_run_case(Callable(self, "_test_facility_poses"))

func _test_fitness_center_interior() -> void:
	var actor: Node3D = _create_building("fitness_center", 0.0)
	_expect(
		actor.get_node_or_null("Interior/FitnessFloor") != null
		and actor.get_node_or_null("Interior/FitnessMirror_0") != null
		and actor.get_node_or_null("Interior/FitnessTreadmillBase_0") != null
		and actor.get_node_or_null("Interior/FitnessTreadmillConsole_3") != null,
		"Fitness center must contain mirrors and four distinct cardio stations."
	)
	for slot_index in range(4):
		var route: Array[Vector3] = actor.call(
			"get_workplace_path",
			slot_index
		)
		_expect(
			route.size() >= 4,
			"Every fitness station must have a complete entrance and interior route."
		)

func _test_studio_lounge_interior() -> void:
	var actor: Node3D = _create_building("studio_lounge", 0.0)
	_expect(
		actor.get_node_or_null("Interior/LoungeCoffeeCounter") != null
		and actor.get_node_or_null("Interior/LoungeCoffeeTable") != null
		and actor.get_node_or_null("Interior/LoungeSofaBaseLeft") != null
		and actor.get_node_or_null("Interior/LoungeSofaBaseRight") != null,
		"Studio lounge must contain a coffee area, a shared table and two distinct seating zones."
	)
	var first_route: Array[Vector3] = actor.call("get_workplace_path", 0)
	var last_route: Array[Vector3] = actor.call("get_workplace_path", 5)
	_expect(
		first_route.size() >= 4
		and last_route.size() >= 4
		and first_route.back().distance_to(last_route.back()) > 3.0,
		"Studio lounge must expose six separated social positions with navigable routes."
	)

func _test_cafeteria_seating_layout() -> void:
	var actor: Node3D = _create_building("cafeteria", 0.0)
	var first_front_path: Array[Vector3] = actor.call("get_workplace_path", 0)
	var second_front_path: Array[Vector3] = actor.call("get_workplace_path", 1)
	var first_back_path: Array[Vector3] = actor.call("get_workplace_path", 2)
	var second_back_path: Array[Vector3] = actor.call("get_workplace_path", 3)
	var first_front_seat: Vector3 = actor.to_local(first_front_path.back())
	var second_front_seat: Vector3 = actor.to_local(second_front_path.back())
	var first_back_seat: Vector3 = actor.to_local(first_back_path.back())
	var second_back_seat: Vector3 = actor.to_local(second_back_path.back())
	_expect(
		absf(first_front_seat.z - second_front_seat.z) < 0.01
		and absf(first_back_seat.z - second_back_seat.z) < 0.01
		and first_front_seat.z < first_back_seat.z
		and absf(first_front_seat.x - second_front_seat.x) > 0.8,
		"Cafeteria must place two chairs along each long side of the table instead of clustering seats at the corners."
	)
	var front_chair_back: Node3D = actor.get_node(
		"Interior/CafeteriaChairBack_0_0"
	) as Node3D
	var back_chair_back: Node3D = actor.get_node(
		"Interior/CafeteriaChairBack_0_2"
	) as Node3D
	var front_back_position: Vector3 = actor.to_local(
		front_chair_back.global_position
	)
	var back_back_position: Vector3 = actor.to_local(
		back_chair_back.global_position
	)
	_expect(
		front_back_position.z < first_front_seat.z
		and back_back_position.z > first_back_seat.z,
		"Cafeteria chair backs must sit behind the employee on both sides of the table."
	)
	var front_back_mesh: BoxMesh = (front_chair_back as MeshInstance3D).mesh as BoxMesh
	_expect(
		front_back_mesh != null
		and absf(front_back_mesh.size.x - 0.58) < 0.01
		and absf(front_back_mesh.size.z - 0.12) < 0.01,
		"Chair backs must be wide across the seat and thin front-to-back, not laid across the seat center."
	)
	var front_facing: Vector3 = actor.call("get_workplace_facing_direction", 0)
	var back_facing: Vector3 = actor.call("get_workplace_facing_direction", 2)
	var front_table_direction: Vector3 = (
		actor.to_global(Vector3(-4.0, 0.0, 0.35)) - first_front_path.back()
	).normalized()
	var back_table_direction: Vector3 = (
		actor.to_global(Vector3(-4.0, 0.0, 0.35)) - first_back_path.back()
	).normalized()
	_expect(
		front_facing.dot(front_table_direction) > 0.99
		and back_facing.dot(back_table_direction) > 0.99,
		"Both cafeteria seat rows must face the table in building-local orientation."
	)

func _test_staff_housing_beds() -> void:
	var actor: Node3D = _create_building("staff_housing", 0.0)
	var first_bed_path: Array[Vector3] = actor.call("get_workplace_path", 0)
	var last_bed_path: Array[Vector3] = actor.call("get_workplace_path", 7)
	var first_bed: Vector3 = actor.to_local(first_bed_path.back())
	var last_bed: Vector3 = actor.to_local(last_bed_path.back())
	_expect(
		first_bed.distance_to(Vector3(-5.15, 0.0, -2.75)) < 0.01
		and last_bed.distance_to(Vector3(5.15, 0.0, 4.25)) < 0.01,
		"Staff housing slots must align with the centers of the eight beds without arbitrary lateral offsets."
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
		"Employees must receive valid exit routes from occupied beds, including when the caller omits the bed slot."
	)

func _test_rotated_housing_sleep_alignment() -> void:
	var housing_actor: Node3D = _create_building("staff_housing", 90.0)
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 773311
	var employee: Variant = generator.call(
		"generate",
		rng,
		"EMP-ROTATED-HOUSING",
		"actor"
	)
	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	var all_beds_aligned: bool = true
	for slot_index in range(8):
		var route: Array[Vector3] = housing_actor.call(
			"get_workplace_path",
			slot_index
		)
		var facing_direction: Vector3 = housing_actor.call(
			"get_workplace_facing_direction",
			slot_index
		)
		var expected_direction: Vector3 = (
			housing_actor.global_basis * Vector3.FORWARD
		).normalized()
		if (
			facing_direction.length_squared() <= 0.9
			or facing_direction.dot(expected_direction) <= 0.99
		):
			all_beds_aligned = false
			continue
		var character_actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
		root.add_child(character_actor)
		var empty_route: Array[Vector3] = []
		character_actor.call("setup", employee, empty_route, clock, 1.0)
		character_actor.call(
			"assign_facility_route",
			"BLD-ROTATED-HOUSING",
			"staff_housing",
			slot_index,
			route,
			"sleeping",
			facing_direction
		)
		character_actor.call("snap_to_facility")
		var character_forward: Vector3 = (
			-character_actor.global_basis.z
		).normalized()
		var visual: Node3D = character_actor.get_node(
			"CharacterVisual"
		) as Node3D
		var body_root: Node3D = visual.get_node("BodyRoot") as Node3D
		var body_axis: Vector3 = (
			body_root.global_basis * Vector3.UP
		).normalized()
		if (
			character_forward.dot(facing_direction) <= 0.99
			or body_axis.dot(facing_direction) <= 0.99
			or not is_equal_approx(body_root.rotation.x, -PI * 0.5)
		):
			all_beds_aligned = false
		character_actor.free()
	_expect(
		all_beds_aligned,
		"Every staff housing bed must align the actor's sleeping body axis with the mattress, including when the building is rotated."
	)
	clock.free()

func _test_star_bungalow_interior() -> void:
	var actor: Node3D = _create_building("star_bungalow", 0.0)
	_expect(
		actor.get_node_or_null("Interior/StarBedMattress") != null
		and actor.get_node_or_null("Interior/StarBedPillow") != null,
		"Star bungalow must contain a private bed and pillow."
	)
	_expect(
		actor.get_node_or_null("Interior/StarWardrobe") != null
		and actor.get_node_or_null("Interior/StarLoungeChair") != null,
		"Star bungalow must contain private furniture."
	)
	var route: Array[Vector3] = actor.call("get_workplace_path", 0)
	var interior: Node3D = actor.get_node("Interior") as Node3D
	var local_bed_arrival: Vector3 = interior.to_local(route.back())
	_expect(
		route.size() >= 4
		and local_bed_arrival.distance_to(Vector3(0.0, 0.0, -1.3)) < 0.1,
		"Star bungalow must expose a navigable route that ends on its private bed."
	)

func _test_facility_poses() -> void:
	var visual: Node3D = CHARACTER_VISUAL_SCRIPT.new()
	root.add_child(visual)
	visual.call("setup", {"appearance": {}})
	visual.call("set_performance_action", "eating")
	var body_root: Node3D = visual.get_node("BodyRoot") as Node3D
	var left_leg: Node3D = visual.get_node("BodyRoot/LeftLegPivot") as Node3D
	var left_arm: Node3D = visual.get_node("BodyRoot/LeftArmPivot") as Node3D
	var minimum_arm_angle: float = INF
	var maximum_arm_angle: float = -INF
	for _step in range(12):
		visual.call("advance_simulation", 0.1)
		minimum_arm_angle = minf(minimum_arm_angle, left_arm.rotation.x)
		maximum_arm_angle = maxf(maximum_arm_angle, left_arm.rotation.x)
	_expect(
		body_root.position.y < -0.2
		and left_leg.rotation.x > 0.65,
		"Eating must lower the torso and bend the legs into a seated chair pose."
	)
	_expect(
		maximum_arm_angle - minimum_arm_angle > 0.08,
		"Eating must animate alternating hand movement instead of holding a static pose."
	)
	visual.call("set_performance_action", "training")
	var training_arm_min: float = INF
	var training_arm_max: float = -INF
	for _step in range(12):
		visual.call("advance_simulation", 0.1)
		training_arm_min = minf(training_arm_min, left_arm.rotation.x)
		training_arm_max = maxf(training_arm_max, left_arm.rotation.x)
	_expect(
		training_arm_max - training_arm_min > 0.35,
		"Fitness training must animate repeated exercise movement instead of a static idle pose."
	)
	visual.call("set_performance_action", "socializing")
	var social_arm_min: float = INF
	var social_arm_max: float = -INF
	for _step in range(12):
		visual.call("advance_simulation", 0.1)
		social_arm_min = minf(social_arm_min, left_arm.rotation.x)
		social_arm_max = maxf(social_arm_max, left_arm.rotation.x)
	_expect(
		social_arm_max - social_arm_min > 0.2,
		"Studio lounge socializing must use a visible conversational gesture."
	)
	visual.call("set_performance_action", "sleeping")
	visual.call("advance_simulation", 0.25)
	_expect(
		absf(body_root.rotation.x + PI * 0.5) < 0.1
		and body_root.position.y > 0.5
		and body_root.scale.y < 0.9,
		"Sleeping must place a scaled-down character horizontally on the bed with subtle breathing."
	)
	var left_knee: Node3D = visual.get_node(
		"BodyRoot/LeftLegPivot/LeftKneePivot"
	) as Node3D
	visual.call("set_performance_action", "")
	visual.call("set_working", true)
	visual.call("advance_simulation", 0.25)
	_expect(
		absf(left_knee.rotation.x) < 0.01,
		"After leaving the cafeteria, normal work must reset the seated knee bend."
	)
	visual.free()
