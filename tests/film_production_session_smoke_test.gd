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


class StubProductionActor extends Node:
	var at_workplace: bool = false
	var in_scene_performance: bool = false
	var at_scene_mark: bool = false
	var at_scene_hold_mark: bool = false
	var returning_to_workplace: bool = false

	func is_at_workplace() -> bool:
		return at_workplace

	func is_in_scene_performance() -> bool:
		return in_scene_performance

	func is_at_scene_mark() -> bool:
		return at_scene_mark

	func is_at_scene_hold_mark() -> bool:
		return at_scene_hold_mark

	func is_returning_to_workplace() -> bool:
		return returning_to_workplace


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
	var production_controller: Variant = studio_manager.get(
		"_film_production_controller"
	)
	_expect(
		production_controller != null
		and production_controller.call("get_active_project") == project,
		"StudioBuildingManager must expose its active production project through FilmProductionController."
	)

	var character_manager: Node = CHARACTER_MANAGER_SCRIPT.new()
	character_manager.set("_studio_building_manager", studio_manager)
	var production_actor := StubProductionActor.new()
	character_manager.set("_workplace_assignments", {
		"EMP-DIRECTOR": {
			"building_id": "BUILDING-STAGE-01",
			"building_type_id": "sound_stage",
			"slot_index": 0,
		}
	})
	character_manager.set("_employee_actors", {
		"EMP-DIRECTOR": production_actor,
	})

	production_actor.in_scene_performance = true
	production_actor.at_scene_mark = true
	_expect(
		bool(character_manager.call(
			"is_employee_ready_for_production",
			"EMP-DIRECTOR",
			"sound_stage"
		)),
		"An assigned crew member at a scene mark must remain production-ready outside normal shift hours."
	)
	production_actor.at_scene_mark = false
	production_actor.at_scene_hold_mark = true
	_expect(
		bool(character_manager.call(
			"is_employee_ready_for_production",
			"EMP-DIRECTOR",
			"sound_stage"
		)),
		"An assigned crew member at an off-camera holding mark must remain production-ready."
	)
	production_actor.at_scene_hold_mark = false
	_expect(
		not bool(character_manager.call(
			"is_employee_ready_for_production",
			"EMP-DIRECTOR",
			"sound_stage"
		)),
		"A crew member still moving to a scene mark must not be treated as ready."
	)
	production_actor.returning_to_workplace = true
	_expect(
		not bool(character_manager.call(
			"is_employee_ready_for_production",
			"EMP-DIRECTOR",
			"sound_stage"
		)),
		"A crew member returning from a scene must finish the return before production resumes."
	)
	production_actor.returning_to_workplace = false
	production_actor.in_scene_performance = false
	production_actor.at_workplace = true
	_expect(
		bool(character_manager.call(
			"is_employee_ready_for_production",
			"EMP-DIRECTOR",
			"sound_stage"
		)),
		"A crew member at their assigned Sound Stage workstation must be production-ready."
	)
	production_actor.at_workplace = false

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

	production_actor.free()
	character_manager.free()
	studio_manager.free()
	_finish_test("FilmProductionSessionSmokeTest")
