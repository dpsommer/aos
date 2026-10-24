extends GutTest
## Unit tests for the army builder screen (scripts/ui/forge/forge.gd).

const ForgeScene := preload("res://scenes/ui/forge/forge.tscn")


## Screens and faction buttons are removed with queue_free, so let a frame pass for
## them to be freed before GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame


## Returns a fresh forge instance added to the tree with its signals watched.
func _make_forge() -> Forge:
	var forge: Forge = ForgeScene.instantiate()
	add_child_autofree(forge)
	watch_signals(forge)
	return forge


## Returns two distinct alliances, so tests can switch between them.
func _two_alliances() -> Array:
	var all := GrandAlliance.Type.values()
	return [all[0], all[1]]


func _faction_button_texts(forge: Forge) -> PackedStringArray:
	var texts := PackedStringArray()
	for child in forge.faction_grid.get_children():
		texts.append((child as Button).text)
	return texts


func _press_cancel(forge: Forge) -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	forge._unhandled_input(event)


func test_starts_showing_alliance_panel() -> void:
	var forge := _make_forge()
	assert_true(forge.alliance_panel.visible)


func test_starts_with_faction_panel_hidden() -> void:
	var forge := _make_forge()
	assert_false(forge.faction_panel.visible)


func test_has_a_button_for_every_alliance() -> void:
	var forge := _make_forge()
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		assert_true(forge.alliance_buttons.has(alliance),
				"no button for %s" % GrandAlliance.display_name(alliance))


func test_pressing_alliance_button_shows_faction_panel() -> void:
	var forge := _make_forge()
	forge.alliance_buttons[_two_alliances()[0]].pressed.emit()
	assert_true(forge.faction_panel.visible)


func test_pressing_alliance_button_hides_alliance_panel() -> void:
	var forge := _make_forge()
	forge.alliance_buttons[_two_alliances()[0]].pressed.emit()
	assert_false(forge.alliance_panel.visible)


func test_each_alliance_button_lists_that_alliances_factions() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.alliance_buttons[alliance].pressed.emit()
		assert_eq(_faction_button_texts(forge), FactionCatalog.factions_for(alliance))


func test_faction_title_is_alliance_display_name() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.alliance_buttons[alliance].pressed.emit()
		assert_eq(forge.faction_title.text, GrandAlliance.display_name(alliance))


func test_choosing_second_alliance_leaves_no_buttons_from_first() -> void:
	var forge := _make_forge()
	var alliances := _two_alliances()
	forge.show_factions(alliances[0])
	forge.show_alliances()
	forge.show_factions(alliances[1])
	assert_eq(_faction_button_texts(forge), FactionCatalog.factions_for(alliances[1]))


func test_showing_same_alliance_twice_does_not_duplicate_buttons() -> void:
	var forge := _make_forge()
	var alliance: GrandAlliance.Type = _two_alliances()[0]
	forge.show_factions(alliance)
	forge.show_factions(alliance)
	assert_eq(forge.faction_grid.get_child_count(), FactionCatalog.factions_for(alliance).size())


func test_first_faction_button_has_focus_after_choosing_alliance() -> void:
	var forge := _make_forge()
	forge.show_factions(_two_alliances()[0])
	assert_true((forge.faction_grid.get_child(0) as Button).has_focus())


func test_pressing_faction_button_emits_faction_selected_with_alliance_and_name() -> void:
	var forge := _make_forge()
	var alliance: GrandAlliance.Type = _two_alliances()[1]
	forge.show_factions(alliance)
	var last := forge.faction_grid.get_child_count() - 1
	var button := forge.faction_grid.get_child(last) as Button
	button.pressed.emit()
	assert_signal_emitted_with_parameters(forge, "faction_selected",
			[alliance, FactionCatalog.factions_for(alliance)[last]])


func test_faction_back_button_shows_alliance_panel() -> void:
	var forge := _make_forge()
	forge.show_factions(_two_alliances()[0])
	forge.faction_back_button.pressed.emit()
	assert_true(forge.alliance_panel.visible)


func test_faction_back_button_hides_faction_panel() -> void:
	var forge := _make_forge()
	forge.show_factions(_two_alliances()[0])
	forge.faction_back_button.pressed.emit()
	assert_false(forge.faction_panel.visible)


func test_faction_back_button_does_not_emit_back_pressed() -> void:
	var forge := _make_forge()
	forge.show_factions(_two_alliances()[0])
	forge.faction_back_button.pressed.emit()
	assert_signal_not_emitted(forge, "back_pressed")


func test_faction_back_button_refocuses_chosen_alliance() -> void:
	var forge := _make_forge()
	var alliance: GrandAlliance.Type = _two_alliances()[1]
	forge.show_factions(alliance)
	forge.faction_back_button.pressed.emit()
	assert_true(forge.alliance_buttons[alliance].has_focus())


func test_alliance_back_button_emits_back_pressed() -> void:
	var forge := _make_forge()
	forge.alliance_back_button.pressed.emit()
	assert_signal_emitted(forge, "back_pressed")


func test_cancel_on_alliance_panel_emits_back_pressed() -> void:
	var forge := _make_forge()
	_press_cancel(forge)
	assert_signal_emitted(forge, "back_pressed")


func test_cancel_on_faction_panel_shows_alliance_panel() -> void:
	var forge := _make_forge()
	forge.show_factions(_two_alliances()[0])
	_press_cancel(forge)
	assert_true(forge.alliance_panel.visible)


func test_cancel_on_faction_panel_does_not_emit_back_pressed() -> void:
	var forge := _make_forge()
	forge.show_factions(_two_alliances()[0])
	_press_cancel(forge)
	assert_signal_not_emitted(forge, "back_pressed")


func test_released_cancel_does_nothing() -> void:
	var forge := _make_forge()
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = false
	forge._unhandled_input(event)
	assert_signal_not_emitted(forge, "back_pressed")
