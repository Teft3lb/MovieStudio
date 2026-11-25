extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
const VISUAL_SCRIPT = preload("res://scripts/presentation/characters/character_visual.gd")

const PROFESSIONS: Array[String] = [
	"actor", "camera_operator", "technician", "screenwriter", "film_editor", "producer", "director",
]

var _output: String
var _capture_failed: bool = false


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual capture requires an active rendering device.")
		quit(1)
		return
	var arguments := OS.get_cmdline_user_args()
	_output = arguments[0] if not arguments.is_empty() else "res://.godot/visual-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	var clock := world.get_node("GameClock") as GameClock
	clock.set_speed_mode(GameClock.SpeedMode.PAUSED)
	await _save_frame("studio")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 39.0
	(world.get_node("StudioHUD") as CanvasLayer).hide()
	var manager := world.get_node("StudioBuildingManager") as StudioBuildingManager
	var stage := manager.get_building_actor_by_id(manager.get_preferred_stage_building_id()) as StudioBuildingActor
	var stage_camera := stage.get_node("Interior/CameraRig_1") as Node3D
	var equipment_center := stage_camera.global_position
	equipment_center.y = 1.4
	_aim(camera, equipment_center, Vector3(1.15, 2.5, 3.5))
	await _save_frame("equipment")
	_aim(camera, stage.global_position + Vector3.UP, Vector3(6.8, 11.0, 9.0))
	await _save_frame("stage")
	for tier in [1, 2, 3]:
		var location: Vector3 = [Vector3(32, 0, -28), Vector3(50, 0, -34), Vector3(-36, 0, -29)][tier - 1]
		var data: Variant = manager.call("_create_building", "sound_stage", location, 0.0, "", true, tier)
		var review_stage := manager.get_building_actor_by_id(str(data.id)) as StudioBuildingActor
		review_stage.set_selected(true)
		var camera_scale: float = [0.72, 1.0, 1.53][tier - 1]
		_aim(camera, review_stage.global_position + Vector3.UP * 0.85,
			Vector3(7.4, 16.2, 12.7) * camera_scale)
		await _save_frame("stage-tier-%d" % tier)

	var gallery := Node3D.new()
	world.add_child(gallery)
	var samples: Array[Node3D] = []
	for index in range(PROFESSIONS.size()):
		var visual: Node3D = VISUAL_SCRIPT.new()
		visual.call("setup", {
			"id": "GALLERY-%d" % index,
			"profession_id": PROFESSIONS[index],
			"age": 25 + index * 9,
			"appearance": {
				"skin_tone": index,
				"hair_color": index,
				"hair_style": index,
				"outfit_color": index,
				"silhouette": index % 2,
				"wardrobe_style": 2 if index == 0 else index % 3,
			},
		})
		gallery.add_child(visual)
		visual.position = Vector3((index - 3.0) * 1.15, 0.0, 0.0)
		visual.call("advance_simulation", 0.0)
		samples.append(visual)
	gallery.position = Vector3(-51.0, 0.0, 41.0)
	var target := gallery.position + Vector3.UP * 1.2
	_aim(camera, target, Vector3(0.0, 0.45, -10.0))
	await _save_frame("front")
	_aim(camera, target, Vector3(0.0, 0.6, 10.0))
	await _save_frame("back")
	_aim(camera, samples[0].global_position + Vector3.UP * 1.2, Vector3(-4.0, 0.3, -0.35))
	await _save_frame("side")
	_aim(camera, samples[0].global_position + Vector3.UP * 2.0, Vector3(-0.35, 0.2, -2.0))
	await _save_frame("portrait")

	samples[0].call("set_performance_action", "speaking")
	samples[6].call("set_performance_action", "directing")
	samples[1].call("set_performance_action", "operating_camera")
	samples[2].call("set_carrying_prop", true)
	samples[2].call("set_walking", true)
	samples[3].call("set_performance_action", "eating")
	samples[4].call("set_performance_action", "sleeping")
	for visual in samples:
		for step in range(20):
			visual.call("advance_simulation", 0.025)
	_aim(camera, target, Vector3(-0.5, 3.7, -10.0))
	await _save_frame("actions")

	for row in range(1, 7):
		for index in range(PROFESSIONS.size()):
			var visual: Node3D = VISUAL_SCRIPT.new()
			visual.call("setup", {"id": "BENCH-%d-%d" % [row, index], "profession_id": PROFESSIONS[index]})
			gallery.add_child(visual)
			visual.position = Vector3((index - 2.5) * 1.15, 0.0, row * 1.15)
			visual.call("set_walking", true)
			samples.append(visual)
	gallery.position = Vector3(-7.0, 0.0, 10.0)
	_aim(camera, Vector3(-1.0, 0.0, 0.0), Vector3(18.0, 35.0, 31.0))
	await _save_frame("benchmark")
	var scene_mark := stage.get_scene_mark(0, "rehearsal", 0)
	var scene_actor := _add_preview_actor(world, clock, scene_mark)
	scene_actor.start_scene_performance(
		scene_mark, stage.get_scene_focus_point(), "speaking", "", [], true
	)
	scene_actor.snap_to_scene_mark()
	if scene_actor.has_method("set_scene_costume"):
		scene_actor.call("set_scene_costume", "western_costumes")
	scene_actor.call("_advance_visual", 0.25)
	stage.set_camera_target(scene_mark + Vector3.UP * 1.4, true)
	_aim(camera, stage.global_position + Vector3.UP, Vector3(6.8, 11.0, 9.0))
	await _save_frame("rehearsal")
	await _capture_facility(world, manager, clock, camera, "cafeteria", "eating", Vector3(41, 0, 3))
	await _capture_facility(world, manager, clock, camera, "staff_housing", "sleeping", Vector3(41, 0, 20))
	gallery.free()
	(world.get_node("StudioHUD") as CanvasLayer).show()
	_aim(camera, Vector3(5, 0, 2), Vector3(31, 42, 52))
	await _save_frame("studio-overview")
	quit(1 if _capture_failed else 0)


