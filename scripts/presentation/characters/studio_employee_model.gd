extends Node3D

const MODEL: PackedScene = preload("res://assets/models/characters/studio_employee.glb")
const COSTUME_CATALOG = preload("res://scripts/domain/studio/studio_costume_catalog.gd")
const ROLE_MESHES: Dictionary = {
	"actor": "RoleActor", "extra": "RoleActor",
	"director": "RoleDirector", "camera_operator": "RoleCamera",
	"technician": "RoleTechnician", "screenwriter": "RoleWriter",
	"film_editor": "RoleEditor", "producer": "RoleOffice",
	"casting_director": "RoleOffice", "production_designer": "RoleOffice",
	"maintenance_worker": "RoleTechnician", "cleaner": "RoleTechnician",
}
const COSTUME_MESHES: Dictionary = {
	"western_costumes": "CostumeWestern",
	"classic_period_costumes": "CostumePeriod",
	"science_fiction_costumes": "CostumeFuturistic",
}
const POSE_BONES: Array[String] = [
	"LeftArm", "RightArm", "LeftThigh", "RightThigh", "LeftShin", "RightShin",
]
const DISTANT_ANIMATION_DISTANCE_SQUARED: float = 32.0 * 32.0
const DISTANT_ANIMATION_INTERVAL: float = 1.0 / 30.0
const HAIR_STYLE_COUNT: int = 8

static var _tinted_materials: Dictionary[String, StandardMaterial3D] = {}
static var _states: AnimationNodeStateMachine

var _skeleton: Skeleton3D
var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _mesh_nodes: Array[MeshInstance3D] = []
var _bone_indices: Dictionary[String, int] = {}
var _role_name: String
var _hair_name: String
var _idle_state: StringName
var _animation_state: StringName
var _outfit: Color
var _head_scale: Vector3
var _phase_offset: float
var _started: bool = false
var _costume_id: String
var _pending_delta: float = 0.0


func setup(
	payload: Dictionary, skin: Color, hair: Color, outfit: Color, facial_scale: float
) -> MeshInstance3D:
	var imported := MODEL.instantiate() as Node3D
	add_child(imported)
	_skeleton = imported.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for bone_name in POSE_BONES + ["Head", "LeftForearm", "RightForearm"]:
		_bone_indices[bone_name] = _skeleton.find_bone(bone_name)
	var player := imported.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_setup_animation_tree(player)

	var appearance: Dictionary = payload.get("appearance", {})
	var identity_hash := str(payload.get("id", "")).hash()
	var silhouette: float = clampf(float(appearance.get("silhouette", identity_hash % 2)), 0.0, 1.0)
	var wardrobe_style := posmod(int(appearance.get("wardrobe_style", identity_hash / 3)), 3)
	var face_style := clampf(float(appearance.get("cheekbones", (identity_hash >> 5) % 5 / 4.0)), 0.0, 1.0)
	_role_name = str(ROLE_MESHES.get(str(payload.get("profession_id", "")), "RoleOffice"))
	var skirt := wardrobe_style == 2 and _role_name in ["RoleOffice", "RoleActor"]
	_hair_name = "Hair%d" % posmod(int(appearance.get("hair_style", 0)), HAIR_STYLE_COUNT)
	_idle_state = &"Idle" if identity_hash % 2 == 0 else &"IdleLook"
	_phase_offset = float(identity_hash % 997) / 997.0
	var width := lerpf(0.96, 1.09, _phase_offset)
	_head_scale = Vector3(width, 1.025, lerpf(1.00, 1.06, face_style)) * facial_scale
	_outfit = outfit

	var mouth: MeshInstance3D
	for node in imported.find_children("*", "MeshInstance3D", true, false):
		var model_mesh := node as MeshInstance3D
		if model_mesh.name == &"MouthShape":
			mouth = model_mesh
			continue
		if str(model_mesh.name).begins_with("Role"):
			if model_mesh.name != _role_name:
				model_mesh.free()
				continue
		elif str(model_mesh.name).begins_with("Costume"):
			model_mesh.hide()
		elif str(model_mesh.name).begins_with("Hair"):
			if model_mesh.name != _hair_name:
				model_mesh.free()
				continue
			model_mesh.visible = _role_name != "RoleDirector"
		elif model_mesh.name == &"CollarCrew":
			if wardrobe_style != 1:
				model_mesh.free()
				continue
		elif model_mesh.name == &"CollarFold":
			if wardrobe_style != 2:
				model_mesh.free()
				continue
		elif model_mesh.name == &"WardrobeSkirt":
			if not skirt:
				model_mesh.free()
				continue
		elif model_mesh.name == &"WardrobeBody":
			model_mesh.set_blend_shape_value(0, silhouette)
			model_mesh.set_blend_shape_value(1, 0.75 if wardrobe_style == 1 else 0.0)
			model_mesh.set_blend_shape_value(2, 0.85 if wardrobe_style == 2 else 0.0)
			model_mesh.set_blend_shape_value(3, 1.0 if skirt else 0.0)
		elif model_mesh.name == &"Face":
			model_mesh.set_blend_shape_value(0, silhouette)
			model_mesh.set_blend_shape_value(1, face_style)
		_mesh_nodes.append(model_mesh)
	mouth.owner = null
	mouth.get_parent().remove_child(mouth)
	_tint_surfaces("Skin", skin)
	_tint_surfaces("Hair", hair)
	_tint_surfaces("Cloth", outfit)
	if wardrobe_style == 1:
		_tint_surfaces("ShoeUpper", Color(0.23, 0.18, 0.15))
		var knit := outfit.lerp(Color(0.65, 0.62, 0.51), 0.46)
		_tint_surfaces("KnitTrim", knit)
		_tint_surfaces("Cotton", knit)
	elif wardrobe_style == 2:
		_tint_surfaces("ShoeUpper", Color(0.11, 0.13, 0.15))
		_tint_surfaces("KnitTrim", outfit.darkened(0.32))
	return mouth


