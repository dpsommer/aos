class_name Forge
extends Control
## Lists the player's saved armies, and starts new ones: players pick a Grand Alliance, a faction,
## then an Army of Renown or the faction's own rules with a battle formation. Each step shares a
## header, with Back and the steps so far, and the last two share a footer to confirm the choice.

signal back_pressed
## The player asked to read [param faction]'s rules in the faction browser.
signal browse_requested(alliance: GrandAlliance.Type, faction: String)
## The player finished choosing; [param army] is a new, empty army.
signal army_started(army: Army)
## The player opened a saved army.
signal army_opened(army: Army)

enum Step { ARMIES, ALLIANCE, FACTION, RENOWN, FORMATION }

## The header's Back button names where it goes.
const BACK_LABELS := {
	Step.ARMIES: "Main menu",
	Step.ALLIANCE: "Armies",
	Step.FACTION: "Grand Alliance",
	Step.RENOWN: "Factions",
	Step.FORMATION: "Army of Renown",
}
## The new army steps, in order, as the breadcrumb names them until they're chosen.
const STEPS: PackedStringArray = ["Grand Alliance", "Faction", "Army of Renown", "Battle Formation", "Builder"]
const NO_ARMY_OF_RENOWN := "No Army of Renown"

var step := Step.ARMIES
var _selected_alliance: GrandAlliance.Type = GrandAlliance.Type.ORDER
var _faction: Faction
## The chosen Army of Renown's name, or empty for the faction's own rules.
var _army_of_renown := ""
## The chosen battle formation's name, or empty if none is chosen yet.
var _formation := ""
## Id of the saved army waiting for the delete confirmation.
var _deleting := ""
## Grand Alliance cards by [enum GrandAlliance.Type].
var alliance_buttons := {}

@onready var back_button: Button = %BackButton
@onready var header_title: Label = %HeaderTitle
@onready var breadcrumb: HBoxContainer = %Breadcrumb
@onready var browse_button: Button = %BrowseButton
@onready var body: ScrollContainer = %Body
@onready var footer: PanelContainer = %Footer
@onready var selected_label: Label = %SelectedLabel
@onready var continue_button: Button = %ContinueButton
@onready var armies_panel: Control = %ArmiesPanel
@onready var army_list: VBoxContainer = %ArmyList
@onready var new_army_button: Button = %NewArmyButton
@onready var delete_dialog: ConfirmationDialog = %DeleteDialog
@onready var alliance_panel: Control = %AlliancePanel
@onready var alliance_grid: GridContainer = %AllianceGrid
@onready var faction_panel: Control = %FactionPanel
@onready var faction_description: Label = %FactionDescription
@onready var faction_grid: GridContainer = %FactionGrid
@onready var renown_panel: Control = %RenownPanel
@onready var renown_description: Label = %RenownDescription
@onready var renown_chips: HBoxContainer = %RenownChips
@onready var renown_none: VBoxContainer = %RenownNone
@onready var renown_grid: GridContainer = %RenownGrid
@onready var formation_panel: Control = %FormationPanel
@onready var formation_grid: GridContainer = %FormationGrid
@onready var panels := {
	Step.ARMIES: armies_panel,
	Step.ALLIANCE: alliance_panel,
	Step.FACTION: faction_panel,
	Step.RENOWN: renown_panel,
	Step.FORMATION: formation_panel,
}


