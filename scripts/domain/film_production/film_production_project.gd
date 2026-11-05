extends RefCounted
class_name FilmProductionProject

const SCHEMA_VERSION: int = 3

var id: String = ""
var script_id: String = ""
var film_title: String = ""
var genre_id: String = ""
var genre_title: String = ""
var script_potential_score: int = 0
var script_potential_stars: int = 1

var status: String = "in_production"
var current_scene_index: int = 0
var total_scene_count: int = 0
var completed_scene_count: int = 0
var current_phase: String = "preparation"
var phase_minutes_elapsed: int = 0
var phase_duration_minutes: int = 0
var total_elapsed_minutes: int = 0
var current_scene_elapsed_minutes: int = 0
var estimated_total_minutes: int = 0
var current_scene_retakes: int = 0
var current_scene_quality: float = 0.0
var technician_count: int = 1

var crew_assignments: Dictionary = {}
var cast_assignments: Dictionary = {}
var scene_results: Array = []
var scene_setups: Array = []

var pause_reason: String = ""
var last_activity_message: String = ""
var final_quality: int = 0
var seed: int = 0
var rng_state: int = 0
var started_day: int = 1
var started_hour: int = 8
var started_minute: int = 0


func get_progress_percent() -> float:
	if status == "completed":
		return 100.0
	if estimated_total_minutes <= 0:
		return 0.0
	return clampf(
		float(total_elapsed_minutes) / float(estimated_total_minutes) * 100.0,
		0.0,
		99.9
	)


func get_phase_progress_percent() -> float:
	if phase_duration_minutes <= 0:
		return 0.0
	return clampf(
		float(phase_minutes_elapsed) / float(phase_duration_minutes) * 100.0,
		0.0,
		100.0
	)


func get_remaining_work_minutes() -> int:
	return maxi(estimated_total_minutes - total_elapsed_minutes, 0)


func get_phase_title() -> String:
	match current_phase:
		"preparation":
			return "Подготовка площадки"
		"set_dressing":
			return "Монтаж декораций"
		"rehearsal":
			return "Репетиция"
		"shooting":
			return "Съёмка дубля"
		"review":
			return "Просмотр материала"
		"set_strike":
			return "Уборка декораций"
		_:
			return "Неизвестный этап"


func get_current_scene_setup() -> Dictionary:
	if current_scene_index < 0 or current_scene_index >= scene_setups.size():
		return {}
	var setup: Variant = scene_setups[current_scene_index]
	if setup is Dictionary:
		return setup.duplicate(true)
	return {}


func get_status_title() -> String:
	match status:
		"in_production":
			return "В производстве"
		"completed":
			return "Съёмки завершены"
		"cancelled":
			return "Производство отменено"
		"failed":
			return "Производство остановлено"
		_:
			return "Неизвестный статус"


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"script_id": script_id,
		"film_title": film_title,
		"genre_id": genre_id,
		"genre_title": genre_title,
		"script_potential_score": script_potential_score,
		"script_potential_stars": script_potential_stars,
		"status": status,
		"current_scene_index": current_scene_index,
		"total_scene_count": total_scene_count,
		"completed_scene_count": completed_scene_count,
		"current_phase": current_phase,
		"phase_minutes_elapsed": phase_minutes_elapsed,
		"phase_duration_minutes": phase_duration_minutes,
		"total_elapsed_minutes": total_elapsed_minutes,
		"current_scene_elapsed_minutes": current_scene_elapsed_minutes,
		"estimated_total_minutes": estimated_total_minutes,
		"current_scene_retakes": current_scene_retakes,
		"current_scene_quality": current_scene_quality,
		"technician_count": technician_count,
		"crew_assignments": crew_assignments.duplicate(true),
		"cast_assignments": cast_assignments.duplicate(true),
		"scene_results": scene_results.duplicate(true),
		"scene_setups": scene_setups.duplicate(true),
		"pause_reason": pause_reason,
		"last_activity_message": last_activity_message,
		"final_quality": final_quality,
		"seed": seed,
		"rng_state": rng_state,
		"started_day": started_day,
		"started_hour": started_hour,
		"started_minute": started_minute,
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/film_production/film_production_project.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.script_id = str(payload.get("script_id", ""))
	result.film_title = str(payload.get("film_title", ""))
	result.genre_id = str(payload.get("genre_id", ""))
	result.genre_title = str(payload.get("genre_title", ""))
	result.script_potential_score = clampi(
		int(payload.get("script_potential_score", 0)),
		0,
		100
	)
	result.script_potential_stars = clampi(
		int(payload.get("script_potential_stars", 1)),
		1,
		5
	)
	result.status = str(payload.get("status", "in_production"))
	result.current_scene_index = maxi(
		int(payload.get("current_scene_index", 0)),
		0
	)
	result.total_scene_count = maxi(
		int(payload.get("total_scene_count", 0)),
		0
	)
	result.completed_scene_count = clampi(
		int(payload.get("completed_scene_count", 0)),
		0,
		result.total_scene_count
	)
	result.current_phase = str(payload.get("current_phase", "preparation"))
	result.phase_minutes_elapsed = maxi(
		int(payload.get("phase_minutes_elapsed", 0)),
		0
	)
	result.phase_duration_minutes = maxi(
		int(payload.get("phase_duration_minutes", 0)),
		0
	)
	result.total_elapsed_minutes = maxi(
		int(payload.get("total_elapsed_minutes", 0)),
		0
	)
	result.current_scene_elapsed_minutes = maxi(
		int(payload.get("current_scene_elapsed_minutes", 0)),
		0
	)
	result.estimated_total_minutes = maxi(
		int(payload.get("estimated_total_minutes", 0)),
		0
	)
	result.current_scene_retakes = clampi(
		int(payload.get("current_scene_retakes", 0)),
		0,
		2
	)
	result.current_scene_quality = clampf(
		float(payload.get("current_scene_quality", 0.0)),
		0.0,
		100.0
	)
	result.technician_count = clampi(
		int(payload.get("technician_count", 1)),
		1,
		8
	)
	var raw_crew: Variant = payload.get("crew_assignments", {})
	if raw_crew is Dictionary:
		result.crew_assignments = raw_crew.duplicate(true)
	var raw_cast: Variant = payload.get("cast_assignments", {})
	if raw_cast is Dictionary:
		result.cast_assignments = raw_cast.duplicate(true)
	var raw_results: Variant = payload.get("scene_results", [])
	if raw_results is Array:
		result.scene_results = raw_results.duplicate(true)
	var raw_setups: Variant = payload.get("scene_setups", [])
	if raw_setups is Array:
		result.scene_setups = raw_setups.duplicate(true)
	result.pause_reason = str(payload.get("pause_reason", ""))
	result.last_activity_message = str(
		payload.get("last_activity_message", "")
	)
	result.final_quality = clampi(
		int(payload.get("final_quality", 0)),
		0,
		100
	)
	result.seed = int(payload.get("seed", 0))
	result.rng_state = int(payload.get("rng_state", 0))
	result.started_day = maxi(int(payload.get("started_day", 1)), 1)
	result.started_hour = clampi(int(payload.get("started_hour", 8)), 0, 23)
	result.started_minute = clampi(
		int(payload.get("started_minute", 0)),
		0,
		59
	)
	return result
