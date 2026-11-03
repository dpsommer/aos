extends GutTest
## Unit tests for the deployment phase's state machine (scripts/battle/deployment/deployment.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")

var _battle: Battle
var _d: Deployment
var _me: BattleArmy
var _them: BattleArmy


func before_each() -> void:
	_battle = BattleKit.deployment_battle()
	_me = _battle.player
	_them = _battle.opponent
	_d = Deployment.new(_battle)


func _start() -> void:
	_d.start()


func _unit(army: BattleArmy, unit_name: String) -> BattleUnit:
	for unit in army.units:
		if unit.name == unit_name:
			return unit
	return null


func _positions(army: BattleArmy, unit: BattleUnit, across := 30.0) -> PackedVector2Array:
	var anchor := Vector2(across, 5) if army == _battle.player else Vector2(across, 39)
	return Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, anchor, army.facing)


## Deploys [param unit_name] of [param army] on a valid spot, returning any error.
func _put(army: BattleArmy, unit_name: String, across := 30.0) -> String:
	var unit := _unit(army, unit_name)
	return _d.place_unit(army, unit, _positions(army, unit, across), army.facing)


func _forced(army: BattleArmy, unit_name: String) -> void:
	var unit := _unit(army, unit_name)
	_d.place_unit(army, unit, _positions(army, unit), army.facing, false)


func _reserve_entry(army: BattleArmy, owner_name: String, name_text := "Hide", effect := "Set up this unit in reserve in the clouds.", frequency := "") -> DeploymentAbility:
	var ability := BattleKit.ability(name_text, PackedStringArray(["DEPLOY"]), effect, "Pick this unit.", frequency)
	var entry := BattleKit.deploy_entry(ability, "Warscroll", _unit(army, owner_name) if not owner_name.is_empty() else null)
	army.deployment_abilities.append(entry)
	return entry


func _record_entry(army: BattleArmy, name_text := "Scout", frequency := "") -> DeploymentAbility:
	var ability := BattleKit.ability(name_text, PackedStringArray(), "Do something.", "", frequency)
	ability.timing = DeploymentAbility.TIMING
	var entry := BattleKit.deploy_entry(ability)
	army.deployment_abilities.append(entry)
	return entry


func _deploy_everything() -> void:
	for army in [_me, _them]:
		for unit: BattleUnit in army.units:
			unit.deployed = true
			unit.positions = PackedVector2Array([Vector2.ZERO])


func _add_terrain(army: BattleArmy, count := 1) -> void:
	for i in count:
		army.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))


# start

func test_start_skips_the_terrain_step_when_nobody_has_terrain() -> void:
	_start()
	assert_eq(_d.step, Deployment.Step.UNITS)


func test_start_begins_with_the_attacker() -> void:
	_start()
	assert_same(_d.active, _battle.attacker())


func test_start_begins_with_the_defender_when_only_it_has_terrain() -> void:
	_add_terrain(_them)
	_start()
	assert_eq(_d.step, Deployment.Step.TERRAIN)
	assert_same(_d.active, _them)


func test_start_begins_terrain_with_the_attacker_when_both_have_some() -> void:
	_add_terrain(_me)
	_add_terrain(_them)
	_start()
	assert_same(_d.active, _me)


func test_start_is_done_when_there_is_nothing_to_deploy() -> void:
	_deploy_everything()
	watch_signals(_d)
	_start()
	assert_true(_d.is_done())
	assert_null(_d.active)
	assert_signal_emitted(_d, "finished")


func test_start_skips_to_the_abilities_step_when_units_are_deployed_but_an_ability_is_left() -> void:
	_deploy_everything()
	_record_entry(_me)
	_start()
	assert_eq(_d.step, Deployment.Step.OTHER)
	assert_same(_d.active, _me)


func test_the_other_side_starts_when_the_attacker_has_nothing_to_do() -> void:
	for unit in _me.units:
		unit.deployed = true
		unit.positions = PackedVector2Array([Vector2.ZERO])
	_start()
	assert_same(_d.active, _them)


func test_when_the_opponent_is_the_attacker_it_goes_first() -> void:
	_battle.player_is_attacker = false
	_start()
	assert_same(_d.active, _them)


# turns in Matched Play

func test_matched_play_sides_alternate_units() -> void:
	_start()
	_put(_me, "A1")
	assert_same(_d.active, _them)
	_put(_them, "A1")
	assert_same(_d.active, _me)


func test_a_side_with_nothing_left_lets_the_other_go_again() -> void:
	for unit_name in ["A2", "B1", "B2", "Aux"]:
		_unit(_them, unit_name).deployed = true
		_unit(_them, unit_name).positions = PackedVector2Array([Vector2.ZERO])
	_start()
	_put(_me, "A1")
	_put(_them, "A1")
	assert_same(_d.active, _me)
	_put(_me, "A2")
	assert_same(_d.active, _me)


