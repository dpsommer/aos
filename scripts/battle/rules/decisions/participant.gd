class_name Participant
extends RefCounted
## Who commands an army: the player or the AI. The [GameController] gives whoever's asked a
## [DecisionRequest]; how they come to an answer is their business.


## Whether [method decide] answers straight away. The player's answer comes from the map.
func answers_at_once() -> bool:
	return true


## Their answer to [param request], when [method answers_at_once].
func decide(_request: DecisionRequest, _game: GameController) -> Decision:
	return Decision.pass_it()
