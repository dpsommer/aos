extends GutTest
## Unit tests for the army builder's info pane (scripts/ui/forge/builder/info_pane.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")

const TEMP_FAVOURITES := "user://test_info_pane_favourites.cfg"


func before_each() -> void:
	Sandbox.begin()
	InfoPane.favourites_path = TEMP_FAVOURITES
	DirAccess.remove_absolute(TEMP_FAVOURITES)


## Redrawn content is removed with queue_free, so let a frame pass for it to be freed before GUT
## counts orphans.
func after_each() -> void:
	await get_tree().process_frame
	Sandbox.end()
	DirAccess.remove_absolute(TEMP_FAVOURITES)


# --- Set-up ---

func _abilities(names: Array) -> Array[Ability]:
	var result: Array[Ability] = []
	for ability_name: String in names:
		result.append(Kit.ability(ability_name))
	return result


## UIKit's faction with rules: a battle trait, two formations, an enhancement table, a spell lore
## and a prayer lore, and a regiment of renown.
func _faction() -> Faction:
	var faction := UIKit.faction()
	faction.battle_traits = _abilities(["Trait Alpha"])
	faction.battle_formations = [Kit.formation("Vanguard"), Kit.formation("Siege", 50)] as Array[BattleFormation]
	faction.battle_formations[0].abilities = _abilities(["Charge Plan"])
	faction.battle_formations[1].abilities = _abilities(["Wall Breaker"])
	faction.enhancement_tables = [Kit.table("Artefacts", _abilities(["Sword of Dawn"]))] as Array[EnhancementTable]
	var spells := Kit.lore("Fire Spells", "spell")
	spells.entries = _abilities(["Fireball"])
	var prayers := Kit.lore("Sun Prayers", "prayer", 20)
	prayers.entries = _abilities(["Blessing"])
	faction.lores = [spells, prayers] as Array[Lore]
	return faction


func _band(band_name: String, unit_name: String, legends := false) -> RegimentOfRenown:
	var units: Array[RegimentUnit] = [Kit.renown_unit(unit_name, unit_name.to_lower())]
	var own: Array[Warscroll] = [Kit.warscroll(unit_name.to_lower())]
	var band := Kit.regiment_of_renown(band_name, 150, units, own)
	band.legends = legends
	return band


func _pane(army: Army = null, faction: Faction = null) -> InfoPane:
	var core := Kit.core(PackedStringArray(["Card A", "Card B"]))
	var builder := UIKit.builder(self, army if army else UIKit.army_with_regiment(), faction if faction else _faction(), core)
	return builder.info_pane


func _search(pane: InfoPane, text: String) -> void:
	pane.search.text = text
	pane.search.text_changed.emit(text)


func _card_ids(pane: InfoPane) -> Array:
	var ids := []
	for node in UIKit.find_all(pane, func(n: Node) -> bool: return str(n.get_meta(&"focus_key", "")).begins_with("info:card:")):
		ids.append(str(node.get_meta(&"focus_key")).trim_prefix("info:card:"))
	return ids


func _rich_count(node: Node) -> int:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is RichTextLabel).size()


func _press(pane: InfoPane, key: String) -> void:
	(UIKit.keyed(pane, key) as Button).pressed.emit()


func _first_content_node(pane: InfoPane) -> Node:
	return pane._content.get_child(0)


# --- Tabs ---

func test_pane_starts_on_the_roster_tab() -> void:
	assert_eq(_pane().tab, "roster")


func test_each_tab_button_switches_tab() -> void:
	var pane := _pane()
	for key: String in pane.tab_buttons:
		_press(pane, "info:tab:" + key)
		assert_eq(pane.tab, key)


func test_only_the_current_tabs_button_is_pressed() -> void:
	var pane := _pane()
	pane.set_tab("rules")
	for key: String in pane.tab_buttons:
		assert_eq(pane.tab_buttons[key].button_pressed, key == "rules", key)


func test_each_tab_has_its_own_placeholder() -> void:
	var pane := _pane()
	var placeholders := {}
	for key: String in InfoPane.TABS:
		pane.set_tab(key)
		assert_false(pane.search.placeholder_text.is_empty(), key)
		placeholders[pane.search.placeholder_text] = true
	assert_eq(placeholders.size(), InfoPane.TABS.size())


func test_search_is_visible_on_every_tab() -> void:
	var pane := _pane()
	for key: String in InfoPane.TABS:
		pane.set_tab(key)
		assert_true(pane.search.visible, key)


func test_search_query_is_shared_across_tabs() -> void:
	var pane := _pane()
	_search(pane, "wall")
	pane.set_tab("rules")
	assert_eq(pane.query, "wall")
	assert_eq(pane.search.text, "wall")


func test_the_query_filters_the_new_tab() -> void:
	var pane := _pane()
	_search(pane, "wall breaker")
	pane.set_tab("rules")
	assert_not_null(UIKit.keyed(pane, "info:sec:Battle Formations"))
	assert_null(UIKit.keyed(pane, "info:sec:Battle Traits"))


# --- Esc ---

