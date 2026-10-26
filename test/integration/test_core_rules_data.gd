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


# Ability types

func _all_abilities() -> Array[Ability]:
	var out: Array[Ability] = []
	out.append_array(_rules.abilities)
	out.append_array(_rules.weapon_abilities)
	out.append_array(_rules.terrain_abilities)
	for lore in _rules.manifestation_lores:
		out.append_array(lore.entries)
	for warscroll in _rules.manifestations:
		out.append_array(warscroll.abilities)
	return out


func test_every_core_ability_has_a_known_type() -> void:
	for ability in _all_abilities():
		assert_has(Ability.TYPES, ability.type, ability.name)


func test_every_core_ability_with_command_points_is_a_command() -> void:
	for ability in _all_abilities():
		if ability.command_points > 0:
			assert_eq(ability.type, "command", ability.name)


func test_every_core_command_has_command_points() -> void:
	for ability in _all_abilities():
		if ability.type == "command":
			assert_gt(ability.command_points, 0, ability.name)


func test_every_core_spell_has_a_casting_value_or_spell_keyword() -> void:
	for ability in _all_abilities():
		if ability.type == "spell":
			assert_true(ability.casting_value > 0 or "SPELL" in ability.keywords, ability.name)


func test_counter_charge_is_a_two_point_command() -> void:
	var ability := _rules.get_ability("Counter-charge")
	assert_not_null(ability)
	assert_eq([ability.type, ability.command_points], ["command", 2])


func test_fly_is_passive() -> void:
	var ability := _rules.get_ability("Fly")
	assert_not_null(ability)
	assert_eq(ability.type, "passive")
