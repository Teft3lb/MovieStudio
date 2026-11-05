extends "res://tests/smoke_test_base.gd"

const FILM_SCRIPT_DATA_SCRIPT = preload(
	"res://scripts/domain/script_department/film_script_data.gd"
)
const FILM_PRODUCTION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_system.gd"
)
const FILM_PRODUCTION_PROJECT_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_project.gd"
)
const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
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

	_expect(project != null, "A valid script and crew must start production.")
	_expect(
		bool(system.call("can_start_project", script, crew_assignments, cast_assignments)),
		"A complete script, cast and crew must be startable without waiting for a shift change."
	)
	_test_quick_production_pacing(script, crew_assignments, cast_assignments)
	_test_multiple_technicians_reduce_logistics_time(
		script,
		crew_assignments,
		cast_assignments
	)
	_test_missing_props_do_not_block_production(
		system,
		script,
		crew_assignments,
		cast_assignments
	)
	_test_late_prop_purchases_update_unprepared_scenes(
		system,
		script,
		crew_assignments,
		cast_assignments
	)
	_test_scene_cast_resolution(system, script, project)
	_test_production_pause(system, script, project)
	_test_cast_can_wait_during_set_preparation(
		system,
		script,
		crew_assignments,
		cast_assignments
	)
	_test_mid_phase_progress(system, script, project)
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
	_expect(
		rejected_project == null,
		"Production must reject scripts with unassigned roles."
	)
	_expect(
		not bool(system.call("can_start_project", script, crew_assignments, incomplete_cast)),
		"Production start validation must reject incomplete casting."
	)

	_finish_test("FilmProductionSystemSmokeTest")


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


func _test_missing_props_do_not_block_production(
	system: RefCounted,
	script: Variant,
	crew_assignments: Dictionary,
	cast_assignments: Dictionary
) -> void:
	var no_owned_props: Array[String] = []
	var scene_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		script.scenes,
		no_owned_props,
		str(script.genre_id)
	)
	var project: Variant = system.call(
		"start_project",
		script,
		crew_assignments,
		cast_assignments,
		"FILM-NO-PROPS",
		123456,
		1,
		8,
		0,
		scene_setups
	)
	_expect(
		project != null,
		"A film must remain startable when the studio has not purchased its required props."
	)
	_expect(
		project != null
		and project.scene_setups[0].get("missing_prop_ids", []).size() == 3
		and float(project.scene_setups[0].get("set_dressing_quality", 100.0)) < 45.0,
		"Missing set pieces must be recorded and lower scene set-dressing quality."
	)


