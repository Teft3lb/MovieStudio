extends "res://tests/smoke_test_base.gd"

const PLACEMENT_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_placement_controller.gd"
)

var _requested_placement_type: String = ""


func _initialize() -> void:
	call_deferred("_run_tests")


func _on_placement_mode_requested(building_type_id: String) -> void:
	_requested_placement_type = building_type_id


func _run_tests() -> void:
	var manager := Node3D.new()
	root.add_child(manager)
	var buildings: Array = []
	var controller: RefCounted = PLACEMENT_CONTROLLER_SCRIPT.new()
	controller.call("setup", manager, buildings)

	var palette: PanelContainer = controller.call("build_palette")
	_expect(
		palette.name == "BuildingPalettePanel",
		"The placement controller must build the studio construction palette."
	)
	_expect(
		palette.get_child_count() == 1,
		"The construction palette must contain its layout root."
	)
	_expect(
		not bool(controller.call("is_placing_building")),
		"Placement mode must be inactive before the player chooses a building."
	)
	controller.connect(
		"placement_mode_requested",
		Callable(self, "_on_placement_mode_requested")
	)
	var layout: VBoxContainer = palette.get_child(0) as VBoxContainer
	var script_button: Button = layout.get_child(1) as Button
	script_button.pressed.emit()
	_expect(
		_requested_placement_type == "script_department",
		"Construction palette buttons must request placement through the manager-facing signal."
	)
	_expect(
		not bool(controller.call("is_placing_building")),
		"The placement controller must not bypass the manager when a palette button is pressed."
	)

	controller.call("begin_placement", "sound_stage")
	_expect(
		bool(controller.call("is_placing_building")),
		"Choosing a sound stage must activate placement mode."
	)
	_expect(
		int(controller.call("get_stage_size_tier")) == 2,
		"The default sound-stage size must remain medium."
	)

	controller.call("_on_stage_size_selected", 2)
	_expect(
		int(controller.call("get_stage_size_tier")) == 3,
		"Selecting the third stage option must update the placement size."
	)

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	controller.call("handle_input", escape_event)
	_expect(
		not bool(controller.call("is_placing_building")),
		"Escape must cancel placement mode."
	)

	controller.call("begin_placement", "not_a_building")
	_expect(
		not bool(controller.call("is_placing_building")),
		"Unknown building types must not activate placement mode."
	)

	manager.queue_free()
	_finish_test("StudioBuildingPlacementControllerSmokeTest")
