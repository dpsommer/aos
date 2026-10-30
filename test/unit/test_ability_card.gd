extends GutTest
## Unit tests for the ability card (scripts/ui/cards/ability_card.gd).

const UIKit := preload("res://test/support/ui_kit.gd")


func _ability(fields := {}) -> Ability:
	var rule := Ability.new()
	rule.name = "Made-up Ability"
	for key: String in fields:
		rule.set(key, fields[key])
	return rule


func _phase(timing: String, fields := {}) -> String:
	fields["timing"] = timing
	return AbilityCard.phase(_ability(fields))


func _card(fields := {}) -> AbilityCard:
	var card := AbilityCard.new(_ability(fields))
	add_child_autofree(card)
	return card


func _labels(card: Node, variation: String) -> Array[Node]:
	return UIKit.find_all(card, func(n: Node) -> bool: return n is Label and n.theme_type_variation == variation)


func _label_texts(card: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for label in UIKit.find_all(card, func(n: Node) -> bool: return n is Label):
		result.append(label.text)
	return result


func _bg(card: AbilityCard) -> Color:
	return (card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color


# phase

func test_phase_deployment() -> void:
	assert_eq(_phase("Deployment Phase"), "deployment")


func test_phase_hero() -> void:
	assert_eq(_phase("Your Hero Phase"), "hero")


func test_phase_movement() -> void:
	assert_eq(_phase("Your Movement Phase"), "movement")


func test_phase_shooting() -> void:
	assert_eq(_phase("Your Shooting Phase"), "shooting")


func test_phase_charge() -> void:
	assert_eq(_phase("Your Charge Phase"), "charge")


func test_phase_combat() -> void:
	assert_eq(_phase("Any Combat Phase"), "combat")


func test_start_of_turn_is_deployment() -> void:
	assert_eq(_phase("Start of Your Turn"), "deployment")


func test_start_of_round_is_deployment() -> void:
	assert_eq(_phase("Start of the Battle Round"), "deployment")


func test_start_of_a_named_phase_is_deployment() -> void:
	assert_eq(_phase("Start of Your Hero Phase"), "deployment")


func test_end_of_turn_is_end() -> void:
	assert_eq(_phase("End of Your Turn"), "end")


func test_passive_type_is_passive_whatever_its_timing() -> void:
	assert_eq(_phase("Your Hero Phase", {type = "passive"}), "passive")


func test_passive_timing_is_passive() -> void:
	assert_eq(_phase("Passive"), "passive")


func test_reaction_to_a_fight_ability_is_combat() -> void:
	assert_eq(_phase("Reaction: You declared a FIGHT ability for this unit"), "combat")


func test_reaction_to_an_attack_is_combat() -> void:
	assert_eq(_phase("Reaction: You declared an ATTACK ability"), "combat")


func test_reaction_to_a_shoot_ability_is_shooting() -> void:
	assert_eq(_phase("Reaction: You declared a SHOOT ability"), "shooting")


func test_reaction_to_a_charge_ability_is_charge() -> void:
	assert_eq(_phase("Reaction: You declared a CHARGE ability"), "charge")


func test_reaction_to_a_run_ability_is_movement() -> void:
	assert_eq(_phase("Reaction: You declared a RUN ability"), "movement")


func test_reaction_to_a_retreat_ability_is_movement() -> void:
	assert_eq(_phase("Reaction: You declared a RETREAT ability"), "movement")


func test_reaction_to_a_move_ability_is_movement() -> void:
	assert_eq(_phase("Reaction: You declared a MOVE ability"), "movement")


func test_reaction_to_a_spell_is_hero() -> void:
	assert_eq(_phase("Reaction: You declared a SPELL ability"), "hero")


func test_reaction_to_a_prayer_is_hero() -> void:
	assert_eq(_phase("Reaction: You declared a PRAYER ability"), "hero")


func test_reaction_to_an_unbind_is_hero() -> void:
	assert_eq(_phase("Reaction: You declared an UNBIND ability"), "hero")


func test_reaction_after_a_named_phase_takes_that_phase() -> void:
	assert_eq(_phase("Your Movement Phase, Reaction: You declared a CHARGE ability"), "movement")


func test_reaction_keywords_match_whole_words_only() -> void:
	assert_eq(_phase("Reaction: GRUNTA declared a SPELL ability"), "hero")


func test_reaction_keyword_inside_a_longer_word_does_not_count() -> void:
	assert_eq(_phase("Reaction: A RUNE was used for a PRAYER ability"), "hero")


func test_reaction_without_a_keyword_uses_a_phase_in_its_clause() -> void:
	assert_eq(_phase("Reaction: An enemy unit finished the Shooting Phase"), "shooting")


func test_reaction_keyword_wins_over_a_phase_in_its_clause() -> void:
	assert_eq(_phase("Reaction: You declared a FIGHT ability in the Hero Phase"), "combat")


func test_reaction_without_keyword_or_phase_is_movement() -> void:
	assert_eq(_phase("Reaction: Something odd happened"), "movement")


func test_unknown_timing_is_movement() -> void:
	assert_eq(_phase("Whenever it feels like it"), "movement")


func test_empty_timing_is_movement() -> void:
	assert_eq(_phase(""), "movement")


func test_every_phase_is_a_known_colour_scheme() -> void:
	for timing in ["Deployment Phase", "Your Hero Phase", "Your Movement Phase", "Your Shooting Phase",
			"Your Charge Phase", "Any Combat Phase", "End of Your Turn", "Passive", "Nonsense"]:
		assert_true(AbilityCard.PHASE_COLOURS.has(_phase(timing)), timing)


# icon_name

func test_icon_name_uses_the_category() -> void:
	assert_eq(AbilityCard.icon_name(_ability({category = "movement"})), "aos/white/characteristics/move")


func test_icon_name_maps_rally_to_rallying() -> void:
	assert_eq(AbilityCard.icon_name(_ability({category = "rally"})), "aos/white/misc/glove")


func test_icon_name_of_an_unknown_category_is_special() -> void:
	assert_eq(AbilityCard.icon_name(_ability({category = "made-up"})), AbilityCard.CATEGORY_ICONS.special)


func test_icon_name_without_a_category_is_special() -> void:
	assert_eq(AbilityCard.icon_name(_ability()), AbilityCard.CATEGORY_ICONS.special)


func test_every_category_has_an_icon() -> void:
	for category: String in AbilityCard.CATEGORY_ICONS:
		var icon := UITheme.icon(AbilityCard.icon_name(_ability({category = category})))
		assert_not_null(icon, category)


func test_the_rally_icon_exists() -> void:
	assert_not_null(UITheme.icon(AbilityCard.icon_name(_ability({category = "rally"}))))


# Battle Damaged

func test_battle_damaged_is_recognised_by_name() -> void:
	assert_true(AbilityCard.is_battle_damaged(_ability({name = "Battle Damaged"})))


func test_battle_damaged_ignores_case() -> void:
	assert_true(AbilityCard.is_battle_damaged(_ability({name = "BATTLE DAMAGED"})))


func test_other_names_are_not_battle_damaged() -> void:
	assert_false(AbilityCard.is_battle_damaged(_ability()))
	assert_false(AbilityCard.is_battle_damaged(_ability({name = "Battle Damaged Again"})))


func test_battle_damaged_icon_is_the_same_whatever_the_category() -> void:
	for category in ["", "offensive", "rally", "made-up"]:
		assert_eq(AbilityCard.icon_name(_ability({name = "Battle Damaged", category = category})),
				AbilityCard.BATTLE_DAMAGED_ICON, category)


func test_the_battle_damaged_icon_loads() -> void:
	assert_not_null(UITheme.icon(AbilityCard.BATTLE_DAMAGED_ICON))


func test_battle_damaged_card_has_the_battle_damaged_icon() -> void:
	var card := _card({name = "Battle Damaged", timing = "Your Hero Phase", category = "offensive"})
	var icons := UIKit.find_all(card, func(n: Node) -> bool: return n is TextureRect)
	assert_same(icons[0].texture, UITheme.icon(AbilityCard.BATTLE_DAMAGED_ICON))


# header and values

func test_header_joins_frequency_and_timing() -> void:
	var header := AbilityCard.header(_ability({frequency = "Once Per Turn", timing = "Your Hero Phase"}))
	assert_true(header.begins_with("Once Per Turn"), header)
	assert_true(header.ends_with("Your Hero Phase"), header)


func test_header_without_frequency_is_the_timing() -> void:
	assert_eq(AbilityCard.header(_ability({timing = "Your Hero Phase"})), "Your Hero Phase")


func test_header_without_timing_is_the_frequency() -> void:
	assert_eq(AbilityCard.header(_ability({frequency = "Once Per Turn"})), "Once Per Turn")


func test_header_of_an_ability_with_neither_is_empty() -> void:
	assert_eq(AbilityCard.header(_ability()), "")


func test_values_of_a_plain_ability_are_empty() -> void:
	assert_eq(AbilityCard.values(_ability()).size(), 0)


func test_values_include_only_the_nonzero_ones() -> void:
	var values := AbilityCard.values(_ability({casting_value = 7, points = 20}))
	assert_eq(values.size(), 2)
	assert_true(values[0].contains("7"))
	assert_true(values[1].contains("20"))


func test_values_include_the_chanting_value() -> void:
	var values := AbilityCard.values(_ability({chanting_value = 4}))
	assert_eq(values.size(), 1)
	assert_true(values[0].contains("4"))


func test_values_include_the_command_points() -> void:
	var values := AbilityCard.values(_ability({command_points = 2}))
	assert_eq(values.size(), 1)
	assert_true(values[0].contains("2"))


func test_values_include_every_nonzero_value() -> void:
	var rule := _ability({casting_value = 7, chanting_value = 4, command_points = 2, points = 20})
	assert_eq(AbilityCard.values(rule).size(), 4)


# card

func test_card_shows_the_header_in_capitals() -> void:
	var card := _card({frequency = "Once Per Turn", timing = "Your Hero Phase"})
	var labels := _labels(card, "AbilityTimingLabel")
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].text, AbilityCard.header(card.ability).to_upper())


