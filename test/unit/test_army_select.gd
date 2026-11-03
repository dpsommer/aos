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


func _count(root: Node, type: Variant) -> int:
	return UIKit.find_all(root, func(n: Node) -> bool: return is_instance_of(n, type)).size()


func _count_cards_in(screen: ArmySelect, heading: String) -> int:
	return _count(_section_of(screen, heading), AbilityCard)


## Types [param text] into the Spearhead search box, as the player would.
func _search(screen: ArmySelect, text: String) -> void:
	var box: LineEdit = UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is LineEdit)[0]
	box.text = text
	box.text_changed.emit(text)
	box.grab_focus()


## The battle plan card beside the detail's heading.
func _plan_card(screen: ArmySelect) -> OptionCard:
	return UIKit.find_all(screen.detail_column, func(n: Node) -> bool:
		return n is OptionCard and n.accessibility_name.begins_with("Battle plan"))[0]


func _labels(root: Node, text: String) -> Array[Node]:
	return UIKit.find_all(root, func(n: Node) -> bool: return n is Label and n.text.to_upper() == text.to_upper())


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
	_entry_cards(screen).filter(func(c: Node) -> bool: return c.get_meta(&"army_id") == id)[0].pressed.emit()
	assert_eq(screen.army_id, "")


func test_army_without_faction_data_has_a_disabled_card() -> void:
	_save_unplayable_army()
	var screen := _matched_play()
	assert_true(_entry_cards(screen)[0].disabled)


# --- Matched Play: play_blocker, Play and setup ---


func test_army_with_problems_cannot_play() -> void:
	_save_army("Empty")
	var screen := _matched_play()
	assert_ne(screen.play_blocker(), "")


func test_army_with_problems_disables_play() -> void:
	_save_army("Empty")
	var screen := _matched_play()
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


## The panel holding the points limit and rules, beside the Play button.
func _info_box(screen: ArmySelect) -> Control:
	var node: Node = screen.limit_label
	while not node is PanelContainer:
		node = node.get_parent()
	return node


func test_play_button_is_as_tall_as_the_points_limit_and_rules_box() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	await get_tree().process_frame
	assert_gt(_info_box(screen).size.y, 0.0)
	assert_eq(screen.play_button.size.y, _info_box(screen).size.y)


func test_spearhead_play_button_is_as_tall_as_the_points_limit_and_rules_box() -> void:
	var screen := _spearhead()
	await get_tree().process_frame
	assert_eq(screen.play_button.size.y, _info_box(screen).size.y)


func test_rules_stand_out_from_the_points_limit() -> void:
	var screen := _spearhead()
	assert_ne(screen.rules_label.get_theme_color("font_color"), screen.limit_label.get_theme_color("font_color"))


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
	var screen := _spearhead(shown[-1].name)
	assert_eq(screen.spearhead.name, shown[-1].name)


func test_spearhead_lists_a_card_per_spearhead() -> void:
	var screen := _spearhead()
	assert_eq(_entry_cards(screen).size(), GameModeScreen.shown_spearheads().size())


func test_spearhead_screen_fits_the_smallest_ui_size() -> void:
	var screen := _spearhead()
	for entry in GameModeScreen.shown_spearheads():
		screen.open(BattleSetup.Mode.SPEARHEAD, entry.name)
		assert_lte(screen.get_node("Layout").get_combined_minimum_size().x, GameSettings.MIN_UI_SIZE.x,
				"%s is too wide" % entry.name)


func test_spearhead_can_play_without_choosing_abilities() -> void:
	assert_eq(_spearhead().play_blocker(), "")


func test_spearhead_enables_play() -> void:
	assert_false(_spearhead().play_button.disabled)


func test_spearhead_play_tooltip_is_not_a_blocker() -> void:
	var screen := _spearhead()
	assert_ne(screen.play_button.tooltip_text, screen.play_blocker())


func test_spearhead_regiment_abilities_and_enhancements_are_read_only() -> void:
	var screen := _spearhead()
	assert_eq(_count(screen, AbilityChoiceCard), 0)


func test_spearhead_shows_a_card_per_regiment_ability_and_enhancement() -> void:
	var screen := _spearhead()
	var cards := _count_cards_in(screen, "Regiment Abilities") + _count_cards_in(screen, "Enhancements")
	assert_eq(cards, screen.spearhead.regiment_abilities.size() + screen.spearhead.enhancements.size())


