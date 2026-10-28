extends GutTest
## Unit tests for the army builder screen (scripts/ui/forge/builder/army_builder.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")


## Redrawn sections are removed with queue_free, so let a frame pass for them to be freed before
## GUT counts orphans.
func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	await get_tree().process_frame
	Sandbox.end()


func _press_cancel(node: Node) -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	node._unhandled_input(event)


func _core() -> CoreRules:
	return Kit.core(PackedStringArray(["Card A", "Card B"]))


## An army that passes validation: a general-led regiment and two battle tactics cards.
func _valid_army() -> Army:
	var army := UIKit.army_with_regiment()
	army.tactics = PackedStringArray(["Card A", "Card B"])
	return army


func _builder(army: Army, faction: Faction = null) -> ArmyBuilder:
	return UIKit.builder(self, army, faction, _core())


func _pick_ids(builder: ArmyBuilder) -> PackedStringArray:
	var ids := PackedStringArray()
	for button in UIKit.buttons(builder.picker):
		var key: String = button.get_meta(&"focus_key", "")
		if key.begins_with("pick:"):
			ids.append(key.trim_prefix("pick:"))
	return ids


func _warscroll_names(list: Array[Warscroll]) -> PackedStringArray:
	var names := PackedStringArray()
	for warscroll in list:
		names.append(warscroll.id)
	return names


# --- Header ---

func test_points_label_shows_total_and_limit() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	var total := ArmyPoints.total(army, builder.catalog)
	assert_string_contains(builder.points_label.text, str(total))
	assert_string_contains(builder.points_label.text, str(army.points_limit))


func test_points_label_is_normal_colour_when_within_limit() -> void:
	var builder := _builder(_valid_army())
	assert_eq(builder.points_label.get_theme_color("font_color"), UITheme.TEXT)


func test_points_label_is_danger_colour_when_over_limit() -> void:
	var army := _valid_army()
	army.points_limit = 1
	var builder := _builder(army)
	assert_eq(builder.points_label.get_theme_color("font_color"), UITheme.DANGER)


func test_points_label_updates_after_the_army_changes() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	var before := builder.points_label.text
	builder.editor.add_unit("r1", "grunt")
	assert_ne(builder.points_label.text, before)


func test_status_says_army_valid_when_valid() -> void:
	var builder := _builder(_valid_army())
	assert_string_contains(builder.status_label.text.to_lower(), "valid")


func test_status_counts_problems() -> void:
	var army := Kit.army()
	var builder := _builder(army)
	var count := ArmyValidator.validate(army, builder.catalog).problems.size()
	assert_gt(count, 1)
	assert_string_starts_with(builder.status_label.text, str(count))


func test_status_uses_singular_for_one_problem() -> void:
	var army := _valid_army()
	army.general_uid = ""
	var builder := _builder(army)
	assert_eq(ArmyValidator.validate(army, builder.catalog).problems.size(), 1)
	assert_string_starts_with(builder.status_label.text, "1 problem")
	assert_false(builder.status_label.text.ends_with("s"))


func test_status_says_overridden_when_constraints_are_overridden() -> void:
	var army := UIKit.army_with_regiment()
	army.override_constraints = true
	var builder := _builder(army)
	assert_string_contains(builder.status_label.text.to_lower(), "overridden")


func test_status_colour_differs_between_valid_and_invalid() -> void:
	var valid := _builder(_valid_army())
	var invalid := _builder(UIKit.army_with_regiment())
	assert_ne(valid.status_label.get_theme_color("font_color"), invalid.status_label.get_theme_color("font_color"))


func test_header_shows_faction_name() -> void:
	var builder := _builder(_valid_army())
	assert_string_contains(builder.faction_label.text, builder.catalog.faction.name)


# --- Validation panel ---

func test_validation_panel_lists_each_problem() -> void:
	var army := UIKit.army_with_regiment()
	var builder := _builder(army)
	var problems := ArmyValidator.validate(army, builder.catalog).problems
	var shown := UIKit.labels_with_variation(builder.builder_list, "ProblemLabel")
	assert_eq(shown.size(), problems.size())
	for problem in problems:
		assert_true(UIKit.has_label_containing(builder.builder_list, problem), problem)


func test_validation_panel_lists_warnings() -> void:
	var army := _valid_army()
	army.tactics = PackedStringArray(["Card A", ""])
	var builder := _builder(army)
	var warnings := ArmyValidator.validate(army, builder.catalog).warnings
	assert_false(warnings.is_empty())
	assert_eq(UIKit.labels_with_variation(builder.builder_list, "WarningLabel").size(), warnings.size())


func test_validation_panel_has_no_problem_labels_for_valid_army() -> void:
	var builder := _builder(_valid_army())
	assert_eq(UIKit.labels_with_variation(builder.builder_list, "ProblemLabel").size(), 0)
	assert_eq(UIKit.labels_with_variation(builder.builder_list, "WarningLabel").size(), 0)


func test_validation_panel_says_unchecked_when_overridden() -> void:
	var army := UIKit.army_with_regiment()
	army.override_constraints = true
	var builder := _builder(army)
	assert_eq(UIKit.labels_with_variation(builder.builder_list, "ProblemLabel").size(), 0)
	assert_true(UIKit.has_label_containing(builder.builder_list, "overridden"))


# --- Picker and info pane ---

func test_pick_leader_opens_picker_and_hides_info_pane() -> void:
	var builder := _builder(_valid_army())
	builder.pick_leader("")
	assert_true(builder.picker.visible)
	assert_true(builder.picker.is_open())
	assert_false(builder.info_pane.visible)


func test_pick_unit_opens_picker_and_hides_info_pane() -> void:
	var builder := _builder(_valid_army())
	builder.pick_unit("r1")
	assert_true(builder.picker.visible)
	assert_false(builder.info_pane.visible)


func test_pick_auxiliary_opens_picker_and_hides_info_pane() -> void:
	var builder := _builder(_valid_army())
	builder.pick_auxiliary()
	assert_true(builder.picker.visible)
	assert_false(builder.info_pane.visible)


