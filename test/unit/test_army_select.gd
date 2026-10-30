extends GutTest
## Unit tests for Quick Play's army step (scripts/ui/quick_play/army_select.gd).

const ArmySelectScene := preload("res://scenes/ui/quick_play/army_select.tscn")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")

const DAY := 86400.0


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	# Cards are removed with queue_free, so let a frame pass for them to be freed.
	await get_tree().process_frame
	Sandbox.end()


func _make_select() -> ArmySelect:
	var screen: ArmySelect = ArmySelectScene.instantiate()
	add_child_autofree(screen)
	watch_signals(screen)
	return screen


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


## Noon, local time, on some day: far from any midnight, so the day counts in saved_when are exact.
func _noon() -> float:
	var offset: int = Time.get_time_zone_from_system().bias * 60
	return floorf((1750000000.0 + offset) / DAY) * DAY + DAY / 2 - offset


## The first faction with data.
func _faction() -> Faction:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for name in FactionCatalog.factions_for(alliance):
			if FactionCatalog.is_available(name):
				return FactionCatalog.load_faction(name)
	fail_test("no faction is available")
	return null


## Saves a new army of the first faction with data, named [param army_name].
func _save_army(army_name: String, overridden := false, saved_at := 0.0) -> Army:
	var army := ArmyEditor.create_army(ArmyCatalog.new(_faction(), CoreRulesCatalog.get_rules()))
	army.name = army_name
	army.override_constraints = overridden
	assert_eq(ArmyStore.save(army), OK)
	if saved_at > 0.0:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArmyStore.path(army.id)))
		data.saved_at = saved_at
		FileAccess.open(ArmyStore.path(army.id), FileAccess.WRITE).store_string(JSON.stringify(data))
	return army


## Saves an army whose faction has no data, so it can't be chosen. Returns its id.
func _save_unplayable_army() -> String:
	var army := Army.new()
	army.faction_id = "no_such_faction"
	army.name = "Orphan"
	assert_eq(ArmyStore.save(army), OK)
	return army.id


func _write_raw(id: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ArmyStore.directory)
	FileAccess.open(ArmyStore.path(id), FileAccess.WRITE).store_string(text)


func _matched_play(focus := "") -> ArmySelect:
	var screen := _make_select()
	screen.open(BattleSetup.Mode.MATCHED_PLAY, focus)
	return screen


func _spearhead(focus := "") -> ArmySelect:
	var screen := _make_select()
	screen.open(BattleSetup.Mode.SPEARHEAD, focus)
	return screen


func _ability_names(abilities: Array[Ability]) -> Array:
	return abilities.map(func(ability: Ability) -> String: return ability.name)


func _entry_cards(screen: ArmySelect) -> Array[Node]:
	return UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is OptionCard)


func _spearhead_names(screen: ArmySelect) -> Array:
	return _entry_cards(screen).map(func(card: Node) -> String: return card.get_meta(&"spearhead"))


func _first_plan_name() -> String:
	return CoreRulesCatalog.get_rules().battlepack.battleplans[0].name


# --- Matched Play: choosing an army ---


func test_matched_play_without_armies_cannot_play() -> void:
	var screen := _matched_play()
	assert_ne(screen.play_blocker(), "")


func test_matched_play_without_armies_disables_play() -> void:
	var screen := _matched_play()
	assert_true(screen.play_button.disabled)


func test_matched_play_without_armies_has_no_army_chosen() -> void:
	var screen := _matched_play()
	assert_eq(screen.army_id, "")


func test_matched_play_chooses_the_first_playable_army() -> void:
	var army := _save_army("Mine")
	var screen := _matched_play()
	assert_eq(screen.army_id, army.id)


func test_matched_play_skips_armies_without_faction_data_when_choosing_first() -> void:
	_save_unplayable_army()
	var army := _save_army("Mine", false, 100.0)
	var screen := _matched_play()
	assert_eq(screen.army_id, army.id)


func test_matched_play_focus_chooses_that_army() -> void:
	var older := _save_army("Older", false, 100.0)
	_save_army("Newer", false, 200.0)
	var screen := _matched_play(older.id)
	assert_eq(screen.army_id, older.id)


