extends RefCounted
class_name StudioBusinessController

const SET_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_set_catalog.gd"
)
const COSTUME_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_costume_catalog.gd"
)
const WARDROBE_INVENTORY_SCRIPT = preload(
	"res://scripts/domain/studio/studio_wardrobe_inventory.gd"
)

const REPAIR_WORK_MINUTES: int = 30
const REPAIR_CONDITION_PER_TASK: float = 25.0
const REPAIR_CONDITION_THRESHOLD: float = 92.0

var _manager: Node
var _character_manager: Node
var _game_clock: Node
var _set_inventory: Variant
var _wardrobe_inventory: RefCounted
var _active_repair: Dictionary = {}
var _feedback_label: Label


func setup(
	manager: Node,
	character_manager: Node,
	game_clock: Node,
	set_inventory: Variant
) -> void:
	_manager = manager
	_character_manager = character_manager
	_game_clock = game_clock
	_set_inventory = set_inventory
	_wardrobe_inventory = WARDROBE_INVENTORY_SCRIPT.new()


func get_owned_costume_ids() -> Array[String]:
	return _wardrobe_inventory.call("get_owned_costume_ids")


func get_costume_ids_for_genre(genre_id: String) -> Array[String]:
	if (
		not is_instance_valid(_manager)
		or not bool(_manager.call("has_building_type", "costume_wardrobe"))
	):
		return []
	return _wardrobe_inventory.call("get_costume_ids_for_genre", genre_id)


func get_costume_quality_bonus_for_genre(genre_id: String) -> float:
	if (
		not is_instance_valid(_manager)
		or not bool(_manager.call("has_building_type", "costume_wardrobe"))
	):
		return 0.0
	return float(_wardrobe_inventory.call(
		"get_costume_quality_bonus_for_genre", genre_id
	))


func get_costume_resale_value(costume_id: String) -> int:
	return int(_wardrobe_inventory.call("get_resale_value", costume_id))


func purchase_costume(costume_id: String) -> bool:
	if (
		not is_instance_valid(_manager)
		or not bool(_manager.call("has_building_type", "costume_wardrobe"))
	):
		return false
	var purchased: bool = bool(_wardrobe_inventory.call(
		"purchase", costume_id, _set_inventory
	))
	if purchased and is_instance_valid(_manager):
		_manager.call("refresh_wardrobe_inventory_visuals")
	return purchased


func sell_costume(costume_id: String) -> int:
	var amount: int = int(_wardrobe_inventory.call(
		"sell", costume_id, _set_inventory
	))
	if amount > 0 and is_instance_valid(_manager):
		_manager.call("refresh_wardrobe_inventory_visuals")
	return amount


func is_employee_in_maintenance(employee_id: String) -> bool:
	return (
		not _active_repair.is_empty()
		and str(_active_repair.get("employee_id", "")) == employee_id
	)


func is_prop_under_repair(prop_id: String) -> bool:
	return (
		not _active_repair.is_empty()
		and str(_active_repair.get("prop_id", "")) == prop_id
	)


func has_staff_conflict(
	crew: Dictionary,
	cast: Dictionary,
	background_ids: Array[String]
) -> bool:
	for employee_id_value in crew.values():
		if is_employee_in_maintenance(str(employee_id_value)):
			return true
	for employee_id_value in cast.values():
		if is_employee_in_maintenance(str(employee_id_value)):
			return true
	for employee_id in background_ids:
		if is_employee_in_maintenance(employee_id):
			return true
	return false


