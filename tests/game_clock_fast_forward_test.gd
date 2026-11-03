extends SceneTree

const GAME_CLOCK_SCRIPT = preload("res://scripts/core/game_clock.gd")
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_management_system.gd"
)

var _advanced_days: int = 0
var _advanced_minutes: int = 0
var _completed_minutes: int = 0
var _management: Variant


func _initialize() -> void:
	var clock: Variant = GAME_CLOCK_SCRIPT.new()
	clock.current_day = 1
	clock.current_hour = 8
	clock.current_minute = 0
	clock.set_speed_mode(0)

	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 908172

	var starting_employee: Variant = generator.call(
		"generate", rng, "EMP-CLOCK-TEST-0001", "actor"
	)
	_management = EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT.new()
	_management.call("initialize", [starting_employee], 1, 908173, 8)

	var first_candidate: Variant = _management.market_candidates[0]
	var first_market_id: String = str(first_candidate.id)
	var hire_result: Dictionary = _management.call(
		"hire_candidate",
		first_market_id,
		"fixed_30_days",
		1
	)
	assert(
		bool(hire_result.get("success", false)),
		"A 30-day employee contract must be available for the integration test."
	)

	var hired_employee: Variant = hire_result.get("employee")
	var hired_employee_id: String = str(hired_employee.id)
	var hired_contract: Variant = hire_result.get("contract")

	clock.day_advanced.connect(_on_day_advanced)
	clock.minute_advanced.connect(_on_minute_advanced)
	clock.manual_advance_finished.connect(_on_manual_advance_finished)

	clock.advance_days(30)

	assert(
		clock.current_day == 31,
		"Thirty fast-forwarded days must advance the game date from day 1 to day 31."
	)
	assert(
		clock.current_hour == 8 and clock.current_minute == 0,
		"Fast-forwarding full days must preserve the time of day."
	)
	assert(
		_advanced_days == 30,
		"Each crossed midnight must emit day_advanced."
	)
	assert(
		_advanced_minutes == 30 * 24 * 60,
		"Manual advancement must emit every minute signal."
	)
	assert(
		_completed_minutes == 30 * 24 * 60,
		"Manual advancement must report the exact number of simulated minutes."
	)
	assert(
		clock.speed_mode == 0,
		"Manual advancement must preserve the paused simulation state."
	)
	assert(
		not clock.is_manual_fast_forward,
		"The clock must leave manual fast-forward mode after completion."
	)
	assert(
		hired_contract.status == "expired",
		"A 30-day contract must expire when the fast-forward crosses into day 31."
	)
	assert(
		_management.employees.size() == 1,
		"An expired employee must be removed from the active roster."
	)
	assert(
		_management.former_employees.size() == 1
		and str(_management.former_employees[0].id) == hired_employee_id,
		"The expired employee must remain in the former-employee archive."
	)
	assert(
		_management.market_candidates.size() == 8,
		"The candidate market must refresh during the 30-day fast-forward."
	)
	assert(
		str(_management.market_candidates[0].id) != first_market_id,
		"Market refresh must replace the initial candidate pool."
	)

	print("GameClockFastForwardTest: PASS")
	quit(0)


func _on_day_advanced(day: int) -> void:
	_advanced_days += 1
	_management.call("advance_day", day)


func _on_minute_advanced(_day: int, _hour: int, _minute: int) -> void:
	_advanced_minutes += 1


func _on_manual_advance_finished(minutes_advanced: int) -> void:
	_completed_minutes = minutes_advanced
