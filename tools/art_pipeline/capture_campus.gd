extends SceneTree

const WORLD = preload("res://scenes/main.tscn")
const BUILDINGS := [
	["cafeteria", Vector3(-18, 0, 3), 2],
	["studio_lounge", Vector3(-17, 0, 21), 2],
	["editing_suite", Vector3(23, 0, 24), 2],
	["tv_studio", Vector3(28, 0, -11), 2],
	["sound_stage", Vector3(-33, 0, -13), 1],
	["sound_stage", Vector3(-2, 0, -26), 3],
]

var _output: String
var _failed := false


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	_output = args[0] if not args.is_empty() else "res://.godot/studio-campus"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output)) != OK:
		quit(1)
		return
	var world := WORLD.instantiate()
	root.add_child(world)
	(world.get_node("GameClock") as GameClock).set_speed_mode(GameClock.SpeedMode.PAUSED)
	var manager := world.get_node("StudioBuildingManager") as StudioBuildingManager
	for entry in BUILDINGS:
		manager.call("_create_building", entry[0], entry[1], 0.0, "", true, entry[2])
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	camera.make_current()
	await _shot(camera, "campus", Vector3(2, 1.5, -2), Vector3(38, 57, 62), 61.0)
	world.get_node("StudioHUD").hide()
	await _shot(camera, "street", Vector3(3, 1.4, -8), Vector3(16, 35, 47), 34.5)
	await _shot(camera, "creative-block", Vector3(-14, 1.8, -9), Vector3(16, 28, 42), 25.0)
	await _shot(camera, "broadcast-block", Vector3(26, 2, -3), Vector3(31, 31, 42), 31.0)
	await _shot(camera, "gate", Vector3(10, 1.4, -61), Vector3(16, 27, -37), 24.0)
	await _shot(camera, "crew-yard", Vector3(-4.4, 0.75, 11.6), Vector3(13, 21, 29), 12.0)
	await _shot(camera, "service-yard", Vector3(19, 0.75, -31.4), Vector3(17, 28, 28), 16.0)
	quit(1 if _failed else 0)


func _shot(camera: Camera3D, label: String, target: Vector3, offset: Vector3, size: float) -> void:
	camera.size = size
	camera.position = target + offset
	camera.look_at(target)
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(_output.path_join(label + ".png"))
	if result != OK:
		_failed = true
		push_error("Could not save %s: %s" % [label, error_string(result)])
