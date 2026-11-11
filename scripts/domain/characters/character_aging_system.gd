extends RefCounted
class_name CharacterAgingSystem

const DAYS_PER_YEAR: int = 365
const MINIMUM_WORKING_AGE: int = 18


func advance_day(character: Variant) -> bool:
	if character == null:
		return false
	var age_progress: int = clampi(
		int(character.age_days),
		0,
		DAYS_PER_YEAR - 1
	) + 1
	var became_older: bool = age_progress >= DAYS_PER_YEAR
	if became_older:
		character.age = maxi(
			int(character.age) + 1,
			MINIMUM_WORKING_AGE
		)
		age_progress -= DAYS_PER_YEAR
	character.age_days = age_progress
	return became_older
