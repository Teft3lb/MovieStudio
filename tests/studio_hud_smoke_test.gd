extends "res://tests/smoke_test_base.gd"

const STUDIO_HUD_SCRIPT = preload(
	"res://scripts/presentation/ui/studio_hud.gd"
)
const STUDIO_BUILDING_MANAGER_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_manager.gd"
)
const SET_INVENTORY_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_inventory.gd"
)

var _requested_developer_funds: int = 0


func _on_developer_funds_requested(amount: int) -> void:
	_requested_developer_funds = amount


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var hud: Node = STUDIO_HUD_SCRIPT.new()
	root.add_child(hud)

	var employee_panel := PanelContainer.new()
	var studio_panel := PanelContainer.new()
	var decor_panel := PanelContainer.new()
	var market_panel := PanelContainer.new()
	_expect(
		not bool(hud.call("is_workspace_drawer_open")),
		"Workspace drawer must start hidden until the player requests it."
	)
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
	hud.call(
		"register_workspace_panel",
		"decor_shop",
		"Магазин декораций",
		decor_panel
	)
	hud.call(
		"register_workspace_panel",
		"market",
		"Кадровый рынок",
		market_panel
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
	var navigation_buttons: Dictionary = hud.get("_navigation_buttons")
	var building_button: Button = navigation_buttons.get("studio") as Button
	var decor_button: Button = navigation_buttons.get("decor_shop") as Button
	var market_button: Button = navigation_buttons.get("market") as Button
	_expect(
		building_button != null and building_button.text == "▣  ЗДАНИЯ",
		"Construction must have an explicit bottom-navigation entry."
	)
	_expect(
		decor_button != null
		and decor_button.text == "▧  РЕКВИЗИТ",
		"Decor shop must have a dedicated bottom-navigation button."
	)
	_expect(
		market_button != null and market_button.text == "★  РЫНОК",
		"Employee market must be clearly named in the bottom navigation."
	)
	hud.call("show_workspace_panel", "decor_shop")
	_expect(
		decor_panel.visible and bool(hud.call("is_workspace_drawer_open")),
		"Selecting the decor shop navigation item must open its workspace drawer."
	)
	hud.call("_on_navigation_button_pressed", "decor_shop")
	_expect(
		not bool(hud.call("is_workspace_drawer_open")),
		"Pressing the active navigation entry again must close the drawer."
	)
	_expect(
		hud.get("_root").theme != null,
		"StudioHUD must provide a unified visual theme."
	)
	var overlay_root: Control = hud.call("get_overlay_control_root") as Control
	_expect(
		overlay_root != null and overlay_root == hud.get("_root"),
		"Character popups must share the HUD's themed overlay layer."
	)
	hud.call("show_notification", "Сотрудник отправлен на репетицию.", true)
	var notification_stack: VBoxContainer = hud.get("_notification_stack") as VBoxContainer
	_expect(
		notification_stack != null and notification_stack.get_child_count() == 1,
		"Employee actions must be able to surface non-blocking HUD notifications."
	)
	var scroll_test := ScrollContainer.new()
	hud.call("configure_scroll_container", scroll_test)
	_expect(
		scroll_test.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"All studio UI scroll containers must disable horizontal scrolling."
	)
	_expect(
		scroll_test.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"Vertical scrolling must remain available when content requires it."
	)
	scroll_test.free()

	var dev_button: Button = hud.find_child(
		"DeveloperFundsButton",
		true,
		false
	) as Button
	_expect(
		dev_button != null
		and dev_button.text.contains("10 000"),
		"The developer panel must expose a dedicated decor-budget grant button."
	)
	hud.developer_funds_requested.connect(
		_on_developer_funds_requested
	)
	if dev_button != null:
		dev_button.pressed.emit()
	_expect(
		_requested_developer_funds == 10000,
		"The developer button must request exactly 10,000 decor-budget units."
	)
	var building_manager: Node = STUDIO_BUILDING_MANAGER_SCRIPT.new()
	var inventory: RefCounted = SET_INVENTORY_SCRIPT.new()
	building_manager.set("_set_inventory", inventory)
	building_manager.call(
		"_on_developer_funds_requested",
		_requested_developer_funds
	)
	_expect(
		int(inventory.budget) == 13000,
		"StudioBuildingManager must apply the developer grant to the decor inventory."
	)
	building_manager.free()
	hud.call(
		"set_developer_funds_status",
		"Бюджет пополнен."
	)
	var dev_status: Label = hud.get("_developer_funds_status_label")
	_expect(
		dev_status != null and dev_status.text == "Бюджет пополнен.",
		"The developer funds status must be refreshable after the grant."
	)

	var speed_buttons: Dictionary = hud.get("_speed_buttons")
	_expect(
		speed_buttons.size() == 4,
		"All four simulation speed controls must remain available."
	)

	hud.free()
	_finish_test("StudioHUDSmokeTest")
