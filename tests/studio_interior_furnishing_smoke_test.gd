extends "res://tests/smoke_test_base.gd"

const ROOMS := [
	["cafeteria", 2, "KitchenWashStation"],
	["studio_lounge", 2, "LoungeRefreshmentStorage"],
	["staff_housing", 2, "BedPrivacy_-1_0"],
	["star_bungalow", 2, "BungalowReadingTable"],
	["script_department", 2, "ScriptCoffeeStation"],
	["editing_suite", 2, "EditingReviewSeat"],
	["costume_wardrobe", 2, "WardrobeTailorStation"],
	["prop_warehouse", 2, "WarehouseSortingBench"],
	["film_promotion", 2, "CampaignPlotter"],
	["sound_stage", 1, "SmallStagePrepBench"],
	["sound_stage", 2, "StagePrepBench"],
	["sound_stage", 3, "HighBayPrepBench"],
	["tv_studio", 2, "TVEngineeringDesk"],
	["prop_exchange", 2, "ExchangeRegister"],
	["fitness_center", 2, "FitnessFreeWeights"],
]


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	for entry in ROOMS:
		var data := StudioBuildingData.new()
		data.id = "FURNISHING-TEST"
		data.building_type_id = entry[0]
		data.stage_size_tier = entry[1]
		data.position = Vector3(9, 0, -12)
		data.rotation_degrees = 90
		var room := StudioBuildingActor.new()
		room.setup(data)
		root.add_child(room)
		var fixture := room.get_node_or_null("Interior/" + str(entry[2])) as MeshInstance3D
		_expect(fixture != null and fixture.mesh != null, "Room is missing fixture %s." % entry[2])
		var front := room.get_wall_group_for_visual_builder("front")
		var facade := front.get_node_or_null("EntranceMasonry") as MeshInstance3D
		_expect(facade != null and facade.mesh.get_surface_count() >= 2,
			"The entrance architecture must be attached to its cutaway wall.")
		if data.building_type_id == "cafeteria":
			var first := room.get_node("Interior/CafeteriaTable_0") as MeshInstance3D
			var second := room.get_node("Interior/CafeteriaTable_1") as MeshInstance3D
			_expect(first.mesh == second.mesh, "Repeated tables must share one mesh resource.")
		if data.building_type_id == "costume_wardrobe":
			room.set_wardrobe_inventory(["western_costumes"])
			var garment := room.get_node("Interior/WardrobeInventory/StoredCostume_western_costumes") as Node3D
			var rail := room.get_node("Interior/WardrobeRackBar_-1") as Node3D
			var hook := garment.get_node("CostumeHangerHook") as Node3D
			var hook_top := hook.global_position + Vector3.UP * .06
			_expect(is_equal_approx(garment.position.x, rail.position.x)
				and absf(hook_top.y - rail.global_position.y) < .04, "The gameplay costume must hang on its visible rail.")
		var obstacles := _fixture_footprints(room.get_node("Interior"))
		var count := maxi(
			StudioBuildingCatalog.get_workplace_capacity_for_building(data),
			StudioBuildingCatalog.get_facility_capacity(data.building_type_id)
		)
		if data.building_type_id == "prop_warehouse":
			count = 8
		for slot in count:
			var route := room.get_workplace_path(slot)
			_expect(route.size() >= 4, "%s must retain route %d." % [data.building_type_id, slot])
			_expect(_is_clear(room, route, obstacles),
				"%s route %d crosses a new piece of furniture." % [data.building_type_id, slot])
			if not route.is_empty():
				var exit_route := room.get_exit_path_from(route.back(), slot)
				_expect(exit_route.size() >= 2 and _is_clear(room, exit_route, obstacles),
					"%s exit %d must remain clear of new furniture." % [data.building_type_id, slot])
		room.free()
	_finish_test("StudioInteriorFurnishingSmokeTest")


func _fixture_footprints(interior: Node) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for child in interior.get_children():
		var fixture := child as MeshInstance3D
		if fixture == null or not fixture.has_meta("blocks_passage"):
			continue
		var bounds: AABB = fixture.transform * fixture.get_aabb()
		result.append(Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)))
	return result


func _is_clear(room: Node3D, route: Array[Vector3], obstacles: Array[Rect2]) -> bool:
	for index in range(1, route.size()):
		var start := room.to_local(route[index - 1])
		var end := room.to_local(route[index])
		var steps := maxi(ceili(start.distance_to(end) * 12.0), 1)
		for step in range(steps + 1):
			var sample := start.lerp(end, float(step) / steps)
			for bounds in obstacles:
				if bounds.has_point(Vector2(sample.x, sample.z)):
					return false
	return true
