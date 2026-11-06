extends "res://tests/smoke_test_base.gd"

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const GAME_CLOCK_SCRIPT = preload(
	"res://scripts/core/game_clock.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const CHARACTER_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/characters/character_manager.gd"
)
const CHARACTER_NEEDS_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_needs_system.gd"
)
const STUDIO_BUILDING_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_manager.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


class FakeWorkplaceManager extends Node:
	var workplace_position: Vector3 = Vector3(0.0, 0.0, -3.0)
	var active_production_employee_id: String = ""
	var active_editing_employee_id: String = ""

	func is_employee_in_active_production(employee_id: String) -> bool:
		return employee_id == active_production_employee_id

	func is_employee_in_active_editing(employee_id: String) -> bool:
		return employee_id == active_editing_employee_id

	func get_workplace_path_from(
		_building_id: String,
		_slot_index: int,
		start_position: Vector3
	) -> Array[Vector3]:
		var route: Array[Vector3] = [start_position, workplace_position]
		return route

	func get_workplace_position(
		_building_id: String,
		_slot_index: int
	) -> Vector3:
		return workplace_position

	func get_scene_path(
		_building_id: String,
		start_position: Vector3,
		target_position: Vector3
	) -> Array[Vector3]:
		var route: Array[Vector3] = [start_position, target_position]
		return route


func _run_tests() -> void:
	_test_character_moves_and_performs_scene()
	_test_off_shift_crew_returns_to_stage()
	_test_stage_bystander_moves_off_camera_and_returns()
	_test_idle_production_staff_roam_until_dispatched()
	_test_camera_crew_remains_at_workstations()
	_finish_test("FilmScenePerformanceSmokeTest")


func _test_off_shift_crew_returns_to_stage() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 778899
	var employee: Variant = generator.call(
		"generate",
		rng,
		"EMP-OFF-SHIFT-DIRECTOR",
		"director"
	)
	employee.work_state = "off_shift"
	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	clock.call("set_speed_mode", 1)

	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	var initial_position: Vector3 = Vector3(6.0, 0.0, 5.0)
	var initial_waypoints: Array[Vector3] = [
		initial_position,
		initial_position + Vector3.RIGHT,
	]
	actor.call(
		"setup",
		employee,
		initial_waypoints,
		clock,
		2.0
	)
	var initialized_visual: Node = actor.get_node_or_null("CharacterVisual")
	_expect(
		actor.get("character_data") == employee
		and initialized_visual != null,
		"CharacterActor.setup must initialize the employee and visual before workplace dispatch."
	)
	if actor.get("character_data") != employee or initialized_visual == null:
		actor.free()
		clock.free()
		return
	actor.global_position = initial_position

	var fake_building_manager := FakeWorkplaceManager.new()
	var character_manager: Node = CHARACTER_MANAGER_SCRIPT.new()
	character_manager.set("employees", [employee])
	character_manager.set("_employee_actors", {
		"EMP-OFF-SHIFT-DIRECTOR": actor,
	})
	character_manager.set("_workplace_assignments", {
		"EMP-OFF-SHIFT-DIRECTOR": {
			"building_id": "BLD-TEST-STAGE",
			"building_type_id": "sound_stage",
			"slot_index": 0,
		},
	})
	character_manager.set("_studio_building_manager", fake_building_manager)

	_expect(
		str(character_manager.call(
			"_get_production_participant_status",
			"EMP-OFF-SHIFT-DIRECTOR"
		)) == "Направляется на площадку",
		"An off-shift production participant must be shown as travelling, not already on set."
	)
	var ready_before_dispatch: bool = character_manager.call(
		"dispatch_employee_to_workplace",
		"EMP-OFF-SHIFT-DIRECTOR"
	)
	_expect(
		not ready_before_dispatch
		and str(actor.call("get_workplace_building_id")) == "BLD-TEST-STAGE",
		"An off-shift production crew member must receive a route back to the Sound Stage."
	)
	for _step in range(30):
		actor.call("_process", 1.0)
	_expect(
		bool(character_manager.call(
			"dispatch_employee_to_workplace",
			"EMP-OFF-SHIFT-DIRECTOR"
		)),
		"Production crew readiness must become true after the employee reaches the stage workstation."
	)
	_expect(
		bool(actor.call("is_at_workplace")),
		"The dispatched employee must physically arrive at the assigned stage workstation."
	)
	_expect(
		str(character_manager.call(
			"_get_production_participant_status",
			"EMP-OFF-SHIFT-DIRECTOR"
		)) == "На площадке",
		"An arrived production participant must be shown as present on the Sound Stage."
	)

	actor.call("leave_workplace")
	for _step in range(30):
		actor.call("_process", 1.0)
	_expect(
		str(actor.call("get_workplace_building_id")).is_empty()
		and not bool(actor.call("is_leaving_workplace")),
		"A employee must be able to leave the Sound Stage after being released from the scene."
	)
	var roaming_position: Vector3 = actor.global_position
	actor.call("_process", 0.25)
	_expect(
		actor.global_position.distance_to(roaming_position) > 0.1,
		"A released employee must resume the studio's free-roaming route."
	)
	var recalled_before_arrival: bool = character_manager.call(
		"dispatch_employee_to_workplace",
		"EMP-OFF-SHIFT-DIRECTOR"
	)
	_expect(
		not recalled_before_arrival
		and str(actor.call("get_workplace_building_id")) == "BLD-TEST-STAGE",
		"A employee must be recalled to the Sound Stage when rehearsal is ready."
	)
	for _step in range(30):
		actor.call("_process", 1.0)
	_expect(
		bool(character_manager.call(
			"dispatch_employee_to_workplace",
			"EMP-OFF-SHIFT-DIRECTOR"
		))
		and bool(actor.call("is_at_workplace")),
		"A recalled employee must physically return to the Sound Stage."
	)
	character_manager.free()
	fake_building_manager.free()
	actor.free()
	clock.free()