func _cancel() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func test_escape_in_the_search_box_clears_the_query() -> void:
	var pane := _pane()
	_search(pane, "grunt")
	pane.search.gui_input.emit(_cancel())
	assert_eq(pane.query, "")
	assert_eq(pane.search.text, "")


func test_escape_restores_the_full_list() -> void:
	var pane := _pane()
	_search(pane, "grunt")
	pane.search.gui_input.emit(_cancel())
	assert_gt(_card_ids(pane).size(), 1)


func test_escape_with_an_empty_query_does_nothing() -> void:
	var pane := _pane()
	var event := _cancel()
	pane.search.gui_input.emit(event)
	assert_eq(pane.query, "")


# --- Roster ---

func test_roster_groups_units_under_their_type() -> void:
	var pane := _pane()
	assert_not_null(UIKit.keyed(pane, "info:type:Hero"))
	assert_not_null(UIKit.keyed(pane, "info:type:Infantry"))
	assert_not_null(UIKit.keyed(pane, "info:type:Other"))
	assert_null(UIKit.keyed(pane, "info:type:Monster"))


func test_roster_lists_every_unit_but_not_terrain() -> void:
	var ids := _card_ids(_pane())
	for id in ["lead", "grunt", "beast", "unique", "wizard"]:
		assert_has(ids, id)
	assert_does_not_have(ids, "terrain")


func test_unit_type_picks_the_first_matching_keyword() -> void:
	assert_eq(InfoPane.unit_type(Kit.warscroll("a", PackedStringArray(["INFANTRY", "HERO"]))), "Hero")
	assert_eq(InfoPane.unit_type(Kit.warscroll("a", PackedStringArray(["CAVALRY"]))), "Cavalry")
	assert_eq(InfoPane.unit_type(Kit.warscroll("a", PackedStringArray(["MONSTER"]))), "Monster")


func test_unit_type_without_a_known_keyword_is_other() -> void:
	assert_eq(InfoPane.unit_type(Kit.warscroll("a", PackedStringArray(["BEAST"]))), "Other")


func test_legends_units_are_hidden_by_default() -> void:
	assert_does_not_have(_card_ids(_pane()), "legend")


func test_hidden_legends_units_are_counted() -> void:
	var pane := _pane()
	assert_true(UIKit.has_label_containing(pane, "1 Legends unit hidden"))


func test_hidden_count_is_plural_for_several_units() -> void:
	var faction := _faction()
	faction.get_warscroll("grunt").legends = true
	assert_true(UIKit.has_label_containing(_pane(null, faction), "2 Legends units hidden"))


func test_turning_on_legends_shows_them_and_drops_the_count() -> void:
	var pane := _pane()
	pane.builder.editor.set_show_legends(true)
	assert_has(_card_ids(pane), "legend")
	assert_false(UIKit.has_label_containing(pane, "hidden"))


func test_search_filters_the_roster_by_name() -> void:
	var pane := _pane()
	_search(pane, "grunt")
	assert_eq(_card_ids(pane), ["grunt"])


func test_search_filters_the_roster_by_type() -> void:
	var pane := _pane()
	_search(pane, "hero")
	var ids := _card_ids(pane)
	assert_has(ids, "lead")
	assert_does_not_have(ids, "grunt")


func test_search_does_not_reveal_hidden_legends() -> void:
	var pane := _pane()
	_search(pane, "legend")
	assert_does_not_have(_card_ids(pane), "legend")


func test_roster_search_with_no_match_shows_a_message() -> void:
	var pane := _pane()
	_search(pane, "zzzz")
	assert_true(UIKit.has_label_containing(pane, "Nothing matches"))
	assert_eq(_card_ids(pane).size(), 0)


func test_folding_a_type_hides_its_cards() -> void:
	var pane := _pane()
	_press(pane, "info:type:Hero")
	assert_has(pane.folded, "type:Hero")
	assert_does_not_have(_card_ids(pane), "lead")
	assert_has(_card_ids(pane), "grunt")


func test_unfolding_a_type_shows_its_cards_again() -> void:
	var pane := _pane()
	_press(pane, "info:type:Hero")
	_press(pane, "info:type:Hero")
	assert_has(_card_ids(pane), "lead")


func test_searching_shows_matches_in_folded_types() -> void:
	var pane := _pane()
	_press(pane, "info:type:Hero")
	_search(pane, "lead")
	assert_has(_card_ids(pane), "lead")


func test_a_cards_warscroll_is_hidden_until_selected() -> void:
	var pane := _pane()
	assert_eq(_rich_count(pane._content), 0)
	assert_null(UIKit.keyed(pane, "info:aux:grunt"))


func test_pressing_a_card_shows_its_warscroll_and_the_add_auxiliary_button() -> void:
	var pane := _pane()
	_press(pane, "info:card:grunt")
	assert_eq(pane.selected, "grunt")
	assert_gt(_rich_count(pane._content), 0)
	assert_eq((UIKit.keyed(pane, "info:aux:grunt") as Button).text, "Add as auxiliary unit")


## The roster card holding the button with [param key].
func _card_of(pane: InfoPane, key: String) -> PanelContainer:
	var node := UIKit.keyed(pane, key).get_parent()
	while not node is PanelContainer:
		node = node.get_parent()
	return node


