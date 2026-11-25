extends SceneTree

const WORLD = preload("res://scenes/main.tscn")
const PROFESSIONS := ["screenwriter", "film_editor", "actor", "director", "camera_operator", "technician"]

var _peak_facility_reservations: int = 0
var _audits: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD.instantiate() as Node3D
	root.add_child(world)
	var clock := world.get_node("GameClock") as GameClock
	var staff := world.get_node("CharacterManager") as CharacterManager
	var studio := world.get_node("StudioBuildingManager") as StudioBuildingManager
	clock.set_speed_mode(GameClock.SpeedMode.PAUSED)
	var editor_room: Variant = studio.call("_create_building", "editing_suite", Vector3(25, 0, 23), 0.0)
	for item in [
		["cafeteria", Vector3(-32, 0, -10)], ["staff_housing", Vector3(23, 0, -27)],
		["studio_lounge", Vector3(-33, 0, 12)], ["film_promotion", Vector3(42, 0, 8)],
	]:
		studio.call("_create_building", item[0], item[1], 0.0)
	for profession in ["technician", "film_editor"]:
		for candidate in staff.market_candidates.duplicate():
			if str(candidate.profession_id) == profession:
				staff.set("_selected_market_candidate_id", str(candidate.id))
				staff.call("_on_hire_button_pressed")
				break
	var active_staff: Dictionary = {}
	for employee in staff.employees:
		active_staff.get_or_add(str(employee.profession_id), str(employee.id))
	if not active_staff.has("technician") or not active_staff.has("film_editor"):
		_fail("Could not recruit the required occupations through the market.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7716
	var generator := CharacterGenerator.new()
	for index in range(staff.employees.size(), 30):
		var employee: Variant = generator.generate(rng, "ENDURANCE-%03d" % index, PROFESSIONS[index % PROFESSIONS.size()])
		staff.employees.append(employee)
		staff.call("_spawn_employee_actor", employee, index)
	staff.call("_refresh_workplace_assignments")
	var initial_budget: int = studio.get("_set_inventory").budget
	var dossier: StudioFilmDossierController = studio.call("_get_film_dossier_controller")
	var stage_id := studio.get_preferred_stage_building_id()
	for film_index in 3:
		if not _complete_film(studio, clock, dossier, active_staff, stage_id, str(editor_room.id), film_index):
			_fail("Production, editing or the physical release failed for film %d." % film_index)
			return
		if not _advance_days(clock, 2):
			return
		studio.set("_active_film_project", null)
		studio.set("_active_editing_project", null)
	if not _advance_days(clock, 7):
		return
	var finished_runs: int = 0
	var gross: int = 0
	for film in studio.get_marketable_films():
		if bool(film.distribution.get("closed", false)):
			finished_runs += 1
			gross += int(film.distribution.gross)
	var actual_delta: int = int(studio.get("_set_inventory").budget) - initial_budget
	if finished_runs != 3 or gross <= 0 or actual_delta != gross:
		_fail("Final archive or budget does not reconcile with the three runs.")
		return
	print("STUDIO_ENDURANCE ", JSON.stringify({
		"employees": staff.get_employee_count(), "days": clock.current_day - 1,
		"completed_runs": finished_runs, "gross": gross, "budget_change": actual_delta,
		"reservation_audits": _audits, "peak_facility_reservations": _peak_facility_reservations,
	}))
	world.free()
	quit()


func _advance_days(clock: GameClock, days: int) -> bool:
	for period in days * 8:
		clock.advance_minutes(180)
		_audits += 1
		var occupied: Dictionary = {}
		for actor in get_nodes_in_group("studio_employee"):
			if not actor.is_in_facility():
				continue
			var key := "%s/%d" % [actor.get_facility_building_id(), actor.get_facility_slot_index()]
			if occupied.has(key):
				_fail("Duplicate facility reservation: " + key)
				return false
			occupied[key] = true
		_peak_facility_reservations = maxi(_peak_facility_reservations, occupied.size())
	return true


func _complete_film(
	studio: StudioBuildingManager, clock: GameClock, dossier: StudioFilmDossierController,
	employees: Dictionary, stage_id: String, editor_room: String, index: int
) -> bool:
	var screenplay := FilmScriptData.new()
	screenplay.id = "ENDURANCE-SCRIPT-%d" % index
	screenplay.title = "Endurance %d" % index
	screenplay.genre_id = "drama"
	screenplay.scene_count = 2
	screenplay.potential_score = 81
	screenplay.cast = [{"role_id": "ROLE-01", "character_name": "Avery"}]
	for scene_number in 2:
		screenplay.scenes.append({
			"scene_id": "SCN-%d" % scene_number, "scene_number": scene_number + 1,
			"title": "Scene %d" % scene_number, "characters": ["Avery"], "dialogue": "Avery: Ready.",
		})
	var filming := FilmProductionSystem.new()
	var crew := {"director": employees.director, "camera_operator": employees.camera_operator, "technician": employees.technician}
	var production: Variant = filming.start_project(screenplay, crew, {"ROLE-01": employees.actor},
		"ENDURANCE-FILM-%d" % index, 7000 + index, clock.current_day, clock.current_hour, clock.current_minute)
	if production == null or not dossier.add_completed_script(screenplay):
		return false
	if not dossier.deliver_to_building(screenplay.id, stage_id) or not dossier.on_production_started(screenplay.id, stage_id):
		return false
	for minute in 2000:
		if str(production.status) == "completed":
			break
		filming.advance_minute(production, screenplay, true, true,
			{"directing": 85.0, "acting": 84.0, "camera": 78.0})
	if str(production.status) != "completed" or not dossier.on_production_completed(screenplay.id):
		return false
	if not dossier.deliver_to_building(screenplay.id, editor_room):
		return false
	var editing_system := FilmEditingSystem.new()
	var editing: Variant = editing_system.create_project(production, str(employees.film_editor), 83.0,
		"ENDURANCE-EDIT-%d" % index, clock.current_day, clock.current_hour, clock.current_minute)
	if editing == null or not editing_system.start_editing(editing) or not dossier.on_editing_started(screenplay.id):
		return false
	for minute in 2000:
		if str(editing.status) == "completed":
			break
		editing_system.advance_minute(editing, true)
	if str(editing.status) != "completed" or not dossier.on_editing_completed(screenplay.id):
		return false
	studio.set("_active_film_project", production)
	studio.set("_active_editing_project", editing)
	return dossier.release_film(screenplay.id)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
