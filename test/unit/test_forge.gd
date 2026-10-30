extends GutTest
## Unit tests for the Forge screen (scripts/ui/forge/forge.gd).

const ForgeScene := preload("res://scenes/ui/forge/forge.tscn")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")
const Kit := preload("res://test/support/army_kit.gd")
const FactionFixture := preload("res://test/support/faction_fixture.gd")


## Screens and faction buttons are removed with queue_free, so let a frame pass for
## them to be freed before GUT counts orphans.
func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	await get_tree().process_frame
	Sandbox.end()
	FactionFixture.end()


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


func _faction_button_names(forge: Forge) -> PackedStringArray:
	var texts := PackedStringArray()
	for child in forge.faction_grid.get_children():
		texts.append(child.get_meta(&"faction"))
	return texts


## Returns the first alliance with a faction that has data. Fails the test if there is none.
func _alliance_with_available_faction() -> GrandAlliance.Type:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction in FactionCatalog.factions_for(alliance):
			if FactionCatalog.is_available(faction):
				return alliance
	fail_test("no faction is available")
	return GrandAlliance.Type.values()[0]


## Shows the Order factions with the fixture faction, which has no data, listed among them, and
## returns the fixture faction's card.
func _fixture_faction_card() -> Button:
	FactionFixture.list_beside(GrandAlliance.Type.ORDER)
	var forge := _make_forge()
	forge.show_factions(GrandAlliance.Type.ORDER)
	for button: Button in forge.faction_grid.get_children():
		if button.get_meta(&"faction") == FactionFixture.NAME:
			return button
	fail_test("the fixture faction has no card")
	return null


func _first_enabled_index(forge: Forge) -> int:
	for button: Button in forge.faction_grid.get_children():
		if not button.disabled:
			return button.get_index()
	return -1


func _press_cancel(forge: Forge) -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	forge._unhandled_input(event)


## Returns the alliance listing the first Legends faction, or -1 if no faction is Legends.
func _alliance_with_legends_faction() -> int:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction in FactionCatalog.factions_for(alliance):
			if FactionCatalog.is_legends(faction):
				return alliance
	return -1


# --- Saved armies and the shared header ---


func test_starts_showing_armies_panel() -> void:
	var forge := _make_forge()
	assert_true(forge.armies_panel.visible)
	assert_eq(forge.step, Forge.Step.ARMIES)


func test_starts_with_other_panels_hidden() -> void:
	var forge := _make_forge()
	for panel: Control in [forge.alliance_panel, forge.faction_panel, forge.renown_panel, forge.formation_panel]:
		assert_false(panel.visible)


func test_only_the_current_steps_panel_is_shown() -> void:
	for shown: Forge.Step in Forge.Step.values():
		var forge := _make_forge()
		_go_to(forge, shown)
		for panel_step: Forge.Step in forge.panels:
			assert_eq(forge.panels[panel_step].visible, panel_step == shown, "step %d, panel %d" % [shown, panel_step])


## Shows [param target] with a faction that has Armies of Renown and battle formations.
func _go_to(forge: Forge, target: Forge.Step) -> void:
	var faction := _with_armies_of_renown()
	match target:
		Forge.Step.ARMIES:
			forge.show_armies()
		Forge.Step.ALLIANCE:
			forge.show_alliances()
		Forge.Step.FACTION:
			forge.show_factions(faction.grand_alliance)
		Forge.Step.RENOWN:
			forge.show_armies_of_renown(faction.grand_alliance, faction.name)
		Forge.Step.FORMATION:
			forge.show_armies_of_renown(faction.grand_alliance, faction.name)
			forge.renown_cards()[0].pressed.emit()


func test_back_label_differs_on_every_step() -> void:
	var labels := []
	for shown: Forge.Step in Forge.Step.values():
		var forge := _make_forge()
		_go_to(forge, shown)
		assert_ne(forge.back_button.text, "", "step %d has no Back label" % shown)
		assert_does_not_have(labels, forge.back_button.text)
		labels.append(forge.back_button.text)


func test_back_leads_one_step_back_on_every_step() -> void:
	for shown: Forge.Step in Forge.Step.values():
		if shown == Forge.Step.ARMIES:
			continue
		var forge := _make_forge()
		_go_to(forge, shown)
		forge.back_button.pressed.emit()
		assert_eq(forge.step, shown - 1)
		assert_signal_not_emitted(forge, "back_pressed")


func test_cancel_goes_where_back_goes_on_every_step() -> void:
	for shown: Forge.Step in Forge.Step.values():
		var by_button := _make_forge()
		_go_to(by_button, shown)
		by_button.back_button.pressed.emit()
		var by_cancel := _make_forge()
		_go_to(by_cancel, shown)
		_press_cancel(by_cancel)
		assert_eq(by_cancel.step, by_button.step, "step %d" % shown)
		assert_eq(get_signal_emit_count(by_cancel, "back_pressed"), get_signal_emit_count(by_button, "back_pressed"))


func test_go_back_from_armies_emits_back_pressed() -> void:
	var forge := _make_forge()
	forge.go_back()
	assert_signal_emitted(forge, "back_pressed")


func test_back_button_on_armies_emits_back_pressed() -> void:
	var forge := _make_forge()
	forge.back_button.pressed.emit()
	assert_signal_emitted(forge, "back_pressed")


func test_released_cancel_does_nothing() -> void:
	var forge := _make_forge()
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = false
	forge._unhandled_input(event)
	assert_signal_not_emitted(forge, "back_pressed")


func test_header_title_is_only_shown_on_armies() -> void:
	for shown: Forge.Step in Forge.Step.values():
		var forge := _make_forge()
		_go_to(forge, shown)
		assert_eq(forge.header_title.visible, shown == Forge.Step.ARMIES, "step %d" % shown)


func test_browse_button_is_only_shown_on_renown_and_formation() -> void:
	for shown: Forge.Step in Forge.Step.values():
		var forge := _make_forge()
		_go_to(forge, shown)
		var expected := shown == Forge.Step.RENOWN or shown == Forge.Step.FORMATION
		assert_eq(forge.browse_button.visible, expected, "step %d" % shown)


func test_breadcrumb_is_empty_on_armies() -> void:
	var forge := _make_forge()
	assert_eq(forge.breadcrumb.get_child_count(), 0)


