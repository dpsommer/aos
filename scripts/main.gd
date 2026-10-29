class_name Main
extends Node
## Root of the game. Owns screen flow, keeping exactly one screen as a child, and applies the
## player's settings.

const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const FORGE_SCENE := preload("res://scenes/ui/forge/forge.tscn")
const FACTION_BROWSER_SCENE := preload("res://scenes/ui/forge/faction_browser.tscn")
const ARMY_BUILDER_SCENE := preload("res://scenes/ui/forge/builder/army_builder.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_screen.tscn")

var current_screen: Node


func _ready() -> void:
	if _is_game():
		GameSettings.current().apply(get_window())
		GameSettings.current().read_window(get_window())
		get_window().dpi_changed.connect(func() -> void: GameSettings.current().apply_graphics(get_window()))
	show_main_menu()


func _notification(what: int) -> void:
	if not _is_game():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		GameSettings.current().apply_focus(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		GameSettings.current().apply_focus(true)


## Whether this is the running game's Main, rather than one a test made: only that one applies
## settings, so tests leave the test runner's window alone.
func _is_game() -> bool:
	return is_inside_tree() and get_tree().current_scene == self


func show_main_menu() -> void:
	var menu: MainMenu = _show_screen(MAIN_MENU_SCENE)
	menu.forge_pressed.connect(show_forge)
	menu.settings_pressed.connect(show_settings)


func show_settings() -> void:
	var settings: SettingsScreen = _show_screen(SETTINGS_SCENE)
	settings.back_pressed.connect(show_main_menu)


## Opens the Forge on its saved armies, focusing [param army_id]'s if given; or on [param alliance]'s
## faction list if one is given, or on [param faction]'s Army of Renown choice if that is given too.
func show_forge(alliance: int = -1, faction := "", army_id := "") -> void:
	var forge: Forge = _show_screen(FORGE_SCENE)
	forge.back_pressed.connect(show_main_menu)
	forge.browse_requested.connect(show_faction_browser)
	forge.army_started.connect(show_army_builder)
	forge.army_opened.connect(show_army_builder)
	if not army_id.is_empty():
		forge.show_armies(army_id)
	elif alliance >= 0:
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


## Opens the army builder on [param army]. Back returns to the Forge's saved armies.
func show_army_builder(army: Army) -> void:
	var faction_name := FactionCatalog.name_for_id(army.faction_id)
	var faction := FactionCatalog.load_faction(faction_name) if not faction_name.is_empty() else null
	if faction == null:
		push_error("No data for the army's faction '%s'" % army.faction_id)
		return
	var builder: ArmyBuilder = _show_screen(ARMY_BUILDER_SCENE)
	builder.open(army)
	builder.back_pressed.connect(func() -> void: show_forge(-1, "", army.id))


func _show_screen(scene: PackedScene) -> Node:
	if current_screen:
		remove_child(current_screen)
		current_screen.queue_free()
	current_screen = scene.instantiate()
	add_child(current_screen)
	return current_screen
