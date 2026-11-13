extends "res://tests/smoke_test_base.gd"

const PUBLICITY_CONTROLLER = preload(
	"res://scripts/presentation/studio/studio_publicity_event_controller.gd"
)
const GENERATOR = preload(
	"res://scripts/domain/characters/character_generator.gd"
)


class FakeClock extends Node:
	var current_day: int = 1
	var is_manual_fast_forward: bool = true

	func get_simulation_delta(delta: float) -> float:
		return delta


class FakeBuilding extends RefCounted:
	var id: String = "STAGE-01"
	var is_operational: bool = true
	var building_type_id: String = "sound_stage"


class FakeActor extends Node3D:
	var _workplace_slot_index: int = 0
	var _scene_target_position: Vector3
	var _scene_active: bool = false
	var _arrived: bool = false
	var _returned: bool = false

	func start_scene_performance(
		target: Vector3,
		_focus: Vector3,
		_action: String,
		_text: String = "",
		_route: Array = [],
		_allow_unassigned: bool = false
	) -> void:
		_scene_target_position = target
		_scene_active = true
		_arrived = false

	func snap_to_scene_mark() -> void:
		if not _scene_active:
			return
		global_position = _scene_target_position
		_arrived = true

	func is_at_scene_mark() -> bool:
		return _scene_active and _arrived

	func get_workplace_building_id() -> String:
		return ""

	func return_to_workplace(_path: Array = []) -> void:
		_returned = true
		_scene_active = false


class FakeCharacters extends Node:
	var staff: Array = []
	var actors: Dictionary = {}

	func get_employees() -> Array:
		return staff

	func get_employee_actor(employee_id: String) -> Node:
		return actors.get(employee_id) as Node


class FakeStudio extends Node3D:
	func get_buildings() -> Array:
		return [FakeBuilding.new()]

	func get_workplace_path(
		_building_id: String, _slot: int
	) -> Array[Vector3]:
		return [Vector3(10.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0)]

	func get_roaming_route(
		start: Vector3, base: Array[Vector3]
	) -> Array[Vector3]:
		return [start, base.front(), base.back()]

	func get_scene_recovery_path(
		_building_id: String,
		start: Vector3, goal: Vector3
	) -> Array[Vector3]:
		return [start, goal]

	func is_employee_in_active_production(_id: String) -> bool:
		return false

	func is_employee_in_active_editing(_id: String) -> bool:
		return false


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var clock := FakeClock.new()
	var studio := FakeStudio.new()
	var characters := FakeCharacters.new()
	root.add_child(clock)
	root.add_child(studio)
	root.add_child(characters)
	var generator: RefCounted = GENERATOR.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 81461
	var star: Variant = generator.call(
		"generate", rng, "PUBLIC-STAR", "actor", true
	)
	star.recognition = 48.0
	star.needs = {"energy": 1.0, "morale": 0.8, "stress": 0.10}
	characters.staff.append(star)
	var star_actor := FakeActor.new()
	studio.add_child(star_actor)
	characters.actors[str(star.id)] = star_actor
	var guards: Array = []
	for index in range(2):
		var guard: Variant = generator.call(
			"generate", rng, "SEC-%d" % index, "security_guard", true
		)
		guard.skills["security"] = 80.0
		guards.append(guard)
		characters.staff.append(guard)
		var guard_actor := FakeActor.new()
		studio.add_child(guard_actor)
		characters.actors[str(guard.id)] = guard_actor

	var controller: RefCounted = PUBLICITY_CONTROLLER.new()
	controller.call("setup", studio, characters, clock)
	var invitation: Dictionary = controller.call(
		"request_event", str(star.id), "fan_meet"
	)
	_expect(
		bool(invitation.get("success", false))
		and int(invitation.get("guards_assigned", 0)) == 2
		and int(invitation.get("visitor_count", 0)) >= 4,
		"Inviting fans must spawn a crowd and route two existing guards to the event."
	)
	# Keep the empty background-performer list explicitly typed: GDScript
	# does not implicitly convert a literal [] to Array[String] in call().
	var background_ids: Array[String] = []
	_expect(
		bool(controller.call("is_participant", str(star.id)))
		and bool(controller.call("is_participant", str(guards[0].id)))
		and bool(controller.call("has_staff_conflict",
			{}, {"LEAD": str(star.id)}, background_ids
		)),
		"Public event participants must be reserved from film production."
	)
	_expect(
		not bool(controller.call(
			"has_staff_conflict", {}, {"LEAD": "UNRELATED"}, background_ids
		)),
		"Unrelated film personnel must remain available during a fan event."
	)
	var blocked: Dictionary = controller.call(
		"request_event", str(star.id), "paparazzi"
	)
	_expect(
		not bool(blocked.get("success", false)),
		"Only one outdoor celebrity event may be hosted at once."
	)
	for minute in range(60):
		controller.call("advance_minute", 1, 10, minute)
	var first_result: Dictionary = controller.call("get_last_result")
	_expect(
		controller.call("get_active_event").is_empty()
		and bool(first_result.get("completed", false))
		and int(first_result.get("guards_present", 0)) == 2
		and star_actor._returned,
		"The fully attended event must finish, book the protection and release the star."
	)
	var guarded_stress: float = float(first_result.get("stress_delta", 1.0))
	var cooldown: Dictionary = controller.call(
		"request_event", str(star.id), "fan_meet"
	)
	_expect(
		not bool(cooldown.get("success", false)),
		"Fan meets must not be farmable multiple times in one game day."
	)

	clock.current_day = 3
	for employee in guards:
		employee.profession_id = "technician"
	star.needs = {"energy": 1.0, "morale": 0.8, "stress": 0.10}
	star_actor._returned = false
	var solo: Dictionary = controller.call(
		"request_event", str(star.id), "fan_meet"
	)
	_expect(
		bool(solo.get("success", false))
		and int(solo.get("guards_assigned", -1)) == 0,
		"A second event should run without security when none is available."
	)
	for minute in range(60):
		controller.call("advance_minute", 3, 10, minute)
	var solo_result: Dictionary = controller.call("get_last_result")
	_expect(
		bool(solo_result.get("completed", false))
		and float(solo_result.get("stress_delta", 0.0)) > guarded_stress,
		"The same star must accumulate more stress without guards physically present."
	)
	studio.free()
	characters.free()
	clock.free()
	_finish_test("StudioPublicityEventSmokeTest")
