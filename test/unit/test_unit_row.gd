extends GutTest
## Unit tests for a unit's row in the army list (scripts/ui/forge/builder/unit_row.gd).

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


func test_options_button_is_disabled_without_options() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_true(_btn(row, "options").disabled)


func test_options_button_is_enabled_with_a_weapon_option() -> void:
	var faction := _faction_with_option(Kit.weapon_option("Axe", 1, 5))
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])), faction), "u2")
	assert_false(_btn(row, "options").disabled)


func test_options_button_is_enabled_with_an_enhancement() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	assert_false(_btn(_row(builder, "u1"), "options").disabled)


func test_unit_without_options_draws_no_options_panel_when_expanded() -> void:
	var row := _expanded_row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_eq(row.get_child(0).get_child_count(), 1)


# --- Renaming ---

func test_unit_has_a_rename_button() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_not_null(_btn(row, "rename"))


func test_rename_button_follows_the_unit_name() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	var rename := _btn(row, "rename")
	var siblings := rename.get_parent().get_children()
	assert_true(siblings[0] is Label and (siblings[0] as Label).text == "Grunt")
	assert_eq(siblings.find(rename), 1)


func test_regiment_of_renown_units_have_no_rename_button() -> void:
	var row := _row(_builder(_army_with_renown_regiment()), "u9")
	assert_null(_btn(row, "rename"))


func test_pressing_rename_shows_a_name_field() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])))
	_btn(_drawn_row(builder, "u2"), "rename").pressed.emit()
	assert_true(UIKit.keyed(_drawn_row(builder, "u2"), "u2:label") is LineEdit)


func test_name_field_hidden_until_renaming() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_null(UIKit.keyed(row, "u2:label"))


func test_submitting_the_name_field_names_the_unit() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var builder := _builder(army)
	builder.start_renaming("u2")
	var edit := UIKit.keyed(_drawn_row(builder, "u2"), "u2:label") as LineEdit
	edit.text_submitted.emit("Old Bill")
	assert_eq(army.find_unit("u2").label, "Old Bill")
	assert_eq(builder.renaming, "")


func test_submitting_a_blank_name_goes_back_to_the_warscroll_name() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").label = "Old Bill"
	var builder := _builder(army)
	builder.start_renaming("u2")
	(UIKit.keyed(_drawn_row(builder, "u2"), "u2:label") as LineEdit).text_submitted.emit("  ")
	assert_eq(army.find_unit("u2").label, "")


func test_submitting_the_same_name_stops_renaming() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])))
	builder.start_renaming("u2")
	(UIKit.keyed(_drawn_row(builder, "u2"), "u2:label") as LineEdit).text_submitted.emit("")
	assert_eq(builder.renaming, "")
	assert_null(UIKit.keyed(_drawn_row(builder, "u2"), "u2:label"))


func test_finish_renaming_does_nothing_when_the_unit_is_not_being_renamed() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var row := _row(_builder(army), "u2")
	row.finish_renaming("Old Bill")
	assert_eq(army.find_unit("u2").label, "")


# --- Subtext ---

func _subtext(army: Army, uid: String, faction: Faction = null) -> String:
	var builder := _builder(army, faction)
	var unit := army.find_unit(uid)
	var regiment := army.regiment_of(uid)
	return UnitRow.subtext(unit, regiment, army, builder.catalog.warscroll(unit, regiment))


func test_subtext_names_the_general() -> void:
	assert_true(_subtext(UIKit.army_with_regiment(), "u1").begins_with("General · "))


func test_subtext_names_a_leader_that_is_not_the_general() -> void:
	var army := UIKit.army_with_regiment()
	army.general_uid = ""
	assert_true(_subtext(army, "u1").begins_with("Leader · "))


func test_subtext_of_a_regiment_member_has_no_role() -> void:
	var text := _subtext(UIKit.army_with_regiment(PackedStringArray(["grunt"])), "u2")
	assert_false(text.contains("Leader") or text.contains("General"), text)


func test_subtext_shows_the_warscroll_name_of_a_renamed_unit_after_its_role() -> void:
	var army := UIKit.army_with_regiment()
	army.find_unit("u1").label = "Old Bill"
	assert_true(_subtext(army, "u1").begins_with("General · Lead · "))


