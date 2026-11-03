extends RefCounted
class_name EmployeeManagementSystem

const EMPLOYEE_CONTRACT_SCRIPT = preload(
	"res://scripts/domain/staff/employee_contract.gd"
)
const EMPLOYEE_MARKET_SCRIPT = preload(
	"res://scripts/domain/staff/employee_market_system.gd"
)

const DEFAULT_MARKET_SIZE: int = 8
const MARKET_REFRESH_INTERVAL_DAYS: int = 7

var employees: Array = []
var market_candidates: Array = []
var former_employees: Array = []
var contracts: Dictionary = {}

var _market_system: RefCounted
var _next_contract_number: int = 1
var _last_market_refresh_day: int = 1


func initialize(
	initial_employees: Array,
	current_day: int,
	world_seed: int,
	market_size: int = DEFAULT_MARKET_SIZE
) -> void:
	employees = initial_employees
	market_candidates.clear()
	former_employees.clear()
	contracts.clear()
	_next_contract_number = 1
	_last_market_refresh_day = maxi(current_day, 1)

	_market_system = EMPLOYEE_MARKET_SCRIPT.new()
	_market_system.call("setup", world_seed)
	market_candidates.append_array(
		_market_system.call(
			"generate_candidates",
			market_size,
			_last_market_refresh_day
		)
	)

	for employee in employees:
		var contract: Variant = _create_contract(
			employee,
			"permanent",
			_last_market_refresh_day,
			employee.daily_salary
		)
		contracts[str(employee.id)] = contract


func hire_candidate(
	candidate_id: String,
	contract_type: String,
	current_day: int
) -> Dictionary:
	var candidate_index: int = _find_candidate_index(candidate_id)
	if candidate_index < 0:
		return _failure("Кандидат больше недоступен на рынке.")

	if _find_employee_index(candidate_id) >= 0:
		return _failure("Этот персонаж уже работает в студии.")

	if not EMPLOYEE_CONTRACT_SCRIPT.CONTRACT_TYPES.has(contract_type):
		return _failure("Выбран неизвестный тип контракта.")

	var employee: Variant = market_candidates[candidate_index]
	var salary: int = get_offer_salary(candidate_id, contract_type)
	var contract: Variant = _create_contract(
		employee,
		contract_type,
		current_day,
		salary
	)

	employee.daily_salary = salary
	employee.current_task = "Приступает к работе в студии"
	employee.work_state = "off_duty"

	employees.append(employee)
	contracts[candidate_id] = contract
	market_candidates.remove_at(candidate_index)

	return {
		"success": true,
		"message": "%s принят(а) в штат." % employee.get_full_name(),
		"employee": employee,
		"contract": contract,
	}


func dismiss_employee(employee_id: String, current_day: int) -> Dictionary:
	var employee_index: int = _find_employee_index(employee_id)
	if employee_index < 0:
		return _failure("Сотрудник не найден в действующем штате.")

	var employee: Variant = employees[employee_index]
	var contract: Variant = contracts.get(employee_id)

	if contract != null:
		contract.call("terminate", current_day)

	employee.work_state = "off_duty"
	employee.current_task = "Больше не работает в студии"

	employees.remove_at(employee_index)
	former_employees.append(employee)

	return {
		"success": true,
		"message": "%s исключён(а) из штата." % employee.get_full_name(),
		"employee": employee,
		"contract": contract,
	}


func advance_day(current_day: int) -> Dictionary:
	var expired_employees: Array = []

	for index in range(employees.size() - 1, -1, -1):
		var employee: Variant = employees[index]
		var contract: Variant = contracts.get(str(employee.id))
		if contract == null:
			continue

		var expired: bool = contract.call("expire", current_day)
		if not expired:
			continue

		employee.work_state = "off_duty"
		employee.current_task = "Срок контракта завершён"
		expired_employees.append(employee)
		employees.remove_at(index)
		former_employees.append(employee)

	var market_refreshed: bool = false
	if current_day - _last_market_refresh_day >= MARKET_REFRESH_INTERVAL_DAYS:
		refresh_market(current_day)
		market_refreshed = true

	return {
		"expired_employees": expired_employees,
		"market_refreshed": market_refreshed,
	}


func refresh_market(current_day: int) -> void:
	market_candidates.clear()
	market_candidates.append_array(
		_market_system.call(
			"generate_candidates",
			DEFAULT_MARKET_SIZE,
			current_day
		)
	)
	_last_market_refresh_day = maxi(current_day, 1)


func get_offer_salary(candidate_id: String, contract_type: String) -> int:
	var candidate: Variant = _find_candidate(candidate_id)
	if candidate == null:
		return 0

	var multiplier: float = 1.0
	match contract_type:
		"fixed_30_days":
			multiplier = 1.15
		"fixed_90_days":
			multiplier = 1.08

	return maxi(roundi(float(candidate.daily_salary) * multiplier), 1)


func get_contract(employee_id: String) -> Variant:
	return contracts.get(employee_id)


func get_candidate(candidate_id: String) -> Variant:
	return _find_candidate(candidate_id)


func get_market_days_until_refresh(current_day: int) -> int:
	var elapsed: int = current_day - _last_market_refresh_day
	return maxi(MARKET_REFRESH_INTERVAL_DAYS - elapsed, 0)


func _create_contract(
	employee: Variant,
	contract_type: String,
	current_day: int,
	daily_salary: int
) -> Variant:
	var contract_id: String = "CTR-%06d" % _next_contract_number
	_next_contract_number += 1

	return EMPLOYEE_CONTRACT_SCRIPT.create(
		contract_id,
		str(employee.id),
		contract_type,
		daily_salary,
		current_day
	)


func _find_employee_index(employee_id: String) -> int:
	for index in range(employees.size()):
		if str(employees[index].id) == employee_id:
			return index
	return -1


func _find_candidate_index(candidate_id: String) -> int:
	for index in range(market_candidates.size()):
		if str(market_candidates[index].id) == candidate_id:
			return index
	return -1


func _find_candidate(candidate_id: String) -> Variant:
	var index: int = _find_candidate_index(candidate_id)
	if index < 0:
		return null
	return market_candidates[index]


func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"employee": null,
		"contract": null,
	}
