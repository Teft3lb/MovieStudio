extends "res://tests/smoke_test_base.gd"

const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const SCRIPT_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/script_department/script_generator.gd"
)
const FILM_SCRIPT_DATA_SCRIPT = preload(
	"res://scripts/domain/script_department/film_script_data.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var writer: Variant = _create_writer()
	var generator: RefCounted = SCRIPT_GENERATOR_SCRIPT.new()

	_test_requested_script_structure(generator, writer)
	_test_deterministic_generation(generator, writer)
	_test_skill_influence(generator, writer)
	_test_invalid_writer(generator)

	_finish_test("ScriptGeneratorSmokeTest")


func _create_writer() -> Variant:
	var character_generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 731905
	return character_generator.call(
		"generate",
		rng,
		"WRITER-SMOKE-TEST",
		"screenwriter"
	)


func _test_requested_script_structure(
	generator: Variant,
	writer: Variant
) -> void:
	var script: Variant = generator.call(
		"generate",
		writer,
		"mystery",
		11,
		4,
		90125,
		"SCR-SMOKE-01"
	)
	_expect(script != null, "A valid screenwriter must generate a script.")
	_expect(script.scene_count == 11, "Generated script must use the requested scene count.")
	_expect(script.role_count == 4, "Generated script must use the requested role count.")
	_expect(script.scenes.size() == 11, "Script data must contain every requested scene.")
	_expect(script.cast.size() == 4, "Script data must contain every requested role.")
	_expect(
		script.potential_score >= 0 and script.potential_score <= 100,
		"Potential score must stay within 0–100."
	)
	_expect(
		script.potential_stars >= 1 and script.potential_stars <= 5,
		"Potential rating must stay within one to five stars."
	)
	_expect(
		script.popularity_modifier >= 0.8
		and script.popularity_modifier <= 1.2,
		"Potential popularity modifier must remain bounded."
	)
	_expect(not str(script.title).is_empty(), "Generated script must have a title.")
	_expect(not str(script.logline).is_empty(), "Generated script must have a logline.")

	for scene in script.scenes:
		_expect(scene.has("scene_number"), "Each scene must have a sequence number.")
		_expect(scene.has("beat"), "Each scene must have a dramatic beat.")
		_expect(scene.has("location"), "Each scene must have a location.")
		_expect(scene.has("action"), "Each scene must have an action.")
		_expect(scene.has("dialogue"), "Each scene must have dialogue.")
		var scene_characters: Array = scene.get("characters", [])
		_expect(
			scene_characters.size() >= 1,
			"Each generated scene must feature at least one character."
		)
		var dialogue: String = str(scene.get("dialogue", ""))
		var speaker_separator: int = dialogue.find(":")
		_expect(speaker_separator > 0, "Every scene must identify its dialogue speaker.")
		var speaker_name: String = dialogue.substr(
			0,
			speaker_separator
		).strip_edges()
		_expect(
			scene_characters.has(speaker_name),
			"The speaking character must be present in the generated scene."
		)


func _test_deterministic_generation(
	generator: Variant,
	writer: Variant
) -> void:
	var first: Variant = generator.call(
		"generate", writer, "adventure", 8, 3, 44321, "SCR-DETERMINISTIC"
	)
	var second: Variant = generator.call(
		"generate", writer, "adventure", 8, 3, 44321, "SCR-DETERMINISTIC"
	)
	_expect(
		first.to_dict() == second.to_dict(),
		"Identical writer data and seed must produce identical scripts."
	)

	var restored: Variant = FILM_SCRIPT_DATA_SCRIPT.from_dict(first.to_dict())
	_expect(
		restored.to_dict() == first.to_dict(),
		"Generated script data must survive serialization."
	)


func _test_skill_influence(
	generator: Variant,
	writer: Variant
) -> void:
	var low_payload: Dictionary = writer.to_dict()
	var low_source_skills: Variant = low_payload.get("skills", {})
	var low_skills: Dictionary = {}
	if low_source_skills is Dictionary:
		low_skills = low_source_skills.duplicate(true)
	for skill_id in ["writing", "story_structure", "dialogue", "creativity", "research"]:
		low_skills[skill_id] = 10.0
	low_payload["skills"] = low_skills
	var low_writer: Variant = CHARACTER_DATA_SCRIPT.from_dict(low_payload)

	var high_payload: Dictionary = writer.to_dict()
	var high_source_skills: Variant = high_payload.get("skills", {})
	var high_skills: Dictionary = {}
	if high_source_skills is Dictionary:
		high_skills = high_source_skills.duplicate(true)
	for skill_id in ["writing", "story_structure", "dialogue", "creativity", "research"]:
		high_skills[skill_id] = 100.0
	high_payload["skills"] = high_skills
	var high_writer: Variant = CHARACTER_DATA_SCRIPT.from_dict(high_payload)

	var low_script: Variant = generator.call(
		"generate", low_writer, "drama", 9, 3, 55221, "SCR-LOW"
	)
	var high_script: Variant = generator.call(
		"generate", high_writer, "drama", 9, 3, 55221, "SCR-HIGH"
	)
	_expect(
		high_script.potential_score > low_script.potential_score,
		"Stronger screenwriting skills must improve the potential success score."
	)
	_expect(
		high_script.popularity_modifier > low_script.popularity_modifier,
		"Higher-rated scripts must carry a stronger future popularity modifier."
	)


func _test_invalid_writer(generator: Variant) -> void:
	var character_generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5511
	var actor: Variant = character_generator.call(
		"generate", rng, "ACTOR-SHOULD-NOT-WRITE", "actor"
	)
	var invalid_result: Variant = generator.call(
		"generate", actor, "drama", 6, 2, 77, "SCR-INVALID"
	)
	_expect(
		invalid_result == null,
		"Only employees with the screenwriter profession may generate scripts."
	)
