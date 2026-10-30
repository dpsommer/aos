extends GutTest
## Unit tests for the battle tactics card widget (scripts/ui/cards/tactic_card.gd).

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
	var node := TacticCard.new(_card(), TacticCard.Form.FULL if full else TacticCard.Form.SUMMARY, heading, action)
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


func test_action_can_be_any_control() -> void:
	var chip := Label.new()
	chip.text = "Battle tactic 1"
	var node := TacticCard.new(_card(), TacticCard.Form.SUMMARY, "", chip)
	add_child_autofree(node)
	assert_true(node.is_ancestor_of(chip))


## The row holding the card's name.
func _title_row(node: TacticCard) -> Node:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is Label and n.text == "Hold the Line")[0].get_parent()


## The label showing [param text] on [param node].
func _label(node: TacticCard, text: String) -> Label:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is Label and n.text == text)[0]


func test_without_a_heading_the_action_ends_the_names_row() -> void:
	var action := Button.new()
	var node := _make(false, "", action)
	var row := _title_row(node)
	assert_eq(action.get_parent(), row)
	assert_eq(action.get_index(), row.get_child_count() - 1)


func test_without_a_heading_the_action_is_vertically_centred() -> void:
	var action := Button.new()
	_make(false, "", action)
	assert_eq(action.size_flags_vertical, Control.SIZE_SHRINK_CENTER)


func test_with_a_heading_the_action_shares_the_headings_row() -> void:
	var action := Button.new()
	var node := _make(false, "Slot 1", action)
	assert_eq(action.get_parent(), _label(node, "Slot 1").get_parent())
	assert_ne(action.get_parent(), _title_row(node))


func test_with_a_heading_the_action_ends_the_headings_row() -> void:
	var action := Button.new()
	var node := _make(false, "Slot 1", action)
	var row := action.get_parent()
	assert_eq(action.get_index(), row.get_child_count() - 1)


# --- Pressing and focus ---

func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _accept() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	return event


func _pressable() -> TacticCard:
	var node := _make(true)
	node.make_pressable("Choose it")
	return node


func test_card_is_not_pressable_by_default() -> void:
	var node := _make(true)
	watch_signals(node)
	node._gui_input(_click())
	assert_signal_not_emitted(node, "pressed")
	assert_eq(node.focus_mode, Control.FOCUS_NONE)


func test_pressable_card_is_focusable_with_a_tooltip() -> void:
	var node := _pressable()
	assert_eq(node.focus_mode, Control.FOCUS_ALL)
	assert_eq(node.tooltip_text, "Choose it")
	assert_eq(node.accessibility_name, "Hold the Line")


func test_clicking_a_pressable_card_emits_pressed() -> void:
	var node := _pressable()
	watch_signals(node)
	node._gui_input(_click())
	assert_signal_emit_count(node, "pressed", 1)


func test_accept_on_a_pressable_card_emits_pressed() -> void:
	var node := _pressable()
	watch_signals(node)
	node._gui_input(_accept())
	assert_signal_emit_count(node, "pressed", 1)


func test_other_keys_on_a_pressable_card_do_nothing() -> void:
	var node := _pressable()
	watch_signals(node)
	var event := InputEventKey.new()
	event.keycode = KEY_A
	event.pressed = true
	node._gui_input(event)
	assert_signal_not_emitted(node, "pressed")


func test_clicks_on_a_pressable_cards_content_reach_the_card() -> void:
	var node := _pressable()
	for found in UIKit.find_all(node, func(n: Node) -> bool: return n is Control):
		assert_eq((found as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, found.name)


func test_card_shows_focus_only_while_focused() -> void:
	var node := _pressable()
	assert_false(node.shows_focus())
	node.grab_focus()
	assert_true(node.shows_focus())


func _faq_card() -> BattleTacticCard:
	var card := _card()
	card.faqs.append({"question": "Can I [b]do it[/b]?", "answer": "Yes."})
	return card


func _rich_texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for found in UIKit.find_all(node, func(n: Node) -> bool: return n is RichTextLabel):
		result.append((found as RichTextLabel).text)
	return result


func test_full_card_shows_its_faqs() -> void:
	var node := TacticCard.new(_faq_card(), TacticCard.Form.FULL)
	add_child_autofree(node)
	var texts := _rich_texts(node)
	assert_eq(texts.size(), 1)
	assert_string_contains(texts[0], "Yes.")
	assert_string_contains(texts[0], "Can I")


func test_faq_text_cannot_inject_bbcode() -> void:
	var node := TacticCard.new(_faq_card(), TacticCard.Form.FULL)
	add_child_autofree(node)
	assert_false(_rich_texts(node)[0].contains("[b]do it"))


func test_short_card_hides_faqs() -> void:
	var node := TacticCard.new(_faq_card(), TacticCard.Form.SUMMARY)
	add_child_autofree(node)
	assert_eq(_rich_texts(node).size(), 0)


func test_card_without_faqs_has_no_rich_text() -> void:
	assert_eq(_rich_texts(_make(true)).size(), 0)


# --- Brief form ---

func _brief(action: Button = null) -> TacticCard:
	var node := TacticCard.new(_card(), TacticCard.Form.BRIEF, "", action)
	add_child_autofree(node)
	return node


func _separators(node: Node) -> Array[Node]:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is HSeparator)


