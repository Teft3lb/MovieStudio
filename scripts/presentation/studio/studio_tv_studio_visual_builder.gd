extends RefCounted
class_name StudioTVStudioVisualBuilder

const FURNITURE = preload("res://scripts/presentation/studio/studio_office_furniture.gd")

var _actor: Node3D
var _interior_root: Node3D
var _visual_factory: RefCounted
var _roof_assembly: Node3D
var _workplace_points: Array[Vector3] = []


func build(
	actor: Node3D,
	interior_root: Node3D,
	visual_factory: RefCounted,
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> Dictionary:
	_actor = actor
	_interior_root = interior_root
	_visual_factory = visual_factory
	_roof_assembly = null
	_workplace_points.clear()
	_build_exterior(footprint, height, definition)
	_build_interior(footprint)
	return {
		"roof_assembly": _roof_assembly,
		"workplace_points": _workplace_points,
	}


func _build_exterior(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.30, 0.38, 0.43)
	var roof_color: Color = Color(0.10, 0.16, 0.22)
	var trim_color: Color = Color(0.07, 0.23, 0.31)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.12, 0.48, 0.62)
	)
	_create_floor(footprint, Color(0.13, 0.17, 0.20), "TVStudioFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		4.8,
		3.6
	)

	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	_actor.add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"TVStudioRoofDeck",
		Vector3(width + 0.7, 0.38, depth + 0.7),
		roof_color,
		Vector3(0.0, height - 0.22, 0.0)
	)
	for beam_x in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		_create_box(
			_roof_assembly,
			"TVStudioRoofBeam_%d" % roundi(beam_x * 10.0),
			Vector3(0.18, 0.5, depth + 0.45),
			trim_color,
			Vector3(beam_x, height - 0.48, 0.0)
		)

	_create_box(
		_actor,
		"TVStudioEntranceCanopy",
		Vector3(6.2, 0.22, 1.45),
		trim_color,
		Vector3(0.0, 3.7, depth * 0.5 + 0.78)
	)
	_create_box(
		_actor,
		"TVStudioSign",
		Vector3(7.6, 0.68, 0.18),
		accent_color,
		Vector3(0.0, 4.55, depth * 0.5 + 0.34)
	)
	_create_label(
		_actor,
		"TVStudioSignText",
		"ТЕЛЕВИЗИОННЫЙ ПАВИЛЬОН",
		Vector3(0.0, 4.55, depth * 0.5 + 0.45),
		18
	)
	for side_x in [-6.7, 6.7]:
		_create_box(
			_get_wall_group("front"),
			"TVStudioFrontGlass_%d" % roundi(side_x),
			Vector3(3.1, 1.65, 0.12),
			Color(0.10, 0.31, 0.42),
			Vector3(side_x, 4.0, depth * 0.5 + 0.22)
		)
	_create_box(
		_get_wall_group("left"),
		"TVStudioControlRoomGlass",
		Vector3(0.12, 2.1, 5.2),
		Color(0.08, 0.27, 0.37),
		Vector3(-width * 0.5 - 0.05, 5.0, 2.0)
	)
	_create_box(
		_get_wall_group("right"),
		"TVStudioServiceWindow",
		Vector3(0.12, 1.7, 3.4),
		Color(0.08, 0.27, 0.37),
		Vector3(width * 0.5 + 0.05, 4.3, -1.0)
	)