func test_pick_tactic_opens_picker_and_hides_info_pane() -> void:
	var builder := _builder(_valid_army())
	builder.pick_tactic(0)
	assert_true(builder.picker.visible)
	assert_false(builder.info_pane.visible)


func test_pick_regiment_of_renown_opens_picker_and_hides_info_pane() -> void:
	var builder := _builder(_valid_army())
	builder.pick_regiment_of_renown()
	assert_true(builder.picker.visible)
	assert_false(builder.info_pane.visible)


func test_closing_the_picker_restores_the_info_pane() -> void:
	var builder := _builder(_valid_army())
	builder.pick_tactic(0)
	builder.picker.close()
	assert_false(builder.picker.visible)
	assert_true(builder.info_pane.visible)


func test_picker_starts_closed_with_info_pane_shown() -> void:
	var builder := _builder(_valid_army())
	assert_false(builder.picker.visible)
	assert_true(builder.info_pane.visible)


func test_add_regiment_button_opens_leader_picker() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder, "army:add_regiment").pressed.emit()
	assert_true(builder.picker.is_open())


func test_picking_a_leader_adds_a_regiment_and_closes_the_picker() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	builder.pick_leader("")
	UIKit.keyed(builder.picker, "pick:lead").pressed.emit()
	assert_eq(army.regiments.size(), 2)
	assert_false(builder.picker.is_open())


func test_picking_an_auxiliary_unit_adds_it_and_closes_the_picker() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	builder.pick_auxiliary()
	UIKit.keyed(builder.picker, "pick:beast").pressed.emit()
	assert_eq(army.auxiliary.size(), 1)
	assert_false(builder.picker.is_open())


func test_picking_a_unit_keeps_the_picker_open_while_the_regiment_has_room() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	builder.pick_unit("r1")
	UIKit.keyed(builder.picker, "pick:grunt").pressed.emit()
	assert_eq(army.regiments[0].units.size(), 2)
	assert_true(builder.picker.is_open())


func test_picking_the_last_unit_that_fits_closes_the_picker() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	for i in ArmyValidator.regiment_capacity(army.regiments[0], army) - 1:
		builder.editor.add_unit("r1", "grunt")
	builder.pick_unit("r1")
	UIKit.keyed(builder.picker, "pick:grunt").pressed.emit()
	assert_false(builder.picker.is_open())


# --- Picker focus ---

func test_picking_a_unit_with_room_left_keeps_focus_in_the_picker() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder, "r1:add").grab_focus()
	builder.pick_unit("r1")
	UIKit.keyed(builder.picker, "pick:grunt").pressed.emit()
	var focused := builder.get_viewport().gui_get_focus_owner()
	assert_not_null(focused)
	assert_true(builder.picker.is_ancestor_of(focused))


func test_picking_the_last_unit_that_fits_focuses_the_regiment() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	for i in ArmyValidator.regiment_capacity(army.regiments[0], army) - 1:
		builder.editor.add_unit("r1", "grunt")
	UIKit.keyed(builder, "r1:add").grab_focus()
	builder.pick_unit("r1")
	UIKit.keyed(builder.picker, "pick:grunt").pressed.emit()
	assert_true(UIKit.keyed(builder.builder_list, "r1:collapse").has_focus())


func test_picking_a_leader_returns_focus_to_the_add_regiment_button() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder, "army:add_regiment").grab_focus()
	builder.pick_leader("")
	UIKit.keyed(builder.picker, "pick:lead").pressed.emit()
	assert_true(UIKit.keyed(builder.builder_list, "army:add_regiment").has_focus())


func test_closing_the_picker_with_cancel_returns_focus_to_its_opener() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder, "army:add_aux").grab_focus()
	builder.pick_auxiliary()
	_press_cancel(builder)
	assert_true(UIKit.keyed(builder.builder_list, "army:add_aux").has_focus())


func test_closing_the_picker_focuses_back_when_the_opener_is_gone() -> void:
	var builder := _builder(_valid_army())
	builder.pick_tactic(0)
	builder.picker.close()
	assert_true(builder.back_button.has_focus())


func test_redraw_focuses_back_when_the_focused_control_is_removed() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder.builder_list, "r1:delete").grab_focus()
	builder.editor.remove_regiment("r1")
	assert_true(builder.back_button.has_focus())


# --- available_units ---

func test_available_units_hides_legends_by_default() -> void:
	var builder := _builder(_valid_army())
	var ids := _warscroll_names(builder.available_units(func(_w: Warscroll) -> bool: return true))
	assert_does_not_have(ids, "legend")


func test_available_units_shows_legends_when_enabled() -> void:
	var army := _valid_army()
	army.show_legends = true
	var builder := _builder(army)
	var ids := _warscroll_names(builder.available_units(func(_w: Warscroll) -> bool: return true))
	assert_has(ids, "legend")


func test_available_units_leaves_out_units_the_army_of_renown_roster_does_not_allow() -> void:
	var faction := UIKit.faction()
	var entries: Array[RosterEntry] = [Kit.roster_entry("Lead")]
	faction.armies_of_renown = [Kit.army_of_renown("Horde", entries)] as Array[ArmyOfRenown]
	var army := _valid_army()
	army.army_of_renown = "Horde"
	var builder := _builder(army, faction)
	var ids := _warscroll_names(builder.available_units(func(_w: Warscroll) -> bool: return true))
	assert_true("lead" in ids and not "grunt" in ids, str(ids))


func test_available_units_hides_unique_units_already_in_the_army() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["unique"]))
	var builder := _builder(army)
	var ids := _warscroll_names(builder.available_units(func(_w: Warscroll) -> bool: return true))
	assert_does_not_have(ids, "unique")


func test_available_units_offers_unique_units_not_yet_in_the_army() -> void:
	var builder := _builder(_valid_army())
	var ids := _warscroll_names(builder.available_units(func(_w: Warscroll) -> bool: return true))
	assert_has(ids, "unique")


func test_available_units_offers_taken_unique_units_when_overridden() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["unique"]))
	army.override_constraints = true
	var builder := _builder(army)
	var ids := _warscroll_names(builder.available_units(func(_w: Warscroll) -> bool: return true))
	assert_has(ids, "unique")


