extends RefCounted
class_name StudioFilmDossierController

const DOSSIER_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_dossier.gd"
)
const DOSSIER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_film_dossier_actor.gd"
)
const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)

const DOCK_POSITION: Vector3 = Vector3(23.0, 0.0, -28.0)
const FILM_RELEASE_LAYER: int = 64

var _manager: Node3D
var _dossiers: Dictionary = {}
var _visuals: Dictionary = {}
var _dossier_order: Array[String] = []
var _dragged_script_id: String = ""
var _production_script_id: String = ""
var _staged_script_id: String = ""
var _release_dock: Node3D
var _last_message: String = ""


func setup(manager: Node3D) -> void:
	_manager = manager
	_create_release_dock()


func add_completed_script(completed_script: Variant) -> bool:
	if completed_script == null:
		return false
	var script_id: String = str(completed_script.id)
	if script_id.is_empty() or _dossiers.has(script_id):
		return false
	var writer_building_id: String = _find_building_of_type("script_department")
	if writer_building_id.is_empty():
		return false
	var dossier: RefCounted = DOSSIER_SCRIPT.new()
	dossier.call("setup", completed_script, writer_building_id)
	_dossiers[script_id] = dossier
	_dossier_order.append(script_id)
	var visual: Node3D = DOSSIER_ACTOR_SCRIPT.new()
	visual.call("setup", dossier)
	_manager.add_child(visual)
	_visuals[script_id] = visual
	_place_visual(script_id)
	_last_message = (
		"Сценарий «%s» готов. Возьми папку мышью у сценарного отдела "
		+ "и перенеси в съёмочный павильон."
	) % str(dossier.title)
	return true


func get_dossier(script_id: String) -> Variant:
	return _dossiers.get(script_id)


func get_script_at_stage() -> Variant:
	var dossier: Variant = _dossiers.get(_staged_script_id)
	if dossier != null and str(dossier.phase) == DOSSIER_SCRIPT.AT_STAGE:
		return dossier.screenplay
	return null


func get_staged_stage_id() -> String:
	var dossier: Variant = _dossiers.get(_staged_script_id)
	if dossier != null and str(dossier.phase) == DOSSIER_SCRIPT.AT_STAGE:
		return str(dossier.stage_building_id)
	return ""


func get_production_stage_id() -> String:
	var dossier: Variant = _dossiers.get(_production_script_id)
	if dossier == null:
		return ""
	return str(dossier.stage_building_id)


func get_latest_message() -> String:
	return _last_message


func is_script_at_stage(script_id: String, stage_building_id: String) -> bool:
	var dossier: Variant = _dossiers.get(script_id)
	return (
		dossier != null
		and str(dossier.phase) == DOSSIER_SCRIPT.AT_STAGE
		and str(dossier.stage_building_id) == stage_building_id
	)


func is_footage_at_editing(script_id: String) -> bool:
	var dossier: Variant = _dossiers.get(script_id)
	if dossier == null:
		return false
	return str(dossier.phase) in [
		DOSSIER_SCRIPT.AT_EDITING,
		DOSSIER_SCRIPT.IN_EDITING,
		DOSSIER_SCRIPT.MASTER_READY,
		DOSSIER_SCRIPT.RELEASED,
	]


func deliver_to_building(script_id: String, building_id: String) -> bool:
	var dossier: Variant = _dossiers.get(script_id)
	if dossier == null or not bool(dossier.is_movable()):
		return false
	var building: Variant = _manager.call("get_building_by_id", building_id)
	if building == null or not bool(building.is_operational):
		_last_message = "Здание недоступно для передачи материалов."
		return false
	var building_type: String = str(building.building_type_id)
	if (
		str(dossier.phase) == DOSSIER_SCRIPT.AT_WRITERS
		and building_type == "sound_stage"
	):
		var required_tier: int = int(_manager.call(
			"get_required_stage_size_tier_for_script",
			dossier.screenplay
		))
		if int(building.stage_size_tier) < required_tier:
			_last_message = (
				"Для «%s» нужен павильон не меньше %s."
				% [
					str(dossier.title),
					BUILDING_CATALOG_SCRIPT.get_stage_size_title(required_tier),
				]
			)
			return false
	if not bool(dossier.deliver_to_building(building_type, building_id)):
		_last_message = "Перенеси материалы в %s." % str(
			dossier.get_destination_title()
		)
		return false
	if str(dossier.phase) == DOSSIER_SCRIPT.AT_STAGE:
		_staged_script_id = script_id
		_last_message = "Сценарий доставлен. Назначь съёмочную группу и начинай съёмки."
	elif str(dossier.phase) == DOSSIER_SCRIPT.AT_EDITING:
		_last_message = "Отснятый материал в монтажной. Подготовь проект и начни монтаж."
	_place_visual(script_id)
	return true