func test_focusing_a_card_outlines_the_whole_card() -> void:
	var pane := _pane()
	(UIKit.keyed(pane, "info:card:grunt") as Button).grab_focus()
	assert_eq(_card_of(pane, "info:card:grunt").theme_type_variation, &"FocusRowPanel")


func test_card_loses_its_outline_with_focus() -> void:
	var pane := _pane()
	var button := UIKit.keyed(pane, "info:card:grunt") as Button
	button.grab_focus()
	button.release_focus()
	assert_eq(_card_of(pane, "info:card:grunt").theme_type_variation, &"RowPanel")


func test_focused_open_card_keeps_its_picked_look() -> void:
	var pane := _pane()
	_press(pane, "info:card:grunt")
	(UIKit.keyed(pane, "info:card:grunt") as Button).grab_focus()
	assert_eq(_card_of(pane, "info:card:grunt").theme_type_variation, &"FocusPickedRowPanel")


func test_pressing_the_selected_card_again_hides_its_warscroll() -> void:
	var pane := _pane()
	_press(pane, "info:card:grunt")
	_press(pane, "info:card:grunt")
	assert_eq(pane.selected, "")
	assert_eq(_rich_count(pane._content), 0)


func test_only_one_card_is_selected_at_a_time() -> void:
	var pane := _pane()
	_press(pane, "info:card:grunt")
	_press(pane, "info:card:beast")
	assert_null(UIKit.keyed(pane, "info:aux:grunt"))
	assert_not_null(UIKit.keyed(pane, "info:aux:beast"))


func test_add_as_auxiliary_unit_adds_the_unit_to_the_army() -> void:
	var army := UIKit.army_with_regiment()
	var pane := _pane(army)
	_press(pane, "info:card:grunt")
	_press(pane, "info:aux:grunt")
	assert_eq(army.auxiliary.size(), 1)
	assert_eq(army.auxiliary[0].warscroll_id, "grunt")


func test_add_as_auxiliary_unit_is_enabled_for_a_unique_not_in_the_army() -> void:
	var pane := _pane()
	_press(pane, "info:card:unique")
	assert_false((UIKit.keyed(pane, "info:aux:unique") as Button).disabled)


func test_add_as_auxiliary_unit_is_disabled_for_a_unique_already_in_the_army() -> void:
	var pane := _pane(UIKit.army_with_regiment(PackedStringArray(["unique"])))
	_press(pane, "info:card:unique")
	assert_true((UIKit.keyed(pane, "info:aux:unique") as Button).disabled)


func test_the_button_disables_once_a_unique_is_added() -> void:
	var pane := _pane()
	_press(pane, "info:card:unique")
	_press(pane, "info:aux:unique")
	assert_true((UIKit.keyed(pane, "info:aux:unique") as Button).disabled)


func test_override_allows_a_second_copy_of_a_unique() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["unique"]))
	army.override_constraints = true
	var pane := _pane(army)
	_press(pane, "info:card:unique")
	assert_false((UIKit.keyed(pane, "info:aux:unique") as Button).disabled)


# --- Favourites ---

func test_the_star_adds_a_favourite() -> void:
	var pane := _pane()
	(UIKit.keyed(pane, "info:star:grunt") as Button).button_pressed = true
	assert_eq(pane.favourites, PackedStringArray(["grunt"]))


func test_pressing_the_star_again_removes_the_favourite() -> void:
	var pane := _pane()
	pane.toggle_favourite("grunt")
	(UIKit.keyed(pane, "info:star:fav:grunt") as Button).button_pressed = false
	assert_eq(pane.favourites.size(), 0)


func test_favourites_are_pinned_above_the_types() -> void:
	var pane := _pane()
	pane.toggle_favourite("beast")
	assert_eq(_card_ids(pane)[0], "fav:beast")
	assert_has(_card_ids(pane), "beast")


func test_newest_favourite_is_first() -> void:
	var pane := _pane()
	pane.toggle_favourite("beast")
	pane.toggle_favourite("grunt")
	assert_eq(_card_ids(pane).slice(0, 2), ["fav:grunt", "fav:beast"])


func test_favourites_are_filtered_by_the_search() -> void:
	var pane := _pane()
	pane.toggle_favourite("beast")
	pane.toggle_favourite("grunt")
	_search(pane, "beast")
	assert_has(_card_ids(pane), "fav:beast")
	assert_does_not_have(_card_ids(pane), "fav:grunt")


func test_a_favourite_legends_unit_is_hidden_while_legends_are_hidden() -> void:
	var pane := _pane()
	pane.toggle_favourite("legend")
	assert_does_not_have(_card_ids(pane), "fav:legend")


func test_the_pinned_card_selects_separately_from_the_listed_card() -> void:
	var pane := _pane()
	pane.toggle_favourite("grunt")
	_press(pane, "info:card:fav:grunt")
	assert_not_null(UIKit.keyed(pane, "info:aux:fav:grunt"))
	assert_null(UIKit.keyed(pane, "info:aux:grunt"))


func test_favourites_are_saved_to_the_config_file() -> void:
	var pane := _pane()
	pane.toggle_favourite("grunt")
	var config := ConfigFile.new()
	assert_eq(config.load(TEMP_FAVOURITES), OK)
	assert_eq(config.get_value("favourites", "test_faction"), PackedStringArray(["grunt"]))


