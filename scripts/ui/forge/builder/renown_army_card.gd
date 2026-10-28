class_name RenownArmyCard
extends PressableCard
## An Army of Renown: its name, source, roster options and limits, and in full its battle traits.

## [param action] is shown at the end of the name's row, e.g. a "Change" button, or null for none.
func _init(renown: ArmyOfRenown, full: bool, action: Control = null) -> void:
	super()
	card_name = renown.name
	var content := UIBuilder.vbox([], 8)
	var title := UIBuilder.label(renown.name, "TitleLabel", true)
	var title_row := UIBuilder.hbox([title], 6)
	if not renown.source.is_empty():
		var source := UIBuilder.label(renown.source, "MutedLabel")
		source.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(source)
	if action:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(action)
	content.add_child(title_row)
	var roster := Forge.roster_summary(renown)
	if not roster.is_empty():
		content.add_child(UIBuilder.label(roster, "MutedLabel", true))
	var chips := HFlowContainer.new()
	for chip: Array in Forge.renown_chips_for(renown):
		chips.add_child(UITheme.chip(chip[0], chip[1]))
	if chips.get_child_count() > 0:
		content.add_child(chips)
	else:
		chips.free()
	if full:
		for ability in renown.battle_traits:
			content.add_child(AbilityCard.new(ability))
	add_child(content)
