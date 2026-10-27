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


## Returns the first alliance with no faction data, or -1 if every alliance has some.
func _alliance_without_available_faction() -> int:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var available := false
		for faction in FactionCatalog.factions_for(alliance):
			available = available or FactionCatalog.is_available(faction)
		if not available:
			return alliance
	return -1


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
		assert_eq(_faction_button_names(forge), FactionCatalog.factions_for(alliance))


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
	assert_eq(_faction_button_names(forge), FactionCatalog.factions_for(alliances[1]))


func test_showing_same_alliance_twice_does_not_duplicate_buttons() -> void:
	var forge := _make_forge()
	var alliance: GrandAlliance.Type = _two_alliances()[0]
	forge.show_factions(alliance)
	forge.show_factions(alliance)
	assert_eq(forge.faction_grid.get_child_count(), FactionCatalog.factions_for(alliance).size())


func test_first_enabled_faction_button_has_focus_after_choosing_alliance() -> void:
	var alliance := _alliance_with_available_faction()
	var forge := _make_forge()
	forge.show_factions(alliance)
	assert_true(forge.faction_grid.get_child(_first_enabled_index(forge)).has_focus())


func test_faction_back_button_has_focus_when_no_faction_is_available() -> void:
	var alliance := _alliance_without_available_faction()
	if alliance < 0:
		pending("every alliance has an available faction")
		return
	var forge := _make_forge()
	forge.show_factions(alliance)
	assert_true(forge.faction_back_button.has_focus())


func test_available_faction_buttons_are_enabled() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			if FactionCatalog.is_available(button.get_meta(&"faction")):
				assert_false(button.disabled, "%s is disabled" % button.text)


func test_unavailable_faction_buttons_are_disabled() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			if not FactionCatalog.is_available(button.get_meta(&"faction")):
				assert_true(button.disabled, "%s is enabled" % button.text)


## Returns the alliance listing the first Legends faction, or -1 if no faction is Legends.
func _alliance_with_legends_faction() -> int:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction in FactionCatalog.factions_for(alliance):
			if FactionCatalog.is_legends(faction):
				return alliance
	return -1


func test_faction_button_meta_is_plain_faction_name() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			assert_has(FactionCatalog.factions_for(alliance), button.get_meta(&"faction"),
					"%s button meta isn't a listed faction" % button.text)


func test_non_legends_faction_button_text_is_faction_name() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			var faction: String = button.get_meta(&"faction")
			if not FactionCatalog.is_legends(faction):
				assert_eq(button.text, faction)


func test_legends_faction_button_text_marks_legends() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	var forge := _make_forge()
	forge.show_factions(alliance)
	for button: Button in forge.faction_grid.get_children():
		if FactionCatalog.is_legends(button.get_meta(&"faction")):
			assert_string_contains(button.text, "Legends")


func test_legends_faction_button_text_starts_with_faction_name() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	var forge := _make_forge()
	forge.show_factions(alliance)
	for button: Button in forge.faction_grid.get_children():
		var faction: String = button.get_meta(&"faction")
		if FactionCatalog.is_legends(faction):
			assert_true(button.text.begins_with(faction), button.text)


func test_pressing_legends_faction_button_marks_the_faction_as_legends() -> void:
	var alliance := _alliance_with_legends_faction()
	if alliance < 0:
		pending("no faction is Legends")
		return
	var forge := _make_forge()
	forge.show_factions(alliance)
	for button: Button in forge.faction_grid.get_children():
		var faction: String = button.get_meta(&"faction")
		if FactionCatalog.is_legends(faction) and not button.disabled:
			button.pressed.emit()
			assert_eq(forge.renown_title.text, faction + " (Legends)")
			return
	pending("no Legends faction has data")


func test_unavailable_faction_buttons_explain_why_in_tooltip() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			if button.disabled:
				assert_ne(button.tooltip_text, "", "%s has no tooltip" % button.text)


func test_pressing_faction_button_shows_its_army_of_renown_choice() -> void:
	var alliance := _alliance_with_available_faction()
	var forge := _make_forge()
	forge.show_factions(alliance)
	var index := _first_enabled_index(forge)
	(forge.faction_grid.get_child(index) as Button).pressed.emit()
	assert_true(forge.renown_panel.visible)
	assert_eq(forge.renown_title.text.trim_suffix(" (Legends)"), FactionCatalog.factions_for(alliance)[index])