func test_placing_the_last_unit_of_both_sides_moves_to_the_next_step_and_finishes() -> void:
	_deploy_everything()
	_unit(_me, "Aux").deployed = false
	_unit(_them, "Aux").deployed = false
	_start()
	watch_signals(_d)
	_put(_me, "Aux")
	_put(_them, "Aux")
	assert_true(_d.is_done())
	assert_signal_emitted(_d, "finished")


func test_placing_out_of_turn_is_rejected() -> void:
	_start()
	assert_ne(_put(_them, "A1"), "")
	assert_false(_unit(_them, "A1").deployed)


func test_placing_a_unit_that_is_already_deployed_is_rejected() -> void:
	_start()
	_put(_me, "A1")
	_put(_them, "A1")
	assert_ne(_put(_me, "A1", 40.0), "")


func test_placing_needs_a_position_per_model() -> void:
	_start()
	var unit := _unit(_me, "A1")
	assert_ne(_d.place_unit(_me, unit, PackedVector2Array([Vector2(30, 5)]), _me.facing), "")


func test_placing_in_an_invalid_spot_is_rejected_and_changes_nothing() -> void:
	_start()
	var unit := _unit(_me, "A1")
	var error := _d.place_unit(_me, unit, Formations.arrange(Formations.Kind.LINE, unit.bases, Vector2(30, 40), 0.0), 0.0)
	assert_ne(error, "")
	assert_false(unit.deployed)
	assert_same(_d.active, _me)


func test_check_off_places_in_an_invalid_spot() -> void:
	_start()
	var unit := _unit(_me, "A1")
	var error := _d.place_unit(_me, unit, Formations.arrange(Formations.Kind.LINE, unit.bases, Vector2(30, 40), 0.0), 0.0, false)
	assert_eq(error, "")
	assert_true(unit.deployed)


func test_placing_sets_the_units_positions_and_facing() -> void:
	_start()
	var unit := _unit(_me, "A1")
	var positions := _positions(_me, unit)
	_d.place_unit(_me, unit, positions, 1.25)
	assert_eq(unit.positions, positions)
	assert_eq(unit.facing, 1.25)
	assert_true(unit.is_on_battlefield())


func test_placing_logs_the_action() -> void:
	_start()
	_put(_me, "A1")
	assert_eq(_d.history.size(), 1)
	assert_eq(_d.history[0].action, "unit")
	assert_same(_d.history[0].unit, _unit(_me, "A1"))


func test_actions_of_lists_only_that_armys_actions() -> void:
	_start()
	_put(_me, "A1")
	_put(_them, "A1")
	assert_eq(_d.actions_of(_me).size(), 1)
	assert_same(_d.actions_of(_them)[0].army, _them)


func test_changed_is_emitted_after_a_placement() -> void:
	_start()
	watch_signals(_d)
	_put(_me, "A1")
	assert_signal_emitted(_d, "changed")


func test_remaining_counts_undeployed_units_and_unplaced_terrain() -> void:
	_add_terrain(_me)
	assert_eq(_d.remaining(_me), _me.units.size() + 1)


# terrain

func test_terrain_step_places_terrain_and_logs_it() -> void:
	_add_terrain(_me)
	_start()
	var feature := _me.terrain[0]
	assert_eq(_d.place_terrain(_me, feature, Vector2(30, 9), 0.0), "")
	assert_true(feature.placed)
	assert_eq(feature.position, Vector2(30, 9))
	assert_eq(_d.history[0].action, "terrain")


func test_placing_terrain_in_a_bad_spot_is_rejected() -> void:
	_add_terrain(_me)
	_start()
	assert_ne(_d.place_terrain(_me, _me.terrain[0], Vector2(30, 40), 0.0), "")
	assert_false(_me.terrain[0].placed)


func test_terrain_check_off_places_anywhere() -> void:
	_add_terrain(_me)
	_start()
	assert_eq(_d.place_terrain(_me, _me.terrain[0], Vector2(30, 40), 0.0, false), "")


func test_terrain_cannot_be_placed_in_the_units_step() -> void:
	_start()
	_add_terrain(_me)
	assert_ne(_d.place_terrain(_me, _me.terrain[0], Vector2(30, 9), 0.0), "")


func test_another_armys_terrain_cannot_be_placed() -> void:
	_add_terrain(_me)
	_add_terrain(_them)
	_start()
	assert_ne(_d.place_terrain(_me, _them.terrain[0], Vector2(30, 9), 0.0), "")


func test_terrain_alternates_between_sides() -> void:
	_add_terrain(_me)
	_add_terrain(_them)
	_start()
	_d.place_terrain(_me, _me.terrain[0], Vector2(30, 9), 0.0)
	assert_same(_d.active, _them)


func test_after_terrain_the_units_step_starts() -> void:
	_add_terrain(_me)
	_start()
	_d.place_terrain(_me, _me.terrain[0], Vector2(30, 9), 0.0)
	assert_eq(_d.step, Deployment.Step.UNITS)


# Deploy Regiment

func test_a_regiment_keeps_its_side_going_until_it_is_down() -> void:
	_start()
	var regiment := _me.regiments[0]
	assert_eq(_d.begin_regiment(_me, regiment), "")
	_put(_me, "A1", 20.0)
	assert_same(_d.active, _me)
	_put(_me, "A2", 40.0)
	assert_same(_d.active, _them)
	assert_null(_d.regiment)


