extends SceneTree

const WORLD = preload("res://scenes/main.tscn")
const CASES := {
	"empty": [0, 0], "staff10": [10, 3], "staff42": [42, 3],
	"staff100": [100, 3], "staff200": [200, 3], "large": [100, 21],
	"working": [100, 21], "filming": [42, 3],
}
const PROFESSIONS := ["screenwriter", "film_editor", "actor", "director", "camera_operator", "technician"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("navigation"):
		_navigation_probe()
		quit()
		return
	if DisplayServer.get_name() == "headless":
		push_error("The studio benchmark requires a rendering device.")
		quit(1)
		return
	var options := {"shadows": not args.has("no-shadows"), "hud": not args.has("no-hud")}
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	for id in CASES:
		if args.size() > 0 and not args.has(id) and not args.has("all"):
			continue
		var world := _create_case(id, options)
		await _sample(id, world, viewport_rid)
		world.free()
		await process_frame
	RenderingServer.viewport_set_measure_render_time(viewport_rid, false)
	quit()


func _create_case(id: String, options: Dictionary) -> Node3D:
	var world := WORLD.instantiate() as Node3D
	root.add_child(world)
	world.get_node("DirectionalLight3D").shadow_enabled = bool(options.shadows)
	world.get_node("StudioHUD").visible = bool(options.hud)
	var buildings := world.get_node("StudioBuildingManager") as StudioBuildingManager
	var characters := world.get_node("CharacterManager") as CharacterManager
	var clock := world.get_node("GameClock") as GameClock
	var camera := world.get_node("Camera3D") as OrbitCameraController
	camera.orbit_distance = 44.0 if id in ["large", "working"] else 26.0
	if id == "working":
		clock.current_hour = 10
		camera.focus_point = Vector3(-8, 0, 30)
	if id == "empty":
		for node in [buildings, characters]:
			node.free()
		world.get_node("StudioHUD").hide()
		return world
	for index in range(int(CASES[id][1]) - 3):
		var building_type: String = "script_department" if index % 2 == 0 else "editing_suite"
		buildings.call("_create_building", building_type,
			Vector3(-52.0 + float(index % 6) * 18.0, 0, 24.0 + float(index / 6) * 18.0), 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 273712
	var generator := CharacterGenerator.new()
	for index in range(characters.employees.size(), int(CASES[id][0])):
		var profession: String = PROFESSIONS[index % PROFESSIONS.size()]
		if id == "working":
			profession = "screenwriter" if index % 2 == 0 else "film_editor"
		var employee: Variant = generator.generate(rng, "BENCH-%04d" % index, profession, true)
		characters.employees.append(employee)
		characters.call("_spawn_employee_actor", employee, index)
	characters.call("_refresh_workplace_assignments")
	if id == "working":
		if bool(options.hud):
			world.get_node("StudioHUD").call("show_workspace_panel", "employees")
		for employee in characters.employees:
			_place_at_station(buildings, characters, str(employee.id), str(employee.profession_id))
	elif id == "filming":
		_start_take(buildings, characters, clock)
	return world


func _start_take(buildings: StudioBuildingManager, characters: CharacterManager, clock: GameClock) -> void:
	var stage := buildings.get_building_actor_by_id(buildings.get_preferred_stage_building_id()) as StudioBuildingActor
	var employee_ids: Dictionary = {}
	for employee in characters.employees:
		if characters.is_employee_assigned_to_building(str(employee.id), "sound_stage"):
			employee_ids.get_or_add(str(employee.profession_id), str(employee.id))
	var screen := FilmScriptData.new()
	screen.id = "BENCH-SCRIPT"
	screen.title = "Benchmark"
	screen.scene_count = 1
	screen.cast = [{"role_id": "ROLE-01", "character_name": "Avery"}]
	screen.scenes = [{"title": "On set", "characters": ["Avery"], "dialogue": "Avery: Ready."}]
	var project := FilmProductionProject.new()
	project.id = "BENCH-TAKE"
	project.script_id = screen.id
	project.total_scene_count = 1
	project.current_phase = "shooting"
	project.phase_duration_minutes = 120
	project.estimated_total_minutes = 120
	for role in ["director", "camera_operator", "technician"]:
		project.crew_assignments[role] = employee_ids.get(role, "")
	project.cast_assignments["ROLE-01"] = employee_ids.get("actor", "")
	buildings.set("_active_film_script", screen)
	buildings.set("_active_film_project", project)
	for role in ["director", "camera_operator", "technician", "actor"]:
		var employee_id: String = employee_ids.get(role, "")
		if not employee_id.is_empty():
			_place_at_station(buildings, characters, employee_id, role)
	buildings.call("_sync_film_scene_performance")
	var actor := characters.get_employee_actor(str(project.cast_assignments["ROLE-01"])) as CharacterActor
	if actor != null:
		actor.snap_to_scene_mark()
	stage.set_camera_target(stage.get_scene_mark(0, "shooting", 0) + Vector3.UP, true)
	clock.current_hour = 10


func _place_at_station(
	buildings: StudioBuildingManager, characters: CharacterManager, employee_id: String, profession: String
) -> void:
	var assignment := characters.get_employee_workplace_assignment(employee_id)
	if assignment.is_empty():
		return
	var id: String = str(assignment.building_id)
	var index: int = int(assignment.slot_index)
	var path := buildings.get_workplace_path(id, index)
	var actor := characters.get_employee_actor(employee_id) as CharacterActor
	if actor != null and not path.is_empty():
		actor.assign_workplace_route(id, path, profession, path, index)
		actor.snap_to_workplace()


func _sample(id: String, world: Node, viewport_rid: RID) -> void:
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var process_peak: float = 0.0
	var physics_peak: float = 0.0
	var frames_over_budget: int = 0
	var slowest: float = 0.0
	var warm_until := Time.get_ticks_usec() + 1_000_000
	while Time.get_ticks_usec() < warm_until:
		await process_frame
	var start := Time.get_ticks_usec()
	var previous := start
	while frames.size() < 180 or previous - start < 2_500_000:
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := (now - previous) / 1000.0
		frames.append(frame_ms)
		if frame_ms > 1000.0 / 60.0:
			frames_over_budget += 1
		slowest = maxf(slowest, frame_ms)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		process_peak = maxf(process_peak, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_peak = maxf(physics_peak, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var result := {
		"case": id, "frames": frames.size(), "frame_p50_ms": _percentile(frames, 0.5),
		"frame_p95_ms": _percentile(frames, 0.95), "frame_p99_ms": _percentile(frames, 0.99),
		"frame_max_ms": slowest, "frames_over_16_67_ms": frames_over_budget,
		"render_cpu_p50_ms": _percentile(cpu, 0.5),
		"render_gpu_p50_ms": _percentile(gpu, 0.5), "process_peak_ms": process_peak,
		"physics_peak_ms": physics_peak, "nodes": get_node_count(),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"minute": world.get_node("GameClock").current_minute,
	}
	if id == "filming":
		var project: Variant = world.get_node("StudioBuildingManager").get_active_film_project()
		result["take_phase"] = project.current_phase
		result["take_minutes"] = project.total_elapsed_minutes
		result["take_status"] = project.last_activity_message
	if id == "working":
		var working: int = 0
		for actor in get_nodes_in_group("studio_employee"):
			if actor.is_at_workplace():
				working += 1
		result["at_workplace"] = working
	print("STUDIO_BENCH ", JSON.stringify(result))


func _percentile(values: Array[float], rank: float) -> float:
	values.sort()
	return snappedf(values[ceili(float(values.size() - 1) * rank)], 0.001)


func _navigation_probe() -> void:
	var nav := StudioNavigationSystem.new()
	var obstacles: Array[Dictionary] = []
	for index in 18:
		obstacles.append({
			"center": Vector2(-16.0 + (index % 6) * 7.0, -8.0 + (index / 6) * 8.0),
			"half_extents": Vector2(2.1, 2.4),
		})
	var bounds := Rect2(-28, -23, 56, 46)
	var start := Vector3(-25, 0, -7)
	var target := Vector3(25, 0, 8)
	var cold_start := Time.get_ticks_usec()
	var expected := nav.build_path(start, target, obstacles, 0.75, bounds)
	var cold_ms := (Time.get_ticks_usec() - cold_start) / 1000.0
	var start_us := Time.get_ticks_usec()
	var matches: int = 0
	for index in 50:
		if nav.build_path(start, target, obstacles, 0.75, bounds) == expected:
			matches += 1
	print("STUDIO_NAV ", JSON.stringify({
		"cold_ms": cold_ms, "repeat_total_ms": (Time.get_ticks_usec() - start_us) / 1000.0,
		"matches": matches, "route_points": expected.size(),
	}))
