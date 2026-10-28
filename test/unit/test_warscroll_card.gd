extends GutTest
## Unit tests for the warscroll card (scripts/ui/forge/builder/warscroll_card.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func _weapon(weapon_name := "Blade", range_inches := 0, rend := 1, abilities := PackedStringArray()) -> Weapon:
	var weapon := Weapon.new()
	weapon.name = weapon_name
	weapon.range = range_inches
	weapon.attacks = "2"
	weapon.hit = 3
	weapon.wound = 4
	weapon.rend = rend
	weapon.damage = "D3"
	weapon.abilities = abilities
	return weapon


func _scroll() -> Warscroll:
	var scroll := Kit.warscroll("grunt", PackedStringArray(["INFANTRY", "CHAMPION"]), 120, "Grunt Boyz")
	scroll.move = "5"
	scroll.health = 4
	scroll.save = 4
	scroll.control = 2
	return scroll


func _card(scroll: Warscroll, summoned := Callable()) -> WarscrollCard:
	var card := WarscrollCard.new(scroll, summoned)
	add_child_autofree(card)
	return card


func _names(stats: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for stat: Array in stats:
		result.append(stat[0])
	return result


func _value_of(stats: Array, key: String) -> String:
	for stat: Array in stats:
		if stat[0] == key:
			return stat[1]
	return ""


func _labels(node: Node, variation: String) -> Array[Node]:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is Label and n.theme_type_variation == variation)


func _table_count(node: Node) -> int:
	return _labels(node, "WeaponTitleLabel").size()


func test_card_shows_the_units_name() -> void:
	assert_true(UIKit.has_label_containing(_card(_scroll()), "Grunt Boyz"))


func test_subtitle_shows_points() -> void:
	assert_true(UIKit.has_label_containing(_card(_scroll()), "120 pts"))


func test_subtitle_shows_model_count() -> void:
	assert_true(UIKit.has_label_containing(_card(_scroll()), "5 models"))


func test_single_model_is_not_pluralised() -> void:
	var scroll := _scroll()
	scroll.unit_size = 1
	var card := _card(scroll)
	assert_true(UIKit.has_label_containing(card, "1 model"))
	assert_false(UIKit.has_label_containing(card, "1 models"))


func test_subtitle_shows_base_size() -> void:
	var scroll := _scroll()
	scroll.base_size = "32mm"
	assert_true(UIKit.has_label_containing(_card(scroll), "32mm base"))


func test_zero_points_are_not_shown() -> void:
	var scroll := _scroll()
	scroll.points = 0
	assert_false(UIKit.has_label_containing(_card(scroll), "pts"))


func test_legends_unit_has_a_legends_chip() -> void:
	var scroll := _scroll()
	scroll.legends = true
	assert_true(UIKit.has_label_containing(_card(scroll), "LEGENDS"))


func test_ordinary_unit_has_no_legends_chip() -> void:
	assert_false(UIKit.has_label_containing(_card(_scroll()), "LEGENDS"))


func test_unit_characteristics_include_control() -> void:
	var names := _names(WarscrollCard.characteristics(_scroll()))
	assert_has(names, "Control")
	assert_does_not_have(names, "Banish")


func test_manifestation_shows_banish_in_place_of_control() -> void:
	var scroll := _scroll()
	scroll.banishment = 5
	var names := _names(WarscrollCard.characteristics(scroll))
	assert_has(names, "Banish")
	assert_does_not_have(names, "Control")


func test_ward_is_shown_only_when_there_is_one() -> void:
	var scroll := _scroll()
	assert_does_not_have(_names(WarscrollCard.characteristics(scroll)), "Ward")
	scroll.ward = 5
	assert_has(_names(WarscrollCard.characteristics(scroll)), "Ward")


func test_move_of_zero_is_shown_as_a_dash() -> void:
	var scroll := _scroll()
	scroll.move = "0"
	assert_eq(_value_of(WarscrollCard.characteristics(scroll), "Move"), "-")


func test_nonzero_move_shows_the_distance() -> void:
	assert_string_contains(_value_of(WarscrollCard.characteristics(_scroll()), "Move"), "5")


func test_ranged_weapon_values_start_with_the_range() -> void:
	var values := WarscrollCard.weapon_values(_weapon("Bow", 18), true)
	assert_string_contains(values[0], "18")
	assert_eq(values.size(), 6)


func test_melee_weapon_values_have_no_range() -> void:
	assert_eq(WarscrollCard.weapon_values(_weapon(), false).size(), 5)


func test_zero_rend_is_shown_as_a_dash() -> void:
	var values := WarscrollCard.weapon_values(_weapon("Blade", 0, 0), false)
	assert_has(values, "-")


