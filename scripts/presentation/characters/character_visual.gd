extends Node3D
class_name CharacterVisual

const EMPLOYEE_MODEL = preload("res://scripts/presentation/characters/studio_employee_model.gd")

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

var _employee_model: Node3D
var _body_root: Node3D
var _head_root: Node3D
var _left_arm_pivot: Node3D
var _right_arm_pivot: Node3D
var _left_leg_pivot: Node3D
var _right_leg_pivot: Node3D
var _left_knee_pivot: Node3D
var _right_knee_pivot: Node3D
var _mouth_node: MeshInstance3D
var _carried_prop_root: Node3D
var _pose_pivots: Array[Node3D] = []
var _body_base_scale: Vector3 = Vector3.ONE
var _base_hair_color: Color = Color.WHITE
var _character_age: int = -1

var _walking: bool = false
var _working: bool = false
var _work_style: String = ""
var _performing: bool = false
var _performance_action: String = ""
var _animation_phase: float = 0.0
var _last_facing: float = 0.0
var _turn_time: float = 0.0
var _seat_blend: float = 0.0
var _seat_drop: float = 0.28
var _office_interaction: OfficeInteractionSlot


func setup(character_payload: Dictionary) -> void:
	_build_model(character_payload)


func set_character_age(age: int) -> void:
	var normalized_age := maxi(age, 18)
	if _character_age == normalized_age:
		return
	_character_age = normalized_age
	var grey_factor: float = clampf(
		(float(_character_age) - 43.0) / 32.0,
		0.0,
		0.88
	)
	var aged_hair_color: Color = _base_hair_color.lerp(
		Color(0.68, 0.68, 0.66, 1.0),
		grey_factor
	)
	_employee_model.call("set_hair_color", aged_hair_color)


func set_costume(costume_id: String) -> void:
	_employee_model.call("set_costume", costume_id)


func set_office_interaction(interaction: OfficeInteractionSlot) -> void:
	_office_interaction = interaction

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
		_body_root.position.y = 0.0
		_body_root.scale = _body_base_scale
	if is_instance_valid(_head_root):
		_head_root.rotation = Vector3.ZERO
	if is_instance_valid(_mouth_node):
		_mouth_node.scale.y = 1.0


func set_performance_action(action_id: String) -> void:
	_performance_action = action_id
	_performing = not action_id.is_empty()
	if _performing:
		_walking = false
		_working = false
	elif is_instance_valid(_mouth_node):
		_mouth_node.scale.y = 1.0


func set_carrying_prop(value: bool) -> void:
	if is_instance_valid(_carried_prop_root):
		_carried_prop_root.visible = value


func is_performing() -> bool:
	return _performing


func is_working() -> bool:
	return _working


func advance_simulation(simulation_delta: float) -> void:
	_animation_phase += simulation_delta * (
		7.2 if _walking else 4.8 if _performing else 3.0 if _working else 1.8
	)

	var carrying: bool = _carried_prop_root.visible
	var is_eating: bool = _performing and _performance_action == "eating"
	var is_at_desk: bool = _working and is_instance_valid(_office_interaction)
	_seat_blend = move_toward(
		_seat_blend, 1.0 if is_eating or is_at_desk else 0.0, simulation_delta / 0.24
	)
	if is_at_desk:
		var seat := _office_interaction.get_node("Seat") as Marker3D
		_seat_drop = 0.85 * _body_base_scale.y - seat.position.y
	elif is_eating:
		_seat_drop = 0.28
	if _walking:
		var swing: float = sin(_animation_phase) * 0.55
		if carrying:
			_set_arm_pose(0.82 + swing * 0.08, 0.82 - swing * 0.08)
		else:
			_set_arm_pose(swing, -swing)
		_set_leg_pose(-swing, swing)
		_set_knee_pose(0.0, 0.0)
	elif _performing:
		_advance_performance_animation()
	elif _working:
		_set_knee_pose(0.0, 0.0)
		_advance_work_animation()
		if is_at_desk:
			_set_leg_pose(1.42 * _seat_blend, 1.42 * _seat_blend)
			_set_knee_pose(-1.42 * _seat_blend, -1.42 * _seat_blend)
			_body_root.rotation.x = -0.10 * _seat_blend
	else:
		_set_arm_pose(0.0, 0.0)
		_set_leg_pose(0.0, 0.0)
		_set_knee_pose(0.0, 0.0)
		if is_instance_valid(_body_root):
			_body_root.rotation = Vector3.ZERO
		if is_instance_valid(_head_root):
			_head_root.rotation = Vector3.ZERO

	if is_instance_valid(_body_root):
		var is_sleeping: bool = _performing and _performance_action == "sleeping"
		var pose_offset: float = 0.58 if is_sleeping else -_seat_drop * _seat_blend
		var bob_amount: float = (
			0.022 if _walking
			else 0.004 if is_sleeping
			else 0.018 if _performing
			else 0.008 if _working
			else 0.006
		)
		_body_root.position.y = pose_offset + sin(_animation_phase * 2.0) * bob_amount
		_body_root.scale = (
			Vector3(
				_body_base_scale.x,
				_body_base_scale.y * 0.72,
				_body_base_scale.z
			)
			if is_sleeping
			else _body_base_scale
		)
	_employee_model.call(
		"advance", simulation_delta, _get_skeletal_state(simulation_delta),
		_pose_pivots, _head_root, carrying
	)
	if is_at_desk:
		_employee_model.call("apply_keyboard_pose", _office_interaction, _seat_blend, _animation_phase)