func test_subtext_hides_the_warscroll_name_when_not_renamed() -> void:
	assert_false(_subtext(UIKit.army_with_regiment(PackedStringArray(["grunt"])), "u2").contains("Grunt"))


func test_subtext_counts_models() -> void:
	assert_eq(_subtext(UIKit.army_with_regiment(PackedStringArray(["grunt"])), "u2"), "5 models")


func test_subtext_counts_reinforced_models() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").reinforced = true
	assert_eq(_subtext(army, "u2"), "10 models")


func test_subtext_says_model_for_a_single_model() -> void:
	var faction := _faction_with("lead", func(w: Warscroll) -> void: w.unit_size = 1)
	assert_eq(_subtext(UIKit.army_with_regiment(), "u1", faction), "General · 1 model")


func test_subtext_lists_enhancements_after_the_model_count() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").enhancements = {"Monstrous Traits": "Boon A"}
	assert_eq(_subtext(army, "u2"), "5 models · Boon A")


func test_subtext_lists_weapon_options_after_enhancements() -> void:
	var faction := _faction_with_option(Kit.weapon_option("Axe", 1, 5))
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").enhancements = {"Monstrous Traits": "Boon A"}
	assert_eq(_subtext(army, "u2", faction), "5 models · Boon A · 1 × Axe")


func test_subtext_skips_weapon_options_no_model_takes() -> void:
	var faction := _faction_with_option(Kit.weapon_option("Axe", 1, 5))
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.find_unit("u2").weapon_options["Axe"] = 0
	assert_false(_subtext(army, "u2", faction).contains("Axe"))


func test_subtext_flags_a_unit_missing_from_the_data() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["gone"]))
	army.find_unit("u2").label = "Old Bill"
	assert_eq(_subtext(army, "u2"), "gone · No longer in the faction data")


func test_row_shows_the_subtext() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var row := _row(_builder(army), "u2")
	assert_true(UIKit.has_label_containing(row, "5 models"))


# --- Points ---

## The tag with the points from the unit's enhancements, or null.
func _enhancement_tag(row: UnitRow) -> Control:
	var found := UIKit.find_all(row, func(n: Node) -> bool: return n.has_meta(&"enhancement_points"))
	return found[0] if not found.is_empty() else null


func _enhanced_builder(army: Army) -> ArmyBuilder:
	var builder := _builder(army)
	builder.catalog.faction.enhancement_tables = [Kit.table("Heroic Traits",
			[Kit.ability("Boon B", 20)] as Array[Ability])] as Array[EnhancementTable]
	return builder


func test_enhancement_points_show_in_a_tag_after_the_units_own_points() -> void:
	var army := UIKit.army_with_regiment()
	army.find_unit("u1").enhancements = {"Heroic Traits": "Boon B"}
	var row := _row(_enhanced_builder(army), "u1")
	var tag := _enhancement_tag(row)
	assert_not_null(tag)
	assert_eq(tag.get_meta(&"enhancement_points"), 20)
	assert_true(UIKit.has_label_containing(tag, "+20"))


func test_unit_points_leave_out_enhancement_points() -> void:
	var army := UIKit.army_with_regiment()
	army.find_unit("u1").enhancements = {"Heroic Traits": "Boon B"}
	var builder := _enhanced_builder(army)
	var row := _row(builder, "u1")
	var warscroll_points := builder.catalog.warscroll(army.find_unit("u1"), army.regiments[0]).points
	assert_true(UIKit.has_label_containing(row, "%d pts" % warscroll_points))


func test_unit_without_enhancement_points_has_no_tag() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u2")
	assert_null(_enhancement_tag(row))


# --- Crown and grip column ---

func test_crown_comes_before_the_hero_leaders_portrait() -> void:
	var row := _row(_builder(UIKit.army_with_regiment(PackedStringArray(["grunt"]))), "u1")
	var crown := _btn(row, "general")
	assert_eq(crown.get_index(), 0)


func test_crown_and_grip_share_a_column() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])))
	var crown := _btn(_drawn_row(builder, "u1"), "general")
	var grip := _btn(_drawn_row(builder, "u2"), "grip")
	assert_eq(crown.get_index(), grip.get_index())


