extends "res://tests/smoke_test_base.gd"

const STUDIO_HUD_SCRIPT = preload(
	"res://scripts/presentation/ui/studio_hud.gd"
)
const EMPLOYEE_ROSTER_PANEL_CONTROLLER_SCRIPT = preload(
	"res://scripts/presentation/characters/employee_roster_panel_controller.gd"
)
const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)

var _selected_employee_id: String = ""
var _selected_candidate_id: String = ""
var _market_toggle_count: int = 0
var _market_close_count: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _on_employee_selected(employee_id: String) -> void:
	_selected_employee_id = employee_id


func _on_market_toggled() -> void:
	_market_toggle_count += 1


func _on_market_closed() -> void:
	_market_close_count += 1


func _on_market_candidate_selected(candidate_id: String) -> void:
	_selected_candidate_id = candidate_id


func _get_employee_status(_employee: Variant) -> String:
	return "Тестовый статус"


func _run_tests() -> void:
	var hud: Node = STUDIO_HUD_SCRIPT.new()
	root.add_child(hud)

	var controller: RefCounted = EMPLOYEE_ROSTER_PANEL_CONTROLLER_SCRIPT.new()
	controller.call(
		"setup",
		hud,
		Callable(self, "_on_employee_selected"),
		Callable(self, "_on_market_toggled"),
		Callable(self, "_on_market_closed"),
		Callable(self, "_on_market_candidate_selected"),
		Callable(self, "_get_employee_status")
	)

	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	var employees: Array = [
		generator.call("generate", rng, "EMP-UI-0001", "actor"),
		generator.call("generate", rng, "EMP-UI-0002", "director"),
	]
	var candidates: Array = [
		generator.call("generate", rng, "MARKET-UI-0001", "screenwriter"),
		generator.call("generate", rng, "MARKET-UI-0002", "camera_operator"),
	]

	controller.call("build", employees, candidates, "EMP-UI-0001", 4)

	var roster_buttons: Dictionary = controller.get("_roster_buttons")
	var roster_header: Label = controller.get("_roster_header")
	var market_header: Label = controller.get("_market_header")
	var market_status: Label = controller.get("_market_status_label")
	var market_list: VBoxContainer = controller.get("_market_list")
	var market_toggle: Button = controller.get("_market_toggle_button")
	_expect(
		roster_buttons.size() == 2 and roster_header.text.contains("2"),
		"Roster view must create one button per employee and show the current headcount."
	)
	_expect(
		market_list.get_child_count() == 2
		and market_header.text.contains("2")
		and market_status.text.contains("4 дн."),
		"Market view must show candidates and the supplied refresh countdown."
	)
	var first_button: Button = roster_buttons["EMP-UI-0001"] as Button
	var second_button: Button = roster_buttons["EMP-UI-0002"] as Button
	_expect(
		first_button.button_pressed
		and not second_button.button_pressed
		and first_button.text.contains("Тестовый статус"),
		"Roster selection and manager-provided work status must be reflected in the row."
	)
	first_button.pressed.emit()
	_expect(
		_selected_employee_id == "EMP-UI-0001",
		"Roster row activation must delegate employee selection to the manager."
	)

	market_toggle.pressed.emit()
	_expect(_market_toggle_count == 1, "Market navigation must delegate to the manager.")
	var candidate_button: Button = market_list.get_child(0) as Button
	candidate_button.pressed.emit()
	_expect(
		_selected_candidate_id == str(candidates[0].id),
		"Market candidate activation must delegate candidate selection to the manager."
	)
	var workspace_panels: Dictionary = hud.get("_workspace_panels")
	var market_panel: Control = workspace_panels.get("market") as Control
	_expect(
		workspace_panels.has("employees") and workspace_panels.has("market"),
		"Roster controller must register both employee and recruitment workspaces."
	)
	var close_button: Button = market_panel.find_child(
		"MarketCloseButton",
		true,
		false
	) as Button
	_expect(close_button != null, "Market panel must expose its close action.")
	if close_button != null:
		close_button.pressed.emit()
	_expect(_market_close_count == 1, "Market close action must delegate to the manager.")

	controller.call("remove_employee", "EMP-UI-0001")
	_expect(
		not roster_buttons.has("EMP-UI-0001") and roster_buttons.size() == 1,
		"Removing an employee must remove only its roster row."
	)
	controller.call("refresh_roster", employees, "EMP-UI-0002")
	_expect(
		second_button.button_pressed,
		"Roster refresh must update the selected row without recreating buttons."
	)
	controller.call("refresh_market_panel", [candidates[1]], 2)
	_expect(
		market_header.text.contains("1")
		and market_status.text.contains("2 дн.")
		and market_list.get_child_count() == 1,
		"Market refresh must update candidate rows and countdown in place."
	)
	_expect(
		bool(controller.call("has_market_panel")),
		"Roster controller must report whether the market workspace is registered."
	)

	hud.free()
	_finish_test("EmployeeRosterPanelControllerSmokeTest")
