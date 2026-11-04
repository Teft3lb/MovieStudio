extends RefCounted
class_name ScriptGenerator

const FILM_SCRIPT_DATA_SCRIPT = preload(
	"res://scripts/domain/script_department/film_script_data.gd"
)

const GENRES: Dictionary = {
	"drama": {
		"title": "Драма",
		"market_base_score": 74.0,
		"titles": ["Последний рубеж", "Тихая гавань", "Цена обещания", "Письма домой"],
		"loglines": [
			"Человек вынужден сделать выбор, который изменит судьбы близких.",
			"Старая тайна возвращается и разрушает привычный порядок жизни.",
			"Несколько незнакомцев учатся доверять друг другу перед решающим испытанием.",
		],
		"locations": ["Городская площадь", "Семейный дом", "Вокзал", "Больничный коридор", "Набережная"],
		"actions": ["Герой сталкивается с последствиями давнего решения.", "Союзники спорят о цене правды.", "Неожиданная встреча меняет планы персонажей.", "Герой решается рассказать то, что скрывал годами."],
		"dialogues": ["Я больше не могу делать вид, что ничего не произошло.", "Иногда правильный выбор оказывается самым трудным.", "Ты должен услышать всю историю, прежде чем решать."],
	},
	"comedy": {
		"title": "Комедия",
		"market_base_score": 70.0,
		"titles": ["Невероятная путаница", "План почти сработал", "Соседи сверху", "День наоборот"],
		"loglines": [
			"Нелепое недоразумение превращает обычный день в череду катастроф.",
			"Герой пытается скрыть маленькую ошибку, создавая всё более крупные проблемы.",
			"Случайная компания решает задачу совершенно неподходящими методами.",
		],
		"locations": ["Гостиничный холл", "Офис", "Ресторан", "Прачечная", "Городская улица"],
		"actions": ["Персонажи путают важные документы и обвиняют друг друга.", "Неудачная попытка всё исправить создаёт новую проблему.", "Герой попадает в ситуацию, из которой невозможно выйти незамеченным.", "Секрет раскрывается в самый неподходящий момент."],
		"dialogues": ["У меня был план. Он был хорошим ровно до этой минуты.", "Давайте спокойно обсудим, почему здесь стоит лошадь.", "Я могу объяснить. Но сначала нужно убрать последствия."],
	},
	"action": {
		"title": "Боевик",
		"market_base_score": 72.0,
		"titles": ["Красная тревога", "Последний приказ", "На грани скорости", "Операция «Феникс»"],
		"loglines": [
			"Команда должна остановить опасную операцию до наступления рассвета.",
			"Бывший агент возвращается, когда угроза достигает его родного города.",
			"Герой обнаруживает предательство внутри собственной команды.",
		],
		"locations": ["Промышленный порт", "Крыша небоскрёба", "Подземный переход", "Склад", "Шоссе"],
		"actions": ["Команда прорывается через охраняемый объект.", "Герой обнаруживает след, ведущий к организатору заговора.", "План срывается, и персонажам приходится импровизировать.", "Соперники сходятся в решающем противостоянии."],
		"dialogues": ["У нас осталось мало времени. Действуем сейчас.", "Ты знал, что это ловушка, и всё равно пришёл.", "Пока мы вместе, у них нет преимущества."],
	},
	"romance": {
		"title": "Мелодрама",
		"market_base_score": 67.0,
		"titles": ["Встреча под дождём", "Пока горят огни", "Случайное письмо", "Время для двоих"],
		"loglines": [
			"Два человека из разных миров находят общий язык вопреки обстоятельствам.",
			"Случайное письмо заставляет героев пересмотреть прошлое.",
			"Дружба постепенно превращается в чувство, которое трудно признать.",
		],
		"locations": ["Кафе у вокзала", "Парк", "Театр", "Набережная", "Старый книжный магазин"],
		"actions": ["Герои встречаются после долгой разлуки.", "Неловкий разговор открывает давно скрываемые чувства.", "Персонажи пытаются решить конфликт, не потеряв доверие.", "Герой делает шаг навстречу, рискуя получить отказ."],
		"dialogues": ["Я думал, что время всё изменит, но ошибался.", "Мне не нужен идеальный ответ. Мне нужна честность.", "Если мы уйдём сейчас, второго шанса может не быть."],
	},
	"mystery": {
		"title": "Детектив",
		"market_base_score": 77.0,
		"titles": ["Тень на стекле", "Дело без свидетеля", "Пятый ключ", "Комната номер девять"],
		"loglines": [
			"Следователь ищет связь между уликами, которые никто не считает важными.",
			"Исчезновение человека раскрывает тайну целого района.",
			"Каждый свидетель скрывает часть правды, а время работает против героя.",
		],
		"locations": ["Архив", "Полицейский участок", "Старая гостиница", "Ночной переулок", "Частный кабинет"],
		"actions": ["Герой находит улику, противоречащую официальной версии.", "Свидетель меняет показания после неожиданного звонка.", "Команда сопоставляет детали и обнаруживает скрытую связь.", "Разгадка оказывается ближе, чем предполагали герои."],
		"dialogues": ["Эта деталь не случайна. Кто-то хотел, чтобы мы её заметили.", "Вы рассказали почти всё. Осталось объяснить одну вещь.", "Ответ был перед нами с самого начала."],
	},
	"adventure": {
		"title": "Приключения",
		"market_base_score": 73.0,
		"titles": ["За краем карты", "Остров забытых имён", "Путь к горизонту", "Секрет старого маяка"],
		"loglines": [
			"Небольшая экспедиция отправляется туда, откуда ещё никто не возвращался.",
			"Старинная карта приводит героев к открытию, способному изменить историю.",
			"Команда ищет пропавшего исследователя и находит нечто неожиданное.",
		],
		"locations": ["Горный перевал", "Заброшенный храм", "Лесная тропа", "Морской берег", "Пещера"],
		"actions": ["Экспедиция обнаруживает следы неизвестного присутствия.", "Герои преодолевают препятствие и теряют часть припасов.", "Старая карта открывает путь к следующей точке маршрута.", "Команда принимает решение продолжить путь несмотря на риск."],
		"dialogues": ["Мы прошли слишком далеко, чтобы повернуть назад.", "Посмотри на карту. Здесь отмечено то, чего не должно существовать.", "Сначала найдём остальных, потом будем задавать вопросы."],
	},
	"science_fiction": {
		"title": "Научная фантастика",
		"market_base_score": 75.0,
		"titles": ["Сигнал из завтра", "Орбита молчания", "Город после звёзд", "Протокол «Аврора»"],
		"loglines": [
			"Исследователи получают сигнал, который, возможно, пришёл из будущего.",
			"Экспедиция обнаруживает технологию, меняющую представление о человечестве.",
			"Герои пытаются предотвратить эксперимент с непредсказуемыми последствиями.",
		],
		"locations": ["Исследовательская станция", "Орбитальный модуль", "Подземная лаборатория", "Город будущего", "Командный центр"],
		"actions": ["Система фиксирует аномалию, которую невозможно объяснить.", "Герой обнаруживает скрытый протокол в архиве станции.", "Команда спорит, следует ли продолжать эксперимент.", "Последний запуск меняет условия всей операции."],
		"dialogues": ["Это не ошибка датчика. Сигнал повторяется.", "Мы создали инструмент, но не подумали о последствиях.", "Если расчёты верны, у нас осталась одна попытка."],
	},
}

