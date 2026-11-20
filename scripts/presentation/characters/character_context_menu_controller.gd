extends RefCounted
class_name CharacterContextMenuController

const ACTION_WHEEL_SCRIPT = preload(
	"res://scripts/presentation/characters/character_action_wheel.gd"
)
const DETAILS_DIALOG_SCRIPT = preload(
	"res://scripts/presentation/characters/character_details_dialog.gd"
)

var _manager: Node
var _wheel: Control
var _details_dialog: Control
var _selected_employee_id: String = ""


func setup(manager: Node, overlay_root: Control) -> void:
	_manager = manager
	if not is_instance_valid(overlay_root):
		return
	_wheel = ACTION_WHEEL_SCRIPT.new() as Control
	overlay_root.add_child(_wheel)
	_wheel.connect("action_selected", Callable(self, "_on_action_selected"))
	_details_dialog = DETAILS_DIALOG_SCRIPT.new() as Control
	overlay_root.add_child(_details_dialog)


func open_employee(employee: Variant, screen_position: Vector2) -> void:
	if employee == null or _wheel == null:
		return
	_selected_employee_id = str(employee.id)
	if is_instance_valid(_details_dialog):
		_details_dialog.call("close_dialog")
	var status_text: String = str(employee.current_task)
	if status_text.is_empty():
		status_text = employee.get_work_state_title()
	var profession_title: String = employee.get_profession_title()
	var specialization: String = employee.get_specialization_title()
	if not specialization.is_empty():
		profession_title += " · " + specialization
	_wheel.call(
		"open_for_employee",
		{
			"name": employee.get_full_name(),
			"initials": _get_initials(employee.get_full_name()),
			"profession": profession_title,
			"status": status_text,
		},
		_build_actions(employee),
		screen_position
	)


func close_menu() -> void:
	if is_instance_valid(_wheel):
		_wheel.call("close")


func close_details() -> void:
	if is_instance_valid(_details_dialog):
		_details_dialog.call("close_dialog")


func is_details_open() -> bool:
	return (
		is_instance_valid(_details_dialog)
		and bool(_details_dialog.call("is_open"))
	)


func refresh_details(employee_id: String) -> void:
	if (
		not is_details_open()
		or employee_id.is_empty()
		or employee_id != _selected_employee_id
	):
		return
	_details_dialog.call(
		"refresh_profile",
		_manager.call("get_character_details_data", employee_id)
	)


