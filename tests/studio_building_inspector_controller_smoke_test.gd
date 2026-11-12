extends "res://tests/smoke_test_base.gd"

const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)
const INSPECTOR_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_inspector_controller.gd"
)


class MockEmployee extends RefCounted:
	var id: String = "EMP-INSPECTOR-WRITER"
	var profession_id: String = "screenwriter"
	var skills: Dictionary = {"writing": 76.0}

	func get_full_name() -> String:
		return "Тестовый сценарист"


class MockCharacterManager extends Node:
	func get_employees_using_facility(_building_id: String) -> Array:
		return []


class MockBuildingManager extends Node:
	var buildings: Array = []
	var eligible_staff: Array = []
	var assigned_staff: Array = []
	var active_writing_project: Variant
	var latest_script: Variant
	var production_detail_count: int = 0
	var editing_detail_count: int = 0

	func get_building_by_id(building_id: String) -> Variant:
		for building in buildings:
			if str(building.id) == building_id:
				return building
		return null

	func get_assigned_staff_for_building(_building_id: String) -> Array:
		return assigned_staff

	func get_eligible_staff_for_building(building_type_id: String) -> Array:
		return eligible_staff if building_type_id == "script_department" else []

	func get_profession_title(profession_id: String) -> String:
		return "Сценарист" if profession_id == "screenwriter" else profession_id

	func get_active_writing_project() -> Variant:
		return active_writing_project

	func get_latest_script() -> Variant:
		return latest_script

	func build_film_production_detail(
		detail_layout: VBoxContainer,
		_assigned_staff: Array
	) -> void:
		production_detail_count += 1
		var label := Label.new()
		label.text = "Production controller detail"
		detail_layout.add_child(label)

	func build_film_editing_detail(
		detail_layout: VBoxContainer,
		_assigned_staff: Array
	) -> void:
		editing_detail_count += 1
		var label := Label.new()
		label.text = "Editing controller detail"
		detail_layout.add_child(label)


class MockStudioHUD extends Node:
	var registered_panel: PanelContainer
	var inspector_visible: bool = false
	var active_workspace_id: String = ""

	func register_inspector_panel(
		_panel_id: String,
		_title: String,
		panel: PanelContainer
	) -> void:
		registered_panel = panel

	func configure_scroll_container(scroll: ScrollContainer) -> void:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	func show_workspace_panel(workspace_id: String) -> void:
		active_workspace_id = workspace_id

	func show_inspector_panel(_panel_id: String, visible: bool) -> void:
		inspector_visible = visible
		if is_instance_valid(registered_panel):
			registered_panel.visible = visible


var _script_request: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run_tests")


func _on_script_generation_requested(
	writer_id: String,
	genre_id: String,
	scene_count: int,
	role_count: int
) -> void:
	_script_request = {
		"writer_id": writer_id,
		"genre_id": genre_id,
		"scene_count": scene_count,
		"role_count": role_count,
	}


func _run_tests() -> void:
	var manager := MockBuildingManager.new()
	var character_manager := MockCharacterManager.new()
	var hud := MockStudioHUD.new()
	root.add_child(manager)
	root.add_child(character_manager)
	root.add_child(hud)

	var writer := MockEmployee.new()
	manager.eligible_staff = [writer]
	manager.buildings = [
		_create_building("BLD-SCRIPT", "script_department", "Сценарный отдел"),
		_create_building("BLD-STAGE", "sound_stage", "Съёмочный павильон"),
		_create_building("BLD-EDIT", "editing_suite", "Монтажный отдел"),
		_create_building("BLD-TV", "tv_studio", "Телевизионная студия"),
		_create_building("BLD-CAFETERIA", "cafeteria", "Столовая"),
	]

	var controller: RefCounted = INSPECTOR_CONTROLLER_SCRIPT.new()
	controller.call("setup", manager, character_manager)
	controller.connect(
		"script_generation_requested",
		Callable(self, "_on_script_generation_requested")
	)
	var panel: PanelContainer = controller.call("build_panel", hud)
	_expect(
		panel.name == "BuildingDetailPanel"
		and hud.registered_panel == panel,
		"The inspector controller must create and register its own context panel."
	)

	controller.call("select_building", "BLD-SCRIPT")
	_expect(
		str(controller.call("get_selected_building_id")) == "BLD-SCRIPT"
		and panel.visible
		and hud.inspector_visible
		and hud.active_workspace_id == "studio",
		"Selecting a valid building must update selection and open the Studio inspector."
	)
	controller.call("_on_generate_script_pressed")
	_expect(
		str(_script_request.get("writer_id", "")) == writer.id
		and not str(_script_request.get("genre_id", "")).is_empty()
		and int(_script_request.get("scene_count", 0)) == 8
		and int(_script_request.get("role_count", 0)) == 3,
		"The script-writing UI must emit a typed generation request without owning writing simulation."
	)

	controller.call("select_building", "BLD-STAGE")
	_expect(
		manager.production_detail_count == 1,
		"Sound-stage inspector content must remain delegated to FilmProductionController."
	)
	controller.call("select_building", "BLD-EDIT")
	_expect(
		manager.editing_detail_count == 1,
		"Editing-suite inspector content must remain delegated to FilmEditingController."
	)
	controller.call("select_building", "BLD-TV")
	controller.call("select_building", "BLD-CAFETERIA")
	_expect(
		panel.visible,
		"Television and facility building types must continue to render through the shared inspector."
	)

	controller.call("hide_inspector")
	_expect(
		not panel.visible
		and not hud.inspector_visible
		and str(controller.call("get_selected_building_id")) == "BLD-CAFETERIA",
		"Hiding the inspector must not discard the selected building."
	)
	controller.call("select_building", "BLD-MISSING")
	_expect(
		str(controller.call("get_selected_building_id")).is_empty()
		and not panel.visible
		and not hud.inspector_visible,
		"Selecting an unknown building must clear selection and hide the inspector."
	)

	panel.free()
	hud.free()
	character_manager.free()
	manager.free()
	_finish_test("StudioBuildingInspectorControllerSmokeTest")


func _create_building(
	building_id: String,
	building_type_id: String,
	display_name: String
) -> Variant:
	var building: Variant = BUILDING_DATA_SCRIPT.new()
	building.id = building_id
	building.building_type_id = building_type_id
	building.display_name = display_name
	building.position = Vector3.ZERO
	building.rotation_degrees = 0.0
	building.stage_size_tier = 2
	building.is_operational = true
	return building
