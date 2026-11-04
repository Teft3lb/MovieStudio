extends RefCounted
class_name StudioBuildingCatalog

const BUILDINGS: Dictionary = {
	"script_department": {
		"title": "Сценарный отдел",
		"description": "Рабочее пространство сценаристов для разработки историй и подготовки сценариев.",
		"footprint": Vector2(8.0, 6.0),
		"building_height": 6.2,
		"workplace_capacity": 3,
		"accepted_professions": [
			"screenwriter", "producer", "casting_director",
		],
		"primary_profession": "screenwriter",
		"accent_color": Color(0.43, 0.48, 0.54),
	},
	"sound_stage": {
		"title": "Съёмочный павильон",
		"description": "Закрытая площадка для съёмки сцен с актёрами и съёмочной группой.",
		"footprint": Vector2(14.0, 12.0),
		"building_height": 7.0,
		"workplace_capacity": 8,
		"accepted_professions": [
			"actor", "extra", "director", "camera_operator",
			"technician", "production_designer", "producer",
		],
		"primary_profession": "director",
		"accent_color": Color(0.53, 0.43, 0.33),
	},
}

static func get_building_type_ids() -> Array[String]:
	var result: Array[String] = []
	for building_type_id in BUILDINGS.keys():
		result.append(str(building_type_id))
	result.sort()
	return result


static func has_building_type(building_type_id: String) -> bool:
	return BUILDINGS.has(building_type_id)


static func get_definition(building_type_id: String) -> Dictionary:
	if not BUILDINGS.has(building_type_id):
		return {}
	var definition: Dictionary = BUILDINGS[building_type_id]
	return definition.duplicate(true)


static func get_title(building_type_id: String) -> String:
	var definition: Dictionary = get_definition(building_type_id)
	return str(definition.get("title", "Неизвестное здание"))


static func get_description(building_type_id: String) -> String:
	var definition: Dictionary = get_definition(building_type_id)
	return str(definition.get("description", ""))


static func get_footprint(building_type_id: String, rotation_degrees: float = 0.0) -> Vector2:
	var definition: Dictionary = get_definition(building_type_id)
	var footprint: Vector2 = definition.get("footprint", Vector2.ZERO)
	var normalized_rotation: int = posmod(roundi(rotation_degrees / 90.0), 2)
	return Vector2(footprint.y, footprint.x) if normalized_rotation == 1 else footprint


static func get_workplace_capacity(building_type_id: String) -> int:
	var definition: Dictionary = get_definition(building_type_id)
	return maxi(int(definition.get("workplace_capacity", 0)), 0)


static func get_accepted_professions(building_type_id: String) -> Array[String]:
	var result: Array[String] = []
	var definition: Dictionary = get_definition(building_type_id)
	var raw_professions: Array = definition.get("accepted_professions", [])
	for profession_id in raw_professions:
		result.append(str(profession_id))
	return result


static func accepts_profession(building_type_id: String, profession_id: String) -> bool:
	return get_accepted_professions(building_type_id).has(profession_id)
