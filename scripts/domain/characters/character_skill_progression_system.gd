extends RefCounted
class_name CharacterSkillProgressionSystem

const BASE_XP_PER_SKILL_POINT: float = 10.0
const SKILL_XP_SCALE: float = 0.15


func award_skill_experience(
	employee: Variant,
	skill_id: String,
	amount: float
) -> bool:
	if employee == null or amount <= 0.0:
		return false
	if not (employee.skills is Dictionary) or not employee.skills.has(skill_id):
		return false

	var skills: Dictionary = employee.skills.duplicate(true)
	var skill_xp: Dictionary = employee.skill_xp.duplicate(true)
	var skill_value: float = clampf(
		float(skills.get(skill_id, 0.0)),
		0.0,
		100.0
	)
	if skill_value >= 100.0:
		skill_xp[skill_id] = 0.0
		employee.skill_xp = skill_xp
		return false

	var learning_modifier: float = get_learning_rate_modifier(int(employee.age))
	var accumulated_xp: float = maxf(
		float(skill_xp.get(skill_id, 0.0)),
		0.0
	) + amount * learning_modifier

	while skill_value < 100.0:
		var required_xp: float = get_xp_required_for_next_point(skill_value)
		if accumulated_xp + 0.000001 < required_xp:
			break
		accumulated_xp -= required_xp
		skill_value = minf(skill_value + 1.0, 100.0)

	skills[skill_id] = skill_value
	skill_xp[skill_id] = (
		0.0 if skill_value >= 100.0 else accumulated_xp
	)
	employee.skills = skills
	employee.skill_xp = skill_xp
	return true


func get_xp_required_for_next_point(skill_value: float) -> float:
	return BASE_XP_PER_SKILL_POINT + clampf(skill_value, 0.0, 100.0) * SKILL_XP_SCALE


func get_progress_percent(employee: Variant, skill_id: String) -> float:
	if employee == null or not employee.skills.has(skill_id):
		return 0.0
	var skill_value: float = clampf(
		float(employee.skills.get(skill_id, 0.0)),
		0.0,
		100.0
	)
	if skill_value >= 100.0:
		return 100.0
	var current_xp: float = maxf(
		float(employee.skill_xp.get(skill_id, 0.0)),
		0.0
	)
	return clampf(
		current_xp / get_xp_required_for_next_point(skill_value) * 100.0,
		0.0,
		99.9
	)


func get_learning_rate_modifier(age: int) -> float:
	if age < 25:
		return 1.10
	if age < 40:
		return 1.0
	if age < 55:
		return 0.90
	if age < 70:
		return 0.75
	return 0.60