func test_favourites_are_loaded_when_the_builder_opens() -> void:
	var config := ConfigFile.new()
	config.set_value("favourites", "test_faction", PackedStringArray(["beast"]))
	config.save(TEMP_FAVOURITES)
	var pane := _pane()
	assert_eq(pane.favourites, PackedStringArray(["beast"]))
	assert_eq(_card_ids(pane)[0], "fav:beast")


func test_favourites_are_kept_per_faction() -> void:
	var config := ConfigFile.new()
	config.set_value("favourites", "other_faction", PackedStringArray(["beast"]))
	config.save(TEMP_FAVOURITES)
	assert_eq(_pane().favourites.size(), 0)


func test_saving_a_favourite_keeps_other_factions_favourites() -> void:
	var config := ConfigFile.new()
	config.set_value("favourites", "other_faction", PackedStringArray(["beast"]))
	config.save(TEMP_FAVOURITES)
	_pane().toggle_favourite("grunt")
	config.load(TEMP_FAVOURITES)
	assert_eq(config.get_value("favourites", "other_faction"), PackedStringArray(["beast"]))


func test_missing_config_file_means_no_favourites() -> void:
	assert_eq(_pane().favourites.size(), 0)


# --- Rules ---

func _rules_pane(army: Army = null) -> InfoPane:
	var pane := _pane(army)
	pane.set_tab("rules")
	return pane


func test_rules_tab_has_a_section_per_kind_of_rules() -> void:
	var pane := _rules_pane()
	for title in ["Battle Traits", "Battle Formations", "Enhancements", "Lores", "Battle Tactics"]:
		assert_not_null(UIKit.keyed(pane, "info:sec:" + title), title)


func test_sections_start_open_with_their_rules_shown() -> void:
	assert_gt(_rich_count(_rules_pane()._content), 0)


func test_folding_a_section_hides_its_rules() -> void:
	var pane := _rules_pane()
	for title in ["Battle Traits", "Battle Formations", "Enhancements", "Lores", "Faction Terrain", "Battle Tactics"]:
		if UIKit.keyed(pane, "info:sec:" + title):
			_press(pane, "info:sec:" + title)
	assert_has(pane.folded, "sec:Battle Traits")
	assert_eq(_rich_count(pane._content), 0)
	assert_eq(UIKit.find_all(pane, func(n: Node) -> bool: return n is TacticCard).size(), 0)


func test_unfolding_a_section_shows_its_rules_again() -> void:
	var pane := _rules_pane()
	_press(pane, "info:sec:Battle Traits")
	var folded := _rich_count(pane._content)
	_press(pane, "info:sec:Battle Traits")
	assert_gt(_rich_count(pane._content), folded)


func test_formations_are_groups_that_can_be_folded() -> void:
	var pane := _rules_pane()
	var before := _rich_count(pane._content)
	_press(pane, "info:grp:Battle Formations:Vanguard")
	assert_has(pane.folded, "grp:Battle Formations:Vanguard")
	assert_lt(_rich_count(pane._content), before)


func test_rules_tab_has_no_manifestations_section() -> void:
	assert_null(UIKit.keyed(_rules_pane(), "info:sec:Manifestations"))


## Rules text in the pane containing [param text].
func _rules_containing(pane: InfoPane, text: String) -> Array[Node]:
	return UIKit.find_all(pane._content, func(n: Node) -> bool:
		return n is RichTextLabel and n.get_parsed_text().contains(text))


## [method _faction] with a second "Artefacts" table, from Scourge of Ghyran.
func _scourge_faction() -> Faction:
	var faction := _faction()
	var second := Kit.table("Artefacts", _abilities(["Shield of Dusk"]))
	second.source = "Scourge of Ghyran"
	faction.enhancement_tables.append(second)
	return faction


func test_groups_with_the_same_title_fold_independently() -> void:
	var pane := _pane(null, _scourge_faction())
	pane.set_tab("rules")
	_press(pane, "info:grp:Enhancements:Artefacts#2")
	assert_not_null(UIKit.keyed(pane, "info:grp:Enhancements:Artefacts"))
	assert_eq(_rules_containing(pane, "Sword of Dawn").size(), 1)
	assert_eq(_rules_containing(pane, "Shield of Dusk").size(), 0)


func test_scourge_groups_have_a_scourge_tag() -> void:
	var pane := _pane(null, _scourge_faction())
	pane.set_tab("rules")
	assert_eq(Array(UIKit.label_texts(pane)).count("SOG"), 1)


func test_battletome_groups_have_no_scourge_tag() -> void:
	var texts := UIKit.label_texts(_rules_pane())
	assert_does_not_have(texts, "SOG")
	assert_does_not_have(texts, "SOA")


