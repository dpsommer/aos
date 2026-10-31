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
