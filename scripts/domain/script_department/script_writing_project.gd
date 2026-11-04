extends RefCounted
class_name ScriptWritingProject

const SCHEMA_VERSION: int = 1

var id: String = ""
var script_id: String = ""
var writer_id: String = ""
var writer_name: String = ""
var genre_id: String = ""
var scene_count: int = 0
var role_count: int = 0
var seed: int = 0
var rng_state: int = 0
var required_work_minutes: int = 0
var completed_work_minutes: int = 0
var interruption_minutes_remaining: int = 0
var interruption_count: int = 0
var interruption_message: String = ""
var last_activity_message: String = ""
var status: String = "in_progress"
var started_day: int = 1
var started_hour: int = 8
var started_minute: int = 0


func get_progress_ratio() -> float:
	if required_work_minutes <= 0:
		return 0.0
	return clampf(
		float(completed_work_minutes) / float(required_work_minutes),
		0.0,
		1.0
	)


func get_progress_percent() -> float:
	return get_progress_ratio() * 100.0


func get_remaining_work_minutes() -> int:
	return maxi(required_work_minutes - completed_work_minutes, 0)


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"script_id": script_id,
		"writer_id": writer_id,
		"writer_name": writer_name,
		"genre_id": genre_id,
		"scene_count": scene_count,
		"role_count": role_count,
		"seed": seed,
		"rng_state": rng_state,
		"required_work_minutes": required_work_minutes,
		"completed_work_minutes": completed_work_minutes,
		"interruption_minutes_remaining": interruption_minutes_remaining,
		"interruption_count": interruption_count,
		"interruption_message": interruption_message,
		"last_activity_message": last_activity_message,
		"status": status,
		"started_day": started_day,
		"started_hour": started_hour,
		"started_minute": started_minute,
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/script_department/script_writing_project.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.script_id = str(payload.get("script_id", ""))
	result.writer_id = str(payload.get("writer_id", ""))
	result.writer_name = str(payload.get("writer_name", ""))
	result.genre_id = str(payload.get("genre_id", "drama"))
	result.scene_count = clampi(int(payload.get("scene_count", 0)), 0, 20)
	result.role_count = clampi(int(payload.get("role_count", 0)), 0, 8)
	result.seed = int(payload.get("seed", 0))
	result.rng_state = int(payload.get("rng_state", 0))
	result.required_work_minutes = maxi(
		int(payload.get("required_work_minutes", 0)),
		0
	)
	result.completed_work_minutes = clampi(
		int(payload.get("completed_work_minutes", 0)),
		0,
		result.required_work_minutes
	)
	result.interruption_minutes_remaining = maxi(
		int(payload.get("interruption_minutes_remaining", 0)),
		0
	)
	result.interruption_count = maxi(
		int(payload.get("interruption_count", 0)),
		0
	)
	result.interruption_message = str(
		payload.get("interruption_message", "")
	)
	result.last_activity_message = str(
		payload.get("last_activity_message", "")
	)
	result.status = str(payload.get("status", "in_progress"))
	result.started_day = maxi(int(payload.get("started_day", 1)), 1)
	result.started_hour = clampi(int(payload.get("started_hour", 8)), 0, 23)
	result.started_minute = clampi(
		int(payload.get("started_minute", 0)),
		0,
		59
	)
	return result
