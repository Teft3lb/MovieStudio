extends "res://tests/smoke_test_base.gd"

const ASSIGNMENT_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/film_production_assignment_controller.gd"
)


class MockFilmScript extends RefCounted:
	var id: String = "SCRIPT-ASSIGNMENT-01"
	var cast: Array[Dictionary] = []


class MockEmployee extends RefCounted:
	var id: String = ""
	var profession_id: String = ""
	var specialization_id: String = ""
	var skills: Dictionary = {}

	func get_full_name() -> String:
		return id

	func get_profession_title() -> String:
		match profession_id:
			"actor":
				return "Актёр"
			"extra":
				return "Актёр массовки"
			"director":
				return "Режиссёр"
			"camera_operator":
				return "Оператор"
			"technician":
				return "Техник"
			_:
				return profession_id


class MockManager extends Node:
	var latest_script: Variant
	var refresh_count: int = 0

	func get_latest_script() -> Variant:
		return latest_script

	func get_active_film_project() -> Variant:
		return null

	func refresh_film_production_ui() -> void:
		refresh_count += 1


class MockFilmProductionSystem extends RefCounted:
	func can_start_project(
		_script: Variant,
		_crew_assignments: Dictionary,
		_cast_assignments: Dictionary
	) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var manager := MockManager.new()
	var production_system := MockFilmProductionSystem.new()
	var script := MockFilmScript.new()
	script.cast = [
		{
			"role_id": "ROLE-LEAD",
			"role_title": "Главная роль",
			"character_name": "Алекс",
		},
		{
			"role_id": "ROLE-SUPPORT",
			"role_title": "Вторая роль",
			"character_name": "Борис",
		},
	]
	manager.latest_script = script
	root.add_child(manager)

	var assigned_staff: Array = [
		_create_employee("EMP-DIRECTOR", "director", {"directing": 75.0}),
		_create_employee("EMP-CAMERA", "camera_operator", {"camera_work": 72.0}),
		_create_employee("EMP-TECHNICIAN", "technician", {"technical": 68.0}),
		_create_employee("EMP-ACTOR-01", "actor", {"acting": 80.0}),
		_create_employee("EMP-ACTOR-02", "actor", {"acting": 76.0}),
		_create_employee("EMP-EXTRA-01", "extra", {"acting": 52.0}),
	]

	var detail_layout := VBoxContainer.new()
	root.add_child(detail_layout)
	var controller: RefCounted = ASSIGNMENT_CONTROLLER_SCRIPT.new()
	controller.call("setup", manager, production_system)
	controller.call("build_controls", detail_layout, assigned_staff)

	var crew_assignments: Dictionary = controller.call(
		"get_film_crew_assignments",
		assigned_staff
	)
	var cast_assignments: Dictionary = controller.call("get_cast_assignments")
	var background_ids: Array[String] = controller.call(
		"get_background_performer_ids"
	)
	_expect(
		str(crew_assignments.get("director", "")) == "EMP-DIRECTOR"
		and str(crew_assignments.get("camera_operator", "")) == "EMP-CAMERA"
		and str(crew_assignments.get("technician", "")) == "EMP-TECHNICIAN",
		"Required production crew positions must resolve to eligible employees."
	)
	_expect(
		cast_assignments.size() == 2
		and str(cast_assignments.get("ROLE-LEAD", "")) == "EMP-ACTOR-01"
		and str(cast_assignments.get("ROLE-SUPPORT", "")) == "EMP-ACTOR-02",
		"Scripted cast roles must receive distinct eligible performers."
	)
	_expect(
		background_ids.is_empty(),
		"Background performers must remain opt-in rather than expanding the roster automatically."
	)
	_expect(
		bool(controller.call(
			"has_complete_production_assignments",
			crew_assignments,
			cast_assignments,
			assigned_staff
		)),
		"A valid crew and scripted cast must pass production-start validation."
	)
	var technician_ids: Array[String] = controller.call(
		"get_stage_technician_ids",
		crew_assignments
	)
	_expect(
		technician_ids == ["EMP-TECHNICIAN"],
		"Only employees assigned to technician crew roles should enter set logistics."
	)

	var background_options: Dictionary = controller.get(
		"_film_background_options"
	)
	var extra_checkbox: CheckBox = (
		background_options.get("EMP-EXTRA-01") as CheckBox
	)
	_expect(
		is_instance_valid(extra_checkbox),
		"An eligible uncast extra must receive a background-performer control."
	)
	if is_instance_valid(extra_checkbox):
		controller.call(
			"_on_film_background_performer_toggled",
			true,
			"EMP-EXTRA-01",
			extra_checkbox
		)
	background_ids = controller.call("get_background_performer_ids")
	_expect(
		background_ids == ["EMP-EXTRA-01"],
		"The player must be able to opt an eligible extra into background scenes."
	)

	var rejected_checkbox := CheckBox.new()
	rejected_checkbox.button_pressed = true
	controller.call(
		"_on_film_background_performer_toggled",
		true,
		"EMP-ACTOR-01",
		rejected_checkbox
	)
	background_ids = controller.call("get_background_performer_ids")
	_expect(
		not background_ids.has("EMP-ACTOR-01")
		and not rejected_checkbox.button_pressed,
		"A scripted cast member must not also be assigned as a background performer."
	)
	_expect(
		manager.refresh_count == 1,
		"Assignment changes must refresh production readiness through the manager adapter."
	)

	detail_layout.free()
	manager.free()
	_finish_test("FilmProductionAssignmentControllerSmokeTest")


func _create_employee(
	employee_id: String,
	profession_id: String,
	skills: Dictionary
) -> MockEmployee:
	var employee := MockEmployee.new()
	employee.id = employee_id
	employee.profession_id = profession_id
	employee.skills = skills
	return employee
