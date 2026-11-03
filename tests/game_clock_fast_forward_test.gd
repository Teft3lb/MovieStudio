extends SceneTree

const GAME_CLOCK_SCRIPT = preload("res://scripts/core/game_clock.gd")

var _advanced_days: int = 0
var _completed_minutes: int = 0


func _initialize() -> void:
	var clock: Variant = GAME_CLOCK_SCRIPT.new()
	clock.current_day = 1
	clock.current_hour = 8
	clock.current_minute = 0
	clock.set_speed_mode(0)
	clock.day_advanced.connect(_on_day_advanced)
	clock.manual_advance_finished.connect(_on_manual_advance_finished)

	clock.advance_days(7)

	assert(
		clock.current_day == 8,
		"Seven fast-forwarded days must advance the game date by seven days."
	)
	assert(
		clock.current_hour == 8 and clock.current_minute == 0,
		"Fast-forwarding full days must preserve the time of day."
	)
	assert(
		_advanced_days == 7,
		"Each crossed midnight must emit day_advanced."
	)
	assert(
		_completed_minutes == 7 * 24 * 60,
		"Manual advancement must report the exact number of simulated minutes."
	)
	assert(
		clock.speed_mode == 0,
		"Manual advancement must preserve the paused simulation state."
	)

	print("GameClockFastForwardTest: PASS")
	quit(0)


func _on_day_advanced(_day: int) -> void:
	_advanced_days += 1


func _on_manual_advance_finished(minutes_advanced: int) -> void:
	_completed_minutes = minutes_advanced
