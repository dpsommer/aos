extends GutTest
## Unit tests for top-level screen flow (scripts/main.gd).

const MainScene := preload("res://scenes/main.tscn")


## Screens and faction buttons are removed with queue_free, so let a frame pass for
## them to be freed before GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame


## Returns a fresh Main instance added to the tree, which shows its first screen on ready.
func _make_main() -> Main:
	var main: Main = MainScene.instantiate()
	add_child_autofree(main)
	return main


func test_starts_on_main_menu() -> void:
	var main := _make_main()
	assert_is(main.current_screen, MainMenu)


func test_starts_with_one_child() -> void:
	var main := _make_main()
	assert_eq(main.get_child_count(), 1)


func test_current_screen_is_a_child() -> void:
	var main := _make_main()
	assert_eq(main.current_screen.get_parent(), main)


func test_menu_forge_pressed_shows_forge() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	assert_is(main.current_screen, Forge)


func test_menu_forge_pressed_leaves_one_child() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	assert_eq(main.get_child_count(), 1)


func test_menu_forge_pressed_frees_menu() -> void:
	var main := _make_main()
	var menu := main.current_screen
	menu.forge_pressed.emit()
	assert_true(menu.is_queued_for_deletion())


func test_forge_back_pressed_shows_main_menu() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	(main.current_screen as Forge).back_pressed.emit()
	assert_is(main.current_screen, MainMenu)


func test_forge_back_pressed_leaves_one_child() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	(main.current_screen as Forge).back_pressed.emit()
	assert_eq(main.get_child_count(), 1)


func test_returned_main_menu_can_open_forge_again() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	(main.current_screen as Forge).back_pressed.emit()
	(main.current_screen as MainMenu).forge_pressed.emit()
	assert_is(main.current_screen, Forge)


## Returns [alliance, faction name] for the first faction with data.
func _available_faction() -> Array:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction in FactionCatalog.factions_for(alliance):
			if FactionCatalog.is_available(faction):
				return [alliance, faction]
	fail_test("no faction is available")
	return [GrandAlliance.Type.values()[0], ""]


## Opens the Forge from the menu and selects [param choice], an [alliance, faction name] pair.
func _select_faction(main: Main, choice: Array) -> void:
	(main.current_screen as MainMenu).forge_pressed.emit()
	(main.current_screen as Forge).faction_selected.emit(choice[0], choice[1])


func test_menu_forge_pressed_opens_forge_on_alliance_panel() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	assert_true((main.current_screen as Forge).alliance_panel.visible)


func test_forge_faction_selected_shows_faction_browser() -> void:
	var main := _make_main()
	_select_faction(main, _available_faction())
	assert_is(main.current_screen, FactionBrowser)


func test_faction_browser_shows_selected_faction() -> void:
	var main := _make_main()
	var choice := _available_faction()
	_select_faction(main, choice)
	assert_eq((main.current_screen as FactionBrowser).title.text, choice[1])


func test_forge_faction_selected_leaves_one_child() -> void:
	var main := _make_main()
	_select_faction(main, _available_faction())
	assert_eq(main.get_child_count(), 1)


func test_selecting_faction_without_data_stays_on_forge() -> void:
	var main := _make_main()
	var choice := [GrandAlliance.Type.values()[0], "Not A Real Faction"]
	_select_faction(main, choice)
	assert_push_error(choice[1])
	assert_is(main.current_screen, Forge)


func test_browser_back_pressed_shows_forge() -> void:
	var main := _make_main()
	_select_faction(main, _available_faction())
	(main.current_screen as FactionBrowser).back_pressed.emit()
	assert_is(main.current_screen, Forge)


func test_browser_back_pressed_leaves_one_child() -> void:
	var main := _make_main()
	_select_faction(main, _available_faction())
	(main.current_screen as FactionBrowser).back_pressed.emit()
	assert_eq(main.get_child_count(), 1)


func test_browser_back_pressed_shows_faction_panel() -> void:
	var main := _make_main()
	_select_faction(main, _available_faction())
	(main.current_screen as FactionBrowser).back_pressed.emit()
	assert_true((main.current_screen as Forge).faction_panel.visible)


func test_browser_back_pressed_lists_selected_alliances_factions() -> void:
	var main := _make_main()
	var choice := _available_faction()
	_select_faction(main, choice)
	(main.current_screen as FactionBrowser).back_pressed.emit()
	assert_eq((main.current_screen as Forge).faction_title.text, GrandAlliance.display_name(choice[0]))


func test_returned_forge_can_open_browser_again() -> void:
	var main := _make_main()
	var choice := _available_faction()
	_select_faction(main, choice)
	(main.current_screen as FactionBrowser).back_pressed.emit()
	(main.current_screen as Forge).faction_selected.emit(choice[0], choice[1])
	assert_is(main.current_screen, FactionBrowser)


func test_returned_forge_back_pressed_shows_main_menu() -> void:
	var main := _make_main()
	_select_faction(main, _available_faction())
	(main.current_screen as FactionBrowser).back_pressed.emit()
	(main.current_screen as Forge).back_pressed.emit()
	assert_is(main.current_screen, MainMenu)
