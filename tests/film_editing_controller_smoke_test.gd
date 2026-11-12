extends "res://tests/smoke_test_base.gd"

const GAME_CLOCK_SCRIPT = preload(
	"res://scripts/core/game_clock.gd"
)
const FILM_PRODUCTION_PROJECT_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_project.gd"
)
const FILM_EDITING_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_editing/film_editing_system.gd"
)
const FILM_EDITING_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/film_editing_controller.gd"
)


class MockEmployee extends RefCounted:
	var id: String = "EMP-EDIT-CONTROLLER"
	var profession_id: String = "film_editor"
	var work_state: String = "working"
	var skills: Dictionary = {"editing": 78.0}
	var shift_start_hour: int = 9
	var shift_end_hour: int = 18
	var break_start_hour: int = 13
	var break_end_hour: int = 14

	func get_full_name() -> String:
		return "Тестовый монтажёр"


class MockCharacterManager extends Node:
	var employees: Array = []
	var at_workplace: bool = true

	func get_employees() -> Array:
		return employees

	func is_employee_at_workplace(
		_employee_id: String,
		_building_type_id: String
	) -> bool:
		return at_workplace


class MockBuildingManager extends Node:
	var active_film_project: Variant
	var detail_refresh_count: int = 0
	var completion_refresh_count: int = 0

	func get_active_film_project() -> Variant:
		return active_film_project

	func refresh_building_detail() -> void:
		detail_refresh_count += 1

	func on_film_editing_completed() -> void:
		completion_refresh_count += 1


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var manager := MockBuildingManager.new()
	var character_manager := MockCharacterManager.new()
	var game_clock: Node = GAME_CLOCK_SCRIPT.new()
	var employee := MockEmployee.new()
	character_manager.employees = [employee]
	root.add_child(manager)
	root.add_child(character_manager)
	root.add_child(game_clock)

	var production: Variant = _create_completed_production()
	manager.active_film_project = production
	var controller: RefCounted = FILM_EDITING_CONTROLLER_SCRIPT.new()
	controller.call(
		"setup",
		manager,
		character_manager,
		FILM_EDITING_SYSTEM_SCRIPT.new(),
		game_clock
	)
	var detail_layout := VBoxContainer.new()
	root.add_child(detail_layout)
	var assigned_staff: Array = [employee]
	_rebuild_detail(controller, detail_layout, assigned_staff)

	_expect(
		str(controller.call("get_editor_id")) == employee.id,
		"The editing controller must select an eligible editor from the assigned staff."
	)
	controller.call("_on_create_film_editing_project_pressed")
	var project: Variant = controller.call("get_active_project")
	_expect(
		project != null
		and str(project.status) == "draft"
		and str(project.editor_id) == employee.id
		and str(project.id) == "EDIT-0001",
		"The controller must create and own a draft editing project with the next sequence ID."
	)
	_expect(
		bool(controller.call("is_employee_in_active_editing", employee.id)),
		"The selected editor must be reported as assigned while the project is a draft."
	)
	if project == null:
		_finish_test("FilmEditingControllerSmokeTest")
		return

	_rebuild_detail(controller, detail_layout, assigned_staff)
	controller.call("_on_film_editing_move_scene_pressed", 1)
	_expect(
		project.timeline_order == [1, 0, 2],
		"The extracted controller must preserve timeline scene reordering."
	)

	_rebuild_detail(controller, detail_layout, assigned_staff)
	controller.call("_on_start_film_editing_pressed")
	_expect(
		str(project.status) == "in_editing",
		"Editing must start only after the assigned editor is on shift at the Editing Suite."
	)

	character_manager.at_workplace = false
	var elapsed_before_pause: int = int(project.total_elapsed_minutes)
	controller.call("advance")
	_expect(
		int(project.total_elapsed_minutes) == elapsed_before_pause
		and not str(project.pause_reason).is_empty(),
		"The controller must preserve the editor-availability pause without advancing project time."
	)

	character_manager.at_workplace = true
	for _minute_index in range(1000):
		if str(project.status) == "completed":
			break
		controller.call("advance")
	_expect(
		str(project.status) == "completed"
		and manager.completion_refresh_count == 1,
		"The controller must complete the editing pipeline and notify the building manager exactly once."
	)
	_expect(
		not bool(controller.call("is_employee_in_active_editing", employee.id)),
		"A completed project must release the editor from active editing."
	)
	_expect(
		manager.detail_refresh_count >= 3,
		"Controller actions must request inspector refreshes through the manager adapter."
	)

	detail_layout.free()
	game_clock.free()
	character_manager.free()
	manager.free()
	_finish_test("FilmEditingControllerSmokeTest")


func _rebuild_detail(
	controller: RefCounted,
	detail_layout: VBoxContainer,
	assigned_staff: Array
) -> void:
	for child in detail_layout.get_children():
		detail_layout.remove_child(child)
		child.free()
	controller.call("build_detail", detail_layout, assigned_staff)


func _create_completed_production() -> Variant:
	var production: Variant = FILM_PRODUCTION_PROJECT_SCRIPT.new()
	production.id = "FILM-EDIT-CONTROLLER"
	production.film_title = "Тест последнего кадра"
	production.genre_id = "drama"
	production.genre_title = "Драма"
	production.status = "completed"
	production.total_scene_count = 3
	production.completed_scene_count = 3
	production.final_quality = 84
	production.scene_results = [
		{
			"scene_id": "SCN-CONTROLLER-01",
			"scene_number": 1,
			"beat": "Завязка",
			"location": "Павильон",
			"quality": 82,
			"retakes": 0,
		},
		{
			"scene_id": "SCN-CONTROLLER-02",
			"scene_number": 2,
			"beat": "Развитие",
			"location": "Павильон",
			"quality": 86,
			"retakes": 1,
		},
		{
			"scene_id": "SCN-CONTROLLER-03",
			"scene_number": 3,
			"beat": "Финал",
			"location": "Павильон",
			"quality": 84,
			"retakes": 0,
		},
	]
	return production
