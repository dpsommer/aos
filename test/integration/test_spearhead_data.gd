extends GutTest
## Integration test of SpearheadLoader and CoreRulesCatalog with the shipped Spearhead battlepacks in
## data/core/spearhead.
##
## SpearheadLoader returns null if it finds any error, so a battlepack that loads has no loader errors.

## Spacing in inches of the grid of points sampled across the battlefield. The offset keeps the
## samples off edges that lie on whole or half inches.
const _STEP := 0.5
const _OFFSET := 0.13

var _loader: SpearheadLoader
var _packs: Array[SpearheadBattlepack] = []


func before_all() -> void:
	_loader = SpearheadLoader.new()
	for file_path in CoreRulesCatalog.SPEARHEAD_FILES:
		var pack := _loader.load_battlepack(file_path)
		assert_not_null(pack, "%s: %s" % [file_path, "\n".join(_loader.errors)])
		if pack:
			_packs.append(pack)


func after_all() -> void:
	_loader = null
	_packs = []


func _on_battlefield(pack: SpearheadBattlepack, point: Vector2) -> bool:
	return point.x >= 0.0 and point.y >= 0.0 \
			and point.x <= pack.battlefield_size.x and point.y <= pack.battlefield_size.y


func _sample_points(pack: SpearheadBattlepack) -> PackedVector2Array:
	var points := PackedVector2Array()
	var y := _OFFSET
	while y < pack.battlefield_size.y:
		var x := _OFFSET
		while x < pack.battlefield_size.x:
			points.append(Vector2(x, y))
			x += _STEP
		y += _STEP
	return points


func _duplicates(names: PackedStringArray) -> PackedStringArray:
	var seen := {}
	var result := PackedStringArray()
	for card_name in names:
		if seen.has(card_name):
			result.append(card_name)
		seen[card_name] = true
	return result


func test_battlepacks_load_without_errors() -> void:
	assert_gt(_packs.size(), 0)
	assert_eq(_loader.errors.size(), 0, "\n".join(_loader.errors))


func test_catalog_lists_every_shipped_battlepack() -> void:
	assert_eq(CoreRulesCatalog.spearhead_battlepacks().size(), CoreRulesCatalog.SPEARHEAD_FILES.size())


func test_three_battlepacks_ship() -> void:
	assert_eq(CoreRulesCatalog.spearhead_battlepacks().size(), 3)
	assert_eq(_packs.size(), 3)


func test_catalog_finds_battlepack_by_name() -> void:
	for pack in _packs:
		assert_eq(CoreRulesCatalog.get_spearhead_battlepack(pack.name).name, pack.name)


func test_catalog_returns_null_for_unknown_battlepack() -> void:
	assert_null(CoreRulesCatalog.get_spearhead_battlepack("Not A Battlepack"))


func test_every_realm_has_an_objective() -> void:
	for pack in _packs:
		assert_gt(pack.realms.size(), 0)
		for realm in pack.realms:
			assert_gt(realm.objectives.size(), 0, "%s / %s" % [pack.name, realm.name])


func test_no_objective_name_repeats_within_a_realm() -> void:
	for pack in _packs:
		for realm in pack.realms:
			var types := PackedStringArray()
			for objective in realm.objectives:
				types.append(objective.type)
			assert_eq(_duplicates(types), PackedStringArray(), "%s / %s" % [pack.name, realm.name])


func test_every_objective_is_one_of_the_battlepacks_objective_names() -> void:
	for pack in _packs:
		for realm in pack.realms:
			for objective in realm.objectives:
				assert_has(pack.objective_names, objective.type, "%s / %s" % [pack.name, realm.name])


## The circle overlaps the battlefield if the closest point of the battlefield to its centre is within its radius.
func test_every_objective_circle_overlaps_the_battlefield() -> void:
	for pack in _packs:
		for realm in pack.realms:
			for objective in realm.objectives:
				var closest := objective.position.clamp(Vector2.ZERO, pack.battlefield_size)
				assert_lte(objective.position.distance_to(closest), pack.radius_of(objective),
						"%s / %s / %s" % [pack.name, realm.name, objective.type])


func test_every_objective_has_a_positive_radius() -> void:
	for pack in _packs:
		for realm in pack.realms:
			for objective in realm.objectives:
				assert_gt(pack.radius_of(objective), 0.0, "%s / %s / %s" % [pack.name, realm.name, objective.type])


