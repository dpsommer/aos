extends GutTest
## Unit tests for building a Spearhead battlepack from JSON (scripts/data/core/spearhead_loader.gd and the
## battlepack model classes).
##
## Expectations are read from the fixture JSON, so editing a fixture value doesn't break tests.

const FIXTURES := "res://test/fixtures/core/spearhead"


func _path(fixture: String) -> String:
	return FIXTURES.path_join(fixture + ".json")


func _json(fixture := "valid") -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_path(fixture)))


func _load(fixture := "valid") -> SpearheadBattlepack:
	return SpearheadLoader.new().load_battlepack(_path(fixture))


func _errors(fixture: String) -> PackedStringArray:
	var loader := SpearheadLoader.new()
	loader.load_battlepack(_path(fixture))
	return loader.errors


func _has_error_naming(errors: PackedStringArray, file_name: String, field: String) -> bool:
	for error in errors:
		if error.begins_with(file_name) and field in error:
			return true
	return false


func _corners(data: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for corner in data:
		result.append(Vector2(corner.x, corner.y))
	return result


func _centroid(polygon: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for corner in polygon:
		sum += corner
	return sum / polygon.size()


## Asserts that [param fixture] fails to load with an error naming [param field].
func _assert_invalid(fixture: String, field: String) -> void:
	assert_null(_load(fixture), "%s should not load" % fixture)
	assert_true(_has_error_naming(_errors(fixture), fixture + ".json", field), str(_errors(fixture)))


# --- Fields come from the file ---

func test_valid_file_loads_without_errors() -> void:
	assert_not_null(_load())
	assert_eq(_errors("valid").size(), 0, "\n".join(_errors("valid")))


func test_name_and_battle_rounds_come_from_file() -> void:
	var data := _json()
	var pack := _load()
	assert_eq([pack.name, pack.battle_rounds], [data.name, int(data.battle_rounds)])


func test_battlefield_size_comes_from_file() -> void:
	var data := _json()
	assert_eq(_load().battlefield_size, Vector2(data.battlefield.width, data.battlefield.depth))


func test_objective_radius_comes_from_file() -> void:
	assert_eq(_load().objective_radius, float(_json().objective_radius))


func test_objective_names_come_from_file_in_order() -> void:
	assert_eq(Array(_load().objective_names), _json().objective_names)


func test_terrain_features_come_from_file() -> void:
	var expected: Dictionary = _json().terrain_features[0]
	var terrain := _load().terrain_features[0]
	assert_eq([terrain.name, terrain.size, Array(terrain.abilities)], [expected.name, expected.size, expected.abilities])


func test_terrain_abilities_come_from_file() -> void:
	var expected: Array = _json().terrain_abilities
	var pack := _load()
	assert_eq([pack.terrain_abilities.size(), pack.terrain_abilities[0].name], [expected.size(), expected[0].name])


func test_realm_objectives_come_from_file_in_order() -> void:
	var expected: Array = _json().realms[0].objectives
	var objectives := _load().realms[0].objectives
	assert_eq(objectives.size(), expected.size())
	for i in expected.size():
		assert_eq([objectives[i].type, objectives[i].position],
				[expected[i].type, Vector2(expected[i].x, expected[i].y)])


func test_twists_come_from_file_in_order() -> void:
	var expected: Array = _json().realms[0].twists
	var twists := _load().realms[0].twists
	assert_eq(twists.size(), expected.size())
	for i in expected.size():
		assert_eq([twists[i].name, twists[i].text], [expected[i].name, expected[i].text])


func test_twist_without_options_has_none() -> void:
	assert_eq(_load().realms[0].twists[0].options.size(), 0)


func test_twist_options_come_from_file() -> void:
	var expected: Array = _json().realms[0].twists[1].options
	var options := _load().realms[0].twists[1].options
	assert_eq(options.size(), expected.size())
	assert_eq([options[0].name, options[0].text], [expected[0].name, expected[0].text])


func test_realms_keep_file_order() -> void:
	var expected: Array = _json().realms
	var pack := _load()
	assert_eq([pack.realms[0].name, pack.realms[1].name], [expected[0].name, expected[1].name])


func test_deployment_maps_come_from_file_in_order() -> void:
	var expected: Array = _json().deployment_maps
	var maps := _load().deployment_maps
	assert_eq(maps.size(), expected.size())
	for i in expected.size():
		assert_eq(maps[i].name, expected[i].name)


func test_territory_corners_come_from_file_in_order() -> void:
	var expected: Dictionary = _json().deployment_maps[1]
	var map := _load().deployment_maps[1]
	assert_eq([map.territory_a, map.territory_b],
			[_corners(expected.territory_a), _corners(expected.territory_b)])


func test_battleplan_comes_from_file() -> void:
	var expected: Dictionary = _json().battleplan
	var pack := _load()
	assert_eq([pack.battleplan_name, pack.battleplan_sections.size(), Array(pack.scoring)],
			[expected.name, expected.sections.size(), expected.scoring])


func test_tactic_cards_come_from_file_in_order() -> void:
	var expected: Array = _json().battle_tactic_cards
	var cards := _load().battle_tactic_cards
	assert_eq(cards.size(), expected.size())
	for i in expected.size():
		assert_eq([cards[i].name, cards[i].condition], [expected[i].name, expected[i].condition])


func test_tactic_card_command_comes_from_file() -> void:
	var expected: Dictionary = _json().battle_tactic_cards[0].command
	var command := _load().battle_tactic_cards[0].command
	assert_eq([command.name, command.type, command.timing], [expected.name, expected.type, expected.timing])


func test_faqs_come_from_file() -> void:
	var expected: Dictionary = _json().faqs[0]
	var faq := _load().faqs[0]
	assert_eq([faq.about, faq.question, faq.answer], [expected.about, expected.question, expected.answer])


# --- Lookups ---

func test_get_realm_finds_by_name() -> void:
	var realm_name: String = _json().realms[1].name
	assert_eq(_load().get_realm(realm_name).name, realm_name)


func test_get_realm_returns_null_for_unknown_name() -> void:
	assert_null(_load().get_realm("Not A Realm"))


func test_get_deployment_map_finds_by_name() -> void:
	var map_name: String = _json().deployment_maps[1].name
	assert_eq(_load().get_deployment_map(map_name).name, map_name)


func test_get_deployment_map_returns_null_for_unknown_name() -> void:
	assert_null(_load().get_deployment_map("Not A Map"))


func test_get_terrain_ability_finds_by_name() -> void:
	var ability_name: String = _json().terrain_abilities[1].name
	assert_eq(_load().get_terrain_ability(ability_name).name, ability_name)


func test_get_terrain_ability_returns_null_for_unknown_name() -> void:
	assert_null(_load().get_terrain_ability("Not An Ability"))


func test_get_objective_finds_by_name() -> void:
	var expected: Dictionary = _json().realms[1].objectives[0]
	var objective := _load().realms[1].get_objective(expected.type)
	assert_eq(objective.position, Vector2(expected.x, expected.y))


func test_get_objective_returns_null_for_unknown_name() -> void:
	assert_null(_load().realms[0].get_objective("Not An Objective"))


# --- Deployment map containment ---

func test_point_inside_territory_a_is_only_in_a() -> void:
	var map := _load().deployment_maps[1]
	var point := _centroid(map.territory_a)
	assert_eq([map.in_territory_a(point), map.in_territory_b(point)], [true, false])


func test_point_inside_territory_b_is_only_in_b() -> void:
	var map := _load().deployment_maps[1]
	var point := _centroid(map.territory_b)
	assert_eq([map.in_territory_a(point), map.in_territory_b(point)], [false, true])


func test_point_outside_both_territories_is_in_neither() -> void:
	var map := _load().deployment_maps[0]
	var far := Vector2(_json().battlefield.width, _json().battlefield.depth) * 2.0
	assert_eq([map.in_territory_a(far), map.in_territory_b(far)], [false, false])


func test_point_on_shared_edge_is_in_both() -> void:
	var map := _load().deployment_maps[0]
	var point := (map.territory_a[2] + map.territory_a[3]) / 2.0
	assert_eq([map.in_territory_a(point), map.in_territory_b(point)], [true, true])


func test_point_on_diagonal_shared_edge_is_in_both() -> void:
	var map := _load().deployment_maps[1]
	var point := (map.territory_a[1] + map.territory_a[2]) / 2.0
	assert_eq([map.in_territory_a(point), map.in_territory_b(point)], [true, true])


func test_corner_is_in_its_territory() -> void:
	var map := _load().deployment_maps[0]
	assert_true(map.in_territory_a(map.territory_a[0]))


# --- Validation ---

func test_missing_file_returns_null() -> void:
	assert_null(_load("does_not_exist"))


func test_missing_file_error_names_file() -> void:
	assert_true(_has_error_naming(_errors("does_not_exist"), "does_not_exist.json", "not found"),
			str(_errors("does_not_exist")))


func test_missing_name_is_invalid() -> void:
	_assert_invalid("missing_name", "name is required")


func test_missing_battle_rounds_is_invalid() -> void:
	_assert_invalid("missing_battle_rounds", "battle_rounds")


func test_missing_battlefield_is_invalid() -> void:
	_assert_invalid("missing_battlefield", "battlefield")


func test_missing_objective_radius_is_invalid() -> void:
	_assert_invalid("missing_objective_radius", "objective_radius")


func test_missing_battleplan_is_invalid() -> void:
	_assert_invalid("missing_battleplan", "battleplan")


func test_unknown_terrain_size_is_invalid() -> void:
	_assert_invalid("bad_terrain_size", "terrain_features[0].size")


func test_unknown_terrain_ability_is_invalid() -> void:
	_assert_invalid("unknown_terrain_ability", "terrain_features[1].abilities[1]")


func test_unknown_objective_name_is_invalid() -> void:
	_assert_invalid("bad_objective_name", "realms[1].objectives[0].type")


func test_territory_with_too_few_corners_is_invalid() -> void:
	_assert_invalid("short_territory", "deployment_maps[1].territory_b")


func test_territory_corner_missing_a_coordinate_is_invalid() -> void:
	_assert_invalid("bad_corner", "deployment_maps[0].territory_a[2].y")


func test_tactic_card_without_command_is_invalid() -> void:
	_assert_invalid("no_command", "battle_tactic_cards[1].command")


func test_tactic_card_without_condition_is_invalid() -> void:
	_assert_invalid("no_condition", "battle_tactic_cards[0].condition")


func test_tactic_card_without_name_is_invalid() -> void:
	_assert_invalid("no_tactic_name", "battle_tactic_cards[0].name")


func test_twist_without_name_is_invalid() -> void:
	_assert_invalid("twist_no_name", "realms[0].twists[0].name")


func test_twist_without_text_is_invalid() -> void:
	_assert_invalid("twist_no_text", "realms[0].twists[0].text")


func test_twist_option_without_text_is_invalid() -> void:
	_assert_invalid("bad_twist_option", "realms[0].twists[1].options[1].text")


func test_errors_are_reset_between_calls() -> void:
	var loader := SpearheadLoader.new()
	loader.load_battlepack(_path("missing_name"))
	assert_false(loader.errors.is_empty())
	loader.load_battlepack(_path("valid"))
	assert_eq(loader.errors.size(), 0)


# --- Objective radius ---

func test_individual_objective_radius_comes_from_file() -> void:
	var expected: Dictionary = _json().realms[0].objectives[0]
	assert_eq(_load().realms[0].objectives[0].radius, float(expected.radius))


func test_objective_radius_defaults_to_zero() -> void:
	assert_eq(_load().realms[0].objectives[1].radius, 0.0)


func test_radius_of_uses_the_objectives_own_radius() -> void:
	var pack := _load()
	var objective := pack.realms[0].objectives[0]
	assert_eq(pack.radius_of(objective), objective.radius)


func test_radius_of_falls_back_to_the_battlepacks_radius() -> void:
	var pack := _load()
	assert_eq(pack.radius_of(pack.realms[0].objectives[1]), pack.objective_radius)


# --- Terrain ---

func test_terrain_feature_mystical_comes_from_file() -> void:
	var data := _json()
	var index := -1
	for i in data.terrain_features.size():
		if data.terrain_features[i].get("mystical", false):
			index = i
	assert_gte(index, 0, "fixture needs a mystical terrain feature")
	assert_true(_load().terrain_features[index].mystical)


func test_terrain_feature_mystical_defaults_to_false() -> void:
	assert_false(_load().terrain_features[0].mystical)


func test_non_boolean_mystical_is_invalid() -> void:
	_assert_invalid("bad_mystical", "terrain_features[2].mystical")


func test_get_terrain_feature_finds_by_name() -> void:
	var feature_name: String = _json().terrain_features[1].name
	assert_eq(_load().get_terrain_feature(feature_name).name, feature_name)


func test_get_terrain_feature_returns_null_for_unknown_name() -> void:
	assert_null(_load().get_terrain_feature("Not A Feature"))


func test_terrain_groups_come_from_file_in_order() -> void:
	var expected: Array = _json().terrain_groups
	var groups := _load().terrain_groups
	assert_eq(groups.size(), expected.size())
	for i in expected.size():
		assert_eq([groups[i].name, Array(groups[i].features)], [expected[i].name, expected[i].features])


func test_terrain_group_naming_unknown_feature_is_invalid() -> void:
	_assert_invalid("bad_group_feature", "terrain_groups[1].features[1]")


func test_realm_terrain_comes_from_file_in_order() -> void:
	var expected: Array = _json().realms[0].terrain
	var terrain := _load().realms[0].terrain
	assert_eq(terrain.size(), expected.size())
	for i in expected.size():
		assert_eq([terrain[i].type, terrain[i].position], [expected[i].type, Vector2(expected[i].x, expected[i].y)])


func test_realm_without_terrain_has_none() -> void:
	assert_eq(_load().realms[1].terrain.size(), 0)


func test_realm_terrain_naming_unknown_feature_is_invalid() -> void:
	_assert_invalid("bad_realm_terrain_type", "realms[0].terrain[1].type")


# --- Rectangular objectives ---

## Fire's rectangular objective in the fixture and in the loaded battlepack.
func _rect_data() -> Dictionary:
	return _json().realms[0].objectives[2]


func _rect(pack: SpearheadBattlepack) -> MapFeature:
	return pack.realms[0].objectives[2]


func test_objective_extent_comes_from_file() -> void:
	var expected := _rect_data()
	assert_eq(_rect(_load()).extent, Vector2(expected.width, expected.depth))


func test_objective_rotation_comes_from_file() -> void:
	assert_eq(_rect(_load()).rotation, float(_rect_data().rotation))


func test_objective_with_extent_is_a_rectangle() -> void:
	assert_true(_rect(_load()).is_rectangle())


func test_objective_without_extent_is_not_a_rectangle() -> void:
	assert_false(_load().realms[0].objectives[0].is_rectangle())


func test_objective_rotation_defaults_to_zero() -> void:
	assert_eq(_load().realms[0].objectives[0].rotation, 0.0)


func test_extent_with_only_a_width_is_invalid() -> void:
	_assert_invalid("no_extent_depth", "realms[0].objectives[2].depth")


func test_rectangle_has_four_corners() -> void:
	assert_eq(_rect(_load()).corners().size(), 4)


func test_rectangle_corners_are_centred_on_its_position() -> void:
	var feature := _rect(_load())
	assert_true(_centroid(feature.corners()).is_equal_approx(feature.position))


func test_rectangle_sides_are_its_width_and_depth() -> void:
	var feature := _rect(_load())
	var corners := feature.corners()
	assert_almost_eq(corners[0].distance_to(corners[1]), feature.extent.x, 0.001)
	assert_almost_eq(corners[1].distance_to(corners[2]), feature.extent.y, 0.001)


func test_rectangle_corners_are_rotated_by_its_rotation() -> void:
	var feature := _rect(_load())
	var corners := feature.corners()
	assert_almost_eq(absf(corners[1].x - corners[0].x), feature.extent.x * absf(cos(deg_to_rad(feature.rotation))), 0.001)


# --- Standing on an objective ---

func test_circle_centre_is_on_the_objective() -> void:
	var pack := _load()
	var objective := pack.realms[0].objectives[0]
	assert_true(pack.is_on_objective(objective, objective.position))


func test_point_beyond_circle_is_not_on_the_objective() -> void:
	var pack := _load()
	var objective := pack.realms[0].objectives[0]
	assert_false(pack.is_on_objective(objective, objective.position + Vector2(pack.radius_of(objective) + 1.0, 0)))


func test_point_on_circle_edge_is_on_the_objective() -> void:
	var pack := _load()
	var objective := pack.realms[0].objectives[0]
	assert_true(pack.is_on_objective(objective, objective.position + Vector2(0, pack.radius_of(objective))))


func test_circle_uses_the_battlepacks_radius_without_its_own() -> void:
	var pack := _load()
	var objective := pack.realms[0].objectives[1]
	assert_true(pack.is_on_objective(objective, objective.position + Vector2(pack.objective_radius * 0.9, 0)))
	assert_false(pack.is_on_objective(objective, objective.position + Vector2(pack.objective_radius * 1.1, 0)))


func test_point_along_rotated_length_is_on_the_rectangle() -> void:
	var pack := _load()
	var feature := _rect(pack)
	var point := feature.position + Vector2(feature.extent.x * 0.4, 0).rotated(deg_to_rad(feature.rotation))
	assert_true(pack.is_on_objective(feature, point))


func test_point_inside_unrotated_bounds_but_outside_rotated_rectangle_is_not_on_it() -> void:
	var pack := _load()
	var feature := _rect(pack)
	var point := feature.position + Vector2(feature.extent.x * 0.4, 0)
	assert_false(pack.is_on_objective(feature, point))


func test_point_outside_unrotated_bounds_but_inside_rotated_rectangle_is_on_it() -> void:
	var pack := _load()
	var feature := _rect(pack)
	var point := feature.position + Vector2(feature.extent.x * 0.4, 0).rotated(deg_to_rad(feature.rotation))
	assert_gt(absf(point.y - feature.position.y), feature.extent.y / 2, "point should be outside the unrotated rectangle")
	assert_true(pack.is_on_objective(feature, point))


func test_rectangle_corner_is_on_the_objective() -> void:
	var pack := _load()
	var feature := _rect(pack)
	assert_true(pack.is_on_objective(feature, feature.corners()[0]))


func test_point_beyond_rectangle_edge_is_not_on_the_objective() -> void:
	var pack := _load()
	var feature := _rect(pack)
	var point := feature.position + Vector2(feature.extent.x * 0.6, 0).rotated(deg_to_rad(feature.rotation))
	assert_false(pack.is_on_objective(feature, point))


# --- Relics ---

func test_relics_come_from_file_in_order() -> void:
	var expected: Array = _json().relics
	var relics := _load().relics
	assert_eq(relics.size(), expected.size())
	for i in expected.size():
		assert_eq(relics[i].name, expected[i].name)


func test_get_relic_finds_by_name() -> void:
	var relic_name: String = _json().relics[1].name
	assert_eq(_load().get_relic(relic_name).name, relic_name)


func test_get_relic_returns_null_for_unknown_name() -> void:
	assert_null(_load().get_relic("Not A Relic"))


func test_realm_starting_relics_come_from_file() -> void:
	assert_eq(Array(_load().realms[0].starting_relics), _json().realms[0].starting_relics)


func test_realm_without_starting_relics_has_none() -> void:
	assert_eq(_load().realms[1].starting_relics.size(), 0)


func test_unknown_starting_relic_is_invalid() -> void:
	_assert_invalid("bad_starting_relic", "realms[0].starting_relics[1]")


func test_twist_relic_comes_from_file() -> void:
	assert_eq(_load().realms[0].twists[0].relic, _json().realms[0].twists[0].relic)


func test_twist_relic_defaults_to_empty() -> void:
	assert_eq(_load().realms[0].twists[1].relic, "")


func test_twist_naming_unknown_relic_is_invalid() -> void:
	_assert_invalid("bad_twist_relic", "realms[0].twists[0].relic")


# --- Roads ---

func test_roads_come_from_file_in_order() -> void:
	var expected: Array = _json().realms[0].roads
	var roads := _load().realms[0].roads
	assert_eq(roads.size(), expected.size())
	for i in expected.size():
		assert_eq(roads[i], _corners(expected[i]))


func test_realm_without_roads_has_none() -> void:
	assert_eq(_load().realms[1].roads.size(), 0)


func test_road_with_too_few_corners_is_invalid() -> void:
	_assert_invalid("bad_road", "realms[0].roads[1]")


# --- Campaign ---

func test_campaign_is_null_when_absent() -> void:
	assert_not_null(_load("no_campaign"))
	assert_null(_load("no_campaign").campaign)


func test_campaign_name_and_sections_come_from_file() -> void:
	var expected: Dictionary = _json().campaign
	var campaign := _load().campaign
	assert_eq([campaign.name, campaign.sections.size(), campaign.sections[0].name],
			[expected.name, expected.sections.size(), expected.sections[0].name])


func test_campaign_battles_come_from_file_in_order() -> void:
	var expected: Array = _json().campaign.battles
	var battles := _load().campaign.battles
	assert_eq(battles.size(), expected.size())
	for i in expected.size():
		assert_eq([battles[i].name, battles[i].realm], [expected[i].name, expected[i].realm])


func test_campaign_battle_text_and_relics_come_from_file() -> void:
	var expected: Dictionary = _json().campaign.battles[0]
	var battle := _load().campaign.battles[0]
	assert_eq([battle.text, Array(battle.starting_relics)], [expected.text, expected.starting_relics])


func test_campaign_battle_territories_come_from_file() -> void:
	var expected: Dictionary = _json().campaign.battles[0].deployment_map
	var map := _load().campaign.battles[0].deployment_map
	assert_eq([map.name, map.territory_a, map.territory_b],
			[expected.name, _corners(expected.territory_a), _corners(expected.territory_b)])


func test_campaign_battle_fixed_territories_come_from_file() -> void:
	assert_eq(_load().campaign.battles[0].fixed_territories, bool(_json().campaign.battles[0].fixed_territories))


func test_campaign_battle_fixed_territories_defaults_to_false() -> void:
	assert_false(_load().campaign.battles[1].fixed_territories)


func test_campaign_battle_without_relics_has_none() -> void:
	assert_eq(_load().campaign.battles[1].starting_relics.size(), 0)


func test_campaign_battle_naming_unknown_realm_is_invalid() -> void:
	_assert_invalid("bad_campaign_realm", "campaign.battles[1].realm")


func test_campaign_battle_naming_unknown_relic_is_invalid() -> void:
	_assert_invalid("bad_battle_relic", "campaign.battles[0].starting_relics[1]")


func test_campaign_battle_without_deployment_map_is_invalid() -> void:
	_assert_invalid("no_battle_map", "campaign.battles[1].deployment_map")


func test_campaign_battle_territory_with_too_few_corners_is_invalid() -> void:
	_assert_invalid("short_battle_territory", "campaign.battles[0].deployment_map.territory_a")