func _build_interior(_footprint: Vector2) -> void:
	var stage_color: Color = Color(0.18, 0.22, 0.27)
	var metal_color: Color = Color(0.34, 0.42, 0.48)
	var equipment_color: Color = Color(0.07, 0.10, 0.14)

	_create_box(
		_interior_root,
		"TVStudioStagePlatform",
		Vector3(14.0, 0.22, 5.0),
		stage_color,
		Vector3(0.0, 0.12, -3.8)
	)

	var led_wall := Node3D.new()
	led_wall.name = "TVStudioLEDWall"
	led_wall.position = Vector3(0.0, 0.0, -7.0)
	_interior_root.add_child(led_wall)
	_create_box(
		led_wall,
		"TVStudioLEDFrame",
		Vector3(14.0, 4.1, 0.28),
		equipment_color,
		Vector3(0.0, 3.05, 0.0)
	)
	for panel_index in range(5):
		var panel_x: float = -5.6 + float(panel_index) * 2.8
		var panel_asset := "BroadcastPanelWarm" if panel_index == 2 else "BroadcastPanelCool"
		FURNITURE.place(led_wall, panel_asset, "TVStudioLEDPanel_%d" % panel_index,
			Vector3(panel_x, 3.05, .18))

	var host_desk := Node3D.new()
	host_desk.name = "TVStudioHostDesk"
	host_desk.position = Vector3(0.0, 0.0, -2.5)
	_interior_root.add_child(host_desk)
	FURNITURE.place(host_desk, "BroadcastDesk", "TVStudioHostDeskTop", Vector3.ZERO)

	for guest_index in range(2):
		var guest_x: float = -2.3 if guest_index == 0 else 2.3
		FURNITURE.place(_interior_root, "ClubChair", "TVStudioGuestChair_%d" % guest_index,
			Vector3(guest_x, 0, -.75)).rotation.y = PI - signf(guest_x) * .26

	for camera_index in range(3):
		var camera_x: float = [-6.5, 0.0, 6.5][camera_index]
		var camera_z: float = -1.0 if camera_index != 1 else 1.0
		var camera_rig := Node3D.new()
		camera_rig.name = "TVStudioCameraRig_%d" % camera_index
		camera_rig.position = Vector3(camera_x, 0.0, camera_z)
		_interior_root.add_child(camera_rig)
		_visual_factory.call("attach_tv_camera", camera_rig)
		camera_rig.rotation.y = signf(camera_x) * .53

	_create_box(
		_interior_root,
		"TVStudioLightingTruss",
		Vector3(15.0, 0.18, 0.22),
		metal_color,
		Vector3(0.0, 6.45, -1.0)
	)
	for light_index in range(6):
		var light_x: float = -6.0 + float(light_index) * 2.4
		FURNITURE.place(_interior_root, "BroadcastSoftbox", "TVStudioSoftbox_%d" % light_index,
			Vector3(light_x, 5.87, -1.0))
		_create_box(
			_interior_root,
			"TVStudioLightMount_%d" % light_index,
			Vector3(0.12, 0.55, 0.12),
			metal_color,
			Vector3(light_x, 6.15, -1.0)
		)

	var audience_index: int = 0
	for row_index in range(2):
		var seat_z: float = 2.5 + float(row_index) * 2.0
		for seat_x in [-5.0, -2.5, 0.0, 2.5, 5.0]:
			var seat := Node3D.new()
			seat.name = "TVStudioAudienceSeat_%d" % audience_index
			seat.position = Vector3(seat_x, 0.0, seat_z)
			_interior_root.add_child(seat)
			FURNITURE.place(seat, "AudienceSeat", "TVStudioSeatBase", Vector3.ZERO)
			audience_index += 1

	var control_desk := Node3D.new()
	control_desk.name = "TVStudioControlDesk"
	control_desk.position = Vector3(-5.0, 0.0, 5.8)
	_interior_root.add_child(control_desk)
	_create_box(
		control_desk,
		"TVStudioControlConsole",
		Vector3(4.0, 0.85, 1.25),
		equipment_color,
		Vector3(0.0, 0.48, 0.0)
	)
	_create_box(
		control_desk,
		"TVStudioControlMonitorWall",
		Vector3(4.0, 1.55, 0.14),
		metal_color,
		Vector3(0.0, 1.55, -0.5)
	)
	for monitor_index in range(4):
		var monitor_x: float = -1.45 + float(monitor_index) * 0.96
		FURNITURE.place(control_desk, "PlaybackMonitor", "TVStudioControlMonitor_%d" % monitor_index,
			Vector3(monitor_x, 1.27, -.38)).scale = Vector3(.99, 1.35, 1.0)

	for side in [-1, 1]:
		_create_box(_interior_root, "TVStudioTrussUpright_%d" % side,
			Vector3(.15, 1.63, .16), metal_color, Vector3(side * 6.9, 7.29, -1.0))

	FURNITURE.place(host_desk, "CupService", "HostDeskService", Vector3(-1.55, 1.13, .11))
	FURNITURE.place(_interior_root, "DirectorChair", "TVHostChair", Vector3(1.1, .23, -3.54)).rotation.y = PI
	FURNITURE.floor_zone(_interior_root, "TechnicalInset", "TVAudienceFloor", Vector2(0, 3.64), Vector2(12.3, 3.68))
	FURNITURE.floor_zone(_interior_root, "TechnicalInset", "TVControlFloor", Vector2(-5.7, 6.47), Vector2(4.73, 1.91))
	FURNITURE.floor_zone(_interior_root, "RestInset", "TVGuestFloor", Vector2(0, -.45), Vector2(6.75, 1.68))
	FURNITURE.place(control_desk, "AudioMixer", "BroadcastAudio", Vector3(1.37, .91, .29))
	FURNITURE.place(control_desk, "OfficeKeyboard", "BroadcastSwitcher", Vector3(-.31, .91, .25))
	FURNITURE.place(_interior_root, "EquipmentRack", "TVPatchRack", Vector3(-9.16, 0, 4.15)).rotation.y = PI * .5
	FURNITURE.place(_interior_root, "WorkshopBench", "TVEngineeringDesk", Vector3(-9.10, 0, 1.05), true).rotation.y = PI * .5
	FURNITURE.place(_interior_root, "PrivacyScreen", "TVControlDivider", Vector3(-5.51, 0, 7.18), true).scale.x = 2.62
	FURNITURE.place(_interior_root, "ClubSofa", "TVGreenRoomSeat", Vector3(9.06, 0, 3.01), true).rotation.y = -PI * .5
	FURNITURE.place(_interior_root, "WaterCooler", "TVGreenRoomWater", Vector3(9.18, 0, 4.81)).rotation.y = -PI * .5
	for side in [-1, 1]:
		var group := _get_wall_group("left" if side < 0 else "right")
		for panel in range(3):
			FURNITURE.place(group, "AcousticBaffles", "TVAcousticPanel_%d" % panel,
				Vector3(side * 9.77, 2.69, -4.32 + panel * 2.08)).rotation.y = -side * PI * .5
		_visual_factory.call("create_light_stand", _interior_root, Vector3(side * 8.41, 0, -6.32), metal_color)
	_workplace_points = [
		Vector3(0.0, 0.0, -0.75),
		Vector3(-2.3, 0.0, -0.8),
		Vector3(2.3, 0.0, -0.8),
		Vector3(-8.0, 0.0, 6.0),
		Vector3(-7.7, 0.0, -0.3),
		Vector3(7.7, 0.0, -0.3),
		Vector3(8.0, 0.0, 5.8),
		Vector3(0.0, 0.0, 5.8),
		Vector3(4.5, 0.0, 5.8),
		Vector3(-8.0, 0.0, -5.4),
	]


func _create_floor(
	footprint: Vector2,
	color: Color,
	node_name: String
) -> void:
	_visual_factory.call(
		"create_floor",
		_interior_root,
		footprint,
		color,
		node_name
	)


func _create_perimeter_walls(
	width: float,
	depth: float,
	wall_height: float,
	wall_color: Color,
	door_width: float,
	door_height: float
) -> void:
	_actor.call(
		"_create_perimeter_walls",
		width,
		depth,
		wall_height,
		wall_color,
		door_width,
		door_height
	)


func _get_wall_group(group_id: String) -> Node3D:
	return _actor.call(
		"get_wall_group_for_visual_builder",
		group_id
	) as Node3D


func _create_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	return _visual_factory.call(
		"create_box",
		parent,
		node_name,
		size,
		color,
		local_position
	) as MeshInstance3D


func _create_label(
	parent: Node3D,
	node_name: String,
	label_text: String,
	local_position: Vector3,
	font_size: int
) -> void:
	_visual_factory.call(
		"create_label",
		parent,
		node_name,
		label_text,
		local_position,
		font_size
	)
