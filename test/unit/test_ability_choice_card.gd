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


func test_chevron_unfolds_the_card() -> void:
	var card := _card()
	card.fold_button.pressed.emit()
	assert_false(card.folded)


func test_chevron_folds_the_card_again() -> void:
	var card := _card(true)
	card.fold_button.pressed.emit()
	assert_true(card.folded)


func test_chevron_emits_fold_toggled_open() -> void:
	var card := _card()
	watch_signals(card)
	card.fold_button.pressed.emit()
	assert_signal_emitted_with_parameters(card, "fold_toggled", [true])


func test_chevron_emits_fold_toggled_closed() -> void:
	var card := _card(true)
	watch_signals(card)
	card.fold_button.pressed.emit()
	assert_signal_emitted_with_parameters(card, "fold_toggled", [false])


func test_chevron_does_not_emit_pressed() -> void:
	var card := _card()
	watch_signals(card)
	card.fold_button.pressed.emit()
	assert_signal_not_emitted(card, "pressed")


func test_chevron_tooltip_names_the_ability() -> void:
	assert_true(_card().fold_button.tooltip_text.contains("Made-up Ability"))


func test_chevron_takes_the_focus_key() -> void:
	var rule := Ability.new()
	rule.name = "Made-up Ability"
	var card := AbilityChoiceCard.new(rule, false, "slot:fold")
	add_child_autofree(card)
	assert_eq(card.fold_button.get_meta(&"focus_key", ""), "slot:fold")


func test_chevron_can_take_focus() -> void:
	assert_eq(_card().fold_button.focus_mode, Control.FOCUS_ALL)


# A drop target (BuilderDragDrop.pass_mouse) lets clicks on the chevron reach the card too.
func test_click_on_the_chevron_does_not_emit_pressed() -> void:
	var card := _card()
	BuilderDragDrop.pass_mouse(card)
	await get_tree().process_frame
	watch_signals(card)
	var click := _click()
	click.position = card.get_global_transform().affine_inverse() * card.fold_button.get_global_rect().get_center()
	card._gui_input(click)
	assert_signal_not_emitted(card, "pressed")


func test_click_beside_the_chevron_emits_pressed() -> void:
	var card := _card()
	BuilderDragDrop.pass_mouse(card)
	await get_tree().process_frame
	watch_signals(card)
	var click := _click()
	click.position = Vector2(4, 4)
	card._gui_input(click)
	assert_signal_emitted(card, "pressed")


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
	await get_tree().process_frame
	watch_signals(card)
	var click := _click()
	click.position = Vector2(4, 4)
	card._gui_input(click)
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


func test_add_header_control_keeps_the_check_last() -> void:
	var card := _card()
	card.add_header_control(Control.new())
	assert_eq(card._header.get_child(-1), card._check)


func test_added_controls_keep_their_order() -> void:
	var card := _card()
	var first := Control.new()
	var second := Control.new()
	card.add_header_control(first)
	card.add_header_control(second)
	assert_lt(first.get_index(), second.get_index())
