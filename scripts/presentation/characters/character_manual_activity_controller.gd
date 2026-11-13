extends RefCounted
class_name CharacterManualActivityController

const POLICY_SCRIPT = preload(
	"res://scripts/domain/characters/character_manual_activity_policy.gd"
)
const BUILDING_CATALOG = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

const MAX_TRAVEL_WAIT_MINUTES: int = 180

var _characters: Node
var _buildings: Node
var _clock: Node
var _skill_progression: RefCounted
var _policy: RefCounted
var _orders: Dictionary = {}
var _last_message: String = ""


func setup(
	characters: Node,
	clock: Node,
	skill_progression: RefCounted
) -> void:
	_characters = characters
	_clock = clock
	_skill_progression = skill_progression
	_policy = POLICY_SCRIPT.new()


func set_building_manager(manager: Node) -> void:
	_buildings = manager


func get_order(employee_id: String) -> Dictionary:
	return _orders.get(employee_id, {}).duplicate(true)


func has_order(employee_id: String) -> bool:
	return _orders.has(employee_id)


func get_last_message() -> String:
	return _last_message


func preview(employee_id: String, building_id: String) -> Dictionary:
	if not is_instance_valid(_characters) or not is_instance_valid(_buildings):
		return _reject("Навигация ещё не инициализирована.")
	var employee: Variant = _find_employee(employee_id)
	if employee == null:
		return _reject("Сотрудник не найден.")
	var actor: Node3D = _characters.call("get_employee_actor", employee_id) as Node3D
	if not is_instance_valid(actor):
		return _reject("Персонаж недоступен.")
	var building: Variant = _buildings.call("get_building_by_id", building_id)
	if building == null or not bool(building.is_operational):
		return _reject("Здание недоступно.")
	var building_type: String = str(building.building_type_id)
	var activity: Dictionary = _policy.call(
		"get_activity", building_type, str(employee.profession_id)
	)
	if activity.is_empty():
		return _reject("Для профессии нет подходящего занятия в этом здании.")
	for blocking_method in [
		"is_employee_in_active_production",
		"is_employee_in_active_editing",
		"is_employee_in_publicity_event",
	]:
		if (
			_buildings.has_method(blocking_method)
			and bool(_buildings.call(blocking_method, employee_id))
		):
			return _reject("Сотрудник занят в производстве или публичном мероприятии.")
	if (
		bool(actor.call("is_in_scene_performance"))
		and not _orders.has(employee_id)
	):
		return _reject("Нельзя прервать выполняемую сцену или поручение.")
	if building_type in ["sound_stage", "tv_studio"]:
		if (
			building_type == "sound_stage"
			and _buildings.has_method("get_active_film_project")
		):
			var film: Variant = _buildings.call("get_active_film_project")
			if film != null and str(film.status) == "in_production":
				return _reject("Павильон занят текущим фильмом.")
		if (
			building_type == "tv_studio"
			and _buildings.has_method("get_tv_guest_show_controller")
		):
			var controller: RefCounted = _buildings.call(
				"get_tv_guest_show_controller"
			)
			if controller != null:
				var system: RefCounted = controller.call("get_tv_system")
				if system.call("get_active_episode") != null:
					return _reject("В ТВ-павильоне идёт запись.")
	var capacity: int = BUILDING_CATALOG.get_facility_capacity(building_type)
	if capacity <= 0:
		capacity = BUILDING_CATALOG.get_workplace_capacity_for_building(building)
	if capacity <= 0:
		# The prop warehouse has storage markers rather than employee seats.
		capacity = 3 if building_type == "prop_warehouse" else 0
	if capacity <= 0:
		return _reject("Нет подходящих мест для временного занятия.")
	var slot: int = _find_free_slot(building_id, capacity, employee_id)
	if slot < 0:
		return _reject("Все места в здании заняты.")
	return {
		"success": true,
		"title": str(activity["title"]),
		"duration_minutes": int(activity["minutes"]),
		"slot_index": slot,
		"activity": activity,
		"building_type": building_type,
	}


func request(employee_id: String, building_id: String) -> Dictionary:
	var valid: Dictionary = preview(employee_id, building_id)
	if not bool(valid.get("success", false)):
		_last_message = str(valid.get("message", "Нельзя отправить персонажа."))
		return valid
	var actor: Node3D = _characters.call("get_employee_actor", employee_id) as Node3D
	var slot: int = int(valid["slot_index"])
	var route: Array[Vector3] = []
	if str(valid["building_type"]) == "prop_warehouse":
		var target: Vector3 = _buildings.call(
			"get_storage_mark", building_id, slot
		)
		route = _buildings.call(
			"get_scene_recovery_path", building_id,
			actor.global_position, target
		)
	else:
		route = _buildings.call(
			"get_workplace_path_from", building_id, slot, actor.global_position
		)
	if route.size() < 2:
		return _reject("Маршрут через вход здания недоступен.")
	var target_position: Vector3 = route.back()
	var focus: Vector3 = (
		_buildings.call("get_workplace_position", building_id, 0)
	)
	var activity: Dictionary = valid["activity"]
	# The same actor can be redirected between two temporary activities.
	# Only commit the replacement after the entire route was validated.
	_orders[employee_id] = {
		"building_id": building_id,
		"slot_index": slot,
		"activity": activity,
		"elapsed_minutes": 0,
		"travel_wait_minutes": 0,
		"arrived": false,
		"target_position": target_position,
	}
	actor.call(
		"start_scene_performance",
		target_position,
		focus,
		str(activity["action"]),
		"",
		route,
		true
	)
	var employee: Variant = _find_employee(employee_id)
	if employee != null:
		employee.current_task = "Идёт: %s" % str(activity["title"])
	if (
		is_instance_valid(_clock)
		and bool(_clock.is_manual_fast_forward)
	):
		actor.call("snap_to_scene_mark")
	_last_message = "%s: %s (%d игровых минут)." % [
		employee.get_full_name(), str(activity["title"]),
		int(activity["minutes"]),
	]
	return {
		"success": true,
		"message": _last_message,
		"activity": str(activity["title"]),
		"slot_index": slot,
	}


