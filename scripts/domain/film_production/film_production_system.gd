extends RefCounted
class_name FilmProductionSystem

const PROJECT_DATA_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_project.gd"
)
const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)

const PREPARATION_MINUTES: int = 2
const SET_DRESSING_BASE_MINUTES: int = 2
const SET_DRESSING_MINUTES_PER_PROP: int = 1
const REHEARSAL_BASE_MINUTES: int = 2
const REHEARSAL_MINUTES_PER_ACTOR: int = 1
const SHOOTING_BASE_MINUTES: int = 8
const SHOOTING_MINUTES_PER_ACTOR: int = 1
const REVIEW_MINUTES: int = 1
const RETAKE_BASE_MINUTES: int = 4
const RETAKE_MINUTES_PER_ACTOR: int = 1
const RETAKE_QUALITY_THRESHOLD: float = 58.0
const MAX_RETAKES_PER_SCENE: int = 2

var _rng: RandomNumberGenerator


func _init() -> void:
	_rng = RandomNumberGenerator.new()


func can_start_project(
	script: Variant,
	crew_assignments: Dictionary,
	cast_assignments: Dictionary
) -> bool:
	if script == null or script.scenes.is_empty() or script.cast.is_empty():
		return false
	return (
		_has_required_crew(crew_assignments)
		and _has_complete_cast(script, cast_assignments)
	)


func start_project(
	script: Variant,
	crew_assignments: Dictionary,
	cast_assignments: Dictionary,
	project_id: String,
	seed: int,
	current_day: int,
	current_hour: int,
	current_minute: int,
	scene_setups: Array = []
) -> Variant:
	if not can_start_project(script, crew_assignments, cast_assignments):
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
	project.scene_setups = _normalize_scene_setups(
		script.scenes,
		scene_setups
	)
	project.seed = seed
	project.started_day = maxi(current_day, 1)
	project.started_hour = clampi(current_hour, 0, 23)
	project.started_minute = clampi(current_minute, 0, 59)
	project.phase_duration_minutes = PREPARATION_MINUTES
	project.estimated_total_minutes = _estimate_total_minutes(
		script,
		cast_assignments,
		project.scene_setups
	)
	project.last_activity_message = "Съёмочная группа собирается на площадке."
	_rng.seed = seed
	project.rng_state = _rng.state
	return project


func refresh_current_scene_setup(
	project: Variant,
	script: Variant,
	owned_prop_ids: Array[String]
) -> Dictionary:
	if (
		project == null
		or script == null
		or str(project.status) != "in_production"
	):
		return {}
	var current_phase: String = str(project.current_phase)
	if (
		current_phase != "preparation"
		and not (
			current_phase == "set_dressing"
			and int(project.phase_minutes_elapsed) == 0
		)
	):
		return {}
	var scene_index: int = int(project.current_scene_index)
	if (
		scene_index < 0
		or scene_index >= script.scenes.size()
		or scene_index >= project.scene_setups.size()
	):
		return {}

	var scene: Dictionary = script.scenes[scene_index]
	var fresh_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		[scene],
		owned_prop_ids,
		str(script.genre_id)
	)
	if fresh_setups.is_empty():
		return {}
	var normalized_setups: Array = _normalize_scene_setups(
		[scene],
		fresh_setups
	)
	if normalized_setups.is_empty() or not (normalized_setups[0] is Dictionary):
		return {}
	var refreshed_setup: Dictionary = normalized_setups[0]
	var previous_setup: Dictionary = project.get_current_scene_setup()
	var previous_duration: int = clampi(
		int(previous_setup.get("setup_minutes", SET_DRESSING_BASE_MINUTES)),
		SET_DRESSING_BASE_MINUTES,
		10
	)
	var refreshed_duration: int = clampi(
		int(refreshed_setup.get("setup_minutes", SET_DRESSING_BASE_MINUTES)),
		SET_DRESSING_BASE_MINUTES,
		10
	)
	project.scene_setups[scene_index] = refreshed_setup.duplicate(true)
	if current_phase == "set_dressing":
		project.phase_duration_minutes = refreshed_duration
	project.last_activity_message = (
		"Комплект декораций обновлён по текущему инвентарю."
	)
	project.estimated_total_minutes = maxi(
		int(project.estimated_total_minutes)
		+ refreshed_duration
		- previous_duration,
		int(project.total_elapsed_minutes) + 1
	)
	return refreshed_setup.duplicate(true)


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

	var cast_required: bool = str(project.current_phase) in [
		"rehearsal",
		"shooting",
		"review",
	]
	if cast_required and not cast_ready:
		project.pause_reason = "Ожидает актёров на позициях и освобождения кадра."
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
			var setup: Dictionary = project.get_current_scene_setup()
			var setup_duration: int = clampi(
				int(setup.get("setup_minutes", SET_DRESSING_BASE_MINUTES)),
				SET_DRESSING_BASE_MINUTES,
				10
			)
			_set_phase(project, "set_dressing", setup_duration)
			project.last_activity_message = (
				"Техник собирает декорации: %s."
				% str(setup.get("set_title", "Нейтральная площадка"))
			)
			return _phase_change_result()
		"set_dressing":
			_set_phase(
				project,
				"rehearsal",
				_get_phase_duration("rehearsal", active_actor_count)
			)
			project.last_activity_message = "Декорации готовы. Актёры репетируют сцену."
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
				project.estimated_total_minutes += (
					retake_duration + REVIEW_MINUTES
				)
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


