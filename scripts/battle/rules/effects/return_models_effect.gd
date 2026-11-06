class_name ReturnModelsEffect
extends Effect
## Returns slain models to its subjects (Core Rules 22.0). [code]amount[/code] is dice.


func resolve(action: Action, game: GameController) -> DecisionRequest:
	for unit in subjects(action, game):
		game.command(unit, Commands.ReturnModels.new(DiceExpr.parse(str(params.get("amount", "1"))).roll(game.rng)))
	return null
