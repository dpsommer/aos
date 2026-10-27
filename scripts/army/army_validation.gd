class_name ArmyValidation
extends RefCounted
## The result of validating an army.

## Rules the army breaks. The army is valid when there are none.
var problems := PackedStringArray()
## Legal choices that are probably mistakes, e.g. a Wizard with no spell lore.
var warnings := PackedStringArray()
## Whether validation was skipped because the army overrides its constraints.
var overridden: bool


func is_valid() -> bool:
	return problems.is_empty()
