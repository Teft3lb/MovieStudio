extends RefCounted

const PALETTE = preload("res://scripts/presentation/studio/studio_surface_palette.gd")
const PROFILES := {
	"sound_stage": [Color("#5b5b56"), Color("#b99a70"), Color("#333e42"), 3, true],
	"script_department": [Color("#52656a"), Color("#d0b899"), Color("#70888c"), 2, false],
	"editing_suite": [Color("#495b63"), Color("#769495"), Color("#344950"), 3, true],
	"cafeteria": [Color("#967a60"), Color("#d1ad79"), Color("#527672"), 3, false],
	"studio_lounge": [Color("#795b4e"), Color("#bc9e79"), Color("#637b70"), 3, false],
	"tv_studio": [Color("#485f70"), Color("#698fa0"), Color("#324858"), 4, true],
	"staff_housing": [Color("#858572"), Color("#c8b594"), Color("#6e7f69"), 4, false],
	"star_bungalow": [Color("#776653"), Color("#ddbc86"), Color("#57716b"), 2, false],
	"film_promotion": [Color("#865958"), Color("#d6ad93"), Color("#684a55"), 3, false],
	"costume_wardrobe": [Color("#6d5566"), Color("#b89b9f"), Color("#5c485a"), 3, true],
	"prop_exchange": [Color("#81654d"), Color("#ccab76"), Color("#536669"), 2, false],
	"prop_warehouse": [Color("#626663"), Color("#ae9a7a"), Color("#475254"), 4, true],
	"fitness_center": [Color("#485e65"), Color("#91a7a8"), Color("#536973"), 3, false],
}
static var _unit := BoxMesh.new()
static var _architecture_meshes: Dictionary[String, ArrayMesh] = {}


static func apply(actor: Node3D, roof: Node3D, type: String, footprint: Vector2, height: float, tier: int) -> void:
	if roof == null or not PROFILES.has(type):
		return
	var profile: Array = PROFILES[type]
	var front := actor.call("get_wall_group_for_visual_builder", "front") as Node3D
	var right := actor.call("get_wall_group_for_visual_builder", "right") as Node3D
	var header := front.get_node("DoorHeader") as MeshInstance3D
	var header_mesh := header.mesh as BoxMesh
	var opening_top: float = header.position.y - header_mesh.size.y * .5
	var cache_key := "%s:%d" % [type, tier if type == "sound_stage" else 0]
	var front_mesh := _architecture_meshes.get(cache_key + "/front") as ArrayMesh
	if front_mesh == null:
		front_mesh = _front_mesh(front, type, profile, footprint, height, header_mesh.size.x, opening_top)
		_architecture_meshes[cache_key + "/front"] = front_mesh
		_architecture_meshes[cache_key + "/side"] = _side_mesh(profile, footprint.y, height)
		_architecture_meshes[cache_key + "/roof"] = _roof_mesh(type, profile, footprint, height)
	_add(front, "EntranceMasonry", front_mesh, Vector3(0, 0, footprint.y * .5))
	var right_skin := _add(right, "SideRhythm", _architecture_meshes[cache_key + "/side"], Vector3(footprint.x * .5, 0, 0))
	right_skin.rotation.y = PI * .5
	var left := actor.call("get_wall_group_for_visual_builder", "left") as Node3D
	var left_skin := _add(left, "SideRhythm", _architecture_meshes[cache_key + "/side"], Vector3(-footprint.x * .5, 0, 0))
	left_skin.rotation.y = -PI * .5
	if type != "sound_stage" or tier != 1:
		_add(roof, "RoofFixtures", _architecture_meshes[cache_key + "/roof"], Vector3.ZERO)