func test_breadcrumb_highlights_the_current_step() -> void:
	for shown: Forge.Step in Forge.Step.values():
		if shown == Forge.Step.ARMIES:
			continue
		var forge := _make_forge()
		_go_to(forge, shown)
		var current := UIKit.labels_with_variation(forge.breadcrumb, "BreadcrumbCurrentLabel")
		assert_eq(current.size(), 1, "step %d" % shown)
		assert_eq(current[0].text, forge.breadcrumb_steps()[shown - 1])


func test_breadcrumb_is_replaced_not_stacked_when_steps_change() -> void:
	var forge := _make_forge()
	_go_to(forge, Forge.Step.ALLIANCE)
	_go_to(forge, Forge.Step.FACTION)
	await get_tree().process_frame
	assert_eq(forge.breadcrumb.get_child_count(), 1)


func test_breadcrumb_steps_names_every_step_before_any_choice() -> void:
	var forge := _make_forge()
	forge.show_alliances()
	assert_eq(forge.breadcrumb_steps().size(), Forge.STEPS.size())
	assert_eq(forge.breadcrumb_steps(), Forge.STEPS)


func test_breadcrumb_steps_fill_in_choices_made_so_far() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	var steps := forge.breadcrumb_steps()
	assert_eq(steps[0], GrandAlliance.display_name(faction.grand_alliance))
	assert_eq(steps[1], faction.name)
	assert_eq(steps[2], forge.renown_cards()[0].accessibility_name)
	assert_eq(steps.slice(3), Forge.STEPS.slice(3))


func test_breadcrumb_steps_on_renown_only_fill_in_alliance_and_faction() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_go_to(forge, Forge.Step.RENOWN)
	var steps := forge.breadcrumb_steps()
	assert_eq(steps[1], faction.name)
	assert_eq(steps.slice(2), Forge.STEPS.slice(2))


# --- Grand Alliance and faction ---


func test_has_a_card_for_every_alliance() -> void:
	var forge := _make_forge()
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		assert_true(forge.alliance_buttons.has(alliance),
				"no card for %s" % GrandAlliance.display_name(alliance))
		assert_eq(forge.alliance_buttons[alliance].get_parent(), forge.alliance_grid)


func test_alliance_cards_are_named_for_screen_readers() -> void:
	var forge := _make_forge()
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		assert_eq(forge.alliance_buttons[alliance].accessibility_name, GrandAlliance.display_name(alliance))


func _icon_of(card: Control) -> Texture2D:
	var found := UIKit.find_all(card, func(n: Node) -> bool: return n is TextureRect)
	return (found[0] as TextureRect).texture if found else null


func test_alliance_cards_show_their_alliance_icon() -> void:
	var forge := _make_forge()
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		assert_eq(_icon_of(forge.alliance_buttons[alliance]), UITheme.alliance_icon(alliance),
				GrandAlliance.display_name(alliance))


func test_faction_cards_show_their_faction_icon() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for card: Button in forge.faction_grid.get_children():
			var faction: String = card.get_meta(&"faction")
			if UITheme.faction_icon(faction):
				assert_eq(_icon_of(card), UITheme.faction_icon(faction), faction)


func test_faction_cards_without_an_icon_show_initials() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for card: Button in forge.faction_grid.get_children():
			var faction: String = card.get_meta(&"faction")
			if not UITheme.faction_icon(faction):
				assert_null(_icon_of(card), faction)
				assert_has(UIKit.label_texts(card), UIBuilder.initials(faction), faction)


func test_new_army_shows_the_alliances() -> void:
	var forge := _make_forge()
	forge.new_army_button.pressed.emit()
	assert_true(forge.alliance_panel.visible)
	assert_false(forge.armies_panel.visible)


func test_pressing_alliance_card_shows_faction_panel_at_once() -> void:
	var forge := _make_forge()
	forge.show_alliances()
	forge.alliance_buttons[_two_alliances()[0]].pressed.emit()
	assert_eq(forge.step, Forge.Step.FACTION)
	assert_true(forge.faction_panel.visible)
	assert_false(forge.alliance_panel.visible)


func test_each_alliance_card_lists_that_alliances_factions() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.alliance_buttons[alliance].pressed.emit()
		assert_eq(_faction_button_names(forge), FactionCatalog.factions_for(alliance))


func test_faction_description_names_the_alliance() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.alliance_buttons[alliance].pressed.emit()
		assert_string_contains(forge.faction_description.text, GrandAlliance.display_name(alliance))


func test_choosing_second_alliance_leaves_no_cards_from_first() -> void:
	var forge := _make_forge()
	var alliances := _two_alliances()
	forge.show_factions(alliances[0])
	forge.show_alliances()
	forge.show_factions(alliances[1])
	assert_eq(_faction_button_names(forge), FactionCatalog.factions_for(alliances[1]))


func test_showing_same_alliance_twice_does_not_duplicate_cards() -> void:
	var forge := _make_forge()
	var alliance: GrandAlliance.Type = _two_alliances()[0]
	forge.show_factions(alliance)
	forge.show_factions(alliance)
	await get_tree().process_frame
	assert_eq(forge.faction_grid.get_child_count(), FactionCatalog.factions_for(alliance).size())


func test_first_enabled_faction_card_has_focus_after_choosing_alliance() -> void:
	var alliance := _alliance_with_available_faction()
	var forge := _make_forge()
	forge.show_factions(alliance)
	assert_true(forge.faction_grid.get_child(_first_enabled_index(forge)).has_focus())


func test_back_button_has_focus_when_no_faction_is_available() -> void:
	FactionFixture.list_alone(GrandAlliance.Type.ORDER)
	var forge := _make_forge()
	forge.show_factions(GrandAlliance.Type.ORDER)
	assert_true(forge.back_button.has_focus())


func test_available_faction_cards_are_enabled() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			if FactionCatalog.is_available(button.get_meta(&"faction")):
				assert_false(button.disabled, "%s is disabled" % button.accessibility_name)


func test_unavailable_faction_cards_are_disabled() -> void:
	assert_true(_fixture_faction_card().disabled)


