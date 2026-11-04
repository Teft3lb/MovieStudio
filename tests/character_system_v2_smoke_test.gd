extends SceneTree

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
const GAME_CLOCK_SCRIPT = preload("res://scripts/core/game_clock.gd")


func _initialize() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321
	var employee: Variant = generator.call(
		"generate", rng, "V2-TEST-0001", "actor"
	)

	assert(employee.biography != "", "Generated employee must have a biography.")
	assert(employee.career_goal != "", "Generated employee must have a career goal.")
	assert(employee.shift_start_hour == 8, "Default shift must start at 08:00.")
	assert(employee.shift_end_hour == 17, "Default shift must end at 17:00.")

	_test_serialization(employee)
	_test_needs_and_schedule(employee)
	_test_selection_marker(employee)

	print("CharacterSystemV2SmokeTest: PASS")
	quit(0)


func _test_serialization(employee: Variant) -> void:
	var payload: Dictionary = employee.call("to_dict")
	var restored: Variant = CHARACTER_DATA_SCRIPT.from_dict(payload)

	assert(restored.id == employee.id, "Character ID must survive serialization.")
	assert(
		restored.biography == employee.biography,
		"Biography must survive serialization."
	)
	assert(
		restored.career_goal == employee.career_goal,
		"Career goal must survive serialization."
	)
	assert(
		restored.shift_start_hour == employee.shift_start_hour,
		"Work schedule must survive serialization."
	)


func _test_needs_and_schedule(employee: Variant) -> void:
	var needs_system: RefCounted = CHARACTER_NEEDS_SYSTEM_SCRIPT.new()

	needs_system.call("refresh_work_state", employee, 9)
	assert(
		employee.work_state == "working",
		"Employee must be on shift during working hours."
	)
	assert(
		employee.current_task != "",
		"Employee must receive a profession-specific task."
	)

	var energy_before_work: float = float(employee.needs.get("energy", 1.0))
	var stress_before_work: float = float(employee.needs.get("stress", 0.0))
	needs_system.call("advance_minute", employee, 9)
	assert(
		float(employee.needs.energy) < energy_before_work,
		"Working must consume energy."
	)
	assert(
		float(employee.needs.stress) > stress_before_work,
		"Working must increase stress."
	)

	var energy_before_break: float = float(employee.needs.energy)
	var stress_before_break: float = float(employee.needs.stress)
	needs_system.call("advance_minute", employee, 12)
	assert(employee.work_state == "break", "12:00 must be the lunch break.")
	assert(
		float(employee.needs.energy) > energy_before_break,
		"Break time must restore energy."
	)
	assert(
		float(employee.needs.stress) < stress_before_break,
		"Break time must reduce stress."
	)

	var energy_before_off_duty: float = float(employee.needs.energy)
	needs_system.call("advance_minute", employee, 20)
	assert(
		employee.work_state == "off_duty",
		"Employee must be off duty after the shift."
	)
	assert(
		float(employee.needs.energy) > energy_before_off_duty,
		"Off-duty time must restore energy."
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

	assert(
		actor.is_in_group("studio_employee"),
		"Employee actor must be registered for world selection."
	)
	assert(
		actor.get_node_or_null("SelectionHitbox") != null,
		"Employee actor must have a raycast hitbox."
	)

	var ring := actor.get_node("SelectionRing") as MeshInstance3D
	assert(not ring.visible, "Selection marker must start hidden.")

	actor.call("set_selected", true)
	assert(ring.visible, "Selection marker must appear when selected.")

	actor.call("set_selected", false)
	assert(not ring.visible, "Selection marker must hide when deselected.")

	actor.free()
	clock.free()
