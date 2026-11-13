extends "res://tests/smoke_test_base.gd"

const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 2.05
	actor.set("_movement_collision_shape", capsule)
	actor.global_position = Vector3.ZERO

	var barrier := StaticBody3D.new()
	barrier.collision_layer = 8
	barrier.collision_mask = 0
	barrier.position = Vector3(0.0, 1.05, 0.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 2.1, 0.25)
	collision.shape = shape
	barrier.add_child(collision)
	root.add_child(barrier)
	await get_tree().physics_frame

	var no_progress: bool = bool(actor.call(
		"_try_move_to_position",
		Vector3(0.0, 0.0, 0.5)
	))
	_expect(
		not no_progress
		and actor.global_position.distance_to(Vector3.ZERO) < 0.01,
		"Moving into a wall must not count as successful zero-displacement sliding."
	)
	var sideways: bool = bool(actor.call(
		"_try_move_to_position",
		Vector3(0.3, 0.0, 0.5)
	))
	_expect(
		sideways and actor.global_position.x > 0.05,
		"An available side step may advance toward the target without crossing collision geometry."
	)
	var motionless_again: bool = bool(actor.call(
		"_try_move_to_position",
		Vector3(actor.global_position.x, 0.0, 0.5)
	))
	_expect(
		not motionless_again,
		"A side step that no longer changes position must report a blockage and permit route recovery."
	)

	actor.free()
	barrier.free()
	_finish_test("CharacterObstructionRecoverySmokeTest")