func _add_preview_actor(world: Node, clock: GameClock, mark: Vector3) -> CharacterActor:
	var data := CharacterData.new()
	data.id = "VISUAL-" + str(mark)
	data.first_name = "Avery"
	data.profession_id = "actor"
	var actor := CharacterActor.new()
	var route: Array[Vector3] = [mark]
	actor.setup(data, route, clock)
	world.add_child(actor)
	return actor


func _capture_facility(
	world: Node, manager: StudioBuildingManager, clock: GameClock, camera: Camera3D,
	facility_type: String, action: String, location: Vector3
) -> void:
	var data: Variant = manager.call("_create_building", facility_type, location, 0.0)
	var building := manager.get_building_actor_by_id(str(data.id)) as StudioBuildingActor
	building.set_selected(true)
	var mark := building.get_workplace_position(3)
	var preview := _add_preview_actor(world, clock, mark)
	var route: Array[Vector3] = [mark]
	preview.assign_facility_route(
		str(data.id), facility_type, 3, route, action, building.get_workplace_facing_direction(3)
	)
	preview.call("_advance_visual", 0.25)
	(preview.get_node("NameTag") as Label3D).hide()
	_aim(camera, mark + Vector3.UP * 0.60, Vector3(2.55, 3.6, 2.15))
	await _save_frame(action)
	_aim(camera, building.global_position + Vector3.UP * 0.65, Vector3(5.6, 14, 11))
	await _save_frame(facility_type)


func _aim(camera: Camera3D, target: Vector3, offset: Vector3) -> void:
	camera.position = target + offset
	camera.look_at(target)


func _save_frame(label: String) -> void:
	for frame in range(3):
		await RenderingServer.frame_post_draw
	var path := _output.path_join(label + ".png")
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		_capture_failed = true
		push_error("Could not save %s (%s)" % [path, error_string(result)])
