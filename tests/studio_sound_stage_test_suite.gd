extends "res://tests/studio_building_interior_test_suite_base.gd"

const STUDIO_BUILDING_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_manager.gd"
)
const NAVIGATION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)


func _run_tests() -> void:
	_run_case(Callable(self, "_test_sound_stage_interior"))
	_run_case(Callable(self, "_test_small_sound_stage_geometry"))
	_run_case(Callable(self, "_test_large_sound_stage_geometry"))
	_run_case(Callable(self, "_test_large_stage_exit_route"))

func _test_sound_stage_interior() -> void:
	var actor: Node3D = _create_building("sound_stage", 0.0)
	_expect(
		actor.get_node_or_null("Interior/StageFloor") != null,
		"Sound Stage must contain an interior floor."
	)
	_expect(
		(actor.get_node("Interior") as Node3D).scale.is_equal_approx(Vector3.ONE)
		and actor.get_node_or_null("RoofAssembly/StageRoof") != null
		and actor.get_node_or_null("RoofAssembly/SmallStageGableRoofLeft") == null
		and actor.get_node_or_null("RoofAssembly/HighBayRoofDeck") == null,
		"The medium sound stage must keep its own unscaled rectangular architecture."
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
	var back_wall_collision: StaticBody3D = actor.find_child("BackWallCollision", true, false) as StaticBody3D
	var side_wall_collision: StaticBody3D = actor.get_node("Interior/SetSideWallLeftCollision") as StaticBody3D
	_expect(
		back_wall_collision != null
		and side_wall_collision != null
		and back_wall_collision.collision_layer == 8
		and side_wall_collision.collision_layer == 8
		and back_wall_collision.get_node_or_null("CollisionShape3D") != null
		and side_wall_collision.get_node_or_null("CollisionShape3D") != null,
		"Building perimeter and set walls must expose dedicated movement collision shapes."
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

func _test_small_sound_stage_geometry() -> void:
	var actor: Node3D = _create_building("sound_stage", 0.0, 1)
	var interior: Node3D = actor.get_node("Interior") as Node3D
	_expect(
		interior.scale.is_equal_approx(Vector3.ONE)
		and actor.get_node_or_null(
			"RoofAssembly/SmallStageGableRoofLeft"
		) != null
		and actor.get_node_or_null(
			"RoofAssembly/SmallStageGableRoofRight"
		) != null
		and actor.get_node_or_null("Interior/SmallSetBackdrop") != null,
		"The small sound stage must use its own compact gable-roof building and set layout, not a scaled medium model."
	)
	var last_route: Array[Vector3] = actor.call("get_workplace_path", 5)
	var local_workplace: Vector3 = Vector3.ZERO
	if not last_route.is_empty():
		local_workplace = actor.to_local(last_route.back())
	_expect(
		last_route.size() >= 4
		and absf(local_workplace.x) < 5.0
		and absf(local_workplace.z) < 4.0,
		"Small stage crew routes must terminate inside its ten-by-eight-metre footprint."
	)
	var local_mark: Vector3 = interior.to_local(
		actor.call("get_scene_mark", 0, "shooting", 0)
	)
	_expect(
		local_mark.distance_to(Vector3(-1.42, 0.0, -2.13)) < 0.2,
		"Small stage actor blocking must use compact set-specific marks."
	)

func _test_large_sound_stage_geometry() -> void:
	var actor: Node3D = _create_building("sound_stage", 0.0, 3)
	var interior: Node3D = actor.get_node("Interior") as Node3D
	_expect(
		interior.scale.is_equal_approx(Vector3.ONE)
		and actor.get_node_or_null("RoofAssembly/HighBayRoofDeck") != null
		and actor.get_node_or_null("RoofAssembly/HighBayRoofTruss_8") != null
		and actor.get_node_or_null("HighBayFrontSign") != null
		and actor.get_node_or_null("Interior/HighBayMainSetBackdrop") != null,
		"Large sound stage must use a separate high-bay building with roof trusses, control-room glazing and an expanded set."
	)
	var workplace_path: Array[Vector3] = actor.call("get_workplace_path", 10)
	_expect(
		workplace_path.size() >= 4,
		"Large sound stage must expose all twelve crew navigation points."
	)
	var local_mark: Vector3 = interior.to_local(
		actor.call("get_scene_mark", 0, "shooting", 0)
	)
	_expect(
		local_mark.distance_to(Vector3(-4.62, 0.0, -4.78)) < 0.15,
		"Large stage blocking marks must use the expanded high-bay set layout."
	)

func _test_large_stage_exit_route() -> void:
	var source_actor: Node3D = _create_building("sound_stage", 0.0, 3)
	var target_actor: Node3D = _create_building("editing_suite", 0.0)
	var target_position := Vector3(34.0, 0.0, -8.0)
	target_actor.position = target_position
	var source_data: Variant = source_actor.get("building_data")
	var target_data: Variant = target_actor.get("building_data")
	target_data.position = target_position
	var manager: Node3D = STUDIO_BUILDING_MANAGER_SCRIPT.new()
	manager.set("_navigation_system", NAVIGATION_SYSTEM_SCRIPT.new())
	manager.set("_buildings", [source_data, target_data])
	manager.set("_building_actors", {
		str(source_data.id): source_actor,
		str(target_data.id): target_actor,
	})
	var target_path: Array[Vector3] = target_actor.call(
		"get_workplace_path",
		0
	)
	var outer_routes_valid: bool = not target_path.is_empty()
	for source_slot_index in range(12):
		var source_workplace_path: Array[Vector3] = source_actor.call(
			"get_workplace_path",
			source_slot_index
		)
		if source_workplace_path.is_empty():
			outer_routes_valid = false
			continue
		var direct_exit_path: Array[Vector3] = source_actor.call(
			"get_exit_path_from",
			source_workplace_path.back(),
			source_slot_index
		)
		outer_routes_valid = (
			outer_routes_valid
			and source_workplace_path.size() >= 2
			and direct_exit_path.size() >= 2
			and direct_exit_path.front().distance_to(source_workplace_path.back()) < 0.1
			and direct_exit_path.back().distance_to(source_workplace_path.front()) < 0.1
		)
	for source_slot_index in [3, 4]:
		var source_path: Array[Vector3] = source_actor.call(
			"get_workplace_path",
			source_slot_index
		)
		if source_path.is_empty():
			outer_routes_valid = false
			continue
		var route: Array[Vector3] = manager.call(
			"get_workplace_path_from",
			str(target_data.id),
			0,
			source_path.back(),
			str(source_data.id),
			source_slot_index
		)
		var source_entrance_found: bool = false
		for point in route:
			if point.distance_to(source_path.front()) <= 0.25:
				source_entrance_found = true
				break
		outer_routes_valid = (
			outer_routes_valid
			and route.size() >= 3
			and source_entrance_found
			and route.back().distance_to(target_path.back()) < 0.25
		)
	_expect(
		outer_routes_valid,
		"Employees on both outer crew marks of a large 22-by-18-metre stage must exit through its real entrance before crossing the studio yard."
	)
	manager.free()
