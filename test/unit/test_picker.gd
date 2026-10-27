extends GutTest
## Unit tests for the builder's picker (scripts/ui/forge/builder/picker.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


## Redrawn lists are removed with queue_free, so let a frame pass for them to be freed before GUT
## counts orphans.
func after_each() -> void:
	await get_tree().process_frame


func _core() -> CoreRules:
	return Kit.core(PackedStringArray(["Card A", "Card B"]))


func _builder(army: Army = null, faction: Faction = null) -> ArmyBuilder:
	return UIKit.builder(self, army if army else UIKit.army_with_regiment(), faction, _core())


func _faction_with_renown(renown: Array[RegimentOfRenown]) -> Faction:
	var faction := UIKit.faction()
	faction.regiments_of_renown = renown
	return faction


func _band(band_name := "Band", legends := false) -> RegimentOfRenown:
	var band := Kit.regiment_of_renown(band_name, 150, [Kit.renown_unit("Gotrek", "gotrek")] as Array[RegimentUnit],
			[Kit.warscroll("gotrek", PackedStringArray(["HERO"]))] as Array[Warscroll])
	band.legends = legends
	return band


func _warscrolls(ids: PackedStringArray) -> Callable:
	var scrolls: Array[Warscroll] = []
	for id in ids:
		scrolls.append(Kit.warscroll(id))
	return func() -> Array[Warscroll]: return scrolls


# --- Units ---

func test_open_units_adds_a_choice_per_warscroll() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a", "b"])), func(_id: String) -> void: pass)
	assert_not_null(UIKit.keyed(builder.picker, "pick:a"))
	assert_not_null(UIKit.keyed(builder.picker, "pick:b"))


func test_open_units_marks_the_picker_open() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a"])), func(_id: String) -> void: pass)
	assert_true(builder.picker.is_open())


func test_open_units_choice_calls_back_with_the_warscroll_id() -> void:
	var builder := _builder()
	var picked := []
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a", "b"])), func(id: String) -> void: picked.append(id))
	UIKit.keyed(builder.picker, "pick:b").pressed.emit()
	assert_eq(picked, ["b"])


func test_open_units_choices_are_labelled_add() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a"])), func(_id: String) -> void: pass)
	assert_eq((UIKit.keyed(builder.picker, "pick:a") as Button).text, "Add")


func test_open_units_shows_a_message_when_the_list_is_empty() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray()), func(_id: String) -> void: pass)
	assert_true(UIKit.has_label_containing(builder.picker, "No units"))


func test_open_units_focuses_the_first_choice() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a", "b"])), func(_id: String) -> void: pass)
	assert_true(UIKit.keyed(builder.picker, "pick:a").has_focus())


func test_open_units_with_nothing_to_pick_focuses_the_close_button() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray()), func(_id: String) -> void: pass)
	assert_true(UIKit.keyed(builder.picker, "picker:close").has_focus())


func test_open_units_title_is_shown() -> void:
	var builder := _builder()
	builder.picker.open_units("Choose a thing", _warscrolls(PackedStringArray(["a"])), func(_id: String) -> void: pass)
	assert_true(UIKit.has_label_containing(builder.picker, "Choose a thing"))


func test_refresh_redraws_the_list_from_the_callable() -> void:
	var builder := _builder()
	var ids := PackedStringArray(["a"])
	var scrolls := func() -> Array[Warscroll]:
		var result: Array[Warscroll] = []
		for id in ids:
			result.append(Kit.warscroll(id))
		return result
	builder.picker.open_units("Pick", scrolls, func(_id: String) -> void: pass)
	ids.append("b")
	builder.picker.refresh()
	await get_tree().process_frame
	assert_not_null(UIKit.keyed(builder.picker, "pick:b"))


func test_close_button_closes_the_picker() -> void:
	var builder := _builder()
	builder.pick_auxiliary()
	UIKit.keyed(builder.picker, "picker:close").pressed.emit()
	assert_false(builder.picker.is_open())


func test_close_emits_closed() -> void:
	var builder := _builder()
	watch_signals(builder.picker)
	builder.pick_auxiliary()
	builder.picker.close()
	assert_signal_emitted(builder.picker, "closed")


func test_refresh_does_nothing_when_closed() -> void:
	var builder := _builder()
	builder.picker.refresh()
	assert_false(builder.picker.is_open())


# --- Tactics ---

func test_open_tactics_lists_each_card_with_a_choose_button() -> void:
	var builder := _builder()
	builder.picker.open_tactics(0)
	assert_eq((UIKit.keyed(builder.picker, "pick:Card A") as Button).text, "Choose")
	assert_not_null(UIKit.keyed(builder.picker, "pick:Card B"))