func test_available_units_leaves_out_terrain() -> void:
	var builder := _builder(_valid_army())
	var ids := _warscroll_names(builder.available_units(func(_w: Warscroll) -> bool: return true))
	assert_does_not_have(ids, "terrain")


func test_available_units_applies_the_filter() -> void:
	var builder := _builder(_valid_army())
	var ids := _warscroll_names(builder.available_units(func(w: Warscroll) -> bool: return w.has_keyword("BEAST")))
	assert_eq(ids, PackedStringArray(["beast"]))


func test_available_units_are_sorted_by_name() -> void:
	var builder := _builder(_valid_army())
	var names: Array = builder.available_units(func(_w: Warscroll) -> bool: return true).map(func(w: Warscroll) -> String: return w.name)
	var sorted := names.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	assert_eq(names, sorted)


# --- pick_unit restrictions ---

func test_pick_unit_lists_only_units_the_leaders_options_allow() -> void:
	var builder := _builder(_valid_army())
	builder.pick_unit("r1")
	var ids := _pick_ids(builder)
	assert_has(ids, "grunt")
	assert_does_not_have(ids, "beast")


func test_pick_unit_lists_every_unit_when_overridden() -> void:
	var army := _valid_army()
	army.override_constraints = true
	var builder := _builder(army)
	builder.pick_unit("r1")
	assert_has(_pick_ids(builder), "beast")


func test_pick_unit_shows_empty_message_when_nothing_is_allowed() -> void:
	var army := UIKit.army_with_regiment()
	var faction := UIKit.faction()
	faction.get_warscroll("lead").regiment_options = PackedStringArray()
	var builder := _builder(army, faction)
	builder.pick_unit("r1")
	assert_eq(_pick_ids(builder).size(), 0)
	assert_true(UIKit.has_label_containing(builder.picker, "No units"))


# --- Esc ---

func test_cancel_closes_an_open_picker_first() -> void:
	var builder := _builder(_valid_army())
	watch_signals(builder)
	builder.pick_tactic(0)
	_press_cancel(builder)
	assert_false(builder.picker.is_open())
	assert_signal_not_emitted(builder, "back_pressed")


func test_cancel_stops_renaming_before_going_back() -> void:
	var builder := _builder(_valid_army())
	watch_signals(builder)
	builder.start_renaming("r1")
	_press_cancel(builder)
	assert_eq(builder.renaming, "")
	assert_signal_not_emitted(builder, "back_pressed")


func test_cancel_closes_picker_before_cancelling_a_rename() -> void:
	var builder := _builder(_valid_army())
	builder.start_renaming("r1")
	builder.pick_tactic(0)
	_press_cancel(builder)
	assert_eq(builder.renaming, "r1")


func test_cancel_with_nothing_open_emits_back_pressed() -> void:
	var builder := _builder(_valid_army())
	watch_signals(builder)
	_press_cancel(builder)
	assert_signal_emitted(builder, "back_pressed")


func test_released_cancel_does_nothing() -> void:
	var builder := _builder(_valid_army())
	watch_signals(builder)
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = false
	builder._unhandled_input(event)
	assert_signal_not_emitted(builder, "back_pressed")


func test_back_button_emits_back_pressed() -> void:
	var builder := _builder(_valid_army())
	watch_signals(builder)
	builder.back_button.pressed.emit()
	assert_signal_emitted(builder, "back_pressed")


# --- Focus ---

func test_open_focuses_the_back_button() -> void:
	var builder := _builder(_valid_army())
	assert_true(builder.back_button.has_focus())


func test_redraw_restores_focus_to_the_control_with_the_same_focus_key() -> void:
	var builder := _builder(_valid_army())
	var before := UIKit.keyed(builder.builder_list, "army:add_aux")
	before.grab_focus()
	builder.redraw()
	var after := UIKit.keyed(builder.builder_list, "army:add_aux")
	assert_ne(after, before)
	assert_true(after.has_focus())


func test_auxiliary_box_is_styled_like_a_regiment_with_a_drag_hint() -> void:
	var builder := _builder(_valid_army())
	assert_eq(builder.auxiliary_box.theme_type_variation, &"RegimentPanel")
	var add := UIKit.keyed(builder.auxiliary_box, "army:add_aux")
	var hints := add.get_parent().get_children().filter(func(n: Node) -> bool: return n is Label)
	assert_eq(hints.size(), 1)
	assert_eq(hints[0].text, "or drag one here")


func test_redraw_after_an_edit_keeps_focus_on_the_edited_control() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	builder.editor.add_auxiliary("grunt")
	var key := "u2:copy"
	UIKit.keyed(builder.builder_list, key).grab_focus()
	UIKit.keyed(builder.builder_list, key).pressed.emit()
	assert_true(UIKit.keyed(builder.builder_list, key).has_focus())


func test_find_focus_key_returns_null_for_unknown_key() -> void:
	var builder := _builder(_valid_army())
	assert_null(ArmyBuilder.find_focus_key(builder, "no:such:key"))


func test_find_focus_key_skips_hidden_controls() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var hidden := Button.new()
	hidden.set_meta(&"focus_key", "k")
	hidden.hide()
	root.add_child(hidden)
	assert_null(ArmyBuilder.find_focus_key(root, "k"))


func test_find_focus_key_finds_nested_visible_control() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var inner := VBoxContainer.new()
	var target := Button.new()
	target.set_meta(&"focus_key", "k")
	inner.add_child(target)
	root.add_child(inner)
	assert_eq(ArmyBuilder.find_focus_key(root, "k"), target)


# --- Renaming ---

func test_start_renaming_shows_a_name_field_for_the_regiment() -> void:
	var builder := _builder(_valid_army())
	builder.start_renaming("r1")
	assert_eq(builder.renaming, "r1")
	assert_true(UIKit.keyed(builder.builder_list, "r1:name") is LineEdit)


func test_regiment_shows_no_name_field_when_not_renaming() -> void:
	var builder := _builder(_valid_army())
	assert_null(UIKit.keyed(builder.builder_list, "r1:name"))


