extends "res://tests/smoke_test_base.gd"

const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const CHARACTER_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/characters/character_manager.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const GAME_CLOCK_SCRIPT = preload("res://scripts/core/game_clock.gd")
const CHARACTER_NEEDS_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_needs_system.gd"
)
const EMPLOYEE_WORK_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_work_system.gd"
)


class StubFacilityManager extends Node:
	var buildings: Array = []
	var active_production_employee_id: String = ""

	func get_buildings() -> Array:
		return buildings

	func is_employee_in_active_production(employee_id: String) -> bool:
		return employee_id == active_production_employee_id

	func get_facility_path_from(
		_building_id: String,
		_slot_index: int,
		start_position: Vector3,
		_source_building_id: String = "",
		_source_slot_index: int = 0
	) -> Array[Vector3]:
		return [
			start_position,
			Vector3(3.0, 0.0, 0.0),
		]

	func get_workplace_path_from(
		_building_id: String,
		_slot_index: int,
		start_position: Vector3,
		_source_building_id: String = "",
		_source_slot_index: int = 0
	) -> Array[Vector3]:
		return [
			start_position,
			Vector3(2.0, 0.0, 0.0),
		]


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7654321
	var employee: Variant = generator.call(
		"generate",
		rng,
		"FACILITY-TEST-01",
		"actor"
	)
	employee.shift_start_hour = 8
	employee.shift_end_hour = 17
	employee.break_start_hour = 12
	employee.break_end_hour = 13
	var employee_needs: Dictionary = employee.needs
	employee_needs["energy"] = 0.8
	employee_needs["stress"] = 0.2
	employee.needs = employee_needs

	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	actor.call(
		"setup",
		employee,
		[Vector3.ZERO, Vector3(0.0, 0.0, 1.0)],
		clock,
		1.0
	)
	var workplace_route: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0),
	]
	actor.call(
		"assign_workplace_route",
		"BLD-WORKPLACE",
		workplace_route,
		"actor"
	)
	actor.call("snap_to_workplace")

	var cafeteria: Variant = BUILDING_DATA_SCRIPT.new()
	cafeteria.id = "BLD-CAFETERIA"
	cafeteria.building_type_id = "cafeteria"
	cafeteria.is_operational = true
	var housing: Variant = BUILDING_DATA_SCRIPT.new()
	housing.id = "BLD-HOUSING"
	housing.building_type_id = "staff_housing"
	housing.is_operational = true

	var studio_manager := StubFacilityManager.new()
	root.add_child(studio_manager)

	var character_manager: Node = CHARACTER_MANAGER_SCRIPT.new()
	character_manager.set("_studio_building_manager", studio_manager)
	character_manager.set("_game_clock", clock)
	character_manager.set(
		"_needs_system",
		CHARACTER_NEEDS_SYSTEM_SCRIPT.new()
	)
	character_manager.set(
		"_workplace_system",
		EMPLOYEE_WORK_SYSTEM_SCRIPT.new()
	)
	character_manager.set("employees", [employee])
	character_manager.set("_workplace_assignments", {
		employee.id: {
			"building_id": "BLD-WORKPLACE",
			"building_type_id": "sound_stage",
			"slot_index": 0,
		}
	})
	character_manager.set("_employee_actors", {
		employee.id: actor,
	})

	_expect(
		not bool(character_manager.call(
			"_route_employee_to_facility",
			employee.id,
			"cafeteria"
		)),
		"Employees must retain their existing fallback behavior when no cafeteria has been built."
	)
	actor.call("snap_outside_workplace")
	_expect(
		str(actor.call("get_workplace_building_id")).is_empty(),
		"The roaming employee must be allowed to visit a facility without an active workplace route."
	)
	studio_manager.buildings = [cafeteria, housing]

	_expect(
		bool(character_manager.call(
			"_route_employee_to_facility",
			employee.id,
			"cafeteria"
		)),
		"An assigned employee must receive a route to the cafeteria."
	)
	_expect(
		bool(actor.call("is_in_facility"))
		and not bool(actor.call("is_at_facility", "cafeteria")),
		"Facility occupancy must distinguish travelling employees from arrived employees."
	)
	actor.call("snap_to_facility")
	_expect(
		bool(actor.call("is_at_facility", "cafeteria")),
		"An employee must arrive at the assigned cafeteria seat."
	)
	_expect(
		character_manager.call(
			"get_employees_using_facility",
			"BLD-CAFETERIA"
		).size() == 1,
		"The cafeteria inspector must report its current visitor."
	)
	var second_employee: Variant = generator.call(
		"generate",
		rng,
		"FACILITY-TEST-02",
		"actor"
	)
	character_manager.set("employees", [employee, second_employee])
	var next_cafeteria_slot: Dictionary = character_manager.call(
		"_get_facility_assignment",
		second_employee.id,
		"cafeteria"
	)
	_expect(
		int(next_cafeteria_slot.get("slot_index", -1)) == 1,
		"Facility allocation must reserve occupied seats and assign the next free slot."
	)
	character_manager.set("employees", [employee])

	character_manager.call(
		"dispatch_employee_to_workplace",
		employee.id
	)
	_expect(
		not bool(actor.call("is_at_workplace"))
		and not bool(actor.call("is_in_facility"))
		and str(actor.call("get_workplace_building_id")) == "BLD-WORKPLACE",
		"After lunch an employee without a cached workplace route must receive a new route to their assigned workplace."
	)
	actor.call("snap_to_workplace")

	_expect(
		bool(character_manager.call(
			"_route_employee_to_facility",
			employee.id,
			"staff_housing"
		)),
		"An assigned employee must receive a route to staff housing after the shift."
	)
	actor.call("snap_to_facility")
	_expect(
		bool(actor.call("is_at_facility", "staff_housing"))
		and character_manager.call(
			"get_employees_using_facility",
			"BLD-HOUSING"
		).size() == 1,
		"Staff housing must register the employee at their assigned bed."
	)

	character_manager.call(
		"dispatch_employee_to_workplace",
		employee.id
	)
	actor.call("snap_to_workplace")
	_expect(
		bool(actor.call("is_at_workplace"))
		and not bool(actor.call("is_in_facility")),
		"An employee must be able to leave housing and return to the same workplace."
	)

	clock.set("is_manual_fast_forward", true)
	character_manager.call("_on_game_minute_advanced", 1, 12, 0)
	_expect(
		bool(actor.call("is_at_facility", "cafeteria"))
		and str(employee.current_task) == "Обедает в столовой",
		"The scheduled lunch transition must route employees into the cafeteria and update their task."
	)
	character_manager.call("_on_game_minute_advanced", 1, 13, 0)
	_expect(
		bool(actor.call("is_at_workplace"))
		and str(employee.current_task) == "Возвращается на рабочее место",
		"Employees must return to their assigned workstation when lunch ends."
	)
	character_manager.call("_on_game_minute_advanced", 1, 17, 0)
	_expect(
		bool(actor.call("is_at_facility", "staff_housing"))
		and str(employee.current_task) == "Отдыхает в домике",
		"Employees must move into staff housing after their shift ends."
	)
	character_manager.call("_on_game_minute_advanced", 2, 8, 0)
	_expect(
		bool(actor.call("is_at_workplace"))
		and str(employee.current_task) == "Возвращается на рабочее место",
		"Employees must return from staff housing when the next shift starts."
	)
	studio_manager.active_production_employee_id = str(employee.id)
	character_manager.call("_on_game_minute_advanced", 2, 17, 0)
	_expect(
		bool(actor.call("is_at_workplace"))
		and not bool(actor.call("is_in_facility")),
		"An employee assigned to an active film must remain at the Sound Stage after the shift ends."
	)
	studio_manager.active_production_employee_id = ""
	character_manager.call("_on_game_minute_advanced", 2, 17, 1)
	_expect(
		bool(actor.call("is_at_facility", "staff_housing")),
		"Once production ends, an off-duty employee must be allowed to go to staff housing."
	)

	character_manager.free()
	actor.free()
	studio_manager.free()
	clock.free()
	_finish_test("StaffFacilitiesSmokeTest")