const ROLE_TITLES: Array[String] = [
	"Главный герой",
	"Союзник",
	"Соперник",
	"Наставник",
	"Антагонист",
	"Свидетель",
	"Комический персонаж",
	"Второстепенный герой",
]

const FIRST_NAMES: Array[String] = [
	"Эдвард", "Мэри", "Джеймс", "Элеонора", "Генри", "Виктория",
	"Артур", "Клара", "Фрэнк", "Маргарет", "Томас", "Рут",
	"Оливер", "Анна", "Чарльз", "Эвелин",
]

const LAST_NAMES: Array[String] = [
	"Монтгомери", "Уинслоу", "Фэйрчайлд", "Харпер", "Беннетт",
	"Пембертон", "Мерсер", "Коллинз", "Уитмор", "Холлоуэй",
	"Кингсли", "Брукс", "Синклер", "Рид",
]

const SCENE_BEATS: Array[String] = [
	"Завязка",
	"Первое осложнение",
	"Развитие конфликта",
	"Неожиданное открытие",
	"Поворотный момент",
	"Кульминация",
	"Развязка",
]


static func get_genre_ids() -> Array[String]:
	var result: Array[String] = []
	for genre_id in GENRES.keys():
		result.append(str(genre_id))
	result.sort()
	return result


static func get_genre_title(genre_id: String) -> String:
	var genre: Dictionary = GENRES.get(genre_id, GENRES["drama"])
	return str(genre.get("title", "Драма"))


