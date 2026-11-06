class_name ActionOption
extends RefCounted
## Something a player can do now: an ability and who would use it.

var entry: AbilityEntry
## The unit using it, or null if the player does.
var user: BattleUnit


static func create(of: AbilityEntry, by: BattleUnit) -> ActionOption:
	var option := ActionOption.new()
	option.entry = of
	option.user = by
	return option


func ability_name() -> String:
	return entry.ability.name


## "Run (Brutes)", or the ability's name if the player uses it.
func label() -> String:
	return "%s (%s)" % [ability_name(), user.name] if user else ability_name()
