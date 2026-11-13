extends "res://tests/smoke_test_base.gd"

const STUDIO_MANAGER = preload(
	"res://scripts/presentation/studio/studio_building_manager.gd"
)
const BUILDING_ACTOR = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const NAVIGATION = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)
const CHARACTER_ACTOR = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const SET_LOGISTICS = preload(
	"res://scripts/presentation/studio/studio_set_logistics_controller.gd"
)


class LogisticsCharacters extends Node:
	var worker: Node3D

	func get_employee_actor(_worker_id: String) -> Node:
		return worker


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var studio: Node3D = STUDIO_MANAGER.new()
	studio.name = "StudioBuildingManager"
	studio.set("_navigation_system", NAVIGATION.new())
	root.add_child(studio)

	var stage: Variant = BUILDING_DATA.new()
	stage.id = "BLD-RECOVER-STAGE"
	stage.display_name = "Stage"
	stage.building_type_id = "sound_stage"
	stage.stage_size_tier = 2
	stage.position = Vector3.ZERO
	var warehouse: Variant = BUILDING_DATA.new()
	warehouse.id = "BLD-RECOVER-WAREHOUSE"
	warehouse.display_name = "Warehouse"
	warehouse.building_type_id = "prop_warehouse"
	warehouse.position = Vector3(26.0, 0.0, 10.0)
	var stage_actor: Node3D = BUILDING_ACTOR.new()
	stage_actor.call("setup", stage)
	studio.add_child(stage_actor)
	var warehouse_actor: Node3D = BUILDING_ACTOR.new()
	warehouse_actor.call("setup", warehouse)
	studio.add_child(warehouse_actor)
	studio.set("_buildings", [stage, warehouse])
	studio.set("_building_actors", {
		stage.id: stage_actor,
		warehouse.id: warehouse_actor,
	})
	var stage_workplace: Array[Vector3] = stage_actor.call(
		"get_workplace_path", 0
	)
	var warehouse_workplace: Array[Vector3] = warehouse_actor.call(
		"get_workplace_path", 0
	)
	_expect(
		stage_workplace.size() >= 3 and warehouse_workplace.size() >= 3,
		"Both buildings must expose working interior routes for recovery."
	)
	if stage_workplace.size() < 3 or warehouse_workplace.size() < 3:
		studio.free()
		_finish_test("StudioCrossBuildingRecoverySmokeTest")
		return
	var start: Vector3 = stage_workplace.back()
	var target: Vector3 = warehouse_workplace.back()
	# The source building must be inferred from the physical position even
	# when an employee has no workplace assignment or a stale building ID.
	var implicit_commute: Array[Vector3] = studio.call(
		"get_workplace_path_from", warehouse.id, 0, start
	)
	var stale_source_commute: Array[Vector3] = studio.call(
		"get_workplace_path_from", warehouse.id, 0, start,
		warehouse.id, 0
	)
	var implicit_facility: Array[Vector3] = studio.call(
		"get_facility_path_from", warehouse.id, 0, start
	)
	for path in [implicit_commute, stale_source_commute, implicit_facility]:
		var exit_index: int = -1
		var entrance_index: int = -1
		for index in range(path.size()):
			if path[index].distance_to(stage_workplace.front()) <= 0.1:
				exit_index = index
			if path[index].distance_to(warehouse_workplace.front()) <= 0.1:
				entrance_index = index
		_expect(
			path.size() >= 5
			and path.front().distance_to(start) < 0.1
			and path.back().distance_to(target) < 0.1
			and exit_index > 0 and entrance_index > exit_index,
			"Every inter-building commute must exit the source doorway before outdoor navigation."
		)
	var inside_to_inside: Array[Vector3] = studio.call(
		"get_workplace_path_from", stage.id, 1, start
	)
	var indoor_target: Array[Vector3] = stage_actor.call(
		"get_workplace_path", 1
	)
	var inside_routes_outside: bool = false
	for point in inside_to_inside:
		if point.distance_to(stage_workplace.front()) < 0.1:
			inside_routes_outside = true
	_expect(
		inside_to_inside.size() >= 2
		and inside_to_inside.front().distance_to(start) < 0.1
		and inside_to_inside.back().distance_to(indoor_target.back()) < 0.1
		and not inside_routes_outside,
		"Workstation changes inside one building must use indoor navigation, not exit and re-enter."
	)
	var roam_targets: Array[Vector3] = [
		Vector3(38.0, 0.0, 32.0),
		Vector3(40.0, 0.0, 34.0),
	]
	var indoor_to_roaming: Array[Vector3] = studio.call(
		"get_roaming_route", start, roam_targets
	)
	var roaming_outside_index: int = -1
	for index in range(indoor_to_roaming.size()):
		if indoor_to_roaming[index].distance_to(stage_workplace.front()) < 0.1:
			roaming_outside_index = index
	_expect(
		roaming_outside_index > 0
		and indoor_to_roaming.front().distance_to(start) < 0.1,
		"Leaving for free time must first reach the building exit, never traverse a wall."
	)

	var route: Array[Vector3] = studio.call(
		"get_scene_recovery_path", stage.id, start, target
	)
	var goes_through_outdoor: bool = false
	for point in route:
		if point.distance_to(stage_workplace.front()) < 0.3:
			goes_through_outdoor = true
	_expect(
		route.size() >= 5
		and route.front().distance_to(start) < 0.1
		and route.back().distance_to(target) < 0.1
		and goes_through_outdoor,
		"Cross-building recovery must use actual stage doorway and warehouse entrance."
	)
	var reversed_route: Array[Vector3] = studio.call(
		"get_scene_recovery_path", stage.id, target, start
	)
	_expect(
		reversed_route.size() >= 5
		and reversed_route.front().distance_to(target) < 0.1
		and reversed_route.back().distance_to(start) < 0.1,
		"Technicians must also be able to recover the return route from warehouse to stage."
	)

	# Prop technicians must share the same door-first routes in both
	# directions instead of using the obsolete direct-to-exterior builder.
	var worker := Node3D.new()
	root.add_child(worker)
	worker.global_position = start
	var characters := LogisticsCharacters.new()
	characters.worker = worker
	root.add_child(characters)
	var logistics: RefCounted = SET_LOGISTICS.new()
	logistics.call("setup", studio, characters, NAVIGATION.new(), null)
	var storage_mark: Vector3 = warehouse_actor.call("get_storage_mark", 0)
	var to_warehouse: Array[Vector3] = logistics.call(
		"_build_route_stage_to_warehouse",
		"TECHNICIAN", stage.id, warehouse.id, 0, start
	)
	var to_warehouse_uses_exit: bool = false
	for point in to_warehouse:
		if point.distance_to(stage_workplace.front()) < 0.1:
			to_warehouse_uses_exit = true
	_expect(
		to_warehouse.size() >= 5
		and to_warehouse_uses_exit
		and to_warehouse.back().distance_to(storage_mark) < 0.1,
		"Prop delivery must leave through the stage door before crossing the outdoor lot."
	)
	worker.global_position = storage_mark
	var set_mark: Vector3 = stage_actor.call("get_set_dressing_mark", 0)
	var to_stage: Array[Vector3] = logistics.call(
		"_build_route_warehouse_to_stage",
		"TECHNICIAN", stage.id, warehouse.id, 0, set_mark
	)
	var to_stage_uses_exit: bool = false
	for point in to_stage:
		if point.distance_to(warehouse_workplace.front()) < 0.1:
			to_stage_uses_exit = true
	_expect(
		to_stage.size() >= 5
		and to_stage_uses_exit
		and to_stage.front().distance_to(storage_mark) < 0.1
		and to_stage.back().distance_to(set_mark) < 0.1,
		"Warehouse returns must first exit through the warehouse door before entering the stage."
	)
	characters.free()
	worker.free()

	var parent := Node3D.new()
	parent.name = "CharacterManager"
	root.add_child(parent)
	var actor: Node3D = CHARACTER_ACTOR.new()
	parent.add_child(actor)
	actor.global_position = start
	actor.set("_workplace_building_id", stage.id)
	actor.set("_scene_target_position", target)
	actor.call("_recover_blocked_route", 1.3, "scene")
	var corrected: Array[Vector3] = actor.get("_scene_path")
	_expect(
		corrected.size() >= 5
		and corrected.back().distance_to(target) < 0.1,
		"CharacterActor must request cross-building recovery rather than a stage-only indoor path."
	)

	# Free-roaming employees must also replan when a newly placed wall blocks a waypoint.
	actor.global_position = Vector3(40.0, 0.0, 30.0)
	var roaming_targets: Array[Vector3] = [
		Vector3(35.0, 0.0, 30.0), Vector3(35.0, 0.0, 35.0),
	]
	actor.set("_route", roaming_targets)
	actor.set("_route_index", 1)
	actor.call("_recover_blocked_route", 1.3, "roaming")
	var roaming_replan: Array[Vector3] = actor.get("_route")
	_expect(
		roaming_replan.size() >= 3
		and roaming_replan.front().distance_to(actor.global_position) < 0.1,
		"An outdoor collision must trigger fresh pathfinding instead of endless wall pressing."
	)

	# Half-meter waypoint skipping previously discarded mandatory turns.
	var corner_path: Array[Vector3] = [
		Vector3(2.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.4),
		Vector3(2.0, 0.0, 1.5),
	]
	actor.global_position = Vector3(2.3, 0.0, 0.4)
	actor.set("_workplace_path", corner_path)
	actor.set("_workplace_path_index", 1)
	actor.call("_process_workplace_movement", 0.1)
	_expect(
		int(actor.get("_workplace_path_index")) == 1,
		"Workplace route must not skip a corner that is still thirty centimeters away."
	)
	parent.free()
	studio.free()
	_finish_test("StudioCrossBuildingRecoverySmokeTest")
