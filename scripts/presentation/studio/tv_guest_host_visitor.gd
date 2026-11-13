extends Node3D
class_name TVGuestHostVisitor

# Transient visual NPC. The external host is deliberately not a CharacterData
# employee in CharacterManager: no salary, contract, roster or staffing slot.
const CHARACTER_VISUAL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_visual.gd"
)

const MOVE_SPEED: float = 1.9
var _game_clock: Node
var _visual: Node3D
var _path: Array[Vector3] = []
var _waypoint_index: int = 0
var _travelling: bool = false
var _departing: bool = false
var _departed: bool = false
var _at_mark: bool = false


func setup(host: Dictionary, game_clock: Node, arrival_route: Array[Vector3]) -> void:
	_game_clock = game_clock
	name = "ExternalTVHost_%s" % str(host.get("id", "visitor"))
	var appearance: Dictionary = {
		"skin_tone": 0,
		"hair_color": 1,
		"outfit_color": 6,
		"hair_style": 1,
		"height_scale": 1.0,
		"head_scale": 1.0,
	}
	if str(host.get("id", "")).ends_with("VALE"):
		appearance["hair_color"] = 3
		appearance["outfit_color"] = 7
		appearance["hair_style"] = 2
	elif str(host.get("id", "")).ends_with("HALE"):
		appearance["hair_color"] = 4
		appearance["outfit_color"] = 0
	_visual = CHARACTER_VISUAL_SCRIPT.new()
	_visual.name = "ExternalPresenterVisual"
	add_child(_visual)
	_visual.call("setup", {"appearance": appearance})
	_assign_path(arrival_route)


func _process(delta: float) -> void:
	if not _travelling:
		if _at_mark and is_instance_valid(_visual):
			_visual.call("advance_animation", delta)
		return
	if not is_instance_valid(_game_clock):
		return
	var game_delta: float = float(
		_game_clock.call("get_simulation_delta", delta)
	)
	if game_delta <= 0.0:
		return
	if _waypoint_index >= _path.size():
		_finish_path()
		return
	var destination: Vector3 = _path[_waypoint_index]
	var previous_position: Vector3 = global_position
	global_position = global_position.move_toward(
		destination, MOVE_SPEED * game_delta
	)
	var facing: Vector3 = destination - previous_position
	facing.y = 0.0
	if facing.length_squared() > 0.002:
		look_at(global_position + facing.normalized(), Vector3.UP)
	if is_instance_valid(_visual):
		_visual.call("set_walking", true)
		_visual.call("advance_animation", game_delta)
	if global_position.distance_to(destination) <= 0.08:
		_waypoint_index += 1
		if _waypoint_index >= _path.size():
			_finish_path()


func depart(exit_route: Array[Vector3]) -> void:
	if _departing or _departed:
		return
	_departing = true
	_at_mark = false
	if exit_route.size() < 2:
		push_warning("TVGuestHostVisitor: departure route is unavailable.")
		return
	_assign_path(exit_route)


func has_arrived() -> bool:
	return _at_mark and not _departing


func has_departed() -> bool:
	return _departed


func is_external_guest() -> bool:
	return true


func _assign_path(route: Array[Vector3]) -> void:
	if route.is_empty():
		return
	_path = route.duplicate()
	global_position = route.front()
	_waypoint_index = 1
	_travelling = route.size() > 1
	if not _travelling:
		_finish_path()


func _finish_path() -> void:
	_travelling = false
	if is_instance_valid(_visual):
		_visual.call("set_walking", false)
	if _departing:
		_departed = true
		_at_mark = false
	else:
		_at_mark = true
		if is_instance_valid(_visual):
			_visual.call("set_performance_action", "speaking")
