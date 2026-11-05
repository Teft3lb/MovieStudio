extends "res://tests/smoke_test_base.gd"

const NAVIGATION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/studio/studio_navigation_system.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var navigation: RefCounted = NAVIGATION_SYSTEM_SCRIPT.new()
	var building_obstacles: Array[Dictionary] = [
		{
			"center": Vector2(0.0, 0.0),
			"half_extents": Vector2(2.0, 2.0),
			"clearance": 0.5,
		},
	]
	var start: Vector3 = Vector3(-5.0, 0.0, 0.0)
	var target: Vector3 = Vector3(5.0, 0.0, 0.0)
	var outdoor_path: Array[Vector3] = navigation.call(
		"build_path",
		start,
		target,
		building_obstacles,
		0.5
	)
	_expect(
		outdoor_path.size() >= 3,
		"Outdoor employee routes must detour around building footprints."
	)
	_expect(
		outdoor_path.size() >= 2
		and outdoor_path.front().distance_to(start) <= 0.1
		and outdoor_path.back().distance_to(target) <= 0.1,
		"Outdoor routes must preserve the exact start and doorway destination."
	)
	_expect(
		_path_clears_obstacles(outdoor_path, building_obstacles),
		"Smoothed outdoor routes must retain building clearance."
	)

	var stage_obstacles: Array[Dictionary] = [
		{
			"center": Vector2(-3.9, -2.3),
			"half_extents": Vector2(0.14, 1.4),
			"clearance": 0.22,
		},
	]
	var stage_path: Array[Vector3] = navigation.call(
		"build_path",
		Vector3(0.0, 0.0, 1.4),
		Vector3(-4.3, 0.0, -1.7),
		stage_obstacles,
		0.5,
		Rect2(Vector2(-6.4, -5.4), Vector2(12.8, 10.8))
	)
	_expect(
		stage_path.size() >= 3,
		"Stage routes must navigate around the side wall instead of crossing it."
	)
	_expect(
		_path_clears_obstacles(stage_path, stage_obstacles),
		"Stage routes must preserve clearance from the set wall."
	)

	_finish_test("StudioNavigationSmokeTest")


func _path_clears_obstacles(
	path: Array[Vector3],
	obstacles: Array[Dictionary]
) -> bool:
	for segment_index in range(path.size() - 1):
		for sample_index in range(1, 20):
			var sample: Vector3 = path[segment_index].lerp(
				path[segment_index + 1],
				float(sample_index) / 20.0
			)
			for obstacle in obstacles:
				var center: Vector2 = obstacle.get("center", Vector2.ZERO)
				var half_extents: Vector2 = obstacle.get(
					"half_extents",
					Vector2.ONE
				)
				var clearance: float = float(
					obstacle.get("clearance", 0.48)
				)
				if (
					absf(sample.x - center.x) <= half_extents.x + clearance
					and absf(sample.z - center.y) <= half_extents.y + clearance
				):
					return false
	return true
