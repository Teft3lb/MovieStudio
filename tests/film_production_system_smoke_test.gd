extends SceneTree

const FILM_SCRIPT_DATA_SCRIPT = preload(
	"res://scripts/domain/script_department/film_script_data.gd"
)
const FILM_PRODUCTION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_system.gd"
)
const FILM_PRODUCTION_PROJECT_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_project.gd"
)


func _initialize() -> void:
	var script: Variant = _create_script()
	var system: RefCounted = FILM_PRODUCTION_SYSTEM_SCRIPT.new()
	var crew_assignments: Dictionary = {
		"director": "EMP-DIRECTOR",
		"camera_operator": "EMP-CAMERA",
		"technician": "EMP-TECHNICIAN",
	}
	var cast_assignments: Dictionary = {
		"ROLE-01": "EMP-ACTOR-01",
		"ROLE-02": "EMP-ACTOR-02",
	}
	var project: Variant = system.call(
		"start_project",
		script,
		crew_assignments,
		cast_assignments,
		"FILM-SMOKE-01",
		998877,
		1,
		8,
		0
	)

	assert(project != null, "A valid script and crew must start production.")
	_test_scene_cast_resolution(system, script, project)
	_test_production_pause(system, script, project)
	_test_project_serialization(project)
	_test_full_film_completion(system, script, project)
	_test_retake_limit()

	var incomplete_cast: Dictionary = {"ROLE-01": "EMP-ACTOR-01"}
	var rejected_project: Variant = system.call(
		"start_project",
		script,
		crew_assignments,
		incomplete_cast,
		"FILM-INVALID-01",
		1,
		1,
		8,
		0
	)
	assert(
		rejected_project == null,
		"Production must reject scripts with unassigned roles."
	)

	print("FilmProductionSystemSmokeTest: PASS")
	quit(0)


func _create_script() -> Variant:
	var script: Variant = FILM_SCRIPT_DATA_SCRIPT.new()
	script.id = "SCR-FILM-01"
	script.title = "Последний маяк"
	script.genre_id = "adventure"
	script.genre_title = "Приключения"
	script.scene_count = 2
	script.role_count = 2
	script.potential_score = 86
	script.potential_stars = 4
	script.cast = [
		{
			"role_id": "ROLE-01",
			"role_title": "Главный герой",
			"character_name": "Алиса Мерсер",
		},
		{
			"role_id": "ROLE-02",
			"role_title": "Союзник",
			"character_name": "Томас Уинслоу",
		},
	]
	script.scenes = [
		{
			"scene_id": "SCN-01",
			"scene_number": 1,
			"beat": "Завязка",
			"location": "Старый маяк",
			"action": "Герои обнаруживают странный сигнал.",
			"dialogue": "Алиса Мерсер: «Ты тоже это слышал?»",
			"characters": ["Алиса Мерсер", "Томас Уинслоу"],
		},
		{
			"scene_id": "SCN-02",
			"scene_number": 2,
			"beat": "Кульминация",
			"location": "Верхняя площадка маяка",
			"action": "Герои принимают решение перед последним испытанием.",
			"dialogue": "Томас Уинслоу: «Тогда сделаем это вместе.»",
			"characters": ["Алиса Мерсер", "Томас Уинслоу"],
		},
	]
	return script


func _test_scene_cast_resolution(
	system: RefCounted,
	script: Variant,
	project: Variant
) -> void:
	var performers: Array = system.call(
		"get_scene_performer_ids",
		script,
		project
	)
	assert(
		performers.size() == 2,
		"Every distinct performer present in a scene must be resolved."
	)
	assert(
		str(performers[0]) == "EMP-ACTOR-01"
		and str(performers[1]) == "EMP-ACTOR-02",
		"Scene characters must map to their assigned employees."
	)
	assert(
		str(
			system.call(
				"get_scene_dialogue_for_employee",
				script,
				project,
				"EMP-ACTOR-01"
			)
		).contains("Ты тоже это слышал"),
		"The speaking actor must receive the scene dialogue."
	)


