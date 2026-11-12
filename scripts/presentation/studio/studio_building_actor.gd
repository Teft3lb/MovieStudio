extends Node3D
class_name StudioBuildingActor

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const NAVIGATION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)

const CUTAWAY_DISTANCE: float = 36.0
const WALL_THICKNESS: float = 0.28

var building_data: Variant
var _selection_marker: Node3D
var _is_selected: bool = false
var _roof_assembly: Node3D
var _wall_groups: Dictionary = {}
var _interior_root: Node3D
var _production_slate_label: Label3D
var _production_phase_label: Label3D
var _camera_rigs: Array[Node3D] = []
var _workplace_points: Array[Vector3] = []
var _entrance_inside: Vector3 = Vector3.ZERO
var _entrance_outside: Vector3 = Vector3.ZERO
var _set_dressing_root: Node3D
var _active_set_scene_key: String = ""
var _warehouse_inventory_root: Node3D
var _warehouse_storage_positions: Array[Vector3] = []
var _navigation_system: RefCounted


func setup(data: Variant) -> void:
	building_data = data
	_navigation_system = NAVIGATION_SYSTEM_SCRIPT.new()
	name = "Building_%s" % str(data.id).replace("-", "_")
	position = data.position
	rotation_degrees.y = float(data.rotation_degrees)
	add_to_group("studio_building")
	_build_visual()
	_create_hitbox()
	_create_selection_marker()
	_create_name_tag()


func _process(_delta: float) -> void:
	_update_cutaway()


func get_building_id() -> String:
	if building_data == null:
		return ""
	return str(building_data.id)


func set_selected(value: bool) -> void:
	_is_selected = value
	if is_instance_valid(_selection_marker):
		_selection_marker.visible = value
	_update_cutaway()


func get_workplace_path(slot_index: int) -> Array[Vector3]:
	var path: Array[Vector3] = []
	if _workplace_points.is_empty():
		return path
	var normalized_slot: int = clampi(slot_index, 0, _workplace_points.size() - 1)
	var building_type_id: String = str(building_data.building_type_id)
	var slot_offset: float = 0.0
	if building_type_id not in [
		"cafeteria", "staff_housing", "star_bungalow", "sound_stage",
		"fitness_center", "studio_lounge",
	]:
		slot_offset = (
			float(normalized_slot) - float(_workplace_points.size() - 1) * 0.5
		) * 0.22
	var workplace_point: Vector3 = _workplace_points[normalized_slot]
	var outside: Vector3 = _entrance_outside + Vector3(slot_offset, 0.0, 0.0)
	var inside: Vector3 = _entrance_inside + Vector3(slot_offset, 0.0, 0.0)
	var corridor: Vector3 = Vector3(
		workplace_point.x,
		0.0,
		_entrance_inside.z - 1.0
	)
	var indoor_path: Array[Vector3] = _navigation_system.call(
		"build_path",
		corridor,
		workplace_point,
		_get_interior_navigation_obstacles(normalized_slot),
		0.5,
		_get_interior_navigation_bounds()
	)
	if indoor_path.is_empty():
		return path
	path.append(_interior_root.to_global(outside))
	path.append(_interior_root.to_global(inside))
	path.append(_interior_root.to_global(corridor))
	for point_index in range(1, indoor_path.size()):
		var world_point: Vector3 = _interior_root.to_global(indoor_path[point_index])
		if path.back().distance_to(world_point) > 0.2:
			path.append(world_point)
	return path


func get_exit_path_from(
	start_world_position: Vector3,
	slot_index: int = -1
) -> Array[Vector3]:
	var local_start: Vector3 = _interior_root.to_local(start_world_position)
	var indoor_path: Array[Vector3] = _navigation_system.call(
		"build_path",
		local_start,
		_entrance_inside,
		_get_interior_navigation_obstacles(slot_index),
		0.5,
		_get_interior_navigation_bounds()
	)
	if indoor_path.is_empty():
		return []
	var result: Array[Vector3] = []
	for point in indoor_path:
		result.append(_interior_root.to_global(point))
	var outside_position: Vector3 = _interior_root.to_global(_entrance_outside)
	if result.back().distance_to(outside_position) > 0.2:
		result.append(outside_position)
	return result


func _get_interior_navigation_bounds() -> Rect2:
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		str(building_data.building_type_id),
		0.0,
		int(building_data.stage_size_tier)
	)
	var margin: float = 0.65
	return Rect2(
		Vector2(
			-footprint.x * 0.5 + margin,
			-footprint.y * 0.5 + margin
		),
		Vector2(
			footprint.x - margin * 2.0,
			footprint.y - margin * 2.0
		)
	)


func _get_interior_navigation_obstacles(slot_index: int) -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	match str(building_data.building_type_id):
		"cafeteria":
			obstacles.append({
				"center": Vector2(0.0, -4.45),
				"half_extents": Vector2(3.7, 0.5),
				"clearance": 0.22,
			})
			obstacles.append({
				"center": Vector2(0.0, -5.75),
				"half_extents": Vector2(1.7, 0.06),
				"clearance": 0.22,
			})
			for table_center_x in [-4.0, 0.0, 4.0]:
				obstacles.append({
					"center": Vector2(table_center_x, 0.35),
					"half_extents": Vector2(1.05, 0.625),
					"clearance": 0.22,
				})
		"staff_housing":
			var bed_z_positions: Array[float] = [-3.5, -1.2, 1.2, 3.5]
			var bed_slot_index: int = 0
			for side in [-1.0, 1.0]:
				for bed_z in bed_z_positions:
					if bed_slot_index != slot_index:
						obstacles.append({
							"center": Vector2(side * 5.15, bed_z),
							"half_extents": Vector2(0.78, 0.98),
							"clearance": 0.18,
						})
					bed_slot_index += 1
		"star_bungalow":
			if slot_index != 0:
				obstacles.append({
					"center": Vector2(0.0, -1.3),
					"half_extents": Vector2(1.12, 1.25),
					"clearance": 0.18,
				})
			obstacles.append({
				"center": Vector2(-3.2, -1.3),
				"half_extents": Vector2(0.58, 0.62),
				"clearance": 0.18,
			})
			obstacles.append({
				"center": Vector2(2.65, -1.3),
				"half_extents": Vector2(0.48, 0.48),
				"clearance": 0.18,
			})
			obstacles.append({
				"center": Vector2(2.65, 1.0),
				"half_extents": Vector2(0.62, 0.62),
				"clearance": 0.18,
			})
		"prop_warehouse":
			for side in [-1.0, 1.0]:
				obstacles.append({
					"center": Vector2(side * 3.75, -0.25),
					"half_extents": Vector2(0.5, 3.0),
					"clearance": 0.18,
				})
		"sound_stage":
			var stage_tier: int = BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
				int(building_data.stage_size_tier)
			)
			var side_x: float = 3.9
			var side_z: float = -2.3
			var side_depth: float = 1.4
			var backdrop_x: float = 4.1
			var backdrop_z: float = -5.0
			if stage_tier == 1:
				side_x = 2.8
				side_z = -2.2
				side_depth = 1.2
				backdrop_x = 2.9
				backdrop_z = -3.3
			elif stage_tier == 3:
				side_x = 6.4
				side_z = -4.8
				side_depth = 2.4
				backdrop_x = 6.6
				backdrop_z = -7.2
			for side in [-1.0, 1.0]:
				obstacles.append({
					"center": Vector2(side * side_x, side_z),
					"half_extents": Vector2(0.14, side_depth),
					"clearance": 0.22,
				})
			obstacles.append({
				"center": Vector2(0.0, backdrop_z),
				"half_extents": Vector2(backdrop_x, 0.12),
				"clearance": 0.22,
			})
		"fitness_center":
			for station_x in [-3.75, -1.25, 1.25, 3.75]:
				obstacles.append({
					"center": Vector2(station_x, -2.1),
					"half_extents": Vector2(0.55, 0.9),
					"clearance": 0.16,
				})
		"studio_lounge":
			obstacles.append({
				"center": Vector2(-4.5, 0.2),
				"half_extents": Vector2(0.95, 1.15),
				"clearance": 0.18,
			})
			obstacles.append({
				"center": Vector2(4.5, 0.2),
				"half_extents": Vector2(0.95, 1.15),
				"clearance": 0.18,
			})
			obstacles.append({
				"center": Vector2(0.0, 0.15),
				"half_extents": Vector2(0.9, 0.55),
				"clearance": 0.18,
			})
			obstacles.append({
				"center": Vector2(0.0, -4.4),
				"half_extents": Vector2(2.8, 0.45),
				"clearance": 0.18,
			})
	return obstacles


func get_workplace_position(slot_index: int) -> Vector3:
	var path: Array[Vector3] = get_workplace_path(slot_index)
	if path.is_empty():
		return global_position
	return path[path.size() - 1]


func get_workplace_facing_direction(slot_index: int) -> Vector3:
	if _workplace_points.is_empty():
		return Vector3.ZERO
	var normalized_slot: int = clampi(
		slot_index,
		0,
		_workplace_points.size() - 1
	)
	var building_type_id: String = str(building_data.building_type_id)
	var target_position: Vector3 = Vector3.ZERO
	match building_type_id:
		"cafeteria":
			var seat_position: Vector3 = _workplace_points[normalized_slot]
			var table_center_x: float = roundf(seat_position.x / 4.0) * 4.0
			target_position = Vector3(table_center_x, 0.0, 0.35)
		"studio_lounge":
			target_position = Vector3(0.0, 0.0, 0.15)
		"fitness_center":
			var equipment_position: Vector3 = _workplace_points[normalized_slot]
			target_position = equipment_position + Vector3(0.0, 0.0, -1.4)
		"staff_housing", "star_bungalow":
			target_position = (
				_workplace_points[normalized_slot]
				+ Vector3(0.0, 0.0, -1.0)
			)
		_:
			return Vector3.ZERO
	var local_direction: Vector3 = (
		target_position - _workplace_points[normalized_slot]
	)
	local_direction.y = 0.0
	if local_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return (global_basis * local_direction).normalized()