func test_faction_card_meta_is_plain_faction_name() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			assert_has(FactionCatalog.factions_for(alliance), button.get_meta(&"faction"))


func test_faction_card_is_named_for_screen_readers() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			var faction: String = button.get_meta(&"faction")
			assert_string_starts_with(button.accessibility_name, faction)
			assert_eq(button.accessibility_name.ends_with("(Legends)"), FactionCatalog.is_legends(faction), faction)


func test_unavailable_faction_cards_explain_why_in_tooltip() -> void:
	assert_ne(_fixture_faction_card().tooltip_text, "")


func test_pressing_faction_card_shows_its_army_of_renown_choice() -> void:
	var alliance := _alliance_with_available_faction()
	var forge := _make_forge()
	forge.show_factions(alliance)
	var index := _first_enabled_index(forge)
	(forge.faction_grid.get_child(index) as Button).pressed.emit()
	assert_true(forge.renown_panel.visible)
	assert_eq(forge.breadcrumb_steps()[1], FactionCatalog.factions_for(alliance)[index])


func test_pressing_legends_faction_card_marks_the_faction_as_legends() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	var forge := _make_forge()
	forge.show_factions(alliance)
	for button: Button in forge.faction_grid.get_children():
		if FactionCatalog.is_legends(button.get_meta(&"faction")) and not button.disabled:
			button.pressed.emit()
			assert_gt(forge.renown_chips.get_child_count(), 0)
			return
	pending("no Legends faction has data")


func test_shown_factions_include_legends_when_settings_show_them() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	GameSettings.current().show_legends = true
	assert_eq(Forge.shown_factions(alliance), FactionCatalog.factions_for(alliance))


func test_shown_factions_hide_legends_when_settings_hide_them() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	GameSettings.current().show_legends = false
	for faction in Forge.shown_factions(alliance):
		assert_false(FactionCatalog.is_legends(faction), faction)


func test_shown_factions_hiding_legends_keeps_the_other_factions() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	GameSettings.current().show_legends = false
	var expected := Array(FactionCatalog.factions_for(alliance)).filter(
			func(f: String) -> bool: return not FactionCatalog.is_legends(f))
	assert_eq(Array(Forge.shown_factions(alliance)), expected)


func test_faction_grid_hides_legends_factions_when_settings_hide_them() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	GameSettings.current().show_legends = false
	var forge := _make_forge()
	forge.show_factions(alliance)
	for faction in _faction_button_names(forge):
		assert_false(FactionCatalog.is_legends(faction), faction)


func test_faction_grid_lists_legends_factions_when_settings_show_them() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	var forge := _make_forge()
	forge.show_factions(alliance)
	assert_eq(_faction_button_names(forge), FactionCatalog.factions_for(alliance))


func test_renown_grid_hides_legends_armies_when_settings_hide_them() -> void:
	var faction := _faction_where(func(f: Faction) -> bool: return f.armies_of_renown.any(func(a: ArmyOfRenown) -> bool: return a.legends))
	if faction == null:
		pending("no Army of Renown is Legends")
		return
	GameSettings.current().show_legends = false
	var forge := _make_forge()
	_open_renown(forge, faction)
	for army in faction.armies_of_renown:
		var card := _choice_with_meta(forge.renown_grid, &"army_of_renown", army.name)
		assert_eq(card == null, army.legends, army.name)


func test_renown_grid_lists_legends_armies_when_settings_show_them() -> void:
	var faction := _faction_where(func(f: Faction) -> bool: return f.armies_of_renown.any(func(a: ArmyOfRenown) -> bool: return a.legends))
	if faction == null:
		pending("no Army of Renown is Legends")
		return
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_eq(forge.renown_grid.get_child_count(), faction.armies_of_renown.size())


func test_unavailable_faction_card_stays_on_faction_panel() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			if button.disabled:
				button.pressed.emit()
		assert_true(forge.faction_panel.visible)


func test_back_from_factions_refocuses_chosen_alliance() -> void:
	var forge := _make_forge()
	var alliance: GrandAlliance.Type = _two_alliances()[1]
	forge.show_factions(alliance)
	forge.back_button.pressed.emit()
	assert_true(forge.alliance_buttons[alliance].has_focus())


func test_back_from_alliances_returns_to_the_armies_list() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	forge.new_army_button.pressed.emit()
	forge.back_button.pressed.emit()
	assert_not_null(_row(forge, army.id))


# --- Army of Renown ---


## Returns the Faction of the first available faction for which [param wanted] is true, or null.
func _faction_where(wanted: Callable) -> Faction:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction_name in FactionCatalog.factions_for(alliance):
			if FactionCatalog.is_available(faction_name):
				var faction := FactionCatalog.load_faction(faction_name)
				if wanted.call(faction):
					return faction
	return null


func _with_armies_of_renown() -> Faction:
	return _faction_where(func(f: Faction) -> bool: return not f.armies_of_renown.is_empty() and not f.battle_formations.is_empty())


func _open_renown(forge: Forge, faction: Faction) -> void:
	forge.show_armies_of_renown(faction.grand_alliance, faction.name)


func _choice_with_meta(list: Control, key: StringName, value: String) -> Button:
	for button: Button in list.get_children():
		if button.get_meta(key, "") == value:
			return button
	return null


## Presses [param card], as a click does.
func _press(card: Button) -> void:
	card.pressed.emit()


func test_renown_panel_is_the_only_panel_shown() -> void:
	var forge := _make_forge()
	_open_renown(forge, _with_armies_of_renown())
	assert_true(forge.renown_panel.visible)
	assert_false(forge.faction_panel.visible)
	assert_false(forge.formation_panel.visible)
	assert_false(forge.alliance_panel.visible)


func test_renown_cards_start_with_none() -> void:
	var forge := _make_forge()
	_open_renown(forge, _with_armies_of_renown())
	assert_eq(forge.renown_cards()[0].get_meta(&"army_of_renown"), "")
	assert_eq(forge.renown_cards()[0].get_parent(), forge.renown_none)


func _has_icon(f: Faction) -> bool:
	return UITheme.faction_icon(f.name) != null


func test_none_card_shows_the_factions_icon() -> void:
	var faction := _faction_where(_has_icon)
	if faction == null:
		pending("no available faction has an icon")
		return
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_eq(_icon_of(forge.renown_cards()[0]), UITheme.faction_icon(faction.name))