func on_production_started(script_id: String, stage_id: String) -> bool:
	if not is_script_at_stage(script_id, stage_id):
		return false
	var dossier: Variant = _dossiers[script_id]
	if not bool(dossier.start_production()):
		return false
	_production_script_id = script_id
	if _staged_script_id == script_id:
		_staged_script_id = ""
	_refresh_visual(script_id)
	return true


func on_production_completed(script_id: String) -> bool:
	var dossier: Variant = _dossiers.get(script_id)
	if dossier == null or not bool(dossier.finish_production()):
		return false
	_last_message = "Съёмки завершены. Перенеси катушки фильма в монтажную."
	_refresh_visual(script_id)
	return true


func on_editing_started(script_id: String) -> bool:
	var dossier: Variant = _dossiers.get(script_id)
	if dossier == null or not bool(dossier.start_editing()):
		return false
	_refresh_visual(script_id)
	return true


func on_editing_completed(script_id: String) -> bool:
	var dossier: Variant = _dossiers.get(script_id)
	if dossier == null or not bool(dossier.finish_editing()):
		return false
	_last_message = (
		"Монтаж завершён. Перенеси готовый фильм в пункт выпуска "
		+ "«РЕЛИЗ» у дороги."
	)
	_refresh_visual(script_id)
	return true


func release_film(script_id: String) -> bool:
	var dossier: Variant = _dossiers.get(script_id)
	if dossier == null or not bool(dossier.release_film()):
		return false
	_last_message = "Фильм «%s» выпущен! Он добавлен в архив студии." % str(
		dossier.title
	)
	_place_visual(script_id)
	_refresh_visual(script_id)
	if _manager.has_method("on_film_dossier_released"):
		_manager.call("on_film_dossier_released", dossier.to_dict())
	return true


func is_dragging() -> bool:
	return not _dragged_script_id.is_empty()


func try_pickup(screen_position: Vector2) -> bool:
	if is_dragging() or not is_instance_valid(_manager):
		return false
	var hit: Dictionary = _raycast(screen_position, DOSSIER_ACTOR_SCRIPT.PICKING_LAYER)
	var collider: Node = hit.get("collider") as Node
	while collider != null and not collider.is_in_group("film_dossier"):
		collider = collider.get_parent()
	if collider == null:
		return false
	var script_id: String = str(collider.call("get_script_id"))
	var dossier: Variant = _dossiers.get(script_id)
	if dossier == null:
		return false
	if not bool(dossier.is_movable()):
		_last_message = (
			"«%s»: %s." % [
				str(dossier.title),
				str(dossier.get_destination_title()),
			]
		)
		return true
	_dragged_script_id = script_id
	collider.call("set_dragged", true)
	_last_message = "Доставь «%s» в %s." % [
		str(dossier.title),
		str(dossier.get_destination_title()),
	]
	return true


func update_drag(screen_position: Vector2) -> void:
	if not is_dragging():
		return
	var camera: Camera3D = _manager.get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return
	var position_on_ground: Vector3 = hit
	var actor: Node3D = _visuals.get(_dragged_script_id) as Node3D
	if is_instance_valid(actor):
		actor.global_position = position_on_ground + Vector3(0.0, 1.4, 0.0)


