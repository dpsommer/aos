class_name TacticCard
extends PanelContainer
## A battle tactics card: in full, with each battle tactic's condition and victory points, or as a
## short summary of its battle tactics' names for the army list.

const KIND_NAMES := {"affray": "Affray", "strike": "Strike", "domination": "Domination"}


## [param action] is shown beside the card's name, e.g. a "Choose" or "Change" button or a chip, or
## null for none.
func _init(card: BattleTacticCard, full: bool, heading := "", action: Control = null) -> void:
	theme_type_variation = "CardPanel"
	var content := UIBuilder.vbox([], 8)
	if not heading.is_empty():
		content.add_child(UIBuilder.label(heading, "MutedLabel"))
	var title := UIBuilder.label(card.name, "TitleLabel", true)
	content.add_child(UIBuilder.hbox([title, action] if action else [title]))
	if full:
		if not card.text.is_empty():
			content.add_child(UIBuilder.label(card.text, "MutedLabel", true))
		for tactic in card.tactics:
			var name_row := UIBuilder.hbox([UITheme.chip(KIND_NAMES.get(tactic.kind, tactic.kind), tactic.kind),
					UIBuilder.label(tactic.name), UIBuilder.spacer(), UIBuilder.label("%d VP" % tactic.victory_points, "MutedLabel")])
			content.add_child(UIBuilder.vbox([name_row, UIBuilder.label(tactic.condition, "MutedLabel", true)], 4))
		for faq in card.faqs:
			content.add_child(UIBuilder.rich("[b]FAQ:[/b] %s\n[b]Answer:[/b] %s" % [
					str(faq.get("question", "")).replace("[", "[lb]"), str(faq.get("answer", "")).replace("[", "[lb]")]))
	else:
		var chips := HFlowContainer.new()
		for tactic in card.tactics:
			chips.add_child(UITheme.chip(tactic.name, tactic.kind))
		content.add_child(chips)
	add_child(content)
