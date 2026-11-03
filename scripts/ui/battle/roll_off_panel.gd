class_name RollOffPanel
extends Control
## The roll-off over the dimmed battlefield (the design's board 4): each side's dice tumbles and
## lands, a tie is rolled again ("Tie: rolling again"), and the winner picks attacker or defender. If the player won they
## choose with the Attacker and Defender buttons; if the AI won, a banner says which role the
## player has and Continue goes on. See docs/design/battle.md.

## The player's role is settled: [param player_attacks] if they are the attacker.
signal role_chosen(player_attacks: bool)

## How long the dice tumble before landing, per roll, in seconds.
const TUMBLE_SECONDS := 0.9
## How long a tie stays up before the dice roll again.
const TIE_SECONDS := 0.8
const DIM := Color(0.047, 0.051, 0.063, 0.72)
const PLAYER_PIPS := Color("#24527E")
const OPPONENT_PIPS := Color("#8C2A24")
## A role button's smallest size; it grows taller to fit its description.
const ROLE_BUTTON_SIZE := Vector2(400, 104)
## How wide a role's description wraps.
const ROLE_TEXT_WIDTH := 250.0

var battle: Battle
var roll_off: RollOff
## Whether the AI picks attacker if it wins.
var ai_attacks: bool
var player_die: DieFace
var opponent_die: DieFace
var player_value: Label
var opponent_value: Label
var status_label: Label
## The result card: role buttons or the AI's choice. Hidden until the dice land.
var result_card: PanelContainer
var attacker_button: Button
var defender_button: Button
var continue_button: Button
var _finished := false
var _sequence: Tween