func test_none_card_falls_back_to_the_alliance_icon() -> void:
	var faction := _faction_where(func(f: Faction) -> bool: return not _has_icon(f))
	if faction == null:
		pending("every available faction has an icon")
		return
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_eq(_icon_of(forge.renown_cards()[0]), UITheme.alliance_icon(faction.grand_alliance))


func test_renown_cards_are_none_plus_each_army_of_renown() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_eq(forge.renown_cards().size(), faction.armies_of_renown.size() + 1)
	assert_eq(forge.renown_grid.get_child_count(), faction.armies_of_renown.size())


func test_renown_panel_has_a_card_per_army_of_renown() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	for army in faction.armies_of_renown:
		assert_not_null(_choice_with_meta(forge.renown_grid, &"army_of_renown", army.name), army.name)


func test_renown_cards_are_named_for_screen_readers() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	for card in forge.renown_cards():
		assert_ne(card.accessibility_name, "")
	for army in faction.armies_of_renown:
		var card := _choice_with_meta(forge.renown_grid, &"army_of_renown", army.name)
		assert_string_starts_with(card.accessibility_name, army.name)


func test_renown_panel_marks_legends_armies() -> void:
	var faction := _faction_where(func(f: Faction) -> bool: return f.armies_of_renown.any(func(a: ArmyOfRenown) -> bool: return a.legends))
	if faction == null:
		pending("no Army of Renown is Legends")
		return
	var forge := _make_forge()
	_open_renown(forge, faction)
	for army in faction.armies_of_renown:
		var card := _choice_with_meta(forge.renown_grid, &"army_of_renown", army.name)
		assert_eq(card.accessibility_name.ends_with("(Legends)"), army.legends, card.accessibility_name)


func test_renown_panel_without_data_does_nothing() -> void:
	var forge := _make_forge()
	forge.show_armies_of_renown(GrandAlliance.Type.values()[0], "Not A Real Faction")
	assert_push_error("Not A Real Faction")
	assert_false(forge.renown_panel.visible)
	assert_true(forge.armies_panel.visible)


func test_renown_panel_focuses_none() -> void:
	var forge := _make_forge()
	_open_renown(forge, _with_armies_of_renown())
	assert_true(forge.renown_cards()[0].has_focus())


func test_renown_panel_reopened_for_another_faction_replaces_cards() -> void:
	var faction := _with_armies_of_renown()
	var other := _faction_where(func(f: Faction) -> bool: return f.name != faction.name and f.armies_of_renown.size() != faction.armies_of_renown.size())
	var forge := _make_forge()
	_open_renown(forge, faction)
	_open_renown(forge, other)
	await get_tree().process_frame
	assert_eq(forge.renown_grid.get_child_count(), other.armies_of_renown.size())
	assert_eq(forge.renown_none.get_child_count(), 1)


func test_browse_button_emits_browse_requested_with_alliance_and_faction() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	forge.browse_button.pressed.emit()
	assert_signal_emitted_with_parameters(forge, "browse_requested", [faction.grand_alliance, faction.name])


func test_renown_cards_are_not_toggles() -> void:
	var forge := _make_forge()
	_open_renown(forge, _with_armies_of_renown())
	for card in forge.renown_cards():
		assert_false(card.toggle_mode, card.accessibility_name)


func test_pressing_an_army_of_renown_starts_the_army_at_once() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	var army_of_renown := faction.armies_of_renown[0]
	_press(_choice_with_meta(forge.renown_grid, &"army_of_renown", army_of_renown.name))
	var army: Army = get_signal_parameters(forge, "army_started")[0]
	assert_eq(army.faction_id, faction.id)
	assert_eq(army.army_of_renown, army_of_renown.name)
	assert_eq(army.formation, "")
	assert_eq(army.tactics, PackedStringArray(["", ""]))


func test_pressing_an_army_of_renown_skips_the_formation_panel() -> void:
	var forge := _make_forge()
	_open_renown(forge, _with_armies_of_renown())
	_press(forge.renown_cards()[1])
	assert_false(forge.formation_panel.visible)


func test_pressing_none_with_formations_shows_formations_at_once() -> void:
	var forge := _make_forge()
	_open_renown(forge, _with_armies_of_renown())
	_press(forge.renown_cards()[0])
	assert_eq(forge.step, Forge.Step.FORMATION)
	assert_true(forge.formation_panel.visible)
	assert_false(forge.renown_panel.visible)
	assert_signal_not_emitted(forge, "army_started")


func test_choosing_none_without_formations_starts_the_army() -> void:
	var forge := _make_forge()
	forge._faction = Kit.faction([] as Array[Warscroll], "no_formations")
	forge.choose_army_of_renown("")
	var army: Army = get_signal_parameters(forge, "army_started")[0]
	assert_eq(army.faction_id, "no_formations")
	assert_eq(army.formation, "")
	assert_eq(army.army_of_renown, "")
	assert_eq(army.tactics, PackedStringArray(["", ""]))
	assert_false(forge.formation_panel.visible)


func test_chosen_army_of_renown_is_focused_when_returning_to_the_same_faction() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	var army := faction.armies_of_renown[0]
	_press(_choice_with_meta(forge.renown_grid, &"army_of_renown", army.name))
	forge.show_factions(faction.grand_alliance)
	_open_renown(forge, faction)
	assert_true(_choice_with_meta(forge.renown_grid, &"army_of_renown", army.name).has_focus())


func test_choice_is_reset_for_another_faction() -> void:
	GameSettings.current().show_legends = true
	var shared := _shared_army_of_renown()
	if shared.is_empty():
		pending("no two available factions share an Army of Renown name")
		return
	var forge := _make_forge()
	_open_renown(forge, shared[1])
	_press(_choice_with_meta(forge.renown_grid, &"army_of_renown", shared[0]))
	_open_renown(forge, shared[2])
	assert_not_null(_choice_with_meta(forge.renown_grid, &"army_of_renown", shared[0]), "the other faction offers it too")
	assert_false(_choice_with_meta(forge.renown_grid, &"army_of_renown", shared[0]).has_focus())
	assert_true(forge.renown_cards()[0].has_focus())