func test_finish_renaming_renames_the_regiment() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	builder.start_renaming("r1")
	builder.finish_renaming("r1", "  The Vanguard ")
	assert_eq(army.regiments[0].name, "The Vanguard")
	assert_eq(builder.renaming, "")


func test_finish_renaming_with_blank_name_keeps_the_old_name() -> void:
	var army := _valid_army()
	var old_name := army.regiments[0].name
	var builder := _builder(army)
	builder.start_renaming("r1")
	builder.finish_renaming("r1", "   ")
	assert_eq(army.regiments[0].name, old_name)
	assert_eq(builder.renaming, "")


func test_finish_renaming_a_regiment_not_being_renamed_does_nothing() -> void:
	var army := _valid_army()
	var old_name := army.regiments[0].name
	var builder := _builder(army)
	builder.finish_renaming("r1", "Other")
	assert_eq(army.regiments[0].name, old_name)


func test_submitting_the_name_field_renames_the_regiment() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	builder.start_renaming("r1")
	(UIKit.keyed(builder.builder_list, "r1:name") as LineEdit).text_submitted.emit("Shield Wall")
	assert_eq(army.regiments[0].name, "Shield Wall")


# --- Faction terrain ---

func test_terrain_section_shown_when_the_faction_has_terrain() -> void:
	var builder := _builder(_valid_army())
	assert_not_null(UIKit.keyed(builder.builder_list, "terrain:terrain"))


func test_terrain_section_hidden_when_the_faction_has_none() -> void:
	var faction := UIKit.faction()
	faction.warscrolls.erase(faction.get_warscroll("terrain"))
	var builder := _builder(_valid_army(), faction)
	assert_false(UIKit.has_label_containing(builder.builder_list, "Faction Terrain"))


func test_terrain_section_hidden_when_the_army_of_renown_forbids_it() -> void:
	var faction := UIKit.faction()
	var renown := Kit.army_of_renown("No Terrain")
	renown.roster.faction_terrain = false
	faction.armies_of_renown.append(renown)
	var army := _valid_army()
	army.army_of_renown = "No Terrain"
	var builder := _builder(army, faction)
	assert_null(UIKit.keyed(builder.builder_list, "terrain:terrain"))


func test_terrain_section_shown_when_the_army_of_renown_allows_it() -> void:
	var faction := UIKit.faction()
	faction.armies_of_renown.append(Kit.army_of_renown("With Terrain"))
	var army := _valid_army()
	army.army_of_renown = "With Terrain"
	var builder := _builder(army, faction)
	assert_not_null(UIKit.keyed(builder.builder_list, "terrain:terrain"))


func test_adding_terrain_sets_it_on_the_army() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	UIKit.keyed(builder.builder_list, "terrain:terrain").pressed.emit()
	assert_eq(army.faction_terrain, "terrain")


func test_removing_terrain_clears_it_from_the_army() -> void:
	var army := _valid_army()
	army.faction_terrain = "terrain"
	var builder := _builder(army)
	UIKit.keyed(builder.builder_list, "terrain:terrain").pressed.emit()
	assert_eq(army.faction_terrain, "")


func test_included_terrain_offers_remove_instead_of_add() -> void:
	var army := _valid_army()
	var builder := _builder(army)
	var before := (UIKit.keyed(builder.builder_list, "terrain:terrain") as Button).text
	builder.editor.set_faction_terrain("terrain")
	var after := (UIKit.keyed(builder.builder_list, "terrain:terrain") as Button).text
	assert_ne(before, after)


func test_included_terrain_remove_is_a_delete_icon_button() -> void:
	var army := _valid_army()
	army.faction_terrain = "terrain"
	var builder := _builder(army)
	var remove := UIKit.keyed(builder.builder_list, "terrain:terrain") as Button
	assert_eq(remove.text, "")
	assert_eq(remove.icon, UITheme.icon("delete"))
	assert_eq(remove.theme_type_variation, &"DangerIconButton")


func test_included_terrain_row_is_not_highlighted() -> void:
	var army := _valid_army()
	army.faction_terrain = "terrain"
	var builder := _builder(army)
	var panel := UIKit.keyed(builder.builder_list, "terrain:terrain").get_parent().get_parent() as PanelContainer
	assert_eq(panel.theme_type_variation, &"RowPanel")


func test_terrain_row_shows_a_portrait() -> void:
	var builder := _builder(_valid_army())
	var row := UIKit.keyed(builder.builder_list, "terrain:terrain").get_parent()
	assert_true(UIKit.find_all(row, func(n: Node) -> bool: return n is ArtPlaceholder).size() > 0)


func test_terrain_abilities_lists_the_universal_terrain_abilities() -> void:
	var terrain := Kit.warscroll("portal", PackedStringArray(["FACTION TERRAIN"]))
	terrain.composition = "The following universal terrain abilities apply to this terrain feature (Terrain, 1.2): Cover, Impassable"
	assert_eq(ArmyBuilder.terrain_abilities(terrain), "Cover, Impassable")


func test_terrain_abilities_falls_back_when_none_are_listed() -> void:
	var terrain := Kit.warscroll("portal", PackedStringArray(["FACTION TERRAIN"]))
	assert_false(ArmyBuilder.terrain_abilities(terrain).is_empty())


# --- Army name ---

func test_army_name_is_shown_as_a_label_until_edited() -> void:
	var builder := _builder(_valid_army())
	assert_null(UIKit.keyed(builder.builder_list, "army:name"))
	assert_true(UIKit.has_label_containing(builder.builder_list, builder.editor.army.name))


func _army_name_label(builder: ArmyBuilder) -> Label:
	return UIKit.find_all(builder.builder_list, func(node: Node) -> bool:
		return node is Label and node.text == builder.editor.army.name)[0]


func test_army_name_label_is_wide_enough_to_show_the_name() -> void:
	var builder := _builder(_valid_army())
	await get_tree().process_frame
	var title := _army_name_label(builder)
	var text_width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			title.get_theme_font_size("font_size")).x
	assert_gte(title.size.x, text_width)


