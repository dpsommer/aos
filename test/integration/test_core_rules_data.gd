extends GutTest
## Integration test of CoreRulesLoader with the shipped core rules in data/core.
##
## CoreRulesLoader returns null if it finds any error, so rules that load have no loader errors.

const _POINTS := {"Forbidden Power": 20, "Morbid Conjuration": 20, "Primal Energy": 10}

var _loader: CoreRulesLoader
var _rules: CoreRules


func before_all() -> void:
	_loader = CoreRulesLoader.new()
	_rules = _loader.load_core_rules()


func after_all() -> void:
	_loader = null
	_rules = null


func test_core_rules_load_without_errors() -> void:
	assert_not_null(_rules)
	assert_eq(_loader.errors.size(), 0, "\n".join(_loader.errors))


func test_there_are_six_manifestation_lores() -> void:
	assert_eq(_rules.manifestation_lores.size(), 6)


func _manifestation_names() -> PackedStringArray:
	var names := PackedStringArray()
	for warscroll in _rules.manifestations:
		names.append(warscroll.name)
	return names


## The manifestation a "Summon X" spell names; "Summon Burning Head" summons "The Burning Head".
func _summoned_name(spell: Ability) -> String:
	var summoned := spell.name.trim_prefix("Summon ")
	return "The " + summoned if ("The " + summoned) in _manifestation_names() else summoned


func test_every_summon_spell_names_a_manifestation() -> void:
	var names := _manifestation_names()
	for lore in _rules.manifestation_lores:
		for entry in lore.entries:
			if "SUMMON" in entry.keywords:
				assert_has(names, _summoned_name(entry), "%s: %s" % [lore.name, entry.name])


func test_every_command_has_a_timing() -> void:
	var commands := 0
	for ability in _rules.abilities:
		if ability.command_points > 0:
			commands += 1
			assert_false(ability.timing.is_empty(), ability.name)
	assert_gt(commands, 0)


func test_lore_points_match_the_battle_profiles() -> void:
	for lore in _rules.manifestation_lores:
		assert_eq(lore.points, _POINTS.get(lore.name, 0), lore.name)
