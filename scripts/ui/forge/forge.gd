class_name Forge
extends Control
## Lists the player's saved armies, and starts new ones: players pick a Grand Alliance, a faction,
## then an Army of Renown or the faction's own rules with a battle formation. Legends factions and
## Armies of Renown are offered only if Settings shows them. Each step shares a
## header, with Back and the steps so far. Pressing a card makes that step's choice and moves on.

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
## The chosen battle formation's name, or empty if none was chosen.
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
	new_army_button.custom_minimum_size.y = 44
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		alliance_buttons[alliance] = _alliance_card(alliance)
		alliance_grid.add_child(alliance_buttons[alliance])
	new_army_button.pressed.connect(show_alliances)
	UITheme.style_dialog(delete_dialog, "DialogDangerButton")
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
	UIBuilder.clear(breadcrumb)
	if shown != Step.ARMIES:
		breadcrumb.add_child(UIBuilder.breadcrumb(breadcrumb_steps(), shown - 1))
	browse_button.visible = shown == Step.RENOWN or shown == Step.FORMATION
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
	UIBuilder.clear(army_list)
	var focus: Control = new_army_button
	for entry in ArmyStore.list():
		var row := _army_row(entry)
		army_list.add_child(row)
		if entry.id == focus_id or (focus_id.is_empty() and focus == new_army_button):
			focus = row.get_meta(&"first_button")
	if army_list.get_child_count() == 0:
		army_list.add_child(load("res://scenes/ui/forge/no_armies_panel.tscn").instantiate())
	_show_step(Step.ARMIES)
	focus.grab_focus()


## A saved army's card: its name, details and status, with Open, Duplicate and Delete.
func _army_row(entry: ArmyStore.Entry) -> PanelContainer:
	var summary := army_summary(entry)
	var card: PanelContainer = load("res://scenes/ui/forge/army_row.tscn").instantiate()
	(card.get_node(^"%Name") as Label).text = summary.name
	(card.get_node(^"%Detail") as Label).text = " · ".join(summary.details)
	if not summary.note.is_empty():
		var note: Label = card.get_node(^"%Note")
		note.text = summary.note
		note.visible = true
	_fill_faction_art(card.get_node(^"%Art"), summary.faction, 36)
	if not summary.status_kind.is_empty():
		var status: PanelContainer = card.get_node(^"%Status")
		status.add_theme_stylebox_override("panel", UITheme.pill(summary.status_kind))
		var status_label: Label = card.get_node(^"%StatusLabel")
		status_label.text = summary.status
		status_label.add_theme_color_override("font_color", UITheme.STATUS[summary.status_kind][1])
		status.visible = true
	var open: Button = card.get_node(^"%Open")
	open.tooltip_text = "Open " + summary.name
	open.disabled = not summary.can_open
	if summary.can_open:
		open.pressed.connect(army_opened.emit.bind(entry.army))
	var copy: Button = card.get_node(^"%Copy")
	_name_icon_button(copy, "Duplicate " + summary.name)
	copy.pressed.connect(_duplicate.bind(entry.id))
	copy.disabled = entry.army == null
	var delete: Button = card.get_node(^"%Delete")
	_name_icon_button(delete, "Delete " + summary.name)
	delete.pressed.connect(_confirm_delete.bind(entry.id, summary.name))
	card.set_meta(&"army_id", entry.id)
	card.set_meta(&"first_button", open if summary.can_open else copy if not copy.disabled else delete)
	return card


static func _name_icon_button(button: Button, label: String) -> void:
	button.tooltip_text = label
	button.accessibility_name = label


