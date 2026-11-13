extends RefCounted
class_name TVGuestShowPanel

# The inspector UI is intentionally independent of television production.
# It only renders state and forwards the player's explicit invitation.
const INVITATION_POLICY_SCRIPT = preload(
	"res://scripts/domain/tv_production/tv_show_invitation_policy.gd"
)

var _controller: WeakRef
var _guest_option: OptionButton
var _host_option: OptionButton
var _invite_button: Button
var _status_label: Label


func build(
	layout: VBoxContainer,
	stage_id: String,
	controller: RefCounted,
	candidates: Array
) -> void:
	_controller = weakref(controller)
	var heading := Label.new()
	heading.text = "ТОК-ШОУ · ПРИГЛАШЁННЫЙ ВЕДУЩИЙ"
	heading.add_theme_font_size_override("font_size", 13)
	layout.add_child(heading)
	var information := Label.new()
	information.text = (
		"Известные актёры и режиссёры (узнаваемость от 70%) могут стать "
		+ "гостями ток-шоу. Ведущий приезжает извне, участвует в записи "
		+ "и уезжает — не входит в штат киностудии."
	)
	information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(information)
	_guest_option = OptionButton.new()
	_guest_option.fit_to_longest_item = false
	_guest_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for candidate in candidates:
		var index: int = _guest_option.get_item_count()
		_guest_option.add_item(
			"%s · известность %.0f%%" % [
				candidate.get_full_name(), float(candidate.recognition)
			]
		)
		_guest_option.set_item_metadata(index, str(candidate.id))
	if candidates.is_empty():
		_guest_option.add_item("Нет актёров или режиссёров с известностью 70%")
		_guest_option.disabled = true
	layout.add_child(_guest_option)
	_host_option = OptionButton.new()
	_host_option.fit_to_longest_item = false
	_host_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for host in INVITATION_POLICY_SCRIPT.EXTERNAL_HOSTS:
		var index: int = _host_option.get_item_count()
		_host_option.add_item(
			"%s · мастерство ведущего %.0f" % [
				str(host.get("name", "")), float(host.get("hosting", 0.0))
			]
		)
		_host_option.set_item_metadata(index, str(host.get("id", "")))
	layout.add_child(_host_option)
	_invite_button = Button.new()
	_invite_button.text = "ПРИГЛАСИТЬ ВЕДУЩЕГО И СНЯТЬ ВЫПУСК"
	_invite_button.pressed.connect(_on_invite_pressed.bind(stage_id))
	layout.add_child(_invite_button)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status_label)


func _on_invite_pressed(stage_id: String) -> void:
	if (
		not is_instance_valid(_guest_option)
		or not is_instance_valid(_host_option)
		or _guest_option.disabled
	):
		return
	var guest_id: String = str(_guest_option.get_item_metadata(
		_guest_option.selected
	))
	var host_id: String = str(_host_option.get_item_metadata(
		_host_option.selected
	))
	var owner: Variant = _controller.get_ref()
	if owner != null:
		owner.call("request_invitation", stage_id, guest_id, host_id)


func refresh(
	episode: Variant,
	message: String,
	host_present: bool
) -> void:
	if not is_instance_valid(_status_label):
		return
	var active: bool = episode != null
	if active:
		_status_label.text = (
			"Выпуск %s · %s · %.0f%%\n%s" % [
				str(episode.id), str(episode.get_phase_title()),
				float(episode.get_progress_percent()),
				str(episode.pause_reason),
			]
		)
	else:
		_status_label.text = message
	if is_instance_valid(_invite_button):
		_invite_button.disabled = (
			active or host_present
			or not is_instance_valid(_guest_option)
			or _guest_option.disabled
		)
