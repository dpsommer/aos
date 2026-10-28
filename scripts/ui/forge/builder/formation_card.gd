class_name FormationCard
extends PressableCard
## A battle formation: its name and points, with its abilities' names, or in full with their rules.

## [param action] is shown at the end of the name's row, e.g. a "Change" button, or null for none.
func _init(formation: BattleFormation, full: bool, action: Control = null) -> void:
	super()
	card_name = formation.name
	var content := UIBuilder.vbox([], 8)
	var title := UIBuilder.label(formation.name, "TitleLabel", true)
	var title_row := UIBuilder.hbox([title], 6)
	if formation.points > 0:
		var points := UITheme.chip("%d pts" % formation.points, "gold")
		points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(points)
	if action:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(action)
	content.add_child(title_row)
	if full:
		for ability in formation.abilities:
			content.add_child(AbilityCard.new(ability))
	else:
		var chips := HFlowContainer.new()
		for ability in formation.abilities:
			chips.add_child(UITheme.chip(ability.name))
		content.add_child(chips)
	add_child(content)
