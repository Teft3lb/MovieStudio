extends RefCounted
class_name StudioBuildingPlacementRules

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

const MIN_BUILDING_GAP: float = 1.5
const DEFAULT_PLOT_HALF_SIZE: float = 48.0


static func get_footprint(building_type_id: String, rotation_degrees: float = 0.0) -> Vector2:
	return BUILDING_CATALOG_SCRIPT.get_footprint(
		building_type_id,
		rotation_degrees
	)


static func can_place(
	building_type_id: String,
	world_position: Vector3,
	rotation_degrees: float,
	existing_buildings: Array,
	plot_half_size: float = DEFAULT_PLOT_HALF_SIZE
) -> Dictionary:
	if not BUILDING_CATALOG_SCRIPT.has_building_type(building_type_id):
		return {"valid": false, "reason": "Неизвестный тип здания."}

	var footprint: Vector2 = get_footprint(building_type_id, rotation_degrees)
	if footprint == Vector2.ZERO:
		return {"valid": false, "reason": "У здания не задан размер участка."}

	var half_width: float = footprint.x * 0.5
	var half_depth: float = footprint.y * 0.5
	if (
		world_position.x - half_width < -plot_half_size
		or world_position.x + half_width > plot_half_size
		or world_position.z - half_depth < -plot_half_size
		or world_position.z + half_depth > plot_half_size
	):
		return {"valid": false, "reason": "Здание выходит за границы территории."}

	for existing_building in existing_buildings:
		if existing_building == null:
			continue
		var other_type_id: String = str(existing_building.building_type_id)
		var other_position: Vector3 = existing_building.position
		var other_footprint: Vector2 = get_footprint(
			other_type_id,
			float(existing_building.rotation_degrees)
		)
		if other_footprint == Vector2.ZERO:
			continue

		var required_x: float = (footprint.x + other_footprint.x) * 0.5
		var required_z: float = (footprint.y + other_footprint.y) * 0.5
		if (
			absf(world_position.x - other_position.x)
				< required_x + MIN_BUILDING_GAP
			and absf(world_position.z - other_position.z)
				< required_z + MIN_BUILDING_GAP
		):
			return {
				"valid": false,
				"reason": "Недостаточно места: здание пересекается с другим объектом.",
			}

	return {"valid": true, "reason": ""}
