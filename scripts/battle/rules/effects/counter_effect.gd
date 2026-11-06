class_name CounterEffect
extends Effect
## Changes a counter on its subjects: [code]name[/code] and [code]by[/code].


func resolve(action: Action, game: GameController) -> DecisionRequest:
	for unit in subjects(action, game):
		game.command(unit, Commands.ChangeCounter.new(StringName(params.get("name", "")), int(params.get("by", 1))))
	return null
