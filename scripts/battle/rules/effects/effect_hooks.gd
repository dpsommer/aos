class_name EffectHooks
extends RefCounted
## The rules that are easier written than described. Effect data names one with
## {"op": "hook", "name": ...}. Each resolves at once, without asking anything.

## How many rally rolls 'Rally' makes, and what counts (Commands 2.0).
const RALLY_ROLLS := 6
const RALLY_ON := 4
## A PRIEST's counter (Magic 3.0).
const RITUAL_POINTS := &"ritual"


static func run(hook_name: String, action: Action, game: GameController, params: Dictionary) -> void:
	match hook_name:
		"reroll_parent":
			_reroll_parent(action, game, params)
		"at_the_double":
			if action.parent:
				action.parent.flags["no_run_roll"] = true
				action.parent.flags["added_move"] = 6
		"rally":
			_rally(action, game)
		"all_friendly_targets":
			if action.parent:
				action.parent.targets = game.on_battlefield(action.army).filter(func(unit: BattleUnit) -> bool:
					return not game.was_set_up_this_turn(unit))
		"no_retreat_damage":
			if action.parent:
				action.parent.flags["no_retreat_damage"] = true
		"return_on_rolls":
			_return_on_rolls(action, game, int(params.get("on", 5)))
		"beat_health":
			_beat_health(action, game, int(params.get("dice", 6)))
		"unbind":
			_unbind(action, game)
		"banish":
			_banish(action, game)
		"sacred_rites":
			game.command(action.user, Commands.ChangeCounter.new(RITUAL_POINTS, action.rolls.get("chanting", 0)))
		_:
			push_error("Unknown effect hook '%s'" % hook_name)


## Re-rolls a roll of the ability this reacts to, e.g. 'Forward to Victory'.
static func _reroll_parent(action: Action, game: GameController, params: Dictionary) -> void:
	if action.parent == null:
		return
	var roll_name: String = params.get("roll", "")
	game.make_roll(action.parent, roll_name, DiceExpr.parse(params.get("dice", "2D6")))


## Rally: 6 rolls, each 4+ a rally point. A slain model comes back for its Health in points if
## there's one to return and enough points, and the rest heal.
static func _rally(action: Action, game: GameController) -> void:
	var unit := action.user
	if unit == null:
		return
	var points := 0
	for _i in RALLY_ROLLS:
		if game.rng.randi_range(1, 6) >= RALLY_ON:
			points += 1
	var health := maxi(game.stats.value(unit, &"health"), 1)
	while points >= health and not unit.slain_bases.is_empty() and game.controller_of(unit).damage_points == 0:
		game.command(unit, Commands.ReturnModels.new(1))
		points -= health
	game.command(unit, Commands.Heal.new(points))


## A dice for each slain model; each roll of [param on] or more returns one, e.g. 'Fall Back and Rally'.
static func _return_on_rolls(action: Action, game: GameController, on: int) -> void:
	var unit := action.user if action.user else (action.parent.user if action.parent else null)
	if unit == null:
		return
	var returned := 0
	for _i in unit.slain_bases.size():
		if game.rng.randi_range(1, 6) >= on:
			returned += 1
	if returned > 0:
		game.command(unit, Commands.ReturnModels.new(returned))


## 'Unbind': beats the casting roll, and the spell's effect doesn't resolve (Magic 4.0).
static func _unbind(action: Action, game: GameController) -> void:
	if action.parent == null:
		return
	action.parent.flags["Unbind"] = true
	var unbinding := game.make_roll(action, "unbinding", DiceExpr.parse("2D6"))
	if unbinding > action.parent.rolls.get("casting", 0):
		action.parent.flags["unbound"] = true
		game.events.publish(BattleEvent.ROLL_MADE, {"action": action, "name": "unbound", "value": unbinding, "unit": action.user,
				"text": "%s is unbound." % action.parent.ability().name})


## 'Banish Manifestation' (Magic 7.2).
static func _banish(action: Action, game: GameController) -> void:
	for target in action.targets:
		var roll: int = action.rolls.get("banishment", 0)
		var others := game.enemies_on_battlefield(action.army).filter(func(unit: BattleUnit) -> bool: return unit.has_keyword("MANIFESTATION")).size() - 1
		if roll + maxi(others, 0) >= game.stats.value(target, &"banishment"):
			game.command(target, Commands.Destroy.new(action.army))


## A number of dice; each roll above the target's Health is 1 mortal damage, e.g. 'Grotkicker'.
static func _beat_health(action: Action, game: GameController, dice: int) -> void:
	for target in action.targets:
		var health := game.stats.value(target, &"health")
		var points := 0
		for _i in dice:
			if game.rng.randi_range(1, 6) > health:
				points += 1
		action.add_damage(target, points)