func _test_late_prop_purchases_update_unprepared_scenes(
	system: RefCounted,
	script: Variant,
	crew_assignments: Dictionary,
	cast_assignments: Dictionary
) -> void:
	var no_owned_props: Array[String] = []
	var initial_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		script.scenes,
		no_owned_props,
		str(script.genre_id)
	)
	var project: Variant = system.call(
		"start_project",
		script,
		crew_assignments,
		cast_assignments,
		"FILM-LATE-PROP-PURCHASE",
		771122,
		1,
		8,
		0,
		initial_setups
	)
	var initial_estimate: int = int(project.estimated_total_minutes)
	var first_purchase: Array[String] = ["lighthouse_console"]
	var refreshed: Dictionary = system.call(
		"refresh_current_scene_setup",
		project,
		script,
		first_purchase
	)
	_expect(
		refreshed.get("prop_ids", []).size() == 1
		and refreshed.get("missing_prop_ids", []).size() == 2
		and int(refreshed.get("setup_minutes", 0)) == 3
		and int(refreshed.get("set_dressing_quality", 0)) == 32,
		"A prop purchased after production starts must update the current scene while it is still in preparation."
	)
	_expect(
		int(project.estimated_total_minutes) == initial_estimate + 2,
		"Refreshing an unprepared scene must update both installation and later strike time."
	)

	var snapshot: Dictionary = {
		"acting_average": 90.0,
		"directing": 90.0,
		"camera_work": 90.0,
		"technical": 90.0,
		"energy": 0.95,
		"morale": 0.95,
		"stress": 0.05,
	}
	for _minute in range(2):
		system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		str(project.current_phase) == "set_dressing"
		and int(project.phase_duration_minutes) == 3,
		"The current scene must use the newly purchased prop when its set-dressing phase begins."
	)

	var two_props: Array[String] = [
		"lighthouse_console",
		"lighthouse_beacon",
	]
	var zero_progress_refresh: Dictionary = system.call(
		"refresh_current_scene_setup",
		project,
		script,
		two_props
	)
	_expect(
		zero_progress_refresh.get("prop_ids", []).size() == 2
		and int(zero_progress_refresh.get("setup_minutes", 0)) == 4
		and int(zero_progress_refresh.get("set_dressing_quality", 0)) == 48
		and int(project.phase_duration_minutes) == 4,
		"A purchase made before the first set-dressing minute must still update the current scene."
	)
	system.call("advance_minute", project, script, true, true, snapshot)
	var complete_inventory: Array[String] = [
		"lighthouse_console",
		"lighthouse_beacon",
		"lighthouse_rail",
	]
	var late_refresh: Dictionary = system.call(
		"refresh_current_scene_setup",
		project,
		script,
		complete_inventory
	)
	_expect(
		late_refresh.is_empty()
		and project.scene_setups[0].get("prop_ids", []).size() == 2,
		"Purchases after the first set-dressing minute must not change the active scene's locked setup."
	)

	for _minute in range(3):
		system.call("advance_minute", project, script, true, true, snapshot)
	for _minute in range(4):
		system.call("advance_minute", project, script, true, true, snapshot)
	for _minute in range(10):
		system.call("advance_minute", project, script, true, true, snapshot)
	system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		str(project.current_phase) == "set_strike"
		and int(project.phase_duration_minutes) == 3,
		"Two installed props must require a three-minute strike with one technician."
	)
	for _minute in range(3):
		system.call("advance_minute", project, script, true, true, snapshot)

	_expect(
		int(project.current_scene_index) == 1
		and str(project.current_phase) == "preparation"
		and project.scene_results.size() == 1,
		"The next scene must become editable after the previous scene is completed."
	)
	var next_scene_setup: Dictionary = system.call(
		"refresh_current_scene_setup",
		project,
		script,
		complete_inventory
	)
	_expect(
		next_scene_setup.get("prop_ids", []).size() == 3
		and next_scene_setup.get("missing_prop_ids", []).is_empty()
		and int(next_scene_setup.get("setup_minutes", 0)) == 5
		and int(next_scene_setup.get("set_dressing_quality", 0)) == 62,
		"A later scene must automatically use every matching prop purchased before its own set-dressing phase."
	)
	_expect(
		project.scene_results[0].get("set_dressing_props", []).size() == 2
		and project.scene_results[0].get("missing_prop_ids", []).size() == 1,
		"Later purchases must not retroactively rewrite the completed scene's recorded set."
	)
	_expect(
		int(project.estimated_total_minutes) == initial_estimate + 10,
		"Newly purchased props must update only the remaining scene setup estimate."
	)


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
	_expect(
		performers.size() == 2,
		"Every distinct performer present in a scene must be resolved."
	)
	_expect(
		str(performers[0]) == "EMP-ACTOR-01"
		and str(performers[1]) == "EMP-ACTOR-02",
		"Scene characters must map to their assigned employees."
	)
	_expect(
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
	var saved_phase: String = str(project.current_phase)
	var saved_phase_elapsed: int = int(project.phase_minutes_elapsed)
	var saved_phase_duration: int = int(project.phase_duration_minutes)
	var saved_scene_elapsed: int = int(project.current_scene_elapsed_minutes)
	var saved_estimated_total: int = int(project.estimated_total_minutes)
	var saved_pause_reason: String = str(project.pause_reason)
	var saved_activity_message: String = str(project.last_activity_message)
	var result: Dictionary = system.call(
		"advance_minute",
		project,
		script,
		false,
		true,
		{}
	)
	_expect(
		not bool(result.get("advanced", false)),
		"Production must pause when a required crew member is unavailable."
	)
	_expect(
		int(project.total_elapsed_minutes) == before,
		"Paused production must not consume film production time."
	)
	_expect(
		not str(project.pause_reason).is_empty(),
		"Paused production must explain why it is waiting."
	)
	var resumed: Dictionary = system.call(
		"advance_minute",
		project,
		script,
		true,
		true,
		{}
	)
	_expect(
		bool(resumed.get("advanced", false))
		and int(project.total_elapsed_minutes) == before + 1
		and str(project.pause_reason).is_empty(),
		"Production must automatically resume from the same phase when the required crew becomes available again."
	)
	project.current_phase = saved_phase
	project.phase_minutes_elapsed = saved_phase_elapsed
	project.phase_duration_minutes = saved_phase_duration
	project.current_scene_elapsed_minutes = saved_scene_elapsed
	project.total_elapsed_minutes = before
	project.estimated_total_minutes = saved_estimated_total
	project.pause_reason = saved_pause_reason
	project.last_activity_message = saved_activity_message



func _test_cast_can_wait_during_set_preparation(
	system: RefCounted,
	script: Variant,
	crew_assignments: Dictionary,
	cast_assignments: Dictionary
) -> void:
	var no_owned_props: Array[String] = []
	var scene_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		script.scenes,
		no_owned_props,
		str(script.genre_id)
	)
	var project: Variant = system.call(
		"start_project",
		script,
		crew_assignments,
		cast_assignments,
		"FILM-CAST-WAIT-TEST",
		445566,
		1,
		8,
		0,
		scene_setups
	)
	_expect(project != null, "A separate project must be created for cast waiting tests.")
	if project == null:
		return

	var advanced_during_preparation: Dictionary = system.call(
		"advance_minute",
		project,
		script,
		true,
		false,
		{}
	)
	_expect(
		bool(advanced_during_preparation.get("advanced", false))
		and str(project.current_phase) == "preparation",
		"Cast must not be required on set while the director and crew prepare the stage."
	)
	var preparation_complete: Dictionary = system.call(
		"advance_minute",
		project,
		script,
		true,
		false,
		{}
	)
	_expect(
		bool(preparation_complete.get("phase_changed", false))
		and str(project.current_phase) == "set_dressing",
		"Set dressing must begin even while the cast is away from the stage."
	)
	var first_dressing_minute: Dictionary = system.call(
		"advance_minute",
		project,
		script,
		true,
		false,
		{}
	)
	var second_dressing_minute: Dictionary = system.call(
		"advance_minute",
		project,
		script,
		true,
		false,
		{}
	)
	_expect(
		bool(first_dressing_minute.get("advanced", false))
		and bool(second_dressing_minute.get("phase_changed", false))
		and str(project.current_phase) == "rehearsal",
		"The technician must be able to finish set dressing before actors are called."
	)
	var rehearsal_wait: Dictionary = system.call(
		"advance_minute",
		project,
		script,
		true,
		false,
		{}
	)
	_expect(
		not bool(rehearsal_wait.get("advanced", false))
		and int(project.total_elapsed_minutes) == 4
		and str(project.pause_reason).contains("актёров"),
		"Production must wait for the cast only when rehearsal is ready to begin."
	)


