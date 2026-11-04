extends SceneTree

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const GAME_CLOCK_SCRIPT = preload(
	"res://scripts/core/game_clock.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)


func _initialize() -> void:
	_test_character_moves_and_performs_scene()
	print("FilmScenePerformanceSmokeTest: PASS")
	quit(0)


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
	actor.call(
		"setup",
		employee,
		[
			Vector3(0.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
		],
		clock,
		2.0
	)
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
	assert(
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

	assert(
		bool(actor.call("is_at_scene_mark")),
		"An actor must physically move from the workstation to the scene mark."
	)
	assert(
		actor.global_position.distance_to(scene_mark) <= 0.25,
		"The actor must finish at the blocking position on the set."
	)
	assert(
		bool(actor.call("is_scene_animation_active")),
		"The actor must play a distinct performance animation."
	)
	var dialogue_label: Label3D = actor.get_node("SceneDialogue") as Label3D
	assert(
		dialogue_label.visible
		and dialogue_label.text.contains("Ты тоже это слышал"),
		"The speaking character must display its assigned dialogue."
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
	assert(
		actor.global_position.distance_to(next_scene_mark) <= 0.25,
		"The actor must move to new blocking when the scene phase changes."
	)
	assert(
		not dialogue_label.visible,
		"Dialogue subtitles must disappear when the actor is not speaking."
	)
	actor.call("return_to_workplace")
	for _step in range(30):
		actor.call("_process", 1.0)

	assert(
		not bool(actor.call("is_in_scene_performance")),
		"The actor must leave scene blocking after production work."
	)
	assert(
		actor.global_position.distance_to(route[route.size() - 1]) <= 0.25,
		"The actor must return to the assigned workstation after the scene."
	)
	assert(
		not bool(actor.call("is_scene_animation_active")),
		"The scene performance animation must stop after returning to work."
	)
