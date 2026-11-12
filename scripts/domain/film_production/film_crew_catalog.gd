extends RefCounted
class_name FilmCrewCatalog

const REQUIRED_STAGE_PROFESSIONS: Array[String] = [
	"director",
	"actor",
	"camera_operator",
	"technician",
]
const FILM_CREW_ROLE_CONFIG: Array[Dictionary] = [
	{"id": "director", "title": "Режиссёр", "profession_id": "director", "specialization_id": "", "skill_id": "directing", "required": true},
	{"id": "camera_operator", "title": "Оператор", "profession_id": "camera_operator", "specialization_id": "", "skill_id": "camera_work", "required": true},
	{"id": "technician", "title": "Главный техник", "profession_id": "technician", "specialization_id": "", "skill_id": "technical", "required": true},
	{"id": "producer", "title": "Продюсер", "profession_id": "producer", "specialization_id": "", "skill_id": "management", "required": false},
	{"id": "lighting_technician", "title": "Светотехник", "profession_id": "technician", "specialization_id": "lighting", "skill_id": "lighting", "required": false},
	{"id": "sound_technician", "title": "Звукотехник", "profession_id": "technician", "specialization_id": "sound", "skill_id": "sound", "required": false},
	{"id": "equipment_technician", "title": "Техник оборудования", "profession_id": "technician", "specialization_id": "equipment", "skill_id": "equipment", "required": false},
	{"id": "technician_assistant_1", "title": "Дополнительный техник I", "profession_id": "technician", "specialization_id": "", "skill_id": "technical", "required": false},
	{"id": "technician_assistant_2", "title": "Дополнительный техник II", "profession_id": "technician", "specialization_id": "", "skill_id": "technical", "required": false},
	{"id": "production_designer", "title": "Художник-постановщик", "profession_id": "production_designer", "specialization_id": "sets", "skill_id": "set_design", "required": false},
	{"id": "costume_designer", "title": "Художник по костюмам", "profession_id": "production_designer", "specialization_id": "costumes", "skill_id": "costume_design", "required": false},
	{"id": "makeup_artist", "title": "Гримёр", "profession_id": "production_designer", "specialization_id": "makeup", "skill_id": "makeup", "required": false},
]
const FILM_TECHNICIAN_ROLE_IDS: Array[String] = [
	"technician",
	"lighting_technician",
	"sound_technician",
	"equipment_technician",
	"technician_assistant_1",
	"technician_assistant_2",
]
const MAX_BACKGROUND_PERFORMERS: int = 4
