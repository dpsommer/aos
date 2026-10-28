extends GutTest
## Unit tests for the Regiment of Renown card (scripts/ui/forge/builder/renown_card.gd).

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


func _band(band_name := "Band", legends := false) -> RegimentOfRenown:
	var units: Array[RegimentUnit] = [Kit.renown_unit("Gotrek", "gotrek"), Kit.renown_unit("Felix", "felix", "", 2)]
	var own: Array[Warscroll] = [Kit.warscroll("gotrek", PackedStringArray(["HERO"])), Kit.warscroll("felix")]
	var band := Kit.regiment_of_renown(band_name, 150, units, own)
	band.legends = legends
	return band


func _builder(bands: Array[RegimentOfRenown], army: Army = null) -> ArmyBuilder:
	var faction := UIKit.faction()
	faction.regiments_of_renown = bands
	return UIKit.builder(self, army if army else UIKit.army_with_regiment(), faction)


func _card(builder: ArmyBuilder, band: RegimentOfRenown, context := "tab", on_added := Callable(), flash := false) -> RenownCard:
	var card := RenownCard.new(builder, band, context, on_added, flash)
	add_child_autofree(card)
	return card


func _rich_count(node: Node) -> int:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is RichTextLabel).size()


func _warscroll_count(node: Node) -> int:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is WarscrollCard).size()


func test_card_shows_the_regiments_name_and_unit_names() -> void:
	var band := _band()
	var card := _card(_builder([band] as Array[RegimentOfRenown]), band)
	assert_true(UIKit.has_label_containing(card, "Band"))
	assert_not_null(UIKit.keyed(card, "tab:Band:0"))
	assert_not_null(UIKit.keyed(card, "tab:Band:1"))


func test_unit_subhead_shows_the_models_count_when_more_than_one() -> void:
	var band := _band()
	var card := _card(_builder([band] as Array[RegimentOfRenown]), band)
	assert_string_contains((UIKit.keyed(card, "tab:Band:1") as Button).text, "2")
	assert_false("2" in (UIKit.keyed(card, "tab:Band:0") as Button).text)


func test_unit_notes_are_appended_to_the_subhead() -> void:
	var band := _band()
	band.units[0].notes = "General only"
	var card := _card(_builder([band] as Array[RegimentOfRenown]), band)
	assert_string_contains((UIKit.keyed(card, "tab:Band:0") as Button).text, "General only")


func test_subhead_keys_use_the_context() -> void:
	var band := _band()
	var card := _card(_builder([band] as Array[RegimentOfRenown]), band, "pick")
	assert_not_null(UIKit.keyed(card, "pick:Band:0"))
	assert_null(UIKit.keyed(card, "tab:Band:0"))


func test_card_carries_an_info_key_for_links() -> void:
	var band := _band()
	assert_eq(_card(_builder([band] as Array[RegimentOfRenown]), band).get_meta(&"info_key"), "ror:Band")


func test_warscroll_is_hidden_until_the_subhead_is_expanded() -> void:
	var band := _band()
	var builder := _builder([band] as Array[RegimentOfRenown])
	assert_eq(_warscroll_count(_card(builder, band)), 0)
	builder.expanded["tab:Band:0"] = true
	assert_gt(_warscroll_count(_card(builder, band)), 0)


func test_pressing_a_subhead_toggles_the_builders_expanded_state() -> void:
	var band := _band()
	var builder := _builder([band] as Array[RegimentOfRenown])
	var card := _card(builder, band)
	(UIKit.keyed(card, "tab:Band:0") as Button).pressed.emit()
	assert_true(builder.expanded.has("tab:Band:0"))


func test_expanded_state_is_kept_apart_by_context() -> void:
	var band := _band()
	var builder := _builder([band] as Array[RegimentOfRenown])
	builder.expanded["tab:Band:0"] = true
	assert_eq(_warscroll_count(_card(builder, band, "pick")), 0)


func test_subhead_is_disabled_when_the_warscroll_is_missing() -> void:
	var band := _band()
	band.warscrolls = [] as Array[Warscroll]
	var card := _card(_builder([band] as Array[RegimentOfRenown]), band)
	assert_true((UIKit.keyed(card, "tab:Band:0") as Button).disabled)


