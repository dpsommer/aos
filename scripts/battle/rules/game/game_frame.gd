class_name GameFrame
extends RefCounted
## One step in progress on the [GameController]'s stack: a phase, an ability, a reaction window. It
## can be stopped wherever it asks a question and picked up from its own state, so nothing in the
## rules waits on anything, and a battle can run to the end in one go when the AI answers at once.

## Set when there's nothing left to do: the game takes it off the stack.
var finished := false


## Moves on as far as it can. Returns what it needs answering, or null if it's finished or has
## pushed another frame to run first.
func advance(_game: GameController) -> DecisionRequest:
	finished = true
	return null


## Takes the answer to the [param request] it asked. Returns why it can't, or empty.
func answer(_game: GameController, _request: DecisionRequest, _decision: Decision) -> String:
	return "Nothing is being asked."
