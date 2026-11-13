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
	var release_production_for_lunch: bool = false

	func get_buildings() -> Array:
		return buildings

	func is_employee_in_active_production(employee_id: String) -> bool:
		return employee_id == active_production_employee_id

	func should_release_production_employee_for_off_hours(hour: int) -> bool:
		return release_production_for_lunch and hour == 12

	func get_total_facility_capacity(building_type_id: String) -> int:
		match building_type_id:
			"fitness_center":
				return 4
			"studio_lounge":
				return 6
		return 0


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

	func get_workplace_path(
		building_id: String,
		_slot_index: int
	) -> Array[Vector3]:
		# Production dispatch requires the destination building's entrance
		# and interior route, separately from get_workplace_path_from().
		# The mock must model a valid stage, not only facility buildings.
		if building_id == "BLD-WORKPLACE":
			return [
				Vector3(0.0, 0.0, -2.0),
				Vector3(0.0, 0.0, 0.0),
				Vector3(2.0, 0.0, 0.0),
			]
		if building_id in [
			"BLD-HOUSING",
			"BLD-STAR-HOUSING",
			"BLD-FITNESS",
			"BLD-LOUNGE",
		]:
			return [
				Vector3(3.0, 0.0, -3.0),
				Vector3(3.0, 0.0, -2.0),
				Vector3(3.0, 0.0, -1.0),
				Vector3(3.0, 0.0, 0.0),
			]
		return []


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
	employee.popularity = 0.0
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
	var initial_route: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(0.0, 0.0, 1.0),
	]
	actor.call(
		"setup",
		employee,
		initial_route,
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
	var star_bungalow: Variant = BUILDING_DATA_SCRIPT.new()
	star_bungalow.id = "BLD-STAR-HOUSING"
	star_bungalow.building_type_id = "star_bungalow"
	star_bungalow.is_operational = true

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
	studio_manager.buildings = [cafeteria, housing, star_bungalow]

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
	actor.call("_advance_visual", 0.25)
	var eating_body: Node3D = actor.get_node(
		"CharacterVisual/BodyRoot"
	) as Node3D
	var eating_left_leg: Node3D = actor.get_node(
		"CharacterVisual/BodyRoot/LeftLegPivot"
	) as Node3D
	_expect(
		bool(actor.call("is_at_facility", "cafeteria")),
		"An employee must arrive at the assigned cafeteria seat."
	)
	_expect(
		eating_body.position.y < -0.2
		and eating_left_leg.rotation.x > 0.65,
		"Cafeteria arrival must switch the employee into a lowered seated eating pose."
	)
	var cafeteria_facing: Vector3 = -actor.global_transform.basis.z
	_expect(
		cafeteria_facing.dot(Vector3.BACK) > 0.9,
		"Employees in the front cafeteria row must face inward toward the table."
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
	actor.call("_advance_visual", 0.25)
	var sleeping_body: Node3D = actor.get_node(
		"CharacterVisual/BodyRoot"
	) as Node3D
	var sleeping_name_tag: Label3D = actor.get_node("NameTag") as Label3D
	_expect(
		bool(actor.call("is_at_facility", "staff_housing"))
		and character_manager.call(
			"get_employees_using_facility",
			"BLD-HOUSING"
		).size() == 1,
		"Staff housing must register the employee at their assigned bed."
	)
	_expect(
		absf(sleeping_body.rotation.x + PI * 0.5) < 0.1
		and sleeping_body.position.y > 0.5
		and absf(actor.rotation.y) < 0.1
		and not sleeping_name_tag.visible,
		"Staff housing arrival must place the employee lying on the bed, facing the headboard, and hide the floating name tag."
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
	studio_manager.active_production_employee_id = str(employee.id)
	studio_manager.release_production_for_lunch = true
	character_manager.call("_on_game_minute_advanced", 2, 12, 0)
	_expect(
		bool(actor.call("is_at_facility", "cafeteria"))
		and str(employee.current_task) == "Обедает в столовой",
		"Active film participants must be allowed into the cafeteria during production lunch."
	)
	studio_manager.release_production_for_lunch = false
	character_manager.call("dispatch_employee_to_workplace", employee.id)
	_expect(
		bool(actor.call("is_at_workplace")),
		"Film controller must be able to recall a lunching actor when the break ends."
	)
	studio_manager.active_production_employee_id = ""
	character_manager.call("_on_game_minute_advanced", 1, 17, 0)
	_expect(
		str(employee.work_state) == "free_time"
		and str(employee.current_task) == "Свободное время"
		and not bool(actor.call("is_in_facility"))
		and str(actor.call("get_workplace_building_id")).is_empty(),
		"Employees must leave work and roam during evening free time instead of going straight to bed."
	)
	character_manager.call("_on_game_minute_advanced", 1, 22, 0)
	_expect(
		str(employee.work_state) == "off_duty"
		and bool(actor.call("is_at_facility", "staff_housing"))
		and str(employee.current_task) == "Отдыхает в домике",
		"Employees must enter staff housing at bedtime rather than at the end of the work shift."
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
		str(employee.work_state) == "free_time"
		and not bool(actor.call("is_in_facility"))
		and str(actor.call("get_workplace_building_id")).is_empty(),
		"Once production ends before bedtime, the employee must return to evening free time."
	)
	character_manager.call("_on_game_minute_advanced", 2, 22, 0)
	_expect(
		bool(actor.call("is_at_facility", "staff_housing")),
		"Once bedtime begins, an employee released from production must be allowed to go to staff housing."
	)
	character_manager.call("_on_game_minute_advanced", 3, 17, 0)
	_expect(
		str(employee.work_state) == "free_time"
		and not bool(actor.call("is_in_facility"))
		and str(actor.call("get_workplace_building_id")).is_empty(),
		"An employee leaving housing for evening free time must resume roaming instead of returning to a stale workplace route."
	)
	character_manager.call("_on_game_minute_advanced", 3, 22, 0)
	_expect(
		bool(actor.call("is_at_facility", "staff_housing")),
		"Employees must be able to return to their bed at the next bedtime."
	)

	var unassigned_actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(unassigned_actor)
	var unassigned_route: Array[Vector3] = []
	unassigned_actor.call(
		"setup",
		second_employee,
		unassigned_route,
		clock,
		1.0
	)
	character_manager.set("employees", [employee, second_employee])
	character_manager.set("_employee_actors", {
		employee.id: actor,
		second_employee.id: unassigned_actor,
	})
	_expect(
		bool(character_manager.call(
			"_route_employee_to_facility",
			second_employee.id,
			"staff_housing"
		))
		and bool(unassigned_actor.call("is_at_facility", "staff_housing")),
		"Free-roaming employees without a workplace assignment must still be able to use staff housing."
	)
	_expect(
		bool(character_manager.call(
			"dispatch_employee_to_workplace",
			second_employee.id
		))
		and not bool(unassigned_actor.call("is_in_facility"))
		and unassigned_actor.global_position.is_equal_approx(
			Vector3(3.0, 0.0, -3.0)
		),
		"Unassigned employees must exit staff housing through its entrance and resume free roaming."
	)

	character_manager.call(
		"dispatch_employee_to_workplace",
		employee.id
	)
	actor.call("snap_to_workplace")
	employee.popularity = 90.0
	var star_needs: Dictionary = employee.needs.duplicate(true)
	star_needs["energy"] = 0.5
	star_needs["stress"] = 0.5
	employee.needs = star_needs
	character_manager.call("_on_game_minute_advanced", 4, 22, 0)
	var needs_before_star_sleep: Dictionary = employee.needs.duplicate(true)
	character_manager.call("_on_game_minute_advanced", 4, 22, 1)
	var needs_after_star_sleep: Dictionary = employee.needs
	_expect(
		bool(actor.call("is_at_facility", "star_bungalow"))
		and str(employee.current_task) == "Отдыхает в отдельном домике",
		"Popular actors must use the private bungalow when its single bed is available."
	)
	var star_sleep_body: Node3D = actor.get_node(
		"CharacterVisual/BodyRoot"
	) as Node3D
	var star_name_tag: Label3D = actor.get_node("NameTag") as Label3D
	_expect(
		absf(star_sleep_body.rotation.x + PI * 0.5) < 0.1
		and star_sleep_body.position.y > 0.5
		and not star_name_tag.visible,
		"Star bungalow arrival must use the same lying sleep pose and hide the floating name tag."
	)
	_expect(
		float(needs_after_star_sleep.get("energy", 0.0))
			> float(needs_before_star_sleep.get("energy", 0.0))
		and float(needs_after_star_sleep.get("stress", 1.0))
			< float(needs_before_star_sleep.get("stress", 1.0)),
		"Star bungalow sleep must restore energy and reduce stress at the enhanced rate."
	)

	var fitness_center: Variant = BUILDING_DATA_SCRIPT.new()
	fitness_center.id = "BLD-FITNESS"
	fitness_center.building_type_id = "fitness_center"
	fitness_center.is_operational = true
	var studio_lounge: Variant = BUILDING_DATA_SCRIPT.new()
	studio_lounge.id = "BLD-LOUNGE"
	studio_lounge.building_type_id = "studio_lounge"
	studio_lounge.is_operational = true
	studio_manager.buildings = [
		cafeteria,
		housing,
		star_bungalow,
		fitness_center,
		studio_lounge,
	]
	var rotating_roster: Array[String] = ["A", "B", "C", "D", "E"]
	_expect(
		bool(character_manager.call(
			"_is_employee_in_rotating_facility_group",
			"A",
			rotating_roster,
			2,
			0
		))
		and bool(character_manager.call(
			"_is_employee_in_rotating_facility_group",
			"C",
			rotating_roster,
			2,
			1
		))
		and not bool(character_manager.call(
			"_is_employee_in_rotating_facility_group",
			"C",
			rotating_roster,
			2,
			0
		)),
		"Facility capacity overflow must rotate employees between daily attendance groups."
	)
	employee.personality = {
		"ambition": 0.5,
		"sociability": 0.8,
		"discipline": 0.5,
		"creativity": 0.5,
	}
	second_employee.personality = {
		"ambition": 0.5,
		"sociability": 0.8,
		"discipline": 0.5,
		"creativity": 0.5,
	}
	var second_needs: Dictionary = second_employee.needs.duplicate(true)
	second_needs["energy"] = 0.8
	second_needs["stress"] = 0.5
	second_employee.needs = second_needs
	var employee_social_needs: Dictionary = employee.needs.duplicate(true)
	employee_social_needs["energy"] = 0.8
	employee_social_needs["stress"] = 0.5
	employee.needs = employee_social_needs

	character_manager.call("_on_game_minute_advanced", 5, 17, 0)
	character_manager.call("_on_game_minute_advanced", 5, 17, 1)
	_expect(
		bool(actor.call("is_at_facility", "fitness_center"))
		and bool(unassigned_actor.call("is_at_facility", "fitness_center"))
		and str(employee.current_task) == "Тренируется в фитнес-центре",
		"Actors must autonomously use separate fitness stations during their evening training window."
	)
	var fitness_before: float = employee.physical_fitness
	var fitness_energy_before: float = float(employee.needs.get("energy", 1.0))
	character_manager.call("_on_game_minute_advanced", 5, 18, 0)
	_expect(
		employee.physical_fitness > fitness_before
		and float(employee.needs.get("energy", 1.0)) < fitness_energy_before,
		"Training must gradually improve physical fitness while consuming energy."
	)

	character_manager.call("_on_game_minute_advanced", 5, 19, 0)
	character_manager.call("_on_game_minute_advanced", 5, 19, 1)
	_expect(
		bool(actor.call("is_at_facility", "studio_lounge"))
		and bool(unassigned_actor.call("is_at_facility", "studio_lounge")),
		"After training, employees must transition into the studio lounge during the social window."
	)
	var stress_before_lounge: float = float(
		employee.needs.get("stress", 1.0)
	)
	character_manager.call("_on_game_minute_advanced", 5, 19, 2)
	_expect(
		float(employee.needs.get("stress", 1.0)) < stress_before_lounge,
		"Time spent in the studio lounge must reduce employee stress."
	)
	_expect(
		float(employee.relationships.get(second_employee.id, 0.0)) > 0.0
		and float(second_employee.relationships.get(employee.id, 0.0)) > 0.0,
		"Employees sharing the lounge must develop reciprocal relationship scores."
	)
	var relationship_round_trip: Variant = CHARACTER_DATA_SCRIPT.from_dict(
		employee.to_dict()
	)
	_expect(
		is_equal_approx(
			float(relationship_round_trip.physical_fitness),
			employee.physical_fitness
		)
		and float(
			relationship_round_trip.relationships.get(
				second_employee.id,
				0.0
			)
		) > 0.0,
		"Physical fitness and employee relationships must survive character serialization."
	)
	var legacy_character_payload: Dictionary = employee.to_dict()
	legacy_character_payload["schema_version"] = 7
	legacy_character_payload.erase("physical_fitness")
	legacy_character_payload.erase("relationships")
	var migrated_legacy_character: Variant = CHARACTER_DATA_SCRIPT.from_dict(
		legacy_character_payload
	)
	_expect(
		is_equal_approx(
			float(migrated_legacy_character.physical_fitness),
			50.0
		)
		and migrated_legacy_character.relationships.is_empty(),
		"Legacy character saves must receive safe defaults for fitness and relationships."
	)
	employee.relationships = {}
	second_employee.relationships = {}
	employee.personality = {
		"ambition": 0.15,
		"sociability": 0.8,
		"discipline": 0.15,
		"creativity": 0.5,
	}
	second_employee.personality = {
		"ambition": 0.95,
		"sociability": 0.8,
		"discipline": 0.95,
		"creativity": 0.5,
	}
	character_manager.call("_update_social_relationships")
	_expect(
		float(employee.relationships.get(second_employee.id, 0.0)) < 0.0
		and float(second_employee.relationships.get(employee.id, 0.0)) < 0.0,
		"Strong personality incompatibility must be able to create reciprocal conflict scores."
	)
	character_manager.call("_on_game_minute_advanced", 5, 21, 0)
	_expect(
		not bool(actor.call("is_in_facility"))
		and not bool(unassigned_actor.call("is_in_facility")),
		"Employees must leave the social lounge when its evening window ends."
	)

	character_manager.free()
	actor.free()
	unassigned_actor.free()
	studio_manager.free()
	clock.free()
	_finish_test("StaffFacilitiesSmokeTest")
