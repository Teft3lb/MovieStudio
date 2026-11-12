extends RefCounted
class_name StudioBuildingData

const SCHEMA_VERSION: int = 2

var id: String = ""
var building_type_id: String = ""
var display_name: String = ""
var position: Vector3 = Vector3.ZERO
var rotation_degrees: float = 0.0
var is_operational: bool = true
var stage_size_tier: int = 2


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"building_type_id": building_type_id,
		"display_name": display_name,
		"position": {
			"x": position.x,
			"y": position.y,
			"z": position.z,
		},
		"rotation_degrees": rotation_degrees,
		"is_operational": is_operational,
		"stage_size_tier": clampi(stage_size_tier, 1, 3),
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/studio/studio_building_data.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.building_type_id = str(payload.get("building_type_id", ""))
	result.display_name = str(payload.get("display_name", ""))
	var raw_position: Variant = payload.get("position", {})
	if raw_position is Dictionary:
		result.position = Vector3(
			float(raw_position.get("x", 0.0)),
			float(raw_position.get("y", 0.0)),
			float(raw_position.get("z", 0.0))
		)
	result.rotation_degrees = fposmod(
		float(payload.get("rotation_degrees", 0.0)),
		360.0
	)
	result.is_operational = bool(payload.get("is_operational", true))
	result.stage_size_tier = clampi(
		int(payload.get("stage_size_tier", 2)),
		1,
		3
	)
	return result