func test_matched_play_lists_a_card_per_saved_army() -> void:
	_save_army("One")
	_save_army("Two")
	var screen := _matched_play()
	assert_eq(_entry_cards(screen).size(), 2)


func test_pressing_an_army_card_chooses_it() -> void:
	var older := _save_army("Older", false, 100.0)
	_save_army("Newer", false, 200.0)
	var screen := _matched_play()
	var card: OptionCard = _entry_cards(screen).filter(func(c: Node) -> bool: return c.get_meta(&"army_id") == older.id)[0]
	card.pressed.emit()
	assert_eq(screen.army_id, older.id)


func test_army_without_faction_data_cannot_be_chosen() -> void:
	var id := _save_unplayable_army()
	var screen := _matched_play()
	screen._choose_army(id)
	assert_eq(screen.army_id, "")


func test_army_without_faction_data_has_a_disabled_card() -> void:
	_save_unplayable_army()
	var screen := _matched_play()
	assert_true(_entry_cards(screen)[0].disabled)


# --- Matched Play: play_blocker, Play and setup ---


func test_army_with_problems_cannot_play() -> void:
	_save_army("Empty")
	var screen := _matched_play()
	if screen._info.problems.is_empty():
		pending("a new army has no problems")
		return
	assert_ne(screen.play_blocker(), "")


func test_army_with_problems_disables_play() -> void:
	_save_army("Empty")
	var screen := _matched_play()
	if screen._info.problems.is_empty():
		pending("a new army has no problems")
		return
	assert_true(screen.play_button.disabled)


func test_blocked_play_tooltip_is_the_blocker() -> void:
	var screen := _matched_play()
	assert_eq(screen.play_button.tooltip_text, screen.play_blocker())


func test_army_that_overrides_constraints_can_play() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	assert_eq(screen.play_blocker(), "")


func test_playable_army_enables_play() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	assert_false(screen.play_button.disabled)


func test_playable_army_play_tooltip_is_not_a_blocker() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	assert_ne(screen.play_button.tooltip_text, screen.play_blocker())


func test_play_emits_the_setup() -> void:
	var army := _save_army("Free", true)
	var screen := _matched_play()
	screen.play_button.pressed.emit()
	var params: Array = get_signal_parameters(screen, "play_requested")
	assert_eq((params[0] as BattleSetup).army.id, army.id)


func test_matched_play_setup_has_the_mode() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	assert_eq(screen.setup().mode, BattleSetup.Mode.MATCHED_PLAY)


func test_matched_play_setup_has_the_chosen_army() -> void:
	var army := _save_army("Free", true)
	var screen := _matched_play()
	assert_eq(screen.setup().army.id, army.id)


func test_matched_play_setup_without_an_army_has_none() -> void:
	var screen := _matched_play()
	assert_null(screen.setup().army)


func test_matched_play_setup_has_the_battleplan() -> void:
	var screen := _matched_play()
	screen.battleplan = "Some Plan"
	assert_eq(screen.setup().battleplan, "Some Plan")


# --- Spearhead ---


func test_spearhead_chooses_the_first_spearhead() -> void:
	var screen := _spearhead()
	assert_eq(screen.spearhead.name, GameModeScreen.shown_spearheads()[0].name)


func test_spearhead_focus_chooses_that_spearhead() -> void:
	var shown := GameModeScreen.shown_spearheads()
	if shown.size() < 2:
		pending("fewer than two Spearheads")
		return
	var screen := _spearhead(shown[-1].name)
	assert_eq(screen.spearhead.name, shown[-1].name)


func test_spearhead_lists_a_card_per_spearhead() -> void:
	var screen := _spearhead()
	assert_eq(_entry_cards(screen).size(), GameModeScreen.shown_spearheads().size())


func test_spearhead_without_choices_cannot_play() -> void:
	var screen := _spearhead()
	assert_ne(screen.play_blocker(), "")


