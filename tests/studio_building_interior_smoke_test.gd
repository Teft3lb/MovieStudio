extends SceneTree

const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const CHARACTER_VISUAL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_visual.gd"
)


func _initialize() -> void:
	_test_script_department_interior()
	_test_sound_stage_interior()
	_test_profession_work_animation()

	print("StudioBuildingInteriorSmokeTest: PASS")
	quit(0)


func _create_building(building_type_id: String, rotation: float) -> Node3D:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-INTERIOR-%s" % building_type_id
	data.building_type_id = building_type_id
	data.display_name = "Test %s" % building_type_id
	data.position = Vector3(12.0, 0.0, -8.0)
	data.rotation_degrees = rotation

	var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", data)
	root.add_child(actor)
	return actor


func _test_script_department_interior() -> void:
	var actor: Node3D = _create_building("script_department", 90.0)
	assert(
		actor.get_node_or_null("Interior/OfficeFloor") != null,
		"Script Department must contain a visible interior floor."
	)
	assert(
		actor.get_node_or_null("Interior/WriterDesk") != null,
		"Script Department must contain writer desks."
	)
	assert(
		actor.get_node_or_null("Interior/ComputerMonitor") != null,
		"Script Department must contain computer workstations."
	)
	_assert_workplace_route(actor, 0, 3, 8.0, 6.0)
	_assert_workplace_route(actor, 2, 3, 8.0, 6.0)


func _test_sound_stage_interior() -> void:
	var actor: Node3D = _create_building("sound_stage", 0.0)
	assert(
		actor.get_node_or_null("Interior/StageFloor") != null,
		"Sound Stage must contain an interior floor."
	)
	assert(
		actor.get_node_or_null("Interior/MainSetBackdrop") != null,
		"Sound Stage must contain a film set."
	)
	assert(
		actor.get_node_or_null("Interior/CinemaCameraBody") != null,
		"Sound Stage must contain camera equipment."
	)
	assert(
		actor.get_node_or_null("Interior/TechnicalEquipmentRack") != null,
		"Sound Stage must contain a technician equipment station."
	)
	_assert_workplace_route(actor, 0, 8, 14.0, 12.0)
	_assert_workplace_route(actor, 7, 8, 14.0, 12.0)


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
	assert(
		route.size() == 4,
		"Workplace routes must contain outside, entrance, corridor and work points."
	)

	var outside: Vector3 = actor.to_local(route[0])
	var inside: Vector3 = actor.to_local(route[1])
	var workstation: Vector3 = actor.to_local(route[3])

	assert(
		outside.z > depth * 0.5,
		"The first route point must be outside the front entrance."
	)
	assert(
		inside.z < depth * 0.5,
		"The second route point must pass through the entrance into the building."
	)
	assert(
		absf(workstation.x) < width * 0.5
		and absf(workstation.z) < depth * 0.5,
		"The final work point must be inside the building footprint."
	)
	assert(
		route[0].distance_to(route[1]) > 1.0,
		"The employee must visibly travel through the entrance."
	)
	assert(
		slot_index >= 0 and slot_index < capacity,
		"Test slot must fit the building workplace capacity."
	)


func _test_profession_work_animation() -> void:
	var visual: Node3D = CHARACTER_VISUAL_SCRIPT.new()
	root.add_child(visual)
	visual.call("setup", {"appearance": {}})
	visual.call("set_working", true, "screenwriter")
	visual.call("advance_simulation", 0.5)
	assert(
		bool(visual.call("is_working")),
		"CharacterVisual must expose an active working animation state."
	)
	visual.call("set_walking", true)
	assert(
		not bool(visual.call("is_working")),
		"Walking animation must replace the working animation."
	)