## Shows [param faction]'s icon at [param icon_size] on [param art], or its initials if the icon
## pack has none.
static func _fill_faction_art(art: ArtPlaceholder, faction: String, icon_size: int) -> void:
	var icon := UITheme.faction_icon(faction)
	if icon:
		art.set_icon(icon, icon_size)
	else:
		art.set_caption(UIBuilder.initials(faction))


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
	delete_dialog.get_cancel_button().grab_focus()


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
	var card: OptionCard = load("res://scenes/ui/forge/alliance_card.tscn").instantiate()
	card.accessibility_name = alliance_name
	(card.get_node(^"%Art") as ArtPlaceholder).set_icon(UITheme.alliance_icon(alliance), 120)
	(card.get_node(^"%Name") as Label).text = alliance_name
	var count := shown_factions(alliance).size()
	(card.get_node(^"%Count") as Label).text = "%d faction%s" % [count, "" if count == 1 else "s"]
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


## [param alliance]'s factions, without Legends factions unless Settings shows them.
static func shown_factions(alliance: GrandAlliance.Type) -> PackedStringArray:
	var result := PackedStringArray()
	for faction in FactionCatalog.factions_for(alliance):
		if GameSettings.current().show_legends or not FactionCatalog.is_legends(faction):
			result.append(faction)
	return result


func _populate_factions(alliance: GrandAlliance.Type) -> void:
	UIBuilder.clear(faction_grid)
	for faction in shown_factions(alliance):
		var card: OptionCard = load("res://scenes/ui/forge/faction_card.tscn").instantiate()
		card.set_meta(&"faction", faction)
		card.accessibility_name = faction + (" (Legends)" if FactionCatalog.is_legends(faction) else "")
		_fill_faction_art(card.get_node(^"%Art"), faction, 56)
		(card.get_node(^"%Name") as Label).text = faction
		var chips: HBoxContainer = card.get_node(^"%Chips")
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
		chips.visible = chips.get_child_count() > 0
		UIBuilder.ignore_mouse(chips)
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
	UIBuilder.clear(renown_chips)
	if faction.legends:
		renown_chips.add_child(UITheme.chip("Legends", "legends"))
	UIBuilder.clear(renown_none)
	UIBuilder.clear(renown_grid)
	var own := _own_rules_card()
	renown_none.add_child(own)
	var focus: Button = own
	for army in faction.armies_of_renown:
		if army.legends and not GameSettings.current().show_legends:
			continue
		var card := _renown_card(army)
		renown_grid.add_child(card)
		if army.name == _army_of_renown:
			focus = card
	_show_step(Step.RENOWN)
	focus.grab_focus()


## The cards for the faction's own rules and each Army of Renown, in order.
func renown_cards() -> Array[OptionCard]:
	var cards: Array[OptionCard] = []
	for container: Container in [renown_none, renown_grid]:
		for card: OptionCard in container.get_children():
			cards.append(card)
	return cards


func _own_rules_card() -> OptionCard:
	var card: OptionCard = load("res://scenes/ui/forge/own_rules_card.tscn").instantiate()
	_set_choice(card, NO_ARMY_OF_RENOWN, choose_army_of_renown.bind(""))
	card.set_meta(&"army_of_renown", "")
	var faction_icon := UITheme.faction_icon(_faction.name)
	(card.get_node(^"%Icon") as TextureRect).texture = faction_icon if faction_icon else UITheme.alliance_icon(_selected_alliance)
	(card.get_node(^"%Badge") as PanelContainer).add_theme_stylebox_override("panel",
			UITheme.box(Color.TRANSPARENT, UITheme.CONTROL_BORDER, 28, 14))
	var next := "choose a Battle Formation next" if not _formations().is_empty() else "its own rules"
	(card.get_node(^"%Title") as Label).text = NO_ARMY_OF_RENOWN
	(card.get_node(^"%Description") as Label).text = "Use the full %s roster and %s." % [_faction.name, next]
	var chip := UITheme.chip("Recommended for new lists")
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.get_node(^"%Row").add_child(chip)
	return card


