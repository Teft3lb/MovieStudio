extends RefCounted
class_name StudioPublicityEventController

const PUBLICITY_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/celebrity_publicity_system.gd"
)
const PUBLICITY_CROWD_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_publicity_crowd.gd"
)

var _manager: Node3D
var _characters: Node
var _clock: Node
var _publicity: RefCounted
var _active: Dictionary = {}
var _star_actor: Node3D
var _guard_actors: Dictionary = {}
var _previous_tasks: Dictionary = {}
var _crowd: Node3D
var _event_site: Vector3
var _door_position: Vector3
var _last_result: Dictionary = {}
var _last_status: String = ""


func setup(manager: Node3D, characters: Node, clock: Node) -> void:
	_manager = manager
	_characters = characters
	_clock = clock
	_publicity = PUBLICITY_SYSTEM_SCRIPT.new()


func request_event(employee_id: String, event_id: String) -> Dictionary:
	if not _active.is_empty():
		return _fail("На студии уже проходит публичное мероприятие.")
	if not is_instance_valid(_manager) or not is_instance_valid(_characters):
		return _fail("Система мероприятий ещё не подключена.")
	var employee: Variant = _get_employee(employee_id)
	var blocker: String = _publicity.call(
		"get_blocker", employee, event_id, int(_clock.current_day)
	)
	if not blocker.is_empty():
		return _fail(blocker)
	if (
		bool(_manager.call("is_employee_in_active_production", employee_id))
		or bool(_manager.call("is_employee_in_active_editing", employee_id))
	):
		return _fail("Сейчас артист занят на съёмках или монтаже.")
	var actor: Node3D = _characters.call("get_employee_actor", employee_id) as Node3D
	if not is_instance_valid(actor):
		return _fail("3D-персонаж артиста не найден.")
	var location: Dictionary = _find_outdoor_site()
	if location.is_empty():
		return _fail("Нужен действующий павильон с доступным выходом во двор.")
	var site: Vector3 = location["site"]
	var door: Vector3 = location["door"]
	var route: Array[Vector3] = _manager.call(
		"get_scene_recovery_path", "",
		actor.global_position, site
	)
	if route.size() < 2:
		return _fail("Невозможно проложить безопасный маршрут к встрече.")
	var event: Dictionary = _publicity.call(
		"create_event", employee, event_id, int(_clock.current_day)
	)
	if not bool(event.get("success", false)):
		return event
	_active = event
	_event_site = site
	_door_position = door
	_star_actor = actor
	_previous_tasks[employee_id] = str(employee.current_task)
	employee.current_task = "Идёт на публичное мероприятие"
	_star_actor.call(
		"start_scene_performance", site, door, "greeting", "",
		route, true
	)
	_assign_available_guards(employee_id)
	_crowd = PUBLICITY_CROWD_SCRIPT.new()
	_manager.add_child(_crowd)
	_crowd.call(
		"setup", _clock, event_id, door, site,
		int(event["visitor_count"])
	)
	_last_status = (
		"%s: приглашено %d посетителей, сопровождают %d охранников."
		% [
			_publicity.call("get_event_title", event_id),
			int(event["visitor_count"]),
			_guard_actors.size(),
		]
	)
	return {
		"success": true,
		"message": _last_status,
		"visitor_count": int(event["visitor_count"]),
		"guards_assigned": _guard_actors.size(),
	}


func advance_minute(_day: int, _hour: int, _minute: int) -> void:
	if _active.is_empty():
		return
	if not is_instance_valid(_star_actor):
		_abort_event("Артист покинул территорию.")
		return
	if bool(_clock.is_manual_fast_forward):
		_star_actor.call("snap_to_scene_mark")
		for guard in _guard_actors.values():
			if is_instance_valid(guard):
				guard.call("snap_to_scene_mark")
		if is_instance_valid(_crowd):
			_crowd.call("finish_manual_fast_forward")
	if not bool(_star_actor.call("is_at_scene_mark")):
		_last_status = "Ожидание артиста на площадке встречи."
		return
	if is_instance_valid(_crowd) and not bool(_crowd.call("has_arrived")):
		_last_status = "Поклонники подходят к месту встречи."
		return
	var employee_id: String = str(_active["employee_id"])
	var employee: Variant = _get_employee(employee_id)
	if employee == null:
		_abort_event("Артист больше не числится в студии.")
		return
	var guard_skills: Array[float] = []
	for id in _guard_actors.keys():
		var guard: Node3D = _guard_actors[id] as Node3D
		if (
			not is_instance_valid(guard)
			or not bool(guard.call("is_at_scene_mark"))
			or guard.global_position.distance_to(_event_site) > 8.0
		):
			continue
		var guard_employee: Variant = _get_employee(str(id))
		if guard_employee != null:
			guard_skills.append(float(guard_employee.skills.get("security", 0.0)))
	var update: Dictionary = _publicity.call(
		"advance_event", _active, employee, guard_skills
	)
	employee.current_task = (
		"%s · %d/%d мин" % [
			_publicity.call("get_event_title", str(_active["event_id"])),
			int(_active["elapsed_minutes"]),
			int(_active["duration_minutes"]),
		]
	)
	if bool(update.get("completed", false)):
		_last_result = update.duplicate(true)
		_last_status = (
			"%s завершена. Известность %+.1f, популярность %+.1f, "
			+ "стресс +%.1f%%; охрана: %d."
		) % [
			_publicity.call("get_event_title", str(_active["event_id"])),
			float(update["fame_delta"]),
			float(update["popularity_delta"]),
			float(update["stress_delta"]) * 100.0,
			int(update["guards_present"]),
		]
		_finish_event()
	else:
		_last_status = (
			"%s: %d/%d мин · охрана на месте: %d"
			% [
				_publicity.call("get_event_title", str(_active["event_id"])),
				int(_active["elapsed_minutes"]),
				int(_active["duration_minutes"]),
				guard_skills.size(),
			]
		)


