extends "res://tests/smoke_test_base.gd"

const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const CHARACTER_NEEDS_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_needs_system.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const CHARACTER_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/characters/character_manager.gd"
)
const SKILL_PROGRESSION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_skill_progression_system.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)
const GAME_CLOCK_SCRIPT = preload("res://scripts/core/game_clock.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321
	var employee: Variant = generator.call(
		"generate", rng, "V2-TEST-0001", "actor"
	)

	_expect(employee.biography != "", "Generated employee must have a biography.")
	_expect(employee.career_goal != "", "Generated employee must have a career goal.")
	_expect(employee.shift_start_hour == 8, "Default shift must start at 08:00.")
	_expect(employee.shift_end_hour == 17, "Default shift must end at 17:00.")

	_test_serialization(employee)
	_test_needs_and_schedule(employee)
	_test_facility_recovery(employee)
	_test_skill_progress_bars(employee)
	_test_recognition_serialization(employee)
	_test_selection_marker(employee)

	_finish_test("CharacterSystemV2SmokeTest")


func _test_serialization(employee: Variant) -> void:
	var payload: Dictionary = employee.call("to_dict")
	var restored: Variant = CHARACTER_DATA_SCRIPT.from_dict(payload)

	_expect(restored.id == employee.id, "Character ID must survive serialization.")
	_expect(
		restored.biography == employee.biography,
		"Biography must survive serialization."
	)
	_expect(
		restored.career_goal == employee.career_goal,
		"Career goal must survive serialization."
	)
	_expect(
		restored.shift_start_hour == employee.shift_start_hour,
		"Work schedule must survive serialization."
	)


func _test_needs_and_schedule(employee: Variant) -> void:
	var needs_system: RefCounted = CHARACTER_NEEDS_SYSTEM_SCRIPT.new()

	needs_system.call("refresh_work_state", employee, 9)
	_expect(
		employee.work_state == "working",
		"Employee must be on shift during working hours."
	)
	_expect(
		employee.current_task != "",
		"Employee must receive a profession-specific task."
	)

	var energy_before_work: float = float(employee.needs.get("energy", 1.0))
	var stress_before_work: float = float(employee.needs.get("stress", 0.0))
	needs_system.call("advance_minute", employee, 9)
	_expect(
		float(employee.needs.energy) < energy_before_work,
		"Working must consume energy."
	)
	_expect(
		float(employee.needs.stress) > stress_before_work,
		"Working must increase stress."
	)

	var energy_before_break: float = float(employee.needs.energy)
	var stress_before_break: float = float(employee.needs.stress)
	needs_system.call("advance_minute", employee, 12)
	_expect(employee.work_state == "break", "12:00 must be the lunch break.")
	_expect(
		float(employee.needs.energy) > energy_before_break,
		"Break time must restore energy."
	)
	_expect(
		float(employee.needs.stress) < stress_before_break,
		"Break time must reduce stress."
	)

	var energy_before_off_duty: float = float(employee.needs.energy)
	needs_system.call("advance_minute", employee, 22)
	_expect(
		employee.work_state == "off_duty",
		"Employee must be off duty after bedtime."
	)
	_expect(
		is_equal_approx(float(employee.needs.energy), energy_before_off_duty),
		"An off-duty employee who is not physically in staff housing must not receive sleep recovery."
	)


func _test_facility_recovery(employee: Variant) -> void:
	var needs_system: RefCounted = CHARACTER_NEEDS_SYSTEM_SCRIPT.new()
	var regular_lunch: Variant = CHARACTER_DATA_SCRIPT.from_dict(
		employee.to_dict()
	)
	var cafeteria_lunch: Variant = CHARACTER_DATA_SCRIPT.from_dict(
		employee.to_dict()
	)
	var lunch_needs: Dictionary = regular_lunch.needs.duplicate(true)
	lunch_needs["energy"] = 0.5
	lunch_needs["stress"] = 0.6
	regular_lunch.needs = lunch_needs.duplicate(true)
	cafeteria_lunch.needs = lunch_needs.duplicate(true)
	var lunch_energy_before: float = 0.5
	needs_system.call("advance_minute", regular_lunch, 12)
	needs_system.call("advance_minute", cafeteria_lunch, 12, true, false)
	_expect(
		float(cafeteria_lunch.needs.energy) - lunch_energy_before
		> float(regular_lunch.needs.energy) - lunch_energy_before,
		"Dining in the cafeteria must restore more energy than an ordinary lunch break."
	)
	_expect(
		float(cafeteria_lunch.needs.stress) < float(regular_lunch.needs.stress),
		"Dining in the cafeteria must reduce more stress than an ordinary lunch break."
	)

	var regular_night: Variant = CHARACTER_DATA_SCRIPT.from_dict(
		employee.to_dict()
	)
	var housing_night: Variant = CHARACTER_DATA_SCRIPT.from_dict(
		employee.to_dict()
	)
	var night_needs: Dictionary = regular_night.needs.duplicate(true)
	night_needs["energy"] = 0.5
	night_needs["stress"] = 0.6
	regular_night.needs = night_needs.duplicate(true)
	housing_night.needs = night_needs.duplicate(true)
	var night_energy_before: float = 0.5
	needs_system.call("advance_minute", regular_night, 22)
	needs_system.call("advance_minute", housing_night, 22, false, true)
	_expect(
		is_equal_approx(float(regular_night.needs.energy), night_energy_before)
		and float(housing_night.needs.energy) > night_energy_before,
		"Only employees physically resting in staff housing may recover sleep energy."
	)
	_expect(
		float(housing_night.needs.stress) < float(regular_night.needs.stress),
		"Sleeping in staff housing must reduce more stress than ordinary off-duty time."
	)


func _test_skill_progress_bars(employee: Variant) -> void:
	var manager: Node = CHARACTER_MANAGER_SCRIPT.new()
	var container := VBoxContainer.new()
	manager.add_child(container)
	manager.set("_detail_skills_container", container)
	manager.set(
		"_skill_progression_system",
		SKILL_PROGRESSION_SYSTEM_SCRIPT.new()
	)
	manager.call("_refresh_skill_progress_bars", employee, employee.skills)
	var skill_ids: Array[String] = PROFESSION_CATALOG_SCRIPT.get_profession_skill_ids(
		employee.profession_id,
		employee.specialization_id
	)
	_expect(
		container.get_child_count() == skill_ids.size(),
		"Employee skills must be displayed as one progress bar per profession skill."
	)
	if not skill_ids.is_empty():
		var first_row: VBoxContainer = container.get_child(0) as VBoxContainer
		var title_label: Label = first_row.get_child(0) as Label
		var progress_bar: ProgressBar = first_row.get_child(1) as ProgressBar
		var skill_id: String = skill_ids[0]
		var skill_cap: float = float(employee.skill_caps.get(skill_id, 100.0))
		var skill_value: float = float(employee.skills.get(skill_id, 0.0))
		_expect(
			title_label.text == PROFESSION_CATALOG_SCRIPT.get_skill_title(skill_id)
			and is_equal_approx(progress_bar.max_value, skill_cap)
			and is_equal_approx(progress_bar.value, minf(skill_value, skill_cap))
			and not progress_bar.show_percentage
			and progress_bar.custom_minimum_size.y >= 10.0,
			"Skill bars must show current mastery against the employee's individual growth cap without tiny numeric text and match the energy/stress bar height."
		)
		var original_bar: ProgressBar = progress_bar
		var changed_skills: Dictionary = employee.skills.duplicate(true)
		var changed_value: float = (
			minf(skill_value + 1.0, skill_cap)
			if skill_value < skill_cap
			else maxf(skill_value - 1.0, 0.0)
		)
		changed_skills[skill_id] = changed_value
		manager.call("_refresh_skill_progress_bars", employee, changed_skills)
		var updated_row: VBoxContainer = container.get_child(0) as VBoxContainer
		var updated_bar: ProgressBar = updated_row.get_child(1) as ProgressBar
		_expect(
			updated_bar == original_bar
			and is_equal_approx(
				updated_bar.value,
				changed_value
			),
			"Refreshing an employee profile must update existing skill bars without rebuilding the UI every game minute."
		)
	manager.call("_clear_skill_progress_bars")
	_expect(
		container.get_child_count() == 0,
		"Clearing an employee profile must remove its skill progress rows."
	)
	manager.free()


func _test_recognition_serialization(employee: Variant) -> void:
	var serialized: Dictionary = employee.to_dict()
	var restored: Variant = CHARACTER_DATA_SCRIPT.from_dict(serialized)
	_expect(
		is_equal_approx(
			float(restored.recognition),
			float(employee.recognition)
		),
		"Public recognition must survive CharacterData serialization."
	)
	var legacy_payload: Dictionary = serialized.duplicate(true)
	legacy_payload.erase("recognition")
	legacy_payload["schema_version"] = 8
	legacy_payload["popularity"] = 42.0
	var migrated: Variant = CHARACTER_DATA_SCRIPT.from_dict(legacy_payload)
	_expect(
		is_equal_approx(float(migrated.recognition), 42.0)
		and int(migrated.to_dict().get("schema_version", 0)) == 9,
		"Schema 8 saves must migrate recognition from the existing popularity score."
	)


func _test_selection_marker(employee: Variant) -> void:
	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)

	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)

	var route: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(10.0, 0.0, 0.0),
	]
	actor.call("setup", employee, route, clock, 1.0)

	_expect(
		actor.is_in_group("studio_employee"),
		"Employee actor must be registered for world selection."
	)
	_expect(
		actor.get_node_or_null("SelectionHitbox") != null,
		"Employee actor must have a raycast hitbox."
	)

	var workplace_path: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0),
	]
	actor.call(
		"assign_workplace_route",
		"BLD-WORKPLACE",
		workplace_path,
		"actor"
	)
	actor.call("snap_to_workplace")
	var facility_path: Array[Vector3] = [
		Vector3(2.0, 0.0, 0.0),
		Vector3(3.0, 0.0, 0.0),
		Vector3(4.0, 0.0, 0.0),
	]
	_expect(
		bool(actor.call(
			"assign_facility_route",
			"BLD-HOUSING",
			"staff_housing",
			0,
			facility_path,
			"sleeping"
		)),
		"An employee must accept a separate facility route without losing the assigned workplace."
	)
	_expect(
		bool(actor.call("is_in_facility"))
		and not bool(actor.call("is_at_facility", "staff_housing")),
		"An employee travelling to housing must be tracked as en route, not already resting."
	)
	actor.call("snap_to_facility")
	_expect(
		bool(actor.call("is_at_facility", "staff_housing"))
		and str(actor.call("get_workplace_building_id")) == "BLD-WORKPLACE",
		"Arriving at staff housing must preserve the original workplace assignment."
	)
	var untyped_return_path: Array = [
		Vector3(4.0, 0.0, 0.0),
		Vector3(3.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0),
	]
	actor.call("return_to_workplace", untyped_return_path)
	_expect(
		bool(actor.call("is_returning_to_workplace"))
		and not bool(actor.call("is_in_facility")),
		"Returning from housing must clear the facility visit and start the return route."
	)
	actor.call("snap_to_workplace")
	_expect(
		bool(actor.call("is_at_workplace"))
		and not bool(actor.call("is_in_facility")),
		"An employee must return to the original workplace after the facility visit."
	)

	var ring := actor.get_node("SelectionRing") as MeshInstance3D
	_expect(not ring.visible, "Selection marker must start hidden.")

	actor.call("set_selected", true)
	_expect(ring.visible, "Selection marker must appear when selected.")

	actor.call("set_selected", false)
	_expect(not ring.visible, "Selection marker must hide when deselected.")

	actor.free()
	clock.free()