func _test_mid_phase_progress(
	system: RefCounted,
	script: Variant,
	project: Variant
) -> void:
	var snapshot: Dictionary = {
		"acting_average": 80.0,
		"directing": 80.0,
		"camera_work": 80.0,
		"technical": 80.0,
		"energy": 0.9,
		"morale": 0.9,
		"stress": 0.1,
	}
	for _minute_index in range(6):
		system.call(
			"advance_minute",
			project,
			script,
			true,
			true,
			snapshot
		)
	_expect(
		str(project.current_phase) == "rehearsal"
		and int(project.phase_minutes_elapsed) == 2,
		"Preparation and neutral set dressing must lead into a short rehearsal."
	)
	_expect(
		int(project.current_scene_elapsed_minutes) == 6,
		"Active production minutes must accumulate across phase transitions."
	)
	_expect(
		float(project.get_progress_percent()) > 0.0,
		"Film progress must advance independently from screenplay writing."
	)


func _test_quick_production_pacing(
	script: Variant,
	crew_assignments: Dictionary,
	cast_assignments: Dictionary
) -> void:
	var system: RefCounted = FILM_PRODUCTION_SYSTEM_SCRIPT.new()
	var owned_props: Array[String] = [
		"lighthouse_console",
		"lighthouse_beacon",
		"lighthouse_rail",
	]
	var scene_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		script.scenes,
		owned_props,
		str(script.genre_id)
	)
	var project: Variant = system.call(
		"start_project",
		script,
		crew_assignments,
		cast_assignments,
		"FILM-QUICK-PACING",
		445566,
		1,
		8,
		0,
		scene_setups
	)
	var snapshot: Dictionary = {
		"acting_average": 90.0,
		"directing": 90.0,
		"camera_work": 90.0,
		"technical": 90.0,
		"energy": 0.95,
		"morale": 0.95,
		"stress": 0.05,
	}
	_expect(
		int(project.phase_duration_minutes) == 2,
		"Scene preparation must remain a short two-minute gameplay phase."
	)
	for _minute in range(2):
		system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		str(project.current_phase) == "set_dressing"
		and int(project.phase_duration_minutes) == 5
		and str(project.get_phase_title()) == "Монтаж декораций",
		"Three reusable lighthouse props must create a five-minute set-dressing phase."
	)
	for _minute in range(5):
		system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		str(project.current_phase) == "rehearsal"
		and int(project.phase_duration_minutes) == 4,
		"Actors must begin rehearsal as soon as the technician finishes the set."
	)
	for _minute in range(4):
		system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		str(project.current_phase) == "shooting"
		and int(project.phase_duration_minutes) == 10,
		"An actor pair must receive a compact ten-minute shooting block."
	)
	for _minute in range(10):
		system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		str(project.current_phase) == "review"
		and int(project.phase_duration_minutes) == 1,
		"Review must be a quick one-minute transition."
	)
	system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		int(project.completed_scene_count) == 1
		and int(project.current_scene_index) == 0
		and str(project.current_phase) == "set_strike"
		and int(project.phase_duration_minutes) == 4,
		"A completed scene must enter a four-minute prop strike before the next scene begins."
	)
	_expect(
		int(project.total_elapsed_minutes) == 22,
		"A two-performer scene with three installed props must take twenty-two minutes before strike."
	)
	for _minute in range(4):
		system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		int(project.current_scene_index) == 1
		and str(project.current_phase) == "preparation"
		and int(project.total_elapsed_minutes) == 26,
		"The next scene must begin only after all four strike minutes have elapsed."
	)
	_expect(
		int(project.estimated_total_minutes) == 52,
		"Both scenes must include technician-scaled installation and strike phases."
	)
	_expect(
		str(project.scene_setups[0].get("set_id", "")) == "lighthouse"
		and project.scene_setups[0].get("prop_ids", []).size() == 3
		and project.scene_setups[0].get("required_prop_ids", []).size() == 3
		and project.scene_setups[0].get("missing_prop_ids", []).is_empty(),
		"Each scene must retain its reusable prop plan."
	)
	_expect(
		str(project.scene_results[0].get("set_id", "")) == "lighthouse"
		and project.scene_results[0].get("set_dressing_props", []).size() == 3
		and project.scene_results[0].get("required_prop_ids", []).size() == 3
		and project.scene_results[0].get("missing_prop_ids", []).is_empty(),
		"Completed scene results must record the installed set and props."
	)


