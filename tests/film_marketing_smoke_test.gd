extends "res://tests/smoke_test_base.gd"

const EDITING_PROJECT_SCRIPT = preload("res://scripts/domain/film_editing/film_editing_project.gd")
const FILM_MARKETING_SYSTEM_SCRIPT = preload("res://scripts/domain/film_distribution/film_marketing_system.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var system: RefCounted = FILM_MARKETING_SYSTEM_SCRIPT.new()
	var project: Variant = EDITING_PROJECT_SCRIPT.new()
	project.production_project_id = "FILM-MARKETING-001"
	project.film_title = "Проверка рекламной кампании"
	project.status = "completed"
	project.final_quality = 70
	project.commercial_success_score = 70
	_expect(system.call("get_campaign_definitions").size() == 3, "The marketing system must expose local, regional and national campaigns.")
	var local_result: Dictionary = system.call("apply_campaign_to_project", project, "local")
	_expect(bool(local_result.get("success", false)) and int(project.commercial_success_score) == 74 and int(project.marketing_campaign_count) == 1, "The first local campaign must increase commercial success without changing artistic quality.")
	var regional_result: Dictionary = system.call("apply_campaign_to_project", project, "regional")
	_expect(bool(regional_result.get("success", false)) and int(project.commercial_success_score) == 79 and int(project.marketing_campaign_count) == 2, "Repeated campaigns must have diminishing returns.")
	var national_result: Dictionary = system.call("apply_campaign_to_project", project, "national")
	_expect(bool(national_result.get("success", false)) and int(project.commercial_success_score) == 83 and int(project.marketing_campaign_count) == 3 and int(project.marketing_spend) == 2050, "The third campaign must apply its reduced bonus and accumulate marketing spend.")
	var fourth_result: Dictionary = system.call("apply_campaign_to_project", project, "local")
	_expect(not bool(fourth_result.get("success", false)) and int(project.commercial_success_score) == 83 and int(project.marketing_campaign_count) == 3, "A fourth campaign must be rejected after the per-film campaign limit.")
	var restored: Variant = EDITING_PROJECT_SCRIPT.from_dict(project.to_dict())
	_expect(int(restored.commercial_success_score) == 83 and int(restored.marketing_campaign_count) == 3 and int(restored.marketing_spend) == 2050, "Commercial success and campaign history must survive editing project serialization.")
	var archived_record: Dictionary = {"status": "completed", "final_quality": 60, "commercial_success_score": 60}
	var archived_result: Dictionary = system.call("apply_campaign_to_record", archived_record, "local")
	_expect(bool(archived_result.get("success", false)) and int(archived_record.get("commercial_success_score", 0)) == 64, "Released film archive records must accept later advertising campaigns.")
	_finish_test("FilmMarketingSmokeTest")