func test_spearhead_with_only_a_regiment_ability_cannot_play() -> void:
	var screen := _spearhead()
	screen._choose("regiment", screen.spearhead.regiment_abilities[0].name)
	assert_ne(screen.play_blocker(), "")


func test_spearhead_with_only_an_enhancement_cannot_play() -> void:
	var screen := _spearhead()
	screen._choose("enhancement", screen.spearhead.enhancements[0].name)
	assert_ne(screen.play_blocker(), "")


func test_spearhead_blocker_asks_for_the_missing_enhancement() -> void:
	var screen := _spearhead()
	screen._choose("regiment", screen.spearhead.regiment_abilities[0].name)
	assert_true(screen.play_blocker().contains("enhancement"))


func test_spearhead_blocker_asks_for_the_missing_regiment_ability() -> void:
	var screen := _spearhead()
	screen._choose("enhancement", screen.spearhead.enhancements[0].name)
	assert_true(screen.play_blocker().contains("regiment ability"))


func test_spearhead_with_both_choices_can_play() -> void:
	var screen := _spearhead()
	screen._choose("regiment", screen.spearhead.regiment_abilities[0].name)
	screen._choose("enhancement", screen.spearhead.enhancements[0].name)
	assert_eq(screen.play_blocker(), "")


func test_spearhead_with_both_choices_enables_play() -> void:
	var screen := _spearhead()
	screen._choose("regiment", screen.spearhead.regiment_abilities[0].name)
	screen._choose("enhancement", screen.spearhead.enhancements[0].name)
	assert_false(screen.play_button.disabled)


func test_spearhead_without_choices_disables_play() -> void:
	var screen := _spearhead()
	assert_true(screen.play_button.disabled)


func test_spearhead_without_choices_shows_the_blocker_as_play_tooltip() -> void:
	var screen := _spearhead()
	assert_eq(screen.play_button.tooltip_text, screen.play_blocker())


func test_choosing_a_regiment_ability_sets_it() -> void:
	var screen := _spearhead()
	var ability_name: String = screen.spearhead.regiment_abilities[0].name
	screen._choose("regiment", ability_name)
	assert_eq(screen.regiment_ability, ability_name)


func test_choosing_a_regiment_ability_leaves_the_enhancement_alone() -> void:
	var screen := _spearhead()
	screen._choose("regiment", screen.spearhead.regiment_abilities[0].name)
	assert_eq(screen.enhancement, "")


func test_choosing_an_enhancement_sets_it() -> void:
	var screen := _spearhead()
	var ability_name: String = screen.spearhead.enhancements[0].name
	screen._choose("enhancement", ability_name)
	assert_eq(screen.enhancement, ability_name)


func test_pressing_a_chosen_ability_unchooses_it() -> void:
	var screen := _spearhead()
	var ability_name: String = screen.spearhead.regiment_abilities[0].name
	screen._choose("regiment", ability_name)
	screen._choose("regiment", ability_name)
	assert_eq(screen.regiment_ability, "")


func test_unchoosing_disables_play_again() -> void:
	var screen := _spearhead()
	var regiment_name: String = screen.spearhead.regiment_abilities[0].name
	screen._choose("regiment", regiment_name)
	screen._choose("enhancement", screen.spearhead.enhancements[0].name)
	screen._choose("regiment", regiment_name)
	assert_true(screen.play_button.disabled)


func test_choosing_another_ability_replaces_the_choice() -> void:
	var screen := _spearhead()
	var abilities := _ability_names(screen.spearhead.regiment_abilities)
	if abilities.size() < 2:
		pending("fewer than two regiment abilities")
		return
	screen._choose("regiment", abilities[0])
	screen._choose("regiment", abilities[1])
	assert_eq(screen.regiment_ability, abilities[1])


func test_pressing_a_choice_card_chooses_it() -> void:
	var screen := _spearhead()
	var card: PressableCard = screen._choice_cards["regiment"][0]
	card.pressed.emit()
	assert_eq(screen.regiment_ability, card.get_meta(&"ability"))