func _test_project_serialization(project: Variant) -> void:
	var payload: Dictionary = project.to_dict()
	var restored: Variant = FILM_PRODUCTION_PROJECT_SCRIPT.from_dict(payload)
	_expect(
		restored.current_scene_elapsed_minutes == project.current_scene_elapsed_minutes,
		"Elapsed time within the active scene must survive serialization."
	)
	var legacy_payload: Dictionary = payload.duplicate(true)
	legacy_payload.erase("current_scene_elapsed_minutes")
	var legacy_restored: Variant = FILM_PRODUCTION_PROJECT_SCRIPT.from_dict(
		legacy_payload
	)
	_expect(
		legacy_restored.current_scene_elapsed_minutes == 0,
		"Older production data without scene elapsed time must default safely to zero."
	)
	_expect(
		restored.to_dict() == payload
		and restored.scene_setups == project.scene_setups,
		"Production phases, reusable set plans, assignments and timing must survive serialization."
	)


func _test_retake_limit() -> void:
	var script: Variant = _create_script()
	var first_scene: Dictionary = script.scenes[0]
	script.scenes.clear()
	script.scenes.append(first_scene)
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
	_expect(project != null, "A valid one-scene script must start a retake test.")
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

	_expect(
		str(project.status) == "completed",
		"A scene with repeated low-quality takes must still reach a final result."
	)
	_expect(
		int(project.scene_results[0].get("retakes", 0)) == 2,
		"Low-quality scenes must request no more than two retakes."
	)
	_expect(
		int(project.total_elapsed_minutes) == int(project.estimated_total_minutes),
		"Retake and review time must be included in the final schedule estimate."
	)


