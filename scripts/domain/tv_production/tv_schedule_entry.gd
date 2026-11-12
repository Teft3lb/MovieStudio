extends RefCounted
class_name TVScheduleEntry

const DAY_TITLES: Array[String] = [
	"Понедельник",
	"Вторник",
	"Среда",
	"Четверг",
	"Пятница",
	"Суббота",
	"Воскресенье",
]

var id: String = ""
var program_type_id: String = "series"
var program_id: String = ""
var schedule_type_id: String = "shooting"
var day_of_week: int = 0
var start_hour: int = 10
var start_minute: int = 0
var duration_minutes: int = 180
var participant_ids: Array[String] = []
var active: bool = true
var last_triggered_day: int = 0


func is_due(day: int, hour: int, minute: int) -> bool:
	if not active or day < 1 or last_triggered_day == day:
		return false
	return (
		posmod(day - 1, 7) == day_of_week
		and hour == start_hour
		and minute == start_minute
	)


func conflicts_with(other: Variant) -> bool:
	if (
		other == null
		or not active
		or not bool(other.active)
		or day_of_week != int(other.day_of_week)
	):
		return false
	var shared_participant: bool = false
	for participant_id in participant_ids:
		if other.participant_ids.has(participant_id):
			shared_participant = true
			break
	if not shared_participant:
		return false
	var start_a: int = start_hour * 60 + start_minute
	var end_a: int = start_a + duration_minutes
	var start_b: int = int(other.start_hour) * 60 + int(other.start_minute)
	var end_b: int = start_b + int(other.duration_minutes)
	return start_a < end_b and start_b < end_a


func get_day_title() -> String:
	return DAY_TITLES[clampi(day_of_week, 0, DAY_TITLES.size() - 1)]


func to_dict() -> Dictionary:
	return {
		"id": id,
		"program_type_id": program_type_id,
		"program_id": program_id,
		"schedule_type_id": schedule_type_id,
		"day_of_week": day_of_week,
		"start_hour": start_hour,
		"start_minute": start_minute,
		"duration_minutes": duration_minutes,
		"participant_ids": participant_ids.duplicate(),
		"active": active,
		"last_triggered_day": last_triggered_day,
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/tv_production/tv_schedule_entry.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.program_type_id = str(payload.get("program_type_id", "series"))
	result.program_id = str(payload.get("program_id", ""))
	result.schedule_type_id = str(payload.get("schedule_type_id", "shooting"))
	result.day_of_week = clampi(int(payload.get("day_of_week", 0)), 0, 6)
	result.start_hour = clampi(int(payload.get("start_hour", 10)), 0, 23)
	result.start_minute = clampi(int(payload.get("start_minute", 0)), 0, 59)
	result.duration_minutes = clampi(
		int(payload.get("duration_minutes", 180)),
		1,
		720
	)
	var raw_participants: Variant = payload.get("participant_ids", [])
	if raw_participants is Array:
		for participant_value in raw_participants:
			var participant_id: String = str(participant_value)
			if (
				not participant_id.is_empty()
				and not result.participant_ids.has(participant_id)
			):
				result.participant_ids.append(participant_id)
	result.active = bool(payload.get("active", true))
	result.last_triggered_day = maxi(
		int(payload.get("last_triggered_day", 0)),
		0
	)
	return result
