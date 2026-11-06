class_name AbilityTiming
extends RefCounted
## An ability's timing string, as the rules can use it: "Your Hero Phase" is the hero window in your
## turn. See Core Rules 13.0. [AbilityCard] has its own mapping, for colours only.

## When in the battle it can be used.
enum Moment {
	UNKNOWN, PASSIVE, DEPLOYMENT, START_OF_BATTLE, START_OF_ROUND, END_OF_ROUND,
	START_OF_TURN, HERO, MOVEMENT, SHOOTING, CHARGE, COMBAT, END_OF_TURN, REACTION,
}
## Whose turn it has to be, from the point of view of whoever uses it.
enum Whose { ANY, YOURS, ENEMYS }

const PHASE_WORDS := {"Hero": Moment.HERO, "Movement": Moment.MOVEMENT, "Shooting": Moment.SHOOTING,
		"Charge": Moment.CHARGE, "Combat": Moment.COMBAT}
## The names shown for the turn's phases, in order.
const TURN_WINDOWS: Array[Moment] = [Moment.START_OF_TURN, Moment.HERO, Moment.MOVEMENT, Moment.SHOOTING,
		Moment.CHARGE, Moment.COMBAT, Moment.END_OF_TURN]
const WINDOW_NAMES := {Moment.START_OF_TURN: "Start of Turn", Moment.HERO: "Hero", Moment.MOVEMENT: "Movement",
		Moment.SHOOTING: "Shooting", Moment.CHARGE: "Charge", Moment.COMBAT: "Combat", Moment.END_OF_TURN: "End of Turn",
		Moment.START_OF_ROUND: "Start of Round", Moment.END_OF_ROUND: "End of Round"}

var window := Moment.UNKNOWN
var whose := Whose.ANY
## Whether it's only for the first battle round.
var first_round_only := false
## The window a reaction is limited to, e.g. "Your Movement Phase, Reaction: ...", or UNKNOWN.
var within_window := Moment.UNKNOWN

# A reaction's trigger

## Whose ability it reacts to: true for the opponent's, false for your own.
var to_opponent := false
## Keywords the declared ability has to have, any of them; a "non-" one mustn't be there.
var trigger_keywords := PackedStringArray()
var trigger_excludes := PackedStringArray()
## The name of the ability it reacts to, or empty.
var trigger_ability := ""
## Whether any ability will do, once [member trigger_excludes] are ruled out.
var reacts_to_any := false
## Whether it reacts to any command.
var trigger_command := false
## Whether it's only for an ability this unit declared ("for this unit").
var this_unit_only := false
## Whether it's only when this unit is targeted.
var this_unit_targeted := false
## Text after the trigger the parser doesn't act on, e.g. a range. Effect data has to cover it.
var trigger_rest := ""


static func parse(text: String) -> AbilityTiming:
	var timing := AbilityTiming.new()
	var clean := text.strip_edges().trim_suffix(".")
	var at := clean.find("Reaction:")
	if at >= 0:
		timing._read_prefix(clean.substr(0, at))
		timing._read_reaction(clean.substr(at + "Reaction:".length()).strip_edges())
	elif clean.begins_with("You declared") or clean.begins_with("Opponent declared"):
		timing._read_reaction(clean)
	else:
		timing._read_window(clean)
	return timing


func _read_prefix(text: String) -> void:
	var prefix := AbilityTiming.parse(text.strip_edges().trim_suffix(",")) if not text.strip_edges().is_empty() else null
	if prefix:
		within_window = prefix.window
		whose = prefix.whose