func test_positive_rend_is_shown_as_a_number() -> void:
	var values := WarscrollCard.weapon_values(_weapon("Blade", 0, 2), false)
	assert_has(values, "2")
	assert_does_not_have(values, "-")


func test_no_weapons_means_no_weapon_tables() -> void:
	assert_eq(_table_count(_card(_scroll())), 0)


func test_melee_only_unit_has_one_table() -> void:
	var scroll := _scroll()
	scroll.melee_weapons = [_weapon()] as Array[Weapon]
	var card := _card(scroll)
	assert_eq(_table_count(card), 1)
	assert_true(UIKit.has_label_containing(card, "MELEE"))
	assert_false(UIKit.has_label_containing(card, "RANGED"))


func test_ranged_only_unit_has_one_table() -> void:
	var scroll := _scroll()
	scroll.ranged_weapons = [_weapon("Bow", 18)] as Array[Weapon]
	var card := _card(scroll)
	assert_eq(_table_count(card), 1)
	assert_true(UIKit.has_label_containing(card, "RANGED"))
	assert_false(UIKit.has_label_containing(card, "MELEE"))


func test_unit_with_both_kinds_has_two_tables() -> void:
	var scroll := _scroll()
	scroll.ranged_weapons = [_weapon("Bow", 18)] as Array[Weapon]
	scroll.melee_weapons = [_weapon()] as Array[Weapon]
	assert_eq(_table_count(_card(scroll)), 2)


func test_each_weapon_is_named() -> void:
	var scroll := _scroll()
	scroll.melee_weapons = [_weapon("Axe"), _weapon("Hammer")] as Array[Weapon]
	var card := _card(scroll)
	assert_true(UIKit.has_label_containing(card, "Axe"))
	assert_true(UIKit.has_label_containing(card, "Hammer"))


func test_melee_value_columns_line_up_with_ranged_ones() -> void:
	var scroll := _scroll()
	scroll.ranged_weapons = [_weapon("Bow", 18)] as Array[Weapon]
	scroll.melee_weapons = [_weapon()] as Array[Weapon]
	var cells := _labels(_card(scroll), "WeaponValueLabel")
	assert_eq(cells.size(), 11)
	var ranged_trailing := cells.slice(1, 6)
	var melee := cells.slice(6)
	for i in melee.size():
		assert_eq((melee[i] as Control).custom_minimum_size.x, (ranged_trailing[i] as Control).custom_minimum_size.x)


func test_weapon_abilities_are_shown_under_the_weapon() -> void:
	var scroll := _scroll()
	scroll.melee_weapons = [_weapon("Axe", 0, 1, PackedStringArray(["Anti-Cavalry", "Charge"]))] as Array[Weapon]
	assert_true(UIKit.has_label_containing(_card(scroll), "Anti-Cavalry, Charge"))


func test_weapon_without_abilities_shows_no_ability_line() -> void:
	var scroll := _scroll()
	scroll.melee_weapons = [_weapon("Axe")] as Array[Weapon]
	assert_eq(_labels(_card(scroll), "MutedLabel").size(), 1)


func test_each_ability_gets_a_rich_text_label() -> void:
	var scroll := _scroll()
	scroll.abilities = [Kit.ability("One"), Kit.ability("Two")] as Array[Ability]
	var rich := UIKit.find_all(_card(scroll), func(n: Node) -> bool: return n is RichTextLabel)
	assert_gte(rich.size(), 2)


func test_no_nested_cards_without_a_summoned_callable() -> void:
	var scroll := _scroll()
	scroll.abilities = [Kit.ability("Summon")] as Array[Ability]
	var nested := UIKit.find_all(_card(scroll), func(n: Node) -> bool: return n is WarscrollCard)
	assert_eq(nested.size(), 0)


func test_summoned_manifestations_get_a_nested_card_each() -> void:
	var scroll := _scroll()
	scroll.abilities = [Kit.ability("Summon")] as Array[Ability]
	var summoned := func(_rule: Ability) -> Array[Warscroll]:
		return [Kit.warscroll("a", PackedStringArray(), 0, "Spirit A"), Kit.warscroll("b", PackedStringArray(), 0, "Spirit B")]
	var card := _card(scroll, summoned)
	var nested := UIKit.find_all(card, func(n: Node) -> bool: return n is WarscrollCard)
	assert_eq(nested.size(), 2)
	assert_true(UIKit.has_label_containing(card, "Spirit A"))
	assert_true(UIKit.has_label_containing(card, "Spirit B"))


func test_keywords_are_shown() -> void:
	var card := _card(_scroll())
	assert_true(UIKit.has_label_containing(card, "INFANTRY"))
	assert_true(UIKit.has_label_containing(card, "CHAMPION"))