func test_choosing_another_spearhead_clears_the_choices() -> void:
	var shown := GameModeScreen.shown_spearheads()
	if shown.size() < 2:
		pending("fewer than two Spearheads")
		return
	var screen := _spearhead()
	screen._choose("regiment", screen.spearhead.regiment_abilities[0].name)
	screen._choose("enhancement", screen.spearhead.enhancements[0].name)
	screen._choose_spearhead(shown[1])
	assert_eq(screen.regiment_ability + screen.enhancement, "")


func test_spearhead_setup_has_the_regiment_ability() -> void:
	var screen := _spearhead()
	var ability_name: String = screen.spearhead.regiment_abilities[0].name
	screen._choose("regiment", ability_name)
	assert_eq(screen.setup().regiment_ability, ability_name)


func test_spearhead_setup_has_the_enhancement() -> void:
	var screen := _spearhead()
	var ability_name: String = screen.spearhead.enhancements[0].name
	screen._choose("enhancement", ability_name)
	assert_eq(screen.setup().enhancement, ability_name)


func test_spearhead_setup_has_the_spearhead() -> void:
	var screen := _spearhead()
	assert_eq(screen.setup().spearhead, screen.spearhead.name)


func test_spearhead_setup_has_the_spearheads_faction() -> void:
	var screen := _spearhead()
	assert_eq(screen.setup().faction, screen.spearhead_faction.name)


func test_spearhead_setup_has_the_mode() -> void:
	var screen := _spearhead()
	assert_eq(screen.setup().mode, BattleSetup.Mode.SPEARHEAD)


func test_spearhead_setup_has_no_army() -> void:
	var screen := _spearhead()
	assert_null(screen.setup().army)


func test_play_in_spearhead_emits_the_setup_with_the_spearhead() -> void:
	var screen := _spearhead()
	screen._choose("regiment", screen.spearhead.regiment_abilities[0].name)
	screen._choose("enhancement", screen.spearhead.enhancements[0].name)
	screen.play_button.pressed.emit()
	var params: Array = get_signal_parameters(screen, "play_requested")
	assert_eq((params[0] as BattleSetup).spearhead, screen.spearhead.name)


func test_spearhead_battleplan_card_is_disabled() -> void:
	var screen := _spearhead()
	assert_true(screen._plan_card.disabled)


# --- Spearhead search ---


func test_search_by_name_keeps_that_spearhead() -> void:
	var screen := _spearhead()
	var target: String = GameModeScreen.shown_spearheads()[0].name
	screen._on_search_changed(target)
	assert_true(target in _spearhead_names(screen))


func test_search_by_faction_keeps_that_factions_spearheads() -> void:
	var screen := _spearhead()
	var entry: Dictionary = GameModeScreen.shown_spearheads()[0]
	screen._on_search_changed(entry.faction)
	assert_true(entry.name in _spearhead_names(screen))


func test_search_filters_out_spearheads_that_do_not_match() -> void:
	var screen := _spearhead()
	var entry: Dictionary = GameModeScreen.shown_spearheads()[0]
	screen._on_search_changed(entry.name)
	assert_lt(_entry_cards(screen).size(), GameModeScreen.shown_spearheads().size())


func test_search_without_matches_shows_no_cards() -> void:
	var screen := _spearhead()
	screen._on_search_changed("zzzzzz-no-such-spearhead")
	assert_eq(_entry_cards(screen).size(), 0)


func test_search_without_matches_says_so() -> void:
	var screen := _spearhead()
	screen._on_search_changed("zzzzzz-no-such-spearhead")
	assert_true(UIKit.has_label_containing(screen.pane_box, "No Spearheads match"))


func test_clearing_the_search_restores_the_list() -> void:
	var screen := _spearhead()
	screen._on_search_changed("zzzzzz-no-such-spearhead")
	screen._on_search_changed("")
	assert_eq(_entry_cards(screen).size(), GameModeScreen.shown_spearheads().size())


func test_escape_in_a_filled_search_clears_it() -> void:
	var screen := _spearhead()
	screen._search.text = "zzz"
	screen._on_search_changed("zzz")
	screen._search.grab_focus()
	screen._unhandled_input(_escape_event())
	assert_eq(screen.query, "")


