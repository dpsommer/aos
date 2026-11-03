class_name SummonedUnitCard
extends PressableCard
## A unit an ability sets up, such as the Auto-Endrins a Zontari Endrin Dock releases, in short
## under that ability: its name, characteristics and the names of its weapons and abilities. Made
## pressable, it shows the full warscroll, e.g. in the Rules tab's Summoned Units section.

var warscroll: Warscroll


static func create(unit: Warscroll) -> SummonedUnitCard:
	var card: SummonedUnitCard = load("res://scenes/ui/cards/summoned_unit_card.tscn").instantiate()
	card._fill(unit)
	return card


func _fill(unit: Warscroll) -> void:
	warscroll = unit
	card_name = unit.name
	(%Title as Label).text = unit.name
	var header: HBoxContainer = %Header
	var portrait := UIBuilder.portrait(unit.name)
	header.add_child(portrait)
	header.move_child(portrait, 0)
	WarscrollCard.fill_characteristics(%Characteristics, unit)
	var chips: HFlowContainer = %Chips
	for weapon in unit.ranged_weapons + unit.melee_weapons:
		chips.add_child(UITheme.chip(weapon.name))
	for ability in unit.abilities:
		chips.add_child(UITheme.chip(ability.name))
	chips.visible = chips.get_child_count() > 0