func _get_skeletal_state(delta: float) -> StringName:
	var facing: float = get_parent_node_3d().rotation.y if get_parent_node_3d() != null else rotation.y
	if _walking or _performing or _working:
		_turn_time = 0.0
	elif absf(angle_difference(_last_facing, facing)) > 0.5:
		_turn_time = 0.65
	_last_facing = facing
	_turn_time = maxf(_turn_time - delta, 0.0)
	if _walking:
		return &"Walk"
	if _working:
		if is_instance_valid(_office_interaction):
			return &"DeskTyping"
		match _work_style:
			"screenwriter", "film_editor", "producer", "casting_director":
				return &"Typing"
			"camera_operator":
				return &"Camera"
			"technician":
				return &"Lift"
		return &"Gesture"
	if _performing:
		match _performance_action:
			"eating":
				return &"Eating"
			"sleeping", "waiting":
				return &"Rest"
			"operating_camera":
				return &"Camera"
			"placing_set_piece", "collecting_prop", "carrying_prop", "removing_set_piece", "storing_prop":
				return &"Lift"
		return &"Gesture"
	return &"Turn" if _turn_time > 0.0 else &"Idle"


func _advance_performance_animation() -> void:
	var motion: float = sin(_animation_phase * 4.0) * 0.25
	var left_arm: float = 0.18
	var right_arm: float = 0.18
	var body_lean: float = 0.0
	var head_motion: float = sin(_animation_phase * 2.2) * 0.06
	match _performance_action:
		"speaking":
			left_arm = 0.28 - motion * 0.9
			right_arm = 0.72 - sin(_animation_phase * 2.0) * 0.32
			body_lean = sin(_animation_phase * 1.4) * 0.045
			head_motion *= 1.8
		"reacting":
			left_arm = 0.96 - motion * 0.45
			right_arm = 0.96 + motion * 0.45
			body_lean = sin(_animation_phase * 1.5) * 0.045
		"dramatic":
			left_arm = 1.12 - sin(_animation_phase * 1.7) * 0.28
			right_arm = 1.12 + sin(_animation_phase * 1.7) * 0.28
			body_lean = sin(_animation_phase * 1.3) * 0.09
		"pointing":
			left_arm = 0.28 - motion * 0.25
			right_arm = 1.35 - sin(_animation_phase * 1.4) * 0.18
			body_lean = -0.045
		"greeting":
			left_arm = 0.18
			right_arm = 1.35 - sin(_animation_phase * 2.4) * 0.34
			body_lean = sin(_animation_phase * 1.2) * 0.025
		"searching":
			left_arm = 0.72 - motion * 0.35
			right_arm = 0.55 + motion * 0.3
			body_lean = sin(_animation_phase * 1.1) * 0.045
		"rehearsing":
			left_arm = 0.28 - motion * 0.75
			right_arm = 0.48 + motion * 0.75
			body_lean = sin(_animation_phase * 1.5) * 0.04
		"waiting":
			left_arm = 0.12 - motion * 0.12
			right_arm = 0.12 + motion * 0.12
			head_motion *= 0.5
		"training":
			left_arm = 0.70 + sin(_animation_phase * 2.8) * 0.52
			right_arm = 0.70 - sin(_animation_phase * 2.8) * 0.52
			body_lean = sin(_animation_phase * 1.4) * 0.045
			head_motion *= 0.7
		"socializing":
			left_arm = 0.30 + sin(_animation_phase * 1.8) * 0.42
			right_arm = 0.38 + sin(_animation_phase * 2.2 + 0.8) * 0.42
			body_lean = sin(_animation_phase * 1.2) * 0.035
			head_motion *= 1.4
		"eating":
			var left_reach: float = pow(
				maxf(sin(_animation_phase * 1.65), 0.0),
				1.2
			)
			var right_reach: float = pow(
				maxf(sin(_animation_phase * 1.65 - PI), 0.0),
				1.2
			)
			left_arm = lerpf(0.40, 1.45, left_reach)
			right_arm = lerpf(0.40, 1.45, right_reach)
			body_lean = 0.0
			head_motion = -0.035 - maxf(left_reach, right_reach) * 0.10
		"sleeping":
			left_arm = 0.02
			right_arm = 0.02
			body_lean = 0.0
			head_motion = sin(_animation_phase * 0.55) * 0.012
		"placing_set_piece":
			left_arm = 1.05 + sin(_animation_phase * 2.1) * 0.32
			right_arm = 1.10 - sin(_animation_phase * 2.1) * 0.32
			body_lean = 0.075 + sin(_animation_phase * 1.4) * 0.035
		"collecting_prop":
			left_arm = 0.98 + sin(_animation_phase * 1.8) * 0.16
			right_arm = 0.98 - sin(_animation_phase * 1.8) * 0.16
			body_lean = 0.10
		"carrying_prop":
			left_arm = 0.82 + sin(_animation_phase * 1.6) * 0.08
			right_arm = 0.82 - sin(_animation_phase * 1.6) * 0.08
			body_lean = 0.025
		"removing_set_piece":
			left_arm = 1.08 + sin(_animation_phase * 1.9) * 0.18
			right_arm = 1.02 - sin(_animation_phase * 1.9) * 0.18
			body_lean = 0.12
		"storing_prop":
			left_arm = 0.96 + sin(_animation_phase * 1.7) * 0.12
			right_arm = 0.96 - sin(_animation_phase * 1.7) * 0.12
			body_lean = 0.08
		"directing":
			left_arm = 0.24 - motion * 0.3
			right_arm = 0.92 - sin(_animation_phase * 1.8) * 0.32
		"operating_camera":
			left_arm = 0.28 + sin(_animation_phase * 1.7) * 0.10
			right_arm = 0.38 - sin(_animation_phase * 1.7) * 0.10
			body_lean = 0.035
		"checking_equipment":
			left_arm = 0.22 + sin(_animation_phase * 1.8) * 0.06
			right_arm = 0.48 + sin(_animation_phase * 2.7) * 0.12
			body_lean = 0.055
		"reviewing":
			left_arm = 0.30 - motion * 0.2
			right_arm = 0.30 + motion * 0.2
		"coordinating":
			left_arm = 0.42 - motion * 0.35
			right_arm = 0.66 + motion * 0.35
		_:
			left_arm = 0.22 - motion * 0.3
			right_arm = 0.22 + motion * 0.3
	_set_arm_pose(left_arm, right_arm)
	if is_instance_valid(_mouth_node):
		if _performance_action in ["speaking", "socializing"]:
			_mouth_node.scale.y = 1.0 + absf(sin(_animation_phase * 7.0)) * 2.2
		elif _performance_action == "eating":
			_mouth_node.scale.y = 1.0 + absf(sin(_animation_phase * 5.5)) * 0.35
		else:
			_mouth_node.scale.y = 1.0
	var leg_motion: float = sin(_animation_phase * 2.0) * 0.075
	if _performance_action == "eating":
		var seated_hip_angle: float = 1.18 * _seat_blend
		_set_leg_pose(
			seated_hip_angle + leg_motion * 0.12,
			seated_hip_angle - leg_motion * 0.12
		)
		_set_knee_pose(
			-seated_hip_angle - leg_motion * 0.12,
			-seated_hip_angle + leg_motion * 0.12
		)
	elif _performance_action == "sleeping":
		_set_leg_pose(0.0, 0.0)
		_set_knee_pose(0.0, 0.0)
	else:
		_set_leg_pose(leg_motion, -leg_motion)
		_set_knee_pose(0.0, 0.0)
	if is_instance_valid(_body_root):
		if _performance_action == "sleeping":
			_body_root.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		elif _performance_action == "eating":
			_body_root.rotation = Vector3(-0.07, 0.0, 0.0)
		else:
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
	_set_knee_pose(0.0, 0.0)


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


