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
	var location_cases: Array[Dictionary] = [
		{"location": "Городская площадь", "expected": "city_street"},
		{"location": "Семейный дом", "expected": "family_home"},
		{"location": "Вокзал", "expected": "city_street"},
		{"location": "Больничный коридор", "expected": "office"},
		{"location": "Больничная палата", "expected": "office"},
		{"location": "Медицинская клиника", "expected": "office"},
		{"location": "Набережная", "expected": "city_street"},
		{"location": "Гостиничный холл", "expected": "family_home"},
		{"location": "Офис", "expected": "office"},
		{"location": "Ресторан", "expected": "city_street"},
		{"location": "Прачечная", "expected": "family_home"},
		{"location": "Городская улица", "expected": "city_street"},
		{"location": "Промышленный порт", "expected": "industrial"},
		{"location": "Крыша небоскрёба", "expected": "city_street"},
		{"location": "Подземный переход", "expected": "city_street"},
		{"location": "Склад", "expected": "industrial"},
		{"location": "Шоссе", "expected": "city_street"},
		{"location": "Кафе у вокзала", "expected": "city_street"},
		{"location": "Парк", "expected": "forest"},
		{"location": "Театр", "expected": "city_street"},
		{"location": "Старый книжный магазин", "expected": "city_street"},
		{"location": "Архив", "expected": "office"},
		{"location": "Полицейский участок", "expected": "office"},
		{"location": "Старая гостиница", "expected": "family_home"},
		{"location": "Ночной переулок", "expected": "city_street"},
		{"location": "Частный кабинет", "expected": "office"},
		{"location": "Горный перевал", "expected": "forest"},
		{"location": "Заброшенный храм", "expected": "forest"},
		{"location": "Лесная тропа", "expected": "forest"},
		{"location": "Морской берег", "expected": "lighthouse"},
		{"location": "Пещера", "expected": "forest"},
		{"location": "Исследовательская станция", "expected": "science_fiction"},
		{"location": "Орбитальный модуль", "expected": "science_fiction"},
		{"location": "Подземная лаборатория", "expected": "science_fiction"},
		{"location": "Город будущего", "expected": "science_fiction"},
		{"location": "Командный центр", "expected": "science_fiction"},
	]
	for location_case in location_cases:
		_expect(
			SET_CATALOG_SCRIPT.get_group_for_scene({
				"location": str(location_case.get("location", "")),
			}) == str(location_case.get("expected", "")),
			"Generated location %s must map to %s."
			% [
				str(location_case.get("location", "")),
				str(location_case.get("expected", "")),
			]
		)
	_expect(
		SET_CATALOG_SCRIPT.get_group_for_scene(
			{"location": "Заброшенная шахта"},
			"action"
		) == "industrial",
		"Unrecognized action scenes must use their genre's fallback set group."
	)

	var owned_props: Array[String] = inventory.get_owned_prop_ids()
	var setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		scenes,
		owned_props,
		"adventure"
	)
	_expect(
		setups.size() == scenes.size(),
		"Every script scene must receive one stable set setup plan."
	)
	if setups.size() >= 3:
		_expect(
			str(setups[0].get("set_id", "")) == "lighthouse"
			and setups[0].get("prop_ids", []).size() == 3
			and setups[0].get("required_prop_ids", []).size() == 3
			and setups[0].get("missing_prop_ids", []).is_empty()
			and is_equal_approx(
				float(setups[0].get("set_dressing_quality", 0.0)),
				62.0
			)
			and int(setups[0].get("setup_minutes", 0)) == 5,
			"Owned props must create a reusable lighthouse setup and extend setup time."
		)
		_expect(
			setups[0].get("prop_ids", []) == setups[1].get("prop_ids", []),
			"Matching scenes must reuse the same purchased props."
		)
		_expect(
			str(setups[2].get("set_id", "")) == "neutral"
			and setups[2].get("prop_ids", []).is_empty()
			and setups[2].get("missing_prop_ids", []).size() == 3
			and is_equal_approx(
				float(setups[2].get("set_dressing_quality", 0.0)),
				15.0
			),
			"Unowned set groups must use the neutral stage without consuming props."
		)
	var partial_owned_props: Array[String] = ["lighthouse_console"]
	var partial_setup: Dictionary = SET_CATALOG_SCRIPT.build_scene_setups(
		[scenes[0]],
		partial_owned_props,
		"adventure"
	)[0]
	_expect(
		partial_setup.get("prop_ids", []).size() == 1
		and partial_setup.get("missing_prop_ids", []).size() == 2
		and is_equal_approx(
			float(partial_setup.get("set_dressing_quality", 0.0)),
			32.0
		),
		"Partial prop coverage must preserve owned pieces and penalize missing pieces."
	)
	_expect(
		inventory.get_owned_prop_ids().size() == 3,
		"Building scene plans must not consume reusable purchased props."
	)
	_expect(
		inventory.get_props_in_warehouse().size() == 3,
		"Newly purchased props must physically belong to warehouse stock."
	)
	_expect(
		not bool(inventory.call(
			"set_prop_location",
			"lighthouse_console",
			"on_stage"
		)),
		"Inventory must reject skipping the warehouse pickup and transport steps."
	)
	_expect(
		bool(inventory.call(
			"set_prop_location",
			"lighthouse_console",
			"in_transit_to_stage"
		))
		and bool(inventory.call(
			"set_prop_location",
			"lighthouse_console",
			"on_stage"
		)),
		"A prop must transition from warehouse through transport before appearing on stage."
	)
	_expect(
		inventory.get_props_on_stage() == ["lighthouse_console"]
		and inventory.get_props_in_warehouse().size() == 2,
		"Physical stock counts must distinguish warehouse inventory from installed props."
	)
	_expect(
		not bool(inventory.call(
			"set_prop_location",
			"lighthouse_console",
			"warehouse"
		)),
		"An installed prop must not teleport directly back to warehouse stock."
	)
	var on_stage_round_trip: Variant = SET_INVENTORY_SCRIPT.from_dict(
		inventory.to_dict()
	)
	_expect(
		on_stage_round_trip.get_prop_location("lighthouse_console") == "on_stage",
		"Prop location must survive inventory serialization."
	)
	_expect(
		bool(inventory.call(
			"set_prop_location",
			"lighthouse_console",
			"in_transit_to_warehouse"
		))
		and bool(inventory.call(
			"set_prop_location",
			"lighthouse_console",
			"warehouse"
		)),
		"A removed prop must return through transport to warehouse stock."
	)
	var fast_setups: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		[scenes[0]],
		owned_props,
		"adventure",
		3
	)
	_expect(
		int(fast_setups[0].get("setup_minutes", 0)) == 3,
		"Three technicians must reduce a three-prop setup to one parallel installation round plus base preparation."
	)

	var budget_before_dev_grant: int = int(inventory.budget)
	_expect(
		bool(inventory.call("add_funds", 10000))
		and int(inventory.budget) == budget_before_dev_grant + 10000,
		"Developer funds must increase the reusable decor budget by the requested amount."
	)
	_expect(
		not bool(inventory.call("add_funds", 0))
		and not bool(inventory.call("add_funds", -500)),
		"Developer funds must reject zero and negative grants."
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
