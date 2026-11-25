extends SceneTree

const WORLD = preload("res://scenes/main.tscn")

var _output: String
var _failed: bool = false


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	_output = args[0] if not args.is_empty() else "res://.godot/living-review/after"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var world := WORLD.instantiate() as Node3D
	root.add_child(world)
	var clock := world.get_node("GameClock") as GameClock
	clock.set_speed_mode(GameClock.SpeedMode.PAUSED)
	world.get_node("StudioHUD").hide()
	var buildings := world.get_node("StudioBuildingManager") as StudioBuildingManager
	var edit: Variant = buildings.call("_create_building", "editing_suite", Vector3(41, 0, 14), 0.0)
	var writer_id: String
	for building in buildings.get_buildings():
		if str(building.building_type_id) == "script_department":
			writer_id = str(building.id)
	var camera := Camera3D.new()
	camera.fov = 47.0
	world.add_child(camera)
	camera.make_current()
	await _capture_station(world, clock, buildings.get_building_actor_by_id(writer_id), camera, "screenwriter")
	await _capture_station(world, clock, buildings.get_building_actor_by_id(str(edit.id)), camera, "film_editor")
	await _capture_lounge(world, clock, buildings, camera)
	quit(1 if _failed else 0)


func _capture_station(
	world: Node3D, clock: GameClock, building_node: Node3D, camera: Camera3D, profession: String
) -> void:
	var building := building_node as StudioBuildingActor
	building.set_selected(true)
	var target := building.global_position + Vector3.UP * 0.54
	camera.global_position = target + building.global_basis * Vector3(3.3, 8.8, 8)
	camera.look_at(target)
	await _save_frame(profession + "-department")
	var slot: int = 1
	var route := building.get_workplace_path(slot)
	var seat: Vector3 = route.back()
	var angle := Vector3(1.65, 2.45, 2.9)
	camera.global_position = seat + building.global_basis * angle
	camera.look_at(seat + Vector3.UP * 0.82 + building.global_basis * Vector3.FORWARD * 0.42)
	await _save_frame(profession + "-furniture")
	var data := CharacterData.new()
	data.id = "PREVIEW-" + profession
	data.first_name = "Avery"
	data.profession_id = profession
	if profession == "film_editor":
		data.appearance.merge({"hair_style": 5, "skin_tone": 2, "outfit_color": 2, "wardrobe_style": 1}, true)
	var actor := CharacterActor.new()
	var inbound: Array[Vector3] = [route[route.size() - 2], seat]
	actor.setup(data, inbound, clock, 1.3)
	world.add_child(actor)
	actor.assign_workplace_route(building.get_building_id(), inbound, profession, route, slot)
	actor.get_node("NameTag").hide()
	await _save_frame(profession + "-approach")
	actor.snap_to_workplace()
	actor.call("_advance_visual", 0.10)
	await _save_frame(profession + "-enter")
	for sample in 12:
		actor.call("_advance_visual", 1.0 / 30.0)
	await _save_frame(profession + "-interact")
	await _save_frame(profession + "-interact-side", camera, seat, building.global_basis)
	actor.leave_workplace()
	actor.call("_advance_visual", 0.12)
	await _save_frame(profession + "-exit")
	for sample in 14:
		actor.call("_process_workplace_movement", 1.0 / 30.0)
	await _save_frame(profession + "-release")
	actor.free()
	building.set_selected(false)


func _capture_lounge(world: Node3D, clock: GameClock, manager: StudioBuildingManager, camera: Camera3D) -> void:
	var data: Variant = manager.call("_create_building", "studio_lounge", Vector3(39, 0, -15), 0.0)
	var lounge := manager.get_building_actor_by_id(str(data.id)) as StudioBuildingActor
	lounge.set_selected(true)
	var pair: Dictionary = {}
	var records: Array = []
	for index in 2:
		var employee := CharacterData.new()
		employee.id = "LOUNGE-%d" % index
		employee.profession_id = "actor" if index == 0 else "director"
		employee.personality["sociability"] = 0.8
		var slot := index + 1
		var path: Array[Vector3] = [lounge.get_workplace_position(slot)]
		var actor := CharacterActor.new()
		actor.setup(employee, path, clock)
		world.add_child(actor)
		actor.assign_facility_route(str(data.id), "studio_lounge", slot, path, "socializing",
			lounge.get_workplace_facing_direction(slot))
		actor.get_node("NameTag").hide()
		pair[employee.id] = actor
		records.append(employee)
	var script_path := "res://scripts/presentation/characters/studio_lounge_conversations.gd"
	if ResourceLoader.exists(script_path):
		var conversations: RefCounted = load(script_path).new()
		conversations.call("update", {str(data.id): records}, pair, 0)
	for actor in pair.values():
		actor.call("_process_facility_movement", 0.27)
	var target := lounge.global_position + Vector3.UP * 1.15
	camera.global_position = target + Vector3(2.5, 4.5, 6.5)
	camera.look_at(target)
	await _save_frame("lounge")
	camera.global_position = target + Vector3(4.8, 13, 11)
	camera.look_at(target)
	await _save_frame("lounge-overview")


func _save_frame(
	label: String, camera: Camera3D = null, seat: Vector3 = Vector3.ZERO, basis: Basis = Basis.IDENTITY
) -> void:
	var original := Transform3D.IDENTITY
	if camera != null:
		original = camera.global_transform
		camera.global_position = seat + basis * Vector3(2.02, 1.22, 0.23)
		camera.look_at(seat + Vector3.UP * 0.88 + basis * Vector3.FORWARD * 0.28)
	for frame in 4:
		await RenderingServer.frame_post_draw
	var path := _output.path_join(label + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		_failed = true
		push_error("Could not save " + path)
	if camera != null:
		camera.global_transform = original
