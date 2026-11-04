extends Node
class_name GameClock

signal minute_advanced(day: int, hour: int, minute: int)
signal day_advanced(day: int)

enum SpeedMode {
	PAUSED,
	NORMAL,
	FAST,
	VERY_FAST,
}

const SPEED_MULTIPLIERS: Dictionary = {
	SpeedMode.PAUSED: 0.0,
	SpeedMode.NORMAL: 1.0,
	SpeedMode.FAST: 3.0,
	SpeedMode.VERY_FAST: 6.0,
}

const MAX_CATCH_UP_MINUTES_PER_FRAME: int = 120

@export_range(0.05, 10.0, 0.05) var real_seconds_per_game_minute: float = 1.0
@export_range(1, 9999, 1) var starting_day: int = 1
@export_range(0, 23, 1) var starting_hour: int = 8

var current_day: int = 1
var current_hour: int = 8
var current_minute: int = 0
var speed_mode: int = SpeedMode.NORMAL

var _accumulator: float = 0.0


func _ready() -> void:
	current_day = maxi(starting_day, 1)
	current_hour = clampi(starting_hour, 0, 23)
	current_minute = 0
	_emit_time()


func _process(delta: float) -> void:
	var simulation_delta: float = get_simulation_delta(delta)
	if is_zero_approx(simulation_delta):
		return

	var seconds_per_minute: float = maxf(real_seconds_per_game_minute, 0.01)
	_accumulator += simulation_delta

	var advanced_minutes: int = 0
	while _accumulator >= seconds_per_minute and advanced_minutes < MAX_CATCH_UP_MINUTES_PER_FRAME:
		_accumulator -= seconds_per_minute
		_advance_one_minute()
		advanced_minutes += 1


func get_speed_multiplier() -> float:
	return float(SPEED_MULTIPLIERS.get(speed_mode, 0.0))


func get_simulation_delta(real_delta: float) -> float:
	return maxf(real_delta, 0.0) * get_speed_multiplier()


func set_speed_mode(mode: int) -> void:
	if not SPEED_MULTIPLIERS.has(mode):
		push_warning("GameClock: unknown speed mode %s" % mode)
		return

	speed_mode = mode


func get_clock_text() -> String:
	return "День %03d  %02d:%02d" % [current_day, current_hour, current_minute]


func get_speed_text() -> String:
	match speed_mode:
		SpeedMode.PAUSED:
			return "Симуляция: пауза"
		SpeedMode.NORMAL:
			return "Симуляция: 1×"
		SpeedMode.FAST:
			return "Симуляция: 3×"
		SpeedMode.VERY_FAST:
			return "Симуляция: 6×"
		_:
			return "Симуляция: неизвестная скорость"


func _advance_one_minute() -> void:
	current_minute += 1

	if current_minute >= 60:
		current_minute = 0
		current_hour += 1

		if current_hour >= 24:
			current_hour = 0
			current_day += 1
			day_advanced.emit(current_day)

	_emit_time()


func _emit_time() -> void:
	minute_advanced.emit(current_day, current_hour, current_minute)
