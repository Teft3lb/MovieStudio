extends "res://tests/smoke_test_base.gd"

const MAIN_SCENE = preload("res://scenes/main.tscn")
const DISTRIBUTION = preload("res://scripts/domain/film_distribution/film_distribution_system.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_simultaneous_runs()
	_test_release_to_box_office()
	_finish_test("FilmDistributionSmokeTest")


func _test_simultaneous_runs() -> void:
	var system := DISTRIBUTION.new()
	_expect(not system.open_run("", 1, 70), "A release must have a project ID.")
	_expect(system.open_run("first", 1, 70), "The first film must open a run.")
	_expect(not system.open_run("first", 2, 100), "A duplicate release must preserve the run.")
	_expect(system.open_run("second", 2, 50), "A second film can run concurrently.")
	_expect(system.settle_through(2) == 1400, "Only the first run earns on day two.")
	_expect(system.settle_through(2) == 0, "Repeated settlement must pay nothing.")
	_expect(system.settle_through(3) == 2190, "Both open films must earn on day three.")
	_expect(system.settle_through(15) == 6010, "A day jump must settle only the remaining days.")
	_expect(bool(system.get_run("first").closed), "A finished run must be closed.")
	_expect(int(system.get_run("second").gross) == 4000, "Each film retains its own gross.")
	_expect(system.settle_through(16) == 0, "Closed runs must stop earning.")


func _test_release_to_box_office() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	var clock := world.get_node("GameClock") as GameClock
	clock.set_speed_mode(GameClock.SpeedMode.PAUSED)
	var manager := world.get_node("StudioBuildingManager") as StudioBuildingManager
	var inventory: StudioSetInventory = manager.get("_set_inventory")
	var stage_id: String = manager.get_preferred_stage_building_id()
	var editing_suite: Variant = manager.call("_create_building", "editing_suite", Vector3(27, 0, 22), 0.0)
	manager.call("_create_building", "film_promotion", Vector3(-25, 0, 22), 0.0)
	var screenplay := FilmScriptData.new()
	screenplay.id = "SCR-DISTRIBUTION"
	screenplay.title = "Проверка проката"
	var production := FilmProductionProject.new()
	production.id = "FILM-DISTRIBUTION"
	production.script_id = screenplay.id
	production.status = "completed"
	var editing := FilmEditingProject.new()
	editing.production_project_id = production.id
	editing.film_title = screenplay.title
	editing.status = "completed"
	editing.final_quality = 70
	editing.commercial_success_score = 70
	manager.set("_active_film_project", production)
	manager.set("_active_editing_project", editing)
	var starting_budget: int = inventory.budget
	var campaign: Dictionary = manager.launch_marketing_campaign(production.id, "local")
	_expect(bool(campaign.success), "A mastered film must accept pre-release marketing.")
	_expect(inventory.budget == starting_budget - 250, "Marketing must debit the studio budget.")
	var dossier: StudioFilmDossierController = manager.call("_get_film_dossier_controller")
	_expect(
		dossier.add_completed_script(screenplay)
		and dossier.deliver_to_building(screenplay.id, stage_id)
		and dossier.on_production_started(screenplay.id, stage_id)
		and dossier.on_production_completed(screenplay.id)
		and dossier.deliver_to_building(screenplay.id, str(editing_suite.id))
		and dossier.on_editing_started(screenplay.id)
		and dossier.on_editing_completed(screenplay.id)
		and dossier.release_film(screenplay.id),
		"The physical release must start the distribution run."
	)
	_expect(not dossier.release_film(screenplay.id), "The same reel cannot be released again.")
	manager.on_film_dossier_released(dossier.get_dossier(screenplay.id).to_dict())
	_expect(manager.get_released_film_records().size() == 1, "Release must be archived once.")
	_expect(inventory.budget == starting_budget - 250, "Release day must pay nothing.")
	clock.current_hour = 23
	clock.current_minute = 59
	clock.advance_minutes(1)
	_expect(inventory.budget == starting_budget - 250 + 1480, "The first day must pay at the advertised score.")
	campaign = manager.launch_marketing_campaign(production.id, "regional")
	_expect(bool(campaign.success), "An ongoing run must accept another campaign.")
	_expect(
		int(manager.get_marketable_films()[0].distribution.gross) == 1480,
		"New marketing cannot revise previously settled gross."
	)
	manager.set("_active_film_project", null)
	manager.set("_active_editing_project", null)
	clock.advance_days(6)
	var card: Dictionary = manager.get_marketable_films()[0]
	_expect(bool(card.distribution.closed) and int(card.distribution.gross) == 6220, "The archive card must show the final box office.")
	_expect(int(card.final_quality) == 70, "Distribution and marketing must preserve artistic quality.")
	var final_budget: int = inventory.budget
	_expect(final_budget == starting_budget - 850 + 6220, "All gross must reach the studio budget.")
	_expect(
		not bool(manager.launch_marketing_campaign(production.id, "local").success)
		and inventory.budget == final_budget,
		"A closed run must reject marketing without charging the studio."
	)
	world.free()
