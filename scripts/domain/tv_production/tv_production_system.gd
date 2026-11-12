extends RefCounted
class_name TVProductionSystem

const TV_EPISODE_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_episode_data.gd"
)
const TV_SEASON_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_season_data.gd"
)
const TV_SERIES_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_series_data.gd"
)
const TV_TALK_SHOW_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_talk_show_data.gd"
)
const TV_SCHEDULE_ENTRY_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_schedule_entry.gd"
)
const CELEBRITY_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/celebrity_system.gd"
)

const PREPARATION_MINUTES: int = 3
const MIN_REHEARSAL_MINUTES: int = 2
const MIN_SHOOTING_MINUTES: int = 8
const MIN_POSTPRODUCTION_MINUTES: int = 3
const MAX_TALK_SHOW_GUESTS: int = 3

var series: Array = []
var talk_shows: Array = []
var schedule_entries: Array = []
var active_episode: Variant = null
var active_program_type_id: String = ""
var active_program_id: String = ""
var active_schedule_id: String = ""

var _seed: int = 1
var _rng_state: int = 1
var _next_schedule_number: int = 1
var _rng: RandomNumberGenerator
var _celebrity_system: RefCounted


func _init() -> void:
	initialize(1)


func initialize(seed_value: int) -> void:
	_seed = seed_value if seed_value != 0 else 1
	_rng = RandomNumberGenerator.new()
	_rng.seed = _seed
	_rng_state = _rng.state
	_celebrity_system = CELEBRITY_SYSTEM_SCRIPT.new()
	series.clear()
	talk_shows.clear()
	schedule_entries.clear()
	active_episode = null
	active_program_type_id = ""
	active_program_id = ""
	active_schedule_id = ""
	_next_schedule_number = 1


func create_series(
	series_id: String,
	series_title: String,
	genre_id: String,
	genre_title: String,
	format_id: String,
	planned_season_count: int,
	episodes_per_season: int,
	episode_runtime_minutes: int,
	cast_employee_ids: Array[String],
	crew_assignments: Dictionary,
	writer_employee_id: String,
	created_day: int
) -> Dictionary:
	if series_id.strip_edges().is_empty() or series_title.strip_edges().is_empty():
		return _failure("Для сериала нужны идентификатор и название.")
	if _find_series(series_id) != null or _find_talk_show(series_id) != null:
		return _failure("Программа с таким идентификатором уже существует.")
	if cast_employee_ids.is_empty():
		return _failure("Для сериала необходимо назначить постоянный актёрский состав.")
	if writer_employee_id.strip_edges().is_empty():
		return _failure("Для сериала необходимо назначить сценариста.")
	if not _has_required_tv_crew(crew_assignments):
		return _failure("Для телевизионного производства нужны режиссёр, оператор и техник.")

	var normalized_cast: Array[String] = _normalize_employee_ids(
		cast_employee_ids
	)
	if normalized_cast.is_empty():
		return _failure("В актёрском составе нет действительных идентификаторов.")
	var normalized_format: String = format_id
	if normalized_format not in ["drama", "sitcom", "soap", "mini_series"]:
		normalized_format = "drama"

	var series_data: Variant = TV_SERIES_DATA_SCRIPT.new()
	series_data.id = series_id
	series_data.title = series_title.strip_edges()
	series_data.genre_id = genre_id
	series_data.genre_title = genre_title
	series_data.format_id = normalized_format
	series_data.planned_season_count = clampi(
		planned_season_count,
		1,
		8
	)
	series_data.episodes_per_season = clampi(
		episodes_per_season,
		1,
		24
	)
	series_data.episode_runtime_minutes = clampi(
		episode_runtime_minutes,
		5,
		180
	)
	series_data.cast_employee_ids = normalized_cast
	series_data.crew_assignments = crew_assignments.duplicate(true)
	series_data.writer_employee_id = writer_employee_id
	series_data.created_day = maxi(created_day, 1)

	for season_index in range(series_data.planned_season_count):
		var season_number: int = season_index + 1
		var season: Variant = TV_SEASON_DATA_SCRIPT.new()
		season.series_id = series_id
		season.season_number = season_number
		for episode_index in range(series_data.episodes_per_season):
			var episode_number: int = episode_index + 1
			var episode: Variant = TV_EPISODE_DATA_SCRIPT.new()
			episode.id = "%s-S%02dE%02d" % [
				series_id,
				season_number,
				episode_number,
			]
			episode.program_type_id = "series"
			episode.program_id = series_id
			episode.season_number = season_number
			episode.episode_number = episode_number
			episode.title = "Эпизод %02d" % episode_number
			episode.runtime_minutes = series_data.episode_runtime_minutes
			episode.cast_employee_ids = normalized_cast.duplicate()
			episode.crew_assignments = crew_assignments.duplicate(true)
			season.episodes.append(episode)
		series_data.seasons.append(season)

	series.append(series_data)
	return {
		"success": true,
		"message": "Сериал добавлен в телевизионный каталог.",
		"series": series_data,
	}


