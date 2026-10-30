class_name FormationCard
extends PressableCard
## A battle formation: its name and points, with its abilities' names, or in full with their rules.

## [param action] is shown at the end of the name's row, e.g. a "Change" button, or null for none.
func _init(formation: BattleFormation, full: bool, action: Control = null) -> void:
	super()
	var tags: Array[Control] = []
	if formation.points > 0:
		tags.append(UITheme.chip("%d pts" % formation.points, "gold"))
	_add_title(formation.name, "", tags, action)
	if full:
		for ability in formation.abilities:
			content.add_child(AbilityCard.new(ability))
	else:
		var chips := HFlowContainer.new()
		for ability in formation.abilities:
			chips.add_child(UITheme.chip(ability.name))
		content.add_child(chips)
