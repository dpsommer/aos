class_name RenownArmyCard
extends PressableCard
## An Army of Renown: its name, source, roster options and limits, and in full its battle traits.

## [param action] is shown at the end of the name's row, e.g. a "Change" button, or null for none.
func _init(renown: ArmyOfRenown, full: bool, action: Control = null) -> void:
	super()
	var tags: Array[Control] = []
	if not renown.source.is_empty():
		tags.append(UIBuilder.label(renown.source, "MutedLabel"))
	_add_title(renown.name, "", tags, action)
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
