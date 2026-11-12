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
	_test_script_department()
	_test_editing_suite()
	_finish_test("StudioOfficeVisualBuilderSmokeTest")


func _create_office(building_type_id: String) -> Node3D:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-OFFICE-%s-TEST" % building_type_id.to_upper()
	data.building_type_id = building_type_id
	data.display_name = "Test %s" % building_type_id
	data.position = Vector3.ZERO
	data.rotation_degrees = 0.0
	data.stage_size_tier = 2
	var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", data)
	root.add_child(actor)
	return actor


func _assert_office_routes(actor: Node3D, office_name: String) -> void:
	var all_routes_valid: bool = true
	for slot_index in [0, 2]:
		var route: Array[Vector3] = actor.call("get_workplace_path", slot_index)
		if route.size() < 4:
			all_routes_valid = false
			continue
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
		"%s must retain all three navigable workplace entry and exit routes." % office_name
	)


func _test_script_department() -> void:
	var actor: Node3D = _create_office("script_department")
	var interior: Node3D = actor.get_node("Interior") as Node3D
	var roof: Node3D = actor.get_node("RoofAssembly") as Node3D
	_expect(
		interior.get_node_or_null("OfficeFloor") is MeshInstance3D
		and roof.get_node_or_null("OfficeRoof") is MeshInstance3D,
		"Script Department must retain its own office floor and roof."
	)
	_expect(
		interior.get_node_or_null("WriterDesk") is MeshInstance3D
		and interior.get_node_or_null("ComputerMonitor") is MeshInstance3D
		and interior.get_node_or_null("Bookshelf") is MeshInstance3D
		and interior.get_node_or_null("ResearchBoard") is MeshInstance3D,
		"Script Department must retain writer desks, monitors, reference storage and research board."
	)
	_expect(
		actor.get_node_or_null("Interior/FrontWallGroup/OfficeFrontWindowLeft") is MeshInstance3D
		and actor.get_node_or_null("OfficeSignText") is Label3D,
		"Script Department must retain its own front glazing and exterior sign."
	)
	var desk_count: int = 0
	for child in interior.get_children():
		if str(child.name).begins_with("WriterDesk"):
			desk_count += 1
	_expect(desk_count == 3,"Script Department must retain exactly three writer desks.")
	_assert_office_routes(actor,"Script Department")
	actor.queue_free()


func _test_editing_suite() -> void:
	var actor: Node3D = _create_office("editing_suite")
	var interior: Node3D = actor.get_node("Interior") as Node3D
	var roof: Node3D = actor.get_node("RoofAssembly") as Node3D
	_expect(
		interior.get_node_or_null("EditingFloor") is MeshInstance3D
		and roof.get_node_or_null("EditingRoof") is MeshInstance3D,
		"Editing Suite must retain its own editing floor and roof."
	)
	_expect(
		interior.get_node_or_null("EditingDesk_0") is MeshInstance3D
		and interior.get_node_or_null("EditingMonitor_0") is MeshInstance3D
		and interior.get_node_or_null("EditingPreviewMonitor_0") is MeshInstance3D
		and interior.get_node_or_null("EditingReferenceDisplay") is MeshInstance3D,
		"Editing Suite must retain its editing workstations and reference display."
	)
	_expect(
		interior.get_node_or_null("AudioMixer_0") is MeshInstance3D
		and interior.get_node_or_null("AudioEquipmentRack") is MeshInstance3D
		and actor.get_node_or_null("Interior/FrontWallGroup/EditingWindowLeft") is MeshInstance3D,
		"Editing Suite must retain its audio equipment and dedicated front windows."
	)
	var desk_count: int = 0
	for child in interior.get_children():
		if str(child.name).begins_with("EditingDesk_"):
			desk_count += 1
	_expect(desk_count == 3,"Editing Suite must retain exactly three editor workstations.")
	_assert_office_routes(actor,"Editing Suite")
	actor.queue_free()
