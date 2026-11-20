extends RefCounted
class_name FilmMarketingSystem

const MAX_CAMPAIGNS_PER_FILM: int = 3
const CAMPAIGN_ORDER: Array[String] = ["local", "regional", "national"]
const CAMPAIGNS: Dictionary = {
	"local": {"title": "Локальная кампания", "price": 250, "success_bonus": 4.0, "description": "Реклама на территории города и рядом со студией."},
	"regional": {"title": "Региональная кампания", "price": 600, "success_bonus": 8.0, "description": "Продвижение фильма на региональную аудиторию."},
	"national": {"title": "Национальная кампания", "price": 1200, "success_bonus": 14.0, "description": "Широкая рекламная кампания с максимальным охватом."},
}


func get_campaign_ids() -> Array[String]:
	return CAMPAIGN_ORDER.duplicate()


func get_campaign_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for campaign_id in CAMPAIGN_ORDER:
		result.append(get_campaign_definition(campaign_id))
	return result


func get_campaign_definition(campaign_id: String) -> Dictionary:
	if not CAMPAIGNS.has(campaign_id):
		return {}
	var result: Dictionary = CAMPAIGNS[campaign_id].duplicate(true)
	result["id"] = campaign_id
	return result


func get_campaign_cost(campaign_id: String) -> int:
	var definition: Dictionary = get_campaign_definition(campaign_id)
	return maxi(int(definition.get("price", 0)), 0)


func apply_campaign_to_project(project: Variant, campaign_id: String) -> Dictionary:
	if project == null or str(project.status) != "completed":
		return {"success": false, "reason": "Фильм ещё не завершён."}
	var definition: Dictionary = get_campaign_definition(campaign_id)
	if definition.is_empty():
		return {"success": false, "reason": "Неизвестный тип рекламной кампании."}
	var campaign_count: int = int(project.marketing_campaign_count)
	if campaign_count >= MAX_CAMPAIGNS_PER_FILM:
		return {"success": false, "reason": "Для этого фильма уже проведены все доступные кампании."}
	var bonus: float = _get_campaign_bonus(definition, campaign_count)
	project.marketing_campaign_count = campaign_count + 1
	project.marketing_bonus = clampf(float(project.marketing_bonus) + bonus, 0.0, 30.0)
	project.marketing_spend = maxi(int(project.marketing_spend) + int(definition.price), 0)
	project.commercial_success_score = clampi(roundi(float(project.final_quality) + float(project.marketing_bonus)), 0, 100)
	return {
		"success": true,
		"campaign_title": str(definition.title),
		"cost": int(definition.price),
		"bonus": bonus,
		"campaign_count": int(project.marketing_campaign_count),
		"commercial_success_score": int(project.commercial_success_score),
	}


func apply_campaign_to_record(editing_record: Dictionary, campaign_id: String) -> Dictionary:
	if str(editing_record.get("status", "")) != "completed":
		return {"success": false, "reason": "Фильм ещё не завершён."}
	var definition: Dictionary = get_campaign_definition(campaign_id)
	if definition.is_empty():
		return {"success": false, "reason": "Неизвестный тип рекламной кампании."}
	var campaign_count: int = int(editing_record.get("marketing_campaign_count", 0))
	if campaign_count >= MAX_CAMPAIGNS_PER_FILM:
		return {"success": false, "reason": "Для этого фильма уже проведены все доступные кампании."}
	var bonus: float = _get_campaign_bonus(definition, campaign_count)
	var marketing_bonus: float = clampf(float(editing_record.get("marketing_bonus", 0.0)) + bonus, 0.0, 30.0)
	var final_quality: int = clampi(int(editing_record.get("final_quality", 0)), 0, 100)
	var commercial_success: int = clampi(roundi(float(final_quality) + marketing_bonus), 0, 100)
	editing_record["marketing_campaign_count"] = campaign_count + 1
	editing_record["marketing_bonus"] = marketing_bonus
	editing_record["marketing_spend"] = maxi(int(editing_record.get("marketing_spend", 0)) + int(definition.price), 0)
	editing_record["commercial_success_score"] = commercial_success
	return {
		"success": true,
		"campaign_title": str(definition.title),
		"cost": int(definition.price),
		"bonus": bonus,
		"campaign_count": campaign_count + 1,
		"commercial_success_score": commercial_success,
	}


func _get_campaign_bonus(definition: Dictionary, previous_campaign_count: int) -> float:
	var diminishing_multipliers: Array[float] = [1.0, 0.6, 0.3]
	var multiplier: float = diminishing_multipliers[clampi(previous_campaign_count, 0, diminishing_multipliers.size() - 1)]
	return float(definition.get("success_bonus", 0.0)) * multiplier
