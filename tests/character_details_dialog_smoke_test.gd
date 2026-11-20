extends "res://tests/smoke_test_base.gd"

const DETAILS_DIALOG_SCRIPT = preload(
	"res://scripts/presentation/characters/character_details_dialog.gd"
)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var dialog: Control = DETAILS_DIALOG_SCRIPT.new()
	root.add_child(dialog)
	var skill_ids: Array[String] = [
		"acting", "improvisation", "diction", "movement",
		"screen_presence", "communication", "creativity", "reliability",
	]
	var skills: Dictionary = {}
	var caps: Dictionary = {}
	for skill_id in skill_ids:
		skills[skill_id] = 42.0
		caps[skill_id] = 75.0
	dialog.call(
		"open_profile",
		{
			"name": "Анна Тестова",
			"initials": "АТ",
			"profession": "Актёр · Драма · 27 лет",
			"profession_id": "actor",
			"specialization_id": "",
			"status": "Репетирует в павильоне",
			"age": 27,
			"experience": 4.5,
			"popularity": 68.0,
			"recognition": 54.0,
			"salary": 125,
			"growth_remaining": 12.0,
			"growth_total": 24.0,
			"needs": {"energy": 72.0, "morale": 81.0, "stress": 23.0},
			"fitness": 77.0,
			"show_fitness": true,
			"skills": skills,
			"skill_caps": caps,
			"biography": "Тестовая биография персонажа.",
			"career_goal": "Получить главную роль.",
			"personality": "Амбиции 70% · Общительность 60%",
			"contract": "Бессрочный · 125 ед. / день",
		}
	)
	_expect(
		bool(dialog.call("is_open")),
		"Opening a character profile must display the modal dialog."
	)
	var name_label: Label = dialog.get("_name_label") as Label
	var profession_label: Label = dialog.get("_profession_label") as Label
	_expect(
		name_label != null
		and name_label.text == "Анна Тестова"
		and profession_label.text.contains("Актёр"),
		"The dialog header must show the employee identity and profession."
	)
	var metrics: Dictionary = dialog.get("_metric_values")
	var popularity_label: Label = metrics.get("popularity") as Label
	_expect(
		popularity_label != null and popularity_label.text == "68 / 100",
		"Career metrics must display the supplied popularity value."
	)
	var need_bars: Dictionary = dialog.get("_need_bars")
	var energy_bar: ProgressBar = need_bars.get("energy") as ProgressBar
	var fitness_bar: ProgressBar = need_bars.get("fitness") as ProgressBar
	_expect(
		energy_bar != null
		and is_equal_approx(energy_bar.value, 72.0)
		and fitness_bar != null
		and fitness_bar.visible
		and is_equal_approx(fitness_bar.value, 77.0),
		"Need bars must reflect the character's needs and actor fitness."
	)
	var skill_list: VBoxContainer = dialog.get("_skill_list") as VBoxContainer
	_expect(
		skill_list != null and skill_list.get_child_count() == skill_ids.size(),
		"The profile must display the profession-specific skill list."
	)
	dialog.call("close_dialog")
	_expect(
		not bool(dialog.call("is_open")),
		"The close action must dismiss the profile dialog."
	)
	dialog.queue_free()
	_finish_test("CharacterDetailsDialogSmokeTest")
