extends Node3D

const PALETTE = preload("res://scripts/presentation/studio/studio_surface_palette.gd")
const RULES = preload("res://scripts/domain/studio/studio_building_placement_rules.gd")
const FURNITURE = preload("res://scripts/presentation/studio/studio_office_furniture.gd")

var _sites: Array[Node3D] = []


func _ready() -> void:
	var pavers: Array[Transform3D] = []
	var markings: Array[Transform3D] = []
	var lamp_posts: Array[Transform3D] = []
	var fittings: Array[Transform3D] = []
	var light_faces: Array[Transform3D] = []
	var planters: Array[Transform3D] = []
	var shrubs: Array[Transform3D] = []
	var fence: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for side in [-1, 1]:
		var edge: float = 10.0 + side * 2.39
		pavers.append(_piece(Vector3(edge - side * .40, .042, 0), Vector3(.12, .105, 137.8)))
		for tile in range(69):
			pavers.append(_piece(Vector3(edge, .035, tile * 2.0 - 68.0), Vector3(.77, .07, 1.94)))
		for pole in range(11):
			var z: float = -65.0 + pole * 13.0 + side * 1.20
			var x: float = 10.0 + side * 2.77
			lamp_posts.append(_piece(Vector3(x, 1.35, z), Vector3(.095, 2.70, .095)))
			fittings.append(_piece(Vector3(x - side * .14, 2.71, z), Vector3(.42, .12, .22)))
			light_faces.append(_piece(Vector3(x - side * .16, 2.64, z), Vector3(.33, .028, .16)))
			if pole % 3 == 1:
				fittings.append(_piece(Vector3(x, .36, z + 2.15), Vector3(.33, .70, .35)))
			if pole % 2 == 0:
				planters.append(_piece(Vector3(x, .15, z + 4.3), Vector3(.43, .30, 1.12)))
				for index in range(3):
					shrubs.append(_piece(Vector3(x, .39, z + 3.94 + index * .35), Vector3(.39, .33, .40)))
		for tree_z in [-44.0, -20.0, 2.4, 25.9, 48.0]:
			var x: float = 10.0 + side * 2.53
			trunks.append(_piece(Vector3(x, 1.26, tree_z), Vector3(.21, 2.52, .21)))
			crowns.append(_piece(Vector3(x, 2.92, tree_z), Vector3(.76, 2.58, .92)))
			crowns.append(_piece(Vector3(x, 3.52, tree_z - .12), Vector3(.62, 1.65, .75)))
		for index in range(32):
			var axis := -83.7 + index * 5.40
			var x: float = side * 86.0
			fence.append(_piece(Vector3(x, .66, axis), Vector3(.09, 1.32, .12)))
			fence.append(_piece(Vector3(x, .93, axis), Vector3(.07, .08, 5.40)))
			fence.append(_piece(Vector3(x, .47, axis), Vector3(.07, .06, 5.40)))
	for dash in range(33):
		markings.append(_piece(Vector3(10, .065, -66.0 + dash * 4.0), Vector3(.085, .012, 1.72)))
	for crossing_z in [-8.1, 7.9, 16.1]:
		for stripe in range(7):
			markings.append(_piece(Vector3(8.45 + stripe * .51, .071, crossing_z), Vector3(.28, .012, 1.08)))
	pavers.append(_piece(Vector3(-3.7, .039, -8.1), Vector3(22.2, .065, 1.48)))
	pavers.append(_piece(Vector3(-16, .04, -9.58), Vector3(1.48, .069, 3.54)))
	pavers.append(_piece(Vector3(3.8, .037, 7.9), Vector3(7.0, .068, 1.65)))
	pavers.append(_piece(Vector3(16.3, .039, 16.1), Vector3(7.34, .067, 1.48)))
	pavers.append(_piece(Vector3(20, .038, 15.05), Vector3(1.62, .067, 2.82)))
	for index in range(13):
		var x := -80.0 + index * 13.1
		for side in [-1, 1]:
			_tree(Vector3(x, 0, side * 86.1), index, trunks, crowns)
	for side in [-1, 1]:
		for index in range(10):
			_tree(Vector3(side * 87.1, 0, -72 + index * 15.5), index + 2, trunks, crowns)
		fittings.append(_piece(Vector3(10 + side * 2.70, 1.50, -69.0), Vector3(.34, 3.0, .48)))
	fittings.append(_piece(Vector3(10, 3.13, -69.0), Vector3(5.76, .31, .43)))
	for bay in range(5):
		var z := -22.0 - bay * 2.20
		markings.append(_piece(Vector3(8.39, .067, z), Vector3(.68, .015, .084)))
		markings.append(_piece(Vector3(11.59, .067, z + 1.13), Vector3(.68, .015, .084)))
	fittings.append(_piece(Vector3(12.72, 1.02, -16.5), Vector3(.13, 2.04, .13)))
	light_faces.append(_piece(Vector3(12.77, 1.96, -16.5), Vector3(.37, .31, .083)))

	var cube := BoxMesh.new()
	var stem := CylinderMesh.new()
	stem.top_radius = .38
	stem.bottom_radius = .5
	stem.height = 1.0
	stem.radial_segments = 8
	var foliage := SphereMesh.new()
	foliage.radius = .5
	foliage.height = 1.0
	foliage.radial_segments = 10
	foliage.rings = 5
	_batch("Pavements", cube, pavers, PALETTE.finish(Color("#958e7c"), "concrete"), false)
	_batch("RoadPaint", cube, markings, PALETTE.finish(Color("#cbba90")), false)
	_batch("StreetPosts", stem, lamp_posts, PALETTE.finish(Color("#333c3b"), "metal"))
	_batch("StreetFixtures", cube, fittings, PALETTE.finish(Color("#465250"), "metal"))
	_batch("OpalStreetlights", cube, light_faces, PALETTE.finish(Color("#ead7a1")), false)
	_batch("PlantingBeds", cube, planters, PALETTE.finish(Color("#746653"), "concrete"))
	_batch("RoadsideShrubs", foliage, shrubs, PALETTE.finish(Color("#556f45")))
	_batch("BacklotFence", cube, fence, PALETTE.finish(Color("#5d6960"), "metal"), false)
	_batch_by_area("TreeTrunks", stem, trunks, PALETTE.finish(Color("#6a5540")))
	var crown_material := StandardMaterial3D.new()
	crown_material.vertex_color_use_as_albedo = true
	crown_material.roughness = .89
	_batch_by_area("TreeCanopies", foliage, crowns, crown_material, [
		Color("#4d693e"), Color("#65814a"), Color("#788e50"), Color("#4e6b4a"),
	])

	var signboard := Label3D.new()
	signboard.text = "КИНОСТУДИЯ"
	signboard.position = Vector3(10, 3.13, -69.23)
	signboard.rotation.y = PI
	signboard.pixel_size = .009
	signboard.font_size = 35
	signboard.outline_size = 2
	signboard.modulate = Color("#f3ddae")
	add_child(signboard)
	_build_yards(cube, foliage)
	_build_creative_walk(cube, foliage)
	_build_stage_entry(cube, stem, foliage)
	var manager := get_node_or_null("../StudioBuildingManager") as StudioBuildingManager
	if manager != null:
		manager.buildings_changed.connect(_update_yards.bind(manager))
		_update_yards.call_deferred(manager)


