extends GutTest
## Unit tests for the AI's mirrored deployment (scripts/battle/deployment/mirror_deployer.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")

var _battle: Battle
var _d: Deployment
var _me: BattleArmy
var _ai: BattleArmy
var _mirror: MirrorDeployer


func before_each() -> void:
	_battle = BattleKit.deployment_battle()
	_setup()


## Wires up the deployer for the battle's current armies, remaking the AI's army as a mirror of
## the player's so abilities and terrain added to the player's since are copied.
func _setup() -> void:
	_me = _battle.player
	_battle.opponent = _me.mirror()
	_battle.face_armies()
	_ai = _battle.opponent
	_d = Deployment.new(_battle)
	_mirror = MirrorDeployer.new(_d, _ai, _me)


func _unit(army: BattleArmy, unit_name: String) -> BattleUnit:
	for unit in army.units:
		if unit.name == unit_name:
			return unit
	return null


func _put(unit_name: String, across := 30.0, forced := false) -> String:
	var unit := _unit(_me, unit_name)
	var positions := Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, Vector2(across, 5), _me.facing)
	return _d.place_unit(_me, unit, positions, _me.facing, not forced)


func _deploy_flat(army: BattleArmy, except := PackedStringArray()) -> void:
	for unit in army.units:
		if not unit.name in except:
			unit.deployed = true
			unit.positions = PackedVector2Array([Vector2.ZERO])


func _reserve_entry(army: BattleArmy, owner_name: String) -> DeploymentAbility:
	var ability := BattleKit.ability("Hide", PackedStringArray(["DEPLOY"]), "Set up this unit in reserve in the clouds.", "Pick this unit.")
	var entry := BattleKit.deploy_entry(ability, "Warscroll", _unit(army, owner_name))
	army.deployment_abilities.append(entry)
	return entry


func _record_entry(army: BattleArmy) -> DeploymentAbility:
	var ability := BattleKit.ability("Scout", PackedStringArray(), "Do something.")
	ability.timing = DeploymentAbility.TIMING
	var entry := BattleKit.deploy_entry(ability)
	army.deployment_abilities.append(entry)
	return entry


# reflect

func test_reflect_is_the_point_opposite_through_the_middle() -> void:
	assert_eq(_mirror.reflect(Vector2(10, 5)), Vector2(50, 39))


func test_reflecting_twice_gives_the_original_point() -> void:
	assert_eq(_mirror.reflect(_mirror.reflect(Vector2(12, 7))), Vector2(12, 7))


# take_turn

func test_it_does_nothing_on_the_players_turn() -> void:
	_d.start()
	assert_false(_mirror.take_turn())


func test_it_does_nothing_once_deployment_is_done() -> void:
	_deploy_flat(_me)
	_deploy_flat(_ai)
	_d.start()
	assert_false(_mirror.take_turn())


func test_it_mirrors_a_placed_unit_through_the_middle() -> void:
	_d.start()
	_put("A1")
	_mirror.take_turn()
	var original := _unit(_me, "A1")
	var copy := _unit(_ai, "A1")
	for i in original.positions.size():
		assert_almost_eq(copy.positions[i], _mirror.reflect(original.positions[i]), Vector2(0.01, 0.01))


func test_the_mirrored_unit_faces_the_other_way() -> void:
	_d.start()
	_put("A1")
	_mirror.take_turn()
	assert_almost_eq(_unit(_ai, "A1").facing, _unit(_me, "A1").facing + PI, 0.001)


func test_the_unit_it_mirrors_is_the_one_the_player_set_up() -> void:
	_d.start()
	_put("B2")
	_mirror.take_turn()
	assert_true(_unit(_ai, "B2").deployed)
	assert_false(_unit(_ai, "A1").deployed)


func test_it_places_the_next_unit_automatically_with_nothing_to_mirror() -> void:
	_battle.player_is_attacker = false
	_d.start()
	assert_same(_d.active, _ai)
	assert_true(_mirror.take_turn())
	var placed := 0
	for unit in _ai.units:
		if unit.deployed:
			placed += 1
	assert_eq(placed, 1)


