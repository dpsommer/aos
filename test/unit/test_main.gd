extends GutTest
## Unit tests for top-level screen flow (scripts/main.gd).

const MainScene := preload("res://scenes/main.tscn")
const Sandbox := preload("res://test/support/sandbox.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")


## Screens and faction buttons are removed with queue_free, so let a frame pass for
## them to be freed before GUT counts orphans.
func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	await get_tree().process_frame
	Sandbox.end()


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


# --- Settings ---


func test_menu_settings_pressed_shows_settings() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).settings_pressed.emit()
	assert_is(main.current_screen, SettingsScreen)


func test_menu_settings_pressed_leaves_one_child() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).settings_pressed.emit()
	assert_eq(main.get_child_count(), 1)


func test_show_settings_shows_settings() -> void:
	var main := _make_main()
	main.show_settings()
	assert_is(main.current_screen, SettingsScreen)


func test_settings_back_pressed_shows_main_menu() -> void:
	var main := _make_main()
	main.show_settings()
	(main.current_screen as SettingsScreen).back_pressed.emit()
	assert_is(main.current_screen, MainMenu)


func test_settings_back_pressed_leaves_one_child() -> void:
	var main := _make_main()
	main.show_settings()
	(main.current_screen as SettingsScreen).back_pressed.emit()
	assert_eq(main.get_child_count(), 1)


func test_returned_main_menu_can_open_settings_again() -> void:
	var main := _make_main()
	main.show_settings()
	(main.current_screen as SettingsScreen).back_pressed.emit()
	(main.current_screen as MainMenu).settings_pressed.emit()
	assert_is(main.current_screen, SettingsScreen)


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
	(main.current_screen as Forge).browse_requested.emit(choice[0], choice[1])


func test_menu_forge_pressed_opens_forge_on_armies_panel() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	assert_true((main.current_screen as Forge).armies_panel.visible)


func test_forge_browse_requested_shows_faction_browser() -> void:
	var main := _make_main()
	_select_faction(main, _available_faction())
	assert_is(main.current_screen, FactionBrowser)


func test_faction_browser_shows_selected_faction() -> void:
	var main := _make_main()
	var choice := _available_faction()
	_select_faction(main, choice)
	assert_eq((main.current_screen as FactionBrowser).title.text, choice[1])


func test_forge_browse_requested_leaves_one_child() -> void:
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


func test_browser_back_pressed_shows_the_factions_army_of_renown_choice() -> void:
	var main := _make_main()
	var choice := _available_faction()
	_select_faction(main, choice)
	(main.current_screen as FactionBrowser).back_pressed.emit()
	var forge := main.current_screen as Forge
	assert_true(forge.renown_panel.visible)
	assert_eq(forge.breadcrumb_steps()[1], choice[1])


func test_browser_back_then_renown_back_lists_selected_alliances_factions() -> void:
	var main := _make_main()
	var choice := _available_faction()
	_select_faction(main, choice)
	(main.current_screen as FactionBrowser).back_pressed.emit()
	(main.current_screen as Forge).go_back()
	var forge := main.current_screen as Forge
	assert_true(forge.faction_panel.visible)
	assert_eq(forge.breadcrumb_steps()[0], GrandAlliance.display_name(choice[0]))


func test_returned_forge_can_open_browser_again() -> void:
	var main := _make_main()
	var choice := _available_faction()
	_select_faction(main, choice)
	(main.current_screen as FactionBrowser).back_pressed.emit()
	(main.current_screen as Forge).browse_requested.emit(choice[0], choice[1])
	assert_is(main.current_screen, FactionBrowser)


func test_returned_forge_back_pressed_shows_main_menu() -> void:
	var main := _make_main()
	_select_faction(main, _available_faction())
	(main.current_screen as FactionBrowser).back_pressed.emit()
	(main.current_screen as Forge).back_pressed.emit()
	assert_is(main.current_screen, MainMenu)


# --- Army of Renown choice and army builder ---