func test_card_shows_a_chip_for_each_value() -> void:
	var rule := _ability({casting_value = 7, points = 20})
	var card := AbilityCard.new(rule)
	add_child_autofree(card)
	var texts := Array(_label_texts(card)).map(func(text: String) -> String: return text.to_lower())
	for value in AbilityCard.values(rule):
		assert_true(value.to_lower() in texts, value)


func test_card_without_values_shows_no_chips() -> void:
	var card := _card({timing = "Your Hero Phase"})
	var plain := _label_texts(card)
	var valued := _label_texts(_card({timing = "Your Hero Phase", points = 20}))
	assert_eq(valued.size(), plain.size() + 1)


func test_card_shows_the_icon_for_its_category() -> void:
	var card := _card({category = "offensive"})
	var icons := UIKit.find_all(card, func(n: Node) -> bool: return n is TextureRect)
	assert_eq(icons.size(), 1)
	assert_same(icons[0].texture, UITheme.icon(AbilityCard.icon_name(card.ability)))


func test_card_shows_its_name() -> void:
	var card := _card({name = "Special Trick"})
	var names := _labels(card, "AbilityNameLabel")
	assert_eq(names.size(), 1)
	assert_eq(names[0].text, "Special Trick")


func test_name_comes_before_the_separator_before_the_body() -> void:
	var card := _card({effect = "Something happens."})
	var name_label: Node = _labels(card, "AbilityNameLabel")[0]
	var inner := name_label.get_parent()
	var separators := inner.get_children().filter(func(n: Node) -> bool: return n is HSeparator)
	var bodies := inner.get_children().filter(func(n: Node) -> bool: return n is RichTextLabel)
	assert_eq(separators.size(), 1)
	assert_eq(bodies.size(), 1)
	assert_lt(name_label.get_index(), separators[0].get_index())
	assert_lt(separators[0].get_index(), bodies[0].get_index())


