class_name FormationCard
extends PressableCard
## A battle formation: its name and points, with its abilities' names, or in full with their rules.

## [param action] is shown at the end of the name's row, e.g. a "Change" button, or null for none.
static func create(formation: BattleFormation, full: bool, action: Control = null) -> FormationCard:
	var card: FormationCard = load("res://scenes/ui/cards/formation_card.tscn").instantiate()
	card._fill(formation, full, action)
	return card


func _fill(formation: BattleFormation, full: bool, action: Control) -> void:
	var tags := UIBuilder.source_tags(formation.source, formation.legends)
	if formation.points > 0:
		tags.append(UITheme.chip("%d pts" % formation.points, "gold"))
	_add_title(formation.name, "", tags, action)
	if full:
		for ability in formation.abilities:
			content.add_child(AbilityCard.create(ability))
	else:
		_add_name_chips(formation.abilities)
