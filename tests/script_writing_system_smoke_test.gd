extends SceneTree

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const SCRIPT_WRITING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/script_department/script_writing_system.gd"
)
const SCRIPT_WRITING_PROJECT_SCRIPT = preload(
	"res://scripts/domain/script_department/script_writing_project.gd"
)


func _initialize() -> void:
	var writer: Variant = _create_writer()
	var system: RefCounted = SCRIPT_WRITING_SYSTEM_SCRIPT.new()

	_test_duration_scales_with_order(system, writer)
	_test_workplace_and_shift_gates(system, writer)
	_test_interruption_pauses_progress(system, writer)
	_test_project_progress_and_completion(system, writer)
	_test_project_serialization(system, writer)

	print("ScriptWritingSystemSmokeTest: PASS")
	quit(0)


func _create_writer() -> Variant:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 314159
	return generator.call(
		"generate",
		rng,
		"WRITER-TIMED-TEST",
		"screenwriter"
	)


func _test_duration_scales_with_order(
	system: RefCounted,
	writer: Variant
) -> void:
	var short_duration: int = system.call(
		"calculate_required_work_minutes",
		writer,
		3,
		1
	)
	var long_duration: int = system.call(
		"calculate_required_work_minutes",
		writer,
		20,
		8
	)
	assert(
		short_duration > 0 and long_duration > short_duration,
		"More scenes and roles must require more writing time."
	)


func _test_workplace_and_shift_gates(
	system: RefCounted,
	writer: Variant
) -> void:
	var project: Variant = system.call(
		"start_project",
		writer,
		"drama",
		8,
		3,
		44321,
		"WRK-GATE-01",
		"SCR-GATE-01",
		1,
		8,
		0
	)
	assert(project != null, "A screenwriter must be able to start a writing project.")
	var initial_progress: int = int(project.completed_work_minutes)

	system.call("advance_minute", project, writer, false)
	assert(
		int(project.completed_work_minutes) == initial_progress,
		"Writing must not progress before the employee reaches the Script Department."
	)

	writer.work_state = "break"
	system.call("advance_minute", project, writer, true)
	assert(
		int(project.completed_work_minutes) == initial_progress,
		"Writing must pause during the employee's scheduled break."
	)


func _test_interruption_pauses_progress(
	system: RefCounted,
	writer: Variant
) -> void:
	writer.work_state = "working"
	var project: Variant = system.call(
		"start_project",
		writer,
		"drama",
		8,
		3,
		554433,
		"WRK-INTERRUPT-01",
		"SCR-INTERRUPT-01",
		1,
		8,
		0
	)
	var initial_progress: int = int(project.completed_work_minutes)
	var applied: bool = system.call(
		"apply_interruption",
		project,
		5,
		"Тестовая творческая пауза"
	)
	assert(applied, "A valid writing project must accept an interruption event.")

	for _minute_index in range(5):
		var result: Dictionary = system.call(
			"advance_minute",
			project,
			writer,
			true
		)
		assert(
			bool(result.get("interrupted", false)),
			"An active interruption must block screenplay progress."
		)

	assert(
		int(project.completed_work_minutes) == initial_progress,
		"Interrupted work minutes must not count as writing progress."
	)
	assert(
		int(project.interruption_count) == 1,
		"Interruption events must be recorded once per event."
	)


func _test_project_progress_and_completion(
	system: RefCounted,
	writer: Variant
) -> void:
	writer.work_state = "working"
	var needs: Dictionary = writer.needs
	needs["energy"] = 1.0
	needs["stress"] = 1.0
	writer.needs = needs

	var project: Variant = system.call(
		"start_project",
		writer,
		"mystery",
		20,
		8,
		123456,
		"WRK-COMPLETE-01",
		"SCR-COMPLETE-01",
		1,
		8,
		0
	)
	var completion_result: Dictionary = {}
	for _minute_index in range(5000):
		if str(project.status) != "in_progress":
			break
		var result: Dictionary = system.call(
			"advance_minute",
			project,
			writer,
			true
		)
		if bool(result.get("completed", false)):
			completion_result = result

	assert(
		str(project.status) == "completed",
		"The writing project must eventually complete during sufficient working time."
	)
	assert(
		completion_result.get("script") != null,
		"Completing the writing project must produce a FilmScriptData result."
	)
	assert(
		int(project.interruption_count) > 0,
		"Interruption count must be retained on the project."
	)


func _test_project_serialization(
	system: RefCounted,
	writer: Variant
) -> void:
	var project: Variant = system.call(
		"start_project",
		writer,
		"adventure",
		10,
		4,
		778899,
		"WRK-SERIALIZE-01",
		"SCR-SERIALIZE-01",
		3,
		9,
		15
	)
	var restored: Variant = SCRIPT_WRITING_PROJECT_SCRIPT.from_dict(
		project.to_dict()
	)
	assert(
		restored.to_dict() == project.to_dict(),
		"Writing project progress and interruption state must survive serialization."
	)
