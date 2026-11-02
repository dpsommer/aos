extends GutTest
## Unit tests for making a battle from the player's Quick Play choices
## (scripts/battle/battle_builder.gd), with small in-code data.

const BattleKit := preload("res://test/support/battle_kit.gd")
const Kit := preload("res://test/support/army_kit.gd")

const SEEDS := 24


func _rng(seed_value := 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _packs(realm_names: Array[String] = ["Aqshy", "Ghyran"]) -> Array[SpearheadBattlepack]:
	return [BattleKit.spearhead_pack("Pack", realm_names)] as Array[SpearheadBattlepack]


func _matched(plan_name := "", seed_value := 1, plans: Array[Battleplan] = []) -> Battle:
	if plans.is_empty():
		plans = [BattleKit.battleplan("Plan A"), BattleKit.battleplan("Plan B")] as Array[Battleplan]
	return BattleBuilder.build(BattleKit.matched_play_setup(plan_name), _rng(seed_value), BattleKit.core(plans), [], BattleKit.faction())


func _spearhead(pack_name := "", realm_name := "", seed_value := 1) -> Battle:
	return BattleBuilder.build(BattleKit.spearhead_setup(pack_name, realm_name), _rng(seed_value), BattleKit.core([] as Array[Battleplan]),
			_packs(), BattleKit.spearhead_faction())


func _same_polygons(a: Array[PackedVector2Array], b: Array[PackedVector2Array]) -> bool:
	return a.size() == b.size() and a.hash() == b.hash()


# Both modes

func test_no_setup_gives_no_battle() -> void:
	assert_null(BattleBuilder.build(null, _rng()))


# Matched Play

func test_matched_play_builds_a_matched_play_battle() -> void:
	assert_eq(_matched().mode, BattleSetup.Mode.MATCHED_PLAY)


func test_matched_play_without_an_army_gives_no_battle() -> void:
	var setup := BattleKit.matched_play_setup()
	setup.army = null
	var plans: Array[Battleplan] = [BattleKit.battleplan("A")]
	assert_null(BattleBuilder.build(setup, _rng(), BattleKit.core(plans), [], BattleKit.faction()))


func test_matched_play_without_battleplans_gives_no_battle() -> void:
	var battle := BattleBuilder.build(BattleKit.matched_play_setup(), _rng(), BattleKit.core([] as Array[Battleplan]), [], BattleKit.faction())
	assert_null(battle)


func test_matched_play_keeps_the_chosen_battleplan() -> void:
	for seed_value in SEEDS:
		assert_eq(_matched("Plan B", seed_value).title, "Plan B")


func test_chosen_battleplan_is_not_random() -> void:
	assert_false(_matched("Plan A").was_random)


func test_unspecified_battleplan_is_random() -> void:
	assert_true(_matched().was_random)


func test_random_battleplan_is_one_of_the_battlepacks() -> void:
	var battle := _matched()
	assert_true(battle.title in ["Plan A", "Plan B"])
	assert_eq(battle.battleplan.name, battle.title)


func test_unknown_battleplan_name_is_resolved_at_random() -> void:
	assert_true(_matched("Nope").was_random)


func test_same_seed_picks_the_same_battleplan() -> void:
	assert_eq(_matched("", 7).title, _matched("", 7).title)


func test_different_seeds_pick_different_battleplans() -> void:
	var titles := {}
	for seed_value in SEEDS:
		titles[_matched("", seed_value).title] = true
	assert_eq(titles.size(), 2)


func test_matched_play_takes_the_twist_and_table_from_the_battleplan() -> void:
	var plan := BattleKit.battleplan("Plan A")
	plan.table = 3
	var battle := _matched("Plan A", 1, [plan] as Array[Battleplan])
	assert_eq([battle.twist, battle.table], [plan.twist, 3])


func test_matched_play_uses_the_battlepacks_battlefield_size() -> void:
	var plans: Array[Battleplan] = [BattleKit.battleplan("A")]
	var rules := BattleKit.core(plans)
	rules.battlepack.battlefield_size = Vector2(50, 40)
	var battle := BattleBuilder.build(BattleKit.matched_play_setup(), _rng(), rules, [], BattleKit.faction())
	assert_eq(battle.battlefield_size, Vector2(50, 40))


func test_matched_play_battlefield_defaults_when_the_battlepack_has_none() -> void:
	assert_eq(_matched().battlefield_size, Battle.MATCHED_PLAY_BATTLEFIELD)


func test_matched_play_has_the_battleplans_objectives_and_terrain() -> void:
	var battle := _matched("Plan A")
	assert_eq([battle.objectives.size(), battle.terrain.size()], [1, 2])


func test_matched_play_battlefield_terrain_is_placed() -> void:
	for feature in _matched("Plan A").terrain:
		assert_true(feature.placed)


func test_matched_play_player_has_the_armys_units() -> void:
	var battle := _matched()
	assert_eq([battle.player.units.size(), battle.player.model_count()], [1, 5])


func test_matched_play_reinforced_unit_has_twice_the_models() -> void:
	var setup := BattleKit.matched_play_setup()
	setup.army.auxiliary[0].reinforced = true
	var plans: Array[Battleplan] = [BattleKit.battleplan("A")]
	var battle := BattleBuilder.build(setup, _rng(), BattleKit.core(plans), [], BattleKit.faction())
	assert_eq(battle.player.model_count(), 10)


func test_matched_play_army_has_points() -> void:
	assert_gt(_matched().player.points, 0)


func test_opponent_mirrors_the_player() -> void:
	var battle := _matched()
	assert_eq([battle.opponent.name, battle.opponent.model_count(), battle.opponent.points],
			[battle.player.name, battle.player.model_count(), battle.player.points])


func test_opponent_units_are_not_the_players() -> void:
	var battle := _matched()
	assert_ne(battle.opponent.units[0], battle.player.units[0])


func test_matched_play_leaves_the_roles_to_the_roll_off() -> void:
	var battle := _matched()
	assert_false(battle.roles_assigned)
	assert_false(battle.has_territories())


func test_matched_play_battle_has_no_spearhead_data() -> void:
	var battle := _matched()
	assert_null(battle.battlepack)
	assert_null(battle.realm)


func test_faction_terrain_the_army_chose_is_added() -> void:
	var setup := BattleKit.matched_play_setup()
	var shrine := BattleKit.warscroll("Shrine", 1, 60.0)
	var faction := BattleKit.faction()
	faction.warscrolls.append(shrine)
	setup.army.faction_terrain = shrine.id
	var plans: Array[Battleplan] = [BattleKit.battleplan("A")]
	var battle := BattleBuilder.build(setup, _rng(), BattleKit.core(plans), [], faction)
	assert_eq(battle.player.terrain.size(), 1)
	assert_eq(battle.opponent.terrain.size(), 1)


func test_army_without_faction_terrain_has_none() -> void:
	assert_eq(_matched().player.terrain.size(), 0)


# Regiments

func _army_with_regiments() -> Army:
	var army := BattleKit.matched_play_setup().army
	army.regiments = [
		Kit.regiment("r1", [Kit.unit("a", "unit"), Kit.unit("b", "unit")] as Array[ArmyUnit]),
		Kit.regiment("r2", [Kit.unit("c", "unit")] as Array[ArmyUnit], "Vanguard"),
		Kit.ror_regiment("r3", "Renowned", [Kit.unit("d", "unit")] as Array[ArmyUnit]),
	] as Array[ArmyRegiment]
	army.regiments[0].name = ""
	return army


func _built() -> BattleArmy:
	return BattleBuilder.army_of(_army_with_regiments(), Kit.catalog(BattleKit.faction()))


func test_army_has_a_battle_regiment_for_each_forge_regiment() -> void:
	assert_eq(_built().regiments.size(), 3)


func test_regiment_units_are_in_the_armys_units_in_order() -> void:
	var army := _built()
	assert_eq(army.units.slice(0, 2), army.regiments[0].units)
	assert_eq(army.regiments[1].units[0], army.units[2])


func test_units_know_their_regiment() -> void:
	var army := _built()
	assert_same(army.units[0].regiment, army.regiments[0])
	assert_same(army.units[2].regiment, army.regiments[1])


func test_auxiliary_units_have_no_regiment() -> void:
	var army := _built()
	var auxiliary: BattleUnit = army.units[army.units.size() - 1]
	assert_null(auxiliary.regiment)
	assert_eq(army.units.size(), 5)


func test_an_unnamed_regiment_is_numbered_by_its_position() -> void:
	assert_eq(_built().regiments[0].name, "Regiment 1")


func test_a_named_regiment_keeps_its_name() -> void:
	assert_eq(_built().regiments[1].name, "Vanguard")


func test_a_regiment_of_renown_is_named_after_it() -> void:
	var regiment := _built().regiments[2]
	assert_eq(regiment.name, "Renowned")
	assert_true(regiment.is_renown)


func test_ordinary_regiments_are_not_of_renown() -> void:
	assert_false(_built().regiments[0].is_renown)


func test_the_opponent_has_the_same_regiments_over_its_own_units() -> void:
	var battle := BattleBuilder.build(_matched_setup_with_regiments(), _rng(), BattleKit.core([BattleKit.battleplan("A")] as Array[Battleplan]), [], BattleKit.faction())
	assert_eq(battle.opponent.regiments.size(), battle.player.regiments.size())
	assert_same(battle.opponent.units[0].regiment, battle.opponent.regiments[0])


func _matched_setup_with_regiments() -> BattleSetup:
	var setup := BattleKit.matched_play_setup()
	setup.army = _army_with_regiments()
	return setup


# Spearhead

func test_spearhead_builds_a_spearhead_battle() -> void:
	assert_eq(_spearhead().mode, BattleSetup.Mode.SPEARHEAD)


func test_spearhead_battlepack_without_realms_gives_no_battle() -> void:
	var empty: Array[SpearheadBattlepack] = [SpearheadBattlepack.new()]
	assert_null(BattleBuilder.build(BattleKit.spearhead_setup(), _rng(), null, empty, BattleKit.spearhead_faction()))


func test_spearhead_unknown_spearhead_gives_no_battle() -> void:
	var setup := BattleKit.spearhead_setup()
	setup.spearhead = "Nope"
	assert_null(BattleBuilder.build(setup, _rng(), null, _packs(), BattleKit.spearhead_faction()))


func test_spearhead_chosen_realm_is_kept() -> void:
	for seed_value in SEEDS:
		var battle := _spearhead("Pack", "Ghyran", seed_value)
		assert_eq(battle.title, "Ghyran")
		assert_false(battle.was_random)


func test_spearhead_without_a_realm_picks_one_at_random() -> void:
	var battle := _spearhead()
	assert_true(battle.was_random)
	assert_true(battle.title in ["Aqshy", "Ghyran"])


func test_different_seeds_pick_different_realms() -> void:
	var titles := {}
	for seed_value in SEEDS:
		titles[_spearhead("", "", seed_value).title] = true
	assert_eq(titles.size(), 2)


func test_spearhead_battle_takes_the_pack_and_realm_data() -> void:
	var battle := _spearhead("Pack", "Aqshy")
	assert_eq([battle.battlepack.name, battle.realm.name, battle.objectives.size(), battle.terrain.size()], ["Pack", "Aqshy", 1, 1])


func test_spearhead_battlefield_defaults_when_the_pack_has_none() -> void:
	assert_eq(_spearhead().battlefield_size, Battle.SPEARHEAD_BATTLEFIELD)


func test_spearhead_battlefield_terrain_is_placed_and_sized_by_its_feature() -> void:
	var feature := _spearhead("Pack", "Aqshy").terrain[0]
	assert_true(feature.placed)
	assert_eq(feature.position, Vector2(7, 5))
	assert_eq(feature.footprint, SpearheadTerrain.FOOTPRINTS["small"])


func test_spearhead_leaves_the_deployment_map_to_the_defender() -> void:
	var battle := _spearhead("Pack", "Aqshy")
	assert_null(battle.deployment)
	assert_false(battle.has_territories())


func test_spearhead_army_has_the_general_and_each_unit() -> void:
	var battle := _spearhead()
	assert_eq(battle.player.units.size(), 3)
	assert_eq(battle.player.model_count(), 1 + 3 + 2)


func test_spearhead_army_has_no_points() -> void:
	assert_lt(_spearhead().player.points, 0)


func test_spearhead_unit_bases_come_from_the_factions_warscrolls() -> void:
	var faction := BattleKit.spearhead_faction()
	var battle := BattleBuilder.build(BattleKit.spearhead_setup(), _rng(), BattleKit.core([] as Array[Battleplan]), _packs(), faction)
	var alpha: BattleUnit = battle.player.units[1]
	assert_eq(alpha.name, "Alpha")
	assert_eq(alpha.bases[0], faction.find_warscroll("Alpha").base_size)


func test_spearhead_opponent_mirrors_the_player() -> void:
	var battle := _spearhead()
	assert_eq([battle.opponent.name, battle.opponent.model_count()], [battle.player.name, battle.player.model_count()])


func test_spearhead_terrain_without_groups_skips_mystical_features() -> void:
	var pack := BattleKit.spearhead_pack("Pack", ["Aqshy"])
	pack.terrain_groups = [] as Array[Dictionary]
	var names: Array[String] = []
	for feature in BattleBuilder.spearhead_terrain(pack, 0):
		names.append(feature.name)
	assert_eq(names, ["Wall", "Ruin", "Tower"] as Array[String])


func test_spearhead_terrain_group_wraps_around() -> void:
	var pack := BattleKit.spearhead_pack("Pack", ["Aqshy"])
	assert_eq(BattleBuilder.spearhead_terrain(pack, 2).size(), BattleBuilder.spearhead_terrain(pack, 0).size())


func test_spearhead_terrain_is_not_placed() -> void:
	for feature in BattleBuilder.spearhead_terrain(BattleKit.spearhead_pack("Pack", ["Aqshy"]), 1):
		assert_false(feature.placed)


func test_spearhead_terrain_group_skips_unknown_features() -> void:
	var pack := BattleKit.spearhead_pack("Pack", ["Aqshy"])
	pack.terrain_groups = [{"features": ["Wall", "Missing"]}] as Array[Dictionary]
	assert_eq(BattleBuilder.spearhead_terrain(pack, 0).size(), 1)


# merge_rects

func test_touching_rects_merge_into_one_polygon() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(10, 0, 10, 10)]
	assert_eq(BattleBuilder.merge_rects(rects).size(), 1)


func test_merged_rects_cover_both() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(10, 0, 10, 10)]
	var polygon := BattleBuilder.merge_rects(rects)[0]
	assert_true(Geometry2D.is_point_in_polygon(Vector2(5, 5), polygon))
	assert_true(Geometry2D.is_point_in_polygon(Vector2(15, 5), polygon))


func test_separate_rects_stay_separate() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(30, 0, 10, 10)]
	assert_eq(BattleBuilder.merge_rects(rects).size(), 2)


func test_a_chain_of_touching_rects_merges_into_one() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(20, 0, 10, 10), Rect2(10, 0, 10, 10)]
	assert_eq(BattleBuilder.merge_rects(rects).size(), 1)


func test_no_rects_give_no_polygons() -> void:
	assert_eq(BattleBuilder.merge_rects([] as Array[Rect2]).size(), 0)


func test_a_single_rect_is_a_four_cornered_polygon() -> void:
	assert_eq(BattleBuilder.merge_rects([Rect2(2, 3, 4, 5)] as Array[Rect2])[0].size(), 4)
