extends RefCounted
class_name FilmScenePerformanceController

var _manager: Node
var _character_manager: Node
var _film_production_system: RefCounted
var _game_clock: Node

var _active_scene_performer_ids: Array[String] = []
var _off_camera_employee_ids: Array[String] = []


func setup(
	manager: Node,
	character_manager: Node,
	film_production_system: RefCounted,
	game_clock: Node
) -> void:
	_manager = manager
	_character_manager = character_manager
	_film_production_system = film_production_system
	_game_clock = game_clock


func clear_active_scene_performers() -> void:
	_active_scene_performer_ids.clear()


func _find_employee(employee_id: String) -> Variant:
	if not is_instance_valid(_character_manager):
		return null
	var employees: Array = _character_manager.call("get_employees")
	for employee in employees:
		if str(employee.id) == employee_id:
			return employee
	return null


func _get_assigned_staff(building_id: String) -> Array:
	if not is_instance_valid(_manager):
		return []
	return _manager.call("get_assigned_staff_for_building", building_id)


func _get_sound_stage_building_id() -> String:
	if not is_instance_valid(_manager):
		return ""
	return str(_manager.call("get_preferred_stage_building_id"))


func pause_for_off_hours(stage_id: String) -> void:
	if stage_id.is_empty():
		return
	for employee_id in _active_scene_performer_ids:
		var actor: Variant = _character_manager.call("get_employee_actor", employee_id)
		if (
			actor == null
			or not is_instance_valid(actor)
			or not bool(actor.call("is_in_scene_performance"))
			or bool(actor.call("is_returning_to_workplace"))
		):
			continue
		var return_path: Array[Vector3] = _manager.call("get_scene_path",
			stage_id,
			actor.global_position,
			actor.call("get_workplace_position")
		)
		if not return_path.is_empty():
			actor.call("return_to_workplace", return_path)
	_active_scene_performer_ids.clear()
	restore_off_camera_staff(stage_id)
	_manager.call("set_stage_camera_target", stage_id, Vector3.ZERO, false)

