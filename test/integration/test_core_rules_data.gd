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


# General's Handbook battlepack

func _battlepack_abilities() -> Array[Ability]:
	var out: Array[Ability] = []
	out.append_array(_rules.battlepack.season_rules)
	out.append_array(_rules.battlepack.updated_abilities)
	for battleplan in _rules.battlepack.battleplans:
		out.append_array(battleplan.abilities)
	return out


func test_every_battlepack_ability_has_a_known_type() -> void:
	for ability in _battlepack_abilities():
		assert_has(Ability.TYPES, ability.type, ability.name)


func test_every_updated_ability_replaces_a_core_ability() -> void:
	for ability in _rules.battlepack.updated_abilities:
		assert_not_null(_rules.get_ability(ability.name), ability.name)


func test_every_battleplan_table_entry_names_a_battleplan() -> void:
	for table in _rules.battlepack.battleplan_tables:
		for battleplan_name in table:
			assert_not_null(_rules.battlepack.get_battleplan(battleplan_name), battleplan_name)


func test_every_battleplan_is_on_its_table() -> void:
	var tables := _rules.battlepack.battleplan_tables
	for battleplan in _rules.battlepack.battleplans:
		assert_between(battleplan.table, 1, tables.size(), battleplan.name)
		if battleplan.table >= 1 and battleplan.table <= tables.size():
			assert_has(tables[battleplan.table - 1], battleplan.name)


func test_every_battle_tactics_card_has_one_tactic_of_each_kind_in_order() -> void:
	assert_gt(_rules.battlepack.battle_tactic_cards.size(), 0)
	for card in _rules.battlepack.battle_tactic_cards:
		var kinds := PackedStringArray()
		for tactic in card.tactics:
			kinds.append(tactic.kind)
		assert_eq(kinds, BattleTactic.KINDS, card.name)


func _on_battlefield(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, _rules.battlepack.battlefield_size).has_point(point)


func test_every_map_feature_is_on_the_battlefield() -> void:
	for battleplan in _rules.battlepack.battleplans:
		for feature in battleplan.objectives + battleplan.terrain:
			assert_true(_on_battlefield(feature.position), "%s: %s at %s" % [battleplan.name, feature.type, feature.position])


func test_every_battleplan_map_has_both_territories() -> void:
	for battleplan in _rules.battlepack.battleplans:
		assert_gt(battleplan.attacker_territory.size(), 0, battleplan.name)
		assert_gt(battleplan.defender_territory.size(), 0, battleplan.name)


func test_territories_do_not_overlap() -> void:
	for battleplan in _rules.battlepack.battleplans:
		for attacker in battleplan.attacker_territory:
			for defender in battleplan.defender_territory:
				assert_false(attacker.intersects(defender), battleplan.name)


func test_territories_are_on_the_battlefield() -> void:
	var battlefield := Rect2(Vector2.ZERO, _rules.battlepack.battlefield_size)
	for battleplan in _rules.battlepack.battleplans:
		for area in battleplan.attacker_territory + battleplan.defender_territory:
			assert_true(battlefield.encloses(area), "%s: %s" % [battleplan.name, area])


## A map's objectives match the battlepack's set of Aqshian objectives: at most 2 Sun Seekers,
## 2 Golden Lions, 1 Heldenhain and 1 Scions of the Comet.
func test_no_map_uses_more_objectives_of_a_type_than_the_battlepack_has() -> void:
	var available := {"Sun Seekers": 2, "Golden Lions": 2, "Heldenhain": 1, "Scions of the Comet": 1}
	for battleplan in _rules.battlepack.battleplans:
		var counts := {}
		for objective in battleplan.objectives:
			counts[objective.type] = counts.get(objective.type, 0) + 1
		for type: String in counts:
			assert_lte(counts[type], available[type], "%s: %s" % [battleplan.name, type])


func test_every_battlepack_faq_has_a_question_and_answer() -> void:
	var faqs: Array[Dictionary] = []
	faqs.append_array(_rules.battlepack.faqs)
	for card in _rules.battlepack.battle_tactic_cards:
		faqs.append_array(card.faqs)
	for battleplan in _rules.battlepack.battleplans:
		faqs.append_array(battleplan.faqs)
	assert_gt(faqs.size(), 0)
	for faq in faqs:
		assert_false(faq.question.is_empty() or faq.answer.is_empty(), str(faq))
