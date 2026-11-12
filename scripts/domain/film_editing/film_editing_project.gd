extends RefCounted
class_name FilmEditingProject

const SCHEMA_VERSION: int = 2

var id: String = ""
var production_project_id: String = ""
var film_title: String = ""
var genre_id: String = ""
var genre_title: String = ""

var status: String = "draft"
var current_phase: String = ""
var phase_minutes_elapsed: int = 0
var phase_duration_minutes: int = 0
var total_elapsed_minutes: int = 0
var estimated_total_minutes: int = 0
var work_minutes_per_day: int = 480
var phase_duration_multiplier: float = 1.0

var editor_id: String = ""
var editor_skill: float = 0.0
var source_quality: int = 0
var final_quality: int = 0
var continuity_score: int = 100

var scene_results: Array = []
var timeline_order: Array[int] = []

var pause_reason: String = ""
var last_activity_message: String = ""
var started_day: int = 1
var started_hour: int = 8
var started_minute: int = 0


func get_progress_percent() -> float:
	if status == "completed":
		return 100.0
	if status != "in_editing" or estimated_total_minutes <= 0:
		return 0.0
	return clampf(
		float(total_elapsed_minutes) / float(estimated_total_minutes) * 100.0,
		0.0,
		99.9
	)


func get_remaining_work_minutes() -> int:
	return maxi(estimated_total_minutes - total_elapsed_minutes, 0)


func get_estimated_work_days() -> float:
	return float(estimated_total_minutes) / float(maxi(work_minutes_per_day, 1))


func get_elapsed_work_days() -> float:
	return float(total_elapsed_minutes) / float(maxi(work_minutes_per_day, 1))


func get_remaining_work_days() -> float:
	return float(get_remaining_work_minutes()) / float(maxi(work_minutes_per_day, 1))


func get_phase_title() -> String:
	match current_phase:
		"assembly_cut":
			return "Черновая сборка"
		"fine_cut":
			return "Чистовой монтаж"
		"sound_mix":
			return "Сведение звука"
		"color_grading":
			return "Цветокоррекция"
		"export":
			return "Финальный экспорт"
		_:
			return "Ожидает начала монтажа" if status == "draft" else "Монтаж завершён"


func get_status_title() -> String:
	match status:
		"draft":
			return "Таймлайн подготовлен"
		"in_editing":
			return "В монтаже"
		"completed":
			return "Фильм смонтирован"
		_:
			return "Неизвестный статус"


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"production_project_id": production_project_id,
		"film_title": film_title,
		"genre_id": genre_id,
		"genre_title": genre_title,
		"status": status,
		"current_phase": current_phase,
		"phase_minutes_elapsed": phase_minutes_elapsed,
		"phase_duration_minutes": phase_duration_minutes,
		"total_elapsed_minutes": total_elapsed_minutes,
		"estimated_total_minutes": estimated_total_minutes,
		"work_minutes_per_day": work_minutes_per_day,
		"phase_duration_multiplier": phase_duration_multiplier,
		"editor_id": editor_id,
		"editor_skill": editor_skill,
		"source_quality": source_quality,
		"final_quality": final_quality,
		"continuity_score": continuity_score,
		"scene_results": scene_results.duplicate(true),
		"timeline_order": timeline_order.duplicate(),
		"pause_reason": pause_reason,
		"last_activity_message": last_activity_message,
		"started_day": started_day,
		"started_hour": started_hour,
		"started_minute": started_minute,
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/film_editing/film_editing_project.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.production_project_id = str(payload.get("production_project_id", ""))
	result.film_title = str(payload.get("film_title", ""))
	result.genre_id = str(payload.get("genre_id", ""))
	result.genre_title = str(payload.get("genre_title", ""))
	result.status = str(payload.get("status", "draft"))
	result.current_phase = str(payload.get("current_phase", ""))
	result.phase_minutes_elapsed = maxi(int(payload.get("phase_minutes_elapsed", 0)), 0)
	result.phase_duration_minutes = maxi(int(payload.get("phase_duration_minutes", 0)), 0)
	result.total_elapsed_minutes = maxi(int(payload.get("total_elapsed_minutes", 0)), 0)
	result.estimated_total_minutes = maxi(int(payload.get("estimated_total_minutes", 0)), 0)
	result.work_minutes_per_day = clampi(
		int(payload.get("work_minutes_per_day", 480)),
		60,
		1440
	)
	result.phase_duration_multiplier = clampf(
		float(payload.get("phase_duration_multiplier", 1.0)),
		1.0,
		60.0
	)
	result.editor_id = str(payload.get("editor_id", ""))
	result.editor_skill = clampf(float(payload.get("editor_skill", 0.0)), 0.0, 100.0)
	result.source_quality = clampi(int(payload.get("source_quality", 0)), 0, 100)
	result.final_quality = clampi(int(payload.get("final_quality", 0)), 0, 100)
	result.continuity_score = clampi(int(payload.get("continuity_score", 100)), 0, 100)

	var raw_scenes: Variant = payload.get("scene_results", [])
	if raw_scenes is Array:
		result.scene_results = raw_scenes.duplicate(true)

	var raw_order: Variant = payload.get("timeline_order", [])
	if raw_order is Array:
		var seen: Dictionary = {}
		for raw_index in raw_order:
			var scene_index: int = int(raw_index)
			if (
				scene_index >= 0
				and scene_index < result.scene_results.size()
				and not seen.has(scene_index)
			):
				result.timeline_order.append(scene_index)
				seen[scene_index] = true
	if result.timeline_order.size() != result.scene_results.size():
		result.timeline_order.clear()
		for scene_index in range(result.scene_results.size()):
			result.timeline_order.append(scene_index)

	result.pause_reason = str(payload.get("pause_reason", ""))
	result.last_activity_message = str(payload.get("last_activity_message", ""))
	result.started_day = maxi(int(payload.get("started_day", 1)), 1)
	result.started_hour = clampi(int(payload.get("started_hour", 8)), 0, 23)
	result.started_minute = clampi(int(payload.get("started_minute", 0)), 0, 59)
	return result