func test_choosing_a_card_fills_the_slot_and_closes() -> void:
	var army := Kit.army()
	var builder := _builder(army)
	builder.picker.open_tactics(1)
	UIKit.keyed(builder.picker, "pick:Card B").pressed.emit()
	assert_eq(army.tactics[1], "Card B")
	assert_false(builder.picker.is_open())


func test_the_slots_current_card_is_disabled_and_chosen() -> void:
	var army := Kit.army()
	army.tactics = PackedStringArray(["Card A", ""])
	var builder := _builder(army)
	builder.picker.open_tactics(0)
	var current := UIKit.keyed(builder.picker, "pick:Card A") as Button
	assert_true(current.disabled)
	assert_eq(current.text, "Chosen")
	assert_false((UIKit.keyed(builder.picker, "pick:Card B") as Button).disabled)


func test_tactic_title_names_the_slot() -> void:
	var builder := _builder()
	builder.picker.open_tactics(1)
	assert_true(UIKit.has_label_containing(builder.picker, "2"))


# --- Regiments of Renown ---

func test_open_regiments_of_renown_lists_available_regiments() -> void:
	var faction := _faction_with_renown([_band("Band"), _band("Other")] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	assert_not_null(UIKit.keyed(builder.picker, "pick:Band"))
	assert_not_null(UIKit.keyed(builder.picker, "pick:Other"))


func test_regiments_of_renown_hides_legends_unless_shown() -> void:
	var faction := _faction_with_renown([_band("Old Band", true)] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	assert_null(UIKit.keyed(builder.picker, "pick:Old Band"))


func test_regiments_of_renown_shows_legends_when_enabled() -> void:
	var faction := _faction_with_renown([_band("Old Band", true)] as Array[RegimentOfRenown])
	var army := UIKit.army_with_regiment()
	army.show_legends = true
	var builder := _builder(army, faction)
	builder.picker.open_regiments_of_renown()
	assert_not_null(UIKit.keyed(builder.picker, "pick:Old Band"))


func test_regiments_of_renown_shows_a_message_when_there_are_none() -> void:
	var builder := _builder()
	builder.picker.open_regiments_of_renown()
	assert_true(UIKit.has_label_containing(builder.picker, "can't include any"))


func test_regiments_of_renown_empty_when_the_army_of_renown_forbids_them() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var renown := Kit.army_of_renown("Solo")
	renown.roster.regiments_of_renown = false
	faction.armies_of_renown.append(renown)
	var army := UIKit.army_with_regiment()
	army.army_of_renown = "Solo"
	var builder := _builder(army, faction)
	builder.picker.open_regiments_of_renown()
	assert_null(UIKit.keyed(builder.picker, "pick:Band"))


func test_adding_a_regiment_of_renown_adds_it_and_closes() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var army := UIKit.army_with_regiment()
	var builder := _builder(army, faction)
	builder.picker.open_regiments_of_renown()
	UIKit.keyed(builder.picker, "pick:Band").pressed.emit()
	assert_true(army.regiments.any(func(r: ArmyRegiment) -> bool: return r.regiment_of_renown == "Band"))
	assert_false(builder.picker.is_open())


func test_adding_a_second_regiment_of_renown_keeps_the_picker_open() -> void:
	var faction := _faction_with_renown([_band("Band"), _band("Other")] as Array[RegimentOfRenown])
	var army := UIKit.army_with_regiment()
	var builder := _builder(army, faction)
	builder.editor.add_regiment_of_renown("Band")
	builder.picker.open_regiments_of_renown()
	UIKit.keyed(builder.picker, "pick:Other").pressed.emit()
	assert_true(builder.picker.is_open())


func _rich_count(builder: ArmyBuilder) -> int:
	return UIKit.find_all(builder.picker, func(n: Node) -> bool: return n is RichTextLabel).size()


func test_warscrolls_toggle_starts_as_show() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	var toggle := UIKit.keyed(builder.picker, "scrolls:Band") as Button
	assert_string_starts_with(toggle.text, "Show")
	assert_false(toggle.button_pressed)


func test_showing_warscrolls_adds_the_warscroll_text_and_flips_the_toggle() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	var before := _rich_count(builder)
	(UIKit.keyed(builder.picker, "scrolls:Band") as Button).button_pressed = true
	await get_tree().process_frame
	assert_gt(_rich_count(builder), before)
	assert_string_starts_with((UIKit.keyed(builder.picker, "scrolls:Band") as Button).text, "Hide")


func test_hiding_warscrolls_removes_the_warscroll_text() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	var before := _rich_count(builder)
	(UIKit.keyed(builder.picker, "scrolls:Band") as Button).button_pressed = true
	await get_tree().process_frame
	(UIKit.keyed(builder.picker, "scrolls:Band") as Button).button_pressed = false
	await get_tree().process_frame
	assert_eq(_rich_count(builder), before)
	assert_string_starts_with((UIKit.keyed(builder.picker, "scrolls:Band") as Button).text, "Show")