func test_unavailable_faction_button_stays_on_faction_panel() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var forge := _make_forge()
		forge.show_factions(alliance)
		for button: Button in forge.faction_grid.get_children():
			if button.disabled:
				button.pressed.emit()
		assert_true(forge.faction_panel.visible)


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


# --- Army of Renown and battle formation panels ---

const Kit := preload("res://test/support/army_kit.gd")


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


func _choice_texts(list: Control) -> PackedStringArray:
	var texts := PackedStringArray()
	for button: Button in list.get_children():
		texts.append(button.text)
	return texts


func _open_renown(forge: Forge, faction: Faction) -> void:
	forge.show_armies_of_renown(faction.grand_alliance, faction.name)


func _choice_with_meta(list: Control, key: StringName, value: String) -> Button:
	for button: Button in list.get_children():
		if button.get_meta(key, "") == value:
			return button
	return null


func test_renown_panel_is_the_only_panel_shown() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_true(forge.renown_panel.visible)
	assert_false(forge.faction_panel.visible)
	assert_false(forge.formation_panel.visible)
	assert_false(forge.alliance_panel.visible)


func test_renown_panel_first_choice_is_none() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_string_starts_with((forge.renown_list.get_child(0) as Button).text, "None")


func test_renown_panel_none_choice_names_the_faction() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_string_contains((forge.renown_list.get_child(0) as Button).text, faction.name)


func test_renown_panel_lists_none_plus_each_army_of_renown() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_eq(forge.renown_list.get_child_count(), faction.armies_of_renown.size() + 1)


func test_renown_panel_has_a_button_per_army_of_renown() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	for army in faction.armies_of_renown:
		assert_not_null(_choice_with_meta(forge.renown_list, &"army_of_renown", army.name), army.name)


func test_renown_panel_marks_legends_armies() -> void:
	var faction := _faction_where(func(f: Faction) -> bool: return f.armies_of_renown.any(func(a: ArmyOfRenown) -> bool: return a.legends))
	if faction == null:
		pending("no Army of Renown is Legends")
		return
	var forge := _make_forge()
	_open_renown(forge, faction)
	for army in faction.armies_of_renown:
		var button := _choice_with_meta(forge.renown_list, &"army_of_renown", army.name)
		assert_eq(button.text.ends_with("(Legends)"), army.legends, button.text)


func test_renown_panel_title_is_faction_name() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_eq(forge.renown_title.text.trim_suffix(" (Legends)"), faction.name)


func test_renown_panel_without_data_does_nothing() -> void:
	var forge := _make_forge()
	forge.show_armies_of_renown(GrandAlliance.Type.values()[0], "Not A Real Faction")
	assert_push_error("Not A Real Faction")
	assert_false(forge.renown_panel.visible)
	assert_true(forge.alliance_panel.visible)


func test_renown_panel_focuses_the_first_choice() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	assert_true((forge.renown_list.get_child(0) as Button).has_focus())


func test_renown_panel_reopened_for_another_faction_replaces_choices() -> void:
	var faction := _with_armies_of_renown()
	var other := _faction_where(func(f: Faction) -> bool: return f.name != faction.name and f.armies_of_renown.size() != faction.armies_of_renown.size())
	var forge := _make_forge()
	_open_renown(forge, faction)
	_open_renown(forge, other)
	assert_eq(forge.renown_list.get_child_count() - 1, other.armies_of_renown.size())


func test_browse_button_emits_browse_requested_with_alliance_and_faction() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	forge.browse_button.pressed.emit()
	assert_signal_emitted_with_parameters(forge, "browse_requested", [faction.grand_alliance, faction.name])


func test_picking_army_of_renown_emits_army_started() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(1) as Button).pressed.emit()
	assert_signal_emitted(forge, "army_started")


func test_picking_army_of_renown_skips_the_formation_panel() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(1) as Button).pressed.emit()
	assert_false(forge.formation_panel.visible)


func test_army_of_renown_army_has_faction_id_and_renown_name() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	var army_of_renown := faction.armies_of_renown[0]
	_choice_with_meta(forge.renown_list, &"army_of_renown", army_of_renown.name).pressed.emit()
	var army: Army = get_signal_parameters(forge, "army_started")[0]
	assert_eq(army.faction_id, faction.id)
	assert_eq(army.army_of_renown, army_of_renown.name)


