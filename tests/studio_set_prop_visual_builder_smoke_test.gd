extends "res://tests/smoke_test_base.gd"

const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)
const VISUAL_FACTORY_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_visual_factory.gd"
)
const SET_PROP_BUILDER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_set_prop_visual_builder.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_all_catalog_props()
	_test_distinct_compositions()
	_test_unknown_prop_fallback()
	_finish_test("StudioSetPropVisualBuilderSmokeTest")


func _create_builder() -> RefCounted:
	var visual_factory: RefCounted = VISUAL_FACTORY_SCRIPT.new()
	var builder: RefCounted = SET_PROP_BUILDER_SCRIPT.new()
	builder.call("setup", visual_factory)
	return builder


func _test_all_catalog_props() -> void:
	var builder: RefCounted = _create_builder()
	var prop_ids: Array[String] = []
	for group_id in SET_CATALOG_SCRIPT.get_group_ids():
		prop_ids.append_array(
			SET_CATALOG_SCRIPT.get_prop_ids_for_group(group_id)
		)
	_expect(
		prop_ids.size() == 21,
		"Set prop builder coverage must stay aligned with all 21 catalog entries."
	)
	var all_props_have_geometry: bool = true
	for prop_id in prop_ids:
		var prop_root := Node3D.new()
		prop_root.name = "TestProp_%s" % prop_id
		builder.call("build", prop_root, prop_id)
		if prop_root.get_child_count() == 0:
			all_props_have_geometry = false
		for child in prop_root.get_children():
			if not (child is MeshInstance3D):
				all_props_have_geometry = false
		prop_root.free()
	_expect(
		all_props_have_geometry,
		"Every purchased set prop must build a non-empty hierarchy of reusable mesh instances."
	)


func _test_distinct_compositions() -> void:
	var builder: RefCounted = _create_builder()

	var storefront := Node3D.new()
	builder.call("build", storefront, "street_storefront")
	_expect(
		storefront.get_node_or_null("Facade") is MeshInstance3D
		and storefront.get_node_or_null("Awning") is MeshInstance3D
		and storefront.get_node_or_null("ShopWindow") is MeshInstance3D
		and storefront.get_node_or_null("Door") is MeshInstance3D,
		"Street storefront must retain its facade, awning, window and door."
	)
	var facade: MeshInstance3D = storefront.get_node("Facade") as MeshInstance3D
	var facade_mesh: BoxMesh = facade.mesh as BoxMesh
	_expect(
		facade_mesh != null
		and facade_mesh.size.is_equal_approx(Vector3(1.8, 2.6, 0.34)),
		"Street storefront facade dimensions must remain unchanged."
	)
	storefront.free()

	var forest := Node3D.new()
	builder.call("build", forest, "forest_trees")
	var canopy: MeshInstance3D = forest.get_node("TreeCanopy") as MeshInstance3D
	var small_canopy: MeshInstance3D = forest.get_node("TreeCanopySmall") as MeshInstance3D
	_expect(
		canopy.scale.is_equal_approx(Vector3(1.0, 1.2, 1.0))
		and small_canopy.position.is_equal_approx(Vector3(0.8, 1.65, -0.15)),
		"Forest tree cluster must retain its canopy proportions and second tree placement."
	)
	forest.free()

	var rocks := Node3D.new()
	builder.call("build", rocks, "forest_rocks")
	var rock_a: MeshInstance3D = rocks.get_node("RockA") as MeshInstance3D
	var rock_b: MeshInstance3D = rocks.get_node("RockB") as MeshInstance3D
	_expect(
		rock_a.scale.is_equal_approx(Vector3(1.4, 0.8, 1.0))
		and rock_b.scale.is_equal_approx(Vector3(1.0, 0.65, 1.0)),
		"Forest rock cluster must retain both authored rock proportions."
	)
	rocks.free()

	var beacon := Node3D.new()
	builder.call("build", beacon, "lighthouse_beacon")
	_expect(
		beacon.get_node_or_null("BeaconTower") is MeshInstance3D
		and beacon.get_node_or_null("BeaconLens") is MeshInstance3D
		and beacon.get_node_or_null("BeaconCap") is MeshInstance3D,
		"Lighthouse beacon must retain its tower, lens and cap."
	)
	beacon.free()

	var reactor := Node3D.new()
	builder.call("build", reactor, "scifi_reactor")
	_expect(
		reactor.get_node_or_null("ReactorCore") is MeshInstance3D
		and reactor.get_node_or_null("ReactorRingTop") is MeshInstance3D
		and reactor.get_node_or_null("ReactorRingBottom") is MeshInstance3D,
		"Sci-fi reactor must retain its core and both containment rings."
	)
	reactor.free()


func _test_unknown_prop_fallback() -> void:
	var builder: RefCounted = _create_builder()
	var prop_root := Node3D.new()
	builder.call("build", prop_root, "unknown_prop")
	_expect(
		prop_root.get_child_count() == 1
		and prop_root.get_node_or_null("NeutralProp") is MeshInstance3D,
		"Unknown prop IDs must retain the neutral visual fallback."
	)
	prop_root.free()
