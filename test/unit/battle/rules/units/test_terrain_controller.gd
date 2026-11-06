extends GutTest
## Terrain's own rules: Cover and Obscuring.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")

var _game: GameController


func after_each() -> void:
	_game.dispose()


## A game with a 4" terrain feature of [param kind] between the player's unit in the west and the
## opponent's unit in the east.
func _start(kind: BattleTerrain.Kind, target_keywords := PackedStringArray(), size := "") -> TerrainController:
	var gun := RulesKit.weapon("1", 2, 2, 0, "1", PackedStringArray(), 30)
	var shooter := RulesKit.unit("Shooter", 1, Vector2(2, 5), PackedStringArray(), 1, 0, [gun] as Array[Weapon])
	var target := RulesKit.unit("Target", 1, Vector2(18, 5), target_keywords)
	var wall := BattleKit.terrain(kind, 4.0, Vector2(10, 5))
	wall.size = size
	_game = RulesKit.game([shooter] as Array[BattleUnit], [target] as Array[BattleUnit], [wall] as Array[BattleTerrain])
	return _game.terrain_controllers[wall]


func _shooter() -> BattleUnit:
	return _game.battle.player.units[0]


func _target() -> BattleUnit:
	return _game.battle.opponent.units[0]


func _hit_modifier() -> int:
	return _game.stats.roll_modifier(&"hit", RuleContext.of_attack(_game, _shooter(), _target(), _shooter().warscroll.ranged_weapons[0]))


func test_a_unit_behind_terrain_has_cover() -> void:
	var terrain := _start(BattleTerrain.Kind.AREA_OR_OBSTACLE)
	assert_true(terrain.covers(_shooter(), _target()))


func test_cover_takes_one_off_hit_rolls_against_the_unit() -> void:
	_start(BattleTerrain.Kind.AREA_OR_OBSTACLE)
	assert_eq(_hit_modifier(), -1)


func test_a_unit_not_behind_terrain_has_no_cover() -> void:
	var terrain := _start(BattleTerrain.Kind.AREA_OR_OBSTACLE)
	_target().positions = PackedVector2Array([Vector2(18, 15)])
	assert_false(terrain.covers(_shooter(), _target()))
	assert_eq(_hit_modifier(), 0)


func test_a_unit_wholly_on_terrain_has_cover() -> void:
	var terrain := _start(BattleTerrain.Kind.AREA_OR_OBSTACLE)
	_target().positions = PackedVector2Array([Vector2(10, 5)])
	_shooter().positions = PackedVector2Array([Vector2(10, 15)])
	assert_true(terrain.covers(_shooter(), _target()))


func test_a_flyer_has_no_cover() -> void:
	var terrain := _start(BattleTerrain.Kind.AREA_OR_OBSTACLE, PackedStringArray(["FLY"]))
	assert_false(terrain.covers(_shooter(), _target()))


func test_a_unit_that_charged_this_turn_has_no_cover() -> void:
	var terrain := _start(BattleTerrain.Kind.AREA_OR_OBSTACLE)
	_game.controller_of(_target()).charged = true
	assert_false(terrain.covers(_shooter(), _target()))


func test_terrain_not_yet_placed_gives_no_cover() -> void:
	var terrain := _start(BattleTerrain.Kind.AREA_OR_OBSTACLE)
	terrain.feature.placed = false
	assert_false(terrain.covers(_shooter(), _target()))


func test_only_obscuring_terrain_is_obscuring() -> void:
	assert_true(_start(BattleTerrain.Kind.OBSCURING).is_obscuring())
	_game.dispose()
	assert_false(_start(BattleTerrain.Kind.AREA_OR_OBSTACLE).is_obscuring())


func test_a_large_spearhead_feature_is_obscuring_and_a_small_one_is_not() -> void:
	assert_true(_start(BattleTerrain.Kind.SPEARHEAD, PackedStringArray(), "large").is_obscuring())
	_game.dispose()
	assert_false(_start(BattleTerrain.Kind.SPEARHEAD, PackedStringArray(), "small").is_obscuring())


func test_obscuring_terrain_blocks_shooting_at_a_unit_behind_it() -> void:
	var terrain := _start(BattleTerrain.Kind.OBSCURING)
	assert_true(terrain.blocks_shooting(_shooter(), _target()))


func test_obscuring_terrain_does_not_block_a_flyer() -> void:
	var terrain := _start(BattleTerrain.Kind.OBSCURING, PackedStringArray(["FLY"]))
	assert_false(terrain.blocks_shooting(_shooter(), _target()))


func test_obscuring_terrain_does_not_block_a_shooter_in_combat_with_the_target() -> void:
	var terrain := _start(BattleTerrain.Kind.OBSCURING)
	_shooter().positions = PackedVector2Array([Vector2(15, 5)])
	_target().positions = PackedVector2Array([Vector2(16.5, 5)])
	assert_false(terrain.blocks_shooting(_shooter(), _target()))


func test_other_terrain_does_not_block_shooting() -> void:
	var terrain := _start(BattleTerrain.Kind.AREA_OR_OBSTACLE)
	assert_false(terrain.blocks_shooting(_shooter(), _target()))
