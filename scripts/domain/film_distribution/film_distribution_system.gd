extends RefCounted
class_name FilmDistributionSystem

const DAILY_REACH: Array[int] = [20, 17, 14, 11, 8, 6, 4]

var _runs: Dictionary[String, Dictionary] = {}
var _active_ids: Array[String] = []


func open_run(project_id: String, release_day: int, commercial_score: int) -> bool:
	if project_id.is_empty() or release_day < 1 or _runs.has(project_id):
		return false
	_runs[project_id] = {
		"release_day": release_day,
		"end_day": release_day + DAILY_REACH.size(),
		"days_settled": 0,
		"gross": 0,
		"commercial_score": clampi(commercial_score, 0, 100),
		"closed": false,
	}
	_active_ids.append(project_id)
	return true


func get_run(project_id: String) -> Dictionary:
	return _runs.get(project_id, {}).duplicate()


func update_commercial_score(project_id: String, commercial_score: int) -> void:
	var run: Dictionary = _runs.get(project_id, {})
	if not run.is_empty() and not bool(run.closed):
		run.commercial_score = clampi(commercial_score, 0, 100)


func settle_through(day: int) -> int:
	var total: int = 0
	for index in range(_active_ids.size() - 1, -1, -1):
		var run: Dictionary = _runs[_active_ids[index]]
		var due_days: int = clampi(day - int(run.release_day), 0, DAILY_REACH.size())
		for run_day in range(int(run.days_settled), due_days):
			var gross: int = int(run.commercial_score) * DAILY_REACH[run_day]
			run.gross = int(run.gross) + gross
			total += gross
		if due_days > int(run.days_settled):
			run.days_settled = due_days
		if due_days == DAILY_REACH.size():
			run.closed = true
			_active_ids.remove_at(index)
	return total