func create_talk_show(
	show_id: String,
	show_title: String,
	format_id: String,
	host_employee_id: String,
	guest_pool_employee_ids: Array[String],
	crew_assignments: Dictionary,
	episode_duration_minutes: int,
	created_day: int
) -> Dictionary:
	if show_id.strip_edges().is_empty() or show_title.strip_edges().is_empty():
		return _failure("Для ток-шоу нужны идентификатор и название.")
	if _find_series(show_id) != null or _find_talk_show(show_id) != null:
		return _failure("Программа с таким идентификатором уже существует.")
	if host_employee_id.strip_edges().is_empty():
		return _failure("Для ток-шоу необходимо назначить постоянного ведущего.")
	if not _has_required_tv_crew(crew_assignments):
		return _failure("Для телевизионного производства нужны режиссёр, оператор и техник.")

	var guest_pool: Array[String] = _normalize_employee_ids(
		guest_pool_employee_ids
	)
	guest_pool.erase(host_employee_id)
	if guest_pool.is_empty():
		return _failure("Для ток-шоу необходимо подготовить пул приглашённых актёров.")
	var normalized_format: String = format_id
	if normalized_format not in ["late_night", "interview", "panel", "daytime"]:
		normalized_format = "interview"

	var show: Variant = TV_TALK_SHOW_DATA_SCRIPT.new()
	show.id = show_id
	show.title = show_title.strip_edges()
	show.format_id = normalized_format
	show.host_employee_id = host_employee_id
	show.guest_pool_employee_ids = guest_pool
	show.crew_assignments = crew_assignments.duplicate(true)
	show.episode_duration_minutes = clampi(
		episode_duration_minutes,
		5,
		180
	)
	show.created_day = maxi(created_day, 1)
	talk_shows.append(show)
	return {
		"success": true,
		"message": "Ток-шоу добавлено в телевизионный каталог.",
		"talk_show": show,
	}


func schedule_series(
	series_id: String,
	day_of_week: int,
	start_hour: int,
	start_minute: int,
	duration_minutes: int
) -> Dictionary:
	var series_data: Variant = _find_series(series_id)
	if series_data == null:
		return _failure("Сериал не найден.")
	if str(series_data.status) != "active":
		return _failure("Расписание можно назначить только действующему сериалу.")
	var participants: Array[String] = _collect_participant_ids(
		series_data.cast_employee_ids,
		series_data.crew_assignments
	)
	var result: Dictionary = _create_schedule_entry(
		"series",
		series_id,
		day_of_week,
		start_hour,
		start_minute,
		duration_minutes,
		participants
	)
	if bool(result.get("success", false)):
		series_data.recurring_schedule_id = str(result.schedule.id)
	return result


func schedule_talk_show(
	show_id: String,
	day_of_week: int,
	start_hour: int,
	start_minute: int,
	duration_minutes: int
) -> Dictionary:
	var show: Variant = _find_talk_show(show_id)
	if show == null:
		return _failure("Ток-шоу не найдено.")
	if str(show.status) != "active":
		return _failure("Расписание можно назначить только действующему ток-шоу.")
	var participants: Array[String] = [str(show.host_employee_id)]
	var no_cast_ids: Array[String] = []
	participants.append_array(
		_collect_participant_ids(no_cast_ids, show.crew_assignments)
	)
	participants = _normalize_employee_ids(participants)
	var result: Dictionary = _create_schedule_entry(
		"talk_show",
		show_id,
		day_of_week,
		start_hour,
		start_minute,
		duration_minutes,
		participants
	)
	if bool(result.get("success", false)):
		show.recurring_schedule_id = str(result.schedule.id)
	return result


func collect_due_schedule_entries(
	day: int,
	hour: int,
	minute: int
) -> Array:
	var due_entries: Array = []
	for schedule in schedule_entries:
		if not schedule.is_due(day, hour, minute):
			continue
		schedule.last_triggered_day = day
		due_entries.append(schedule)
	return due_entries


