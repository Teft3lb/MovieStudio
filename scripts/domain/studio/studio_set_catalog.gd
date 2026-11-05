extends RefCounted
class_name StudioSetCatalog

const GROUP_ORDER: Array[String] = [
	"city_street",
	"family_home",
	"forest",
	"lighthouse",
	"industrial",
	"office",
	"science_fiction",
]

const GROUPS: Dictionary = {
	"city_street": {"title": "Городская улица"},
	"family_home": {"title": "Семейный дом"},
	"forest": {"title": "Лес и природа"},
	"lighthouse": {"title": "Старый маяк"},
	"industrial": {"title": "Промышленная зона"},
	"office": {"title": "Офис и участок"},
	"science_fiction": {"title": "Научная фантастика"},
}

const PROPS: Dictionary = {
	"street_storefront": {
		"title": "Фасад магазина", "group_id": "city_street",
		"price": 420, "quality_bonus": 7,
	},
	"street_lamp": {
		"title": "Уличный фонарь", "group_id": "city_street",
		"price": 230, "quality_bonus": 5,
	},
	"street_bench": {
		"title": "Городская скамейка", "group_id": "city_street",
		"price": 180, "quality_bonus": 4,
	},
	"home_sofa": {
		"title": "Диван", "group_id": "family_home",
		"price": 280, "quality_bonus": 5,
	},
	"home_coffee_table": {
		"title": "Журнальный столик", "group_id": "family_home",
		"price": 160, "quality_bonus": 3,
	},
	"home_floor_lamp": {
		"title": "Торшер", "group_id": "family_home",
		"price": 140, "quality_bonus": 3,
	},
	"forest_trees": {
		"title": "Группа деревьев", "group_id": "forest",
		"price": 320, "quality_bonus": 6,
	},
	"forest_rocks": {
		"title": "Каменная россыпь", "group_id": "forest",
		"price": 190, "quality_bonus": 4,
	},
	"forest_trail_sign": {
		"title": "Указатель тропы", "group_id": "forest",
		"price": 150, "quality_bonus": 3,
	},
	"lighthouse_console": {
		"title": "Пульт смотрителя", "group_id": "lighthouse",
		"price": 420, "quality_bonus": 7,
	},
	"lighthouse_beacon": {
		"title": "Сигнальный огонь", "group_id": "lighthouse",
		"price": 330, "quality_bonus": 6,
	},
	"lighthouse_rail": {
		"title": "Ограждение маяка", "group_id": "lighthouse",
		"price": 240, "quality_bonus": 4,
	},
	"industrial_crates": {
		"title": "Грузовые ящики", "group_id": "industrial",
		"price": 220, "quality_bonus": 4,
	},
	"industrial_pipes": {
		"title": "Промышленные трубы", "group_id": "industrial",
		"price": 310, "quality_bonus": 5,
	},
	"industrial_work_light": {
		"title": "Рабочий прожектор", "group_id": "industrial",
		"price": 180, "quality_bonus": 4,
	},
	"office_desk": {
		"title": "Рабочий стол", "group_id": "office",
		"price": 260, "quality_bonus": 4,
	},
	"office_bookshelf": {
		"title": "Книжный шкаф", "group_id": "office",
		"price": 180, "quality_bonus": 3,
	},
	"office_evidence_board": {
		"title": "Доска улик", "group_id": "office",
		"price": 220, "quality_bonus": 5,
	},
	"scifi_lab_console": {
		"title": "Лабораторная консоль", "group_id": "science_fiction",
		"price": 390, "quality_bonus": 6,
	},
	"scifi_reactor": {
		"title": "Реактор", "group_id": "science_fiction",
		"price": 420, "quality_bonus": 8,
	},
	"scifi_holo_display": {
		"title": "Голографический экран", "group_id": "science_fiction",
		"price": 290, "quality_bonus": 6,
	},
}


static func get_group_ids() -> Array[String]:
	return GROUP_ORDER.duplicate()


static func get_group_title(group_id: String) -> String:
	var group: Dictionary = GROUPS.get(group_id, {})
	return str(group.get("title", "Нейтральная площадка"))


static func get_prop_ids_for_group(group_id: String) -> Array[String]:
	var result: Array[String] = []
	for prop_id_value in PROPS.keys():
		var prop_id: String = str(prop_id_value)
		if str(PROPS[prop_id].get("group_id", "")) == group_id:
			result.append(prop_id)
	result.sort()
	return result


static func get_prop_definition(prop_id: String) -> Dictionary:
	if not PROPS.has(prop_id):
		return {}
	return PROPS[prop_id].duplicate(true)


static func get_group_for_scene(scene: Dictionary) -> String:
	var location_context: String = str(
		scene.get("location", "")
	).to_lower()
	var action_context: String = str(
		scene.get("action", "")
	).to_lower()
	var location_group: String = _match_scene_context(location_context)
	if not location_group.is_empty():
		return location_group
	return _match_scene_context(action_context)


static func _match_scene_context(context: String) -> String:
	if _contains_any(context, ["улиц", "город", "переул", "магаз", "площадь", "кафе", "ресторан", "вокзал"]):
		return "city_street"
	if _contains_any(context, ["дом", "гостин", "квартир", "семь", "спальн", "кухн", "отель"]):
		return "family_home"
	if _contains_any(context, ["лес", "полян", "сад", "парк", "природ", "дерев"]):
		return "forest"
	if _contains_any(context, ["маяк", "побереж", "берег", "море", "порт", "пляж"]):
		return "lighthouse"
	if _contains_any(context, ["завод", "склад", "фабрик", "промышлен", "цех"]):
		return "industrial"
	if _contains_any(context, ["офис", "полиц", "участок", "кабинет", "больниц"]):
		return "office"
	if _contains_any(context, ["космос", "лаборатор", "науч", "будущ", "космич"]):
		return "science_fiction"
	return ""


static func build_scene_setups(
	scenes: Array,
	owned_prop_ids: Array[String]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for scene_value in scenes:
		var scene: Dictionary = scene_value
		var group_id: String = get_group_for_scene(scene)
		var selected_props: Array[String] = []
		var quality: float = 45.0
		for prop_id in get_prop_ids_for_group(group_id):
			if not owned_prop_ids.has(prop_id):
				continue
			selected_props.append(prop_id)
			var definition: Dictionary = get_prop_definition(prop_id)
			quality += float(definition.get("quality_bonus", 0))
		var set_id: String = group_id if not selected_props.is_empty() else "neutral"
		var set_title: String = (
			get_group_title(group_id)
			if not selected_props.is_empty()
			else "Нейтральная площадка"
		)
		result.append({
			"scene_id": str(scene.get("scene_id", "")),
			"set_id": set_id,
			"source_group_id": group_id,
			"set_title": set_title,
			"prop_ids": selected_props,
			"setup_minutes": 2 + selected_props.size(),
			"set_dressing_quality": clampf(quality, 45.0, 80.0),
		})
	return result


static func _contains_any(value: String, fragments: Array[String]) -> bool:
	for fragment in fragments:
		if value.contains(fragment):
			return true
	return false
