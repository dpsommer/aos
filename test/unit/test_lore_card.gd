extends GutTest
## Unit tests for the lore card widget (scripts/ui/forge/builder/lore_card.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func after_each() -> void:
	await get_tree().process_frame


func _lore(points := 0) -> Lore:
	var lore := Kit.lore("Fiery Arts", "spell", points)
	var scorch := Kit.ability("Scorch")
	scorch.effect = "Deal scorching damage."
	var blaze := Kit.ability("Blaze")
	blaze.effect = "Set things alight."
	blaze.summons = PackedStringArray(["flame"])
	lore.entries = [scorch, blaze] as Array[Ability]
	return lore


func _flame(_ability: Ability) -> Array[Warscroll]:
	return [Kit.warscroll("flame", PackedStringArray(["MANIFESTATION"]))] as Array[Warscroll]


func _make(lore: Lore, full: bool, heading := "", action: Control = null, summoned := Callable()) -> LoreCard:
	var node := LoreCard.new(lore, full, heading, action, summoned)
	add_child_autofree(node)
	return node


func _rules_text(node: Node) -> String:
	var text := ""
	for found in UIKit.find_all(node, func(n: Node) -> bool: return n is RichTextLabel):
		text += (found as RichTextLabel).text
	return text


func _warscrolls(node: Node) -> Array[Node]:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is WarscrollCard)


func test_card_name_is_the_lores_name() -> void:
	assert_eq(_make(_lore(), false).card_name, "Fiery Arts")


func test_card_is_not_pressable_until_made_so() -> void:
	assert_false(_make(_lore(), true).pressable)


func test_full_card_shows_each_abilitys_rules() -> void:
	var text := _rules_text(_make(_lore(), true))
	assert_string_contains(text, "Scorch")
	assert_string_contains(text, "Deal scorching damage.")
	assert_string_contains(text, "Blaze")
	assert_string_contains(text, "Set things alight.")


func test_short_card_hides_the_rules() -> void:
	var node := _make(_lore(), false)
	assert_eq(_rules_text(node), "")


func test_short_card_shows_each_ability_name_as_a_chip() -> void:
	var texts := UIKit.label_texts(_make(_lore(), false))
	assert_has(texts, "SCORCH")
	assert_has(texts, "BLAZE")


func test_full_card_shows_the_name_once_as_a_title() -> void:
	var node := _make(_lore(), true)
	assert_eq(UIKit.labels_with_variation(node, "TitleLabel").size(), 1)
	assert_eq(UIKit.labels_with_variation(node, "TitleLabel")[0].text, "Fiery Arts")


func test_full_card_shows_summoned_manifestations_in_warscroll_cards() -> void:
	var node := _make(_lore(), true, "", null, _flame)
	assert_gt(_warscrolls(node).size(), 0)


func test_summoned_is_called_with_each_ability() -> void:
	var seen: Array[String] = []
	var summoned := func(ability: Ability) -> Array[Warscroll]:
		seen.append(ability.name)
		return []
	_make(_lore(), true, "", null, summoned)
	assert_eq(seen, ["Scorch", "Blaze"] as Array[String])


func test_full_card_without_summoned_shows_no_warscrolls() -> void:
	assert_eq(_warscrolls(_make(_lore(), true)).size(), 0)


func test_short_card_shows_no_warscrolls() -> void:
	assert_eq(_warscrolls(_make(_lore(), false, "", null, _flame)).size(), 0)


func test_heading_is_shown_and_exposed() -> void:
	var node := _make(_lore(), false, "Spell Lore")
	assert_not_null(node.heading_label)
	assert_eq(node.heading_label.text, "Spell Lore")
	assert_has(UIKit.label_texts(node), "Spell Lore")


func test_without_a_heading_there_is_no_heading_label() -> void:
	assert_null(_make(_lore(), false).heading_label)


func test_action_control_is_shown_in_the_card() -> void:
	var action := Button.new()
	action.text = "Change"
	var node := _make(_lore(), false, "", action)
	assert_true(node.is_ancestor_of(action))


func test_card_uses_the_card_panel_style() -> void:
	assert_eq(_make(_lore(), false).theme_type_variation, &"CardPanel")


func test_pressing_a_pressable_card_emits_pressed() -> void:
	var node := _make(_lore(), true)
	node.make_pressable("Choose it")
	watch_signals(node)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	node._gui_input(click)
	assert_signal_emitted(node, "pressed")


func test_pressable_card_ignores_mouse_on_its_contents() -> void:
	var node := _make(_lore(), true)
	node.make_pressable("Choose it")
	for rich in UIKit.find_all(node, func(n: Node) -> bool: return n is RichTextLabel):
		assert_eq((rich as RichTextLabel).mouse_filter, Control.MOUSE_FILTER_IGNORE)


# --- tags ---

func _tag_texts(lore: Lore) -> PackedStringArray:
	var texts := PackedStringArray()
	for tag in LoreCard.tags(lore):
		autofree(tag)
		texts.append((tag.get_child(0) as Label).text)
	return texts


func test_tags_are_empty_for_a_plain_lore() -> void:
	assert_eq(LoreCard.tags(_lore()).size(), 0)


func test_tags_show_the_points_when_the_lore_costs_some() -> void:
	var texts := _tag_texts(_lore(30))
	assert_eq(texts.size(), 1)
	assert_string_contains(texts[0], "30")


func test_tags_show_legends() -> void:
	var lore := _lore()
	lore.legends = true
	assert_has(_tag_texts(lore), "LEGENDS")


func test_tags_show_scourge_with_the_full_name_as_tooltip() -> void:
	var lore := _lore()
	lore.source = "Scourge of Ghyran"
	var tags := LoreCard.tags(lore)
	assert_eq(tags.size(), 1)
	assert_eq(tags[0].tooltip_text, "Scourge of Ghyran")
	autofree(tags[0])


func test_tags_do_not_show_other_sources() -> void:
	var lore := _lore()
	lore.source = "Some Battletome"
	assert_eq(LoreCard.tags(lore).size(), 0)


func test_points_and_legends_tags_can_appear_together() -> void:
	var lore := _lore(20)
	lore.legends = true
	var tags := LoreCard.tags(lore)
	assert_eq(tags.size(), 2)
	for tag in tags:
		tag.free()
