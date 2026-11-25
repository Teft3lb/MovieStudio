extends SceneTree

const WORLD = preload("res://scenes/main.tscn")
const ROOMS := [
	["cafeteria", 2, Vector2(0, .02), Vector2(.09, -.68)],
	["studio_lounge", 2, Vector2(.48, .10), Vector2(0, -.62)],
	["staff_housing", 2, Vector2(.66, 0), Vector2(0, -.67)],
	["star_bungalow", 2, Vector2(0, -.28), Vector2(.55, .36)],
	["script_department", 2, Vector2(-.27, -.36), Vector2(.36, .28)],
	["editing_suite", 2, Vector2(0, -.33), Vector2(.66, .56)],
	["costume_wardrobe", 2, Vector2(-.44, -.13), Vector2(.37, -.66)],
	["prop_warehouse", 2, Vector2(.57, -.08), Vector2(-.11, -.69)],
	["film_promotion", 2, Vector2(-.35, -.49), Vector2(0, .30)],
	["sound_stage", 1, Vector2(-.45, .45), Vector2(.63, -.13)],
	["sound_stage", 2, Vector2(-.52, .54), Vector2(.72, .32)],
	["sound_stage", 3, Vector2(-.61, .63), Vector2(.70, .22)],
	["tv_studio", 2, Vector2(0, -.46), Vector2(-.52, .68)],
	["prop_exchange", 2, Vector2(-.36, .23), Vector2(0, -.63)],
	["fitness_center", 2, Vector2(0, -.42), Vector2(-.62, .39)],
]

var _output: String
var _failed: bool = false


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Interior review requires an active renderer.")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	_output = args[0] if not args.is_empty() else "res://.godot/interior-review"
	var folder_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	if folder_error != OK:
		push_error("Cannot create review directory: %s" % error_string(folder_error))
		quit(1)
		return
	var world := WORLD.instantiate()
	root.add_child(world)
	(world.get_node("GameClock") as GameClock).set_speed_mode(GameClock.SpeedMode.PAUSED)
	world.get_node("StudioHUD").hide()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	camera.make_current()
	var occupant := Node3D.new()
	occupant.add_to_group("studio_employee")
	world.add_child(occupant)
	for room in ROOMS:
		await _capture_room(world, camera, occupant, room[0], room[1], room[2], room[3])
	quit(1 if _failed else 0)


func _capture_room(
	world: Node, camera: Camera3D, occupant: Node3D, type: String, tier: int,
	primary: Vector2, support: Vector2
) -> void:
	var definition := StudioBuildingData.new()
	definition.id = "INTERIOR-REVIEW"
	definition.building_type_id = type
	definition.stage_size_tier = tier
	definition.position = Vector3(39, 0, 34)
	var room := StudioBuildingActor.new()
	room.setup(definition)
	world.add_child(room)
	if type == "costume_wardrobe":
		room.set_wardrobe_inventory(["western_costumes", "classic_period_costumes", "science_fiction_costumes"])
	elif type == "prop_warehouse":
		room.set_warehouse_inventory(["lighthouse_console", "harbor_crates", "captain_desk", "studio_chair"])
	occupant.global_position = definition.position
	room.get("_interior_lighting").call("set_occupied", true)
	var footprint := StudioBuildingCatalog.get_footprint(type, 0, tier)
	var label := "%s-%d" % [type, tier] if type == "sound_stage" else type
	var center := definition.position + Vector3.UP
	_aim(camera, center, Vector3(.26, 1.15, .78), maxf(footprint.y, footprint.x * .67) * 1.22)
	room.set_selected(true)
	await _save_frame(label + "-overview")
	_aim(camera, center + Vector3(primary.x * footprint.x, 0, primary.y * footprint.y) * .5,
		Vector3(-.34 if primary.x > .1 else .34, .77, .77), maxf(4.0, footprint.y * .53))
	await _save_frame(label + "-primary")
	_aim(camera, center + Vector3(support.x * footprint.x, 0, support.y * footprint.y) * .5,
		Vector3(-.32 if support.x > -.1 else .32, .82, .81), maxf(4.0, footprint.y * .53))
	await _save_frame(label + "-support")
	room.free()


func _aim(camera: Camera3D, target: Vector3, direction: Vector3, view_height: float) -> void:
	camera.size = view_height
	camera.global_position = target + direction * 24.0
	camera.look_at(target)


func _save_frame(label: String) -> void:
	for frame in range(3):
		await RenderingServer.frame_post_draw
	var path := _output.path_join(label + ".png")
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		_failed = true
		push_error("Could not save %s (%s)" % [path, error_string(result)])
