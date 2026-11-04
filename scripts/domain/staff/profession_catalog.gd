extends RefCounted
class_name ProfessionCatalog

const DEPARTMENT_TITLES: Dictionary = {
	"creative": "Творческий отдел",
	"production": "Съёмочная группа",
	"facility": "Хозяйственный отдел",
	"catering": "Питание и обслуживание",
	"administration": "Административный отдел",
	"marketing": "Реклама и продвижение",
}

const DEPARTMENT_ORDER: Array[String] = [
	"creative",
	"production",
	"facility",
	"catering",
	"administration",
	"marketing",
]

const CHARACTER_SYSTEM_V2_CORE_PROFESSION_IDS: Array[String] = [
	"actor",
	"director",
	"screenwriter",
	"camera_operator",
	"producer",
	"technician",
]

const SKILL_TITLES: Dictionary = {
	"acting": "Актёрское мастерство",
	"directing": "Режиссура",
	"writing": "Сценарное мастерство",
	"camera_work": "Работа с камерой",
	"management": "Управление",
	"technical": "Технические навыки",
	"creativity": "Креативность",
	"reliability": "Надёжность",
	"lighting": "Освещение",
	"sound": "Звук",
	"editing": "Монтаж",
	"set_design": "Декорации",
	"costume_design": "Костюмы",
	"makeup": "Грим",
	"maintenance": "Обслуживание",
	"culinary": "Кулинария",
	"hospitality": "Гостеприимство",
	"administration": "Администрирование",
	"communication": "Коммуникация",
	"marketing": "Маркетинг",
	"security": "Безопасность",
	"improvisation": "Импровизация",
	"diction": "Дикция",
	"movement": "Пластика",
	"screen_presence": "Экранная харизма",
	"visual_storytelling": "Визуальное повествование",
	"actor_direction": "Работа с актёрами",
	"story_structure": "Структура истории",
	"dialogue": "Диалоги",
	"character_development": "Разработка персонажей",
	"research": "Исследование материала",
	"budgeting": "Бюджетирование",
	"negotiation": "Переговоры",
	"planning": "Планирование",
	"casting": "Кастинг",
	"observation": "Наблюдательность",
	"composition": "Композиция кадра",
	"equipment": "Оборудование",
	"prop_design": "Реквизит",
	"organization": "Организация",
	"hygiene": "Санитарные нормы",
	"safety_compliance": "Техника безопасности",
	"menu_planning": "Планирование меню",
	"beverage_service": "Приготовление напитков",
	"service_speed": "Скорость обслуживания",
	"discretion": "Конфиденциальность",
	"market_research": "Анализ аудитории",
	"advertising": "Рекламные кампании",
	"social_media": "Социальные сети",
	"advertising_design": "Рекламный дизайн",
	"press_relations": "Работа с прессой",
	"crisis_management": "Антикризисные коммуникации",
}

const PROFESSION_SKILL_PROFILES: Dictionary = {
	"actor": [
		"acting", "improvisation", "diction", "movement",
		"screen_presence", "communication", "creativity", "reliability",
	],
	"extra": [
		"acting", "movement", "camera_work", "communication", "reliability",
	],
	"director": [
		"directing", "visual_storytelling", "actor_direction", "camera_work",
		"creativity", "management", "communication", "reliability",
	],
	"screenwriter": [
		"writing", "story_structure", "dialogue", "character_development",
		"research", "creativity", "reliability",
	],
	"producer": [
		"management", "budgeting", "negotiation", "planning",
		"communication", "reliability",
	],
	"casting_director": [
		"casting", "observation", "acting", "communication",
		"negotiation", "management", "reliability",
	],
	"camera_operator": [
		"camera_work", "composition", "lighting", "technical",
		"visual_storytelling", "reliability",
	],
	"technician": [
		"technical", "maintenance", "reliability", "communication",
	],
	"film_editor": [
		"editing", "visual_storytelling", "sound", "creativity", "reliability",
	],
	"production_designer": [
		"set_design", "creativity", "technical", "communication", "reliability",
	],
	"cleaner": [
		"maintenance", "organization", "hygiene", "reliability",
	],
	"maintenance_worker": [
		"maintenance", "technical", "safety_compliance", "reliability",
	],
	"security_guard": [
		"security", "observation", "communication", "safety_compliance", "reliability",
	],
	"chef": [
		"culinary", "menu_planning", "hygiene", "organization",
		"creativity", "reliability",
	],
	"bartender": [
		"hospitality", "beverage_service", "communication",
		"organization", "reliability",
	],
	"waiter": [
		"hospitality", "service_speed", "communication",
		"organization", "reliability",
	],
	"secretary": [
		"administration", "communication", "organization",
		"planning", "reliability",
	],
	"personal_assistant": [
		"communication", "administration", "organization",
		"planning", "discretion", "reliability",
	],
	"marketing_manager": [
		"marketing", "market_research", "creativity", "communication",
		"management", "planning", "reliability",
	],
	"pr_specialist": [
		"communication", "marketing", "writing", "press_relations",
		"negotiation", "crisis_management", "reliability",
	],
}