func test_rename_button_is_right_of_the_army_name() -> void:
	var builder := _builder(_valid_army())
	await get_tree().process_frame
	var title := _army_name_label(builder)
	var rename := UIKit.keyed(builder.builder_list, "army:rename") as Control
	assert_gte(rename.global_position.x, title.global_position.x + title.size.x)


func test_rename_button_shows_a_name_field() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder.builder_list, "army:rename").pressed.emit()
	assert_true(UIKit.keyed(builder.builder_list, "army:name") is LineEdit)


func test_name_field_gets_focus_when_editing_starts() -> void:
	var builder := _builder(_valid_army())
	builder.start_editing_name()
	assert_true(UIKit.keyed(builder.builder_list, "army:name").has_focus())


func test_submitting_the_name_field_renames_the_army() -> void:
	var builder := _builder(_valid_army())
	builder.start_editing_name()
	(UIKit.keyed(builder.builder_list, "army:name") as LineEdit).text_submitted.emit("Hammers of Azyr")
	assert_eq(builder.editor.army.name, "Hammers of Azyr")
	assert_false(builder.editing_name)


func test_submitting_the_name_field_focuses_the_rename_button() -> void:
	var builder := _builder(_valid_army())
	builder.start_editing_name()
	(UIKit.keyed(builder.builder_list, "army:name") as LineEdit).text_submitted.emit("Hammers of Azyr")
	assert_true(UIKit.keyed(builder.builder_list, "army:rename").has_focus())


func test_blank_army_name_keeps_the_old_name() -> void:
	var builder := _builder(_valid_army())
	var old_name := builder.editor.army.name
	builder.start_editing_name()
	builder.finish_editing_name("  ")
	assert_eq(builder.editor.army.name, old_name)
	assert_null(UIKit.keyed(builder.builder_list, "army:name"))


func test_cancel_stops_editing_the_army_name_before_going_back() -> void:
	var builder := _builder(_valid_army())
	watch_signals(builder)
	builder.start_editing_name()
	_press_cancel(builder)
	assert_false(builder.editing_name)
	assert_signal_not_emitted(builder, "back_pressed")


# --- Add Regiment of Renown ---

func _renown_faction() -> Faction:
	var faction := UIKit.faction()
	var band := Kit.regiment_of_renown("Band", 150, [Kit.renown_unit("Gotrek", "gotrek")] as Array[RegimentUnit],
			[Kit.warscroll("gotrek", PackedStringArray(["HERO"]))] as Array[Warscroll])
	faction.regiments_of_renown = [band] as Array[RegimentOfRenown]
	return faction


func test_add_regiment_of_renown_shown_without_one() -> void:
	var builder := _builder(_valid_army(), _renown_faction())
	assert_not_null(UIKit.keyed(builder.builder_list, "army:add_ror"))


func test_add_regiment_of_renown_hidden_once_the_army_has_one() -> void:
	var builder := _builder(_valid_army(), _renown_faction())
	builder.editor.add_regiment_of_renown("Band")
	assert_null(UIKit.keyed(builder.builder_list, "army:add_ror"))


func test_add_regiment_of_renown_shown_with_one_when_constraints_are_overridden() -> void:
	var army := _valid_army()
	army.override_constraints = true
	var builder := _builder(army, _renown_faction())
	builder.editor.add_regiment_of_renown("Band")
	assert_not_null(UIKit.keyed(builder.builder_list, "army:add_ror"))


# --- Lore help ---

func _lore_faction() -> Faction:
	var faction := UIKit.faction()
	var lores: Array[Lore] = [Kit.lore("Fire", "spell")]
	faction.lores = lores
	return faction


func test_lores_have_no_help_button() -> void:
	var builder := _builder(_valid_army(), _lore_faction())
	assert_does_not_have(UIKit.label_texts(builder.builder_list), "?")


func test_empty_lore_slot_has_the_help_as_its_tooltip() -> void:
	var builder := _builder(_valid_army(), _lore_faction())
	assert_eq((UIKit.keyed(builder.builder_list, "lore:spell") as Button).tooltip_text, ArmyBuilder.LORE_HELP["spell"])


func test_view_in_rules_shows_the_lores_section() -> void:
	var builder := _builder(_valid_army(), _lore_faction())
	builder.info_pane.folded["sec:Lores"] = true
	(UIKit.keyed(builder.builder_list, "army:view_lores") as Button).pressed.emit()
	assert_eq(builder.info_pane.tab, "rules")
	assert_does_not_have(builder.info_pane.folded, "sec:Lores")
	assert_eq(builder.info_pane.flash_key, "sec:Lores")


func test_no_view_in_rules_without_lores() -> void:
	assert_null(UIKit.keyed(_builder(_valid_army()).builder_list, "army:view_lores"))


func test_empty_lore_slot_is_warning_coloured_when_a_wizard_has_no_spell_lore() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["wizard"])), _lore_faction())
	var slot := UIKit.keyed(builder.builder_list, "lore:spell") as Button
	assert_eq(slot.get_theme_color("font_color"), UITheme.WARNING)


func test_empty_lore_slot_is_not_warning_coloured_without_a_wizard() -> void:
	var builder := _builder(_valid_army(), _lore_faction())
	var slot := UIKit.keyed(builder.builder_list, "lore:spell") as Button
	assert_ne(slot.get_theme_color("font_color"), UITheme.WARNING)


func test_lore_section_missing_when_faction_has_no_lores() -> void:
	var builder := _builder(_valid_army())
	assert_null(UIKit.keyed(builder.builder_list, "lore:spell"))


func test_choosing_a_lore_in_the_picker_sets_it_on_the_army() -> void:
	var army := _valid_army()
	var builder := _builder(army, _lore_faction())
	(UIKit.keyed(builder.builder_list, "lore:spell") as Button).pressed.emit()
	(UIKit.keyed(builder.picker, "pick:lore:Fire") as LoreCard).pressed.emit()
	assert_eq(army.spell_lore, "Fire")
	assert_false(builder.picker.is_open())


# --- Tactics ---

