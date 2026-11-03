extends SceneTree

const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const GAME_CLOCK_SCRIPT = preload("res://scripts/core/game_clock.gd")
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)


func _initialize() -> void:
	_test_simulation_speed()

	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 123456789
	var first: Variant = generator.call("generate", rng_a, "TEST-0001", "actor")

	assert(first.id == "TEST-0001", "Generated character ID must be preserved.")
	assert(first.first_name != "", "Generated character must have a first name.")
	assert(first.last_name != "", "Generated character must have a last name.")
	assert(first.skills.has("acting"), "Actor must have an acting skill.")
	assert(first.appearance.has("skin_tone"), "Character must have appearance data.")

	var serialized: Dictionary = first.call("to_dict")
	var restored: Variant = CHARACTER_DATA_SCRIPT.from_dict(serialized)

	assert(restored.id == first.id, "Serialization must preserve the character ID.")
	assert(
		restored.get_full_name() == first.get_full_name(),
		"Serialization must preserve the character name."
	)
	assert(
		restored.appearance == first.appearance,
		"Serialization must preserve appearance parameters."
	)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 123456789
	var repeated: Variant = generator.call("generate", rng_b, "TEST-0001", "actor")

	assert(
		repeated.call("to_dict") == first.call("to_dict"),
		"Generation with the same seed and inputs must be deterministic."
	)

	_test_character_movement_scaling(first)

	print("CharacterSystemSmokeTest: PASS")
	quit(0)


func _test_simulation_speed() -> void:
	var clock: Node = GAME_CLOCK_SCRIPT.new()

	clock.call("set_speed_mode", 0)
	assert(
		is_zero_approx(float(clock.call("get_simulation_delta", 0.25))),
		"Paused simulation must produce zero simulation delta."
	)

	clock.call("set_speed_mode", 1)
	assert(
		is_equal_approx(float(clock.call("get_simulation_delta", 0.25)), 0.25),
		"Normal speed must preserve real delta."
	)

	clock.call("set_speed_mode", 2)
	assert(
		is_equal_approx(float(clock.call("get_simulation_delta", 0.25)), 0.75),
		"3x speed must triple simulation delta."
	)

	clock.call("set_speed_mode", 3)
	assert(
		is_equal_approx(float(clock.call("get_simulation_delta", 0.25)), 1.5),
		"6x speed must multiply simulation delta by six."
	)

	clock.free()


func _test_character_movement_scaling(character_data: Variant) -> void:
	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)

	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)

	var route: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(100.0, 0.0, 0.0),
	]
	actor.call("setup", character_data, route, clock, 1.0)

	clock.call("set_speed_mode", 0)
	var previous_position: Vector3 = actor.position
	actor.call("_process", 0.25)
	assert(
		actor.position.is_equal_approx(previous_position),
		"Character movement must stop while simulation is paused."
	)

	clock.call("set_speed_mode", 1)
	previous_position = actor.position
	actor.call("_process", 0.25)
	assert(
		is_equal_approx(actor.position.distance_to(previous_position), 0.25),
		"Character movement must use normal simulation delta at 1x."
	)

	clock.call("set_speed_mode", 2)
	previous_position = actor.position
	actor.call("_process", 0.25)
	assert(
		is_equal_approx(actor.position.distance_to(previous_position), 0.75),
		"Character movement must triple at 3x."
	)

	clock.call("set_speed_mode", 3)
	previous_position = actor.position
	actor.call("_process", 0.25)
	assert(
		is_equal_approx(actor.position.distance_to(previous_position), 1.5),
		"Character movement must multiply by six at 6x."
	)

	actor.free()
	clock.free()