func test_beginning_a_regiment_restricts_the_pickable_units() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	var names := PackedStringArray()
	for unit in _d.pickable_units(_me):
		names.append(unit.name)
	assert_eq(names, PackedStringArray(["A1", "A2"]))


func test_a_unit_outside_the_regiment_cannot_be_placed_meanwhile() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_ne(_put(_me, "Aux"), "")


func test_everything_is_pickable_without_a_regiment() -> void:
	_start()
	assert_eq(_d.pickable_units(_me).size(), _me.units.size())


func test_beginning_a_regiment_out_of_turn_is_rejected() -> void:
	_start()
	assert_ne(_d.begin_regiment(_them, _them.regiments[0]), "")
	assert_null(_d.regiment)


func test_only_one_regiment_is_deployed_at_a_time() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_ne(_d.begin_regiment(_me, _me.regiments[1]), "")


func test_beginning_a_regiment_logs_it() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_eq(_d.history[0].action, "regiment")


func test_cancelling_a_regiment_before_any_unit_is_down_frees_the_side() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_eq(_d.cancel_regiment(_me), "")
	assert_null(_d.regiment)
	assert_eq(_d.history.size(), 0)


func test_a_regiment_cannot_be_cancelled_once_a_unit_is_down() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	_put(_me, "A1")
	assert_ne(_d.cancel_regiment(_me), "")
	assert_not_null(_d.regiment)


func test_all_whole_regiments_are_available_at_the_start() -> void:
	_start()
	assert_eq(_d.regiments_available(_me).size(), 2)


func test_a_regiment_is_not_available_once_deployed() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	_put(_me, "A1", 20.0)
	_put(_me, "A2", 40.0)
	assert_false(_me.regiments[0] in _d.regiments_available(_me))


func test_deploying_one_unit_on_its_own_breaks_its_regiment() -> void:
	_start()
	_put(_me, "A1")
	assert_false(_me.regiments[0] in _d.regiments_available(_me))
	assert_true(_me.regiments[1] in _d.regiments_available(_me))


func test_the_blocker_names_the_unit_that_broke_the_regiment() -> void:
	_start()
	_put(_me, "A1")
	assert_string_contains(_d.regiment_blocker(_me.regiments[0]), "A1")


func test_an_untouched_regiment_has_no_blocker() -> void:
	_start()
	assert_eq(_d.regiment_blocker(_me.regiments[0]), "")


func test_a_regiment_with_a_unit_deployed_elsewhere_has_a_blocker() -> void:
	_unit(_me, "B1").deployed = true
	_start()
	assert_ne(_d.regiment_blocker(_me.regiments[1]), "")


func test_a_regiment_set_up_together_is_not_marked_broken() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	_put(_me, "A1", 20.0)
	assert_eq(_d.regiment_blocker(_me.regiments[0]), "Some of its units are already deployed.")


func test_no_regiments_are_available_without_the_deploy_regiment_ability() -> void:
	_me.deployment_abilities.erase(_me.deployment_ability(DeploymentAbility.DEPLOY_REGIMENT))
	_start()
	assert_eq(_d.regiments_available(_me).size(), 0)


func test_an_empty_regiment_is_not_available() -> void:
	_me.regiments.append(BattleRegiment.new())
	_start()
	assert_eq(_d.regiments_available(_me).size(), 2)


func test_deploy_regiment_is_unavailable_while_one_is_in_progress() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	var entry := _me.deployment_ability(DeploymentAbility.DEPLOY_REGIMENT)
	assert_ne(_d.reason_unavailable(_me, entry), "")


# reserve

func test_reserving_sets_the_units_deployed_with_the_reserve_name() -> void:
	var entry := _reserve_entry(_me, "Aux")
	_start()
	assert_eq(_d.reserve(_me, entry, [_unit(_me, "Aux")] as Array[BattleUnit]), "")
	var unit := _unit(_me, "Aux")
	assert_true(unit.deployed)
	assert_eq(unit.reserve, "in the clouds")
	assert_false(unit.is_on_battlefield())


func test_a_reserved_unit_is_no_longer_waiting_to_deploy() -> void:
	var entry := _reserve_entry(_me, "Aux")
	_start()
	_d.reserve(_me, entry, [_unit(_me, "Aux")] as Array[BattleUnit])
	assert_false(_unit(_me, "Aux") in _me.undeployed_units())


func test_reserving_passes_the_turn() -> void:
	var entry := _reserve_entry(_me, "Aux")
	_start()
	_d.reserve(_me, entry, [_unit(_me, "Aux")] as Array[BattleUnit])
	assert_same(_d.active, _them)


func test_reserving_logs_the_ability_and_units() -> void:
	var entry := _reserve_entry(_me, "Aux")
	_start()
	_d.reserve(_me, entry, [_unit(_me, "Aux")] as Array[BattleUnit])
	assert_eq(_d.history[0].action, "reserve")
	assert_same(_d.history[0].ability, entry)