func sync_scene_performance(project: Variant, script: Variant) -> bool:
	if (
		project == null
		or str(project.status) != "in_production"
		or script == null
	):
		var idle_stage_id: String = _get_sound_stage_building_id()
		if not idle_stage_id.is_empty():
			_manager.call("set_stage_camera_target", idle_stage_id, Vector3.ZERO, false)
			restore_off_camera_staff(idle_stage_id)
		for employee_id in _active_scene_performer_ids:
			var actor: Variant = _character_manager.call(
				"get_employee_actor",
				employee_id
			)
			if actor != null and is_instance_valid(actor):
				var return_path: Array[Vector3] = []
				if not idle_stage_id.is_empty():
					return_path = _manager.call("get_scene_path",
						idle_stage_id,
						actor.global_position,
						actor.call("get_workplace_position")
					)
				if not return_path.is_empty():
					actor.call("return_to_workplace", return_path)
		_active_scene_performer_ids.clear()
		return false

	var stage_id: String = _get_sound_stage_building_id()
	if stage_id.is_empty():
		return false

	var current_phase: String = str(project.current_phase)
	if current_phase in ["preparation", "set_dressing", "set_strike"]:
		restore_off_camera_staff(stage_id)
		release_cast_for_scene_preparation(project, stage_id, current_phase)
		_manager.call("set_stage_camera_target",
			stage_id,
			_manager.call("get_scene_focus_point", stage_id),
			false
		)
		return true

	var performer_ids: Array = _film_production_system.call(
		"get_scene_performer_ids",
		script,
		project
	)
	var scene: Dictionary = _film_production_system.call(
		"get_current_scene",
		script,
		project
	)
	var marks: Array[Vector3] = []
	for mark_index in range(performer_ids.size()):
		marks.append(
			_manager.call("get_scene_mark",
				stage_id,
				mark_index,
				str(project.current_phase),
				int(project.current_scene_index)
			)
		)

	var focus_point: Vector3 = _manager.call("get_scene_focus_point", stage_id)
	var camera_target: Vector3 = focus_point
	if not marks.is_empty():
		camera_target = Vector3.ZERO
		for mark in marks:
			camera_target += mark
		camera_target /= float(marks.size())
		camera_target.y += 1.2
	var camera_active: bool = (
		str(project.current_phase) == "rehearsal"
		or str(project.current_phase) == "shooting"
		or str(project.current_phase) == "review"
	)
	_manager.call("set_stage_camera_target", stage_id, camera_target, camera_active)
	var new_active_ids: Array[String] = []
	var all_at_marks: bool = not performer_ids.is_empty()
	for performer_index in range(performer_ids.size()):
		var employee_id: String = str(performer_ids[performer_index])
		var employee: Variant = _find_employee(employee_id)
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if (
			employee == null
			or actor == null
			or not bool(
				_character_manager.call(
					"is_employee_assigned_to_building",
					employee_id,
					"sound_stage"
				)
			)
		):
			all_at_marks = false
			continue

		var already_performing: bool = bool(
			actor.call("is_in_scene_performance")
		)
		var at_workplace: bool = false
		if not already_performing:
			at_workplace = bool(
				_character_manager.call(
					"dispatch_employee_to_workplace",
					employee_id
				)
			)
		if not already_performing and not at_workplace:
			all_at_marks = false
			continue

		var actor_focus: Vector3 = focus_point
		if performer_ids.size() > 1:
			var focus_total: Vector3 = Vector3.ZERO
			var focus_count: int = 0
			for other_index in range(marks.size()):
				if other_index == performer_index:
					continue
				focus_total += marks[other_index]
				focus_count += 1
			if focus_count > 0:
				actor_focus = focus_total / float(focus_count)

		var dialogue_text: String = ""
		if str(project.current_phase) == "shooting":
			dialogue_text = str(
				_film_production_system.call(
					"get_scene_dialogue_for_employee",
					script,
					project,
					employee_id
				)
			)
		var action_id: String = get_scene_actor_action(
			str(project.current_phase),
			scene,
			not dialogue_text.is_empty()
		)
		var movement_path: Array[Vector3] = _manager.call("get_scene_path",
			stage_id,
			actor.global_position,
			marks[performer_index]
		)
		if movement_path.is_empty():
			all_at_marks = false
			continue
		actor.call(
			"start_scene_performance",
			marks[performer_index],
			actor_focus,
			action_id,
			dialogue_text,
			movement_path
		)
		_character_manager.call(
			"set_employee_task",
			employee_id,
			get_cast_production_task(
				str(project.current_phase),
				int(project.current_scene_index) + 1
			)
		)
		if _game_clock.is_manual_fast_forward:
			actor.call("snap_to_scene_mark")
		if not bool(actor.call("is_at_scene_mark")):
			all_at_marks = false
		new_active_ids.append(employee_id)

	for previous_id in _active_scene_performer_ids:
		if new_active_ids.has(previous_id):
			continue
		var previous_employee: Variant = _find_employee(previous_id)
		var previous_actor: Variant = _character_manager.call(
			"get_employee_actor",
			previous_id
		)
		if (
			previous_employee != null
			and previous_actor != null
			and is_instance_valid(previous_actor)
		):
			_character_manager.call(
				"set_employee_task",
				previous_id,
				"Участвует в съёмках фильма"
			)
			var previous_return_path: Array[Vector3] = _manager.call("get_scene_path",
				stage_id,
				previous_actor.global_position,
				previous_actor.call("get_workplace_position")
			)
			if not previous_return_path.is_empty():
				previous_actor.call("return_to_workplace", previous_return_path)

	_active_scene_performer_ids = new_active_ids
	var bystanders_ready: bool = move_stage_bystanders_off_camera(
		project,
		stage_id,
		performer_ids
	)
	return all_at_marks and bystanders_ready