## The section with the heading and cards for enhancement [param type] on [param row], or null.
func _enh_section(row: UnitRow, type: String) -> Control:
	var found := UIKit.find_all(row, func(n: Node) -> bool: return n.get_meta(&"enhancement_type", "") == type)
	return found[0] if not found.is_empty() else null


func _enh_cards(row: UnitRow, type: String) -> Array[Node]:
	var section := _enh_section(row, type)
	return UIKit.find_all(section, func(n: Node) -> bool: return n is AbilityChoiceCard) if section else []


func _enh_card(row: UnitRow, uid: String, type: String, entry: String) -> AbilityChoiceCard:
	return UIKit.keyed(row, "%s:enh:%s:%s" % [uid, type, entry]) as AbilityChoiceCard


func test_hero_gets_a_section_for_every_enhancement_type() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits", "Artefacts of Power", "Monstrous Traits"]))
	var row := _expanded_row(builder, "u1")
	for type in builder.catalog.enhancement_types(builder.editor.army):
		assert_not_null(_enh_section(row, type), type)


func test_non_hero_skips_hero_only_enhancement_types() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["grunt"])))
	_tables(builder, PackedStringArray(ArmyValidator.HERO_ENHANCEMENTS) + PackedStringArray(["Monstrous Traits"]))
	var row := _expanded_row(builder, "u2")
	for type in ArmyValidator.HERO_ENHANCEMENTS:
		assert_null(_enh_section(row, type), type)
	assert_not_null(_enh_section(row, "Monstrous Traits"))


func test_unit_skips_enhancement_types_only_other_units_can_take() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Great Works"]))
	builder.catalog.faction.enhancement_tables[0].units = PackedStringArray(["Somebody Else"])
	var row := _expanded_row(builder, "u1")
	assert_null(_enh_section(row, "Great Works"))


func test_unique_unit_gets_no_enhancement_cards() -> void:
	var builder := _builder(UIKit.army_with_regiment(PackedStringArray(["unique"])))
	_tables(builder, PackedStringArray(["Heroic Traits", "Monstrous Traits"]))
	var row := _expanded_row(builder, "u2")
	assert_eq(UIKit.find_all(row, func(n: Node) -> bool: return n is AbilityChoiceCard).size(), 0)


func test_enhancement_section_has_a_card_for_each_enhancement() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var row := _expanded_row(builder, "u1")
	assert_eq(_enh_cards(row, "Heroic Traits").size(), 2)
	assert_not_null(_enh_card(row, "u1", "Heroic Traits", "Boon A"))
	assert_not_null(_enh_card(row, "u1", "Heroic Traits", "Boon B"))


func test_enhancement_heading_is_a_section_label_with_the_type() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var heading := _enh_section(_expanded_row(builder, "u1"), "Heroic Traits").get_child(0) as Label
	assert_eq(heading.theme_type_variation, &"SectionLabel")
	assert_eq(heading.text, "Heroic Traits")


func test_choosing_an_enhancement_gives_it_to_the_unit() -> void:
	var army := UIKit.army_with_regiment()
	var builder := _builder(army)
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var card := _enh_card(_expanded_row(builder, "u1"), "u1", "Heroic Traits", "Boon B")
	card.pressed.emit()
	assert_eq(army.find_unit("u1").enhancements["Heroic Traits"], "Boon B")


# A unit row lets the mouse through its controls for drag and drop, so a click on a card's chevron
# reaches the card too.
func test_click_on_an_enhancement_chevron_does_not_choose_it() -> void:
	var army := UIKit.army_with_regiment()
	var builder := _builder(army)
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var row := _expanded_row(builder, "u1")
	row.size = Vector2(400, 0)
	await get_tree().process_frame
	var card := _enh_card(row, "u1", "Heroic Traits", "Boon B")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = card.get_global_transform().affine_inverse() * card.fold_button.get_global_rect().get_center()
	card._gui_input(click)
	assert_eq(army.find_unit("u1").enhancements.get("Heroic Traits", ""), "")


func test_enhancement_chevron_unfolds_the_card() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var card := _enh_card(_expanded_row(builder, "u1"), "u1", "Heroic Traits", "Boon B")
	card.fold_button.pressed.emit()
	assert_false(card.folded)