func is_participant(employee_id: String) -> bool:
	return (
		not _active.is_empty()
		and (
			str(_active["employee_id"]) == employee_id
			or _guard_actors.has(employee_id)
		)
	)


func get_status() -> String:
	return _last_status


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func get_active_event() -> Dictionary:
	return _active.duplicate(true)


func _assign_available_guards(celebrity_id: String) -> void:
	var side: Vector3 = _door_position - _event_site
	side.y = 0.0
	if side.length_squared() < 0.01:
		side = Vector3.FORWARD
	side = Vector3(-side.z, 0.0, side.x).normalized()
	var guard_number: int = 0
	for guard in _characters.call("get_employees"):
		var id: String = str(guard.id)
		if (
			str(guard.profession_id) != "security_guard"
			or id == celebrity_id
			or bool(_manager.call("is_employee_in_active_production", id))
			or bool(_manager.call("is_employee_in_active_editing", id))
		):
			continue
		var actor: Node3D = _characters.call("get_employee_actor", id) as Node3D
		if not is_instance_valid(actor):
			continue
		var guard_mark: Vector3 = (
			_event_site + side * (2.1 if guard_number % 2 == 0 else -2.1)
			+ (_door_position - _event_site).normalized() * 0.7
		)
		var path: Array[Vector3] = _manager.call(
			"get_scene_recovery_path", "", actor.global_position, guard_mark
		)
		if path.size() < 2:
			continue
		_previous_tasks[id] = str(guard.current_task)
		guard.current_task = "Обеспечивает безопасность встречи"
		actor.call(
			"start_scene_performance", guard_mark, _event_site,
			"waiting", "", path, true
		)
		_guard_actors[id] = actor
		guard_number += 1
		if guard_number >= 5:
			break


func _find_outdoor_site() -> Dictionary:
	for building in _manager.call("get_buildings"):
		if (
			not bool(building.is_operational)
			or str(building.building_type_id)
				not in ["sound_stage", "tv_studio", "script_department"]
		):
			continue
		var building_route: Array[Vector3] = _manager.call(
			"get_workplace_path", str(building.id), 0
		)
		if building_route.size() < 2:
			continue
		var door: Vector3 = building_route.front()
		var away: Vector3 = door - building_route[1]
		away.y = 0.0
		if away.length_squared() <= 0.01:
			continue
		away = away.normalized()
		var desired: Vector3 = door + away * 5.0
		var base: Array[Vector3] = [
			desired, desired + away * 0.5
		]
		var exterior_path: Array[Vector3] = _manager.call(
			"get_roaming_route", door, base
		)
		if exterior_path.size() < 3:
			continue
		var site: Vector3 = exterior_path[exterior_path.size() - 2]
		if site.distance_to(door) < 2.0:
			continue
		return {"site": site, "door": door}
	return {}


func _finish_event() -> void:
	for id in _previous_tasks.keys():
		var employee: Variant = _get_employee(str(id))
		if employee != null:
			employee.current_task = str(_previous_tasks[id])
	if is_instance_valid(_star_actor):
		_return_actor(_star_actor)
	for actor_value in _guard_actors.values():
		var guard: Node3D = actor_value as Node3D
		if is_instance_valid(guard):
			_return_actor(guard)
	if is_instance_valid(_crowd):
		_crowd.call("begin_departure")
		if bool(_clock.is_manual_fast_forward):
			_crowd.call("finish_manual_fast_forward")
	_active.clear()
	_guard_actors.clear()
	_previous_tasks.clear()
	_star_actor = null


func _abort_event(message: String) -> void:
	_last_status = message
	_finish_event()


func _return_actor(actor: Node3D) -> void:
	var home_id: String = str(actor.call("get_workplace_building_id"))
	var slot: int = int(actor.get("_workplace_slot_index"))
	if not home_id.is_empty():
		var route: Array[Vector3] = _manager.call(
			"get_workplace_path_from",
			home_id, maxi(slot, 0), actor.global_position
		)
		if route.size() >= 2:
			actor.call("return_to_workplace", route)
			return
	actor.call("return_to_workplace")


func _get_employee(employee_id: String) -> Variant:
	for employee in _characters.call("get_employees"):
		if str(employee.id) == employee_id:
			return employee
	return null


func _fail(message: String) -> Dictionary:
	_last_status = message
	return {"success": false, "message": message}
