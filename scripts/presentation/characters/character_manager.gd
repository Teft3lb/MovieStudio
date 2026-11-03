extends Node3D
class_name CharacterManager

const CHARACTER_GENERATOR_SCRIPT = preload(
	"res://scripts/domain/characters/character_generator.gd"
)
const CHARACTER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/characters/character_actor.gd"
)

const INITIAL_PROFESSIONS: Array[String] = [
	"actor",
	"actor",
	"director",
	"screenwriter",
	"camera_operator",
	"producer",
]

var employees: Array = []
var _generator: RefCounted


func _ready() -> void:
	_spawn_initial_roster()
	_build_roster_panel()


func get_employee_count() -> int:
	return employees.size()


func _spawn_initial_roster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	_generator = CHARACTER_GENERATOR_SCRIPT.new()

	for index in range(INITIAL_PROFESSIONS.size()):
		var employee_id: String = "EMP-%04d" % (index + 1)
		var profession_id: String = INITIAL_PROFESSIONS[index]
		var data: Variant = _generator.call(
			"generate", rng, employee_id, profession_id
		)
		employees.append(data)

		var actor: Variant = CHARACTER_ACTOR_SCRIPT.new()
		actor.name = "Employee_%02d" % (index + 1)
		actor.setup(data, _route_for(index), rng.randf_range(1.0, 1.45))
		add_child(actor)


func _route_for(index: int) -> Array[Vector3]:
	var route: Array[Vector3] = []

	match index % 6:
		0:
			route = [
				Vector3(-8.0, 0.0, 9.0),
				Vector3(-3.0, 0.0, 9.0),
				Vector3(4.0, 0.0, 9.0),
				Vector3(8.0, 0.0, 9.0),
				Vector3(8.0, 0.0, 12.0),
				Vector3(-8.0, 0.0, 12.0),
			]
		1:
			route = [
				Vector3(-8.0, 0.0, -9.0),
				Vector3(0.0, 0.0, -9.0),
				Vector3(8.0, 0.0, -9.0),
				Vector3(8.0, 0.0, -12.0),
				Vector3(-8.0, 0.0, -12.0),
			]
		2:
			route = [
				Vector3(-17.0, 0.0, 8.0),
				Vector3(-17.0, 0.0, 0.0),
				Vector3(-17.0, 0.0, -10.0),
				Vector3(-14.0, 0.0, -10.0),
				Vector3(-14.0, 0.0, 8.0),
			]
		3:
			route = [
				Vector3(14.0, 0.0, -10.0),
				Vector3(14.0, 0.0, 0.0),
				Vector3(14.0, 0.0, 10.0),
				Vector3(11.0, 0.0, 10.0),
				Vector3(11.0, 0.0, -10.0),
			]
		4:
			route = [
				Vector3(-8.0, 0.0, 16.0),
				Vector3(0.0, 0.0, 16.0),
				Vector3(8.0, 0.0, 16.0),
				Vector3(8.0, 0.0, 19.0),
				Vector3(-8.0, 0.0, 19.0),
			]
		_:
			route = [
				Vector3(-8.0, 0.0, -16.0),
				Vector3(0.0, 0.0, -16.0),
				Vector3(8.0, 0.0, -16.0),
				Vector3(8.0, 0.0, -13.0),
				Vector3(-8.0, 0.0, -13.0),
			]

	return route


func _build_roster_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "EmployeeRosterHUD"
	canvas.layer = 5
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 154.0)
	panel.custom_minimum_size = Vector2(310.0, 0.0)
	canvas.add_child(panel)

	var layout := VBoxContainer.new()
	panel.add_child(layout)

	var header := Label.new()
	header.text = "ПЕРСОНАЛ СТУДИИ  ·  %d" % employees.size()
	header.add_theme_font_size_override("font_size", 16)
	layout.add_child(header)

	for employee in employees:
		var summary: Dictionary = employee.call("get_ui_summary")
		var row := Label.new()
		row.text = "%s — %s\n%s: %d%%  ·  Мотивация: %d%%" % [
			summary.get("full_name", "Сотрудник"),
			summary.get("profession_title", "Профессия"),
			summary.get("primary_skill_title", "Навык"),
			int(summary.get("primary_skill_value", 0)),
			int(summary.get("morale", 0)),
		]
		row.add_theme_font_size_override("font_size", 12)
		layout.add_child(row)
