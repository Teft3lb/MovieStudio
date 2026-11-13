extends "res://tests/smoke_test_base.gd"

const GENERATOR = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const CELEBRITY = preload(
	"res://scripts/domain/characters/celebrity_system.gd"
)
const PUBLICITY = preload(
	"res://scripts/domain/characters/celebrity_publicity_system.gd"
)
const DEV_TUNING = preload(
	"res://scripts/domain/characters/character_dev_tuning.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991305
	var generator: RefCounted = GENERATOR.new()
	var actor: Variant = generator.call(
		"generate", rng, "EMP-PUBLICITY-ACTOR", "actor", true
	)
	var director: Variant = generator.call(
		"generate", rng, "EMP-PUBLICITY-DIRECTOR", "director", true
	)
	var celebrity: RefCounted = CELEBRITY.new()
	actor.recognition = 50.0
	actor.popularity = 50.0
	var bad_film: Dictionary = celebrity.call(
		"apply_film_release", actor, false, 15.0
	)
	_expect(
		float(bad_film.get("recognition_delta", 0.0)) < 0.0
		and float(bad_film.get("popularity_delta", 0.0)) < 0.0
		and float(actor.recognition) < 50.0,
		"A critically bad feature must damage recognition and popularity."
	)
	var fame_after_flop: float = float(actor.recognition)
	var good_film: Dictionary = celebrity.call(
		"apply_film_release", actor, false, 93.0
	)
	_expect(
		float(good_film.get("recognition_delta", 0.0)) > 0.0
		and float(actor.recognition) > fame_after_flop
		and float(good_film.get("popularity_delta", 0.0)) > 0.0,
		"An excellent feature must improve both public fame and popularity."
	)
	director.recognition = 50.0
	var director_flop: Dictionary = celebrity.call(
		"apply_film_release", director, true, 18.0
	)
	_expect(
		float(director_flop.get("recognition_delta", 0.0)) < 0.0,
		"Directors must also lose recognition for failed films."
	)

	var dev: RefCounted = DEV_TUNING.new()
	var primary_skill_id: String = str(actor.skills.keys()[0])
	_expect(
		bool(dev.call("set_stat", actor, "recognition", 70.0))
		and is_equal_approx(float(actor.recognition), 70.0)
		and bool(dev.call("adjust_stat", actor, "recognition", 50.0))
		and is_equal_approx(float(actor.recognition), 100.0),
		"DEV override must set recognition to 70 and clamp upgrades to 100."
	)
	_expect(
		bool(dev.call("set_stat", actor, "stress", 25.0))
		and is_equal_approx(float(actor.needs.get("stress", -1.0)), 0.25)
		and bool(dev.call("set_stat", actor, "energy", 100.0))
		and is_equal_approx(float(actor.needs.get("energy", -1.0)), 1.0),
		"DEV adjustments must convert percentages to normalized needs."
	)
	_expect(
		bool(dev.call("set_stat", actor, "skill:" + primary_skill_id, 99.0))
		and is_equal_approx(float(actor.skills[primary_skill_id]), 99.0)
		and not bool(dev.call("set_stat", actor, "skill:missing_skill", 20.0)),
		"DEV can tune real profession skills but must reject unknown skills."
	)

	var fans: RefCounted = PUBLICITY.new()
	actor.recognition = 45.0
	actor.popularity = 40.0
	actor.needs = {"energy": 1.0, "morale": 0.8, "stress": 0.10}
	var solo_event: Dictionary = fans.call(
		"create_event", actor, "fan_meet", 1
	)
	var unguarded: Array[float] = []
	var initial_stress: float = float(actor.needs["stress"])
	var last_solo: Dictionary = {}
	for _minute in range(int(solo_event["duration_minutes"])):
		last_solo = fans.call(
			"advance_event", solo_event, actor, unguarded
		)
	var unguarded_stress: float = float(actor.needs["stress"]) - initial_stress
	_expect(
		bool(last_solo.get("completed", false))
		and float(actor.recognition) > 45.0
		and float(actor.popularity) > 40.0
		and unguarded_stress > 0.10,
		"Unprotected fan meets must raise fame but exhaust and stress the star."
	)
	var repeated: Dictionary = fans.call("create_event", actor, "fan_meet", 2)
	_expect(
		not bool(repeated.get("success", false)),
		"Meeting the same fan audience again tomorrow must respect the cooldown."
	)
	actor.needs = {"energy": 1.0, "morale": 0.8, "stress": 0.10}
	var guarded_event: Dictionary = fans.call(
		"create_event", actor, "fan_meet", 3
	)
	var guards: Array[float] = [75.0, 75.0, 75.0]
	for _minute in range(int(guarded_event["duration_minutes"])):
		fans.call("advance_event", guarded_event, actor, guards)
	var protected_stress: float = float(actor.needs["stress"]) - 0.10
	_expect(
		protected_stress < unguarded_stress * 0.50
		and int(guarded_event["max_guards_present"]) == 3,
		"Three guards present must reduce stress by more than half."
	)

	actor.needs = {"energy": 1.0, "morale": 0.8, "stress": 0.10}
	var press_event: Dictionary = fans.call(
		"create_event", actor, "paparazzi", 3
	)
	var press_result: Dictionary = {}
	for _minute in range(int(press_event["duration_minutes"])):
		press_result = fans.call(
			"advance_event", press_event, actor, unguarded
		)
	_expect(
		bool(press_result.get("completed", false))
		and float(press_result.get("fame_delta", 0.0)) > 0.0
		and float(press_result.get("stress_delta", 0.0)) > protected_stress,
		"Paparazzi publicity must bring recognition but carry meaningful risk."
	)
	_finish_test("CelebrityPublicitySystemSmokeTest")
