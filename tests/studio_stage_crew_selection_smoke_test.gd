extends "res://tests/smoke_test_base.gd"

const BUILDING_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_manager.gd"
)


class FakeInventory extends RefCounted:
	func get_owned_prop_ids() -> Array[String]:
		return []


class FakeScreenplay extends RefCounted:
	var id: String = "SCR-SELECTION-01"
	var genre_id: String = "drama"
	var scenes: Array[Dictionary] = []


class FakeBuilding extends RefCounted:
	var id: String
	var building_type_id: String = "sound_stage"
	var is_operational: bool = true
	var stage_size_tier: int = 3


class FakeCharacters extends Node:
	var stage_staff: Dictionary = {}

	func get_employees_assigned_to_building(building_id: String) -> Array:
		return stage_staff.get(building_id, [])


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var studio: Node3D = BUILDING_MANAGER_SCRIPT.new()
	var characters := FakeCharacters.new()
	var stage_a := FakeBuilding.new()
	stage_a.id = "STAGE-A"
	var stage_b := FakeBuilding.new()
	stage_b.id = "STAGE-B"
	characters.stage_staff = {
		"STAGE-A": ["director"],
		"STAGE-B": [
			"director", "camera_operator", "technician",
			"actor-1", "actor-2",
		],
	}
	studio.set("_latest_script", FakeScreenplay.new())
	studio.set("_set_inventory", FakeInventory.new())
	studio.set("_buildings", [stage_a, stage_b])
	studio.set("_character_manager", characters)
	root.add_child(studio)
	root.add_child(characters)

	_expect(
		str(studio.call("_get_sound_stage_building_id")) == "STAGE-B",
		"Production must target the eligible stage with the assigned film crew instead of an empty stage."
	)
	stage_b.is_operational = false
	_expect(
		str(studio.call("_get_sound_stage_building_id")) == "STAGE-A",
		"Production must never prefer a staffed but non-operational stage."
	)
	stage_b.is_operational = true
	characters.stage_staff["STAGE-A"] = characters.stage_staff["STAGE-B"]
	characters.stage_staff["STAGE-B"] = []
	_expect(
		str(studio.call("_get_sound_stage_building_id")) == "STAGE-A",
		"Reassigning the crew to another stage must update the preferred production location."
	)

	studio.free()
	characters.free()
	_finish_test("StudioStageCrewSelectionSmokeTest")