func generate(
	writer: Variant,
	genre_id: String,
	requested_scene_count: int,
	requested_role_count: int,
	seed: int,
	script_id: String
) -> RefCounted:
	if writer == null or str(writer.profession_id) != "screenwriter":
		return null

	var normalized_genre_id: String = (
		genre_id if GENRES.has(genre_id) else "drama"
	)
	var genre: Dictionary = GENRES[normalized_genre_id]
	var scene_count: int = clampi(requested_scene_count, 3, 20)
	var role_count: int = clampi(requested_role_count, 1, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var result: Variant = FILM_SCRIPT_DATA_SCRIPT.new()
	result.id = script_id
	result.genre_id = normalized_genre_id
	result.genre_title = str(genre.get("title", "Драма"))
	result.writer_id = str(writer.id)
	result.writer_name = str(writer.get_full_name())
	result.scene_count = scene_count
	result.role_count = role_count

	var titles: Array = genre.get("titles", [])
	result.title = str(titles[rng.randi_range(0, titles.size() - 1)])
	var loglines: Array = genre.get("loglines", [])
	result.logline = str(loglines[rng.randi_range(0, loglines.size() - 1)])

	var cast_names: Array[Dictionary] = []
	for role_index in range(role_count):
		var first_name: String = FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)]
		var last_name: String = LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]
		var role_title: String = ROLE_TITLES[
			posmod(role_index, ROLE_TITLES.size())
		]
		var cast_entry: Dictionary = {
			"role_id": "ROLE-%02d" % (role_index + 1),
			"role_title": role_title,
			"character_name": "%s %s" % [first_name, last_name],
		}
		cast_names.append(cast_entry)
	result.cast = cast_names

	var locations: Array = genre.get("locations", [])
	var actions: Array = genre.get("actions", [])
	var dialogues: Array = genre.get("dialogues", [])
	for scene_index in range(scene_count):
		var location: String = str(
			locations[rng.randi_range(0, locations.size() - 1)]
		)
		var action: String = str(
			actions[rng.randi_range(0, actions.size() - 1)]
		)
		var dialogue: String = str(
			dialogues[rng.randi_range(0, dialogues.size() - 1)]
		)
		var beat_index: int = int(
			roundf(
				float(scene_index) / float(maxi(scene_count - 1, 1))
				* float(SCENE_BEATS.size() - 1)
			)
		)
		var present_role_count: int = mini(
			role_count,
			rng.randi_range(1, mini(role_count, 3))
		)
		var present_roles: Array[String] = []
		var used_roles: Dictionary = {}
		while present_roles.size() < present_role_count:
			var role_pick: int = rng.randi_range(0, role_count - 1)
			if used_roles.has(role_pick):
				continue
			used_roles[role_pick] = true
			present_roles.append(
				str(cast_names[role_pick].get("character_name", ""))
			)

		var speaker: String = str(cast_names[0].get("character_name", "Герой"))
		result.scenes.append({
			"scene_id": "SCN-%02d" % (scene_index + 1),
			"scene_number": scene_index + 1,
			"beat": SCENE_BEATS[beat_index],
			"location": location,
			"action": action,
			"dialogue": "%s: «%s»" % [speaker, dialogue],
			"characters": present_roles,
		})

	var skills: Dictionary = writer.skills
	var writing_skill: float = float(skills.get("writing", 40.0))
	var structure_skill: float = float(skills.get("story_structure", 40.0))
	var dialogue_skill: float = float(skills.get("dialogue", 40.0))
	var creativity_skill: float = float(skills.get("creativity", 40.0))
	var research_skill: float = float(skills.get("research", 40.0))
	var writer_score: float = (
		writing_skill * 0.34
		+ structure_skill * 0.25
		+ dialogue_skill * 0.16
		+ creativity_skill * 0.15
		+ research_skill * 0.10
	)
	var scene_fit: float = clampf(
		100.0 - absf(float(scene_count) - 9.0) * 3.5,
		55.0,
		100.0
	)
	var role_fit: float = clampf(
		100.0 - absf(float(role_count) - 3.0) * 6.0,
		52.0,
		100.0
	)
	var genre_score: float = float(genre.get("market_base_score", 70.0))
	var variance: float = rng.randf_range(-4.0, 4.0)
	result.potential_score = roundi(clampf(
		writer_score * 0.58
		+ scene_fit * 0.14
		+ role_fit * 0.10
		+ genre_score * 0.18
		+ variance,
		0.0,
		100.0
	))
	result.potential_stars = _score_to_stars(result.potential_score)
	result.popularity_modifier = snappedf(
		0.80 + float(result.potential_score) / 250.0,
		0.01
	)
	result.logline = result.logline
	return result


static func _score_to_stars(score: int) -> int:
	if score >= 88:
		return 5
	if score >= 74:
		return 4
	if score >= 60:
		return 3
	if score >= 45:
		return 2
	return 1
