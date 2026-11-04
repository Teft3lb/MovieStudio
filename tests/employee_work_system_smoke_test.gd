extends SceneTree

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

	var system: RefCounted = EMPLOYEE_WORK_SYSTEM_SCRIPT.new()
	var employees: Array = [
		writer,
		actor,
		director,
		operator,
		technician,
		cleaner,
	]
	var assignments: Dictionary = system.call(
		"build_assignments",
		employees,
		[script_department, sound_stage]
	)

	_test_profession_assignments(assignments)
	_test_skill_progression(system, actor, assignments)
	_test_non_working_employees_do_not_gain_skills(system, actor, assignments)

	print("EmployeeWorkSystemSmokeTest: PASS")
	quit(0)


func _test_profession_assignments(assignments: Dictionary) -> void:
	assert(
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
		assert(
			str(assignments[employee_id].get("building_type_id", ""))
			== "sound_stage",
			"Creative production staff must be assigned to the Sound Stage."
		)
	assert(
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

	assert(changed, "A working employee must gain professional experience.")
	assert(
		after > before,
		"Completing a work minute must improve the primary professional skill."
	)
	assert(
		after <= 100.0,
		"Professional skill growth must respect the 100-point cap."
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

	assert(not changed, "Employees on break must not gain work experience.")
	assert(
		is_equal_approx(before, after),
		"Skill values must remain unchanged during a break."
	)
