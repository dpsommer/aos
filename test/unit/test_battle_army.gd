extends GutTest
## Unit tests for one side's army on the battlefield (scripts/battle/battle_army.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


func test_model_count_adds_up_every_unit() -> void:
	var army := BattleKit.army("A", 3)
	army.units.append(BattleKit.unit("B", 4))
	assert_eq(army.model_count(), 7)


func test_model_count_of_an_empty_army_is_zero() -> void:
	assert_eq(BattleArmy.new().model_count(), 0)


func test_details_show_points_for_a_matched_play_army() -> void:
	var army := BattleKit.army()
	army.faction_name = "Kharadron Overlords"
	army.points = 1940
	assert_eq(army.details(), "Kharadron Overlords · 1940 pts")


func test_details_say_spearhead_for_an_army_without_points() -> void:
	var army := BattleKit.army()
	army.faction_name = "Kharadron Overlords"
	assert_eq(army.details(), "Kharadron Overlords · Spearhead")


func test_mirror_keeps_name_faction_and_points() -> void:
	var army := BattleKit.army()
	army.points = 500
	var copy := army.mirror()
	assert_eq([copy.name, copy.faction_name, copy.points], [army.name, army.faction_name, army.points])


func test_mirror_has_as_many_units_and_models() -> void:
	var army := BattleKit.army("A", 4)
	army.units.append(BattleKit.unit("B", 2))
	var copy := army.mirror()
	assert_eq([copy.units.size(), copy.model_count()], [army.units.size(), army.model_count()])


func test_mirror_units_are_independent_copies() -> void:
	var army := BattleKit.army()
	var copy := army.mirror()
	assert_ne(copy.units[0], army.units[0])
	copy.units.clear()
	assert_eq(army.units.size(), 1)


func test_mirror_units_are_not_deployed() -> void:
	var army := BattleKit.army("A", 1)
	army.units[0].positions = PackedVector2Array([Vector2(3, 3)])
	assert_eq(army.mirror().units[0].positions.size(), 0)


func test_mirror_terrain_is_unplaced() -> void:
	var army := BattleKit.army()
	army.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2(4, 4)))
	assert_false(army.mirror().terrain[0].placed)


func test_mirror_does_not_unplace_the_original_terrain() -> void:
	var army := BattleKit.army()
	army.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2(4, 4)))
	army.mirror()
	assert_true(army.terrain[0].placed)


func test_mirror_terrain_is_a_copy() -> void:
	var army := BattleKit.army()
	army.terrain.append(BattleKit.terrain())
	var copy := army.mirror()
	assert_ne(copy.terrain[0], army.terrain[0])
	assert_eq(copy.terrain[0].footprint, army.terrain[0].footprint)


# deployment state

func test_undeployed_units_leave_out_the_deployed_ones() -> void:
	var army := BattleKit.army("A", 2)
	army.units.append(BattleKit.unit("B", 2))
	army.units[0].deployed = true
	assert_eq(army.undeployed_units(), [army.units[1]] as Array[BattleUnit])


func test_a_unit_in_reserve_is_not_undeployed() -> void:
	var army := BattleKit.army()
	army.units[0].deployed = true
	army.units[0].reserve = "in the clouds"
	assert_eq(army.undeployed_units().size(), 0)


func test_unplaced_terrain_leaves_out_placed_features() -> void:
	var army := BattleKit.army()
	army.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, true))
	army.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	assert_eq(army.unplaced_terrain(), [army.terrain[1]] as Array[BattleTerrain])


func test_deployment_ability_is_found_by_name() -> void:
	var army := BattleKit.army()
	var entry := BattleKit.deploy_entry(BattleKit.ability("Hide"))
	army.deployment_abilities.append(entry)
	assert_same(army.deployment_ability("Hide"), entry)


func test_deployment_ability_can_be_limited_to_a_source() -> void:
	var army := BattleKit.army()
	var trait_entry := BattleKit.deploy_entry(BattleKit.ability("Hide"), "Battle trait")
	var scroll_entry := BattleKit.deploy_entry(BattleKit.ability("Hide"), "Warscroll")
	army.deployment_abilities.append_array([trait_entry, scroll_entry] as Array[DeploymentAbility])
	assert_same(army.deployment_ability("Hide", "Warscroll"), scroll_entry)


func test_unknown_deployment_ability_is_null() -> void:
	assert_null(BattleKit.army().deployment_ability("Nothing"))


# mirror, regiments and abilities

func test_mirror_has_the_same_regiments_with_the_copied_units() -> void:
	var battle := BattleKit.deployment_battle()
	var copy := battle.player.mirror()
	assert_eq(copy.regiments.size(), battle.player.regiments.size())
	assert_eq(copy.regiments[0].name, battle.player.regiments[0].name)
	assert_eq(copy.regiments[0].units, [copy.units[0], copy.units[1]] as Array[BattleUnit])


func test_mirror_units_point_at_the_copied_regiments() -> void:
	var battle := BattleKit.deployment_battle()
	var copy := battle.player.mirror()
	assert_same(copy.units[0].regiment, copy.regiments[0])
	assert_null(copy.units[4].regiment)


func test_mirror_regiments_are_not_the_originals() -> void:
	var battle := BattleKit.deployment_battle()
	var copy := battle.player.mirror()
	assert_ne(copy.regiments[0], battle.player.regiments[0])


func test_mirror_keeps_whether_a_regiment_is_of_renown() -> void:
	var army := BattleKit.army()
	var members: Array[BattleUnit] = [army.units[0]]
	army.regiments.append(BattleKit.regiment("Renowned", members, true))
	assert_true(army.mirror().regiments[0].is_renown)


func test_mirror_abilities_belong_to_the_copied_units() -> void:
	var army := BattleKit.army()
	army.deployment_abilities.append(BattleKit.deploy_entry(BattleKit.ability("Hide"), "Warscroll", army.units[0]))
	var copy := army.mirror()
	assert_same(copy.deployment_abilities[0].owner, copy.units[0])


func test_mirror_abilities_belong_to_the_copied_regiments() -> void:
	var army := BattleKit.army()
	var members: Array[BattleUnit] = [army.units[0]]
	var regiment := BattleKit.regiment("R", members)
	army.regiments.append(regiment)
	army.deployment_abilities.append(BattleKit.deploy_entry(BattleKit.ability("Hide"), "Regiment of Renown", null, regiment))
	var copy := army.mirror()
	assert_same(copy.deployment_abilities[0].regiment, copy.regiments[0])


func test_mirror_abilities_are_in_the_same_order() -> void:
	var battle := BattleKit.deployment_battle()
	var copy := battle.player.mirror()
	for i in copy.deployment_abilities.size():
		assert_eq(copy.deployment_abilities[i].name(), battle.player.deployment_abilities[i].name())
		assert_ne(copy.deployment_abilities[i], battle.player.deployment_abilities[i])