func _init(of: Battle, rolled: RollOff, ai_picks_attacker: bool) -> void:
	battle = of
	roll_off = rolled
	ai_attacks = ai_picks_attacker
	name = "RollOffPanel"
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title := UIBuilder.label("Roll-off", "DisplayTitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := UIBuilder.label("The winner picks who is the attacker. The attacker deploys first.", "DescriptionLabel")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_die = DieFace.new(140, PLAYER_PIPS)
	opponent_die = DieFace.new(110, OPPONENT_PIPS)
	player_value = _value_label()
	opponent_value = _value_label()
	var dice := UIBuilder.hbox([
		_die_column(player_die, "YOU", Color("#7FA9D6"), player_value),
		_die_column(opponent_die, "OPPONENT", Color("#E58A80"), opponent_value),
	], 160)
	dice.alignment = BoxContainer.ALIGNMENT_CENTER
	status_label = UIBuilder.label("", "DescriptionLabel")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_card = _result_card()
	result_card.visible = false
	var column := UIBuilder.vbox([title, subtitle, dice, status_label, result_card], 24)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(column)
	add_child(center)


func _ready() -> void:
	play()


## Rolls the dice: each roll tumbles and lands, ties say so and roll again, then the result shows.
func play() -> void:
	if _sequence:
		_sequence.kill()
	_sequence = create_tween()
	for i in roll_off.rolls.size():
		var dice := roll_off.rolls[i]
		_sequence.tween_callback(_tumble.bind(true))
		_sequence.tween_interval(TUMBLE_SECONDS)
		_sequence.tween_callback(_land.bind(dice, i < roll_off.rolls.size() - 1))
		if i < roll_off.rolls.size() - 1:
			_sequence.tween_interval(TIE_SECONDS)
	_sequence.tween_callback(_show_result)


## Skips the dice to the result.
func finish() -> void:
	if _sequence:
		_sequence.kill()
	_land(roll_off.final(), false)
	_show_result()


func _tumble(on: bool) -> void:
	player_die.tumbling = on
	opponent_die.tumbling = on
	status_label.text = "Rolling…" if on else status_label.text
	player_value.text = ""
	opponent_value.text = ""


func _land(dice: Vector2i, is_tie: bool) -> void:
	_tumble(false)
	player_die.value = dice.x
	opponent_die.value = dice.y
	player_value.text = str(dice.x)
	opponent_value.text = str(dice.y)
	status_label.text = "Tie: rolling again" if is_tie else ""


func _show_result() -> void:
	if _finished:
		return
	_finished = true
	result_card.visible = true
	if is_inside_tree():
		(attacker_button if roll_off.player_won() else continue_button).grab_focus()


func _result_card() -> PanelContainer:
	var parts: Array = []
	if roll_off.player_won():
		var heading := UIBuilder.label("You won the roll-off. Choose your role.", "GoldTitleLabel")
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		attacker_button = _role_button(true)
		defender_button = _role_button(false)
		parts = [heading, UIBuilder.hbox([attacker_button, defender_button], 16)]
	else:
		var role := "defender" if ai_attacks else "attacker"
		var heading := UIBuilder.label("The opponent won the roll-off and chose to be the %s." % ("attacker" if ai_attacks else "defender"), "GoldTitleLabel")
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var you := UIBuilder.label("You are the %s. %s" % [role, _role_text(not ai_attacks)], "DescriptionLabel")
		you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		continue_button = UIBuilder.button("Continue", func() -> void: role_chosen.emit(not ai_attacks), "continue", "GoldButton")
		continue_button.custom_minimum_size = Vector2(220, 44)
		continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		parts = [heading, you, continue_button]
	var card := UIBuilder.panel("CardPanel", UIBuilder.vbox(parts, 16))
	card.name = "Result"
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return card


func _role_text(attacks: bool) -> String:
	if battle.is_spearhead():
		return "Pick your regiment ability and enhancement first, and set up your army first." if attacks \
				else "Pick the side, deployment map and territories, and set up your terrain first."
	return "Deploy first. Your territory is shown in blue." if attacks else "Deploy second, after seeing the attacker's first moves."


func _role_button(attacks: bool) -> Button:
	var button := Button.new()
	button.name = "AttackerButton" if attacks else "DefenderButton"
	button.theme_type_variation = "OptionCard"
	button.custom_minimum_size = ROLE_BUTTON_SIZE
	button.accessibility_name = "%s: %s" % ["Attacker" if attacks else "Defender", _role_text(attacks)]
	button.pressed.connect(func() -> void: role_chosen.emit(attacks))
	var preview: Control
	if battle.battleplan:
		var map := BattleplanMap.new(battle.battleplan, battle.battlefield_size)
		map.player_attacks = attacks
		preview = map
	else:
		preview = UIBuilder.art("Map", 4, 11)
		preview.custom_minimum_size = Vector2(96, 70)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UIBuilder.label("Attacker" if attacks else "Defender", "CardTitleLabel")
	var text := UIBuilder.label(_role_text(attacks), "DescriptionLabel", true)
	text.custom_minimum_size.x = ROLE_TEXT_WIDTH
	var words := UIBuilder.vbox([name_label, text], 4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIBuilder.hbox([preview, words], 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(row)
	button.add_child(margin)
	# A button doesn't grow to fit its children: grow it to fit the wrapped description.
	margin.minimum_size_changed.connect(_fit_role_button.bind(button, margin))
	_fit_role_button.call_deferred(button, margin)
	return button


## Untyped, as the deferred call can come after the panel is freed, which a typed argument rejects.
static func _fit_role_button(button: Variant, content: Variant) -> void:
	if is_instance_valid(button) and is_instance_valid(content):
		(button as Button).custom_minimum_size.y = maxf(ROLE_BUTTON_SIZE.y, (content as Control).get_combined_minimum_size().y)


func _value_label() -> Label:
	var label := UIBuilder.label("", "DisplayTitleLabel")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = 48
	return label


func _die_column(die: DieFace, who: String, colour: Color, value: Label) -> VBoxContainer:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(160, 160)
	holder.add_child(die)
	var who_label := UIBuilder.label(who)
	who_label.add_theme_color_override("font_color", colour)
	who_label.add_theme_font_size_override("font_size", 12)
	who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var column := UIBuilder.vbox([holder, who_label, value], 8)
	column.alignment = BoxContainer.ALIGNMENT_END
	return column
