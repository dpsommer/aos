class_name CoreRulesCatalog
extends RefCounted
## Loads the core rules once and shares them.

static var _rules: CoreRules


## Returns the core rules from data/core, or null and reports errors if they can't be loaded.
static func get_rules() -> CoreRules:
	if _rules:
		return _rules
	var loader := CoreRulesLoader.new()
	_rules = loader.load_core_rules()
	for error in loader.errors:
		push_error(error)
	return _rules
