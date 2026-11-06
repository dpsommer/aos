class_name SpearheadTactics
extends RefCounted
## Whether a Spearhead battle tactic card has been completed: its condition is effect data.


static func is_complete(card: SpearheadTacticCard, army: BattleArmy, game: GameController) -> bool:
	return TacticChecks.is_complete(game.battle.battlepack.name, card.name, army, game)
