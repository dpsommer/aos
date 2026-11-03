class_name BattleplanPicker
extends VBoxContainer
## The battlepack's battleplans to choose from: Random, then each battleplan with a small map and
## its twist. An eye shows a battleplan in full: a larger map with its terrain, its twist,
## abilities and scoring. Pressing a card chooses it.

## The player chose [param battleplan], or Random if it's empty.
signal picked(battleplan: String)

var battlepack: Battlepack
## The chosen battleplan's name, or empty for Random.
var selected := ""
## The cards by battleplan name, Random's under "".
var cards := {}
## Names of the battleplans shown in full.
var _open := {}


static func create(pack: Battlepack, chosen := "") -> BattleplanPicker:
	var picker: BattleplanPicker = load("res://scenes/ui/quick_play/battleplan_picker.tscn").instantiate()
	picker._fill(pack, chosen)
	return picker


func _fill(pack: Battlepack, chosen: String) -> void:
	battlepack = pack
	selected = chosen
	cards[""] = _random_card()
	add_child(cards[""])
	# The battlepack's tables and numbers are for rolling a battleplan on the tabletop, so they
	# aren't shown.
	for plan in battlepack.battleplans:
		cards[plan.name] = _plan_card(plan)
		add_child(cards[plan.name])


## The chosen card, to give it focus when the picker opens.
func selected_card() -> Control:
	return cards.get(selected, cards[""])


## A key for the map's colours: the attacker's and the defender's territory.
static func legend() -> HBoxContainer:
	return load("res://scenes/ui/quick_play/map_legend.tscn").instantiate()


func _random_card() -> PressableCard:
	var card := random_card("One of the %d battleplans below, picked when the battle starts." % battlepack.battleplans.size(),
			selected.is_empty(), "Pick a battleplan at random when the battle starts")
	_set_up_card(card, "Random", "")
	return card


## The Random card: [param note] under its title, a check if it's [param chosen], and
## [param description] as its tooltip.
static func random_card(note: String, chosen: bool, description: String) -> PressableCard:
	var card: PressableCard = load("res://scenes/ui/quick_play/random_choice_card.tscn").instantiate()
	(card.get_node(^"%Art") as ArtPlaceholder).corner_radius = 6
	(card.get_node(^"%Art") as ArtPlaceholder).set_icon(UITheme.icon("aos/white/fighters/gargantuan"), 36)
	(card.get_node(^"%Note") as Label).text = note
	if chosen:
		card.get_node(^"%Row").add_child(check_mark())
	card.make_pressable(description)
	return card


## A card to choose: [param preview] (e.g. a map) beside [param title] and [param subtitle], a check
## if it's [param chosen], and an eye keyed [param eye_key] that's pressed in if [param full].
## The card's [code]%Stack[/code] takes the rules shown in full.
static func choice_card(preview: Control, title: String, subtitle: String, chosen: bool, full: bool, eye_key: String) -> PressableCard:
	var card: PressableCard = load("res://scenes/ui/quick_play/choice_card.tscn").instantiate()
	var row: HBoxContainer = card.get_node(^"%Row")
	row.add_child(preview)
	row.move_child(preview, 0)
	(card.get_node(^"%ChoiceTitle") as Label).text = title
	(card.get_node(^"%Subtitle") as Label).text = subtitle
	var eye: Button = card.get_node(^"%Eye")
	if chosen:
		var check := check_mark()
		row.add_child(check)
		row.move_child(check, eye.get_index())
	eye.button_pressed = full
	eye.tooltip_text = ("Hide " if full else "Show ") + title + " rules"
	eye.accessibility_name = eye.tooltip_text
	eye.set_meta(&"focus_key", eye_key)
	card.set_meta(&"eye", eye)
	return card


## [param plan]'s card, in brief or, if it's open, in full.
func _plan_card(plan: Battleplan) -> PressableCard:
	var full: bool = _open.has(plan.name)
	var card := choice_card(BattleplanMap.new(plan, battlepack.battlefield_size), plan.name, plan.twist,
			selected == plan.name, full, "plan:" + plan.name)
	var twist: Label = card.get_node(^"%Subtitle")
	twist.max_lines_visible = 2
	twist.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_set_up_card(card, plan.name, plan.name)
	var content: VBoxContainer = card.get_node(^"%Stack")
	if full:
		content.add_child(HSeparator.new())
		content.add_child(BattleplanMap.new(plan, battlepack.battlefield_size, true))
		content.add_child(UIBuilder.label("%d\" × %d\" · dashed: terrain · gold rings: objectives with their %d\" control zone" % [
				battlepack.battlefield_size.x, battlepack.battlefield_size.y, BattleplanMap.CONTROL_RANGE], "MutedLabel", true))
		if not plan.text.is_empty():
			content.add_child(rules_block("Setup", plan.text))
		content.add_child(rules_block("Twist", plan.twist))
		for ability in plan.abilities:
			content.add_child(AbilityCard.create(ability))
		if not plan.scoring.is_empty():
			content.add_child(rules_block("Scoring", "\n".join(plan.scoring)))
	card.make_pressable("Choose " + plan.name)
	(card.get_meta(&"eye") as Button).toggled.connect(_on_eye_toggled.bind(plan))
	return card


func _set_up_card(card: PressableCard, card_name: String, battleplan: String) -> void:
	card.card_name = card_name
	if battleplan == selected:
		card.theme_type_variation = "PickedCardPanel"
	card.pressed.connect(_pick.bind(battleplan))


func _pick(battleplan: String) -> void:
	selected = battleplan
	picked.emit(battleplan)


## Swaps [param plan]'s card for the other form in place, so the list keeps its scroll, and keeps
## focus on its eye.
func _on_eye_toggled(on: bool, plan: Battleplan) -> void:
	if on:
		_open[plan.name] = true
	else:
		_open.erase(plan.name)
	var old: Control = cards[plan.name]
	var index := old.get_index()
	remove_child(old)
	old.queue_free()
	cards[plan.name] = _plan_card(plan)
	add_child(cards[plan.name])
	move_child(cards[plan.name], index)
	(cards[plan.name].get_meta(&"eye") as Button).grab_focus()


static func check_mark() -> Control:
	var check := UIBuilder.check_badge()
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return check


## A heading over rules text.
static func rules_block(heading: String, text: String) -> VBoxContainer:
	var block: VBoxContainer = load("res://scenes/ui/quick_play/rules_block.tscn").instantiate()
	(block.get_node(^"%Heading") as Label).text = heading.to_upper()
	(block.get_node(^"%Text") as Label).text = text
	return block
