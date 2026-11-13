extends "res://tests/smoke_test_base.gd"

const BUILDING_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_building_actor.gd"
)
const BUILDING_DATA_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_data.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_sound_stage_markers()
	_test_facility_facing_directions()
	_test_warehouse_storage_marks()
	_finish_test("StudioBuildingMarkerProviderSmokeTest")


func _create_building(
	building_type_id: String,
	stage_size_tier: int = 2,
	rotation_degrees: float = 90.0
) -> Node3D:
	var data: Variant = BUILDING_DATA_SCRIPT.new()
	data.id = "BLD-MARKER-%s-%d" % [
		building_type_id.to_upper(),
		stage_size_tier,
	]
	data.building_type_id = building_type_id
	data.display_name = "Marker Test %s" % building_type_id
	data.position = Vector3(18.0, 0.0, -12.0)
	data.rotation_degrees = rotation_degrees
	data.stage_size_tier = stage_size_tier
	var actor: Node3D = BUILDING_ACTOR_SCRIPT.new()
	actor.call("setup", data)
	root.add_child(actor)
	return actor


func _test_sound_stage_markers() -> void:
	var expected_scene_marks: Array[Vector3] = [
		Vector3(-1.8, 0.0, -2.65),
		Vector3(-3.0, 0.0, -2.3),
		Vector3(-5.0, 0.0, -5.3),
	]
	var expected_hold_marks: Array[Vector3] = [
		Vector3(-3.6, 0.0, 2.8),
		Vector3(-4.8, 0.0, 4.3),
		Vector3(-9.0, 0.0, 7.0),
	]
	var expected_focus_points: Array[Vector3] = [
		Vector3(0.0, 1.25, -2.75),
		Vector3(0.0, 1.45, -4.35),
		Vector3(0.0, 1.8, -6.0),
	]
	var expected_set_dressing_marks: Array[Vector3] = [
		Vector3(-1.55, 0.0, -3.1),
		Vector3(-2.65, 0.0, -4.0),
		Vector3(-5.2, 0.0, -6.6),
	]

	var stage_tiers: Array[int] = [1, 2, 3]
	for stage_tier in stage_tiers:
		var index: int = stage_tier - 1
		var actor: Node3D = _create_building("sound_stage", stage_tier)
		var base_mark: Vector3 = actor.to_local(actor.call("get_scene_mark", 0, "preparation", 0))
		var rehearsal_mark: Vector3 = actor.to_local(actor.call("get_scene_mark", 0, "rehearsal", 0))
		var shooting_mark: Vector3 = actor.to_local(actor.call("get_scene_mark", 0, "shooting", 0))
		var review_mark: Vector3 = actor.to_local(actor.call("get_scene_mark", 0, "review", 0))
		var alternate_scene_mark: Vector3 = actor.to_local(actor.call("get_scene_mark", 0, "preparation", 1))
		_expect(
			base_mark.distance_to(expected_scene_marks[index]) < 0.01,
			"Sound Stage tier %d must retain its authored preparation mark." % stage_tier
		)
		_expect(
			rehearsal_mark.distance_to(expected_scene_marks[index] + Vector3(0.22, 0.0, 0.28)) < 0.01
			and shooting_mark.distance_to(expected_scene_marks[index] + Vector3(0.38, 0.0, 0.52)) < 0.01
			and review_mark.distance_to(expected_scene_marks[index] + Vector3(0.0, 0.0, 0.12)) < 0.01,
			"Sound Stage phase marks must preserve rehearsal, shooting and review offsets."
		)
		_expect(
			alternate_scene_mark.distance_to(
				Vector3(-expected_scene_marks[index].x, 0.0, expected_scene_marks[index].z)
			) < 0.01,
			"Alternating scenes must mirror the authored actor blocking."
		)
		var hold_mark: Vector3 = actor.to_local(actor.call("get_scene_hold_mark", 0))
		var focus_point: Vector3 = actor.to_local(actor.call("get_scene_focus_point"))
		var set_dressing_mark: Vector3 = actor.to_local(actor.call("get_set_dressing_mark", 0))
		_expect(
			hold_mark.distance_to(expected_hold_marks[index]) < 0.01,
			"Sound Stage tier %d must retain its off-camera holding mark." % stage_tier
		)
		_expect(
			focus_point.distance_to(expected_focus_points[index]) < 0.01,
			"Sound Stage tier %d must retain its camera focus point." % stage_tier
		)
		_expect(
			set_dressing_mark.distance_to(expected_set_dressing_marks[index]) < 0.01,
			"Sound Stage tier %d must retain its set-dressing placement marks." % stage_tier
		)
		actor.queue_free()