func get_scene_path(
	start_world_position: Vector3,
	target_world_position: Vector3
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not BUILDING_CATALOG_SCRIPT.is_sound_stage(
		str(building_data.building_type_id)
	):
		result.append(start_world_position)
		result.append(target_world_position)
		return result
	var local_start: Vector3 = _interior_root.to_local(start_world_position)
	var local_target: Vector3 = _interior_root.to_local(target_world_position)
	var local_start_2d: Vector2 = Vector2(local_start.x, local_start.z)
	var local_target_2d: Vector2 = Vector2(local_target.x, local_target.z)
	var obstacles: Array[Dictionary] = [
		{
			"center": Vector2(-3.9, -2.3),
			"half_extents": Vector2(0.14, 1.4),
			"clearance": 0.28,
		},
		{
			"center": Vector2(3.9, -2.3),
			"half_extents": Vector2(0.14, 1.4),
			"clearance": 0.28,
		},
		{
			"center": Vector2(0.0, -5.0),
			"half_extents": Vector2(4.1, 0.12),
			"clearance": 0.28,
		},
	]
	if is_instance_valid(_set_dressing_root):
		for prop_node in _set_dressing_root.get_children():
			var prop: Node3D = prop_node as Node3D
			if not is_instance_valid(prop) or not prop.visible:
				continue
			var prop_center: Vector2 = Vector2(prop.position.x, prop.position.z)
			var prop_half_extents: Vector2 = Vector2(0.98, 0.55)
			var prop_clearance: float = 0.18
			if (
				_is_point_inside_bounds(
					local_start_2d,
					prop_center,
					prop_half_extents,
					prop_clearance
				)
				or _is_point_inside_bounds(
					local_target_2d,
					prop_center,
					prop_half_extents,
					prop_clearance
				)
			):
				continue
			obstacles.append({
				"center": prop_center,
				"half_extents": prop_half_extents,
				"clearance": prop_clearance,
			})
	var local_path: Array[Vector3] = _navigation_system.call(
		"build_path",
		local_start,
		local_target,
		obstacles,
		0.5,
		_get_interior_navigation_bounds()
	)
	for local_point in local_path:
		result.append(_interior_root.to_global(local_point))
	return result


func _is_point_inside_bounds(
	point: Vector2,
	center: Vector2,
	half_extents: Vector2,
	clearance: float
) -> bool:
	return (
		absf(point.x - center.x) <= half_extents.x + clearance
		and absf(point.y - center.y) <= half_extents.y + clearance
	)


func get_set_dressing_prop_count() -> int:
	if not is_instance_valid(_set_dressing_root):
		return 0
	return _set_dressing_root.get_child_count()


func get_set_dressing_mark(prop_index: int) -> Vector3:
	var positions: Array[Vector3] = _get_set_dressing_positions()
	var index: int = clampi(prop_index, 0, positions.size() - 1)
	return _interior_root.to_global(positions[index])


func _get_set_dressing_positions() -> Array[Vector3]:
	match BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
		int(building_data.stage_size_tier)
	):
		1:
			return [
				Vector3(-1.55, 0.0, -3.1),
				Vector3(0.0, 0.0, -3.1),
				Vector3(1.55, 0.0, -3.1),
				Vector3(0.0, 0.0, -1.5),
			]
		3:
			return [
				Vector3(-5.2, 0.0, -6.6),
				Vector3(0.0, 0.0, -6.6),
				Vector3(5.2, 0.0, -6.6),
				Vector3(0.0, 0.0, -3.8),
			]
		_:
			return [
				Vector3(-2.65, 0.0, -4.0),
				Vector3(0.0, 0.0, -4.0),
				Vector3(2.65, 0.0, -4.0),
				Vector3(0.0, 0.0, -2.0),
			]


func prepare_scene_set_dressing(setup: Dictionary) -> bool:
	if not is_instance_valid(_set_dressing_root):
		return false
	var raw_prop_ids: Variant = setup.get("prop_ids", [])
	var prop_ids: Array = []
	if raw_prop_ids is Array:
		prop_ids = raw_prop_ids
	var prop_signature: String = ""
	for prop_id_value in prop_ids:
		if not prop_signature.is_empty():
			prop_signature += ","
		prop_signature += str(prop_id_value)
	var scene_key: String = "%s:%s:%s" % [
		str(setup.get("scene_id", "")),
		str(setup.get("set_id", "neutral")),
		prop_signature,
	]
	if scene_key == _active_set_scene_key:
		return true
	if _set_dressing_root.get_child_count() > 0:
		push_warning(
			"StudioBuildingActor: refusing to replace set dressing before strike is complete."
		)
		return false
	_active_set_scene_key = scene_key
	var positions: Array[Vector3] = _get_set_dressing_positions()
	for prop_index in range(mini(prop_ids.size(), positions.size())):
		var prop_id: String = str(prop_ids[prop_index])
		var prop_root := Node3D.new()
		prop_root.name = "SetProp_%s" % prop_id
		prop_root.position = positions[prop_index]
		_build_set_prop_visual(prop_root, prop_id)
		_set_dressing_root.add_child(prop_root)
		prop_root.visible = false
	return true


func install_set_prop(prop_id: String) -> bool:
	var prop_node: Node3D = _find_set_prop(prop_id)
	if prop_node == null:
		return false
	prop_node.visible = true
	return true


func remove_set_prop(prop_id: String) -> bool:
	var prop_node: Node3D = _find_set_prop(prop_id)
	if prop_node == null:
		return false
	prop_node.visible = false
	return true


func clear_scene_set_dressing() -> void:
	if not is_instance_valid(_set_dressing_root):
		return
	for child in _set_dressing_root.get_children():
		_set_dressing_root.remove_child(child)
		child.queue_free()
	_active_set_scene_key = ""


func _find_set_prop(prop_id: String) -> Node3D:
	if not is_instance_valid(_set_dressing_root):
		return null
	return _set_dressing_root.get_node_or_null(
		"SetProp_%s" % prop_id
	) as Node3D


func set_scene_set_dressing(setup: Dictionary, progress: float) -> void:
	if not prepare_scene_set_dressing(setup):
		return
	var visible_count: int = clampi(
		floori(
			clampf(progress, 0.0, 1.0)
			* float(_set_dressing_root.get_child_count())
			+ 0.0001
		),
		0,
		_set_dressing_root.get_child_count()
	)
	for prop_index in range(_set_dressing_root.get_child_count()):
		var prop_node: Node3D = _set_dressing_root.get_child(
			prop_index
		) as Node3D
		prop_node.visible = prop_index < visible_count


func get_storage_mark(prop_index: int) -> Vector3:
	if _warehouse_storage_positions.is_empty():
		return global_position
	var index: int = posmod(prop_index, _warehouse_storage_positions.size())
	return to_global(_warehouse_storage_positions[index])


func set_warehouse_inventory(prop_ids: Array) -> void:
	if not is_instance_valid(_warehouse_inventory_root):
		return
	for child in _warehouse_inventory_root.get_children():
		_warehouse_inventory_root.remove_child(child)
		child.queue_free()
	var shelf_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for shelf_level in range(3):
			for column in range(4):
				shelf_positions.append(Vector3(
					side * 3.75,
					0.62 + float(shelf_level) * 1.12,
					-2.55 + float(column) * 1.55
				))
	for prop_index in range(prop_ids.size()):
		var prop_id: String = str(prop_ids[prop_index])
		var prop_root := Node3D.new()
		prop_root.name = "StoredProp_%s" % prop_id
		prop_root.position = shelf_positions[
			posmod(prop_index, shelf_positions.size())
		]
		prop_root.scale = Vector3.ONE * 0.22
		_build_set_prop_visual(prop_root, prop_id)
		_warehouse_inventory_root.add_child(prop_root)


