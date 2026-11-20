extends "res://tests/smoke_test_base.gd"

const SET_INVENTORY_SCRIPT = preload("res://scripts/domain/studio/studio_set_inventory.gd")
const WARDROBE_INVENTORY_SCRIPT = preload("res://scripts/domain/studio/studio_wardrobe_inventory.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var funds: RefCounted = SET_INVENTORY_SCRIPT.new()
	var wardrobe: RefCounted = WARDROBE_INVENTORY_SCRIPT.new()
	_expect(not bool(wardrobe.call("purchase", "unknown_costume", funds)), "Unknown costume IDs must be rejected.")
	_expect(bool(wardrobe.call("purchase", "science_fiction_costumes", funds)), "A valid costume set must be purchasable from the shared studio budget.")
	_expect(int(funds.budget) == 2500 and bool(wardrobe.call("is_owned", "science_fiction_costumes")), "Costume purchases must deduct the catalog price and enter the wardrobe inventory.")
	_expect(
		wardrobe.call("get_costume_ids_for_genre", "science_fiction") == ["science_fiction_costumes"]
		and is_equal_approx(float(wardrobe.call("get_costume_quality_bonus_for_genre", "science_fiction")), 8.0),
		"Matching costume sets must be selected automatically and improve genre-appropriate costume quality."
	)
	_expect(wardrobe.call("get_costume_ids_for_genre", "drama").is_empty(), "Costume sets must not be applied to unsupported genres.")
	var restored: Variant = WARDROBE_INVENTORY_SCRIPT.from_dict(wardrobe.call("to_dict"))
	_expect(bool(restored.call("is_owned", "science_fiction_costumes")), "Owned costume sets must survive wardrobe serialization.")
	_expect(
		int(wardrobe.call("get_resale_value", "science_fiction_costumes")) == 200
		and int(wardrobe.call("sell", "science_fiction_costumes", funds)) == 200,
		"Costumes must be sellable at the documented resale rate."
	)
	_expect(int(funds.budget) == 2700 and wardrobe.call("get_owned_costume_ids").is_empty(), "Selling a costume must return funds and remove it from the wardrobe.")
	_finish_test("StudioWardrobeInventorySmokeTest")
