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
	_test_tv_studio_visuals()
	_finish_test("StudioTVStudioVisualBuilderSmokeTest")


func _test_tv_studio_visuals() -> void:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-TV-STUDIO-VISUAL-TEST"
	data.building_type_id = "tv_studio"
	data.display_name = "Test Television Studio"
	data.position = Vector3.ZERO
	data.rotation_degrees = 0.0
	data.stage_size_tier = 2

	var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", data)
	root.add_child(actor)

	var interior: Node3D = actor.get_node("Interior") as Node3D
	var roof: Node3D = actor.get_node("RoofAssembly") as Node3D
	_expect(
		interior.get_node_or_null("TVStudioFloor") is MeshInstance3D
		and roof.get_node_or_null("TVStudioRoofDeck") is MeshInstance3D
		and roof.get_node_or_null("TVStudioRoofBeam_0") is MeshInstance3D,
		"TV Studio must retain its independent flat-roof architecture and interior floor."
	)
	_expect(
		actor.get_node_or_null("TVStudioEntranceCanopy") is MeshInstance3D
		and actor.get_node_or_null("TVStudioSign") is MeshInstance3D
		and actor.get_node_or_null("TVStudioSignText") is Label3D,
		"TV Studio must retain its dedicated entrance canopy and exterior signage."
	)
	_expect(
		interior.get_node_or_null("TVStudioStagePlatform") is MeshInstance3D
		and interior.get_node_or_null("TVStudioLEDWall/TVStudioLEDFrame") is MeshInstance3D
		and interior.get_node_or_null("TVStudioHostDesk/TVStudioHostDeskTop") is MeshInstance3D,
		"TV Studio must retain the broadcast stage, segmented LED wall and host desk."
	)
	_expect(
		interior.get_node_or_null("TVStudioCameraRig_0/TVStudioCameraBody") is MeshInstance3D
		and interior.get_node_or_null("TVStudioControlDesk/TVStudioControlConsole") is MeshInstance3D
		and interior.get_node_or_null("TVStudioControlDesk/TVStudioControlMonitor_3") is MeshInstance3D,
		"TV Studio must retain its camera rigs and director control console."
	)

	var camera_count: int = 0
	var audience_count: int = 0
	var led_panel_count: int = 0
	var softbox_count: int = 0
	for child in interior.get_children():
		var child_name: String = str(child.name)
		if child_name.begins_with("TVStudioCameraRig_"):
			camera_count += 1
		elif child_name.begins_with("TVStudioAudienceSeat_"):
			audience_count += 1
		elif child_name.begins_with("TVStudioSoftbox_"):
			softbox_count += 1
	var led_wall: Node3D = interior.get_node("TVStudioLEDWall") as Node3D
	for child in led_wall.get_children():
		if str(child.name).begins_with("TVStudioLEDPanel_"):
			led_panel_count += 1
	_expect(
		camera_count == 3
		and audience_count == 10
		and led_panel_count == 5
		and softbox_count == 6,
		"TV Studio must keep three cameras, ten audience seats, five LED panels and six softboxes."
	)

	var all_routes_valid: bool = true
	for slot_index in range(10):
		var route: Array[Vector3] = actor.call("get_workplace_path", slot_index)
		if route.size() < 4:
			all_routes_valid = false
			continue
		var local_workplace: Vector3 = actor.to_local(route.back())
		if absf(local_workplace.x) >= 9.4 or absf(local_workplace.z) >= 7.4:
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
		"All ten TV Studio workstations must retain navigable entry and exit routes."
	)
	actor.queue_free()
