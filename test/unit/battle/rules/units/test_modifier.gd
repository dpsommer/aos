extends GutTest
## Reading a modifier from its effect data.

var _army := BattleArmy.new()


func _from(descriptor: Dictionary, action: Action = null) -> Modifier:
	return Modifier.from_descriptor(descriptor, "Source", _army, action)


func test_by_adds_to_the_stat() -> void:
	var modifier := _from({"stat": "hit", "by": -1})
	assert_eq(modifier.op, Modifier.Op.ADD)
	assert_eq(modifier.stat, &"hit")
	assert_eq(modifier.value, -1)


func test_set_sets_the_stat() -> void:
	var modifier := _from({"stat": "ward", "set": 5})
	assert_eq(modifier.op, Modifier.Op.SET)
	assert_eq(modifier.value, 5)


func test_halve_halves_the_stat() -> void:
	var modifier := _from({"stat": "move", "halve": true})
	assert_eq(modifier.op, Modifier.Op.HALVE)


func test_halve_false_is_an_add() -> void:
	assert_eq(_from({"stat": "move", "halve": false, "by": 1}).op, Modifier.Op.ADD)


func test_grant_forbid_and_permit_name_what_they_change() -> void:
	var grant := _from({"grant": "STRIKE-FIRST"})
	var forbid := _from({"forbid": "contest"})
	var permit := _from({"permit": "charge_after_run"})
	assert_eq(grant.op, Modifier.Op.GRANT)
	assert_eq(grant.stat, &"STRIKE-FIRST")
	assert_eq(forbid.op, Modifier.Op.FORBID)
	assert_eq(forbid.stat, &"contest")
	assert_eq(permit.op, Modifier.Op.PERMIT)
	assert_eq(permit.stat, &"charge_after_run")


func test_each_duration_is_read() -> void:
	var cases := {"phase": Modifier.Until.END_OF_PHASE, "turn": Modifier.Until.END_OF_TURN,
			"round": Modifier.Until.END_OF_ROUND, "start_next_turn": Modifier.Until.START_OF_NEXT_TURN,
			"action": Modifier.Until.END_OF_ACTION, "battle": Modifier.Until.PERMANENT}
	for word: String in cases:
		assert_eq(_from({"stat": "hit", "by": 1, "until": word}).until, cases[word], word)


func test_no_duration_lasts_for_ever() -> void:
	assert_eq(_from({"stat": "hit", "by": 1}).until, Modifier.Until.PERMANENT)


func test_an_unknown_duration_lasts_for_ever() -> void:
	assert_eq(_from({"stat": "hit", "by": 1, "until": "tuesday"}).until, Modifier.Until.PERMANENT)


func test_it_remembers_where_it_came_from() -> void:
	var modifier := _from({"stat": "hit", "by": 1})
	assert_eq(modifier.source_name, "Source")
	assert_eq(modifier.source_army, _army)


func test_scope_fields_are_read() -> void:
	var modifier := _from({"stat": "hit", "by": 1, "against": true, "weapons": "melee", "weapon": "Axe",
			"when": ["charged"], "aura": {"within": 6}, "companion": true})
	assert_true(modifier.against)
	assert_eq(modifier.weapons, "melee")
	assert_eq(modifier.weapon_name, "Axe")
	assert_eq(modifier.conditions, ["charged"])
	assert_eq(modifier.aura, {"within": 6})
	assert_true(modifier.affects_companion)


func test_by_default_it_is_for_its_holder_and_all_weapons() -> void:
	var modifier := _from({"stat": "hit", "by": 1})
	assert_false(modifier.against)
	assert_true(modifier.weapons.is_empty())
	assert_true(modifier.aura.is_empty())
	assert_false(modifier.affects_companion)


func test_an_action_modifier_is_tied_to_its_action() -> void:
	var action := Action.new()
	assert_eq(_from({"stat": "hit", "by": 1, "until": "action"}, action).action, action)


func test_a_modifier_that_is_not_until_the_action_ends_is_not_tied_to_one() -> void:
	assert_null(_from({"stat": "hit", "by": 1, "until": "turn"}, Action.new()).action)


func test_is_positive_for_what_improves_a_roll() -> void:
	var cases := [[{"stat": "hit", "by": 1}, true], [{"stat": "hit", "by": -1}, false], [{"stat": "hit", "by": 0}, false],
			[{"stat": "ward", "set": 4}, true], [{"grant": "X"}, true], [{"forbid": "X"}, false],
			[{"stat": "move", "halve": true}, false], [{"permit": "X"}, false]]
	for entry: Array in cases:
		assert_eq(_from(entry[0]).is_positive(), entry[1], str(entry[0]))