func advance_employee(employee: Variant, actor: Node3D) -> bool:
	var employee_id: String = str(employee.id)
	if not _orders.has(employee_id):
		return false
	if not is_instance_valid(actor):
		_orders.erase(employee_id)
		return false
	var order: Dictionary = _orders[employee_id]
	if (
		is_instance_valid(_clock)
		and bool(_clock.is_manual_fast_forward)
	):
		actor.call("snap_to_scene_mark")
	if not bool(actor.call("is_at_scene_mark")):
		order["travel_wait_minutes"] = int(order["travel_wait_minutes"]) + 1
		employee.current_task = "Идёт: %s" % str(order["activity"]["title"])
		if int(order["travel_wait_minutes"]) >= MAX_TRAVEL_WAIT_MINUTES:
			_finish_order(employee, actor)
		return true
	order["arrived"] = true
	var activity: Dictionary = order["activity"]
	if int(order["elapsed_minutes"]) >= int(activity["minutes"]):
		# A temporarily blocked journey home must not keep granting
		# training XP or wellness bonuses after the session has finished.
		_finish_order(employee, actor)
		return true
	_policy.call(
		"apply_minute", employee, activity, _skill_progression
	)
	order["elapsed_minutes"] = int(order["elapsed_minutes"]) + 1
	employee.current_task = "%s · %d/%d мин" % [
		str(activity["title"]),
		int(order["elapsed_minutes"]),
		int(activity["minutes"]),
	]
	if int(order["elapsed_minutes"]) >= int(activity["minutes"]):
		_finish_order(employee, actor)
	return true


func forget_employee(employee_id: String) -> void:
	_orders.erase(employee_id)


func _finish_order(employee: Variant, actor: Node3D) -> void:
	var employee_id: String = str(employee.id)
	if not _orders.has(employee_id):
		return
	var home_id: String = str(actor.call("get_workplace_building_id"))
	var slot_index: int = int(actor.get("_workplace_slot_index"))
	var return_route: Array[Vector3] = []
	if not home_id.is_empty():
		if slot_index >= 0:
			return_route = _buildings.call(
				"get_workplace_path_from",
				home_id,
				slot_index,
				actor.global_position
			)
		else:
			# Legacy workplaces may not have a slot index. Use the
			# precise old workplace mark, still routed through doors.
			return_route = _buildings.call(
				"get_scene_recovery_path",
				home_id, actor.global_position,
				actor.call("get_workplace_position")
			)
		if return_route.size() < 2:
			employee.current_task = "Ожидает маршрута домой"
			# Keep the order while routing is blocked; try again next minute.
			return
	actor.call("return_to_workplace", return_route)
	_orders.erase(employee_id)
	employee.current_task = (
		"Возвращается на рабочее место"
		if not home_id.is_empty()
		else "Свободное время"
	)
	if home_id.is_empty() and _characters.has_method("refresh_navigation_routes"):
		_characters.call("refresh_navigation_routes")


func _find_free_slot(
	building_id: String, capacity: int, employee_id: String
) -> int:
	var occupied: Dictionary = {}
	for other_id_value in _orders.keys():
		var other_id: String = str(other_id_value)
		if other_id == employee_id:
			continue
		var other: Dictionary = _orders[other_id]
		if str(other["building_id"]) == building_id:
			occupied[int(other["slot_index"])] = true
	if _characters.has_method("get_employees_using_facility"):
		for visitor in _characters.call("get_employees_using_facility", building_id):
			var visitor_actor: Node = _characters.call(
				"get_employee_actor", str(visitor.id)
			)
			if is_instance_valid(visitor_actor):
				occupied[int(visitor_actor.call("get_facility_slot_index"))] = true
	# Rehearsal must not be staged on top of an idle employee already
	# occupying their assigned workstation in the same pavilion.
	if _characters.has_method("get_employees_assigned_to_building"):
		for staff_member in _characters.call(
			"get_employees_assigned_to_building", building_id
		):
			if str(staff_member.id) == employee_id:
				continue
			var staff_actor: Node = _characters.call(
				"get_employee_actor", str(staff_member.id)
			)
			if (
				is_instance_valid(staff_actor)
				and bool(staff_actor.call("is_at_workplace"))
				and str(staff_actor.call("get_workplace_building_id")) == building_id
			):
				occupied[int(staff_actor.get("_workplace_slot_index"))] = true
	for index in range(capacity):
		if not occupied.has(index):
			return index
	return -1


func _find_employee(employee_id: String) -> Variant:
	for employee in _characters.call("get_employees"):
		if str(employee.id) == employee_id:
			return employee
	return null


func _reject(reason: String) -> Dictionary:
	return {"success": false, "message": reason}
