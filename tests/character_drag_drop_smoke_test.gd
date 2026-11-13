extends "res://tests/smoke_test_base.gd"

const ACTIVITY_POLICY = preload(
	"res://scripts/domain/characters/character_manual_activity_policy.gd"
)
const ACTIVITY_CONTROLLER = preload(
	"res://scripts/presentation/characters/character_manual_activity_controller.gd"
)
const DRAG_CONTROLLER = preload(
	"res://scripts/presentation/characters/character_drag_drop_controller.gd"
)
const CHARACTER_GENERATOR = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const SKILL_SYSTEM = preload(
	"res://scripts/domain/characters/character_skill_progression_system.gd"
)


class FakeClock extends Node:
	var is_manual_fast_forward: bool = false


class FakeBuilding extends RefCounted:
	var id: String = ""
	var building_type_id: String = ""
	var is_operational: bool = true
	var stage_size_tier: int = 2

	func _init(building_id: String, building_type: String) -> void:
		id = building_id
		building_type_id = building_type


class FakeFilm extends RefCounted:
	var status: String = "in_production"


class FakeBuildingActor extends Node3D:
	var building_id: String = ""

	func get_building_id() -> String:
		return building_id


class FakeEmployeeActor extends Node3D:
	var _workplace_slot_index: int = 0
	var _scene_target_position: Vector3 = Vector3.ZERO
	var _scene_active: bool = false
	var at_mark: bool = false
	var return_route: Array[Vector3] = []
	var activity_action: String = ""
	var starts: int = 0

	func is_in_scene_performance() -> bool:
		return _scene_active

	func start_scene_performance(
		target: Vector3,
		_focus: Vector3,
		action: String,
		_text: String = "",
		_route: Array = [],
		_allow_unassigned: bool = false
	) -> void:
		_scene_target_position = target
		_scene_active = true
		at_mark = false
		activity_action = action
		starts += 1

	func is_at_scene_mark() -> bool:
		return at_mark

	func snap_to_scene_mark() -> void:
		at_mark = true
		global_position = _scene_target_position

	func get_workplace_building_id() -> String:
		return "HOME-1"

	func return_to_workplace(route: Array = []) -> void:
		return_route.clear()
		for point in route:
			if point is Vector3:
				return_route.append(point)
		_scene_active = false
		at_mark = false


class FakeCharacters extends Node:
	var employees: Array = []
	var actor: FakeEmployeeActor
	var activity_controller: RefCounted

	func get_employees() -> Array:
		return employees

	func get_employee_actor(_employee_id: String) -> Node:
		return actor

	func get_employees_using_facility(_building_id: String) -> Array:
		return []

	func get_manual_activity_preview(
		employee_id: String, building_id: String
	) -> Dictionary:
		return activity_controller.call("preview", employee_id, building_id)

	func request_manual_activity(
		employee_id: String, building_id: String
	) -> Dictionary:
		return activity_controller.call("request", employee_id, building_id)

	func refresh_navigation_routes() -> void:
		pass