## Returns [name, faction, other faction] for an Army of Renown name offered by two available
## factions, or an empty array if there is none.
func _shared_army_of_renown() -> Array:
	var owners := {}
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction_name in FactionCatalog.factions_for(alliance):
			if not FactionCatalog.is_available(faction_name):
				continue
			var faction := FactionCatalog.load_faction(faction_name)
			for army in faction.armies_of_renown:
				if owners.has(army.name) and owners[army.name].name != faction.name:
					return [army.name, owners[army.name], faction]
				owners[army.name] = faction
	return []


func test_none_is_focused_on_return_from_formation() -> void:
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	forge.go_back()
	assert_eq(forge.step, Forge.Step.RENOWN)
	assert_true(forge.renown_cards()[0].has_focus())


func test_roster_summary_lists_the_roster_options() -> void:
	var army := ArmyOfRenown.new()
	army.text = "Some description.\nROSTER OPTIONS\nFirst Hero\nSecond Hero"
	var summary := Forge.roster_summary(army)
	assert_string_contains(summary, "First Hero")
	assert_string_contains(summary, "Second Hero")
	assert_does_not_have(summary.split(" "), "description.")


func test_roster_summary_ignores_you_cannot_include_lines() -> void:
	var army := ArmyOfRenown.new()
	army.text = "ROSTER OPTIONS\nFirst Hero\nYou cannot include Regiments of Renown."
	var summary := Forge.roster_summary(army)
	assert_string_contains(summary, "First Hero")
	assert_eq(summary.contains("cannot include"), false)


func test_roster_summary_without_roster_options_is_the_first_sentence() -> void:
	var army := ArmyOfRenown.new()
	army.text = "A short intro. More detail follows.\nAnother line."
	var summary := Forge.roster_summary(army)
	assert_string_contains(summary, "A short intro")
	assert_eq(summary.contains("More detail"), false)


func test_roster_summary_of_empty_text_is_empty() -> void:
	assert_eq(Forge.roster_summary(ArmyOfRenown.new()), "")


func _chip_texts(army: ArmyOfRenown) -> Array:
	return Forge.renown_chips_for(army).map(func(chip: Array) -> String: return chip[0])


func _roster(entries: Array[RosterEntry] = []) -> ArmyRoster:
	var roster := ArmyRoster.new()
	roster.entries = entries
	return roster


func test_renown_chips_of_a_plain_army_are_empty() -> void:
	var army := ArmyOfRenown.new()
	army.roster = _roster()
	assert_eq(Forge.renown_chips_for(army), [])


func test_renown_chips_of_an_army_without_a_roster_are_empty() -> void:
	assert_eq(Forge.renown_chips_for(ArmyOfRenown.new()), [])


func test_renown_chips_mark_legends() -> void:
	var army := ArmyOfRenown.new()
	army.legends = true
	var chips := Forge.renown_chips_for(army)
	assert_eq(chips.size(), 1)
	assert_eq(chips[0][1], "legends")


func test_renown_chips_note_no_regiments_of_renown() -> void:
	var army := ArmyOfRenown.new()
	army.roster = _roster()
	army.roster.regiments_of_renown = false
	assert_eq(_chip_texts(army).size(), 1)
	assert_eq(Forge.renown_chips_for(army)[0][1], "warn")


func test_renown_chips_note_no_faction_terrain() -> void:
	var army := ArmyOfRenown.new()
	army.roster = _roster()
	army.roster.faction_terrain = false
	assert_eq(_chip_texts(army).size(), 1)
	assert_eq(Forge.renown_chips_for(army)[0][1], "warn")


func test_renown_chips_note_no_manifestations() -> void:
	var army := ArmyOfRenown.new()
	army.roster = _roster()
	army.roster.manifestations = false
	assert_eq(_chip_texts(army).size(), 1)
	assert_eq(Forge.renown_chips_for(army)[0][1], "warn")


func test_renown_chips_for_both_limits_differ_in_text() -> void:
	var army := ArmyOfRenown.new()
	army.roster = _roster()
	army.roster.faction_terrain = false
	army.roster.regiments_of_renown = false
	var texts := _chip_texts(army)
	assert_eq(texts.size(), 2)
	assert_ne(texts[0], texts[1])


func test_renown_chips_note_a_fixed_general() -> void:
	var entry := RosterEntry.new()
	entry.general = true
	var army := ArmyOfRenown.new()
	army.roster = _roster([entry] as Array[RosterEntry])
	assert_eq(_chip_texts(army).size(), 1)


func test_renown_chips_do_not_note_a_general_when_none_is_fixed() -> void:
	var army := ArmyOfRenown.new()
	army.roster = _roster([RosterEntry.new()] as Array[RosterEntry])
	assert_eq(_chip_texts(army).size(), 0)


func test_back_from_renown_focuses_the_faction_just_left() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	forge.back_button.pressed.emit()
	assert_eq(forge.get_viewport().gui_get_focus_owner().get_meta(&"faction"), faction.name)


# --- Battle formation ---


func test_formation_panel_lists_each_formation() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	assert_eq(forge.formation_grid.get_child_count(), faction.battle_formations.size())
	for formation in faction.battle_formations:
		assert_not_null(_choice_with_meta(forge.formation_grid, &"formation", formation.name), formation.name)


func test_formation_cards_are_not_toggles() -> void:
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	for card: Button in forge.formation_grid.get_children():
		assert_false(card.toggle_mode, card.accessibility_name)


func test_formation_panel_focuses_the_first_card() -> void:
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	assert_true((forge.formation_grid.get_child(0) as Button).has_focus())


func test_pressing_a_formation_starts_the_army_with_it() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	var formation := faction.battle_formations[faction.battle_formations.size() - 1]
	_press(_choice_with_meta(forge.formation_grid, &"formation", formation.name))
	var army: Army = get_signal_parameters(forge, "army_started")[0]
	assert_eq(army.formation, formation.name)
	assert_eq(army.faction_id, faction.id)
	assert_eq(army.army_of_renown, "")
	assert_eq(army.tactics, PackedStringArray(["", ""]))


