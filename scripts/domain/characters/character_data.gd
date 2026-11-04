extends RefCounted
class_name CharacterData

const SCHEMA_VERSION: int = 2

const PROFESSION_TITLES: Dictionary = {
	"actor": "Актёр",
	"director": "Режиссёр",
	"screenwriter": "Сценарист",
	"camera_operator": "Оператор",
	"producer": "Продюсер",
	"technician": "Техник",
}

const PRIMARY_SKILLS: Dictionary = {
	"actor": "acting",
	"director": "directing",
	"screenwriter": "writing",
	"camera_operator": "camera_work",
	"producer": "management",
	"technician": "technical",
}

const SKILL_TITLES: Dictionary = {
	"acting": "Актёрское мастерство",
	"directing": "Режиссура",
	"writing": "Сценарное мастерство",
	"camera_work": "Работа с камерой",
	"management": "Управление",
	"technical": "Технические навыки",
	"creativity": "Креативность",
	"reliability": "Надёжность",
}

var id: String = ""
var first_name: String = ""
var last_name: String = ""
var profession_id: String = "actor"
var age: int = 30

var experience: float = 0.0
var popularity: float = 0.0
var daily_salary: int = 0
var biography: String = ""
var career_goal: String = ""

var shift_start_hour: int = 8
var shift_end_hour: int = 17
var break_start_hour: int = 12
var break_end_hour: int = 13
var work_state: String = "working"
var current_task: String = ""

var skills: Dictionary = {
	"acting": 0.0,
	"directing": 0.0,
	"writing": 0.0,
	"camera_work": 0.0,
	"management": 0.0,
	"technical": 0.0,
	"creativity": 0.0,
	"reliability": 0.0,
}

var personality: Dictionary = {
	"ambition": 0.5,
	"sociability": 0.5,
	"discipline": 0.5,
	"creativity": 0.5,
}

var needs: Dictionary = {
	"energy": 1.0,
	"morale": 0.75,
	"stress": 0.1,
}

var appearance: Dictionary = {
	"skin_tone": 0,
	"hair_color": 0,
	"outfit_color": 0,
	"hair_style": 0,
	"height_scale": 1.0,
	"head_scale": 1.0,
}


func get_full_name() -> String:
	return "%s %s" % [first_name, last_name]


func get_profession_title() -> String:
	return str(PROFESSION_TITLES.get(profession_id, "Сотрудник"))


func get_primary_skill_id() -> String:
	return str(PRIMARY_SKILLS.get(profession_id, "reliability"))


func get_primary_skill_title() -> String:
	return str(SKILL_TITLES.get(get_primary_skill_id(), "Основной навык"))


func get_primary_skill_value() -> float:
	return float(skills.get(get_primary_skill_id(), 0.0))


func get_work_state_title() -> String:
	match work_state:
		"working":
			return "На смене"
		"break":
			return "Перерыв"
		"resting":
			return "Восстанавливается"
		"off_duty":
			return "Вне смены"
		_:
			return "Неизвестно"


func get_ui_summary() -> Dictionary:
	return {
		"id": id,
		"full_name": get_full_name(),
		"profession_title": get_profession_title(),
		"age": age,
		"experience": experience,
		"popularity": popularity,
		"current_task": current_task,
		"work_state_title": get_work_state_title(),
		"energy": roundi(float(needs.get("energy", 1.0)) * 100.0),
		"morale": roundi(float(needs.get("morale", 0.75)) * 100.0),
		"primary_skill_title": get_primary_skill_title(),
		"primary_skill_value": roundi(get_primary_skill_value()),
		"daily_salary": daily_salary,
	}


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"profession_id": profession_id,
		"age": age,
		"experience": experience,
		"popularity": popularity,
		"daily_salary": daily_salary,
		"biography": biography,
		"career_goal": career_goal,
		"shift_start_hour": shift_start_hour,
		"shift_end_hour": shift_end_hour,
		"break_start_hour": break_start_hour,
		"break_end_hour": break_end_hour,
		"work_state": work_state,
		"current_task": current_task,
		"skills": skills.duplicate(true),
		"personality": personality.duplicate(true),
		"needs": needs.duplicate(true),
		"appearance": appearance.duplicate(true),
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	# Load this script resource directly instead of resolving its class_name.
	# This keeps the factory usable in headless --script runs before the
	# editor's global script-class cache has been generated.
	var result: Variant = load("res://scripts/domain/characters/character_data.gd").new()

	result.id = str(payload.get("id", ""))
	result.first_name = str(payload.get("first_name", ""))
	result.last_name = str(payload.get("last_name", ""))
	result.profession_id = str(payload.get("profession_id", "actor"))
	result.age = maxi(int(payload.get("age", 30)), 18)
	result.experience = clampf(float(payload.get("experience", 0.0)), 0.0, 100.0)
	result.popularity = clampf(float(payload.get("popularity", 0.0)), 0.0, 100.0)
	result.daily_salary = maxi(int(payload.get("daily_salary", 0)), 0)
	result.biography = str(payload.get("biography", ""))
	result.career_goal = str(payload.get("career_goal", ""))
	result.shift_start_hour = clampi(int(payload.get("shift_start_hour", 8)), 0, 23)
	result.shift_end_hour = clampi(int(payload.get("shift_end_hour", 17)), 1, 24)
	result.break_start_hour = clampi(int(payload.get("break_start_hour", 12)), 0, 23)
	result.break_end_hour = clampi(int(payload.get("break_end_hour", 13)), 1, 24)
	result.work_state = str(payload.get("work_state", "working"))
	result.current_task = str(payload.get("current_task", ""))

	var raw_skills: Variant = payload.get("skills", {})
	if raw_skills is Dictionary:
		result.skills = raw_skills.duplicate(true)

	var raw_personality: Variant = payload.get("personality", {})
	if raw_personality is Dictionary:
		result.personality = raw_personality.duplicate(true)

	var raw_needs: Variant = payload.get("needs", {})
	if raw_needs is Dictionary:
		result.needs = raw_needs.duplicate(true)

	var raw_appearance: Variant = payload.get("appearance", {})
	if raw_appearance is Dictionary:
		result.appearance = raw_appearance.duplicate(true)

	return result
