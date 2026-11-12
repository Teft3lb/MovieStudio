extends RefCounted
class_name CelebritySystem

const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)


func apply_tv_appearance(
	employee: Variant,
	role_type: String,
	audience_rating: float,
	production_quality: float,
	audience_reach: int
) -> Dictionary:
	if employee == null:
		return {}
	if str(employee.profession_id) not in ["actor", "extra"]:
		return {
			"applied": false,
			"reason": "Персонаж не относится к актёрскому составу.",
		}

	var role_multiplier: float = 1.0
	match role_type:
		"host":
			role_multiplier = 1.3
		"guest":
			role_multiplier = 0.7
		"series_regular":
			role_multiplier = 1.0
		_:
			role_multiplier = 0.85
	var reach_factor: float = clampf(
		sqrt(float(maxi(audience_reach, 0)) / 50000.0),
		0.25,
		2.5
	)
	var exposure_factor: float = clampf(
		reach_factor * role_multiplier,
		0.2,
		3.0
	)
	var recognition_delta: float = clampf(
		(0.15 + clampf(audience_rating, 0.0, 100.0) / 100.0 * 0.85)
		* exposure_factor,
		0.05,
		3.0
	)
	var popularity_delta: float = clampf(
		(
			(audience_rating - 50.0) * 0.035
			+ (production_quality - 50.0) * 0.018
		) * exposure_factor,
		-3.0,
		3.0
	)
	var experience_delta: float = 0.05 * exposure_factor
	var previous_popularity: float = clampf(
		float(employee.popularity),
		0.0,
		100.0
	)
	var previous_recognition: float = clampf(
		float(employee.recognition),
		0.0,
		100.0
	)
	employee.popularity = clampf(
		previous_popularity + popularity_delta,
		0.0,
		100.0
	)
	employee.recognition = clampf(
		previous_recognition + recognition_delta,
		0.0,
		100.0
	)
	employee.experience = clampf(
		float(employee.experience) + experience_delta,
		0.0,
		100.0
	)
	return {
		"applied": true,
		"role_type": role_type,
		"popularity_before": previous_popularity,
		"popularity_after": employee.popularity,
		"popularity_delta": employee.popularity - previous_popularity,
		"recognition_before": previous_recognition,
		"recognition_after": employee.recognition,
		"recognition_delta": employee.recognition - previous_recognition,
		"experience_delta": experience_delta,
	}


func get_contract_offer_profile(employee: Variant) -> Dictionary:
	if employee == null:
		return {}
	if str(employee.profession_id) not in ["actor", "extra"]:
		return {
			"eligible": false,
			"reason": "Контрактный профиль предназначен для актёров.",
			"marketability_score": 0.0,
			"salary_multiplier": 1.0,
			"suggested_daily_salary": maxi(int(employee.daily_salary), 0),
		}

	var skills: Dictionary = employee.skills
	var popularity: float = clampf(
		float(employee.popularity),
		0.0,
		100.0
	)
	var recognition: float = clampf(
		float(employee.recognition),
		0.0,
		100.0
	)
	var screen_presence: float = clampf(
		float(skills.get("screen_presence", skills.get("acting", 45.0))),
		0.0,
		100.0
	)
	var diction: float = clampf(
		float(skills.get("diction", 45.0)),
		0.0,
		100.0
	)
	var communication: float = clampf(
		float(skills.get("communication", 45.0)),
		0.0,
		100.0
	)
	var marketability_score: float = clampf(
		popularity * 0.35
		+ recognition * 0.35
		+ screen_presence * 0.15
		+ diction * 0.10
		+ communication * 0.05,
		0.0,
		100.0
	)
	var salary_multiplier: float = clampf(
		0.85 + marketability_score / 100.0 * 1.65,
		0.85,
		2.5
	)
	var primary_skill_id: String = str(
		PROFESSION_CATALOG_SCRIPT.get_primary_skill_id(
			str(employee.profession_id)
		)
	)
	var primary_skill_value: float = clampf(
		float(skills.get(primary_skill_id, 50.0)),
		0.0,
		100.0
	)
	var catalog_base_salary: float = float(
		PROFESSION_CATALOG_SCRIPT.get_base_salary(
			str(employee.profession_id)
		)
	)
	var base_salary: int = maxi(
		roundi(
			catalog_base_salary * (0.7 + primary_skill_value / 100.0)
		),
		1
	)
	var suggested_salary: int = maxi(
		roundi(float(base_salary) * salary_multiplier),
		base_salary
	)
	var demand_tier: String = "rising"
	if marketability_score >= 75.0:
		demand_tier = "superstar"
	elif marketability_score >= 50.0:
		demand_tier = "star"
	elif marketability_score >= 25.0:
		demand_tier = "recognizable"
	return {
		"eligible": true,
		"marketability_score": marketability_score,
		"demand_tier": demand_tier,
		"popularity": popularity,
		"recognition": recognition,
		"salary_multiplier": salary_multiplier,
		"base_daily_salary": base_salary,
		"suggested_daily_salary": suggested_salary,
		"contract_offer_available": marketability_score >= 20.0,
	}