func test_enhancement_chevron_has_a_focus_key() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var card := _enh_card(_expanded_row(builder, "u1"), "u1", "Heroic Traits", "Boon B")
	assert_eq(card.fold_button.get_meta(&"focus_key", ""), "u1:enh:Heroic Traits:Boon B:fold")


func test_enhancement_card_is_selected_for_the_units_current_enhancement() -> void:
	var army := UIKit.army_with_regiment()
	army.find_unit("u1").enhancements["Heroic Traits"] = "Boon A"
	var builder := _builder(army)
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var row := _expanded_row(builder, "u1")
	assert_true(_enh_card(row, "u1", "Heroic Traits", "Boon A").selected)
	assert_false(_enh_card(row, "u1", "Heroic Traits", "Boon B").selected)


func test_pressing_the_picked_card_removes_the_enhancement() -> void:
	var army := UIKit.army_with_regiment()
	army.find_unit("u1").enhancements["Heroic Traits"] = "Boon A"
	var builder := _builder(army)
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var card := _enh_card(_expanded_row(builder, "u1"), "u1", "Heroic Traits", "Boon A")
	card.pressed.emit()
	assert_false(army.find_unit("u1").enhancements.has("Heroic Traits"))


## Chips upper-case their text, so these match against the upper-case form.
func test_enhancement_card_shows_a_points_chip_only_when_it_costs_points() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var row := _expanded_row(builder, "u1")
	assert_true(UIKit.has_label_containing(_enh_card(row, "u1", "Heroic Traits", "Boon B"), "20 PTS"))
	assert_false(UIKit.has_label_containing(_enh_card(row, "u1", "Heroic Traits", "Boon A"), "PTS"))


func test_legends_enhancement_table_shows_a_legends_chip() -> void:
	var army := UIKit.army_with_regiment()
	army.show_legends = true
	var builder := _builder(army)
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	builder.catalog.faction.enhancement_tables[0].legends = true
	var card := _enh_card(_expanded_row(builder, "u1"), "u1", "Heroic Traits", "Boon A")
	assert_true(UIKit.has_label_containing(card, "LEGENDS"))


func test_non_legends_enhancement_card_has_no_legends_chip() -> void:
	var builder := _builder(UIKit.army_with_regiment())
	_tables(builder, PackedStringArray(["Heroic Traits"]))
	var card := _enh_card(_expanded_row(builder, "u1"), "u1", "Heroic Traits", "Boon A")
	assert_false(UIKit.has_label_containing(card, "LEGENDS"))


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


# --- Reordering: grips, drops and keyboard ---

## Regiment r1 (general lead u1, grunts u2 and u3), regiment r2 (wizard u4, grunt u5), auxiliary grunts u6 and u7.
func _ordered_army() -> Army:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt", "grunt"]))
	army.regiments.append(Kit.regiment("r2", [Kit.unit("u4", "wizard"), Kit.unit("u5", "grunt")] as Array[ArmyUnit]))
	army.auxiliary.append(Kit.unit("u6", "grunt"))
	army.auxiliary.append(Kit.unit("u7", "grunt"))
	return army


## The row the builder drew for the unit.
func _drawn_row(builder: ArmyBuilder, uid: String) -> UnitRow:
	var found := UIKit.find_all(builder.builder_list, func(n: Node) -> bool: return n is UnitRow and n.unit.uid == uid)
	var row: UnitRow = found[0]
	row.size = Vector2(300, 60)
	return row


func _uids(units: Array[ArmyUnit]) -> Array:
	return units.map(func(u: ArmyUnit) -> String: return u.uid)


func _key(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## Presses [param action] on the grip of the unit's row.
func _press_grip(builder: ArmyBuilder, uid: String, action: String) -> void:
	var grip := UIKit.keyed(_drawn_row(builder, uid), uid + ":grip") as Button
	grip.gui_input.emit(_key(action))


func test_regiment_unit_has_a_grip() -> void:
	var row := _row(_builder(_ordered_army()), "u2")
	assert_not_null(_btn(row, "grip"))


func test_auxiliary_unit_has_a_grip() -> void:
	var row := _row(_builder(_ordered_army()), "u6")
	assert_not_null(_btn(row, "grip"))


func test_hero_leader_has_no_grip() -> void:
	var row := _row(_builder(_ordered_army()), "u1")
	assert_null(_btn(row, "grip"))


func test_non_hero_first_unit_has_a_grip() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "grunt"), Kit.unit("u2", "grunt")] as Array[ArmyUnit]))
	var row := _row(_builder(army), "u1")
	assert_not_null(_btn(row, "grip"))