func test_a_reserve_ability_can_only_be_used_once() -> void:
	var entry := _reserve_entry(_me, "")
	_start()
	_d.reserve(_me, entry, [_unit(_me, "A1")] as Array[BattleUnit])
	_put(_them, "A1")
	assert_ne(_d.reserve(_me, entry, [_unit(_me, "A2")] as Array[BattleUnit]), "")


func test_reserving_with_no_units_is_rejected() -> void:
	var entry := _reserve_entry(_me, "")
	_start()
	assert_ne(_d.reserve(_me, entry, [] as Array[BattleUnit]), "")


func test_an_owner_only_ability_cannot_reserve_another_unit() -> void:
	var entry := _reserve_entry(_me, "A1")
	_start()
	assert_ne(_d.reserve(_me, entry, [_unit(_me, "A2")] as Array[BattleUnit]), "")
	assert_false(_unit(_me, "A2").deployed)


func test_an_ability_for_any_unit_can_reserve_several() -> void:
	var entry := _reserve_entry(_me, "")
	_start()
	var units: Array[BattleUnit] = [_unit(_me, "A1"), _unit(_me, "Aux")]
	assert_eq(_d.reserve(_me, entry, units), "")
	assert_eq(_unit(_me, "Aux").reserve, _unit(_me, "A1").reserve)


func test_reserving_out_of_turn_is_rejected() -> void:
	var entry := _reserve_entry(_them, "")
	_start()
	assert_ne(_d.reserve(_them, entry, [_unit(_them, "A1")] as Array[BattleUnit]), "")


func test_reserving_breaks_the_units_regiment() -> void:
	var entry := _reserve_entry(_me, "A1")
	_start()
	_d.reserve(_me, entry, [_unit(_me, "A1")] as Array[BattleUnit])
	assert_false(_me.regiments[0] in _d.regiments_available(_me))


func test_a_regiment_of_renown_ability_targets_its_regiments_units() -> void:
	var ability := BattleKit.ability("Renowned", PackedStringArray(["DEPLOY"]), "Set up in reserve.", "Pick units.")
	var entry := BattleKit.deploy_entry(ability, "Regiment of Renown", null, _me.regiments[0])
	_me.deployment_abilities.append(entry)
	_start()
	var targets := _d.reserve_targets(_me, entry)
	assert_eq(targets.size(), 2)
	assert_eq(_d.reserve(_me, entry, [_unit(_me, "Aux")] as Array[BattleUnit]).is_empty(), false)


func test_a_regiment_of_renown_ability_is_unavailable_once_a_unit_is_deployed_alone() -> void:
	var ability := BattleKit.ability("Renowned", PackedStringArray(["DEPLOY"]), "Set up in reserve.", "Pick units.")
	var entry := BattleKit.deploy_entry(ability, "Regiment of Renown", null, _me.regiments[0])
	_me.deployment_abilities.append(entry)
	_start()
	_put(_me, "A1")
	assert_string_contains(_d.reason_unavailable(_me, entry), "A1")
	assert_false(_d.can_use(_me, entry))


func test_a_regiment_of_renown_ability_is_unavailable_while_another_regiment_deploys() -> void:
	var ability := BattleKit.ability("Renowned", PackedStringArray(["DEPLOY"]), "Set up in reserve.", "Pick units.")
	var entry := BattleKit.deploy_entry(ability, "Regiment of Renown", null, _me.regiments[0])
	_me.deployment_abilities.append(entry)
	_start()
	_d.begin_regiment(_me, _me.regiments[1])
	assert_ne(_d.reason_unavailable(_me, entry), "")


func test_a_regiment_of_renown_ability_works_for_the_regiment_being_deployed() -> void:
	var ability := BattleKit.ability("Renowned", PackedStringArray(["DEPLOY"]), "Set up in reserve.", "Pick units.")
	var entry := BattleKit.deploy_entry(ability, "Regiment of Renown", null, _me.regiments[0])
	_me.deployment_abilities.append(entry)
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_eq(_d.reason_unavailable(_me, entry), "")


func test_reserved_units_complete_a_regiment_being_deployed() -> void:
	var entry := _reserve_entry(_me, "A2")
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	_put(_me, "A1", 20.0)
	assert_eq(_d.reserve(_me, entry, [_unit(_me, "A2")] as Array[BattleUnit]), "")
	assert_null(_d.regiment)
	assert_same(_d.active, _them)


func test_an_ability_that_cannot_find_a_unit_is_unavailable() -> void:
	var entry := _reserve_entry(_me, "A1")
	_unit(_me, "A1").deployed = true
	_start()
	assert_string_contains(_d.reason_unavailable(_me, entry), "No unit")


func test_an_ability_from_another_army_is_unavailable() -> void:
	_start()
	assert_ne(_d.reason_unavailable(_me, _them.deployment_abilities[0]), "")


# Deploy Unit, terrain availability

