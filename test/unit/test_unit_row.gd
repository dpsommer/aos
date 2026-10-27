extends GutTest
## Unit tests for a unit's row in the army list (scripts/ui/forge/builder/unit_row.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


## Redrawn sections are removed with queue_free, so let a frame pass for them to be freed before
## GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame


func _builder(army: Army, faction: Faction = null) -> ArmyBuilder:
	return UIKit.builder(self, army, faction)


## A row for the unit with [param uid], as the army list would draw it.
func _row(builder: ArmyBuilder, uid: String) -> UnitRow:
	var unit := builder.editor.army.find_unit(uid)
	var row := UnitRow.new(builder, unit, builder.editor.army.regiment_of(uid))
	add_child_autofree(row)
	return row


func _faction_with(scroll_id: String, change: Callable) -> Faction:
	var faction := UIKit.faction()
	change.call(faction.get_warscroll(scroll_id))
	return faction


func _tables(builder: ArmyBuilder, types: PackedStringArray) -> void:
	var tables: Array[EnhancementTable] = []
	for type in types:
		tables.append(Kit.table(type, [Kit.ability("Boon A"), Kit.ability("Boon B", 20)] as Array[Ability]))
	builder.catalog.faction.enhancement_tables = tables


# --- Which buttons appear ---

## The button with focus key suffix [param action] (e.g. "copy") on [param row]'s unit, or null.
func _btn(row: UnitRow, action: String) -> Button:
	return UIKit.keyed(row, "%s:%s" % [row.unit.uid, action]) as Button


func test_regiment_leader_has_a_general_button() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u1")
	assert_not_null(_btn(row, "general"))


func test_regiment_member_has_no_general_button() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_null(_btn(row, "general"))


func test_auxiliary_unit_has_no_general_button() -> void:
	var army := UIKit.army_with_regiment()
	army.auxiliary.append(Kit.unit("a1", "grunt"))
	var row := _row(_builder(army), "a1")
	assert_null(_btn(row, "general"))


func test_general_button_is_pressed_for_the_general() -> void:
	var row := _row(_builder(UIKit.army_with_regiment()), "u1")
	assert_true(_btn(row, "general").button_pressed)


func test_pressing_general_makes_the_leader_the_general() -> void:
	var army := UIKit.army_with_regiment()
	army.general_uid = ""
	var row := _row(_builder(army), "u1")
	_btn(row, "general").button_pressed = true
	assert_eq(army.general_uid, "u1")


func test_unpressing_general_clears_the_general() -> void:
	var army := UIKit.army_with_regiment()
	var row := _row(_builder(army), "u1")
	_btn(row, "general").button_pressed = false
	assert_eq(army.general_uid, "")


func test_reinforce_button_appears_when_the_warscroll_can_reinforce() -> void:
	var faction := _faction_with("grunt", func(w: Warscroll) -> void: w.can_reinforce = true)
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])), faction), "u2")
	assert_not_null(_btn(row, "reinforce"))


func test_reinforce_button_missing_when_the_warscroll_cannot_reinforce() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_null(_btn(row, "reinforce"))


func test_pressing_reinforce_reinforces_the_unit() -> void:
	var faction := _faction_with("grunt", func(w: Warscroll) -> void: w.can_reinforce = true)
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var row := _row(_builder(army, faction), "u2")
	_btn(row, "reinforce").button_pressed = true
	assert_true(army.find_unit("u2").reinforced)


func test_reinforced_unit_button_says_reinforced() -> void:
	var faction := _faction_with("grunt", func(w: Warscroll) -> void: w.can_reinforce = true)
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").reinforced = true
	var row := _row(_builder(army, faction), "u2")
	assert_true(_btn(row, "reinforce").button_pressed)
	assert_string_contains(_btn(row, "reinforce").tooltip_text, "Unreinforce")


func test_pressing_options_expands_the_unit() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])))
	var row := _row(builder, "u2")
	_btn(row, "options").button_pressed = true
	assert_true(builder.expanded.has("u2"))


func test_pressing_copy_adds_a_copy_after_the_unit() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var row := _row(_builder(army), "u2")
	_btn(row, "copy").pressed.emit()
	assert_eq(army.regiments[0].units.size(), 3)
	assert_eq(army.regiments[0].units[2].warscroll_id, "grunt")


