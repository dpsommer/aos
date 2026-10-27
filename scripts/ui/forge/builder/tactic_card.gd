class_name TacticCard
extends PanelContainer
## A battle tactics card: in full, with each battle tactic's condition and victory points, or as a
## short summary of its battle tactics' names for the army list.

const KIND_NAMES := {"affray": "Affray", "strike": "Strike", "domination": "Domination"}


## [param action] is a button shown on the card, e.g. "Choose" or "Change", or null for none.
func _init(card: BattleTacticCard, full: bool, heading := "", action: Button = null) -> void:
	theme_type_variation = "CardPanel"
	var content := BuilderUI.vbox([], 8)
	if not heading.is_empty():
		content.add_child(BuilderUI.label(heading, "MutedLabel"))
	var title := BuilderUI.label(card.name, "TitleLabel", true)
	content.add_child(BuilderUI.hbox([title, action] if action else [title]))
	if full:
		if not card.text.is_empty():
			content.add_child(BuilderUI.label(card.text, "MutedLabel", true))
		for tactic in card.tactics:
			var name_row := BuilderUI.hbox([ForgeTheme.chip(KIND_NAMES.get(tactic.kind, tactic.kind), tactic.kind),
					BuilderUI.label(tactic.name), BuilderUI.spacer(), BuilderUI.label("%d VP" % tactic.victory_points, "MutedLabel")])
			content.add_child(BuilderUI.vbox([name_row, BuilderUI.label(tactic.condition, "MutedLabel", true)], 4))
	else:
		var chips := HFlowContainer.new()
		for tactic in card.tactics:
			chips.add_child(ForgeTheme.chip(tactic.name, tactic.kind))
		content.add_child(chips)
	add_child(content)