func test_escape_in_a_filled_search_does_not_go_back() -> void:
	var screen := _spearhead()
	screen._search.text = "zzz"
	screen._on_search_changed("zzz")
	screen._search.grab_focus()
	screen._unhandled_input(_escape_event())
	assert_signal_not_emitted(screen, "back_pressed")


# --- Navigation ---


func test_go_back_from_the_list_emits_back_pressed() -> void:
	var screen := _matched_play()
	screen.go_back()
	assert_signal_emitted(screen, "back_pressed")


func test_back_button_emits_back_pressed() -> void:
	var screen := _matched_play()
	screen.back_button.pressed.emit()
	assert_signal_emitted(screen, "back_pressed")


func test_escape_on_the_list_emits_back_pressed() -> void:
	var screen := _matched_play()
	screen._unhandled_input(_escape_event())
	assert_signal_emitted(screen, "back_pressed")


func test_show_plans_switches_to_the_plans_pane() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.show_plans()
	assert_eq(screen.pane, ArmySelect.Pane.PLANS)


func test_go_back_from_the_plans_pane_returns_to_the_list() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.show_plans()
	screen.go_back()
	assert_eq(screen.pane, ArmySelect.Pane.LIST)


func test_go_back_from_the_plans_pane_does_not_emit_back_pressed() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.show_plans()
	screen.go_back()
	assert_signal_not_emitted(screen, "back_pressed")


func test_escape_on_the_plans_pane_returns_to_the_list() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.show_plans()
	screen._unhandled_input(_escape_event())
	assert_eq(screen.pane, ArmySelect.Pane.LIST)


func test_go_back_from_a_warscroll_returns_to_the_list() -> void:
	var screen := _spearhead()
	screen.show_warscroll(screen.spearhead_faction.warscrolls[0])
	screen.go_back()
	assert_eq(screen.pane, ArmySelect.Pane.LIST)


func test_show_warscroll_switches_to_the_warscroll_pane() -> void:
	var screen := _spearhead()
	screen.show_warscroll(screen.spearhead_faction.warscrolls[0])
	assert_eq(screen.pane, ArmySelect.Pane.WARSCROLL)


func test_picking_a_battleplan_sets_it() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.show_plans()
	var picker: BattleplanPicker = UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is BattleplanPicker)[0]
	picker.cards[_first_plan_name()].pressed.emit()
	assert_eq(screen.battleplan, _first_plan_name())


func test_picking_a_battleplan_returns_to_the_list() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.show_plans()
	var picker: BattleplanPicker = UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is BattleplanPicker)[0]
	picker.cards[_first_plan_name()].pressed.emit()
	assert_eq(screen.pane, ArmySelect.Pane.LIST)


func test_picking_random_clears_the_battleplan() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.battleplan = _first_plan_name()
	screen.show_plans()
	var picker: BattleplanPicker = UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is BattleplanPicker)[0]
	picker.cards[""].pressed.emit()
	assert_eq(screen.battleplan, "")


func test_picked_battleplan_is_in_the_setup() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.show_plans()
	var picker: BattleplanPicker = UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is BattleplanPicker)[0]
	picker.cards[_first_plan_name()].pressed.emit()
	assert_eq(screen.setup().battleplan, _first_plan_name())


# --- Saved armies list ---


func test_edit_button_emits_edit_requested_with_the_army() -> void:
	var army := _save_army("Mine")
	var screen := _matched_play()
	var edit := UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is Button and n.tooltip_text.begins_with("Edit "))
	edit[0].pressed.emit()
	var params: Array = get_signal_parameters(screen, "edit_requested")
	assert_eq((params[0] as Army).id, army.id)


func test_edit_button_does_not_choose_or_play() -> void:
	_save_army("Mine")
	var screen := _matched_play()
	var edit := UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is Button and n.tooltip_text.begins_with("Edit "))
	edit[0].pressed.emit()
	assert_signal_not_emitted(screen, "play_requested")


func test_without_saved_armies_a_button_requests_the_forge() -> void:
	var screen := _matched_play()
	var buttons := UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is Button)
	buttons[0].pressed.emit()
	assert_signal_emitted(screen, "forge_requested")


