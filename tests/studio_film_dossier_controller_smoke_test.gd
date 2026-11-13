extends "res://tests/smoke_test_base.gd"

const DOSSIER_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_film_dossier_controller.gd"
)
const DOSSIER_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_dossier.gd"
)


class FakeBuilding extends RefCounted:
	var id: String
	var building_type_id: String
	var is_operational: bool = true
	var stage_size_tier: int = 2
	var position: Vector3 = Vector3.ZERO


class FakeScript extends RefCounted:
	var id: String = "SCR-DOSSIER-01"
	var title: String = "Производственный фильм"


class FakeManager extends Node3D:
	var buildings: Array = []
	var actors: Dictionary = {}
	var released_count: int = 0

	func get_buildings() -> Array:
		return buildings

	func get_building_by_id(building_id: String) -> Variant:
		for building in buildings:
			if str(building.id) == building_id:
				return building
		return null

	func get_building_actor_by_id(building_id: String) -> Node3D:
		return actors.get(building_id)

	func get_required_stage_size_tier_for_script(_script: Variant) -> int:
		return 2

	func on_film_dossier_released(_payload: Dictionary) -> void:
		released_count += 1


func _initialize() -> void:
	call_deferred("_run_tests")


func _make_building(
	manager: FakeManager,
	building_id: String,
	building_type: String,
	pos: Vector3,
	tier: int = 2
) -> void:
	var building := FakeBuilding.new()
	building.id = building_id
	building.building_type_id = building_type
	building.position = pos
	building.stage_size_tier = tier
	manager.buildings.append(building)
	var actor := Node3D.new()
	actor.position = pos
	manager.add_child(actor)
	manager.actors[building_id] = actor


func _run_tests() -> void:
	var manager := FakeManager.new()
	root.add_child(manager)
	_make_building(manager, "WRITER", "script_department", Vector3(-16, 0, -16))
	_make_building(manager, "STAGE-SMALL", "sound_stage", Vector3(0, 0, 0), 1)
	_make_building(manager, "STAGE", "sound_stage", Vector3(0, 0, -25), 2)
	_make_building(manager, "EDIT", "editing_suite", Vector3(22, 0, 10))
	var coordinator: RefCounted = DOSSIER_CONTROLLER_SCRIPT.new()
	coordinator.call("setup", manager)
	var screenplay := FakeScript.new()
	_expect(
		bool(coordinator.call("add_completed_script", screenplay)),
		"Completing writing must create a production dossier."
	)
	var doc: Variant = coordinator.call("get_dossier", screenplay.id)
	var visuals: Dictionary = coordinator.get("_visuals")
	var actor: Node3D = visuals.get(screenplay.id) as Node3D
	_expect(
		actor.get_node_or_null("DocumentVisual/ScreenplayCover") != null
		and doc.phase == DOSSIER_SCRIPT.AT_WRITERS,
		"The 3D screenplay must be visible outside the writers' building."
	)
	_expect(
		not bool(coordinator.call("deliver_to_building", screenplay.id, "STAGE-SMALL"))
		and doc.phase == DOSSIER_SCRIPT.AT_WRITERS,
		"The stage must satisfy the film's required scale before accepting the script."
	)
	_expect(
		bool(coordinator.call("deliver_to_building", screenplay.id, "STAGE"))
		and coordinator.call("get_script_at_stage") == screenplay,
		"Hand-delivering the script to the Sound Stage must unlock its production assignment."
	)
	_expect(
		bool(coordinator.call("on_production_started", screenplay.id, "STAGE"))
		and not bool(coordinator.call("deliver_to_building", screenplay.id, "EDIT")),
		"Film material cannot be sent to editing before shooting completes."
	)
	_expect(
		bool(coordinator.call("on_production_completed", screenplay.id))
		and bool(coordinator.call("deliver_to_building", screenplay.id, "EDIT"))
		and bool(coordinator.call("is_footage_at_editing", screenplay.id)),
		"Physical footage must move from the sound stage into the editing suite."
	)
	_expect(
		bool(coordinator.call("on_editing_started", screenplay.id))
		and bool(coordinator.call("on_editing_completed", screenplay.id))
		and bool(coordinator.call("release_film", screenplay.id)),
		"Only a completed edit can be delivered for release."
	)
	_expect(
		manager.released_count == 1
		and not bool(coordinator.call("release_film", screenplay.id)),
		"Releasing a finished film must notify the studio exactly once."
	)
	manager.free()
	_finish_test("StudioFilmDossierControllerSmokeTest")
