extends RefCounted
class_name FilmEditingSystem

const PROJECT_DATA_SCRIPT = preload(
	"res://scripts/domain/film_editing/film_editing_project.gd"
)

const ASSEMBLY_BASE_MINUTES: int = 18
const ASSEMBLY_MINUTES_PER_SCENE: int = 3
const FINE_CUT_BASE_MINUTES: int = 12
const FINE_CUT_MINUTES_PER_SCENE: int = 2
const SOUND_MIX_BASE_MINUTES: int = 10
const SOUND_MIX_MINUTES_PER_SCENE: int = 1
const COLOR_GRADING_BASE_MINUTES: int = 8
const COLOR_GRADING_MINUTES_PER_SCENE: int = 1
const EXPORT_MINUTES: int = 5


func create_project(
	production_project: Variant,
	editor_id: String,
	editor_skill: float,
	project_id: String,
	current_day: int,
	current_hour: int,
	current_minute: int
) -> Variant:
	if (
		production_project == null
		or str(production_project.status) != "completed"
		or editor_id.is_empty()
	):
		return null
	var source_scenes: Variant = production_project.scene_results
	if (
		not source_scenes is Array
		or source_scenes.is_empty()
		or source_scenes.size() != int(production_project.total_scene_count)
	):
		return null
	for scene_result in source_scenes:
		if not scene_result is Dictionary:
			return null

	var project: Variant = PROJECT_DATA_SCRIPT.new()
	project.id = project_id
	project.production_project_id = str(production_project.id)
	project.film_title = str(production_project.film_title)
	project.genre_id = str(production_project.genre_id)
	project.genre_title = str(production_project.genre_title)
	project.editor_id = editor_id
	project.editor_skill = clampf(editor_skill, 0.0, 100.0)
	project.source_quality = clampi(int(production_project.final_quality), 0, 100)
	project.scene_results = source_scenes.duplicate(true)
	for scene_index in range(project.scene_results.size()):
		project.timeline_order.append(scene_index)
	project.estimated_total_minutes = _estimate_total_minutes(
		project.scene_results.size()
	)
	project.started_day = maxi(current_day, 1)
	project.started_hour = clampi(current_hour, 0, 23)
	project.started_minute = clampi(current_minute, 0, 59)
	project.last_activity_message = (
		"Таймлайн подготовлен. Проверь порядок сцен перед началом монтажа."
	)
	return project


func move_scene(
	project: Variant,
	from_position: int,
	to_position: int
) -> bool:
	if project == null or str(project.status) != "draft":
		return false
	if not _is_valid_timeline(project):
		return false
	if (
		from_position < 0
		or from_position >= project.timeline_order.size()
		or to_position < 0
		or to_position >= project.timeline_order.size()
	):
		return false
	if from_position == to_position:
		return true
	project.timeline_order.insert(
		to_position,
		project.timeline_order.pop_at(from_position)
	)
	return true


func get_ordered_scene_results(project: Variant) -> Array:
	var result: Array = []
	if project == null or not _is_valid_timeline(project):
		return result
	for timeline_position in range(project.timeline_order.size()):
		var source_index: int = project.timeline_order[timeline_position]
		var scene_result: Dictionary = project.scene_results[source_index].duplicate(
			true
		)
		scene_result["source_index"] = source_index
		scene_result["timeline_position"] = timeline_position
		result.append(scene_result)
	return result


func reassign_editor(
	project: Variant,
	editor_id: String,
	editor_skill: float
) -> bool:
	if (
		project == null
		or not ["draft", "in_editing"].has(str(project.status))
		or editor_id.is_empty()
	):
		return false
	project.editor_id = editor_id
	project.editor_skill = clampf(editor_skill, 0.0, 100.0)
	project.pause_reason = ""
	project.last_activity_message = (
		"Проект передан монтажёру. Работа продолжится после его выхода на рабочее место."
	)
	return true


func start_editing(project: Variant) -> bool:
	if (
		project == null
		or str(project.status) != "draft"
		or not _is_valid_timeline(project)
	):
		return false
	project.status = "in_editing"
	project.current_phase = "assembly_cut"
	project.phase_minutes_elapsed = 0
	project.phase_duration_minutes = _get_phase_duration(
		"assembly_cut",
		project.scene_results.size()
	)
	project.last_activity_message = "Монтажёр начал черновую сборку фильма."
	project.pause_reason = ""
	return true


