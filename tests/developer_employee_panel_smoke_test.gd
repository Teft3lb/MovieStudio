extends "res://tests/smoke_test_base.gd"

const DEVELOPER_PANEL = preload(
	"res://scripts/presentation/ui/developer_employee_panel.gd"
)
const DEV_TUNING = preload(
	"res://scripts/domain/characters/character_dev_tuning.gd"
)
const GENERATOR = preload(
	"res://scripts/domain/characters/character_generator.gd"
)


class MockEmployeeManager extends Node:
	var employees: Array = []
	var tuner: RefCounted

	func get_employees() -> Array:
		return employees

	func developer_change_employee_stat(
		employee_id: String, stat_id: String,
		amount: float, absolute: bool = false
	) -> bool:
		for employee in employees:
			if str(employee.id) != employee_id:
				continue
			return bool(
				tuner.call("set_stat", employee, stat_id, amount)
				if absolute
				else tuner.call("adjust_stat", employee, stat_id, amount)
			)
		return false


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23666
	var generator: RefCounted = GENERATOR.new()
	var employee: Variant = generator.call(
		"generate", rng, "DEV-EMP-01", "actor", true
	)
	employee.recognition = 8.0
	var manager := MockEmployeeManager.new()
	manager.employees = [employee]
	manager.tuner = DEV_TUNING.new()
	root.add_child(manager)
	var layout := VBoxContainer.new()
	root.add_child(layout)
	var panel: RefCounted = DEVELOPER_PANEL.new()
	panel.call("build", layout, manager)
	var roster_option: OptionButton = panel.get("_employee_select") as OptionButton
	var stat_option: OptionButton = panel.get("_stat_select") as OptionButton
	_expect(
		roster_option != null
		and not roster_option.disabled
		and roster_option.get_item_count() == 1
		and stat_option != null
		and stat_option.get_item_count() >= 7,
		"DEV workspace must expose staff and customizable test attributes."
	)
	if roster_option == null or stat_option == null:
		layout.free()
		manager.free()
		_finish_test("DeveloperEmployeePanelSmokeTest")
		return
	var recognition_index: int = -1
	var stress_index: int = -1
	for index in range(stat_option.get_item_count()):
		match str(stat_option.get_item_metadata(index)):
			"recognition":
				recognition_index = index
			"stress":
				stress_index = index
	_expect(
		recognition_index >= 0 and stress_index >= 0,
		"DEV controls must expose both career fame and normalized employee stress."
	)
	if recognition_index >= 0:
		stat_option.select(recognition_index)
		panel.call("_on_adjust_pressed", 70.0, true)
		_expect(
			is_equal_approx(float(employee.recognition), 70.0),
			"DEV =70 must immediately unlock the fame threshold."
		)
		panel.call("_on_adjust_pressed", 50.0, false)
		_expect(
			is_equal_approx(float(employee.recognition), 100.0),
			"DEV incremental adjustments must clamp to 100."
		)
	if stress_index >= 0:
		stat_option.select(stress_index)
		panel.call("_on_adjust_pressed", 0.0, true)
		_expect(
			is_equal_approx(float(employee.needs.get("stress", -1.0)), 0.0),
			"DEV absolute change of stress to zero must use percent scaling."
		)
	layout.free()
	manager.free()
	_finish_test("DeveloperEmployeePanelSmokeTest")