func _renown_card(army: ArmyOfRenown) -> OptionCard:
	var card: OptionCard = load("res://scenes/ui/forge/renown_option_card.tscn").instantiate()
	_set_choice(card, army.name + (" (Legends)" if army.legends else ""), choose_army_of_renown.bind(army.name))
	card.set_meta(&"army_of_renown", army.name)
	(card.get_node(^"%Art") as ArtPlaceholder).set_caption(UIBuilder.initials(army.name))
	(card.get_node(^"%Name") as Label).text = army.name
	if not army.source.is_empty():
		var source: Label = card.get_node(^"%Source")
		source.text = army.source
		source.visible = true
	var roster := roster_summary(army)
	if not roster.is_empty():
		var roster_label: Label = card.get_node(^"%Roster")
		roster_label.text = roster
		roster_label.visible = true
	var chips: HFlowContainer = card.get_node(^"%Chips")
	for chip: Array in renown_chips_for(army):
		chips.add_child(UITheme.chip(chip[0], chip[1]))
	chips.visible = chips.get_child_count() > 0
	UIBuilder.ignore_mouse(chips)
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
		if not army.roster.manifestations:
			chips.append(["No manifestations", "warn"])
		if army.roster.entries.any(func(entry: RosterEntry) -> bool: return entry.general):
			chips.append(["Fixed General", ""])
	return chips


## Chooses the Army of Renown named [param army_name], or the faction's own rules if it's empty,
## and moves on: to the battle formations for the faction's own rules, if it has any, else to the
## builder.
func choose_army_of_renown(army_name: String) -> void:
	_army_of_renown = army_name
	if not army_name.is_empty():
		_start(army_name, "")
	elif _formations().is_empty():
		_start("", "")
	else:
		_show_formations()


# --- Battle formation ---


## The faction's battle formations to choose from: those from a Scourge the battlepack doesn't use
## (Legends) are left out, and can only be picked in the builder by overriding army constraints.
func _formations() -> Array[BattleFormation]:
	var result: Array[BattleFormation] = []
	for formation in _faction.battle_formations:
		if not formation.legends:
			result.append(formation)
	return result


func _show_formations() -> void:
	UIBuilder.clear(formation_grid)
	var focus: Button = null
	for formation in _formations():
		var card := _formation_card(formation)
		formation_grid.add_child(card)
		if formation.name == _formation:
			focus = card
	_show_step(Step.FORMATION)
	(focus if focus else formation_grid.get_child(0) as Button).grab_focus()


func _formation_card(formation: BattleFormation) -> OptionCard:
	var card: OptionCard = load("res://scenes/ui/forge/formation_option_card.tscn").instantiate()
	_set_choice(card, formation.name, choose_formation.bind(formation.name))
	card.set_meta(&"formation", formation.name)
	card.min_height = 260
	var chip: PanelContainer
	if formation.points > 0:
		chip = UITheme.chip("%d pts" % formation.points, "gold")
	else:
		chip = UITheme.chip(formation.abilities[0].type if not formation.abilities.is_empty() else "Formation")
	var chips: Array[Control] = [chip]
	chips.append_array(UIBuilder.source_tags(formation.source, formation.legends))
	for tag in chips:
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.get_node(^"%ChipRow").add_child(tag)
	(card.get_node(^"%Name") as Label).text = formation.name
	var rules: VBoxContainer = card.get_node(^"%Rules")
	for ability in formation.abilities:
		rules.add_child(AbilityCard.create(ability))
	UIBuilder.ignore_mouse(card.content)
	return card


## Chooses the battle formation named [param formation_name] and starts the army.
func choose_formation(formation_name: String) -> void:
	_formation = formation_name
	_start("", formation_name)


# --- Shared ---


## Names [param card] [param title] for screen readers, and has it call [param on_pressed] when
## it's pressed.
static func _set_choice(card: OptionCard, title: String, on_pressed: Callable) -> void:
	card.accessibility_name = title
	card.pressed.connect(on_pressed)


func _start(army_of_renown: String, formation: String) -> void:
	var catalog := ArmyCatalog.new(_faction, CoreRulesCatalog.get_rules())
	army_started.emit(ArmyEditor.create_army(catalog, army_of_renown, formation))


func _on_browse_pressed() -> void:
	browse_requested.emit(_selected_alliance, _faction.name)
