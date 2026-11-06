class_name HealEffect
extends Effect
## Heal (N) on its subjects (Core Rules 21.0). [code]amount[/code] is dice.


func resolve(action: Action, game: GameController) -> DecisionRequest:
	for unit in subjects(action, game):
		game.command(unit, Commands.Heal.new(DiceExpr.parse(str(params.get("amount", "1"))).roll(game.rng)))
	return null
