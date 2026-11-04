extends Node3D
class_name CharacterVisual

const SKIN_TONES: Array[Color] = [
	Color(0.96, 0.78, 0.64),
	Color(0.83, 0.61, 0.45),
	Color(0.66, 0.43, 0.30),
	Color(0.45, 0.29, 0.22),
	Color(0.96, 0.84, 0.72),
	Color(0.72, 0.51, 0.39),
]

const HAIR_COLORS: Array[Color] = [
	Color(0.12, 0.09, 0.08),
	Color(0.28, 0.16, 0.09),
	Color(0.48, 0.29, 0.13),
	Color(0.72, 0.53, 0.25),
	Color(0.72, 0.70, 0.64),
	Color(0.22, 0.25, 0.29),
]

const OUTFIT_COLORS: Array[Color] = [
	Color(0.18, 0.25, 0.36),
	Color(0.42, 0.20, 0.19),
	Color(0.22, 0.34, 0.29),
	Color(0.58, 0.43, 0.26),
	Color(0.30, 0.30, 0.34),
	Color(0.60, 0.58, 0.49),
	Color(0.22, 0.38, 0.48),
	Color(0.48, 0.30, 0.42),
]

const TROUSER_COLOR: Color = Color(0.16, 0.18, 0.22)
const SHOE_COLOR: Color = Color(0.08, 0.075, 0.07)
const EYE_COLOR: Color = Color(0.94, 0.91, 0.84)
const PUPIL_COLOR: Color = Color(0.10, 0.085, 0.075)

var _body_root: Node3D
var _head_root: Node3D
var _left_arm_pivot: Node3D
var _right_arm_pivot: Node3D
var _left_leg_pivot: Node3D
var _right_leg_pivot: Node3D

var _walking: bool = false
var _working: bool = false
var _work_style: String = ""
var _performing: bool = false
var _performance_action: String = ""
var _animation_phase: float = 0.0


func setup(character_payload: Dictionary) -> void:
	_build_model(character_payload)


func set_walking(value: bool) -> void:
	_walking = value
	if value:
		_working = false
		_performing = false
		_performance_action = ""
		_reset_upper_body_pose()


func set_working(value: bool, work_style: String = "") -> void:
	_working = value
	_work_style = work_style
	_performing = false
	_performance_action = ""
	if value:
		_walking = false
	_reset_upper_body_pose()


func _reset_upper_body_pose() -> void:
	if is_instance_valid(_body_root):
		_body_root.rotation = Vector3.ZERO
	if is_instance_valid(_head_root):
		_head_root.rotation = Vector3.ZERO


func set_performance_action(action_id: String) -> void:
	_performance_action = action_id
	_performing = not action_id.is_empty()
	if _performing:
		_walking = false
		_working = false


func is_performing() -> bool:
	return _performing


func is_working() -> bool:
	return _working


func advance_simulation(simulation_delta: float) -> void:
	_animation_phase += simulation_delta * (
		7.2 if _walking else 3.0 if _working else 1.8
	)

	if _walking:
		var swing: float = sin(_animation_phase) * 0.55
		_set_arm_pose(swing, -swing)
		_set_leg_pose(-swing, swing)
	elif _performing:
		_advance_performance_animation()
	elif _working:
		_advance_work_animation()
	else:
		_set_arm_pose(0.0, 0.0)
		_set_leg_pose(0.0, 0.0)
		if is_instance_valid(_body_root):
			_body_root.rotation = Vector3.ZERO
		if is_instance_valid(_head_root):
			_head_root.rotation = Vector3.ZERO

	if is_instance_valid(_body_root):
		var bob_amount: float = (
			0.022 if _walking else 0.008 if _working else 0.006
		)
		_body_root.position.y = sin(_animation_phase * 2.0) * bob_amount


