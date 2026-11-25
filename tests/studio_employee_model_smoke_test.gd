extends "res://tests/smoke_test_base.gd"

const VISUAL = preload("res://scripts/presentation/characters/character_visual.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var payload := {
		"id": "EMP-VISUAL-TEST", "profession_id": "technician", "age": 28,
		"appearance": {"silhouette": 1.0, "hair_style": 1, "outfit_color": 4},
	}
	var visual := VISUAL.new()
	visual.setup(payload)
	root.add_child(visual)
	var skeleton := visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := visual.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var tree := visual.find_child("EmployeeAnimationTree", true, false) as AnimationTree
	var body := visual.find_child("WardrobeBody", true, false) as MeshInstance3D
	var role := visual.find_child("RoleTechnician", true, false) as MeshInstance3D
	var hair := visual.find_child("Hair1", true, false) as MeshInstance3D
	var western := visual.find_child("CostumeWestern", true, false) as MeshInstance3D
	_expect(skeleton.get_bone_count() == 13 and body.skin != null, "The employee wardrobe must be skinned to the shared rig.")
	_expect(is_equal_approx(body.get_blend_shape_value(0), 1.0), "Saved silhouette parameters must select the authored morph.")
	_expect(role.visible and hair.visible, "Profession equipment and saved hair must select their respective modules.")
	_expect(player.has_animation("Walk") and player.has_animation("Camera") and player.has_animation("Rest"),
		"The imported source must expose the authored locomotion and activity clips.")
	_expect(tree.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"The game clock must own advancement of the animation tree.")

	visual.set_walking(true)
	visual.advance_simulation(0.1)
	var knee := skeleton.find_bone("LeftShin")
	var first_pose := skeleton.get_bone_pose_rotation(knee)
	visual.advance_simulation(0.2)
	var next_pose := skeleton.get_bone_pose_rotation(knee)
	_expect(not first_pose.is_equal_approx(next_pose), "The authored walking clip must animate visible skinned joints.")
	visual.advance_simulation(0.0)
	_expect(skeleton.get_bone_pose_rotation(knee).is_equal_approx(next_pose), "A paused simulation must preserve the skeletal pose.")

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position.z = 40.0
	camera.make_current()
	visual.advance_simulation(1.0 / 60.0)
	_expect(skeleton.get_bone_pose_rotation(knee).is_equal_approx(next_pose), "A distant walking rig may skip the first visual update.")
	visual.advance_simulation(1.0 / 60.0)
	_expect(not skeleton.get_bone_pose_rotation(knee).is_equal_approx(next_pose), "The next distant update must consume the accumulated simulation time.")
	camera.free()

	var original_cloth := _surface_color(body, "Cloth")
	visual.set_costume("western_costumes")
	_expect(western.visible and not hair.visible and not role.visible
		and not _surface_color(body, "Cloth").is_equal_approx(original_cloth),
		"A set costume must use the wardrobe palette and hide the daily role accessory.")
	visual.set_costume("")
	_expect(role.visible and hair.visible and not western.visible
		and _surface_color(body, "Cloth").is_equal_approx(original_cloth),
		"Returning from a set must restore the regular outfit.")
	var original_hair := _surface_color(hair, "Hair")
	visual.set_character_age(72)
	_expect(not _surface_color(hair, "Hair").is_equal_approx(original_hair),
		"Changing age must update visible hair without rebuilding the model.")
	visual.free()
	_check_authored_variants()
	_finish_test("StudioEmployeeModelSmokeTest")


func _check_authored_variants() -> void:
	var payload := {
		"id": "EMP-VISUAL-V3", "profession_id": "actor",
		"appearance": {"hair_style": 7, "wardrobe_style": 2, "cheekbones": 0.75},
	}
	for instance in range(2):
		var visual := VISUAL.new()
		visual.setup(payload)
		root.add_child(visual)
		var face := visual.find_child("Face", true, false) as MeshInstance3D
		var skirt := visual.find_child("WardrobeSkirt", true, false) as MeshInstance3D
		_expect(visual.find_child("Hair7", true, false) != null
			and visual.find_child("Hair0", true, false) == null
			and visual.find_child("CollarFold", true, false) != null,
			"Saved appearance should reproduce the same selected hair and collar.")
		_expect(is_equal_approx(face.get_blend_shape_value(1), 0.75) and skirt.skin != null,
			"Authored cheeks and skinned skirt must remain available after import.")
		visual.set_costume("western_costumes")
		_expect(not skirt.visible, "A production costume should cover the everyday skirt.")
		visual.set_costume("")
		_expect(skirt.visible, "Everyday clothing should return after production.")
		visual.free()


func _surface_color(part: MeshInstance3D, slot: String) -> Color:
	for surface in part.mesh.get_surface_count():
		if part.mesh.surface_get_material(surface).resource_name == slot:
			var material := part.get_active_material(surface) as StandardMaterial3D
			return material.albedo_color
	return Color.TRANSPARENT