func set_hair_color(color: Color) -> void:
	_tint_surfaces("Hair", color)


func set_costume(costume_id: String) -> void:
	if costume_id == _costume_id:
		return
	_costume_id = costume_id
	var costume: Dictionary = COSTUME_CATALOG.get_costume_definition(costume_id)
	var costume_mesh: String = COSTUME_MESHES.get(costume_id, "")
	_tint_surfaces("Cloth", costume.get("visual_color", _outfit))
	for part in _mesh_nodes:
		if part.name == _role_name:
			part.visible = costume.is_empty()
		elif part.name == &"WardrobeSkirt":
			part.visible = costume.is_empty()
		elif part.name == _hair_name:
			part.visible = costume_mesh != "CostumeWestern" and (
				_role_name != "RoleDirector" or not costume.is_empty()
			)
		elif str(part.name).begins_with("Costume"):
			part.visible = part.name == costume_mesh


func advance(
	delta: float, state: StringName, pose_pivots: Array[Node3D], head: Node3D, carrying: bool
) -> void:
	if not is_inside_tree():
		return
	if state == &"Idle":
		state = _idle_state
	var ambient_state: bool = state == _idle_state or state == &"Walk"
	if ambient_state and state == _animation_state and not carrying and delta > 0.0:
		var camera := get_viewport().get_camera_3d()
		if camera != null and global_position.distance_squared_to(camera.global_position) > DISTANT_ANIMATION_DISTANCE_SQUARED:
			_pending_delta += delta
			if _pending_delta + 0.00001 < DISTANT_ANIMATION_INTERVAL:
				return
			delta = 0.0
	delta += _pending_delta
	_pending_delta = 0.0
	if not _started:
		_playback.start(state)
		_tree.advance(0.0)
		if state == _idle_state:
			_tree.advance(_phase_offset * 2.0)
		_started = true
	elif state != _animation_state:
		_playback.travel(state)
	_animation_state = state
	_tree.advance(delta)

	var head_index: int = _bone_indices["Head"]
	if state in [&"Idle", &"IdleLook", &"Walk", &"Turn"]:
		if carrying:
			_set_joint_pitch("LeftArm", pose_pivots[0].rotation.x)
			_set_joint_pitch("RightArm", pose_pivots[1].rotation.x)
	else:
		for index in POSE_BONES.size():
			_set_joint_pitch(POSE_BONES[index], pose_pivots[index].rotation.x)
		_skeleton.set_bone_pose_rotation(head_index, head.quaternion)
	_skeleton.set_bone_pose_scale(head_index, _head_scale)
	# The original dialogue mesh follows the skeletal head, including chest motion.
	head.transform = _skeleton.get_bone_global_pose(head_index)


