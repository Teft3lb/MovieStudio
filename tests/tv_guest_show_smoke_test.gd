extends "res://tests/smoke_test_base.gd"

const CHARACTER_GENERATOR = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const CELEBRITY = preload(
	"res://scripts/domain/characters/celebrity_system.gd"
)
const INVITATION_POLICY = preload(
	"res://scripts/domain/tv_production/tv_show_invitation_policy.gd"
)
const GUEST_SHOW_CONTROLLER = preload(
	"res://scripts/presentation/studio/tv_guest_show_controller.gd"
)


class FakeClock extends Node:
	var current_day: int = 1
	var current_hour: int = 10
	var current_minute: int = 0
	var is_manual_fast_forward: bool = true

	func get_simulation_delta(delta: float) -> float:
		return delta


class FakeGuestActor extends Node3D:
	var _has_workplace_destination: bool = true
	var _workplace_slot_index: int = 0
	var _scene_target_position: Vector3 = Vector3.ZERO
	var _at_scene_mark: bool = false
	var last_return_path: Array[Vector3] = []

	func start_scene_performance(
		target_position: Vector3,
		_focus_position: Vector3,
		_action_id: String,
		_dialogue_text: String = "",
		_movement_path: Array = []
	) -> void:
		_scene_target_position = target_position
		_at_scene_mark = false

	func snap_to_scene_mark() -> void:
		global_position = _scene_target_position
		_at_scene_mark = true

	func is_at_scene_mark() -> bool:
		return _at_scene_mark

	func get_workplace_building_id() -> String:
		return "HOME-STAGE"

	func return_to_workplace(path: Array = []) -> void:
		last_return_path.assign(path)
		_at_scene_mark = false


class FakeStudio extends Node3D:
	var tv_building: Node3D
	var busy_ids: Array[String] = []

	func get_building_actor_by_id(building_id: String) -> Node3D:
		if building_id == "TV-STAGE":
			return tv_building
		return null

	func get_workplace_path(
		_building_id: String,
		slot_index: int
	) -> Array[Vector3]:
		var location: Vector3 = (
			Vector3(-2.0, 0.0, 0.5)
			if slot_index == 1
			else Vector3(0.0, 0.0, 0.5)
		)
		return [
			Vector3(0.0, 0.0, 8.0),
			Vector3(0.0, 0.0, 6.0),
			location,
		]

	func get_workplace_path_from(
		building_id: String,
		slot_index: int,
		start_position: Vector3,
		_source_building_id: String = "",
		_source_slot_index: int = 0
	) -> Array[Vector3]:
		var target: Vector3 = (
			Vector3(12.0, 0.0, 0.0)
			if building_id == "HOME-STAGE"
			else get_workplace_path(building_id, slot_index).back()
		)
		return [
			start_position,
			Vector3(0.0, 0.0, 8.0),
			target,
		]

	func get_scene_recovery_path(
		_source_building_id: String,
		start_position: Vector3,
		target_position: Vector3
	) -> Array[Vector3]:
		return [
			start_position,
			Vector3(0.0, 0.0, 8.0),
			target_position,
		]

	func get_workplace_position(
		building_id: String, slot_index: int
	) -> Vector3:
		return get_workplace_path(building_id, slot_index).back()

	func get_exit_path_from(
		_building_id: String,
		start_position: Vector3,
		_slot_index: int = 0
	) -> Array[Vector3]:
		return [start_position, Vector3(0.0, 0.0, 8.0)]

	func is_employee_in_active_production(employee_id: String) -> bool:
		return busy_ids.has(employee_id)

	func is_employee_in_active_film_production(employee_id: String) -> bool:
		return busy_ids.has(employee_id)

	func is_employee_in_active_editing(_employee_id: String) -> bool:
		return false


