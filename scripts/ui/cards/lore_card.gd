class_name LoreCard
extends PressableCard
## A spell, prayer or manifestation lore: in full, with its points and each spell or prayer's rules
## (and the warscrolls of the manifestations it summons), or as a short summary of its spells' or
## prayers' names for the army list.

## [param heading] is shown over the lore's name, e.g. "Spell Lore". [param action] is shown in the top
## right corner (at the end of the name's row without a heading), e.g. a "Change" button, or null
## for none. [param summoned], given an ability, returns the manifestations and units it summons
## ([method ArmyCatalog.summoned]), shown under it ([method WarscrollCard.summoned_card]).
static func create(lore: Lore, full: bool, heading := "", action: Control = null, summoned := Callable()) -> LoreCard:
	var card: LoreCard = load("res://scenes/ui/cards/lore_card.tscn").instantiate()
	card._fill(lore, full, heading, action, summoned)
	return card


func _fill(lore: Lore, full: bool, heading: String, action: Control, summoned: Callable) -> void:
	_add_title(lore.name, heading, tags(lore), action)
	if full:
		for ability in lore.entries:
			content.add_child(AbilityCard.create(ability))
			if summoned.is_valid():
				for summoned_unit: Warscroll in summoned.call(ability):
					content.add_child(WarscrollCard.summoned_card(summoned_unit))
	else:
		_add_name_chips(lore.entries)


## The lore's points, Scourge and Legends tags.
static func tags(lore: Lore) -> Array[Control]:
	var result: Array[Control] = []
	if lore.points > 0:
		result.append(UITheme.chip("%d pts" % lore.points, "gold"))
	result.append_array(UIBuilder.source_tags(lore.source, lore.legends))
	return result