func test_spearhead_ability_cards_start_folded() -> void:
	var screen := _spearhead()
	for heading in ["Regiment Abilities", "Enhancements"]:
		for card in UIKit.find_all(_section_of(screen, heading), func(n: Node) -> bool: return n is AbilityCard):
			assert_true(card.folded, "%s: %s" % [heading, card.ability.name])


func test_spearhead_ability_cards_can_be_unfolded() -> void:
	var screen := _spearhead()
	var card: AbilityCard = UIKit.find_all(_section_of(screen, "Enhancements"), func(n: Node) -> bool: return n is AbilityCard)[0]
	card.fold_button.pressed.emit()
	assert_false(card.folded)


func test_spearhead_says_the_abilities_are_picked_later() -> void:
	assert_eq(_labels(_spearhead(), "Picked later").size(), 2)


func test_matched_play_does_not_say_anything_is_picked_later() -> void:
	_save_army("Free", true)
	assert_eq(_labels(_matched_play(), "Picked later").size(), 0)


func test_spearhead_setup_has_no_regiment_ability_or_enhancement() -> void:
	var setup := _spearhead().setup()
	assert_eq(setup.regiment_ability, "")
	assert_eq(setup.enhancement, "")


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
	screen.play_button.pressed.emit()
	var params: Array = get_signal_parameters(screen, "play_requested")
	assert_eq((params[0] as BattleSetup).spearhead, screen.spearhead.name)


func test_spearhead_battleplan_card_is_enabled() -> void:
	var screen := _spearhead()
	assert_false(_plan_card(screen).disabled)


func _realm_picker(screen: ArmySelect) -> RealmPicker:
	return UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is RealmPicker)[0]


func _first_pack() -> String:
	return CoreRulesCatalog.spearhead_battlepacks()[0].name


func _plan_card_texts(screen: ArmySelect) -> Array:
	return UIKit.find_all(_plan_card(screen), func(n: Node) -> bool: return n is Label).map(func(l: Label) -> String: return l.text)


func test_spearhead_plans_pane_shows_a_realm_picker() -> void:
	var screen := _spearhead()
	screen.show_plans()
	assert_eq(screen.pane, ArmySelect.Pane.PLANS)
	assert_eq(UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is RealmPicker).size(), 1)


func test_spearhead_plans_pane_has_no_battleplan_picker() -> void:
	var screen := _spearhead()
	screen.show_plans()
	assert_eq(UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is BattleplanPicker).size(), 0)


func test_picking_a_battlepack_sets_it() -> void:
	var screen := _spearhead()
	screen.show_plans()
	_realm_picker(screen).cards[_first_pack()].pressed.emit()
	assert_eq(screen.battlepack, _first_pack())


func test_picking_a_battlepack_returns_to_the_list() -> void:
	var screen := _spearhead()
	screen.show_plans()
	_realm_picker(screen).cards[_first_pack()].pressed.emit()
	assert_eq(screen.pane, ArmySelect.Pane.LIST)


func test_picking_a_battlepack_leaves_the_battleplan_alone() -> void:
	var screen := _spearhead()
	screen.show_plans()
	_realm_picker(screen).cards[_first_pack()].pressed.emit()
	assert_eq(screen.battleplan, "")


## The battle plan card, found by the name screen readers announce.
func _battleplan_card(screen: ArmySelect) -> Control:
	return UIKit.find_all(screen, func(n: Node) -> bool:
		return n is Control and n.accessibility_name.begins_with("Battle plan:"))[0]


## The nodes of [param type] on the battle plan card, e.g. its map.
func _plan_card_nodes(screen: ArmySelect, type: Variant) -> Array[Node]:
	return UIKit.find_all(_battleplan_card(screen), func(n: Node) -> bool: return is_instance_of(n, type))


func test_spearhead_random_battleplan_card_shows_the_icon() -> void:
	var screen := _spearhead()
	await get_tree().process_frame
	assert_true(_plan_card_nodes(screen, RealmMap).is_empty())
	assert_eq(_plan_card_nodes(screen, ArtPlaceholder)[0].size, ArmySelect.PLAN_ART_SIZE)


func test_picked_battlepack_card_shows_its_first_sides_map_in_place_of_the_icon() -> void:
	var screen := _spearhead()
	screen.show_plans()
	_realm_picker(screen).cards[_first_pack()].pressed.emit()
	await get_tree().process_frame
	var maps := _plan_card_nodes(screen, RealmMap)
	assert_eq(maps.size(), 1)
	assert_eq(maps[0].realm, CoreRulesCatalog.spearhead_battlepacks()[0].realms[0])
	assert_eq(maps[0].size, ArmySelect.PLAN_ART_SIZE)
	assert_true(_plan_card_nodes(screen, ArtPlaceholder).is_empty())


