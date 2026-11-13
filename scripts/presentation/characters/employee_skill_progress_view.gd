extends RefCounted
class_name EmployeeSkillProgressView

const PROFESSION_CATALOG_SCRIPT = preload(
	"res://scripts/domain/staff/profession_catalog.gd"
)

var _container: VBoxContainer
var _skill_progression_system: RefCounted
var _skill_rows: Dictionary = {}


func setup(
	container: VBoxContainer,
	skill_progression_system: RefCounted
) -> void:
	_container = container
	_skill_progression_system = skill_progression_system


func clear() -> void:
	if not is_instance_valid(_container):
		return
	for child in _container.get_children():
		_container.remove_child(child)
		child.queue_free()
	_skill_rows.clear()


func refresh(employee: Variant, skills: Dictionary) -> void:
	if not is_instance_valid(_container):
		return
	var profession_skill_ids: Array[String] = (
		PROFESSION_CATALOG_SCRIPT.get_profession_skill_ids(
			employee.profession_id,
			employee.specialization_id
		)
	)
	var rebuild_rows: bool = (
		_skill_rows.size() != profession_skill_ids.size()
	)
	for skill_id in profession_skill_ids:
		if not _skill_rows.has(skill_id):
			rebuild_rows = true
			break
	if rebuild_rows:
		clear()
		for skill_id in profession_skill_ids:
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			var title_label := Label.new()
			title_label.text = PROFESSION_CATALOG_SCRIPT.get_skill_title(skill_id)
			title_label.add_theme_font_size_override("font_size", 12)
			row.add_child(title_label)
			var progress_bar: ProgressBar = _create_progress_bar(
				row,
				Color(0.48, 0.82, 0.72, 1.0)
			)
			progress_bar.custom_minimum_size = Vector2(0.0, 10.0)
			_container.add_child(row)
			_skill_rows[skill_id] = {
				"label": title_label,
				"bar": progress_bar,
			}

	for skill_id in profession_skill_ids:
		var skill_value: float = clampf(
			float(skills.get(skill_id, 0.0)),
			0.0,
			100.0
		)
		var skill_cap: float = clampf(
			float(employee.skill_caps.get(skill_id, 100.0)),
			1.0,
			100.0
		)
		var row_controls: Dictionary = _skill_rows.get(
			skill_id,
			{}
		)
		var title_label: Label = row_controls.get("label") as Label
		var progress_bar: ProgressBar = row_controls.get("bar") as ProgressBar
		if not is_instance_valid(title_label) or not is_instance_valid(progress_bar):
			continue
		progress_bar.max_value = skill_cap
		progress_bar.value = minf(skill_value, skill_cap)
		var status_text: String
		if skill_value >= skill_cap:
			status_text = "потенциал достигнут"
		elif float(employee.growth_points_remaining) < 1.0:
			status_text = "резерв развития исчерпан"
		else:
			var progress_percent: int = mini(
				roundi(float(
					_skill_progression_system.call(
						"get_progress_percent",
						employee,
						skill_id
					)
				)),
				99
			)
			status_text = "опыт до следующего пункта: %d%%" % progress_percent
		var tooltip_text: String = "%s · %.0f / %.0f · %s" % [
			PROFESSION_CATALOG_SCRIPT.get_skill_title(skill_id),
			skill_value,
			skill_cap,
			status_text,
		]
		title_label.tooltip_text = tooltip_text
		progress_bar.tooltip_text = tooltip_text


func _create_progress_bar(
	parent: VBoxContainer,
	fill_color: Color
) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0.0, 10.0)
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.12, 0.15, 0.17, 1.0)
	background_style.set_corner_radius_all(5)
	progress.add_theme_stylebox_override("background", background_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(5)
	progress.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(progress)
	return progress
