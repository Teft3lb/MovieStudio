extends "res://tests/studio_building_interior_test_suite_base.gd"




func _run_tests() -> void:
	_test_script_department_interior()
	_test_tv_studio_interior()
	_test_prop_warehouse_interior()
	_test_editing_suite_interior()


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

func _test_tv_studio_interior() -> void:
	var actor: Node3D = _create_building("tv_studio", 0.0)
	_expect(
		actor.get_node_or_null("Interior/TVStudioFloor") != null
		and actor.get_node_or_null("Interior/TVStudioStagePlatform") != null
		and actor.get_node_or_null("Interior/TVStudioLEDWall") != null
		and actor.get_node_or_null("Interior/TVStudioHostDesk") != null,
		"TV Studio must have a dedicated broadcast stage, LED backdrop and host desk."
	)
	_expect(
		actor.get_node_or_null("Interior/TVStudioCameraRig_0/TVStudioCameraBody") != null
		and actor.get_node_or_null("Interior/TVStudioAudienceSeat_0") != null
		and actor.get_node_or_null("Interior/TVStudioControlDesk") != null
		and actor.get_node_or_null("RoofAssembly/TVStudioRoofDeck") != null,
		"TV Studio must contain multi-camera equipment, audience seating, a control booth and its own flat-roof architecture."
	)

	var all_routes_valid: bool = true
	for slot_index in range(10):
		var route: Array[Vector3] = actor.call(
			"get_workplace_path",
			slot_index
		)
		if route.size() < 4:
			all_routes_valid = false
			continue
		var local_workplace: Vector3 = actor.to_local(route.back())
		if (
			absf(local_workplace.x) >= 9.4
			or absf(local_workplace.z) >= 7.4
		):
			all_routes_valid = false
		var exit_route: Array[Vector3] = actor.call(
			"get_exit_path_from",
			route.back(),
			slot_index
		)
		if (
			exit_route.size() < 2
			or exit_route.front().distance_to(route.back()) > 0.1
			or exit_route.back().distance_to(route.front()) > 0.1
		):
			all_routes_valid = false
	_expect(
		all_routes_valid,
		"All ten TV Studio workstations must have navigable entry and exit routes around cameras, the host desk, audience rows and control booth."
	)

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