func _ready() -> void:
	theme = UITheme.get_theme()
	back_button.icon = UITheme.icon("back")
	back_button.pressed.connect(go_back)
	browse_button.pressed.connect(_on_browse_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	for button: Button in [new_army_button, continue_button]:
		button.custom_minimum_size.y = 44
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		alliance_buttons[alliance] = _alliance_card(alliance)
		alliance_grid.add_child(alliance_buttons[alliance])
	new_army_button.pressed.connect(show_alliances)
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	delete_dialog.canceled.connect(_on_delete_canceled)
	show_armies()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


## Goes back one step, as the header's Back button does: from the saved armies, leaves the Forge.
func go_back() -> void:
	match step:
		Step.ARMIES:
			back_pressed.emit()
		Step.ALLIANCE:
			show_armies()
		Step.FACTION:
			show_alliances()
		Step.RENOWN:
			show_factions(_selected_alliance)
			for button: Button in faction_grid.get_children():
				if button.get_meta(&"faction") == _faction.name:
					button.grab_focus()
		Step.FORMATION:
			show_armies_of_renown(_selected_alliance, _faction.name)


func _show_step(shown: Step) -> void:
	step = shown
	for panel_step: Step in panels:
		panels[panel_step].visible = panel_step == shown
	back_button.text = BACK_LABELS[shown]
	back_button.tooltip_text = "Back to " + BACK_LABELS[shown].to_lower()
	header_title.visible = shown == Step.ARMIES
	_clear(breadcrumb)
	if shown != Step.ARMIES:
		breadcrumb.add_child(UIBuilder.breadcrumb(breadcrumb_steps(), shown - 1))
	var choosing := shown == Step.RENOWN or shown == Step.FORMATION
	browse_button.visible = choosing
	footer.visible = choosing
	_update_footer()
	body.scroll_vertical = 0


## The breadcrumb's steps, naming the choices made so far.
func breadcrumb_steps() -> PackedStringArray:
	var steps := STEPS.duplicate()
	if step > Step.ALLIANCE:
		steps[0] = GrandAlliance.display_name(_selected_alliance)
	if step > Step.FACTION:
		steps[1] = _faction.name
	if step > Step.RENOWN:
		steps[2] = _army_of_renown if not _army_of_renown.is_empty() else NO_ARMY_OF_RENOWN
	return steps


# --- Saved armies ---


## Shows the saved armies, most recently saved first, focusing the army with [param focus_id] if
## given.
func show_armies(focus_id := "") -> void:
	_clear(army_list)
	var focus: Control = new_army_button
	for entry in ArmyStore.list():
		var row := _army_row(entry)
		army_list.add_child(row)
		if entry.id == focus_id or (focus_id.is_empty() and focus == new_army_button):
			focus = row.get_meta(&"first_button")
	if army_list.get_child_count() == 0:
		var empty := UIBuilder.vbox([
			UIBuilder.label("No saved armies yet", "CardHeadingLabel"),
			UIBuilder.label("Start one with New army.", "DescriptionLabel"),
		], 8)
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		for label: Label in empty.get_children():
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var panel := UIBuilder.panel("EmptyPanel", empty)
		panel.custom_minimum_size.y = 160
		army_list.add_child(panel)
	_show_step(Step.ARMIES)
	focus.grab_focus()


## A saved army's card: its name, details and status, with Open, Duplicate and Delete.
func _army_row(entry: ArmyStore.Entry) -> PanelContainer:
	var summary := army_summary(entry)
	var text := UIBuilder.vbox([UIBuilder.label(summary.name, "CardHeadingLabel")], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var detail := UIBuilder.label(" · ".join(summary.details), "MutedLabel", true)
	detail.add_theme_font_size_override("font_size", 13)
	text.add_child(detail)
	if not summary.note.is_empty():
		text.add_child(UIBuilder.label(summary.note, "WarningLabel", true))
	var art := UIBuilder.art(UIBuilder.initials(summary.faction))
	art.custom_minimum_size = Vector2(56, 56)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UIBuilder.hbox([art, text], 16)
	if not summary.status_kind.is_empty():
		var status := UIBuilder.panel("", UIBuilder.label(summary.status))
		status.add_theme_stylebox_override("panel", UITheme.pill(summary.status_kind))
		(status.get_child(0) as Label).add_theme_color_override("font_color", UITheme.STATUS[summary.status_kind][1])
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(status)
	var open := UIBuilder.button("Open", army_opened.emit.bind(entry.army) if summary.can_open else func() -> void: pass,
			"", "", "Open " + summary.name)
	open.disabled = not summary.can_open
	var copy := UIBuilder.icon_button("copy", "Duplicate " + summary.name, _duplicate.bind(entry.id), "")
	copy.disabled = entry.army == null
	var delete := UIBuilder.icon_button("delete", "Delete " + summary.name, _confirm_delete.bind(entry.id, summary.name),
			"", "DangerIconButton")
	for button: Button in [open, copy, delete]:
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(button)
	var card := UIBuilder.panel("CardPanel", row)
	card.set_meta(&"army_id", entry.id)
	card.set_meta(&"first_button", open if summary.can_open else copy if not copy.disabled else delete)
	return card


## A saved army's summary for its card:
## [br]- [code]name[/code]: the army's name;
## [br]- [code]faction[/code]: its faction's name, or empty if it has no data;
## [br]- [code]details[/code]: the faction, alliance and points, as a [PackedStringArray];
## [br]- [code]status[/code] and [code]status_kind[/code]: "Valid", "N problems" or "Constraints
## overridden", and its [constant UITheme.STATUS] kind; both empty if it can't be checked;
## [br]- [code]note[/code]: why the file couldn't be fully read, or empty;
## [br]- [code]detail[/code]: all of the above on one line;
## [br]- [code]can_open[/code]: false when the file can't be read or its faction has no data.
static func army_summary(entry: ArmyStore.Entry) -> Dictionary:
	var army := entry.army
	var summary := {"name": "", "faction": "", "details": PackedStringArray(), "status": "", "status_kind": "", "note": "",
			"can_open": false}
	if army == null:
		summary.name = "Unreadable army (%s)" % entry.id
		summary.note = " ".join(entry.errors)
	else:
		summary.name = army.name if not army.name.is_empty() else "Unnamed army"
		var faction_name := FactionCatalog.name_for_id(army.faction_id)
		var faction := FactionCatalog.load_faction(faction_name) if not faction_name.is_empty() else null
		if faction == null:
			summary.note = "No data for the faction '%s'" % army.faction_id
		else:
			var catalog := ArmyCatalog.new(faction, CoreRulesCatalog.get_rules())
			summary.faction = faction.name
			summary.details = PackedStringArray([faction.name, GrandAlliance.display_name(faction.grand_alliance),
					"%d / %d pts" % [ArmyPoints.total(army, catalog), army.points_limit]])
			var validation := ArmyValidator.validate(army, catalog)
			if validation.overridden:
				summary.status = "Constraints overridden"
				summary.status_kind = "overridden"
			elif validation.is_valid():
				summary.status = "Valid"
				summary.status_kind = "valid"
			else:
				var count := validation.problems.size()
				summary.status = "%d problem%s" % [count, "" if count == 1 else "s"]
				summary.status_kind = "problems"
			if not entry.errors.is_empty():
				summary.note = "Some saved choices couldn't be read"
			summary.can_open = true
	var parts: PackedStringArray = summary.details.duplicate()
	for part: String in [summary.status, summary.note]:
		if not part.is_empty():
			parts.append(part)
	summary.detail = " · ".join(parts)
	return summary


func _duplicate(id: String) -> void:
	var copy := ArmyStore.copy(id)
	show_armies(copy.id if copy else id)


func _confirm_delete(id: String, army_name: String) -> void:
	_deleting = id
	delete_dialog.dialog_text = "Delete %s? This can't be undone." % army_name
	delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	ArmyStore.delete(_deleting)
	_deleting = ""
	show_armies()


func _on_delete_canceled() -> void:
	var id := _deleting
	_deleting = ""
	show_armies(id)


# --- Grand Alliance and faction ---


func show_alliances() -> void:
	_show_step(Step.ALLIANCE)
	alliance_buttons[_selected_alliance].grab_focus()


func _alliance_card(alliance: GrandAlliance.Type) -> OptionCard:
	var alliance_name := GrandAlliance.display_name(alliance)
	var card := OptionCard.new()
	card.accessibility_name = alliance_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art := UIBuilder.art(alliance_name.left(1), 8, 40)
	art.custom_minimum_size.y = 200
	card.add(art)
	card.add(UIBuilder.label(alliance_name, "CardHeadingLabel"))
	var count := FactionCatalog.factions_for(alliance).size()
	card.add(UIBuilder.label("%d faction%s" % [count, "" if count == 1 else "s"], "MutedLabel"))
	card.pressed.connect(show_factions.bind(alliance))
	return card


func show_factions(alliance: GrandAlliance.Type) -> void:
	_selected_alliance = alliance
	faction_description.text = "The factions of %s. Factions without rules yet are marked Coming soon." % \
			GrandAlliance.display_name(alliance)
	_populate_factions(alliance)
	_show_step(Step.FACTION)
	for button: Button in faction_grid.get_children():
		if not button.disabled:
			button.grab_focus()
			return
	back_button.grab_focus()


func _populate_factions(alliance: GrandAlliance.Type) -> void:
	_clear(faction_grid)
	for faction in FactionCatalog.factions_for(alliance):
		var card := OptionCard.new()
		card.set_meta(&"faction", faction)
		card.accessibility_name = faction + (" (Legends)" if FactionCatalog.is_legends(faction) else "")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var art := UIBuilder.art(UIBuilder.initials(faction))
		art.custom_minimum_size.y = 72
		card.add(art)
		card.add(UIBuilder.label(faction, "CardHeadingLabel", true))
		var chips := UIBuilder.hbox([], 6)
		if FactionCatalog.is_legends(faction):
			chips.add_child(UITheme.chip("Legends", "legends"))
		if FactionCatalog.is_available(faction):
			card.pressed.connect(show_armies_of_renown.bind(alliance, faction))
		else:
			card.disabled = true
			card.content.modulate.a = 0.5
			card.tooltip_text = "Coming soon"
			card.accessibility_description = "Coming soon"
			chips.add_child(UITheme.chip("Coming soon"))
		if chips.get_child_count() > 0:
			card.add(chips)
		else:
			chips.free()
		faction_grid.add_child(card)


# --- Army of Renown ---


## Shows the Army of Renown choice for [param faction_name], of [param alliance]. Does nothing if
## the faction's data can't be loaded.
func show_armies_of_renown(alliance: GrandAlliance.Type, faction_name: String) -> void:
	var faction := FactionCatalog.load_faction(faction_name)
	if faction == null:
		return
	if _faction == null or _faction.name != faction.name:
		_army_of_renown = ""
		_formation = ""
	_selected_alliance = alliance
	_faction = faction
	renown_description.text = ("Optional. An Army of Renown replaces the %s faction rules with its own and limits which"
			+ " units you can take. You can change this later in the builder's settings.") % faction.name
	_clear(renown_chips)
	if faction.legends:
		renown_chips.add_child(UITheme.chip("Legends", "legends"))
	_clear(renown_none)
	_clear(renown_grid)
	var group := ButtonGroup.new()
	var own := _own_rules_card(group)
	renown_none.add_child(own)
	var focus: Button = own
	for army in faction.armies_of_renown:
		var card := _renown_card(army, group)
		renown_grid.add_child(card)
		if army.name == _army_of_renown:
			focus = card
	focus.button_pressed = true
	_show_step(Step.RENOWN)
	focus.grab_focus()


## The cards for the faction's own rules and each Army of Renown, in order.
func renown_cards() -> Array[OptionCard]:
	var cards: Array[OptionCard] = []
	for container: Container in [renown_none, renown_grid]:
		for card: OptionCard in container.get_children():
			cards.append(card)
	return cards


func _own_rules_card(group: ButtonGroup) -> OptionCard:
	var card := _choice_card(group, NO_ARMY_OF_RENOWN, _select_army_of_renown.bind(""))
	card.set_meta(&"army_of_renown", "")
	var icon := TextureRect.new()
	icon.texture = UITheme.icon("shield")
	icon.modulate = UITheme.GOLD
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(26, 26)
	var badge := UIBuilder.panel("", UIBuilder.vbox([icon]))
	badge.add_theme_stylebox_override("panel", UITheme.box(Color.TRANSPARENT, UITheme.CONTROL_BORDER, 28, 14))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var next := "choose a Battle Formation next" if not _faction.battle_formations.is_empty() else "its own rules"
	var text := UIBuilder.vbox([
		UIBuilder.label(NO_ARMY_OF_RENOWN, "CardHeadingLabel"),
		UIBuilder.label("Use the full %s roster and %s." % [_faction.name, next], "DescriptionLabel", true),
	], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chip := UITheme.chip("Recommended for new lists")
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add(UIBuilder.hbox([badge, text, chip], 20))
	return card


func _renown_card(army: ArmyOfRenown, group: ButtonGroup) -> OptionCard:
	var card := _choice_card(group, army.name + (" (Legends)" if army.legends else ""), _select_army_of_renown.bind(army.name))
	card.set_meta(&"army_of_renown", army.name)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art := UIBuilder.art(UIBuilder.initials(army.name))
	art.custom_minimum_size.y = 96
	card.add(art)
	var title := UIBuilder.label(army.name, "CardHeadingLabel", true)
	var heading := UIBuilder.hbox([title], 12)
	if not army.source.is_empty():
		heading.add_child(UIBuilder.label(army.source, "MutedLabel"))
	card.add(heading)
	var roster := roster_summary(army)
	if not roster.is_empty():
		card.add(UIBuilder.label(roster, "BodyLabel", true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for chip: Array in renown_chips_for(army):
		chips.add_child(UITheme.chip(chip[0], chip[1]))
	if chips.get_child_count() > 0:
		card.add(chips)
	else:
		chips.free()
	return card


## The units an Army of Renown can include, from the roster options in its text, e.g.
## "Yndrasta, the Celestial Spear · Hamilcar Bear-Eater". Its text's first sentence if it has none.
static func roster_summary(army: ArmyOfRenown) -> String:
	var lines := PackedStringArray()
	for line in army.text.split("\n", false):
		lines.append(line.strip_edges())
	var start := lines.find("ROSTER OPTIONS")
	if start < 0:
		var first := army.text.get_slice("\n", 0)
		var end := first.find(". ")
		return first if end < 0 else first.left(end + 1)
	var units := PackedStringArray()
	for line in lines.slice(start + 1):
		if not line.begins_with("You cannot include"):
			units.append(line)
	return " · ".join(units)


## Chips for an Army of Renown's card, as [text, chip kind] pairs: Legends, and the roster's
## limits.
static func renown_chips_for(army: ArmyOfRenown) -> Array:
	var chips := []
	if army.legends:
		chips.append(["Legends", "legends"])
	if army.roster:
		if not army.roster.regiments_of_renown:
			chips.append(["No Regiments of Renown", "warn"])
		if not army.roster.faction_terrain:
			chips.append(["No faction terrain", "warn"])
		if army.roster.entries.any(func(entry: RosterEntry) -> bool: return entry.general):
			chips.append(["Fixed General", ""])
	return chips


func _select_army_of_renown(army_name: String) -> void:
	_army_of_renown = army_name
	_update_footer()


# --- Battle formation ---


func _show_formations() -> void:
	_clear(formation_grid)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	var focus: Button = null
	for formation in _faction.battle_formations:
		var card := _formation_card(formation, group)
		formation_grid.add_child(card)
		if formation.name == _formation:
			card.button_pressed = true
			focus = card
	_show_step(Step.FORMATION)
	(focus if focus else formation_grid.get_child(0) as Button).grab_focus()


func _formation_card(formation: BattleFormation, group: ButtonGroup) -> OptionCard:
	var card := _choice_card(group, formation.name, func() -> void: pass)
	card.set_meta(&"formation", formation.name)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.min_height = 260
	var chip: PanelContainer
	if formation.points > 0:
		chip = UITheme.chip("%d pts" % formation.points, "gold")
	else:
		chip = UITheme.chip(formation.abilities[0].type if not formation.abilities.is_empty() else "Formation")
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var check := TextureRect.new()
	check.texture = UITheme.icon("check")
	check.modulate = Color("#17140C")
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.custom_minimum_size = Vector2(14, 14)
	var badge := UIBuilder.panel("", check)
	badge.add_theme_stylebox_override("panel", UITheme.box(UITheme.GOLD, Color.TRANSPARENT, 12, 5))
	badge.visible = false
	var top := UIBuilder.hbox([chip, UIBuilder.spacer(), badge])
	# As tall as the badge, so showing it doesn't move the rest of the card.
	top.custom_minimum_size.y = 24
	card.add(top)
	card.toggled.connect(func(on: bool) -> void:
		badge.visible = on
		_select_formation())
	card.add(UIBuilder.label(formation.name, "CardHeadingLabel", true))
	var rules := UIBuilder.vbox([HSeparator.new()], 12)
	for ability in formation.abilities:
		var ability_name := UIBuilder.label(ability.name, "CardTitleLabel", true)
		ability_name.add_theme_font_size_override("font_size", 14)
		var timing := UIBuilder.label(ability.timing, "MutedLabel")
		rules.add_child(UIBuilder.vbox([UIBuilder.hbox([ability_name, timing]), UIBuilder.rich(RulesFormatter.ability_body(ability))], 6))
	card.add(rules)
	return card


## Picking a card unpresses the one picked before, and pressing the picked card unpicks it.
func _select_formation() -> void:
	_formation = ""
	for card: Button in formation_grid.get_children():
		if card.button_pressed:
			_formation = card.get_meta(&"formation")
	_update_footer()


# --- Shared ---


## A selectable card in [param group], named [param title] for screen readers, calling
## [param on_selected] when it's selected.
func _choice_card(group: ButtonGroup, title: String, on_selected: Callable) -> OptionCard:
	var card := OptionCard.new()
	card.toggle_mode = true
	card.button_group = group
	card.accessibility_name = title
	card.toggled.connect(func(on: bool) -> void:
		if on:
			on_selected.call())
	return card


func _update_footer() -> void:
	match step:
		Step.RENOWN:
			selected_label.text = _army_of_renown if not _army_of_renown.is_empty() else NO_ARMY_OF_RENOWN
			continue_button.disabled = false
			continue_button.text = "Continue to Battle Formation" if _army_of_renown.is_empty() \
					and not _faction.battle_formations.is_empty() else "Continue to Builder"
		Step.FORMATION:
			selected_label.text = _formation if not _formation.is_empty() else "None"
			continue_button.disabled = _formation.is_empty()
			continue_button.text = "Continue to Builder" if not _formation.is_empty() \
					else "Choose a Battle Formation to continue"


func _on_continue_pressed() -> void:
	if step == Step.FORMATION:
		_start("", _formation)
	elif not _army_of_renown.is_empty():
		_start(_army_of_renown, "")
	elif _faction.battle_formations.is_empty():
		# Without battle formations to pick from, the army starts straight away.
		_start("", "")
	else:
		_show_formations()


func _start(army_of_renown: String, formation: String) -> void:
	var catalog := ArmyCatalog.new(_faction, CoreRulesCatalog.get_rules())
	army_started.emit(ArmyEditor.create_army(catalog, army_of_renown, formation))


func _on_browse_pressed() -> void:
	browse_requested.emit(_selected_alliance, _faction.name)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
