class_name MortalEffect
extends Effect
## Inflicts mortal damage on its subjects. [code]amount[/code] is dice, e.g. "D3". With
## [code]per_model_within[/code], rolls a dice for each user's model that near the target, and each
## roll of [code]on[/code] or more (with [code]roll_stat[/code]'s modifiers) does [code]amount[/code].
## [code]amount[/code] "gate" is the gate roll. [code]amount_against[/code] gives a different amount
## against a keyword, and [code]bonus_against[/code] adds 1 against one.


func resolve(action: Action, game: GameController) -> DecisionRequest:
	if action.flags.has(params.get("unless_flag", "")):
		return null
	for unit in subjects(action, game):
		var dice := DiceExpr.parse(str(_amount_for(unit, game)))
		var total := 0
		if params.has("per_model_within"):
			var near := BattleGeometry.models_within(action.user, unit, float(params.per_model_within)) if action.user else 0
			var bonus := game.stats.roll_modifier(StringName(params.get("roll_stat", "")), RuleContext.of_unit(game, action.user)) if action.user and params.has("roll_stat") else 0
			for _i in near:
				if game.rng.randi_range(1, 6) + bonus >= int(params.get("on", 1)):
					total += dice.roll(game.rng)
		elif params.get("amount") == "gate":
			total = action.rolls.get("gate", 0)
		else:
			total = dice.roll(game.rng)
		if params.has("bonus_against") and game.stats.has_keyword(unit, params.bonus_against):
			total += 1
		action.add_damage(unit, total)
	return null


func _amount_for(unit: BattleUnit, game: GameController) -> Variant:
	var special: Dictionary = params.get("amount_against", {})
	if not special.is_empty() and game.stats.has_keyword(unit, special.keyword):
		return special.amount
	var amount: Variant = params.get("amount", "1")
	return "0" if amount == "gate" else amount
