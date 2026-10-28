class_name LoreCard
extends PressableCard
## A spell, prayer or manifestation lore: in full, with its points and each spell or prayer's rules
## (and the warscrolls of the manifestations it summons), or as a short summary of its spells' or
## prayers' names for the army list.

## The muted heading over the lore's name, or null without one.
var heading_label: Label


## [param heading] is shown over the lore's name, e.g. "Spell Lore". [param action] is shown in the top
## right corner (at the end of the name's row without a heading), e.g. a "Change" button, or null
## for none. [param summoned], given an ability, returns the
## manifestations it summons ([method ArmyCatalog.summoned]), shown in full cards.
func _init(lore: Lore, full: bool, heading := "", action: Control = null, summoned := Callable()) -> void:
	super()
	card_name = lore.name
	var content := UIBuilder.vbox([], 8)
	# The heading and the action share the top row, so the name has the card's full width. Without a
	# heading, the action sits at the end of the name's row.
	if not heading.is_empty():
		heading_label = UIBuilder.label(heading, "MutedLabel")
		var top := UIBuilder.hbox([heading_label, UIBuilder.spacer()], 6)
		if action:
			top.add_child(action)
		content.add_child(top)
	var title := UIBuilder.label(lore.name, "TitleLabel", true)
	var title_row := UIBuilder.hbox([title], 6)
	for tag in tags(lore):
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(tag)
	if action and heading.is_empty():
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(action)
	content.add_child(title_row)
	if full:
		for ability in lore.entries:
			content.add_child(AbilityCard.new(ability))
			if summoned.is_valid():
				for manifestation: Warscroll in summoned.call(ability):
					content.add_child(WarscrollCard.new(manifestation))
	else:
		var chips := HFlowContainer.new()
		for ability in lore.entries:
			chips.add_child(UITheme.chip(ability.name))
		content.add_child(chips)
	add_child(content)


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