func _build_actions(employee: Variant) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var employee_id: String = str(employee.id)
	var profession_id: String = str(employee.profession_id)
	var profession_preview: Dictionary = _manager.call(
		"get_profession_activity_preview", employee_id
	)
	var rest_preview: Dictionary = _manager.call(
		"get_manual_activity_preview_for_types",
		employee_id,
		["studio_lounge", "cafeteria"]
	)
	actions.append({
		"id": "profile",
		"title": "Характеристики",
		"icon": "◈",
		"description": "Открыть подробную карточку сотрудника.",
	})
	actions.append({
		"id": "profession_activity",
		"title": "По своим делам",
		"icon": _get_profession_symbol(profession_id),
		"description": (
			"%s · %s" % [
				str(profession_preview.get("title", "Профильное занятие")),
				str(profession_preview.get("building_name", ""))
			]
			if bool(profession_preview.get("success", false))
			else str(profession_preview.get("message", "Нет подходящего занятия."))
		),
		"disabled": not bool(profession_preview.get("success", false)),
	})
	actions.append({
		"id": "rest",
		"title": "Отдохнуть",
		"icon": "⌂",
		"description": (
			str(rest_preview.get("title", "Восстановить силы"))
			if bool(rest_preview.get("success", false))
			else str(rest_preview.get("message", "Нет свободной зоны отдыха."))
		),
		"disabled": not bool(rest_preview.get("success", false)),
	})
	if profession_id in ["actor", "extra"]:
		var training_preview: Dictionary = _manager.call(
			"get_manual_activity_preview_for_types",
			employee_id,
			["fitness_center"]
		)
		actions.append({
			"id": "training",
			"title": "Тренировка",
			"icon": "✧",
			"description": (
				str(training_preview.get("title", ""))
				if bool(training_preview.get("success", false))
				else str(training_preview.get("message", "Фитнес-центр недоступен."))
			),
			"disabled": not bool(training_preview.get("success", false)),
		})
	if profession_id in ["actor", "director"]:
		var publicity_blocked: bool = (
			bool(_manager.call(
				"is_employee_busy_in_production_or_editing", employee_id
			))
			or bool(_manager.call("is_employee_in_publicity_event", employee_id))
		)
		actions.append({
			"id": "fan_meet",
			"title": "Встреча с фанатами",
			"icon": "★",
			"description": "Собрать поклонников у входа в студию. Охрана обеспечит безопасность.",
			"disabled": publicity_blocked,
		})
	var has_manual_activity: bool = bool(
		_manager.call("has_manual_activity_order", employee_id)
	)
	var has_manual_workplace_dispatch: bool = bool(
		_manager.call("is_employee_manually_dispatched", employee_id)
	)
	if has_manual_activity or has_manual_workplace_dispatch:
		actions.append({
			"id": "cancel_activity",
			"title": "Отменить задачу",
			"icon": "×",
			"description": "Вернуть сотрудника к обычному распорядку.",
		})
	else:
		var assignment: Dictionary = _manager.call(
			"get_employee_workplace_assignment", employee_id
		)
		var assignment_type: String = str(assignment.get("building_type_id", ""))
		if (
			not assignment.is_empty()
			and assignment_type in ["sound_stage", "editing_suite"]
			and bool(_manager.call(
				"can_reassign_employee_workplace", employee_id
			))
		):
			actions.append({
				"id": "workplace",
				"title": "На рабочее место",
				"icon": "▣",
				"description": "Вызвать сотрудника на назначенное рабочее место.",
			})
	return actions


func _on_action_selected(action_id: String) -> void:
	if _selected_employee_id.is_empty() or not is_instance_valid(_manager):
		return
	if action_id == "profile":
		close_menu()
		_details_dialog.call(
			"open_profile",
			_manager.call("get_character_details_data", _selected_employee_id)
		)
		return
	var result: Dictionary = {}
	match action_id:
		"profession_activity":
			result = _manager.call(
				"request_profession_activity", _selected_employee_id
			)
		"rest":
			result = _manager.call(
				"request_activity_for_types",
				_selected_employee_id,
				["studio_lounge", "cafeteria"]
			)
		"training":
			result = _manager.call(
				"request_activity_for_types",
				_selected_employee_id,
				["fitness_center"]
			)
		"fan_meet":
			result = _manager.call(
				"request_fan_meeting", _selected_employee_id
			)
		"cancel_activity":
			result = _manager.call(
				"cancel_employee_activity", _selected_employee_id
			)
		"workplace":
			var dispatched: bool = bool(_manager.call(
				"dispatch_employee_to_workplace_manually",
				_selected_employee_id
			))
			result = {
				"success": dispatched,
				"message": (
					"Сотрудник вызван на рабочее место."
					if dispatched
					else "Не удалось вызвать сотрудника на рабочее место."
				),
			}
		_:
			result = {"success": false, "message": "Неизвестное действие."}
	close_menu()
	_manager.call("refresh_character_context_ui")
	_manager.call(
		"show_character_context_notification",
		str(result.get("message", "Действие выполнено.")),
		bool(result.get("success", false))
	)


func _get_profession_symbol(profession_id: String) -> String:
	match profession_id:
		"actor", "extra":
			return "★"
		"director":
			return "◆"
		"screenwriter":
			return "✎"
		"camera_operator":
			return "◉"
		"film_editor":
			return "▤"
		"technician", "production_designer", "maintenance_worker":
			return "⚒"
		"producer":
			return "✦"
		_:
			return "◇"


func _get_initials(full_name: String) -> String:
	var initials: String = ""
	for name_part in full_name.split(" ", false):
		if not str(name_part).is_empty():
			initials += str(name_part).left(1).to_upper()
	return initials
