class_name LoreCard
extends PressableCard
## A spell, prayer or manifestation lore: in full, with its points and each spell or prayer's rules
## (and the warscrolls of the manifestations it summons), or as a short summary of its spells' or
## prayers' names for the army list.

## [param heading] is shown over the lore's name, e.g. "Spell Lore". [param action] is shown in the top
## right corner (at the end of the name's row without a heading), e.g. a "Change" button, or null
## for none. [param summoned], given an ability, returns the manifestations and units it summons
## ([method ArmyCatalog.summoned]), shown under it ([method WarscrollCard.summoned_card]).
func _init(lore: Lore, full: bool, heading := "", action: Control = null, summoned := Callable()) -> void:
	super()
	_add_title(lore.name, heading, tags(lore), action)
	if full:
		for ability in lore.entries:
			content.add_child(AbilityCard.new(ability))
			if summoned.is_valid():
				for summoned_unit: Warscroll in summoned.call(ability):
					content.add_child(WarscrollCard.summoned_card(summoned_unit))
	else:
		var chips := HFlowContainer.new()
		for ability in lore.entries:
			chips.add_child(UITheme.chip(ability.name))
		content.add_child(chips)


## The lore's points, Scourge and Legends tags.
static func tags(lore: Lore) -> Array[Control]:
	var result: Array[Control] = []
	if lore.points > 0:
		result.append(UITheme.chip("%d pts" % lore.points, "gold"))
	var scourge := UIBuilder.scourge_tag(lore.source)
	if scourge:
		result.append(scourge)
	if lore.legends:
		result.append(UITheme.chip("Legends", "legends"))
	return result
