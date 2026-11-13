extends "res://tests/smoke_test_base.gd"

const FILM_PRODUCTION_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/film_production_controller.gd"
)
const FILM_PRODUCTION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_system.gd"
)
const SCRIPT_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/script_department/script_generator.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)


class FakeStage extends RefCounted:
	var stage_size_tier: int = 3


class FakeInventory extends RefCounted:
	func get_owned_prop_ids() -> Array[String]:
		return []


class FakeStudioManager extends Node:
	var screenplay: Variant
	var stage: Variant
	var staff: Array = []
	var staged: bool = false
	var required_tier: int = 1

	func get_latest_script() -> Variant:
		return screenplay

	func get_script_for_production() -> Variant:
		return screenplay

	func get_active_film_project() -> Variant:
		return null

	func get_active_film_editing_project() -> Variant:
		return null

	func get_preferred_stage_building_id() -> String:
		return "BLD-TEST-STAGE"

	func get_required_stage_size_tier_for_script(_script: Variant) -> int:
		return required_tier

	func get_building_by_id(building_id: String) -> Variant:
		return stage if building_id == "BLD-TEST-STAGE" else null

	func get_assigned_staff_for_building(_building_id: String) -> Array:
		return staff

	func is_film_script_staged(_script_id: String, _building_id: String) -> bool:
		return staged

	func get_next_script_sequence() -> int:
		return 1

	func refresh_film_production_ui() -> void:
		pass


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 52130
	var character_generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var writer: Variant = character_generator.call(
		"generate", rng, "WRITER-TEST", "screenwriter"
	)
	var script_generator: RefCounted = SCRIPT_GENERATOR_SCRIPT.new()
	var screenplay: Variant = script_generator.call(
		"generate", writer, "drama", 3, 2, 72001, "SCR-READY-001"
	)

	var studio := FakeStudioManager.new()
	studio.screenplay = screenplay
	studio.stage = FakeStage.new()
	for profession_id in [
		"director", "camera_operator", "technician", "actor", "actor"
	]:
		var employee_id: String = "EMP-READY-%d" % studio.staff.size()
		studio.staff.append(character_generator.call(
			"generate", rng, employee_id, profession_id
		))
	root.add_child(studio)

	var controller: RefCounted = FILM_PRODUCTION_CONTROLLER_SCRIPT.new()
	controller.call(
		"setup",
		studio,
		null,
		FILM_PRODUCTION_SYSTEM_SCRIPT.new(),
		null,
		null,
		FakeInventory.new()
	)
	var layout := VBoxContainer.new()
	root.add_child(layout)
	controller.call("build_detail", layout, studio.staff)
	var button: Button = controller.get("_film_production_start_button") as Button
	_expect(
		button != null and button.disabled
		and button.tooltip_text.contains("Доставь папку"),
		"A fully assigned crew must clearly see the missing physical screenplay delivery."
	)
	_expect(
		not bool(controller.call("_can_start_film_production")),
		"Filming must not start before the script is physically delivered."
	)

	studio.staged = true
	controller.call("_update_film_production_ui")
	_expect(
		not button.disabled
		and bool(controller.call("_can_start_film_production")),
		"After screenplay delivery, complete crew and cast assignments must enable the filming button."
	)

	studio.required_tier = 3
	studio.stage.stage_size_tier = 1
	controller.call("_update_film_production_ui")
	_expect(
		button.disabled and button.tooltip_text.contains("павильон"),
		"An undersized stage must remain blocked with the precise building requirement."
	)
	studio.stage.stage_size_tier = 3
	controller.call("_update_film_production_ui")
	_expect(
		not button.disabled,
		"Choosing a stage of the required size must restore production-start readiness."
	)

	layout.free()
	studio.free()
	_finish_test("FilmProductionStartReadinessSmokeTest")
