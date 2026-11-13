extends RefCounted
class_name StudioBuildingMarkerProvider

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

var _building_data: Variant
var _interior_root: Node3D
var _workplace_points: Array[Vector3] = []
var _warehouse_storage_positions: Array[Vector3] = []


func setup(
	building_data: Variant,
	interior_root: Node3D,
	workplace_points: Array[Vector3],
	warehouse_storage_positions: Array[Vector3]
) -> void:
	_building_data = building_data
	_interior_root = interior_root
	_workplace_points = workplace_points
	_warehouse_storage_positions = warehouse_storage_positions


func get_workplace_facing_direction(slot_index: int) -> Vector3:
	if _workplace_points.is_empty():
		return Vector3.ZERO
	var normalized_slot: int = clampi(
		slot_index,
		0,
		_workplace_points.size() - 1
	)
	var building_type_id: String = str(_building_data.building_type_id)
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
		"tv_studio":
			if normalized_slot <= 2:
				target_position = (
					_workplace_points[normalized_slot]
					+ Vector3(0.0, 0.0, 1.8)
				)
			elif normalized_slot in [4, 5]:
				target_position = Vector3(0.0, 0.0, -3.0)
			else:
				target_position = Vector3(0.0, 0.0, -2.0)
		_:
			return Vector3.ZERO
	var local_direction: Vector3 = (
		target_position - _workplace_points[normalized_slot]
	)
	local_direction.y = 0.0
	if local_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return (_interior_root.global_basis * local_direction).normalized()

func get_scene_mark(
	slot_index: int,
	phase_id: String = "preparation",
	scene_index: int = 0
) -> Vector3:
	var stage_tier: int = BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
		int(_building_data.stage_size_tier)
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
		int(_building_data.stage_size_tier)
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
		int(_building_data.stage_size_tier)
	):
		1:
			focus_point = Vector3(0.0, 1.25, -2.75)
		3:
			focus_point = Vector3(0.0, 1.8, -6.0)
	return _interior_root.to_global(focus_point)

func get_set_dressing_mark(prop_index: int) -> Vector3:
	var positions: Array[Vector3] = get_set_dressing_positions()
	var index: int = clampi(prop_index, 0, positions.size() - 1)
	return _interior_root.to_global(positions[index])

func get_set_dressing_positions() -> Array[Vector3]:
	match BUILDING_CATALOG_SCRIPT.get_stage_size_tier(
		int(_building_data.stage_size_tier)
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

func get_storage_mark(prop_index: int) -> Vector3:
	if _warehouse_storage_positions.is_empty():
		return _interior_root.global_position
	var index: int = posmod(prop_index, _warehouse_storage_positions.size())
	return _interior_root.to_global(_warehouse_storage_positions[index])
