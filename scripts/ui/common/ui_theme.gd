class_name UITheme
extends RefCounted
## The game's look, from the Forge design: dark panels, warm text and a gold accent. Every screen
## sets it as its [member Control.theme].
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
const DESCRIPTION := Color("#B8BBC3")
const GOLD := Color("#D9A84A")
const GOLD_DARK := Color("#4A3F2A")
const GOOD := Color("#8FD4B0")
const GOOD_BG := Color("#1D2E26")
const DANGER := Color("#F5A58E")
const DANGER_BG := Color("#3A2620")
const WARNING := Color("#EEC877")
const WARNING_BG := Color("#3A3020")

## An army's status pill colours by kind: [background, text].
const STATUS := {
	"valid": [GOOD_BG, GOOD],
	"problems": [DANGER_BG, DANGER],
	"overridden": [Color("#2A2F38"), Color("#C9CCD3")],
}

## Chip colours by kind: [background, text].
## Chip text is a pale tint of its colour, so the small upper-case text stays easy to read: see
## [constant CHIP_MIN_CONTRAST].
const CHIPS := {
	"": [Color("#2A2F38"), Color("#E6E8EC")],
	"legends": [Color("#33283F"), Color("#EADCFB")],
	"warn": [Color("#3A2A20"), Color("#FFD5C0")],
	"gold": [WARNING_BG, Color("#F8DFA2")],
	"Scourge of Aqshy": [Color("#3A2418"), Color("#FFC9A3")],
	"Scourge of Ghyran": [Color("#1E3324"), Color("#C4EDCA")],
	"affray": [Color("#1E2A38"), Color("#C7DEFA")],
	"strike": [Color("#3A2420"), Color("#FFC8B5")],
	"domination": [Color("#2E2A1A"), Color("#F3E0A0")],
}
## The least WCAG contrast ratio between a chip's text and its background: well above the 7:1 of
## WCAG AAA, as chip text is small.
const CHIP_MIN_CONTRAST := 9.0

## Ability card colours by [member Ability.colour]: [header background, border]. As on the official
## warscrolls, mostly by phase: black for deployment, the start of a turn or round and Battle Damaged,
## yellow (gold) for the hero phase, grey for movement, blue for shooting, orange for charge, red for
## combat, purple for the end of a turn and green for passive abilities.
const ABILITY_COLOURS := {
	"black": [Color("#0E0F12"), Color("#4A4F5A")],
	"yellow": [Color("#7A5A1E"), Color("#B8892F")],
	"grey": [Color("#4A505A"), Color("#6E7582")],
	"blue": [Color("#24527E"), Color("#3D74A8")],
	"orange": [Color("#9A4A16"), Color("#C66A2C")],
	"red": [Color("#8C2A24"), Color("#B8443B")],
	"purple": [Color("#5B3A7E"), Color("#8158AA")],
	"green": [Color("#2F6A3E"), Color("#48925C")],
}
## The least WCAG contrast ratio between an ability card's header text and its colour.
const ABILITY_COLOUR_MIN_CONTRAST := 4.5
## The background of an ability card's inner box, holding its name and rules.
const ABILITY_INNER := Color("#1A1D23")

const INTER := preload("res://assets/2d/fonts/inter/Inter.ttf")
const CINZEL := preload("res://assets/2d/fonts/cinzel/Cinzel.ttf")
## Icons are imported at twice their size so they stay sharp on high-density screens, and shown at
## this size.
const ICON_SIZE := 18
## Each faction's icon in the AoS icon pack, under assets/2d/icons/aos/white/factions/. Factions the pack
## has no icon for (Kruleboyz) are missing.
const FACTION_ICONS := {
	"Cities of Sigmar": "order/cities_of_sigmar",
	"Daughters of Khaine": "order/daughters_of_khaine",
	"Fyreslayers": "order/fyreslayers",
	"Idoneth Deepkin": "order/idoneth_deepkin",
	"Kharadron Overlords": "order/kharadron_overlords",
	"Khazalite Holds": "order/free_peoples/dispossessed",
	"Lumineth Realm-lords": "order/lumineth_realmlords",
	"Seraphon": "order/seraphon",
	"Stormcast Eternals": "order/stormcast_eternals",
	"Sylvaneth": "order/sylvaneth",
	"Beasts of Chaos": "chaos/beasts_of_chaos",
	"Blades of Khorne": "chaos/khorne_bloodbound",
	"Disciples of Tzeentch": "chaos/tzeentch_arcanites",
	"Hedonites of Slaanesh": "chaos/hedonites_of_slaanesh",
	"Helsmiths of Hashut": "chaos/dawi_zharr",
	"Maggotkin of Nurgle": "chaos/maggotkin_of_nurgle",
	"Skaven": "chaos/skaven",
	"Slaves to Darkness": "chaos/slaves_to_darkness",
	"Flesh-eater Courts": "death/flesh_eater_courts",
	"Nighthaunt": "death/nighthaunt",
	"Ossiarch Bonereapers": "death/ossiarch_bonereapers",
	"Soulblight Gravelords": "death/legions_of_nagash",
	"Bonesplitterz": "destruction/bonesplitterz",
	"Gloomspite Gitz": "destruction/gloomspite_gitz",
	"Ironjawz": "destruction/ironjawz",
	"Ogor Mawtribes": "destruction/ogor_mawtribes",
	"Sons of Behemat": "destruction/sons_of_behemat",
}
## Every state a button variation styles.
const BUTTON_STATES: PackedStringArray = ["normal", "hover", "pressed", "disabled", "focus"]

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _create()
	return _theme