func _test_stage_bystander_moves_off_camera_and_returns() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 445566
	var employee: Variant = generator.call(
		"generate",
		rng,
		"EMP-OFF-CAMERA-CREW",
		"camera_operator"
	)
	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	clock.call("set_speed_mode", 1)

	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	var workplace_position: Vector3 = Vector3(0.0, 0.0, -2.0)
	var initial_position: Vector3 = Vector3.ZERO
	var initial_waypoints: Array[Vector3] = [
		initial_position,
		initial_position + Vector3.RIGHT,
	]
	var workplace_route: Array[Vector3] = [
		initial_position,
		workplace_position,
	]
	actor.call("setup", employee, initial_waypoints, clock, 2.0)
	actor.call(
		"assign_workplace_route",
		"BLD-OFF-CAMERA-STAGE",
		workplace_route,
		"camera_operator"
	)
	for _step in range(30):
		actor.call("_process", 1.0)
	_expect(
		bool(actor.call("is_at_workplace")),
		"A stage bystander must begin from an arrived workstation."
	)

	var hold_position: Vector3 = Vector3(0.0, 0.0, 4.4)
	var hold_route: Array[Vector3] = [
		workplace_position,
		hold_position,
	]
	actor.call("move_to_scene_hold", hold_position, hold_route)
	_expect(
		bool(actor.call("is_off_camera"))
		and not bool(actor.call("is_at_scene_hold_mark"))
		and not bool(actor.call("is_in_scene_performance")),
		"An off-camera employee must be marked as leaving the frame, not as a performer."
	)
	for _step in range(30):
		actor.call("_process", 1.0)
	_expect(
		bool(actor.call("is_at_scene_hold_mark"))
		and actor.global_position.distance_to(hold_position) <= 0.25,
		"A stage bystander must reach a holding mark behind the camera line."
	)

	var return_route: Array[Vector3] = [
		hold_position,
		workplace_position,
	]
	actor.call("return_to_workplace", return_route)
	for _step in range(30):
		actor.call("_process", 1.0)
	_expect(
		not bool(actor.call("is_off_camera"))
		and bool(actor.call("is_at_workplace"))
		and actor.global_position.distance_to(workplace_position) <= 0.25,
		"An off-camera employee must return to the original workstation after the take."
	)
	actor.free()
	clock.free()


