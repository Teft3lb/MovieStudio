extends RefCounted
class_name FilmProductionDossier

const AT_WRITERS: String = "at_writers"
const AT_STAGE: String = "at_stage"
const IN_PRODUCTION: String = "in_production"
const FOOTAGE_READY: String = "footage_ready"
const AT_EDITING: String = "at_editing"
const IN_EDITING: String = "in_editing"
const MASTER_READY: String = "master_ready"
const RELEASED: String = "released"

var screenplay: Variant
var script_id: String = ""
var title: String = ""
var phase: String = AT_WRITERS
var building_id: String = ""
var stage_building_id: String = ""
var editing_building_id: String = ""


func setup(completed_script: Variant, writers_building_id: String) -> void:
	screenplay = completed_script
	script_id = str(completed_script.id)
	title = str(completed_script.title)
	phase = AT_WRITERS
	building_id = writers_building_id
	stage_building_id = ""
	editing_building_id = ""


func is_movable() -> bool:
	return phase in [AT_WRITERS, FOOTAGE_READY, MASTER_READY]


func get_destination_title() -> String:
	match phase:
		AT_WRITERS:
			return "съёмочный павильон"
		FOOTAGE_READY:
			return "монтажный отдел"
		MASTER_READY:
			return "пункт выпуска фильма"
		AT_STAGE:
			return "ожидание начала съёмок"
		IN_PRODUCTION:
			return "идут съёмки"
		AT_EDITING:
			return "ожидание монтажа"
		IN_EDITING:
			return "идёт монтаж"
		RELEASED:
			return "фильм выпущен"
		_:
			return ""


func deliver_to_building(building_type_id: String, destination_id: String) -> bool:
	if destination_id.is_empty():
		return false
	if phase == AT_WRITERS and building_type_id == "sound_stage":
		stage_building_id = destination_id
		building_id = destination_id
		phase = AT_STAGE
		return true
	if phase == FOOTAGE_READY and building_type_id == "editing_suite":
		editing_building_id = destination_id
		building_id = destination_id
		phase = AT_EDITING
		return true
	return false


func start_production() -> bool:
	if phase != AT_STAGE:
		return false
	phase = IN_PRODUCTION
	return true


func finish_production() -> bool:
	if phase != IN_PRODUCTION:
		return false
	phase = FOOTAGE_READY
	return true


func start_editing() -> bool:
	if phase != AT_EDITING:
		return false
	phase = IN_EDITING
	return true


func finish_editing() -> bool:
	if phase != IN_EDITING:
		return false
	phase = MASTER_READY
	return true


func release_film() -> bool:
	if phase != MASTER_READY:
		return false
	phase = RELEASED
	building_id = ""
	return true


func to_dict() -> Dictionary:
	return {
		"script_id": script_id,
		"title": title,
		"phase": phase,
		"building_id": building_id,
		"stage_building_id": stage_building_id,
		"editing_building_id": editing_building_id,
	}
