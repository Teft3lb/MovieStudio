extends RefCounted
class_name TVSeriesData

const TV_SEASON_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_season_data.gd"
)

var id: String = ""
var title: String = ""
var genre_id: String = ""
var genre_title: String = ""
var format_id: String = "drama"
var episode_runtime_minutes: int = 45
var episodes_per_season: int = 8
var planned_season_count: int = 1
var status: String = "active"
var writer_employee_id: String = ""
var producer_employee_id: String = ""
var cast_employee_ids: Array[String] = []
var crew_assignments: Dictionary = {}
var seasons: Array = []
var average_rating: float = 0.0
var total_viewers: int = 0
var created_day: int = 1
var last_episode_broadcast_day: int = 0
var renewal_status: String = "pending"
var recurring_schedule_id: String = ""


func get_season(season_number: int) -> Variant:
	for season in seasons:
		if int(season.season_number) == season_number:
			return season
	return null


func get_next_episode() -> Variant:
	for season in seasons:
		var episode: Variant = season.get_next_episode()
		if episode != null:
			return episode
	return null


func get_episode(episode_id: String) -> Variant:
	for season in seasons:
		var episode: Variant = season.get_episode(episode_id)
		if episode != null:
			return episode
	return null


func get_total_episode_count() -> int:
	var count: int = 0
	for season in seasons:
		count += season.episodes.size()
	return count


func get_broadcast_episode_count() -> int:
	var count: int = 0
	for season in seasons:
		count += int(season.get_broadcast_episode_count())
	return count


func refresh_statistics() -> void:
	var rating_total: float = 0.0
	var rating_count: int = 0
	total_viewers = 0
	for season in seasons:
		season.refresh_statistics()
		for episode in season.episodes:
			if str(episode.status) != "broadcasted":
				continue
			rating_total += float(episode.audience_rating)
			rating_count += 1
			total_viewers += int(episode.audience_reach)
	average_rating = (
		rating_total / float(rating_count)
		if rating_count > 0
		else 0.0
	)
	if get_broadcast_episode_count() >= get_total_episode_count():
		status = "completed"


func to_dict() -> Dictionary:
	var season_payloads: Array[Dictionary] = []
	for season in seasons:
		season_payloads.append(season.to_dict())
	return {
		"id": id,
		"title": title,
		"genre_id": genre_id,
		"genre_title": genre_title,
		"format_id": format_id,
		"episode_runtime_minutes": episode_runtime_minutes,
		"episodes_per_season": episodes_per_season,
		"planned_season_count": planned_season_count,
		"status": status,
		"writer_employee_id": writer_employee_id,
		"producer_employee_id": producer_employee_id,
		"cast_employee_ids": cast_employee_ids.duplicate(),
		"crew_assignments": crew_assignments.duplicate(true),
		"seasons": season_payloads,
		"average_rating": average_rating,
		"total_viewers": total_viewers,
		"created_day": created_day,
		"last_episode_broadcast_day": last_episode_broadcast_day,
		"renewal_status": renewal_status,
		"recurring_schedule_id": recurring_schedule_id,
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/tv_production/tv_series_data.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.title = str(payload.get("title", ""))
	result.genre_id = str(payload.get("genre_id", ""))
	result.genre_title = str(payload.get("genre_title", ""))
	result.format_id = str(payload.get("format_id", "drama"))
	result.episode_runtime_minutes = clampi(
		int(payload.get("episode_runtime_minutes", 45)),
		5,
		180
	)
	result.episodes_per_season = clampi(
		int(payload.get("episodes_per_season", 8)),
		1,
		24
	)
	result.planned_season_count = clampi(
		int(payload.get("planned_season_count", 1)),
		1,
		99
	)
	result.status = str(payload.get("status", "active"))
	result.writer_employee_id = str(payload.get("writer_employee_id", ""))
	result.producer_employee_id = str(payload.get("producer_employee_id", ""))
	var raw_cast: Variant = payload.get("cast_employee_ids", [])
	if raw_cast is Array:
		for employee_id_value in raw_cast:
			var employee_id: String = str(employee_id_value)
			if not employee_id.is_empty() and not result.cast_employee_ids.has(employee_id):
				result.cast_employee_ids.append(employee_id)
	var raw_crew: Variant = payload.get("crew_assignments", {})
	if raw_crew is Dictionary:
		result.crew_assignments = raw_crew.duplicate(true)
	result.average_rating = clampf(
		float(payload.get("average_rating", 0.0)),
		0.0,
		100.0
	)
	result.total_viewers = maxi(int(payload.get("total_viewers", 0)), 0)
	result.created_day = maxi(int(payload.get("created_day", 1)), 1)
	result.last_episode_broadcast_day = maxi(
		int(payload.get("last_episode_broadcast_day", 0)),
		0
	)
	result.renewal_status = str(payload.get("renewal_status", "pending"))
	result.recurring_schedule_id = str(
		payload.get("recurring_schedule_id", "")
	)
	var raw_seasons: Variant = payload.get("seasons", [])
	if raw_seasons is Array:
		for raw_season in raw_seasons:
			if raw_season is Dictionary:
				result.seasons.append(
					TV_SEASON_DATA_SCRIPT.from_dict(raw_season)
				)
	return result
