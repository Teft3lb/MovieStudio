extends "res://tests/smoke_test_base.gd"

const WORK_SYSTEM = preload(
	"res://scripts/domain/staff/employee_work_system.gd"
)
const CHARACTER_MANAGER = preload(
	"res://scripts/presentation/characters/character_manager.gd"
)
const BUILDING_INSPECTOR = preload(
	"res://scripts/presentation/studio/studio_building_inspector_controller.gd"
)


class FakeEmployee extends RefCounted:
	var id: String = ""
	var profession_id: String = "director"

	func get_full_name() -> String:
		return id


class FakeBuilding extends RefCounted:
	var id: String = ""
	var display_name: String = ""
	var building_type_id: String = "sound_stage"
	var stage_size_tier: int = 2
	var is_operational: bool = true


class FakeStudio extends Node:
	var buildings: Array = []
	var current_production_employee_id: String = ""

	func get_buildings() -> Array:
		return buildings

	func get_preferred_stage_building_id() -> String:
		return "STAGE-A"

	func is_employee_in_active_production(employee_id: String) -> bool:
		return current_production_employee_id == employee_id


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var employee_a := FakeEmployee.new()
	employee_a.id = "EMP-DIRECTOR-A"
	var employee_b := FakeEmployee.new()
	employee_b.id = "EMP-DIRECTOR-B"
	var stage_a := FakeBuilding.new()
	stage_a.id = "STAGE-A"
	var stage_b := FakeBuilding.new()
	stage_b.id = "STAGE-B"
	var studio := FakeStudio.new()
	studio.buildings = [stage_a, stage_b]
	root.add_child(studio)

	var policy: RefCounted = WORK_SYSTEM.new()
	var manual_choices: Dictionary = {"EMP-DIRECTOR-B": "STAGE-B"}
	var assigned: Dictionary = policy.call(
		"build_assignments",
		[employee_a, employee_b],
		studio.buildings,
		"STAGE-A",
		manual_choices
	)
	_expect(
		str(assigned["EMP-DIRECTOR-A"].get("building_id", "")) == "STAGE-A"
		and str(assigned["EMP-DIRECTOR-B"].get("building_id", "")) == "STAGE-B",
		"Manual assignments must override the automatic stage preference without moving unrelated staff."
	)

	var manager: Node3D = CHARACTER_MANAGER.new()
	manager.set("employees", [employee_a, employee_b])
	manager.set("_workplace_system", policy)
	manager.set("_studio_building_manager", studio)
	manager.set("_workplace_assignments", assigned)
	var layout := VBoxContainer.new()
	root.add_child(layout)
	var inspector: RefCounted = BUILDING_INSPECTOR.new()
	inspector.call("setup", studio, manager)
	inspector.set("_detail_layout", layout)
	inspector.call("set_selected_building_id", "STAGE-A")
	inspector.call("_build_workplace_reassignment_controls", [employee_a])
	var transfer_option: OptionButton = null
	for row_node in layout.get_children():
		if row_node is VBoxContainer:
			for child in row_node.get_children():
				if child is OptionButton:
					transfer_option = child as OptionButton
	var target_found: bool = false
	if transfer_option != null:
		for index in range(transfer_option.get_item_count()):
			if str(transfer_option.get_item_metadata(index)) == "STAGE-B":
				target_found = not transfer_option.is_item_disabled(index)
	_expect(
		transfer_option != null and not transfer_option.disabled and target_found,
		"Building inspector must show stage transfer controls before a screenplay exists."
	)
	layout.free()
	_expect(
		bool(manager.call(
			"set_employee_workplace_assignment", employee_a.id, "STAGE-B"
		)),
		"Players must be able to reassign an inactive director to another sound stage."
	)
	_expect(
		manager.call(
			"get_employees_assigned_to_building", "STAGE-B"
		).size() == 2,
		"Moving one employee must preserve the capacity-checked assignments of existing staff."
	)
	studio.current_production_employee_id = employee_a.id
	_expect(
		not bool(manager.call(
			"set_employee_workplace_assignment", employee_a.id, "STAGE-A"
		)),
		"Staff already participating in an active film must not be reassigned mid-shoot."
	)
	studio.current_production_employee_id = ""
	stage_b.is_operational = false
	_expect(
		not bool(manager.call(
			"set_employee_workplace_assignment", employee_a.id, "STAGE-B"
		)),
		"Non-operational stages must reject reassignment."
	)
	stage_b.is_operational = true

	var directors: Array = []
	var manual_targets: Dictionary = {}
	for i in range(9):
		var employee := FakeEmployee.new()
		employee.id = "D-%d" % i
		directors.append(employee)
		manual_targets[employee.id] = "STAGE-B"
	var capacity_result: Dictionary = policy.call(
		"build_assignments",
		directors,
		studio.buildings,
		"STAGE-A",
		manual_targets
	)
	var occupied_stage_b: int = 0
	for employee_id in capacity_result:
		if str(capacity_result[employee_id].get("building_id", "")) == "STAGE-B":
			occupied_stage_b += 1
	_expect(
		occupied_stage_b == 8,
		"Manual assignment to a medium stage must respect its eight physical workstations."
	)

	manager.free()
	studio.free()
	_finish_test("StudioEmployeeReassignmentSmokeTest")