func test_army_of_renown_army_has_no_formation() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(1) as Button).pressed.emit()
	var army: Army = get_signal_parameters(forge, "army_started")[0]
	assert_eq(army.formation, "")


func test_army_started_has_two_empty_tactic_slots() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(1) as Button).pressed.emit()
	var army: Army = get_signal_parameters(forge, "army_started")[0]
	assert_eq(army.tactics, PackedStringArray(["", ""]))


func test_none_choice_with_formations_shows_formation_panel() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	assert_true(forge.formation_panel.visible)
	assert_false(forge.renown_panel.visible)
	assert_signal_not_emitted(forge, "army_started")


func test_formation_panel_lists_each_formation() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	assert_eq(forge.formation_list.get_child_count(), faction.battle_formations.size())
	for formation in faction.battle_formations:
		assert_not_null(_choice_with_meta(forge.formation_list, &"formation", formation.name), formation.name)


func test_formation_panel_title_is_faction_name() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	assert_eq(forge.formation_title.text, faction.name)


func test_formation_panel_focuses_the_first_choice() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	assert_true((forge.formation_list.get_child(0) as Button).has_focus())


func test_formation_with_points_shows_them_in_its_label() -> void:
	var faction := _faction_where(func(f: Faction) -> bool: return f.battle_formations.any(func(b: BattleFormation) -> bool: return b.points > 0))
	if faction == null:
		pending("no formation costs points")
		return
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	for formation in faction.battle_formations:
		var button := _choice_with_meta(forge.formation_list, &"formation", formation.name)
		assert_eq(button.text.contains("%d pts" % formation.points), formation.points > 0, button.text)


func test_picking_formation_emits_army_with_that_formation() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	var formation := faction.battle_formations[faction.battle_formations.size() - 1]
	_choice_with_meta(forge.formation_list, &"formation", formation.name).pressed.emit()
	var army: Army = get_signal_parameters(forge, "army_started")[0]
	assert_eq(army.formation, formation.name)
	assert_eq(army.faction_id, faction.id)
	assert_eq(army.army_of_renown, "")
	assert_eq(army.tactics, PackedStringArray(["", ""]))


func test_none_choice_without_formations_starts_army_immediately() -> void:
	var forge := _make_forge()
	forge._faction = Kit.faction([] as Array[Warscroll], "no_formations")
	forge._on_own_rules_pressed()
	var army: Army = get_signal_parameters(forge, "army_started")[0]
	assert_eq(army.faction_id, "no_formations")
	assert_eq(army.formation, "")
	assert_eq(army.army_of_renown, "")
	assert_eq(army.tactics, PackedStringArray(["", ""]))
	assert_false(forge.formation_panel.visible)


func test_renown_back_button_shows_faction_panel() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	forge.renown_back_button.pressed.emit()
	assert_true(forge.faction_panel.visible)
	assert_false(forge.renown_panel.visible)


func test_renown_back_button_focuses_the_faction_just_left() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	forge.renown_back_button.pressed.emit()
	var focused := forge.get_viewport().gui_get_focus_owner()
	assert_eq(focused.get_meta(&"faction"), faction.name)


func test_renown_back_button_does_not_emit_back_pressed() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	forge.renown_back_button.pressed.emit()
	assert_signal_not_emitted(forge, "back_pressed")


func test_cancel_on_renown_panel_shows_faction_panel() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	_press_cancel(forge)
	assert_true(forge.faction_panel.visible)
	assert_signal_not_emitted(forge, "back_pressed")


func test_formation_back_button_shows_renown_panel_for_same_faction() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	forge.formation_back_button.pressed.emit()
	assert_true(forge.renown_panel.visible)
	assert_false(forge.formation_panel.visible)
	assert_eq(forge.renown_title.text.trim_suffix(" (Legends)"), faction.name)


func test_formation_back_button_focuses_the_first_renown_choice() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	forge.formation_back_button.pressed.emit()
	assert_true((forge.renown_list.get_child(0) as Button).has_focus())


func test_cancel_on_formation_panel_shows_renown_panel() -> void:
	var faction := _with_armies_of_renown()
	var forge := _make_forge()
	_open_renown(forge, faction)
	(forge.renown_list.get_child(0) as Button).pressed.emit()
	_press_cancel(forge)
	assert_true(forge.renown_panel.visible)
	assert_signal_not_emitted(forge, "back_pressed")