const PROFESSIONS: Dictionary = {
	"actor": {
		"title": "Актёр", "department": "creative", "primary_skill": "acting",
		"base_salary": 85, "task": "Репетирует сцены",
		"goal": "Получить главную роль в успешном фильме",
		"biographies": [
			"Начинал с небольших ролей и мечтает о большом прорыве на экране.",
			"Любит перевоплощаться и внимательно изучает характеры персонажей.",
			"Считает, что сильная игра начинается с наблюдения за обычной жизнью.",
		],
	},
	"extra": {
		"title": "Актёр массовки", "department": "creative", "primary_skill": "acting",
		"base_salary": 35, "task": "Участвует в массовых сценах",
		"goal": "Получить заметную роль с репликами",
		"biographies": [
			"Начинает карьеру в массовке и мечтает однажды оказаться в центре кадра.",
			"Умеет точно следовать указаниям режиссёра и работать в большой группе.",
		],
	},
	"director": {
		"title": "Режиссёр", "department": "creative", "primary_skill": "directing",
		"base_salary": 145, "task": "Разрабатывает постановку",
		"goal": "Снять собственный полнометражный фильм",
		"biographies": [
			"Известен вниманием к деталям и стремлением контролировать каждый кадр.",
			"Мечтает найти собственный визуальный язык и снять фильм, который запомнят.",
			"Умеет видеть сцену целиком, но продолжает учиться работать с командой.",
		],
	},
	"screenwriter": {
		"title": "Сценарист", "department": "creative", "primary_skill": "writing",
		"base_salary": 105, "task": "Работает над сценарием",
		"goal": "Продать сценарий крупной постановке",
		"biographies": [
			"Собирает идеи из разговоров, газет и случайных встреч.",
			"Верит, что хороший сценарий начинается с интересного героя.",
			"Постоянно переписывает черновики в поисках точной истории.",
		],
	},
	"producer": {
		"title": "Продюсер", "department": "creative", "primary_skill": "management",
		"base_salary": 135, "task": "Координирует производство",
		"goal": "Запустить крупный кинопроект",
		"biographies": [
			"Умеет сводить людей, сроки и ресурсы в один рабочий план.",
			"Строит карьеру на переговорах, дисциплине и умении решать проблемы.",
		],
	},
	"casting_director": {
		"title": "Кастинг-директор", "department": "creative", "primary_skill": "communication",
		"base_salary": 100, "task": "Подбирает актёров на роли",
		"goal": "Собрать актёрский состав для большого фильма",
		"biographies": [
			"Умеет замечать подходящих исполнителей там, где другие видят случайных людей.",
			"Знает актёрский рынок и поддерживает связи с агентами и артистами.",
		],
	},
	"camera_operator": {
		"title": "Оператор", "department": "production", "primary_skill": "camera_work",
		"base_salary": 90, "task": "Готовит операторское оборудование",
		"goal": "Стать главным оператором студии",
		"biographies": [
			"Увлечён светом и композицией, любит искать необычный ракурс.",
			"Начинал помощником на съёмках и постепенно освоил камеру.",
		],
	},
	"technician": {
		"title": "Техник", "department": "production", "primary_skill": "technical",
		"base_salary": 70, "task": "Обслуживает оборудование",
		"goal": "Возглавить технический отдел",
		"biographies": [
			"Любит разбираться в механизмах и не терпит неисправное оборудование.",
			"Считает, что хорошая съёмка начинается с надёжной техники.",
		],
	},
	"production_designer": {
		"title": "Художник-постановщик", "department": "production", "primary_skill": "set_design",
		"base_salary": 112, "task": "Разрабатывает оформление декораций",
		"goal": "Создать узнаваемый визуальный стиль фильма",
		"biographies": [
			"Продумывает пространство кадра и следит за визуальной целостностью фильма.",
			"Умеет превращать эскизы в выразительные съёмочные декорации.",
		],
	},
	"film_editor": {
		"title": "Монтажёр", "department": "production", "primary_skill": "editing",
		"base_salary": 98, "task": "Монтирует отснятые сцены",
		"goal": "Собрать фильм, который станет классикой",
		"biographies": [
			"Внимательно выстраивает ритм истории и ищет точный монтажный переход.",
			"Считает, что хороший монтаж раскрывает сильные стороны актёрской игры.",
		],
	},
	"cleaner": {
		"title": "Уборщик", "department": "facility", "primary_skill": "maintenance",
		"base_salary": 42, "task": "Убирает помещения студии",
		"goal": "Стать старшим сотрудником хозяйственного отдела",
		"biographies": [
			"Поддерживает чистоту в помещениях и замечает беспорядок раньше остальных.",
			"Считает, что комфортная студия начинается с ежедневной заботы о пространстве.",
		],
	},
	"maintenance_worker": {
		"title": "Рабочий по обслуживанию", "department": "facility", "primary_skill": "maintenance",
		"base_salary": 60, "task": "Обслуживает здания и помещения",
		"goal": "Возглавить службу эксплуатации",
		"biographies": [
			"Умеет чинить мебель, двери и бытовое оборудование.",
			"Быстро реагирует на заявки и поддерживает помещения в рабочем состоянии.",
		],
	},
	"security_guard": {
		"title": "Охранник", "department": "facility", "primary_skill": "security",
		"base_salary": 56, "task": "Патрулирует территорию студии",
		"goal": "Стать начальником охраны",
		"biographies": [
			"Внимательно следит за пропускным режимом и безопасностью территории.",
			"Сохраняет спокойствие и умеет действовать по инструкции.",
		],
	},
	"chef": {
		"title": "Повар", "department": "catering", "primary_skill": "culinary",
		"base_salary": 86, "task": "Готовит блюда для сотрудников",
		"goal": "Возглавить кухню киностудии",
		"biographies": [
			"Любит готовить для больших коллективов и умеет планировать кухонную работу.",
			"Считает, что хорошая еда помогает съёмочной группе выдерживать длинные смены.",
		],
	},
	"bartender": {
		"title": "Бармен", "department": "catering", "primary_skill": "hospitality",
		"base_salary": 62, "task": "Обслуживает бар и готовит напитки",
		"goal": "Открыть собственное заведение",
		"biographies": [
			"Легко находит общий язык с людьми и умеет работать в оживлённой обстановке.",
			"Следит за запасами бара и помнит предпочтения постоянных посетителей.",
		],
	},
	"waiter": {
		"title": "Официант", "department": "catering", "primary_skill": "hospitality",
		"base_salary": 46, "task": "Обслуживает посетителей столовой",
		"goal": "Стать управляющим заведением",
		"biographies": [
			"Умеет быстро обслуживать гостей и сохранять вежливость в час пик.",
			"Знает, как организовать работу зала во время большого обеденного перерыва.",
		],
	},
	"secretary": {
		"title": "Секретарь", "department": "administration", "primary_skill": "administration",
		"base_salary": 66, "task": "Работает с документами и расписанием",
		"goal": "Стать руководителем административного отдела",
		"biographies": [
			"Умеет организовывать встречи, документы и рабочее расписание.",
			"Сохраняет спокойствие даже при плотном графике руководства.",
		],
	},
	"personal_assistant": {
		"title": "Личный ассистент звезды", "department": "administration", "primary_skill": "communication",
		"base_salary": 98, "task": "Сопровождает назначенную звезду",
		"goal": "Стать персональным менеджером известного артиста",
		"biographies": [
			"Умеет управлять плотным расписанием и решать повседневные вопросы знаменитостей.",
			"Знает, как защищать время подопечного и координировать его встречи.",
		],
	},
	"marketing_manager": {
		"title": "Маркетолог", "department": "marketing", "primary_skill": "marketing",
		"base_salary": 112, "task": "Планирует продвижение фильмов",
		"goal": "Возглавить маркетинг успешной киностудии",
		"biographies": [
			"Изучает аудиторию и умеет находить сильные стороны будущего фильма.",
			"Любит превращать творческую идею в понятную рекламную кампанию.",
		],
	},
	"pr_specialist": {
		"title": "PR-специалист", "department": "marketing", "primary_skill": "communication",
		"base_salary": 96, "task": "Работает с репутацией студии и фильмов",
		"goal": "Стать директором по связям с общественностью",
		"biographies": [
			"Умеет выстраивать отношения с журналистами и организовывать пресс-мероприятия.",
			"Следит за общественной реакцией и помогает студии правильно отвечать на события.",
		],
	},
}