func test_regiment_of_renown_units_have_no_grip() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.ror_regiment("r9", "Band", [Kit.unit("u9", "grunt"), Kit.unit("u10", "grunt")] as Array[ArmyUnit]))
	var builder := _builder(army)
	assert_null(_btn(_row(builder, "u9"), "grip"))
	assert_null(_btn(_row(builder, "u10"), "grip"))


func test_grip_is_a_grip_button() -> void:
	var row := _row(_builder(_ordered_army()), "u2")
	assert_eq(_btn(row, "grip").theme_type_variation, &"GripButton")


# drop_index

func test_drop_index_on_the_top_half_is_before_the_row() -> void:
	var row := _drawn_row(_builder(_ordered_army()), "u3")
	assert_eq(row.drop_index(Vector2(0, 0)), 2)


func test_drop_index_on_the_bottom_half_is_after_the_row() -> void:
	var row := _drawn_row(_builder(_ordered_army()), "u3")
	assert_eq(row.drop_index(Vector2(0, row.size.y)), 3)


func test_drop_index_never_goes_before_a_hero_leader() -> void:
	var row := _drawn_row(_builder(_ordered_army()), "u1")
	assert_eq(row.drop_index(Vector2(0, 0)), 1)


func test_drop_index_in_the_auxiliary_units_is_not_clamped() -> void:
	var row := _drawn_row(_builder(_ordered_army()), "u6")
	assert_eq([row.drop_index(Vector2(0, 0)), row.drop_index(Vector2(0, row.size.y))], [0, 1])


# Drop handlers

func test_row_accepts_a_roster_drop_and_shows_the_line() -> void:
	var builder := _builder(_ordered_army())
	var row := _drawn_row(builder, "u2")
	assert_true(row._can_drop_data(Vector2.ZERO, {"kind": "roster", "warscroll_id": "grunt"}))
	assert_true(builder.drag.line.visible)


func test_row_refuses_data_that_is_not_a_dictionary() -> void:
	var row := _drawn_row(_builder(_ordered_army()), "u2")
	assert_false(row._can_drop_data(Vector2.ZERO, "text"))


func test_row_refuses_a_regiment_drag() -> void:
	var row := _drawn_row(_builder(_ordered_army()), "u2")
	assert_false(row._can_drop_data(Vector2.ZERO, {"kind": "reg", "regiment_id": "r2"}))


func test_row_refuses_a_roster_drop_when_its_regiment_is_full() -> void:
	var builder := _builder(_ordered_army())
	while builder.editor.add_unit("r2", "grunt"):
		pass
	var row := _drawn_row(builder, "u5")
	assert_false(row._can_drop_data(Vector2.ZERO, {"kind": "roster", "warscroll_id": "grunt"}))


func test_row_in_a_regiment_of_renown_refuses_drops() -> void:
	var army := _ordered_army()
	army.regiments.append(Kit.ror_regiment("r9", "Band", [Kit.unit("u9", "grunt")] as Array[ArmyUnit]))
	var builder := _builder(army)
	var row := _drawn_row(builder, "u9")
	assert_false(row._can_drop_data(Vector2.ZERO, {"kind": "unit", "uid": "u2"}))


func test_dropping_a_roster_unit_on_the_top_half_adds_it_before_the_row() -> void:
	var builder := _builder(_ordered_army())
	_drawn_row(builder, "u3")._drop_data(Vector2.ZERO, {"kind": "roster", "warscroll_id": "beast"})
	var units := builder.editor.army.find_regiment("r1").units
	assert_eq([units[2].warscroll_id, units[3].uid], ["beast", "u3"])


