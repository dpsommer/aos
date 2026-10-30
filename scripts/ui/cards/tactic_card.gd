class_name TacticCard
extends PressableCard
## A battle tactics card: in full, with each battle tactic's condition and victory points; as a
## brief list of its battle tactics' kinds, names and victory points; or as a short summary of its
## battle tactics' names for the army list.

enum Form { SUMMARY, BRIEF, FULL }

const KIND_NAMES := {"affray": "Affray", "strike": "Strike", "domination": "Domination"}


## [param heading] is shown over the card's name, e.g. "Slot 1". [param action] is shown in the top
## right corner (at the end of the name's row without a heading), e.g. a "Change" button or a chip,
## or null for none.
func _init(card: BattleTacticCard, form: Form, heading := "", action: Control = null) -> void:
	super()
	_add_title(card.name, heading, [], action)
	match form:
		Form.FULL:
			# Rules divide the card's setup, each battle tactic and its FAQs.
			if not card.text.is_empty():
				content.add_child(HSeparator.new())
				content.add_child(UIBuilder.label(card.text, "MutedLabel", true))
			for tactic in card.tactics:
				content.add_child(HSeparator.new())
				content.add_child(UIBuilder.vbox([_tactic_row(tactic), UIBuilder.label(tactic.condition, "MutedLabel", true)], 4))
			if not card.faqs.is_empty():
				content.add_child(HSeparator.new())
			for faq in card.faqs:
				content.add_child(UIBuilder.rich("[b]FAQ:[/b] %s\n[b]Answer:[/b] %s" % [
						str(faq.get("question", "")).replace("[", "[lb]"), str(faq.get("answer", "")).replace("[", "[lb]")]))
		Form.BRIEF:
			for tactic in card.tactics:
				content.add_child(_tactic_row(tactic))
		Form.SUMMARY:
			var chips := HFlowContainer.new()
			for tactic in card.tactics:
				chips.add_child(UITheme.chip(tactic.name, tactic.kind))
			content.add_child(chips)


## A battle tactic's kind, name and victory points.
static func _tactic_row(tactic: BattleTactic) -> HBoxContainer:
	return UIBuilder.hbox([UITheme.chip(KIND_NAMES.get(tactic.kind, tactic.kind), tactic.kind),
			UIBuilder.label(tactic.name), UIBuilder.spacer(), UIBuilder.label("%d VP" % tactic.victory_points, "MutedLabel")])