func _advance_performance_animation() -> void:
	var motion: float = sin(_animation_phase * 4.0) * 0.16
	var left_arm: float = -0.18
	var right_arm: float = -0.18
	var body_lean: float = 0.0
	var head_motion: float = sin(_animation_phase * 2.2) * 0.06

	match _performance_action:
		"speaking":
			left_arm = -0.38 + motion
			right_arm = -0.78 + sin(_animation_phase * 2.0) * 0.22
			head_motion *= 1.6
		"reacting":
			left_arm = -0.88 + motion * 0.35
			right_arm = -0.88 - motion * 0.35
			body_lean = -0.035
		"dramatic":
			left_arm = -1.02 + sin(_animation_phase * 1.7) * 0.18
			right_arm = -1.02 - sin(_animation_phase * 1.7) * 0.18
			body_lean = sin(_animation_phase * 1.3) * 0.055
		"pointing":
			left_arm = -0.22 + motion * 0.2
			right_arm = -1.18 + sin(_animation_phase * 1.4) * 0.12
			body_lean = -0.025
		"greeting":
			left_arm = -0.18
			right_arm = -1.28 + sin(_animation_phase * 2.4) * 0.24
		"searching":
			left_arm = -0.64 + motion * 0.2
			right_arm = -0.52 - motion * 0.2
			body_lean = 0.025
		"rehearsing":
			left_arm = -0.34 + motion * 0.45
			right_arm = -0.42 - motion * 0.45
		"directing":
			left_arm = -0.24 + motion * 0.3
			right_arm = -0.92 + sin(_animation_phase * 1.8) * 0.32
		"operating_camera":
			left_arm = -0.72 + motion * 0.25
			right_arm = -0.72 - motion * 0.25
		"checking_equipment":
			left_arm = -0.78 + motion
			right_arm = -0.82 - motion
		"reviewing":
			left_arm = -0.30 + motion * 0.2
			right_arm = -0.30 - motion * 0.2
		"coordinating":
			left_arm = -0.42 + motion * 0.35
			right_arm = -0.66 - motion * 0.35
		_:
			left_arm = -0.22 + motion * 0.3
			right_arm = -0.22 - motion * 0.3

	_set_arm_pose(left_arm, right_arm)
	_set_leg_pose(
		sin(_animation_phase * 1.5) * 0.035,
		-sin(_animation_phase * 1.5) * 0.035
	)
	if is_instance_valid(_body_root):
		_body_root.rotation = Vector3(0.0, 0.0, body_lean)
	if is_instance_valid(_head_root):
		_head_root.rotation.x = head_motion


func _advance_work_animation() -> void:
	var motion: float = sin(_animation_phase * 3.6) * 0.10
	var left_arm: float = -0.12
	var right_arm: float = -0.12

	match _work_style:
		"screenwriter", "producer", "casting_director", "production_designer":
			left_arm = -0.48 + motion
			right_arm = -0.52 - motion
		"camera_operator":
			left_arm = -0.58 + motion * 0.45
			right_arm = -0.58 - motion * 0.45
		"director":
			left_arm = -0.20 + motion * 0.35
			right_arm = -0.78 + sin(_animation_phase * 1.8) * 0.28
		"actor", "extra":
			left_arm = -0.18 + sin(_animation_phase * 1.8) * 0.20
			right_arm = -0.18 - sin(_animation_phase * 1.8) * 0.20
		"technician":
			left_arm = -0.68 + motion
			right_arm = -0.72 - motion
		"film_editor":
			left_arm = -0.46 + sin(_animation_phase * 4.4) * 0.07
			right_arm = -0.46 - sin(_animation_phase * 4.4) * 0.07
			if is_instance_valid(_head_root):
				_head_root.rotation.x = 0.06 + sin(_animation_phase * 2.2) * 0.025
			if is_instance_valid(_body_root):
				_body_root.rotation.x = -0.025
		_:
			left_arm = -0.18 + motion * 0.25
			right_arm = -0.18 - motion * 0.25

	_set_arm_pose(left_arm, right_arm)
	_set_leg_pose(0.0, 0.0)


func _set_arm_pose(left_angle: float, right_angle: float) -> void:
	if is_instance_valid(_left_arm_pivot):
		_left_arm_pivot.rotation.x = left_angle
	if is_instance_valid(_right_arm_pivot):
		_right_arm_pivot.rotation.x = right_angle


func _set_leg_pose(left_angle: float, right_angle: float) -> void:
	if is_instance_valid(_left_leg_pivot):
		_left_leg_pivot.rotation.x = left_angle
	if is_instance_valid(_right_leg_pivot):
		_right_leg_pivot.rotation.x = right_angle