const SPECIALIZATIONS: Dictionary = {
	"technician": [
		{"id": "lighting", "title": "Свет", "skill_id": "lighting"},
		{"id": "sound", "title": "Звук", "skill_id": "sound"},
		{"id": "equipment", "title": "Оборудование", "skill_id": "equipment"},
		{"id": "editing", "title": "Монтаж", "skill_id": "editing"},
	],
	"production_designer": [
		{"id": "sets", "title": "Декорации", "skill_id": "set_design"},
		{"id": "costumes", "title": "Костюмы", "skill_id": "costume_design"},
		{"id": "makeup", "title": "Грим", "skill_id": "makeup"},
		{"id": "props", "title": "Реквизит", "skill_id": "prop_design"},
	],
	"marketing_manager": [
		{"id": "advertising", "title": "Реклама", "skill_id": "advertising"},
		{"id": "social_media", "title": "Социальные сети", "skill_id": "social_media"},
		{"id": "design", "title": "Рекламный дизайн", "skill_id": "advertising_design"},
	],
}

static func get_department_ids() -> Array[String]:
	return DEPARTMENT_ORDER.duplicate()


static func get_department_title(department_id: String) -> String:
	return str(DEPARTMENT_TITLES.get(department_id, "Другие сотрудники"))


static func get_department_title_for_profession(profession_id: String) -> String:
	var profession: Dictionary = get_profession(profession_id)
	return get_department_title(str(profession.get("department", "")))


