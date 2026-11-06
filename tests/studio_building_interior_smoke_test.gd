extends "res://tests/smoke_test_base.gd"

const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const CHARACTER_VISUAL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_visual.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const GAME_CLOCK_SCRIPT = preload(
	"res://scripts/core/game_clock.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_script_department_interior()
	_test_sound_stage_interior()
	_test_prop_warehouse_interior()
	_test_editing_suite_interior()
	_test_staff_housing_beds()
	_test_profession_work_animation()
	_test_facility_poses()
	_test_employee_enters_and_leaves_workplace()

	_finish_test("StudioBuildingInteriorSmokeTest")


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
	_expect(
		actor.get_node_or_null("Interior/OfficeFloor") != null,
		"Script Department must contain a visible interior floor."
	)
	_expect(
		actor.get_node_or_null("Interior/WriterDesk") != null,
		"Script Department must contain writer desks."
	)
	_expect(
		actor.get_node_or_null("Interior/ComputerMonitor") != null,
		"Script Department must contain computer workstations."
	)
	_assert_workplace_route(actor, 0, 3, 8.0, 6.0)
	_assert_workplace_route(actor, 2, 3, 8.0, 6.0)


func _test_prop_warehouse_interior() -> void:
	var actor: Node3D = _create_building("prop_warehouse", 0.0)
	_expect(
		actor.get_node_or_null("Interior/WarehouseFloor") != null
		and actor.get_node_or_null("Interior/WarehouseInventory") != null,
		"Prop Warehouse must contain a dedicated interior and inventory display."
	)
	_expect(
		actor.get_node_or_null("Interior/WarehouseShelf_-1_0") != null
		and actor.get_node_or_null("Interior/WarehouseShelf_1_2") != null,
		"Prop Warehouse must contain reusable storage shelving."
	)
	var workplace_path: Array[Vector3] = actor.call(
		"get_workplace_path",
		0
	)
	_expect(
		workplace_path.size() == 4,
		"Warehouse pickup routes must pass through the building entrance."
	)
	var storage_mark: Vector3 = actor.call("get_storage_mark", 3)
	var local_storage_mark: Vector3 = actor.to_local(storage_mark)
	_expect(
		absf(local_storage_mark.x) <= 3.0
		and local_storage_mark.z >= -2.2
		and local_storage_mark.z <= 0.6,
		"Technician pickup marks must be inside the warehouse aisle."
	)
	actor.call(
		"set_warehouse_inventory",
		["lighthouse_console", "lighthouse_beacon"]
	)
	var inventory_root: Node3D = actor.get_node(
		"Interior/WarehouseInventory"
	) as Node3D
	_expect(
		inventory_root.get_child_count() == 2
		and inventory_root.get_node_or_null(
			"StoredProp_lighthouse_console"
		) != null,
		"Owned props in warehouse stock must have visible shelf representations."
	)
	actor.call("set_warehouse_inventory", [])
	_expect(
		inventory_root.get_child_count() == 0,
		"Picking a prop must remove its stored representation from the warehouse shelves."
	)


func _test_editing_suite_interior() -> void:
	var actor: Node3D = _create_building("editing_suite", 0.0)
	_expect(
		actor.get_node_or_null("Interior/EditingFloor") != null,
		"Editing Suite must contain an interior floor."
	)
	_expect(
		actor.get_node_or_null("Interior/EditingDesk_0") != null,
		"Editing Suite must contain editing workstations."
	)
	_expect(
		actor.get_node_or_null("Interior/EditingMonitor_0") != null
		and actor.get_node_or_null("Interior/EditingPreviewMonitor_0") != null,
		"Editing workstations must contain timeline and preview monitors."
	)
	_expect(
		actor.get_node_or_null("Interior/AudioMixer_0") != null
		and actor.get_node_or_null("Interior/AudioEquipmentRack") != null,
		"Editing Suite must contain audio mixing equipment."
	)
	_expect(
		actor.get_node_or_null("Interior/EditingReferenceDisplay") != null,
		"Editing Suite must contain a shared reference display."
	)
	var interior: Node3D = actor.get_node("Interior") as Node3D
	var desk_count: int = 0
	for child in interior.get_children():
		if str(child.name).begins_with("EditingDesk_"):
			desk_count += 1
	_expect(
		desk_count == 3,
		"Editing Suite must expose exactly three physical editor workstations."
	)
	_assert_workplace_route(actor, 0, 3, 10.0, 8.0)
	_assert_workplace_route(actor, 2, 3, 10.0, 8.0)


func _test_sound_stage_interior() -> void:
	var actor: Node3D = _create_building("sound_stage", 0.0)
	_expect(
		actor.get_node_or_null("Interior/StageFloor") != null,
		"Sound Stage must contain an interior floor."
	)
	_expect(
		actor.get_node_or_null("Interior/MainSetBackdrop") != null,
		"Sound Stage must contain a film set."
	)
	_expect(
		actor.get_node_or_null("Interior/CameraRig_0/CinemaCameraBody") != null,
		"Sound Stage must contain camera equipment."
	)
	var camera_rig: Node3D = actor.get_node(
		"Interior/CameraRig_0"
	) as Node3D
	actor.call(
		"set_camera_target",
		Vector3(0.0, 1.0, -4.0),
		true
	)
	_expect(
		not camera_rig.rotation.is_equal_approx(Vector3.ZERO),
		"Camera rigs must turn toward the active scene during filming."
	)
	actor.call(
		"set_camera_target",
		Vector3.ZERO,
		false
	)
	_expect(
		camera_rig.rotation.is_equal_approx(Vector3.ZERO),
		"Camera rigs must return to their idle position when filming stops."
	)
	_expect(
		actor.get_node_or_null("Interior/TechnicalEquipmentRack") != null,
		"Sound Stage must contain a technician equipment station."
	)
	var camera_workplace: Vector3 = actor.to_local(
		actor.call("get_workplace_position", 3)
	)
	var director_workplace: Vector3 = actor.to_local(
		actor.call("get_workplace_position", 2)
	)
	var technician_workplace: Vector3 = actor.to_local(
		actor.call("get_workplace_position", 5)
	)
	var director_desk: Node3D = actor.get_node(
		"Interior/DirectorMonitorDesk"
	) as Node3D
	var equipment_rack: Node3D = actor.get_node(
		"Interior/TechnicalEquipmentRack"
	) as Node3D
	_expect(
		camera_workplace.distance_to(Vector3(-5.0, 0.0, 0.8)) < 0.25,
		"The camera operator workstation must sit directly behind the primary camera rig."
	)
	_expect(
		director_workplace.distance_to(
			actor.to_local(director_desk.global_position)
		) < 1.2,
		"The director workstation must be beside the production monitor."
	)
	_expect(
		technician_workplace.distance_to(
			actor.to_local(equipment_rack.global_position)
		) < 1.5,
		"The technician workstation must be beside the equipment rack."
	)
	_assert_workplace_route(actor, 0, 8, 14.0, 12.0)
	_assert_workplace_route(actor, 7, 8, 14.0, 12.0)

	var hold_mark: Vector3 = actor.call("get_scene_hold_mark", 0)
	var local_hold_mark: Vector3 = actor.to_local(hold_mark)
	_expect(
		absf(local_hold_mark.x) > 4.5
		and local_hold_mark.z >= 4.0
		and local_hold_mark.z <= 5.4,
		"Off-camera holding marks must be behind the camera line and inside the Sound Stage."
	)
	var preparation_mark: Vector3 = actor.call(
		"get_scene_mark",
		0,
		"preparation",
		0
	)
	var shooting_mark: Vector3 = actor.call(
		"get_scene_mark",
		0,
		"shooting",
		0
	)
	_expect(
		preparation_mark.distance_to(shooting_mark) > 0.4,
		"Actors must receive different blocking marks during the shooting phase."
	)

	var slate: Label3D = actor.get_node_or_null(
		"Interior/ProductionSceneSlate"
	) as Label3D
	_expect(
		slate != null,
		"Sound Stage must contain a visible production slate."
	)
	actor.call(
		"set_production_scene",
		2,
		"Кульминация",
		"Съёмка дубля"
	)
	_expect(
		slate.text.contains("02")
		and slate.text.contains("Кульминация"),
		"Production slate must display the active scene."
	)

	var set_dressing_root: Node3D = actor.get_node_or_null(
		"Interior/SetDressing"
	) as Node3D
	_expect(
		set_dressing_root != null,
		"Sound Stage must own a dedicated reusable set-dressing area."
	)
	var setup: Dictionary = {
		"scene_id": "SCN-SET-01",
		"set_id": "lighthouse",
		"prop_ids": [
			"lighthouse_console",
			"lighthouse_beacon",
			"lighthouse_rail",
		],
	}
	actor.call("set_scene_set_dressing", setup, 0.0)
	_expect(
		set_dressing_root.get_child_count() == 3,
		"Each purchased set piece must create its own physical prop instance."
	)
	var first_prop: Node3D = set_dressing_root.get_node(
		"SetProp_lighthouse_console"
	) as Node3D
	var first_prop_mark: Vector3 = actor.to_local(
		actor.call("get_set_dressing_mark", 0)
	)
	_expect(
		actor.to_local(first_prop.global_position).distance_to(first_prop_mark) < 0.01,
		"Technician installation marks must exactly match the physical prop positions."
	)
	if set_dressing_root.get_child_count() > 0:
		_expect(
			not (set_dressing_root.get_child(0) as Node3D).visible,
			"Purchased props must remain hidden until the technician installs them."
		)
	for prop_node in set_dressing_root.get_children():
		var prop_root: Node3D = prop_node as Node3D
		_expect(
			absf(prop_root.position.x) < 3.9
			and prop_root.position.z >= -4.2
			and prop_root.position.z <= -1.0,
			"Purchased props must be placed on the visible set platform, inside its side walls."
		)
	actor.call("set_scene_set_dressing", setup, 0.34)
	var visible_prop_count: int = 0
	for prop_node in set_dressing_root.get_children():
		if (prop_node as Node3D).visible:
			visible_prop_count += 1
	_expect(
		visible_prop_count == 1,
		"Installed props must appear progressively during set dressing."
	)
	actor.call("set_scene_set_dressing", setup, 1.0)
	visible_prop_count = 0
	for prop_node in set_dressing_root.get_children():
		if (prop_node as Node3D).visible:
			visible_prop_count += 1
	_expect(
		visible_prop_count == 3,
		"All planned props must be visible when technician setup completes."
	)
	var set_start: Vector3 = actor.to_global(Vector3(0.0, 0.0, 1.4))
	var set_target: Vector3 = actor.call("get_set_dressing_mark", 0)
	var set_path: Array[Vector3] = actor.call(
		"get_scene_path",
		set_start,
		set_target
	)
	_expect(
		set_path.size() >= 2
		and set_path.front().distance_to(set_start) <= 0.1
		and set_path.back().distance_to(set_target) <= 0.1,
		"Technicians must receive a valid route to each prop installation mark."
	)
	var technician_return_path: Array[Vector3] = actor.call(
		"get_scene_path",
		set_target,
		actor.call("get_workplace_position", 5)
	)
	_expect(
		technician_return_path.size() >= 2,
		"A technician standing at an installed prop must be able to route back to the workstation without treating that prop as an impassable start obstacle."
	)
	var next_setup: Dictionary = setup.duplicate(true)
	next_setup["scene_id"] = "SCN-SET-02"
	_expect(
		not bool(actor.call("prepare_scene_set_dressing", next_setup))
		and set_dressing_root.get_child_count() == 3,
		"A new scene must not replace props until technicians have removed the previous set."
	)
	_expect(
		bool(actor.call("remove_set_prop", "lighthouse_console"))
		and not (set_dressing_root.get_node(
			"SetProp_lighthouse_console"
		) as Node3D).visible,
		"A set piece must be removed explicitly before the warehouse return."
	)
	_expect(
		bool(actor.call("install_set_prop", "lighthouse_console"))
		and (set_dressing_root.get_node(
			"SetProp_lighthouse_console"
		) as Node3D).visible,
		"A delivered prop must be installable after removal."
	)
	for prop_id in setup.get("prop_ids", []):
		actor.call("remove_set_prop", str(prop_id))
	actor.call("clear_scene_set_dressing")
	_expect(
		set_dressing_root.get_child_count() == 0,
		"The stage may clear its prop nodes only after the explicit strike operation."
	)
	_expect(
		bool(actor.call("prepare_scene_set_dressing", next_setup))
		and set_dressing_root.get_child_count() == 3,
		"A new scene setup must be accepted after the previous props are cleared."
	)
	actor.call("clear_scene_set_dressing")



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


func _test_staff_housing_beds() -> void:
	var actor: Node3D = _create_building("staff_housing", 0.0)
	var first_bed_path: Array[Vector3] = actor.call("get_workplace_path", 0)
	var last_bed_path: Array[Vector3] = actor.call("get_workplace_path", 7)
	var first_bed: Vector3 = actor.to_local(first_bed_path.back())
	var last_bed: Vector3 = actor.to_local(last_bed_path.back())
	_expect(
		first_bed.distance_to(Vector3(-5.15, 0.0, -2.75)) < 0.01
		and last_bed.distance_to(Vector3(5.15, 0.0, 4.25)) < 0.01,
		"Staff housing slots must align with the centers of the eight beds without arbitrary lateral offsets."
	)


func _test_facility_poses() -> void:
	var visual: Node3D = CHARACTER_VISUAL_SCRIPT.new()
	root.add_child(visual)
	visual.call("setup", {"appearance": {}})
	visual.call("set_performance_action", "eating")
	var body_root: Node3D = visual.get_node("BodyRoot") as Node3D
	var left_leg: Node3D = visual.get_node("BodyRoot/LeftLegPivot") as Node3D
	var left_arm: Node3D = visual.get_node("BodyRoot/LeftArmPivot") as Node3D
	var minimum_arm_angle: float = INF
	var maximum_arm_angle: float = -INF
	for _step in range(12):
		visual.call("advance_simulation", 0.1)
		minimum_arm_angle = minf(minimum_arm_angle, left_arm.rotation.x)
		maximum_arm_angle = maxf(maximum_arm_angle, left_arm.rotation.x)
	_expect(
		body_root.position.y < -0.2
		and left_leg.rotation.x > 0.65,
		"Eating must lower the torso and bend the legs into a seated chair pose."
	)
	_expect(
		maximum_arm_angle - minimum_arm_angle > 0.08,
		"Eating must animate alternating hand movement instead of holding a static pose."
	)
	visual.call("set_performance_action", "sleeping")
	visual.call("advance_simulation", 0.25)
	_expect(
		absf(body_root.rotation.x + PI * 0.5) < 0.1
		and body_root.position.y > 0.5
		and body_root.scale.y < 0.9,
		"Sleeping must place a scaled-down character horizontally on the bed with subtle breathing."
	)
	visual.free()


func _test_employee_enters_and_leaves_workplace() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 912345
	var employee: Variant = generator.call(
		"generate",
		rng,
		"EMP-INTERIOR-ROUTE",
		"screenwriter"
	)

	var building: Node3D = _create_building("script_department", 0.0)
	var route: Array[Vector3] = building.call(
		"get_workplace_path",
		0
	)

	var clock: Node = GAME_CLOCK_SCRIPT.new()
	root.add_child(clock)
	var actor: Node3D = CHARACTER_ACTOR_SCRIPT.new()
	root.add_child(actor)
	var empty_waypoints: Array[Vector3] = []
	actor.call("setup", employee, empty_waypoints, clock, 5.0)
	actor.call(
		"assign_workplace_route",
		"BLD-INTERIOR-ROUTE",
		route,
		"screenwriter"
	)

	for _step in range(12):
		actor.call("_process", 10.0)

	_expect(
		bool(actor.call("is_at_workplace")),
		"An employee must reach the final interior workstation."
	)
	_expect(
		bool(actor.call("is_work_animation_active")),
		"An employee must switch to a profession-specific work animation on arrival."
	)

	actor.call("leave_workplace")
	for _step in range(12):
		actor.call("_process", 10.0)

	_expect(
		str(actor.call("get_workplace_building_id")).is_empty(),
		"An employee must clear the workplace assignment after exiting."
	)
	_expect(
		actor.global_position.is_equal_approx(route[0]),
		"An employee must leave through the entrance rather than disappear inside."
	)
	_expect(
		not bool(actor.call("is_work_animation_active")),
		"An employee must stop the work animation after leaving."
	)


func _test_profession_work_animation() -> void:
	var visual: Node3D = CHARACTER_VISUAL_SCRIPT.new()
	root.add_child(visual)
	visual.call("setup", {"appearance": {}})
	visual.call("set_working", true, "screenwriter")
	visual.call("advance_simulation", 0.5)
	_expect(
		bool(visual.call("is_working")),
		"CharacterVisual must expose an active working animation state."
	)
	visual.call("set_working", true, "film_editor")
	visual.call("advance_simulation", 0.5)
	var left_arm: Node3D = visual.get_node("BodyRoot/LeftArmPivot") as Node3D
	_expect(
		left_arm.rotation.x < -0.3,
		"Film editors must use a forward typing pose at their editing workstation."
	)
	visual.call("set_walking", true)
	_expect(
		not bool(visual.call("is_working")),
		"Walking animation must replace the working animation."
	)
	visual.call("set_carrying_prop", true)
	visual.call("set_walking", true)
	visual.call("advance_simulation", 0.5)
	var carried_case: Node3D = visual.get_node(
		"BodyRoot/CarriedProp"
	) as Node3D
	var carrying_arm: Node3D = visual.get_node(
		"BodyRoot/LeftArmPivot"
	) as Node3D
	_expect(
		carried_case.visible
		and carried_case.get_node_or_null("PropTransportCase") != null
		and carrying_arm.rotation.x > 0.5,
		"Technicians must visibly carry a transport case while walking."
	)
	visual.call("set_carrying_prop", false)
	_expect(
		not carried_case.visible,
		"The transport case must disappear when the prop is installed or stored."
	)
	visual.call("set_performance_action", "placing_set_piece")
	visual.call("advance_simulation", 0.5)
	_expect(
		carrying_arm.rotation.x > 0.5,
		"The installation pose must reach forward toward the set piece."
	)

