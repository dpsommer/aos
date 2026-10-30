extends GutTest
## Unit tests for the short card of a unit an ability summons (scripts/ui/cards/summoned_unit_card.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func _unit() -> Warscroll:
	var unit := Kit.warscroll("auto", PackedStringArray(["CONSTRUCT"]), 0, "Auto-Endrin")
	unit.move = "5"
	unit.health = 3
	var hammer := Weapon.new()
	hammer.name = "Cog Hammer"
	unit.melee_weapons = [hammer] as Array[Weapon]
	var gun := Weapon.new()
	gun.name = "Steam Gun"
	unit.ranged_weapons = [gun] as Array[Weapon]
	unit.abilities = [Kit.ability("Wind Up")] as Array[Ability]
	return unit


func _card(unit: Warscroll = null) -> SummonedUnitCard:
	var card := SummonedUnitCard.new(unit if unit else _unit())
	add_child_autofree(card)
	return card


func test_card_shows_the_units_name() -> void:
	assert_true(UIKit.has_label_containing(_card(), "Auto-Endrin"))


func test_card_shows_the_units_characteristics() -> void:
	var unit := _unit()
	var card := _card(unit)
	for stat: Array in WarscrollCard.characteristics(unit):
		assert_true(UIKit.has_label_containing(card, stat[0].to_upper()), stat[0])


func test_card_names_the_weapons() -> void:
	var card := _card()
	assert_true(_shows(card, "Cog Hammer"))
	assert_true(_shows(card, "Steam Gun"))


func test_card_names_the_abilities() -> void:
	assert_true(_shows(_card(), "Wind Up"))


func test_card_without_weapons_or_abilities_still_shows_the_name() -> void:
	var card := _card(Kit.warscroll("plain", PackedStringArray(), 0, "Plain Thing"))
	assert_true(UIKit.has_label_containing(card, "Plain Thing"))


func test_card_is_not_pressable_until_made_so() -> void:
	assert_false(_card().pressable)


## Chips show their text in capitals.
func _shows(card: Node, text: String) -> bool:
	return Array(UIKit.label_texts(card)).any(func(t: String) -> bool: return t.to_lower() == text.to_lower())