func test_brief_card_shows_each_tactics_name_kind_and_victory_points() -> void:
	var node := _brief()
	for tactic in _card().tactics:
		assert_true(UIKit.has_label_containing(node, tactic.name), tactic.name)
		assert_true(UIKit.has_label_containing(node, TacticCard.KIND_NAMES[tactic.kind].to_upper()), tactic.kind)
	assert_eq(Array(UIKit.label_texts(node)).filter(func(t: String) -> bool: return t.contains("VP")).size(), _card().tactics.size())


func test_brief_card_hides_conditions_text_and_faqs() -> void:
	var node := TacticCard.new(_faq_card(), TacticCard.Form.BRIEF)
	add_child_autofree(node)
	assert_false(UIKit.has_label_containing(node, "Complete the"))
	assert_false(UIKit.has_label_containing(node, "Pick a hideout."))
	assert_eq(_rich_texts(node).size(), 0)


func test_brief_card_shows_the_card_name_and_action() -> void:
	var action := Button.new()
	var node := _brief(action)
	assert_true(UIKit.has_label_containing(node, "Hold the Line"))
	assert_true(node.is_ancestor_of(action))


func test_brief_and_short_cards_have_no_separators() -> void:
	assert_eq(_separators(_brief()).size(), 0)
	assert_eq(_separators(_make(false)).size(), 0)


# --- Separators in the full form ---

func test_full_card_has_a_separator_before_the_text_and_each_tactic() -> void:
	var node := _make(true)
	assert_eq(_separators(node).size(), 1 + _card().tactics.size())


func test_full_card_without_text_has_a_separator_per_tactic_only() -> void:
	var card := _card()
	card.text = ""
	var node := TacticCard.new(card, TacticCard.Form.FULL)
	add_child_autofree(node)
	assert_eq(_separators(node).size(), card.tactics.size())


func test_full_card_with_faqs_has_one_more_separator_not_one_per_faq() -> void:
	var card := _faq_card()
	card.faqs.append({"question": "Second?", "answer": "No."})
	var node := TacticCard.new(card, TacticCard.Form.FULL)
	add_child_autofree(node)
	assert_eq(_separators(node).size(), 2 + card.tactics.size())


func test_full_cards_first_separator_comes_before_the_text() -> void:
	var node := _make(true)
	var text_label := UIKit.find_all(node, func(n: Node) -> bool: return n is Label and n.text == "Pick a hideout.")[0]
	assert_true(text_label.get_parent().get_child(text_label.get_index() - 1) is HSeparator)


func test_full_cards_faq_follows_a_separator() -> void:
	var node := TacticCard.new(_faq_card(), TacticCard.Form.FULL)
	add_child_autofree(node)
	var rich := UIKit.find_all(node, func(n: Node) -> bool: return n is RichTextLabel)[0]
	assert_true(rich.get_parent().get_child(rich.get_index() - 1) is HSeparator)


# --- Buttons on pressable cards ---

func test_a_button_on_a_pressable_card_keeps_its_own_clicks() -> void:
	var action := Button.new()
	var node := TacticCard.new(_card(), TacticCard.Form.BRIEF, "", action)
	add_child_autofree(node)
	node.make_pressable("Choose it")
	assert_ne(action.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_a_pressable_card_still_ignores_mouse_on_non_button_content_beside_a_button() -> void:
	var node := TacticCard.new(_card(), TacticCard.Form.BRIEF, "", Button.new())
	add_child_autofree(node)
	node.make_pressable("Choose it")
	for label in UIKit.find_all(node, func(n: Node) -> bool: return n is Label):
		assert_eq((label as Label).mouse_filter, Control.MOUSE_FILTER_IGNORE)