func _build_model(character_payload: Dictionary) -> void:
	var appearance: Dictionary = character_payload.get("appearance", {})

	var skin_color: Color = SKIN_TONES[
		posmod(int(appearance.get("skin_tone", 0)), SKIN_TONES.size())
	]
	var hair_color: Color = HAIR_COLORS[
		posmod(int(appearance.get("hair_color", 0)), HAIR_COLORS.size())
	]
	var outfit_color: Color = OUTFIT_COLORS[
		posmod(int(appearance.get("outfit_color", 0)), OUTFIT_COLORS.size())
	]
	var hair_style: int = int(appearance.get("hair_style", 0))
	var height_scale: float = float(appearance.get("height_scale", 1.0))
	var head_scale: float = float(appearance.get("head_scale", 1.0))

	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	_body_root.scale = Vector3(1.0, height_scale, 1.0)
	add_child(_body_root)

	_create_capsule(
		_body_root, "Trousers", 0.22, 0.48, TROUSER_COLOR, Vector3(0.0, 0.91, 0.0)
	)
	_create_capsule(
		_body_root, "Jacket", 0.275, 0.92, outfit_color, Vector3(0.0, 1.43, 0.0)
	)
	_create_capsule(
		_body_root, "Neck", 0.09, 0.20, skin_color, Vector3(0.0, 1.94, 0.0)
	)

	_head_root = Node3D.new()
	_head_root.name = "Head"
	var head_root: Node3D = _head_root
	head_root.position = Vector3(0.0, 2.17, 0.0)
	head_root.scale = Vector3.ONE * head_scale
	_body_root.add_child(head_root)

	_create_sphere(head_root, "Face", 0.235, skin_color, Vector3.ZERO)

	var hair_cap := _create_sphere(
		head_root, "HairCap", 0.24, hair_color, Vector3(0.0, 0.135, 0.0)
	)
	hair_cap.scale = Vector3(1.0, 0.52, 1.0)

	if hair_style == 1:
		var back_hair := _create_sphere(
			head_root, "BackHair", 0.19, hair_color, Vector3(0.0, -0.015, 0.115)
		)
		back_hair.scale = Vector3(0.88, 1.05, 0.75)
	elif hair_style == 2:
		var fringe := _create_sphere(
			head_root, "Fringe", 0.15, hair_color, Vector3(0.0, 0.105, -0.145)
		)
		fringe.scale = Vector3(1.0, 0.48, 0.52)

	_create_sphere(
		head_root, "LeftEar", 0.055, skin_color, Vector3(-0.225, 0.0, 0.0)
	)
	_create_sphere(
		head_root, "RightEar", 0.055, skin_color, Vector3(0.225, 0.0, 0.0)
	)

	for side in [-1.0, 1.0]:
		var eye_x: float = side * 0.078
		_create_sphere(
			head_root, "EyeWhite", 0.032, EYE_COLOR,
			Vector3(eye_x, 0.025, -0.204)
		)
		_create_sphere(
			head_root, "Pupil", 0.015, PUPIL_COLOR,
			Vector3(eye_x, 0.022, -0.231)
		)
		_create_box(
			head_root, "Eyebrow", Vector3(0.075, 0.014, 0.012),
			hair_color, Vector3(eye_x, 0.082, -0.207)
		)

	_create_sphere(
		head_root, "Nose", 0.035, skin_color, Vector3(0.0, -0.045, -0.218)
	)
	_create_box(
		head_root, "Mouth", Vector3(0.072, 0.012, 0.012),
		Color(0.32, 0.12, 0.12), Vector3(0.0, -0.112, -0.211)
	)

	_left_arm_pivot = Node3D.new()
	_left_arm_pivot.name = "LeftArmPivot"
	_left_arm_pivot.position = Vector3(-0.34, 1.76, 0.0)
	_body_root.add_child(_left_arm_pivot)
	_create_capsule(
		_left_arm_pivot, "LeftSleeve", 0.105, 0.70, outfit_color,
		Vector3(0.0, -0.32, 0.0)
	)
	_create_sphere(
		_left_arm_pivot, "LeftHand", 0.085, skin_color,
		Vector3(0.0, -0.68, 0.0)
	)

	_right_arm_pivot = Node3D.new()
	_right_arm_pivot.name = "RightArmPivot"
	_right_arm_pivot.position = Vector3(0.34, 1.76, 0.0)
	_body_root.add_child(_right_arm_pivot)
	_create_capsule(
		_right_arm_pivot, "RightSleeve", 0.105, 0.70, outfit_color,
		Vector3(0.0, -0.32, 0.0)
	)
	_create_sphere(
		_right_arm_pivot, "RightHand", 0.085, skin_color,
		Vector3(0.0, -0.68, 0.0)
	)

	_left_leg_pivot = Node3D.new()
	_left_leg_pivot.name = "LeftLegPivot"
	_left_leg_pivot.position = Vector3(-0.14, 0.83, 0.0)
	_body_root.add_child(_left_leg_pivot)
	_create_capsule(
		_left_leg_pivot, "LeftLeg", 0.125, 0.86, TROUSER_COLOR,
		Vector3(0.0, -0.36, 0.0)
	)
	_create_box(
		_left_leg_pivot, "LeftShoe", Vector3(0.25, 0.13, 0.36),
		SHOE_COLOR, Vector3(0.0, -0.78, -0.07)
	)

	_right_leg_pivot = Node3D.new()
	_right_leg_pivot.name = "RightLegPivot"
	_right_leg_pivot.position = Vector3(0.14, 0.83, 0.0)
	_body_root.add_child(_right_leg_pivot)
	_create_capsule(
		_right_leg_pivot, "RightLeg", 0.125, 0.86, TROUSER_COLOR,
		Vector3(0.0, -0.36, 0.0)
	)
	_create_box(
		_right_leg_pivot, "RightShoe", Vector3(0.25, 0.13, 0.36),
		SHOE_COLOR, Vector3(0.0, -0.78, -0.07)
	)


func _create_capsule(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _make_material(color)
	instance.position = local_position
	parent.add_child(instance)
	return instance


func _create_sphere(
	parent: Node3D,
	node_name: String,
	radius: float,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _make_material(color)
	instance.position = local_position
	parent.add_child(instance)
	return instance


func _create_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	local_position: Vector3
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _make_material(color)
	instance.position = local_position
	parent.add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