func test_every_realm_terrain_feature_is_mystical_and_on_the_battlefield() -> void:
	for pack in _packs:
		for realm in pack.realms:
			for feature in realm.terrain:
				var context := "%s / %s / %s" % [pack.name, realm.name, feature.type]
				assert_true(pack.get_terrain_feature(feature.type).mystical, context)
				assert_true(_on_battlefield(pack, feature.position), context)


func test_every_terrain_group_names_existing_non_mystical_features() -> void:
	for pack in _packs:
		for group in pack.terrain_groups:
			assert_gt(group.features.size(), 0, group.name)
			for feature_name in group.features:
				var feature := pack.get_terrain_feature(feature_name)
				assert_not_null(feature, "%s / %s: %s" % [pack.name, group.name, feature_name])
				if feature:
					assert_false(feature.mystical, "%s / %s: %s" % [pack.name, group.name, feature_name])


func test_every_terrain_group_has_one_large_and_one_small_feature() -> void:
	for pack in _packs:
		for group in pack.terrain_groups:
			var sizes := PackedStringArray()
			for feature_name in group.features:
				var feature := pack.get_terrain_feature(feature_name)
				if feature:
					sizes.append(feature.size)
			sizes.sort()
			assert_eq(sizes, PackedStringArray(["large", "small"]), "%s / %s" % [pack.name, group.name])


func test_every_objective_centre_is_on_the_battlefield() -> void:
	for pack in _packs:
		for realm in pack.realms:
			for objective in realm.objectives:
				assert_true(_on_battlefield(pack, objective.position),
						"%s / %s / %s" % [pack.name, realm.name, objective.type])


func test_every_territory_corner_is_on_the_battlefield() -> void:
	for pack in _packs:
		for map in pack.deployment_maps:
			for corner in map.territory_a + map.territory_b:
				assert_true(_on_battlefield(pack, corner), "%s / %s: %s" % [pack.name, map.name, corner])


func _overlaps(pack: SpearheadBattlepack, map: DeploymentMap) -> int:
	var overlaps := 0
	for point in _sample_points(pack):
		if Geometry2D.is_point_in_polygon(point, map.territory_a) \
				and Geometry2D.is_point_in_polygon(point, map.territory_b):
			overlaps += 1
	return overlaps


func _uncovered(pack: SpearheadBattlepack, map: DeploymentMap) -> int:
	var uncovered := 0
	for point in _sample_points(pack):
		if not map.in_territory_a(point) and not map.in_territory_b(point):
			uncovered += 1
	return uncovered


func test_territories_do_not_overlap() -> void:
	for pack in _packs:
		assert_gt(pack.deployment_maps.size(), 0)
		for map in pack.deployment_maps:
			assert_eq(_overlaps(pack, map), 0, "%s / %s" % [pack.name, map.name])


func test_territories_together_cover_the_battlefield() -> void:
	for pack in _packs:
		for map in pack.deployment_maps:
			assert_eq(_uncovered(pack, map), 0, "%s / %s" % [pack.name, map.name])


func test_twist_deck_of_every_realm_has_no_duplicate_names() -> void:
	for pack in _packs:
		for realm in pack.realms:
			var names := PackedStringArray()
			for twist in realm.twists:
				names.append(twist.name)
			assert_eq(_duplicates(names), PackedStringArray(), "%s / %s" % [pack.name, realm.name])


func test_battle_tactic_deck_has_no_duplicate_names() -> void:
	for pack in _packs:
		var names := PackedStringArray()
		for card in pack.battle_tactic_cards:
			names.append(card.name)
		assert_gt(names.size(), 0)
		assert_eq(_duplicates(names), PackedStringArray(), pack.name)


func test_every_tactic_card_command_is_a_command_with_a_timing() -> void:
	for pack in _packs:
		for card in pack.battle_tactic_cards:
			assert_eq(card.command.type, "command", card.name)
			assert_false(card.command.timing.is_empty(), card.name)


func test_every_objective_a_battle_tactic_names_exists() -> void:
	var regex := RegEx.create_from_string("the ([A-Z][\\w' -]*?) objective")
	var named := 0
	for pack in _packs:
		for card in pack.battle_tactic_cards:
			for match in regex.search_all(card.condition):
				named += 1
				assert_has(pack.objective_names, match.get_string(1), "%s / %s" % [pack.name, card.name])
	assert_gt(named, 0)


