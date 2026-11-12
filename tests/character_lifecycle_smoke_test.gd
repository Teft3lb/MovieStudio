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
		employee.age_days >= 0 and employee.age_days < 73,
		"Biological age progress must stay inside a 73-game-day cycle."
	)

	var original_age: int = int(employee.age)
	employee.age_days = 0
	for _day in range(72):
		aging.call("advance_day", employee)
	_expect(
		int(employee.age) == original_age and int(employee.age_days) == 72,
		"Employees must not gain a biological year before 73 game days."
	)
	var aged: bool = bool(aging.call("advance_day", employee))
	_expect(
		aged and int(employee.age) == original_age + 1
		and int(employee.age_days) == 0,
		"Employees must gain one biological year every 73 game days."
	)
	var full_year_employee: Variant = CHARACTER_DATA_SCRIPT.from_dict(
		employee.to_dict()
	)
	full_year_employee.age_days = 0
	var age_before_game_year: int = int(full_year_employee.age)
	for _day in range(365):
		aging.call("advance_day", full_year_employee)
	_expect(
		int(full_year_employee.age) == age_before_game_year + 5
		and int(full_year_employee.age_days) == 0,
		"One 365-day game year must advance biological age by exactly five years."
	)

	var before: float = float(employee.skills["acting"])
	var starting_growth_budget: float = float(employee.growth_points_remaining)
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
		float(employee.skills["acting"]) <= float(employee.skill_caps["acting"])
		and float(employee.growth_points_remaining) < starting_growth_budget,
		"Skill growth must respect personal potential and consume a shared career development reserve."
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
		and restored.skill_xp == employee.skill_xp
		and restored.skill_caps == employee.skill_caps
		and is_equal_approx(
			float(restored.growth_points_remaining),
			float(employee.growth_points_remaining)
		),
		"Age, personal skill potential and remaining development reserve must survive serialization."
	)

	var legacy_payload: Dictionary = employee.to_dict()
	legacy_payload["schema_version"] = 6
	legacy_payload["age_days"] = 364
	legacy_payload.erase("skill_caps")
	legacy_payload.erase("growth_points_total")
	legacy_payload.erase("growth_points_remaining")
	var migrated: Variant = CHARACTER_DATA_SCRIPT.from_dict(legacy_payload)
	_expect(
		int(migrated.age_days) == 72
		and migrated.skill_caps.size() == migrated.skills.size()
		and float(migrated.growth_points_remaining) > 0.0,
		"Legacy character data must migrate age progress, skill potential and growth reserve safely."
	)

	var limited_employee: Variant = CHARACTER_DATA_SCRIPT.from_dict(employee.to_dict())
	limited_employee.skills["acting"] = 20.0
	limited_employee.skill_caps["acting"] = 100.0
	limited_employee.growth_points_total = 1.0
	limited_employee.growth_points_remaining = 1.0
	limited_employee.skill_xp["acting"] = 0.0
	progression.call("award_skill_experience", limited_employee, "acting", 1000.0)
	_expect(
		is_equal_approx(float(limited_employee.skills["acting"]), 21.0)
		and is_zero_approx(float(limited_employee.growth_points_remaining)),
		"A character must not gain more mastery points than the remaining career growth budget allows."
	)

	_finish_test("CharacterLifecycleSmokeTest")
