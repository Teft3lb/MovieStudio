extends "res://tests/smoke_test_base.gd"

const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55190427

	var profession_ids: Array[String] = PROFESSION_CATALOG_SCRIPT.get_profession_ids()
	_expect(
		profession_ids.size() == 20,
		"Skill profiles must exist for all 20 active professions."
	)

	for profession_id in profession_ids:
		_test_profession_profile(generator, rng, profession_id)

	_test_role_separation(generator, rng)
	_test_serialization_filter(generator, rng)

	_finish_test("CharacterSkillProfilesSmokeTest")


func _test_profession_profile(
	generator: Variant,
	rng: RandomNumberGenerator,
	profession_id: String
) -> void:
	var candidate: Variant = generator.call(
		"generate",
		rng,
		"SKILL-TEST-%s" % profession_id,
		profession_id
	)
	var expected_skill_ids: Array[String] = (
		PROFESSION_CATALOG_SCRIPT.get_profession_skill_ids(
			profession_id,
			candidate.specialization_id
		)
	)
	var available_specializations: Array[String] = (
		PROFESSION_CATALOG_SCRIPT.get_specialization_ids(profession_id)
	)
	for specialization_id in available_specializations:
		var specialized_skill_ids: Array[String] = (
			PROFESSION_CATALOG_SCRIPT.get_profession_skill_ids(
				profession_id,
				specialization_id
			)
		)
		var mapped_skill_id: String = (
			PROFESSION_CATALOG_SCRIPT.get_specialization_skill_id(
				profession_id,
				specialization_id
			)
		)
		_expect(
			specialized_skill_ids.size() >= 4
			and specialized_skill_ids.size() <= 8,
			"Every specialization must keep the profession within the 4–8 skill limit."
		)
		_expect(
			not mapped_skill_id.is_empty()
			and specialized_skill_ids.has(mapped_skill_id),
			"Every specialization must map to a skill in its profession profile."
		)

	var generated_skill_ids: Array[String] = []
	for skill_id in candidate.skills.keys():
		generated_skill_ids.append(str(skill_id))

	_expect(
		expected_skill_ids.size() >= 4 and expected_skill_ids.size() <= 8,
		"Every profession must have between four and eight relevant skills."
	)
	_expect(
		generated_skill_ids.size() == expected_skill_ids.size(),
		"Generated skill count must match the profession profile."
	)
	_expect(
		candidate.skills.has(candidate.get_primary_skill_id()),
		"Every generated character must have its primary profession skill."
	)

	expected_skill_ids.sort()
	generated_skill_ids.sort()
	_expect(
		generated_skill_ids == expected_skill_ids,
		"Generated characters must not receive unrelated profession skills."
	)

	for skill_id in expected_skill_ids:
		_expect(
			not PROFESSION_CATALOG_SCRIPT.get_skill_title(skill_id).is_empty(),
			"Every profile skill must have a localized title."
		)
		_expect(
			float(candidate.skills[skill_id]) >= 0.0
			and float(candidate.skills[skill_id]) <= 100.0,
			"Generated skill values must stay within 0–100."
		)

	var specialization_skill_id: String = (
		PROFESSION_CATALOG_SCRIPT.get_specialization_skill_id(
			profession_id,
			candidate.specialization_id
		)
	)
	if not specialization_skill_id.is_empty():
		_expect(
			candidate.skills.has(specialization_skill_id),
			"Generated specialization must add its mapped professional skill."
		)

	var restored: Variant = CHARACTER_DATA_SCRIPT.from_dict(candidate.to_dict())
	_expect(
		restored.skills == candidate.skills,
		"Profession-specific skills must survive CharacterData serialization."
	)
	_expect(
		restored.specialization_id == candidate.specialization_id,
		"Profession specialization must survive CharacterData serialization."
	)


func _test_role_separation(generator: Variant, rng: RandomNumberGenerator) -> void:
	var actor: Variant = generator.call("generate", rng, "SKILL-ACTOR", "actor")
	var chef: Variant = generator.call("generate", rng, "SKILL-CHEF", "chef")
	var cleaner: Variant = generator.call("generate", rng, "SKILL-CLEANER", "cleaner")
	var director: Variant = generator.call("generate", rng, "SKILL-DIRECTOR", "director")
	var screenwriter: Variant = generator.call(
		"generate", rng, "SKILL-WRITER", "screenwriter"
	)
	var editor: Variant = generator.call(
		"generate", rng, "SKILL-EDITOR", "film_editor"
	)

	_expect(
		actor.skills.has("acting")
		and actor.skills.has("improvisation")
		and actor.skills.has("diction")
		and not actor.skills.has("culinary")
		and not actor.skills.has("maintenance"),
		"Actors must have a detailed acting profile without service skills."
	)
	_expect(
		chef.skills.has("culinary")
		and chef.skills.has("menu_planning")
		and not chef.skills.has("acting")
		and not chef.skills.has("directing"),
		"Chefs must have culinary skills without creative-department skills."
	)
	_expect(
		cleaner.skills.has("hygiene")
		and cleaner.skills.has("maintenance")
		and not cleaner.skills.has("marketing")
		and not cleaner.skills.has("acting"),
		"Cleaners must have facility skills only."
	)
	_expect(
		director.skills.has("directing")
		and director.skills.has("visual_storytelling")
		and director.skills.has("actor_direction"),
		"Directors must have a detailed directing skill profile."
	)
	_expect(
		screenwriter.skills.has("story_structure")
		and screenwriter.skills.has("dialogue")
		and screenwriter.skills.has("character_development"),
		"Screenwriters must have a detailed writing skill profile."
	)
	_expect(
		editor.skills.has("editing")
		and editor.skills.has("visual_storytelling")
		and editor.skills.has("sound")
		and not editor.skills.has("acting"),
		"Film editors must have a focused post-production skill profile."
	)
	_expect(
		actor.skills.size() > cleaner.skills.size(),
		"Creative professions should retain greater skill depth than basic service roles."
	)


func _test_serialization_filter(generator: Variant, rng: RandomNumberGenerator) -> void:
	var actor: Variant = generator.call("generate", rng, "SKILL-FILTER-ACTOR", "actor")
	var payload: Dictionary = actor.to_dict()
	var source_skills: Variant = payload.get("skills", {})
	var injected_skills: Dictionary = {}
	if source_skills is Dictionary:
		injected_skills = source_skills.duplicate(true)
	injected_skills["culinary"] = 99.0
	injected_skills["security"] = 88.0
	payload["skills"] = injected_skills

	var restored: Variant = CHARACTER_DATA_SCRIPT.from_dict(payload)
	_expect(
		not restored.skills.has("culinary") and not restored.skills.has("security"),
		"CharacterData must discard skills outside the character's profession profile."
	)
	_expect(
		restored.skills.size() == actor.skills.size(),
		"Deserialization must preserve only the profession's defined skill set."
	)
