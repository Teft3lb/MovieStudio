extends "res://tests/smoke_test_base.gd"

const SET_CATALOG_SCRIPT = preload("res://scripts/domain/studio/studio_set_catalog.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var scenes: Array[Dictionary] = [{
		"scene_id": "SCN-QUALITY-01",
		"location": "Старый маяк",
		"action": "Герои находят старый сигнал.",
	}]
	var owned_props: Array[String] = ["lighthouse_console", "lighthouse_beacon", "lighthouse_rail"]
	var baseline: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(scenes, owned_props, "drama")
	var conditions: Dictionary = {"lighthouse_console": 20.0, "lighthouse_beacon": 20.0, "lighthouse_rail": 20.0}
	var reuse_counts: Dictionary = {"lighthouse_console": 2, "lighthouse_beacon": 2, "lighthouse_rail": 2}
	var worn_reused: Array[Dictionary] = SET_CATALOG_SCRIPT.build_scene_setups(
		scenes, owned_props, "drama", 2, conditions, reuse_counts,
		["classic_period_costumes"], 6.0
	)
	_expect(
		baseline.size() == 1 and worn_reused.size() == 1
		and int(baseline[0].get("set_dressing_quality", 0)) == 62,
		"Existing prop quality must remain stable when no condition or reuse data is supplied."
	)
	_expect(
		is_equal_approx(float(worn_reused[0].get("condition_penalty", 0.0)), 6.4)
		and is_equal_approx(float(worn_reused[0].get("reuse_penalty", 0.0)), 5.0)
		and is_equal_approx(float(worn_reused[0].get("average_prop_condition", 0.0)), 20.0),
		"Worn props and repeated use across films must create separate, measurable penalties."
	)
	_expect(
		worn_reused[0].get("costume_ids", []) == ["classic_period_costumes"]
		and is_equal_approx(float(worn_reused[0].get("costume_quality_bonus", 0.0)), 6.0),
		"Genre-matched wardrobe inventory must be carried into the scene setup."
	)
	_finish_test("StudioSetDressingQualitySmokeTest")