func _build_stage_entry(cube: Mesh, stem: Mesh, foliage: Mesh) -> void:
	var site := _site("StageEntryPocket", Rect2(2.64, 8.65, 3.95, 4.18))
	_batch("StageEntryStone", cube, [
		_piece(Vector3(4.58, .034, 10.56), Vector3(3.84, .057, 4.02)),
		_piece(Vector3(5.92, .20, 10.82), Vector3(.82, .40, 2.70)),
		_piece(Vector3(3.28, .21, 11.81), Vector3(.77, .42, .94)),
	], PALETTE.finish(Color("#9c9075"), "concrete"), false).reparent(site, false)
	_batch("EntryTreeTrunk", stem, [
		_piece(Vector3(5.96, 1.38, 11.48), Vector3(.31, 2.08, .31)),
	], PALETTE.finish(Color("#69583e"))).reparent(site, false)
	_batch("EntryTreeCanopy", foliage, [
		_piece(Vector3(5.91, 2.81, 11.48), Vector3(1.66, 2.04, 1.62)),
		_piece(Vector3(5.56, 2.55, 11.12), Vector3(1.30, 1.40, 1.19)),
		_piece(Vector3(6.19, 2.52, 11.83), Vector3(1.24, 1.37, 1.23)),
		_piece(Vector3(3.28, .64, 11.81), Vector3(.71, .57, .81)),
		_piece(Vector3(5.92, .57, 10.12), Vector3(.73, .43, .78)),
	], PALETTE.finish(Color("#637949"))).reparent(site, false)
	_add_sign(site, "ПАВИЛЬОНЫ", Vector3(3.43, 1.33, 9.03))


