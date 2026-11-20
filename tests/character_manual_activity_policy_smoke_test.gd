extends "res://tests/smoke_test_base.gd"

const POLICY_SCRIPT = preload(
	"res://scripts/domain/characters/character_manual_activity_policy.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var policy: RefCounted = POLICY_SCRIPT.new()
	var actor_types: Array = policy.call(
		"get_preferred_activity_building_types", "actor"
	)
	var writer_types: Array = policy.call(
		"get_preferred_activity_building_types", "screenwriter"
	)
	var technician_types: Array = policy.call(
		"get_preferred_activity_building_types", "technician"
	)
	_expect(
		not actor_types.is_empty() and actor_types[0] == "sound_stage",
		"Actors must be directed toward rehearsal before generic leisure activities."
	)
	_expect(
		not writer_types.is_empty() and writer_types[0] == "script_department",
		"Screenwriters must be directed toward the script department."
	)
	_expect(
		not technician_types.is_empty() and technician_types[0] == "prop_warehouse",
		"Technicians must be directed toward the prop warehouse."
	)
	var camera_activity: Dictionary = policy.call(
		"get_activity", "sound_stage", "camera_operator"
	)
	var maintenance_activity: Dictionary = policy.call(
		"get_activity", "prop_warehouse", "maintenance_worker"
	)
	_expect(
		str(camera_activity.get("skill", "")) == "camera_work",
		"Camera operators must gain camera-work experience from stage practice."
	)
	_expect(
		str(maintenance_activity.get("skill", "")) == "maintenance",
		"Maintenance workers must gain maintenance experience in the prop warehouse."
	)
	_expect(
		policy.call("get_activity", "editing_suite", "actor").is_empty(),
		"Profession-specific activities must reject unrelated departments."
	)
	_finish_test("CharacterManualActivityPolicySmokeTest")
