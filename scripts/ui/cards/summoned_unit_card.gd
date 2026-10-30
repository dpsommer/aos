class_name SummonedUnitCard
extends PressableCard
## A unit an ability sets up, such as the Auto-Endrins a Zontari Endrin Dock releases, in short
## under that ability: its name, characteristics and the names of its weapons and abilities. Made
## pressable, it shows the full warscroll, e.g. in the Rules tab's Summoned Units section.

var warscroll: Warscroll


func _init(unit: Warscroll) -> void:
	super()
	warscroll = unit
	card_name = unit.name
	var title := UIBuilder.label(unit.name, "TitleLabel", true)
	var names := UIBuilder.vbox([UIBuilder.label("Summoned unit", "MutedLabel"), title], 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var content := UIBuilder.vbox([UIBuilder.hbox([UIBuilder.portrait(unit.name), names], 10),
			WarscrollCard.characteristic_row(unit)], 8)
	var chips := HFlowContainer.new()
	for weapon in unit.ranged_weapons + unit.melee_weapons:
		chips.add_child(UITheme.chip(weapon.name))
	for ability in unit.abilities:
		chips.add_child(UITheme.chip(ability.name))
	if chips.get_child_count() > 0:
		content.add_child(chips)
	else:
		chips.free()
	add_child(content)
