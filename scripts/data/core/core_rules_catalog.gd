class_name CoreRulesCatalog
extends RefCounted
## Loads the core rules and the Spearhead battlepacks once and shares them.

## The Spearhead battlepacks, one file per realm battlefield.
const SPEARHEAD_FILES: PackedStringArray = [
	"res://data/core/spearhead/fire_and_jade.json",
	"res://data/core/spearhead/sand_and_bone.json",
]

static var _rules: CoreRules
static var _spearhead_battlepacks: Array[SpearheadBattlepack] = []


## Returns the core rules from data/core, or null and reports errors if they can't be loaded.
static func get_rules() -> CoreRules:
	if _rules:
		return _rules
	var loader := CoreRulesLoader.new()
	_rules = loader.load_core_rules()
	for error in loader.errors:
		push_error(error)
	return _rules


## Returns the Spearhead battlepacks that load, reporting errors for any that can't be loaded.
static func spearhead_battlepacks() -> Array[SpearheadBattlepack]:
	if not _spearhead_battlepacks.is_empty():
		return _spearhead_battlepacks
	var loader := SpearheadLoader.new()
	for file_path in SPEARHEAD_FILES:
		var pack := loader.load_battlepack(file_path)
		for error in loader.errors:
			push_error(error)
		if pack:
			_spearhead_battlepacks.append(pack)
	return _spearhead_battlepacks


## Returns the Spearhead battlepack named [param pack_name], or null.
static func get_spearhead_battlepack(pack_name: String) -> SpearheadBattlepack:
	for pack in spearhead_battlepacks():
		if pack.name == pack_name:
			return pack
	return null
