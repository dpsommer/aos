class_name ForgeTheme
extends RefCounted
## The army builder's look, from the Forge design: dark panels, warm text and a gold accent.
## Variations are named with [code]theme_type_variation[/code], e.g. "GoldButton" or "CardPanel".

const BACKGROUND := Color("#121418")
const HEADER := Color("#15171B")
const PANE := Color("#171A1F")
const CARD := Color("#1C1F25")
const REGIMENT := Color("#181B20")
const CONTROL := Color("#22262E")
const CONTROL_HOVER := Color("#2C313B")
const BORDER := Color("#2B3039")
const CONTROL_BORDER := Color("#3A404C")
const TEXT := Color("#ECE7DC")
const MUTED := Color("#A9ADB6")
const GOLD := Color("#D9A84A")
const GOLD_DARK := Color("#4A3F2A")
const GOOD := Color("#8FD4B0")
const GOOD_BG := Color("#1D2E26")
const DANGER := Color("#F5A58E")
const DANGER_BG := Color("#3A2620")
const WARNING := Color("#EEC877")
const WARNING_BG := Color("#3A3020")

## Chip colours by kind: [background, text].
const CHIPS := {
	"": [Color("#2A2F38"), Color("#C3C7CF")],
	"legends": [Color("#33283F"), Color("#D5BFF0")],
	"gold": [WARNING_BG, WARNING],
	"Scourge of Aqshy": [Color("#3A2418"), Color("#F4A571")],
	"Scourge of Ghyran": [Color("#1E3324"), Color("#9FD8A8")],
	"affray": [Color("#1E2A38"), Color("#9CC3F0")],
	"strike": [Color("#3A2420"), Color("#F2A28A")],
	"domination": [Color("#2E2A1A"), Color("#E2C773")],
}

const INTER := preload("res://assets/2d/fonts/inter/Inter.ttf")
const CINZEL := preload("res://assets/2d/fonts/cinzel/Cinzel.ttf")
## Icons are imported at twice their size so they stay sharp on high-density screens, and shown at
## this size.
const ICON_SIZE := 18

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _create()
	return _theme


