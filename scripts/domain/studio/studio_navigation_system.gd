extends RefCounted
class_name StudioNavigationSystem

const DEFAULT_CELL_SIZE: float = 0.75
const DEFAULT_CLEARANCE: float = 0.48


func build_path(
	start_position: Vector3,
	target_position: Vector3,
	obstacles: Array,
	cell_size: float = DEFAULT_CELL_SIZE,
	bounds: Rect2 = Rect2()
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var step: float = maxf(cell_size, 0.25)
	var origin: Vector2
	var grid_size: Vector2i

	if bounds.has_area():
		origin = Vector2(
			floorf(bounds.position.x / step) * step,
			floorf(bounds.position.y / step) * step
		)
		grid_size = Vector2i(
			maxi(ceili((bounds.end.x - origin.x) / step) + 1, 8),
			maxi(ceili((bounds.end.y - origin.y) / step) + 1, 8)
		)
	else:
		var min_x: float = minf(start_position.x, target_position.x) - 5.0
		var max_x: float = maxf(start_position.x, target_position.x) + 5.0
		var min_z: float = minf(start_position.z, target_position.z) - 5.0
		var max_z: float = maxf(start_position.z, target_position.z) + 5.0
		for obstacle_value in obstacles:
			if not (obstacle_value is Dictionary):
				continue
			var obstacle: Dictionary = obstacle_value
			var center: Vector2 = obstacle.get("center", Vector2.ZERO)
			var half_extents: Vector2 = obstacle.get(
				"half_extents",
				Vector2.ONE
			)
			min_x = minf(min_x, center.x - half_extents.x - 2.0)
			max_x = maxf(max_x, center.x + half_extents.x + 2.0)
			min_z = minf(min_z, center.y - half_extents.y - 2.0)
			max_z = maxf(max_z, center.y + half_extents.y + 2.0)
		origin = Vector2(
			floorf(min_x / step) * step,
			floorf(min_z / step) * step
		)
		grid_size = Vector2i(
			maxi(ceili((max_x - origin.x) / step) + 1, 8),
			maxi(ceili((max_z - origin.y) / step) + 1, 8)
		)

	var astar := AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, grid_size)
	astar.cell_size = Vector2(step, step)
	astar.offset = origin
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	var clearance: float = maxf(step * 0.55, DEFAULT_CLEARANCE)
	for x in range(grid_size.x):
		for z in range(grid_size.y):
			var point_id := Vector2i(x, z)
			var point: Vector2 = astar.get_point_position(point_id)
			if _is_blocked(point, obstacles, clearance):
				astar.set_point_solid(point_id, true)

	var start_id: Vector2i = _get_cell_id(
		Vector2(start_position.x, start_position.z),
		origin,
		step
	)
	var target_id: Vector2i = _get_cell_id(
		Vector2(target_position.x, target_position.z),
		origin,
		step
	)
	start_id = _find_nearest_open_cell(astar, start_id, grid_size)
	target_id = _find_nearest_open_cell(astar, target_id, grid_size)
	if start_id.x < 0 or target_id.x < 0:
		return result

	var id_path: Array[Vector2i] = astar.get_id_path(start_id, target_id)
	if id_path.is_empty():
		return result

	result.append(start_position)
	var path_points: Array[Vector2] = []
	for point_id in id_path:
		path_points.append(astar.get_point_position(point_id))
	var smoothed: Array[Vector2] = _smooth_path(
		Vector2(start_position.x, start_position.z),
		path_points,
		obstacles,
		clearance,
		step
	)
	for point in smoothed:
		var world_point := Vector3(point.x, start_position.y, point.y)
		if result.back().distance_to(world_point) > 0.25:
			result.append(world_point)
	if result.back().distance_to(target_position) > 0.25:
		result.append(target_position)
	else:
		result[result.size() - 1] = target_position
	return result


func _get_cell_id(point: Vector2, origin: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(
		roundi((point.x - origin.x) / cell_size),
		roundi((point.y - origin.y) / cell_size)
	)


func _find_nearest_open_cell(
	astar: AStarGrid2D,
	start_id: Vector2i,
	grid_size: Vector2i
) -> Vector2i:
	if (
		start_id.x >= 0
		and start_id.y >= 0
		and start_id.x < grid_size.x
		and start_id.y < grid_size.y
		and not astar.is_point_solid(start_id)
	):
		return start_id

	for radius in range(1, 9):
		var best_id := Vector2i(-1, -1)
		var best_distance: float = INF
		for x_offset in range(-radius, radius + 1):
			for y_offset in range(-radius, radius + 1):
				if maxi(abs(x_offset), abs(y_offset)) != radius:
					continue
				var candidate := start_id + Vector2i(x_offset, y_offset)
				if (
					candidate.x < 0
					or candidate.y < 0
					or candidate.x >= grid_size.x
					or candidate.y >= grid_size.y
					or astar.is_point_solid(candidate)
				):
					continue
				var distance: float = Vector2(
					x_offset,
					y_offset
				).length_squared()
				if distance < best_distance:
					best_distance = distance
					best_id = candidate
		if best_id.x >= 0:
			return best_id
	return Vector2i(-1, -1)


func _is_blocked(
	point: Vector2,
	obstacles: Array,
	clearance: float
) -> bool:
	for obstacle_value in obstacles:
		if not (obstacle_value is Dictionary):
			continue
		var obstacle: Dictionary = obstacle_value
		var center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var half_extents: Vector2 = obstacle.get(
			"half_extents",
			Vector2.ONE
		)
		var extra_clearance: float = float(
			obstacle.get("clearance", clearance)
		)
		if (
			absf(point.x - center.x) <= half_extents.x + extra_clearance
			and absf(point.y - center.y) <= half_extents.y + extra_clearance
		):
			return true
	return false


func _smooth_path(
	start: Vector2,
	path_points: Array[Vector2],
	obstacles: Array,
	clearance: float,
	cell_size: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if path_points.is_empty():
		return result
	var current: Vector2 = start
	var index: int = 0
	while index < path_points.size():
		var furthest: int = index
		for candidate_index in range(index + 1, path_points.size()):
			if _has_clear_line(
				current,
				path_points[candidate_index],
				obstacles,
				clearance,
				cell_size
			):
				furthest = candidate_index
			else:
				break
		var next_point: Vector2 = path_points[furthest]
		if current.distance_to(next_point) > 0.25:
			result.append(next_point)
		current = next_point
		index = furthest + 1
	return result


func _has_clear_line(
	start: Vector2,
	finish: Vector2,
	obstacles: Array,
	clearance: float,
	cell_size: float
) -> bool:
	var distance: float = start.distance_to(finish)
	var sample_count: int = maxi(
		ceili(distance / maxf(cell_size * 0.35, 0.15)),
		1
	)
	for sample_index in range(1, sample_count):
		var point: Vector2 = start.lerp(
			finish,
			float(sample_index) / float(sample_count)
		)
		if _is_blocked(point, obstacles, clearance):
			return false
	return true