func build_costume_shop_items(container: VBoxContainer) -> void:
	var has_wardrobe: bool = (
		is_instance_valid(_manager)
		and bool(_manager.call("has_building_type", "costume_wardrobe"))
	)
	if not has_wardrobe:
		var requirement_label := Label.new()
		requirement_label.text = "Сначала построй здание «Гардеробная» — без него костюмы нельзя хранить и использовать."
		requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(requirement_label)
	for costume_id in COSTUME_CATALOG_SCRIPT.get_costume_ids():
		var definition: Dictionary = COSTUME_CATALOG_SCRIPT.get_costume_definition(
			costume_id
		)
		var row := PanelContainer.new()
		var row_layout := HBoxContainer.new()
		row_layout.add_theme_constant_override("separation", 8)
		row.add_child(row_layout)

		var item_label := Label.new()
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.text = "%s\n%s\nКачество костюмов: +%.0f · Цена: %d усл. ед." % [
			str(definition.get("title", costume_id)),
			str(definition.get("description", "")),
			float(definition.get("quality_bonus", 0.0)),
			int(definition.get("price", 0)),
		]
		row_layout.add_child(item_label)

		var purchase_button := Button.new()
		purchase_button.custom_minimum_size = Vector2(112.0, 38.0)
		if bool(_wardrobe_inventory.call("is_owned", costume_id)):
			purchase_button.text = "В ГАРДЕРОБНОЙ"
			purchase_button.disabled = true
		else:
			purchase_button.text = "КУПИТЬ"
			purchase_button.disabled = (
				not has_wardrobe
				or int(_set_inventory.get("budget"))
				< int(definition.get("price", 0))
			)
			if not has_wardrobe:
				purchase_button.tooltip_text = "Сначала построй гардеробную."
			purchase_button.pressed.connect(
				_on_costume_purchase_pressed.bind(costume_id)
			)
		row_layout.add_child(purchase_button)
		container.add_child(row)


func _on_costume_purchase_pressed(costume_id: String) -> void:
	if not purchase_costume(costume_id):
		_set_feedback("Не удалось купить костюм: проверь бюджет и наличие.")
		return
	if is_instance_valid(_manager):
		_manager.call("refresh_decor_shop_panel")


func build_building_detail(
	layout: VBoxContainer,
	building_id: String
) -> void:
	if not is_instance_valid(_manager):
		return
	var building: Variant = _manager.call("get_building_by_id", building_id)
	if building == null:
		return
	_feedback_label = null
	match str(building.building_type_id):
		"film_promotion":
			_build_marketing_detail(layout)
		"costume_wardrobe":
			_build_wardrobe_detail(layout)
		"prop_exchange":
			_build_prop_exchange_detail(layout)


func _build_marketing_detail(layout: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "РЕКЛАМНЫЕ КАМПАНИИ"
	heading.add_theme_font_size_override("font_size", 13)
	layout.add_child(heading)

	var description := Label.new()
	description.text = (
		"Продвигай завершённые фильмы до или после релиза. "
		+ "Кампания повышает коммерческий успех, но не меняет художественное качество. "
		+ "Для одного фильма доступно не более трёх кампаний; повторные вложения дают меньший эффект."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)

	var budget_label := Label.new()
	budget_label.text = "Бюджет студии: %d усл. ед." % int(
		_set_inventory.get("budget")
	)
	layout.add_child(budget_label)

	var films: Array = _manager.call("get_marketable_films")
	if films.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Завершённый и смонтированный фильм появится здесь."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(empty_label)
		return

	var campaign_definitions: Array = _manager.call(
		"get_marketing_campaign_definitions"
	)
	for film in films:
		var film_card := PanelContainer.new()
		var film_layout := VBoxContainer.new()
		film_layout.add_theme_constant_override("separation", 6)
		film_card.add_child(film_layout)
		var film_label := Label.new()
		film_label.text = "%s\nКачество: %d/100 · Коммерческий успех: %d/100\nКампании: %d/3 · Потрачено на рекламу: %d" % [
			str(film.get("film_title", "Без названия")),
			int(film.get("final_quality", 0)),
			int(film.get("commercial_success_score", 0)),
			int(film.get("marketing_campaign_count", 0)),
			int(film.get("marketing_spend", 0)),
		]
		film_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		film_layout.add_child(film_label)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 5)
		film_layout.add_child(buttons)
		var project_id: String = str(film.get("project_id", ""))
		for campaign in campaign_definitions:
			var campaign_id: String = str(campaign.get("id", ""))
			var price: int = int(campaign.get("price", 0))
			var campaign_button := Button.new()
			campaign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			campaign_button.text = "%s\n%d" % [
				str(campaign.get("title", campaign_id)),
				price,
			]
			campaign_button.tooltip_text = str(
				campaign.get("description", "")
			)
			campaign_button.disabled = (
				int(film.get("marketing_campaign_count", 0)) >= 3
				or int(_set_inventory.get("budget")) < price
			)
			campaign_button.pressed.connect(
				_on_marketing_campaign_pressed.bind(
					project_id, campaign_id
				)
			)
			buttons.add_child(campaign_button)
		layout.add_child(film_card)


