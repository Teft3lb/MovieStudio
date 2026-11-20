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
		{"id": "profession_activity", "title": "По своим делам", "icon": "★"},
		{"id": "rest", "title": "Отдохнуть", "icon": "⌂"},
		{"id": "fan_meet", "title": "Встреча с фанатами", "icon": "✦"},
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
	var center_name: Label = wheel.get("_center_name") as Label
	_expect(
		center_name != null and center_name.text == "Тестовый актёр",
		"The wheel center must identify the selected employee."
	)
	var action_buttons: Array = wheel.get("_action_buttons")
	if not action_buttons.is_empty():
		var first_button: Button = action_buttons[0] as Button
		var title_label: Label = first_button.find_child(
			"ActionTitleLabel", true, false
		) as Label
		_expect(
			first_button.size.x >= 145.0
			and title_label != null
			and title_label.size.x >= 120.0,
			"Radial action labels must receive enough horizontal space to avoid one-letter wrapping."
		)
		first_button.pressed.emit()
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
	_finish_test("CharacterActionWheelSmokeTest")
