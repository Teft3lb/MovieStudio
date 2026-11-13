extends RefCounted
class_name CharacterManualActivityPolicy

# Temporary drag-and-drop orders. These never alter employment, contracts,
# permanent workplace assignments, or the existing production systems.
const BUILDING_CATALOG = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

const ACTIVITY_CONFIG: Dictionary = {
	"studio_lounge": {
		"title": "Отдых в клубе",
		"action": "socializing",
		"minutes": 60,
		"stress": -0.0025,
		"energy": 0.0003,
		"morale": 0.0005,
	},
	"cafeteria": {
		"title": "Перекус в столовой",
		"action": "eating",
		"minutes": 35,
		"stress": -0.0010,
		"energy": 0.0020,
		"morale": 0.0002,
	},
	"fitness_center": {
		"title": "Тренировка",
		"action": "training",
		"minutes": 60,
		"stress": -0.0005,
		"energy": -0.0012,
		"morale": 0.0003,
		"fitness": 0.006,
	},
	"staff_housing": {
		"title": "Отдых в домике",
		"action": "sleeping",
		"minutes": 90,
		"stress": -0.0015,
		"energy": 0.0020,
		"morale": 0.0002,
	},
	"star_bungalow": {
		"title": "Отдых в звёздном домике",
		"action": "sleeping",
		"minutes": 90,
		"stress": -0.0018,
		"energy": 0.0025,
		"morale": 0.0003,
	},
	"sound_stage": {
		"title": "Репетиция в павильоне",
		"action": "rehearsing",
		"minutes": 75,
		"energy": -0.0007,
		"stress": 0.0001,
		"xp": 0.42,
	},
	"tv_studio": {
		"title": "Репетиция телесцены",
		"action": "rehearsing",
		"minutes": 75,
		"energy": -0.0007,
		"stress": 0.0001,
		"xp": 0.42,
	},
	"script_department": {
		"title": "Практика сценарного мастерства",
		"action": "working",
		"minutes": 60,
		"energy": -0.0006,
		"xp": 0.30,
	},
	"editing_suite": {
		"title": "Практика монтажа",
		"action": "working",
		"minutes": 60,
		"energy": -0.0006,
		"xp": 0.30,
	},
	"prop_warehouse": {
		"title": "Практика работы с реквизитом",
		"action": "placing_set_piece",
		"minutes": 50,
		"energy": -0.0007,
		"xp": 0.28,
	},
}


func get_activity(building_type: String, profession_id: String) -> Dictionary:
	if not ACTIVITY_CONFIG.has(building_type):
		return {}
	if building_type in ["sound_stage", "tv_studio"]:
		if profession_id not in ["actor", "extra", "director"]:
			return {}
	elif building_type in ["script_department", "editing_suite"]:
		if not BUILDING_CATALOG.accepts_profession(building_type, profession_id):
			return {}
	elif building_type == "prop_warehouse" and profession_id != "technician":
		return {}
	var result: Dictionary = ACTIVITY_CONFIG[building_type].duplicate(true)
	result["building_type"] = building_type
	result["skill"] = ""
	match building_type:
		"sound_stage", "tv_studio":
			result["skill"] = "directing" if profession_id == "director" else "acting"
		"script_department":
			result["skill"] = "writing" if profession_id == "screenwriter" else "management"
		"editing_suite":
			result["skill"] = "editing"
		"prop_warehouse":
			result["skill"] = "technical"
	return result


func apply_minute(
	employee: Variant,
	activity: Dictionary,
	skill_progression: RefCounted
) -> void:
	if employee == null or activity.is_empty():
		return
	var needs: Dictionary = employee.needs.duplicate(true)
	for stat_id in ["stress", "energy", "morale"]:
		if not activity.has(stat_id):
			continue
		needs[stat_id] = clampf(
			float(needs.get(stat_id, 0.5)) + float(activity[stat_id]),
			0.0, 1.0
		)
	employee.needs = needs
	if activity.has("fitness"):
		employee.physical_fitness = clampf(
			float(employee.physical_fitness) + float(activity["fitness"]),
			0.0, 100.0
		)
	var skill_id: String = str(activity.get("skill", ""))
	if (
		not skill_id.is_empty()
		and employee.skills.has(skill_id)
		and skill_progression != null
	):
		# Use the existing capped experience progression. No free 100% skills.
		skill_progression.call(
			"award_skill_experience",
			employee, skill_id, float(activity.get("xp", 0.0))
		)