func advance_minute(project: Variant, editor_ready: bool) -> Dictionary:
	if project == null or str(project.status) != "in_editing":
		return _empty_result()
	if not editor_ready:
		project.pause_reason = (
			"Ожидает монтажёра на рабочем месте монтажного отдела."
		)
		project.last_activity_message = project.pause_reason
		return _empty_result()

	project.pause_reason = ""
	project.phase_minutes_elapsed += 1
	project.total_elapsed_minutes += 1
	if project.phase_minutes_elapsed < project.phase_duration_minutes:
		return {
			"advanced": true,
			"phase_changed": false,
			"completed": false,
		}

	match str(project.current_phase):
		"assembly_cut":
			_set_phase(project, "fine_cut")
			project.last_activity_message = "Черновая сборка завершена. Начат чистовой монтаж."
			return _phase_change_result()
		"fine_cut":
			_set_phase(project, "sound_mix")
			project.last_activity_message = "Чистовой монтаж завершён. Выполняется сведение звука."
			return _phase_change_result()
		"sound_mix":
			_set_phase(project, "color_grading")
			project.last_activity_message = "Звук сведён. Начата цветокоррекция."
			return _phase_change_result()
		"color_grading":
			_set_phase(project, "export")
			project.last_activity_message = "Цветокоррекция завершена. Выполняется экспорт."
			return _phase_change_result()
		"export":
			project.status = "completed"
			project.continuity_score = get_timeline_coherence_score(project)
			project.final_quality = _calculate_final_quality(project)
			project.pause_reason = ""
			project.last_activity_message = (
				"Фильм «%s» смонтирован и готов к выпуску."
				% project.film_title
			)
			return {
				"advanced": true,
				"phase_changed": true,
				"completed": true,
			}
	return _empty_result()


func get_timeline_coherence_score(project: Variant) -> int:
	if project == null or not _is_valid_timeline(project):
		return 0
	var scene_count: int = project.timeline_order.size()
	var possible_inversions: int = int(
		float(scene_count * (scene_count - 1)) * 0.5
	)
	if possible_inversions <= 0:
		return 100
	var inversions: int = 0
	for left_index in range(scene_count):
		for right_index in range(left_index + 1, scene_count):
			if project.timeline_order[left_index] > project.timeline_order[right_index]:
				inversions += 1
	var disorder_ratio: float = float(inversions) / float(possible_inversions)
	return clampi(roundi(100.0 - disorder_ratio * 30.0), 70, 100)


func _calculate_final_quality(project: Variant) -> int:
	return roundi(clampf(
		float(project.source_quality) * 0.75
		+ float(project.editor_skill) * 0.20
		+ float(project.continuity_score) * 0.05,
		0.0,
		100.0
	))


func _estimate_total_minutes(scene_count: int) -> int:
	var normalized_count: int = maxi(scene_count, 1)
	return (
		_get_phase_duration("assembly_cut", normalized_count)
		+ _get_phase_duration("fine_cut", normalized_count)
		+ _get_phase_duration("sound_mix", normalized_count)
		+ _get_phase_duration("color_grading", normalized_count)
		+ EXPORT_MINUTES
	)


func _get_phase_duration(phase: String, scene_count: int) -> int:
	var normalized_count: int = maxi(scene_count, 1)
	match phase:
		"assembly_cut":
			return ASSEMBLY_BASE_MINUTES + normalized_count * ASSEMBLY_MINUTES_PER_SCENE
		"fine_cut":
			return FINE_CUT_BASE_MINUTES + normalized_count * FINE_CUT_MINUTES_PER_SCENE
		"sound_mix":
			return SOUND_MIX_BASE_MINUTES + normalized_count * SOUND_MIX_MINUTES_PER_SCENE
		"color_grading":
			return COLOR_GRADING_BASE_MINUTES + normalized_count * COLOR_GRADING_MINUTES_PER_SCENE
		_:
			return EXPORT_MINUTES


func _set_phase(project: Variant, phase: String) -> void:
	project.current_phase = phase
	project.phase_minutes_elapsed = 0
	project.phase_duration_minutes = _get_phase_duration(
		phase,
		project.scene_results.size()
	)


func _is_valid_timeline(project: Variant) -> bool:
	if project.scene_results.is_empty():
		return false
	if project.timeline_order.size() != project.scene_results.size():
		return false
	var seen: Dictionary = {}
	for scene_index in project.timeline_order:
		if (
			scene_index < 0
			or scene_index >= project.scene_results.size()
			or seen.has(scene_index)
		):
			return false
		seen[scene_index] = true
	return true


func _phase_change_result() -> Dictionary:
	return {
		"advanced": true,
		"phase_changed": true,
		"completed": false,
	}


func _empty_result() -> Dictionary:
	return {
		"advanced": false,
		"phase_changed": false,
		"completed": false,
	}
