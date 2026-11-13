extends "res://tests/smoke_test_base.gd"

const BUILDING_MANAGER = preload(
	"res://scripts/presentation/studio/studio_building_manager.gd"
)
const BUILDING_ACTOR = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const CHARACTER_ACTOR = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const NAVIGATION = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var studio: Node3D = BUILDING_MANAGER.new()
	studio.name = "StudioBuildingManager"
	studio.set("_navigation_system", NAVIGATION.new())
	root.add_child(studio)
	var building: Variant = BUILDING_DATA.new()
	building.id = "STAGE-RECOVERY"
	building.building_type_id = "sound_stage"
	building.stage_size_tier = 3
	building.position = Vector3(0.0, 0.0, 0.0)
	var stage: Node3D = BUILDING_ACTOR.new()
	stage.call("setup", building)
	studio.add_child(stage)
	studio.set("_buildings", [building])
	studio.set("_building_actors", {building.id: stage})

	var route: Array[Vector3] = stage.call("get_workplace_path", 0)
	_expect(
		route.size() >= 4
		and route.front().z > 9.0
		and route.back().z < 9.0,
		"A large stage's work path must enter through the doorway and reach an indoor work slot."
	)
	var replan: Array[Vector3] = studio.call(
		"get_employee_recovery_path",
		building.id,
		0,
		route[1],
		false
	)
	_expect(
		replan.size() >= 2
		and replan.front().distance_to(route[1]) < 0.2
		and replan.back().distance_to(route.back()) < 0.2,
		"Recovery must rebuild an interior AStar route without teleporting the employee."
	)

	var exit_route: Array[Vector3] = studio.call(
		"get_employee_recovery_path",
		building.id,
		0,
		route.back(),
		true
	)
	_expect(
		exit_route.size() >= 2
		and exit_route.back().distance_to(route.front()) < 0.2,
		"Recovery must guide an employee back out through the correct entrance."
	)

	var character_manager := Node3D.new()
	character_manager.name = "CharacterManager"
	root.add_child(character_manager)
	var actor: Node3D = CHARACTER_ACTOR.new()
	character_manager.add_child(actor)
	actor.global_position = route[1]
	actor.set("_workplace_building_id", building.id)
	actor.set("_workplace_slot_index", 0)
	actor.call("_recover_blocked_route", 1.3, "workplace")
	var repaired: Array[Vector3] = actor.get("_workplace_path")
	_expect(
		repaired.size() >= 2
		and repaired.back().distance_to(route.back()) < 0.2,
		"CharacterActor must consume a rebuilt route after a sustained obstruction."
	)

	var bounds: Rect2 = studio.call(
		"_get_outdoor_navigation_bounds",
		Vector3(60.0, 0.0, 60.0),
		Vector3(70.0, 0.0, 70.0)
	)
	_expect(
		bounds.has_area()
		and bounds.has_point(Vector2(65.0, 65.0)),
		"Navigation bounds must include the expanded studio plot rather than the old 94-by-94 site."
	)
	actor.free()
	character_manager.free()
	studio.free()
	_finish_test("StudioNavigationRecoverySmokeTest")
