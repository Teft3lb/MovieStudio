extends RefCounted
class_name TVGuestShowController

const TV_PRODUCTION_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_production_system.gd"
)
const INVITATION_POLICY_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_show_invitation_policy.gd"
)
const VISITING_HOST_SCRIPT = preload(
	"res://scripts/presentation/studio/tv_guest_host_visitor.gd"
)
const TV_SHOW_PANEL_SCRIPT = preload(
	"res://scripts/presentation/studio/tv_guest_show_panel.gd"
)

var _manager: Node3D
var _characters: Node
var _clock: Node
var _television: RefCounted
var _invitation_policy: RefCounted
var _active_stage_id: String = ""
var _active_guest_id: String = ""
var _active_host: Dictionary = {}
var _active_crew: Dictionary = {}
var _active_show_id: String = ""
var _guest_actor: Node3D
var _external_host: Node3D
var _guest_released: bool = false
var _next_show_number: int = 1
var _last_broadcast: Dictionary = {}
var _feedback: String = ""
var _view: RefCounted


func setup(manager: Node3D, characters: Node, clock: Node) -> void:
	_manager = manager
	_characters = characters
	_clock = clock
	_television = TV_PRODUCTION_SCRIPT.new()
	_television.call("initialize", 20261113)
	_invitation_policy = INVITATION_POLICY_SCRIPT.new()


func build_controls(layout: VBoxContainer, stage_id: String) -> void:
	_view = TV_SHOW_PANEL_SCRIPT.new()
	var candidates: Array = _invitation_policy.call(
		"get_invitation_candidates", _get_employees()
	)
	_view.call("build", layout, stage_id, self, candidates)
	_refresh_ui()


func request_invitation(stage_id: String, guest_id: String, host_id: String) -> void:
	var result: Dictionary = invite_host(stage_id, guest_id, host_id)
	_feedback = str(result.get("message", ""))
	_refresh_ui()


