extends RefCounted
class_name CharacterData

const SCHEMA_VERSION: int = 8
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)

var id: String = ""
var first_name: String = ""
var last_name: String = ""
var profession_id: String = "actor"
var specialization_id: String = ""
var age: int = 30
var age_days: int = 0

var experience: float = 0.0
var popularity: float = 0.0
var physical_fitness: float = 50.0
var relationships: Dictionary = {}
var daily_salary: int = 0
var biography: String = ""
var career_goal: String = ""

var shift_start_hour: int = 8
var shift_end_hour: int = 17
var break_start_hour: int = 12
var break_end_hour: int = 13
var work_state: String = "working"
var current_task: String = ""

var skills: Dictionary = {}
var skill_xp: Dictionary = {}
var skill_caps: Dictionary = {}
var growth_points_total: float = 0.0
var growth_points_remaining: float = 0.0

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
	return PROFESSION_CATALOG_SCRIPT.get_profession_title(profession_id)


func get_specialization_title() -> String:
	return PROFESSION_CATALOG_SCRIPT.get_specialization_title(
		profession_id,
		specialization_id
	)


func get_department_title() -> String:
	return PROFESSION_CATALOG_SCRIPT.get_department_title_for_profession(profession_id)


func get_primary_skill_id() -> String:
	return PROFESSION_CATALOG_SCRIPT.get_primary_skill_id(profession_id)


func get_primary_skill_title() -> String:
	return PROFESSION_CATALOG_SCRIPT.get_primary_skill_title(profession_id)


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
		"physical_fitness": physical_fitness,
		"current_task": current_task,
		"work_state_title": get_work_state_title(),
		"energy": roundi(float(needs.get("energy", 1.0)) * 100.0),
		"morale": roundi(float(needs.get("morale", 0.75)) * 100.0),
		"primary_skill_title": get_primary_skill_title(),
		"primary_skill_value": roundi(get_primary_skill_value()),
		"daily_salary": daily_salary,
		"growth_points_remaining": growth_points_remaining,
	}


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"profession_id": profession_id,
		"specialization_id": specialization_id,
		"age": age,
		"age_days": age_days,
		"experience": experience,
		"popularity": popularity,
		"physical_fitness": physical_fitness,
		"relationships": relationships.duplicate(true),
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
		"skill_xp": skill_xp.duplicate(true),
		"skill_caps": skill_caps.duplicate(true),
		"growth_points_total": growth_points_total,
		"growth_points_remaining": growth_points_remaining,
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
	var raw_profession_id: String = str(payload.get("profession_id", "actor"))
	result.profession_id = PROFESSION_CATALOG_SCRIPT.normalize_profession_id(
		raw_profession_id
	)
	result.specialization_id = str(payload.get("specialization_id", ""))
	var available_specializations: Array[String] = (
		PROFESSION_CATALOG_SCRIPT.get_specialization_ids(result.profession_id)
	)
	if not available_specializations.has(result.specialization_id):
		result.specialization_id = ""
	result.age = maxi(int(payload.get("age", 30)), 18)
	var source_schema_version: int = maxi(int(payload.get("schema_version", 1)), 1)
	var source_age_days: int = maxi(int(payload.get("age_days", 0)), 0)
	if source_schema_version < 7:
		result.age_days = clampi(int(float(source_age_days) * 73.0 / 365.0), 0, 72)
	else:
		result.age_days = clampi(source_age_days, 0, 72)
	result.experience = clampf(float(payload.get("experience", 0.0)), 0.0, 100.0)
	result.popularity = clampf(float(payload.get("popularity", 0.0)), 0.0, 100.0)
	result.physical_fitness = clampf(
		float(payload.get("physical_fitness", 50.0)),
		0.0,
		100.0
	)
	var raw_relationships: Variant = payload.get("relationships", {})
	var restored_relationships: Dictionary = {}
	if raw_relationships is Dictionary:
		for relationship_id_value in raw_relationships.keys():
			var relationship_id: String = str(relationship_id_value)
			if relationship_id.is_empty() or relationship_id == result.id:
				continue
			restored_relationships[relationship_id] = clampf(
				float(raw_relationships[relationship_id_value]),
				-100.0,
				100.0
			)
	result.relationships = restored_relationships
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
	var restored_skills: Dictionary = {}
	var profession_skill_ids: Array[String] = (
		PROFESSION_CATALOG_SCRIPT.get_profession_skill_ids(
			result.profession_id,
			result.specialization_id
		)
	)
	for skill_id in profession_skill_ids:
		var skill_value: float = 0.0
		if raw_skills is Dictionary:
			if raw_skills.has(skill_id):
				skill_value = clampf(float(raw_skills[skill_id]), 0.0, 100.0)
		restored_skills[skill_id] = skill_value
	result.skills = restored_skills

	var raw_skill_caps: Variant = payload.get("skill_caps", {})
	var restored_skill_caps: Dictionary = {}
	for skill_id in profession_skill_ids:
		var skill_value: float = float(restored_skills.get(skill_id, 0.0))
		var skill_cap: float = _get_legacy_skill_cap(
			result.id,
			result.profession_id,
			result.specialization_id,
			skill_id,
			skill_value
		)
		if raw_skill_caps is Dictionary and raw_skill_caps.has(skill_id):
			skill_cap = maxf(
				skill_value,
				clampf(float(raw_skill_caps[skill_id]), 0.0, 100.0)
			)
		restored_skill_caps[skill_id] = skill_cap
	result.skill_caps = restored_skill_caps

	var default_growth_budget: float = _get_legacy_growth_budget(
		result.age,
		result.experience,
		restored_skills
	)
	result.growth_points_total = clampf(
		float(payload.get("growth_points_total", default_growth_budget)),
		0.0,
		100.0
	)
	result.growth_points_remaining = clampf(
		float(payload.get("growth_points_remaining", result.growth_points_total)),
		0.0,
		result.growth_points_total
	)

	var raw_skill_xp: Variant = payload.get("skill_xp", {})
	var restored_skill_xp: Dictionary = {}
	for skill_id in profession_skill_ids:
		var skill_xp_value: float = 0.0
		if raw_skill_xp is Dictionary and raw_skill_xp.has(skill_id):
			skill_xp_value = maxf(float(raw_skill_xp[skill_id]), 0.0)
		restored_skill_xp[skill_id] = skill_xp_value
	result.skill_xp = restored_skill_xp

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



