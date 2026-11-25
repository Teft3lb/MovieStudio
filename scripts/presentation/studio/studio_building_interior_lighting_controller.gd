extends RefCounted
class_name StudioBuildingInteriorLightingController

const UPDATE_INTERVAL: float = 0.45

var _building: Node3D
var _footprint: Vector2 = Vector2.ZERO
var _lamps: Array[OmniLight3D] = []
var _elapsed: float = 0.0
var _occupied: bool = false


func setup(
	building: Node3D,
	interior_root: Node3D,
	footprint: Vector2,
	height: float,
	building_type_id: String
) -> void:
	_building = building
	_footprint = footprint
	var split_light: bool = footprint.x >= 12.0 or building_type_id in ["editing_suite", "script_department"]
	var columns: int = 2 if split_light else 1
	var rows: int = 2 if footprint.y >= 15.0 else 1
	var technical := building_type_id in ["sound_stage", "tv_studio", "editing_suite"]
	var residential := building_type_id in ["staff_housing", "star_bungalow", "studio_lounge"]
	for col in range(columns):
		for row in range(rows):
			var lamp := OmniLight3D.new()
			lamp.name = "InteriorWorkLight_%d_%d" % [col, row]
			lamp.position = Vector3(
				(float(col) - float(columns - 1) * 0.5) * footprint.x * 0.48,
				maxf(height - 1.5, 2.6),
				(float(row) - float(rows - 1) * 0.5) * footprint.y * 0.48
			)
			lamp.omni_range = maxf(footprint.x, footprint.y) * 0.79
			lamp.light_energy = 1.28 if split_light else 1.68
			lamp.light_color = Color(1.0, .89, .74)
			if technical:
				lamp.light_color = Color(.83, .91, 1.0) if col == 0 else Color(1.0, .93, .81)
			elif residential:
				lamp.light_color = Color(1.0, .81, .62) if col == 0 else Color(1.0, .94, .84)
			# Many studios can exist at once. Keep the lights unshadowed:
			# collision geometry already controls employee movement.
			lamp.shadow_enabled = false
			lamp.visible = false
			interior_root.add_child(lamp)
			_lamps.append(lamp)


func advance(delta: float) -> void:
	if not is_instance_valid(_building):
		return
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	var present: bool = false
	for employee in _building.get_tree().get_nodes_in_group("studio_employee"):
		var actor: Node3D = employee as Node3D
		if not is_instance_valid(actor):
			continue
		var local: Vector3 = _building.to_local(actor.global_position)
		if (
			absf(local.x) <= _footprint.x * 0.5 - 0.2
			and absf(local.z) <= _footprint.y * 0.5 - 0.2
		):
			present = true
			break
	set_occupied(present)


func set_occupied(value: bool) -> void:
	if _occupied == value:
		return
	_occupied = value
	for lamp in _lamps:
		if is_instance_valid(lamp):
			lamp.visible = _occupied


func is_occupied() -> bool:
	return _occupied


func get_light_count() -> int:
	return _lamps.size()