func test_deploy_unit_is_never_used_up() -> void:
	_start()
	var entry := _me.deployment_ability(DeploymentAbility.DEPLOY_UNIT)
	_put(_me, "A1")
	_put(_them, "A1")
	assert_eq(_d.reason_unavailable(_me, entry), "")


func test_deploy_unit_is_unavailable_with_every_unit_deployed() -> void:
	_deploy_everything()
	_record_entry(_me)
	_start()
	assert_ne(_d.reason_unavailable(_me, _me.deployment_ability(DeploymentAbility.DEPLOY_UNIT)), "")


func test_can_use_needs_the_right_step() -> void:
	_start()
	assert_false(_d.can_use(_me, _me.deployment_ability(DeploymentAbility.DEPLOY_FACTION_TERRAIN)))
	assert_true(_d.can_use(_me, _me.deployment_ability(DeploymentAbility.DEPLOY_UNIT)))


func test_can_use_needs_the_active_army() -> void:
	_start()
	assert_false(_d.can_use(_them, _them.deployment_ability(DeploymentAbility.DEPLOY_UNIT)))


func test_terrain_ability_says_why_when_there_is_no_faction_terrain() -> void:
	_start()
	assert_ne(_d.reason_unavailable(_me, _me.deployment_ability(DeploymentAbility.DEPLOY_FACTION_TERRAIN)), "")


func test_step_of_maps_the_abilitys_step() -> void:
	assert_eq(_d.step_of(_me.deployment_ability(DeploymentAbility.DEPLOY_FACTION_TERRAIN)), Deployment.Step.TERRAIN)
	assert_eq(_d.step_of(_me.deployment_ability(DeploymentAbility.DEPLOY_UNIT)), Deployment.Step.UNITS)
	assert_eq(_d.step_of(_record_entry(_me)), Deployment.Step.OTHER)


func test_unsupported_abilities_are_unavailable() -> void:
	var ability := BattleKit.ability("Odd", PackedStringArray(["DEPLOY"]), "Does something odd.")
	var entry := BattleKit.deploy_entry(ability)
	_me.deployment_abilities.append(entry)
	_start()
	assert_string_contains(_d.reason_unavailable(_me, entry), "Not supported")


# record and pass

func test_the_abilities_step_follows_the_units_step() -> void:
	var entry := _record_entry(_me)
	_deploy_everything()
	_unit(_me, "Aux").deployed = false
	_unit(_them, "Aux").deployed = false
	_start()
	_put(_me, "Aux")
	_put(_them, "Aux")
	assert_eq(_d.step, Deployment.Step.OTHER)
	assert_true(_d.can_use(_me, entry))


func test_recording_an_ability_marks_it_used_and_logs_it() -> void:
	var entry := _record_entry(_me)
	_deploy_everything()
	_start()
	assert_eq(_d.record(_me, entry), "")
	assert_true(_d.is_used(_me, entry))
	assert_eq(_d.history[0].action, "record")


func test_a_recorded_ability_cannot_be_used_twice() -> void:
	var entry := _record_entry(_me)
	_record_entry(_me, "Other")
	_deploy_everything()
	_start()
	_d.record(_me, entry)
	assert_ne(_d.record(_me, entry), "")


func test_recording_stores_the_target() -> void:
	var entry := _record_entry(_me)
	_deploy_everything()
	_start()
	_d.record(_me, entry, _unit(_me, "A1"))
	assert_same(_d.history[0].target, _unit(_me, "A1"))


func test_recording_ends_the_phase_when_it_was_the_last_ability() -> void:
	var entry := _record_entry(_me)
	_deploy_everything()
	_start()
	_d.record(_me, entry)
	assert_true(_d.is_done())


func test_recording_a_deploy_ability_is_rejected() -> void:
	var entry := _reserve_entry(_me, "")
	_start()
	assert_ne(_d.record(_me, entry), "")


func test_passing_in_the_abilities_step_hands_over_or_ends() -> void:
	_record_entry(_me)
	_deploy_everything()
	_start()
	assert_eq(_d.pass_step(_me), "")
	assert_true(_d.is_done())


func test_passing_logs_a_pass() -> void:
	_record_entry(_me)
	_deploy_everything()
	_start()
	_d.pass_step(_me)
	assert_eq(_d.history[0].action, "pass")


func test_passing_in_the_units_step_is_rejected() -> void:
	_start()
	assert_ne(_d.pass_step(_me), "")


func test_a_passed_side_has_no_more_work_in_the_step() -> void:
	_record_entry(_me)
	_record_entry(_them)
	_deploy_everything()
	_start()
	_d.pass_step(_me)
	assert_false(_d.has_work(_me))
	assert_true(_d.has_work(_them))
	assert_same(_d.active, _them)


func test_once_per_battle_ability_is_used_up_with_its_own_message() -> void:
	var entry := _record_entry(_me, "Once", "Once Per Battle")
	_record_entry(_me, "Twice")
	_deploy_everything()
	_start()
	_d.record(_me, entry)
	assert_string_contains(_d.reason_unavailable(_me, entry), "once per battle")