func test_every_pack_has_a_non_mystical_terrain_feature() -> void:
	for pack in _packs:
		var found := false
		for terrain in pack.terrain_features:
			found = found or not terrain.mystical
		assert_true(found, pack.name)


func test_every_rectangular_objectives_corners_are_on_the_battlefield() -> void:
	var rectangles := 0
	for pack in _packs:
		for realm in pack.realms:
			for objective in realm.objectives:
				if objective.is_rectangle():
					rectangles += 1
					for corner in objective.corners():
						assert_true(_on_battlefield(pack, corner),
								"%s / %s / %s: %s" % [pack.name, realm.name, objective.type, corner])
	assert_gt(rectangles, 0)


func test_every_road_is_on_the_battlefield() -> void:
	for pack in _packs:
		for realm in pack.realms:
			for road in realm.roads:
				assert_gte(road.size(), 3, "%s / %s" % [pack.name, realm.name])
				for corner in road:
					assert_true(_on_battlefield(pack, corner), "%s / %s: %s" % [pack.name, realm.name, corner])


func test_roads_of_the_realm_with_a_junction_pass_through_the_battlefield_centre() -> void:
	var junctions := 0
	for pack in _packs:
		for realm in pack.realms:
			if realm.get_objective("Junction") == null:
				continue
			junctions += 1
			assert_gt(realm.roads.size(), 0, "%s / %s" % [pack.name, realm.name])
			for road in realm.roads:
				assert_true(Geometry2D.is_point_in_polygon(pack.battlefield_size / 2.0, road),
						"%s / %s" % [pack.name, realm.name])
	assert_gt(junctions, 0)


func test_every_twist_relic_names_a_relic() -> void:
	for pack in _packs:
		for realm in pack.realms:
			for twist in realm.twists:
				if not twist.relic.is_empty():
					assert_not_null(pack.get_relic(twist.relic), "%s / %s / %s" % [pack.name, realm.name, twist.name])


func test_every_starting_relic_names_a_relic() -> void:
	for pack in _packs:
		for realm in pack.realms:
			for relic_name in realm.starting_relics:
				assert_not_null(pack.get_relic(relic_name), "%s / %s: %s" % [pack.name, realm.name, relic_name])


func test_every_realm_with_relics_has_two_starting_relics() -> void:
	var with_relics := 0
	for pack in _packs:
		if pack.relics.is_empty():
			continue
		for realm in pack.realms:
			with_relics += 1
			assert_eq(realm.starting_relics.size(), 2, "%s / %s" % [pack.name, realm.name])
	assert_gt(with_relics, 0)


func test_every_campaign_battle_names_an_existing_realm() -> void:
	for pack in _packs:
		if pack.campaign:
			assert_gt(pack.campaign.battles.size(), 0, pack.name)
			for battle in pack.campaign.battles:
				assert_not_null(pack.get_realm(battle.realm), "%s / %s" % [pack.name, battle.name])


func test_every_campaign_battle_has_a_deployment_map() -> void:
	for pack in _packs:
		if pack.campaign:
			for battle in pack.campaign.battles:
				assert_not_null(battle.deployment_map, "%s / %s" % [pack.name, battle.name])


func test_campaign_battle_territories_do_not_overlap() -> void:
	var battles := 0
	for pack in _packs:
		if pack.campaign:
			for battle in pack.campaign.battles:
				battles += 1
				assert_eq(_overlaps(pack, battle.deployment_map), 0, "%s / %s" % [pack.name, battle.name])
	assert_gt(battles, 0)


func test_campaign_battle_territories_cover_the_battlefield() -> void:
	for pack in _packs:
		if pack.campaign:
			for battle in pack.campaign.battles:
				assert_eq(_uncovered(pack, battle.deployment_map), 0, "%s / %s" % [pack.name, battle.name])


func test_campaign_battle_territory_corners_are_on_the_battlefield() -> void:
	for pack in _packs:
		if pack.campaign:
			for battle in pack.campaign.battles:
				var map := battle.deployment_map
				for corner in map.territory_a + map.territory_b:
					assert_true(_on_battlefield(pack, corner), "%s / %s: %s" % [pack.name, battle.name, corner])
