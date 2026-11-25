extends RefCounted

static var _materials: Dictionary[String, StandardMaterial3D] = {}
static var _grain: ImageTexture


static func finish(color: Color, surface: String = "paint") -> StandardMaterial3D:
	var key := "%s:%s" % [surface, color.to_html()]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	match surface:
		"glass":
			material.roughness = .18
			material.metallic = .34
		"metal":
			material.roughness = .39
			material.metallic = .44
		"wood":
			material.roughness = .64
		"concrete":
			material.roughness = .92
		_:
			material.roughness = .73
	if surface in ["concrete", "wood", "wall"]:
		if _grain == null:
			_grain = _build_grain()
		material.albedo_texture = _grain
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3(.08, .85, .85) if surface == "wood" else Vector3.ONE * .53
	_materials[key] = material
	return material


static func _build_grain() -> ImageTexture:
	const SIDE := 64
	var noise := FastNoiseLite.new()
	noise.seed = 631
	noise.frequency = .12
	var tile := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGB8)
	for y in range(SIDE):
		for x in range(SIDE):
			var dx := float(x) / SIDE
			var dy := float(y) / SIDE
			var a := lerpf(noise.get_noise_2d(x, y), noise.get_noise_2d(x - SIDE, y), dx)
			var b := lerpf(noise.get_noise_2d(x, y - SIDE), noise.get_noise_2d(x - SIDE, y - SIDE), dx)
			var shade := .95 + lerpf(a, b, dy) * .084
			tile.set_pixel(x, y, Color(shade, shade, shade))
	tile.generate_mipmaps()
	return ImageTexture.create_from_image(tile)
