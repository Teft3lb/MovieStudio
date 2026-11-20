extends "res://tests/smoke_test_base.gd"

const SET_INVENTORY_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_inventory.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var inventory: RefCounted = SET_INVENTORY_SCRIPT.new()
	_expect(
		bool(inventory.call("purchase", "lighthouse_console", 420)),
		"A catalog prop must be purchasable before it can wear."
	)
	_expect(
		is_equal_approx(
			float(inventory.call("get_prop_condition", "lighthouse_console")),
			100.0
		),
		"New props must begin at full condition."
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
		"A prop must follow the existing warehouse-to-stage logistics states."
	)
	_expect(
		bool(inventory.call(
			"record_prop_use", "lighthouse_console", "FILM-001", 7.5
		))
		and bool(inventory.call(
			"record_prop_use", "lighthouse_console", "FILM-001", 7.5
		)),
		"Each completed scene must be able to apply wear to an installed prop."
	)
	_expect(
		is_equal_approx(
			float(inventory.call("get_prop_condition", "lighthouse_console")),
			85.0
		)
		and int(inventory.call(
			"get_prop_film_usage_count", "lighthouse_console"
		)) == 1,
		"Multiple scenes in one film must increase wear but count as one film reuse."
	)
	_expect(
		bool(inventory.call(
			"record_prop_use", "lighthouse_console", "FILM-002", 7.5
		))
		and int(inventory.call(
			"get_prop_film_usage_count", "lighthouse_console"
		)) == 2,
		"A second film must increase the unique-film reuse count."
	)
	_expect(
		int(inventory.call(
			"get_prop_film_usage_count",
			"lighthouse_console",
			"FILM-002"
		)) == 1,
		"The active film must be excluded from its own cross-film reuse penalty."
	)
	var reuse_map: Dictionary = inventory.call(
		"get_prop_film_usage_count_map", "FILM-002"
	)
	_expect(
		int(reuse_map.get("lighthouse_console", 0)) == 1,
		"The scene setup usage map must exclude the active film from the novelty penalty."
	)
	_expect(
		float(inventory.call(
			"repair_prop", "lighthouse_console", 25.0
		)) == 0.0,
		"Props on the active stage must not be repaired."
	)
	var payload: Dictionary = inventory.call("to_dict")
	var restored: Variant = SET_INVENTORY_SCRIPT.from_dict(payload)
	_expect(
		is_equal_approx(
			float(restored.call("get_prop_condition", "lighthouse_console")),
			77.5
		)
		and int(restored.call(
			"get_prop_film_usage_count", "lighthouse_console"
		)) == 2,
		"Condition and unique-film reuse history must survive inventory serialization."
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
		"A used prop must be returned to the warehouse before maintenance."
	)
	_expect(
		is_equal_approx(
			float(inventory.call(
				"repair_prop", "lighthouse_console", 25.0
			)),
			22.5
		)
		and is_equal_approx(
			float(inventory.call("get_prop_condition", "lighthouse_console")),
			100.0
		),
		"Warehouse repairs must restore condition without exceeding 100 percent."
	)
	_expect(
		int(inventory.call(
			"get_prop_resale_value", "lighthouse_console"
		)) == 210,
		"Resale value must reflect the restored condition and catalog price."
	)
	_expect(
		int(inventory.call("sell_prop", "lighthouse_console")) == 210
		and not bool(inventory.call("is_owned", "lighthouse_console"))
		and int(inventory.budget) == 2790,
		"Only warehouse props may be sold, and the resale proceeds must return to the shared budget."
	)

	_finish_test("StudioAssetConditionSmokeTest")