func test_a_summoning_spell_shows_its_manifestations_warscroll() -> void:
	var faction := _faction()
	var lore := Kit.lore("Flame Lore", "manifestation")
	lore.entries = _abilities(["Summon Living Flame"])
	lore.entries[0].summons = PackedStringArray(["living_flame"])
	faction.lores.append(lore)
	faction.warscrolls.append(Kit.warscroll("living_flame", PackedStringArray(["MANIFESTATION"]), 0, "Living Flame"))
	var pane := _pane(null, faction)
	pane.set_tab("rules")
	_press(pane, "info:grp:Lores:Flame Lore")
	var cards := _rules_containing(pane, "Summon Living Flame")
	assert_eq(cards.size(), 1)
	var card: Node = cards[0].get_parent()
	assert_eq(_rich_count(card), 2)


func test_show_lores_switches_to_the_rules_tab_and_unfolds_the_section() -> void:
	var pane := _rules_pane()
	_press(pane, "info:sec:Lores")
	pane.set_tab("roster")
	pane.show_lores()
	assert_eq(pane.tab, "rules")
	assert_does_not_have(pane.folded, "sec:Lores")
	assert_eq(pane.flash_key, "sec:Lores")


func test_lores_start_folded() -> void:
	var pane := _rules_pane()
	assert_not_null(UIKit.keyed(pane, "info:grp:Lores:Fire Spells"))
	assert_true(pane.open_lores.is_empty())


func test_a_folded_lore_shows_no_rules() -> void:
	var folded := _rich_count(_rules_pane()._content)
	var pane := _rules_pane()
	_press(pane, "info:grp:Lores:Fire Spells")
	assert_gt(_rich_count(pane._content), folded)


func test_pressing_a_lore_unfolds_it_and_again_folds_it() -> void:
	var pane := _rules_pane()
	_press(pane, "info:grp:Lores:Fire Spells")
	assert_has(pane.open_lores, "Fire Spells")
	_press(pane, "info:grp:Lores:Fire Spells")
	assert_does_not_have(pane.open_lores, "Fire Spells")


func test_picked_lore_has_a_selected_chip() -> void:
	var army := UIKit.army_with_regiment()
	army.prayer_lore = "Sun Prayers"
	var texts := UIKit.label_texts(_rules_pane(army))
	assert_eq(Array(texts).filter(func(t: String) -> bool: return t == "SELECTED").size(), 1)


func test_no_selected_chip_without_a_picked_lore() -> void:
	assert_does_not_have(UIKit.label_texts(_rules_pane()), "SELECTED")


func test_picked_formation_has_a_selected_chip() -> void:
	var army := UIKit.army_with_regiment()
	army.formation = "Siege"
	assert_has(UIKit.label_texts(_rules_pane(army)), "SELECTED")


func test_picking_a_lore_in_the_army_updates_the_chip() -> void:
	var pane := _rules_pane()
	pane.builder.editor.set_lore("spell", "Fire Spells")
	assert_has(UIKit.label_texts(pane), "SELECTED")


func test_rules_search_filters_the_sections() -> void:
	var pane := _rules_pane()
	_search(pane, "wall breaker")
	assert_not_null(UIKit.keyed(pane, "info:sec:Battle Formations"))
	assert_null(UIKit.keyed(pane, "info:sec:Battle Traits"))


func test_rules_search_unfolds_matching_lores() -> void:
	var pane := _rules_pane()
	_search(pane, "fireball")
	assert_gt(_rich_count(pane._content), 0)


func test_rules_search_with_no_match_shows_a_message() -> void:
	var pane := _rules_pane()
	_search(pane, "zzzz")
	assert_true(UIKit.has_label_containing(pane, "Nothing matches"))


func test_battle_tactic_cards_are_listed_in_full() -> void:
	var cards := UIKit.find_all(_rules_pane(), func(n: Node) -> bool: return n is TacticCard)
	assert_eq(cards.size(), 2)


func test_battle_tactic_cards_in_the_army_are_marked_with_their_slot() -> void:
	var army := UIKit.army_with_regiment()
	army.tactics = PackedStringArray(["Card A", ""])
	assert_has(UIKit.label_texts(_rules_pane(army)), "BATTLE TACTIC 1")


# --- Regiments of Renown ---

func _renown_faction() -> Faction:
	var faction := _faction()
	faction.regiments_of_renown = [_band("Band", "Gotrek"), _band("Old Band", "Felix", true)] as Array[RegimentOfRenown]
	return faction


func _renown_pane(army: Army = null, faction: Faction = null) -> InfoPane:
	var pane := _pane(army, faction if faction else _renown_faction())
	pane.set_tab("renown")
	return pane


func _cards(pane: InfoPane) -> Array[Node]:
	return UIKit.find_all(pane, func(n: Node) -> bool: return n is RenownCard)


func test_renown_tab_lists_regiments_of_renown() -> void:
	var cards := _cards(_renown_pane())
	assert_eq(cards.size(), 1)
	assert_eq(cards[0].regiment.name, "Band")


func test_renown_tab_hides_legends_regiments_unless_shown() -> void:
	var army := UIKit.army_with_regiment()
	army.show_legends = true
	assert_eq(_cards(_renown_pane(army)).size(), 2)


func test_renown_cards_use_the_tab_context() -> void:
	assert_not_null(UIKit.keyed(_renown_pane(), "tab:add:Band"))


