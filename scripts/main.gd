class_name Main
extends Node
## Root of the game. Owns screen flow, keeping exactly one screen as a child.

const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const FORGE_SCENE := preload("res://scenes/ui/forge/forge.tscn")
const FACTION_BROWSER_SCENE := preload("res://scenes/ui/forge/faction_browser.tscn")

var current_screen: Node


func _ready() -> void:
	show_main_menu()


func show_main_menu() -> void:
	var menu: MainMenu = _show_screen(MAIN_MENU_SCENE)
	menu.forge_pressed.connect(show_forge)


## Opens the Forge, on [param alliance]'s faction list if one is given.
func show_forge(alliance: int = -1) -> void:
	var forge: Forge = _show_screen(FORGE_SCENE)
	forge.back_pressed.connect(show_main_menu)
	forge.faction_selected.connect(show_faction_browser)
	if alliance >= 0:
		forge.show_factions(alliance)


func show_faction_browser(alliance: GrandAlliance.Type, faction_name: String) -> void:
	var faction := FactionCatalog.load_faction(faction_name)
	if faction == null:
		return
	var browser: FactionBrowser = _show_screen(FACTION_BROWSER_SCENE)
	browser.show_faction(faction)
	browser.back_pressed.connect(show_forge.bind(alliance))


func _show_screen(scene: PackedScene) -> Node:
	if current_screen:
		remove_child(current_screen)
		current_screen.queue_free()
	current_screen = scene.instantiate()
	add_child(current_screen)
	return current_screen
