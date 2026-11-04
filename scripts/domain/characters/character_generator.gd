extends RefCounted
class_name CharacterGenerator

const CHARACTER_DATA_SCRIPT = preload("res://scripts/domain/characters/character_data.gd")
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)

const FIRST_NAMES: Array[String] = [
	"Arthur", "Evelyn", "Clara", "Walter", "Mabel",
	"Henry", "Iris", "Edwin", "Violet", "George",
	"Florence", "Oscar", "Beatrice", "Leonard", "Alice",
	"Felix", "Margot", "Julian", "Nora", "Victor",
	"Edith", "Theodore", "Sylvia", "Harold", "Cecilia",
]

const LAST_NAMES: Array[String] = [
	"Whitmore", "Bennett", "Hawthorne", "Marlowe", "Sinclair",
	"Calloway", "Sterling", "Waverly", "Bishop", "Holloway",
	"Mercer", "Ashford", "Prescott", "Langley", "Fairchild",
	"Redford", "Winslow", "Ellington", "Crawford", "Pemberton",
]

func generate(
	rng: RandomNumberGenerator,
	character_id: String,
	profession_id: String = "actor"
) -> RefCounted:
	var data: Variant = CHARACTER_DATA_SCRIPT.new()

	data.id = character_id
	data.first_name = FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)]
	data.last_name = LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]
	data.profession_id = PROFESSION_CATALOG_SCRIPT.normalize_profession_id(
		profession_id
	)
	var specialization_ids: Array[String] = (
		PROFESSION_CATALOG_SCRIPT.get_specialization_ids(data.profession_id)
	)
	if not specialization_ids.is_empty():
		data.specialization_id = specialization_ids[
			rng.randi_range(0, specialization_ids.size() - 1)
		]
	data.age = rng.randi_range(20, 64)

	var primary_skill_id: String = PROFESSION_CATALOG_SCRIPT.get_primary_skill_id(
		data.profession_id
	)
	var specialization_skill_id: String = (
		PROFESSION_CATALOG_SCRIPT.get_specialization_skill_id(
			data.profession_id,
			data.specialization_id
		)
	)
	var profession_skill_ids: Array[String] = (
		PROFESSION_CATALOG_SCRIPT.get_profession_skill_ids(
			data.profession_id,
			data.specialization_id
		)
	)
	var skills: Dictionary = {}
	for skill_id in profession_skill_ids:
		if skill_id == primary_skill_id:
			skills[skill_id] = rng.randf_range(56.0, 94.0)
		elif skill_id == specialization_skill_id:
			skills[skill_id] = rng.randf_range(58.0, 94.0)
		elif skill_id == "reliability":
			skills[skill_id] = rng.randf_range(38.0, 88.0)
		else:
			skills[skill_id] = rng.randf_range(18.0, 78.0)

	data.skills = skills

	data.experience = rng.randf_range(0.0, 48.0)
	if data.profession_id == "actor":
		data.popularity = rng.randf_range(0.0, 26.0)
	elif data.profession_id == "extra":
		data.popularity = rng.randf_range(0.0, 4.0)
	else:
		data.popularity = rng.randf_range(0.0, 9.0)

	var primary_skill_value: float = float(skills.get(primary_skill_id, 50.0))
	var base_salary: float = float(
		PROFESSION_CATALOG_SCRIPT.get_base_salary(data.profession_id)
	)
	data.daily_salary = roundi(base_salary * (0.7 + primary_skill_value / 100.0))

	var biography_options: Array = PROFESSION_CATALOG_SCRIPT.get_biographies(
		data.profession_id
	)
	data.biography = str(
		biography_options[rng.randi_range(0, biography_options.size() - 1)]
	)
	data.career_goal = PROFESSION_CATALOG_SCRIPT.get_career_goal(data.profession_id)

	var schedule: Dictionary = PROFESSION_CATALOG_SCRIPT.get_schedule(
		data.profession_id
	)
	data.shift_start_hour = int(schedule.get("shift_start_hour", 8))
	data.shift_end_hour = int(schedule.get("shift_end_hour", 17))
	data.break_start_hour = int(schedule.get("break_start_hour", 12))
	data.break_end_hour = int(schedule.get("break_end_hour", 13))

	data.personality = {
		"ambition": rng.randf_range(0.15, 0.95),
		"sociability": rng.randf_range(0.15, 0.95),
		"discipline": rng.randf_range(0.15, 0.95),
		"creativity": rng.randf_range(0.15, 0.95),
	}

	data.needs = {
		"energy": rng.randf_range(0.65, 1.0),
		"morale": rng.randf_range(0.55, 0.95),
		"stress": rng.randf_range(0.02, 0.28),
	}

	data.appearance = {
		"skin_tone": rng.randi_range(0, 5),
		"hair_color": rng.randi_range(0, 5),
		"outfit_color": rng.randi_range(0, 7),
		"hair_style": rng.randi_range(0, 2),
		"height_scale": snappedf(rng.randf_range(0.94, 1.06), 0.01),
		"head_scale": snappedf(rng.randf_range(0.94, 1.06), 0.01),
	}

	return data
