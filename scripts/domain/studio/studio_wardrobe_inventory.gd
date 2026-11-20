extends RefCounted
class_name StudioWardrobeInventory

const COSTUME_CATALOG_SCRIPT = preload("res://scripts/domain/studio/studio_costume_catalog.gd")

var _owned_costume_ids: Dictionary = {}


func purchase(costume_id: String, funds: Variant) -> bool:
	var definition: Dictionary = COSTUME_CATALOG_SCRIPT.get_costume_definition(costume_id)
	if definition.is_empty() or _owned_costume_ids.has(costume_id) or funds == null or not funds.has_method("spend_funds"):
		return false
	var price: int = int(definition.get("price", 0))
	if price <= 0 or not bool(funds.call("spend_funds", price)):
		return false
	_owned_costume_ids[costume_id] = true
	return true


func sell(costume_id: String, funds: Variant) -> int:
	if not _owned_costume_ids.has(costume_id) or funds == null or not funds.has_method("add_funds"):
		return 0
	var resale_value: int = get_resale_value(costume_id)
	if resale_value <= 0 or not bool(funds.call("add_funds", resale_value)):
		return 0
	_owned_costume_ids.erase(costume_id)
	return resale_value


func is_owned(costume_id: String) -> bool:
	return _owned_costume_ids.has(costume_id)


func get_owned_costume_ids() -> Array[String]:
	var result: Array[String] = []
	for costume_id_value in _owned_costume_ids.keys():
		result.append(str(costume_id_value))
	result.sort()
	return result


func get_resale_value(costume_id: String) -> int:
	if not is_owned(costume_id):
		return 0
	var definition: Dictionary = COSTUME_CATALOG_SCRIPT.get_costume_definition(costume_id)
	return maxi(roundi(float(definition.get("price", 0)) * 0.4), 0)


func get_costume_ids_for_genre(genre_id: String) -> Array[String]:
	var best_id: String = ""
	var best_bonus: float = -1.0
	for costume_id in get_owned_costume_ids():
		var definition: Dictionary = COSTUME_CATALOG_SCRIPT.get_costume_definition(costume_id)
		var supported_genres: Array = definition.get("genre_ids", [])
		if not supported_genres.has(genre_id):
			continue
		var bonus: float = float(definition.get("quality_bonus", 0.0))
		if bonus > best_bonus:
			best_bonus = bonus
			best_id = costume_id
	var result: Array[String] = []
	if not best_id.is_empty():
		result.append(best_id)
	return result


func get_costume_quality_bonus_for_genre(genre_id: String) -> float:
	var costume_ids: Array[String] = get_costume_ids_for_genre(genre_id)
	if costume_ids.is_empty():
		return 0.0
	var definition: Dictionary = COSTUME_CATALOG_SCRIPT.get_costume_definition(costume_ids[0])
	return clampf(float(definition.get("quality_bonus", 0.0)), 0.0, 10.0)


func to_dict() -> Dictionary:
	return {"owned_costume_ids": get_owned_costume_ids()}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load("res://scripts/domain/studio/studio_wardrobe_inventory.gd").new()
	var raw_ids: Variant = payload.get("owned_costume_ids", [])
	if raw_ids is Array:
		for costume_id_value in raw_ids:
			var costume_id: String = str(costume_id_value)
			if not COSTUME_CATALOG_SCRIPT.get_costume_definition(costume_id).is_empty():
				result._owned_costume_ids[costume_id] = true
	return result
