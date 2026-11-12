extends RefCounted
class_name CharacterAgingSystem

const GAME_DAYS_PER_BIOLOGICAL_YEAR: int = 73
const MINIMUM_WORKING_AGE: int = 18


func advance_day(character: Variant) -> bool:
	if character == null:
		return false
	var age_progress: int = clampi(
		int(character.age_days),
		0,
		GAME_DAYS_PER_BIOLOGICAL_YEAR - 1
	) + 1
	var became_older: bool = age_progress >= GAME_DAYS_PER_BIOLOGICAL_YEAR
	if became_older:
		character.age = maxi(
			int(character.age) + 1,
			MINIMUM_WORKING_AGE
		)
		age_progress -= GAME_DAYS_PER_BIOLOGICAL_YEAR
	character.age_days = age_progress
	return became_older