func test_body_shows_the_rules_text() -> void:
	var card := _card({effect = "Something happens."})
	var bodies := UIKit.find_all(card, func(n: Node) -> bool: return n is RichTextLabel)
	assert_string_contains(bodies[0].text, "Something happens.")


func test_card_with_no_rules_text_has_no_body() -> void:
	var card := _card()
	assert_eq(UIKit.find_all(card, func(n: Node) -> bool: return n is RichTextLabel).size(), 0)


func test_card_shows_its_keywords() -> void:
	var card := _card({keywords = PackedStringArray(["FIRSTWORD", "SECONDWORD"])})
	var labels := _labels(card, "KeywordsLabel")
	assert_eq(labels.size(), 1)
	assert_string_contains(labels[0].text, "FIRSTWORD")
	assert_string_contains(labels[0].text, "SECONDWORD")


func test_card_without_keywords_has_no_keywords_label() -> void:
	assert_eq(_labels(_card(), "KeywordsLabel").size(), 0)


func test_card_shows_its_source() -> void:
	var labels := _labels(_card({source = "Made-up Book"}), "MutedLabel")
	assert_eq(labels.size(), 1)
	assert_string_contains(labels[0].text, "Made-up Book")


func test_card_without_a_source_has_no_source_label() -> void:
	assert_eq(_labels(_card(), "MutedLabel").size(), 0)