func _build_creative_walk(cube: Mesh, canopy: Mesh) -> void:
	var site := _site("CreativeWalk", Rect2(-15.68, -10.77, 7.43, 4.23))
	_batch("CreativePaving", cube, [
		_piece(Vector3(-11.95, .031, -8.48), Vector3(7.35, .054, 3.23)),
		_piece(Vector3(-15.14, .031, -9.50), Vector3(1.02, .055, 2.35)),
	], PALETTE.finish(Color("#aa9478"), "concrete"), false).reparent(site, false)
	_batch("PergolaSteel", cube, [
		_piece(Vector3(-14.79, 1.16, -9.58), Vector3(.10, 2.30, .12)),
		_piece(Vector3(-9.44, 1.16, -9.58), Vector3(.10, 2.30, .12)),
		_piece(Vector3(-14.79, 1.16, -10.42), Vector3(.10, 2.30, .12)),
		_piece(Vector3(-9.44, 1.16, -10.42), Vector3(.10, 2.30, .12)),
		_piece(Vector3(-12.11, 2.31, -9.57), Vector3(5.55, .17, .12)),
		_piece(Vector3(-12.11, 2.31, -10.42), Vector3(5.55, .17, .12)),
	], PALETTE.finish(Color("#52625f"), "metal")).reparent(site, false)
	var slats: Array[Transform3D] = []
	for strip in range(15):
		slats.append(_piece(Vector3(-14.70 + strip * .369, 2.43, -10.0), Vector3(.075, .09, 1.07)))
	_batch("PergolaTimber", cube, slats, PALETTE.finish(Color("#967049"), "wood")).reparent(site, false)
	_batch("CreativePlanters", cube, [
		_piece(Vector3(-13.4, .32, -10.10), Vector3(2.0, .62, .66)),
		_piece(Vector3(-10.5, .32, -10.10), Vector3(1.62, .62, .66)),
	], PALETTE.finish(Color("#817060"), "concrete"), false).reparent(site, false)
	var hedges: Array[Transform3D] = []
	for x in [-14.05, -13.45, -12.85, -11.02, -10.50, -9.99]:
		hedges.append(_piece(Vector3(x, .81, -10.10), Vector3(.67, .40, .51)))
	_batch("CreativeHedge", canopy, hedges, PALETTE.finish(Color("#667a45")), false).reparent(site, false)
	_add_sign(site, "СЦЕНАРНЫЙ ОТДЕЛ", Vector3(-15.1, 1.24, -7.32))


