extends "res://tests/smoke_test_base.gd"

const WORLD = preload("res://scenes/main.tscn")
const CONVERSATIONS = preload("res://scripts/presentation/characters/studio_lounge_conversations.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var world := WORLD.instantiate() as Node3D
	root.add_child(world)
	var clock := world.get_node("GameClock") as GameClock
	var manager := world.get_node("StudioBuildingManager") as StudioBuildingManager
	var data: Variant = manager.call("_create_building", "editing_suite", Vector3(-14, 0, 14), 90.0)
	var building := manager.get_building_actor_by_id(str(data.id)) as StudioBuildingActor
	_test_cutaway(world, building)
	var slot := building.get_office_interaction(1)
	var route := building.get_workplace_path(1)
	var worker := _add_worker(world, clock, "TEST-EDITOR", "film_editor", route.front())
	var duplicate := _add_worker(world, clock, "TEST-SECOND", "film_editor", route.front())
	worker.assign_workplace_route(building.get_building_id(), route, "film_editor", route, 1)
	_expect(slot.slot_id == "%s/office/1" % data.id and route.back().is_equal_approx(slot.global_position),
		"Office station IDs and path endpoints must refer to the rotated station.")
	_expect(route[route.size() - 2].is_equal_approx(slot.get_node("Approach").global_position),
		"The workplace route must approach from the side before reaching the chair.")
	worker.snap_to_workplace()
	worker.call("_process", 0.5)
	_expect(slot.get_occupant() == worker and not slot.try_reserve(duplicate),
		"A working employee reserves the station exclusively.")
	var body := worker.get_node("CharacterVisual/BodyRoot") as Node3D
	_expect(body.position.y < -0.20 and (-worker.global_basis.z).dot(-slot.global_basis.z) > 0.99,
		"The worker must align to the furniture and lower into the seat.")
	var skeleton := worker.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for side in ["Left", "Right"]:
		var pose := skeleton.get_bone_global_pose(skeleton.find_bone(side + "Forearm"))
		var wrist := skeleton.to_global(pose * Vector3(0, -0.36, 0))
		var target := slot.get_node(side + "Hand") as Marker3D
		_expect(wrist.distance_to(target.global_position) < 0.115, "The wrist must reach its own keyboard marker.")
	clock.set_speed_mode(GameClock.SpeedMode.PAUSED)
	var paused_pose := body.transform
	worker.call("_process", 0.5)
	_expect(body.transform.is_equal_approx(paused_pose) and slot.get_occupant() == worker,
		"Pause must preserve pose and station ownership.")
	clock.set_speed_mode(GameClock.SpeedMode.FAST)
	worker.leave_workplace()
	worker.call("_process", 0.14)
	_expect(slot.get_occupant() == null and body.position.y > -0.11,
		"Leaving the station must release the reservation and stand up at accelerated speed.")
	duplicate.assign_workplace_route(building.get_building_id(), route, "film_editor", route, 1)
	duplicate.snap_to_workplace()
	_expect(slot.get_occupant() == duplicate, "A released station must be reusable.")
	building.free()
	_expect(not duplicate.is_at_workplace(), "Removing a workstation must clear its active interaction.")
	_test_conversation(world, clock)
	world.free()
	_finish_test("OfficeInteractionSmokeTest")


func _test_cutaway(world: Node3D, building: StudioBuildingActor) -> void:
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	building.set_selected(true)
	var directions := {"Front": Vector3.BACK, "Back": Vector3.FORWARD, "Left": Vector3.LEFT, "Right": Vector3.RIGHT}
	var all_open: bool = true
	for facing in directions:
		camera.global_position = building.to_global(directions[facing] * 12.0 + Vector3.UP * 5.0)
		building.call("_update_cutaway")
		for other in directions:
			var wall := building.get_node("Interior/%sWallGroup" % other) as Node3D
			all_open = all_open and (wall.visible == (other != facing))
	_expect(all_open and not building.get_node("RoofAssembly").visible,
		"Cutaway must suppress the near wall from each direction of a rotated building.")
	camera.free()


func _test_conversation(world: Node3D, clock: GameClock) -> void:
	var first := _add_worker(world, clock, "FRIEND-A", "actor", Vector3(37, 0, 0))
	var second := _add_worker(world, clock, "FRIEND-B", "actor", Vector3(39, 0, 0))
	var actors := {"FRIEND-A": first, "FRIEND-B": second}
	for actor in [first, second]:
		actor.character_data.personality["sociability"] = 0.8
		var route: Array[Vector3] = [actor.global_position]
		actor.assign_facility_route("LOUNGE", "studio_lounge", 0, route, "socializing")
	var conversations := CONVERSATIONS.new()
	var cohorts := {"LOUNGE": [first.character_data, second.character_data]}
	conversations.update(cohorts, actors, 0)
	var first_turn: String = first.get("_lounge_action")
	_expect(first_turn in ["speaking", "waiting"] and first_turn != str(second.get("_lounge_action")),
		"Two willing lounge visitors must face one another and alternate conversation roles.")
	conversations.update(cohorts, actors, 3)
	_expect(first_turn != str(first.get("_lounge_action")), "Speaking roles must alternate over game time.")
	conversations.update({}, actors, 4)
	_expect(str(first.get("_lounge_action")).is_empty() and first.is_at_facility("studio_lounge"),
		"Ending a conversation must restore the lounge activity without changing occupancy.")


func _add_worker(world: Node3D, clock: GameClock, id: String, profession: String, start: Vector3) -> CharacterActor:
	var data := CharacterData.new()
	data.id = id
	data.profession_id = profession
	var actor := CharacterActor.new()
	var route: Array[Vector3] = [start]
	actor.setup(data, route, clock)
	world.add_child(actor)
	return actor