func test_an_automatically_placed_unit_is_in_the_ais_zone() -> void:
	_battle.player_is_attacker = false
	_d.start()
	_mirror.take_turn()
	var unit := _ai.units[0]
	assert_eq(DeploymentRules.unit_problems(_battle, _ai, unit, unit.positions, unit.facing).size(), 0)


func test_it_falls_back_to_automatic_placement_when_the_reflected_spot_is_not_allowed() -> void:
	_d.start()
	# A player's unit forced into the AI's own zone reflects to a spot outside it.
	var unit := _unit(_me, "A1")
	var positions := Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, Vector2(30, 32), _me.facing)
	_d.place_unit(_me, unit, positions, _me.facing, false)
	_mirror.take_turn()
	var copy := _unit(_ai, "A1")
	assert_true(copy.deployed)
	assert_eq(DeploymentRules.unit_problems(_battle, _ai, copy, copy.positions, copy.facing).size(), 0)


func test_it_deploys_a_unit_even_when_there_is_no_room() -> void:
	_battle.player_is_attacker = false
	_battle.opponent_territory = [BattleKit.rect_polygon(0, 40, 2, 2)] as Array[PackedVector2Array]
	_d.start()
	_mirror.take_turn()
	assert_true(_ai.units[0].deployed)


# play

func test_play_keeps_going_while_it_is_the_ais_turn() -> void:
	_deploy_flat(_me, PackedStringArray(["A1"]))
	_d.start()
	_put("A1")
	_mirror.play()
	assert_true(_d.is_done())
	assert_eq(_ai.undeployed_units().size(), 0)


func test_play_stops_when_the_player_is_up_again() -> void:
	_d.start()
	_put("A1")
	_mirror.play()
	assert_same(_d.active, _me)


func test_play_does_nothing_on_the_players_turn() -> void:
	_d.start()
	_mirror.play()
	assert_eq(_d.history.size(), 0)


# regiments

func test_it_mirrors_deploy_regiment() -> void:
	_d.start()
	_d.begin_regiment(_me, _me.regiments[0])
	_put("A1", 20.0)
	_put("A2", 40.0)
	_mirror.play()
	assert_true(_ai.regiments[0].all_deployed())
	assert_eq(_d.actions_of(_ai)[0].action, "regiment")


func test_the_regiment_units_are_mirrored_into_place() -> void:
	_d.start()
	_d.begin_regiment(_me, _me.regiments[0])
	_put("A1", 20.0)
	_put("A2", 40.0)
	_mirror.play()
	assert_almost_eq(_unit(_ai, "A2").positions[0], _mirror.reflect(_unit(_me, "A2").positions[0]), Vector2(0.01, 0.01))


func test_it_does_not_deploy_a_regiment_whole_when_the_player_deployed_it_unit_by_unit() -> void:
	_d.start()
	_put("A1")
	_mirror.play()
	assert_false(_d.actions_of(_ai).any(func(entry: Dictionary) -> bool: return entry.action == "regiment"))


func test_it_does_not_start_a_regiment_whose_counterpart_is_already_partly_deployed() -> void:
	_d.start()
	_d.begin_regiment(_me, _me.regiments[0])
	_put("A1", 20.0)
	_put("A2", 40.0)
	_unit(_ai, "A1").deployed = true
	_unit(_ai, "A1").positions = PackedVector2Array([Vector2.ZERO])
	_mirror.play()
	assert_false(_d.actions_of(_ai).any(func(entry: Dictionary) -> bool: return entry.action == "regiment"))


# reserves

func test_it_mirrors_a_unit_set_up_in_reserve() -> void:
	var entry := _reserve_entry(_me, "Aux")
	_setup()
	_d.start()
	_d.reserve(_me, entry, [_unit(_me, "Aux")] as Array[BattleUnit])
	_mirror.take_turn()
	assert_eq(_unit(_ai, "Aux").reserve, _unit(_me, "Aux").reserve)
	assert_false(_unit(_ai, "Aux").is_on_battlefield())


func test_it_mirrors_a_reserve_inside_a_regiment() -> void:
	var entry := _reserve_entry(_me, "A2")
	_setup()
	_d.start()
	_d.begin_regiment(_me, _me.regiments[0])
	_put("A1", 20.0)
	_d.reserve(_me, entry, [_unit(_me, "A2")] as Array[BattleUnit])
	_mirror.play()
	assert_ne(_unit(_ai, "A2").reserve, "")
	assert_true(_unit(_ai, "A1").is_on_battlefield())


