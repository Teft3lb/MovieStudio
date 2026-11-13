extends RefCounted
class_name CharacterDragDropController

# Mouse gesture/feedback only. No work schedules or character stats live here.
const START_THRESHOLD_PX: float = 12.0
const FEEDBACK_SECONDS: float = 3.0

var _studio: Node3D
var _characters: Node
var _pending_employee_id: String = ""
var _pressed_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _hover_building_id: String = ""
var _hover_valid: bool = false
var _overlay: CanvasLayer
var _hint: Label
var _target_marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _message_seconds: float = 0.0


func setup(studio: Node3D, characters: Node) -> void:
	_studio = studio
	_characters = characters
	_overlay = CanvasLayer.new()
	_overlay.name = "CharacterDragHUD"
	_studio.add_child(_overlay)
	_hint = Label.new()
	_hint.name = "CharacterDropHint"
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_child(_hint)
	_target_marker = MeshInstance3D.new()
	_target_marker.name = "CharacterDragTargetRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 1.1
	ring.outer_radius = 1.28
	ring.rings = 12
	ring.ring_segments = 28
	_target_marker.mesh = ring
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.albedo_color = Color(0.3, 0.9, 0.45)
	_target_marker.material_override = _marker_material
	_target_marker.visible = false
	_studio.add_child(_target_marker)


func begin(employee_id: String, screen_position: Vector2) -> void:
	if employee_id.is_empty():
		return
	_pending_employee_id = employee_id
	_pressed_at = screen_position
	_dragging = false
	_hover_building_id = ""
	_hover_valid = false
	_message_seconds = 0.0
	_hint.visible = false
	_target_marker.visible = false


func is_pending() -> bool:
	return not _pending_employee_id.is_empty()


func is_dragging() -> bool:
	return _dragging


func on_motion(screen_position: Vector2) -> bool:
	if not is_pending():
		return false
	if not _dragging:
		if screen_position.distance_to(_pressed_at) < START_THRESHOLD_PX:
			return false
		_dragging = true
	if not is_instance_valid(_studio) or not is_instance_valid(_characters):
		cancel()
		return false
	var hit: Node = _studio.call("_get_building_actor_at", screen_position) as Node
	var new_building_id: String = (
		str(hit.call("get_building_id")) if hit != null else ""
	)
	if new_building_id != _hover_building_id:
		_hover_building_id = new_building_id
		_refresh_preview()
	_hint.position = screen_position + Vector2(17.0, -22.0)
	return true


func on_release(screen_position: Vector2) -> bool:
	if not is_pending():
		return false
	var was_dragging: bool = _dragging
	if was_dragging:
		# The last movement may be a release without a preceding motion.
		var target: Node = _studio.call(
			"_get_building_actor_at", screen_position
		) as Node
		_hover_building_id = (
			str(target.call("get_building_id")) if target != null else ""
		)
		var result: Dictionary = {
			"success": false,
			"message": "Отпустите персонажа над доступным зданием."
		}
		if not _hover_building_id.is_empty():
			result = _characters.call(
				"request_manual_activity",
				_pending_employee_id,
				_hover_building_id
			)
		_show_message(
			str(result.get("message", "Поручение не создано.")),
			bool(result.get("success", false)),
			screen_position
		)
	_pending_employee_id = ""
	_dragging = false
	_hover_building_id = ""
	_hover_valid = false
	_target_marker.visible = false
	if not was_dragging:
		_hint.visible = false
	return was_dragging


func cancel() -> void:
	_pending_employee_id = ""
	_dragging = false
	_hover_building_id = ""
	_hover_valid = false
	_target_marker.visible = false
	_hint.visible = false
	_message_seconds = 0.0


func advance(delta: float) -> void:
	if _dragging or _message_seconds <= 0.0:
		return
	_message_seconds -= delta
	if _message_seconds <= 0.0 and is_instance_valid(_hint):
		_hint.visible = false


func _refresh_preview() -> void:
	if _hover_building_id.is_empty():
		_hint.text = "Перетащите сотрудника на здание"
		_hint.add_theme_color_override("font_color", Color.WHITE)
		_hint.visible = true
		_target_marker.visible = false
		_hover_valid = false
		return
	var result: Dictionary = _characters.call(
		"get_manual_activity_preview",
		_pending_employee_id, _hover_building_id
	)
	_hover_valid = bool(result.get("success", false))
	_hint.text = (
		"%s · %d мин" % [
			str(result.get("title", "")),
			int(result.get("duration_minutes", 0))
		]
		if _hover_valid else str(result.get("message", "Недоступно"))
	)
	_hint.visible = true
	var color: Color = (
		Color(0.45, 1.0, 0.58)
		if _hover_valid else Color(1.0, 0.54, 0.48)
	)
	_hint.add_theme_color_override("font_color", color)
	_marker_material.albedo_color = color
	var route: Array[Vector3] = _studio.call(
		"get_workplace_path", _hover_building_id, 0
	)
	if not route.is_empty():
		_target_marker.global_position = route.front() + Vector3.UP * 0.08
	else:
		var actor: Node3D = _studio.call(
			"get_building_actor_by_id", _hover_building_id
		) as Node3D
		if not is_instance_valid(actor):
			_target_marker.visible = false
			return
		_target_marker.global_position = actor.global_position + Vector3.UP * 0.1
	_target_marker.visible = true


func _show_message(message: String, success: bool, point: Vector2) -> void:
	_hint.text = message
	_hint.position = point + Vector2(16.0, -24.0)
	_hint.add_theme_color_override(
		"font_color",
		Color(0.45, 1.0, 0.58) if success else Color(1.0, 0.54, 0.48)
	)
	_hint.visible = true
	_message_seconds = FEEDBACK_SECONDS
