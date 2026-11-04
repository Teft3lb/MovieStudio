extends RefCounted
class_name FilmProductionSystem

const PROJECT_DATA_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_project.gd"
)

const PREPARATION_MINUTES: int = 12
const REHEARSAL_BASE_MINUTES: int = 10
const REHEARSAL_MINUTES_PER_ACTOR: int = 3
const SHOOTING_BASE_MINUTES: int = 24
const SHOOTING_MINUTES_PER_ACTOR: int = 8
const REVIEW_MINUTES: int = 6
const RETAKE_BASE_MINUTES: int = 16
const RETAKE_MINUTES_PER_ACTOR: int = 5
const RETAKE_QUALITY_THRESHOLD: float = 58.0
const MAX_RETAKES_PER_SCENE: int = 2

var _rng: RandomNumberGenerator


func _init() -> void:
	_rng = RandomNumberGenerator.new()


func start_project(
	script: Variant,
	crew_assignments: Dictionary,
	cast_assignments: Dictionary,
	project_id: String,
	seed: int,
	current_day: int,
	current_hour: int,
	current_minute: int
) -> Variant:
	if script == null or script.scenes.is_empty() or script.cast.is_empty():
		return null
	if not _has_required_crew(crew_assignments):
		return null
	if not _has_complete_cast(script, cast_assignments):
		return null

	var project: Variant = PROJECT_DATA_SCRIPT.new()
	project.id = project_id
	project.script_id = str(script.id)
	project.film_title = str(script.title)
	project.genre_id = str(script.genre_id)
	project.genre_title = str(script.genre_title)
	project.script_potential_score = clampi(
		int(script.potential_score),
		0,
		100
	)
	project.script_potential_stars = clampi(
		int(script.potential_stars),
		1,
		5
	)
	project.total_scene_count = script.scenes.size()
	project.crew_assignments = crew_assignments.duplicate(true)
	project.cast_assignments = cast_assignments.duplicate(true)
	project.seed = seed
	project.started_day = maxi(current_day, 1)
	project.started_hour = clampi(current_hour, 0, 23)
	project.started_minute = clampi(current_minute, 0, 59)
	project.phase_duration_minutes = PREPARATION_MINUTES
	project.estimated_total_minutes = _estimate_total_minutes(
		script,
		cast_assignments
	)
	project.last_activity_message = "Подготовка съёмочной площадки."
	_rng.seed = seed
	project.rng_state = _rng.state
	return project


func advance_minute(
	project: Variant,
	script: Variant,
	crew_ready: bool,
	cast_ready: bool,
	performance_snapshot: Dictionary
) -> Dictionary:
	if project == null or str(project.status) != "in_production":
		return {
			"advanced": false,
			"phase_changed": false,
			"scene_completed": false,
			"completed": false,
			"retake_required": false,
		}

	if not crew_ready:
		project.pause_reason = "Ожидает режиссёра, оператора и техника на площадке."
		project.last_activity_message = project.pause_reason
		return _empty_advance_result()

	if not cast_ready:
		project.pause_reason = "Ожидает актёров на съёмочных позициях."
		project.last_activity_message = project.pause_reason
		return _empty_advance_result()

	project.pause_reason = ""
	project.phase_minutes_elapsed += 1
	project.total_elapsed_minutes += 1
	project.current_scene_elapsed_minutes += 1
	if project.phase_minutes_elapsed < project.phase_duration_minutes:
		return {
			"advanced": true,
			"phase_changed": false,
			"scene_completed": false,
			"completed": false,
			"retake_required": false,
		}

	var active_actor_count: int = get_scene_performer_ids(
		script,
		project
	).size()
	match str(project.current_phase):
		"preparation":
			_set_phase(
				project,
				"rehearsal",
				_get_phase_duration("rehearsal", active_actor_count)
			)
			project.last_activity_message = "Актёры репетируют сцену."
			return _phase_change_result()
		"rehearsal":
			_set_phase(
				project,
				"shooting",
				_get_phase_duration("shooting", active_actor_count)
			)
			project.last_activity_message = "Камера включена. Идёт съёмка дубля."
			return _phase_change_result()
		"shooting":
			_set_phase(project, "review", REVIEW_MINUTES)
			project.last_activity_message = "Дубль снят. Режиссёр просматривает материал."
			return _phase_change_result()
		"review":
			project.current_scene_quality = _calculate_scene_quality(
				project,
				performance_snapshot
			)
			if (
				project.current_scene_quality < RETAKE_QUALITY_THRESHOLD
				and project.current_scene_retakes < MAX_RETAKES_PER_SCENE
			):
				project.current_scene_retakes += 1
				var retake_duration: int = _get_phase_duration(
					"retake",
					active_actor_count
				)
				project.estimated_total_minutes += retake_duration
				_set_phase(project, "shooting", retake_duration)
				project.last_activity_message = (
					"Качество дубля %.0f/100. Нужна пересъёмка №%d."
					% [
						project.current_scene_quality,
						project.current_scene_retakes,
					]
				)
				var retake_result: Dictionary = _phase_change_result()
				retake_result["retake_required"] = true
				return retake_result

			_complete_current_scene(project, script)
			if project.completed_scene_count >= project.total_scene_count:
				project.status = "completed"
				project.final_quality = _calculate_final_quality(project)
				project.pause_reason = ""
				project.last_activity_message = (
					"Съёмки фильма «%s» завершены. Материал готов к монтажу."
					% project.film_title
				)
				return {
					"advanced": true,
					"phase_changed": true,
					"scene_completed": true,
					"completed": true,
					"retake_required": false,
					"scene_quality": project.current_scene_quality,
				}

			project.current_scene_index += 1
			project.current_scene_retakes = 0
			project.current_scene_quality = 0.0
			project.current_scene_elapsed_minutes = 0
			_set_phase(project, "preparation", PREPARATION_MINUTES)
			project.last_activity_message = (
				"Сцена %d завершена. Подготовка следующей сцены."
				% (project.current_scene_index + 1)
			)
			return {
				"advanced": true,
				"phase_changed": true,
				"scene_completed": true,
				"completed": false,
				"retake_required": false,
				"scene_quality": float(
					project.scene_results.back().get("quality", 0.0)
				),
			}

	return _empty_advance_result()