# --- army_info ---


func test_army_info_names_an_unreadable_army_by_its_id() -> void:
	_write_raw("broken", "not json")
	var info := ArmySelect.army_info(ArmyStore.read("broken"))
	assert_true(info.name.contains("broken"))


func test_army_info_of_an_unreadable_army_explains_why() -> void:
	_write_raw("broken", "not json")
	var info := ArmySelect.army_info(ArmyStore.read("broken"))
	assert_ne(info.note, "")


func test_army_info_of_an_unreadable_army_has_no_catalog() -> void:
	_write_raw("broken", "not json")
	assert_null(ArmySelect.army_info(ArmyStore.read("broken")).catalog)


func test_army_info_of_an_army_without_faction_data_notes_it() -> void:
	var id := _save_unplayable_army()
	assert_ne(ArmySelect.army_info(ArmyStore.read(id)).note, "")


func test_army_info_of_an_army_without_faction_data_has_no_faction() -> void:
	var id := _save_unplayable_army()
	assert_eq(ArmySelect.army_info(ArmyStore.read(id)).faction, "")


func test_army_info_names_the_faction() -> void:
	var army := _save_army("Mine")
	assert_eq(ArmySelect.army_info(ArmyStore.read(army.id)).faction, _faction().name)


func test_army_info_names_the_army() -> void:
	var army := _save_army("Mine")
	assert_eq(ArmySelect.army_info(ArmyStore.read(army.id)).name, "Mine")


func test_army_info_names_an_unnamed_army() -> void:
	var army := _save_army("")
	assert_ne(ArmySelect.army_info(ArmyStore.read(army.id)).name, "")


func test_army_info_reports_points_against_the_limit() -> void:
	var army := _save_army("Mine")
	assert_true(ArmySelect.army_info(ArmyStore.read(army.id)).points.contains(str(army.points_limit)))


func test_army_info_reports_overridden_constraints() -> void:
	var army := _save_army("Free", true)
	assert_true(ArmySelect.army_info(ArmyStore.read(army.id)).overridden)


func test_army_info_of_an_overriding_army_has_no_problems() -> void:
	var army := _save_army("Free", true)
	assert_true(ArmySelect.army_info(ArmyStore.read(army.id)).problems.is_empty())


func test_army_info_has_a_catalog_for_an_army_with_faction_data() -> void:
	var army := _save_army("Mine")
	assert_not_null(ArmySelect.army_info(ArmyStore.read(army.id)).catalog)


# --- saved_when ---


func test_saved_when_is_empty_when_the_time_is_unknown() -> void:
	assert_eq(ArmySelect.saved_when(0.0, _noon()), "")


func test_saved_when_the_same_day_is_today() -> void:
	assert_eq(ArmySelect.saved_when(_noon() - 3600.0, _noon()), "saved today")


func test_saved_when_the_day_before_is_yesterday() -> void:
	assert_eq(ArmySelect.saved_when(_noon() - DAY, _noon()), "saved yesterday")


func test_saved_when_a_few_days_ago_counts_the_days() -> void:
	assert_eq(ArmySelect.saved_when(_noon() - 3 * DAY, _noon()), "saved 3 days ago")


func test_saved_when_eight_days_ago_is_last_week() -> void:
	assert_eq(ArmySelect.saved_when(_noon() - 8 * DAY, _noon()), "saved last week")


func test_saved_when_three_weeks_ago_counts_the_weeks() -> void:
	assert_eq(ArmySelect.saved_when(_noon() - 21 * DAY, _noon()), "saved 3 weeks ago")


func test_saved_when_long_ago_gives_the_date() -> void:
	var text := ArmySelect.saved_when(_noon() - 200 * DAY, _noon())
	assert_true(text.begins_with("saved on "), text)


func test_saved_when_long_ago_includes_the_year() -> void:
	var saved_at := _noon() - 200 * DAY
	var year := str(Time.get_date_dict_from_unix_time(int(saved_at)).year)
	assert_true(ArmySelect.saved_when(saved_at, _noon()).ends_with(year))
