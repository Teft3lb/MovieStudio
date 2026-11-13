extends "res://tests/smoke_test_base.gd"

const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const LIGHTING_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_interior_lighting_controller.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-LIGHTING-TEST"
	data.building_type_id = "sound_stage"
	data.stage_size_tier = 3
	var building: Node3D = BUILDING_ACTOR_SCRIPT.new()
	building.call("setup", data)
	root.add_child(building)
	var interior: Node3D = building.get_node_or_null("Interior")
	var lamp_count: int = 0
	for child in interior.get_children():
		if child is OmniLight3D:
			lamp_count += 1
	_expect(
		lamp_count >= 4,
		"Large sound stages must have multiple independent ceiling lights."
	)

	var fake_employee := Node3D.new()
	fake_employee.add_to_group("studio_employee")
	root.add_child(fake_employee)
	fake_employee.global_position = Vector3(0.0, 0.0, 0.0)
	var light: RefCounted = building.get("_interior_lighting")
	light.call("advance", 0.6)
	_expect(
		bool(building.call("is_interior_occupied")),
		"Entering an interior must enable the building's lights."
	)
	fake_employee.global_position = Vector3(60.0, 0.0, 60.0)
	light.call("advance", 0.6)
	_expect(
		not bool(building.call("is_interior_occupied")),
		"Unoccupied interiors must stop lighting the whole studio to save GPU time."
	)
	fake_employee.free()
	building.free()
	_finish_test("StudioBuildingInteriorLightingSmokeTest")
