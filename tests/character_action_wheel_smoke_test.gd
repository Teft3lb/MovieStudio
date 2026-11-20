extends "res://tests/smoke_test_base.gd"

const ACTION_WHEEL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_action_wheel.gd"
)

var _selected_action_id: String = ""


func _initialize() -> void:
	call_deferred("_run_tests")


func _on_action_selected(action_id: String) -> void:
	_selected_action_id = action_id


func _run_tests() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var wheel: Control = ACTION_WHEEL_SCRIPT.new()
	host.add_child(wheel)
	wheel.connect("action_selected", Callable(self, "_on_action_selected"))
	var actions: Array[Dictionary] = [
		{"id": "profile", "title": "Характеристики", "icon": "◈"},
		{"id": "workplace", "title": "На рабочее место", "icon": "▣"},
		{"id": "profession_activity", "title": "По своим делам", "icon": "★"},
		{"id": "fan_meet", "title": "Встреча с фанатами", "icon": "✦"},
		{"id": "rest", "title": "Отдохнуть", "icon": "⌂"},
		{"id": "training", "title": "Тренировка", "icon": "✧"},
	]
	wheel.call(
		"open_for_employee",
		{
			"name": "Тестовый актёр",
			"initials": "ТА",
			"profession": "Актёр · Драма",
			"status": "Свободное время",
		},
		actions,
		Vector2(520.0, 300.0)
	)
	await process_frame
	_expect(bool(wheel.call("is_open")), "Selecting an employee must open the radial action wheel.")
	_expect(
		int(wheel.call("get_action_button_count")) == 6,
		"The action wheel must create one radial button for each available action."
	)
	_expect(
		wheel.size.is_equal_approx(Vector2(380.0, 380.0)),
		"The radial wheel must use the compact 380x380 layout."
	)
	var center_name: Label = wheel.get("_center_name") as Label
	_expect(
		center_name != null and center_name.text == "Тестовый актёр",
		"The wheel center must identify the selected employee."
	)
	var center_panel: Panel = wheel.find_child(
		"CharacterCenterCard", true, false
	) as Panel
	_expect(
		center_panel != null
		and center_panel.size.is_equal_approx(Vector2(116.0, 108.0)),
		"The employee center card must use the compact dimensions."
	)
	var action_buttons: Array = wheel.get("_action_buttons")
	var wheel_rect := Rect2(Vector2.ZERO, wheel.size)
	var center_rect := (
		Rect2(center_panel.position, center_panel.size)
		if center_panel != null
		else Rect2()
	)
	for index in range(action_buttons.size()):
		var action_button: Button = action_buttons[index] as Button
		var action_rect := Rect2(action_button.position, action_button.size)
		_expect(
			action_button.size.x <= 104.0 and action_button.size.y <= 62.0,
			"Radial action buttons must remain compact."
		)
		_expect(
			wheel_rect.encloses(action_rect),
			"Every radial action button must remain inside the wheel bounds."
		)
		_expect(
			not center_rect.intersects(action_rect),
			"Radial action buttons must not overlap the employee center card."
		)
		var title_label: Label = action_button.find_child(
			"ActionTitleLabel", true, false
		) as Label
		_expect(
			title_label != null and title_label.size.x >= 90.0,
			"Compact action labels must retain enough width for readable wrapping."
		)
		for other_index in range(index + 1, action_buttons.size()):
			var other_button: Button = action_buttons[other_index] as Button
			var other_rect := Rect2(other_button.position, other_button.size)
			_expect(
				not action_rect.intersects(other_rect),
				"Radial action buttons must not overlap each other."
			)
	if not action_buttons.is_empty():
		(action_buttons[0] as Button).pressed.emit()
	_expect(
		_selected_action_id == "profile",
		"Radial action activation must emit the selected action ID to the manager."
	)
	wheel.call("close")
	_expect(
		not bool(wheel.call("is_open")),
		"Closing the action wheel must hide it and release its action buttons."
	)
	host.queue_free()
	await process_frame
	_finish_test("CharacterActionWheelSmokeTest")