func _build_set_prop_visual(parent: Node3D, prop_id: String) -> void:
	var wood: Color = Color(0.38, 0.25, 0.16)
	var dark_wood: Color = Color(0.20, 0.13, 0.09)
	var metal: Color = Color(0.27, 0.31, 0.34)
	var accent: Color = Color(0.63, 0.48, 0.27)
	var glass: Color = Color(0.10, 0.29, 0.36)
	match prop_id:
		"street_storefront":
			_create_box(parent, "Facade", Vector3(1.8, 2.6, 0.34), Color(0.53, 0.43, 0.32), Vector3(0.0, 1.3, 0.0))
			_create_box(parent, "Awning", Vector3(1.95, 0.25, 0.72), Color(0.64, 0.25, 0.18), Vector3(0.0, 2.0, -0.22))
			_create_box(parent, "ShopWindow", Vector3(0.9, 0.95, 0.06), glass, Vector3(-0.35, 1.15, -0.2))
			_create_box(parent, "Door", Vector3(0.42, 1.75, 0.08), dark_wood, Vector3(0.68, 0.88, -0.2))
		"street_lamp":
			_create_cylinder(parent, "LampPost", 0.07, 2.9, metal, Vector3(0.0, 1.45, 0.0))
			_create_box(parent, "LampHead", Vector3(0.55, 0.34, 0.48), Color(0.86, 0.77, 0.53), Vector3(0.0, 2.95, -0.12))
		"street_bench":
			_create_box(parent, "BenchSeat", Vector3(1.55, 0.16, 0.48), wood, Vector3(0.0, 0.55, 0.0))
			_create_box(parent, "BenchBack", Vector3(1.55, 0.72, 0.14), wood, Vector3(0.0, 0.95, 0.18))
			for leg_x in [-0.58, 0.58]:
				_create_box(parent, "BenchLeg", Vector3(0.12, 0.52, 0.12), metal, Vector3(leg_x, 0.27, 0.0))
		"home_sofa":
			_create_box(parent, "SofaBase", Vector3(1.65, 0.52, 0.78), Color(0.35, 0.22, 0.25), Vector3(0.0, 0.48, 0.0))
			_create_box(parent, "SofaBack", Vector3(1.65, 0.82, 0.22), Color(0.42, 0.27, 0.30), Vector3(0.0, 1.0, 0.28))
			for arm_x in [-0.82, 0.82]:
				_create_box(parent, "SofaArm", Vector3(0.22, 0.62, 0.78), Color(0.39, 0.24, 0.27), Vector3(arm_x, 0.63, 0.0))
		"home_coffee_table":
			_create_box(parent, "TableTop", Vector3(1.25, 0.12, 0.72), wood, Vector3(0.0, 0.62, 0.0))
			for leg_x in [-0.48, 0.48]:
				for leg_z in [-0.24, 0.24]:
					_create_box(parent, "TableLeg", Vector3(0.08, 0.58, 0.08), dark_wood, Vector3(leg_x, 0.29, leg_z))
		"home_floor_lamp":
			_create_cylinder(parent, "LampStand", 0.045, 1.8, metal, Vector3(0.0, 0.9, 0.0))
			_create_cylinder(parent, "LampShade", 0.34, 0.38, accent, Vector3(0.0, 1.75, 0.0))
		"forest_trees":
			_create_cylinder(parent, "TreeTrunk", 0.18, 2.0, dark_wood, Vector3(0.0, 1.0, 0.0))
			var canopy := _create_sphere(parent, "TreeCanopy", 0.9, Color(0.16, 0.32, 0.19), Vector3(0.0, 2.2, 0.0))
			canopy.scale = Vector3(1.0, 1.2, 1.0)
			_create_cylinder(parent, "TreeTrunkSmall", 0.13, 1.5, dark_wood, Vector3(0.8, 0.75, -0.15))
			_create_sphere(parent, "TreeCanopySmall", 0.65, Color(0.21, 0.39, 0.22), Vector3(0.8, 1.65, -0.15))
		"forest_rocks":
			var rock_a := _create_sphere(parent, "RockA", 0.55, Color(0.38, 0.40, 0.39), Vector3(-0.35, 0.35, 0.0))
			rock_a.scale = Vector3(1.4, 0.8, 1.0)
			var rock_b := _create_sphere(parent, "RockB", 0.42, Color(0.45, 0.46, 0.43), Vector3(0.38, 0.25, -0.1))
			rock_b.scale = Vector3(1.0, 0.65, 1.0)
		"forest_trail_sign":
			_create_cylinder(parent, "SignPost", 0.07, 1.8, dark_wood, Vector3(0.0, 0.9, 0.0))
			_create_box(parent, "TrailSign", Vector3(1.15, 0.48, 0.12), wood, Vector3(0.0, 1.45, -0.05))
		"lighthouse_console":
			_create_box(parent, "ConsoleDesk", Vector3(1.55, 0.9, 0.75), dark_wood, Vector3(0.0, 0.48, 0.0))
			_create_box(parent, "ConsolePanel", Vector3(1.35, 0.52, 0.12), metal, Vector3(0.0, 1.15, -0.22))
			_create_box(parent, "ConsoleScreen", Vector3(0.72, 0.34, 0.05), glass, Vector3(-0.22, 1.18, -0.30))
		"lighthouse_beacon":
			_create_cylinder(parent, "BeaconTower", 0.42, 2.6, Color(0.72, 0.68, 0.55), Vector3(0.0, 1.3, 0.0))
			_create_cylinder(parent, "BeaconLens", 0.48, 0.58, Color(0.83, 0.69, 0.34), Vector3(0.0, 2.35, 0.0))
			_create_cylinder(parent, "BeaconCap", 0.55, 0.16, metal, Vector3(0.0, 2.72, 0.0))
		"lighthouse_rail":
			for rail_x in [-0.75, 0.0, 0.75]:
				_create_cylinder(parent, "RailPost", 0.055, 1.1, metal, Vector3(rail_x, 0.55, 0.0))
			_create_box(parent, "RailTop", Vector3(1.65, 0.08, 0.08), metal, Vector3(0.0, 1.0, 0.0))
			_create_box(parent, "RailBottom", Vector3(1.65, 0.08, 0.08), metal, Vector3(0.0, 0.42, 0.0))
		"industrial_crates":
			_create_box(parent, "CrateA", Vector3(0.85, 0.85, 0.85), wood, Vector3(-0.38, 0.43, 0.0))
			_create_box(parent, "CrateB", Vector3(0.75, 0.75, 0.75), accent, Vector3(0.42, 0.38, -0.12))
			_create_box(parent, "CrateC", Vector3(0.62, 0.62, 0.62), dark_wood, Vector3(0.0, 1.13, 0.0))
		"industrial_pipes":
			for pipe_x in [-0.48, 0.0, 0.48]:
				_create_cylinder(parent, "PipeStack", 0.13, 2.2, metal, Vector3(pipe_x, 1.1, 0.0))
			_create_box(parent, "PipeRack", Vector3(1.25, 0.12, 0.72), dark_wood, Vector3(0.0, 0.18, 0.0))
		"industrial_work_light":
			_create_cylinder(parent, "WorkLightStand", 0.06, 2.0, metal, Vector3(0.0, 1.0, 0.0))
			_create_box(parent, "WorkLightHead", Vector3(0.85, 0.58, 0.28), Color(0.82, 0.73, 0.48), Vector3(0.0, 2.05, -0.12))
		"office_desk":
			_create_box(parent, "OfficeDeskTop", Vector3(1.5, 0.14, 0.78), dark_wood, Vector3(0.0, 0.82, 0.0))
			for leg_x in [-0.62, 0.62]:
				for leg_z in [-0.28, 0.28]:
					_create_box(parent, "OfficeDeskLeg", Vector3(0.08, 0.78, 0.08), metal, Vector3(leg_x, 0.39, leg_z))
		"office_bookshelf":
			_create_box(parent, "ShelfBack", Vector3(1.35, 2.25, 0.12), dark_wood, Vector3(0.0, 1.12, 0.0))
			for shelf_y in [0.35, 0.95, 1.55, 2.15]:
				_create_box(parent, "Shelf", Vector3(1.4, 0.08, 0.42), wood, Vector3(0.0, shelf_y, -0.16))
		"office_evidence_board":
			_create_box(parent, "EvidenceBoard", Vector3(1.55, 1.45, 0.12), Color(0.39, 0.34, 0.25), Vector3(0.0, 1.55, 0.0))
			for note_x in [-0.42, 0.0, 0.42]:
				_create_box(parent, "EvidenceNote", Vector3(0.22, 0.28, 0.035), Color(0.82, 0.78, 0.61), Vector3(note_x, 1.65, -0.09))
		"scifi_lab_console":
			_create_box(parent, "LabConsoleBase", Vector3(1.55, 0.85, 0.72), metal, Vector3(0.0, 0.44, 0.0))
			_create_box(parent, "LabConsoleScreen", Vector3(1.2, 0.65, 0.1), Color(0.10, 0.54, 0.66), Vector3(0.0, 1.15, -0.22))
		"scifi_reactor":
			_create_cylinder(parent, "ReactorCore", 0.42, 2.5, Color(0.16, 0.42, 0.50), Vector3(0.0, 1.25, 0.0))
			_create_cylinder(parent, "ReactorRingTop", 0.68, 0.14, accent, Vector3(0.0, 2.0, 0.0))
			_create_cylinder(parent, "ReactorRingBottom", 0.68, 0.14, accent, Vector3(0.0, 0.55, 0.0))
		"scifi_holo_display":
			_create_box(parent, "HoloBase", Vector3(1.2, 0.22, 0.7), metal, Vector3(0.0, 0.12, 0.0))
			_create_cylinder(parent, "HoloProjector", 0.08, 1.15, Color(0.13, 0.65, 0.75), Vector3(0.0, 0.72, 0.0))
			_create_box(parent, "HoloImage", Vector3(0.9, 0.75, 0.08), Color(0.15, 0.63, 0.75), Vector3(0.0, 1.48, 0.0))
		_:
			_create_box(parent, "NeutralProp", Vector3(0.8, 0.8, 0.8), wood, Vector3(0.0, 0.4, 0.0))


func get_scene_mark(
	slot_index: int,
	phase_id: String = "preparation",
	scene_index: int = 0
) -> Vector3:
	var stage_tier: int = BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
		int(building_data.stage_size_tier)
	)
	var scene_marks: Array[Vector3] = []
	match stage_tier:
		1:
			scene_marks = [
				Vector3(-1.8, 0.0, -2.65),
				Vector3(-0.6, 0.0, -2.65),
				Vector3(0.6, 0.0, -2.65),
				Vector3(1.8, 0.0, -2.65),
				Vector3(-1.35, 0.0, -1.65),
				Vector3(0.0, 0.0, -1.65),
				Vector3(1.35, 0.0, -1.65),
				Vector3(0.0, 0.0, -0.9),
			]
		3:
			scene_marks = [
				Vector3(-5.0, 0.0, -5.3),
				Vector3(-2.5, 0.0, -5.3),
				Vector3(0.0, 0.0, -5.3),
				Vector3(2.5, 0.0, -5.3),
				Vector3(5.0, 0.0, -5.3),
				Vector3(-3.8, 0.0, -4.0),
				Vector3(0.0, 0.0, -4.0),
				Vector3(3.8, 0.0, -4.0),
			]
		_:
			scene_marks = [
				Vector3(-3.0, 0.0, -2.3),
				Vector3(-1.0, 0.0, -2.3),
				Vector3(1.0, 0.0, -2.3),
				Vector3(3.0, 0.0, -2.3),
				Vector3(-2.2, 0.0, -1.65),
				Vector3(0.0, 0.0, -1.65),
				Vector3(2.2, 0.0, -1.65),
				Vector3(3.4, 0.0, -1.65),
			]
	var normalized_index: int = clampi(slot_index, 0, scene_marks.size() - 1)
	var mark: Vector3 = scene_marks[normalized_index]
	if posmod(scene_index, 2) == 1:
		mark.x = -mark.x
	match phase_id:
		"rehearsal":
			mark.x += 0.22 if mark.x < 0.0 else -0.22
			mark.z += 0.28
		"shooting":
			mark.x += 0.38 if mark.x < 0.0 else -0.38
			mark.z += 0.52 if normalized_index % 2 == 0 else -0.18
		"review":
			mark.z += 0.12
	return _interior_root.to_global(mark)


func get_scene_hold_mark(slot_index: int) -> Vector3:
	var hold_marks: Array[Vector3] = []
	match BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
		int(building_data.stage_size_tier)
	):
		1:
			hold_marks = [
				Vector3(-3.6, 0.0, 2.8),
				Vector3(-2.2, 0.0, 3.0),
				Vector3(-0.8, 0.0, 3.1),
				Vector3(0.8, 0.0, 3.1),
				Vector3(2.2, 0.0, 3.0),
				Vector3(3.6, 0.0, 2.8),
			]
		3:
			hold_marks = [
				Vector3(-9.0, 0.0, 7.0),
				Vector3(-6.0, 0.0, 7.2),
				Vector3(-3.0, 0.0, 7.4),
				Vector3(0.0, 0.0, 7.5),
				Vector3(3.0, 0.0, 7.4),
				Vector3(6.0, 0.0, 7.2),
				Vector3(9.0, 0.0, 7.0),
				Vector3(-7.5, 0.0, 5.8),
				Vector3(-2.5, 0.0, 5.8),
				Vector3(2.5, 0.0, 5.8),
				Vector3(7.5, 0.0, 5.8),
				Vector3(0.0, 0.0, 6.6),
			]
		_:
			hold_marks = [
				Vector3(-4.8, 0.0, 4.3),
				Vector3(-3.5, 0.0, 4.5),
				Vector3(-2.2, 0.0, 4.7),
				Vector3(-0.9, 0.0, 4.8),
				Vector3(0.9, 0.0, 4.8),
				Vector3(2.2, 0.0, 4.7),
				Vector3(3.5, 0.0, 4.5),
				Vector3(4.8, 0.0, 4.3),
				Vector3(-3.2, 0.0, 5.0),
				Vector3(-1.0, 0.0, 5.2),
				Vector3(1.0, 0.0, 5.2),
				Vector3(3.2, 0.0, 5.0),
			]
	var normalized_index: int = posmod(slot_index, hold_marks.size())
	return _interior_root.to_global(hold_marks[normalized_index])


func get_scene_focus_point() -> Vector3:
	var focus_point: Vector3 = Vector3(0.0, 1.45, -4.35)
	match BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
		int(building_data.stage_size_tier)
	):
		1:
			focus_point = Vector3(0.0, 1.25, -2.75)
		3:
			focus_point = Vector3(0.0, 1.8, -6.0)
	return _interior_root.to_global(focus_point)


func set_production_scene(
	scene_number: int,
	scene_title: String,
	phase_title: String
) -> void:
	if is_instance_valid(_production_slate_label):
		if scene_number > 0:
			_production_slate_label.text = (
				"СЦЕНА %02d · %s" % [scene_number, scene_title]
			)
		else:
			_production_slate_label.text = scene_title
	if is_instance_valid(_production_phase_label):
		_production_phase_label.text = phase_title


func set_camera_target(target_position: Vector3, active: bool) -> void:
	for camera_rig in _camera_rigs:
		if not is_instance_valid(camera_rig):
			continue
		if active:
			camera_rig.look_at(target_position, Vector3.UP)
		else:
			camera_rig.rotation = Vector3.ZERO


