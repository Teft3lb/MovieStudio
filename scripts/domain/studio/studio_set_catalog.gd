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

const GENRE_DEFAULT_GROUPS: Dictionary = {
	"drama": "family_home",
	"comedy": "city_street",
	"action": "industrial",
	"romance": "family_home",
	"mystery": "office",
	"adventure": "forest",
	"science_fiction": "science_fiction",
}
const MISSING_PROP_QUALITY_PENALTY: float = 10.0

const PROP_DIMENSIONS: Dictionary = {
	"street_storefront": {"size_class": "large", "required_stage_tier": 3, "footprint": Vector2(3.6, 1.4)},
	"street_lamp": {"size_class": "small", "required_stage_tier": 1, "footprint": Vector2(0.7, 0.7)},
	"street_bench": {"size_class": "small", "required_stage_tier": 1, "footprint": Vector2(1.7, 0.7)},
	"home_sofa": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(2.0, 1.1)},
	"home_coffee_table": {"size_class": "small", "required_stage_tier": 1, "footprint": Vector2(1.4, 0.9)},
	"home_floor_lamp": {"size_class": "small", "required_stage_tier": 1, "footprint": Vector2(0.6, 0.6)},
	"forest_trees": {"size_class": "large", "required_stage_tier": 3, "footprint": Vector2(4.0, 3.0)},
	"forest_rocks": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(2.2, 1.8)},
	"forest_trail_sign": {"size_class": "small", "required_stage_tier": 1, "footprint": Vector2(1.0, 0.5)},
	"lighthouse_console": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(1.8, 1.0)},
	"lighthouse_beacon": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(1.2, 1.2)},
	"lighthouse_rail": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(2.0, 0.5)},
	"industrial_crates": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(1.8, 1.5)},
	"industrial_pipes": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(2.0, 1.1)},
	"industrial_work_light": {"size_class": "small", "required_stage_tier": 1, "footprint": Vector2(0.9, 0.8)},
	"office_desk": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(1.8, 1.0)},
	"office_bookshelf": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(1.5, 0.7)},
	"office_evidence_board": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(1.7, 0.4)},
	"scifi_lab_console": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(1.8, 1.0)},
	"scifi_reactor": {"size_class": "large", "required_stage_tier": 3, "footprint": Vector2(1.5, 1.5)},
	"scifi_holo_display": {"size_class": "medium", "required_stage_tier": 2, "footprint": Vector2(1.3, 0.9)},
};

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
	var definition: Dictionary = PROPS[prop_id].duplicate(true)
	var dimensions: Dictionary = PROP_DIMENSIONS.get(prop_id, {})
	definition.merge(dimensions, true)
	return definition


static func get_group_for_scene(
	scene: Dictionary,
	genre_id: String = ""
) -> String:
	var location_context: String = str(
		scene.get("location", "")
	).to_lower()
	var action_context: String = str(
		scene.get("action", "")
	).to_lower()
	var location_group: String = _match_scene_context(location_context)
	if not location_group.is_empty():
		return location_group

	var action_group: String = _match_scene_context(action_context)
	if not action_group.is_empty():
		return action_group

	return str(GENRE_DEFAULT_GROUPS.get(genre_id, ""))


static func _match_scene_context(context: String) -> String:
	if _contains_any(context, [
		"космос", "орбит", "космич", "лаборатор", "науч",
		"будущ", "исследовательск", "командн", "реактор", "станци",
	]):
		return "science_fiction"
	if _contains_any(context, [
		"промышленный порт", "грузовой порт", "портовый",
		"завод", "склад", "фабрик", "промышлен", "цех", "верф", "док",
	]):
		return "industrial"
	if _contains_any(context, [
		"маяк", "побереж", "морск", "море", "берег", "пляж", "пристан",
	]):
		return "lighthouse"
	if _contains_any(context, [
		"дом", "гостин", "квартир", "семь", "спальн",
		"кухн", "отел", "прачеч",
	]):
		return "family_home"
	if _contains_any(context, [
		"лес", "полян", "сад", "парк", "природ", "дерев",
		"горн", "перевал", "храм", "пещер", "троп",
	]):
		return "forest"
	if _contains_any(context, [
		"офис", "полиц", "участок", "кабинет",
		"больнич", "больниц", "медицин", "клиник",
		"архив", "следств",
	]):
		return "office"
	if _contains_any(context, [
		"улиц", "город", "переул", "площад", "кафе", "ресторан",
		"вокзал", "шоссе", "небоскр", "переход", "набереж",
		"театр", "магаз",
	]):
		return "city_street"
	return ""


static func build_scene_setups(
	scenes: Array,
	owned_prop_ids: Array[String],
	genre_id: String = "",
	technician_count: int = 1
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var effective_technician_count: int = clampi(technician_count, 1, 8)
	for scene_value in scenes:
		var scene: Dictionary = scene_value
		var group_id: String = get_group_for_scene(scene, genre_id)
		var required_props: Array[String] = get_prop_ids_for_group(group_id)
		var selected_props: Array[String] = []
		var missing_props: Array[String] = []
		var quality: float = 45.0
		var required_stage_tier: int = 1
		for prop_id in required_props:
			if owned_prop_ids.has(prop_id):
				selected_props.append(prop_id)
				var definition: Dictionary = get_prop_definition(prop_id)
				quality += float(definition.get("quality_bonus", 0))
				required_stage_tier = maxi(
					required_stage_tier,
					int(definition.get("required_stage_tier", 1))
				)
			else:
				missing_props.append(prop_id)
				quality -= MISSING_PROP_QUALITY_PENALTY
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
			"required_prop_ids": required_props,
			"missing_prop_ids": missing_props,
			"required_stage_tier": required_stage_tier,
			"setup_minutes": 2 + ceili(
				float(selected_props.size()) / float(effective_technician_count)
			),
			"set_dressing_quality": clampf(quality, 15.0, 80.0),
		})
	return result


static func get_size_class_title(size_class: String) -> String:
	match size_class:
		"small":
			return "Компактный"
		"large":
			return "Крупный"
		_:
			return "Средний"


static func get_required_stage_tier(
	scenes: Array,
	owned_prop_ids: Array[String],
	genre_id: String = ""
) -> int:
	var required_tier: int = 1
	if scenes.size() > 12:
		required_tier = 3
	elif scenes.size() > 5:
		required_tier = 2
	for scene_value in scenes:
		var scene: Dictionary = scene_value
		var group_id: String = get_group_for_scene(scene, genre_id)
		for prop_id in get_prop_ids_for_group(group_id):
			if not owned_prop_ids.has(prop_id):
				continue
			var definition: Dictionary = get_prop_definition(prop_id)
			required_tier = maxi(
				required_tier,
				int(definition.get("required_stage_tier", 1))
			)
	return required_tier


static func _contains_any(value: String, fragments: Array[String]) -> bool:
	for fragment in fragments:
		if value.contains(fragment):
			return true
	return false