func release_drag(screen_position: Vector2) -> bool:
	if not is_dragging():
		return false
	var script_id: String = _dragged_script_id
	_dragged_script_id = ""
	var actor: Node3D = _visuals.get(script_id) as Node3D
	var dossier: Variant = _dossiers.get(script_id)
	var success: bool = false
	var building_actor: Node = _manager.call(
		"_get_building_actor_at",
		screen_position
	)
	if building_actor != null:
		success = deliver_to_building(
			script_id,
			str(building_actor.call("get_building_id"))
		)
	elif (
		dossier != null
		and str(dossier.phase) == DOSSIER_SCRIPT.MASTER_READY
		and _is_release_dock_hit(screen_position)
	):
		success = release_film(script_id)
	if not success and dossier != null:
		_last_message = "Передача не состоялась. %s." % str(
			dossier.get_destination_title()
		)
	if is_instance_valid(actor):
		actor.call("set_dragged", false)
	_place_visual(script_id)
	if _manager.has_method("refresh_film_production_ui"):
		_manager.call("refresh_film_production_ui")
	if _manager.has_method("refresh_building_detail"):
		_manager.call("refresh_building_detail")
	return true


func _refresh_visual(script_id: String) -> void:
	var actor: Node3D = _visuals.get(script_id) as Node3D
	if is_instance_valid(actor):
		actor.call("refresh_appearance")


func _place_visual(script_id: String) -> void:
	var actor: Node3D = _visuals.get(script_id) as Node3D
	var dossier: Variant = _dossiers.get(script_id)
	if not is_instance_valid(actor) or dossier == null:
		return
	if str(dossier.phase) == DOSSIER_SCRIPT.RELEASED:
		actor.global_position = DOCK_POSITION + Vector3(0.0, 0.05, 0.0)
		return
	var building: Variant = _manager.call(
		"get_building_by_id",
		str(dossier.building_id)
	)
	if building == null:
		return
	var footprint: Vector2 = BUILDING_CATALOG_SCRIPT.get_footprint(
		str(building.building_type_id),
		0.0,
		int(building.stage_size_tier)
	)
	var local_dock := Vector3(0.0, 0.05, footprint.y * 0.5 + 1.85)
	var building_actor: Node3D = _manager.call(
		"get_building_actor_by_id",
		str(building.id)
	) as Node3D
	if is_instance_valid(building_actor):
		actor.global_position = building_actor.to_global(local_dock)
	else:
		actor.global_position = building.position + local_dock


func _find_building_of_type(building_type: String) -> String:
	var buildings: Array = _manager.call("get_buildings")
	for building in buildings:
		if (
			str(building.building_type_id) == building_type
			and bool(building.is_operational)
		):
			return str(building.id)
	return ""


func _raycast(screen_position: Vector2, layer: int) -> Dictionary:
	var camera: Camera3D = _manager.get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var end: Vector3 = origin + camera.project_ray_normal(screen_position) * 400.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, layer)
	return _manager.get_world_3d().direct_space_state.intersect_ray(query)


func _is_release_dock_hit(screen_position: Vector2) -> bool:
	return not _raycast(screen_position, FILM_RELEASE_LAYER).is_empty()


func _create_release_dock() -> void:
	if not is_instance_valid(_manager):
		return
	_release_dock = Node3D.new()
	_release_dock.name = "FilmReleaseDock"
	_release_dock.position = DOCK_POSITION
	_manager.add_child(_release_dock)

	var platform := MeshInstance3D.new()
	platform.name = "DeliveryPlatform"
	var platform_mesh := BoxMesh.new()
	platform_mesh.size = Vector3(5.0, 0.35, 3.8)
	platform.mesh = platform_mesh
	platform.position.y = 0.22
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.16, 0.35, 0.35)
	platform.material_override = paint
	_release_dock.add_child(platform)

	var body := StaticBody3D.new()
	body.name = "ReleaseTarget"
	body.collision_layer = FILM_RELEASE_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 2.2, 3.8)
	shape.shape = box
	shape.position.y = 1.1
	body.add_child(shape)
	_release_dock.add_child(body)

	var sign := Label3D.new()
	sign.name = "ReleaseLabel"
	sign.position = Vector3(0.0, 2.2, 0.0)
	sign.text = "РЕЛИЗ ФИЛЬМОВ\nПЕРЕНЕСИ ГОТОВЫЙ ФИЛЬМ СЮДА"
	sign.font_size = 28
	sign.pixel_size = 0.009
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.modulate = Color(1.0, 0.83, 0.40)
	_release_dock.add_child(sign)
