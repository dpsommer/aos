extends GutTest
## Unit tests for the choosable ability card (scripts/ui/cards/ability_choice_card.gd).


func _card(open := false) -> AbilityChoiceCard:
	var rule := Ability.new()
	rule.name = "Made-up Ability"
	rule.timing = "Your Hero Phase"
	var card := AbilityChoiceCard.new(rule, open)
	add_child_autofree(card)
	return card


func _click(button := MOUSE_BUTTON_LEFT, down := true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	return event


func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


# fold

func test_starts_folded_by_default() -> void:
	assert_true(_card().folded)


func test_starts_unfolded_when_open() -> void:
	assert_false(_card(true).folded)


func test_eye_starts_pressed_when_open() -> void:
	assert_true(_card(true).eye.button_pressed)


func test_eye_unfolds_the_card() -> void:
	var card := _card()
	card.eye.button_pressed = true
	assert_false(card.folded)


func test_eye_folds_the_card_again() -> void:
	var card := _card(true)
	card.eye.button_pressed = false
	assert_true(card.folded)


func test_eye_emits_eye_toggled_open() -> void:
	var card := _card()
	watch_signals(card)
	card.eye.button_pressed = true
	assert_signal_emitted_with_parameters(card, "eye_toggled", [true])


func test_eye_emits_eye_toggled_closed() -> void:
	var card := _card(true)
	watch_signals(card)
	card.eye.button_pressed = false
	assert_signal_emitted_with_parameters(card, "eye_toggled", [false])


func test_eye_tooltip_offers_show_when_folded() -> void:
	assert_true(_card().eye.tooltip_text.begins_with("Show"))


func test_eye_tooltip_offers_hide_when_unfolded() -> void:
	assert_true(_card(true).eye.tooltip_text.begins_with("Hide"))


func test_eye_tooltip_changes_when_toggled() -> void:
	var card := _card()
	var before := card.eye.tooltip_text
	card.eye.button_pressed = true
	assert_ne(card.eye.tooltip_text, before)


func test_eye_tooltip_names_the_ability() -> void:
	assert_true(_card().eye.tooltip_text.contains("Made-up Ability"))


# selected

func test_starts_unselected() -> void:
	assert_false(_card().selected)


func test_check_is_hidden_when_unselected() -> void:
	assert_eq(_card()._check.modulate.a, 0.0)


func test_check_shows_when_selected() -> void:
	var card := _card()
	card.selected = true
	assert_eq(card._check.modulate.a, 1.0)


func test_check_hides_when_deselected() -> void:
	var card := _card()
	card.selected = true
	card.selected = false
	assert_eq(card._check.modulate.a, 0.0)


func test_tooltip_offers_choose_when_unselected() -> void:
	assert_true(_card().tooltip_text.begins_with("Choose"))


func test_tooltip_offers_unchoose_when_selected() -> void:
	var card := _card()
	card.selected = true
	assert_true(card.tooltip_text.begins_with("Unchoose"))


func test_tooltip_names_the_ability() -> void:
	assert_true(_card().tooltip_text.contains("Made-up Ability"))


func test_description_begins_with_chosen_when_selected() -> void:
	var card := _card()
	card.selected = true
	assert_true(card.accessibility_description.begins_with("Chosen"))


func test_description_does_not_say_chosen_when_unselected() -> void:
	assert_false(_card().accessibility_description.begins_with("Chosen"))


func test_description_drops_chosen_when_deselected() -> void:
	var card := _card()
	card.selected = true
	card.selected = false
	assert_false(card.accessibility_description.begins_with("Chosen"))


func test_description_keeps_the_timing_when_selected() -> void:
	var card := _card()
	card.selected = true
	assert_true(card.accessibility_description.contains("Your Hero Phase"))


# pressed

func test_left_click_emits_pressed() -> void:
	var card := _card()
	watch_signals(card)
	card._gui_input(_click())
	assert_signal_emitted(card, "pressed")


func test_right_click_does_not_emit_pressed() -> void:
	var card := _card()
	watch_signals(card)
	card._gui_input(_click(MOUSE_BUTTON_RIGHT))
	assert_signal_not_emitted(card, "pressed")


func test_click_release_does_not_emit_pressed() -> void:
	var card := _card()
	watch_signals(card)
	card._gui_input(_click(MOUSE_BUTTON_LEFT, false))
	assert_signal_not_emitted(card, "pressed")


func test_ui_accept_emits_pressed() -> void:
	var card := _card()
	watch_signals(card)
	card._gui_input(_action("ui_accept"))
	assert_signal_emitted(card, "pressed")


func test_other_action_does_not_emit_pressed() -> void:
	var card := _card()
	watch_signals(card)
	card._gui_input(_action("ui_cancel"))
	assert_signal_not_emitted(card, "pressed")


func test_card_is_focusable() -> void:
	assert_ne(_card().focus_mode, Control.FOCUS_NONE)


func test_clicking_does_not_change_selected() -> void:
	var card := _card()
	card._gui_input(_click())
	assert_false(card.selected)


# header controls

func test_add_header_control_goes_before_the_check() -> void:
	var card := _card()
	var chip := Control.new()
	card.add_header_control(chip)
	assert_lt(chip.get_index(), card._check.get_index())


func test_add_header_control_keeps_the_eye_last() -> void:
	var card := _card()
	card.add_header_control(Control.new())
	assert_eq(card._header.get_child(-1), card.eye)


func test_add_header_control_keeps_the_check_before_the_eye() -> void:
	var card := _card()
	card.add_header_control(Control.new())
	assert_lt(card._check.get_index(), card.eye.get_index())


func test_added_controls_keep_their_order() -> void:
	var card := _card()
	var first := Control.new()
	var second := Control.new()
	card.add_header_control(first)
	card.add_header_control(second)
	assert_lt(first.get_index(), second.get_index())