class FakeCharacters extends Node:
	var employees: Array = []
	var guest_actor: Node3D

	func get_employees() -> Array:
		return employees

	func get_employee_actor(_employee_id: String) -> Node:
		return guest_actor

	func get_employees_assigned_to_building(_building_id: String) -> Array:
		return [employees[1], employees[2], employees[3]]

	func is_employee_at_workplace(
		_employee_id: String, _building_type_id: String = ""
	) -> bool:
		return true

	func dispatch_employee_to_workplace(_employee_id: String) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	var generator: RefCounted = CHARACTER_GENERATOR.new()
	var star: Variant = generator.call(
		"generate", rng, "STAR-01", "actor", true
	)
	var director: Variant = generator.call(
		"generate", rng, "DIRECTOR-01", "director", true
	)
	var camera: Variant = generator.call(
		"generate", rng, "CAMERA-01", "camera_operator", true
	)
	var technician: Variant = generator.call(
		"generate", rng, "TECH-01", "technician", true
	)
	var roster: Array = [star, director, camera, technician]
	var policy: RefCounted = INVITATION_POLICY.new()
	star.recognition = 69.9
	_expect(
		not bool(policy.call("is_eligible_guest", star)),
		"69.9 percent recognition must not unlock television invitations."
	)
	star.recognition = 70.0
	_expect(
		bool(policy.call("is_eligible_guest", star)),
		"70 percent recognition unlocks a television host invitation."
	)
	director.recognition = 85.0
	_expect(
		bool(policy.call("is_eligible_guest", director)),
		"Recognized directors must qualify as talk-show guests too."
	)
	_expect(
		not bool(policy.call("is_eligible_guest", camera)),
		"Camera operators must not be invited as celebrity guests."
	)
	var busy: Array[String] = [str(camera.id)]
	var crew: Dictionary = policy.call("choose_crew", roster, str(star.id), busy)
	_expect(
		not bool(policy.call("has_complete_crew", crew)),
		"An unavailable camera operator must prevent production readiness."
	)
	var no_busy: Array[String] = []
	var small_tv_crew: Dictionary = policy.call(
		"choose_crew", [camera, technician], str(director.id), no_busy
	)
	small_tv_crew = policy.call(
		"allow_guest_director", small_tv_crew, director
	)
	_expect(
		bool(policy.call("has_complete_crew", small_tv_crew))
		and str(small_tv_crew.get("director", "")) == str(director.id),
		"A director guest can co-direct their interview without forcing another employee hire."
	)
	var celebrity: RefCounted = CELEBRITY.new()
	var before_film: float = float(director.recognition)
	celebrity.call("apply_film_release", director, true, 85.0)
	_expect(
		float(director.recognition) > before_film,
		"Film credits must raise directors' public recognition."
	)
	var before_tv_director: float = float(director.recognition)
	var director_tv_update: Dictionary = celebrity.call(
		"apply_tv_appearance", director, "guest", 75.0, 85.0, 120000
	)
	_expect(
		bool(director_tv_update.get("applied", false))
		and float(director.recognition) > before_tv_director,
		"Guest TV appearances must increase directors' recognition, not only actors'."
	)

	var clock := FakeClock.new()
	root.add_child(clock)
	var studio := FakeStudio.new()
	root.add_child(studio)
	studio.tv_building = Node3D.new()
	studio.add_child(studio.tv_building)
	var characters := FakeCharacters.new()
	characters.employees = roster
	root.add_child(characters)
	var guest_actor := FakeGuestActor.new()
	guest_actor.position = Vector3(12.0, 0.0, 0.0)
	studio.add_child(guest_actor)
	characters.guest_actor = guest_actor
	var production: RefCounted = GUEST_SHOW_CONTROLLER.new()
	production.call("setup", studio, characters, clock)
	var layout := VBoxContainer.new()
	root.add_child(layout)
	production.call("build_controls", layout, "TV-STAGE")
	star.recognition = 69.9
	var under_threshold: Dictionary = production.call(
		"invite_host", "TV-STAGE", str(star.id), "EXT-TV-HOST-MERCER"
	)
	_expect(
		not bool(under_threshold.get("success", false)),
		"The controller must reject a below-threshold celebrity, not only disable the UI."
	)
	star.recognition = 70.0
	var invalid_host: Dictionary = production.call(
		"invite_host", "TV-STAGE", str(star.id), "MISSING-HOST"
	)
	_expect(
		not bool(invalid_host.get("success", false)),
		"An invitation must reject unknown external hosts."
	)
	studio.busy_ids = [str(star.id)]
	var busy_guest: Dictionary = production.call(
		"invite_host", "TV-STAGE", str(star.id), "EXT-TV-HOST-MERCER"
	)
	_expect(
		not bool(busy_guest.get("success", false)),
		"An actor already filming a feature cannot appear in a TV show."
	)
	studio.busy_ids.clear()
	var roster_size: int = characters.employees.size()
	var invited: Dictionary = production.call(
		"invite_host", "TV-STAGE", str(star.id), "EXT-TV-HOST-MERCER"
	)
	_expect(
		bool(invited.get("success", false))
		and bool(production.call("is_host_present"))
		and characters.employees.size() == roster_size,
		"External host must arrive as a 3D visitor without ever joining the payroll roster."
	)
	var invitation_system: RefCounted = production.call("get_tv_system")
	var active_episode: Variant = invitation_system.call("get_active_episode")
	_expect(
		active_episode != null
		and str(active_episode.host_employee_id) == "EXT-TV-HOST-MERCER",
		"Existing TV domain must own the invited-host episode."
	)
	var overlapping_cast: Dictionary = {"LEAD": str(star.id)}
	var background_ids: Array[String] = []
	_expect(
		bool(production.call(
			"has_staff_conflict", {}, overlapping_cast, background_ids
		))
		and not bool(production.call(
			"has_staff_conflict", {}, {"LEAD": "UNRELATED"}, background_ids
		)),
		"Feature films must be blocked only when their cast or crew overlaps an active TV show."
	)
	var before_tv: float = float(star.recognition)
	for minute_index in range(45):
		production.call("advance_minute", 1, 10, minute_index % 60)
	var broadcast: Dictionary = production.call("get_last_broadcast")
	_expect(
		not bool(production.call(
			"has_staff_conflict", {}, overlapping_cast, background_ids
		)),
		"Film employees must become available again after TV production finishes."
	)
	_expect(
		bool(broadcast.get("success", false))
		and int(broadcast.get("audience_reach", 0)) > 0
		and float(star.recognition) > before_tv,
		"The show must finish, air and advance the guest's public recognition."
	)
	_expect(
		guest_actor.last_return_path.size() >= 2
		and characters.employees.size() == roster_size,
		"The guest must be routed home and the external host must never become an employee."
	)
	var original_show: Variant = invitation_system.call(
		"get_talk_show", "TV-VISIT-0001"
	)
	_expect(
		original_show != null
		and original_show.episodes.size() == 1
		and str(original_show.episodes[0].status) == "broadcasted",
		"One-time external-host shows must remain archived in the TV domain."
	)
	# The only director is now the celebrity guest. Camera and technical
	# staff remain unchanged; no new director should be hired or generated.
	guest_actor.global_position = Vector3(12.0, 0.0, 0.0)
	var second_guest_before: float = float(director.recognition)
	var second_invite: Dictionary = production.call(
		"invite_host", "TV-STAGE", str(director.id), "EXT-TV-HOST-VALE"
	)
	_expect(
		bool(second_invite.get("success", false))
		and characters.employees.size() == roster_size,
		"A known film director must be able to guest-star with the existing crew."
	)
	for minute_index in range(45):
		production.call("advance_minute", 1, 11, minute_index % 60)
	var second_show: Variant = invitation_system.call(
		"get_talk_show", "TV-VISIT-0002"
	)
	_expect(
		second_show != null
		and second_show.episodes.size() == 1
		and str(second_show.episodes[0].status) == "broadcasted"
		and float(director.recognition) > second_guest_before,
		"The director's interview must air, improve their fame and remain in the TV archive."
	)
	layout.free()
	characters.free()
	studio.free()
	clock.free()
	_finish_test("TVGuestShowSmokeTest")
