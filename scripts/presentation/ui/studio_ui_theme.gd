extends RefCounted
class_name StudioUITheme

const INK: Color = Color(0.055, 0.047, 0.055, 0.98)
const SURFACE: Color = Color(0.105, 0.083, 0.088, 0.98)
const SURFACE_RAISED: Color = Color(0.155, 0.118, 0.112, 1.0)
const BURGUNDY: Color = Color(0.31, 0.105, 0.145, 1.0)
const GOLD: Color = Color(0.78, 0.59, 0.29, 1.0)
const GOLD_BRIGHT: Color = Color(0.96, 0.77, 0.40, 1.0)
const CREAM: Color = Color(0.94, 0.88, 0.75, 1.0)
const MUTED: Color = Color(0.68, 0.62, 0.56, 1.0)
const MINT: Color = Color(0.39, 0.69, 0.57, 1.0)
const RED: Color = Color(0.76, 0.34, 0.31, 1.0)


static func build_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", CREAM)
	ui_theme.set_color("font_color", "Button", CREAM)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "Button", INK)
	ui_theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))
	ui_theme.set_color("font_color", "OptionButton", CREAM)
	ui_theme.set_color("font_color", "SpinBox", CREAM)
	ui_theme.set_font_size("font_size", "Button", 13)
	ui_theme.set_font_size("font_size", "OptionButton", 13)
	_apply_button_theme(ui_theme, "Button")
	_apply_button_theme(ui_theme, "OptionButton")
	ui_theme.set_stylebox(
		"normal",
		"LineEdit",
		_make_flat_style(SURFACE_RAISED, Color(0.39, 0.29, 0.21, 1.0), 9, 0)
	)
	ui_theme.set_stylebox(
		"focus",
		"LineEdit",
		_make_flat_style(SURFACE_RAISED, GOLD_BRIGHT, 9, 0)
	)
	ui_theme.set_stylebox(
		"panel",
		"PanelContainer",
		panel_style()
	)
	ui_theme.set_stylebox(
		"panel",
		"PopupPanel",
		_make_flat_style(SURFACE, GOLD, 12, 10)
	)
	ui_theme.set_stylebox(
		"panel",
		"PopupMenu",
		_make_flat_style(SURFACE, GOLD, 10, 8)
	)
	ui_theme.set_stylebox(
		"background",
		"ProgressBar",
		_make_flat_style(Color(0.075, 0.061, 0.067, 1.0), Color(0.24, 0.17, 0.15, 1.0), 6, 0)
	)
	ui_theme.set_stylebox(
		"fill",
		"ProgressBar",
		_make_flat_style(GOLD, GOLD, 6, 0)
	)
	var separator := StyleBoxLine.new()
	separator.color = Color(0.48, 0.34, 0.20, 0.76)
	separator.thickness = 1
	ui_theme.set_stylebox("separator", "HSeparator", separator)
	ui_theme.set_stylebox("separator", "VSeparator", separator)
	var scroll_track := _make_flat_style(Color(0.045, 0.037, 0.043, 0.78), Color.TRANSPARENT, 5, 0)
	var scroll_grabber := _make_flat_style(Color(0.43, 0.30, 0.18, 0.95), GOLD, 5, 0)
	var scroll_hover := _make_flat_style(Color(0.68, 0.49, 0.25, 1.0), GOLD_BRIGHT, 5, 0)
	for scrollbar_type in ["VScrollBar", "HScrollBar"]:
		ui_theme.set_stylebox("scroll", scrollbar_type, scroll_track)
		ui_theme.set_stylebox("grabber", scrollbar_type, scroll_grabber)
		ui_theme.set_stylebox("grabber_highlight", scrollbar_type, scroll_hover)
		ui_theme.set_stylebox("grabber_pressed", scrollbar_type, scroll_hover)
	ui_theme.set_constant("scrollbar_width", "VScrollBar", 7)
	ui_theme.set_constant("grabber_min_size", "VScrollBar", 24)
	return ui_theme


static func panel_style(alpha: float = 0.97) -> StyleBoxFlat:
	var style := _make_flat_style(
		Color(SURFACE.r, SURFACE.g, SURFACE.b, alpha),
		Color(0.43, 0.31, 0.19, 0.95),
		14,
		10
	)
	style.content_margin_left = 15.0
	style.content_margin_top = 13.0
	style.content_margin_right = 15.0
	style.content_margin_bottom = 13.0
	return style


static func card_style(active: bool = false) -> StyleBoxFlat:
	return _make_flat_style(
		SURFACE_RAISED if active else Color(0.12, 0.094, 0.095, 0.98),
		GOLD if active else Color(0.34, 0.25, 0.19, 0.9),
		11,
		4
	)


static func notification_style(success: bool) -> StyleBoxFlat:
	var style := _make_flat_style(
		Color(0.10, 0.079, 0.083, 0.98),
		MINT if success else RED,
		12,
		8
	)
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


static func _apply_button_theme(ui_theme: Theme, theme_type: String) -> void:
	ui_theme.set_stylebox(
		"normal",
		theme_type,
		_make_button_style(Color(0.16, 0.115, 0.11, 1.0), Color(0.42, 0.29, 0.18, 1.0))
	)
	ui_theme.set_stylebox(
		"hover",
		theme_type,
		_make_button_style(Color(0.29, 0.19, 0.15, 1.0), GOLD)
	)
	ui_theme.set_stylebox(
		"pressed",
		theme_type,
		_make_button_style(GOLD, GOLD_BRIGHT)
	)
	ui_theme.set_stylebox(
		"hover_pressed",
		theme_type,
		_make_button_style(GOLD_BRIGHT, Color(1.0, 0.88, 0.62, 1.0))
	)
	ui_theme.set_stylebox(
		"disabled",
		theme_type,
		_make_button_style(Color(0.09, 0.073, 0.076, 1.0), Color(0.22, 0.17, 0.15, 1.0))
	)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = GOLD_BRIGHT
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(10)
	ui_theme.set_stylebox("focus", theme_type, focus)


static func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _make_flat_style(background, border, 10, 3)
	style.content_margin_left = 13.0
	style.content_margin_top = 9.0
	style.content_margin_right = 13.0
	style.content_margin_bottom = 9.0
	return style


static func _make_flat_style(
	background: Color,
	border: Color,
	radius: int,
	shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0.0, 4.0)
	return style
