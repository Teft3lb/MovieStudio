extends RefCounted
class_name CharacterNeedsSystem

const SHIFT_START_HOUR: int = 8
const SHIFT_END_HOUR: int = 17
const BREAK_START_HOUR: int = 12
const BREAK_END_HOUR: int = 13

const TASK_BY_PROFESSION: Dictionary = {
	"actor": "Репетирует сцены",
	"director": "Разрабатывает постановку",
	"screenwriter": "Работает над сценарием",
	"camera_operator": "Готовит операторское оборудование",
	"producer": "Координирует производство",
	"technician": "Обслуживает оборудование",
}


func refresh_work_state(character: Variant, hour: int) -> void:
	var needs: Dictionary = character.needs
	var energy: float = float(needs.get("energy", 1.0))

	if hour < character.shift_start_hour or hour >= character.shift_end_hour:
		character.work_state = "off_duty"
		character.current_task = "Вне рабочей смены"
	elif hour >= character.break_start_hour and hour < character.break_end_hour:
		character.work_state = "break"
		character.current_task = "Обеденный перерыв"
	elif energy <= 0.18:
		character.work_state = "resting"
		character.current_task = "Восстанавливает силы"
	else:
		character.work_state = "working"
		character.current_task = str(
			TASK_BY_PROFESSION.get(character.profession_id, "Выполняет рабочие задачи")
		)


func advance_minute(character: Variant, hour: int) -> void:
	refresh_work_state(character, hour)

	var needs: Dictionary = character.needs
	var energy: float = float(needs.get("energy", 1.0))
	var morale: float = float(needs.get("morale", 0.75))
	var stress: float = float(needs.get("stress", 0.1))

	match character.work_state:
		"working":
			energy -= 0.0005
			stress += 0.00055
		"break":
			energy += 0.001
			stress -= 0.001
		"resting":
			energy += 0.0007
			stress += 0.0001
		_:
			energy += 0.00025
			stress -= 0.0003

	if stress > 0.7 or energy < 0.2:
		morale -= 0.00025
	elif stress < 0.35 and energy > 0.55:
		morale += 0.00008

	needs["energy"] = clampf(energy, 0.0, 1.0)
	needs["morale"] = clampf(morale, 0.0, 1.0)
	needs["stress"] = clampf(stress, 0.0, 1.0)
	character.needs = needs

	refresh_work_state(character, hour)
