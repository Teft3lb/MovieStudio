extends "res://tests/smoke_test_base.gd"

const GAME_CLOCK_SCRIPT = preload(
	"res://scripts/core/game_clock.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const CHARACTER_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/characters/character_manager.gd"
)
const SET_LOGISTICS_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_set_logistics_controller.gd"
)


class FakeWorkplaceManager extends Node:
	var last_source_building_id: String = ""

	func get_workplace_path_from(
		_building_id: String,
		_slot_index: int,
		start_position: Vector3,
		source_building_id: String = "",
		_source_slot_index: int = 0
	) -> Array[Vector3]:
		last_source_building_id = source_building_id
		return [start_position, Vector3.ZERO]

	func get_workplace_path(
		_building_id: String,
		_slot_index: int
	) -> Array[Vector3]:
		return [Vector3(1.0, 0.0, 0.0), Vector3.ZERO]


class FakeLogisticsClock extends Node:
	var is_manual_fast_forward: bool = false


class FakeLogisticsManager extends Node:
	var _game_clock: Node

	func get_prop_warehouse_building_id() -> String:
		return "BLD-WAREHOUSE"


class FakeLogisticsActor extends Node:
	var at_mark: bool = false
	var performing: bool = true
	var returning: bool = false
	var at_workplace: bool = false
	var snap_to_mark_count: int = 0
	var snap_to_workplace_count: int = 0

	func is_in_scene_performance() -> bool:
		return performing

	func is_at_scene_mark() -> bool:
		return at_mark

	func snap_to_scene_mark() -> void:
		snap_to_mark_count += 1
		at_mark = true

	func return_to_workplace() -> void:
		performing = false
		returning = true

	func is_returning_to_workplace() -> bool:
		return returning

	func snap_to_workplace() -> void:
		snap_to_workplace_count += 1
		returning = false
		at_workplace = true

	func is_at_workplace() -> bool:
		return at_workplace


class FakeLogisticsCharacters extends Node:
	var actor: FakeLogisticsActor
	var task_clear_count: int = 0

	func get_employee_actor(_employee_id: String) -> Node:
		return actor

	func clear_employee_task(_employee_id: String) -> void:
		task_clear_count += 1

	func set_employee_production_action(
		_employee_id: String,
		_action_id: String
	) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_morning_dispatch_interrupts_housing_trip()
	_test_manual_advance_finishes_logistics_travel()
	_finish_test("FilmProductionOvernightRecoverySmokeTest")


func _test_morning_dispatch_interrupts_housing_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 213401
	var employee: Variant = CHARACTER_GENERATOR_SCRIPT.new().call(
		"generate", rng, "EMP-WAKEUP", "director"
	)
	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	var initial_position: Vector3 = Vector3(4.0, 0.0, 0.0)
	var roaming_route: Array[Vector3] = [
		initial_position, initial_position + Vector3.RIGHT,
	]
	actor.call("setup", employee, roaming_route, clock, 2.0)
	var stage_path: Array[Vector3] = [
		initial_position, Vector3.ZERO,
	]
	var stage_exit: Array[Vector3] = [
		Vector3(1.0, 0.0, 0.0), Vector3.ZERO,
	]
	actor.call(
		"assign_workplace_route",
		"BLD-STAGE",
		stage_path,
		"director",
		stage_exit,
		0
	)
	var housing_path: Array[Vector3] = [
		initial_position, Vector3(8.0, 0.0, 0.0),
	]
	actor.call(
		"assign_facility_route",
		"BLD-HOUSING",
		"staff_housing",
		0,
		housing_path,
		"sleeping"
	)
	_expect(
		bool(actor.call("is_in_facility"))
		and not bool(actor.call("is_at_facility")),
		"Overnight employee must be travelling to housing before morning dispatch."
	)
	var workplace := FakeWorkplaceManager.new()
	root.add_child(workplace)
	var characters: Node = CHARACTER_MANAGER_SCRIPT.new()
	characters.set("employees", [employee])
	characters.set("_employee_actors", {"EMP-WAKEUP": actor})
	characters.set("_studio_building_manager", workplace)
	characters.set("_game_clock", clock)
	characters.set("_workplace_assignments", {
		"EMP-WAKEUP": {
			"building_id": "BLD-STAGE",
			"building_type_id": "sound_stage",
			"slot_index": 0,
		}
	})
	var arrived_immediately: bool = bool(
		characters.call("dispatch_employee_to_workplace", "EMP-WAKEUP")
	)
	_expect(
		not arrived_immediately
		and not bool(actor.call("is_in_facility"))
		and bool(actor.call("is_returning_to_workplace"))
		and workplace.last_source_building_id == "BLD-HOUSING"
		and actor.global_position.distance_to(initial_position) < 0.1,
		"Morning recall must interrupt travel to housing and route back without teleporting."
	)
	characters.free()
	workplace.free()
	actor.free()
	clock.free()


func _test_manual_advance_finishes_logistics_travel() -> void:
	var clock := FakeLogisticsClock.new()
	root.add_child(clock)
	var manager := FakeLogisticsManager.new()
	manager._game_clock = clock
	root.add_child(manager)
	var actor := FakeLogisticsActor.new()
	root.add_child(actor)
	var characters := FakeLogisticsCharacters.new()
	characters.actor = actor
	root.add_child(characters)
	var logistics: RefCounted = SET_LOGISTICS_SCRIPT.new()
	logistics.call("setup", manager, characters, null, null)
	logistics.set("_set_logistics_phase", "set_dressing")
	var worker_ids: Array[String] = ["EMP-TECH"]
	logistics.set("_set_logistics_worker_ids", worker_ids)
	logistics.set("_set_logistics_worker_tasks", {
		"EMP-TECH": {
			"state": "returning_via_warehouse",
		},
	})
	logistics.call("process_tasks", "BLD-STAGE", null)
	var original_task: Dictionary = logistics.get(
		"_set_logistics_worker_tasks"
	).get("EMP-TECH", {})
	_expect(
		str(original_task.get("state", "")) == "returning_via_warehouse"
		and actor.snap_to_mark_count == 0,
		"Normal movement must never teleport a technician."
	)
	clock.is_manual_fast_forward = true
	logistics.call("process_tasks", "BLD-STAGE", null)
	var returning_task: Dictionary = logistics.get(
		"_set_logistics_worker_tasks"
	).get("EMP-TECH", {})
	_expect(
		str(returning_task.get("state", "")) == "returning"
		and actor.snap_to_mark_count == 1,
		"Fast-forward must finish the technician's route and start their return."
	)
	logistics.call("process_tasks", "BLD-STAGE", null)
	var completed_task: Dictionary = logistics.get(
		"_set_logistics_worker_tasks"
	).get("EMP-TECH", {})
	_expect(
		str(completed_task.get("state", "")) == "done"
		and actor.snap_to_workplace_count == 1
		and characters.task_clear_count == 1,
		"Fast-forward must complete the return and unblock set logistics."
	)
	characters.free()
	actor.free()
	manager.free()
	clock.free()
