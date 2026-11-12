extends "res://tests/smoke_test_base.gd"

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)
const TV_PRODUCTION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_production_system.gd"
)
const TV_SERIES_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_series_data.gd"
)
const TV_TALK_SHOW_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_talk_show_data.gd"
)
const TV_PRODUCTION_EPISODE_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_episode_data.gd"
)
const EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_management_system.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5102026
	var actor_one: Variant = generator.call(
		"generate",
		rng,
		"EMP-TV-ACTOR-01",
		"actor"
	)
	var actor_two: Variant = generator.call(
		"generate",
		rng,
		"EMP-TV-ACTOR-02",
		"actor"
	)
	var actor_three: Variant = generator.call(
		"generate",
		rng,
		"EMP-TV-ACTOR-03",
		"actor"
	)
	var director: Variant = generator.call(
		"generate",
		rng,
		"EMP-TV-DIRECTOR",
		"director"
	)
	var camera_operator: Variant = generator.call(
		"generate",
		rng,
		"EMP-TV-CAMERA",
		"camera_operator"
	)
	var technician: Variant = generator.call(
		"generate",
		rng,
		"EMP-TV-TECH",
		"technician"
	)
	var screenwriter: Variant = generator.call(
		"generate",
		rng,
		"EMP-TV-WRITER",
		"screenwriter"
	)
	actor_one.popularity = 48.0
	actor_one.recognition = 36.0
	actor_two.popularity = 28.0
	actor_two.recognition = 20.0
	actor_three.popularity = 16.0
	actor_three.recognition = 12.0
	var employees: Array = [
		actor_one,
		actor_two,
		actor_three,
		director,
		camera_operator,
		technician,
		screenwriter,
	]
	var crew_assignments: Dictionary = {
		"director": str(director.id),
		"camera_operator": str(camera_operator.id),
		"technician": str(technician.id),
	}
	var cast_ids: Array[String] = [
		str(actor_one.id),
		str(actor_two.id),
	]

	var system: RefCounted = TV_PRODUCTION_SYSTEM_SCRIPT.new()
	system.call("initialize", 661122)
	var series_result: Dictionary = system.call(
		"create_series",
		"TV-SERIES-01",
		"Последний рубеж",
		"drama",
		"Драма",
		"drama",
		2,
		3,
		45,
		cast_ids,
		crew_assignments,
		str(screenwriter.id),
		1
	)
	_expect(
		bool(series_result.get("success", false)),
		"A TV series must be created with a planned season and episode structure."
	)
	var series_data: Variant = series_result.get("series")
	_expect(
		series_data != null
		and series_data.seasons.size() == 2
		and series_data.get_total_episode_count() == 6
		and series_data.get_next_episode() != null,
		"Series creation must generate all planned seasons and individual episodes."
	)
	_test_series_serialization(series_data)

	var series_schedule_result: Dictionary = system.call(
		"schedule_series",
		"TV-SERIES-01",
		0,
		10,
		0,
		180
	)
	_expect(
		bool(series_schedule_result.get("success", false)),
		"A series must accept a recurring weekly shooting schedule."
	)
	var series_schedule: Variant = series_schedule_result.get("schedule")

	var guest_pool_ids: Array[String] = [
		str(actor_two.id),
		str(actor_three.id),
	]
	var talk_show_result: Dictionary = system.call(
		"create_talk_show",
		"TV-TALK-01",
		"Вечерний разговор",
		"late_night",
		str(actor_one.id),
		guest_pool_ids,
		crew_assignments,
		60,
		1
	)
	_expect(
		bool(talk_show_result.get("success", false)),
		"A talk show must keep a permanent host and a pool of invited actors."
	)
	var talk_show: Variant = talk_show_result.get("talk_show")
	_test_talk_show_serialization(talk_show)

	var conflicting_schedule: Dictionary = system.call(
		"schedule_talk_show",
		"TV-TALK-01",
		0,
		11,
		0,
		90
	)
	_expect(
		not bool(conflicting_schedule.get("success", false)),
		"The same actor and TV crew must not be booked into overlapping weekly productions."
	)
	var talk_show_schedule_result: Dictionary = system.call(
		"schedule_talk_show",
		"TV-TALK-01",
		0,
		15,
		0,
		90
	)
	_expect(
		bool(talk_show_schedule_result.get("success", false)),
		"A talk show must be schedulable when its host and crew are free."
	)
	var talk_show_schedule: Variant = talk_show_schedule_result.get("schedule")

	var due_series: Array = system.call(
		"collect_due_schedule_entries",
		1,
		10,
		0
	)
	var duplicate_due_series: Array = system.call(
		"collect_due_schedule_entries",
		1,
		10,
		0
	)
	_expect(
		due_series.size() == 1
		and due_series[0].id == series_schedule.id
		and duplicate_due_series.is_empty(),
		"A weekly shooting slot must trigger once at its exact game-clock minute."
	)

	var no_guests: Array[String] = []
	var busy_employees: Array[String] = [str(actor_one.id)]
	var blocked_series_start: Dictionary = system.call(
		"start_scheduled_episode",
		str(series_schedule.id),
		1,
		10,
		0,
		no_guests,
		busy_employees
	)
	_expect(
		not bool(blocked_series_start.get("success", false)),
		"TV production must reject cast or crew members already occupied by another active production."
	)
	var no_busy_employees: Array[String] = []
	var start_series: Dictionary = system.call(
		"start_scheduled_episode",
		str(series_schedule.id),
		1,
		10,
		0,
		no_guests,
		no_busy_employees
	)
	_expect(
		bool(start_series.get("success", false)),
		"A due series slot must start its next planned episode."
	)
	var first_episode: Variant = start_series.get("episode")
	_expect(
		first_episode != null
		and first_episode.status == TV_PRODUCTION_EPISODE_SCRIPT.STATUS_IN_PRODUCTION
		and first_episode.cast_employee_ids.size() == 2,
		"The first series episode must inherit the show's regular cast."
	)

	var series_snapshot: Dictionary = {
		"acting_average": 92.0,
		"directing": 90.0,
		"writing": 88.0,
		"camera_work": 86.0,
		"technical": 84.0,
		"set_design": 82.0,
		"energy": 0.92,
		"morale": 0.90,
		"stress": 0.05,
	}
	var paused_step: Dictionary = system.call(
		"advance_minute",
		false,
		true,
		series_snapshot
	)
	_expect(
		bool(paused_step.get("paused", false))
		and int(first_episode.production_elapsed_minutes) == 0,
		"TV production must pause cleanly when the technical crew is not ready."
	)
	_advance_until_complete(system, first_episode, series_snapshot)
	_expect(
		first_episode.status == TV_PRODUCTION_EPISODE_SCRIPT.STATUS_READY_FOR_BROADCAST
		and float(first_episode.production_quality) >= 60.0
		and first_episode.get_progress_percent() == 100.0,
		"A series episode must pass through preparation, rehearsal, shooting and postproduction."
	)

	var popularity_before: float = float(actor_one.popularity)
	var recognition_before: float = float(actor_one.recognition)
	var series_broadcast: Dictionary = system.call(
		"record_broadcast",
		"series",
		"TV-SERIES-01",
		str(first_episode.id),
		employees,
		1
	)
	_expect(
		bool(series_broadcast.get("success", false))
		and first_episode.status == TV_PRODUCTION_EPISODE_SCRIPT.STATUS_BROADCASTED
		and int(first_episode.audience_reach) > 0
		and float(first_episode.audience_rating) > 0.0,
		"A completed episode must produce a measurable audience rating and reach when broadcast."
	)
	_expect(
		float(actor_one.recognition) > recognition_before
		and float(actor_one.popularity) > popularity_before,
		"Successful recurring TV exposure must improve an actor's recognition and popularity."
	)

	var management: RefCounted = EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT.new()
	management.call("initialize", employees, 1, 882211, 0)
	var media_offer: Dictionary = management.call(
		"get_media_contract_offer_profile",
		str(actor_one.id)
	)
	var media_offer_salary: int = int(
		management.call(
			"get_media_contract_offer_salary",
			str(actor_one.id),
			"fixed_30_days"
		)
	)
	_expect(
		bool(media_offer.get("eligible", false))
		and float(media_offer.get("marketability_score", 0.0)) > 0.0
		and media_offer_salary >= int(media_offer.get("suggested_daily_salary", 0)),
		"Television exposure must feed the employee market's media contract offer profile."
	)

	var due_talk_show: Array = system.call(
		"collect_due_schedule_entries",
		1,
		15,
		0
	)
	var invited_guests: Array[String] = [str(actor_two.id)]
	var start_talk_show: Dictionary = system.call(
		"start_scheduled_episode",
		str(talk_show_schedule.id),
		1,
		15,
		0,
		invited_guests
	)
	var talk_episode: Variant = start_talk_show.get("episode")
	_expect(
		due_talk_show.size() == 1
		and bool(start_talk_show.get("success", false))
		and talk_episode != null
		and talk_episode.host_employee_id == actor_one.id
		and talk_episode.guest_employee_ids == invited_guests,
		"A scheduled talk show must record its permanent host and the selected invited actor."
	)
	var talk_snapshot: Dictionary = {
		"host_presence": 94.0,
		"improvisation": 91.0,
		"communication": 93.0,
		"directing": 86.0,
		"camera_work": 88.0,
		"guest_performance": 89.0,
		"technical": 85.0,
		"energy": 0.95,
		"morale": 0.92,
		"stress": 0.04,
	}
	_advance_until_complete(system, talk_episode, talk_snapshot)
	var guest_recognition_before: float = float(actor_two.recognition)
	var talk_broadcast: Dictionary = system.call(
		"record_broadcast",
		"talk_show",
		"TV-TALK-01",
		str(talk_episode.id),
		employees,
		1
	)
	_expect(
		bool(talk_broadcast.get("success", false))
		and talk_episode.status == TV_PRODUCTION_EPISODE_SCRIPT.STATUS_BROADCASTED
		and float(actor_two.recognition) > guest_recognition_before,
		"Talk-show guest appearances must become persistent career credits and improve recognition."
	)

	var next_week_due: Array = system.call(
		"collect_due_schedule_entries",
		8,
		10,
		0
	)
	var second_start: Dictionary = system.call(
		"start_scheduled_episode",
		str(series_schedule.id),
		8,
		10,
		0,
		no_guests
	)
	var second_episode: Variant = second_start.get("episode")
	_expect(
		next_week_due.size() == 1
		and bool(second_start.get("success", false))
		and second_episode != null
		and second_episode.episode_number == 2,
		"Weekly series production must advance to the next planned episode on the following week."
	)
	system.call("advance_minute", true, true, series_snapshot)
	system.call("advance_minute", true, true, series_snapshot)
	var saved_state: Dictionary = system.call("to_dict")
	var restored_system: Variant = TV_PRODUCTION_SYSTEM_SCRIPT.from_dict(saved_state)
	var restored_episode: Variant = restored_system.call("get_active_episode")
	var restored_series: Variant = restored_system.call(
		"get_series",
		"TV-SERIES-01"
	)
	var restored_talk_show: Variant = restored_system.call(
		"get_talk_show",
		"TV-TALK-01"
	)
	_expect(
		restored_episode != null
		and restored_episode.id == second_episode.id
		and restored_episode.phase_minutes_elapsed == 2
		and restored_series.get_broadcast_episode_count() == 1
		and restored_talk_show.get_broadcast_episode_count() == 1
		and restored_system.call(
			"get_schedule_entry",
			str(series_schedule.id)
		).last_triggered_day == 8,
		"TV series, talk-show archives, recurring schedules and in-progress episodes must survive serialization."
	)
	_advance_until_complete(restored_system, restored_episode, series_snapshot)
	var restored_broadcast: Dictionary = restored_system.call(
		"record_broadcast",
		"series",
		"TV-SERIES-01",
		str(restored_episode.id),
		employees,
		8
	)
	_expect(
		bool(restored_broadcast.get("success", false))
		and restored_series.get_broadcast_episode_count() == 2,
		"An episode restored mid-production must finish and broadcast without losing its season history."
	)

	_finish_test("TVProductionSystemSmokeTest")


