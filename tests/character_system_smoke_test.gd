extends SceneTree

const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)


func _initialize() -> void:
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
	var restored: Variant = CHARACTER_DATA_SCRIPT.call("from_dict", serialized)

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