func test_renown_search_filters_by_unit_name() -> void:
	var army := UIKit.army_with_regiment()
	army.show_legends = true
	var pane := _renown_pane(army)
	_search(pane, "felix")
	var cards := _cards(pane)
	assert_eq(cards.size(), 1)
	assert_eq(cards[0].regiment.name, "Old Band")


func test_renown_search_with_no_match_shows_a_message() -> void:
	var pane := _renown_pane()
	_search(pane, "zzzz")
	assert_eq(_cards(pane).size(), 0)
	assert_true(UIKit.has_label_containing(pane, "No Regiments of Renown match"))


func test_renown_tab_without_any_regiments_says_so() -> void:
	var pane := _renown_pane(null, _faction())
	assert_true(UIKit.has_label_containing(pane, "No Regiments of Renown are available"))


func _forbidding_faction() -> Faction:
	var faction := _renown_faction()
	var renown := Kit.army_of_renown("Solo")
	renown.roster.regiments_of_renown = false
	faction.armies_of_renown.append(renown)
	return faction


func _solo_army() -> Army:
	var army := UIKit.army_with_regiment()
	army.army_of_renown = "Solo"
	return army


func test_an_army_of_renown_can_forbid_regiments_of_renown() -> void:
	var pane := _renown_pane(_solo_army(), _forbidding_faction())
	assert_eq(_cards(pane).size(), 0)
	assert_true(UIKit.has_label_containing(pane, "Solo armies can't include Regiments of Renown"))


func test_override_shows_every_regiment_of_renown_with_a_note() -> void:
	var army := _solo_army()
	army.override_constraints = true
	var pane := _renown_pane(army, _forbidding_faction())
	assert_eq(_cards(pane).size(), 1)
	assert_true(UIKit.has_label_containing(pane, "overridden"))


func test_adding_a_regiment_from_the_tab_updates_the_army() -> void:
	var army := UIKit.army_with_regiment()
	var pane := _renown_pane(army)
	_press(pane, "tab:add:Band")
	assert_true(army.regiments.any(func(r: ArmyRegiment) -> bool: return r.regiment_of_renown == "Band"))


func test_opening_a_unit_in_the_tab_redraws_the_tab() -> void:
	var pane := _renown_pane()
	var before := _rich_count(pane._content)
	_press(pane, "tab:Band:0")
	assert_gt(_rich_count(pane._content), before)


# --- Settings ---

func _settings_pane(army: Army = null, faction: Faction = null) -> InfoPane:
	var pane := _pane(army, faction)
	pane.set_tab("settings")
	return pane


func test_settings_search_shows_only_matching_settings() -> void:
	var pane := _settings_pane()
	pane.search.text = "points"
	pane.search.text_changed.emit("points")
	assert_not_null(UIKit.keyed(pane, "info:points"))
	assert_null(UIKit.keyed(pane, "info:legends"))
	assert_null(UIKit.keyed(pane, "info:override"))


func test_settings_search_matches_a_settings_note() -> void:
	var pane := _settings_pane()
	pane.search.text_changed.emit("validation")
	assert_not_null(UIKit.keyed(pane, "info:override"))
	assert_null(UIKit.keyed(pane, "info:points"))


func test_settings_search_with_no_matches_says_so() -> void:
	var pane := _settings_pane()
	pane.search.text_changed.emit("zzz")
	assert_true(UIKit.has_label_containing(pane, "No settings match"))


func test_legends_switch_sets_show_legends() -> void:
	var army := UIKit.army_with_regiment()
	var pane := _settings_pane(army)
	(UIKit.keyed(pane, "info:legends") as CheckButton).button_pressed = true
	assert_true(army.show_legends)


func test_legends_switch_reflects_the_army() -> void:
	var army := UIKit.army_with_regiment()
	army.show_legends = true
	assert_true((UIKit.keyed(_settings_pane(army), "info:legends") as CheckButton).button_pressed)


func test_override_switch_sets_override_constraints() -> void:
	var army := UIKit.army_with_regiment()
	var pane := _settings_pane(army)
	(UIKit.keyed(pane, "info:override") as CheckButton).button_pressed = true
	assert_true(army.override_constraints)


func test_turning_a_switch_off_clears_the_setting() -> void:
	var army := UIKit.army_with_regiment()
	army.override_constraints = true
	var pane := _settings_pane(army)
	(UIKit.keyed(pane, "info:override") as CheckButton).button_pressed = false
	assert_false(army.override_constraints)


func test_points_spin_box_shows_and_sets_the_limit() -> void:
	var army := UIKit.army_with_regiment()
	army.points_limit = 2000
	var pane := _settings_pane(army)
	var spin := UIKit.keyed(pane, "info:points") as SpinBox
	assert_eq(int(spin.value), 2000)
	spin.value = 3000
	assert_eq(army.points_limit, 3000)


func test_points_buttons_step_the_limit() -> void:
	var army := UIKit.army_with_regiment()
	army.points_limit = 2000
	var pane := _settings_pane(army)
	_press(pane, "info:points_up")
	assert_eq(army.points_limit, 2000 + InfoPane.POINTS_STEP)
	_press(pane, "info:points_down")
	_press(pane, "info:points_down")
	assert_eq(army.points_limit, 2000 - InfoPane.POINTS_STEP)