func invite_host(stage_id: String, guest_id: String, host_id: String) -> Dictionary:
	if _television.call("get_active_episode") != null:
		return _failure("Телевизионный выпуск уже снимается.")
	if is_instance_valid(_external_host):
		return _failure("Предыдущий ведущий ещё покидает территорию.")
	if _manager == null or not is_instance_valid(
		_manager.call("get_building_actor_by_id", stage_id)
	):
		return _failure("Постройте телевизионный павильон.")
	var guest: Variant = _find_employee(guest_id)
	var blocker: String = str(_invitation_policy.call("get_guest_blocker", guest))
	if not blocker.is_empty():
		return _failure(blocker)
	if _is_busy(guest_id):
		return _failure("Актёр или режиссёр занят другим производством.")
	var host: Dictionary = _invitation_policy.call("get_host_profile", host_id)
	if host.is_empty():
		return _failure("Выбранный ведущий недоступен.")
	var actor: Node3D = _characters.call("get_employee_actor", guest_id) as Node3D
	if actor == null or not bool(actor.get("_has_workplace_destination")):
		return _failure("Гость должен иметь назначенное рабочее место.")
	var unavailable_ids: Array[String] = _get_busy_employee_ids()
	var tv_staff: Array = _characters.call(
		"get_employees_assigned_to_building", stage_id
	)
	var crew: Dictionary = _invitation_policy.call(
		"choose_crew", tv_staff, guest_id, unavailable_ids
	)
	if not bool(_invitation_policy.call("has_complete_crew", crew)):
		return _failure(
			"Назначьте в ТВ-павильон режиссёра, оператора и техника "
			+ "(без приглашённого гостя). Штат расширять не нужно."
		)
	var host_route: Array[Vector3] = _manager.call(
		"get_workplace_path", stage_id, 0
	)
	# The TV furniture sits directly on workplace slot 1. Target an open
	# standing mark in front of the guest chair, never its collision shape.
	var tv_actor: Node3D = _manager.call(
		"get_building_actor_by_id", stage_id
	) as Node3D
	var guest_mark: Vector3 = tv_actor.to_global(
		Vector3(-2.3, 0.0, 0.95)
	)
	var guest_route: Array[Vector3] = _manager.call(
		"get_scene_recovery_path",
		str(actor.call("get_workplace_building_id")),
		actor.global_position, guest_mark
	)
	if host_route.size() < 2 or guest_route.size() < 2:
		return _failure("Нет маршрута к телевизионной площадке.")
	var hour: int = int(_clock.current_hour)
	var minute: int = int(_clock.current_minute)
	if hour * 60 + minute + 60 > 1440:
		return _failure("Для записи нужен час до полуночи. Пригласите ведущего утром.")
	var show_id: String = "TV-VISIT-%04d" % _next_show_number
	var guest_pool: Array[String] = [guest_id]
	var show_result: Dictionary = _television.call(
		"create_talk_show", show_id,
		"Разговор с %s" % guest.get_full_name(),
		"interview", host_id, guest_pool, crew, 30,
		int(_clock.current_day)
	)
	if not bool(show_result.get("success", false)):
		return show_result
	var schedule_result: Dictionary = _television.call(
		"schedule_talk_show", show_id,
		posmod(int(_clock.current_day) - 1, 7),
		hour, minute, 60
	)
	if not bool(schedule_result.get("success", false)):
		return schedule_result
	var schedule: Variant = schedule_result.get("schedule")
	_television.call(
		"collect_due_schedule_entries",
		int(_clock.current_day), hour, minute
	)
	var guests: Array[String] = [guest_id]
	var started: Dictionary = _television.call(
		"start_scheduled_episode",
		str(schedule.id), int(_clock.current_day), hour, minute,
		guests, unavailable_ids
	)
	if not bool(started.get("success", false)):
		return started
	# This is a one-time invitation, not a permanent staff-hosted TV format.
	schedule.active = false
	_next_show_number += 1
	_active_stage_id = stage_id
	_active_guest_id = guest_id
	_active_host = host
	_active_crew = crew.duplicate(true)
	_active_show_id = show_id
	_guest_actor = actor
	_guest_released = false
	_external_host = VISITING_HOST_SCRIPT.new()
	_manager.add_child(_external_host)
	_external_host.call("setup", host, _clock, host_route)
	actor.call(
		"start_scene_performance", guest_mark,
		_manager.call("get_workplace_position", stage_id, 0),
		"waiting", "", guest_route
	)
	_feedback = "Ведущий %s приглашён. Идёт подготовка выпуска." % str(host.name)
	_refresh_ui()
	return {"success": true, "message": _feedback, "episode": started.get("episode")}


func advance_minute(day: int, _hour: int, _minute: int) -> void:
	_cleanup_departed_host()
	var episode: Variant = _television.call("get_active_episode")
	if episode == null:
		return
	var performers_needed: bool = str(episode.current_phase) != "postproduction"
	if performers_needed and (
		not is_instance_valid(_external_host)
		or not is_instance_valid(_guest_actor)
	):
		_feedback = "Телешоу остановлено: один из участников отсутствует."
		_refresh_ui()
		return
	if bool(_clock.is_manual_fast_forward) and performers_needed:
		_external_host.call("snap_to_mark")
		_guest_actor.call("snap_to_scene_mark")
	var crew_ready: bool = true
	for employee_id_value in _active_crew.values():
		var employee_id: String = str(employee_id_value)
		if _is_busy(employee_id):
			crew_ready = false
			break
		if not bool(_characters.call(
			"is_employee_at_workplace", employee_id, "tv_studio"
		)):
			_characters.call("dispatch_employee_to_workplace", employee_id)
			crew_ready = false
	var talent_ready: bool = not performers_needed
	if performers_needed:
		talent_ready = (
			bool(_external_host.call("has_arrived"))
			and bool(_guest_actor.call("is_at_scene_mark"))
			and not _is_busy(_active_guest_id)
		)
	var snapshot: Dictionary = _build_performance_snapshot()
	var result: Dictionary = _television.call(
		"advance_minute", crew_ready, talent_ready, snapshot
	)
	if str(episode.current_phase) == "shooting" and is_instance_valid(_guest_actor):
		_guest_actor.call(
			"start_scene_performance",
			_guest_actor.get("_scene_target_position"),
			_manager.call("get_workplace_position", _active_stage_id, 0),
			"speaking"
		)
	if str(episode.current_phase) == "postproduction" and not _guest_released:
		_release_guests()
	if bool(result.get("completed", false)):
		var broadcast: Dictionary = _television.call(
			"record_broadcast", "talk_show", _active_show_id,
			str(episode.id), _get_employees(), day
		)
		if bool(broadcast.get("success", false)):
			_last_broadcast = broadcast
			_feedback = (
				"%s: эфир состоялся. Рейтинг %.0f/100, зрителей: %d."
				% [
					str(episode.title),
					float(broadcast.get("audience_rating", 0.0)),
					int(broadcast.get("audience_reach", 0)),
				]
			)
		else:
			_feedback = str(broadcast.get("message", "Эфир не состоялся."))
		_active_guest_id = ""
		_active_show_id = ""
		_active_crew.clear()
	_refresh_ui()


