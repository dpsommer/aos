class_name Main
extends Node
## Root of the game. Owns screen flow, keeping exactly one screen as a child.

const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const FORGE_SCENE := preload("res://scenes/ui/forge/forge.tscn")
const FACTION_BROWSER_SCENE := preload("res://scenes/ui/forge/faction_browser.tscn")
const ARMY_BUILDER_SCENE := preload("res://scenes/ui/forge/builder/army_builder.tscn")

var current_screen: Node


func _ready() -> void:
	show_main_menu()


func show_main_menu() -> void:
	var menu: MainMenu = _show_screen(MAIN_MENU_SCENE)
	menu.forge_pressed.connect(show_forge)


## Opens the Forge, on [param alliance]'s faction list if one is given, or on [param faction]'s
## Army of Renown choice if that is given too.
func show_forge(alliance: int = -1, faction := "") -> void:
	var forge: Forge = _show_screen(FORGE_SCENE)
	forge.back_pressed.connect(show_main_menu)
	forge.browse_requested.connect(show_faction_browser)
	forge.army_started.connect(show_army_builder)
	if alliance >= 0:
		forge.show_factions(alliance)
		if not faction.is_empty():
			forge.show_armies_of_renown(alliance, faction)


func show_faction_browser(alliance: GrandAlliance.Type, faction_name: String) -> void:
	var faction := FactionCatalog.load_faction(faction_name)
	if faction == null:
		return
	var browser: FactionBrowser = _show_screen(FACTION_BROWSER_SCENE)
	browser.show_faction(faction)
	browser.back_pressed.connect(show_forge.bind(alliance, faction_name))


## Opens the army builder on [param army]. Back returns to the Forge's Army of Renown choice for
## the army's faction.
func show_army_builder(army: Army) -> void:
	var faction_name := FactionCatalog.name_for_id(army.faction_id)
	var faction := FactionCatalog.load_faction(faction_name) if not faction_name.is_empty() else null
	if faction == null:
		push_error("No data for the army's faction '%s'" % army.faction_id)
		return
	var builder: ArmyBuilder = _show_screen(ARMY_BUILDER_SCENE)
	builder.open(army)
	builder.back_pressed.connect(show_forge.bind(faction.grand_alliance, faction_name))


func _show_screen(scene: PackedScene) -> Node:
	if current_screen:
		remove_child(current_screen)
		current_screen.queue_free()
	current_screen = scene.instantiate()
	add_child(current_screen)
	return current_screen
