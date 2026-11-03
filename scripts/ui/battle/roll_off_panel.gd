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
var attacker_button: RoleButton
var defender_button: RoleButton
var continue_button: Button
var _finished := false
var _sequence: Tween


static func create(of: Battle, rolled: RollOff, ai_picks_attacker: bool) -> RollOffPanel:
	var panel: RollOffPanel = load("res://scenes/ui/battle/roll_off_panel.tscn").instantiate()
	panel.battle = of
	panel.roll_off = rolled
	panel.ai_attacks = ai_picks_attacker
	panel._fill_result()
	return panel


func _init() -> void:
	theme = UITheme.get_theme()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		player_die = %PlayerDie
		opponent_die = %OpponentDie
		player_value = %PlayerValue
		opponent_value = %OpponentValue
		status_label = %Status
		result_card = %Result


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


func _fill_result() -> void:
	var heading: Label = %Heading
	if roll_off.player_won():
		heading.text = "You won the roll-off. Choose your role."
		attacker_button = _role_button(true)
		defender_button = _role_button(false)
		for button in [attacker_button, defender_button]:
			%Roles.add_child(button)
		%Roles.visible = true
	else:
		var role := "defender" if ai_attacks else "attacker"
		heading.text = "The opponent won the roll-off and chose to be the %s." % ("attacker" if ai_attacks else "defender")
		var you: Label = %YourRole
		you.text = "You are the %s. %s" % [role, _role_text(not ai_attacks)]
		you.visible = true
		continue_button = %Continue
		continue_button.visible = true


func _on_continue_pressed() -> void:
	role_chosen.emit(not ai_attacks)


func _role_text(attacks: bool) -> String:
	if battle.is_spearhead():
		return "Pick your regiment ability and enhancement first, and set up your army first." if attacks \
				else "Pick the side, deployment map and territories, and set up your terrain first."
	return "Deploy first. Your territory is shown in blue." if attacks else "Deploy second, after seeing the attacker's first moves."


func _role_button(attacks: bool) -> RoleButton:
	var preview: Control
	if battle.battleplan:
		var map := BattleplanMap.new(battle.battleplan, battle.battlefield_size)
		map.player_attacks = attacks
		preview = map
	else:
		preview = UIBuilder.art("Map", 4, 11)
		preview.custom_minimum_size = Vector2(96, 70)
	var button := RoleButton.create(attacks, _role_text(attacks), preview)
	button.pressed.connect(func() -> void: role_chosen.emit(attacks))
	return button