func test_picking_a_battlepack_keeps_the_card_size() -> void:
	var screen := _spearhead()
	await get_tree().process_frame
	var random_size := _battleplan_card(screen).size
	screen.show_plans()
	_realm_picker(screen).cards[_first_pack()].pressed.emit()
	await get_tree().process_frame
	assert_eq(_battleplan_card(screen).size, random_size)


func test_picking_random_clears_the_battlepack() -> void:
	var screen := _spearhead()
	screen.battlepack = _first_pack()
	screen.show_plans()
	_realm_picker(screen).cards[""].pressed.emit()
	assert_eq(screen.battlepack, "")


func test_realm_picker_opens_on_the_chosen_battlepack() -> void:
	var screen := _spearhead()
	screen.battlepack = _first_pack()
	screen.show_plans()
	assert_eq(_realm_picker(screen).selected, _first_pack())


func test_spearhead_setup_carries_the_battlepack() -> void:
	var screen := _spearhead()
	screen.battlepack = _first_pack()
	assert_eq(screen.setup().battlepack, _first_pack())


func test_spearhead_setup_is_random_by_default() -> void:
	assert_eq(_spearhead().setup().battlepack, "")


func test_spearhead_setup_leaves_the_realm_to_the_defender() -> void:
	var screen := _spearhead()
	screen.battlepack = _first_pack()
	assert_eq(screen.setup().realm, "")


func test_spearhead_setup_has_no_battleplan() -> void:
	var screen := _spearhead()
	screen.battlepack = _first_pack()
	screen.battleplan = "Some Plan"
	assert_eq(screen.setup().battleplan, "")


func test_spearhead_setup_still_carries_the_spearhead() -> void:
	var screen := _spearhead()
	screen.battlepack = _first_pack()
	assert_eq(screen.setup().spearhead, screen.spearhead.name)


func test_matched_play_setup_has_no_battlepack_or_realm() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	screen.battlepack = _first_pack()
	var setup := screen.setup()
	assert_eq(setup.realm, "")
	assert_eq(setup.battlepack, "")


func test_plan_card_names_the_chosen_battlepack_and_its_sides() -> void:
	var screen := _spearhead()
	var pack := CoreRulesCatalog.spearhead_battlepacks()[0]
	screen.show_plans()
	_realm_picker(screen).cards[pack.name].pressed.emit()
	var texts := _plan_card_texts(screen)
	assert_true(texts.has(pack.name))
	var sides := PackedStringArray(pack.realms.map(func(side: RealmBattlefield) -> String: return side.name))
	assert_true(texts.has("%s: the defender picks" % " or ".join(sides)))


func test_plan_card_is_random_before_a_battlepack_is_chosen() -> void:
	assert_string_contains(_plan_card(_spearhead()).accessibility_name, "Random")


# --- Spearhead search ---


func test_search_by_name_keeps_that_spearhead() -> void:
	var screen := _spearhead()
	var target: String = GameModeScreen.shown_spearheads()[0].name
	_search(screen, target)
	assert_true(target in _spearhead_names(screen))


func test_search_by_faction_keeps_that_factions_spearheads() -> void:
	var screen := _spearhead()
	var entry: Dictionary = GameModeScreen.shown_spearheads()[0]
	_search(screen, entry.faction)
	assert_true(entry.name in _spearhead_names(screen))


func test_search_filters_out_spearheads_that_do_not_match() -> void:
	var screen := _spearhead()
	var entry: Dictionary = GameModeScreen.shown_spearheads()[0]
	_search(screen, entry.name)
	assert_lt(_entry_cards(screen).size(), GameModeScreen.shown_spearheads().size())


func test_search_by_alliance_name_keeps_that_alliances_spearheads() -> void:
	var screen := _spearhead()
	var entry: Dictionary = GameModeScreen.shown_spearheads()[0]
	_search(screen, GrandAlliance.display_name(entry.alliance))
	assert_true(entry.name in _spearhead_names(screen))