func test_cards_of_different_phases_have_different_backgrounds() -> void:
	assert_ne(_bg(_card({timing = "Your Hero Phase"})), _bg(_card({timing = "Any Combat Phase"})))


func test_cards_of_the_same_phase_have_the_same_background() -> void:
	assert_eq(_bg(_card({timing = "Your Hero Phase"})), _bg(_card({timing = "Your Hero Phase", name = "Other"})))


func test_card_is_coloured_by_its_phase() -> void:
	var card := _card({timing = "Your Hero Phase"})
	assert_eq(_bg(card), UITheme.ABILITY_COLOURS[AbilityCard.PHASE_COLOURS[AbilityCard.phase(card.ability)]][0])


# colour


func test_colour_prefers_the_data_colour() -> void:
	assert_eq(AbilityCard.colour(_ability({timing = "Your Hero Phase", colour = "red"})), "red")


func test_colour_falls_back_to_the_phase_colour_when_empty() -> void:
	var rule := _ability({timing = "Your Hero Phase"})
	assert_eq(AbilityCard.colour(rule), AbilityCard.PHASE_COLOURS["hero"])


func test_colour_falls_back_to_the_phase_colour_when_unknown() -> void:
	var rule := _ability({timing = "Any Combat Phase", colour = "chartreuse"})
	assert_eq(AbilityCard.colour(rule), AbilityCard.PHASE_COLOURS["combat"])


func test_every_phase_colour_is_a_known_ability_colour() -> void:
	for phase: String in AbilityCard.PHASE_COLOURS:
		assert_true(UITheme.ABILITY_COLOURS.has(AbilityCard.PHASE_COLOURS[phase]), phase)


func test_every_phase_has_a_phase_colour() -> void:
	for word: Array in AbilityCard.PHASE_WORDS:
		assert_true(AbilityCard.PHASE_COLOURS.has(word[1]), word[1])


func test_card_uses_the_data_colour_whatever_the_timing() -> void:
	for colour: String in ["black", "red"]:
		var card := _card({timing = "Passive", type = "passive", colour = colour})
		assert_eq(_bg(card), UITheme.ABILITY_COLOURS[colour][0], colour)


func test_card_with_a_data_colour_ignores_its_phase_colour() -> void:
	var with_data := _card({timing = "Your Hero Phase", colour = "purple"})
	var without := _card({timing = "Your Hero Phase"})
	assert_ne(_bg(with_data), _bg(without))


func test_accessibility_name_is_the_ability_name() -> void:
	assert_eq(_card({name = "Special Trick"}).accessibility_name, "Special Trick")


