extends GutTest
## Unit tests for the Spearhead regiment ability and enhancement picker
## (scripts/ui/battle/spearhead_options_picker.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func _army() -> BattleArmy:
	return BattleKit.spearhead_army(BattleKit.spearhead_with_options())


func _picker(attacks := true, opponent: BattleArmy = null) -> SpearheadOptionsPicker:
	var picker := SpearheadOptionsPicker.new(_army(), opponent, attacks)
	add_child_autofree(picker)
	return picker


## An opponent that has already chosen.
func _chosen_opponent() -> BattleArmy:
	var opponent := _army()
	opponent.choose_spearhead_options("Ambush", "Crown")
	return opponent


func _press_confirm(picker: SpearheadOptionsPicker) -> void:
	picker.confirm_button.pressed.emit()


# Cards

func test_there_is_a_card_per_regiment_ability() -> void:
	assert_eq(_picker().cards.regiment.size(), 2)


func test_there_is_a_card_per_enhancement() -> void:
	assert_eq(_picker().cards.enhancement.size(), 2)


func test_the_cards_hold_the_spearheads_abilities() -> void:
	var picker := _picker()
	var names: Array = picker.cards.regiment.map(func(card: AbilityChoiceCard) -> String: return card.ability.name)
	assert_eq(names, ["Charge", "Ambush"])


func test_the_enhancement_column_names_the_general() -> void:
	assert_true(UIKit.has_label_containing(_picker(), "GENERAL"))


func test_nothing_is_picked_to_begin_with() -> void:
	assert_eq(_picker().selection(), ["", ""])


func test_no_card_looks_picked_to_begin_with() -> void:
	var picker := _picker()
	for group: String in picker.cards:
		for card: AbilityChoiceCard in picker.cards[group]:
			assert_false(card.selected, card.ability.name)


# Picking

func test_picking_a_regiment_ability_selects_it() -> void:
	var picker := _picker()
	picker.pick("regiment", "Ambush")
	assert_eq(picker.selection(), ["Ambush", ""])


func test_picking_an_enhancement_selects_it() -> void:
	var picker := _picker()
	picker.pick("enhancement", "Crown")
	assert_eq(picker.selection(), ["", "Crown"])


func test_picking_marks_only_that_card() -> void:
	var picker := _picker()
	picker.pick("regiment", "Ambush")
	assert_false(picker.cards.regiment[0].selected)
	assert_true(picker.cards.regiment[1].selected)
	assert_false(picker.cards.enhancement[1].selected)


func test_picking_another_replaces_the_pick() -> void:
	var picker := _picker()
	picker.pick("regiment", "Charge")
	picker.pick("regiment", "Ambush")
	assert_eq(picker.selection()[0], "Ambush")
	assert_false(picker.cards.regiment[0].selected)


func test_pressing_a_card_picks_it() -> void:
	var picker := _picker()
	picker.cards.enhancement[1].pressed.emit()
	assert_eq(picker.selection()[1], "Crown")


# Confirm

func test_confirm_is_disabled_to_begin_with() -> void:
	assert_true(_picker().confirm_button.disabled)


func test_confirm_is_disabled_with_only_a_regiment_ability() -> void:
	var picker := _picker()
	picker.pick("regiment", "Charge")
	assert_true(picker.confirm_button.disabled)


func test_confirm_is_disabled_with_only_an_enhancement() -> void:
	var picker := _picker()
	picker.pick("enhancement", "Banner")
	assert_true(picker.confirm_button.disabled)


func test_confirm_is_enabled_with_both() -> void:
	var picker := _picker()
	picker.pick("regiment", "Charge")
	picker.pick("enhancement", "Banner")
	assert_false(picker.confirm_button.disabled)


func test_confirm_asks_for_what_is_missing() -> void:
	var picker := _picker()
	assert_string_contains(picker.confirm_button.text, "regiment ability")
	assert_string_contains(picker.confirm_button.text, "enhancement")
	picker.pick("regiment", "Charge")
	assert_false(picker.confirm_button.text.contains("regiment ability"))
	assert_string_contains(picker.confirm_button.text, "enhancement")


func test_confirm_asks_for_a_regiment_ability_alone() -> void:
	var picker := _picker()
	picker.pick("enhancement", "Banner")
	assert_string_contains(picker.confirm_button.text, "regiment ability")
	assert_false(picker.confirm_button.text.contains("enhancement"))


func test_confirm_emits_the_picks() -> void:
	var picker := _picker()
	picker.pick("regiment", "Ambush")
	picker.pick("enhancement", "Crown")
	watch_signals(picker)
	_press_confirm(picker)
	assert_signal_emitted_with_parameters(picker, "chosen", ["Ambush", "Crown"])


func test_confirm_emits_nothing_while_picks_are_missing() -> void:
	var picker := _picker()
	picker.pick("regiment", "Ambush")
	watch_signals(picker)
	_press_confirm(picker)
	assert_signal_not_emitted(picker, "chosen")


func test_repicking_before_confirming_emits_the_latest_picks() -> void:
	var picker := _picker()
	picker.pick("regiment", "Charge")
	picker.pick("enhancement", "Banner")
	picker.pick("regiment", "Ambush")
	watch_signals(picker)
	_press_confirm(picker)
	assert_signal_emitted_with_parameters(picker, "chosen", ["Ambush", "Banner"])


# A Spearhead with an empty list

func test_an_empty_enhancement_list_is_not_required() -> void:
	var spearhead := BattleKit.spearhead_with_options()
	spearhead.enhancements = [] as Array[Ability]
	var picker := SpearheadOptionsPicker.new(BattleKit.spearhead_army(spearhead), null, true)
	add_child_autofree(picker)
	picker.pick("regiment", "Charge")
	assert_false(picker.confirm_button.disabled)


func test_an_empty_regiment_list_is_not_required() -> void:
	var spearhead := BattleKit.spearhead_with_options()
	spearhead.regiment_abilities = [] as Array[Ability]
	var picker := SpearheadOptionsPicker.new(BattleKit.spearhead_army(spearhead), null, true)
	add_child_autofree(picker)
	picker.pick("enhancement", "Banner")
	assert_false(picker.confirm_button.disabled)


# Subtitle

func test_the_attacker_is_told_it_picks_first() -> void:
	assert_true(UIKit.has_label_containing(_picker(true), "attacker"))


func test_the_defender_is_told_it_picks_second() -> void:
	assert_true(UIKit.has_label_containing(_picker(false), "defender"))


func test_the_defender_sees_the_opponents_picks() -> void:
	var picker := _picker(false, _chosen_opponent())
	assert_true(UIKit.has_label_containing(picker, "Ambush"))
	assert_true(UIKit.has_label_containing(picker, "Crown"))


func test_the_defender_sees_no_picks_if_the_opponent_has_not_chosen() -> void:
	var picker := _picker(false, _army())
	assert_false(UIKit.has_label_containing(picker, "Your opponent picked"))


func test_the_attacker_is_not_shown_the_opponents_picks() -> void:
	var picker := _picker(true, _chosen_opponent())
	assert_false(UIKit.has_label_containing(picker, "Your opponent picked"))
