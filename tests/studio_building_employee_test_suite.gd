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
	_run_case(Callable(self, "_test_large_stage_exit_from_live_scene_position"))
	_run_case(Callable(self, "_test_profession_work_animation"))
	_run_case(Callable(self, "_test_employee_enters_and_leaves_workplace"))

func _test_large_stage_exit_from_live_scene_position() -> void:
	var stage_actor: Node3D = _create_building("sound_stage", 0.0, 3)
	var workplace_path: Array[Vector3] = stage_actor.call(
		"get_workplace_path",
		0
	)
	var scene_position: Vector3 = stage_actor.call(
		"get_scene_mark",
		0,
		"shooting",
		0
	)
	var dynamic_exit: Array[Vector3] = stage_actor.call(
		"get_exit_path_from",
		scene_position,
		0
	)
	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	var employee_generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 773312
	var employee: Variant = employee_generator.call(
		"generate",
		rng,
		"EMP-LIVE-EXIT",
		"actor"
	)
	var character_actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(character_actor)
	var empty_route: Array[Vector3] = []
	character_actor.call("setup", employee, empty_route, clock, 1.0)
	character_actor.call(
		"assign_workplace_route",
		"BLD-LARGE-STAGE",
		workplace_path,
		"actor",
		workplace_path
	)
	character_actor.global_position = scene_position
	character_actor.call("leave_workplace", dynamic_exit)
	var active_exit: Array[Vector3] = character_actor.get(
		"_workplace_path"
	)
	_expect(
		dynamic_exit.size() >= 2
		and active_exit.size() >= 2
		and active_exit.front().distance_to(scene_position) < 0.1
		and active_exit.back().distance_to(workplace_path.front()) < 0.1
		and bool(character_actor.call("is_leaving_workplace")),
		"An employee leaving a large sound stage from a live scene mark must follow a freshly calculated route from the current position to the real entrance."
	)
	character_actor.free()
	clock.free()

func _test_profession_work_animation() -> void:
	var visual: Node3D = CHARACTER_VISUAL_SCRIPT.new()
	root.add_child(visual)
	visual.call("setup", {"appearance": {}})
	visual.call("set_working", true, "screenwriter")
	visual.call("advance_simulation", 0.5)
	_expect(
		bool(visual.call("is_working")),
		"CharacterVisual must expose an active working animation state."
	)
	visual.call("set_working", true, "film_editor")
	visual.call("advance_simulation", 0.5)
	var left_arm: Node3D = visual.get_node("BodyRoot/LeftArmPivot") as Node3D
	_expect(
		left_arm.rotation.x < -0.3,
		"Film editors must use a forward typing pose at their editing workstation."
	)
	visual.call("set_walking", true)
	_expect(
		not bool(visual.call("is_working")),
		"Walking animation must replace the working animation."
	)
	visual.call("set_carrying_prop", true)
	visual.call("set_walking", true)
	visual.call("advance_simulation", 0.5)
	var carried_case: Node3D = visual.get_node(
		"BodyRoot/CarriedProp"
	) as Node3D
	var carrying_arm: Node3D = visual.get_node(
		"BodyRoot/LeftArmPivot"
	) as Node3D
	_expect(
		carried_case.visible
		and carried_case.get_node_or_null("PropTransportCase") != null
		and carrying_arm.rotation.x > 0.5,
		"Technicians must visibly carry a transport case while walking."
	)
	visual.call("set_carrying_prop", false)
	_expect(
		not carried_case.visible,
		"The transport case must disappear when the prop is installed or stored."
	)
	visual.call("set_performance_action", "placing_set_piece")
	visual.call("advance_simulation", 0.5)
	_expect(
		carrying_arm.rotation.x > 0.5,
		"The installation pose must reach forward toward the set piece."
	)

func _test_employee_enters_and_leaves_workplace() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 912345
	var employee: Variant = generator.call(
		"generate",
		rng,
		"EMP-INTERIOR-ROUTE",
		"screenwriter"
	)

	var building: Node3D = _create_building("script_department", 0.0)
	var route: Array[Vector3] = building.call(
		"get_workplace_path",
		0
	)

	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	var empty_waypoints: Array[Vector3] = []
	actor.call("setup", employee, empty_waypoints, clock, 5.0)
	actor.call(
		"assign_workplace_route",
		"BLD-INTERIOR-ROUTE",
		route,
		"screenwriter"
	)

	for _step in range(12):
		actor.call("_process", 10.0)

	_expect(
		bool(actor.call("is_at_workplace")),
		"An employee must reach the final interior workstation."
	)
	_expect(
		bool(actor.call("is_work_animation_active")),
		"An employee must switch to a profession-specific work animation on arrival."
	)

	actor.call("leave_workplace")
	for _step in range(12):
		actor.call("_process", 10.0)

	_expect(
		str(actor.call("get_workplace_building_id")).is_empty(),
		"An employee must clear the workplace assignment after exiting."
	)
	_expect(
		actor.global_position.is_equal_approx(route[0]),
		"An employee must leave through the entrance rather than disappear inside."
	)
	_expect(
		not bool(actor.call("is_work_animation_active")),
		"An employee must stop the work animation after leaving."
	)