func test_accessibility_description_is_the_header() -> void:
	var card := _card({frequency = "Once Per Turn", timing = "Your Hero Phase"})
	assert_eq(card.accessibility_description, AbilityCard.header(card.ability))


# --- Folding ---


func _foldable(open: bool, fields := {}) -> AbilityCard:
	var card := _card(fields)
	card.make_foldable(open)
	return card


func _body_fields() -> Dictionary:
	return {effect = "Do a thing.", keywords = PackedStringArray(["WIZARD"]), source = "Somewhere"}


func _all_details(card: AbilityCard, shown: bool) -> bool:
	return card._details.all(func(control: Control) -> bool: return control.visible == shown)


func test_card_is_not_foldable_by_default() -> void:
	assert_null(_card().fold_button)


func test_card_is_not_folded_by_default() -> void:
	assert_false(_card().folded)


func test_foldable_card_has_a_fold_button() -> void:
	assert_not_null(_foldable(true).fold_button)


func test_foldable_card_opened_starts_unfolded() -> void:
	assert_false(_foldable(true).folded)


func test_foldable_card_not_opened_starts_folded() -> void:
	assert_true(_foldable(false).folded)


func test_card_with_a_body_has_details_to_fold() -> void:
	assert_gt(_card(_body_fields())._details.size(), 1)


func test_folded_card_hides_everything_below_the_name() -> void:
	assert_true(_all_details(_foldable(false, _body_fields()), false))


func test_unfolded_card_shows_everything_below_the_name() -> void:
	assert_true(_all_details(_foldable(true, _body_fields()), true))


func test_folded_card_still_shows_the_name() -> void:
	assert_true(_foldable(false)._name_label.visible)


func test_fold_button_folds_an_open_card() -> void:
	var card := _foldable(true)
	card.fold_button.pressed.emit()
	assert_true(card.folded)


func test_fold_button_unfolds_a_folded_card() -> void:
	var card := _foldable(false)
	card.fold_button.pressed.emit()
	assert_false(card.folded)


func test_fold_button_shows_the_details_again_when_unfolding() -> void:
	var card := _foldable(false, _body_fields())
	card.fold_button.pressed.emit()
	assert_true(_all_details(card, true))


func test_set_folded_works_without_a_fold_button() -> void:
	var card := _card(_body_fields())
	card.set_folded(true)
	assert_true(_all_details(card, false))


func test_open_fold_button_describes_itself_as_expanded() -> void:
	assert_eq(_foldable(true).fold_button.accessibility_description, "Expanded")


func test_folded_fold_button_describes_itself_as_collapsed() -> void:
	assert_eq(_foldable(false).fold_button.accessibility_description, "Collapsed")


func test_fold_button_description_follows_the_fold() -> void:
	var card := _foldable(true)
	card.fold_button.pressed.emit()
	assert_eq(card.fold_button.accessibility_description, "Collapsed")


func test_fold_button_label_names_the_ability() -> void:
	var card := _foldable(true, {name = "Special Trick"})
	assert_true(card.fold_button.accessibility_name.contains("Special Trick"))


func test_fold_button_label_changes_with_the_fold() -> void:
	var card := _foldable(true)
	var open_label := card.fold_button.accessibility_name
	card.fold_button.pressed.emit()
	assert_ne(card.fold_button.accessibility_name, open_label)


func test_fold_button_icon_changes_with_the_fold() -> void:
	var card := _foldable(true)
	var open_icon := card.fold_button.icon
	card.fold_button.pressed.emit()
	assert_ne(card.fold_button.icon, open_icon)


# add_header_control

func test_add_header_control_appends_at_the_end_of_the_header() -> void:
	var card := _card()
	var control := Control.new()
	card.add_header_control(control)
	assert_eq(card._header.get_child(-1), control)


func test_add_header_control_centres_the_control_vertically() -> void:
	var card := _card()
	var control := Control.new()
	card.add_header_control(control)
	assert_eq(control.size_flags_vertical, Control.SIZE_SHRINK_CENTER)