func _build_visual() -> void:
	var building_type_id: String = str(building_data.building_type_id)
	var stage_size_tier: int = int(building_data.stage_size_tier)
	var definition: Dictionary = BUILDING_CATALOG_SCRIPT.get_definition(
		building_type_id
	)
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		building_type_id,
		0.0,
		stage_size_tier
	)
	var height: float = BUILDING_CATALOG_SCRIPT.get_building_height(
		building_type_id,
		stage_size_tier
	)
	_create_interior_root()
	if BUILDING_CATALOG_SCRIPT.is_sound_stage(building_type_id):
		_build_sound_stage(footprint, height, definition)
		return
	match building_type_id:
		"editing_suite":
			_build_editing_suite(footprint, height, definition)
		"prop_warehouse":
			_build_prop_warehouse(footprint, height, definition)
		"cafeteria":
			_build_cafeteria(footprint, height, definition)
		"staff_housing":
			_build_staff_housing(footprint, height, definition)
		"star_bungalow":
			_build_star_bungalow(footprint, height, definition)
		"fitness_center":
			_build_fitness_center(footprint, height, definition)
		"studio_lounge":
			_build_studio_lounge(footprint, height, definition)
		_:
			_build_script_department(footprint, height, definition)


func _create_interior_root() -> void:
	_interior_root = Node3D.new()
	_interior_root.name = "Interior"
	add_child(_interior_root)


func _build_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	match BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
		int(building_data.stage_size_tier)
	):
		1:
			_build_small_sound_stage(footprint, height, definition)
		3:
			_build_large_sound_stage(footprint, height, definition)
		_:
			_build_medium_sound_stage(footprint, height, definition)


func _build_small_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.49, 0.47, 0.43)
	var roof_color: Color = Color(0.26, 0.19, 0.17)
	var trim_color: Color = Color(0.18, 0.20, 0.22)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.53, 0.43, 0.33)
	)
	_create_floor(footprint, Color(0.20, 0.21, 0.22), "SmallStageFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		3.2,
		3.2
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	var left_roof: MeshInstance3D = _create_box(
		_roof_assembly,
		"SmallStageGableRoofLeft",
		Vector3(width + 0.55, 0.28, depth * 0.64),
		roof_color,
		Vector3(0.0, height - 0.55, -depth * 0.20)
	)
	left_roof.rotation.x = -0.42
	var right_roof: MeshInstance3D = _create_box(
		_roof_assembly,
		"SmallStageGableRoofRight",
		Vector3(width + 0.55, 0.28, depth * 0.64),
		roof_color,
		Vector3(0.0, height - 0.55, depth * 0.20)
	)
	right_roof.rotation.x = 0.42
	_create_box(
		_roof_assembly,
		"SmallStageRidgeBeam",
		Vector3(width + 0.7, 0.28, 0.34),
		trim_color,
		Vector3(0.0, height + 0.05, 0.0)
	)
	_create_box(
		self,
		"SmallStageLoadingCanopy",
		Vector3(4.0, 0.18, 1.0),
		trim_color,
		Vector3(0.0, 3.55, depth * 0.5 + 0.45)
	)
	_create_box(
		self,
		"SmallStageSign",
		Vector3(4.8, 0.58, 0.18),
		accent_color,
		Vector3(0.0, 4.25, depth * 0.5 + 0.24)
	)
	_create_label(
		self,
		"SmallStageSignText",
		"МАЛАЯ СТУДИЯ",
		Vector3(0.0, 4.25, depth * 0.5 + 0.34),
		18
	)
	_create_box(
		_wall_groups["front"],
		"SmallStageFrontWindow",
		Vector3(1.45, 0.95, 0.12),
		Color(0.18, 0.34, 0.39),
		Vector3(-3.75, 3.55, depth * 0.5 + 0.22)
	)
	_build_small_sound_stage_interior()


func _build_medium_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.43, 0.40, 0.36)
	var roof_color: Color = Color(0.22, 0.24, 0.26)
	var trim_color: Color = Color(0.16, 0.18, 0.20)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.53, 0.43, 0.33)
	)
	_create_floor(footprint, Color(0.19, 0.20, 0.21), "StageFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		4.6,
		4.0
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"StageRoof",
		Vector3(width + 0.45, 0.55, depth + 0.45),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_roof_assembly,
		"VentilationUnit",
		Vector3(2.4, 0.7, 1.8),
		trim_color,
		Vector3(width * 0.26, height + 0.35, -depth * 0.18)
	)
	_create_box(
		self,
		"RollDoorRaisedPanel",
		Vector3(4.4, 0.35, 0.16),
		trim_color,
		Vector3(0.0, 4.35, depth * 0.5 + 0.24)
	)
	_create_box(
		self,
		"FrontSign",
		Vector3(5.2, 0.72, 0.18),
		accent_color,
		Vector3(0.0, 5.0, depth * 0.5 + 0.24)
	)
	_create_label(
		self,
		"StageSignText",
		"СЪЁМОЧНЫЙ ПАВИЛЬОН",
		Vector3(0.0, 5.0, depth * 0.5 + 0.34),
		20
	)
	_build_medium_sound_stage_interior()


func _build_large_sound_stage(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.34, 0.39, 0.42)
	var roof_color: Color = Color(0.17, 0.21, 0.25)
	var truss_color: Color = Color(0.24, 0.29, 0.33)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.53, 0.43, 0.33)
	)
	_create_floor(footprint, Color(0.17, 0.19, 0.21), "HighBayStageFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		7.0,
		5.6
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"HighBayRoofDeck",
		Vector3(width + 0.8, 0.65, depth + 0.8),
		roof_color,
		Vector3(0.0, height - 0.325, 0.0)
	)
	for beam_x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_create_box(
			_roof_assembly,
			"HighBayRoofTruss_%d" % roundi(beam_x + 8.0),
			Vector3(0.24, 1.15, depth + 0.3),
			truss_color,
			Vector3(beam_x, height - 1.0, 0.0)
		)
	for skylight_x in [-4.0, 4.0]:
		_create_box(
			_roof_assembly,
			"HighBaySkylight_%d" % roundi(skylight_x + 4.0),
			Vector3(2.6, 0.16, depth - 2.0),
			Color(0.30, 0.43, 0.48),
			Vector3(skylight_x, height + 0.025, 0.0)
		)
	_create_box(
		self,
		"HighBayLoadingDoorHeader",
		Vector3(7.2, 0.32, 0.2),
		truss_color,
		Vector3(0.0, 5.85, depth * 0.5 + 0.25)
	)
	_create_box(
		self,
		"HighBayFrontSign",
		Vector3(8.2, 0.82, 0.2),
		accent_color,
		Vector3(0.0, 6.8, depth * 0.5 + 0.25)
	)
	_create_label(
		self,
		"HighBayFrontSignText",
		"БОЛЬШОЙ СЪЁМОЧНЫЙ АНГАР",
		Vector3(0.0, 6.8, depth * 0.5 + 0.36),
		22
	)
	_create_box(
		_wall_groups["front"],
		"HighBayControlRoomWindow",
		Vector3(3.8, 1.35, 0.12),
		Color(0.13, 0.30, 0.38),
		Vector3(-7.0, 6.4, depth * 0.5 + 0.22)
	)
	_create_box(
		_wall_groups["right"],
		"HighBayServiceWindow",
		Vector3(0.12, 1.2, 2.8),
		Color(0.13, 0.30, 0.38),
		Vector3(width * 0.5 + 0.22, 6.2, 0.0)
	)
	_build_large_sound_stage_interior()


func _build_small_sound_stage_interior() -> void:
	var set_color: Color = Color(0.29, 0.31, 0.32)
	var equipment_color: Color = Color(0.11, 0.13, 0.15)
	var metal_color: Color = Color(0.34, 0.36, 0.38)
	var tape_color: Color = Color(0.88, 0.69, 0.24)
	_set_dressing_root = Node3D.new()
	_set_dressing_root.name = "SetDressing"
	_interior_root.add_child(_set_dressing_root)
	_create_wall_panel(
		_interior_root,
		"SmallSetBackdrop",
		Vector3(5.8, 3.3, 0.22),
		set_color,
		Vector3(0.0, 1.7, -3.3)
	)
	_create_box(
		_interior_root,
		"SmallSetPlatform",
		Vector3(5.8, 0.16, 2.8),
		Color(0.29, 0.28, 0.25),
		Vector3(0.0, 0.12, -2.35)
	)
	for side in [-1.0, 1.0]:
		_create_wall_panel(
			_interior_root,
			"SmallSetSideWallLeft" if side < 0.0 else "SmallSetSideWallRight",
			Vector3(0.18, 2.6, 2.4),
			Color(0.34, 0.32, 0.29),
			Vector3(side * 2.8, 1.35, -2.15)
		)
	for mark_x in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		_create_box(
			_interior_root,
			"SmallStageFloorMark_%d" % roundi(mark_x + 2.0),
			Vector3(0.08, 0.025, 1.2),
			tape_color,
			Vector3(mark_x, 0.055, -0.4)
		)
	_camera_rigs.clear()
	_camera_rigs.append(
		_create_camera_rig(
			Vector3(3.15, 0.0, -0.15),
			metal_color,
			equipment_color
		)
	)
	_create_light_stand(Vector3(-3.5, 0.0, -3.0), metal_color)
	_create_light_stand(Vector3(3.5, 0.0, -3.0), metal_color)
	_create_box(
		_interior_root,
		"SmallStageEquipmentRack",
		Vector3(0.85, 1.45, 0.55),
		equipment_color,
		Vector3(3.75, 0.72, 2.55)
	)
	_create_box(
		_interior_root,
		"SmallStageDirectorDesk",
		Vector3(1.25, 0.78, 0.58),
		Color(0.23, 0.20, 0.18),
		Vector3(-3.65, 0.42, 2.55)
	)
	_create_film_slate()
	_workplace_points = [
		Vector3(-1.35, 0.0, -1.1),
		Vector3(1.35, 0.0, -1.1),
		Vector3(-3.55, 0.0, 1.45),
		Vector3(-3.45, 0.0, -0.15),
		Vector3(3.45, 0.0, -0.15),
		Vector3(3.55, 0.0, 1.45),
	]


