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
static func create(card: BattleTacticCard, form: Form, heading := "", action: Control = null) -> TacticCard:
	var node: TacticCard = load("res://scenes/ui/cards/tactic_card.tscn").instantiate()
	node._fill(card, form, heading, action)
	return node


func _fill(card: BattleTacticCard, form: Form, heading: String, action: Control) -> void:
	_add_title(card.name, heading, [], action)
	match form:
		Form.FULL:
			# Rules divide the card's setup, each battle tactic and its FAQs.
			if not card.text.is_empty():
				content.add_child(HSeparator.new())
				content.add_child(UIBuilder.label(card.text, "MutedLabel", true))
			for tactic in card.tactics:
				content.add_child(HSeparator.new())
				var entry: VBoxContainer = load("res://scenes/ui/cards/tactic_entry.tscn").instantiate()
				(entry.get_node(^"%Condition") as Label).text = tactic.condition
				var row := _tactic_row(tactic)
				entry.add_child(row)
				entry.move_child(row, 0)
				content.add_child(entry)
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
	var row: HBoxContainer = load("res://scenes/ui/cards/tactic_row.tscn").instantiate()
	var kind := UITheme.chip(KIND_NAMES.get(tactic.kind, tactic.kind), tactic.kind)
	row.add_child(kind)
	row.move_child(kind, 0)
	(row.get_node(^"%TacticName") as Label).text = tactic.name
	(row.get_node(^"%Points") as Label).text = "%d VP" % tactic.victory_points
	return row
