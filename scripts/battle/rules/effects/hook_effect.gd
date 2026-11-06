class_name HookEffect
extends Effect
## A rule that doesn't fit the other effects: runs [code]name[/code] in [EffectHooks].


func resolve(action: Action, game: GameController) -> DecisionRequest:
	EffectHooks.run(params.get("name", ""), action, game, params)
	return null