func test_once_per_army_uses_up_every_copy_of_the_ability() -> void:
	var first := _record_entry(_me, "Shared", "Once Per Battle (Army)")
	var second := _record_entry(_me, "Shared", "Once Per Battle (Army)")
	_deploy_everything()
	_start()
	_d.record(_me, first)
	assert_true(_d.is_used(_me, second))


func test_separate_unit_abilities_with_one_name_are_used_separately() -> void:
	var first := _record_entry(_me, "Shared", "Once Per Battle")
	var second := _record_entry(_me, "Shared", "Once Per Battle")
	_deploy_everything()
	_start()
	_d.record(_me, first)
	assert_false(_d.is_used(_me, second))


func test_the_other_sides_copy_of_an_ability_is_not_used_up() -> void:
	var mine := _record_entry(_me, "Shared", "Once Per Battle (Army)")
	var theirs := _record_entry(_them, "Shared", "Once Per Battle (Army)")
	_deploy_everything()
	_start()
	_d.record(_me, mine)
	assert_false(_d.is_used(_them, theirs))


# cramped terrain

## A small territory with a 2" feature in the middle, so a 3" feature has no spot that keeps the
## rules' gap from it, though it fits beside it.
func _cramped_field() -> BattleTerrain:
	_battle.player_territory = [BattleKit.rect_polygon(0, 0, 10, 10)] as Array[PackedVector2Array]
	_battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5)))
	_add_terrain(_me)
	_start()
	return _me.terrain[0]


## A spot beside the middle feature of [method _cramped_field]: it's clear of it, but nearer than the gap.
const _NEAR := Vector2(1.7, 1.7)


func test_a_feature_with_no_spot_meeting_the_gap_is_cramped() -> void:
	var feature := _cramped_field()
	assert_true(_d.is_cramped(_me, feature))


func test_a_feature_with_room_is_not_cramped() -> void:
	_add_terrain(_me)
	_start()
	assert_false(_d.is_cramped(_me, _me.terrain[0]))


func test_cramped_terrain_only_has_to_keep_off_other_terrain() -> void:
	var feature := _cramped_field()
	assert_eq(_d.terrain_problems(_me, feature, _NEAR, 0.0).size(), 0)


func test_cramped_terrain_still_cannot_overlap_other_terrain() -> void:
	var feature := _cramped_field()
	assert_gt(_d.terrain_problems(_me, feature, Vector2(5, 5), 0.0).size(), 0)


func test_cramped_terrain_still_has_to_be_within_the_territory() -> void:
	var feature := _cramped_field()
	assert_gt(_d.terrain_problems(_me, feature, Vector2(30, 40), 0.0).size(), 0)


func test_terrain_with_room_keeps_the_gap_from_other_terrain() -> void:
	_battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5)))
	_add_terrain(_me)
	_start()
	assert_gt(_d.terrain_problems(_me, _me.terrain[0], Vector2(5, 9), 0.0).size(), 0)


func test_placing_cramped_terrain_waives_the_gap() -> void:
	var feature := _cramped_field()
	assert_eq(_d.place_terrain(_me, feature, _NEAR, 0.0), "")
	assert_true(feature.placed)


func test_placing_terrain_with_room_refuses_a_spot_inside_the_gap() -> void:
	_battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5)))
	_add_terrain(_me)
	_start()
	assert_ne(_d.place_terrain(_me, _me.terrain[0], Vector2(5, 9), 0.0), "")


func test_cramped_is_worked_out_again_after_terrain_is_placed() -> void:
	_battle.player_territory = [BattleKit.rect_polygon(0, 0, 10, 10)] as Array[PackedVector2Array]
	for i in 2:
		_me.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 4.0, Vector2.ZERO, false))
	_start()
	assert_false(_d.is_cramped(_me, _me.terrain[1]))
	assert_eq(_d.place_terrain(_me, _me.terrain[0], Vector2(2.1, 2.1), 0.0), "")
	assert_true(_d.is_cramped(_me, _me.terrain[1]))


# Spearhead

func _spearhead(terrain_each := 2) -> void:
	_battle = BattleKit.battle()
	_me = _battle.player
	_them = _battle.opponent
	_me.units.append(BattleKit.unit("Second", 2))
	_them.units.append(BattleKit.unit("Second", 2))
	_add_terrain(_me, terrain_each)
	_add_terrain(_them, terrain_each)
	_d = Deployment.new(_battle)
	_d.start()


func _order(actions: Array[Dictionary]) -> Array:
	var result := []
	for entry in actions:
		result.append([entry.army == _me, entry.action])
	return result


func test_spearhead_defender_sets_up_terrain_first() -> void:
	_spearhead()
	assert_eq(_d.step, Deployment.Step.TERRAIN)
	assert_same(_d.active, _battle.defender())


func test_spearhead_terrain_is_set_up_all_at_once_by_each_side() -> void:
	_spearhead()
	var defender := _battle.defender()
	var attacker := _battle.attacker()
	for feature in defender.terrain.duplicate():
		_d.place_terrain(defender, feature, Vector2.ZERO, 0.0, false)
	assert_same(_d.active, attacker)
	assert_eq(_d.step, Deployment.Step.TERRAIN)