func _test_idle_production_staff_roam_until_dispatched() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 889900
	var employee: Variant = generator.call(
		"generate",
		rng,
		"EMP-IDLE-DIRECTOR",
		"director"
	)
	employee.shift_start_hour = 8
	employee.shift_end_hour = 17
	employee.break_start_hour = 12
	employee.break_end_hour = 13
	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	clock.set("is_manual_fast_forward", true)
	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	var initial_route: Array[Vector3] = []
	actor.call("setup", employee, initial_route, clock, 1.5)
	var workplace_manager := FakeWorkplaceManager.new()
	root.add_child(workplace_manager)
	var character_manager: Node = CHARACTER_MANAGER_SCRIPT.new()
	character_manager.set("employees", [employee])
	character_manager.set("_employee_actors", {
		str(employee.id): actor,
	})
	character_manager.set("_workplace_assignments", {
		str(employee.id): {
			"building_id": "BLD-TEST-STAGE",
			"building_type_id": "sound_stage",
			"slot_index": 2,
		},
	})
	character_manager.set("_studio_building_manager", workplace_manager)
	character_manager.set("_game_clock", clock)
	character_manager.set(
		"_needs_system",
		CHARACTER_NEEDS_SYSTEM_SCRIPT.new()
	)

	character_manager.call("_on_game_minute_advanced", 1, 9, 0)
	_expect(
		str(actor.call("get_workplace_building_id")).is_empty()
		and not bool(actor.call("is_at_workplace")),
		"An idle director must remain on the studio roaming route instead of being sent to an empty Sound Stage."
	)
	_expect(
		bool(character_manager.call(
			"dispatch_employee_to_workplace",
			str(employee.id)
		))
		and bool(actor.call("is_at_workplace")),
		"An idle production employee must still be dispatchable when a rehearsal or shoot explicitly calls them."
	)

	workplace_manager.active_production_employee_id = str(employee.id)
	character_manager.call("_on_game_minute_advanced", 1, 9, 1)
	_expect(
		bool(actor.call("is_at_workplace")),
		"An employee assigned to the active production must remain at the Sound Stage."
	)
	workplace_manager.active_production_employee_id = ""
	character_manager.call("_on_game_minute_advanced", 1, 9, 2)
	_expect(
		bool(actor.call("is_leaving_workplace")),
		"Once production releases the employee, an idle director must leave the Sound Stage again."
	)
	actor.call("snap_outside_workplace")
	_expect(
		str(actor.call("get_workplace_building_id")).is_empty(),
		"A released production employee must return to free roaming."
	)

	character_manager.free()
	actor.free()
	workplace_manager.free()
	clock.free()


func _test_camera_crew_remains_at_workstations() -> void:
	var studio_manager: Node = STUDIO_BUILDING_MANAGER_SCRIPT.new()
	_expect(
		not bool(studio_manager.call(
			"_should_move_stage_employee_off_camera",
			"EMP-CAMERA",
			[],
			[],
			["EMP-CAMERA"]
		)),
		"The camera operator must remain at the camera rig instead of being moved to a generic holding mark."
	)
	_expect(
		not bool(studio_manager.call(
			"_should_move_stage_employee_off_camera",
			"EMP-DIRECTOR",
			[],
			[],
			["EMP-DIRECTOR"]
		)),
		"The director must remain at the production monitor during the take."
	)
	_expect(
		not bool(studio_manager.call(
			"_should_move_stage_employee_off_camera",
			"EMP-CAST",
			[],
			["EMP-CAST"],
			[]
		)),
		"Cast members must not be treated as generic stage bystanders."
	)
	_expect(
		bool(studio_manager.call(
			"_should_move_stage_employee_off_camera",
			"EMP-BYSTANDER",
			[],
			[],
			[]
		)),
		"Only non-cast, non-crew bystanders should be moved behind the camera line."
	)
	studio_manager.free()