func test_search_by_alliance_name_filters_out_other_alliances_spearheads() -> void:
	var screen := _spearhead()
	var entry: Dictionary = GameModeScreen.shown_spearheads()[0]
	_search(screen, GrandAlliance.display_name(entry.alliance))
	var other_alliances := GameModeScreen.shown_spearheads().filter(func(other: Dictionary) -> bool:
		return other.alliance != entry.alliance).map(func(other: Dictionary) -> String: return other.name)
	assert_eq(_spearhead_names(screen).filter(func(name: String) -> bool: return name in other_alliances), [])


func test_search_without_matches_shows_no_cards() -> void:
	var screen := _spearhead()
	_search(screen, "zzzzzz-no-such-spearhead")
	assert_eq(_entry_cards(screen).size(), 0)


func test_search_without_matches_says_so() -> void:
	var screen := _spearhead()
	_search(screen, "zzzzzz-no-such-spearhead")
	assert_true(UIKit.has_label_containing(screen.pane_box, "No Spearheads match"))


func test_clearing_the_search_restores_the_list() -> void:
	var screen := _spearhead()
	_search(screen, "zzzzzz-no-such-spearhead")
	_search(screen, "")
	assert_eq(_entry_cards(screen).size(), GameModeScreen.shown_spearheads().size())


func test_escape_in_a_filled_search_clears_it() -> void:
	var screen := _spearhead()
	_search(screen, "zzz")
	screen._unhandled_input(_escape_event())
	assert_eq(screen.query, "")


func test_escape_in_a_filled_search_does_not_go_back() -> void:
	var screen := _spearhead()
	_search(screen, "zzz")
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


func _pick_plan(screen: ArmySelect, plan_name: String) -> void:
	screen.show_plans()
	var picker: BattleplanPicker = UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is BattleplanPicker)[0]
	picker.cards[plan_name].pressed.emit()


func test_random_battleplan_card_shows_the_icon_filling_its_art() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	await get_tree().process_frame
	assert_true(_plan_card_nodes(screen, BattleplanMap).is_empty())
	var art: Control = _plan_card_nodes(screen, ArtPlaceholder)[0]
	var icon: TextureRect = UIKit.find_all(art, func(n: Node) -> bool: return n is TextureRect)[0]
	assert_eq(art.size, ArmySelect.PLAN_ART_SIZE)
	assert_gte(icon.size.y, art.size.y * 0.75, "the icon fills most of its box")


func test_picked_battleplan_card_shows_its_map_in_place_of_the_icon() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	_pick_plan(screen, _first_plan_name())
	await get_tree().process_frame
	var maps := _plan_card_nodes(screen, BattleplanMap)
	assert_eq(maps.size(), 1)
	assert_eq(maps[0].battleplan.name, _first_plan_name())
	assert_eq(maps[0].size, ArmySelect.PLAN_ART_SIZE)
	assert_true(_plan_card_nodes(screen, ArtPlaceholder).is_empty())


func test_picking_a_battleplan_keeps_the_card_size() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	await get_tree().process_frame
	var random_size := _battleplan_card(screen).size
	_pick_plan(screen, _first_plan_name())
	await get_tree().process_frame
	assert_eq(_battleplan_card(screen).size, random_size)


func test_picking_random_shows_the_icon_again() -> void:
	_save_army("Free", true)
	var screen := _matched_play()
	_pick_plan(screen, _first_plan_name())
	_pick_plan(screen, "")
	await get_tree().process_frame
	assert_true(_plan_card_nodes(screen, BattleplanMap).is_empty())


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


# --- Spearhead detail layout ---


func _section_of(screen: ArmySelect, accessibility_name: String) -> Node:
	var cards := UIKit.find_all(screen, func(n: Node) -> bool:
		return n is Control and n.accessibility_name == accessibility_name)
	return cards[0].get_parent() if not cards.is_empty() else null


func test_spearhead_battle_traits_are_laid_out_two_to_a_row() -> void:
	var screen := _spearhead()
	var grids := UIKit.find_all(screen, func(n: Node) -> bool:
		return n is GridContainer and n.get_children().any(func(c: Node) -> bool: return c is AbilityCard))
	assert_eq(grids.size(), 1)
	assert_eq(grids[0].columns, 2)
	assert_eq(grids[0].get_child_count(), screen.spearhead.battle_traits.size())


func _trait_cards(screen: ArmySelect) -> Array[Node]:
	return UIKit.find_all(screen, func(n: Node) -> bool:
		return n is AbilityCard and n.get_parent() is GridContainer)