func _build_large_sound_stage_interior() -> void:
	var set_color: Color = Color(0.24, 0.29, 0.32)
	var equipment_color: Color = Color(0.09, 0.12, 0.15)
	var metal_color: Color = Color(0.38, 0.42, 0.45)
	var tape_color: Color = Color(0.91, 0.72, 0.25)
	_set_dressing_root = Node3D.new()
	_set_dressing_root.name = "SetDressing"
	_interior_root.add_child(_set_dressing_root)
	_create_wall_panel(
		_interior_root,
		"HighBayMainSetBackdrop",
		Vector3(13.2, 5.0, 0.28),
		set_color,
		Vector3(0.0, 2.5, -7.2)
	)
	_create_box(
		_interior_root,
		"HighBaySetPlatform",
		Vector3(13.2, 0.18, 5.4),
		Color(0.27, 0.29, 0.30),
		Vector3(0.0, 0.13, -4.45)
	)
	for side in [-1.0, 1.0]:
		_create_wall_panel(
			_interior_root,
			"HighBaySetSideWallLeft" if side < 0.0 else "HighBaySetSideWallRight",
			Vector3(0.22, 4.2, 4.8),
			Color(0.32, 0.35, 0.37),
			Vector3(side * 6.4, 2.1, -4.85)
		)
	for mark_x in [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]:
		_create_box(
			_interior_root,
			"HighBayFloorMark_%d" % roundi(mark_x + 7.5),
			Vector3(0.10, 0.025, 3.0),
			tape_color,
			Vector3(mark_x, 0.055, -2.2)
		)
	_camera_rigs.clear()
	for camera_x in [-7.6, 0.0, 7.6]:
		_camera_rigs.append(
			_create_camera_rig(
				Vector3(camera_x, 0.0, -1.5),
				metal_color,
				equipment_color
			)
		)
	for light_x in [-8.0, -2.7, 2.7, 8.0]:
		_create_light_stand(
			Vector3(light_x, 0.0, -6.1 if absf(light_x) > 4.0 else -1.0),
			metal_color
		)
	_create_box(
		_interior_root,
		"HighBayTechnicalEquipmentRack",
		Vector3(1.7, 2.1, 0.8),
		equipment_color,
		Vector3(9.2, 1.05, 6.8)
	)
	_create_box(
		_interior_root,
		"HighBayDirectorControlDesk",
		Vector3(2.5, 1.0, 0.85),
		Color(0.20, 0.22, 0.24),
		Vector3(-9.2, 0.55, 6.8)
	)
	_create_box(
		_interior_root,
		"HighBayDirectorControlMonitor",
		Vector3(1.35, 0.72, 0.08),
		Color(0.10, 0.29, 0.37),
		Vector3(-9.2, 1.38, 6.8)
	)
	_create_film_slate()
	_workplace_points = [
		Vector3(-4.0, 0.0, -3.0),
		Vector3(0.0, 0.0, -3.0),
		Vector3(4.0, 0.0, -3.0),
		Vector3(-9.0, 0.0, 6.0),
		Vector3(9.0, 0.0, 6.0),
		Vector3(-8.5, 0.0, 1.0),
		Vector3(8.5, 0.0, 1.0),
		Vector3(-5.5, 0.0, 6.5),
		Vector3(-2.0, 0.0, 6.5),
		Vector3(2.0, 0.0, 6.5),
		Vector3(5.5, 0.0, 6.5),
		Vector3(0.0, 0.0, 3.8),
	]


func _build_medium_sound_stage_interior() -> void:
	var set_color: Color = Color(0.26, 0.29, 0.31)
	var equipment_color: Color = Color(0.11, 0.13, 0.15)
	var metal_color: Color = Color(0.34, 0.36, 0.38)
	var tape_color: Color = Color(0.88, 0.69, 0.24)
	_set_dressing_root = Node3D.new()
	_set_dressing_root.name = "SetDressing"
	_interior_root.add_child(_set_dressing_root)
	_create_wall_panel(
		_interior_root,
		"MainSetBackdrop",
		Vector3(8.2, 4.0, 0.24),
		set_color,
		Vector3(0.0, 2.0, -5.0)
	)
	_create_box(
		_interior_root,
		"SetPlatform",
		Vector3(8.2, 0.16, 3.2),
		Color(0.29, 0.28, 0.25),
		Vector3(0.0, 0.12, -2.6)
	)
	_create_wall_panel(
		_interior_root,
		"SetSideWallLeft",
		Vector3(0.18, 3.0, 2.8),
		Color(0.34, 0.32, 0.29),
		Vector3(-3.9, 1.6, -2.3)
	)
	_create_wall_panel(
		_interior_root,
		"SetSideWallRight",
		Vector3(0.18, 3.0, 2.8),
		Color(0.34, 0.32, 0.29),
		Vector3(3.9, 1.6, -2.3)
	)
	for mark_x in [-4.5, -1.5, 1.5, 4.5]:
		_create_box(
			_interior_root,
			"FloorMark",
			Vector3(0.10, 0.025, 2.0),
			tape_color,
			Vector3(mark_x, 0.055, 0.0)
		)
	_camera_rigs.clear()
	_camera_rigs.append(
		_create_camera_rig(
			Vector3(-5.0, 0.0, -0.6),
			metal_color,
			equipment_color
		)
	)
	_camera_rigs.append(
		_create_camera_rig(
			Vector3(5.0, 0.0, -0.6),
			metal_color,
			equipment_color
		)
	)
	_create_light_stand(Vector3(-5.6, 0.0, -4.1), metal_color)
	_create_light_stand(Vector3(5.6, 0.0, -4.1), metal_color)
	_create_box(
		_interior_root,
		"TechnicalEquipmentRack",
		Vector3(1.3, 1.8, 0.65),
		equipment_color,
		Vector3(6.0, 0.9, 5.0)
	)
	_create_box(
		_interior_root,
		"DirectorMonitorDesk",
		Vector3(1.8, 0.9, 0.65),
		Color(0.23, 0.20, 0.18),
		Vector3(-5.9, 0.48, 5.0)
	)
	_create_box(
		_interior_root,
		"DirectorMonitor",
		Vector3(0.85, 0.48, 0.08),
		Color(0.10, 0.25, 0.30),
		Vector3(-5.9, 1.18, 5.0)
	)
	_create_film_slate()
	_workplace_points = [
		Vector3(-1.8, 0.0, -1.6),
		Vector3(1.8, 0.0, -1.6),
		Vector3(-5.8, 0.0, 4.3),
		Vector3(-5.0, 0.0, 0.8),
		Vector3(-3.7, 0.0, 4.3),
		Vector3(4.9, 0.0, 4.7),
		Vector3(-4.2, 0.0, 1.8),
		Vector3(4.2, 0.0, 1.8),
		Vector3(-2.2, 0.0, 4.5),
		Vector3(0.0, 0.0, 4.5),
		Vector3(2.2, 0.0, 4.5),
		Vector3(0.0, 0.0, 2.2),
	]


func _build_editing_suite(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.37, 0.42, 0.45)
	var roof_color: Color = Color(0.19, 0.23, 0.26)
	var trim_color: Color = Color(0.13, 0.17, 0.19)
	var glass_color: Color = Color(0.14, 0.31, 0.38)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.34, 0.48, 0.52)
	)

	_create_floor(
		footprint,
		Color(0.24, 0.27, 0.29),
		"EditingFloor"
	)
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		1.8,
		2.65
	)

	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"EditingRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		self,
		"EditingBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		_wall_groups["front"],
		"EditingWindowLeft",
		Vector3(1.45, 1.15, 0.12),
		glass_color,
		Vector3(-3.0, 3.7, depth * 0.5 + 0.22)
	)
	_create_box(
		_wall_groups["front"],
		"EditingWindowRight",
		Vector3(1.45, 1.15, 0.12),
		glass_color,
		Vector3(3.0, 3.7, depth * 0.5 + 0.22)
	)
	_create_box(
		self,
		"EditingSuiteSign",
		Vector3(4.8, 0.55, 0.16),
		accent_color,
		Vector3(0.0, 2.85, depth * 0.5 + 0.22)
	)
	_create_label(
		self,
		"EditingSuiteSignText",
		"МОНТАЖНЫЙ ОТДЕЛ",
		Vector3(0.0, 2.85, depth * 0.5 + 0.32),
		18
	)

	_build_editing_suite_interior(width, depth)


func _build_editing_suite_interior(width: float, depth: float) -> void:
	var desk_color: Color = Color(0.22, 0.24, 0.26)
	var metal_color: Color = Color(0.15, 0.17, 0.19)
	var screen_color: Color = Color(0.08, 0.28, 0.36)
	var mixer_color: Color = Color(0.31, 0.34, 0.35)

	for slot_index in range(3):
		var desk_x: float = float(slot_index - 1) * 3.0
		_create_box(
			_interior_root,
			"EditingDesk_%d" % slot_index,
			Vector3(2.45, 0.16, 0.95),
			desk_color,
			Vector3(desk_x, 0.82, -0.55)
		)
		for leg_x in [-1.02, 1.02]:
			for leg_z in [-0.34, 0.34]:
				_create_box(
					_interior_root,
					"EditingDeskLeg_%d_%d_%d" % [
						slot_index,
						roundi(leg_x * 100.0),
						roundi(leg_z * 100.0),
					],
					Vector3(0.09, 0.78, 0.09),
					metal_color,
					Vector3(desk_x + leg_x, 0.40, -0.55 + leg_z)
				)
		_create_box(
			_interior_root,
			"EditingMonitor_%d" % slot_index,
			Vector3(0.78, 0.54, 0.08),
			screen_color,
			Vector3(desk_x - 0.43, 1.25, -0.93)
		)
		_create_box(
			_interior_root,
			"EditingPreviewMonitor_%d" % slot_index,
			Vector3(0.78, 0.54, 0.08),
			Color(0.12, 0.24, 0.30),
			Vector3(desk_x + 0.43, 1.25, -0.93)
		)
		_create_box(
			_interior_root,
			"EditingKeyboard_%d" % slot_index,
			Vector3(0.72, 0.04, 0.22),
			metal_color,
			Vector3(desk_x - 0.22, 0.93, -0.12)
		)
		_create_box(
			_interior_root,
			"AudioMixer_%d" % slot_index,
			Vector3(0.58, 0.18, 0.42),
			mixer_color,
			Vector3(desk_x + 0.76, 0.95, -0.12)
		)
		_create_cylinder(
			_interior_root,
			"EditingChairSeat_%d" % slot_index,
			0.32,
			0.12,
			metal_color,
			Vector3(desk_x, 0.48, 0.82)
		)
		_create_box(
			_interior_root,
			"EditingChairBack_%d" % slot_index,
			Vector3(0.62, 0.68, 0.12),
			Color(0.12, 0.15, 0.18),
			Vector3(desk_x, 0.86, 1.08)
		)

	_create_box(
		_interior_root,
		"EditingReferenceDisplay",
		Vector3(3.4, 1.8, 0.12),
		Color(0.07, 0.17, 0.22),
		Vector3(0.0, 2.25, -depth * 0.5 + 0.18)
	)
	_create_box(
		_interior_root,
		"AudioEquipmentRack",
		Vector3(0.82, 1.85, 0.72),
		metal_color,
		Vector3(width * 0.5 - 0.55, 0.93, -2.55)
	)
	_workplace_points = [
		Vector3(-3.0, 0.0, 1.55),
		Vector3(0.0, 0.0, 1.55),
		Vector3(3.0, 0.0, 1.55),
	]