# terrain

func test_it_mirrors_terrain_through_the_middle() -> void:
	_me.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_setup()
	_d.start()
	_d.place_terrain(_me, _me.terrain[0], Vector2(20, 9), 0.5)
	_mirror.take_turn()
	assert_true(_ai.terrain[0].placed)
	assert_almost_eq(_ai.terrain[0].position, Vector2(40, 35), Vector2(0.01, 0.01))
	assert_almost_eq(_ai.terrain[0].rotation, 0.5 + PI, 0.001)


func test_it_places_terrain_itself_with_nothing_to_mirror() -> void:
	_me.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.player_is_attacker = false
	_setup()
	_d.start()
	_mirror.take_turn()
	var feature := _ai.terrain[0]
	assert_true(feature.placed)
	assert_true(DeploymentRules.is_wholly_within(_battle.opponent_territory, DeploymentRules.terrain_outline(feature, feature.position, feature.rotation)))


func test_it_still_places_terrain_when_nowhere_meets_the_rules() -> void:
	_me.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.player_is_attacker = false
	_setup()
	_battle.opponent_territory = [BattleKit.rect_polygon(0, 40, 2, 2)] as Array[PackedVector2Array]
	_d.start()
	_mirror.take_turn()
	assert_true(_ai.terrain[0].placed)


func _spearhead_battle() -> void:
	_battle = BattleKit.deployment_battle()
	_battle.mode = BattleSetup.Mode.SPEARHEAD
	_battle.battlefield_size = Vector2(30, 22)
	_battle.player_territory = [BattleKit.rect_polygon(0, 0, 10, 22)] as Array[PackedVector2Array]
	_battle.opponent_territory = [BattleKit.rect_polygon(20, 0, 10, 22)] as Array[PackedVector2Array]
	for i in 2:
		_battle.player.terrain.append(BattleKit.terrain(BattleTerrain.Kind.SPEARHEAD, 3.0, Vector2.ZERO, false))
	_setup()


func test_it_places_all_its_spearhead_terrain_within_the_rules() -> void:
	_spearhead_battle()
	_d.start()
	_mirror.take_turn()
	_mirror.take_turn()
	for feature in _ai.terrain:
		assert_true(feature.placed)
		assert_eq(_d.terrain_problems(_ai, feature, feature.position, feature.rotation).size(), 0)


func test_it_keeps_its_terrain_off_other_terrain_when_cramped() -> void:
	_spearhead_battle()
	for i in 4:
		_battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 3.0, Vector2(25, 2.5 + i * 5.0)))
	_d.start()
	assert_true(_d.is_cramped(_ai, _ai.terrain[0]), "the scenario needs a cramped battlefield")
	_mirror.take_turn()
	_mirror.take_turn()
	for feature in _ai.terrain:
		assert_true(feature.placed)
		assert_eq(_d.terrain_problems(_ai, feature, feature.position, feature.rotation).size(), 0)


# abilities step

func test_it_mirrors_a_recorded_ability() -> void:
	var entry := _record_entry(_me)
	_setup()
	_deploy_flat(_me)
	_deploy_flat(_ai)
	_d.start()
	_d.record(_me, entry)
	_mirror.take_turn()
	assert_true(_d.is_used(_ai, _ai.deployment_abilities.back()))


func test_it_mirrors_the_target_of_a_recorded_ability() -> void:
	var entry := _record_entry(_me)
	_setup()
	_deploy_flat(_me)
	_deploy_flat(_ai)
	_d.start()
	_d.record(_me, entry, _unit(_me, "A2"))
	_mirror.take_turn()
	assert_same(_d.actions_of(_ai)[0].target, _unit(_ai, "A2"))


func test_it_passes_the_abilities_step_when_there_is_nothing_to_mirror() -> void:
	_record_entry(_me)
	_setup()
	_deploy_flat(_me)
	_deploy_flat(_ai)
	_d.start()
	_d.pass_step(_me)
	_mirror.take_turn()
	assert_eq(_d.actions_of(_ai)[0].action, "pass")
	assert_true(_d.is_done())