func test_spearhead_defender_does_not_alternate_terrain() -> void:
	_spearhead()
	var defender := _battle.defender()
	_d.place_terrain(defender, defender.terrain[0], Vector2.ZERO, 0.0, false)
	assert_same(_d.active, defender)


func test_spearhead_attacker_sets_up_its_whole_army_then_the_defender() -> void:
	_spearhead(0)
	assert_same(_d.active, _battle.attacker())
	var attacker := _battle.attacker()
	var defender := _battle.defender()
	for unit in attacker.units.duplicate():
		assert_same(_d.active, attacker)
		_d.place_unit(attacker, unit, Formations.arrange(Formations.Kind.LINE, unit.bases, Vector2(2, 11), 0.0), 0.0, false)
	assert_same(_d.active, defender)


func test_spearhead_finishes_after_the_defender_is_down() -> void:
	_spearhead(0)
	watch_signals(_d)
	for army in [_battle.attacker(), _battle.defender()]:
		for unit: BattleUnit in army.units.duplicate():
			_d.place_unit(army, unit, Formations.arrange(Formations.Kind.LINE, unit.bases, Vector2(2, 11), 0.0), 0.0, false)
	assert_true(_d.is_done())
	assert_signal_emitted(_d, "finished")


func test_spearhead_step_names_are_not_the_matched_play_ones() -> void:
	_spearhead()
	var matched := Deployment.new(BattleKit.deployment_battle())
	assert_ne(_d.step_names(), matched.step_names())


func test_spearhead_deploys_without_regiments() -> void:
	_spearhead(0)
	assert_eq(_d.regiments_available(_me).size(), 0)


func test_spearhead_alternation_flags_only_the_abilities_step() -> void:
	_spearhead()
	assert_false(_d.alternates(Deployment.Step.TERRAIN))
	assert_false(_d.alternates(Deployment.Step.UNITS))
	assert_true(_d.alternates(Deployment.Step.OTHER))


func test_matched_play_alternates_terrain_and_units() -> void:
	assert_true(_d.alternates(Deployment.Step.TERRAIN))
	assert_true(_d.alternates(Deployment.Step.UNITS))


# whole army (Spearhead)

## A started Spearhead deployment with no terrain, where the player (the attacker) deploys first.
func _army_game() -> void:
	_battle = BattleKit.spearhead_deployment_battle()
	_me = _battle.player
	_them = _battle.opponent
	_d = Deployment.new(_battle)
	_d.start()


## Gives every undeployed unit of [param army] its own valid row, one behind another.
func _stage(army: BattleArmy) -> Array[BattleUnit]:
	var units := army.undeployed_units()
	for i in units.size():
		var anchor := Vector2(10.0 + i * 15.0, 5.0 if army == _battle.player else 39.0)
		units[i].positions = Formations.arrange(Formations.Kind.WIDE_BLOCK, units[i].bases, anchor, army.facing)
		units[i].facing = army.facing
	return units


func test_the_attacker_deploys_its_whole_army_at_once_in_army_game() -> void:
	_army_game()
	assert_true(_d.deploys_whole_army(_me))


func test_the_defender_does_not_deploy_whole_army_while_the_attacker_is_to_act() -> void:
	_army_game()
	assert_false(_d.deploys_whole_army(_them))


func test_matched_play_never_deploys_a_whole_army() -> void:
	_start()
	assert_false(_d.deploys_whole_army(_me))


func test_no_army_deploys_as_a_whole_once_deployment_is_done() -> void:
	_army_game()
	_d.place_army(_me, _stage(_me))
	_d.place_army(_them, _stage(_them))
	assert_true(_d.is_done())
	assert_false(_d.deploys_whole_army(_me))


func test_placing_an_army_deploys_every_unit() -> void:
	_army_game()
	assert_eq(_d.place_army(_me, _stage(_me)), "")
	for unit in _me.units:
		assert_true(unit.deployed, unit.name)


func test_placing_an_army_logs_each_unit() -> void:
	_army_game()
	_d.place_army(_me, _stage(_me))
	var logged := _d.history.filter(func(entry: Dictionary) -> bool: return entry.action == "unit" and entry.army == _me)
	assert_eq(logged.size(), _me.units.size())


func test_placing_an_army_hands_the_turn_over_once() -> void:
	_army_game()
	watch_signals(_d)
	_d.place_army(_me, _stage(_me))
	assert_signal_emit_count(_d, "changed", 1)
	assert_same(_d.active, _them)


func test_placing_an_army_out_of_turn_is_refused() -> void:
	_army_game()
	var units := _stage(_them)
	assert_ne(_d.place_army(_them, units), "")
	assert_false(units[0].deployed)


func test_placing_no_units_is_refused() -> void:
	_army_game()
	var none: Array[BattleUnit] = []
	assert_ne(_d.place_army(_me, none), "")