func _build_prop_warehouse(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.42, 0.38, 0.32)
	var roof_color: Color = Color(0.22, 0.23, 0.23)
	var trim_color: Color = Color(0.16, 0.17, 0.17)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.48, 0.38, 0.25)
	)

	_create_floor(
		footprint,
		Color(0.30, 0.27, 0.22),
		"WarehouseFloor"
	)
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		2.2,
		2.65
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"WarehouseRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		self,
		"WarehouseBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		self,
		"WarehouseSign",
		Vector3(4.6, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.05, depth * 0.5 + 0.22)
	)
	_create_label(
		self,
		"WarehouseSignText",
		"СКЛАД РЕКВИЗИТА",
		Vector3(0.0, 3.05, depth * 0.5 + 0.32),
		18
	)

	var rack_color: Color = Color(0.20, 0.22, 0.22)
	var shelf_color: Color = Color(0.39, 0.31, 0.22)
	for side in [-1.0, 1.0]:
		_create_box(
			_interior_root,
			"WarehouseRackFrame_%d" % int(side),
			Vector3(0.22, 3.75, 6.0),
			rack_color,
			Vector3(side * 4.2, 1.88, -0.25)
		)
		for shelf_level in range(3):
			_create_box(
				_interior_root,
				"WarehouseShelf_%d_%d" % [int(side), shelf_level],
				Vector3(1.0, 0.14, 6.0),
				shelf_color,
				Vector3(
					side * 3.75,
					0.55 + float(shelf_level) * 1.12,
					-0.25
				)
			)
		for support_index in range(2):
			var support_z: float = -3.0 + float(support_index) * 5.5
			_create_box(
				_interior_root,
				"WarehouseSupport_%d_%d" % [int(side), support_index],
				Vector3(0.12, 3.6, 0.12),
				rack_color,
				Vector3(side * 3.75, 1.8, support_z)
			)

	_warehouse_storage_positions = [
		Vector3(-2.55, 0.0, -2.1),
		Vector3(-0.85, 0.0, -2.1),
		Vector3(0.85, 0.0, -2.1),
		Vector3(2.55, 0.0, -2.1),
		Vector3(-2.55, 0.0, 0.45),
		Vector3(-0.85, 0.0, 0.45),
		Vector3(0.85, 0.0, 0.45),
		Vector3(2.55, 0.0, 0.45),
	]
	_workplace_points = _warehouse_storage_positions.duplicate()
	_warehouse_inventory_root = Node3D.new()
	_warehouse_inventory_root.name = "WarehouseInventory"
	_interior_root.add_child(_warehouse_inventory_root)


func _build_fitness_center(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.42, 0.49, 0.51)
	var roof_color: Color = Color(0.20, 0.25, 0.29)
	var trim_color: Color = Color(0.14, 0.19, 0.23)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.28, 0.48, 0.55)
	)
	_create_floor(footprint, Color(0.22, 0.25, 0.27), "FitnessFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		3.0,
		2.8
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"FitnessCenterRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		_roof_assembly,
		"FitnessCenterSkylight",
		Vector3(4.2, 0.16, 2.0),
		Color(0.22, 0.42, 0.48),
		Vector3(0.0, height + 0.08, -1.0)
	)
	_create_box(
		self,
		"FitnessCenterSign",
		Vector3(4.8, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.05, depth * 0.5 + 0.22)
	)
	_create_label(
		self,
		"FitnessCenterSignText",
		"ФИТНЕС-ЦЕНТР",
		Vector3(0.0, 3.05, depth * 0.5 + 0.32),
		19
	)
	_create_box(
		_wall_groups["front"],
		"FitnessFrontWindowLeft",
		Vector3(1.6, 1.15, 0.12),
		Color(0.15, 0.34, 0.42),
		Vector3(-4.1, 3.1, depth * 0.5 + 0.22)
	)
	_create_box(
		_wall_groups["front"],
		"FitnessFrontWindowRight",
		Vector3(1.6, 1.15, 0.12),
		Color(0.15, 0.34, 0.42),
		Vector3(4.1, 3.1, depth * 0.5 + 0.22)
	)
	for mirror_x in [-3.2, 0.0, 3.2]:
		_create_box(
			_interior_root,
			"FitnessMirror_%d" % roundi(mirror_x + 3.2),
			Vector3(2.4, 2.3, 0.08),
			Color(0.34, 0.48, 0.52),
			Vector3(mirror_x, 2.0, -4.65)
		)
	for station_index in range(4):
		var station_x: float = -3.75 + float(station_index) * 2.5
		_create_box(
			_interior_root,
			"FitnessTreadmillBase_%d" % station_index,
			Vector3(0.92, 0.18, 1.85),
			trim_color,
			Vector3(station_x, 0.22, -2.1)
		)
		_create_box(
			_interior_root,
			"FitnessTreadmillConsole_%d" % station_index,
			Vector3(0.68, 0.78, 0.16),
			Color(0.12, 0.24, 0.29),
			Vector3(station_x, 0.92, -2.72)
		)
		_create_cylinder(
			_interior_root,
			"FitnessTreadmillHandle_%d" % station_index,
			0.045,
			0.82,
			Color(0.38, 0.43, 0.45),
			Vector3(station_x, 0.82, -1.28)
		)
	_create_box(
		_interior_root,
		"FitnessWeightRack",
		Vector3(0.65, 1.45, 3.4),
		Color(0.18, 0.22, 0.25),
		Vector3(-5.15, 0.72, 0.0)
	)
	_create_box(
		_interior_root,
		"FitnessDumbbellBench",
		Vector3(2.0, 0.32, 0.72),
		Color(0.29, 0.31, 0.33),
		Vector3(5.0, 0.48, 0.2)
	)
	_create_box(
		_interior_root,
		"FitnessMatStorage",
		Vector3(0.45, 1.6, 1.2),
		Color(0.30, 0.37, 0.36),
		Vector3(5.2, 0.8, -3.0)
	)
	_workplace_points = [
		Vector3(-3.75, 0.0, 0.15),
		Vector3(-1.25, 0.0, 0.15),
		Vector3(1.25, 0.0, 0.15),
		Vector3(3.75, 0.0, 0.15),
	]


func _build_studio_lounge(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.58, 0.56, 0.48)
	var roof_color: Color = Color(0.23, 0.27, 0.24)
	var wood_color: Color = Color(0.34, 0.25, 0.18)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.42, 0.54, 0.48)
	)
	_create_floor(footprint, Color(0.43, 0.37, 0.29), "StudioLoungeFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		3.0,
		2.8
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"StudioLoungeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		self,
		"StudioLoungeEntranceCanopy",
		Vector3(5.2, 0.22, 1.4),
		wood_color,
		Vector3(0.0, 3.05, depth * 0.5 + 0.52)
	)
	_create_box(
		self,
		"StudioLoungeSign",
		Vector3(4.6, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.1, depth * 0.5 + 0.22)
	)
	_create_label(
		self,
		"StudioLoungeSignText",
		"КЛУБ СТУДИИ",
		Vector3(0.0, 3.1, depth * 0.5 + 0.32),
		19
	)
	_create_box(
		_wall_groups["front"],
		"StudioLoungeWindowLeft",
		Vector3(1.7, 1.2, 0.12),
		Color(0.19, 0.35, 0.37),
		Vector3(-4.5, 3.2, depth * 0.5 + 0.22)
	)
	_create_box(
		_wall_groups["front"],
		"StudioLoungeWindowRight",
		Vector3(1.7, 1.2, 0.12),
		Color(0.19, 0.35, 0.37),
		Vector3(4.5, 3.2, depth * 0.5 + 0.22)
	)
	_create_box(
		_interior_root,
		"LoungeCoffeeCounter",
		Vector3(5.2, 0.92, 0.92),
		wood_color,
		Vector3(0.0, 0.52, -4.4)
	)
	_create_box(
		_interior_root,
		"LoungeCoffeeCounterTop",
		Vector3(5.45, 0.14, 1.02),
		Color(0.66, 0.57, 0.42),
		Vector3(0.0, 1.05, -4.4)
	)
	_create_box(
		_interior_root,
		"LoungeCoffeeMachine",
		Vector3(0.72, 0.78, 0.55),
		Color(0.17, 0.20, 0.22),
		Vector3(-1.55, 1.48, -4.35)
	)
	_create_box(
		_interior_root,
		"LoungeCoffeeTable",
		Vector3(1.8, 0.16, 1.1),
		wood_color,
		Vector3(0.0, 0.62, 0.15)
	)
	for sofa_index in range(2):
		var sofa_x: float = -4.5 if sofa_index == 0 else 4.5
		var sofa_suffix: String = "Left" if sofa_index == 0 else "Right"
		_create_box(
			_interior_root,
			"LoungeSofaBase" + sofa_suffix,
			Vector3(1.75, 0.55, 2.0),
			Color(0.36, 0.24, 0.27),
			Vector3(sofa_x, 0.48, 0.2)
		)
		_create_box(
			_interior_root,
			"LoungeSofaBack" + sofa_suffix,
			Vector3(1.75, 0.95, 0.24),
			Color(0.43, 0.29, 0.31),
			Vector3(sofa_x, 1.0, -0.72)
		)
		_create_box(
			_interior_root,
			"LoungeSofaArmOuter" + sofa_suffix,
			Vector3(0.22, 0.7, 1.8),
			Color(0.39, 0.27, 0.28),
			Vector3(sofa_x - 0.78, 0.65, 0.2)
		)
		_create_box(
			_interior_root,
			"LoungeSofaArmInner" + sofa_suffix,
			Vector3(0.22, 0.7, 1.8),
			Color(0.39, 0.27, 0.28),
			Vector3(sofa_x + 0.78, 0.65, 0.2)
		)
	for plant_index in range(2):
		var plant_x: float = -5.8 if plant_index == 0 else 5.8
		var plant_suffix: String = "Left" if plant_index == 0 else "Right"
		_create_cylinder(
			_interior_root,
			"LoungePlanter" + plant_suffix,
			0.42,
			0.72,
			Color(0.31, 0.25, 0.19),
			Vector3(plant_x, 0.36, -3.0)
		)
		_create_sphere(
			_interior_root,
			"LoungePlant" + plant_suffix,
			0.72,
			Color(0.18, 0.36, 0.23),
			Vector3(plant_x, 1.15, -3.0)
		)
	_workplace_points = [
		Vector3(-2.6, 0.0, -1.65),
		Vector3(0.0, 0.0, -2.15),
		Vector3(2.6, 0.0, -1.65),
		Vector3(-2.6, 0.0, 2.0),
		Vector3(0.0, 0.0, 2.4),
		Vector3(2.6, 0.0, 2.0),
	]


