extends SceneTree

const EMPLOYEE_MARKET_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/staff/employee_market_system.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)


func _initialize() -> void:
	var market: RefCounted = EMPLOYEE_MARKET_SYSTEM_SCRIPT.new()
	market.call("setup", 884422)

	_test_initial_market(market)
	_test_refreshed_market(market)

	print("EmployeeMarketCriticalRolesTest: PASS")
	quit(0)


func _test_initial_market(market: RefCounted) -> void:
	var candidates: Array = market.call("generate_candidates", 8, 1)
	assert(candidates.size() == 8, "The standard market must contain eight candidates.")

	var technician_count: int = _count_profession(candidates, "technician")
	assert(
		technician_count >= 1,
		"The standard recruitment market must always contain a technician."
	)

	var departments: Dictionary = {}
	for candidate in candidates:
		departments[str(candidate.get_department_title())] = true
	assert(
		departments.size() == 6,
		"The standard market must continue to represent all six departments."
	)


func _test_refreshed_market(market: RefCounted) -> void:
	var candidates: Array = market.call("generate_candidates", 8, 8)
	assert(
		_count_profession(candidates, "technician") >= 1,
		"A refreshed market must also contain a technician."
	)


func _count_profession(candidates: Array, profession_id: String) -> int:
	var count: int = 0
	for candidate in candidates:
		if str(candidate.profession_id) == profession_id:
			count += 1
	return count
