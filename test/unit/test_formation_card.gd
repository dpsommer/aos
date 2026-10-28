extends GutTest
## Unit tests for the battle formation card widget (scripts/ui/forge/builder/formation_card.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func after_each() -> void:
	await get_tree().process_frame


func _formation(points := 0) -> BattleFormation:
	var formation := Kit.formation("Vanguard", points)
	var plan := Kit.ability("Charge Plan")
	plan.effect = "Charge harder."
	var wall := Kit.ability("Wall Breaker")
	wall.effect = "Break walls."
	formation.abilities = [plan, wall] as Array[Ability]
	return formation


func _make(formation: BattleFormation, full: bool, action: Control = null) -> FormationCard:
	var node := FormationCard.new(formation, full, action)
	add_child_autofree(node)
	return node


func _rules_text(node: Node) -> String:
	var text := ""
	for found in UIKit.find_all(node, func(n: Node) -> bool: return n is RichTextLabel):
		text += (found as RichTextLabel).text
	return text


func _ability_names(node: Node) -> Array:
	var cards := UIKit.find_all(node, func(n: Node) -> bool: return n is AbilityCard)
	return cards.map(func(c: AbilityCard) -> String: return c.ability.name)


func test_card_name_is_the_formations_name() -> void:
	assert_eq(_make(_formation(), false).card_name, "Vanguard")


func test_card_is_not_pressable_until_made_so() -> void:
	assert_false(_make(_formation(), true).pressable)


func test_name_is_shown_once_as_a_title() -> void:
	var titles := UIKit.labels_with_variation(_make(_formation(), false), "TitleLabel")
	assert_eq(titles.size(), 1)
	assert_eq(titles[0].text, "Vanguard")


func test_points_are_shown_when_the_formation_costs_some() -> void:
	assert_true(UIKit.has_label_containing(_make(_formation(50), false), "50"))


func test_no_points_chip_when_the_formation_is_free() -> void:
	assert_false(UIKit.has_label_containing(_make(_formation(0), false), "pts"))


func test_short_card_shows_each_ability_name_as_a_chip() -> void:
	var texts := UIKit.label_texts(_make(_formation(), false))
	assert_has(texts, "CHARGE PLAN")
	assert_has(texts, "WALL BREAKER")


func test_short_card_hides_the_rules() -> void:
	var node := _make(_formation(), false)
	assert_eq(_rules_text(node), "")
	assert_eq(_ability_names(node), [])


func test_full_card_shows_each_abilitys_rules() -> void:
	var node := _make(_formation(), true)
	assert_eq(_ability_names(node), ["Charge Plan", "Wall Breaker"])
	assert_string_contains(_rules_text(node), "Break walls.")


func test_action_control_is_shown_in_the_card() -> void:
	var action := Button.new()
	var node := _make(_formation(), false, action)
	assert_true(node.is_ancestor_of(action))


func test_action_ends_the_names_row() -> void:
	var action := Button.new()
	var node := _make(_formation(50), false, action)
	var row := UIKit.labels_with_variation(node, "TitleLabel")[0].get_parent()
	assert_eq(action.get_parent(), row)
	assert_eq(action.get_index(), row.get_child_count() - 1)


func test_action_is_vertically_centred() -> void:
	var action := Button.new()
	_make(_formation(), false, action)
	assert_eq(action.size_flags_vertical, Control.SIZE_SHRINK_CENTER)


func test_card_uses_the_card_panel_style() -> void:
	assert_eq(_make(_formation(), false).theme_type_variation, &"CardPanel")


func test_pressing_a_pressable_card_emits_pressed() -> void:
	var node := _make(_formation(), false)
	node.make_pressable("Choose it")
	watch_signals(node)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	node._gui_input(click)
	assert_signal_emitted(node, "pressed")
