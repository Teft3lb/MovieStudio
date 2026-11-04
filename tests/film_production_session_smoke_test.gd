extends "res://tests/smoke_test_base.gd"

const STUDIO_BUILDING_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_manager.gd"
)
const CHARACTER_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/characters/character_manager.gd"
)
const FILM_PRODUCTION_PROJECT_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_project.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var studio_manager: Node = STUDIO_BUILDING_MANAGER_SCRIPT.new()
	var project: Variant = FILM_PRODUCTION_PROJECT_SCRIPT.new()
	project.status = "in_production"
	project.crew_assignments = {
		"director": "EMP-DIRECTOR",
		"camera_operator": "EMP-CAMERA",
		"technician": "EMP-TECHNICIAN",
	}
	project.cast_assignments = {
		"ROLE-01": "EMP-ACTOR",
	}
	studio_manager.set("_active_film_project", project)

	var character_manager: Node = CHARACTER_MANAGER_SCRIPT.new()
	character_manager.set("_studio_building_manager", studio_manager)

	_expect(
		bool(studio_manager.call(
			"is_employee_in_active_production",
			"EMP-ACTOR"
		)),
		"Assigned cast members must be marked as active production participants."
	)
	_expect(
		bool(character_manager.call(
			"_is_active_production_participant",
			"EMP-DIRECTOR"
		)),
		"CharacterManager must recognise assigned crew during an active shoot."
	)
	_expect(
		not bool(character_manager.call(
			"_should_leave_workplace",
			"EMP-ACTOR",
			"off_shift",
			false
		)),
		"Cast members must remain on the set through normal shift boundaries."
	)
	_expect(
		not bool(character_manager.call(
			"_should_leave_workplace",
			"EMP-TECHNICIAN",
			"lunch",
			false
		)),
		"Crew members must remain on the set through scheduled lunch breaks."
	)
	_expect(
		bool(character_manager.call(
			"_should_leave_workplace",
			"EMP-OTHER",
			"off_shift",
			false
		)),
		"Employees outside the active production must retain normal off-shift routing."
	)
	_expect(
		bool(character_manager.call(
			"_should_leave_workplace",
			"EMP-ACTOR",
			"working",
			true
		)),
		"An employee without a workplace assignment must still leave the building."
	)

	project.status = "completed"
	_expect(
		not bool(character_manager.call(
			"_is_active_production_participant",
			"EMP-ACTOR"
		)),
		"Production priority must end when the film shoot is completed."
	)

	character_manager.free()
	studio_manager.free()
	_finish_test("FilmProductionSessionSmokeTest")
