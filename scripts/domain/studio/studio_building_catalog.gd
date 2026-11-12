extends RefCounted
class_name StudioBuildingCatalog

const STAGE_FOOTPRINTS: Dictionary = {
	1: Vector2(10.0, 8.0),
	2: Vector2(14.0, 12.0),
	3: Vector2(22.0, 18.0),
}
const STAGE_HEIGHTS: Dictionary = {1: 5.8, 2: 7.0, 3: 9.0}
const STAGE_WORKPLACE_CAPACITIES: Dictionary = {1: 6, 2: 8, 3: 12}

const BUILDINGS: Dictionary = {
	"cafeteria": {
		"title": "Столовая",
		"description": "Общая столовая студии: сотрудники приходят сюда во время личного обеденного перерыва, чтобы поесть и восстановить силы.",
		"footprint": Vector2(14.0, 12.0),
		"building_height": 5.8,
		"workplace_capacity": 0,
		"facility_capacity": 12,
		"accepted_professions": [],
		"primary_profession": "",
		"accent_color": Color(0.66, 0.48, 0.28),
	},
	"script_department": {
		"title": "Сценарный отдел",
		"description": "Рабочее пространство сценаристов для разработки историй и подготовки сценариев.",
		"footprint": Vector2(8.0, 6.0),
		"building_height": 6.2,
		"workplace_capacity": 3,
		"accepted_professions": ["screenwriter", "producer", "casting_director"],
		"primary_profession": "screenwriter",
		"accent_color": Color(0.43, 0.48, 0.54),
	},
	"editing_suite": {
		"title": "Монтажный отдел",
		"description": "Рабочее пространство монтажёров для сборки фильма, сведения звука и цветокоррекции.",
		"footprint": Vector2(10.0, 8.0),
		"building_height": 6.2,
		"workplace_capacity": 3,
		"accepted_professions": ["film_editor"],
		"primary_profession": "film_editor",
		"accent_color": Color(0.34, 0.48, 0.52),
	},
	"prop_warehouse": {
		"title": "Склад реквизита",
		"description": "Складское помещение для хранения, выдачи и возврата многоразовых декораций.",
		"footprint": Vector2(10.0, 8.0),
		"building_height": 6.2,
		"workplace_capacity": 0,
		"accepted_professions": [],
		"primary_profession": "",
		"accent_color": Color(0.48, 0.38, 0.25),
	},
	"staff_housing": {
		"title": "Домик персонала",
		"description": "Жилой корпус с отдельными спальными местами. После смены сотрудники приходят сюда отдыхать и восстанавливать энергию.",
		"footprint": Vector2(14.0, 12.0),
		"building_height": 5.8,
		"workplace_capacity": 0,
		"facility_capacity": 8,
		"accepted_professions": [],
		"primary_profession": "",
		"accent_color": Color(0.42, 0.56, 0.43),
	},
	"star_bungalow": {
		"title": "Звёздный домик",
		"description": "Отдельное жильё для популярного актёра: приватная спальня и повышенное восстановление энергии после смены.",
		"footprint": Vector2(10.0, 8.0),
		"building_height": 5.8,
		"workplace_capacity": 0,
		"facility_capacity": 1,
		"accepted_professions": [],
		"primary_profession": "",
		"accent_color": Color(0.66, 0.53, 0.32),
	},
	"fitness_center": {
		"title": "Фитнес-центр",
		"description": "Тренировочное пространство с кардио- и силовыми станциями. Актёры приходят сюда после смены, постепенно улучшают физическую форму, расходуют энергию и снимают напряжение.",
		"footprint": Vector2(12.0, 10.0),
		"building_height": 5.8,
		"workplace_capacity": 0,
		"facility_capacity": 4,
		"accepted_professions": [],
		"primary_profession": "",
		"accent_color": Color(0.28, 0.48, 0.55),
	},
	"studio_lounge": {
		"title": "Клуб студии",
		"description": "Общее пространство отдыха с мягкой мебелью и кофейной зоной. Сотрудники общаются, снижают стресс и постепенно укрепляют личные отношения.",
		"footprint": Vector2(14.0, 12.0),
		"building_height": 5.8,
		"workplace_capacity": 0,
		"facility_capacity": 6,
		"accepted_professions": [],
		"primary_profession": "",
		"accent_color": Color(0.42, 0.54, 0.48),
	},
	"tv_studio": {
		"title": "Телевизионная студия",
		"description": "Отдельный телевизионный павильон с многокамерной площадкой, местами для аудитории, ведущего, гостей и аппаратной режиссёра. Используется для сериалов и регулярных ток-шоу.",
		"footprint": Vector2(20.0, 16.0),
		"building_height": 8.8,
		"workplace_capacity": 10,
		"facility_capacity": 0,
		"accepted_professions": [
			"actor", "extra", "director", "camera_operator",
			"technician", "producer", "production_designer",
			"screenwriter",
		],
		"primary_profession": "director",
		"accent_color": Color(0.12, 0.48, 0.62),
	},
	"sound_stage": {
		"title": "Съёмочный павильон",
		"description": "Закрытая съёмочная площадка. Размер павильона определяет площадь, число рабочих мест и максимальный масштаб постановки.",
		"footprint": Vector2(14.0, 12.0),
		"building_height": 7.0,
		"workplace_capacity": 8,
		"facility_capacity": 0,
		"stage_size_tier": 2,
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
	return BUILDINGS[building_type_id].duplicate(true)


static func get_title(building_type_id: String) -> String:
	var definition: Dictionary = get_definition(building_type_id)
	return str(definition.get("title", "Неизвестное здание"))


static func get_description(building_type_id: String) -> String:
	var definition: Dictionary = get_definition(building_type_id)
	return str(definition.get("description", ""))


static func is_sound_stage(building_type_id: String) -> bool:
	return building_type_id == "sound_stage"


static func get_stage_size_tier(stage_size_tier: int) -> int:
	return clampi(stage_size_tier, 1, 3)


static func get_stage_size_title(stage_size_tier: int) -> String:
	match get_stage_size_tier(stage_size_tier):
		1:
			return "Малый"
		3:
			return "Большой"
		_:
			return "Средний"


static func get_stage_footprint(stage_size_tier: int) -> Vector2:
	return STAGE_FOOTPRINTS[get_stage_size_tier(stage_size_tier)]


static func get_stage_height(stage_size_tier: int) -> float:
	return float(STAGE_HEIGHTS[get_stage_size_tier(stage_size_tier)])


static func get_stage_workplace_capacity(stage_size_tier: int) -> int:
	return int(STAGE_WORKPLACE_CAPACITIES[get_stage_size_tier(stage_size_tier)])


static func get_footprint(
	building_type_id: String,
	rotation_degrees: float = 0.0,
	stage_size_tier: int = 2
) -> Vector2:
	var footprint: Vector2
	if is_sound_stage(building_type_id):
		footprint = get_stage_footprint(stage_size_tier)
	else:
		var definition: Dictionary = get_definition(building_type_id)
		footprint = definition.get("footprint", Vector2.ZERO)
	var normalized_rotation: int = posmod(roundi(rotation_degrees / 90.0), 2)
	return Vector2(footprint.y, footprint.x) if normalized_rotation == 1 else footprint


static func get_building_height(
	building_type_id: String,
	stage_size_tier: int = 2
) -> float:
	if is_sound_stage(building_type_id):
		return get_stage_height(stage_size_tier)
	var definition: Dictionary = get_definition(building_type_id)
	return float(definition.get("building_height", 6.0))


static func get_workplace_capacity(building_type_id: String) -> int:
	if is_sound_stage(building_type_id):
		return get_stage_workplace_capacity(2)
	var definition: Dictionary = get_definition(building_type_id)
	return maxi(int(definition.get("workplace_capacity", 0)), 0)


static func get_workplace_capacity_for_building(building: Variant) -> int:
	if building == null:
		return 0
	var building_type_id: String = str(building.building_type_id)
	if is_sound_stage(building_type_id):
		return get_stage_workplace_capacity(int(building.stage_size_tier))
	return get_workplace_capacity(building_type_id)


static func get_facility_capacity(building_type_id: String) -> int:
	var definition: Dictionary = get_definition(building_type_id)
	return maxi(int(definition.get("facility_capacity", 0)), 0)


static func get_accepted_professions(building_type_id: String) -> Array[String]:
	var result: Array[String] = []
	var definition: Dictionary = get_definition(building_type_id)
	var raw_professions: Array = definition.get("accepted_professions", [])
	for profession_id in raw_professions:
		result.append(str(profession_id))
	return result


static func accepts_profession(building_type_id: String, profession_id: String) -> bool:
	return get_accepted_professions(building_type_id).has(profession_id)
