extends "res://tests/smoke_test_base.gd"

const STUDIO_HUD_SCRIPT = preload(
	"res://scripts/presentation/ui/studio_hud.gd"
)
const PROFILE_VIEW_SCRIPT = preload(
	"res://scripts/presentation/characters/employee_profile_panel_controller.gd"
)

var _contract_selection_count: int = 0
var _hire_count: int = 0
var _dismiss_count: int = 0
var _dismiss_confirmed_count: int = 0
var _dispatch_count: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _on_contract_type_selected(_index: int) -> void:
	_contract_selection_count += 1


func _on_hire_requested() -> void:
	_hire_count += 1


func _on_dismiss_requested() -> void:
	_dismiss_count += 1


func _on_dismiss_confirmed() -> void:
	_dismiss_confirmed_count += 1


func _on_dispatch_requested() -> void:
	_dispatch_count += 1


func _run_tests() -> void:
	var hud: Node = STUDIO_HUD_SCRIPT.new()
	root.add_child(hud)

	var view: RefCounted = PROFILE_VIEW_SCRIPT.new()
	view.call(
		"setup",
		Callable(self, "_on_contract_type_selected"),
		Callable(self, "_on_hire_requested"),
		Callable(self, "_on_dismiss_requested"),
		Callable(self, "_on_dismiss_confirmed"),
		Callable(self, "_on_dispatch_requested")
	)
	view.call("build", hud)

	var inspector_panels: Dictionary = hud.get("_inspector_panels")
	_expect(
		inspector_panels.has("employee") and bool(view.call("is_built")),
		"Profile view must register the employee inspector and build its controls."
	)
	var skill_container: VBoxContainer = view.call("get_skill_container")
	_expect(
		skill_container != null and skill_container.name == "SkillProgressList",
		"Profile view must expose the skill container for the skill-progress component."
	)

	var candidate_data: Dictionary = {
		"has_profile": true,
		"name": "ТЕСТОВЫЙ КАНДИДАТ",
		"profession": "Актёр · Драма · Возраст: 27",
		"biography": "Тестовая биография кандидата.",
		"stats": "Опыт: 4.0 лет\nПопулярность: 62 / 100",
		"task": "СТАТУС: Кандидат открыт к предложениям",
		"schedule": "График работы согласуется при найме.",
		"contract": "ПРЕДЛАГАЕМЫЙ КОНТРАКТ\nТип: Бессрочный\nСтавка: 120 усл. ед. / день",
		"personality": "Амбиции: 70%\nОбщительность: 55%",
		"needs": {
			"energy": 80.0,
			"morale": 65.0,
			"stress": 25.0,
		},
		"show_contract_type": true,
		"show_hire_button": true,
		"show_dismiss_button": false,
	}
	view.call("refresh", candidate_data)

	var name_label: Label = view.get("_detail_name_label")
	var stats_label: Label = view.get("_detail_stats_label")
	var energy_bar: ProgressBar = view.get("_energy_bar")
	var morale_bar: ProgressBar = view.get("_morale_bar")
	var stress_bar: ProgressBar = view.get("_stress_bar")
	var contract_option: OptionButton = view.get("_contract_type_option")
	var hire_button: Button = view.get("_hire_button")
	var dismiss_button: Button = view.get("_dismiss_button")
	var dispatch_button: Button = view.get("_workplace_dispatch_button")
	_expect(
		name_label.text == "ТЕСТОВЫЙ КАНДИДАТ"
		and stats_label.text.contains("Популярность: 62"),
		"Profile view must render the supplied biography and employee statistics."
	)
	_expect(
		is_equal_approx(energy_bar.value, 80.0)
		and is_equal_approx(morale_bar.value, 65.0)
		and is_equal_approx(stress_bar.value, 25.0),
		"Profile view must render energy, morale and stress values without recalculation."
	)
	_expect(
		contract_option.visible
		and hire_button.visible
		and not dismiss_button.visible
		and not dispatch_button.visible,
		"Candidate profiles must expose contract selection and hiring, not dismissal or dispatch."
	)
	contract_option.select(1)
	contract_option.item_selected.emit(1)
	_expect(
		str(view.call("get_selected_contract_type")) == "fixed_30_days"
		and _contract_selection_count == 1,
		"Contract selection must preserve metadata and delegate changes to CharacterManager."
	)
	hire_button.pressed.emit()
	_expect(_hire_count == 1, "Hiring action must delegate to CharacterManager.")

	var employee_data: Dictionary = candidate_data.duplicate(true)
	employee_data["name"] = "ТЕСТОВЫЙ СОТРУДНИК"
	employee_data["show_contract_type"] = false
	employee_data["show_hire_button"] = false
	employee_data["show_dismiss_button"] = true
	view.call("refresh", employee_data)
	_expect(
		not contract_option.visible
		and not hire_button.visible
		and dismiss_button.visible,
		"Employee profiles must expose dismissal and hide candidate contract controls."
	)
	view.call("set_workplace_dispatch_state", true, "ОТПРАВИТЬ В МОНТАЖНУЮ")
	_expect(
		dispatch_button.visible
		and dispatch_button.text == "ОТПРАВИТЬ В МОНТАЖНУЮ",
		"Profile view must render the manager-provided workplace dispatch state."
	)
	dispatch_button.pressed.emit()
	dismiss_button.pressed.emit()
	_expect(
		_dispatch_count == 1 and _dismiss_count == 1,
		"Workplace dispatch and dismissal actions must delegate to CharacterManager."
	)
	view.call("show_dismiss_confirmation", "Тестовый сотрудник")
	var dismiss_dialog: ConfirmationDialog = view.get("_dismiss_dialog")
	_expect(
		dismiss_dialog.dialog_text.contains("Тестовый сотрудник"),
		"Dismiss confirmation must include the selected employee's name."
	)
	dismiss_dialog.confirmed.emit()
	_expect(
		_dismiss_confirmed_count == 1,
		"Dismiss confirmation must delegate the final decision to CharacterManager."
	)

	view.call("clear")
	_expect(
		name_label.text == "ВЫБЕРИ СОТРУДНИКА"
		and energy_bar.value == 0.0
		and not dismiss_button.visible
		and not dispatch_button.visible,
		"Clearing the profile must reset labels, needs bars and action visibility."
	)

	hud.free()
	_finish_test("EmployeeProfilePanelControllerSmokeTest")