func _set_knee_pose(left_angle: float, right_angle: float) -> void:
	if is_instance_valid(_left_knee_pivot):
		_left_knee_pivot.rotation.x = left_angle
	if is_instance_valid(_right_knee_pivot):
		_right_knee_pivot.rotation.x = right_angle


func _build_model(character_payload: Dictionary) -> void:
	var appearance: Dictionary = character_payload.get("appearance", {})
	var skin := SKIN_TONES[posmod(int(appearance.get("skin_tone", 0)), SKIN_TONES.size())]
	var outfit := OUTFIT_COLORS[posmod(int(appearance.get("outfit_color", 0)), OUTFIT_COLORS.size())]
	_base_hair_color = HAIR_COLORS[posmod(int(appearance.get("hair_color", 0)), HAIR_COLORS.size())]
	var identity_hash := str(character_payload.get("id", "")).hash()
	var shoulder_scale := lerpf(0.88, 1.13, float(identity_hash % 211) / 210.0)
	var height_scale := clampf(float(appearance.get("height_scale", 1.0)), 0.9, 1.1)
	var head_scale := clampf(float(appearance.get("head_scale", 1.0)), 0.9, 1.1)
	_body_root = _make_pivot(self, "BodyRoot", Vector3.ZERO)
	_body_base_scale = Vector3(shoulder_scale, height_scale, 1.0)
	_body_root.scale = _body_base_scale

	_employee_model = EMPLOYEE_MODEL.new()
	_employee_model.name = "EmployeeModel"
	_body_root.add_child(_employee_model)
	_mouth_node = _employee_model.call("setup", character_payload, skin, _base_hair_color, outfit, head_scale)
	_mouth_node.name = "Mouth"
	_mouth_node.position = Vector3(0.0, -0.149, -0.188)
	_head_root = _make_pivot(_body_root, "Head", Vector3(0.0, 2.17, 0.0))
	_head_root.add_child(_mouth_node)

	_left_arm_pivot = _make_pivot(_body_root, "LeftArmPivot", Vector3(-0.34, 1.76, 0.0))
	_right_arm_pivot = _make_pivot(_body_root, "RightArmPivot", Vector3(0.34, 1.76, 0.0))
	_left_leg_pivot = _make_pivot(_body_root, "LeftLegPivot", Vector3(-0.14, 0.83, 0.0))
	_right_leg_pivot = _make_pivot(_body_root, "RightLegPivot", Vector3(0.14, 0.83, 0.0))
	_left_knee_pivot = _make_pivot(_left_leg_pivot, "LeftKneePivot", Vector3.DOWN * 0.46)
	_right_knee_pivot = _make_pivot(_right_leg_pivot, "RightKneePivot", Vector3.DOWN * 0.46)
	_pose_pivots = [
		_left_arm_pivot, _right_arm_pivot, _left_leg_pivot, _right_leg_pivot,
		_left_knee_pivot, _right_knee_pivot,
	]

	_carried_prop_root = _make_pivot(_body_root, "CarriedProp", Vector3(0.0, 1.08, -0.48))
	_create_box(_carried_prop_root, "PropTransportCase", Vector3(0.58, 0.4, 0.34),
		Color(0.42, 0.29, 0.17), Vector3.ZERO)
	_create_box(_carried_prop_root, "PropTransportCaseHandle", Vector3(0.24, 0.07, 0.08),
		Color(0.18, 0.19, 0.19), Vector3(0.0, 0.22, -0.02))
	_carried_prop_root.visible = false
	set_character_age(int(character_payload.get("age", 30)))


func _make_pivot(parent: Node3D, pivot_name: String, pivot_position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = pivot_position
	parent.add_child(pivot)
	return pivot


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