func _test_character_moves_and_performs_scene() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 556677
	var employee: Variant = generator.call(
		"generate",
		rng,
		"EMP-SCENE-PERFORMER",
		"actor"
	)

	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	clock.call("set_speed_mode", 1)

	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	var initial_waypoints: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
	]
	actor.call(
		"setup",
		employee,
		initial_waypoints,
		clock,
		2.0
	)
	var initialized_visual: Node = actor.get_node_or_null("CharacterVisual")
	_expect(
		actor.get("character_data") == employee
		and initialized_visual != null,
		"CharacterActor.setup must initialize the employee and visual before scene performance."
	)
	if actor.get("character_data") != employee or initialized_visual == null:
		actor.free()
		clock.free()
		return
	var route: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -1.0),
		Vector3(0.0, 0.0, -2.0),
		Vector3(0.0, 0.0, -3.0),
	]
	actor.call(
		"assign_workplace_route",
		"BLD-TEST-STAGE",
		route,
		"actor"
	)

	for _step in range(30):
		actor.call("_process", 1.0)
	_expect(
		bool(actor.call("is_at_workplace")),
		"An actor must reach the assigned Sound Stage workstation first."
	)

	var scene_mark: Vector3 = Vector3(1.5, 0.0, -2.5)
	actor.call(
		"start_scene_performance",
		scene_mark,
		Vector3(-1.0, 0.0, -2.5),
		"speaking",
		"«Ты тоже это слышал?»"
	)
	for _step in range(30):
		actor.call("_process", 1.0)

	_expect(
		bool(actor.call("is_at_scene_mark")),
		"An actor must physically move from the workstation to the scene mark."
	)
	_expect(
		actor.global_position.distance_to(scene_mark) <= 0.25,
		"The actor must finish at the blocking position on the set."
	)
	_expect(
		bool(actor.call("is_scene_animation_active")),
		"The actor must play a distinct performance animation."
	)
	var left_arm: Node3D = actor.get_node(
		"CharacterVisual/BodyRoot/LeftArmPivot"
	) as Node3D
	var minimum_gesture: float = left_arm.rotation.x
	var maximum_gesture: float = left_arm.rotation.x
	for _step in range(20):
		actor.call("_process", 0.05)
		minimum_gesture = minf(minimum_gesture, left_arm.rotation.x)
		maximum_gesture = maxf(maximum_gesture, left_arm.rotation.x)
	_expect(
		maximum_gesture - minimum_gesture > 0.08,
		"Actor gestures must visibly change over time during a scene performance."
	)
	var dialogue_label: Label3D = actor.get_node("SceneDialogue") as Label3D
	_expect(
		dialogue_label.visible
		and dialogue_label.text.contains("Ты тоже это слышал"),
		"The speaking character must display its assigned dialogue."
	)
	var mouth: MeshInstance3D = actor.get_node(
		"CharacterVisual/BodyRoot/Head/Mouth"
	) as MeshInstance3D
	_expect(mouth != null, "Character model must expose a mouth mesh.")
	if is_instance_valid(mouth):
		var minimum_mouth_scale: float = mouth.scale.y
		var maximum_mouth_scale: float = mouth.scale.y
		for _step in range(20):
			actor.call("_process", 0.05)
			minimum_mouth_scale = minf(minimum_mouth_scale, mouth.scale.y)
			maximum_mouth_scale = maxf(maximum_mouth_scale, mouth.scale.y)
		_expect(
			maximum_mouth_scale - minimum_mouth_scale > 0.2,
			"Speaking actors must animate their mouth in addition to gestures and subtitles."
		)

	var next_scene_mark: Vector3 = Vector3(2.0, 0.0, -2.0)
	actor.call(
		"start_scene_performance",
		next_scene_mark,
		Vector3(-1.0, 0.0, -2.5),
		"dramatic",
		""
	)
	for _step in range(30):
		actor.call("_process", 1.0)
	_expect(
		actor.global_position.distance_to(next_scene_mark) <= 0.25,
		"The actor must move to new blocking when the scene phase changes."
	)
	_expect(
		not dialogue_label.visible,
		"Dialogue subtitles must disappear when the actor is not speaking."
	)
	actor.call("return_to_workplace")
	for _step in range(30):
		actor.call("_process", 1.0)

	_expect(
		not bool(actor.call("is_in_scene_performance")),
		"The actor must leave scene blocking after production work."
	)
	_expect(
		actor.global_position.distance_to(route[route.size() - 1]) <= 0.25,
		"The actor must return to the assigned workstation after the scene."
	)
	_expect(
		not bool(actor.call("is_scene_animation_active")),
		"The scene performance animation must stop after returning to work."
	)
	actor.free()
	clock.free()