## Returns an Army for the first faction with data, as the Forge would start it.
func _new_army() -> Army:
	var choice := _available_faction()
	var faction := FactionCatalog.load_faction(choice[1])
	return ArmyEditor.create_army(ArmyCatalog.new(faction, CoreRulesCatalog.get_rules()))


func test_show_forge_with_faction_opens_its_army_of_renown_panel() -> void:
	var main := _make_main()
	var choice := _available_faction()
	main.show_forge(choice[0], choice[1])
	var forge := main.current_screen as Forge
	assert_true(forge.renown_panel.visible)
	assert_eq(forge.breadcrumb_steps()[1], choice[1])


func test_show_forge_with_only_alliance_opens_its_faction_panel() -> void:
	var main := _make_main()
	main.show_forge(_available_faction()[0])
	assert_true((main.current_screen as Forge).faction_panel.visible)


func test_forge_army_started_shows_army_builder() -> void:
	var main := _make_main()
	main.show_forge()
	(main.current_screen as Forge).army_started.emit(_new_army())
	assert_is(main.current_screen, ArmyBuilder)


func test_army_builder_screen_edits_the_started_army() -> void:
	var main := _make_main()
	main.show_forge()
	var army := _new_army()
	(main.current_screen as Forge).army_started.emit(army)
	assert_eq((main.current_screen as ArmyBuilder).editor.army, army)


func test_army_builder_leaves_one_child() -> void:
	var main := _make_main()
	main.show_forge()
	(main.current_screen as Forge).army_started.emit(_new_army())
	assert_eq(main.get_child_count(), 1)


func test_army_builder_back_pressed_shows_forge_on_armies_panel() -> void:
	var main := _make_main()
	main.show_forge()
	(main.current_screen as Forge).army_started.emit(_new_army())
	(main.current_screen as ArmyBuilder).back_pressed.emit()
	assert_true((main.current_screen as Forge).armies_panel.visible)


func test_army_builder_back_pressed_focuses_the_saved_army() -> void:
	var main := _make_main()
	var army := _new_army()
	assert_eq(ArmyStore.save(army), OK)
	main.show_forge()
	(main.current_screen as Forge).army_started.emit(army)
	(main.current_screen as ArmyBuilder).back_pressed.emit()
	var forge := main.current_screen as Forge
	assert_eq(_focused_army_id(forge), army.id)


func test_show_forge_with_army_id_focuses_that_army() -> void:
	var main := _make_main()
	var first := _new_army()
	var second := _new_army()
	ArmyStore.save(first)
	ArmyStore.save(second)
	main.show_forge(-1, "", first.id)
	assert_eq(_focused_army_id(main.current_screen as Forge), first.id)


func test_show_forge_with_army_id_shows_armies_panel() -> void:
	var main := _make_main()
	var army := _new_army()
	ArmyStore.save(army)
	main.show_forge(GrandAlliance.Type.values()[0], "", army.id)
	assert_true((main.current_screen as Forge).armies_panel.visible)


func test_forge_army_opened_shows_army_builder() -> void:
	var main := _make_main()
	main.show_forge()
	(main.current_screen as Forge).army_opened.emit(_new_army())
	assert_is(main.current_screen, ArmyBuilder)


func test_opened_army_is_the_one_edited() -> void:
	var main := _make_main()
	main.show_forge()
	var army := _new_army()
	(main.current_screen as Forge).army_opened.emit(army)
	assert_eq((main.current_screen as ArmyBuilder).editor.army, army)


func test_opening_a_saved_army_from_its_row_shows_the_builder() -> void:
	var main := _make_main()
	var army := _new_army()
	ArmyStore.save(army)
	main.show_forge()
	var forge := main.current_screen as Forge
	forge.army_list.get_child(0).get_meta(&"first_button").pressed.emit()
	assert_is(main.current_screen, ArmyBuilder)
	assert_eq((main.current_screen as ArmyBuilder).editor.army.id, army.id)


func test_showing_army_builder_for_unknown_faction_stays_put() -> void:
	var main := _make_main()
	main.show_forge()
	var army := Army.new()
	army.faction_id = "not_a_faction"
	main.show_army_builder(army)
	assert_push_error("not_a_faction")
	assert_is(main.current_screen, Forge)


