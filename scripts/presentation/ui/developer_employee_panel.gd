extends RefCounted
class_name DeveloperEmployeePanel

const DEV_TUNING_SCRIPT = preload(
	"res://scripts/domain/characters/character_dev_tuning.gd"
)

var _owner: WeakRef
var _tuning: RefCounted
var _employee_select: OptionButton
var _stat_select: OptionButton
var _value_label: Label
var _feedback_label: Label


func build(parent: VBoxContainer, employee_manager: Node) -> void:
	_owner = weakref(employee_manager)
	_tuning = DEV_TUNING_SCRIPT.new()
	parent.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = "DEV · ПАРАМЕТРЫ СОТРУДНИКОВ"
	heading.add_theme_font_size_override("font_size", 14)
	parent.add_child(heading)
	var note := Label.new()
	note.text = (
		"Только тестовые изменения. Не тратят опыт или очки роста, "
		+ "могут превышать природный потолок навыка."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)
	_employee_select = OptionButton.new()
	_employee_select.fit_to_longest_item = false
	_employee_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_employee_select.item_selected.connect(_on_employee_changed)
	parent.add_child(_employee_select)
	_stat_select = OptionButton.new()
	_stat_select.fit_to_longest_item = false
	_stat_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_select.item_selected.connect(_on_stat_changed)
	parent.add_child(_stat_select)
	_value_label = Label.new()
	parent.add_child(_value_label)
	var buttons := HBoxContainer.new()
	parent.add_child(buttons)
	for action in [
		{"title": "-10", "amount": -10.0, "absolute": false},
		{"title": "+10", "amount": 10.0, "absolute": false},
		{"title": "+25", "amount": 25.0, "absolute": false},
		{"title": "=70", "amount": 70.0, "absolute": true},
		{"title": "=100", "amount": 100.0, "absolute": true},
	]:
		var button := Button.new()
		button.text = str(action["title"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_adjust_pressed.bind(
			float(action["amount"]), bool(action["absolute"])
		))
		buttons.add_child(button)
	var refresh_button := Button.new()
	refresh_button.text = "ОБНОВИТЬ СПИСОК СОТРУДНИКОВ"
	refresh_button.pressed.connect(refresh)
	parent.add_child(refresh_button)
	_feedback_label = Label.new()
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_feedback_label)
	refresh()


func refresh() -> void:
	if not is_instance_valid(_employee_select):
		return
	var previous_id: String = _get_selected_employee_id()
	_employee_select.clear()
	var owner: Variant = _owner.get_ref()
	if owner == null:
		return
	var employees: Array = owner.call("get_employees")
	for employee in employees:
		var index: int = _employee_select.get_item_count()
		_employee_select.add_item(
			"%s · %s" % [
				employee.get_full_name(), employee.get_profession_title()
			]
		)
		_employee_select.set_item_metadata(index, str(employee.id))
		if str(employee.id) == previous_id:
			_employee_select.select(index)
	if employees.is_empty():
		_employee_select.add_item("Нет сотрудников")
		_employee_select.disabled = true
	else:
		_employee_select.disabled = false
		if _employee_select.selected < 0:
			_employee_select.select(0)
	_refresh_stat_choices()


func _on_employee_changed(_index: int) -> void:
	_refresh_stat_choices()


func _on_stat_changed(_index: int) -> void:
	_refresh_value()


func _refresh_stat_choices() -> void:
	if not is_instance_valid(_stat_select):
		return
	var previous_stat: String = _get_selected_stat_id()
	_stat_select.clear()
	var employee: Variant = _get_selected_employee()
	if employee == null:
		_stat_select.disabled = true
		_refresh_value()
		return
	_stat_select.disabled = false
	for choice in _tuning.call("get_stat_choices", employee):
		var index: int = _stat_select.get_item_count()
		_stat_select.add_item(str(choice["title"]))
		_stat_select.set_item_metadata(index, str(choice["id"]))
		if str(choice["id"]) == previous_stat:
			_stat_select.select(index)
	if _stat_select.selected < 0 and _stat_select.get_item_count() > 0:
		_stat_select.select(0)
	_refresh_value()


func _refresh_value() -> void:
	if not is_instance_valid(_value_label):
		return
	var employee: Variant = _get_selected_employee()
	if employee == null:
		_value_label.text = "Выберите сотрудника."
		return
	_value_label.text = "Текущее значение: %.1f / 100" % float(
		_tuning.call(
			"get_stat_value", employee, _get_selected_stat_id()
		)
	)


func _on_adjust_pressed(amount: float, absolute: bool) -> void:
	var owner: Variant = _owner.get_ref()
	var employee_id: String = _get_selected_employee_id()
	var stat_id: String = _get_selected_stat_id()
	if owner == null or employee_id.is_empty() or stat_id.is_empty():
		return
	var successful: bool = bool(owner.call(
		"developer_change_employee_stat", employee_id, stat_id,
		amount, absolute
	))
	_feedback_label.text = (
		"DEV: значение сотрудника изменено." if successful
		else "DEV: параметр недоступен."
	)
	_refresh_value()


func _get_selected_employee_id() -> String:
	if (
		not is_instance_valid(_employee_select)
		or _employee_select.selected < 0
		or _employee_select.disabled
	):
		return ""
	return str(_employee_select.get_item_metadata(_employee_select.selected))


func _get_selected_stat_id() -> String:
	if (
		not is_instance_valid(_stat_select)
		or _stat_select.selected < 0
		or _stat_select.disabled
	):
		return ""
	return str(_stat_select.get_item_metadata(_stat_select.selected))


func _get_selected_employee() -> Variant:
	var employee_id: String = _get_selected_employee_id()
	var owner: Variant = _owner.get_ref() if _owner != null else null
	if employee_id.is_empty() or owner == null:
		return null
	for employee in owner.call("get_employees"):
		if str(employee.id) == employee_id:
			return employee
	return null
