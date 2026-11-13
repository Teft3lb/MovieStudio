extends RefCounted
class_name StudioBuildingInteriorTestSuiteBase

const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)

var _test_context: SceneTree
var root: Node


func run(test_context: SceneTree) -> void:
	_test_context = test_context
	root = test_context.root
	_run_tests()


func _run_tests() -> void:
	pass


func _expect(
	condition: bool,
	message: String = "Assertion failed."
) -> void:
	_test_context.call("_expect", condition, message)


func _create_building(
	building_type_id: String,
	rotation: float,
	stage_size_tier: int = 2
) -> Node3D:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-INTERIOR-%s" % building_type_id
	data.building_type_id = building_type_id
	data.display_name = "Test %s" % building_type_id
	data.position = Vector3(12.0, 0.0, -8.0)
	data.rotation_degrees = rotation
	data.stage_size_tier = stage_size_tier
	var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", data)
	root.add_child(actor)
	return actor


func _assert_workplace_route(
	actor: Node3D,
	slot_index: int,
	capacity: int,
	width: float,
	depth: float
) -> void:
	var route: Array[Vector3] = actor.call(
		"get_workplace_path",
		slot_index
	)
	_expect(
		route.size() == 4,
		"Workplace routes must contain outside, entrance, corridor and work points."
	)

	var outside: Vector3 = actor.to_local(route[0])
	var inside: Vector3 = actor.to_local(route[1])
	var workstation: Vector3 = actor.to_local(route[3])

	_expect(
		outside.z > depth * 0.5,
		"The first route point must be outside the front entrance."
	)
	_expect(
		inside.z < depth * 0.5,
		"The second route point must pass through the entrance into the building."
	)
	_expect(
		absf(workstation.x) < width * 0.5
		and absf(workstation.z) < depth * 0.5,
		"The final work point must be inside the building footprint."
	)
	_expect(
		route[0].distance_to(route[1]) > 1.0,
		"The employee must visibly travel through the entrance."
	)
	_expect(
		slot_index >= 0 and slot_index < capacity,
		"Test slot must fit the building workplace capacity."
	)
