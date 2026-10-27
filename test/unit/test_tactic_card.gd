extends GutTest
## Unit tests for the battle tactics card widget (scripts/ui/forge/builder/tactic_card.gd).

const UIKit := preload("res://test/support/ui_kit.gd")


func after_each() -> void:
	await get_tree().process_frame


func _card() -> BattleTacticCard:
	var card := BattleTacticCard.new()
	card.name = "Hold the Line"
	card.text = "Pick a hideout."
	for kind in BattleTactic.KINDS:
		var tactic := BattleTactic.new()
		tactic.name = "%s tactic" % kind
		tactic.kind = kind
		tactic.condition = "Complete the %s." % kind
		tactic.victory_points = 4
		card.tactics.append(tactic)
	return card


func _make(full: bool, heading := "", action: Button = null) -> TacticCard:
	var node := TacticCard.new(_card(), full, heading, action)
	add_child_autofree(node)
	return node


func test_full_card_shows_each_tactics_condition() -> void:
	var node := _make(true)
	for tactic in _card().tactics:
		assert_true(UIKit.has_label_containing(node, tactic.condition), tactic.condition)


func test_full_card_shows_victory_points() -> void:
	var node := _make(true)
	assert_true(UIKit.has_label_containing(node, "4 VP"))


func test_full_card_shows_the_cards_text() -> void:
	assert_true(UIKit.has_label_containing(_make(true), "Pick a hideout."))


func test_short_card_hides_conditions_and_victory_points() -> void:
	var node := _make(false)
	assert_false(UIKit.has_label_containing(node, "Complete the"))
	assert_false(UIKit.has_label_containing(node, "VP"))
	assert_false(UIKit.has_label_containing(node, "Pick a hideout."))


func test_short_card_names_each_tactic() -> void:
	var node := _make(false)
	for tactic in _card().tactics:
		assert_true(UIKit.has_label_containing(node, tactic.name.to_upper()), tactic.name)


func test_both_forms_show_the_card_name() -> void:
	assert_true(UIKit.has_label_containing(_make(true), "Hold the Line"))
	assert_true(UIKit.has_label_containing(_make(false), "Hold the Line"))


func test_heading_is_shown_when_given() -> void:
	assert_true(UIKit.has_label_containing(_make(false, "Battle tactics card 1"), "Battle tactics card 1"))


func test_action_button_is_added_to_the_card() -> void:
	var action := Button.new()
	action.text = "Change"
	var node := _make(false, "", action)
	assert_true(node.is_ancestor_of(action))