func test_add_button_adds_the_regiment() -> void:
	var band := _band()
	var army := UIKit.army_with_regiment()
	var card := _card(_builder([band] as Array[RegimentOfRenown], army), band)
	(UIKit.keyed(card, "tab:add:Band") as Button).pressed.emit()
	assert_true(army.regiments.any(func(r: ArmyRegiment) -> bool: return r.regiment_of_renown == "Band"))


func test_add_button_calls_on_added() -> void:
	var band := _band()
	var calls := []
	var on_added := func() -> void: calls.append(1)
	var card := _card(_builder([band] as Array[RegimentOfRenown]), band, "pick", on_added)
	(UIKit.keyed(card, "pick:add:Band") as Button).pressed.emit()
	assert_eq(calls.size(), 1)


func test_add_button_needs_no_on_added_callback() -> void:
	var band := _band()
	var army := UIKit.army_with_regiment()
	var card := _card(_builder([band] as Array[RegimentOfRenown], army), band)
	(UIKit.keyed(card, "tab:add:Band") as Button).pressed.emit()
	assert_eq(army.regiments.size(), 2)


func test_a_regiment_of_renown_already_in_the_army_replaces_the_add_button_with_a_reason() -> void:
	var band := _band()
	var builder := _builder([band, _band("Other")] as Array[RegimentOfRenown])
	builder.editor.add_regiment_of_renown("Band")
	var card := _card(builder, _band("Other"))
	assert_null(UIKit.keyed(card, "tab:add:Other"))
	assert_true(UIKit.has_label_containing(card, "already has a Regiment of Renown"))


func test_the_added_regiment_is_marked_as_in_the_army() -> void:
	var band := _band()
	var builder := _builder([band] as Array[RegimentOfRenown])
	builder.editor.add_regiment_of_renown("Band")
	var card := _card(builder, band)
	assert_true(UIKit.has_label_containing(card, "In your army"))


func test_override_brings_the_add_button_back() -> void:
	var band := _band()
	var army := UIKit.army_with_regiment()
	army.override_constraints = true
	var builder := _builder([band, _band("Other")] as Array[RegimentOfRenown], army)
	builder.editor.add_regiment_of_renown("Band")
	assert_not_null(UIKit.keyed(_card(builder, _band("Other")), "tab:add:Other"))


func _chip_texts(card: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for text in UIKit.label_texts(card):
		result.append(text.to_upper())
	return result


func test_legends_regiment_has_a_legends_chip() -> void:
	var band := _band("Old", true)
	var builder := _builder([band] as Array[RegimentOfRenown])
	assert_has(_chip_texts(_card(builder, band)), "LEGENDS")


func test_ordinary_regiment_has_no_chips() -> void:
	var band := _band()
	var texts := _chip_texts(_card(_builder([band] as Array[RegimentOfRenown]), band))
	assert_does_not_have(texts, "LEGENDS")
	assert_does_not_have(texts, "NOT NORMALLY AVAILABLE")


func test_regiment_the_army_cannot_normally_include_is_flagged() -> void:
	var band := _band()
	var faction := UIKit.faction()
	var renown := Kit.army_of_renown("Solo")
	renown.roster.regiments_of_renown = false
	faction.armies_of_renown.append(renown)
	faction.regiments_of_renown = [band] as Array[RegimentOfRenown]
	var army := UIKit.army_with_regiment()
	army.army_of_renown = "Solo"
	var builder := UIKit.builder(self, army, faction)
	assert_has(_chip_texts(_card(builder, band)), "NOT NORMALLY AVAILABLE")


func test_flash_uses_a_highlighted_variation() -> void:
	var band := _band()
	var builder := _builder([band] as Array[RegimentOfRenown])
	assert_ne(_card(builder, band, "tab", Callable(), true).theme_type_variation, _card(builder, band).theme_type_variation)


func test_regiment_text_and_abilities_are_shown() -> void:
	var band := _band()
	band.text = "A band of heroes."
	band.abilities = [Kit.ability("Doomed")] as Array[Ability]
	var card := _card(_builder([band] as Array[RegimentOfRenown]), band)
	assert_true(UIKit.has_label_containing(card, "A band of heroes."))
	assert_gt(_rich_count(card), 0)