func test_tactic_slot_without_a_card_offers_to_choose_one() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	assert_not_null(UIKit.keyed(builder.builder_list, "tactic:0"))
	assert_string_starts_with(UIKit.keyed(builder.builder_list, "tactic:0").text, "Choose")


func test_tactic_slot_with_a_card_offers_to_change_it() -> void:
	var builder := _builder(_valid_army())
	assert_eq(UIKit.keyed(builder.builder_list, "tactic:0").text, "Change")


# --- Info pane integration ---

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


func test_builder_creates_an_info_pane_in_the_left_pane() -> void:
	var builder := _builder(_valid_army())
	assert_not_null(builder.info_pane)
	assert_true(builder.left_pane.is_ancestor_of(builder.info_pane))


func test_info_pane_shows_the_factions_roster_after_opening() -> void:
	var builder := _builder(_valid_army())
	assert_not_null(UIKit.keyed(builder.info_pane, "info:card:grunt"))


func test_clicking_a_short_tactic_card_shows_it_in_the_rules_tab() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder.builder_list, "tactic_card:1").gui_input.emit(_click())
	assert_eq(builder.info_pane.tab, "rules")
	assert_eq(builder.info_pane.flash_key, "tactic:Card B")


func test_enter_on_a_short_tactic_card_shows_it_in_the_rules_tab() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder.builder_list, "tactic_card:0").gui_input.emit(_accept())
	assert_eq(builder.info_pane.tab, "rules")
	assert_eq(builder.info_pane.flash_key, "tactic:Card A")


func test_other_keys_on_a_tactic_card_do_nothing() -> void:
	var builder := _builder(_valid_army())
	var event := InputEventAction.new()
	event.action = "ui_down"
	event.pressed = true
	UIKit.keyed(builder.builder_list, "tactic_card:0").gui_input.emit(event)
	assert_eq(builder.info_pane.tab, "roster")


func test_tactic_card_is_focusable_and_has_a_tooltip() -> void:
	var card := UIKit.keyed(_builder(_valid_army()).builder_list, "tactic_card:0")
	assert_eq(card.focus_mode, Control.FOCUS_ALL)
	assert_string_contains(card.tooltip_text, "Card A")


func test_the_change_button_still_opens_the_picker_rather_than_the_link() -> void:
	var builder := _builder(_valid_army())
	UIKit.keyed(builder.builder_list, "tactic:0").pressed.emit()
	assert_true(builder.picker.is_open())
	assert_eq(builder.info_pane.tab, "roster")


func test_clicking_a_chosen_lore_shows_it_in_the_rules_tab() -> void:
	var army := UIKit.army_with_regiment()
	army.spell_lore = "Fire"
	var builder := _builder(army, _lore_faction())
	UIKit.keyed(builder.builder_list, "lore_card:spell").gui_input.emit(_click())
	assert_eq(builder.info_pane.tab, "rules")
	assert_has(builder.info_pane.open_lores, "Fire")
	assert_eq(builder.info_pane.flash_key, "lore:Fire")


func test_removing_a_lore_does_not_switch_tab() -> void:
	var army := UIKit.army_with_regiment()
	army.spell_lore = "Fire"
	var builder := _builder(army, _lore_faction())
	(UIKit.keyed(builder.builder_list, "lore_remove:spell") as Button).pressed.emit()
	assert_eq(army.spell_lore, "")
	assert_eq(builder.info_pane.tab, "roster")


func test_army_changes_refresh_the_visible_info_pane() -> void:
	var builder := _builder(_valid_army())
	builder.info_pane.set_tab("rules")
	builder.editor.set_lore("spell", "Fire")
	assert_eq(builder.info_pane.tab, "rules")


func test_the_info_pane_is_hidden_while_the_picker_is_open() -> void:
	var builder := _builder(_valid_army())
	builder.pick_auxiliary()
	assert_false(builder.info_pane.visible)


func test_closing_the_picker_shows_the_info_pane_up_to_date() -> void:
	var builder := _builder(_valid_army())
	builder.pick_auxiliary()
	builder.editor.set_show_legends(true)
	builder.picker.close()
	assert_true(builder.info_pane.visible)
	assert_not_null(UIKit.keyed(builder.info_pane, "info:card:legend"))


# --- Saving and leaving ---

func _edited_builder() -> ArmyBuilder:
	var builder := _builder(UIKit.army_with_regiment())
	builder.editor.set_points_limit(1234)
	return builder


func _saved_builder() -> ArmyBuilder:
	var builder := _builder(UIKit.army_with_regiment())
	assert_true(builder.save())
	return builder


func test_opened_army_is_not_dirty() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	assert_false(builder.dirty)


func test_editing_the_army_makes_it_dirty() -> void:
	var builder := _edited_builder()
	assert_true(builder.dirty)


func test_reopening_clears_dirty() -> void:
	var builder := _edited_builder()
	builder.open(UIKit.army_with_regiment(), Kit.catalog(UIKit.faction()))
	assert_false(builder.dirty)


func test_unsaved_new_army_offers_to_save() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	assert_eq(builder.save_button.text, "Save army")
	assert_false(builder.save_button.disabled)


func test_saved_unchanged_army_shows_saved_and_disables_the_button() -> void:
	var builder := _saved_builder()
	assert_eq(builder.save_button.text, "Saved")
	assert_true(builder.save_button.disabled)


func test_opening_an_army_that_has_an_id_shows_saved() -> void:
	var army := UIKit.army_with_regiment()
	ArmyStore.save(army)
	var builder := _builder(army)
	assert_true(builder.save_button.disabled)


func test_editing_a_saved_army_enables_the_save_button() -> void:
	var builder := _saved_builder()
	builder.editor.set_points_limit(999)
	assert_eq(builder.save_button.text, "Save army")
	assert_false(builder.save_button.disabled)


func test_save_writes_the_army_to_the_store() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	builder.save()
	var saved := ArmyStore.load_army(builder.editor.army.id)
	assert_not_null(saved)
	assert_eq(saved.name, builder.editor.army.name)


func test_save_assigns_the_army_an_id() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	builder.save()
	assert_false(builder.editor.army.id.is_empty())


func test_save_clears_dirty() -> void:
	var builder := _edited_builder()
	builder.save()
	assert_false(builder.dirty)


