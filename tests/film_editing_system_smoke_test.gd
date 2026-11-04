extends "res://tests/smoke_test_base.gd"

const FILM_PRODUCTION_PROJECT_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_project.gd"
)
const FILM_EDITING_PROJECT_SCRIPT = preload(
	"res://scripts/domain/film_editing/film_editing_project.gd"
)
const FILM_EDITING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_editing/film_editing_system.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var production: Variant = _create_completed_production()
	var system: RefCounted = FILM_EDITING_SYSTEM_SCRIPT.new()
	_test_project_validation(system, production)
	var project: Variant = system.call(
		"create_project",
		production,
		"EMP-EDITOR",
		82.0,
		"EDIT-SMOKE-01",
		1,
		9,
		30
	)
	_expect(project != null, "A completed film must create an editing project.")
	if project == null:
		_finish_test("FilmEditingSystemSmokeTest")
		return

	_test_timeline_editing(system, project)
	_test_serialization(project)
	_test_editing_progress(system, project)
	_finish_test("FilmEditingSystemSmokeTest")


func _create_completed_production() -> Variant:
	var production: Variant = FILM_PRODUCTION_PROJECT_SCRIPT.new()
	production.id = "FILM-EDIT-SOURCE"
	production.film_title = "Последний маяк"
	production.genre_id = "adventure"
	production.genre_title = "Приключения"
	production.status = "completed"
	production.total_scene_count = 3
	production.completed_scene_count = 3
	production.final_quality = 84
	production.scene_results = [
		{
			"scene_id": "SCN-01",
			"scene_number": 1,
			"beat": "Завязка",
			"location": "Старый маяк",
			"quality": 82,
			"retakes": 0,
		},
		{
			"scene_id": "SCN-02",
			"scene_number": 2,
			"beat": "Развитие",
			"location": "Пристань",
			"quality": 86,
			"retakes": 1,
		},
		{
			"scene_id": "SCN-03",
			"scene_number": 3,
			"beat": "Кульминация",
			"location": "Верхняя площадка маяка",
			"quality": 84,
			"retakes": 0,
		},
	]
	return production


func _test_project_validation(
	system: RefCounted,
	production: Variant
) -> void:
	var unfinished: Variant = FILM_PRODUCTION_PROJECT_SCRIPT.new()
	unfinished.status = "in_production"
	_expect(
		system.call(
			"create_project",
			unfinished,
			"EMP-EDITOR",
			80.0,
			"EDIT-INVALID-01",
			1,
			8,
			0
		) == null,
		"Editing must reject a film whose shooting is not completed."
	)
	_expect(
		system.call(
			"create_project",
			production,
			"",
			80.0,
			"EDIT-INVALID-02",
			1,
			8,
			0
		) == null,
		"Editing must require an assigned editor."
	)


func _test_timeline_editing(
	system: RefCounted,
	project: Variant
) -> void:
	_expect(
		project.timeline_order == [0, 1, 2],
		"The initial timeline must preserve screenplay scene order."
	)
	_expect(
		bool(system.call("move_scene", project, 2, 0)),
		"The player must be able to move a scene earlier in the timeline."
	)
	_expect(
		project.timeline_order == [2, 0, 1],
		"Moving a scene must update the timeline without losing scene IDs."
	)
	_expect(
		not bool(system.call("move_scene", project, -1, 0)),
		"Timeline edits must reject invalid source positions."
	)
	var ordered: Array = system.call("get_ordered_scene_results", project)
	_expect(
		ordered.size() == 3
		and str(ordered[0].get("scene_id", "")) == "SCN-03",
		"Timeline queries must return scenes in the edited order."
	)


func _test_serialization(project: Variant) -> void:
	var payload: Dictionary = project.to_dict()
	var restored: Variant = FILM_EDITING_PROJECT_SCRIPT.from_dict(payload)
	_expect(
		restored.to_dict() == payload,
		"Editor assignment, timeline order and source footage must survive serialization."
	)
	var malformed: Dictionary = payload.duplicate(true)
	malformed["timeline_order"] = [2, 2, 99]
	var recovered: Variant = FILM_EDITING_PROJECT_SCRIPT.from_dict(malformed)
	_expect(
		recovered.timeline_order == [0, 1, 2],
		"Malformed timeline data must recover to the original scene order."
	)


func _test_editing_progress(
	system: RefCounted,
	project: Variant
) -> void:
	_expect(
		bool(system.call("start_editing", project)),
		"A valid timeline must start the editing workflow."
	)
	_expect(
		not bool(system.call("move_scene", project, 0, 1)),
		"The timeline must lock when editing begins."
	)
	var before: int = int(project.total_elapsed_minutes)
	var paused: Dictionary = system.call("advance_minute", project, false)
	_expect(
		not bool(paused.get("advanced", false))
		and int(project.total_elapsed_minutes) == before
		and not str(project.pause_reason).is_empty(),
		"Editing must pause without an available editor at the Editing Suite."
	)
	_expect(
		bool(system.call(
			"reassign_editor",
			project,
			"EMP-EDITOR-02",
			68.0
		)),
		"An active edit must allow a replacement editor when the assigned employee leaves the studio."
	)
	_expect(
		str(project.editor_id) == "EMP-EDITOR-02"
		and is_equal_approx(float(project.editor_skill), 68.0),
		"Reassigning an editor must update the active editor and skill snapshot."
	)

	var phases_seen: Dictionary = {}
	for _minute_index in range(1000):
		if str(project.status) == "completed":
			break
		phases_seen[str(project.current_phase)] = true
		system.call("advance_minute", project, true)

	_expect(
		str(project.status) == "completed",
		"Editing must eventually complete and export the film."
	)
	_expect(
		int(project.final_quality) >= 0
		and int(project.final_quality) <= 100,
		"Final edited quality must remain within the 0-100 range."
	)
	_expect(
		int(project.total_elapsed_minutes) == int(project.estimated_total_minutes),
		"Editing phase durations must match the total schedule estimate."
	)
	_expect(
		int(project.continuity_score) < 100,
		"Reordering scenes must influence the continuity score."
	)
	for phase in [
		"assembly_cut",
		"fine_cut",
		"sound_mix",
		"color_grading",
		"export",
	]:
		_expect(
			phases_seen.has(phase),
			"Editing must pass through the %s phase." % phase
		)
	_expect(
		str(project.last_activity_message).contains("готов к выпуску"),
		"Completed editing must report that the film is ready for release."
	)
	_expect(
		not bool(system.call(
			"reassign_editor",
			project,
			"EMP-EDITOR-03",
			95.0
		)),
		"A completed edit must not accept a new editor."
	)
