extends SceneTree

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_management_system.gd"
)
const EMPLOYEE_CONTRACT_SCRIPT = preload(
	"res://scripts/domain/staff/employee_contract.gd"
)


func _initialize() -> void:
	var generator: RefCounted = CHARACTER_GENERATOR_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4102026

	var initial_employees: Array = []
	initial_employees.append(
		generator.call("generate", rng, "EMP-TEST-0001", "actor")
	)
	initial_employees.append(
		generator.call("generate", rng, "EMP-TEST-0002", "director")
	)

	var management: Variant = EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT.new()
	management.call("initialize", initial_employees, 1, 246810, 4)

	assert(
		management.employees.size() == 2,
		"Initial employees must remain in the active roster."
	)
	assert(
		management.market_candidates.size() == 4,
		"Initial market must contain the configured candidate count."
	)
	assert(
		management.contracts.size() == 2,
		"Every starting employee must receive a permanent contract."
	)

	_test_contract_serialization(management)
	_test_hiring(management)
	_test_dismissal(management)
	_test_market_refresh(management)
	_test_fixed_term_expiry(management)

	print("EmployeeManagementSmokeTest: PASS")
	quit(0)


func _test_contract_serialization(management: Variant) -> void:
	var employee_id: String = str(management.employees[0].id)
	var contract: Variant = management.call("get_contract", employee_id)
	var payload: Dictionary = contract.call("to_dict")
	var restored: Variant = EMPLOYEE_CONTRACT_SCRIPT.from_dict(payload)

	assert(
		restored.contract_id == contract.contract_id,
		"Contract ID must survive serialization."
	)
	assert(
		restored.employee_id == employee_id,
		"Employee ID must survive contract serialization."
	)
	assert(
		restored.type_id == "permanent" and restored.end_day == 0,
		"Starting employees must have indefinite contracts."
	)


func _test_hiring(management: Variant) -> void:
	var candidate: Variant = management.market_candidates[0]
	var candidate_id: String = str(candidate.id)
	var base_salary: int = candidate.daily_salary
	var expected_salary: int = int(
		management.call("get_offer_salary", candidate_id, "fixed_30_days")
	)

	var result: Dictionary = management.call(
		"hire_candidate",
		candidate_id,
		"fixed_30_days",
		1
	)

	assert(bool(result.get("success", false)), "A valid market candidate must be hireable.")
	assert(
		management.employees.size() == 3,
		"Hiring must add one employee to the active roster."
	)
	assert(
		management.market_candidates.size() == 3,
		"Hired candidates must leave the market."
	)

	var hired_employee: Variant = result.get("employee")
	var contract: Variant = result.get("contract")
	assert(
		str(hired_employee.id) == candidate_id,
		"Hiring must preserve the candidate's stable character ID."
	)
	assert(
		hired_employee.daily_salary == expected_salary,
		"Employee salary must use the selected contract offer."
	)
	assert(
		contract.type_id == "fixed_30_days",
		"The selected contract type must be stored."
	)
	assert(
		contract.term_days == 30 and contract.end_day == 30,
		"A 30-day contract signed on day 1 must end on day 30."
	)
	assert(
		expected_salary >= base_salary,
		"Fixed-term contracts must not undercut the candidate's salary expectation."
	)

	var duplicate_result: Dictionary = management.call(
		"hire_candidate",
		candidate_id,
		"permanent",
		1
	)
	assert(
		not bool(duplicate_result.get("success", false)),
		"A candidate cannot be hired twice."
	)


func _test_dismissal(management: Variant) -> void:
	var employee_id: String = str(management.employees[2].id)
	var result: Dictionary = management.call(
		"dismiss_employee",
		employee_id,
		2
	)

	assert(bool(result.get("success", false)), "An active employee must be dismissible.")
	assert(
		management.employees.size() == 2,
		"Dismissal must remove the employee from the active roster."
	)
	assert(
		management.former_employees.size() == 1,
		"Dismissed employees must remain in the former-employee archive."
	)

	var contract: Variant = management.call("get_contract", employee_id)
	assert(
		contract.status == "terminated" and contract.termination_day == 2,
		"Dismissal must terminate the employment contract."
	)


func _test_market_refresh(management: Variant) -> void:
	var result: Dictionary = management.call("advance_day", 8)

	assert(
		bool(result.get("market_refreshed", false)),
		"The market must refresh after seven elapsed game days."
	)
	assert(
		management.market_candidates.size() == 8,
		"Market refresh must restore the default candidate pool."
	)
	assert(
		int(management.call("get_market_days_until_refresh", 8)) == 7,
		"Market refresh countdown must reset after refresh."
	)


func _test_fixed_term_expiry(management: Variant) -> void:
	var candidate: Variant = management.market_candidates[0]
	var candidate_id: String = str(candidate.id)
	var hire_result: Dictionary = management.call(
		"hire_candidate",
		candidate_id,
		"fixed_90_days",
		8
	)
	assert(bool(hire_result.get("success", false)), "Candidate must be hireable on refreshed market.")

	var contract: Variant = hire_result.get("contract")
	assert(contract.end_day == 97, "A 90-day contract starting on day 8 must end on day 97.")

	var before_end: Dictionary = management.call("advance_day", 97)
	assert(
		before_end.get("expired_employees", []).is_empty(),
		"A fixed-term contract must remain active through its final day."
	)

	var after_end: Dictionary = management.call("advance_day", 98)
	var expired: Array = after_end.get("expired_employees", [])
	assert(
		expired.size() == 1 and str(expired[0].id) == candidate_id,
		"Expired employees must be removed from active staff on the following day."
	)
	assert(
		management.employees.size() == 2,
		"Expired employees must no longer count as active staff."
	)
	assert(
		management.former_employees.size() == 2,
		"Expired employees must be retained in the former-employee archive."
	)
	assert(
		contract.status == "expired" and contract.termination_day == 98,
		"Contract expiry must be recorded."
	)