func test_pressing_remove_removes_the_unit() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var row := _row(_builder(army), "u2")
	_btn(row, "remove").pressed.emit()
	assert_null(army.find_unit("u2"))


func _army_with_renown_regiment() -> Army:
	var army := Kit.army()
	army.regiments.append(Kit.ror_regiment("r9", "Band", [Kit.unit("u9", "grunt")] as Array[ArmyUnit]))
	return army


func test_regiment_of_renown_units_have_no_editing_buttons() -> void:
	var row := _row(_builder(_army_with_renown_regiment()), "u9")
	var editing := UIKit.buttons(row).filter(func(b: Button) -> bool: return b.theme_type_variation != "PortraitButton")
	assert_eq(editing.size(), 0, str(UIKit.button_texts(row)))


func test_regiment_of_renown_unit_portrait_links_to_the_regiments_of_renown_tab() -> void:
	var builder := _builder(_army_with_renown_regiment())
	var row := _row(builder, "u9")
	var portrait: Button = UIKit.buttons(row).filter(func(b: Button) -> bool: return b.theme_type_variation == "PortraitButton")[0]
	portrait.pressed.emit()
	assert_eq(builder.info_pane.tab, "renown")
	assert_eq(builder.info_pane.flash_key, "ror:Band")


func test_faction_unit_portrait_links_to_the_roster() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])))
	var row := _row(builder, "u2")
	var portrait: Button = UIKit.buttons(row).filter(func(b: Button) -> bool: return b.theme_type_variation == "PortraitButton")[0]
	portrait.pressed.emit()
	assert_eq(builder.info_pane.tab, "roster")
	assert_eq(builder.info_pane.selected, "grunt")


func test_unit_missing_from_the_faction_has_a_plain_portrait() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["gone"]))
	var row := _row(_builder(army), "u2")
	assert_eq(UIKit.buttons(row).filter(func(b: Button) -> bool: return b.theme_type_variation == "PortraitButton").size(), 0)


func test_regiment_of_renown_units_do_not_show_points() -> void:
	var row := _row(_builder(_army_with_renown_regiment()), "u9")
	assert_false(UIKit.has_label_containing(row, " pts"))


func test_unit_in_a_regiment_shows_its_points() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_true(UIKit.has_label_containing(row, " pts"))


func test_unit_with_a_custom_name_shows_it_first() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").label = "Old Bill"
	var row := _row(_builder(army), "u2")
	assert_has(UIKit.label_texts(row), "Old Bill")


func test_unit_missing_from_the_data_is_flagged_and_cannot_be_customised() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["gone"]))
	var row := _row(_builder(army), "u2")
	assert_true(UIKit.has_label_containing(row, "No longer"))
	assert_null(_btn(row, "options"))


# --- Options panel ---

func _expanded_row(builder: ArmyBuilder, uid: String) -> UnitRow:
	builder.expanded[uid] = true
	return _row(builder, uid)


func test_options_panel_hidden_until_expanded() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_null(UIKit.keyed(row, "u2:label"))


func test_options_panel_has_a_name_field() -> void:
	var row := _expanded_row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_true(UIKit.keyed(row, "u2:label") is LineEdit)


func test_submitting_the_name_field_names_the_unit() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var row := _expanded_row(_builder(army), "u2")
	var edit := UIKit.keyed(row, "u2:label") as LineEdit
	edit.text = "Old Bill"
	edit.text_submitted.emit("Old Bill")
	assert_eq(army.find_unit("u2").label, "Old Bill")


func test_hero_gets_a_select_for_every_enhancement_type() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits", "Artefacts of Power", "Monstrous Traits"]))
	var row := _expanded_row(builder, "u1")
	for type in builder.catalog.enhancement_types(builder.editor.army):
		assert_true(UIKit.keyed(row, "u1:enh:" + type) is OptionButton, type)


func test_non_hero_skips_hero_only_enhancement_types() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])))
	_tables(builder, PackedStringArray(ArmyValidator.HERO_ENHANCEMENTS) + PackedStringArray(["Monstrous Traits"]))
	var row := _expanded_row(builder, "u2")
	for type in ArmyValidator.HERO_ENHANCEMENTS:
		assert_null(UIKit.keyed(row, "u2:enh:" + type), type)
	assert_not_null(UIKit.keyed(row, "u2:enh:Monstrous Traits"))


