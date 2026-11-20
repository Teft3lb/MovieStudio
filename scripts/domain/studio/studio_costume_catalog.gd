extends RefCounted
class_name StudioCostumeCatalog

const COSTUMES: Dictionary = {
	"classic_period_costumes": {"title": "Костюмы исторической эпохи", "description": "Платья, жилеты и пальто для исторических драм и мелодрам.", "price": 340, "quality_bonus": 6.0, "genre_ids": ["drama", "romance", "mystery"], "visual_color": Color(0.47, 0.28, 0.20)},
	"modern_casual_costumes": {"title": "Современная повседневная одежда", "description": "Универсальный гардероб для городских и комедийных историй.", "price": 260, "quality_bonus": 4.0, "genre_ids": ["comedy", "drama", "romance"], "visual_color": Color(0.30, 0.43, 0.54)},
	"detective_uniforms": {"title": "Детективная форма", "description": "Форма полиции, следователей и сотрудников спецслужб.", "price": 300, "quality_bonus": 5.0, "genre_ids": ["mystery", "action", "drama"], "visual_color": Color(0.24, 0.34, 0.31)},
	"western_costumes": {"title": "Костюмы Дикого Запада", "description": "Ковбойские куртки, шляпы и дорожная одежда.", "price": 420, "quality_bonus": 7.0, "genre_ids": ["adventure", "action"], "visual_color": Color(0.57, 0.38, 0.20)},
	"fantasy_costumes": {"title": "Фэнтези-костюмы", "description": "Плащи, доспехи и необычные наряды для приключений.", "price": 480, "quality_bonus": 8.0, "genre_ids": ["adventure"], "visual_color": Color(0.39, 0.30, 0.53)},
	"science_fiction_costumes": {"title": "Футуристические костюмы", "description": "Форма экипажей, лабораторные комбинезоны и костюмы будущего.", "price": 500, "quality_bonus": 8.0, "genre_ids": ["science_fiction"], "visual_color": Color(0.20, 0.49, 0.54)},
	"office_costumes": {"title": "Деловой гардероб", "description": "Костюмы для офисных, судебных и криминальных драм.", "price": 280, "quality_bonus": 4.0, "genre_ids": ["drama", "mystery", "comedy"], "visual_color": Color(0.32, 0.33, 0.37)},
}


static func get_costume_ids() -> Array[String]:
	var result: Array[String] = []
	for costume_id_value in COSTUMES.keys():
		result.append(str(costume_id_value))
	result.sort()
	return result


static func get_costume_definition(costume_id: String) -> Dictionary:
	if not COSTUMES.has(costume_id):
		return {}
	return COSTUMES[costume_id].duplicate(true)


static func get_costume_title(costume_id: String) -> String:
	var definition: Dictionary = get_costume_definition(costume_id)
	return str(definition.get("title", costume_id))