static func get_profession_ids() -> Array[String]:
	var result: Array[String] = []
	for profession_id in PROFESSIONS.keys():
		result.append(str(profession_id))
	result.sort()
	return result


static func get_profession_ids_for_department(department_id: String) -> Array[String]:
	var result: Array[String] = []
	for profession_id in PROFESSIONS.keys():
		var profession: Dictionary = PROFESSIONS[profession_id]
		if str(profession.get("department", "")) == department_id:
			result.append(str(profession_id))
	result.sort()
	return result


static func has_profession(profession_id: String) -> bool:
	return PROFESSIONS.has(profession_id)


static func normalize_profession_id(profession_id: String) -> String:
	return profession_id if PROFESSIONS.has(profession_id) else "technician"


static func get_profession(profession_id: String) -> Dictionary:
	return PROFESSIONS.get(
		normalize_profession_id(profession_id),
		PROFESSIONS["technician"]
	)


static func get_profession_title(profession_id: String) -> String:
	var profession: Dictionary = get_profession(profession_id)
	return str(profession.get("title", "Сотрудник"))


static func get_primary_skill_id(profession_id: String) -> String:
	var profession: Dictionary = get_profession(profession_id)
	return str(profession.get("primary_skill", "reliability"))


static func get_primary_skill_title(profession_id: String) -> String:
	return str(SKILL_TITLES.get(get_primary_skill_id(profession_id), "Основной навык"))


