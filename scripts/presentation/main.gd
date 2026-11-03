extends Node3D

@onready var game_clock: GameClock = $GameClock

var _time_label: Label
var _speed_label: Label


func _ready() -> void:
	game_clock.minute_advanced.connect(_on_minute_advanced)
	_build_debug_hud()
	_refresh_hud()


func _build_debug_hud() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "DebugHUD"
	add_child(canvas_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	canvas_layer.add_child(panel)

	var layout := VBoxContainer.new()
	panel.add_child(layout)

	var title := Label.new()
	title.text = "MOVIESTUDIO  |  FOUNDATION"
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


func _add_speed_button(parent: HBoxContainer, button_text: String, mode: int) -> void:
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(_on_speed_button_pressed.bind(mode))
	parent.add_child(button)


func _on_speed_button_pressed(mode: int) -> void:
	game_clock.set_speed_mode(mode)
	_refresh_hud()


func _on_minute_advanced(_day: int, _hour: int, _minute: int) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	if not is_instance_valid(game_clock):
		return

	if is_instance_valid(_time_label):
		_time_label.text = game_clock.get_clock_text()

	if is_instance_valid(_speed_label):
		_speed_label.text = game_clock.get_speed_text()