func test_save_stores_the_latest_edits() -> void:
	var builder := _edited_builder()
	builder.save()
	assert_eq(ArmyStore.load_army(builder.editor.army.id).points_limit, 1234)


func test_saving_twice_keeps_one_file() -> void:
	var builder := _edited_builder()
	builder.save()
	builder.editor.set_points_limit(500)
	builder.save()
	assert_eq(ArmyStore.list().size(), 1)


func test_save_tooltip_names_the_shortcut_once() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	var shortcut := builder.save_button.shortcut.get_as_text()
	assert_string_contains(builder.save_button.tooltip_text, shortcut)
	# Godot would otherwise add the shortcut to the tooltip a second time.
	assert_false(builder.save_button.shortcut_in_tooltip)


func test_pressing_the_save_button_saves() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	builder.save_button.pressed.emit()
	assert_eq(ArmyStore.list().size(), 1)


func test_save_commits_text_still_being_typed_in_the_name_field() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	builder.start_editing_name()
	var edit := UIKit.keyed(builder, "army:name") as LineEdit
	edit.grab_focus()
	edit.text = "Typed name"
	builder.save()
	assert_eq(ArmyStore.load_army(builder.editor.army.id).name, "Typed name")


func test_failed_save_returns_false_and_stays_dirty() -> void:
	var builder := _edited_builder()
	# A file where the directory should be, so it can't be created.
	var blocker := Sandbox.armies_directory()
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.close()
	var saved := builder.save()
	assert_false(saved)
	assert_true(builder.dirty)
	assert_push_error_count(1)
	DirAccess.remove_absolute(blocker)


func test_failed_save_tells_the_player() -> void:
	var builder := _edited_builder()
	var file := FileAccess.open(Sandbox.armies_directory(), FileAccess.WRITE)
	file.close()
	builder.save()
	var dialogs := UIKit.find_all(builder, func(n: Node) -> bool: return n is AcceptDialog and not n is ConfirmationDialog)
	assert_eq(dialogs.size(), 1)
	assert_push_error_count(1)
	DirAccess.remove_absolute(Sandbox.armies_directory())


func test_request_back_without_changes_goes_back() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	watch_signals(builder)
	builder.request_back()
	assert_signal_emitted(builder, "back_pressed")
	assert_false(builder.discard_dialog.visible)


func test_request_back_with_changes_asks_first() -> void:
	var builder := _edited_builder()
	watch_signals(builder)
	builder.request_back()
	assert_signal_not_emitted(builder, "back_pressed")
	assert_true(builder.discard_dialog.visible)


func test_request_back_after_saving_goes_back() -> void:
	var builder := _edited_builder()
	builder.save()
	watch_signals(builder)
	builder.request_back()
	assert_signal_emitted(builder, "back_pressed")


func test_back_button_asks_when_there_are_changes() -> void:
	var builder := _edited_builder()
	watch_signals(builder)
	builder.back_button.pressed.emit()
	assert_true(builder.discard_dialog.visible)
	assert_signal_not_emitted(builder, "back_pressed")


func test_cancel_key_asks_when_there_are_changes() -> void:
	var builder := _edited_builder()
	watch_signals(builder)
	_press_cancel(builder)
	assert_true(builder.discard_dialog.visible)
	assert_signal_not_emitted(builder, "back_pressed")


func test_cancel_key_goes_back_without_changes() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	watch_signals(builder)
	_press_cancel(builder)
	assert_signal_emitted(builder, "back_pressed")


func test_dialog_cancel_button_is_focused() -> void:
	var builder := _edited_builder()
	builder.request_back()
	assert_true(builder.discard_dialog.get_cancel_button().has_focus())


func test_dialog_discard_goes_back_without_saving() -> void:
	var builder := _edited_builder()
	builder.request_back()
	watch_signals(builder)
	builder.discard_dialog.confirmed.emit()
	assert_signal_emitted(builder, "back_pressed")
	assert_eq(ArmyStore.list().size(), 0)


func test_dialog_keep_editing_stays_dirty_and_does_not_go_back() -> void:
	var builder := _edited_builder()
	builder.request_back()
	watch_signals(builder)
	builder.discard_dialog.canceled.emit()
	assert_signal_not_emitted(builder, "back_pressed")
	assert_true(builder.dirty)
	assert_eq(ArmyStore.list().size(), 0)


func test_dialog_save_saves_then_goes_back() -> void:
	var builder := _edited_builder()
	builder.request_back()
	watch_signals(builder)
	builder.discard_dialog.custom_action.emit(&"save")
	assert_signal_emitted(builder, "back_pressed")
	assert_eq(ArmyStore.load_army(builder.editor.army.id).points_limit, 1234)


func test_dialog_save_does_not_go_back_when_saving_fails() -> void:
	var builder := _edited_builder()
	var file := FileAccess.open(Sandbox.armies_directory(), FileAccess.WRITE)
	file.close()
	watch_signals(builder)
	builder.discard_dialog.custom_action.emit(&"save")
	assert_signal_not_emitted(builder, "back_pressed")
	assert_push_error_count(1)
	DirAccess.remove_absolute(Sandbox.armies_directory())


# --- Lore slots ---

func _two_spell_faction() -> Faction:
	var faction := UIKit.faction()
	var lores: Array[Lore] = [Kit.lore("Fire", "spell"), Kit.lore("Ice", "spell"), Kit.lore("Hymns", "prayer")]
	faction.lores = lores
	return faction


func test_empty_lore_slot_is_a_dashed_button() -> void:
	var slot := UIKit.keyed(_builder(_valid_army(), _lore_faction()).builder_list, "lore:spell") as Button
	assert_eq(slot.theme_type_variation, &"DashedButton")


func test_empty_tactic_slot_is_a_dashed_button() -> void:
	var slot := UIKit.keyed(_builder(UIKit.army_with_regiment()).builder_list, "tactic:0") as Button
	assert_eq(slot.theme_type_variation, &"DashedButton")