func _assert_facing_direction(
	actor: Node3D,
	slot_index: int,
	expected_local_target: Vector3,
	building_label: String
) -> void:
	var route: Array[Vector3] = actor.call("get_workplace_path", slot_index)
	if route.is_empty():
		_expect(false, "%s must provide the workplace used by its facing marker." % building_label)
		return
	var local_workplace: Vector3 = actor.to_local(route.back())
	var local_direction: Vector3 = expected_local_target - local_workplace
	local_direction.y = 0.0
	var expected_world_direction: Vector3 = (actor.global_basis * local_direction).normalized()
	var actual_direction: Vector3 = actor.call("get_workplace_facing_direction", slot_index)
	_expect(
		actual_direction.length_squared() > 0.99
		and actual_direction.dot(expected_world_direction) > 0.999,
		"%s workplace %d must preserve its authored facing direction after rotation." % [
			building_label,
			slot_index,
		]
	)


func _test_facility_facing_directions() -> void:
	var cafeteria: Node3D = _create_building("cafeteria", 2, 90.0)
	var cafeteria_route: Array[Vector3] = cafeteria.call("get_workplace_path", 0)
	var cafeteria_seat: Vector3 = cafeteria.to_local(cafeteria_route.back())
	var table_center_x: float = roundf(cafeteria_seat.x / 4.0) * 4.0
	_assert_facing_direction(cafeteria, 0, Vector3(table_center_x, 0.0, 0.35), "Cafeteria")
	cafeteria.queue_free()

	var lounge: Node3D = _create_building("studio_lounge", 2, 180.0)
	_assert_facing_direction(lounge, 0, Vector3(0.0, 0.0, 0.15), "Studio Lounge")
	lounge.queue_free()

	var fitness: Node3D = _create_building("fitness_center", 2, 270.0)
	var fitness_route: Array[Vector3] = fitness.call("get_workplace_path", 1)
	var fitness_workplace: Vector3 = fitness.to_local(fitness_route.back())
	_assert_facing_direction(
		fitness,
		1,
		fitness_workplace + Vector3(0.0, 0.0, -1.4),
		"Fitness Center"
	)
	fitness.queue_free()

	var housing: Node3D = _create_building("staff_housing", 2, 90.0)
	var housing_route: Array[Vector3] = housing.call("get_workplace_path", 7)
	var housing_workplace: Vector3 = housing.to_local(housing_route.back())
	_assert_facing_direction(
		housing,
		7,
		housing_workplace + Vector3(0.0, 0.0, -1.0),
		"Staff Housing"
	)
	housing.queue_free()

	var tv_studio: Node3D = _create_building("tv_studio", 2, 180.0)
	var host_route: Array[Vector3] = tv_studio.call("get_workplace_path", 0)
	var host_workplace: Vector3 = tv_studio.to_local(host_route.back())
	_assert_facing_direction(
		tv_studio,
		0,
		host_workplace + Vector3(0.0, 0.0, 1.8),
		"TV Studio host"
	)
	_assert_facing_direction(tv_studio, 4, Vector3(0.0, 0.0, -3.0), "TV Studio guest")
	tv_studio.queue_free()

	var office: Node3D = _create_building("script_department", 2, 90.0)
	_expect(
		office.call("get_workplace_facing_direction", 0) == Vector3.ZERO,
		"Buildings without an authored facing target must keep the zero direction."
	)
	office.queue_free()


func _test_warehouse_storage_marks() -> void:
	var actor: Node3D = _create_building("prop_warehouse", 2, 270.0)
	var expected_marks: Array[Vector3] = [
		Vector3(-2.55, 0.0, -2.1),
		Vector3(-0.85, 0.0, -2.1),
		Vector3(0.85, 0.0, -2.1),
		Vector3(2.55, 0.0, -2.1),
		Vector3(-2.55, 0.0, 0.45),
		Vector3(-0.85, 0.0, 0.45),
		Vector3(0.85, 0.0, 0.45),
		Vector3(2.55, 0.0, 0.45),
	]
	for mark_index in range(expected_marks.size()):
		var actual_mark: Vector3 = actor.to_local(actor.call("get_storage_mark", mark_index))
		_expect(
			actual_mark.distance_to(expected_marks[mark_index]) < 0.01,
			"Warehouse storage mark %d must retain its authored pickup position." % mark_index
		)
	actor.queue_free()