func _advance_until_complete(
	system: Variant,
	episode: Variant,
	performance_snapshot: Dictionary
) -> void:
	var guard: int = 0
	while (
		episode != null
		and str(episode.status) == TV_PRODUCTION_EPISODE_SCRIPT.STATUS_IN_PRODUCTION
		and guard < 240
	):
		system.call("advance_minute", true, true, performance_snapshot)
		guard += 1
	_expect(
		episode != null
		and str(episode.status) == TV_PRODUCTION_EPISODE_SCRIPT.STATUS_READY_FOR_BROADCAST,
		"TV production must complete within the configured phase-duration guard."
	)


func _test_series_serialization(series_data: Variant) -> void:
	if series_data == null:
		return
	var restored: Variant = TV_SERIES_DATA_SCRIPT.from_dict(series_data.to_dict())
	_expect(
		restored.id == series_data.id
		and restored.seasons.size() == series_data.seasons.size()
		and restored.get_total_episode_count() == series_data.get_total_episode_count(),
		"Series metadata, seasons and episode plans must survive serialization."
	)


func _test_talk_show_serialization(show: Variant) -> void:
	if show == null:
		return
	var restored: Variant = TV_TALK_SHOW_DATA_SCRIPT.from_dict(show.to_dict())
	_expect(
		restored.id == show.id
		and restored.host_employee_id == show.host_employee_id
		and restored.guest_pool_employee_ids == show.guest_pool_employee_ids,
		"Talk-show host, guest pool and format must survive serialization."
	)


