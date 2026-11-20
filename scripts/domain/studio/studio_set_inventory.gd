extends RefCounted
class_name StudioSetInventory

const STARTING_BUDGET: int = 3000
const MAX_BUDGET: int = 999999999
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
var _prop_condition: Dictionary = {}
var _prop_film_usage_ids: Dictionary = {}


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
	_prop_condition[prop_id] = 100.0
	_prop_film_usage_ids[prop_id] = []
	return true


func spend_funds(amount: int) -> bool:
	if amount <= 0 or budget < amount:
		return false
	budget -= amount
	return true


func add_funds(amount: int) -> bool:
	if amount <= 0 or budget >= MAX_BUDGET:
		return false
	budget = mini(budget + amount, MAX_BUDGET)
	return true


func is_owned(prop_id: String) -> bool:
	return _owned_prop_ids.has(prop_id)


func get_prop_location(prop_id: String) -> String:
	if not is_owned(prop_id):
		return ""
	return str(_prop_locations.get(prop_id, LOCATION_WAREHOUSE))


func get_prop_condition(prop_id: String) -> float:
	if not is_owned(prop_id):
		return 0.0
	return clampf(float(_prop_condition.get(prop_id, 100.0)), 0.0, 100.0)


func get_prop_film_usage_count(
	prop_id: String,
	exclude_film_id: String = ""
) -> int:
	if not is_owned(prop_id):
		return 0
	var raw_ids: Variant = _prop_film_usage_ids.get(prop_id, [])
	if not (raw_ids is Array):
		return 0
	var usage_count: int = raw_ids.size()
	if not exclude_film_id.is_empty() and raw_ids.has(exclude_film_id):
		usage_count -= 1
	return maxi(usage_count, 0)


func get_prop_condition_map() -> Dictionary:
	var result: Dictionary = {}
	for prop_id in get_owned_prop_ids():
		result[prop_id] = get_prop_condition(prop_id)
	return result


func get_prop_film_usage_count_map(
	exclude_film_id: String = ""
) -> Dictionary:
	var result: Dictionary = {}
	for prop_id in get_owned_prop_ids():
		result[prop_id] = get_prop_film_usage_count(
			prop_id, exclude_film_id
		)
	return result


func record_prop_use(
	prop_id: String,
	film_id: String,
	wear_amount: float = 7.5
) -> bool:
	if (
		not is_owned(prop_id)
		or get_prop_location(prop_id) != LOCATION_ON_STAGE
		or film_id.is_empty()
		or wear_amount <= 0.0
	):
		return false
	_prop_condition[prop_id] = clampf(
			get_prop_condition(prop_id) - wear_amount,
			0.0,
			100.0
	)
	var usage_ids: Array = _prop_film_usage_ids.get(prop_id, []).duplicate()
	if not usage_ids.has(film_id):
		usage_ids.append(film_id)
	_prop_film_usage_ids[prop_id] = usage_ids
	return true


func repair_prop(prop_id: String, repair_amount: float) -> float:
	if (
		not is_owned(prop_id)
		or get_prop_location(prop_id) != LOCATION_WAREHOUSE
		or repair_amount <= 0.0
	):
		return 0.0
	var previous_condition: float = get_prop_condition(prop_id)
	var repaired_condition: float = minf(
		previous_condition + repair_amount,
		100.0
	)
	_prop_condition[prop_id] = repaired_condition
	return repaired_condition - previous_condition


func get_prop_resale_value(prop_id: String) -> int:
	if not is_owned(prop_id):
		return 0
	var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(prop_id)
	var original_price: int = int(definition.get("price", 0))
	var condition_factor: float = get_prop_condition(prop_id) / 100.0
	return maxi(roundi(float(original_price) * (0.20 + condition_factor * 0.30)), 0)


func sell_prop(prop_id: String) -> int:
	if (
		not is_owned(prop_id)
		or get_prop_location(prop_id) != LOCATION_WAREHOUSE
	):
		return 0
	var resale_value: int = get_prop_resale_value(prop_id)
	if resale_value <= 0 or not add_funds(resale_value):
		return 0
	_owned_prop_ids.erase(prop_id)
	_prop_locations.erase(prop_id)
	_prop_condition.erase(prop_id)
	_prop_film_usage_ids.erase(prop_id)
	return resale_value


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
		"prop_condition": _prop_condition.duplicate(true),
		"prop_film_usage_ids": _prop_film_usage_ids.duplicate(true),
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
				result._prop_condition[prop_id] = 100.0
				result._prop_film_usage_ids[prop_id] = []
	var raw_locations: Variant = payload.get("prop_locations", {})
	if raw_locations is Dictionary:
		for prop_id_value in result._owned_prop_ids.keys():
			var prop_id: String = str(prop_id_value)
			var location: String = str(
				raw_locations.get(prop_id, LOCATION_WAREHOUSE)
			)
			if VALID_LOCATIONS.has(location):
				result._prop_locations[prop_id] = location
	var raw_conditions: Variant = payload.get("prop_condition", {})
	if raw_conditions is Dictionary:
		for prop_id_value in result._owned_prop_ids.keys():
			var prop_id: String = str(prop_id_value)
			result._prop_condition[prop_id] = clampf(
				float(raw_conditions.get(prop_id, 100.0)),
				0.0,
				100.0
			)
	var raw_usage: Variant = payload.get("prop_film_usage_ids", {})
	if raw_usage is Dictionary:
		for prop_id_value in result._owned_prop_ids.keys():
			var prop_id: String = str(prop_id_value)
			var raw_ids: Variant = raw_usage.get(prop_id, [])
			var usage_ids: Array = []
			if raw_ids is Array:
				for film_id_value in raw_ids:
					var film_id: String = str(film_id_value)
					if not film_id.is_empty() and not usage_ids.has(film_id):
						usage_ids.append(film_id)
			result._prop_film_usage_ids[prop_id] = usage_ids
	return result