func start_scheduled_episode(
	schedule_id: String,
	day: int,
	hour: int,
	minute: int,
	guest_employee_ids: Array[String] = [],
	unavailable_employee_ids: Array[String] = []
) -> Dictionary:
	if (
		active_episode != null
		and str(active_episode.status) == TV_EPISODE_DATA_SCRIPT.STATUS_IN_PRODUCTION
	):
		return _failure("Телевизионная съёмочная группа уже занята другим эпизодом.")
	var schedule: Variant = _find_schedule_entry(schedule_id)
	if schedule == null or not schedule.active:
		return _failure("Регулярное расписание не найдено или отключено.")
	if (
		schedule.last_triggered_day != day
		or schedule.start_hour != hour
		or schedule.start_minute != minute
	):
		return _failure("Начать эпизод можно только в назначенное время съёмок.")

	var episode: Variant = null
	var talk_show_to_update: Variant = null
	var runtime_minutes: int = 30
	if schedule.program_type_id == "series":
		var series_data: Variant = _find_series(schedule.program_id)
		if series_data == null or str(series_data.status) != "active":
			return _failure("Сериал больше не находится в производстве.")
		episode = series_data.get_next_episode()
		if episode == null:
			if (
				series_data.get_broadcast_episode_count()
				>= series_data.get_total_episode_count()
			):
				series_data.status = "completed"
				_deactivate_program_schedule("series", schedule.program_id)
				return _failure("Все запланированные эпизоды сериала уже вышли в эфир.")
			return _failure(
				"Все запланированные эпизоды уже сняты; ожидается их телевизионный эфир."
			)
		var series_guest_ids: Array[String] = _normalize_employee_ids(
			guest_employee_ids
		)
		for guest_id in series_guest_ids:
			if (
				series_data.cast_employee_ids.has(guest_id)
				or _has_employee_schedule_conflict(
					guest_id,
					schedule.day_of_week,
					schedule.start_hour * 60 + schedule.start_minute,
					schedule.duration_minutes,
					schedule.id
				)
			):
				return _failure("Приглашённый актёр уже занят в это время.")
		episode.cast_employee_ids = series_data.cast_employee_ids.duplicate()
		episode.guest_employee_ids = series_guest_ids
		episode.crew_assignments = series_data.crew_assignments.duplicate(true)
		runtime_minutes = int(series_data.episode_runtime_minutes)
	else:
		var show: Variant = _find_talk_show(schedule.program_id)
		if show == null or str(show.status) != "active":
			return _failure("Ток-шоу больше не находится в производстве.")
		var talk_show_guest_ids: Array[String] = _resolve_talk_show_guests(
			show,
			guest_employee_ids
		)
		if talk_show_guest_ids.is_empty():
			return _failure("Для выпуска ток-шоу не удалось подобрать приглашённых актёров.")
		for guest_id in talk_show_guest_ids:
			if _has_employee_schedule_conflict(
				guest_id,
				schedule.day_of_week,
				schedule.start_hour * 60 + schedule.start_minute,
				schedule.duration_minutes,
				schedule.id
			):
				return _failure("Приглашённый актёр уже занят в это время.")
		episode = TV_EPISODE_DATA_SCRIPT.new()
		episode.id = "%s-E%03d" % [show.id, show.next_episode_number]
		episode.program_type_id = "talk_show"
		episode.program_id = show.id
		episode.episode_number = show.next_episode_number
		episode.title = "Выпуск %03d" % show.next_episode_number
		episode.runtime_minutes = int(show.episode_duration_minutes)
		episode.host_employee_id = str(show.host_employee_id)
		episode.guest_employee_ids = talk_show_guest_ids
		episode.crew_assignments = show.crew_assignments.duplicate(true)
		talk_show_to_update = show
		runtime_minutes = int(show.episode_duration_minutes)

	var required_employee_ids: Array[String] = _collect_participant_ids(
		episode.cast_employee_ids,
		episode.crew_assignments
	)
	if not str(episode.host_employee_id).is_empty():
		if not required_employee_ids.has(str(episode.host_employee_id)):
			required_employee_ids.append(str(episode.host_employee_id))
	for guest_id in episode.guest_employee_ids:
		if not required_employee_ids.has(guest_id):
			required_employee_ids.append(guest_id)
	for employee_id in required_employee_ids:
		if unavailable_employee_ids.has(employee_id):
			return _failure(
				"Сотрудник уже занят в другом производстве и не может выйти на телевизионную площадку."
			)
	if talk_show_to_update != null:
		talk_show_to_update.next_episode_number += 1
		talk_show_to_update.episodes.append(episode)

	episode.status = TV_EPISODE_DATA_SCRIPT.STATUS_IN_PRODUCTION
	episode.current_phase = "preparation"
	episode.phase_minutes_elapsed = 0
	episode.phase_duration_minutes = PREPARATION_MINUTES
	episode.production_elapsed_minutes = 0
	episode.runtime_minutes = runtime_minutes
	episode.estimated_total_minutes = _estimate_episode_minutes(episode)
	episode.production_quality = 0.0
	episode.pause_reason = ""
	episode.production_started_day = day
	episode.production_started_hour = hour
	episode.production_started_minute = minute
	episode.production_seed = _rng.randi()
	episode.production_rng_state = _rng.state
	_rng_state = _rng.state
	episode.last_activity_message = "Подготовка телевизионной площадки"

	active_episode = episode
	active_program_type_id = schedule.program_type_id
	active_program_id = schedule.program_id
	active_schedule_id = schedule.id
	return {
		"success": true,
		"message": "Телевизионное производство эпизода началось.",
		"episode": episode,
	}


