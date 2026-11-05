extends "res://tests/smoke_test_base.gd"

const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)
const SET_INVENTORY_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_inventory.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var inventory: RefCounted = SET_INVENTORY_SCRIPT.new()
	_expect(
		int(inventory.budget) == 3000,
		"Set Dressing Workshop must begin with its documented prototype budget."
	)
	_expect(
		bool(inventory.call("purchase", "lighthouse_console", 420)),
		"An affordable catalog prop must be purchasable."
	)
	_expect(
		bool(inventory.call("purchase", "lighthouse_beacon", 330)),
		"A second prop from the same set must be purchasable."
	)
	_expect(
		bool(inventory.call("purchase", "lighthouse_rail", 240)),
		"A third prop from the same set must be purchasable."
	)
	_expect(
		int(inventory.budget) == 2010,
		"Purchases must deduct the catalog prices from the workshop budget."
	)
	_expect(
		not bool(inventory.call("purchase", "lighthouse_console", 420)),
		"An already-owned prop must not be purchased twice."
	)
	_expect(
		not bool(inventory.call("purchase", "unknown_prop", 1)),
		"Unknown prop IDs must be rejected."
	)
	_expect(
		not bool(inventory.call("purchase", "street_lamp", 1)),
		"Caller-supplied prices must match the catalog price."
	)

	var scenes: Array[Dictionary] = [
		{
			"scene_id": "SCN-LIGHTHOUSE-01",
			"location": "Старый маяк",
			"action": "Герои обнаруживают странный сигнал.",
		},
		{
			"scene_id": "SCN-LIGHTHOUSE-02",
			"location": "Верхняя площадка маяка",
			"action": "Герои принимают решение.",
		},
		{
			"scene_id": "SCN-STREET-01",
			"location": "Ночная улица",
			"action": "Герой ищет свидетеля.",
		},
	]
	_expect(
		SET_CATALOG_SCRIPT.get_group_for_scene(scenes[0]) == "lighthouse"
		and SET_CATALOG_SCRIPT.get_group_for_scene(scenes[1]) == "lighthouse",
		"Specific lighthouse locations must map to the lighthouse set group."
	)
	_expect(
		SET_CATALOG_SCRIPT.get_group_for_scene(scenes[2]) == "city_street",
		"Street locations must map to the city street set group."
	)
	var owned_props: Array[String] = inventory.get_owned_prop_ids()
	var setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		scenes,
		owned_props
	)
	_expect(
		setups.size() == scenes.size(),
		"Every script scene must receive one stable set setup plan."
	)
	if setups.size() >= 3:
		_expect(
			str(setups[0].get("set_id", "")) == "lighthouse"
			and setups[0].get("prop_ids", []).size() == 3
			and int(setups[0].get("setup_minutes", 0)) == 5,
			"Owned props must create a reusable lighthouse setup and extend setup time."
		)
		_expect(
			setups[0].get("prop_ids", []) == setups[1].get("prop_ids", []),
			"Matching scenes must reuse the same purchased props."
		)
		_expect(
			str(setups[2].get("set_id", "")) == "neutral"
			and setups[2].get("prop_ids", []).is_empty(),
			"Unowned set groups must use the neutral stage without consuming props."
		)
	_expect(
		inventory.get_owned_prop_ids().size() == 3,
		"Building scene plans must not consume reusable purchased props."
	)

	var restored: Variant = SET_INVENTORY_SCRIPT.from_dict(
		inventory.to_dict()
	)
	_expect(
		int(restored.budget) == int(inventory.budget)
		and restored.get_owned_prop_ids() == inventory.get_owned_prop_ids(),
		"Set budget and owned prop IDs must survive inventory serialization."
	)

	_finish_test("StudioSetInventorySmokeTest")