func get_current_scene(script: Variant, project: Variant) -> Dictionary:
	if script == null or project == null:
		return {}
	if project.current_scene_index < 0:
		return {}
	if project.current_scene_index >= script.scenes.size():
		return {}
	var scene: Dictionary = script.scenes[project.current_scene_index]
	return scene.duplicate(true)


func get_scene_performer_ids(
	script: Variant,
	project: Variant
) -> Array[String]:
	var result: Array[String] = []
	if script == null or project == null:
		return result

	var role_by_character: Dictionary = {}
	for cast_member in script.cast:
		var role_id: String = str(cast_member.get("role_id", ""))
		var character_name: String = str(
			cast_member.get("character_name", "")
		)
		if not role_id.is_empty() and not character_name.is_empty():
			role_by_character[character_name] = role_id

	var scene: Dictionary = get_current_scene(script, project)
	var scene_characters: Array = scene.get("characters", [])
	for character_name_value in scene_characters:
		var character_name: String = str(character_name_value)
		var role_id: String = str(
			role_by_character.get(character_name, "")
		)
		var employee_id: String = str(
			project.cast_assignments.get(role_id, "")
		)
		if not employee_id.is_empty() and not result.has(employee_id):
			result.append(employee_id)

	if result.is_empty():
		for cast_member in script.cast:
			var role_id: String = str(cast_member.get("role_id", ""))
			var employee_id: String = str(
				project.cast_assignments.get(role_id, "")
			)
			if not employee_id.is_empty() and not result.has(employee_id):
				result.append(employee_id)
	return result


func get_scene_dialogue_for_employee(
	script: Variant,
	project: Variant,
	employee_id: String
) -> String:
	var scene: Dictionary = get_current_scene(script, project)
	var dialogue: String = str(scene.get("dialogue", ""))
	if dialogue.is_empty():
		return ""
	var separator_index: int = dialogue.find(":")
	if separator_index < 0:
		return dialogue
	var speaker_name: String = dialogue.substr(0, separator_index).strip_edges()
	var spoken_text: String = dialogue.substr(separator_index + 1).strip_edges()
	for cast_member in script.cast:
		if str(cast_member.get("character_name", "")) != speaker_name:
			continue
		var role_id: String = str(cast_member.get("role_id", ""))
		if str(project.cast_assignments.get(role_id, "")) == employee_id:
			return spoken_text
	return ""


func _has_required_crew(crew_assignments: Dictionary) -> bool:
	for profession_id in ["director", "camera_operator", "technician"]:
		if str(crew_assignments.get(profession_id, "")).is_empty():
			return false
	return true


func _has_complete_cast(
	script: Variant,
	cast_assignments: Dictionary
) -> bool:
	for cast_member in script.cast:
		var role_id: String = str(cast_member.get("role_id", ""))
		if role_id.is_empty() or str(cast_assignments.get(role_id, "")).is_empty():
			return false
	return true


func _estimate_total_minutes(
	script: Variant,
	cast_assignments: Dictionary
) -> int:
	var total: int = 0
	for scene in script.scenes:
		var scene_data: Dictionary = scene
		var performer_count: int = _get_scene_performer_count(
			script,
			scene_data,
			cast_assignments
		)
		total += _get_phase_duration("preparation", performer_count)
		total += _get_phase_duration("rehearsal", performer_count)
		total += _get_phase_duration("shooting", performer_count)
		total += REVIEW_MINUTES
	return maxi(total, 1)