func _release_guests() -> void:
	_guest_released = true
	if is_instance_valid(_external_host):
		var exit_path: Array[Vector3] = _manager.call(
			"get_exit_path_from", _active_stage_id,
			_external_host.global_position, 0
		)
		_external_host.call("depart", exit_path)
	if is_instance_valid(_guest_actor):
		var home_id: String = str(_guest_actor.call("get_workplace_building_id"))
		var home_slot: int = int(_guest_actor.get("_workplace_slot_index"))
		if not home_id.is_empty() and home_slot >= 0:
			var return_path: Array[Vector3] = _manager.call(
				"get_workplace_path_from", home_id, home_slot,
				_guest_actor.global_position, _active_stage_id, 1
			)
			if return_path.size() >= 2:
				_guest_actor.call("return_to_workplace", return_path)
	_guest_actor = null


func _cleanup_departed_host() -> void:
	if is_instance_valid(_external_host):
		if bool(_external_host.call("has_departed")):
			_external_host.queue_free()
			_external_host = null


func _build_performance_snapshot() -> Dictionary:
	var guest: Variant = _find_employee(_active_guest_id)
	if guest == null:
		return {}
	var director: Variant = _find_employee(str(_active_crew.get("director", "")))
	var camera: Variant = _find_employee(str(_active_crew.get("camera_operator", "")))
	var technician: Variant = _find_employee(str(_active_crew.get("technician", "")))
	var guest_skills: Dictionary = guest.skills
	var director_skills: Dictionary = director.skills if director != null else {}
	var camera_skills: Dictionary = camera.skills if camera != null else {}
	var tech_skills: Dictionary = technician.skills if technician != null else {}
	return {
		"host_presence": float(_active_host.get("hosting", 60.0)),
		"improvisation": float(guest_skills.get("improvisation", 55.0)),
		"communication": float(guest_skills.get("communication", 55.0)),
		"directing": float(director_skills.get("directing", 55.0)),
		"camera_work": float(camera_skills.get("camera_work", 55.0)),
		"guest_performance": float(guest.recognition),
		"technical": float(tech_skills.get("technical", 55.0)),
		"energy": float(guest.needs.get("energy", 0.7)),
		"morale": float(guest.needs.get("morale", 0.7)),
		"stress": float(guest.needs.get("stress", 0.1)),
	}


func _get_employees() -> Array:
	if not is_instance_valid(_characters):
		return []
	return _characters.call("get_employees")


func _find_employee(employee_id: String) -> Variant:
	for employee in _get_employees():
		if str(employee.id) == employee_id:
			return employee
	return null


func _is_busy(employee_id: String) -> bool:
	return (
		bool(_manager.call("is_employee_in_active_production", employee_id))
		or bool(_manager.call("is_employee_in_active_editing", employee_id))
	)


func _get_busy_employee_ids() -> Array[String]:
	var busy_ids: Array[String] = []
	for employee in _get_employees():
		if _is_busy(str(employee.id)):
			busy_ids.append(str(employee.id))
	return busy_ids


func _refresh_ui() -> void:
	if _view == null:
		return
	_view.call(
		"refresh",
		_television.call("get_active_episode"),
		_feedback,
		is_instance_valid(_external_host)
	)


func get_last_broadcast() -> Dictionary:
	return _last_broadcast.duplicate(true)


func get_tv_system() -> RefCounted:
	return _television


func is_host_present() -> bool:
	return is_instance_valid(_external_host)


func _failure(reason: String) -> Dictionary:
	return {"success": false, "message": reason}
