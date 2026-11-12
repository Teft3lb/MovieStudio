extends RefCounted
class_name CharacterNeedsSystem

const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)

const SHIFT_START_HOUR: int = 8
const SHIFT_END_HOUR: int = 17
const BREAK_START_HOUR: int = 12
const BREAK_END_HOUR: int = 13
const BEDTIME_HOUR: int = 22


func refresh_work_state(character: Variant, hour: int) -> void:
	var needs: Dictionary = character.needs
	var energy: float = float(needs.get("energy", 1.0))

	if hour < character.shift_start_hour:
		character.work_state = "off_duty"
		character.current_task = "Вне рабочей смены"
	elif hour >= character.shift_end_hour:
		if hour < BEDTIME_HOUR:
			character.work_state = "free_time"
			character.current_task = "Свободное время"
		else:
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
		character.current_task = PROFESSION_CATALOG_SCRIPT.get_default_task(
			character.profession_id
		)


func advance_minute(
	character: Variant,
	hour: int,
	at_cafeteria: bool = false,
	at_staff_housing: bool = false,
	at_star_bungalow: bool = false,
	at_fitness_center: bool = false,
	at_studio_lounge: bool = false
) -> void:
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
			if at_cafeteria:
				energy += 0.0022
				stress -= 0.0018
			else:
				energy += 0.001
				stress -= 0.001
		"resting":
			energy += 0.0007
			stress += 0.0001
		"free_time":
			if at_fitness_center:
				energy -= 0.0010
				stress -= 0.00035
				morale += 0.00012
				var fitness: float = clampf(
					float(character.physical_fitness),
					0.0,
					100.0
				)
				fitness += 0.004 * (1.0 - fitness / 125.0)
				character.physical_fitness = clampf(fitness, 0.0, 100.0)
			elif at_studio_lounge:
				energy += 0.0002
				stress -= 0.0011
				morale += 0.00018
			else:
				energy += 0.00035
				stress -= 0.00055
		"off_duty":
			if at_star_bungalow:
				energy += 0.0015
				stress -= 0.0016
			elif at_staff_housing:
				energy += 0.0011
				stress -= 0.0012
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
