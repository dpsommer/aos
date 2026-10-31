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


func _init(pack: Battlepack, chosen := "") -> void:
	battlepack = pack
	selected = chosen
	add_theme_constant_override("separation", 8)
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
	var row := UIBuilder.hbox([], 10)
	for pair: Array in [["Attacker", BattleplanMap.ATTACKER], ["Defender", BattleplanMap.DEFENDER]]:
		var swatch := ColorRect.new()
		swatch.color = Color(pair[1], 1)
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(UIBuilder.hbox([swatch, UIBuilder.label(pair[0], "MutedLabel")], 4))
	return row


func _random_card() -> PressableCard:
	var card := _card("Random", "")
	var art := UIBuilder.icon_art(UITheme.icon("aos/white/fighters/gargantuan"), 36, 6)
	art.get_child(0).modulate = UITheme.TEXT
	art.custom_minimum_size = Vector2(96, 70)
	var count := battlepack.battleplans.size()
	var text := UIBuilder.vbox([UIBuilder.label("Random", "TitleLabel"),
			UIBuilder.label("One of the %d battleplans below, picked when the battle starts." % count, "MutedLabel", true)], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIBuilder.hbox([art, text], 12)
	if selected.is_empty():
		row.add_child(check_mark())
	card.add_child(row)
	card.make_pressable("Pick a battleplan at random when the battle starts")
	return card


## [param plan]'s card, in brief or, if it's open, in full.
func _plan_card(plan: Battleplan) -> PressableCard:
	var full: bool = _open.has(plan.name)
	var card := _card(plan.name, plan.name)
	var title := UIBuilder.label(plan.name, "TitleLabel", true)
	var twist := UIBuilder.label(plan.twist, "MutedLabel", true)
	twist.max_lines_visible = 2
	twist.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var text := UIBuilder.vbox([title, twist], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIBuilder.hbox([BattleplanMap.new(plan, battlepack.battlefield_size), text], 12)
	if selected == plan.name:
		row.add_child(check_mark())
	var eye := UIBuilder.icon_toggle("eye", ("Hide " if full else "Show ") + plan.name + " rules", full,
			func(_on: bool) -> void: pass, "plan:" + plan.name)
	eye.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(eye)
	var content := UIBuilder.vbox([row], 12)
	if full:
		content.add_child(HSeparator.new())
		content.add_child(BattleplanMap.new(plan, battlepack.battlefield_size, true))
		content.add_child(UIBuilder.label("%d\" × %d\" · dashed: terrain · gold rings: objectives with their %d\" control zone" % [
				battlepack.battlefield_size.x, battlepack.battlefield_size.y, BattleplanMap.CONTROL_RANGE], "MutedLabel", true))
		if not plan.text.is_empty():
			content.add_child(rules_block("Setup", plan.text))
		content.add_child(rules_block("Twist", plan.twist))
		for ability in plan.abilities:
			content.add_child(AbilityCard.new(ability))
		if not plan.scoring.is_empty():
			content.add_child(rules_block("Scoring", "\n".join(plan.scoring)))
	card.add_child(content)
	card.make_pressable("Choose " + plan.name)
	card.set_meta(&"eye", eye)
	eye.toggled.connect(_on_eye_toggled.bind(plan))
	return card


func _card(card_name: String, battleplan: String) -> PressableCard:
	var card := PressableCard.new()
	card.card_name = card_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if battleplan == selected:
		card.theme_type_variation = "PickedCardPanel"
	card.pressed.connect(_pick.bind(battleplan))
	return card


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
	var title := UIBuilder.label(heading.to_upper(), "StatNameLabel")
	title.add_theme_color_override("font_color", UITheme.TEXT)
	return UIBuilder.vbox([title, UIBuilder.label(text, "BodyLabel", true)], 4)