func _on_marketing_campaign_pressed(
	project_id: String,
	campaign_id: String
) -> void:
	var result: Dictionary = _manager.call(
		"launch_marketing_campaign", project_id, campaign_id
	)
	if not bool(result.get("success", false)):
		_set_feedback(str(result.get("reason", "Кампания не запущена.")))
		return
	_manager.call("refresh_building_detail")


func _build_wardrobe_detail(layout: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "СОДЕРЖИМОЕ ГАРДЕРОБНОЙ"
	heading.add_theme_font_size_override("font_size", 13)
	layout.add_child(heading)
	var costume_ids: Array[String] = get_owned_costume_ids()
	if costume_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = (
			"Гардеробная пока пуста. Покупай комплекты костюмов "
			+ "в магазине декораций — они будут автоматически подбираться по жанру фильма."
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(empty_label)
		return
	for costume_id in costume_ids:
		var definition: Dictionary = COSTUME_CATALOG_SCRIPT.get_costume_definition(
			costume_id
		)
		var genres: Array = definition.get("genre_ids", [])
		var genre_titles: Array[String] = []
		for genre_id_value in genres:
			genre_titles.append(str(genre_id_value).replace("_", " ").capitalize())
		var genre_text: String = ""
		for genre_title in genre_titles:
			if not genre_text.is_empty():
				genre_text += ", "
			genre_text += genre_title
		var item_label := Label.new()
		item_label.text = "%s\nПодходящие жанры: %s · Бонус к качеству костюмов: +%.0f" % [
			str(definition.get("title", costume_id)),
			genre_text,
			float(definition.get("quality_bonus", 0.0)),
		]
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(item_label)


func _build_prop_exchange_detail(layout: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "СКУПКА РЕКВИЗИТА"
	heading.add_theme_font_size_override("font_size", 13)
	layout.add_child(heading)
	var description := Label.new()
	description.text = (
		"Продавай ненужные декорации и костюмы. Декорации можно продать "
		+ "только после возврата на склад; предметы на съёмочной площадке и в пути защищены."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)
	var budget_label := Label.new()
	budget_label.text = "Бюджет студии: %d усл. ед." % int(
		_set_inventory.get("budget")
	)
	layout.add_child(budget_label)

	var prop_heading := Label.new()
	prop_heading.text = "ДЕКОРАЦИИ"
	prop_heading.add_theme_font_size_override("font_size", 11)
	layout.add_child(prop_heading)
	var owned_props: Array[String] = _set_inventory.call("get_owned_prop_ids")
	if owned_props.is_empty():
		var empty_props := Label.new()
		empty_props.text = "Пока нет купленных декораций."
		layout.add_child(empty_props)
	for prop_id in owned_props:
		var definition: Dictionary = SET_CATALOG_SCRIPT.get_prop_definition(
			prop_id
		)
		var location: String = str(_set_inventory.call(
			"get_prop_location", prop_id
		))
		var condition: float = float(_set_inventory.call(
			"get_prop_condition", prop_id
		))
		var resale_value: int = int(_set_inventory.call(
			"get_prop_resale_value", prop_id
		))
		var film_use_count: int = int(_set_inventory.call(
			"get_prop_film_usage_count", prop_id
		))
		var repairing: bool = is_prop_under_repair(prop_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var item_label := Label.new()
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.text = "%s\nСостояние: %.0f/100 · Фильмов: %d · %s · Выкуп: %d" % [
			str(definition.get("title", prop_id)),
			condition,
			film_use_count,
			_location_title(location, repairing),
			resale_value,
		]
		row.add_child(item_label)
		var sell_button := Button.new()
		sell_button.text = "ПРОДАТЬ"
		sell_button.disabled = (
			location != "warehouse"
			or repairing
			or resale_value <= 0
		)
		sell_button.pressed.connect(
			_on_prop_sale_pressed.bind(prop_id)
		)
		row.add_child(sell_button)
		layout.add_child(row)

	var costume_heading := Label.new()
	costume_heading.text = "КОСТЮМЫ"
	costume_heading.add_theme_font_size_override("font_size", 11)
	layout.add_child(costume_heading)
	var costume_ids: Array[String] = get_owned_costume_ids()
	if costume_ids.is_empty():
		var empty_costumes := Label.new()
		empty_costumes.text = "В гардеробной пока нет костюмов."
		layout.add_child(empty_costumes)
	for costume_id in costume_ids:
		var costume_definition: Dictionary = COSTUME_CATALOG_SCRIPT.get_costume_definition(
			costume_id
		)
		var resale: int = get_costume_resale_value(costume_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var item_label := Label.new()
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.text = "%s\nВыкуп: %d усл. ед." % [
			str(costume_definition.get("title", costume_id)),
			resale,
		]
		row.add_child(item_label)
		var sell_button := Button.new()
		sell_button.text = "ПРОДАТЬ"
		sell_button.disabled = resale <= 0
		sell_button.pressed.connect(
			_on_costume_sale_pressed.bind(costume_id)
		)
		row.add_child(sell_button)
		layout.add_child(row)


func _on_prop_sale_pressed(prop_id: String) -> void:
	var amount: int = int(_manager.call(
		"sell_prop_from_exchange", prop_id
	))
	if amount <= 0:
		_set_feedback("Декорацию нельзя продать: верни её на склад и освободи от ремонта.")
		return
	_manager.call("refresh_building_detail")


func _on_costume_sale_pressed(costume_id: String) -> void:
	var amount: int = int(_manager.call(
		"sell_costume_from_exchange", costume_id
	))
	if amount <= 0:
		_set_feedback("Не удалось продать костюм.")
		return
	_manager.call("refresh_building_detail")


func _location_title(location: String, repairing: bool) -> String:
	if repairing:
		return "на ремонте"
	match location:
		"warehouse":
			return "на складе"
		"on_stage":
			return "на площадке"
		"in_transit_to_stage", "in_transit_to_warehouse":
			return "в пути"
		_:
			return "неизвестное место"


func _set_feedback(message: String) -> void:
	if is_instance_valid(_feedback_label):
		_feedback_label.text = message
	elif is_instance_valid(_manager):
		var studio_hud: Node = _manager.get_node_or_null("../StudioHUD")
		if studio_hud != null:
			studio_hud.call("set_developer_funds_status", message)


func advance_minute(_day: int, hour: int, _minute: int) -> void:
	if not _active_repair.is_empty():
		_advance_active_repair()
		return
	if hour >= 9 and hour < 17:
		_try_start_repair()


func _try_start_repair() -> void:
	if (
		not is_instance_valid(_manager)
		or not is_instance_valid(_character_manager)
		or _set_inventory == null
	):
		return
	var warehouse_id: String = str(
		_manager.call("get_prop_warehouse_building_id")
	)
	if warehouse_id.is_empty():
		return
	var repairable_props: Array[String] = _set_inventory.call(
		"get_props_in_warehouse"
	)
	if repairable_props.is_empty():
		return
	for prop_id in repairable_props:
		if float(_set_inventory.call("get_prop_condition", prop_id)) >= REPAIR_CONDITION_THRESHOLD:
			continue
		for employee in _character_manager.call("get_employees"):
			var employee_id: String = str(employee.id)
			if str(employee.profession_id) != "technician":
				continue
			if str(employee.work_state) != "working":
				continue
			if _is_employee_busy(employee_id):
				continue
			var actor: Node3D = _character_manager.call(
				"get_employee_actor", employee_id
			) as Node3D
			if not is_instance_valid(actor):
				continue
			if (
				bool(actor.call("is_in_scene_performance"))
				or bool(actor.call("is_returning_to_workplace"))
				or bool(actor.call("is_in_facility"))
			):
				continue
			if not bool(_character_manager.call(
				"is_employee_at_workplace", employee_id
			)):
				_character_manager.call(
					"dispatch_employee_to_workplace", employee_id
				)
				continue
			var target_position: Vector3 = _manager.call(
				"get_storage_mark", warehouse_id, 0
			)
			var route: Array[Vector3] = _manager.call(
				"get_scene_recovery_path",
				str(actor.call("get_workplace_building_id")),
				actor.global_position,
				target_position
			)
			if route.is_empty():
				continue
			var source_building_id: String = str(
				actor.call("get_workplace_building_id")
			)
			var source_slot_index: int = int(
				actor.get("_workplace_slot_index")
			)
			actor.call(
				"start_scene_performance",
				target_position,
				target_position + Vector3(0.0, 0.0, -1.0),
				"checking_equipment",
				"Ремонтирует декорацию",
				route,
				true
			)
			_character_manager.call(
				"set_employee_task",
				employee_id,
				"Ремонтирует декорацию «%s»"
				% str(SET_CATALOG_SCRIPT.get_prop_definition(prop_id).get(
					"title", prop_id
				))
			)
			_active_repair = {
				"employee_id": employee_id,
				"prop_id": prop_id,
				"source_building_id": source_building_id,
				"source_slot_index": source_slot_index,
				"warehouse_id": warehouse_id,
				"elapsed_minutes": 0,
			}
			return


func _is_employee_busy(employee_id: String) -> bool:
	if (
		_manager.call("is_employee_in_active_production", employee_id)
		or _manager.call("is_employee_in_active_editing", employee_id)
		or _manager.call("is_employee_in_publicity_event", employee_id)
		or _manager.call("is_employee_in_manual_activity", employee_id)
		or is_employee_in_maintenance(employee_id)
	):
		return true
	return false


func _advance_active_repair() -> void:
	var employee_id: String = str(_active_repair.get("employee_id", ""))
	var employee: Variant = _find_employee(employee_id)
	var actor: Node3D = _character_manager.call(
		"get_employee_actor", employee_id
	) as Node3D
	if employee == null or not is_instance_valid(actor):
		_active_repair.clear()
		return
	if str(employee.work_state) != "working":
		_finish_active_repair()
		return
	if (
		is_instance_valid(_game_clock)
		and bool(_game_clock.get("is_manual_fast_forward"))
		and bool(actor.call("is_in_scene_performance"))
		and not bool(actor.call("is_at_scene_mark"))
	):
		actor.call("snap_to_scene_mark")
	if not bool(actor.call("is_at_scene_mark")):
		return
	_active_repair["elapsed_minutes"] = (
		int(_active_repair.get("elapsed_minutes", 0)) + 1
	)
	if int(_active_repair["elapsed_minutes"]) < REPAIR_WORK_MINUTES:
		return
	var prop_id: String = str(_active_repair.get("prop_id", ""))
	_set_inventory.call(
		"repair_prop", prop_id, REPAIR_CONDITION_PER_TASK
	)
	_finish_active_repair()
	_manager.call("refresh_warehouse_inventory_visuals")
	_manager.call("refresh_building_detail")


func _finish_active_repair() -> void:
	var employee_id: String = str(_active_repair.get("employee_id", ""))
	var actor: Node3D = _character_manager.call(
		"get_employee_actor", employee_id
	) as Node3D
	if is_instance_valid(actor):
		var source_building_id: String = str(
			_active_repair.get("source_building_id", "")
		)
		var source_slot_index: int = int(
			_active_repair.get("source_slot_index", 0)
		)
		var warehouse_id: String = str(
			_active_repair.get("warehouse_id", "")
		)
		var return_route: Array[Vector3] = _manager.call(
			"get_workplace_path_from",
			source_building_id,
			source_slot_index,
			actor.global_position,
			warehouse_id,
			0
		)
		if return_route.is_empty():
			actor.call("return_to_workplace")
		else:
			actor.call("return_to_workplace", return_route)
	if not employee_id.is_empty():
		_character_manager.call("clear_employee_task", employee_id)
		_character_manager.call(
			"set_employee_production_action", employee_id, ""
		)
	_active_repair.clear()


func _find_employee(employee_id: String) -> Variant:
	if not is_instance_valid(_character_manager):
		return null
	for employee in _character_manager.call("get_employees"):
		if str(employee.id) == employee_id:
			return employee
	return null