func test_points_spin_box_follows_the_buttons() -> void:
	var army := UIKit.army_with_regiment()
	army.points_limit = 2000
	var pane := _settings_pane(army)
	_press(pane, "info:points_up")
	assert_eq(int((UIKit.keyed(pane, "info:points") as SpinBox).value), 2000 + InfoPane.POINTS_STEP)


func test_points_limit_never_goes_below_zero() -> void:
	var army := UIKit.army_with_regiment()
	army.points_limit = 100
	var pane := _settings_pane(army)
	_press(pane, "info:points_down")
	assert_eq(army.points_limit, 0)


func _faction_with_armies_of_renown() -> Faction:
	var faction := _faction()
	faction.armies_of_renown.append(Kit.army_of_renown("Wanderers"))
	return faction


func test_army_of_renown_select_is_missing_when_the_faction_has_none() -> void:
	assert_null(UIKit.keyed(_settings_pane(), "info:aor"))


func test_army_of_renown_select_sets_the_army_of_renown() -> void:
	var army := UIKit.army_with_regiment()
	var pane := _settings_pane(army, _faction_with_armies_of_renown())
	var select := UIKit.keyed(pane, "info:aor") as OptionButton
	select.select(1)
	select.item_selected.emit(1)
	assert_eq(army.army_of_renown, "Wanderers")


func test_army_of_renown_select_can_go_back_to_the_faction_rules() -> void:
	var army := UIKit.army_with_regiment()
	army.army_of_renown = "Wanderers"
	var pane := _settings_pane(army, _faction_with_armies_of_renown())
	var select := UIKit.keyed(pane, "info:aor") as OptionButton
	select.select(0)
	select.item_selected.emit(0)
	assert_eq(army.army_of_renown, "")


func test_formation_select_sets_the_formation() -> void:
	var army := UIKit.army_with_regiment()
	var pane := _settings_pane(army)
	var select := UIKit.keyed(pane, "info:formation") as OptionButton
	select.select(2)
	select.item_selected.emit(2)
	assert_eq(army.formation, "Siege")


func test_formation_select_is_hidden_with_an_army_of_renown() -> void:
	var army := UIKit.army_with_regiment()
	army.army_of_renown = "Wanderers"
	var pane := _settings_pane(army, _faction_with_armies_of_renown())
	assert_null(UIKit.keyed(pane, "info:formation"))


func test_formation_select_is_missing_when_the_faction_has_no_formations() -> void:
	var faction := _faction()
	faction.battle_formations = [] as Array[BattleFormation]
	assert_null(UIKit.keyed(_settings_pane(null, faction), "info:formation"))


# --- Links ---

func test_show_unit_selects_the_unit_on_the_roster_tab() -> void:
	var pane := _pane()
	pane.set_tab("rules")
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("grunt"))
	assert_eq(pane.tab, "roster")
	assert_eq(pane.selected, "grunt")
	assert_not_null(UIKit.keyed(pane, "info:aux:grunt"))


func test_show_unit_flashes_the_card() -> void:
	var pane := _pane()
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("grunt"))
	assert_eq(pane.flash_key, "unit:grunt")


func test_show_unit_turns_on_legends_for_a_legends_unit() -> void:
	var pane := _pane()
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("legend"))
	assert_true(pane.builder.editor.army.show_legends)
	assert_has(_card_ids(pane), "legend")


func test_show_unit_leaves_legends_alone_for_other_units() -> void:
	var pane := _pane()
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("grunt"))
	assert_false(pane.builder.editor.army.show_legends)


func test_show_unit_unfolds_the_units_type() -> void:
	var pane := _pane()
	_press(pane, "info:type:Infantry")
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("grunt"))
	assert_does_not_have(pane.folded, "type:Infantry")
	assert_has(_card_ids(pane), "grunt")


func test_show_unit_leaves_other_types_folded() -> void:
	var pane := _pane()
	_press(pane, "info:type:Hero")
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("grunt"))
	assert_has(pane.folded, "type:Hero")


func test_show_unit_clears_the_search() -> void:
	var pane := _pane()
	_search(pane, "beast")
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("grunt"))
	assert_eq(pane.query, "")
	assert_eq(pane.search.text, "")
	assert_has(_card_ids(pane), "grunt")


func test_show_tactic_switches_to_the_rules_tab_and_flashes_the_card() -> void:
	var pane := _pane()
	pane.show_tactic("Card B")
	assert_eq(pane.tab, "rules")
	assert_eq(pane.flash_key, "tactic:Card B")


func test_show_tactic_unfolds_the_battle_tactics_section() -> void:
	var pane := _rules_pane()
	_press(pane, "info:sec:Battle Tactics")
	pane.show_tactic("Card B")
	assert_does_not_have(pane.folded, "sec:Battle Tactics")


func test_show_tactic_clears_the_search() -> void:
	var pane := _pane()
	_search(pane, "zzzz")
	pane.show_tactic("Card A")
	assert_eq(pane.query, "")
	assert_not_null(UIKit.keyed(pane, "info:sec:Battle Tactics"))