func advance_minute(
	crew_ready: bool,
	cast_ready: bool,
	performance_snapshot: Dictionary
) -> Dictionary:
	if (
		active_episode == null
		or str(active_episode.status) != TV_EPISODE_DATA_SCRIPT.STATUS_IN_PRODUCTION
	):
		return {
			"advanced": false,
			"completed": false,
			"paused": false,
		}
	if not crew_ready:
		active_episode.pause_reason = "Съёмочная группа не готова."
		return {
			"advanced": false,
			"completed": false,
			"paused": true,
			"reason": active_episode.pause_reason,
		}
	if (
		active_episode.current_phase in ["rehearsal", "shooting"]
		and not cast_ready
	):
		active_episode.pause_reason = "Ведущий или актёрский состав отсутствует на площадке."
		return {
			"advanced": false,
			"completed": false,
			"paused": true,
			"reason": active_episode.pause_reason,
		}

	active_episode.pause_reason = ""
	active_episode.phase_minutes_elapsed += 1
	active_episode.production_elapsed_minutes += 1
	if (
		active_episode.phase_minutes_elapsed
		< active_episode.phase_duration_minutes
	):
		return {
			"advanced": true,
			"completed": false,
			"paused": false,
			"phase": active_episode.current_phase,
			"progress": active_episode.get_progress_percent(),
		}

	match active_episode.current_phase:
		"preparation":
			_set_active_phase(
				"rehearsal",
				maxi(MIN_REHEARSAL_MINUTES, _get_performer_count(active_episode)),
				"Началась репетиция телевизионного эпизода"
			)
		"rehearsal":
			_set_active_phase(
				"shooting",
				maxi(
					MIN_SHOOTING_MINUTES,
					ceili(float(active_episode.runtime_minutes) * 0.4)
				),
				"Началась запись телевизионного эпизода"
			)
		"shooting":
			_set_active_phase(
				"postproduction",
				maxi(
					MIN_POSTPRODUCTION_MINUTES,
					ceili(float(active_episode.runtime_minutes) * 0.1)
				),
				"Материал передан в телевизионный постпродакшен"
			)
		"postproduction":
			var completed_episode: Variant = active_episode
			completed_episode.production_quality = _calculate_production_quality(
				completed_episode,
				performance_snapshot
			)
			completed_episode.status = (
				TV_EPISODE_DATA_SCRIPT.STATUS_READY_FOR_BROADCAST
			)
			completed_episode.current_phase = "completed"
			completed_episode.phase_minutes_elapsed = 0
			completed_episode.phase_duration_minutes = 0
			completed_episode.last_activity_message = (
				"Эпизод готов к телевизионному эфиру"
			)
			active_episode = null
			active_program_type_id = ""
			active_program_id = ""
			active_schedule_id = ""
			return {
				"advanced": true,
				"completed": true,
				"paused": false,
				"episode": completed_episode,
			}

	return {
		"advanced": true,
		"completed": false,
		"paused": false,
		"phase": active_episode.current_phase,
		"phase_duration_minutes": active_episode.phase_duration_minutes,
	}


