class_name Forge
extends Control
## Army builder. Players pick a Grand Alliance, then a faction from that alliance.

signal back_pressed
signal faction_selected(alliance: GrandAlliance.Type, faction: String)

var _selected_alliance: GrandAlliance.Type = GrandAlliance.Type.ORDER

@onready var alliance_panel: Control = %AlliancePanel
@onready var faction_panel: Control = %FactionPanel
@onready var faction_title: Label = %FactionTitle
@onready var faction_grid: GridContainer = %FactionGrid
@onready var alliance_back_button: Button = %AllianceBackButton
@onready var faction_back_button: Button = %FactionBackButton
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
	show_alliances()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if faction_panel.visible:
			_on_faction_back_pressed()
		else:
			_on_alliance_back_pressed()


func show_alliances() -> void:
	faction_panel.hide()
	alliance_panel.show()
	alliance_buttons[_selected_alliance].grab_focus()


func show_factions(alliance: GrandAlliance.Type) -> void:
	_selected_alliance = alliance
	faction_title.text = GrandAlliance.display_name(alliance)
	_populate_factions(alliance)
	alliance_panel.hide()
	faction_panel.show()
	for button: Button in faction_grid.get_children():
		if not button.disabled:
			button.grab_focus()
			return
	faction_back_button.grab_focus()


func _populate_factions(alliance: GrandAlliance.Type) -> void:
	for child in faction_grid.get_children():
		faction_grid.remove_child(child)
		child.queue_free()
	for faction in FactionCatalog.factions_for(alliance):
		var button := Button.new()
		button.text = faction + (" (Legends)" if FactionCatalog.is_legends(faction) else "")
		button.set_meta(&"faction", faction)
		button.custom_minimum_size = Vector2(240, 48)
		if FactionCatalog.is_available(faction):
			button.pressed.connect(_on_faction_pressed.bind(faction))
		else:
			button.disabled = true
			button.tooltip_text = "Coming soon"
		faction_grid.add_child(button)


func _on_faction_pressed(faction: String) -> void:
	faction_selected.emit(_selected_alliance, faction)


func _on_alliance_back_pressed() -> void:
	back_pressed.emit()


func _on_faction_back_pressed() -> void:
	show_alliances()
