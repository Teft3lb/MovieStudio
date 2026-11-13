extends RefCounted
class_name StudioBuildingNavigationController

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

var _building_data: Variant
var _interior_root: Node3D
var _navigation_system: RefCounted
var _workplace_points: Array[Vector3] = []
var _entrance_inside: Vector3 = Vector3.ZERO
var _entrance_outside: Vector3 = Vector3.ZERO
var _set_dressing_root: Node3D


func setup(
	building_data: Variant,
	interior_root: Node3D,
	navigation_system: RefCounted,
	workplace_points: Array[Vector3],
	entrance_inside: Vector3,
	entrance_outside: Vector3,
	set_dressing_root: Node3D
) -> void:
	_building_data = building_data
	_interior_root = interior_root
	_navigation_system = navigation_system
	_workplace_points = workplace_points
	_entrance_inside = entrance_inside
	_entrance_outside = entrance_outside
	_set_dressing_root = set_dressing_root


func get_workplace_position(slot_index: int) -> Vector3:
	var path: Array[Vector3] = get_workplace_path(slot_index)
	if path.is_empty():
		return _interior_root.global_position
	return path[path.size() - 1]


func get_workplace_path(slot_index: int) -> Array[Vector3]:
	var path: Array[Vector3] = []
	if _workplace_points.is_empty():
		return path
	var normalized_slot: int = clampi(slot_index, 0, _workplace_points.size() - 1)
	var building_type_id: String = str(_building_data.building_type_id)
	var slot_offset: float = _get_entrance_slot_offset(
		normalized_slot,
		building_type_id
	)
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
	# AStar can return a single point when a workstation is close to the
	# corridor; do not drop the authored destination or turn a route into
	# a three-point path that ends short of the actual workstation.
	var workplace_world_position: Vector3 = _interior_root.to_global(workplace_point)
	if path.size() == 3 or path.back().distance_to(workplace_world_position) > 0.01:
		path.append(workplace_world_position)
	return path

func _get_entrance_slot_offset(
	slot_index: int,
	building_type_id: String
) -> float:
	if slot_index < 0 or _workplace_points.is_empty():
		return 0.0
	if building_type_id in [
		"cafeteria", "staff_housing", "star_bungalow", "sound_stage",
		"tv_studio", "fitness_center", "studio_lounge",
	]:
		return 0.0
	var normalized_slot: int = clampi(
		slot_index, 0, _workplace_points.size() - 1
	)
	return (
		float(normalized_slot) - float(_workplace_points.size() - 1) * 0.5
	) * 0.22


func _resolve_exit_navigation_slot(
	local_start: Vector3,
	requested_slot_index: int
) -> int:
	if requested_slot_index >= 0 or _workplace_points.is_empty():
		return requested_slot_index
	var building_type_id: String = str(_building_data.building_type_id)
	if building_type_id not in ["staff_housing", "star_bungalow"]:
		return requested_slot_index
	var nearest_slot_index: int = 0
	var nearest_distance_squared: float = INF
	for slot_index in range(_workplace_points.size()):
		var point: Vector3 = _workplace_points[slot_index]
		var distance_squared: float = Vector2(
			local_start.x - point.x,
			local_start.z - point.z
		).length_squared()
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_slot_index = slot_index
	return nearest_slot_index

func get_exit_path_from(
	start_world_position: Vector3,
	slot_index: int = -1
) -> Array[Vector3]:
	var local_start: Vector3 = _interior_root.to_local(start_world_position)
	var resolved_slot_index: int = _resolve_exit_navigation_slot(
		local_start,
		slot_index
	)
	var slot_offset: float = _get_entrance_slot_offset(
		resolved_slot_index,
		str(_building_data.building_type_id)
	)
	var doorway_offset := Vector3(slot_offset, 0.0, 0.0)
	var inside_position: Vector3 = _entrance_inside + doorway_offset
	var indoor_path: Array[Vector3] = _navigation_system.call(
		"build_path",
		local_start,
		inside_position,
		_get_interior_navigation_obstacles(resolved_slot_index),
		0.5,
		_get_interior_navigation_bounds()
	)
	if indoor_path.is_empty():
		return []
	var result: Array[Vector3] = []
	for point in indoor_path:
		result.append(_interior_root.to_global(point))
	var outside_position: Vector3 = _interior_root.to_global(
		_entrance_outside + doorway_offset
	)
	if result.back().distance_to(outside_position) > 0.2:
		result.append(outside_position)
	return result

func _get_interior_navigation_bounds() -> Rect2:
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		str(_building_data.building_type_id),
		0.0,
		int(_building_data.stage_size_tier)
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
	match str(_building_data.building_type_id):
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
				int(_building_data.stage_size_tier)
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
					"clearance": 0.48,
				})
			obstacles.append({
				"center": Vector2(0.0, backdrop_z),
				"half_extents": Vector2(backdrop_x, 0.12),
				"clearance": 0.48,
			})
		"tv_studio":
			obstacles.append({
				"center": Vector2(0.0, -7.0),
				"half_extents": Vector2(7.0, 0.2),
				"clearance": 0.25,
			})
			obstacles.append({
				"center": Vector2(0.0, -2.5),
				"half_extents": Vector2(2.5, 0.75),
				"clearance": 0.25,
			})
			for camera_x in [-6.5, 6.5]:
				obstacles.append({
					"center": Vector2(camera_x, -1.0),
					"half_extents": Vector2(0.55, 0.55),
					"clearance": 0.25,
				})
			obstacles.append({
				"center": Vector2(0.0, 1.0),
				"half_extents": Vector2(0.55, 0.55),
				"clearance": 0.25,
			})
			for audience_row_z in [2.5, 4.5]:
				obstacles.append({
					"center": Vector2(0.0, audience_row_z),
					"half_extents": Vector2(6.2, 0.45),
					"clearance": 0.2,
				})
			obstacles.append({
				"center": Vector2(-5.0, 5.8),
				"half_extents": Vector2(2.2, 0.65),
				"clearance": 0.25,
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

func get_scene_path(
	start_world_position: Vector3,
	target_world_position: Vector3
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not BUILDING_CATALOG_SCRIPT.is_sound_stage(
		str(_building_data.building_type_id)
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