func _build_cafeteria(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.69, 0.61, 0.48)
	var roof_color: Color = Color(0.29, 0.25, 0.21)
	var trim_color: Color = Color(0.31, 0.24, 0.17)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.66, 0.48, 0.28)
	)

	_create_floor(footprint, Color(0.49, 0.42, 0.32), "CafeteriaFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		2.6,
		2.7
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"CafeteriaRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		self,
		"CafeteriaBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		self,
		"CafeteriaSign",
		Vector3(4.0, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.05, depth * 0.5 + 0.22)
	)
	_create_label(
		self,
		"CafeteriaSignText",
		"СТОЛОВАЯ",
		Vector3(0.0, 3.05, depth * 0.5 + 0.32),
		20
	)
	_create_box(
		_wall_groups["front"],
		"CafeteriaWindowLeft",
		Vector3(1.8, 1.2, 0.12),
		Color(0.22, 0.39, 0.43),
		Vector3(-4.5, 3.25, depth * 0.5 + 0.22)
	)
	_create_box(
		_wall_groups["front"],
		"CafeteriaWindowRight",
		Vector3(1.8, 1.2, 0.12),
		Color(0.22, 0.39, 0.43),
		Vector3(4.5, 3.25, depth * 0.5 + 0.22)
	)

	var counter_color: Color = Color(0.35, 0.25, 0.18)
	var counter_top_color: Color = Color(0.72, 0.65, 0.48)
	_create_box(
		_interior_root,
		"ServingCounter",
		Vector3(7.4, 0.95, 1.0),
		counter_color,
		Vector3(0.0, 0.55, -4.45)
	)
	_create_box(
		_interior_root,
		"ServingCounterTop",
		Vector3(7.7, 0.16, 1.12),
		counter_top_color,
		Vector3(0.0, 1.08, -4.45)
	)
	_create_box(
		_interior_root,
		"KitchenPass",
		Vector3(3.4, 1.0, 0.12),
		Color(0.16, 0.22, 0.24),
		Vector3(0.0, 2.0, -5.75)
	)
	for tray_index in range(4):
		var tray_x: float = -2.7 + float(tray_index) * 1.8
		_create_cylinder(
			_interior_root,
			"ServingTray_%d" % tray_index,
			0.28,
			0.06,
			Color(0.73, 0.72, 0.63),
			Vector3(tray_x, 1.2, -4.45)
		)

	var seat_positions: Array[Vector3] = []
	var table_centers: Array[float] = [-4.0, 0.0, 4.0]
	var table_center_z: float = 0.35
	for table_index in range(table_centers.size()):
		var center_x: float = table_centers[table_index]
		_create_box(
			_interior_root,
			"CafeteriaTable_%d" % table_index,
			Vector3(2.1, 0.16, 1.25),
			Color(0.42, 0.29, 0.19),
			Vector3(center_x, 0.82, table_center_z)
		)
		_create_box(
			_interior_root,
			"CafeteriaTableLeg_%d" % table_index,
			Vector3(0.16, 0.72, 0.16),
			trim_color,
			Vector3(center_x, 0.40, 0.35)
		)
		var table_seats: Array[Vector3] = [
			Vector3(center_x - 0.55, 0.0, table_center_z - 1.3),
			Vector3(center_x + 0.55, 0.0, table_center_z - 1.3),
			Vector3(center_x - 0.55, 0.0, table_center_z + 1.3),
			Vector3(center_x + 0.55, 0.0, table_center_z + 1.3),
		]
		for seat_index in range(table_seats.size()):
			var seat_position: Vector3 = table_seats[seat_index]
			seat_positions.append(seat_position)
			_create_cylinder(
				_interior_root,
				"CafeteriaChairSeat_%d_%d" % [table_index, seat_index],
				0.30,
				0.12,
				Color(0.23, 0.27, 0.27),
				seat_position + Vector3(0.0, 0.48, 0.0)
			)
			var chair_back_side: float = (
				-1.0 if seat_position.z < table_center_z else 1.0
			)
			_create_box(
				_interior_root,
				"CafeteriaChairBack_%d_%d" % [table_index, seat_index],
				Vector3(0.58, 0.62, 0.12),
				Color(0.23, 0.27, 0.27),
				seat_position + Vector3(0.0, 0.80, chair_back_side * 0.34)
			)
	_workplace_points = seat_positions


func _build_staff_housing(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.53, 0.48, 0.39)
	var roof_color: Color = Color(0.24, 0.29, 0.24)
	var trim_color: Color = Color(0.25, 0.29, 0.23)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.42, 0.56, 0.43)
	)

	_create_floor(footprint, Color(0.38, 0.34, 0.27), "StaffHousingFloor")
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		2.5,
		2.6
	)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"StaffHousingRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		self,
		"StaffHousingBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		self,
		"StaffHousingSign",
		Vector3(5.0, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.0, depth * 0.5 + 0.22)
	)
	_create_label(
		self,
		"StaffHousingSignText",
		"ДОМИК ПЕРСОНАЛА",
		Vector3(0.0, 3.0, depth * 0.5 + 0.32),
		18
	)
	_create_box(
		_wall_groups["front"],
		"StaffHousingWindowLeft",
		Vector3(1.7, 1.15, 0.12),
		Color(0.20, 0.34, 0.37),
		Vector3(-4.7, 3.2, depth * 0.5 + 0.22)
	)
	_create_box(
		_wall_groups["front"],
		"StaffHousingWindowRight",
		Vector3(1.7, 1.15, 0.12),
		Color(0.20, 0.34, 0.37),
		Vector3(4.7, 3.2, depth * 0.5 + 0.22)
	)

	var bed_frame_color: Color = Color(0.28, 0.20, 0.15)
	var mattress_color: Color = Color(0.68, 0.65, 0.56)
	var locker_color: Color = Color(0.24, 0.29, 0.28)
	var bed_z_positions: Array[float] = [-3.5, -1.2, 1.2, 3.5]
	var sleeping_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for bed_index in range(bed_z_positions.size()):
			var bed_z: float = bed_z_positions[bed_index]
			var bed_position := Vector3(side * 5.15, 0.0, bed_z)
			_create_box(
				_interior_root,
				"StaffBedFrame_%d_%d" % [int(side), bed_index],
				Vector3(1.55, 0.20, 1.95),
				bed_frame_color,
				bed_position + Vector3(0.0, 0.20, 0.0)
			)
			_create_box(
				_interior_root,
				"StaffBedMattress_%d_%d" % [int(side), bed_index],
				Vector3(1.42, 0.20, 1.82),
				mattress_color,
				bed_position + Vector3(0.0, 0.40, 0.0)
			)
			_create_box(
				_interior_root,
				"StaffBedPillow_%d_%d" % [int(side), bed_index],
				Vector3(0.78, 0.15, 0.46),
				Color(0.83, 0.82, 0.74),
				bed_position + Vector3(0.0, 0.56, -0.55)
			)
			_create_box(
				_interior_root,
				"StaffBedHeadboard_%d_%d" % [int(side), bed_index],
				Vector3(1.55, 0.82, 0.12),
				bed_frame_color,
				bed_position + Vector3(0.0, 0.58, -0.95)
			)
			sleeping_positions.append(
				Vector3(bed_position.x, 0.0, bed_z + 0.75)
			)
		_create_box(
			_interior_root,
			"StaffLocker_%d" % int(side),
			Vector3(0.78, 1.9, 1.0),
			locker_color,
			Vector3(side * 5.5, 0.95, 0.0)
		)
	_workplace_points = sleeping_positions


func _build_star_bungalow(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.63, 0.55, 0.43)
	var roof_color: Color = Color(0.20, 0.23, 0.27)
	var trim_color: Color = Color(0.28, 0.22, 0.17)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.66, 0.53, 0.32)
	)
	_create_floor(footprint, Color(0.48, 0.39, 0.29), "StarBungalowFloor")
	_create_perimeter_walls(width, depth, wall_height, wall_color, 2.4, 2.6)
	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"StarBungalowRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)
	_create_box(
		self,
		"StarBungalowBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		self,
		"StarBungalowSign",
		Vector3(4.8, 0.62, 0.16),
		accent_color,
		Vector3(0.0, 3.0, depth * 0.5 + 0.22)
	)
	_create_label(
		self,
		"StarBungalowSignText",
		"ЗВЁЗДНЫЙ ДОМ",
		Vector3(0.0, 3.0, depth * 0.5 + 0.32),
		18
	)
	_create_box(
		_wall_groups["front"],
		"StarBungalowWindowLeft",
		Vector3(1.7, 1.15, 0.12),
		Color(0.20, 0.34, 0.37),
		Vector3(-3.3, 3.2, depth * 0.5 + 0.22)
	)
	_create_box(
		_wall_groups["front"],
		"StarBungalowWindowRight",
		Vector3(1.7, 1.15, 0.12),
		Color(0.20, 0.34, 0.37),
		Vector3(3.3, 3.2, depth * 0.5 + 0.22)
	)
	var bed_frame_color: Color = Color(0.30, 0.22, 0.16)
	var mattress_color: Color = Color(0.77, 0.72, 0.63)
	var bed_position := Vector3(0.0, 0.0, -1.3)
	_create_box(_interior_root, "StarBedFrame", Vector3(2.05, 0.22, 2.35), bed_frame_color, bed_position + Vector3(0.0, 0.20, 0.0))
	_create_box(_interior_root, "StarBedMattress", Vector3(1.92, 0.20, 2.20), mattress_color, bed_position + Vector3(0.0, 0.41, 0.0))
	_create_box(_interior_root, "StarBedPillow", Vector3(0.95, 0.15, 0.48), Color(0.91, 0.88, 0.80), bed_position + Vector3(0.0, 0.56, -0.72))
	_create_box(_interior_root, "StarBedHeadboard", Vector3(2.05, 0.92, 0.14), bed_frame_color, bed_position + Vector3(0.0, 0.58, -1.12))
	_create_box(_interior_root, "StarWardrobe", Vector3(1.15, 2.15, 0.82), Color(0.28, 0.23, 0.20), Vector3(-3.35, 1.08, -1.25))
	_create_box(_interior_root, "StarNightstand", Vector3(0.78, 0.72, 0.68), Color(0.35, 0.25, 0.18), Vector3(2.65, 0.36, -1.3))
	_create_cylinder(_interior_root, "StarBedsideLamp", 0.12, 0.42, Color(0.86, 0.72, 0.48), Vector3(2.65, 0.91, -1.3))
	_create_box(_interior_root, "StarLoungeChair", Vector3(1.05, 0.78, 0.92), Color(0.34, 0.25, 0.25), Vector3(2.65, 0.42, 1.05))
	_workplace_points = [Vector3(0.0, 0.0, -1.3)]

func _build_script_department(
	footprint: Vector2,
	height: float,
	definition: Dictionary
) -> void:
	var width: float = footprint.x
	var depth: float = footprint.y
	var wall_height: float = height - 0.55
	var wall_color: Color = Color(0.48, 0.51, 0.53)
	var roof_color: Color = Color(0.25, 0.28, 0.31)
	var trim_color: Color = Color(0.19, 0.22, 0.25)
	var glass_color: Color = Color(0.18, 0.31, 0.39)
	var accent_color: Color = definition.get(
		"accent_color",
		Color(0.43, 0.48, 0.54)
	)

	_create_floor(
		footprint,
		Color(0.39, 0.34, 0.28),
		"OfficeFloor"
	)
	_create_perimeter_walls(
		width,
		depth,
		wall_height,
		wall_color,
		1.8,
		2.65
	)

	_roof_assembly = Node3D.new()
	_roof_assembly.name = "RoofAssembly"
	add_child(_roof_assembly)
	_create_box(
		_roof_assembly,
		"OfficeRoof",
		Vector3(width + 0.35, 0.55, depth + 0.35),
		roof_color,
		Vector3(0.0, height - 0.275, 0.0)
	)

	_create_box(
		self,
		"OfficeBaseTrim",
		Vector3(width + 0.12, 0.28, depth + 0.12),
		trim_color,
		Vector3(0.0, 0.14, 0.0)
	)
	_create_box(
		_wall_groups["front"],
		"OfficeFrontWindowLeft",
		Vector3(1.55, 1.25, 0.12),
		glass_color,
		Vector3(-2.35, 3.75, depth * 0.5 + 0.22)
	)
	_create_box(
		_wall_groups["front"],
		"OfficeFrontWindowRight",
		Vector3(1.55, 1.25, 0.12),
		glass_color,
		Vector3(2.35, 3.75, depth * 0.5 + 0.22)
	)
	_create_box(
		self,
		"OfficeSign",
		Vector3(4.6, 0.52, 0.16),
		accent_color,
		Vector3(0.0, 2.85, depth * 0.5 + 0.22)
	)
	_create_label(
		self,
		"OfficeSignText",
		"СЦЕНАРНЫЙ ОТДЕЛ",
		Vector3(0.0, 2.85, depth * 0.5 + 0.32),
		18
	)

	_build_script_department_interior(width, depth)


