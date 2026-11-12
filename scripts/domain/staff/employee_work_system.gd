extends RefCounted
class_name EmployeeWorkSystem

const BUILDING_CATALOG_SCRIPT = preload(
	"res://scripts/domain/studio/studio_building_catalog.gd"
)
const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)

const PRIMARY_SKILL_XP_PER_MINUTE: float = 0.0008
const RELIABILITY_SKILL_XP_PER_MINUTE: float = 0.0002
const SKILL_PROGRESSION_SYSTEM_SCRIPT = preload(
	"res://scripts/domain/characters/character_skill_progression_system.gd"
)

var _skill_progression_system: RefCounted


func _init() -> void:
	_skill_progression_system = SKILL_PROGRESSION_SYSTEM_SCRIPT.new()


func build_assignments(employees: Array, buildings: Array) -> Dictionary:
	var assignments: Dictionary = {}
	var occupied_slots: Dictionary = {}

	for employee in employees:
		var employee_id: String = str(employee.id)
		var profession_id: String = str(employee.profession_id)
		var preferred_types: Array[String] = get_preferred_building_types(
			profession_id
		)
		if preferred_types.is_empty():
			continue

		for preferred_type in preferred_types:
			for building in buildings:
				var building_type_id: String = str(building.building_type_id)
				if building_type_id != preferred_type:
					continue
				if not bool(building.is_operational):
					continue
				if not BUILDING_CATALOG_SCRIPT.accepts_profession(
					building_type_id,
					profession_id
				):
					continue

				var building_id: String = str(building.id)
				var slot_index: int = int(occupied_slots.get(building_id, 0))
				var capacity: int = BUILDING_CATALOG_SCRIPT.get_workplace_capacity(
					building_type_id
				)
				if slot_index >= capacity:
					continue

				assignments[employee_id] = {
					"building_id": building_id,
					"building_type_id": building_type_id,
					"slot_index": slot_index,
					"task_title": PROFESSION_CATALOG_SCRIPT.get_default_task(
						profession_id
					),
					"primary_skill_id": PROFESSION_CATALOG_SCRIPT.get_primary_skill_id(
						profession_id
					),
				}
				occupied_slots[building_id] = slot_index + 1
				break

			if assignments.has(employee_id):
				break

	return assignments


func get_preferred_building_types(profession_id: String) -> Array[String]:
	match profession_id:
		"screenwriter", "casting_director":
			return ["script_department"]
		"producer":
			return ["sound_stage", "script_department"]
		"film_editor":
			return ["editing_suite"]
		"actor", "extra", "director", "camera_operator", "technician", "production_designer":
			return ["sound_stage"]
		_:
			return []


func advance_work_minute(employee: Variant, assignment: Dictionary) -> bool:
	if employee == null or str(employee.work_state) != "working":
		return false

	var primary_skill_id: String = str(
		assignment.get("primary_skill_id", "")
	)
	if primary_skill_id.is_empty():
		return false

	employee.current_task = str(
		assignment.get("task_title", employee.current_task)
	)

	var changed: bool = bool(
		_skill_progression_system.call(
			"award_skill_experience",
			employee,
			primary_skill_id,
			PRIMARY_SKILL_XP_PER_MINUTE
		)
	)
	if employee.skills.has("reliability"):
		changed = bool(
			_skill_progression_system.call(
				"award_skill_experience",
				employee,
				"reliability",
				RELIABILITY_SKILL_XP_PER_MINUTE
			)
		) or changed
	return changed

