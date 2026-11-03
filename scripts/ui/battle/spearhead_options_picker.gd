class_name SpearheadOptionsPicker
extends Control
## Spearhead's Pre-battle Sequence, step 2: the player picks their regiment ability and their
## general's enhancement, over the dimmed battlefield. The attacker picks first, then the defender;
## if the opponent has already picked, their choices are shown. See docs/design/battle.md.

## The player picked the regiment ability called [param regiment_ability] and the enhancement
## called [param enhancement].
signal chosen(regiment_ability: String, enhancement: String)

const DIM := Color(0.047, 0.051, 0.063, 0.72)
const COLUMN_WIDTH := 380.0

var army: BattleArmy
## The opponent's army, whose choices are shown if they've made them.
var opponent: BattleArmy
var is_attacker: bool
var regiment_ability := ""
var enhancement := ""
## The choice cards by group: "regiment" and "enhancement".
var cards := {"regiment": [], "enhancement": []}
var confirm_button: Button


func _init(of: BattleArmy, against: BattleArmy, attacks: bool) -> void:
	army = of
	opponent = against
	is_attacker = attacks
	name = "SpearheadOptionsPicker"
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title := UIBuilder.label("Pick your regiment ability and enhancement", "DisplayTitleLabel", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wraps to the panel's width rather than running off a small screen.
	title.custom_minimum_size.x = COLUMN_WIDTH * 2 + 80
	var subtitle := UIBuilder.label(_subtitle(), "DescriptionLabel", true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var columns := UIBuilder.hbox([
		_column("regiment", "Regiment ability", army.spearhead.regiment_abilities),
		_column("enhancement", "Enhancement · %s" % army.spearhead.general, army.spearhead.enhancements),
	], 24)
	confirm_button = UIBuilder.button("Confirm", _confirm, "confirm", "GoldButton")
	confirm_button.custom_minimum_size = Vector2(220, 44)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card := UIBuilder.panel("CardPanel", UIBuilder.vbox([columns, confirm_button], 16))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var column := UIBuilder.vbox([title, subtitle, card], 20)
	column.custom_minimum_size.x = COLUMN_WIDTH * 2 + 80
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(column)
	scroll.add_child(center)
	add_child(scroll)
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


func _column(group: String, heading: String, abilities: Array[Ability]) -> VBoxContainer:
	var box := UIBuilder.vbox([UIBuilder.label(heading.to_upper(), "StatNameLabel")], 10)
	box.custom_minimum_size.x = COLUMN_WIDTH
	box.accessibility_name = heading
	for ability in abilities:
		var card := AbilityChoiceCard.new(ability, false, "%s:%s" % [group, ability.name])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(pick.bind(group, ability.name))
		cards[group].append(card)
		box.add_child(card)
	return box


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