func _normalize_scene_setups(
	scenes: Array,
	raw_setups: Array
) -> Array:
	var result: Array = []
	for scene_index in range(scenes.size()):
		var scene: Dictionary = scenes[scene_index]
		var setup: Dictionary = {}
		if (
			scene_index < raw_setups.size()
			and raw_setups[scene_index] is Dictionary
		):
			setup = raw_setups[scene_index].duplicate(true)
		var raw_prop_ids: Variant = setup.get("prop_ids", [])
		var prop_ids: Array = []
		if raw_prop_ids is Array:
			prop_ids = raw_prop_ids
		var normalized_props: Array[String] = []
		for prop_id_value in prop_ids:
			var prop_id: String = str(prop_id_value)
			if not prop_id.is_empty() and not normalized_props.has(prop_id):
				normalized_props.append(prop_id)

		var raw_required_prop_ids: Variant = setup.get(
			"required_prop_ids",
			normalized_props
		)
		var normalized_required_props: Array[String] = []
		if raw_required_prop_ids is Array:
			for prop_id_value in raw_required_prop_ids:
				var prop_id: String = str(prop_id_value)
				if (
					not prop_id.is_empty()
					and not normalized_required_props.has(prop_id)
				):
					normalized_required_props.append(prop_id)

		var raw_missing_prop_ids: Variant = setup.get("missing_prop_ids", [])
		var normalized_missing_props: Array[String] = []
		if raw_missing_prop_ids is Array:
			for prop_id_value in raw_missing_prop_ids:
				var prop_id: String = str(prop_id_value)
				if (
					not prop_id.is_empty()
					and not normalized_missing_props.has(prop_id)
				):
					normalized_missing_props.append(prop_id)

		setup["scene_id"] = str(
			setup.get("scene_id", scene.get("scene_id", ""))
		)
		setup["set_id"] = str(setup.get("set_id", "neutral"))
		setup["set_title"] = str(
			setup.get("set_title", "Нейтральная площадка")
		)
		setup["prop_ids"] = normalized_props
		setup["required_prop_ids"] = normalized_required_props
		setup["missing_prop_ids"] = normalized_missing_props
		setup["setup_minutes"] = clampi(
			int(setup.get(
				"setup_minutes",
				SET_DRESSING_BASE_MINUTES
				+ normalized_props.size() * SET_DRESSING_MINUTES_PER_PROP
			)),
			SET_DRESSING_BASE_MINUTES,
			10
		)
		setup["set_dressing_quality"] = clampf(
			float(setup.get("set_dressing_quality", 45.0)),
			0.0,
			100.0
		)
		result.append(setup)
	return result


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
	cast_assignments: Dictionary,
	scene_setups: Array
) -> int:
	var total: int = 0
	for scene_index in range(script.scenes.size()):
		var scene_data: Dictionary = script.scenes[scene_index]
		var performer_count: int = _get_scene_performer_count(
			script,
			scene_data,
			cast_assignments
		)
		var setup: Dictionary = scene_setups[scene_index]
		total += _get_phase_duration("preparation", performer_count)
		total += clampi(
			int(setup.get("setup_minutes", SET_DRESSING_BASE_MINUTES)),
			SET_DRESSING_BASE_MINUTES,
			10
		)
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
		"set_dressing":
			return SET_DRESSING_BASE_MINUTES
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
		+ (
			float(project.get_current_scene_setup().get(
				"set_dressing_quality",
				45.0
			)) - 45.0
		) * 0.14
		+ (energy - 0.5) * 10.0
		+ (morale - 0.5) * 6.0
		- stress * 4.0
		+ variance
		+ float(project.current_scene_retakes) * 2.0
	)
	return clampf(score, 0.0, 100.0)


func _complete_current_scene(project: Variant, script: Variant) -> void:
	var scene: Dictionary = get_current_scene(script, project)
	var setup: Dictionary = project.get_current_scene_setup()
	var setup_props: Array = setup.get("prop_ids", [])
	var required_props: Array = setup.get("required_prop_ids", setup_props)
	var missing_props: Array = setup.get("missing_prop_ids", [])
	var scene_duration: int = int(project.current_scene_elapsed_minutes)
	project.scene_results.append({
		"scene_id": str(scene.get("scene_id", "")),
		"scene_number": int(scene.get("scene_number", project.current_scene_index + 1)),
		"beat": str(scene.get("beat", "")),
		"location": str(scene.get("location", "")),
		"action": str(scene.get("action", "")),
		"dialogue": str(scene.get("dialogue", "")),
		"set_id": str(setup.get("set_id", "neutral")),
		"set_title": str(setup.get("set_title", "Нейтральная площадка")),
		"set_dressing_quality": float(
			setup.get("set_dressing_quality", 45.0)
		),
		"set_dressing_props": setup_props.duplicate(),
		"required_prop_ids": required_props.duplicate(),
		"missing_prop_ids": missing_props.duplicate(),
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
