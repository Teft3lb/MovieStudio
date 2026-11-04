extends Camera3D
class_name OrbitCameraController

@export var movement_speed: float = 16.0
@export var fast_movement_multiplier: float = 3.0
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.004
@export_range(0.02, 0.3, 0.01) var zoom_factor: float = 0.12
@export var min_distance: float = 5.0
@export var max_distance: float = 70.0

var focus_point: Vector3 = Vector3.ZERO
var orbit_distance: float = 22.0

var _yaw: float = deg_to_rad(45.0)
var _pitch: float = deg_to_rad(35.0)
var _rotating: bool = false
var _panning: bool = false


func _ready() -> void:
	current = true
	_update_camera_transform()


func _process(delta: float) -> void:
	_process_keyboard_movement(delta)
	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_rotating = event.pressed
		get_viewport().set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		_panning = event.pressed
		get_viewport().set_input_as_handled()
		return

	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		orbit_distance = maxf(min_distance, orbit_distance * (1.0 - zoom_factor))
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		orbit_distance = minf(max_distance, orbit_distance * (1.0 + zoom_factor))
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _rotating:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(
			_pitch + event.relative.y * mouse_sensitivity,
			deg_to_rad(15.0),
			deg_to_rad(80.0)
		)
		get_viewport().set_input_as_handled()
	elif _panning:
		var right: Vector3 = Vector3(cos(_yaw), 0.0, -sin(_yaw))
		var forward: Vector3 = Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var pan_scale: float = orbit_distance * 0.0025
		focus_point += (-right * event.relative.x + forward * event.relative.y) * pan_scale
		get_viewport().set_input_as_handled()


func _process_keyboard_movement(delta: float) -> void:
	var horizontal: float = 0.0
	var vertical: float = 0.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vertical += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vertical -= 1.0

	var movement: Vector2 = Vector2(horizontal, vertical)
	if movement.length_squared() <= 0.0:
		return

	movement = movement.normalized()

	var right: Vector3 = Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var forward: Vector3 = Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var direction: Vector3 = right * movement.x + forward * movement.y

	var speed_multiplier: float = fast_movement_multiplier if (
		Input.is_key_pressed(KEY_SHIFT)
	) else 1.0

	var distance_scale: float = maxf(orbit_distance / 20.0, 0.5)
	focus_point += direction * movement_speed * speed_multiplier * distance_scale * delta


func _update_camera_transform() -> void:
	var horizontal_distance: float = cos(_pitch) * orbit_distance
	global_position = focus_point + Vector3(
		sin(_yaw) * horizontal_distance,
		sin(_pitch) * orbit_distance,
		cos(_yaw) * horizontal_distance
	)
	look_at(focus_point, Vector3.UP)
