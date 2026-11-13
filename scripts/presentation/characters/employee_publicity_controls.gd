extends RefCounted
class_name EmployeePublicityControls

# Profile UI owns only buttons and feedback. All eligibility, cooldowns,
# guard strength and popularity changes live in the publicity domain.
var _on_request: Callable
var _container: VBoxContainer
var _fan_button: Button
var _press_button: Button
var _status: Label
var _employee_id: String = ""


func build(parent: VBoxContainer, on_request: Callable) -> void:
	_on_request = on_request
	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 5)
	parent.add_child(_container)
	var heading := Label.new()
	heading.text = "ПУБЛИЧНАЯ ЖИЗНЬ"
	heading.add_theme_font_size_override("font_size", 12)
	_container.add_child(heading)
	var description := Label.new()
	description.text = (
		"Встреча с поклонниками повышает известность. Пресса тоже "
		+ "привлекает внимание, но создаёт стресс. Нанятые охранники "
		+ "приходят к месту встречи и снижают стресс, если успели занять позиции."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_container.add_child(description)
	_fan_button = Button.new()
	_fan_button.text = "ПРИГЛАСИТЬ ПОКЛОННИКОВ"
	_fan_button.pressed.connect(_request.bind("fan_meet"))
	_container.add_child(_fan_button)
	_press_button = Button.new()
	_press_button.text = "ВСТРЕЧА С ПАПАРАЦЦИ"
	_press_button.pressed.connect(_request.bind("paparazzi"))
	_container.add_child(_press_button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_container.add_child(_status)
	_container.visible = false


func refresh(data: Dictionary) -> void:
	if not is_instance_valid(_container):
		return
	var visible_for_employee: bool = (
		bool(data.get("show_recognition", false))
		and bool(data.get("is_employed", false))
	)
	_container.visible = visible_for_employee
	_employee_id = str(data.get("employee_id", "")) if visible_for_employee else ""
	if visible_for_employee:
		_status.text = str(data.get("publicity_status", ""))


func _request(event_id: String) -> void:
	if _employee_id.is_empty() or not _on_request.is_valid():
		return
	_on_request.call(_employee_id, event_id)
