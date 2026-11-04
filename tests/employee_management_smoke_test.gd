extends "res://tests/smoke_test_base.gd"

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const EMPLOYEE_MANAGEMENT_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_management_system.gd"
)
const EMPLOYEE_CONTRACT_SCRIPT = preload(
	"res://scripts/domain/staff/employee_contract.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)
const CHARACTER_DATA_SCRIPT = preload(
	"res://scripts/domain/characters/character_data.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
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

	_expect(
		management.employees.size() == 2,
		"Initial employees must remain in the active roster."
	)
	_expect(
		management.market_candidates.size() == 4,
		"Initial market must contain the configured candidate count."
	)
	_expect(
		management.contracts.size() == 2,
		"Every starting employee must receive a permanent contract."
	)

	_test_profession_catalog(generator, rng)
	_test_contract_serialization(management)
	_test_hiring(management)
	_test_dismissal(management)
	_test_market_refresh(management)
	_test_fixed_term_expiry(management)

	_finish_test("EmployeeManagementSmokeTest")


func _test_profession_catalog(generator: Variant, rng: RandomNumberGenerator) -> void:
	var profession_ids: Array[String] = PROFESSION_CATALOG_SCRIPT.get_profession_ids()
	_expect(
		profession_ids.size() == 19,
		"The profession catalog must contain exactly 19 focused professions."
	)

	for profession_id in profession_ids:
		var candidate: Variant = generator.call(
			"generate", rng, "PROF-TEST-%s" % profession_id, profession_id
		)
		_expect(
			candidate.profession_id == profession_id,
			"Generated employee must retain the requested profession."
		)
		_expect(
			not candidate.get_profession_title().is_empty(),
			"Every profession must have a localized title."
		)
		_expect(
			not candidate.get_department_title().is_empty(),
			"Every profession must belong to a department."
		)
		_expect(
			candidate.skills.has(candidate.get_primary_skill_id()),
			"Every profession must map to an existing primary skill."
		)
		_expect(
			candidate.daily_salary > 0,
			"Every profession must generate a positive salary expectation."
		)

		var specialization_ids: Array[String] = (
			PROFESSION_CATALOG_SCRIPT.get_specialization_ids(profession_id)
		)
		if specialization_ids.is_empty():
			_expect(
				candidate.specialization_id.is_empty(),
				"Professions without specializations must not receive a fabricated specialization."
			)
		else:
			_expect(
				specialization_ids.has(candidate.specialization_id),
				"Generated specialization must belong to its profession."
			)
			_expect(
				not candidate.get_specialization_title().is_empty(),
				"Generated specialization must have a localized title."
			)
			var specialization_skill_id: String = (
				PROFESSION_CATALOG_SCRIPT.get_specialization_skill_id(
					profession_id,
					candidate.specialization_id
				)
			)
			_expect(
				candidate.skills.has(specialization_skill_id),
				"Specializations must reuse an existing character skill."
			)
			var restored_specialist: Variant = CHARACTER_DATA_SCRIPT.from_dict(
				candidate.to_dict()
			)
			_expect(
				restored_specialist.specialization_id == candidate.specialization_id,
				"Specialization must survive CharacterData serialization."
			)

	var expected_department_counts: Dictionary = {
		"creative": 6,
		"production": 3,
		"facility": 3,
		"catering": 3,
		"administration": 2,
		"marketing": 2,
	}
	var market_departments: Dictionary = {}
	for department_id in PROFESSION_CATALOG_SCRIPT.get_department_ids():
		market_departments[str(department_id)] = false
		var department_professions: Array[String] = (
			PROFESSION_CATALOG_SCRIPT.get_profession_ids_for_department(
				str(department_id)
			)
		)
		_expect(
			department_professions.size() == int(expected_department_counts.get(
				str(department_id), -1
			)),
			"Each department must contain only its agreed number of professions."
		)

	var market_system: Variant = load(
		"res://scripts/domain/staff/employee_market_system.gd"
	).new()
	market_system.call("setup", 20261104)
	var candidates: Array = market_system.call("generate_candidates", 8, 1)
	for candidate in candidates:
		market_departments[str(
			PROFESSION_CATALOG_SCRIPT.get_profession(
				candidate.profession_id
			).get("department", "")
		)] = true

	for department_id in market_departments.keys():
		_expect(
			bool(market_departments[department_id]),
			"The initial market must represent every employee department."
		)

	for core_profession_id in [
		"actor",
		"director",
		"screenwriter",
		"camera_operator",
		"producer",
		"technician",
	]:
		var core_schedule: Dictionary = PROFESSION_CATALOG_SCRIPT.get_schedule(
			core_profession_id
		)
		_expect(
			int(core_schedule.get("shift_start_hour", -1)) == 8
			and int(core_schedule.get("shift_end_hour", -1)) == 17
			and int(core_schedule.get("break_start_hour", -1)) == 12
			and int(core_schedule.get("break_end_hour", -1)) == 13,
			"Character System v2 core professions must keep their verified schedule."
		)

	_expect(
		PROFESSION_CATALOG_SCRIPT.get_profession_title("camera_operator") == "Оператор",
		"Existing Character System v2 profession titles must remain unchanged."
	)
	_expect(
		PROFESSION_CATALOG_SCRIPT.get_default_task("camera_operator")
			== "Готовит операторское оборудование",
		"Existing Character System v2 work-task labels must remain unchanged."
	)

	var technician_candidate: Variant = generator.call(
		"generate", rng, "PROF-TEST-TECHNICIAN", "technician"
	)
	_expect(
		technician_candidate.get_profession_title() == "Техник",
		"Character System v2 technician profiles must remain supported."
	)




func _test_contract_serialization(management: Variant) -> void:
	var employee_id: String = str(management.employees[0].id)
	var contract: Variant = management.call("get_contract", employee_id)
	var payload: Dictionary = contract.call("to_dict")
	var restored: Variant = EMPLOYEE_CONTRACT_SCRIPT.from_dict(payload)

	_expect(
		restored.contract_id == contract.contract_id,
		"Contract ID must survive serialization."
	)
	_expect(
		restored.employee_id == employee_id,
		"Employee ID must survive contract serialization."
	)
	_expect(
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

	_expect(bool(result.get("success", false)), "A valid market candidate must be hireable.")
	_expect(
		management.employees.size() == 3,
		"Hiring must add one employee to the active roster."
	)
	_expect(
		management.market_candidates.size() == 3,
		"Hired candidates must leave the market."
	)

	var hired_employee: Variant = result.get("employee")
	var contract: Variant = result.get("contract")
	_expect(
		str(hired_employee.id) == candidate_id,
		"Hiring must preserve the candidate's stable character ID."
	)
	_expect(
		hired_employee.daily_salary == expected_salary,
		"Employee salary must use the selected contract offer."
	)
	_expect(
		contract.type_id == "fixed_30_days",
		"The selected contract type must be stored."
	)
	_expect(
		contract.term_days == 30 and contract.end_day == 30,
		"A 30-day contract signed on day 1 must end on day 30."
	)
	_expect(
		expected_salary >= base_salary,
		"Fixed-term contracts must not undercut the candidate's salary expectation."
	)

	var duplicate_result: Dictionary = management.call(
		"hire_candidate",
		candidate_id,
		"permanent",
		1
	)
	_expect(
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

	_expect(bool(result.get("success", false)), "An active employee must be dismissible.")
	_expect(
		management.employees.size() == 2,
		"Dismissal must remove the employee from the active roster."
	)
	_expect(
		management.former_employees.size() == 1,
		"Dismissed employees must remain in the former-employee archive."
	)

	var contract: Variant = management.call("get_contract", employee_id)
	_expect(
		contract.status == "terminated" and contract.termination_day == 2,
		"Dismissal must terminate the employment contract."
	)


func _test_market_refresh(management: Variant) -> void:
	var result: Dictionary = management.call("advance_day", 8)

	_expect(
		bool(result.get("market_refreshed", false)),
		"The market must refresh after seven elapsed game days."
	)
	_expect(
		management.market_candidates.size() == 8,
		"Market refresh must restore the default candidate pool."
	)
	_expect(
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
	_expect(bool(hire_result.get("success", false)), "Candidate must be hireable on refreshed market.")

	var contract: Variant = hire_result.get("contract")
	_expect(contract.end_day == 97, "A 90-day contract starting on day 8 must end on day 97.")

	var before_end: Dictionary = management.call("advance_day", 97)
	_expect(
		before_end.get("expired_employees", []).is_empty(),
		"A fixed-term contract must remain active through its final day."
	)

	var after_end: Dictionary = management.call("advance_day", 98)
	var expired: Array = after_end.get("expired_employees", [])
	_expect(
		expired.size() == 1 and str(expired[0].id) == candidate_id,
		"Expired employees must be removed from active staff on the following day."
	)
	_expect(
		management.employees.size() == 2,
		"Expired employees must no longer count as active staff."
	)
	_expect(
		management.former_employees.size() == 2,
		"Expired employees must be retained in the former-employee archive."
	)
	_expect(
		contract.status == "expired" and contract.termination_day == 98,
		"Contract expiry must be recorded."
	)
