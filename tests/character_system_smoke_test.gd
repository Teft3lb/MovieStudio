extends SceneTree

const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const GAME_CLOCK_SCRIPT = preload("res://scripts/core/game_clock.gd")


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