func test_chosen_formation_is_focused_when_returning_to_the_step() -> void:
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	var picked := forge.formation_grid.get_child(1) as Button
	_press(picked)
	forge.go_back()
	_press(forge.renown_cards()[0])
	assert_true(_choice_with_meta(forge.formation_grid, &"formation", picked.get_meta(&"formation")).has_focus())



func test_formation_with_points_shows_them_on_its_card() -> void:
	var faction := _faction_where(func(f: Faction) -> bool: return f.battle_formations.any(func(b: BattleFormation) -> bool: return b.points > 0))
	if faction == null:
		pending("no formation costs points")
		return
	var forge := _make_forge()
	_open_renown(forge, faction)
	forge.renown_cards()[0].pressed.emit()
	for formation in faction.battle_formations:
		var card := _choice_with_meta(forge.formation_grid, &"formation", formation.name)
		var shown := Array(UIKit.label_texts(card)).any(func(t: String) -> bool: return t.contains("%d" % formation.points) and t.to_lower().contains("pts"))
		assert_eq(shown, formation.points > 0, formation.name)


## A long reaction timing, such as the Khazalite Holds' Wayfarer Nomads, must wrap rather than widen
## the card and squeeze the ability's name.
func test_formation_ability_cards_wrap_their_timing_and_name_its_frequency() -> void:
	var has_frequency := func(b: BattleFormation) -> bool:
		return b.abilities.any(func(a: Ability) -> bool: return not a.frequency.is_empty())
	var faction := _faction_where(func(f: Faction) -> bool: return f.battle_formations.any(has_frequency))
	if faction == null:
		pending("no formation ability has a frequency")
		return
	var forge := _make_forge()
	_open_renown(forge, faction)
	forge.renown_cards()[0].pressed.emit()
	for formation in faction.battle_formations.filter(has_frequency):
		var card := _choice_with_meta(forge.formation_grid, &"formation", formation.name)
		var ability_cards := UIKit.find_all(card, func(n: Node) -> bool: return n is AbilityCard)
		assert_eq(ability_cards.size(), formation.abilities.size(), formation.name)
		for ability_card: AbilityCard in ability_cards:
			var ability := ability_card.ability
			var timing: Label = ability_card.find_children("*", "Label", true, false).filter(
					func(l: Label) -> bool: return l.theme_type_variation == "AbilityTimingLabel")[0]
			assert_ne(timing.autowrap_mode, TextServer.AUTOWRAP_OFF, ability.name)
			assert_string_contains(timing.text, ability.frequency.to_upper())


func test_back_from_formations_shows_renown_panel_for_same_faction() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	forge.back_button.pressed.emit()
	assert_true(forge.renown_panel.visible)
	assert_false(forge.formation_panel.visible)
	assert_eq(forge.breadcrumb_steps()[1], faction.name)


func test_back_from_formations_focuses_the_selected_renown_card() -> void:
	var forge := _make_forge()
	_go_to(forge, Forge.Step.FORMATION)
	forge.back_button.pressed.emit()
	assert_true(forge.renown_cards()[0].has_focus())


# --- Saved armies panel ---

## Saves a new army of the first faction with data, named [param army_name].
func _save_army(army_name: String) -> Army:
	var faction: Faction
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for name in FactionCatalog.factions_for(alliance):
			if faction == null and FactionCatalog.is_available(name):
				faction = FactionCatalog.load_faction(name)
	var army := ArmyEditor.create_army(ArmyCatalog.new(faction, CoreRulesCatalog.get_rules()))
	army.name = army_name
	assert_eq(ArmyStore.save(army), OK)
	return army


