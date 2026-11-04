extends RefCounted
class_name ScriptWritingSystem

const PROJECT_DATA_SCRIPT = preload(
	"res://scripts/domain/script_department/script_writing_project.gd"
)
const SCRIPT_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/script_department/script_generator.gd"
)

const BASE_WORK_MINUTES: int = 180
const MINUTES_PER_SCENE: int = 45
const MINUTES_PER_ROLE: int = 30
const MINIMUM_PROJECT_MINUTES: int = 60
const BASE_INTERRUPTION_CHANCE: float = 0.0015
const INTERRUPTION_MESSAGES: Array[String] = [
	"Отвлёкся на телефонный звонок",
	"Творческий ступор — подбирает сюжетный ход",
	"Перечитывает заметки и собирает мысли",
	"Незапланированный разговор с продюсером",
	"Ищет дополнительный материал для сцены",
]

var _rng: RandomNumberGenerator
var _script_generator: RefCounted


func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_script_generator = SCRIPT_GENERATOR_SCRIPT.new()


func start_project(
	writer: Variant,
	genre_id: String,
	scene_count: int,
	role_count: int,
	seed: int,
	project_id: String,
	script_id: String,
	current_day: int,
	current_hour: int,
	current_minute: int
) -> Variant:
	if writer == null or str(writer.profession_id) != "screenwriter":
		return null

	var normalized_scene_count: int = clampi(scene_count, 3, 20)
	var normalized_role_count: int = clampi(role_count, 1, 8)
	var project: Variant = PROJECT_DATA_SCRIPT.new()
	project.id = project_id
	project.script_id = script_id
	project.writer_id = str(writer.id)
	project.writer_name = str(writer.get_full_name())
	project.genre_id = genre_id
	project.scene_count = normalized_scene_count
	project.role_count = normalized_role_count
	project.seed = seed
	project.required_work_minutes = calculate_required_work_minutes(
		writer,
		normalized_scene_count,
		normalized_role_count
	)
	project.started_day = maxi(current_day, 1)
	project.started_hour = clampi(current_hour, 0, 23)
	project.started_minute = clampi(current_minute, 0, 59)
	project.last_activity_message = "Ожидает сценариста на рабочем месте."

	_rng.seed = seed
	project.rng_state = _rng.state
	return project


func calculate_required_work_minutes(
	writer: Variant,
	scene_count: int,
	role_count: int
) -> int:
	if writer == null:
		return 0

	var skills: Dictionary = writer.skills
	var writing_skill: float = clampf(
		float(skills.get("writing", 40.0)),
		0.0,
		100.0
	)
	var reliability_skill: float = clampf(
		float(skills.get("reliability", 40.0)),
		0.0,
		100.0
	)
	var base_minutes: float = float(
		BASE_WORK_MINUTES
		+ clampi(scene_count, 3, 20) * MINUTES_PER_SCENE
		+ clampi(role_count, 1, 8) * MINUTES_PER_ROLE
	)
	var writing_factor: float = 1.25 - writing_skill * 0.0045
	var reliability_factor: float = 1.10 - reliability_skill * 0.002
	return maxi(
		roundi(base_minutes * writing_factor * reliability_factor),
		MINIMUM_PROJECT_MINUTES
	)


func advance_minute(
	project: Variant,
	writer: Variant,
	is_at_workplace: bool
) -> Dictionary:
	if project == null or str(project.status) != "in_progress":
		return {"advanced": false, "completed": false, "interrupted": false}

	if writer == null:
		project.last_activity_message = "Сценарист больше не работает в студии."
		return {"advanced": false, "completed": false, "interrupted": false}

	if str(writer.work_state) != "working":
		project.last_activity_message = _get_non_working_message(
			str(writer.work_state)
		)
		return {"advanced": false, "completed": false, "interrupted": false}

	if not is_at_workplace:
		project.last_activity_message = "Сценарист направляется в сценарный отдел."
		return {"advanced": false, "completed": false, "interrupted": false}

	if project.interruption_minutes_remaining > 0:
		project.interruption_minutes_remaining -= 1
		project.last_activity_message = project.interruption_message
		writer.current_task = project.interruption_message
		return {
			"advanced": false,
			"completed": false,
			"interrupted": true,
		}

	var needs: Dictionary = writer.needs
	var energy: float = float(needs.get("energy", 1.0))
	var stress: float = float(needs.get("stress", 0.0))
	if energy <= 0.2:
		project.last_activity_message = "Сценарист слишком устал и восстанавливает силы."
		return {"advanced": false, "completed": false, "interrupted": false}

	_rng.state = project.rng_state
	var interruption_chance: float = (
		BASE_INTERRUPTION_CHANCE + clampf(stress, 0.0, 1.0) * 0.0015
	)
	if _rng.randf() < interruption_chance:
		var interruption_duration: int = _rng.randi_range(10, 35)
		var interruption_message: String = INTERRUPTION_MESSAGES[
			_rng.randi_range(0, INTERRUPTION_MESSAGES.size() - 1)
		]
		apply_interruption(
			project,
			interruption_duration,
			interruption_message
		)
		project.rng_state = _rng.state
		writer.current_task = project.interruption_message
		return {
			"advanced": false,
			"completed": false,
			"interrupted": true,
		}

	project.rng_state = _rng.state
	project.completed_work_minutes += 1
	var genre_title: String = SCRIPT_GENERATOR_SCRIPT.get_genre_title(
		str(project.genre_id)
	)
	project.last_activity_message = "Пишет сценарий «%s»" % genre_title
	writer.current_task = "Пишет сценарий «%s»" % genre_title

	if project.completed_work_minutes < project.required_work_minutes:
		return {"advanced": true, "completed": false, "interrupted": false}

	var completed_script: Variant = _script_generator.call(
		"generate",
		writer,
		str(project.genre_id),
		int(project.scene_count),
		int(project.role_count),
		int(project.seed),
		str(project.script_id)
	)
	if completed_script == null:
		project.status = "failed"
		project.last_activity_message = "Не удалось сформировать итоговый сценарий."
		return {
			"advanced": true,
			"completed": false,
			"interrupted": false,
			"failed": true,
		}

	project.status = "completed"
	project.last_activity_message = "Сценарий завершён и готов к производству."
	writer.current_task = "Завершил сценарий «%s»" % str(
		completed_script.title
	)
	return {
		"advanced": true,
		"completed": true,
		"interrupted": false,
		"script": completed_script,
	}


func apply_interruption(
	project: Variant,
	duration_minutes: int,
	message: String
) -> bool:
	if project == null or str(project.status) != "in_progress":
		return false

	project.interruption_minutes_remaining = clampi(
		duration_minutes,
		1,
		240
	)
	project.interruption_count += 1
	project.interruption_message = message
	project.last_activity_message = message
	return true


func _get_non_working_message(work_state: String) -> String:
	match work_state:
		"break":
			return "Сценарист на обеденном перерыве."
		"resting":
			return "Сценарист восстанавливает силы."
		"off_duty":
			return "Ожидает следующей рабочей смены."
		_:
			return "Ожидает начала работы."