func _build_script_department_interior(width: float, depth: float) -> void:
	var desk_color: Color = Color(0.34, 0.23, 0.16)
	var metal_color: Color = Color(0.17, 0.19, 0.21)
	var screen_color: Color = Color(0.10, 0.27, 0.32)

	for slot_index in range(3):
		var desk_x: float = float(slot_index - 1) * 2.35
		_create_box(
			_interior_root,
			"WriterDesk",
			Vector3(1.75, 0.16, 0.85),
			desk_color,
			Vector3(desk_x, 0.82, -0.95)
		)
		for leg_x in [-0.72, 0.72]:
			for leg_z in [-0.30, 0.30]:
				_create_box(
					_interior_root,
					"DeskLeg",
					Vector3(0.09, 0.78, 0.09),
					metal_color,
					Vector3(desk_x + leg_x, 0.40, -0.95 + leg_z)
				)
		_create_box(
			_interior_root,
			"ComputerMonitor",
			Vector3(0.72, 0.48, 0.08),
			screen_color,
			Vector3(desk_x, 1.16, -1.23)
		)
		_create_box(
			_interior_root,
			"Keyboard",
			Vector3(0.58, 0.035, 0.20),
			metal_color,
			Vector3(desk_x, 0.92, -0.56)
		)
		_create_cylinder(
			_interior_root,
			"OfficeChairSeat",
			0.32,
			0.12,
			metal_color,
			Vector3(desk_x + 0.82, 0.48, 0.72)
		)
		_create_box(
			_interior_root,
			"OfficeChairBack",
			Vector3(0.58, 0.65, 0.12),
			Color(0.15, 0.18, 0.21),
			Vector3(desk_x + 0.82, 0.85, 0.97)
		)

	_workplace_points = [
		Vector3(-2.35, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(2.35, 0.0, 0.0),
	]
	_create_box(
		_interior_root,
		"Bookshelf",
		Vector3(0.55, 2.1, 2.2),
		Color(0.28, 0.20, 0.15),
		Vector3(-width * 0.5 + 0.45, 1.08, -0.55)
	)
	_create_box(
		_interior_root,
		"ResearchBoard",
		Vector3(2.1, 1.3, 0.10),
		Color(0.38, 0.40, 0.36),
		Vector3(width * 0.5 - 1.2, 2.0, -depth * 0.5 + 0.12)
	)


func _create_perimeter_walls(
	width: float,
	depth: float,
	wall_height: float,
	wall_color: Color,
	door_width: float,
	door_height: float
) -> void:
	var wall_y: float = wall_height * 0.5
	var half_width: float = width * 0.5
	var half_depth: float = depth * 0.5
	var back_group: Node3D = _create_wall_group("back")
	_create_wall_panel(back_group, "BackWall", Vector3(width, wall_height, WALL_THICKNESS), wall_color, Vector3(0.0, wall_y, -half_depth))
	var left_group: Node3D = _create_wall_group("left")
	_create_wall_panel(left_group, "LeftWall", Vector3(WALL_THICKNESS, wall_height, depth), wall_color, Vector3(-half_width, wall_y, 0.0))
	var right_group: Node3D = _create_wall_group("right")
	_create_wall_panel(right_group, "RightWall", Vector3(WALL_THICKNESS, wall_height, depth), wall_color, Vector3(half_width, wall_y, 0.0))
	var front_group: Node3D = _create_wall_group("front")
	var side_width: float = (width - door_width) * 0.5
	_create_wall_panel(front_group, "FrontWallLeft", Vector3(side_width, wall_height, WALL_THICKNESS), wall_color, Vector3(-(door_width * 0.5 + side_width * 0.5), wall_y, half_depth))
	_create_wall_panel(front_group, "FrontWallRight", Vector3(side_width, wall_height, WALL_THICKNESS), wall_color, Vector3(door_width * 0.5 + side_width * 0.5, wall_y, half_depth))
	var header_size: Vector3 = Vector3(door_width, maxf(wall_height - door_height, 0.25), WALL_THICKNESS)
	var header_position: Vector3 = Vector3(0.0, door_height + maxf(wall_height - door_height, 0.25) * 0.5, half_depth)
	_create_wall_panel(front_group, "DoorHeader", header_size, wall_color, header_position)
	_entrance_inside = Vector3(0.0, 0.0, half_depth - 0.8)
	_entrance_outside = Vector3(0.0, 0.0, half_depth + 1.4)


func _create_wall_group(group_id: String) -> Node3D:
	var group := Node3D.new()
	group.name = "%sWallGroup" % group_id.capitalize()
	_interior_root.add_child(group)
	_wall_groups[group_id] = group
	return group


func _create_floor(
	footprint: Vector2,
	color: Color,
	node_name: String
) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(
		maxf(footprint.x - 0.4, 1.0),
		maxf(footprint.y - 0.4, 1.0)
	)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position.y = 0.02
	instance.material_override = _make_material(color)
	_interior_root.add_child(instance)


func _create_film_slate() -> void:
	_create_box(
		_interior_root,
		"FilmSlateBody",
		Vector3(2.0, 1.05, 0.16),
		Color(0.075, 0.085, 0.095),
		Vector3(0.0, 1.15, 2.55)
	)
	_create_box(
		_interior_root,
		"FilmSlateClapper",
		Vector3(2.08, 0.14, 0.2),
		Color(0.72, 0.70, 0.62),
		Vector3(0.0, 1.75, 2.55)
	)

	_production_slate_label = Label3D.new()
	_production_slate_label.name = "ProductionSceneSlate"
	_production_slate_label.position = Vector3(0.0, 1.28, 2.43)
	_production_slate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_production_slate_label.font_size = 15
	_production_slate_label.outline_size = 5
	_production_slate_label.modulate = Color(0.97, 0.95, 0.88)
	_production_slate_label.no_depth_test = true
	_production_slate_label.text = "СЪЁМКИ НЕ ИДУТ"
	_interior_root.add_child(_production_slate_label)

	_production_phase_label = Label3D.new()
	_production_phase_label.name = "ProductionPhaseSlate"
	_production_phase_label.position = Vector3(0.0, 0.91, 2.43)
	_production_phase_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_production_phase_label.font_size = 11
	_production_phase_label.outline_size = 4
	_production_phase_label.modulate = Color(0.82, 0.86, 0.88)
	_production_phase_label.no_depth_test = true
	_production_phase_label.text = "ПАВИЛЬОН ГОТОВ"
	_interior_root.add_child(_production_phase_label)


func _create_camera_rig(
	local_position: Vector3,
	metal_color: Color,
	equipment_color: Color
) -> Node3D:
	var rig := Node3D.new()
	rig.name = "CameraRig_%d" % _camera_rigs.size()
	rig.position = local_position
	_interior_root.add_child(rig)
	_create_cylinder(rig, "CameraTripodBase", 0.38, 0.10, metal_color, Vector3(0.0, 0.10, 0.0))
	_create_cylinder(rig, "CameraTripodColumn", 0.075, 1.25, metal_color, Vector3(0.0, 0.72, 0.0))
	_create_box(rig, "CinemaCameraBody", Vector3(0.68, 0.48, 0.82), equipment_color, Vector3(0.0, 1.45, -0.18))
	_create_cylinder(rig, "CameraLens", 0.19, 0.42, Color(0.08, 0.10, 0.12), Vector3(0.0, 1.45, -0.78))
	return rig


func _create_light_stand(
	local_position: Vector3,
	metal_color: Color
) -> void:
	_create_cylinder(
		_interior_root,
		"LightStand",
		0.055,
		2.5,
		metal_color,
		local_position + Vector3(0.0, 1.25, 0.0)
	)
	_create_box(
		_interior_root,
		"StudioLight",
		Vector3(1.05, 0.65, 0.28),
		Color(0.73, 0.68, 0.53),
		local_position + Vector3(0.0, 2.55, -0.10)
	)


func _create_wall_panel(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> void:
	_create_box(parent, node_name, size, color, local_position)
	_create_wall_collision(parent, node_name, size, local_position)


func _create_wall_collision(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	local_position: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	body.position = local_position
	body.collision_layer = 8
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _create_hitbox() -> void:
	var building_type_id: String = str(building_data.building_type_id)
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		building_type_id,
		0.0,
		int(building_data.stage_size_tier)
	)
	var height: float = BUILDING_CATALOG_SCRIPT.get_building_height(
		building_type_id,
		int(building_data.stage_size_tier)
	)
	var body := StaticBody3D.new()
	body.name = "BuildingHitbox"
	body.collision_layer = 4
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint.x, height, footprint.y)
	collision.shape = shape
	collision.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(collision)
	add_child(body)


func _create_selection_marker() -> void:
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		str(building_data.building_type_id),
		0.0,
		int(building_data.stage_size_tier)
	)
	var marker := Node3D.new()
	marker.name = "SelectionMarker"
	marker.position.y = 0.035
	marker.visible = false
	add_child(marker)
	_selection_marker = marker
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.78, 0.22)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var thickness: float = 0.10
	_create_marker_strip(marker, "Front", Vector3(footprint.x, thickness, thickness), Vector3(0.0, 0.0, footprint.y * 0.5), material)
	_create_marker_strip(marker, "Back", Vector3(footprint.x, thickness, thickness), Vector3(0.0, 0.0, -footprint.y * 0.5), material)
	_create_marker_strip(marker, "Left", Vector3(thickness, thickness, footprint.y), Vector3(-footprint.x * 0.5, 0.0, 0.0), material)
	_create_marker_strip(marker, "Right", Vector3(thickness, thickness, footprint.y), Vector3(footprint.x * 0.5, 0.0, 0.0), material)


func _create_marker_strip(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	material: StandardMaterial3D
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)


func _create_name_tag() -> void:
	var height: float = BUILDING_CATALOG_SCRIPT.get_building_height(
		str(building_data.building_type_id),
		int(building_data.stage_size_tier)
	)
	_create_label(
		self,
		"BuildingName",
		str(building_data.display_name),
		Vector3(0.0, height + 0.55, 0.0),
		26
	)


func _create_label(
	parent: Node3D,
	node_name: String,
	label_text: String,
	local_position: Vector3,
	font_size: int
) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = label_text
	label.position = local_position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.outline_size = 6
	label.modulate = Color(0.97, 0.95, 0.88)
	label.no_depth_test = true
	parent.add_child(label)


func _create_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance


func _create_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance


func _create_sphere(
	parent: Node3D,
	node_name: String,
	radius: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _update_cutaway() -> void:
	if not is_instance_valid(_roof_assembly):
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var is_close: bool = _is_selected or (
		camera.global_position.distance_to(global_position)
		<= CUTAWAY_DISTANCE
	)
	_roof_assembly.visible = not is_close

	var visible_wall: String = ""
	if is_close:
		var camera_local: Vector3 = to_local(camera.global_position)
		if absf(camera_local.x) > absf(camera_local.z):
			visible_wall = "right" if camera_local.x > 0.0 else "left"
		else:
			visible_wall = "front" if camera_local.z > 0.0 else "back"

	for wall_id in _wall_groups:
		var wall_group: Node3D = _wall_groups[wall_id]
		wall_group.visible = not is_close or str(wall_id) != visible_wall