class FakeStudio extends Node3D:
	var lounge: FakeBuilding
	var stage: FakeBuilding
	var club_actor: FakeBuildingActor
	var stage_actor: FakeBuildingActor
	var busy_ids: Array[String] = []
	var active_film: Variant

	func _ready() -> void:
		lounge = FakeBuilding.new("LOUNGE-1", "studio_lounge")
		stage = FakeBuilding.new("STAGE-1", "sound_stage")
		club_actor = FakeBuildingActor.new()
		club_actor.building_id = lounge.id
		add_child(club_actor)
		stage_actor = FakeBuildingActor.new()
		stage_actor.building_id = stage.id
		add_child(stage_actor)

	func get_building_by_id(building_id: String) -> Variant:
		if building_id == "LOUNGE-1":
			return lounge
		if building_id == "STAGE-1":
			return stage
		return null

	func is_employee_in_active_production(employee_id: String) -> bool:
		return busy_ids.has(employee_id)

	func is_employee_in_active_editing(_employee_id: String) -> bool:
		return false

	func is_employee_in_publicity_event(_employee_id: String) -> bool:
		return false

	func get_active_film_project() -> Variant:
		return active_film

	func get_building_actor_by_id(building_id: String) -> Node3D:
		if building_id == "LOUNGE-1":
			return club_actor
		if building_id == "STAGE-1":
			return stage_actor
		return null

	func _get_building_actor_at(screen_position: Vector2) -> Node:
		if screen_position.x > 240.0:
			return stage_actor
		if screen_position.x > 100.0:
			return club_actor
		return null

	func get_workplace_path(
		building_id: String, _slot: int
	) -> Array[Vector3]:
		var destination: Vector3 = (
			Vector3(30.0, 0.0, 0.0)
			if building_id == "STAGE-1"
			else Vector3(10.0, 0.0, 0.0)
		)
		return [destination + Vector3(0.0, 0.0, 5.0), destination]

	func get_workplace_path_from(
		building_id: String,
		slot: int,
		start: Vector3,
		_source_id: String = "",
		_source_slot: int = 0
	) -> Array[Vector3]:
		var destination: Vector3 = get_workplace_position(building_id, slot)
		return [
			start,
			Vector3(0.0, 0.0, 3.0),
			destination + Vector3(0.0, 0.0, 5.0),
			destination,
		]

	func get_workplace_position(building_id: String, _slot: int) -> Vector3:
		if building_id == "HOME-1":
			return Vector3(-10.0, 0.0, 0.0)
		if building_id == "STAGE-1":
			return Vector3(30.0, 0.0, 0.0)
		return Vector3(10.0, 0.0, 0.0)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var clock := FakeClock.new()
	var studio := FakeStudio.new()
	var characters := FakeCharacters.new()
	root.add_child(clock)
	root.add_child(studio)
	root.add_child(characters)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8269
	var employee: Variant = CHARACTER_GENERATOR.new().call(
		"generate", rng, "EMP-DRAG-TEST", "actor", true
	)
	employee.needs["stress"] = 0.65
	characters.employees = [employee]
	var actor := FakeEmployeeActor.new()
	actor.global_position = Vector3(-10.0, 0.0, 0.0)
	studio.add_child(actor)
	characters.actor = actor
	var skills: RefCounted = SKILL_SYSTEM.new()
	var activities: RefCounted = ACTIVITY_CONTROLLER.new()
	activities.call("setup", characters, clock, skills)
	activities.call("set_building_manager", studio)
	characters.activity_controller = activities
	var drag: RefCounted = DRAG_CONTROLLER.new()
	drag.call("setup", studio, characters)

	var policy: RefCounted = ACTIVITY_POLICY.new()
	_expect(
		str(policy.call("get_activity", "studio_lounge", "actor").get(
			"action", ""
		)) == "socializing"
		and policy.call("get_activity", "sound_stage", "actor").get(
			"skill", ""
		) == "acting"
		and policy.call("get_activity", "sound_stage", "film_editor").is_empty(),
		"Club relaxation and stage acting rehearsal must be profession aware."
	)
	drag.call("begin", str(employee.id), Vector2(10, 10))
	_expect(
		not bool(drag.call("on_motion", Vector2(15, 15)))
		and not bool(drag.call("on_release", Vector2(15, 15)))
		and not bool(activities.call("has_order", str(employee.id))),
		"A short left click must select, not issue a movement order."
	)
	drag.call("begin", str(employee.id), Vector2(10, 10))
	_expect(
		bool(drag.call("on_motion", Vector2(130, 40)))
		and bool(drag.call("is_dragging"))
		and bool(drag.call("on_release", Vector2(130, 40)))
		and bool(activities.call("has_order", str(employee.id)))
		and actor.starts == 1
		and actor.activity_action == "socializing",
		"Dragging a character onto the club must start a timed social visit."
	)
	_expect(
		actor.global_position.distance_to(
			Vector3(-10.0, 0.0, 0.0)
		) < 0.1,
		"Manual orders must not teleport actors during ordinary gameplay."
	)
	var first_order: Dictionary = activities.call(
		"get_order", str(employee.id)
	)
	var no_arrival: bool = bool(activities.call(
		"advance_employee", employee, actor
	))
	_expect(
		no_arrival and int(activities.call(
			"get_order", str(employee.id)
		).get("elapsed_minutes", -1)) == 0,
		"The activity clock must not advance before the character arrives."
	)
	actor.snap_to_scene_mark()
	var original_stress: float = float(employee.needs["stress"])
	for _minute in range(int(first_order["activity"]["minutes"])):
		activities.call("advance_employee", employee, actor)
	_expect(
		not bool(activities.call("has_order", str(employee.id)))
		and float(employee.needs["stress"]) < original_stress - 0.10
		and actor.return_route.size() >= 2,
		"An hour in the club must relieve stress and route the actor back home."
	)

	studio.busy_ids = [str(employee.id)]
	_expect(
		not bool(activities.call(
			"preview", str(employee.id), "STAGE-1"
		).get("success", false)),
		"Employees on a live film must not be dragged out for rehearsal."
	)
	studio.busy_ids.clear()
	studio.active_film = FakeFilm.new()
	_expect(
		not bool(activities.call(
			"preview", str(employee.id), "STAGE-1"
		).get("success", false)),
		"New rehearsals must not invade the active sound stage."
	)
	studio.active_film = null
	var before_skill_xp: float = float(
		employee.skill_xp.get("acting", 0.0)
	)
	var before_acting: float = float(employee.skills.get("acting", 0.0))
	drag.call("begin", str(employee.id), Vector2(10, 10))
	drag.call("on_motion", Vector2(300, 80))
	_expect(
		bool(drag.call("on_release", Vector2(300, 80)))
		and actor.activity_action == "rehearsing",
		"Dropping an idle actor into a stage must issue a rehearsal order."
	)
	actor.snap_to_scene_mark()
	var rehearsal_order: Dictionary = activities.call(
		"get_order", str(employee.id)
	)
	for _minute in range(int(rehearsal_order["activity"]["minutes"])):
		activities.call("advance_employee", employee, actor)
	_expect(
		not bool(activities.call("has_order", str(employee.id)))
		and (
			float(employee.skill_xp.get("acting", 0.0)) > before_skill_xp
			or float(employee.skills.get("acting", 0.0)) > before_acting
		),
		"Rehearsal must award capped acting XP, then end automatically."
	)
	studio.free()
	characters.free()
	clock.free()
	_finish_test("CharacterDragDropSmokeTest")
