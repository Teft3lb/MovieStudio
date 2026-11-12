extends RefCounted
class_name TVEpisodeData

const STATUS_PLANNED: String = "planned"
const STATUS_IN_PRODUCTION: String = "in_production"
const STATUS_READY_FOR_BROADCAST: String = "ready_for_broadcast"
const STATUS_BROADCASTED: String = "broadcasted"
const STATUS_CANCELLED: String = "cancelled"

const VALID_STATUSES: Array[String] = [
	STATUS_PLANNED,
	STATUS_IN_PRODUCTION,
	STATUS_READY_FOR_BROADCAST,
	STATUS_BROADCASTED,
	STATUS_CANCELLED,
]

var id: String = ""
var program_type_id: String = "series"
var program_id: String = ""
var season_number: int = 0
var episode_number: int = 1
var title: String = ""
var synopsis: String = ""
var runtime_minutes: int = 30
var script_id: String = ""
var script_potential_score: float = 50.0

var status: String = STATUS_PLANNED
var current_phase: String = ""
var phase_minutes_elapsed: int = 0
var phase_duration_minutes: int = 0
var production_elapsed_minutes: int = 0
var estimated_total_minutes: int = 0
var production_quality: float = 0.0
var audience_rating: float = 0.0
var audience_reach: int = 0

var host_employee_id: String = ""
var cast_employee_ids: Array[String] = []
var guest_employee_ids: Array[String] = []
var crew_assignments: Dictionary = {}

var production_started_day: int = 0
var production_started_hour: int = 0
var production_started_minute: int = 0
var broadcast_day: int = 0
var production_seed: int = 0
var production_rng_state: int = 0
var pause_reason: String = ""
var last_activity_message: String = ""


func get_progress_percent() -> float:
	if status in [
		STATUS_READY_FOR_BROADCAST,
		STATUS_BROADCASTED,
	]:
		return 100.0
	if estimated_total_minutes <= 0:
		return 0.0
	return clampf(
		float(production_elapsed_minutes)
		/ float(estimated_total_minutes)
		* 100.0,
		0.0,
		99.0
	)


func get_status_title() -> String:
	match status:
		STATUS_PLANNED:
			return "Запланирован"
		STATUS_IN_PRODUCTION:
			return "В производстве"
		STATUS_READY_FOR_BROADCAST:
			return "Готов к эфиру"
		STATUS_BROADCASTED:
			return "Вышел в эфир"
		STATUS_CANCELLED:
			return "Отменён"
		_:
			return "Неизвестный статус"


func get_phase_title() -> String:
	match current_phase:
		"preparation":
			return "Подготовка площадки"
		"rehearsal":
			return "Репетиция"
		"shooting":
			return "Съёмка"
		"postproduction":
			return "Постпродакшен"
		"completed":
			return "Производство завершено"
		_:
			return "Не начато"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"program_type_id": program_type_id,
		"program_id": program_id,
		"season_number": season_number,
		"episode_number": episode_number,
		"title": title,
		"synopsis": synopsis,
		"runtime_minutes": runtime_minutes,
		"script_id": script_id,
		"script_potential_score": script_potential_score,
		"status": status,
		"current_phase": current_phase,
		"phase_minutes_elapsed": phase_minutes_elapsed,
		"phase_duration_minutes": phase_duration_minutes,
		"production_elapsed_minutes": production_elapsed_minutes,
		"estimated_total_minutes": estimated_total_minutes,
		"production_quality": production_quality,
		"audience_rating": audience_rating,
		"audience_reach": audience_reach,
		"host_employee_id": host_employee_id,
		"cast_employee_ids": cast_employee_ids.duplicate(),
		"guest_employee_ids": guest_employee_ids.duplicate(),
		"crew_assignments": crew_assignments.duplicate(true),
		"production_started_day": production_started_day,
		"production_started_hour": production_started_hour,
		"production_started_minute": production_started_minute,
		"broadcast_day": broadcast_day,
		"production_seed": production_seed,
		"production_rng_state": production_rng_state,
		"pause_reason": pause_reason,
		"last_activity_message": last_activity_message,
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/tv_production/tv_episode_data.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.program_type_id = str(payload.get("program_type_id", "series"))
	result.program_id = str(payload.get("program_id", ""))
	result.season_number = clampi(int(payload.get("season_number", 0)), 0, 99)
	result.episode_number = clampi(int(payload.get("episode_number", 1)), 1, 999)
	result.title = str(payload.get("title", ""))
	result.synopsis = str(payload.get("synopsis", ""))
	result.runtime_minutes = clampi(
		int(payload.get("runtime_minutes", 30)),
		5,
		180
	)
	result.script_id = str(payload.get("script_id", ""))
	result.script_potential_score = clampf(
		float(payload.get("script_potential_score", 50.0)),
		0.0,
		100.0
	)
	var raw_status: String = str(payload.get("status", STATUS_PLANNED))
	result.status = raw_status if VALID_STATUSES.has(raw_status) else STATUS_PLANNED
	result.current_phase = str(payload.get("current_phase", ""))
	result.phase_minutes_elapsed = maxi(
		int(payload.get("phase_minutes_elapsed", 0)),
		0
	)
	result.phase_duration_minutes = maxi(
		int(payload.get("phase_duration_minutes", 0)),
		0
	)
	result.production_elapsed_minutes = maxi(
		int(payload.get("production_elapsed_minutes", 0)),
		0
	)
	result.estimated_total_minutes = maxi(
		int(payload.get("estimated_total_minutes", 0)),
		0
	)
	result.production_quality = clampf(
		float(payload.get("production_quality", 0.0)),
		0.0,
		100.0
	)
	result.audience_rating = clampf(
		float(payload.get("audience_rating", 0.0)),
		0.0,
		100.0
	)
	result.audience_reach = maxi(int(payload.get("audience_reach", 0)), 0)
	result.host_employee_id = str(payload.get("host_employee_id", ""))
	result.cast_employee_ids = _read_string_array(
		payload.get("cast_employee_ids", [])
	)
	result.guest_employee_ids = _read_string_array(
		payload.get("guest_employee_ids", [])
	)
	var raw_crew: Variant = payload.get("crew_assignments", {})
	if raw_crew is Dictionary:
		result.crew_assignments = raw_crew.duplicate(true)
	result.production_started_day = maxi(
		int(payload.get("production_started_day", 0)),
		0
	)
	result.production_started_hour = clampi(
		int(payload.get("production_started_hour", 0)),
		0,
		23
	)
	result.production_started_minute = clampi(
		int(payload.get("production_started_minute", 0)),
		0,
		59
	)
	result.broadcast_day = maxi(int(payload.get("broadcast_day", 0)), 0)
	result.production_seed = int(payload.get("production_seed", 0))
	result.production_rng_state = int(payload.get("production_rng_state", 0))
	result.pause_reason = str(payload.get("pause_reason", ""))
	result.last_activity_message = str(
		payload.get("last_activity_message", "")
	)
	return result


static func _read_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var item_id: String = str(item)
			if not item_id.is_empty() and not result.has(item_id):
				result.append(item_id)
	return result