func release_cast_for_scene_preparation(
	project: Variant,
	stage_id: String,
	phase: String
) -> void:
	if (
		project == null
		or not is_instance_valid(_character_manager)
	):
		return

	var scene_number: int = int(project.current_scene_index) + 1
	var processed_ids: Dictionary = {}
	var crew_ids: Array = project.crew_assignments.values()
	var cast_and_background_ids: Array[String] = []
	for assigned_id_value in project.cast_assignments.values():
		var employee_id: String = str(assigned_id_value)
		if not employee_id.is_empty() and not cast_and_background_ids.has(employee_id):
			cast_and_background_ids.append(employee_id)
	for background_employee_id in project.background_performer_ids:
		if not background_employee_id.is_empty() and not cast_and_background_ids.has(background_employee_id):
			cast_and_background_ids.append(background_employee_id)
	for employee_id in cast_and_background_ids:
		if employee_id.is_empty() or processed_ids.has(employee_id):
			continue
		processed_ids[employee_id] = true
		if crew_ids.has(employee_id):
			continue

		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if actor == null or not is_instance_valid(actor):
			continue

		if (
			bool(actor.call("is_returning_to_workplace"))
			or bool(actor.call("is_leaving_workplace"))
		):
			pass
		elif not str(actor.call("get_workplace_building_id")).is_empty():
			actor.call("leave_workplace")

		_character_manager.call(
			"set_employee_task",
			employee_id,
			get_cast_production_task(phase, scene_number)
		)

	_active_scene_performer_ids.clear()

func _should_move_stage_employee_off_camera(
	employee_id: String,
	performer_ids: Array,
	crew_ids: Array
) -> bool:
	return (
		not employee_id.is_empty()
		and not performer_ids.has(employee_id)
		and not crew_ids.has(employee_id)
	)

func move_stage_bystanders_off_camera(
	project: Variant,
	stage_id: String,
	performer_ids: Array
) -> bool:
	if not is_instance_valid(_character_manager):
		return false
	var all_clear: bool = true
	var current_off_camera_ids: Array[String] = []
	var hold_slot: int = 0
	var crew_ids: Array = project.crew_assignments.values()
	for employee in _get_assigned_staff(stage_id):
		var employee_id: String = str(employee.id)
		if not _should_move_stage_employee_off_camera(
			employee_id,
			performer_ids,
			crew_ids
		):
			continue
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if actor == null or not is_instance_valid(actor):
			continue
		if str(actor.call("get_workplace_building_id")) != stage_id:
			continue

		var hold_mark: Vector3 = _manager.call("get_scene_hold_mark", stage_id, hold_slot)
		hold_slot += 1
		current_off_camera_ids.append(employee_id)
		var already_at_mark: bool = (
			bool(actor.call("is_at_scene_hold_mark"))
			and actor.global_position.distance_to(hold_mark) <= 0.25
		)
		if not already_at_mark and not bool(actor.call("is_off_camera")):
			var movement_path: Array[Vector3] = _manager.call("get_scene_path",
				stage_id,
				actor.global_position,
				hold_mark
			)
			if movement_path.is_empty():
				all_clear = false
				continue
			actor.call("move_to_scene_hold", hold_mark, movement_path)
			_character_manager.call(
				"set_employee_task",
				employee_id,
				"Уходит за кадр перед съёмкой"
			)

		if _game_clock.is_manual_fast_forward:
			actor.call("snap_to_scene_hold_mark")
		if not bool(actor.call("is_at_scene_hold_mark")):
			all_clear = false
		else:
			_character_manager.call(
				"set_employee_task",
				employee_id,
				"За кадром во время съёмки"
			)

	for previous_id in _off_camera_employee_ids:
		if current_off_camera_ids.has(previous_id):
			continue
		var previous_actor: Variant = _character_manager.call(
			"get_employee_actor",
			previous_id
		)
		if (
			previous_actor == null
			or not is_instance_valid(previous_actor)
			or not bool(previous_actor.call("is_off_camera"))
		):
			continue
		if str(previous_actor.call("get_workplace_building_id")) != stage_id:
			previous_actor.call("leave_workplace")
		else:
			var return_path: Array[Vector3] = _manager.call("get_scene_path",
				stage_id,
				previous_actor.global_position,
				previous_actor.call("get_workplace_position")
			)
			if return_path.is_empty():
				previous_actor.call("leave_workplace")
			else:
				previous_actor.call("return_to_workplace", return_path)
		_character_manager.call("clear_employee_task", previous_id)

	_off_camera_employee_ids = current_off_camera_ids
	return all_clear