## The id of the saved army whose row holds the focus, or "" if none does.
func _focused_army_id(forge: Forge) -> String:
	for row in forge.army_list.get_children():
		if row.has_meta(&"first_button") and row.get_meta(&"first_button").has_focus():
			return row.get_meta(&"army_id")
	return ""


# --- Quick Play ---


func _saved_army() -> Army:
	var army := _new_army()
	army.override_constraints = true
	assert_eq(ArmyStore.save(army), OK)
	return army


func test_menu_quick_play_pressed_shows_game_mode_screen() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).quick_play_pressed.emit()
	assert_is(main.current_screen, GameModeScreen)


func test_menu_quick_play_pressed_leaves_one_child() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).quick_play_pressed.emit()
	assert_eq(main.get_child_count(), 1)


func test_game_mode_back_pressed_shows_main_menu() -> void:
	var main := _make_main()
	main.show_quick_play()
	(main.current_screen as GameModeScreen).back_pressed.emit()
	assert_is(main.current_screen, MainMenu)


func test_show_quick_play_focuses_the_given_mode_card() -> void:
	var main := _make_main()
	main.show_quick_play(BattleSetup.Mode.MATCHED_PLAY)
	var screen := main.current_screen as GameModeScreen
	assert_true(screen.mode_cards[BattleSetup.Mode.MATCHED_PLAY].has_focus())


func test_game_mode_chosen_shows_army_select() -> void:
	var main := _make_main()
	main.show_quick_play()
	(main.current_screen as GameModeScreen).mode_chosen.emit(BattleSetup.Mode.MATCHED_PLAY)
	assert_is(main.current_screen, ArmySelect)


func test_army_select_opens_in_the_chosen_mode() -> void:
	var main := _make_main()
	main.show_quick_play()
	(main.current_screen as GameModeScreen).mode_chosen.emit(BattleSetup.Mode.SPEARHEAD)
	assert_eq((main.current_screen as ArmySelect).mode, BattleSetup.Mode.SPEARHEAD)


func test_army_select_back_pressed_shows_game_mode_screen() -> void:
	var main := _make_main()
	main.show_army_select(BattleSetup.Mode.MATCHED_PLAY)
	(main.current_screen as ArmySelect).back_pressed.emit()
	assert_is(main.current_screen, GameModeScreen)


func test_army_select_back_pressed_focuses_the_mode_that_was_chosen() -> void:
	var main := _make_main()
	main.show_army_select(BattleSetup.Mode.MATCHED_PLAY)
	(main.current_screen as ArmySelect).back_pressed.emit()
	var screen := main.current_screen as GameModeScreen
	assert_true(screen.mode_cards[BattleSetup.Mode.MATCHED_PLAY].has_focus())


func test_army_select_forge_requested_shows_forge() -> void:
	var main := _make_main()
	main.show_army_select(BattleSetup.Mode.MATCHED_PLAY)
	(main.current_screen as ArmySelect).forge_requested.emit()
	assert_is(main.current_screen, Forge)


func test_army_select_edit_requested_shows_army_builder() -> void:
	var main := _make_main()
	var army := _saved_army()
	main.show_army_select(BattleSetup.Mode.MATCHED_PLAY)
	(main.current_screen as ArmySelect).edit_requested.emit(ArmyStore.load_army(army.id))
	assert_is(main.current_screen, ArmyBuilder)


func test_army_builder_opened_from_army_select_goes_back_to_army_select() -> void:
	var main := _make_main()
	var army := _saved_army()
	main.show_army_select(BattleSetup.Mode.MATCHED_PLAY)
	(main.current_screen as ArmySelect).edit_requested.emit(ArmyStore.load_army(army.id))
	(main.current_screen as ArmyBuilder).back_pressed.emit()
	assert_is(main.current_screen, ArmySelect)


func test_army_select_after_editing_chooses_the_edited_army() -> void:
	var main := _make_main()
	var army := _saved_army()
	main.show_army_select(BattleSetup.Mode.MATCHED_PLAY)
	(main.current_screen as ArmySelect).edit_requested.emit(ArmyStore.load_army(army.id))
	(main.current_screen as ArmyBuilder).back_pressed.emit()
	assert_eq((main.current_screen as ArmySelect).army_id, army.id)