func _set_joint_pitch(bone_name: String, radians: float) -> void:
	_skeleton.set_bone_pose_rotation(_bone_indices[bone_name], Quaternion(Vector3.RIGHT, radians))


func apply_keyboard_pose(slot: OfficeInteractionSlot, seated: float, phase: float) -> void:
	var influence := smoothstep(0.55, 1.0, seated)
	if influence <= 0.0:
		return
	var left := slot.left_hand.global_position + Vector3.UP * (0.012 * sin(phase * 5.8))
	var right := slot.right_hand.global_position + Vector3.UP * (0.012 * sin(phase * 5.1 + PI))
	_reach("Left", _skeleton.to_local(left), Vector3(-0.55, -1.0, 0.0), influence)
	_reach("Right", _skeleton.to_local(right), Vector3(0.55, -1.0, 0.0), influence)


func _reach(side: String, target: Vector3, pole: Vector3, influence: float) -> void:
	var upper: int = _bone_indices[side + "Arm"]
	var forearm: int = _bone_indices[side + "Forearm"]
	var shoulder := _skeleton.get_bone_global_pose(upper).origin
	var axis := (target - shoulder).normalized()
	var bend := (pole - axis * pole.dot(axis)).normalized()
	if axis.is_zero_approx() or bend.is_zero_approx():
		return
	var upper_rest := _skeleton.get_bone_rest(forearm).origin
	var upper_length := upper_rest.length()
	var lower_length: float = 0.36
	var distance := clampf(shoulder.distance_to(target), 0.10, upper_length + lower_length - 0.015)
	var projected := (distance * distance + upper_length * upper_length - lower_length * lower_length) / (2.0 * distance)
	var elbow := shoulder + axis * projected + bend * sqrt(maxf(upper_length * upper_length - projected * projected, 0.0))
	var wrist := shoulder + axis * distance
	_aim_arm_bone(upper, upper_rest.normalized(), (elbow - shoulder).normalized(), influence)
	_aim_arm_bone(forearm, Vector3.DOWN, (wrist - elbow).normalized(), influence)


func _aim_arm_bone(bone: int, rest_axis: Vector3, target_axis: Vector3, influence: float) -> void:
	var parent := _skeleton.get_bone_global_pose(_skeleton.get_bone_parent(bone)).basis.orthonormalized()
	var desired := parent.get_rotation_quaternion().inverse() * Quaternion(rest_axis, target_axis)
	var current := _skeleton.get_bone_pose_rotation(bone)
	_skeleton.set_bone_pose_rotation(bone, current.slerp(desired, influence))


func _setup_animation_tree(player: AnimationPlayer) -> void:
	if _states == null:
		_states = AnimationNodeStateMachine.new()
		var clips := player.get_animation_list()
		for clip in clips:
			if clip == &"RESET":
				continue
			var animation := AnimationNodeAnimation.new()
			animation.animation = clip
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			_states.add_node(clip, animation)
		for source in clips:
			if source == &"RESET":
				continue
			for target in clips:
				if target == &"RESET" or target == source:
					continue
				var transition := AnimationNodeStateMachineTransition.new()
				transition.xfade_time = 0.14
				_states.add_transition(source, target, transition)
	_tree = AnimationTree.new()
	_tree.name = "EmployeeAnimationTree"
	add_child(_tree)
	_tree.root_node = _tree.get_path_to(player.get_node(player.root_node))
	_tree.anim_player = _tree.get_path_to(player)
	_tree.tree_root = _states
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.active = true
	_playback = _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback


func _tint_surfaces(slot: String, color: Color) -> void:
	var key := slot + ":" + color.to_html(false)
	for part in _mesh_nodes:
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null or original.resource_name != slot:
				continue
			if not _tinted_materials.has(key):
				var material := original.duplicate() as StandardMaterial3D
				material.albedo_color = color
				_tinted_materials[key] = material
			part.set_surface_override_material(surface, _tinted_materials[key])
