extends "res://tests/smoke_test_base.gd"


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_expect(
		main_scene != null,
		"The project main scene must be available for the startup integration test."
	)
	if main_scene == null:
		_finish_test("StudioWorldBootstrapSmokeTest")
		return

	var game_root: Node = main_scene.instantiate()
	root.add_child(game_root)
	await process_frame

	var building_manager: Node = game_root.get_node_or_null("StudioBuildingManager")
	var studio_hud: Node = game_root.get_node_or_null("StudioHUD")
	_expect(
		is_instance_valid(building_manager) and is_instance_valid(studio_hud),
		"The main scene must contain the building manager and studio HUD."
	)
	if not is_instance_valid(building_manager) or not is_instance_valid(studio_hud):
		game_root.queue_free()
		await process_frame
		_finish_test("StudioWorldBootstrapSmokeTest")
		return

	var buildings: Array = building_manager.call("get_buildings")
	_expect(
		buildings.size() >= 3,
		"The startup flow must create the script department, sound stage and prop warehouse."
	)
	var building_types: Array[String] = []
	for building in buildings:
		building_types.append(str(building.building_type_id))
	_expect(
		building_types.has("script_department")
		and building_types.has("sound_stage")
		and building_types.has("prop_warehouse"),
		"All three original starter buildings must be present in the world model."
	)

	var building_actors: Array[Node] = game_root.get_tree().get_nodes_in_group(
		"studio_building"
	)
	_expect(
		building_actors.size() >= 3,
		"All starter building records must have visible world actors."
	)

	var workspace_ids: Array[String] = studio_hud.call(
		"get_registered_workspace_ids"
	)
	_expect(
		workspace_ids.has("studio") and workspace_ids.has("decor_shop"),
		"The construction and prop-shop workspaces must be registered during startup."
	)
	_expect(
		workspace_ids.has("employees") and workspace_ids.has("market"),
		"The employee roster and employee market workspaces must remain registered."
	)
	_expect(
		not bool(studio_hud.call("is_workspace_drawer_open")),
		"The workspace drawer must start closed so the 3D world remains unobstructed."
	)
	_expect(
		bool(building_manager.call("is_startup_content_ready")),
		"The building manager must report a complete world and UI bootstrap."
	)
	var courtyard := game_root.get_node("Backlot/CrewCourtyard") as Node3D
	_expect(courtyard.visible, "The unoccupied backlot courtyard should be visible.")
	building_manager.call("_create_building", "script_department", Vector3(-7, 0, 11.6), 90.0)
	_expect(not courtyard.visible, "A placed building should take precedence over decorative yards.")

	game_root.queue_free()
	await process_frame
	_finish_test("StudioWorldBootstrapSmokeTest")