## Rewrites the saved_at of the saved army [param id].
func _set_saved_at(id: String, saved_at: float) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArmyStore.path(id)))
	data.saved_at = saved_at
	var file := FileAccess.open(ArmyStore.path(id), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


func _write_raw(id: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ArmyStore.directory)
	var file := FileAccess.open(ArmyStore.path(id), FileAccess.WRITE)
	file.store_string(text)


func _rows(forge: Forge) -> Array[Node]:
	return forge.army_list.get_children().filter(func(n: Node) -> bool: return n.has_meta(&"army_id"))


func _row(forge: Forge, id: String) -> Control:
	for row in _rows(forge):
		if row.get_meta(&"army_id") == id:
			return row
	return null


## A row's Open button by its text; Duplicate and Delete are icon buttons found by tooltip.
func _row_button(forge: Forge, id: String, text: String) -> Button:
	if text == "Open":
		return UIKit.button(_row(forge, id), text)
	for button in UIKit.buttons(_row(forge, id)):
		if button.tooltip_text.begins_with(text):
			return button
	return null


func _row_title(forge: Forge, id: String) -> String:
	return UIKit.labels_with_variation(_row(forge, id), "CardHeadingLabel")[0].text


## All of a row's text, apart from its name.
func _row_detail(forge: Forge, id: String) -> String:
	var texts := UIKit.label_texts(_row(forge, id))
	texts.remove_at(texts.find(_row_title(forge, id)))
	return " ".join(texts)


func _row_ids(forge: Forge) -> PackedStringArray:
	var ids := PackedStringArray()
	for row in _rows(forge):
		ids.append(row.get_meta(&"army_id"))
	return ids


func _unknown_faction_army() -> Army:
	var army := Army.new()
	army.name = "Orphan"
	army.faction_id = "not_a_faction"
	return army


func test_armies_panel_lists_each_saved_army() -> void:
	var first := _save_army("One")
	var second := _save_army("Two")
	var forge := _make_forge()
	var ids := _row_ids(forge)
	ids.sort()
	var expected := PackedStringArray([first.id, second.id])
	expected.sort()
	assert_eq(ids, expected)


func test_armies_panel_lists_most_recently_saved_first() -> void:
	var older := _save_army("Older")
	var newer := _save_army("Newer")
	_set_saved_at(older.id, 100.0)
	_set_saved_at(newer.id, 200.0)
	var forge := _make_forge()
	assert_eq(_row_ids(forge), PackedStringArray([newer.id, older.id]))


func test_armies_panel_row_shows_the_army_name() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	assert_eq(_row_title(forge, army.id), "Vanguard")


func test_armies_panel_row_shows_points_against_the_limit() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	assert_string_contains(_row_detail(forge, army.id), "/ %d pts" % army.points_limit)


func test_armies_panel_row_names_the_faction() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	assert_string_contains(_row_detail(forge, army.id), FactionCatalog.name_for_id(army.faction_id))


func test_armies_panel_without_saved_armies_explains() -> void:
	var forge := _make_forge()
	assert_eq(forge.army_list.get_child_count(), 1)
	assert_gt(UIKit.label_texts(forge.army_list).size(), 0)


func test_armies_panel_without_saved_armies_has_no_rows() -> void:
	var forge := _make_forge()
	assert_eq(_rows(forge).size(), 0)


func test_empty_armies_panel_focuses_new_army() -> void:
	var forge := _make_forge()
	assert_true(forge.new_army_button.has_focus())


func test_armies_panel_with_armies_has_no_empty_message() -> void:
	_save_army("One")
	var forge := _make_forge()
	assert_eq(forge.army_list.get_child_count(), _rows(forge).size())


func test_armies_panel_focuses_the_first_rows_open_button() -> void:
	var older := _save_army("Older")
	var newer := _save_army("Newer")
	_set_saved_at(older.id, 100.0)
	_set_saved_at(newer.id, 200.0)
	var forge := _make_forge()
	assert_true(_row_button(forge, newer.id, "Open").has_focus())


func test_show_armies_focuses_the_given_army() -> void:
	var older := _save_army("Older")
	var newer := _save_army("Newer")
	_set_saved_at(older.id, 100.0)
	_set_saved_at(newer.id, 200.0)
	var forge := _make_forge()
	forge.show_armies(older.id)
	assert_true(_row_button(forge, older.id, "Open").has_focus())


func test_show_armies_refreshes_the_list() -> void:
	var forge := _make_forge()
	var army := _save_army("Late")
	forge.show_armies()
	assert_not_null(_row(forge, army.id))


func test_open_emits_army_opened_with_the_army() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Open").pressed.emit()
	assert_signal_emitted(forge, "army_opened")
	var emitted: Army = get_signal_parameters(forge, "army_opened")[0]
	assert_eq(emitted.id, army.id)
	assert_eq(emitted.name, "Vanguard")


func test_unreadable_file_cannot_be_opened() -> void:
	_write_raw("broken", "not json {")
	var forge := _make_forge()
	assert_true(_row_button(forge, "broken", "Open").disabled)


func test_unreadable_file_can_still_be_deleted() -> void:
	_write_raw("broken", "[1, 2]")
	var forge := _make_forge()
	assert_false(_row_button(forge, "broken", "Delete").disabled)


func test_unreadable_file_cannot_be_duplicated() -> void:
	_write_raw("broken", "[1, 2]")
	var forge := _make_forge()
	assert_true(_row_button(forge, "broken", "Duplicate").disabled)


func test_unreadable_file_is_marked_in_its_row() -> void:
	_write_raw("broken", "[1, 2]")
	var forge := _make_forge()
	assert_string_contains(_row_title(forge, "broken"), "Unreadable")


func test_unreadable_file_row_takes_the_focus_when_it_is_first() -> void:
	_write_raw("broken", "[1, 2]")
	var forge := _make_forge()
	assert_true(_row_button(forge, "broken", "Delete").has_focus())


func test_army_of_a_faction_without_data_cannot_be_opened() -> void:
	assert_eq(ArmyStore.save(_unknown_faction_army()), OK)
	var forge := _make_forge()
	var id := _row_ids(forge)[0]
	assert_true(_row_button(forge, id, "Open").disabled)


func test_army_of_a_faction_without_data_says_so() -> void:
	assert_eq(ArmyStore.save(_unknown_faction_army()), OK)
	var forge := _make_forge()
	var id := _row_ids(forge)[0]
	assert_string_contains(_row_detail(forge, id), "not_a_faction")


func test_army_of_a_faction_without_data_can_be_duplicated() -> void:
	assert_eq(ArmyStore.save(_unknown_faction_army()), OK)
	var forge := _make_forge()
	var id := _row_ids(forge)[0]
	assert_false(_row_button(forge, id, "Duplicate").disabled)


func test_duplicate_adds_a_copy() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Duplicate").pressed.emit()
	assert_eq(_rows(forge).size(), 2)


func test_duplicate_names_the_copy() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Duplicate").pressed.emit()
	var titles := PackedStringArray()
	for id in _row_ids(forge):
		titles.append(_row_title(forge, id))
	assert_has(titles, "Vanguard (copy)")


func test_duplicate_focuses_the_copy() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Duplicate").pressed.emit()
	var copy_id := ""
	for id in _row_ids(forge):
		if id != army.id:
			copy_id = id
	assert_true(_row_button(forge, copy_id, "Open").has_focus())


func test_duplicate_leaves_the_original() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Duplicate").pressed.emit()
	assert_not_null(_row(forge, army.id))


func test_delete_asks_before_deleting() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Delete").pressed.emit()
	assert_true(forge.delete_dialog.visible)


func test_delete_dialog_focuses_cancel() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Delete").pressed.emit()
	assert_true(forge.delete_dialog.get_cancel_button().has_focus())
	assert_true(FileAccess.file_exists(ArmyStore.path(army.id)))


func test_delete_dialog_names_the_army() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Delete").pressed.emit()
	assert_string_contains(forge.delete_dialog.dialog_text, "Vanguard")


func test_confirming_delete_removes_the_file() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Delete").pressed.emit()
	forge.delete_dialog.confirmed.emit()
	assert_false(FileAccess.file_exists(ArmyStore.path(army.id)))


func test_confirming_delete_removes_the_row() -> void:
	var army := _save_army("Vanguard")
	var other := _save_army("Other")
	var forge := _make_forge()
	_row_button(forge, army.id, "Delete").pressed.emit()
	forge.delete_dialog.confirmed.emit()
	assert_eq(_row_ids(forge), PackedStringArray([other.id]))


func test_confirming_delete_of_the_last_army_shows_the_empty_state() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Delete").pressed.emit()
	forge.delete_dialog.confirmed.emit()
	assert_eq(_rows(forge).size(), 0)
	assert_eq(forge.army_list.get_child_count(), 1)


func test_canceling_delete_keeps_the_army() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	_row_button(forge, army.id, "Delete").pressed.emit()
	forge.delete_dialog.canceled.emit()
	assert_true(FileAccess.file_exists(ArmyStore.path(army.id)))
	assert_not_null(_row(forge, army.id))


func test_canceling_delete_refocuses_the_army() -> void:
	var older := _save_army("Older")
	var newer := _save_army("Newer")
	_set_saved_at(older.id, 100.0)
	_set_saved_at(newer.id, 200.0)
	var forge := _make_forge()
	_row_button(forge, older.id, "Delete").pressed.emit()
	forge.delete_dialog.canceled.emit()
	assert_true(_row_button(forge, older.id, "Open").has_focus())


func test_summary_of_unreadable_entry_cannot_open() -> void:
	var entry := ArmyStore.Entry.new()
	entry.id = "x"
	entry.errors = PackedStringArray(["bad file"])
	var summary := Forge.army_summary(entry)
	assert_false(summary.can_open)
	assert_string_contains(summary.detail, "bad file")


func test_summary_of_valid_empty_army_can_open() -> void:
	var army := _save_army("Vanguard")
	var summary := Forge.army_summary(ArmyStore.read(army.id))
	assert_true(summary.can_open)
	assert_eq(summary.name, "Vanguard")


func test_summary_without_a_name_says_unnamed() -> void:
	var army := _save_army("")
	var summary := Forge.army_summary(ArmyStore.read(army.id))
	assert_string_contains(summary.name, "Unnamed")


func test_summary_counts_problems() -> void:
	var army := _save_army("Vanguard")
	var entry := ArmyStore.read(army.id)
	var catalog := ArmyCatalog.new(FactionCatalog.load_faction(FactionCatalog.name_for_id(army.faction_id)), CoreRulesCatalog.get_rules())
	var problems := ArmyValidator.validate(entry.army, catalog).problems.size()
	var detail: String = Forge.army_summary(entry).detail
	if problems == 0:
		assert_string_contains(detail, "Valid")
	else:
		assert_string_contains(detail, "%d problem" % problems)


func test_summary_flags_overridden_constraints() -> void:
	var army := _save_army("Vanguard")
	var entry := ArmyStore.read(army.id)
	entry.army.override_constraints = true
	assert_string_contains(Forge.army_summary(entry).detail, "overridden")


func test_summary_mentions_choices_that_could_not_be_read() -> void:
	var army := _save_army("Vanguard")
	var entry := ArmyStore.read(army.id)
	entry.errors = PackedStringArray(["tactics: bad"])
	assert_string_contains(Forge.army_summary(entry).detail, "couldn't be read")


func test_summary_splits_out_the_faction() -> void:
	var army := _save_army("Vanguard")
	var summary := Forge.army_summary(ArmyStore.read(army.id))
	assert_eq(summary.faction, FactionCatalog.name_for_id(army.faction_id))
	assert_has(summary.details, summary.faction)


func test_summary_details_exclude_the_status() -> void:
	var army := _save_army("Vanguard")
	var summary := Forge.army_summary(ArmyStore.read(army.id))
	assert_does_not_have(summary.details, summary.status)
	assert_string_contains(summary.detail, summary.status)


func test_summary_status_kind_matches_overridden_constraints() -> void:
	var entry := ArmyStore.read(_save_army("Vanguard").id)
	entry.army.override_constraints = true
	assert_eq(Forge.army_summary(entry).status_kind, "overridden")


func test_summary_status_kind_is_a_theme_status() -> void:
	var entry := ArmyStore.read(_save_army("Vanguard").id)
	assert_has(UITheme.STATUS.keys(), Forge.army_summary(entry).status_kind)


func test_summary_of_unreadable_entry_has_no_status_and_a_note() -> void:
	var entry := ArmyStore.Entry.new()
	entry.id = "x"
	entry.errors = PackedStringArray(["bad file"])
	var summary := Forge.army_summary(entry)
	assert_eq(summary.status_kind, "")
	assert_eq(summary.faction, "")
	assert_string_contains(summary.note, "bad file")


func test_summary_note_is_empty_for_a_clean_army() -> void:
	var entry := ArmyStore.read(_save_army("Vanguard").id)
	assert_eq(Forge.army_summary(entry).note, "")


func test_summary_note_mentions_unreadable_choices() -> void:
	var entry := ArmyStore.read(_save_army("Vanguard").id)
	entry.errors = PackedStringArray(["tactics: bad"])
	assert_ne(Forge.army_summary(entry).note, "")


func test_summary_of_a_faction_without_data_notes_the_faction() -> void:
	var army := _unknown_faction_army()
	var entry := ArmyStore.Entry.new()
	entry.id = "orphan"
	entry.army = army
	var summary := Forge.army_summary(entry)
	assert_false(summary.can_open)
	assert_string_contains(summary.note, "not_a_faction")


func test_row_icon_buttons_are_named_for_screen_readers() -> void:
	var army := _save_army("Vanguard")
	var forge := _make_forge()
	assert_eq(_row_button(forge, army.id, "Duplicate").accessibility_name, "Duplicate Vanguard")
	assert_eq(_row_button(forge, army.id, "Delete").accessibility_name, "Delete Vanguard")


## Saves a new army of [param faction] named [param army_name].
func _save_army_of(faction: Faction, army_name: String) -> Army:
	var army := ArmyEditor.create_army(ArmyCatalog.new(faction, CoreRulesCatalog.get_rules()))
	army.name = army_name
	assert_eq(ArmyStore.save(army), OK)
	return army


func test_armies_panel_row_shows_the_factions_icon() -> void:
	var faction := _faction_where(_has_icon)
	if faction == null:
		pending("no available faction has an icon")
		return
	var army := _save_army_of(faction, "Iconic")
	var forge := _make_forge()
	assert_eq(_icon_of(_row(forge, army.id)), UITheme.faction_icon(faction.name))


func test_armies_panel_row_without_a_faction_icon_shows_initials() -> void:
	var faction := _faction_where(func(f: Faction) -> bool: return not _has_icon(f))
	if faction == null:
		pending("every available faction has an icon")
		return
	var army := _save_army_of(faction, "Plain")
	var forge := _make_forge()
	var row := _row(forge, army.id)
	assert_null(_icon_of(row))
	assert_has(UIKit.label_texts(row), UIBuilder.initials(faction.name))
