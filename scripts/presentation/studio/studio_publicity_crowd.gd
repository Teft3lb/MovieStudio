extends Node3D
class_name StudioPublicityCrowd

# Lightweight non-employee visitors. Visuals have no collision, headcount,
# contracts or salary; they do not alter the employee navigation mesh.
const CHARACTER_VISUAL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_visual.gd"
)
const WALK_SPEED: float = 2.0

var _clock: Node
var _visitors: Array[Dictionary] = []
var _leaving: bool = false


func setup(
	clock: Node,
	event_id: String,
	door_position: Vector3,
	celebrity_mark: Vector3,
	count: int
) -> void:
	_clock = clock
	var direction: Vector3 = door_position - celebrity_mark
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var lateral: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	for index in range(clampi(count, 0, 10)):
		var fraction: float = (
			(float(index) / float(maxi(count - 1, 1))) - 0.5
		)
		var spot: Vector3 = (
			celebrity_mark + direction * (2.4 + float(index % 2) * 0.5)
			+ lateral * fraction * 5.0
		)
		var visitor := Node3D.new()
		visitor.name = "Paparazzi_%d" % index if event_id == "paparazzi" else "Fan_%d" % index
		add_child(visitor)
		var visual: Node3D = CHARACTER_VISUAL_SCRIPT.new()
		visitor.add_child(visual)
		visual.call("setup", {
			"appearance": {
				"skin_tone": index % 5,
				"hair_color": (index + 1) % 5,
				"outfit_color": (index + 3) % 8,
				"hair_style": index % 3,
				"height_scale": 0.92 + float(index % 4) * 0.045,
				"head_scale": 1.0,
			}
		})
		if event_id == "paparazzi":
			var camera_body := MeshInstance3D.new()
			camera_body.name = "PressCamera"
			var camera_mesh := BoxMesh.new()
			camera_mesh.size = Vector3(0.38, 0.22, 0.20)
			camera_body.mesh = camera_mesh
			camera_body.position = Vector3(0.0, 1.65, -0.36)
			var camera_material := StandardMaterial3D.new()
			camera_material.albedo_color = Color(0.08, 0.10, 0.12)
			camera_body.material_override = camera_material
			visitor.add_child(camera_body)
		var entrance: Vector3 = (
			door_position + lateral * fraction * 2.4
			+ direction * (1.0 + float(index % 3) * 0.5)
		)
		visitor.global_position = entrance
		_visitors.append({
			"actor": visitor,
			"visual": visual,
			"mark": spot,
			"exit": entrance,
			"reached": false,
			"departed": false,
		})


func _process(delta: float) -> void:
	if not is_instance_valid(_clock):
		return
	var elapsed: float = float(_clock.call("get_simulation_delta", delta))
	if elapsed <= 0.0:
		return
	for visitor_data in _visitors:
		var visitor: Node3D = visitor_data.get("actor") as Node3D
		if not is_instance_valid(visitor):
			continue
		var visual: Node3D = visitor_data.get("visual") as Node3D
		var destination: Vector3 = (
			visitor_data["exit"] if _leaving else visitor_data["mark"]
		)
		var remaining: float = visitor.global_position.distance_to(destination)
		if remaining > 0.08:
			visitor.global_position = visitor.global_position.move_toward(
				destination, WALK_SPEED * elapsed
			)
			var facing: Vector3 = destination - visitor.global_position
			facing.y = 0.0
			if facing.length_squared() > 0.01:
				visitor.look_at(visitor.global_position + facing, Vector3.UP)
			visual.call("set_walking", true)
		else:
			visual.call("set_walking", false)
			visual.call(
				"set_performance_action", "" if _leaving else "greeting"
			)
			if _leaving:
				visitor_data["departed"] = true
			else:
				visitor_data["reached"] = true
		visual.call("advance_simulation", elapsed)
	if _leaving and has_departed():
		queue_free()


func begin_departure() -> void:
	_leaving = true


func finish_manual_fast_forward() -> void:
	for visitor_data in _visitors:
		var actor: Node3D = visitor_data.get("actor") as Node3D
		if not is_instance_valid(actor):
			continue
		actor.global_position = (
			visitor_data["exit"] if _leaving else visitor_data["mark"]
		)
		visitor_data["departed" if _leaving else "reached"] = true
	if _leaving:
		queue_free()


func has_arrived() -> bool:
	for entry in _visitors:
		if not bool(entry.get("reached", false)):
			return false
	return true


func has_departed() -> bool:
	for entry in _visitors:
		if not bool(entry.get("departed", false)):
			return false
	return true