## Sets [param dialog]'s title in Cinzel and styles its buttons as Cinzel DialogButtons, its OK button
## as [param ok_variation] (e.g. "DialogGoldButton" for the main action, "DialogDangerButton" for a
## destructive one).
static func style_dialog(dialog: AcceptDialog, ok_variation := "DialogButton") -> void:
	# Overrides, as a window's title takes the theme's default font and size over its Window items.
	dialog.add_theme_font_override("title_font", font(CINZEL, 700))
	dialog.add_theme_font_size_override("title_font_size", 17)
	for button in dialog.get_ok_button().get_parent().get_children():
		if button is Button:
			button.theme_type_variation = &"DialogButton"
	dialog.get_ok_button().theme_type_variation = StringName(ok_variation)


## The width of an icon button of type [param variation], e.g. "GripButton": its icon plus the
## content margins of the nearest type in its variation chain that sets a normal stylebox.
static func icon_button_width(variation := "IconButton") -> float:
	var theme := get_theme()
	var type := StringName(variation)
	while type != &"" and not theme.has_stylebox("normal", type):
		type = theme.get_type_variation_base(type)
	return theme.get_stylebox("normal", type).get_minimum_size().x + theme.get_constant("icon_max_width", variation)


## [param font] at weight [param weight] (100-900), e.g. 600 for semibold Inter.
static func font(base: FontFile, weight: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return variation


static func icon(icon_name: String) -> Texture2D:
	return load("res://assets/2d/icons/%s.svg" % icon_name)


## [param faction]'s icon from the AoS icon pack ([constant FACTION_ICONS]), or null if the pack has none.
static func faction_icon(faction: String) -> Texture2D:
	return icon("aos/white/factions/" + FACTION_ICONS[faction]) if FACTION_ICONS.has(faction) else null


## [param alliance]'s icon from the AoS icon pack.
static func alliance_icon(alliance: GrandAlliance.Type) -> Texture2D:
	return icon("aos/white/factions/grand_alliances/" + GrandAlliance.display_name(alliance).to_lower())


## An icon drawn at [constant ICON_SIZE] where a control can't size its icon, e.g. a [LineEdit]'s.
static func small_icon(icon_name: String) -> Texture2D:
	var image := icon(icon_name).get_image()
	image.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


static func box(color: Color, border := Color.TRANSPARENT, radius := 8, padding := 0, border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width if border.a > 0 else 0)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


## The WCAG contrast ratio between two colours, from 1 (none) to 21 (black on white).
static func contrast(a: Color, b: Color) -> float:
	var lighter := maxf(_luminance(a), _luminance(b))
	var darker := minf(_luminance(a), _luminance(b))
	return (lighter + 0.05) / (darker + 0.05)


## WCAG relative luminance.
static func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


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


## The rounded background of an army's status pill, e.g. "Army valid"; [param kind] is a key of
## [constant STATUS].
static func pill(kind: String) -> StyleBoxFlat:
	var style := box(STATUS[kind][0], Color.TRANSPARENT, 16, 0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func _create() -> Theme:
	var theme := Theme.new()
	theme.default_font = INTER
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", TEXT)
	_add_buttons(theme)
	_add_inputs(theme)
	_add_panels(theme)
	_add_labels(theme)
	_add_rich_text(theme)
	_add_lists_and_dialogs(theme)

	var separator := StyleBoxLine.new()
	separator.color = BORDER
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_stylebox("background", "ProgressBar", box(Color("#2A2F38"), Color.TRANSPARENT, 3))
	theme.set_stylebox("fill", "ProgressBar", box(GOOD, Color.TRANSPARENT, 3))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme


## Buttons, from the plain Button to the icon, banner, tab and card variations.
static func _add_buttons(theme: Theme) -> void:
	var semibold := font(INTER, 600)
	var heading := font(CINZEL, 700)
	_button(theme, "Button", CONTROL, CONTROL_HOVER, CONTROL_BORDER, TEXT)
	_button(theme, "GoldButton", GOLD, Color("#E8BB5E"), GOLD, Color("#17140C"))
	# A destructive action, e.g. deleting an army.
	_button(theme, "DangerButton", Color("#A8402C"), Color("#BC4F39"), Color("#A8402C"), TEXT)
	_button(theme, "GhostButton", Color.TRANSPARENT, Color.TRANSPARENT, CONTROL_BORDER, Color("#C9CCD3"))
	# An empty slot to fill, e.g. a battle tactics card or a lore: a ghost button with a dashed border.
	theme.set_type_variation("DashedButton", "GhostButton")
	var dashed_borders := {"normal": CONTROL_BORDER, "hover": Color("#5A6170"), "pressed": Color("#5A6170"),
			"disabled": CONTROL_BORDER.darkened(0.3)}
	for state: String in dashed_borders:
		var dashed := DashedStyleBox.new(dashed_borders[state], 10, 10)
		if state == "hover" or state == "pressed":
			dashed.bg_color = Color(1, 1, 1, 0.03)
		theme.set_stylebox(state, "DashedButton", dashed)
	_button(theme, "IconButton", Color.TRANSPARENT, Color("#2A2F38"), Color.TRANSPARENT, MUTED)
	theme.set_stylebox("pressed", "IconButton", box(Color("#2A2418"), GOLD_DARK, 6, 6))
	theme.set_color("font_pressed_color", "IconButton", Color("#E2B24F"))
	for state in BUTTON_STATES:
		theme.set_stylebox(state, "IconButton", _square(theme.get_stylebox(state, "IconButton")))
	theme.set_color("icon_normal_color", "IconButton", MUTED)
	theme.set_color("icon_focus_color", "IconButton", MUTED)
	theme.set_color("icon_hover_color", "IconButton", TEXT)
	theme.set_color("icon_pressed_color", "IconButton", Color("#E2B24F"))
	theme.set_color("icon_hover_pressed_color", "IconButton", Color("#E2B24F"))
	theme.set_color("icon_disabled_color", "IconButton", Color(MUTED, 0.35))
	_button(theme, "DangerIconButton", Color.TRANSPARENT, Color("#3A2420"), Color.TRANSPARENT, MUTED)
	theme.set_type_variation("DangerIconButton", "IconButton")
	for state in BUTTON_STATES:
		theme.set_stylebox(state, "DangerIconButton", _square(theme.get_stylebox(state, "DangerIconButton")))
	theme.set_color("icon_hover_color", "DangerIconButton", Color("#F08A70"))
	# A smaller icon button that sits inline with text, e.g. the pencil after a unit's name.
	theme.set_type_variation("SmallIconButton", "IconButton")
	for state in BUTTON_STATES:
		var small := theme.get_stylebox(state, "IconButton").duplicate() as StyleBox
		small.set_content_margin_all(5)
		theme.set_stylebox(state, "SmallIconButton", small)
	theme.set_constant("icon_max_width", "SmallIconButton", 14)
	# The info pane's fold banners, warscroll toggles, tabs and roster cards.
	_button(theme, "BannerButton", Color("#22262E"), Color("#292E37"), Color("#2E333D"), Color("#D8D2C4"))
	for state in BUTTON_STATES:
		var banner := theme.get_stylebox(state, "BannerButton").duplicate() as StyleBoxFlat
		banner.set_corner_radius_all(6)
		banner.content_margin_top = 7
		banner.content_margin_bottom = 7
		theme.set_stylebox(state, "BannerButton", banner)
	theme.set_font("font", "BannerButton", heading)
	theme.set_font_size("font_size", "BannerButton", 13)
	_button(theme, "SubheadButton", Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, TEXT)
	var underline := _underline(BORDER)
	underline.set_content_margin_all(6)
	for state in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(state, "SubheadButton", underline)
	theme.set_color("font_hover_color", "SubheadButton", Color("#F0C46A"))
	_button(theme, "TabButton", Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, MUTED)
	var tab := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	tab.content_margin_left = 12
	tab.content_margin_right = 12
	tab.content_margin_top = 14
	tab.content_margin_bottom = 14
	var tab_on := tab.duplicate() as StyleBoxFlat
	tab_on.border_color = GOLD
	tab_on.border_width_bottom = 2
	theme.set_stylebox("normal", "TabButton", tab)
	theme.set_stylebox("hover", "TabButton", tab)
	theme.set_stylebox("pressed", "TabButton", tab_on)
	theme.set_stylebox("hover_pressed", "TabButton", tab_on)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "icon_hover_color",
			"icon_pressed_color", "icon_hover_pressed_color"]:
		theme.set_color(state, "TabButton", TEXT)
	theme.set_color("icon_normal_color", "TabButton", MUTED)
	theme.set_color("icon_focus_color", "TabButton", MUTED)
	# The key's button inside a KeyChipPanel, which draws its border.
	_button(theme, "KeyButton", Color.TRANSPARENT, CONTROL_HOVER, Color.TRANSPARENT, TEXT)
	for state in BUTTON_STATES:
		var key_style := theme.get_stylebox(state, "KeyButton").duplicate() as StyleBoxFlat
		key_style.set_corner_radius_all(6)
		key_style.content_margin_top = 6
		key_style.content_margin_bottom = 6
		theme.set_stylebox(state, "KeyButton", key_style)
	_button(theme, "CardButton", Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, TEXT)
	# A card button's focus outline is drawn by the card around it (FocusRowPanel), not the button.
	theme.set_stylebox("focus", "CardButton", StyleBoxEmpty.new())
	# Portraits draw their stripes behind the button (see UIBuilder.portrait), so only hover adds a
	# border.
	_button(theme, "PortraitButton", Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, Color("#7E8490"))
	theme.set_stylebox("hover", "PortraitButton", box(Color.TRANSPARENT, GOLD, 6, 0))
	for state in ["normal", "pressed", "disabled"]:
		theme.set_stylebox(state, "PortraitButton", box(Color.TRANSPARENT, Color.TRANSPARENT, 6, 0))
	theme.set_stylebox("focus", "PortraitButton", box(Color.TRANSPARENT, GOLD, 6, 0, 2))
	theme.set_color("font_hover_color", "PortraitButton", TEXT)
	theme.set_font("font", "PortraitButton", heading)
	theme.set_font_size("font_size", "PortraitButton", 12)
	theme.set_type_variation("GripButton", "IconButton")
	theme.set_color("icon_normal_color", "GripButton", Color("#6B717C"))
	theme.set_color("icon_focus_color", "GripButton", Color("#6B717C"))
	for type in ["Button", "IconButton", "DangerIconButton", "GripButton", "GoldButton", "DangerButton", "GhostButton", "BannerButton", "SubheadButton",
			"TabButton"]:
		theme.set_constant("icon_max_width", type, ICON_SIZE)
	theme.set_font("font", "Button", semibold)


## The main menu's buttons, the Forge's option cards, and settings switches, sliders and fields.
static func _add_inputs(theme: Theme) -> void:
	var semibold := font(INTER, 600)
	# The main menu's options.
	for type in ["HeroButton", "HeroGoldButton", "HeroGhostButton"]:
		var base: String = {"HeroButton": "Button", "HeroGoldButton": "GoldButton", "HeroGhostButton": "GhostButton"}[type]
		theme.set_type_variation(type, base)
		for state in BUTTON_STATES:
			var style := theme.get_stylebox(state, base).duplicate() as StyleBoxFlat
			style.content_margin_top = 14
			style.content_margin_bottom = 14
			style.content_margin_left = 24
			style.content_margin_right = 24
			theme.set_stylebox(state, type, style)
		theme.set_font("font", type, font(CINZEL, 700))
		theme.set_font_size("font_size", type, 17)
	# Quick Play's Play button: large gold Cinzel with a glow, or dark while the army can't play.
	theme.set_type_variation("PlayButton", "GoldButton")
	for state in BUTTON_STATES:
		var style := theme.get_stylebox(state, "GoldButton").duplicate() as StyleBoxFlat
		if state == "disabled":
			style = box(CARD, CONTROL_BORDER, 8, 10)
		elif state != "focus":
			style.border_color = Color("#F8DFA2")
			style.shadow_color = Color(GOLD, 0.5)
			style.shadow_size = 18
		style.content_margin_left = 36
		style.content_margin_right = 36
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		theme.set_stylebox(state, "PlayButton", style)
	theme.set_font("font", "PlayButton", font(CINZEL, 700))
	theme.set_font_size("font_size", "PlayButton", 28)
	theme.set_color("font_disabled_color", "PlayButton", Color("#6B717C"))
	theme.set_color("icon_disabled_color", "PlayButton", Color("#6B717C"))
	theme.set_color("icon_normal_color", "PlayButton", Color("#17140C"))
	theme.set_color("icon_hover_color", "PlayButton", Color("#17140C"))
	theme.set_color("icon_pressed_color", "PlayButton", Color("#17140C"))
	theme.set_color("icon_focus_color", "PlayButton", Color("#17140C"))
	# A round "!" badge on an army with problems, naming them in its tooltip.
	_button(theme, "ProblemButton", DANGER_BG, Color("#4A2E26"), Color("#8C2A24"), DANGER)
	for state in BUTTON_STATES:
		var style := theme.get_stylebox(state, "ProblemButton").duplicate() as StyleBoxFlat
		style.set_corner_radius_all(18)
		style.set_content_margin_all(0)
		theme.set_stylebox(state, "ProblemButton", style)
	theme.set_font("font", "ProblemButton", font(INTER, 800))
	theme.set_font_size("font_size", "ProblemButton", 16)

	# Choices in the Forge's steps (OptionCard): selected while pressed.
	_button(theme, "OptionCard", Color("#1A1D23"), Color("#1A1D23"), Color("#2E333D"), TEXT)
	var card_on := box(Color("#211F19"), GOLD, 12, 0, 2)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style: StyleBoxFlat
		match state:
			"pressed", "hover_pressed":
				style = card_on
			"hover":
				style = box(Color("#1A1D23"), Color("#4A515F"), 12, 0)
			"focus":
				# Drawn over the selected border, so a focused selected card shows one outline.
				style = box(Color.TRANSPARENT, GOLD, 12, 0, 2)
			"disabled":
				style = box(Color("#16181C"), Color("#24282F"), 12, 0)
			_:
				style = box(Color("#1A1D23"), Color("#2E333D"), 12, 0)
		theme.set_stylebox(state, "OptionCard", style)
	theme.set_font("font", "OptionButton", semibold)

	# Settings switches.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "CheckButton", box(Color.TRANSPARENT, GOLD, 12, 0, 2))
	theme.set_icon("unchecked", "CheckButton", icon("switch_off"))
	theme.set_icon("checked", "CheckButton", icon("switch_on"))
	theme.set_icon("unchecked_disabled", "CheckButton", icon("switch_off"))
	theme.set_icon("checked_disabled", "CheckButton", icon("switch_on"))
	theme.set_constant("icon_max_width", "CheckButton", 0)

	# Settings sliders: a thin track, filled gold up to a round grabber.
	var track := box(CONTROL, Color.TRANSPARENT, 3, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", box(GOLD, Color.TRANSPARENT, 3, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(Color("#E8BB5E"), Color.TRANSPARENT, 3, 0))
	theme.set_stylebox("focus", "HSlider", box(Color.TRANSPARENT, GOLD, 6, 0, 2))
	theme.set_icon("grabber", "HSlider", icon("slider_grabber"))
	theme.set_icon("grabber_highlight", "HSlider", icon("slider_grabber_highlight"))
	theme.set_icon("grabber_disabled", "HSlider", icon("slider_grabber"))

	var field := box(Color("#14161A"), CONTROL_BORDER, 6, 8)
	for type in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type, field)
		theme.set_stylebox("focus", type, box(Color.TRANSPARENT, GOLD, 6, 8, 2))
		theme.set_color("font_color", type, TEXT)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_icon("clear", "LineEdit", small_icon("close"))
	_button(theme, "OptionButton", CONTROL, CONTROL_HOVER, CONTROL_BORDER, TEXT)


## Panels: cards, rows, regiments, drop targets and warscrolls.
static func _add_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	_panel(theme, "HeaderPanel", box(HEADER, Color("#262A32"), 0, 0))
	# An empty list's placeholder.
	_panel(theme, "EmptyPanel", box(Color.TRANSPARENT, CONTROL_BORDER, 12, 24))
	_panel(theme, "PanePanel", box(PANE, Color("#262A32"), 0, 16))
	_panel(theme, "RegimentPanel", box(REGIMENT, Color("#2E333D"), 10, 12))
	_panel(theme, "RenownRegimentPanel", box(REGIMENT, GOLD_DARK, 10, 12))
	_panel(theme, "CardPanel", box(Color("#1A1D23"), Color("#2E333D"), 10, 14))
	_panel(theme, "RowPanel", box(CARD, BORDER, 8, 8))
	# A bound key in the Settings screen's Input tab: the key's button and its remove button, in one
	# outline, which turns gold while waiting for a new key.
	var key_chip := box(CONTROL, CONTROL_BORDER, 8, 2)
	key_chip.content_margin_right = 4
	_panel(theme, "KeyChipPanel", key_chip)
	var key_chip_on := key_chip.duplicate() as StyleBoxFlat
	key_chip_on.bg_color = Color("#2A2418")
	key_chip_on.border_color = GOLD
	_panel(theme, "KeyChipListeningPanel", key_chip_on)
	_panel(theme, "FlashCardPanel", box(Color("#1A1D23"), GOLD, 10, 14, 2))
	# A chosen card, e.g. a Spearhead's regiment ability or a battleplan.
	_panel(theme, "PickedCardPanel", box(Color("#211F19"), GOLD, 10, 14, 2))
	# Outlines drawn over a card (TacticCard) with keyboard focus, or hovered when it can be pressed.
	theme.set_stylebox("focus", "CardPanel", box(Color.TRANSPARENT, GOLD, 10, 0, 2))
	theme.set_stylebox("hover", "CardPanel", box(Color.TRANSPARENT, Color("#4A515F"), 10, 0))
	_panel(theme, "PickedRowPanel", box(Color("#222019"), GOLD, 8, 8))
	_panel(theme, "FlashRowPanel", box(CARD, GOLD, 8, 8, 2))
	_panel(theme, "FocusRowPanel", box(CARD, GOLD, 8, 8, 2))
	_panel(theme, "FocusPickedRowPanel", box(Color("#222019"), GOLD, 8, 8, 2))
	_panel(theme, "FlashGroupPanel", box(Color.TRANSPARENT, GOLD, 8, 6, 2))
	_panel(theme, "FavouritesPanel", box(Color("#2A2418"), GOLD_DARK, 6, 8))
	_panel(theme, "TabBarPanel", _underline(Color("#262A32")))
	# Drop targets while dragging.
	_panel(theme, "DropRegimentPanel", box(Color("#1D1C18"), GOLD, 10, 12))
	# Replaces the army list's add buttons while a unit that can lead is dragged from the Roster tab.
	var new_regiment := DashedStyleBox.new(GOLD, 10, 14, 2)
	new_regiment.bg_color = Color(GOLD, 0.06)
	_panel(theme, "NewRegimentDropPanel", new_regiment)
	_panel(theme, "NewRegimentDropOnPanel", box(Color("#2A2418"), GOLD, 10, 14, 2))
	_panel(theme, "RemoveDropPanel", box(Color(0.09, 0.1, 0.12, 0.96), Color("#7A4A3E"), 12, 0, 2))
	_panel(theme, "RemoveDropOnPanel", box(Color(0.23, 0.14, 0.13, 0.96), Color("#F2A28A"), 12, 0, 2))
	# Warscrolls (WarscrollCard): characteristics in boxes and each kind of weapon in a table.
	_panel(theme, "WarscrollPanel", box(Color("#16191E"), Color("#343A45"), 8, 12))
	_panel(theme, "FlashWarscrollPanel", box(Color("#16191E"), GOLD, 8, 12, 2))
	var stat := box(CONTROL, Color.TRANSPARENT, 6, 6)
	stat.content_margin_left = 2
	stat.content_margin_right = 2
	_panel(theme, "StatPanel", stat)
	_panel(theme, "WeaponTablePanel", box(Color.TRANSPARENT, BORDER, 6, 1))
	var weapon_header := box(CONTROL, Color.TRANSPARENT, 0, 0)
	weapon_header.corner_radius_top_left = 5
	weapon_header.corner_radius_top_right = 5
	_panel(theme, "WeaponHeaderPanel", weapon_header)
	var weapon_row := box(Color.TRANSPARENT, BORDER, 0, 0)
	weapon_row.border_width_left = 0
	weapon_row.border_width_right = 0
	weapon_row.border_width_bottom = 0
	_panel(theme, "WeaponRowPanel", weapon_row)
	for style: StyleBoxFlat in [weapon_header, weapon_row]:
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 7
	_panel(theme, "ProblemsPanel", box(DANGER_BG, Color.TRANSPARENT, 8, 12))
	_panel(theme, "WarningsPanel", box(WARNING_BG, Color.TRANSPARENT, 8, 12))


## Label variations, from titles to warscroll and ability card text.
static func _add_labels(theme: Theme) -> void:
	var semibold := font(INTER, 600)
	var heading := font(CINZEL, 700)
	_label(theme, "MutedLabel", MUTED, 12)
	_label(theme, "DisplayTitleLabel", TEXT, 56)
	theme.set_font("font", "DisplayTitleLabel", heading)
	_label(theme, "PageTitleLabel", TEXT, 34)
	theme.set_font("font", "PageTitleLabel", heading)
	_label(theme, "CardHeadingLabel", TEXT, 20)
	theme.set_font("font", "CardHeadingLabel", heading)
	_label(theme, "DescriptionLabel", DESCRIPTION, 15)
	_label(theme, "BreadcrumbLabel", MUTED, 13)
	_label(theme, "BreadcrumbCurrentLabel", TEXT, 13)
	theme.set_font("font", "BreadcrumbCurrentLabel", semibold)
	_label(theme, "BodyLabel", Color("#C9CCD3"), 13)
	_label(theme, "ArtLabel", Color("#7E8490"), 14)
	theme.set_font("font", "ArtLabel", heading)
	_label(theme, "TitleLabel", TEXT, 18)
	theme.set_font("font", "TitleLabel", heading)
	_label(theme, "SectionLabel", Color("#D8D2C4"), 20)
	theme.set_font("font", "SectionLabel", heading)
	_label(theme, "CardTitleLabel", TEXT, 15)
	theme.set_font("font", "CardTitleLabel", semibold)
	_label(theme, "FavouritesLabel", WARNING, 13)
	theme.set_font("font", "FavouritesLabel", heading)
	var caps := font(INTER, 600)
	caps.spacing_glyph = 1
	_label(theme, "WarscrollNameLabel", TEXT, 15)
	theme.set_font("font", "WarscrollNameLabel", heading)
	_label(theme, "StatValueLabel", TEXT, 16)
	theme.set_font("font", "StatValueLabel", heading)
	_label(theme, "StatNameLabel", MUTED, 10)
	theme.set_font("font", "StatNameLabel", caps)
	_label(theme, "WeaponTitleLabel", Color("#D8D2C4"), 10)
	theme.set_font("font", "WeaponTitleLabel", caps)
	_label(theme, "WeaponColumnLabel", MUTED, 10)
	theme.set_font("font", "WeaponColumnLabel", caps)
	_label(theme, "WeaponNameLabel", TEXT, 13)
	theme.set_font("font", "WeaponNameLabel", semibold)
	_label(theme, "WeaponValueLabel", TEXT, 13)
	theme.set_font("font", "WeaponValueLabel", font(INTER, 700))
	_label(theme, "KeywordsLabel", MUTED, 11)
	theme.set_font("font", "KeywordsLabel", caps)
	# Ability cards (AbilityCard): the timing in the coloured header, the name in the inner box.
	_label(theme, "AbilityTimingLabel", TEXT, 11)
	theme.set_font("font", "AbilityTimingLabel", caps)
	_label(theme, "AbilityNameLabel", TEXT, 15)
	theme.set_font("font", "AbilityNameLabel", heading)
	_label(theme, "ProblemLabel", DANGER, 13)
	_label(theme, "WarningLabel", WARNING, 13)


static func _add_rich_text(theme: Theme) -> void:
	# Rules text: Inter, with a slanted Inter for italics as the font has no italic.
	var italic := FontVariation.new()
	italic.base_font = INTER
	# The slant goes in the x axis's y component, which FreeType reads as a horizontal shear
	# (see FontVariation.variation_transform); the y axis's x component tilts glyphs backwards.
	italic.variation_transform = Transform2D(Vector2(1, 0.2), Vector2(0, 1), Vector2.ZERO)
	theme.set_font("normal_font", "RichTextLabel", INTER)
	theme.set_font("bold_font", "RichTextLabel", font(INTER, 700))
	theme.set_font("italics_font", "RichTextLabel", italic)
	theme.set_font("bold_italics_font", "RichTextLabel", italic)
	for size in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		theme.set_font_size(size, "RichTextLabel", 13)
	theme.set_color("default_color", "RichTextLabel", Color("#C9CCD3"))
	theme.set_constant("table_h_separation", "RichTextLabel", 10)
	# Space between paragraphs, so a rule's timing, Declare, Effect and keywords read as separate sections.
	theme.set_constant("paragraph_separation", "RichTextLabel", 6)


## The faction browser's tabs and lists, and dialogs.
static func _add_lists_and_dialogs(theme: Theme) -> void:
	var semibold := font(INTER, 600)
	var heading := font(CINZEL, 700)
	# The faction browser's tabs, like the builder's TabButton.
	var tab_bar := _underline(Color("#262A32"))
	theme.set_stylebox("tabbar_background", "TabContainer", tab_bar)
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	var tab_style := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	tab_style.content_margin_left = 14
	tab_style.content_margin_right = 14
	tab_style.content_margin_top = 14
	tab_style.content_margin_bottom = 14
	var tab_selected := tab_style.duplicate() as StyleBoxFlat
	tab_selected.border_color = GOLD
	tab_selected.border_width_bottom = 2
	for type in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_unselected", type, tab_style)
		theme.set_stylebox("tab_hovered", type, tab_style)
		theme.set_stylebox("tab_disabled", type, tab_style)
		theme.set_stylebox("tab_selected", type, tab_selected)
		theme.set_stylebox("tab_focus", type, box(Color.TRANSPARENT, GOLD, 4, 0, 2))
		theme.set_color("font_unselected_color", type, MUTED)
		theme.set_color("font_hovered_color", type, TEXT)
		theme.set_color("font_selected_color", type, TEXT)
		theme.set_font("font", type, semibold)

	# The faction browser's lists.
	theme.set_stylebox("panel", "ItemList", box(PANE, BORDER, 8, 8))
	theme.set_stylebox("focus", "ItemList", box(Color.TRANSPARENT, GOLD, 8, 0, 2))
	theme.set_stylebox("hovered", "ItemList", box(CONTROL, Color.TRANSPARENT, 6, 4))
	for state in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		theme.set_stylebox(state, "ItemList", box(Color("#2A2418"), GOLD_DARK, 6, 4))
	theme.set_stylebox("cursor", "ItemList", box(Color.TRANSPARENT, GOLD, 6, 4))
	theme.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	theme.set_color("font_color", "ItemList", Color("#C9CCD3"))
	# Dialogs: a pane-coloured window. style_dialog() sets its title and buttons in Cinzel.
	var window := box(PANE, CONTROL_BORDER, 10)
	window.expand_margin_left = 8
	window.expand_margin_right = 8
	window.expand_margin_bottom = 8
	window.expand_margin_top = 44
	theme.set_stylebox("embedded_border", "Window", window)
	theme.set_stylebox("embedded_unfocused_border", "Window", window)
	theme.set_constant("title_height", "Window", 40)
	theme.set_color("title_color", "Window", TEXT)
	# When the UI is scaled, a dialog's window can be a pixel wider and taller than its panel, showing
	# the clear colour, so project.godot sets that to PANE too.
	theme.set_stylebox("panel", "AcceptDialog", box(PANE, Color.TRANSPARENT, 0, 12))
	theme.set_constant("buttons_separation", "AcceptDialog", 12)
	for type in ["DialogButton", "DialogGoldButton", "DialogDangerButton"]:
		var base: String = {"DialogButton": "Button", "DialogGoldButton": "GoldButton",
				"DialogDangerButton": "DangerButton"}[type]
		theme.set_type_variation(type, base)
		for state in BUTTON_STATES:
			var style := theme.get_stylebox(state, base).duplicate() as StyleBoxFlat
			style.content_margin_left = 18
			style.content_margin_right = 18
			theme.set_stylebox(state, type, style)
		theme.set_font("font", type, heading)
		theme.set_font_size("font_size", type, 15)

	theme.set_color("font_hovered_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", WARNING)
	theme.set_constant("v_separation", "ItemList", 6)
	theme.set_stylebox("split_bar_background", "HSplitContainer", StyleBoxEmpty.new())


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


## A line along the bottom only.
static func _underline(color: Color) -> StyleBoxFlat:
	var style := box(Color.TRANSPARENT, color, 0, 0)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	return style


static func _panel(theme: Theme, type: String, style: StyleBox) -> void:
	theme.set_type_variation(type, "PanelContainer")
	theme.set_stylebox("panel", type, style)


static func _label(theme: Theme, type: String, color: Color, size: int) -> void:
	theme.set_type_variation(type, "Label")
	theme.set_color("font_color", type, color)
	theme.set_font_size("font_size", type, size)
