extends RefCounted
class_name EmployeeMarketSystem

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)

const PROFESSION_IDS: Array[String] = [
	"actor",
	"director",
	"screenwriter",
	"camera_operator",
	"producer",
	"technician",
]

var _generator: RefCounted
var _rng: RandomNumberGenerator
var _market_cycle: int = 0


func setup(seed_value: int) -> void:
	_generator = CHARACTER_GENERATOR_SCRIPT.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	_market_cycle = 0


func generate_candidates(count: int, current_day: int) -> Array:
	var candidates: Array = []
	var used_names: Dictionary = {}
	_market_cycle += 1

	for index in range(maxi(count, 0)):
		var profession_id: String = PROFESSION_IDS[
			_rng.randi_range(0, PROFESSION_IDS.size() - 1)
		]
		var candidate_id: String = "CAND-D%03d-%02d-%02d" % [
			current_day,
			_market_cycle,
			index + 1,
		]

		var candidate: Variant = _generator.call(
			"generate",
			_rng,
			candidate_id,
			profession_id
		)

		var name_key: String = candidate.get_full_name().to_lower()
		var attempts: int = 0
		while used_names.has(name_key) and attempts < 8:
			candidate = _generator.call(
				"generate",
				_rng,
				candidate_id,
				profession_id
			)
			name_key = candidate.get_full_name().to_lower()
			attempts += 1

		used_names[name_key] = true
		candidate.current_task = "Ищет работу в киноиндустрии"
		candidate.work_state = "market"
		candidates.append(candidate)

	return candidates
