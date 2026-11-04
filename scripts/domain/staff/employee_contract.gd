extends RefCounted
class_name EmployeeContract

const TYPE_PERMANENT: String = "permanent"
const TYPE_FIXED_30_DAYS: String = "fixed_30_days"
const TYPE_FIXED_90_DAYS: String = "fixed_90_days"

const CONTRACT_TYPES: Array[String] = [
	TYPE_PERMANENT,
	TYPE_FIXED_30_DAYS,
	TYPE_FIXED_90_DAYS,
]

var contract_id: String = ""
var employee_id: String = ""
var type_id: String = TYPE_PERMANENT
var daily_salary: int = 0
var start_day: int = 1
var term_days: int = 0
var end_day: int = 0
var status: String = "active"
var termination_day: int = 0


func get_type_title() -> String:
	match type_id:
		TYPE_PERMANENT:
			return "Бессрочный"
		TYPE_FIXED_30_DAYS:
			return "Срочный · 30 дней"
		TYPE_FIXED_90_DAYS:
			return "Срочный · 90 дней"
		_:
			return "Неизвестный тип"


func get_duration_title() -> String:
	if term_days <= 0:
		return "Без ограничения срока"
	return "%d дней · до конца дня %d" % [term_days, end_day]


func is_active_on_day(day: int) -> bool:
	if status != "active":
		return false
	return end_day == 0 or day <= end_day


func terminate(day: int) -> bool:
	if status != "active":
		return false
	status = "terminated"
	termination_day = maxi(day, start_day)
	return true


func expire(day: int) -> bool:
	if status != "active" or end_day <= 0 or day <= end_day:
		return false
	status = "expired"
	termination_day = day
	return true


func to_dict() -> Dictionary:
	return {
		"contract_id": contract_id,
		"employee_id": employee_id,
		"type_id": type_id,
		"daily_salary": daily_salary,
		"start_day": start_day,
		"term_days": term_days,
		"end_day": end_day,
		"status": status,
		"termination_day": termination_day,
	}


static func create(
	new_contract_id: String,
	new_employee_id: String,
	new_type_id: String,
	new_daily_salary: int,
	new_start_day: int
) -> RefCounted:
	var script: Script = load("res://scripts/domain/staff/employee_contract.gd")
	var result: Variant = script.new()

	result.contract_id = new_contract_id
	result.employee_id = new_employee_id
	result.type_id = new_type_id
	result.daily_salary = maxi(new_daily_salary, 0)
	result.start_day = maxi(new_start_day, 1)

	match new_type_id:
		TYPE_FIXED_30_DAYS:
			result.term_days = 30
		TYPE_FIXED_90_DAYS:
			result.term_days = 90
		_:
			result.type_id = TYPE_PERMANENT
			result.term_days = 0

	result.end_day = (
		result.start_day + result.term_days - 1
		if result.term_days > 0
		else 0
	)
	return result


static func from_dict(payload: Dictionary) -> RefCounted:
	var script: Script = load("res://scripts/domain/staff/employee_contract.gd")
	var result: Variant = script.new()

	result.contract_id = str(payload.get("contract_id", ""))
	result.employee_id = str(payload.get("employee_id", ""))
	result.type_id = str(payload.get("type_id", TYPE_PERMANENT))
	result.daily_salary = maxi(int(payload.get("daily_salary", 0)), 0)
	result.start_day = maxi(int(payload.get("start_day", 1)), 1)
	result.term_days = maxi(int(payload.get("term_days", 0)), 0)
	result.end_day = maxi(int(payload.get("end_day", 0)), 0)
	result.status = str(payload.get("status", "active"))
	result.termination_day = maxi(int(payload.get("termination_day", 0)), 0)
	return result