func test_a_problem_names_the_unit_and_deploys_nothing() -> void:
	_army_game()
	var units := _stage(_me)
	units[1].positions = Formations.arrange(Formations.Kind.WIDE_BLOCK, units[1].bases, Vector2(30, 40), _me.facing)
	var error := _d.place_army(_me, units)
	assert_true(error.begins_with("%s: " % units[1].name), error)
	for unit in _me.units:
		assert_false(unit.deployed, unit.name)


func test_units_overlapping_each_other_are_refused() -> void:
	_army_game()
	var units := _stage(_me)
	units[1].positions = units[0].positions.duplicate()
	assert_ne(_d.place_army(_me, units), "")
	assert_false(units[0].deployed)


func test_a_unit_without_a_position_for_every_model_is_refused() -> void:
	_army_game()
	var units := _stage(_me)
	units[0].positions = PackedVector2Array([Vector2(10, 5)])
	var error := _d.place_army(_me, units)
	assert_string_contains(error, units[0].name)
	assert_false(units[0].deployed)


func test_a_unit_that_is_already_deployed_cannot_be_placed_again() -> void:
	_army_game()
	var units := _stage(_me)
	units[0].deployed = true
	assert_string_contains(_d.place_army(_me, units), units[0].name)


# together (Deploy Regiment)

## Sets out every unit of the regiment being deployed on its own valid spot, one beside another.
func _stage_regiment(army: BattleArmy) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	for unit in _d.pickable_units(army):
		var anchor := Vector2(15.0 + units.size() * 15.0, 5.0 if army == _battle.player else 39.0)
		unit.positions = Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, anchor, army.facing)
		unit.facing = army.facing
		units.append(unit)
	return units


func test_a_regiment_being_deployed_deploys_together() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_true(_d.deploys_together(_me))


func test_matched_play_without_a_regiment_does_not_deploy_together() -> void:
	_start()
	assert_false(_d.deploys_together(_me))


func test_the_other_army_does_not_deploy_together_during_a_regiment() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_false(_d.deploys_together(_them))


func test_a_regiment_no_longer_deploys_together_once_it_is_down() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	_d.place_army(_me, _stage_regiment(_me))
	assert_false(_d.deploys_together(_me))


func test_a_called_off_regiment_no_longer_deploys_together() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	_d.cancel_regiment(_me)
	assert_false(_d.deploys_together(_me))


func test_spearhead_whole_army_deploys_together() -> void:
	_army_game()
	assert_true(_d.deploys_together(_me))


func test_placing_a_regiment_deploys_all_its_units() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_eq(_d.place_army(_me, _stage_regiment(_me)), "")
	assert_true(_unit(_me, "A1").deployed)
	assert_true(_unit(_me, "A2").deployed)


func test_placing_a_regiment_ends_it_and_hands_the_turn_on() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	_d.place_army(_me, _stage_regiment(_me))
	assert_null(_d.regiment)
	assert_same(_d.active, _them)


func test_placing_a_regiment_leaves_other_units_undeployed() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	_d.place_army(_me, _stage_regiment(_me))
	assert_false(_unit(_me, "Aux").deployed)


func test_placing_part_of_a_regiment_is_refused_naming_regiment_and_missing_unit() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	var units := _stage_regiment(_me)
	var partial: Array[BattleUnit] = [units[0]]
	var error := _d.place_army(_me, partial)
	assert_string_contains(error, _me.regiments[0].name)
	assert_string_contains(error, units[1].name)


func test_a_refused_partial_regiment_deploys_nothing_and_stays_in_progress() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	var units := _stage_regiment(_me)
	var partial: Array[BattleUnit] = [units[0]]
	_d.place_army(_me, partial)
	assert_false(units[0].deployed)
	assert_not_null(_d.regiment)
	assert_same(_d.active, _me)


func test_a_regiment_with_a_unit_in_reserve_needs_only_the_rest() -> void:
	var entry := _reserve_entry(_me, "A2")
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	var units := _stage_regiment(_me)
	_d.reserve(_me, entry, [_unit(_me, "A2")] as Array[BattleUnit])
	# Reserving A2 finished the regiment only if A1 was down; here A1 is still to place.
	assert_not_null(_d.regiment)
	var left: Array[BattleUnit] = [units[0]]
	assert_eq(_d.place_army(_me, left), "")
	assert_null(_d.regiment)


func test_a_regiment_with_an_overlapping_unit_is_refused_and_deploys_nothing() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	var units := _stage_regiment(_me)
	units[1].positions = units[0].positions.duplicate()
	assert_ne(_d.place_army(_me, units), "")
	assert_false(units[0].deployed)
	assert_false(units[1].deployed)


func test_placing_a_regiment_out_of_turn_is_refused() -> void:
	_start()
	_d.begin_regiment(_me, _me.regiments[0])
	assert_ne(_d.place_army(_them, _stage_regiment(_me)), "")


func test_placing_an_army_without_a_regiment_is_refused_in_matched_play() -> void:
	_start()
	var units: Array[BattleUnit] = [_unit(_me, "A1")]
	assert_ne(_d.place_army(_me, units), "")
