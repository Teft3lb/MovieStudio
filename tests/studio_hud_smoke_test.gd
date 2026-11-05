extends "res://tests/smoke_test_base.gd"

const STUDIO_HUD_SCRIPT = preload(
	"res://scripts/presentation/ui/studio_hud.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var hud: Node = STUDIO_HUD_SCRIPT.new()
	root.add_child(hud)

	var employee_panel := PanelContainer.new()
	var studio_panel := PanelContainer.new()
	hud.call(
		"register_workspace_panel",
		"employees",
		"Персонал",
		employee_panel
	)
	hud.call(
		"register_workspace_panel",
		"studio",
		"Студия",
		studio_panel
	)

	hud.call("show_workspace_panel", "employees")
	_expect(
		employee_panel.visible,
		"Selected workspace section must be visible."
	)
	_expect(
		not studio_panel.visible,
		"Inactive workspace sections must remain hidden."
	)

	var employee_inspector := PanelContainer.new()
	hud.call(
		"register_inspector_panel",
		"employee",
		"Сотрудник",
		employee_inspector
	)
	hud.call("show_inspector_panel", "employee", true)
	_expect(
		employee_inspector.visible,
		"Requested context inspector must be visible."
	)

	hud.call("show_workspace_panel", "studio")
	_expect(
		studio_panel.visible,
		"Navigation must activate the requested workspace."
	)
	_expect(
		not employee_inspector.visible,
		"Changing workspace must close the previous context inspector."
	)

	hud.call("show_inspector_panel", "employee", true)
	_expect(
		employee_inspector.visible,
		"Context inspector must be reopenable after navigation."
	)
	hud.call("_on_close_inspector_pressed")
	_expect(
		not employee_inspector.visible,
		"Inspector close action must hide the selected context panel."
	)

	var navigation_list: Control = hud.get("_navigation_list")
	_expect(
		navigation_list is HBoxContainer,
		"Navigation must use a compact horizontal strip."
	)
	var bottom_navigation: Node = hud.find_child(
		"BottomNavigationPanel",
		true,
		false
	)
	_expect(
		bottom_navigation is PanelContainer,
		"Bottom navigation panel must exist in the HUD shell."
	)
	_expect(
		hud.get("_root").theme != null,
		"StudioHUD must provide a unified visual theme."
	)
	var speed_buttons: Dictionary = hud.get("_speed_buttons")
	_expect(
		speed_buttons.size() == 4,
		"All four simulation speed controls must remain available."
	)

	hud.free()
	_finish_test("StudioHUDSmokeTest")