func record_broadcast(
	program_type_id: String,
	program_id: String,
	episode_id: String,
	employees: Array,
	broadcast_day: int
) -> Dictionary:
	var episode: Variant = _find_episode(
		program_type_id,
		program_id,
		episode_id
	)
	if episode == null:
		return _failure("Эпизод не найден.")
	if str(episode.status) != TV_EPISODE_DATA_SCRIPT.STATUS_READY_FOR_BROADCAST:
		return _failure("В эфир можно отправить только завершённый эпизод.")

	var talent_ids: Array[String] = _get_episode_talent_ids(episode)
	if talent_ids.is_empty():
		return _failure("Для эфира не назначены ведущие или актёры.")
	var popularity_total: float = 0.0
	var recognition_total: float = 0.0
	var talent_count: int = 0
	for employee_id in talent_ids:
		var employee: Variant = _find_employee(employees, employee_id)
		if employee == null:
			continue
		popularity_total += clampf(float(employee.popularity), 0.0, 100.0)
		recognition_total += clampf(float(employee.recognition), 0.0, 100.0)
		talent_count += 1
	var average_popularity: float = (
		popularity_total / float(talent_count)
		if talent_count > 0
		else 10.0
	)
	var average_recognition: float = (
		recognition_total / float(talent_count)
		if talent_count > 0
		else 10.0
	)
	_rng.state = _rng_state
	var rating_variance: float = _rng.randf_range(-4.0, 4.0)
	_rng_state = _rng.state
	var media_appeal: float = (
		average_popularity * 0.45
		+ average_recognition * 0.55
	)
	var audience_rating: float = clampf(
		float(episode.production_quality) * 0.68
		+ media_appeal * 0.32
		+ rating_variance,
		0.0,
		100.0
	)
	var audience_base: float = (
		12000.0
		+ average_recognition * 1400.0
		+ average_popularity * 900.0
	)
	var audience_reach: int = roundi(clampf(
		audience_base * (0.4 + audience_rating / 150.0),
		4000.0,
		2000000.0
	))
	episode.status = TV_EPISODE_DATA_SCRIPT.STATUS_BROADCASTED
	episode.audience_rating = audience_rating
	episode.audience_reach = audience_reach
	episode.broadcast_day = maxi(broadcast_day, 1)
	episode.last_activity_message = "Эпизод вышел в эфир"

	var career_updates: Array[Dictionary] = []
	for employee_id in talent_ids:
		var employee: Variant = _find_employee(employees, employee_id)
		if employee == null:
			continue
		var role_type: String = _get_episode_role(episode, employee_id)
		var update: Dictionary = _celebrity_system.call(
			"apply_tv_appearance",
			employee,
			role_type,
			audience_rating,
			episode.production_quality,
			audience_reach
		)
		career_updates.append({
			"employee_id": employee_id,
			"role_type": role_type,
			"update": update,
		})
	_update_program_statistics(program_type_id, program_id, broadcast_day)
	return {
		"success": true,
		"message": "Эпизод вышел в эфир.",
		"episode": episode,
		"audience_rating": audience_rating,
		"audience_reach": audience_reach,
		"career_updates": career_updates,
	}


func get_contract_offer_profile(
	employee_id: String,
	employees: Array
) -> Dictionary:
	var employee: Variant = _find_employee(employees, employee_id)
	if employee == null:
		return {}
	var profile: Dictionary = _celebrity_system.call(
		"get_contract_offer_profile",
		employee
	)
	return profile


func get_series(series_id: String) -> Variant:
	return _find_series(series_id)


func get_talk_show(show_id: String) -> Variant:
	return _find_talk_show(show_id)


func get_schedule_entry(schedule_id: String) -> Variant:
	return _find_schedule_entry(schedule_id)


func get_active_episode() -> Variant:
	return active_episode


