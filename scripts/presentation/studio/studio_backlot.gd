extends Node3D

const PALETTE = preload("res://scripts/presentation/studio/studio_surface_palette.gd")


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
) -> void:
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
