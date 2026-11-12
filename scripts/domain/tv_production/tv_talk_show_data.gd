extends RefCounted
class_name TVTalkShowData

const TV_EPISODE_DATA_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_episode_data.gd"
)

var id: String = ""
var title: String = ""
var format_id: String = "interview"
var host_employee_id: String = ""
var guest_pool_employee_ids: Array[String] = []
var crew_assignments: Dictionary = {}
var episode_duration_minutes: int = 60
var status: String = "active"
var episodes: Array = []
var next_episode_number: int = 1
var next_guest_index: int = 0
var average_rating: float = 0.0
var total_viewers: int = 0
var created_day: int = 1
var last_episode_broadcast_day: int = 0
var recurring_schedule_id: String = ""


func get_episode(episode_id: String) -> Variant:
	for episode in episodes:
		if str(episode.id) == episode_id:
			return episode
	return null


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


func to_dict() -> Dictionary:
	var episode_payloads: Array[Dictionary] = []
	for episode in episodes:
		episode_payloads.append(episode.to_dict())
	return {
		"id": id,
		"title": title,
		"format_id": format_id,
		"host_employee_id": host_employee_id,
		"guest_pool_employee_ids": guest_pool_employee_ids.duplicate(),
		"crew_assignments": crew_assignments.duplicate(true),
		"episode_duration_minutes": episode_duration_minutes,
		"status": status,
		"episodes": episode_payloads,
		"next_episode_number": next_episode_number,
		"next_guest_index": next_guest_index,
		"average_rating": average_rating,
		"total_viewers": total_viewers,
		"created_day": created_day,
		"last_episode_broadcast_day": last_episode_broadcast_day,
		"recurring_schedule_id": recurring_schedule_id,
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/tv_production/tv_talk_show_data.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.title = str(payload.get("title", ""))
	result.format_id = str(payload.get("format_id", "interview"))
	result.host_employee_id = str(payload.get("host_employee_id", ""))
	var raw_guests: Variant = payload.get("guest_pool_employee_ids", [])
	if raw_guests is Array:
		for employee_id_value in raw_guests:
			var employee_id: String = str(employee_id_value)
			if (
				not employee_id.is_empty()
				and employee_id != result.host_employee_id
				and not result.guest_pool_employee_ids.has(employee_id)
			):
				result.guest_pool_employee_ids.append(employee_id)
	var raw_crew: Variant = payload.get("crew_assignments", {})
	if raw_crew is Dictionary:
		result.crew_assignments = raw_crew.duplicate(true)
	result.episode_duration_minutes = clampi(
		int(payload.get("episode_duration_minutes", 60)),
		5,
		180
	)
	result.status = str(payload.get("status", "active"))
	result.next_episode_number = maxi(
		int(payload.get("next_episode_number", 1)),
		1
	)
	result.next_guest_index = maxi(int(payload.get("next_guest_index", 0)), 0)
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
	result.recurring_schedule_id = str(
		payload.get("recurring_schedule_id", "")
	)
	var raw_episodes: Variant = payload.get("episodes", [])
	if raw_episodes is Array:
		for raw_episode in raw_episodes:
			if raw_episode is Dictionary:
				result.episodes.append(
					TV_EPISODE_DATA_SCRIPT.from_dict(raw_episode)
				)
	return result
