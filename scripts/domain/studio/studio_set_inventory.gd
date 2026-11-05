extends RefCounted
class_name StudioSetInventory

const STARTING_BUDGET: int = 3000
const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)

var budget: int = STARTING_BUDGET
var _owned_prop_ids: Dictionary = {}


func purchase(prop_id: String, price: int) -> bool:
	var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(prop_id)
	if (
		definition.is_empty()
		or price != int(definition.get("price", -1))
		or _owned_prop_ids.has(prop_id)
	):
		return false
	if budget < price:
		return false
	budget -= price
	_owned_prop_ids[prop_id] = true
	return true


func is_owned(prop_id: String) -> bool:
	return _owned_prop_ids.has(prop_id)


func get_owned_prop_ids() -> Array[String]:
	var result: Array[String] = []
	for prop_id_value in _owned_prop_ids.keys():
		result.append(str(prop_id_value))
	result.sort()
	return result


func to_dict() -> Dictionary:
	return {
		"budget": budget,
		"owned_prop_ids": get_owned_prop_ids(),
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/studio/studio_set_inventory.gd"
	).new()
	result.budget = maxi(int(payload.get("budget", STARTING_BUDGET)), 0)
	var raw_owned: Variant = payload.get("owned_prop_ids", [])
	if raw_owned is Array:
		for prop_id_value in raw_owned:
			var prop_id: String = str(prop_id_value)
			if (
				not prop_id.is_empty()
				and not SET_CATALOG_SCRIPT.get_prop_definition(prop_id).is_empty()
			):
				result._owned_prop_ids[prop_id] = true
	return result