func _test_multiple_technicians_reduce_logistics_time(
	script: Variant,
	crew_assignments: Dictionary,
	cast_assignments: Dictionary
) -> void:
	var system: RefCounted = FILM_PRODUCTION_SYSTEM_SCRIPT.new()
	var owned_props: Array[String] = [
		"lighthouse_console",
		"lighthouse_beacon",
		"lighthouse_rail",
	]
	var scene_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		script.scenes,
		owned_props,
		str(script.genre_id),
		3
	)
	var project: Variant = system.call(
		"start_project",
		script,
		crew_assignments,
		cast_assignments,
		"FILM-MULTI-TECH-LOGISTICS",
		998812,
		1,
		8,
		0,
		scene_setups,
		3
	)
	var snapshot: Dictionary = {
		"acting_average": 90.0,
		"directing": 90.0,
		"camera_work": 90.0,
		"technical": 90.0,
		"energy": 0.95,
		"morale": 0.95,
		"stress": 0.05,
	}
	_expect(
		int(project.technician_count) == 3
		and int(project.scene_setups[0].get("setup_minutes", 0)) == 3
		and int(project.estimated_total_minutes) == 44,
		"Three technicians must parallelize three props and reduce estimated installation/strike time."
	)
	for _minute in range(2):
		system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		str(project.current_phase) == "set_dressing"
		and int(project.phase_duration_minutes) == 3,
		"Three technicians must reduce a three-prop set-dressing phase to three minutes."
	)
	for _minute in range(3):
		system.call("advance_minute", project, script, true, true, snapshot)
	for _minute in range(4):
		system.call("advance_minute", project, script, true, true, snapshot)
	for _minute in range(10):
		system.call("advance_minute", project, script, true, true, snapshot)
	system.call("advance_minute", project, script, true, true, snapshot)
	_expect(
		str(project.current_phase) == "set_strike"
		and int(project.phase_duration_minutes) == 2,
		"Three technicians must parallelize the three-prop strike to two minutes."
	)
	var restored: Variant = FILM_PRODUCTION_PROJECT_SCRIPT.from_dict(
		project.to_dict()
	)
	_expect(
		int(restored.technician_count) == 3,
		"Technician count must survive production project serialization."
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
	var phases_seen: Dictionary = {"preparation": true}
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

	_expect(
		str(project.status) == "completed",
		"Every scene must eventually finish and complete the film."
	)
	_expect(
		int(project.completed_scene_count) == 2
		and project.scene_results.size() == 2,
		"Every scripted scene must have a recorded production result."
	)
	_expect(
		int(project.final_quality) >= 0
		and int(project.final_quality) <= 100,
		"Final film quality must be bounded from 0 to 100."
	)
	_expect(
		float(project.get_progress_percent()) == 100.0,
		"A completed film must report 100 percent production progress."
	)
	_expect(
		int(project.get_remaining_work_minutes()) == 0,
		"A completed film must have no remaining production time."
	)
	_expect(
		int(project.total_elapsed_minutes) == 40,
		"A two-scene film must include both neutral set-dressing and one-minute strike phases."
	)
	for phase in ["preparation", "set_dressing", "rehearsal", "shooting", "review", "set_strike"]:
		_expect(
			phases_seen.has(phase),
			"Every scene must pass through the %s phase." % phase
		)
	_expect(
		int(project.scene_results[0].get("production_minutes", 0)) > 0,
		"Scene results must retain actual elapsed production time."
	)