func _build_yards(cube: Mesh, foliage: Mesh) -> void:
	var courtyard := _site("CrewCourtyard", Rect2(-10, 8.5, 5.6, 6.2))
	_batch("CourtyardPaving", cube, [
		_piece(Vector3(-7.2, .032, 11.55), Vector3(5.6, .056, 6.1)),
		_piece(Vector3(-2.03, .027, 8.76), Vector3(4.91, .053, 1.24)),
	], PALETTE.finish(Color("#b39d80"), "concrete"), false).reparent(courtyard, false)
	var beds: Array[Transform3D] = []
	var boards: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	for x in [-9.36, -5.00]:
		beds.append(_piece(Vector3(x, .30, 10.40), Vector3(.62, .60, 2.31)))
		beds.append(_piece(Vector3(x, .245, 13.29), Vector3(.64, .49, 2.20)))
		boards.append(_piece(Vector3(x, .51, 13.29), Vector3(.73, .085, 2.24)))
		boards.append(_piece(Vector3(x, .87, 13.29), Vector3(.13, .14, 2.24)))
		for index in range(6):
			var z := 9.50 + index * .36
			leaves.append(_piece(Vector3(x, .69, z), Vector3(.52, .33 + .07 * (index % 2), .47)))
			flowers.append(_piece(Vector3(x + .08 * (-1 if index % 2 == 0 else 1), .87, z), Vector3(.23, .18, .22)))
	_batch("CourtyardMasonry", cube, beds, PALETTE.finish(Color("#8d8775"), "concrete"), false).reparent(courtyard, false)
	_batch("CourtyardBenches", cube, boards, PALETTE.finish(Color("#a67448"), "wood"), false).reparent(courtyard, false)
	_batch("CourtyardFoliage", foliage, leaves, PALETTE.finish(Color("#587449")), false).reparent(courtyard, false)
	var planting := StandardMaterial3D.new()
	planting.vertex_color_use_as_albedo = true
	planting.roughness = .88
	_batch("CourtyardBlooms", foliage, flowers, planting, false, [
		Color("#dd9e60"), Color("#c87887"), Color("#dbc486"), Color("#be6886"),
	]).reparent(courtyard, false)

	var parking := _site("VisitorLayby", Rect2(13.18, -21, 4.50, 9.0))
	_batch("LaybyPaving", cube, [
		_piece(Vector3(15.4, .033, -16.5), Vector3(4.5, .061, 9)),
		_piece(Vector3(12.78, .032, -19.35), Vector3(1.47, .061, 1.80)),
	],
		PALETTE.finish(Color("#5c625e"), "concrete"), false).reparent(parking, false)
	var lines: Array[Transform3D] = []
	for bay in range(4):
		lines.append(_piece(Vector3(15.91, .07, -20.32 + bay * 2.50), Vector3(3.2, .012, .08)))
	lines.append(_piece(Vector3(17.45, .07, -16.52), Vector3(.11, .013, 7.58)))
	_batch("VisitorBayStripes", cube, lines, PALETTE.finish(Color("#e3c68e")), false).reparent(parking, false)
	_add_sign(parking, "P · ГОСТИ", Vector3(17.39, 1.31, -12.12))

	var cargo := _site("ServiceYard", Rect2(15.3, -38.2, 10.8, 6.6))
	_batch("ServicePaving", cube, [
		_piece(Vector3(20.7, .031, -34.90), Vector3(10.8, .059, 6.6)),
		_piece(Vector3(13.70, .031, -35.30), Vector3(3.42, .058, 2.34)),
	],
		PALETTE.finish(Color("#837b6d"), "concrete"), false).reparent(cargo, false)
	_batch("LoadingMarkings", cube, [
		_piece(Vector3(19.05, .068, -33.06), Vector3(6.44, .014, .10)),
		_piece(Vector3(19.05, .068, -36.86), Vector3(6.44, .014, .10)),
		_piece(Vector3(22.22, .068, -34.96), Vector3(.10, .014, 3.77)),
	], PALETTE.finish(Color("#efbb5d")), false).reparent(cargo, false)
	FURNITURE.place(cargo, "PropStock", "CargoStaging", Vector3(24.24, .060, -36.87)).scale = Vector3.ONE * 1.29
	FURNITURE.place(cargo, "FlightCaseCart", "CargoCart", Vector3(24.41, .060, -33.10)).rotation.y = -PI * .5
	_batch("CargoBarriers", cube, [
		_piece(Vector3(25.47, .54, -36.31), Vector3(.13, 1.08, .13)),
		_piece(Vector3(25.47, .54, -34.48), Vector3(.13, 1.08, .13)),
		_piece(Vector3(25.47, .72, -35.40), Vector3(.12, .19, 1.90)),
	], PALETTE.finish(Color("#9d7547"), "metal")).reparent(cargo, false)
	_add_sign(cargo, "ПОГРУЗКА", Vector3(24.73, 1.36, -32.06))