func test_show_army_builder_with_on_back_calls_it_on_back() -> void:
	var main := _make_main()
	var calls: Array[int] = []
	main.show_army_builder(_new_army(), func() -> void: calls.append(1))
	(main.current_screen as ArmyBuilder).back_pressed.emit()
	assert_eq(calls.size(), 1)


func test_show_army_builder_with_on_back_does_not_show_forge() -> void:
	var main := _make_main()
	main.show_army_builder(_new_army(), func() -> void: pass)
	(main.current_screen as ArmyBuilder).back_pressed.emit()
	assert_is(main.current_screen, ArmyBuilder)


# Battle

func _show_loading(main: Main) -> LoadingScreen:
	main.show_army_select(BattleSetup.Mode.SPEARHEAD)
	(main.current_screen as ArmySelect).play_requested.emit(BattleKit.real_spearhead_setup())
	return main.current_screen as LoadingScreen


func test_army_select_play_requested_shows_loading_screen() -> void:
	var main := _make_main()
	assert_is(_show_loading(main), LoadingScreen)


func test_loading_screen_is_the_only_child() -> void:
	var main := _make_main()
	_show_loading(main)
	await get_tree().process_frame
	assert_eq(main.get_child_count(), 1)


func test_loading_screen_builds_the_battle_for_the_setup() -> void:
	var main := _make_main()
	var setup := BattleKit.real_spearhead_setup()
	main.show_army_select(BattleSetup.Mode.SPEARHEAD)
	(main.current_screen as ArmySelect).play_requested.emit(setup)
	assert_eq((main.current_screen as LoadingScreen).battle.player.name, setup.spearhead)


func test_loading_screen_finished_shows_the_battle_map() -> void:
	var main := _make_main()
	var screen := _show_loading(main)
	screen.finish()
	assert_is(main.current_screen, BattleMap)
	assert_eq(main.current_screen, screen.map)


func test_battle_map_is_a_child_of_main() -> void:
	var main := _make_main()
	_show_loading(main).finish()
	assert_eq(main.current_screen.get_parent(), main)


func test_battle_map_menu_requested_shows_main_menu() -> void:
	var main := _make_main()
	_show_loading(main).finish()
	(main.current_screen as BattleMap).menu_requested.emit()
	assert_is(main.current_screen, MainMenu)


func test_battle_map_is_freed_when_returning_to_the_main_menu() -> void:
	var main := _make_main()
	_show_loading(main).finish()
	var map := main.current_screen
	(map as BattleMap).menu_requested.emit()
	assert_true(map.is_queued_for_deletion())


func test_show_battle_map_shows_the_given_map() -> void:
	var main := _make_main()
	var map: BattleMap = load("res://scenes/battle/battle_map.tscn").instantiate()
	main.show_battle_map(map)
	assert_eq(main.current_screen, map)


func test_loading_screen_failed_returns_to_army_select() -> void:
	var main := _make_main()
	main.show_army_select(BattleSetup.Mode.SPEARHEAD)
	var setup := BattleSetup.new()
	(main.current_screen as ArmySelect).play_requested.emit(setup)
	await wait_for_signal((main.current_screen as LoadingScreen).failed, 2)
	assert_is(main.current_screen, ArmySelect)
	assert_push_error_count(1)


func test_loading_screen_failed_returns_to_the_army_step_of_the_same_mode() -> void:
	var main := _make_main()
	main.show_army_select(BattleSetup.Mode.MATCHED_PLAY)
	var setup := BattleSetup.new()
	setup.mode = BattleSetup.Mode.MATCHED_PLAY
	(main.current_screen as ArmySelect).play_requested.emit(setup)
	await wait_for_signal((main.current_screen as LoadingScreen).failed, 2)
	assert_eq((main.current_screen as ArmySelect).mode, BattleSetup.Mode.MATCHED_PLAY)
	assert_push_error_count(1)