func to_dict() -> Dictionary:
	var series_payloads: Array[Dictionary] = []
	for series_data in series:
		series_payloads.append(series_data.to_dict())
	var talk_show_payloads: Array[Dictionary] = []
	for show in talk_shows:
		talk_show_payloads.append(show.to_dict())
	var schedule_payloads: Array[Dictionary] = []
	for schedule in schedule_entries:
		schedule_payloads.append(schedule.to_dict())
	return {
		"schema_version": 1,
		"seed": _seed,
		"rng_state": _rng_state,
		"next_schedule_number": _next_schedule_number,
		"series": series_payloads,
		"talk_shows": talk_show_payloads,
		"schedule_entries": schedule_payloads,
		"active_program_type_id": active_program_type_id,
		"active_program_id": active_program_id,
		"active_schedule_id": active_schedule_id,
		"active_episode_id": (
			str(active_episode.id)
			if active_episode != null
			else ""
		),
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/tv_production/tv_production_system.gd"
	).new()
	result.initialize(int(payload.get("seed", 1)))
	result._rng_state = int(payload.get("rng_state", result._rng_state))
	result._next_schedule_number = maxi(
		int(payload.get("next_schedule_number", 1)),
		1
	)
	var raw_series: Variant = payload.get("series", [])
	if raw_series is Array:
		for raw_series_data in raw_series:
			if raw_series_data is Dictionary:
				result.series.append(
					TV_SERIES_DATA_SCRIPT.from_dict(raw_series_data)
				)
	var raw_talk_shows: Variant = payload.get("talk_shows", [])
	if raw_talk_shows is Array:
		for raw_show in raw_talk_shows:
			if raw_show is Dictionary:
				result.talk_shows.append(
					TV_TALK_SHOW_DATA_SCRIPT.from_dict(raw_show)
				)
	var raw_schedules: Variant = payload.get("schedule_entries", [])
	if raw_schedules is Array:
		for raw_schedule in raw_schedules:
			if raw_schedule is Dictionary:
				result.schedule_entries.append(
					TV_SCHEDULE_ENTRY_SCRIPT.from_dict(raw_schedule)
				)
	result.active_program_type_id = str(
		payload.get("active_program_type_id", "")
	)
	result.active_program_id = str(payload.get("active_program_id", ""))
	result.active_schedule_id = str(payload.get("active_schedule_id", ""))
	var active_episode_id: String = str(
		payload.get("active_episode_id", "")
	)
	if not active_episode_id.is_empty():
		result.active_episode = result._find_episode(
			result.active_program_type_id,
			result.active_program_id,
			active_episode_id
		)
		if (
			result.active_episode == null
			or str(result.active_episode.status)
			!= TV_EPISODE_DATA_SCRIPT.STATUS_IN_PRODUCTION
		):
			result.active_episode = null
			result.active_program_type_id = ""
			result.active_program_id = ""
			result.active_schedule_id = ""
	return result


func _create_schedule_entry(
	program_type_id: String,
	program_id: String,
	day_of_week: int,
	start_hour: int,
	start_minute: int,
	duration_minutes: int,
	participant_ids: Array[String]
) -> Dictionary:
	if day_of_week < 0 or day_of_week > 6:
		return _failure("День регулярных съёмок должен находиться в диапазоне 0–6.")
	if start_hour < 0 or start_hour > 23 or start_minute < 0 or start_minute > 59:
		return _failure("Указано некорректное время начала съёмок.")
	if duration_minutes < 1 or duration_minutes > 720:
		return _failure("Продолжительность съёмочного окна должна быть от 1 до 720 минут.")
	if start_hour * 60 + start_minute + duration_minutes > 1440:
		return _failure("Регулярное съёмочное окно не должно переходить на следующие игровые сутки.")
	for existing in schedule_entries:
		if (
			existing.active
			and existing.program_type_id == program_type_id
			and existing.program_id == program_id
		):
			return _failure("Для этой программы уже существует регулярное расписание.")

	var schedule: Variant = TV_SCHEDULE_ENTRY_SCRIPT.new()
	schedule.id = "TVS-%06d" % _next_schedule_number
	_next_schedule_number += 1
	schedule.program_type_id = program_type_id
	schedule.program_id = program_id
	schedule.day_of_week = day_of_week
	schedule.start_hour = start_hour
	schedule.start_minute = start_minute
	schedule.duration_minutes = duration_minutes
	schedule.participant_ids = _normalize_employee_ids(participant_ids)
	for existing in schedule_entries:
		if schedule.conflicts_with(existing):
			return _failure(
				"Расписание конфликтует с другой телевизионной или кинопроизводственной занятостью сотрудника."
			)
	schedule_entries.append(schedule)
	return {
		"success": true,
		"message": "Регулярное расписание съёмок сохранено.",
		"schedule": schedule,
	}


func _has_required_tv_crew(crew_assignments: Dictionary) -> bool:
	for role_id in ["director", "camera_operator", "technician"]:
		if str(crew_assignments.get(role_id, "")).strip_edges().is_empty():
			return false
	return true