func test_dropping_a_roster_unit_on_the_bottom_half_adds_it_after_the_row() -> void:
	var builder := _builder(_ordered_army())
	var row := _drawn_row(builder, "u2")
	row._drop_data(Vector2(0, row.size.y), {"kind": "roster", "warscroll_id": "beast"})
	var units := builder.editor.army.find_regiment("r1").units
	assert_eq([units[1].uid, units[2].warscroll_id], ["u2", "beast"])


func test_dropping_a_unit_on_the_hero_leader_puts_it_after_the_leader() -> void:
	var builder := _builder(_ordered_army())
	_drawn_row(builder, "u1")._drop_data(Vector2.ZERO, {"kind": "unit", "uid": "u3"})
	assert_eq(_uids(builder.editor.army.find_regiment("r1").units), ["u1", "u3", "u2"])


func test_dropping_a_unit_on_a_row_in_another_regiment_moves_it() -> void:
	var builder := _builder(_ordered_army())
	_drawn_row(builder, "u5")._drop_data(Vector2.ZERO, {"kind": "unit", "uid": "u2"})
	assert_eq(_uids(builder.editor.army.find_regiment("r2").units), ["u4", "u2", "u5"])
	assert_eq(_uids(builder.editor.army.find_regiment("r1").units), ["u1", "u3"])


func test_dropping_a_regiment_unit_on_an_auxiliary_row_moves_it_to_the_auxiliary_units() -> void:
	var builder := _builder(_ordered_army())
	var row := _drawn_row(builder, "u6")
	row._drop_data(Vector2(0, row.size.y), {"kind": "unit", "uid": "u2"})
	assert_eq(_uids(builder.editor.army.auxiliary), ["u6", "u2", "u7"])


# Keyboard

func test_down_moves_a_unit_after_the_next_one() -> void:
	var builder := _builder(_ordered_army())
	_press_grip(builder, "u2", "ui_down")
	assert_eq(_uids(builder.editor.army.find_regiment("r1").units), ["u1", "u3", "u2"])


func test_up_moves_a_unit_before_the_previous_one() -> void:
	var builder := _builder(_ordered_army())
	_press_grip(builder, "u7", "ui_up")
	assert_eq(_uids(builder.editor.army.auxiliary), ["u7", "u6"])


func test_down_on_the_last_unit_does_nothing() -> void:
	var builder := _builder(_ordered_army())
	_press_grip(builder, "u3", "ui_down")
	assert_eq(_uids(builder.editor.army.find_regiment("r1").units), ["u1", "u2", "u3"])


func test_up_on_the_first_unit_does_nothing() -> void:
	var builder := _builder(_ordered_army())
	_press_grip(builder, "u6", "ui_up")
	assert_eq(_uids(builder.editor.army.auxiliary), ["u6", "u7"])


func test_up_never_moves_a_unit_above_a_hero_leader() -> void:
	var builder := _builder(_ordered_army())
	_press_grip(builder, "u2", "ui_up")
	assert_eq(_uids(builder.editor.army.find_regiment("r1").units), ["u1", "u2", "u3"])


func test_up_moves_a_non_hero_first_unit_nowhere_and_down_moves_it_on() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "grunt"), Kit.unit("u2", "grunt")] as Array[ArmyUnit]))
	var builder := _builder(army)
	_press_grip(builder, "u1", "ui_up")
	assert_eq(_uids(army.regiments[0].units), ["u1", "u2"])
	_press_grip(builder, "u1", "ui_down")
	assert_eq(_uids(army.regiments[0].units), ["u2", "u1"])


func test_other_keys_on_the_grip_do_nothing() -> void:
	var builder := _builder(_ordered_army())
	_press_grip(builder, "u2", "ui_left")
	assert_eq(_uids(builder.editor.army.find_regiment("r1").units), ["u1", "u2", "u3"])


func test_the_grip_keeps_focus_after_the_unit_moves() -> void:
	var builder := _builder(_ordered_army())
	var grip := UIKit.keyed(_drawn_row(builder, "u2"), "u2:grip") as Button
	grip.grab_focus()
	grip.gui_input.emit(_key("ui_down"))
	var focused := builder.get_viewport().gui_get_focus_owner()
	assert_not_null(focused)
	assert_eq(focused.get_meta(&"focus_key", ""), "u2:grip")
