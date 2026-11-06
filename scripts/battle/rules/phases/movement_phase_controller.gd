class_name MovementPhaseController
extends PhaseController
## The movement phase. Each unit can use one CORE ability here (Normal Move, Run or Retreat), which
## the [UsageLedger] enforces; this tracks who can still move and who has.

const MOVE_KEYWORD := "MOVE"


## [param army]'s units that can still use a MOVE ability this phase.
func units_that_can_move(game: GameController, army: BattleArmy) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for option in options_for(game, army):
		if option.user and option.entry.ability.keywords.has(MOVE_KEYWORD) and not option.user in result:
			result.append(option.user)
	return result


## [param army]'s units that have moved this phase.
func units_that_moved(game: GameController, army: BattleArmy) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in game.on_battlefield(army):
		if game.controller_of(unit).moved and has_used(unit):
			result.append(unit)
	return result
