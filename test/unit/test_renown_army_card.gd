extends GutTest
## Unit tests for the Army of Renown card widget (scripts/ui/forge/builder/renown_army_card.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func after_each() -> void:
	await get_tree().process_frame


func _renown() -> ArmyOfRenown:
	var renown := Kit.army_of_renown("Wanderers")
	renown.source = "Some Battletome"
	renown.text = "Wanderers roam far. They fight.\nROSTER OPTIONS\nYndrasta"
	renown.battle_traits = [Kit.ability("Roam"), Kit.ability("Fight")] as Array[Ability]
	return renown


func _make(renown: ArmyOfRenown, full: bool, action: Control = null) -> RenownArmyCard:
	var node := RenownArmyCard.new(renown, full, action)
	add_child_autofree(node)
	return node


func _ability_names(node: Node) -> Array:
	var cards := UIKit.find_all(node, func(n: Node) -> bool: return n is AbilityCard)
	return cards.map(func(c: AbilityCard) -> String: return c.ability.name)


func test_card_name_is_the_armys_name() -> void:
	assert_eq(_make(_renown(), false).card_name, "Wanderers")


func test_card_is_not_pressable_until_made_so() -> void:
	assert_false(_make(_renown(), false).pressable)


func test_name_is_shown_once_as_a_title() -> void:
	var titles := UIKit.labels_with_variation(_make(_renown(), false), "TitleLabel")
	assert_eq(titles.size(), 1)
	assert_eq(titles[0].text, "Wanderers")


func test_source_is_shown() -> void:
	assert_has(UIKit.label_texts(_make(_renown(), false)), "Some Battletome")


func test_card_without_a_source_shows_no_source() -> void:
	var renown := _renown()
	renown.source = ""
	assert_does_not_have(UIKit.label_texts(_make(renown, false)), "")


func test_roster_summary_is_shown() -> void:
	assert_has(UIKit.label_texts(_make(_renown(), false)), Forge.roster_summary(_renown()))


func test_legends_army_shows_a_legends_chip() -> void:
	var renown := _renown()
	renown.legends = true
	assert_true(UIKit.label_texts(_make(renown, false)).has("LEGENDS"))


func test_roster_limits_are_shown_as_chips() -> void:
	var renown := _renown()
	renown.roster.regiments_of_renown = false
	var expected := (Forge.renown_chips_for(renown)[0] as Array)[0] as String
	var texts := Array(UIKit.label_texts(_make(renown, false))).map(func(t: String) -> String: return t.to_lower())
	assert_has(texts, expected.to_lower())


func test_short_card_shows_no_battle_traits() -> void:
	assert_eq(_ability_names(_make(_renown(), false)), [])


func test_full_card_shows_each_battle_trait() -> void:
	assert_eq(_ability_names(_make(_renown(), true)), ["Roam", "Fight"])


func test_action_control_is_shown_in_the_card() -> void:
	var action := Button.new()
	var node := _make(_renown(), false, action)
	assert_true(node.is_ancestor_of(action))


func test_action_ends_the_names_row() -> void:
	var action := Button.new()
	var node := _make(_renown(), false, action)
	var row := UIKit.labels_with_variation(node, "TitleLabel")[0].get_parent()
	assert_eq(action.get_parent(), row)
	assert_eq(action.get_index(), row.get_child_count() - 1)


func test_action_is_vertically_centred() -> void:
	var action := Button.new()
	_make(_renown(), false, action)
	assert_eq(action.size_flags_vertical, Control.SIZE_SHRINK_CENTER)


func test_card_uses_the_card_panel_style() -> void:
	assert_eq(_make(_renown(), false).theme_type_variation, &"CardPanel")


func test_pressing_a_pressable_card_emits_pressed() -> void:
	var node := _make(_renown(), false)
	node.make_pressable("Choose it")
	watch_signals(node)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	node._gui_input(click)
	assert_signal_emitted(node, "pressed")
