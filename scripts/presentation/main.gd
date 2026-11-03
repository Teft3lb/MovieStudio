extends Node3D

@onready var game_clock: GameClock = $GameClock

var _time_label: Label
var _speed_label: Label
var _fast_forward_status_label: Label


func _ready() -> void:
	game_clock.minute_advanced.connect(_on_minute_advanced)
	game_clock.manual_advance_finished.connect(_on_manual_advance_finished)
	_build_debug_hud()
	_refresh_hud()


func _build_debug_hud() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "DebugHUD"
	add_child(canvas_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(390.0, 0.0)
	canvas_layer.add_child(panel)

	var layout := VBoxContainer.new()
	panel.add_child(layout)

	var title := Label.new()
	title.text = "MOVIESTUDIO  |  DEBUG TOOLS"
	layout.add_child(title)

	_time_label = Label.new()
	layout.add_child(_time_label)

	_speed_label = Label.new()
	layout.add_child(_speed_label)

	var buttons := HBoxContainer.new()
	layout.add_child(buttons)

	_add_speed_button(buttons, "Пауза", GameClock.SpeedMode.PAUSED)
	_add_speed_button(buttons, "1×", GameClock.SpeedMode.NORMAL)
	_add_speed_button(buttons, "3×", GameClock.SpeedMode.FAST)
	_add_speed_button(buttons, "6×", GameClock.SpeedMode.VERY_FAST)

	var fast_forward_heading := Label.new()
	fast_forward_heading.text = "ТЕСТОВАЯ ПЕРЕМОТКА · РАБОТАЕТ ДАЖЕ НА ПАУЗЕ"
	layout.add_child(fast_forward_heading)

	var fast_forward_buttons := HBoxContainer.new()
	layout.add_child(fast_forward_buttons)

	_add_fast_forward_button(fast_forward_buttons, "+1 час", 60)
	_add_fast_forward_button(fast_forward_buttons, "+1 день", 24 * 60)
	_add_fast_forward_button(fast_forward_buttons, "+7 дней", 7 * 24 * 60)
	_add_fast_forward_button(fast_forward_buttons, "+30 дней", 30 * 24 * 60)

	_fast_forward_status_label = Label.new()
	_fast_forward_status_label.add_theme_font_size_override("font_size", 11)
	layout.add_child(_fast_forward_status_label)


func _add_fast_forward_button(
	parent: HBoxContainer,
	button_text: String,
	minutes: int
) -> void:
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(_on_fast_forward_button_pressed.bind(minutes))
	parent.add_child(button)


func _on_fast_forward_button_pressed(minutes: int) -> void:
	game_clock.advance_minutes(minutes)


func _on_manual_advance_finished(minutes_advanced: int) -> void:
	if is_instance_valid(_fast_forward_status_label):
		_fast_forward_status_label.text = "Перемотано на %d игровых минут." % minutes_advanced
	_refresh_hud()


func _add_speed_button(parent: HBoxContainer, button_text: String, mode: int) -> void:
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(_on_speed_button_pressed.bind(mode))
	parent.add_child(button)


func _on_speed_button_pressed(mode: int) -> void:
	game_clock.set_speed_mode(mode)
	_refresh_hud()


func _on_minute_advanced(_day: int, _hour: int, _minute: int) -> void:
	if not game_clock.is_manual_fast_forward:
		_refresh_hud()


func _refresh_hud() -> void:
	if not is_instance_valid(game_clock):
		return

	if is_instance_valid(_time_label):
		_time_label.text = game_clock.get_clock_text()

	if is_instance_valid(_speed_label):
		_speed_label.text = game_clock.get_speed_text()