static func get_base_salary(profession_id: String) -> int:
	var profession: Dictionary = get_profession(profession_id)
	return maxi(int(profession.get("base_salary", 70)), 1)


static func get_default_task(profession_id: String) -> String:
	var profession: Dictionary = get_profession(profession_id)
	return str(profession.get("task", "Выполняет рабочие задачи"))


static func get_career_goal(profession_id: String) -> String:
	var profession: Dictionary = get_profession(profession_id)
	return str(profession.get("goal", "Развиваться в своей профессии"))


static func get_biographies(profession_id: String) -> Array:
	var profession: Dictionary = get_profession(profession_id)
	return profession.get("biographies", ["Пришёл в киноиндустрию, чтобы построить карьеру."])


static func get_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for skill_id in SKILL_TITLES.keys():
		result.append(str(skill_id))
	result.sort()
	return result


static func get_skill_titles() -> Dictionary:
	return SKILL_TITLES.duplicate(true)


static func get_skill_title(skill_id: String) -> String:
	return str(SKILL_TITLES.get(skill_id, "Неизвестный навык"))


static func get_profession_skill_ids(
	profession_id: String,
	specialization_id: String = ""
) -> Array[String]:
	var result: Array[String] = []
	var profile: Array = PROFESSION_SKILL_PROFILES.get(
		normalize_profession_id(profession_id),
		[]
	)
	for skill_id in profile:
		var normalized_skill_id: String = str(skill_id)
		if SKILL_TITLES.has(normalized_skill_id) and not result.has(normalized_skill_id):
			result.append(normalized_skill_id)

	var specialization_skill_id: String = get_specialization_skill_id(
		profession_id,
		specialization_id
	)
	if (
		not specialization_skill_id.is_empty()
		and SKILL_TITLES.has(specialization_skill_id)
		and not result.has(specialization_skill_id)
	):
		result.append(specialization_skill_id)

	return result


static func get_specialization_ids(profession_id: String) -> Array[String]:
	var result: Array[String] = []
	var options: Array = SPECIALIZATIONS.get(normalize_profession_id(profession_id), [])
	for option in options:
		result.append(str(option.get("id", "")))
	return result


static func get_specialization_title(profession_id: String, specialization_id: String) -> String:
	var options: Array = SPECIALIZATIONS.get(normalize_profession_id(profession_id), [])
	for option in options:
		if str(option.get("id", "")) == specialization_id:
			return str(option.get("title", ""))
	return ""


static func get_specialization_skill_id(profession_id: String, specialization_id: String) -> String:
	var options: Array = SPECIALIZATIONS.get(normalize_profession_id(profession_id), [])
	for option in options:
		if str(option.get("id", "")) == specialization_id:
			return str(option.get("skill_id", ""))
	return ""


static func get_schedule(profession_id: String) -> Dictionary:
	var normalized_profession_id: String = normalize_profession_id(profession_id)
	if CHARACTER_SYSTEM_V2_CORE_PROFESSION_IDS.has(normalized_profession_id):
		return {
			"shift_start_hour": 8,
			"shift_end_hour": 17,
			"break_start_hour": 12,
			"break_end_hour": 13,
		}

	var department_id: String = str(
		get_profession(normalized_profession_id).get("department", "creative")
	)
	match department_id:
		"catering":
			return {
				"shift_start_hour": 6,
				"shift_end_hour": 15,
				"break_start_hour": 10,
				"break_end_hour": 11,
			}
		"facility":
			return {
				"shift_start_hour": 7,
				"shift_end_hour": 16,
				"break_start_hour": 11,
				"break_end_hour": 12,
			}
		"production":
			return {
				"shift_start_hour": 7,
				"shift_end_hour": 16,
				"break_start_hour": 11,
				"break_end_hour": 12,
			}
		"marketing", "administration":
			return {
				"shift_start_hour": 9,
				"shift_end_hour": 18,
				"break_start_hour": 13,
				"break_end_hour": 14,
			}
		_:
			return {
				"shift_start_hour": 8,
				"shift_end_hour": 17,
				"break_start_hour": 12,
				"break_end_hour": 13,
			}