## [param font] at weight [param weight] (100-900), e.g. 600 for semibold Inter.
static func font(base: FontFile, weight: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return variation


static func icon(icon_name: String) -> Texture2D:
	return load("res://assets/2d/icons/%s.svg" % icon_name)


static func box(color: Color, border := Color.TRANSPARENT, radius := 8, padding := 0, border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width if border.a > 0 else 0)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


## A small coloured label, e.g. a Scourge of Aqshy tag or a battle tactic's kind.
static func chip(text: String, kind := "") -> PanelContainer:
	var colors: Array = CHIPS.get(kind, CHIPS[""])
	var panel := PanelContainer.new()
	var style := box(colors[0], Color.TRANSPARENT, 4)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", colors[1])
	panel.add_child(label)
	return panel


static func _create() -> Theme:
	var theme := Theme.new()
	theme.default_font = INTER
	theme.default_font_size = 14
	var semibold := font(INTER, 600)
	var heading := font(CINZEL, 700)
	theme.set_color("font_color", "Label", TEXT)

	_button(theme, "Button", CONTROL, CONTROL_HOVER, CONTROL_BORDER, TEXT)
	_button(theme, "GoldButton", GOLD, Color("#E8BB5E"), GOLD, Color("#17140C"))
	_button(theme, "GhostButton", Color.TRANSPARENT, Color.TRANSPARENT, CONTROL_BORDER, Color("#C9CCD3"))
	_button(theme, "IconButton", Color.TRANSPARENT, Color("#2A2F38"), Color.TRANSPARENT, MUTED)
	theme.set_stylebox("pressed", "IconButton", box(Color("#2A2418"), GOLD_DARK, 6, 6))
	theme.set_color("font_pressed_color", "IconButton", Color("#E2B24F"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "IconButton", _square(theme.get_stylebox(state, "IconButton")))
	theme.set_color("icon_normal_color", "IconButton", MUTED)
	theme.set_color("icon_focus_color", "IconButton", MUTED)
	theme.set_color("icon_hover_color", "IconButton", TEXT)
	theme.set_color("icon_pressed_color", "IconButton", Color("#E2B24F"))
	theme.set_color("icon_hover_pressed_color", "IconButton", Color("#E2B24F"))
	theme.set_color("icon_disabled_color", "IconButton", Color(MUTED, 0.35))
	_button(theme, "DangerIconButton", Color.TRANSPARENT, Color("#3A2420"), Color.TRANSPARENT, MUTED)
	theme.set_type_variation("DangerIconButton", "IconButton")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "DangerIconButton", _square(theme.get_stylebox(state, "DangerIconButton")))
	theme.set_color("icon_hover_color", "DangerIconButton", Color("#F08A70"))
	for type in ["Button", "IconButton", "DangerIconButton", "GoldButton", "GhostButton"]:
		theme.set_constant("icon_max_width", type, ICON_SIZE)
	theme.set_font("font", "Button", semibold)
	theme.set_font("font", "OptionButton", semibold)

	var field := box(Color("#14161A"), CONTROL_BORDER, 6, 8)
	for type in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type, field)
		theme.set_stylebox("focus", type, box(Color.TRANSPARENT, GOLD, 6, 8, 2))
		theme.set_color("font_color", type, TEXT)
	theme.set_stylebox("read_only", "LineEdit", field)
	_button(theme, "OptionButton", CONTROL, CONTROL_HOVER, CONTROL_BORDER, TEXT)

	theme.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	_panel(theme, "HeaderPanel", box(HEADER, Color("#262A32"), 0, 0))
	_panel(theme, "PanePanel", box(PANE, Color("#262A32"), 0, 16))
	_panel(theme, "RegimentPanel", box(REGIMENT, Color("#2E333D"), 10, 12))
	_panel(theme, "RenownRegimentPanel", box(REGIMENT, GOLD_DARK, 10, 12))
	_panel(theme, "CardPanel", box(Color("#1A1D23"), Color("#2E333D"), 10, 14))
	_panel(theme, "RowPanel", box(CARD, BORDER, 8, 8))
	_panel(theme, "ProblemsPanel", box(DANGER_BG, Color.TRANSPARENT, 8, 12))
	_panel(theme, "WarningsPanel", box(WARNING_BG, Color.TRANSPARENT, 8, 12))

	_label(theme, "MutedLabel", MUTED, 12)
	_label(theme, "TitleLabel", TEXT, 18)
	theme.set_font("font", "TitleLabel", heading)
	_label(theme, "SectionLabel", Color("#D8D2C4"), 16)
	theme.set_font("font", "SectionLabel", heading)
	_label(theme, "ProblemLabel", DANGER, 13)
	_label(theme, "WarningLabel", WARNING, 13)

	theme.set_stylebox("background", "ProgressBar", box(Color("#2A2F38"), Color.TRANSPARENT, 3))
	theme.set_stylebox("fill", "ProgressBar", box(GOOD, Color.TRANSPARENT, 3))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme


static func _button(theme: Theme, type: String, color: Color, hover: Color, border: Color, font: Color) -> void:
	if type != "Button" and type != "OptionButton":
		theme.set_type_variation(type, "Button")
	theme.set_stylebox("normal", type, box(color, border, 8, 10))
	theme.set_stylebox("hover", type, box(hover, border.lightened(0.15) if border.a > 0 else border, 8, 10))
	theme.set_stylebox("pressed", type, box(hover, border, 8, 10))
	theme.set_stylebox("disabled", type, box(color.darkened(0.3) if color.a > 0 else color, border.darkened(0.3), 8, 10))
	# A gold outline on keyboard focus, as in the design.
	theme.set_stylebox("focus", type, box(Color.TRANSPARENT, GOLD, 8, 10, 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, font)
	theme.set_color("font_disabled_color", type, Color(font, 0.4))


## Icon buttons are square, with the icon centred.
static func _square(style: StyleBox) -> StyleBox:
	var square := style.duplicate() as StyleBox
	square.set_content_margin_all(7)
	return square


static func _panel(theme: Theme, type: String, style: StyleBox) -> void:
	theme.set_type_variation(type, "PanelContainer")
	theme.set_stylebox("panel", type, style)


static func _label(theme: Theme, type: String, color: Color, size: int) -> void:
	theme.set_type_variation(type, "Label")
	theme.set_color("font_color", type, color)
	theme.set_font_size("font_size", type, size)
