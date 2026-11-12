extends "res://tests/smoke_test_base.gd"

const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_stage_tier(
		1,
		"SmallStageGableRoofLeft",
		"SmallStageFloor",
		"SmallSetBackdrop",
		1,
		"small"
	)
	_test_stage_tier(
		2,
		"StageRoof",
		"StageFloor",
		"MainSetBackdrop",
		2,
		"medium"
	)
	_test_stage_tier(
		3,
		"HighBayRoofDeck",
		"HighBayStageFloor",
		"HighBayMainSetBackdrop",
		3,
		"large"
	)
	_finish_test("StudioSoundStageVisualBuilderSmokeTest")


func _test_stage_tier(
	stage_size_tier: int,
	expected_roof_node: String,
	expected_floor_node: String,
	expected_set_node: String,
	expected_camera_count: int,
	tier_label: String
) -> void:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-SOUND-STAGE-%s" % tier_label.to_upper()
	data.building_type_id = "sound_stage"
	data.display_name = "Test %s Sound Stage" % tier_label.capitalize()
	data.position = Vector3.ZERO
	data.rotation_degrees = 0.0
	data.stage_size_tier = stage_size_tier

	var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", data)
	root.add_child(actor)

	var interior: Node3D = actor.get_node("Interior") as Node3D
	var roof: Node3D = actor.get_node("RoofAssembly") as Node3D
	_expect(
		interior.scale.is_equal_approx(Vector3.ONE)
		and roof.get_node_or_null(expected_roof_node) is MeshInstance3D,
		"%s sound stage must retain its dedicated, unscaled roof architecture." % tier_label.capitalize()
	)
	_expect(
		interior.get_node_or_null(expected_floor_node) is MeshInstance3D
		and interior.get_node_or_null(expected_set_node) is MeshInstance3D,
		"%s sound stage must retain its own floor and film-set layout." % tier_label.capitalize()
	)
	_expect(
		interior.get_node_or_null("CameraRig_0/CinemaCameraBody") is MeshInstance3D,
		"%s sound stage must expose its first working camera rig." % tier_label.capitalize()
	)

	var camera_count: int = 0
	for child in interior.get_children():
		if str(child.name).begins_with("CameraRig_"):
			camera_count += 1
	_expect(
		camera_count == expected_camera_count,
		"%s sound stage must retain exactly %d camera rigs." % [
			tier_label.capitalize(),
			expected_camera_count,
		]
	)

	var workplace_path: Array[Vector3] = actor.call("get_workplace_path", 0)
	_expect(
		workplace_path.size() >= 4,
		"%s sound stage must keep its workplace route connected to the entrance." % tier_label.capitalize()
	)
	var exit_path: Array[Vector3] = actor.call(
		"get_exit_path_from",
		workplace_path.back(),
		0
	) if not workplace_path.is_empty() else []
	_expect(
		exit_path.size() >= 2
		and exit_path.front().distance_to(workplace_path.back()) <= 0.1,
		"%s sound stage must keep its exit route connected to its workplace." % tier_label.capitalize()
	)

	actor.queue_free()
