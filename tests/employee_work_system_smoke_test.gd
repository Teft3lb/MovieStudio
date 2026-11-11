extends "res://tests/smoke_test_base.gd"

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const EMPLOYEE_WORK_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_work_system.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 741258

	var writer: Variant = generator.call(
		"generate", rng, "EMP-WORK-WRITER", "screenwriter"
	)
	var actor: Variant = generator.call(
		"generate", rng, "EMP-WORK-ACTOR", "actor"
	)
	var director: Variant = generator.call(
		"generate", rng, "EMP-WORK-DIRECTOR", "director"
	)
	var operator: Variant = generator.call(
		"generate", rng, "EMP-WORK-OPERATOR", "camera_operator"
	)
	var technician: Variant = generator.call(
		"generate", rng, "EMP-WORK-TECHNICIAN", "technician"
	)
	var editor: Variant = generator.call(
		"generate", rng, "EMP-WORK-EDITOR", "film_editor"
	)
	var cleaner: Variant = generator.call(
		"generate", rng, "EMP-WORK-CLEANER", "cleaner"
	)

	var script_department: Variant = BUILDING_DATA_SCRIPT.new()
	script_department.id = "BLD-SCRIPT"
	script_department.building_type_id = "script_department"
	script_department.is_operational = true

	var sound_stage: Variant = BUILDING_DATA_SCRIPT.new()
	sound_stage.id = "BLD-STAGE"
	sound_stage.building_type_id = "sound_stage"
	sound_stage.is_operational = true

	var editing_suite: Variant = BUILDING_DATA_SCRIPT.new()
	editing_suite.id = "BLD-EDITING"
	editing_suite.building_type_id = "editing_suite"
	editing_suite.is_operational = true

	var system: RefCounted = EMPLOYEE_WORK_SYSTEM_SCRIPT.new()
	var employees: Array = [
		writer,
		actor,
		director,
		operator,
		technician,
		editor,
		cleaner,
	]
	var assignments: Dictionary = system.call(
		"build_assignments",
		employees,
		[script_department, sound_stage, editing_suite]
	)

	_test_profession_assignments(assignments)
	_test_skill_progression(system, actor, assignments)
	_test_editor_skill_progression(system, editor, assignments)
	_test_non_working_employees_do_not_gain_skills(system, actor, assignments)

	_finish_test("EmployeeWorkSystemSmokeTest")


func _test_profession_assignments(assignments: Dictionary) -> void:
	_expect(
		str(assignments["EMP-WORK-WRITER"].get("building_type_id", ""))
		== "script_department",
		"Screenwriters must be assigned to the Script Department."
	)
	for employee_id in [
		"EMP-WORK-ACTOR",
		"EMP-WORK-DIRECTOR",
		"EMP-WORK-OPERATOR",
		"EMP-WORK-TECHNICIAN",
	]:
		_expect(
			str(assignments[employee_id].get("building_type_id", ""))
			== "sound_stage",
			"Creative production staff must be assigned to the Sound Stage."
		)
	_expect(
		str(assignments["EMP-WORK-EDITOR"].get("building_type_id", ""))
		== "editing_suite",
		"Film editors must be assigned to the Editing Suite."
	)
	_expect(
		str(assignments["EMP-WORK-EDITOR"].get("primary_skill_id", "")) == "editing",
		"Film editors must progress their editing skill at work."
	)
	_expect(
		not assignments.has("EMP-WORK-CLEANER"),
		"Facility staff must not be assigned to a building that does not accept their profession."
	)


func _test_skill_progression(
	system: RefCounted,
	employee: Variant,
	assignments: Dictionary
) -> void:
	employee.work_state = "working"
	var skill_id: String = str(
		assignments["EMP-WORK-ACTOR"].get("primary_skill_id", "")
	)
	var before: float = float(employee.skills.get(skill_id, 0.0))
	var changed: bool = system.call(
		"advance_work_minute",
		employee,
		assignments["EMP-WORK-ACTOR"]
	)
	var after: float = float(employee.skills.get(skill_id, 0.0))
	var xp_after: float = float(employee.skill_xp.get(skill_id, 0.0))

	_expect(changed, "A working employee must gain professional experience.")
	_expect(
		xp_after > 0.0,
		"Every work minute must add persisted experience toward the next skill point."
	)
	for _minute in range(3500):
		system.call("advance_work_minute", employee, assignments["EMP-WORK-ACTOR"])
	after = float(employee.skills.get(skill_id, 0.0))
	_expect(
		after > before,
		"Accumulated work experience must eventually improve the primary professional skill."
	)
	_expect(
		after <= 100.0,
		"Professional skill growth must respect the 100-point cap."
	)


func _test_editor_skill_progression(
	system: RefCounted,
	editor: Variant,
	assignments: Dictionary
) -> void:
	editor.work_state = "working"
	var before: float = float(editor.skills.get("editing", 0.0))
	var changed: bool = system.call(
		"advance_work_minute",
		editor,
		assignments["EMP-WORK-EDITOR"]
	)
	var after: float = float(editor.skills.get("editing", 0.0))
	_expect(changed, "A working film editor must gain editing experience.")
	_expect(
		float(editor.skill_xp.get("editing", 0.0)) > 0.0,
		"Editing Suite work must accumulate persisted editing experience."
	)
	for _minute in range(3500):
		system.call("advance_work_minute", editor, assignments["EMP-WORK-EDITOR"])
	after = float(editor.skills.get("editing", 0.0))
	_expect(
		after > before,
		"Accumulated editing work must eventually improve the editor's editing skill."
	)


func _test_non_working_employees_do_not_gain_skills(
	system: RefCounted,
	employee: Variant,
	assignments: Dictionary
) -> void:
	employee.work_state = "break"
	var skill_id: String = str(
		assignments["EMP-WORK-ACTOR"].get("primary_skill_id", "")
	)
	var before: float = float(employee.skills.get(skill_id, 0.0))
	var changed: bool = system.call(
		"advance_work_minute",
		employee,
		assignments["EMP-WORK-ACTOR"]
	)
	var after: float = float(employee.skills.get(skill_id, 0.0))

	_expect(not changed, "Employees on break must not gain work experience.")
	_expect(
		is_equal_approx(before, after),
		"Skill values must remain unchanged during a break."
	)
