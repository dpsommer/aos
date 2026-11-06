class_name ModifyEffect
extends Effect
## Gives its subjects a buff or debuff: see [method Modifier.from_descriptor].


func resolve(action: Action, game: GameController) -> DecisionRequest:
	for unit in subjects(action, game):
		var descriptor := params
		if params.get("by") is String:
			# "add the number rolled": rolled once for each unit.
			descriptor = params.duplicate()
			descriptor["by"] = DiceExpr.parse(params.by).roll(game.rng)
		var modifier := Modifier.from_descriptor(descriptor, action.ability().name, action.army, action.parent if params.get("of_parent", false) else action)
		game.command(unit, Commands.ApplyModifier.new(modifier))
	return null
