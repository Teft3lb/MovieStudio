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
