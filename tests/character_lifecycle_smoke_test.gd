extends "res://tests/smoke_test_base.gd"

const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const CHARACTER_AGING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_aging_system.gd"
)
const SKILL_PROGRESSION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_skill_progression_system.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 619384
	var employee: Variant = generator.call(
		"generate",
		rng,
		"EMP-LIFECYCLE-01",
		"actor",
		true
	)
	var aging: RefCounted = CHARACTER_AGING_SYSTEM_SCRIPT.new()
	var progression: RefCounted = SKILL_PROGRESSION_SYSTEM_SCRIPT.new()

	_expect(
		int(employee.age) >= 20 and int(employee.age) <= 35,
		"Starter employees must begin as young adults rather than experienced veterans."
	)
	_expect(
		float(employee.skills.get("acting", 100.0)) <= 40.0,
		"Starter employees must begin with modest professional mastery."
	)
	_expect(
		employee.age_days >= 0 and employee.age_days < 365,
		"Age progress must begin inside the current in-game year."
	)

	var original_age: int = int(employee.age)
	var original_age_days: int = int(employee.age_days)
	for _day in range(365 - original_age_days - 1):
		aging.call("advance_day", employee)
	_expect(
		int(employee.age) == original_age,
		"Employees must not age before a full 365-day cycle has elapsed."
	)
	var aged: bool = bool(aging.call("advance_day", employee))
	_expect(
		aged and int(employee.age) == original_age + 1
		and int(employee.age_days) == 0,
		"Employees must gain one year and reset their birthday progress after 365 days."
	)

	var before: float = float(employee.skills["acting"])
	for _minute in range(1000):
		progression.call(
			"award_skill_experience",
			employee,
			"acting",
			0.65
		)
	_expect(
		float(employee.skills["acting"]) > before,
		"Repeated rehearsal experience must eventually improve acting mastery."
	)
	_expect(
		float(employee.skill_xp["acting"]) >= 0.0,
		"Unspent skill experience must remain non-negative."
	)
	_expect(
		float(progression.call("get_learning_rate_modifier", 72)) <
		float(progression.call("get_learning_rate_modifier", 25)),
		"Older employees must learn more slowly without losing their existing mastery."
	)

	var restored: Variant = CHARACTER_DATA_SCRIPT.from_dict(employee.to_dict())
	_expect(
		restored.age == employee.age
		and restored.age_days == employee.age_days
		and restored.skill_xp == employee.skill_xp,
		"Age and accumulated training experience must survive serialization."
	)

	_finish_test("CharacterLifecycleSmokeTest")