func test_show_lore_unfolds_the_lore_and_flashes_it() -> void:
	var pane := _pane()
	pane.show_lore("Fire Spells")
	assert_eq(pane.tab, "rules")
	assert_has(pane.open_lores, "Fire Spells")
	assert_eq(pane.flash_key, "lore:Fire Spells")


func test_show_lore_unfolds_the_lores_section() -> void:
	var pane := _rules_pane()
	_press(pane, "info:sec:Lores")
	pane.show_lore("Fire Spells")
	assert_does_not_have(pane.folded, "sec:Lores")


func test_show_regiment_of_renown_switches_tab_and_flashes() -> void:
	var pane := _pane(null, _renown_faction())
	pane.show_regiment_of_renown("Band")
	assert_eq(pane.tab, "renown")
	assert_eq(pane.flash_key, "ror:Band")


func test_show_regiment_of_renown_clears_the_search() -> void:
	var pane := _pane(null, _renown_faction())
	_search(pane, "zzzz")
	pane.show_regiment_of_renown("Band")
	assert_eq(pane.query, "")
	assert_eq(_cards(pane).size(), 1)


func test_links_close_an_open_picker() -> void:
	var pane := _pane()
	pane.builder.pick_auxiliary()
	assert_true(pane.builder.picker.is_open())
	pane.show_tactic("Card A")
	assert_false(pane.builder.picker.is_open())
	assert_true(pane.visible)
	assert_false(pane.builder.picker.visible)


func test_links_start_the_flash_timer() -> void:
	var pane := _pane()
	pane.show_tactic("Card A")
	assert_false(pane._flash_timer.is_stopped())


func test_flash_ends_when_the_timer_runs_out() -> void:
	var pane := _pane()
	pane.show_tactic("Card A")
	pane._flash_timer.timeout.emit()
	assert_eq(pane.flash_key, "")


func test_flash_highlights_only_while_it_lasts() -> void:
	var pane := _pane()
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("grunt"))
	var flashing := UIKit.find_all(pane, func(n: Node) -> bool: return n is PanelContainer and n.theme_type_variation == "FlashRowPanel")
	assert_eq(flashing.size(), 1)
	pane._flash_timer.timeout.emit()
	flashing = UIKit.find_all(pane, func(n: Node) -> bool: return n is PanelContainer and n.theme_type_variation == "FlashRowPanel")
	assert_eq(flashing.size(), 0)


func test_a_link_scrolls_to_and_focuses_the_target() -> void:
	var pane := _pane()
	pane.show_unit(pane.builder.catalog.faction.get_warscroll("grunt"))
	for i in 4:
		await get_tree().process_frame
	assert_true(UIKit.keyed(pane, "info:card:grunt").has_focus())


func test_a_tactic_link_focuses_the_card() -> void:
	var pane := _pane()
	pane.show_tactic("Card B")
	for i in 4:
		await get_tree().process_frame
	var target := InfoPane._find_info_key(pane._content, "tactic:Card B")
	assert_not_null(target)
	assert_true(target.has_focus())


func test_a_link_to_something_missing_does_not_error_after_the_wait() -> void:
	var pane := _pane()
	pane.show_regiment_of_renown("Nowhere")
	for i in 4:
		await get_tree().process_frame
	assert_eq(pane._scroll_to, "")
	assert_false(pane.is_processing())


# --- Redraw skipping ---

func test_refresh_does_nothing_when_nothing_changed() -> void:
	var pane := _pane()
	var first := _first_content_node(pane)
	pane.refresh()
	assert_same(_first_content_node(pane), first)


func test_changes_the_tab_does_not_show_are_skipped() -> void:
	var pane := _pane()
	var first := _first_content_node(pane)
	pane.builder.editor.set_army_name("Renamed")
	pane.builder.editor.set_tactic(0, "Card A")
	assert_same(_first_content_node(pane), first)


func test_a_relevant_army_change_redraws() -> void:
	var pane := _pane()
	var first := _first_content_node(pane)
	pane.builder.editor.set_show_legends(true)
	assert_ne(_first_content_node(pane), first)


func test_adding_a_unique_unit_redraws_the_roster() -> void:
	var pane := _pane()
	_press(pane, "info:card:unique")
	var first := _first_content_node(pane)
	pane.builder.editor.add_auxiliary("unique")
	assert_ne(_first_content_node(pane), first)


func test_tactic_changes_redraw_the_rules_tab() -> void:
	var pane := _rules_pane()
	var first := _first_content_node(pane)
	pane.builder.editor.set_tactic(0, "Card A")
	assert_ne(_first_content_node(pane), first)


func test_changing_the_search_redraws() -> void:
	var pane := _pane()
	var first := _first_content_node(pane)
	_search(pane, "grunt")
	assert_ne(_first_content_node(pane), first)


func test_refresh_after_a_skipped_change_still_shows_current_data() -> void:
	var pane := _pane()
	pane.builder.editor.set_army_name("Renamed")
	pane.set_tab("settings")
	assert_true(pane.tab_buttons["settings"].button_pressed)


func test_refresh_does_nothing_without_an_editor() -> void:
	var builder := ArmyBuilder.new()
	autofree(builder)
	var pane := InfoPane.new(builder)
	add_child_autofree(pane)
	pane.refresh()
	assert_eq(pane._content.get_child_count(), 0)
