extends "res://tests/smoke_test_base.gd"

const VISUAL_FACTORY_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_visual_factory.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var factory: RefCounted = VISUAL_FACTORY_SCRIPT.new()
	var root_node := Node3D.new()
	root.add_child(root_node)

	var box: MeshInstance3D = factory.call(
		"create_box",
		root_node,
		"FactoryBox",
		Vector3(2.0, 1.0, 3.0),
		Color(0.2, 0.3, 0.4),
		Vector3.ZERO
	)
	_expect(
		box.mesh is BoxMesh
		and (box.mesh as BoxMesh).size == Vector3(2.0, 1.0, 3.0),
		"Visual factory must create box meshes with the requested dimensions."
	)

	var cylinder: MeshInstance3D = factory.call(
		"create_cylinder",
		root_node,
		"FactoryCylinder",
		0.5,
		2.0,
		Color(0.4, 0.3, 0.2),
		Vector3.ZERO
	)
	_expect(
		cylinder.mesh is CylinderMesh
		and is_equal_approx((cylinder.mesh as CylinderMesh).height, 2.0),
		"Visual factory must create cylinder meshes with the requested dimensions."
	)

	var sphere: MeshInstance3D = factory.call(
		"create_sphere",
		root_node,
		"FactorySphere",
		0.75,
		Color(0.5, 0.6, 0.7),
		Vector3.ZERO
	)
	_expect(
		sphere.mesh is SphereMesh
		and is_equal_approx((sphere.mesh as SphereMesh).radius, 0.75),
		"Visual factory must create sphere meshes with the requested radius."
	)

	factory.call(
		"create_floor",
		root_node,
		Vector2(8.0, 6.0),
		Color(0.2, 0.2, 0.2),
		"FactoryFloor"
	)
	_expect(
		root_node.get_node_or_null("FactoryFloor") is MeshInstance3D,
		"Visual factory must create floor surfaces under the supplied visual root."
	)

	factory.call(
		"create_wall_panel",
		root_node,
		"FactoryWall",
		Vector3(4.0, 3.0, 0.2),
		Color(0.4, 0.4, 0.4),
		Vector3.ZERO
	)
	_expect(
		root_node.get_node_or_null("FactoryWall") is MeshInstance3D
		and root_node.get_node_or_null("FactoryWallCollision") is StaticBody3D,
		"Wall panels must retain their matching collision bodies."
	)

	factory.call(
		"create_label",
		root_node,
		"FactoryLabel",
		"VISUAL FACTORY",
		Vector3.ZERO,
		18
	)
	_expect(
		root_node.get_node_or_null("FactoryLabel") is Label3D,
		"Visual factory must create world-space labels."
	)

	var slate: Dictionary = factory.call("create_film_slate", root_node)
	_expect(
		slate.get("scene_label") is Label3D
		and slate.get("phase_label") is Label3D
		and (slate.get("scene_label") as Label3D).name == "ProductionSceneSlate"
		and (slate.get("phase_label") as Label3D).name == "ProductionPhaseSlate"
		and root_node.get_node_or_null("FilmSlateBody") is MeshInstance3D,
		"Film slate construction must return both live labels to the building actor."
	)

	var camera_rig: Node3D = factory.call(
		"create_camera_rig",
		root_node,
		4,
		Vector3(1.0, 0.0, 2.0),
		Color(0.3, 0.3, 0.3),
		Color(0.1, 0.1, 0.1)
	)
	_expect(
		camera_rig.name == "CameraRig_4"
		and camera_rig.get_node_or_null("CinemaCameraBody") is MeshInstance3D,
		"Camera rig creation must preserve its stable hierarchy and rig index."
	)

	factory.call(
		"create_light_stand",
		root_node,
		Vector3(-1.0, 0.0, 2.0),
		Color(0.3, 0.3, 0.3)
	)
	_expect(
		root_node.get_child_count() >= 12,
		"Light-stand construction must populate the supplied root with its equipment meshes."
	)

	root_node.free()
	_finish_test("StudioBuildingVisualFactorySmokeTest")
