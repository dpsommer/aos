class_name SpearheadOptionsPicker
extends Control
## Spearhead's Pre-battle Sequence, step 2: the player picks their regiment ability and their
## general's enhancement, over the dimmed battlefield. The attacker picks first, then the defender;
## if the opponent has already picked, their choices are shown. See docs/design/battle.md.

## The player picked the regiment ability called [param regiment_ability] and the enhancement
## called [param enhancement].
signal chosen(regiment_ability: String, enhancement: String)


var army: BattleArmy
## The opponent's army, whose choices are shown if they've made them.
var opponent: BattleArmy
var is_attacker: bool
var regiment_ability := ""
var enhancement := ""
## The choice cards by group: "regiment" and "enhancement".
var cards := {"regiment": [], "enhancement": []}
var confirm_button: Button


static func create(of: BattleArmy, against: BattleArmy, attacks: bool) -> SpearheadOptionsPicker:
	var picker: SpearheadOptionsPicker = load("res://scenes/ui/battle/spearhead_options_picker.tscn").instantiate()
	picker._fill(of, against, attacks)
	return picker


func _init() -> void:
	theme = UITheme.get_theme()


func _fill(of: BattleArmy, against: BattleArmy, attacks: bool) -> void:
	army = of
	opponent = against
	is_attacker = attacks
	confirm_button = %Confirm
	(%Subtitle as Label).text = _subtitle()
	var enhancement_heading := "Enhancement · %s" % army.spearhead.general
	(%Heading as Label).text = enhancement_heading.to_upper()
	%Enhancement.accessibility_name = enhancement_heading
	_add_cards(%Regiment, "regiment", army.spearhead.regiment_abilities)
	_add_cards(%Enhancement, "enhancement", army.spearhead.enhancements)
	_refresh()


func _ready() -> void:
	if not cards.regiment.is_empty() and is_inside_tree():
		(cards.regiment[0] as Control).grab_focus()


## What's picked so far: [regiment ability, enhancement], either empty if not yet.
func selection() -> Array:
	return [regiment_ability, enhancement]


## Picks the ability called [param ability_name] in [param group] ("regiment" or "enhancement").
func pick(group: String, ability_name: String) -> void:
	if group == "regiment":
		regiment_ability = ability_name
	else:
		enhancement = ability_name
	_refresh()


func _subtitle() -> String:
	if is_attacker:
		return "You're the attacker, so you pick first. Your general takes the enhancement."
	var text := "You're the defender, so you pick second. Your general takes the enhancement."
	if opponent and not opponent.needs_spearhead_options():
		text += "\nYour opponent picked %s and %s." % [opponent.regiment_ability, opponent.enhancement]
	return text


func _add_cards(box: VBoxContainer, group: String, abilities: Array[Ability]) -> void:
	for ability in abilities:
		var card := AbilityChoiceCard.create(ability, false, "%s:%s" % [group, ability.name])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(pick.bind(group, ability.name))
		cards[group].append(card)
		box.add_child(card)


func _confirm() -> void:
	if not confirm_button.disabled:
		chosen.emit(regiment_ability, enhancement)


func _refresh() -> void:
	for group: String in cards:
		var picked: String = regiment_ability if group == "regiment" else enhancement
		for card: AbilityChoiceCard in cards[group]:
			card.selected = card.ability.name == picked
	var missing := PackedStringArray()
	if regiment_ability.is_empty() and not army.spearhead.regiment_abilities.is_empty():
		missing.append("a regiment ability")
	if enhancement.is_empty() and not army.spearhead.enhancements.is_empty():
		missing.append("an enhancement")
	confirm_button.disabled = not missing.is_empty()
	confirm_button.text = "Confirm" if missing.is_empty() else "Pick %s" % " and ".join(missing)