func restore_off_camera_staff(stage_id: String) -> void:
	if _off_camera_employee_ids.is_empty():
		return
	if not is_instance_valid(_character_manager):
		_off_camera_employee_ids.clear()
		return
	for employee_id in _off_camera_employee_ids:
		var actor: Variant = _character_manager.call(
			"get_employee_actor",
			employee_id
		)
		if (
			actor == null
			or not is_instance_valid(actor)
			or not bool(actor.call("is_off_camera"))
		):
			continue
		if str(actor.call("get_workplace_building_id")) != stage_id:
			actor.call("leave_workplace")
		else:
			var return_path: Array[Vector3] = _manager.call("get_scene_path",
				stage_id,
				actor.global_position,
				actor.call("get_workplace_position")
			)
			if return_path.is_empty():
				actor.call("leave_workplace")
			else:
				actor.call("return_to_workplace", return_path)
		_character_manager.call("clear_employee_task", employee_id)
	_off_camera_employee_ids.clear()

func is_employee_off_camera(employee_id: String) -> bool:
	if not is_instance_valid(_character_manager):
		return false
	var actor: Node = _character_manager.call(
		"get_employee_actor",
		employee_id
	)
	if actor == null or not actor.has_method("is_off_camera"):
		return false
	return bool(actor.call("is_off_camera"))

func get_cast_production_task(phase: String, scene_number: int) -> String:
	match phase:
		"preparation":
			return "Гуляет по студии, пока готовят сцену %d" % scene_number
		"set_dressing":
			return "Гуляет по студии, пока монтируют декорации сцены %d" % scene_number
		"set_strike":
			return "Отдыхает, пока техники убирают декорации сцены %d" % scene_number
		"rehearsal":
			return "Репетирует сцену %d" % scene_number
		"shooting":
			return "Снимается в сцене %d" % scene_number
		"review":
			return "Ожидает просмотра сцены %d" % scene_number
		_:
			return "Участвует в съёмках фильма"

func get_scene_actor_action(
	phase: String,
	scene: Dictionary,
	is_speaker: bool
) -> String:
	match phase:
		"preparation":
			return "rehearsing"
		"set_dressing":
			return "waiting"
		"rehearsal":
			return "rehearsing"
		"review":
			return "reviewing"
		"shooting":
			if is_speaker:
				return "speaking"
			var beat: String = str(scene.get("beat", ""))
			var action_text: String = str(scene.get("action", "")).to_lower()
			if (
				beat.contains("Кульминация")
				or beat.contains("Поворот")
				or action_text.contains("противостоя")
				or action_text.contains("спор")
				or action_text.contains("обвин")
			):
				return "dramatic"
			if (
				action_text.contains("обнаруж")
				or action_text.contains("наход")
				or action_text.contains("улику")
				or action_text.contains("карту")
			):
				return "pointing"
			if (
				action_text.contains("встреч")
				or action_text.contains("возвращ")
				or action_text.contains("привет")
			):
				return "greeting"
			if (
				action_text.contains("ищ")
				or action_text.contains("след")
				or action_text.contains("исслед")
			):
				return "searching"
			return "reacting"
		_:
			return "rehearsing"