func _collect_participant_ids(
	cast_employee_ids: Array[String],
	crew_assignments: Dictionary
) -> Array[String]:
	var result: Array[String] = _normalize_employee_ids(cast_employee_ids)
	for employee_id_value in crew_assignments.values():
		var employee_id: String = str(employee_id_value)
		if not employee_id.is_empty() and not result.has(employee_id):
			result.append(employee_id)
	return result


func _normalize_employee_ids(employee_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for employee_id_value in employee_ids:
		var employee_id: String = str(employee_id_value).strip_edges()
		if not employee_id.is_empty() and not result.has(employee_id):
			result.append(employee_id)
	return result


func _resolve_talk_show_guests(
	show: Variant,
	requested_guest_ids: Array[String]
) -> Array[String]:
	var guests: Array[String] = _normalize_employee_ids(requested_guest_ids)
	if guests.is_empty():
		guests = _select_talk_show_guests(show)
	if guests.is_empty() or guests.size() > _get_talk_show_guest_limit(show):
		return []
	for guest_id in guests:
		if guest_id == str(show.host_employee_id):
			return []
		if (
			not show.guest_pool_employee_ids.is_empty()
			and not show.guest_pool_employee_ids.has(guest_id)
		):
			return []
	return guests


func _select_talk_show_guests(show: Variant) -> Array[String]:
	var pool: Array[String] = show.guest_pool_employee_ids
	if pool.is_empty():
		return []
	var guest_limit: int = mini(_get_talk_show_guest_limit(show), pool.size())
	var result: Array[String] = []
	var start_index: int = posmod(show.next_guest_index, pool.size())
	for offset in range(pool.size()):
		if result.size() >= guest_limit:
			break
		var guest_id: String = pool[posmod(start_index + offset, pool.size())]
		if guest_id != str(show.host_employee_id) and not result.has(guest_id):
			result.append(guest_id)
	show.next_guest_index = posmod(start_index + maxi(result.size(), 1), pool.size())
	return result


func _get_talk_show_guest_limit(show: Variant) -> int:
	match str(show.format_id):
		"panel":
			return MAX_TALK_SHOW_GUESTS
		"daytime":
			return 2
		_:
			return 1


func _has_employee_schedule_conflict(
	employee_id: String,
	day_of_week: int,
	start_minute: int,
	duration_minutes: int,
	ignored_schedule_id: String
) -> bool:
	var end_minute: int = start_minute + duration_minutes
	for schedule in schedule_entries:
		if (
			not schedule.active
			or schedule.id == ignored_schedule_id
			or schedule.day_of_week != day_of_week
			or not schedule.participant_ids.has(employee_id)
		):
			continue
		var existing_start: int = schedule.start_hour * 60 + schedule.start_minute
		var existing_end: int = existing_start + schedule.duration_minutes
		if start_minute < existing_end and existing_start < end_minute:
			return true
	return false


func _estimate_episode_minutes(episode: Variant) -> int:
	var performer_count: int = maxi(_get_performer_count(episode), 1)
	var rehearsal_minutes: int = maxi(MIN_REHEARSAL_MINUTES, performer_count)
	var shooting_minutes: int = maxi(
		MIN_SHOOTING_MINUTES,
		ceili(float(episode.runtime_minutes) * 0.4)
	)
	var postproduction_minutes: int = maxi(
		MIN_POSTPRODUCTION_MINUTES,
		ceili(float(episode.runtime_minutes) * 0.1)
	)
	return (
		PREPARATION_MINUTES
		+ rehearsal_minutes
		+ shooting_minutes
		+ postproduction_minutes
	)


func _get_performer_count(episode: Variant) -> int:
	var performers: Array[String] = _get_episode_talent_ids(episode)
	return maxi(performers.size(), 1)


func _get_episode_talent_ids(episode: Variant) -> Array[String]:
	var result: Array[String] = []
	if not str(episode.host_employee_id).is_empty():
		result.append(str(episode.host_employee_id))
	for employee_id in episode.cast_employee_ids:
		if not result.has(employee_id):
			result.append(employee_id)
	for employee_id in episode.guest_employee_ids:
		if not result.has(employee_id):
			result.append(employee_id)
	return result


func _set_active_phase(
	phase_id: String,
	duration_minutes: int,
	activity_message: String
) -> void:
	active_episode.current_phase = phase_id
	active_episode.phase_minutes_elapsed = 0
	active_episode.phase_duration_minutes = maxi(duration_minutes, 1)
	active_episode.last_activity_message = activity_message


func _calculate_production_quality(
	episode: Variant,
	performance_snapshot: Dictionary
) -> float:
	var score: float = 0.0
	if episode.program_type_id == "talk_show":
		score = (
			float(performance_snapshot.get("host_presence", 45.0)) * 0.26
			+ float(performance_snapshot.get("improvisation", 45.0)) * 0.18
			+ float(performance_snapshot.get("communication", 45.0)) * 0.16
			+ float(performance_snapshot.get("directing", 45.0)) * 0.12
			+ float(performance_snapshot.get("camera_work", 45.0)) * 0.12
			+ float(performance_snapshot.get("guest_performance", 45.0)) * 0.10
			+ float(performance_snapshot.get("technical", 45.0)) * 0.06
		)
	else:
		score = (
			float(performance_snapshot.get("acting_average", 45.0)) * 0.28
			+ float(performance_snapshot.get("directing", 45.0)) * 0.18
			+ float(performance_snapshot.get("writing", 45.0)) * 0.18
			+ float(performance_snapshot.get("camera_work", 45.0)) * 0.14
			+ float(performance_snapshot.get("technical", 45.0)) * 0.12
			+ float(performance_snapshot.get("set_design", 45.0)) * 0.10
		)
	var energy: float = clampf(
		float(performance_snapshot.get("energy", 0.75)),
		0.0,
		1.0
	)
	var morale: float = clampf(
		float(performance_snapshot.get("morale", 0.75)),
		0.0,
		1.0
	)
	var stress: float = clampf(
		float(performance_snapshot.get("stress", 0.15)),
		0.0,
		1.0
	)
	var condition_modifier: float = (
		(energy - 0.5) * 8.0
		+ (morale - 0.5) * 6.0
		- stress * 5.0
	)
	_rng.state = (
		episode.production_rng_state
		if episode.production_rng_state != 0
		else _rng_state
	)
	var quality_variance: float = _rng.randf_range(-3.0, 3.0)
	episode.production_rng_state = _rng.state
	_rng_state = _rng.state
	return clampf(score + condition_modifier + quality_variance, 0.0, 100.0)


func _get_episode_role(episode: Variant, employee_id: String) -> String:
	if employee_id == str(episode.host_employee_id):
		return "host"
	if episode.guest_employee_ids.has(employee_id):
		return "guest"
	return "series_regular"


func _find_employee(employees: Array, employee_id: String) -> Variant:
	for employee in employees:
		if str(employee.id) == employee_id:
			return employee
	return null


func _update_program_statistics(
	program_type_id: String,
	program_id: String,
	broadcast_day: int
) -> void:
	if program_type_id == "series":
		var series_data: Variant = _find_series(program_id)
		if series_data == null:
			return
		series_data.last_episode_broadcast_day = maxi(broadcast_day, 1)
		series_data.refresh_statistics()
		if str(series_data.status) == "completed":
			_deactivate_program_schedule("series", program_id)
	else:
		var show: Variant = _find_talk_show(program_id)
		if show == null:
			return
		show.last_episode_broadcast_day = maxi(broadcast_day, 1)
		show.refresh_statistics()


func _deactivate_program_schedule(
	program_type_id: String,
	program_id: String
) -> void:
	for schedule in schedule_entries:
		if (
			schedule.program_type_id == program_type_id
			and schedule.program_id == program_id
		):
			schedule.active = false


func _find_episode(
	program_type_id: String,
	program_id: String,
	episode_id: String
) -> Variant:
	if program_type_id == "series":
		var series_data: Variant = _find_series(program_id)
		return series_data.get_episode(episode_id) if series_data != null else null
	if program_type_id == "talk_show":
		var show: Variant = _find_talk_show(program_id)
		return show.get_episode(episode_id) if show != null else null
	return null


func _find_series(series_id: String) -> Variant:
	for series_data in series:
		if str(series_data.id) == series_id:
			return series_data
	return null


func _find_talk_show(show_id: String) -> Variant:
	for show in talk_shows:
		if str(show.id) == show_id:
			return show
	return null


func _find_schedule_entry(schedule_id: String) -> Variant:
	for schedule in schedule_entries:
		if str(schedule.id) == schedule_id:
			return schedule
	return null


func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
	}