func test_unique_unit_gets_no_enhancement_selects() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["unique"])))
	_tables(builder, PackedStringArray(["Heroic Traits", "Monstrous Traits"]))
	var row := _expanded_row(builder, "u2")
	assert_eq(UIKit.find_all(row, func(n: Node) -> bool: return n is OptionButton).size(), 0)


func test_enhancement_select_lists_none_and_each_enhancement() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var select := UIKit.keyed(_expanded_row(builder, "u1"), "u1:enh:Heroic Traits") as OptionButton
	assert_eq(select.item_count, 3)
	assert_eq(select.get_item_metadata(0), "")


func test_choosing_an_enhancement_gives_it_to_the_unit() -> void:
	var army := UIKit.army_with_regiment()
	var builder := _builder(army)
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var select := UIKit.keyed(_expanded_row(builder, "u1"), "u1:enh:Heroic Traits") as OptionButton
	select.item_selected.emit(2)
	assert_eq(army.find_unit("u1").enhancements["Heroic Traits"], "Boon B")


func test_enhancement_select_shows_the_units_current_enhancement() -> void:
	var army := UIKit.army_with_regiment()
	army.find_unit("u1").enhancements["Heroic Traits"] = "Boon A"
	var builder := _builder(army)
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var select := UIKit.keyed(_expanded_row(builder, "u1"), "u1:enh:Heroic Traits") as OptionButton
	assert_eq(select.get_selected_metadata(), "Boon A")


func _faction_with_option(option: WeaponOption, can_reinforce := false) -> Faction:
	return _faction_with("grunt", func(w: Warscroll) -> void:
		w.weapon_options = [option] as Array[WeaponOption]
		w.can_reinforce = can_reinforce)


func test_weapon_option_spinbox_is_capped_by_weapon_options_cap() -> void:
	var option := Kit.weapon_option("Axe", 1, 5)
	var faction := _faction_with_option(option)
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])), faction)
	var row := _expanded_row(builder, "u2")
	var spin := UIKit.keyed(row, "u2:wopt:Axe") as SpinBox
	assert_eq(int(spin.max_value), WeaponOptions.cap(option, faction.get_warscroll("grunt"), false))


func test_weapon_option_spinbox_cap_grows_when_reinforced() -> void:
	var option := Kit.weapon_option("Axe", 1, 5)
	var faction := _faction_with_option(option, true)
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").reinforced = true
	var row := _expanded_row(_builder(army, faction), "u2")
	var spin := UIKit.keyed(row, "u2:wopt:Axe") as SpinBox
	assert_eq(int(spin.max_value), WeaponOptions.cap(option, faction.get_warscroll("grunt"), true))
	assert_gt(int(spin.max_value), WeaponOptions.cap(option, faction.get_warscroll("grunt"), false))


func test_choice_weapon_option_is_capped_at_the_model_count() -> void:
	var option := Kit.weapon_option("Spear", 1, 5, true)
	var faction := _faction_with_option(option)
	var row := _expanded_row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])), faction), "u2")
	var spin := UIKit.keyed(row, "u2:wopt:Spear") as SpinBox
	assert_eq(int(spin.max_value), faction.get_warscroll("grunt").unit_size)


func test_weapon_option_spinbox_starts_at_the_units_value() -> void:
	var option := Kit.weapon_option("Axe", 2, 5)
	var faction := _faction_with_option(option)
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").weapon_options["Axe"] = 1
	var row := _expanded_row(_builder(army, faction), "u2")
	assert_eq(int((UIKit.keyed(row, "u2:wopt:Axe") as SpinBox).value), 1)


func test_changing_a_weapon_option_spinbox_updates_the_unit() -> void:
	var option := Kit.weapon_option("Axe", 2, 5)
	var faction := _faction_with_option(option)
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var row := _expanded_row(_builder(army, faction), "u2")
	(UIKit.keyed(row, "u2:wopt:Axe") as SpinBox).value = 0
	assert_eq(army.find_unit("u2").weapon_options["Axe"], 0)


func test_unit_without_weapon_options_has_no_spinboxes() -> void:
	var row := _expanded_row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_eq(UIKit.find_all(row, func(n: Node) -> bool: return n is SpinBox).size(), 0)