static func _get_legacy_skill_cap(
	character_id: String,
	profession_id: String,
	specialization_id: String,
	skill_id: String,
	current_value: float
) -> float:
	var seed_value: int = hash("%s:%s" % [character_id, skill_id])
	var offset: int = absi(seed_value) % 15
	var primary_skill_id: String = PROFESSION_CATALOG_SCRIPT.get_primary_skill_id(
		profession_id
	)
	var specialization_skill_id: String = (
		PROFESSION_CATALOG_SCRIPT.get_specialization_skill_id(
			profession_id,
			specialization_id
		)
	)
	var default_cap: float = 50.0 + float(offset)
	if skill_id == primary_skill_id:
		default_cap = 82.0 + float(offset)
	elif skill_id == specialization_skill_id:
		default_cap = 76.0 + float(offset)
	elif skill_id == "reliability":
		default_cap = 62.0 + float(offset)
	return clampf(maxf(current_value, default_cap), 0.0, 100.0)


static func _get_legacy_growth_budget(
	character_age: int,
	professional_experience: float,
	restored_skills: Dictionary
) -> float:
	var total_skill_value: float = 0.0
	for skill_value in restored_skills.values():
		total_skill_value += float(skill_value)
	var average_skill: float = (
		total_skill_value / float(restored_skills.size())
		if not restored_skills.is_empty()
		else 30.0
	)
	var budget: float = (
		72.0
		- maxf(average_skill - 30.0, 0.0) * 0.75
		- maxf(float(character_age - 35), 0.0) * 0.35
		- professional_experience * 0.25
	)
	return clampf(budget, 12.0, 72.0)
