class_name BattlefieldController
extends RefCounted
## Anything on the battlefield that has characteristics and can hold buffs and debuffs: a unit
## ([UnitController]) or a terrain feature ([TerrainController]). Both are reached the same way, so
## effects don't care which they're talking to.

var game: GameController
var characteristics := CharacteristicsController.new()
var modifiers := ModifierController.new()


func _init(on: GameController) -> void:
	game = on
	modifiers.listen(on.events)


## Resolves [param command], one of [Commands]. Returns why it couldn't, or empty. Use
## [method GameController.command] rather than calling this, so events wait for it to finish.
func handle(command: RefCounted) -> String:
	if command is Commands.ApplyModifier:
		modifiers.add(command.modifier)
		return ""
	return "This can't do that."
