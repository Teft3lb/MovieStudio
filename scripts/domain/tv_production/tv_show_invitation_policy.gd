extends RefCounted
class_name TVShowInvitationPolicy

# Recognition is persistent and distinct from popularity. TV invitations
# unlock for known actors and film directors; no new employee is required.
const MIN_RECOGNITION: float = 70.0
const GUEST_PROFESSIONS: Array[String] = ["actor", "director"]
const EXTERNAL_HOSTS: Array[Dictionary] = [
	{
		"id": "EXT-TV-HOST-MERCER",
		"name": "Oliver Mercer",
		"first_name": "Oliver",
		"last_name": "Mercer",
		"hosting": 82.0,
		"popularity": 78.0,
	},
	{
		"id": "EXT-TV-HOST-VALE",
		"name": "Charlotte Vale",
		"first_name": "Charlotte",
		"last_name": "Vale",
		"hosting": 91.0,
		"popularity": 85.0,
	},
	{
		"id": "EXT-TV-HOST-HALE",
		"name": "Benjamin Hale",
		"first_name": "Benjamin",
		"last_name": "Hale",
		"hosting": 74.0,
		"popularity": 65.0,
	},
]


func is_eligible_guest(employee: Variant) -> bool:
	if employee == null:
		return false
	return (
		str(employee.profession_id) in GUEST_PROFESSIONS
		and float(employee.recognition) >= MIN_RECOGNITION
	)


func get_guest_blocker(employee: Variant) -> String:
	if employee == null:
		return "Сотрудник не найден."
	if str(employee.profession_id) not in GUEST_PROFESSIONS:
		return "В ток-шоу можно пригласить актёра или режиссёра."
	if float(employee.recognition) < MIN_RECOGNITION:
		return "Нужна известность 70%%. Сейчас %.0f%%." % float(
			employee.recognition
		)
	return ""


func get_host_profile(host_id: String) -> Dictionary:
	for host in EXTERNAL_HOSTS:
		if str(host.get("id", "")) == host_id:
			return host.duplicate(true)
	return {}


func get_invitation_candidates(employees: Array) -> Array:
	var result: Array = []
	for employee in employees:
		if is_eligible_guest(employee):
			result.append(employee)
	result.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float(a.recognition) > float(b.recognition)
	)
	return result


func choose_crew(employees: Array, guest_id: String, unavailable_ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for role_id in ["director", "camera_operator", "technician"]:
		for employee in employees:
			var employee_id: String = str(employee.id)
			if (
				str(employee.profession_id) != role_id
				or employee_id == guest_id
				or unavailable_ids.has(employee_id)
				or result.values().has(employee_id)
			):
				continue
			result[role_id] = employee_id
			break
	return result


func allow_guest_director(crew: Dictionary, guest: Variant) -> Dictionary:
	var assignments: Dictionary = crew.duplicate(true)
	if (
		guest != null
		and str(guest.profession_id) == "director"
		and str(assignments.get("director", "")).is_empty()
	):
		# A director guest may also coordinate the interview when the
		# studio does not have a second director. This does not add staff.
		assignments["director"] = str(guest.id)
	return assignments


func has_complete_crew(crew_assignments: Dictionary) -> bool:
	for role_id in ["director", "camera_operator", "technician"]:
		if str(crew_assignments.get(role_id, "")).is_empty():
			return false
	return true
