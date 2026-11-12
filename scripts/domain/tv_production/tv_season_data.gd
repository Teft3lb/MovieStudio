extends RefCounted
class_name TVSeasonData

const TV_EPISODE_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_episode_data.gd"
)

var series_id: String = ""
var season_number: int = 1
var status: String = "planned"
var episodes: Array = []
var average_rating: float = 0.0
var total_viewers: int = 0
var premiere_day: int = 0
var finale_day: int = 0


func get_next_episode() -> Variant:
	for episode in episodes:
		if str(episode.status) == TV_EPISODE_DATA_SCRIPT.STATUS_PLANNED:
			return episode
	return null


func get_episode(episode_id: String) -> Variant:
	for episode in episodes:
		if str(episode.id) == episode_id:
			return episode
	return null


func get_produced_episode_count() -> int:
	var count: int = 0
	for episode in episodes:
		if str(episode.status) in [
			TV_EPISODE_DATA_SCRIPT.STATUS_READY_FOR_BROADCAST,
			TV_EPISODE_DATA_SCRIPT.STATUS_BROADCASTED,
		]:
			count += 1
	return count


func get_broadcast_episode_count() -> int:
	var count: int = 0
	for episode in episodes:
		if str(episode.status) == TV_EPISODE_DATA_SCRIPT.STATUS_BROADCASTED:
			count += 1
	return count


func refresh_statistics() -> void:
	var rating_total: float = 0.0
	var rating_count: int = 0
	total_viewers = 0
	for episode in episodes:
		if str(episode.status) != TV_EPISODE_DATA_SCRIPT.STATUS_BROADCASTED:
			continue
		rating_total += float(episode.audience_rating)
		rating_count += 1
		total_viewers += int(episode.audience_reach)
	average_rating = (
		rating_total / float(rating_count)
		if rating_count > 0
		else 0.0
	)
	if get_broadcast_episode_count() >= episodes.size() and not episodes.is_empty():
		status = "completed"
	elif get_produced_episode_count() > 0:
		status = "in_production"


func to_dict() -> Dictionary:
	var episode_payloads: Array[Dictionary] = []
	for episode in episodes:
		episode_payloads.append(episode.to_dict())
	return {
		"series_id": series_id,
		"season_number": season_number,
		"status": status,
		"episodes": episode_payloads,
		"average_rating": average_rating,
		"total_viewers": total_viewers,
		"premiere_day": premiere_day,
		"finale_day": finale_day,
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/tv_production/tv_season_data.gd"
	).new()
	result.series_id = str(payload.get("series_id", ""))
	result.season_number = clampi(
		int(payload.get("season_number", 1)),
		1,
		99
	)
	result.status = str(payload.get("status", "planned"))
	result.average_rating = clampf(
		float(payload.get("average_rating", 0.0)),
		0.0,
		100.0
	)
	result.total_viewers = maxi(int(payload.get("total_viewers", 0)), 0)
	result.premiere_day = maxi(int(payload.get("premiere_day", 0)), 0)
	result.finale_day = maxi(int(payload.get("finale_day", 0)), 0)
	var raw_episodes: Variant = payload.get("episodes", [])
	if raw_episodes is Array:
		for raw_episode in raw_episodes:
			if raw_episode is Dictionary:
				result.episodes.append(
					TV_EPISODE_DATA_SCRIPT.from_dict(raw_episode)
				)
	return result