func _read_window(text: String) -> void:
	# Timings like "(Army,) Your Shooting Phase" or "Any Combat Phase, Once Per Battle".
	var clean := text
	# A bracketed note first, as in "(Army,) Your Shooting Phase", isn't part of the timing.
	var without_note := text.substr(text.find(")") + 1).strip_edges() if text.begins_with("(") else text
	for part in without_note.split(",", false):
		if part.contains("Phase") or part.contains("Turn") or part.contains("Round") or part.contains("Battle") or part == "Passive":
			if not part.contains("Once Per"):
				clean = part.strip_edges()
				break
	if clean == "Passive":
		window = Moment.PASSIVE
	elif clean == "Deployment Phase":
		window = Moment.DEPLOYMENT
	elif clean == "Start of Battle":
		window = Moment.START_OF_BATTLE
	elif clean.contains("Battle Round"):
		first_round_only = clean.contains("First")
		window = Moment.START_OF_ROUND if clean.begins_with("Start") else Moment.END_OF_ROUND
	elif clean.ends_with("Turn"):
		window = Moment.START_OF_TURN if clean.begins_with("Start") else Moment.END_OF_TURN
		_read_whose(clean.get_slice(" ", 2))
	elif clean.ends_with("Phase"):
		var words := clean.split(" ", false)
		if words.size() >= 3:
			window = PHASE_WORDS.get(words[1], Moment.UNKNOWN)
			_read_whose(words[0])


func _read_whose(word: String) -> void:
	match word:
		"Your":
			whose = Whose.YOURS
		"Enemy":
			whose = Whose.ENEMYS
		_:
			whose = Whose.ANY


func _read_reaction(text: String) -> void:
	window = Moment.REACTION
	to_opponent = text.begins_with("Opponent") or text.begins_with("Your opponent")
	var words := text.replace("\n", " ")
	if words.contains("picked as the target of"):
		# "This unit was picked as the target of a non-CORE ability": whose it is goes without saying.
		to_opponent = true
		reacts_to_any = true
		_read_picked_keywords(words)
		this_unit_targeted = true
		return
	var ability_mark := words.find("the '")
	if ability_mark < 0:
		ability_mark = words.find("the ‘")
	if ability_mark >= 0:
		var end := _closing_quote(words, ability_mark + 5)
		if end > 0:
			trigger_ability = words.substr(ability_mark + 5, end - ability_mark - 5)
	elif words.contains(" a command") or words.contains(" command for"):
		trigger_command = true
	else:
		_read_trigger_keywords(words)
	this_unit_only = words.contains("for this unit")
	this_unit_targeted = words.contains("targeted this unit") or words.contains("picked this unit") or words.contains("This unit was picked")
	var rest_at := words.find(" for a ")
	if rest_at < 0:
		rest_at = words.find(" within ")
	trigger_rest = words.substr(rest_at).strip_edges() if rest_at >= 0 else ""


static func _closing_quote(text: String, from: int) -> int:
	for i in range(from, text.length()):
		if text[i] == "'" or text[i] == "’":
			# Not an apostrophe inside a word.
			if i + 1 >= text.length() or not text[i + 1].is_valid_identifier():
				return i
	return -1


## The capitalised words before " ability", e.g. "a non-CHARGE MOVE ability", "a SPELL or PRAYER ability".
func _read_trigger_keywords(words: String) -> void:
	var at := words.find(" ability")
	if at < 0:
		return
	var declared := words.find("declared")
	var phrase := words.substr(declared + 8, at - declared - 8) if declared >= 0 else ""
	for word in phrase.split(" ", false):
		if word in ["a", "an", "or", "the"]:
			continue
		if word.begins_with("non-"):
			trigger_excludes.append(word.substr(4).to_upper())
		else:
			trigger_keywords.append(word.to_upper())


## The "non-X" words after "picked as the target of".
func _read_picked_keywords(words: String) -> void:
	for word in words.split(" ", false):
		if word.begins_with("non-"):
			trigger_excludes.append(word.substr(4).to_upper())


func is_known() -> bool:
	return window != Moment.UNKNOWN


## Whether it can be used in [param now] by the player whose turn it [param is_your_turn] is or isn't.
func fits(now: Moment, is_your_turn: bool) -> bool:
	if window != now:
		return false
	match whose:
		Whose.YOURS:
			return is_your_turn
		Whose.ENEMYS:
			return not is_your_turn
	return true