func test_spearhead_battle_traits_start_folded() -> void:
	var cards := _trait_cards(_spearhead())
	assert_false(cards.is_empty())
	var unfolded := cards.filter(func(card: AbilityCard) -> bool: return not card.folded)
	assert_eq(unfolded.map(func(card: AbilityCard) -> String: return card.ability.name), [])


func test_spearhead_regiment_abilities_and_enhancements_share_a_row() -> void:
	var screen := _spearhead()
	var regiment := _section_of(screen, "Regiment Abilities")
	var enhancements := _section_of(screen, "Enhancements")
	assert_not_null(regiment)
	assert_not_null(enhancements)
	assert_true(regiment.get_parent() is HBoxContainer)
	assert_eq(regiment.get_parent(), enhancements.get_parent())


func test_spearhead_regiment_abilities_and_enhancements_are_below_battle_traits() -> void:
	var screen := _spearhead()
	var grids := UIKit.find_all(screen, func(n: Node) -> bool:
		return n is GridContainer and n.get_children().any(func(c: Node) -> bool: return c is AbilityCard))
	var traits_section: Node = grids[0].get_parent()
	var row: Node = _section_of(screen, "Regiment Abilities").get_parent()
	assert_eq(row.get_parent(), traits_section.get_parent())
	assert_gt(row.get_index(), traits_section.get_index())


# --- Detail section order ---

const SECTION_TITLES := ["Army", "Faction Terrain", "Battle Traits", "Battle Formation", "Battle Tactics", "Lores",
		"Regiment Abilities", "Enhancements"]


## The detail's section titles in the order they appear on screen.
func _section_titles(screen: ArmySelect) -> Array:
	var labels := UIKit.find_all(screen.detail_column, func(n: Node) -> bool:
		return n is Label and SECTION_TITLES.has(n.text.capitalize()) and n.theme_type_variation == &"TitleLabel")
	return labels.map(func(label: Label) -> String: return label.text.capitalize())


## Saves an army of the first faction with data, with its first faction terrain and battle formation,
## and its first Army of Renown if [param renown].
func _save_full_army(renown := false) -> Army:
	var faction := _faction()
	var catalog := ArmyCatalog.new(faction, CoreRulesCatalog.get_rules())
	var army_of_renown: String = faction.armies_of_renown[0].name if renown else ""
	var army := ArmyEditor.create_army(catalog, army_of_renown, faction.battle_formations[0].name)
	army.name = "Full"
	army.faction_terrain = catalog.terrain_warscrolls()[0].id
	assert_eq(ArmyStore.save(army), OK)
	return army


func test_matched_play_puts_army_before_faction_terrain_before_tactics_and_lores() -> void:
	var army := _save_full_army()
	assert_eq(_section_titles(_matched_play(army.id)), ["Army", "Faction Terrain", "Battle Tactics", "Lores"])


func test_matched_play_without_faction_terrain_goes_from_army_to_tactics_and_lores() -> void:
	_save_army("Plain")
	assert_eq(_section_titles(_matched_play()), ["Army", "Battle Tactics", "Lores"])


func test_matched_play_has_no_battle_traits_or_formation_section() -> void:
	var army := _save_full_army()
	var titles := _section_titles(_matched_play(army.id))
	assert_false(titles.has("Battle Traits"))
	assert_false(titles.has("Battle Formation"))


func test_matched_play_army_of_renown_has_no_battle_traits_section() -> void:
	var army := _save_full_army(true)
	assert_false(_section_titles(_matched_play(army.id)).has("Battle Traits"))


func test_spearhead_puts_army_before_battle_traits_before_abilities_and_enhancements() -> void:
	assert_eq(_section_titles(_spearhead()), ["Army", "Battle Traits", "Regiment Abilities", "Enhancements"])


func test_spearhead_does_not_say_ready_to_play() -> void:
	assert_eq(_labels(_spearhead().detail_column, "Ready to play").size(), 0)


# --- Layout ---

func test_list_entries_stop_short_of_the_scroll_bar() -> void:
	var screen := _make_select()
	screen.open(BattleSetup.Mode.SPEARHEAD)
	for i in 3:
		await get_tree().process_frame
	var scroll := UIKit.find_all(screen.pane_box, func(n: Node) -> bool: return n is ScrollContainer)[0] as ScrollContainer
	var card := _entry_cards(screen)[0] as Control
	assert_true(scroll.get_v_scroll_bar().visible, "the list should be long enough to scroll")
	assert_lte(card.get_global_rect().end.x, scroll.get_v_scroll_bar().get_global_rect().position.x - ArmySelect.SCROLL_GAP)
