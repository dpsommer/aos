class_name Forge
extends Control
## Starts an army: players pick a Grand Alliance, a faction, then an Army of Renown or the faction's
## own rules with a battle formation.

signal back_pressed
## The player asked to read [param faction]'s rules in the faction browser.
signal browse_requested(alliance: GrandAlliance.Type, faction: String)
## The player finished choosing; [param army] is a new, empty army.
signal army_started(army: Army)

const BUTTON_SIZE := Vector2(360, 48)

var _selected_alliance: GrandAlliance.Type = GrandAlliance.Type.ORDER
var _faction: Faction

@onready var alliance_panel: Control = %AlliancePanel
@onready var faction_panel: Control = %FactionPanel
@onready var faction_title: Label = %FactionTitle
@onready var faction_grid: GridContainer = %FactionGrid
@onready var alliance_back_button: Button = %AllianceBackButton
@onready var faction_back_button: Button = %FactionBackButton
@onready var renown_panel: Control = %RenownPanel
@onready var renown_title: Label = %RenownTitle
@onready var renown_list: VBoxContainer = %RenownList
@onready var browse_button: Button = %BrowseButton
@onready var renown_back_button: Button = %RenownBackButton
@onready var formation_panel: Control = %FormationPanel
@onready var formation_title: Label = %FormationTitle
@onready var formation_list: VBoxContainer = %FormationList
@onready var formation_back_button: Button = %FormationBackButton
@onready var alliance_buttons := {
	GrandAlliance.Type.ORDER: %OrderButton as Button,
	GrandAlliance.Type.CHAOS: %ChaosButton as Button,
	GrandAlliance.Type.DEATH: %DeathButton as Button,
	GrandAlliance.Type.DESTRUCTION: %DestructionButton as Button,
}


func _ready() -> void:
	for alliance: GrandAlliance.Type in alliance_buttons:
		alliance_buttons[alliance].pressed.connect(show_factions.bind(alliance))
	alliance_back_button.pressed.connect(_on_alliance_back_pressed)
	faction_back_button.pressed.connect(_on_faction_back_pressed)
	browse_button.pressed.connect(_on_browse_pressed)
	renown_back_button.pressed.connect(_on_renown_back_pressed)
	formation_back_button.pressed.connect(_on_formation_back_pressed)
	show_alliances()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if formation_panel.visible:
			_on_formation_back_pressed()
		elif renown_panel.visible:
			_on_renown_back_pressed()
		elif faction_panel.visible:
			_on_faction_back_pressed()
		else:
			_on_alliance_back_pressed()


func _show_only(panel: Control) -> void:
	for other: Control in [alliance_panel, faction_panel, renown_panel, formation_panel]:
		other.visible = other == panel


func show_alliances() -> void:
	_show_only(alliance_panel)
	alliance_buttons[_selected_alliance].grab_focus()


func show_factions(alliance: GrandAlliance.Type) -> void:
	_selected_alliance = alliance
	faction_title.text = GrandAlliance.display_name(alliance)
	_populate_factions(alliance)
	_show_only(faction_panel)
	for button: Button in faction_grid.get_children():
		if not button.disabled:
			button.grab_focus()
			return
	faction_back_button.grab_focus()


## Shows the Army of Renown choice for [param faction_name], of [param alliance]. Does nothing if
## the faction's data can't be loaded.
func show_armies_of_renown(alliance: GrandAlliance.Type, faction_name: String) -> void:
	var faction := FactionCatalog.load_faction(faction_name)
	if faction == null:
		return
	_selected_alliance = alliance
	_faction = faction
	renown_title.text = faction.name + (" (Legends)" if faction.legends else "")
	_clear(renown_list)
	var own := _add_choice(renown_list, "None (%s rules)" % faction.name, _on_own_rules_pressed)
	for army in faction.armies_of_renown:
		_add_choice(renown_list, army.name + (" (Legends)" if army.legends else ""),
				_start.bind(army.name, "")).set_meta(&"army_of_renown", army.name)
	_show_only(renown_panel)
	own.grab_focus()


func _show_formations() -> void:
	formation_title.text = _faction.name
	_clear(formation_list)
	for formation in _faction.battle_formations:
		var label := formation.name + (" (%d pts)" % formation.points if formation.points > 0 else "")
		_add_choice(formation_list, label, _start.bind("", formation.name)).set_meta(&"formation", formation.name)
	_show_only(formation_panel)
	(formation_list.get_child(0) as Button).grab_focus()


func _add_choice(list: VBoxContainer, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.pressed.connect(on_pressed)
	list.add_child(button)
	return button


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _populate_factions(alliance: GrandAlliance.Type) -> void:
	_clear(faction_grid)
	for faction in FactionCatalog.factions_for(alliance):
		var button := Button.new()
		button.text = faction + (" (Legends)" if FactionCatalog.is_legends(faction) else "")
		button.set_meta(&"faction", faction)
		button.custom_minimum_size = Vector2(240, 48)
		if FactionCatalog.is_available(faction):
			button.pressed.connect(show_armies_of_renown.bind(alliance, faction))
		else:
			button.disabled = true
			button.tooltip_text = "Coming soon"
		faction_grid.add_child(button)


## Without battle formations to pick from, the army starts straight away.
func _on_own_rules_pressed() -> void:
	if _faction.battle_formations.is_empty():
		_start("", "")
	else:
		_show_formations()


func _start(army_of_renown: String, formation: String) -> void:
	var catalog := ArmyCatalog.new(_faction, CoreRulesCatalog.get_rules())
	army_started.emit(ArmyEditor.create_army(catalog, army_of_renown, formation))


func _on_browse_pressed() -> void:
	browse_requested.emit(_selected_alliance, _faction.name)


func _on_alliance_back_pressed() -> void:
	back_pressed.emit()


func _on_faction_back_pressed() -> void:
	show_alliances()


func _on_renown_back_pressed() -> void:
	show_factions(_selected_alliance)
	for button: Button in faction_grid.get_children():
		if button.get_meta(&"faction") == _faction.name:
			button.grab_focus()


func _on_formation_back_pressed() -> void:
	show_armies_of_renown(_selected_alliance, _faction.name)