static func _front_mesh(
	front: Node3D, type: String, profile: Array, footprint: Vector2, height: float, door: float, lintel: float
) -> ArrayMesh:
	var span := footprint.x
	var canopy := door + .70
	var overhang := .82
	if type in ["cafeteria", "studio_lounge", "film_promotion"]:
		canopy = door + 1.56
		overhang = 1.03
	var trim: Array = [
		[Vector3(0, height - .68, .185), Vector3(span + .14, .16, .24)],
		[Vector3(0, lintel + .07, overhang * .49), Vector3(canopy, .19, overhang)],
		[Vector3(0, .027, .52), Vector3(door + .57, .055, .94)],
	]
	var masonry: Array = []
	var industrial: bool = profile[4]
	for side in [-1, 1]:
		masonry.append([Vector3(side * (span - .31) * .5, height * .48, .18), Vector3(.30, height * .93, .24)])
		masonry.append([Vector3(side * (span + door) * .25, .22, .16), Vector3((span - door) * .5, .44, .19)])
		trim.append([Vector3(side * (door * .5 + .105), lintel * .5, .24), Vector3(.20, lintel, .27)])
		trim.append([Vector3(side * (span + door) * .25, height - 1.03, .174), Vector3((span - door) * .46, .096, .15)])
		if industrial:
			var panel_width := (span - door) * .28
			var center: float = side * (span + door) * .25
			masonry.append([Vector3(center, 1.37, .152), Vector3(panel_width, 1.78, .10)])
			for rib in range(4):
				trim.append([Vector3(center + (rib - 1.5) * panel_width * .19, 1.37, .216),
					Vector3(.042, 1.65, .048)])
		else:
			var pilaster: float = side * (door * .5 + (span - door) * .27)
			trim.append([Vector3(pilaster, .74, .19), Vector3(.17, .73, .20)])
	for child in front.get_children():
		var window := child as MeshInstance3D
		if window == null or not str(window.name).contains("Window") or not window.mesh is BoxMesh:
			continue
		var pane := window.mesh as BoxMesh
		var at := window.position - Vector3(0, 0, footprint.y * .5)
		at.z += pane.size.z * .5 + .017
		for side in [-1, 1]:
			trim.append([at + Vector3(side * pane.size.x * .5, 0, 0), Vector3(.095, pane.size.y + .14, .055)])
			trim.append([at + Vector3(0, side * pane.size.y * .5, 0), Vector3(pane.size.x + .09, .078, .065)])
		trim.append([at, Vector3(.061, pane.size.y, .052)])
	var result := ArrayMesh.new()
	_append(result, masonry, PALETTE.finish(profile[0], "concrete"))
	_append(result, trim, PALETTE.finish(profile[1], "metal" if industrial else "paint"))
	return result


static func _side_mesh(profile: Array, depth: float, height: float) -> ArrayMesh:
	var bays: int = profile[3]
	var industrial: bool = profile[4]
	var beam_height := height - .86
	var band_y := height * (.67 if industrial else .49)
	var width := depth * .79 / bays
	var trim: Array = [
		[Vector3(0, .23, .155), Vector3(depth, .46, .20)],
		[Vector3(0, beam_height, .18), Vector3(depth, .20, .23)],
	]
	var glazing: Array = []
	for bay in range(bays):
		var x := (float(bay) - (bays - 1) * .5) * depth * .83 / bays
		var window_height := .74 if industrial else 1.37
		trim.append([Vector3(x, band_y, .165), Vector3(width + .16, window_height + .14, .20)])
		trim.append([Vector3(x, band_y - window_height * .5, .234), Vector3(width + .24, .089, .19)])
		for pane in [-1, 1]:
			glazing.append([Vector3(x + pane * width * .249, band_y, .276), Vector3(width * .45, window_height - .12, .035)])
		if industrial:
			trim.append([Vector3(x, 1.22, .157), Vector3(width * .79, 1.14, .103)])
	var result := ArrayMesh.new()
	_append(result, trim, PALETTE.finish(profile[0], "metal" if industrial else "concrete"))
	_append(result, glazing, PALETTE.finish(profile[2].lightened(.14), "glass"))
	return result


static func _roof_mesh(type: String, profile: Array, footprint: Vector2, height: float) -> ArrayMesh:
	var supports: Array = []
	var housings: Array = []
	for side in [-1, 1]:
		var x: float = side * footprint.x * .22
		var z: float = side * footprint.y * .16 - .64
		supports.append([Vector3(x, height + .08, z), Vector3(1.32, .16, .89)])
		housings.append([Vector3(x, height + .27, z), Vector3(1.16, .36, .71)])
		for strip in range(4):
			supports.append([Vector3(x, height + .14 + strip * .071, z + .359), Vector3(.99, .024, .058)])
	if type in ["tv_studio", "sound_stage", "prop_warehouse"]:
		var length := footprint.y * .38
		supports.append([Vector3(0, height + .09, -length * .24), Vector3(2.06, .18, length + .30)])
		housings.append([Vector3(0, height + .33, -length * .24), Vector3(1.86, .40, length)])
		for side in [-1, 1]:
			for course in range(3):
				supports.append([Vector3(side * .948, height + .23 + course * .104, -length * .24),
					Vector3(.056, .048, length * .84)])
	elif type in ["cafeteria", "studio_lounge"]:
		housings.append([Vector3(0, height + .13, -footprint.y * .12), Vector3(footprint.x * .46, .24, 1.05)])
	var result := ArrayMesh.new()
	_append(result, supports, PALETTE.finish(profile[0].darkened(.25), "metal"))
	_append(result, housings, PALETTE.finish(profile[2].lightened(.18), "metal"))
	return result


static func _append(mesh: ArrayMesh, boxes: Array, material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in boxes:
		tool.append_from(_unit, 0, Transform3D(Basis.from_scale(entry[1]), entry[0]))
	tool.set_material(material)
	tool.commit(mesh)


static func _add(parent: Node3D, label: String, mesh: Mesh, position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = position
	parent.add_child(node)
	return node
