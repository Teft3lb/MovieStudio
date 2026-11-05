extends RefCounted
class_name StudioSetInventory

const STARTING_BUDGET: int = 3000
const LOCATION_WAREHOUSE: String = "warehouse"
const LOCATION_IN_TRANSIT_TO_STAGE: String = "in_transit_to_stage"
const LOCATION_ON_STAGE: String = "on_stage"
const LOCATION_IN_TRANSIT_TO_WAREHOUSE: String = "in_transit_to_warehouse"
const VALID_LOCATIONS: Array[String] = [
	LOCATION_WAREHOUSE,
	LOCATION_IN_TRANSIT_TO_STAGE,
	LOCATION_ON_STAGE,
	LOCATION_IN_TRANSIT_TO_WAREHOUSE,
]
const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)

var budget: int = STARTING_BUDGET
var _owned_prop_ids: Dictionary = {}
var _prop_locations: Dictionary = {}


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
	_prop_locations[prop_id] = LOCATION_WAREHOUSE
	return true


func is_owned(prop_id: String) -> bool:
	return _owned_prop_ids.has(prop_id)


func get_prop_location(prop_id: String) -> String:
	if not is_owned(prop_id):
		return ""
	return str(_prop_locations.get(prop_id, LOCATION_WAREHOUSE))


func set_prop_location(prop_id: String, new_location: String) -> bool:
	if not is_owned(prop_id) or not VALID_LOCATIONS.has(new_location):
		return false
	var current_location: String = get_prop_location(prop_id)
	if current_location == new_location:
		return true
	var valid_transition: bool = (
		(current_location == LOCATION_WAREHOUSE
			and new_location == LOCATION_IN_TRANSIT_TO_STAGE)
		or (current_location == LOCATION_IN_TRANSIT_TO_STAGE
			and new_location == LOCATION_ON_STAGE)
		or (current_location == LOCATION_ON_STAGE
			and new_location == LOCATION_IN_TRANSIT_TO_WAREHOUSE)
		or (current_location == LOCATION_IN_TRANSIT_TO_WAREHOUSE
			and new_location == LOCATION_WAREHOUSE)
	)
	if not valid_transition:
		return false
	_prop_locations[prop_id] = new_location
	return true


func get_prop_ids_at_location(location: String) -> Array[String]:
	var result: Array[String] = []
	if not VALID_LOCATIONS.has(location):
		return result
	for prop_id in get_owned_prop_ids():
		if get_prop_location(prop_id) == location:
			result.append(prop_id)
	return result


func get_props_in_warehouse() -> Array[String]:
	return get_prop_ids_at_location(LOCATION_WAREHOUSE)


func get_props_on_stage() -> Array[String]:
	return get_prop_ids_at_location(LOCATION_ON_STAGE)


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
		"prop_locations": _prop_locations.duplicate(true),
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
				result._prop_locations[prop_id] = LOCATION_WAREHOUSE
	var raw_locations: Variant = payload.get("prop_locations", {})
	if raw_locations is Dictionary:
		for prop_id_value in result._owned_prop_ids.keys():
			var prop_id: String = str(prop_id_value)
			var location: String = str(
				raw_locations.get(prop_id, LOCATION_WAREHOUSE)
			)
			if VALID_LOCATIONS.has(location):
				result._prop_locations[prop_id] = location
	return result
