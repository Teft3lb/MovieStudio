extends Node3D
class_name CharacterActor

const CHARACTER_VISUAL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_visual.gd"
)

var character_data: Variant
var _route: Array[Vector3] = []
var _route_index: int = 1
var _move_speed: float = 1.25
var _visual: Node3D
var _game_clock: Node
var _selection_ring: MeshInstance3D
var _workplace_building_id: String = ""
var _workplace_destination: Vector3 = Vector3.ZERO
var _has_workplace_destination: bool = false
var _is_at_workplace: bool = false


func setup(
	data: Variant,
	waypoints: Array[Vector3],
	game_clock: Node,
	move_speed: float = 1.25
) -> void:
	character_data = data
	_route = waypoints.duplicate()
	_game_clock = game_clock
	_move_speed = maxf(move_speed, 0.1)
	add_to_group("studio_employee")

	if not _route.is_empty():
		position = _route[0]

	_visual = CHARACTER_VISUAL_SCRIPT.new()
	var character_payload: Dictionary = data.call("to_dict")
	_visual.call("setup", character_payload)
	add_child(_visual)

	_create_name_tag()
	_create_selection_ring()
	_create_selection_hitbox()


func _process(delta: float) -> void:
	if not is_instance_valid(_game_clock):
		return

	var simulation_delta: float = float(
		_game_clock.call("get_simulation_delta", delta)
	)
	if is_zero_approx(simulation_delta):
		return

	if _has_workplace_destination:
		var workplace_direction: Vector3 = (
			_workplace_destination - global_position
		)
		workplace_direction.y = 0.0
		if workplace_direction.length_squared() <= 0.25:
			_is_at_workplace = true
			_set_walking(false)
			_advance_visual(simulation_delta)
			return

		_is_at_workplace = false
		workplace_direction = workplace_direction.normalized()
		global_position += workplace_direction * _move_speed * simulation_delta
		look_at(global_position + workplace_direction, Vector3.UP)
		_set_walking(true)
		_advance_visual(simulation_delta)
		return

	if _route.size() < 2:
		_set_walking(false)
		_advance_visual(simulation_delta)
		return

	var target: Vector3 = _route[_route_index]
	var direction: Vector3 = target - position
	direction.y = 0.0

	if direction.length_squared() <= 0.09:
		_route_index = (_route_index + 1) % _route.size()
		_set_walking(false)
		_advance_visual(simulation_delta)
		return

	direction = direction.normalized()
	position += direction * _move_speed * simulation_delta
	look_at(position + direction, Vector3.UP)
	_set_walking(true)
	_advance_visual(simulation_delta)


func get_character_id() -> String:
	if character_data == null:
		return ""
	return str(character_data.id)


func assign_workplace(building_id: String, destination: Vector3) -> void:
	if (
		_workplace_building_id == building_id
		and _has_workplace_destination
		and _workplace_destination.is_equal_approx(destination)
	):
		return

	_workplace_building_id = building_id
	_workplace_destination = destination
	_has_workplace_destination = true
	_is_at_workplace = false


func clear_workplace() -> void:
	_workplace_building_id = ""
	_has_workplace_destination = false
	_is_at_workplace = false


func get_workplace_building_id() -> String:
	return _workplace_building_id


func is_at_workplace() -> bool:
	return _is_at_workplace


func set_selected(value: bool) -> void:
	if is_instance_valid(_selection_ring):
		_selection_ring.visible = value


func _advance_visual(simulation_delta: float) -> void:
	if is_instance_valid(_visual):
		_visual.call("advance_simulation", simulation_delta)


func _set_walking(value: bool) -> void:
	if is_instance_valid(_visual):
		_visual.call("set_walking", value)


func _create_name_tag() -> void:
	var summary: Dictionary = character_data.call("get_ui_summary")

	var label := Label3D.new()
	label.name = "NameTag"
	label.text = str(summary.get("full_name", "Employee"))
	label.position = Vector3(0.0, 2.58, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 7
	label.modulate = Color(1.0, 0.96, 0.86)
	label.no_depth_test = true
	add_child(label)


func _create_selection_ring() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.48
	ring_mesh.outer_radius = 0.58
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8

	_selection_ring = MeshInstance3D.new()
	_selection_ring.name = "SelectionRing"
	_selection_ring.mesh = ring_mesh
	_selection_ring.position = Vector3(0.0, 0.035, 0.0)
	_selection_ring.visible = false

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.76, 0.2)
	ring_material.roughness = 0.45
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_ring.material_override = ring_material
	add_child(_selection_ring)


func _create_selection_hitbox() -> void:
	var hit_body := StaticBody3D.new()
	hit_body.name = "SelectionHitbox"
	hit_body.collision_layer = 2
	hit_body.collision_mask = 0

	var hit_shape := CollisionShape3D.new()
	hit_shape.name = "Capsule"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 2.65
	hit_shape.shape = capsule
	hit_shape.position = Vector3(0.0, 1.3, 0.0)

	hit_body.add_child(hit_shape)
	add_child(hit_body)
