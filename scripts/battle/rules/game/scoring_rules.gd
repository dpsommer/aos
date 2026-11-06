class_name ScoringRules
extends RefCounted
## Scores a battleplan's sentences at the end of a turn (Core Rules 31.0). Each sentence's meaning is
## effect data, under its shape: "Score 3 victory points if you control at least 1 objective." is
## "scoring:Score N victory points if you control at least N objective.". A sentence with no data
## scores nothing, and [method unsupported] names it.

const NUMBER_WORDS := {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5}


## [param sentence] with its numbers as N: the key of its data.
static func shape_of(sentence: String) -> String:
	var result := PackedStringArray()
	for word in sentence.split(" ", false):
		if word.is_valid_int() or NUMBER_WORDS.has(word):
			result.append("N")
		else:
			result.append(word)
	return " ".join(result)


## [param sentence]'s numbers in order.
static func numbers_in(sentence: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	for word in sentence.split(" ", false):
		if word.is_valid_int():
			result.append(word.to_int())
		elif NUMBER_WORDS.has(word):
			result.append(NUMBER_WORDS[word])
	return result


## The rules for [param sentence], or empty.
static func rule_for(sentence: String) -> Dictionary:
	return EffectCatalog.raw("scoring:%s" % shape_of(sentence))


## Which of [param sentences] have no data.
static func unsupported(sentences: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for sentence in sentences:
		if rule_for(sentence).get("check", "unsupported") == "unsupported":
			result.append(sentence)
	return result


## How many points [param sentence] gives [param army] now.
static func points_for(sentence: String, army: BattleArmy, game: GameController) -> int:
	var rule := rule_for(sentence)
	var numbers := numbers_in(sentence)
	if rule.is_empty() or numbers.is_empty() or not _round_fits(rule, game):
		return 0
	var points := numbers[0]
	var state := game.state
	var enemy := game.battle.enemy_of(army)
	var mine := state.objectives_held(army)
	match rule.get("check", "unsupported"):
		"control_at_least":
			return points if mine >= numbers[1] else 0
		"control_more":
			return points if mine > state.objectives_held(enemy) else 0
		"control_type":
			return points if _holds_type(army, rule.get("type", ""), game) else 0
		"control_pair":
			return points if _holds_pair(army, state) else 0
		"gained_from_opponent":
			return points if _gained_from(army, enemy, state) else 0
		"per_tactic_this_turn":
			return points * state.turn_stat(army, &"tactics")
		"terrain_more":
			return points if _terrain_held(army, state) > _terrain_held(enemy, state) else 0
	return 0


static func _round_fits(rule: Dictionary, game: GameController) -> bool:
	match rule.get("rounds", ""):
		"first":
			return game.state.round_number == 1
		"from_second":
			return game.state.round_number >= 2
	return true


static func _holds_type(army: BattleArmy, type: String, game: GameController) -> bool:
	for objective: MapFeature in game.state.objective_control:
		if game.state.objective_control[objective] == army and objective.type == type:
			return true
	return false


## Whether [param army] controls 2 objectives of one type.
static func _holds_pair(army: BattleArmy, state: GameState) -> bool:
	var counts := {}
	for objective: MapFeature in state.objective_control:
		if state.objective_control[objective] == army:
			counts[objective.type] = counts.get(objective.type, 0) + 1
			if counts[objective.type] >= 2:
				return true
	return false


static func _gained_from(army: BattleArmy, enemy: BattleArmy, state: GameState) -> bool:
	for objective: MapFeature in state.objective_control:
		if state.objective_control[objective] == army and state.control_at_turn_start.get(objective) == enemy:
			return true
	return false


static func _terrain_held(army: BattleArmy, state: GameState) -> int:
	var total := 0
	for held: BattleArmy in state.terrain_control.values():
		if held == army:
			total += 1
	return total