func _site(label: String, area: Rect2) -> Node3D:
	var site := Node3D.new()
	site.name = label
	site.set_meta("site_area", area)
	add_child(site)
	_sites.append(site)
	return site


func _add_sign(parent: Node3D, title: String, at: Vector3) -> void:
	_batch("WayfindingPost", BoxMesh.new(), [
		_piece(Vector3(at.x, at.y * .5, at.z), Vector3(.067, at.y, .068)),
		_piece(at, Vector3(1.16, .29, .075)),
	], PALETTE.finish(Color("#4d5b56"), "metal")).reparent(parent, false)
	var signboard := Label3D.new()
	signboard.text = title
	signboard.position = at + Vector3(0, 0, .049)
	signboard.font_size = 30
	signboard.outline_size = 5
	signboard.pixel_size = .006
	signboard.modulate = Color("#ead0a0")
	parent.add_child(signboard)


func _update_yards(manager: StudioBuildingManager) -> void:
	for site in _sites:
		site.visible = true
		var area: Rect2 = site.get_meta("site_area")
		for data in manager.get_buildings():
			var size := RULES.get_footprint(data.building_type_id, data.rotation_degrees, data.stage_size_tier)
			var origin := Vector2(data.position.x, data.position.z) - size * .5
			if area.intersects(Rect2(origin, size)):
				site.hide()
				break


func _tree(at: Vector3, index: int, trunks: Array[Transform3D], crowns: Array[Transform3D]) -> void:
	var size := .86 + .11 * (index % 4)
	trunks.append(_piece(at + Vector3.UP * 1.48 * size, Vector3(.41, 2.96, .41) * size))
	for offset in [Vector3(0, 3.21, 0), Vector3(.65, 3.06, .25), Vector3(-.57, 2.82, -.35)]:
		crowns.append(_piece(at + offset * size, Vector3(2.31, 2.52, 2.27) * size))


func _piece(at: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), at)


func _batch_by_area(
	label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material, colors: Array = []
) -> void:
	var regions: Dictionary[String, Array] = {}
	for item in transforms:
		var at := item.origin
		var region := "Road"
		if absf(at.x) > 84:
			region = "East" if at.x > 0 else "West"
		elif absf(at.z) > 84:
			region = "South" if at.z > 0 else "North"
		regions.get_or_add(region, []).append(item)
	for region in regions:
		var pieces: Array[Transform3D] = []
		pieces.assign(regions[region])
		_batch(label + region, mesh, pieces, material, region == "Road", colors)


func _batch(
	label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material,
	shadows: bool = true, colors: Array = []
) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = not colors.is_empty()
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for index in range(transforms.size()):
		instances.set_instance_transform(index, transforms[index])
		if instances.use_colors:
			var tint: Color = colors[index % colors.size()]
			instances.set_instance_color(index, tint.srgb_to_linear())
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.material_override = material
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
