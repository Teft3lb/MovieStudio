extends RefCounted
class_name CharacterDevTuning

# Explicit developer-only overrides. Never called from the simulation loop.
# Needs use 0..1 internally; the DEV panel presents everything as 0..100.
const STAT_LABELS: Dictionary = {
	"recognition": "Известность",
	"popularity": "Популярность",
	"experience": "Опыт",
	"physical_fitness": "Физическая форма",
	"energy": "Энергия",
	"morale": "Настроение",
	"stress": "Стресс",
	"all_skills": "Все навыки (DEV)",
}


func get_stat_choices(employee: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if employee == null:
		return result
	for stat_id in STAT_LABELS.keys():
		result.append({
			"id": str(stat_id),
			"title": str(STAT_LABELS[stat_id]),
		})
	var ids: Array = employee.skills.keys()
	ids.sort()
	for id in ids:
		result.append({"id": "skill:%s" % str(id), "title": "Навык: %s" % str(id)})
	return result


func get_stat_value(employee: Variant, stat_id: String) -> float:
	if employee == null:
		return 0.0
	match stat_id:
		"recognition", "popularity", "experience", "physical_fitness":
			return float(employee.get(stat_id))
		"energy", "morale", "stress":
			return float(employee.needs.get(stat_id, 0.0)) * 100.0
		"all_skills":
			var total: float = 0.0
			for value in employee.skills.values():
				total += float(value)
			return total / maxf(float(employee.skills.size()), 1.0)
		_:
			if stat_id.begins_with("skill:"):
				return float(employee.skills.get(stat_id.substr(6), 0.0))
	return 0.0


func set_stat(employee: Variant, stat_id: String, value: float) -> bool:
	if employee == null or not is_finite(value):
		return false
	var normalized: float = clampf(value, 0.0, 100.0)
	match stat_id:
		"recognition", "popularity", "experience", "physical_fitness":
			employee.set(stat_id, normalized)
		"energy", "morale", "stress":
			var updated_needs: Dictionary = employee.needs.duplicate(true)
			updated_needs[stat_id] = normalized / 100.0
			employee.needs = updated_needs
		"all_skills":
			if employee.skills.is_empty():
				return false
			var updated_skills: Dictionary = employee.skills.duplicate(true)
			for skill_id in updated_skills.keys():
				updated_skills[skill_id] = normalized
			employee.skills = updated_skills
		_:
			if not stat_id.begins_with("skill:"):
				return false
			var skill_id: String = stat_id.substr(6)
			if not employee.skills.has(skill_id):
				return false
			var updated_skills: Dictionary = employee.skills.duplicate(true)
			updated_skills[skill_id] = normalized
			employee.skills = updated_skills
	return true


func adjust_stat(employee: Variant, stat_id: String, amount: float) -> bool:
	return set_stat(employee, stat_id, get_stat_value(employee, stat_id) + amount)