func _test_production_pause(
	system: RefCounted,
	script: Variant,
	project: Variant
) -> void:
	var before: int = int(project.total_elapsed_minutes)
	var result: Dictionary = system.call(
		"advance_minute",
		project,
		script,
		false,
		true,
		{}
	)
	assert(
		not bool(result.get("advanced", false)),
		"Production must pause when a required crew member is unavailable."
	)
	assert(
		int(project.total_elapsed_minutes) == before,
		"Paused production must not consume film production time."
	)
	assert(
		not str(project.pause_reason).is_empty(),
		"Paused production must explain why it is waiting."
	)


func _test_project_serialization(project: Variant) -> void:
	var payload: Dictionary = project.to_dict()
	var restored: Variant = FILM_PRODUCTION_PROJECT_SCRIPT.from_dict(payload)
	assert(
		restored.to_dict() == payload,
		"Production phase, assignments and timing must survive serialization."
	)


func _test_retake_limit() -> void:
	var script: Variant = _create_script()
	script.scenes = [script.scenes[0]]
	script.scene_count = 1
	var system: RefCounted = FILM_PRODUCTION_SYSTEM_SCRIPT.new()
	var crew_assignments: Dictionary = {
		"director": "EMP-DIRECTOR",
		"camera_operator": "EMP-CAMERA",
		"technician": "EMP-TECHNICIAN",
	}
	var cast_assignments: Dictionary = {
		"ROLE-01": "EMP-ACTOR-01",
		"ROLE-02": "EMP-ACTOR-02",
	}
	var project: Variant = system.call(
		"start_project",
		script,
		crew_assignments,
		cast_assignments,
		"FILM-RETAKE-01",
		112233,
		1,
		8,
		0
	)
	var poor_snapshot: Dictionary = {
		"acting_average": 0.0,
		"directing": 0.0,
		"camera_work": 0.0,
		"technical": 0.0,
		"energy": 0.0,
		"morale": 0.0,
		"stress": 1.0,
	}
	for _minute_index in range(1000):
		if str(project.status) == "completed":
			break
		system.call(
			"advance_minute",
			project,
			script,
			true,
			true,
			poor_snapshot
		)

	assert(
		str(project.status) == "completed",
		"A scene with repeated low-quality takes must still reach a final result."
	)
	assert(
		int(project.scene_results[0].get("retakes", 0)) == 2,
		"Low-quality scenes must request no more than two retakes."
	)
	assert(
		int(project.total_elapsed_minutes) == int(project.estimated_total_minutes),
		"Retake and review time must be included in the final schedule estimate."
	)


func _test_full_film_completion(
	system: RefCounted,
	script: Variant,
	project: Variant
) -> void:
	var snapshot: Dictionary = {
		"acting_average": 92.0,
		"directing": 90.0,
		"camera_work": 88.0,
		"technical": 86.0,
		"energy": 0.95,
		"morale": 0.92,
		"stress": 0.05,
	}
	var phases_seen: Dictionary = {}
	for _minute_index in range(5000):
		if str(project.status) == "completed":
			break
		phases_seen[str(project.current_phase)] = true
		system.call(
			"advance_minute",
			project,
			script,
			true,
			true,
			snapshot
		)

	assert(
		str(project.status) == "completed",
		"Every scene must eventually finish and complete the film."
	)
	assert(
		int(project.completed_scene_count) == 2
		and project.scene_results.size() == 2,
		"Every scripted scene must have a recorded production result."
	)
	assert(
		int(project.final_quality) >= 0
		and int(project.final_quality) <= 100,
		"Final film quality must be bounded from 0 to 100."
	)
	assert(
		float(project.get_progress_percent()) == 100.0,
		"A completed film must report 100 percent production progress."
	)
	assert(
		int(project.get_remaining_work_minutes()) == 0,
		"A completed film must have no remaining production time."
	)
	for phase in ["preparation", "rehearsal", "shooting", "review"]:
		assert(
			phases_seen.has(phase),
			"Every scene must pass through the %s phase." % phase
		)
	assert(
		int(project.scene_results[0].get("production_minutes", 0)) > 0,
		"Scene results must retain actual elapsed production time."
	)
