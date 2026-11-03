extends RefCounted
class_name CharacterGenerator

const CHARACTER_DATA_SCRIPT = preload("res://scripts/domain/characters/character_data.gd")

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

const PRIMARY_SKILL_BY_PROFESSION: Dictionary = {
	"actor": "acting",
	"director": "directing",
	"screenwriter": "writing",
	"camera_operator": "camera_work",
	"producer": "management",
	"technician": "technical",
}

const BASE_SALARIES: Dictionary = {
	"actor": 85,
	"director": 145,
	"screenwriter": 105,
	"camera_operator": 90,
	"producer": 135,
	"technician": 70,
}


func generate(
	rng: RandomNumberGenerator,
	character_id: String,
	profession_id: String = "actor"
) -> RefCounted:
	var data: Variant = CHARACTER_DATA_SCRIPT.new()

	data.id = character_id
	data.first_name = FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)]
	data.last_name = LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]
	data.profession_id = profession_id
	data.age = rng.randi_range(20, 64)

	var skills: Dictionary = {
		"acting": rng.randf_range(18.0, 68.0),
		"directing": rng.randf_range(18.0, 68.0),
		"writing": rng.randf_range(18.0, 68.0),
		"camera_work": rng.randf_range(18.0, 68.0),
		"management": rng.randf_range(18.0, 68.0),
		"technical": rng.randf_range(18.0, 68.0),
		"creativity": rng.randf_range(25.0, 80.0),
		"reliability": rng.randf_range(30.0, 85.0),
	}

	var primary_skill_id: String = str(
		PRIMARY_SKILL_BY_PROFESSION.get(profession_id, "reliability")
	)
	skills[primary_skill_id] = rng.randf_range(56.0, 94.0)
	data.skills = skills

	data.experience = rng.randf_range(0.0, 48.0)
	if profession_id == "actor":
		data.popularity = rng.randf_range(0.0, 26.0)
	else:
		data.popularity = rng.randf_range(0.0, 9.0)

	var primary_skill_value: float = float(skills.get(primary_skill_id, 50.0))
	var base_salary: float = float(BASE_SALARIES.get(profession_id, 70))
	data.daily_salary = roundi(base_salary * (0.7 + primary_skill_value / 100.0))

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
