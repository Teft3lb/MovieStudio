extends RefCounted
class_name CelebrityPublicitySystem

# Non-film routes to public recognition. All effects are deterministic and
# scale with actual protection at the event. This is gameplay, not a DEV cheat.
const EVENT_CONFIG: Dictionary = {
	"fan_meet": {
		"title": "Встреча с поклонниками",
		"duration_minutes": 60,
		"cooldown_days": 2,
		"base_stress": 0.18,
		"energy_cost": 0.10,
		"fame_gain": 1.10,
		"popularity_gain": 0.80,
		"max_visitors": 9,
	},
	"paparazzi": {
		"title": "Фотосессия для папарацци",
		"duration_minutes": 30,
		"cooldown_days": 1,
		"base_stress": 0.25,
		"energy_cost": 0.07,
		"fame_gain": 0.95,
		"popularity_gain": 0.25,
		"max_visitors": 5,
	},
}

var _last_event_days: Dictionary = {}


func get_event_title(event_id: String) -> String:
	return str(EVENT_CONFIG.get(event_id, {}).get("title", event_id))


func get_visitor_count(event_id: String, recognition: float) -> int:
	var details: Dictionary = EVENT_CONFIG.get(event_id, {})
	if details.is_empty():
		return 0
	var base: int = 4 if event_id == "fan_meet" else 2
	return mini(base + floori(clampf(recognition, 0.0, 100.0) / 20.0),
		int(details["max_visitors"]))


func get_blocker(
	employee: Variant,
	event_id: String,
	day: int
) -> String:
	if employee == null:
		return "Персонаж не найден."
	if str(employee.profession_id) not in ["actor", "director"]:
		return "Публичные встречи доступны актёрам и режиссёрам."
	if not EVENT_CONFIG.has(event_id):
		return "Неизвестный формат публичного мероприятия."
	if float(employee.needs.get("energy", 0.0)) < 0.15:
		return "Звезда слишком устала для встречи с публикой."
	var key: String = "%s:%s" % [str(employee.id), event_id]
	if _last_event_days.has(key):
		var available_day: int = int(_last_event_days[key]) + int(
			EVENT_CONFIG[event_id]["cooldown_days"]
		)
		if day < available_day:
			return "Повторное мероприятие доступно с игрового дня %d." % available_day
	return ""


func create_event(employee: Variant, event_id: String, day: int) -> Dictionary:
	var blocker: String = get_blocker(employee, event_id, day)
	if not blocker.is_empty():
		return {"success": false, "message": blocker}
	var settings: Dictionary = EVENT_CONFIG[event_id]
	return {
		"success": true,
		"event_id": event_id,
		"employee_id": str(employee.id),
		"start_day": day,
		"elapsed_minutes": 0,
		"duration_minutes": int(settings["duration_minutes"]),
		"visitor_count": get_visitor_count(event_id, float(employee.recognition)),
		"max_guards_present": 0,
		"guard_protection_sum": 0.0,
		"stress_delta": 0.0,
		"energy_delta": 0.0,
	}


func guard_protection(guard_skills: Array[float]) -> float:
	var protection: float = 0.0
	for skill in guard_skills:
		protection += 0.16 + clampf(skill, 0.0, 100.0) * 0.0015
	return clampf(protection, 0.0, 0.90)


func advance_event(
	event: Dictionary,
	employee: Variant,
	guard_skills: Array[float]
) -> Dictionary:
	if employee == null or not bool(event.get("success", false)):
		return {"success": false, "completed": false}
	if not EVENT_CONFIG.has(str(event.get("event_id", ""))):
		return {"success": false, "completed": false}
	var settings: Dictionary = EVENT_CONFIG[str(event["event_id"])]
	var duration: int = maxi(int(event["duration_minutes"]), 1)
	var protection: float = guard_protection(guard_skills)
	var stress_step: float = (
		float(settings["base_stress"]) * (1.0 - protection) / float(duration)
	)
	var energy_step: float = float(settings["energy_cost"]) / float(duration)
	var needs: Dictionary = employee.needs.duplicate(true)
	needs["stress"] = clampf(
		float(needs.get("stress", 0.0)) + stress_step, 0.0, 1.0
	)
	needs["energy"] = clampf(
		float(needs.get("energy", 1.0)) - energy_step, 0.0, 1.0
	)
	employee.needs = needs
	event["elapsed_minutes"] = int(event["elapsed_minutes"]) + 1
	event["guard_protection_sum"] = float(
		event["guard_protection_sum"]
	) + protection
	event["max_guards_present"] = maxi(
		int(event["max_guards_present"]), guard_skills.size()
	)
	event["stress_delta"] = float(event["stress_delta"]) + stress_step
	event["energy_delta"] = float(event["energy_delta"]) - energy_step
	if int(event["elapsed_minutes"]) < duration:
		return {"success": true, "completed": false}

	var before_fame: float = float(employee.recognition)
	var before_popularity: float = float(employee.popularity)
	var attendance: int = int(event["visitor_count"])
	var average_protection: float = (
		float(event["guard_protection_sum"]) / float(duration)
	)
	var fame_gain: float = (
		float(settings["fame_gain"]) + float(attendance) * 0.09
	)
	# Overexposure and tense photo encounters can sour audience opinion.
	var popularity_gain: float = (
		float(settings["popularity_gain"])
		+ float(attendance) * 0.045
		- (1.0 - average_protection) * (
			0.75 if str(event["event_id"]) == "paparazzi" else 0.10
		)
	)
	employee.recognition = clampf(before_fame + fame_gain, 0.0, 100.0)
	employee.popularity = clampf(
		before_popularity + popularity_gain, 0.0, 100.0
	)
	_last_event_days["%s:%s" % [
		str(employee.id), str(event["event_id"])
	]] = int(event["start_day"])
	return {
		"success": true,
		"completed": true,
		"fame_delta": employee.recognition - before_fame,
		"popularity_delta": employee.popularity - before_popularity,
		"stress_delta": float(event["stress_delta"]),
		"guards_present": int(event["max_guards_present"]),
		"average_protection": average_protection,
		"visitor_count": attendance,
	}