func _get_scene_performer_count(
	script: Variant,
	scene: Dictionary,
	cast_assignments: Dictionary
) -> int:
	var role_by_character: Dictionary = {}
	for cast_member in script.cast:
		role_by_character[str(cast_member.get("character_name", ""))] = str(
			cast_member.get("role_id", "")
		)
	var unique_ids: Array[String] = []
	for character_name_value in scene.get("characters", []):
		var role_id: String = str(
			role_by_character.get(str(character_name_value), "")
		)
		var employee_id: String = str(cast_assignments.get(role_id, ""))
		if not employee_id.is_empty() and not unique_ids.has(employee_id):
			unique_ids.append(employee_id)
	if unique_ids.is_empty():
		for employee_id_value in cast_assignments.values():
			var employee_id: String = str(employee_id_value)
			if not unique_ids.has(employee_id):
				unique_ids.append(employee_id)
	return maxi(unique_ids.size(), 1)


func _get_phase_duration(phase: String, actor_count: int) -> int:
	var normalized_actor_count: int = clampi(actor_count, 1, 8)
	match phase:
		"preparation":
			return PREPARATION_MINUTES
		"rehearsal":
			return REHEARSAL_BASE_MINUTES + (
				normalized_actor_count * REHEARSAL_MINUTES_PER_ACTOR
			)
		"shooting":
			return SHOOTING_BASE_MINUTES + (
				normalized_actor_count * SHOOTING_MINUTES_PER_ACTOR
			)
		"retake":
			return RETAKE_BASE_MINUTES + (
				normalized_actor_count * RETAKE_MINUTES_PER_ACTOR
			)
		_:
			return REVIEW_MINUTES


func _calculate_scene_quality(
	project: Variant,
	snapshot: Dictionary
) -> float:
	var acting: float = clampf(
		float(snapshot.get("acting_average", 45.0)),
		0.0,
		100.0
	)
	var directing: float = clampf(
		float(snapshot.get("directing", 45.0)),
		0.0,
		100.0
	)
	var camera: float = clampf(
		float(snapshot.get("camera_work", 45.0)),
		0.0,
		100.0
	)
	var technical: float = clampf(
		float(snapshot.get("technical", 45.0)),
		0.0,
		100.0
	)
	var energy: float = clampf(
		float(snapshot.get("energy", 0.75)),
		0.0,
		1.0
	)
	var morale: float = clampf(
		float(snapshot.get("morale", 0.75)),
		0.0,
		1.0
	)
	var stress: float = clampf(
		float(snapshot.get("stress", 0.15)),
		0.0,
		1.0
	)

	_rng.state = project.rng_state
	var variance: float = _rng.randf_range(-5.0, 5.0)
	project.rng_state = _rng.state

	var score: float = (
		acting * 0.30
		+ directing * 0.20
		+ camera * 0.16
		+ technical * 0.12
		+ float(project.script_potential_score) * 0.22
		+ (energy - 0.5) * 10.0
		+ (morale - 0.5) * 6.0
		- stress * 4.0
		+ variance
		+ float(project.current_scene_retakes) * 2.0
	)
	return clampf(score, 0.0, 100.0)


func _complete_current_scene(project: Variant, script: Variant) -> void:
	var scene: Dictionary = get_current_scene(script, project)
	var scene_duration: int = int(project.current_scene_elapsed_minutes)
	project.scene_results.append({
		"scene_id": str(scene.get("scene_id", "")),
		"scene_number": int(scene.get("scene_number", project.current_scene_index + 1)),
		"beat": str(scene.get("beat", "")),
		"location": str(scene.get("location", "")),
		"action": str(scene.get("action", "")),
		"dialogue": str(scene.get("dialogue", "")),
		"quality": roundi(project.current_scene_quality),
		"retakes": project.current_scene_retakes,
		"production_minutes": scene_duration,
	})
	project.completed_scene_count += 1


func _calculate_final_quality(project: Variant) -> int:
	if project.scene_results.is_empty():
		return 0
	var quality_total: float = 0.0
	for result in project.scene_results:
		quality_total += float(result.get("quality", 0.0))
	var average_scene_quality: float = quality_total / float(
		project.scene_results.size()
	)
	return roundi(clampf(
		average_scene_quality * 0.75
		+ float(project.script_potential_score) * 0.25,
		0.0,
		100.0
	))


func _set_phase(project: Variant, phase: String, duration: int) -> void:
	project.current_phase = phase
	project.phase_minutes_elapsed = 0
	project.phase_duration_minutes = maxi(duration, 1)


func _empty_advance_result() -> Dictionary:
	return {
		"advanced": false,
		"phase_changed": false,
		"scene_completed": false,
		"completed": false,
		"retake_required": false,
	}


func _phase_change_result() -> Dictionary:
	return {
		"advanced": true,
		"phase_changed": true,
		"scene_completed": false,
		"completed": false,
		"retake_required": false,
	}
