extends "res://tests/smoke_test_base.gd"

const FILM_PROJECT = preload(
	"res://scripts/domain/film_production/film_production_project.gd"
)
const FILM_CONTROLLER = preload(
	"res://scripts/presentation/studio/film_production_controller.gd"
)


class FakeFilmScript extends RefCounted:
	var id: String = "SCRIPT-RECAST"
	var cast: Array[Dictionary] = [{
		"role_id": "LEAD",
		"role_title": "Главная роль",
		"character_name": "Герой",
	}]


class FakeEmployee extends RefCounted:
	var id: String = ""
	var profession_id: String = ""
	var specialization_id: String = ""
	var skills: Dictionary = {}
	var shift_start_hour: int = 8
	var shift_end_hour: int = 17
	var break_start_hour: int = 12
	var break_end_hour: int = 13

	func get_full_name() -> String:
		return id

	func get_profession_title() -> String:
		return profession_id


class FakeFilmSystem extends RefCounted:
	func can_start_project(
		_script: Variant,
		_crew: Dictionary,
		_cast: Dictionary
	) -> bool:
		return true


class FakeCharacters extends Node:
	var staff: Array = []
	var cleared: Array[String] = []

	func get_employees() -> Array:
		return staff

	func clear_employee_task(employee_id: String) -> void:
		cleared.append(employee_id)

	func set_employee_production_action(
		_employee_id: String,
		_action_id: String
	) -> void:
		pass


class FakeStudio extends Node:
	var active_script: Variant
	var active_project: Variant
	var staff: Array = []

	func get_active_film_script() -> Variant:
		return active_script

	func get_script_for_production() -> Variant:
		return active_script

	func get_active_film_project() -> Variant:
		return active_project

	func get_preferred_stage_building_id() -> String:
		return "STAGE-1"

	func get_assigned_staff_for_building(_building_id: String) -> Array:
		return staff

	func refresh_film_production_ui() -> void:
		pass

	func set_stage_camera_target(
		_building_id: String,
		_target: Vector3,
		_active: bool
	) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var studio := FakeStudio.new()
	var characters := FakeCharacters.new()
	studio.active_script = FakeFilmScript.new()
	for config in [
		["DIRECTOR-A", "director"],
		["DIRECTOR-B", "director"],
		["CAMERA", "camera_operator"],
		["TECH", "technician"],
		["ACTOR-A", "actor"],
		["ACTOR-B", "actor"],
	]:
		var employee := FakeEmployee.new()
		employee.id = str(config[0])
		employee.profession_id = str(config[1])
		studio.staff.append(employee)
	characters.staff = studio.staff
	root.add_child(studio)
	root.add_child(characters)
	var project: Variant = FILM_PROJECT.new()
	project.id = "PRODUCTION-RECAST"
	project.script_id = str(studio.active_script.id)
	project.status = "in_production"
	project.current_phase = "shooting"
	project.phase_minutes_elapsed = 5
	project.crew_assignments = {
		"director": "DIRECTOR-A",
		"camera_operator": "CAMERA",
		"technician": "TECH",
	}
	project.cast_assignments = {"LEAD": "ACTOR-A"}
	studio.active_project = project
	var controller: RefCounted = FILM_CONTROLLER.new()
	controller.call(
		"setup", studio, characters, FakeFilmSystem.new(), null, null, null
	)
	controller.call("set_active_project", project)
	controller.call("set_active_script", studio.active_script)
	_expect(
		bool(controller.call("_is_film_lunch_break", 12))
		and bool(controller.call("should_release_production_employee_for_off_hours", 12))
		and not bool(controller.call("_is_film_lunch_break", 11))
		and not bool(controller.call("should_release_production_employee_for_off_hours", 11)),
		"Production must release its participants for lunch but retain them during the shooting shift."
	)
	var editor: RefCounted = controller.call("_get_assignment_controller")
	var layout := VBoxContainer.new()
	root.add_child(layout)
	editor.call("build_controls", layout, studio.staff)
	var crew_options: Dictionary = editor.get("_film_crew_options")
	var director_option: OptionButton = crew_options.get("director") as OptionButton
	var cast_options: Dictionary = editor.get("_film_cast_options")
	var actor_option: OptionButton = cast_options.get("LEAD") as OptionButton
	_expect(
		director_option != null and not director_option.disabled
		and actor_option != null and not actor_option.disabled,
		"Crew and cast controls must remain editable during an active film."
	)
	if director_option == null or actor_option == null:
		layout.free()
		characters.free()
		studio.free()
		_finish_test("FilmProductionRecastSmokeTest")
		return
	for index in range(director_option.get_item_count()):
		if str(director_option.get_item_metadata(index)) == "DIRECTOR-B":
			editor.call(
				"_on_film_crew_role_selected",
				index,
				"director",
				director_option
			)
	for index in range(actor_option.get_item_count()):
		if str(actor_option.get_item_metadata(index)) == "ACTOR-B":
			editor.call("_on_film_cast_role_selected", index, "LEAD", actor_option)
	_expect(
		not bool(controller.call("_apply_staged_film_assignments"))
		and str(project.crew_assignments.get("director", "")) == "DIRECTOR-A"
		and str(project.cast_assignments.get("LEAD", "")) == "ACTOR-A",
		"An in-progress take must retain its original cast and crew."
	)
	project.current_phase = "preparation"
	project.phase_minutes_elapsed = 0
	_expect(
		bool(controller.call("_apply_staged_film_assignments"))
		and str(project.crew_assignments.get("director", "")) == "DIRECTOR-B"
		and str(project.cast_assignments.get("LEAD", "")) == "ACTOR-B"
		and characters.cleared.has("DIRECTOR-A"),
		"Next-scene preparation must apply valid substitutions and release old assignments."
	)
	layout.free()
	characters.free()
	studio.free()
	_finish_test("FilmProductionRecastSmokeTest")
