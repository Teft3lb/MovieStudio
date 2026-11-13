extends RefCounted
class_name StudioBuildingPlacementRules

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

const MIN_BUILDING_GAP: float = 1.5
const DEFAULT_PLOT_HALF_SIZE: float = 84.0
const ROAD_CENTER_X: float = 10.0
const ROAD_HALF_WIDTH: float = 2.0
const ROAD_CLEARANCE: float = 1.0
const RELEASE_DOCK_CENTER: Vector2 = Vector2(23.0, -28.0)
const RELEASE_DOCK_HALF_SIZE: Vector2 = Vector2(3.0, 2.6)


static func get_footprint(
	building_type_id: String,
	rotation_degrees: float = 0.0,
	stage_size_tier: int = 2
) -> Vector2:
	return BUILDING_CATALOG_SCRIPT.get_footprint(
		building_type_id,
		rotation_degrees,
		stage_size_tier
	)


static func can_place(
	building_type_id: String,
	world_position: Vector3,
	rotation_degrees: float,
	existing_buildings: Array,
	plot_half_size: float = DEFAULT_PLOT_HALF_SIZE,
	stage_size_tier: int = 2
) -> Dictionary:
	if not BUILDING_CATALOG_SCRIPT.has_building_type(building_type_id):
		return {"valid": false, "reason": "Неизвестный тип здания."}
	var footprint: Vector2 = get_footprint(
		building_type_id,
		rotation_degrees,
		stage_size_tier
	)
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
	var road_clearance_x: float = half_width + ROAD_HALF_WIDTH + ROAD_CLEARANCE
	var road_clearance_z: float = half_depth + plot_half_size * 0.84
	if (
		absf(world_position.x - ROAD_CENTER_X) < road_clearance_x
		and absf(world_position.z) < road_clearance_z
	):
		return {"valid": false, "reason": "Нельзя размещать здание на проезжей части или вплотную к ней."}
	if (
		absf(world_position.x - RELEASE_DOCK_CENTER.x)
			< half_width + RELEASE_DOCK_HALF_SIZE.x + MIN_BUILDING_GAP
		and absf(world_position.z - RELEASE_DOCK_CENTER.y)
			< half_depth + RELEASE_DOCK_HALF_SIZE.y + MIN_BUILDING_GAP
	):
		return {
			"valid": false,
			"reason": "Место занято пунктом выпуска фильмов.",
		}
	for existing_building in existing_buildings:
		if existing_building == null:
			continue
		var other_type_id: String = str(existing_building.building_type_id)
		var other_position: Vector3 = existing_building.position
		var other_footprint: Vector2 = get_footprint(
			other_type_id,
			float(existing_building.rotation_degrees),
			int(existing_building.stage_size_tier)
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