func test_empty_lore_slot_opens_the_picker_with_the_kinds_title() -> void:
	var builder := _builder(_valid_army(), _lore_faction())
	(UIKit.keyed(builder.builder_list, "lore:spell") as Button).pressed.emit()
	assert_true(builder.picker.is_open())
	assert_has(UIKit.label_texts(builder.picker), RulesSections.LORE_KINDS["spell"])


func test_a_kind_without_lores_has_no_slot() -> void:
	var builder := _builder(_valid_army(), _lore_faction())
	assert_not_null(UIKit.keyed(builder.builder_list, "lore:spell"))
	assert_null(UIKit.keyed(builder.builder_list, "lore:prayer"))


func test_a_chosen_lore_is_a_card_with_a_change_button_instead_of_the_dashed_slot() -> void:
	var army := _valid_army()
	army.spell_lore = "Fire"
	var builder := _builder(army, _lore_faction())
	assert_true(UIKit.keyed(builder.builder_list, "lore_card:spell") is LoreCard)
	assert_eq(UIKit.keyed(builder.builder_list, "lore:spell").text, "Change")


func test_a_chosen_lore_card_is_short() -> void:
	var army := _valid_army()
	army.spell_lore = "Fire"
	var faction := _lore_faction()
	faction.lores[0].entries = [Kit.ability("Scorch")] as Array[Ability]
	var card := UIKit.keyed(_builder(army, faction).builder_list, "lore_card:spell")
	assert_has(UIKit.label_texts(card), "SCORCH")
	assert_eq(UIKit.find_all(card, func(n: Node) -> bool: return n is RichTextLabel).size(), 0)


func test_change_opens_the_picker_without_the_chosen_lore() -> void:
	var army := _valid_army()
	army.spell_lore = "Fire"
	var builder := _builder(army, _two_spell_faction())
	(UIKit.keyed(builder.builder_list, "lore:spell") as Button).pressed.emit()
	assert_true(builder.picker.is_open())
	assert_null(UIKit.keyed(builder.picker, "pick:lore:Fire"))
	assert_not_null(UIKit.keyed(builder.picker, "pick:lore:Ice"))


func test_choosing_another_lore_in_the_picker_replaces_the_chosen_one() -> void:
	var army := _valid_army()
	army.spell_lore = "Fire"
	var builder := _builder(army, _two_spell_faction())
	builder.pick_lore("spell")
	(UIKit.keyed(builder.picker, "pick:lore:Ice") as LoreCard).pressed.emit()
	assert_eq(army.spell_lore, "Ice")
	assert_true(UIKit.keyed(builder.builder_list, "lore_card:spell") is LoreCard)


func test_removing_a_lore_shows_the_empty_slot_and_focuses_it() -> void:
	var army := _valid_army()
	army.spell_lore = "Fire"
	var builder := _builder(army, _two_spell_faction())
	(UIKit.keyed(builder.builder_list, "lore_remove:spell") as Button).pressed.emit()
	await get_tree().process_frame
	var slot := UIKit.keyed(builder.builder_list, "lore:spell") as Button
	assert_eq(slot.theme_type_variation, &"DashedButton")
	assert_true(slot.has_focus())


func test_remove_lore_clears_only_that_kind() -> void:
	var army := _valid_army()
	army.spell_lore = "Fire"
	army.prayer_lore = "Hymns"
	var builder := _builder(army, _two_spell_faction())
	builder.remove_lore("spell")
	assert_eq(army.spell_lore, "")
	assert_eq(army.prayer_lore, "Hymns")


func test_picking_a_leader_for_a_leaderless_regiment_puts_it_first() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.regiments[0].units.remove_at(0)
	army.regiments[0].leaderless = true
	var builder := _builder(army)
	builder.pick_leader("r1")
	UIKit.keyed(builder.picker, "pick:lead").pressed.emit()
	var regiment := army.regiments[0]
	assert_false(regiment.leaderless)
	assert_eq(regiment.units.size(), 2)
	assert_eq(regiment.leader().warscroll_id, "lead")


# --- Army of Renown and battle formation slots ---

func _choice_faction() -> Faction:
	var faction := UIKit.faction()
	faction.armies_of_renown.append(Kit.army_of_renown("Wanderers"))
	faction.battle_formations = [Kit.formation("Vanguard"), Kit.formation("Siege")] as Array[BattleFormation]
	return faction


func test_removing_the_army_of_renown_focuses_the_empty_slot() -> void:
	var army := _valid_army()
	army.army_of_renown = "Wanderers"
	var builder := _builder(army, _choice_faction())
	builder.info_pane.set_tab("settings")
	UIKit.keyed(builder.info_pane, "info:aor_remove").grab_focus()
	builder.remove_army_of_renown()
	assert_true(UIKit.keyed(builder.info_pane, "info:aor").has_focus())


func test_removing_the_formation_focuses_the_empty_slot() -> void:
	var army := _valid_army()
	army.formation = "Siege"
	var builder := _builder(army, _choice_faction())
	builder.info_pane.set_tab("settings")
	UIKit.keyed(builder.info_pane, "info:formation_remove").grab_focus()
	builder.remove_formation()
	assert_true(UIKit.keyed(builder.info_pane, "info:formation").has_focus())


func test_closing_the_picker_after_picking_an_army_of_renown_focuses_its_slot() -> void:
	var builder := _builder(_valid_army(), _choice_faction())
	builder.info_pane.set_tab("settings")
	UIKit.keyed(builder.info_pane, "info:aor").grab_focus()
	builder.pick_army_of_renown()
	UIKit.keyed(builder.picker, "pick:aor:Wanderers").pressed.emit()
	assert_true(UIKit.keyed(builder.info_pane, "info:aor").has_focus())


func test_closing_the_picker_after_picking_a_formation_focuses_its_slot() -> void:
	var builder := _builder(_valid_army(), _choice_faction())
	builder.info_pane.set_tab("settings")
	UIKit.keyed(builder.info_pane, "info:formation").grab_focus()
	builder.pick_formation()
	UIKit.keyed(builder.picker, "pick:formation:Siege").pressed.emit()
	assert_true(UIKit.keyed(builder.info_pane, "info:formation").has_focus())
