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
		"title": "Кинооператор", "department": "production", "primary_skill": "camera_work",
		"base_salary": 90, "task": "Готовит камеру и снимает материал",
		"goal": "Стать главным оператором студии",
		"biographies": [
			"Увлечён светом и композицией, любит искать необычный ракурс.",
			"Начинал помощником на съёмках и постепенно освоил камеру.",
		],
	},
	"assistant_camera_operator": {
		"title": "Ассистент оператора", "department": "production", "primary_skill": "camera_work",
		"base_salary": 62, "task": "Готовит объективы и оборудование камеры",
		"goal": "Стать самостоятельным кинооператором",
		"biographies": [
			"Следит за объективами и настройками, чтобы съёмка не теряла ни минуты.",
			"Учится у опытных операторов и постепенно осваивает сложную технику.",
		],
	},
	"gaffer": {
		"title": "Главный осветитель", "department": "production", "primary_skill": "lighting",
		"base_salary": 88, "task": "Выставляет свет на съёмочной площадке",
		"goal": "Возглавить световую группу крупной постановки",
		"biographies": [
			"Умеет превращать обычный павильон в выразительное кинематографическое пространство.",
			"Знает осветительное оборудование и любит сложные световые схемы.",
		],
	},
	"lighting_technician": {
		"title": "Техник по свету", "department": "production", "primary_skill": "lighting",
		"base_salary": 68, "task": "Обслуживает осветительное оборудование",
		"goal": "Стать главным осветителем",
		"biographies": [
			"Подготавливает приборы, кабели и стойки перед началом съёмок.",
			"Быстро устраняет неполадки и внимательно соблюдает технику безопасности.",
		],
	},
	"sound_engineer": {
		"title": "Звукорежиссёр", "department": "production", "primary_skill": "sound",
		"base_salary": 92, "task": "Настраивает запись звука",
		"goal": "Отвечать за звук в большом кинопроекте",
		"biographies": [
			"Слышит детали, которые ускользают от остальных членов съёмочной группы.",
			"Считает чистую запись звука обязательной частью хорошего фильма.",
		],
	},
	"boom_operator": {
		"title": "Оператор микрофона", "department": "production", "primary_skill": "sound",
		"base_salary": 64, "task": "Работает с микрофоном на площадке",
		"goal": "Стать звукорежиссёром",
		"biographies": [
			"Умеет двигаться бесшумно и держать микрофон точно вне границ кадра.",
			"Начинал с небольших площадок и хочет отвечать за звук целиком.",
		],
	},
	"film_editor": {
		"title": "Монтажёр", "department": "production", "primary_skill": "editing",
		"base_salary": 100, "task": "Монтирует отснятый материал",
		"goal": "Смонтировать фильм, который получит признание критиков",
		"biographies": [
			"Чувствует ритм сцены и умеет находить сильные моменты в отснятом материале.",
			"Любит превращать разрозненные дубли в цельную историю.",
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
	"set_builder": {
		"title": "Рабочий декорационного цеха", "department": "production", "primary_skill": "maintenance",
		"base_salary": 72, "task": "Строит и ремонтирует декорации",
		"goal": "Стать мастером декорационного цеха",
		"biographies": [
			"Умеет работать с деревом, крепежом и материалами для декораций.",
			"Любит видеть, как пустой павильон превращается в кинематографическую площадку.",
		],
	},
	"costume_designer": {
		"title": "Художник по костюмам", "department": "production", "primary_skill": "costume_design",
		"base_salary": 96, "task": "Подбирает и готовит костюмы",
		"goal": "Создать костюмы для исторического фильма",
		"biographies": [
			"Внимательно изучает эпохи и характеры, подбирая одежду для персонажей.",
			"Умеет сочетать практичность костюма с визуальным образом героя.",
		],
	},
	"makeup_artist": {
		"title": "Гримёр", "department": "production", "primary_skill": "makeup",
		"base_salary": 84, "task": "Готовит актёров к съёмкам",
		"goal": "Возглавить гримёрный отдел",
		"biographies": [
			"Работает с гримом и причёсками, помогая актёрам перевоплощаться.",
			"Любит сложные образы и внимательно следит за непрерывностью грима между дублями.",
		],
	},
	"props_master": {
		"title": "Реквизитор", "department": "production", "primary_skill": "technical",
		"base_salary": 74, "task": "Готовит реквизит для съёмок",
		"goal": "Возглавить реквизиторскую службу",
		"biographies": [
			"Следит, чтобы каждый предмет в кадре находился на своём месте.",
			"Умеет быстро находить нужный реквизит и поддерживать порядок в мастерской.",
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
	"electrician": {
		"title": "Электрик", "department": "facility", "primary_skill": "technical",
		"base_salary": 82, "task": "Проверяет электросети и оборудование",
		"goal": "Стать главным инженером студии",
		"biographies": [
			"Знает, насколько важны исправные сети для безопасной работы павильонов.",
			"Предпочитает устранять неисправности до того, как они остановят производство.",
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
	"sous_chef": {
		"title": "Помощник повара", "department": "catering", "primary_skill": "culinary",
		"base_salary": 66, "task": "Помогает готовить блюда на кухне",
		"goal": "Стать шеф-поваром",
		"biographies": [
			"Быстро готовит заготовки и следит за порядком на рабочем месте.",
			"Учится у шеф-повара и хочет однажды отвечать за меню.",
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
	"cafeteria_worker": {
		"title": "Работник столовой", "department": "catering", "primary_skill": "hospitality",
		"base_salary": 43, "task": "Подготавливает столовую к приёму сотрудников",
		"goal": "Стать старшим смены столовой",
		"biographies": [
			"Готовит зал к обеду и помогает поддерживать порядок в столовой.",
			"Знает повседневные потребности большого коллектива студии.",
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
	"receptionist": {
		"title": "Администратор ресепшена", "department": "administration", "primary_skill": "communication",
		"base_salary": 52, "task": "Встречает гостей и посетителей",
		"goal": "Стать офис-менеджером",
		"biographies": [
			"Первым встречает гостей студии и помогает им сориентироваться.",
			"Умеет работать с посетителями, звонками и входящими запросами.",
		],
	},
	"hr_manager": {
		"title": "HR-менеджер", "department": "administration", "primary_skill": "administration",
		"base_salary": 102, "task": "Работает с наймом и кадровыми документами",
		"goal": "Возглавить кадровую службу крупной студии",
		"biographies": [
			"Умеет оценивать кандидатов и находить специалистов для разных отделов.",
			"Считает, что сильная студия начинается с правильной команды.",
		],
	},
	"accountant": {
		"title": "Бухгалтер", "department": "administration", "primary_skill": "administration",
		"base_salary": 106, "task": "Ведёт финансовые документы",
		"goal": "Стать финансовым директором",
		"biographies": [
			"Любит точность и умеет находить ошибки в финансовых документах.",
			"Следит за счетами и помогает руководству понимать расходы студии.",
		],
	},
	"office_manager": {
		"title": "Офис-менеджер", "department": "administration", "primary_skill": "administration",
		"base_salary": 86, "task": "Организует повседневную работу офиса",
		"goal": "Возглавить административную службу",
		"biographies": [
			"Следит за тем, чтобы офисная работа не мешала творческому процессу.",
			"Координирует заявки, помещения и повседневные организационные вопросы.",
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
	"advertising_manager": {
		"title": "Рекламный менеджер", "department": "marketing", "primary_skill": "marketing",
		"base_salary": 106, "task": "Организует рекламные кампании",
		"goal": "Провести национальную рекламную кампанию фильма",
		"biographies": [
			"Координирует рекламные материалы, сроки и размещение объявлений.",
			"Умеет распределять рекламный бюджет между разными каналами.",
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
	"social_media_manager": {
		"title": "SMM-специалист", "department": "marketing", "primary_skill": "marketing",
		"base_salary": 86, "task": "Ведёт каналы студии и фильмов",
		"goal": "Создать крупное сообщество поклонников студии",
		"biographies": [
			"Следит за реакцией аудитории и умеет поддерживать интерес к проектам.",
			"Создаёт публикации и планирует контент для каналов студии.",
		],
	},
	"graphic_designer": {
		"title": "Дизайнер рекламы", "department": "marketing", "primary_skill": "creativity",
		"base_salary": 92, "task": "Создаёт афиши и рекламные материалы",
		"goal": "Разработать визуальный стиль крупной кинорекламы",
		"biographies": [
			"Умеет превращать идею фильма в выразительную афишу и рекламный образ.",
			"Работает с типографикой, цветом и композицией.",
		],
	},
	"press_officer": {
		"title": "Пресс-секретарь", "department": "marketing", "primary_skill": "communication",
		"base_salary": 92, "task": "Готовит пресс-релизы и общается с прессой",
		"goal": "Стать руководителем пресс-службы",
		"biographies": [
			"Умеет готовить официальные заявления и отвечать на запросы прессы.",
			"Помогает организовывать интервью, премьеры и пресс-показы.",
		],
	},
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
	return PROFESSIONS.get(normalize_profession_id(profession_id), PROFESSIONS["technician"])


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


static func get_schedule(profession_id: String) -> Dictionary:
	var department_id: String = str(get_profession(profession_id).get("department", "creative"))
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
