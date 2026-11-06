extends GutTest
## Whether a move is allowed, and planning one.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()


func _game(mine: Array[BattleUnit], theirs: Array[BattleUnit]) -> GameController:
	var game := RulesKit.game(mine, theirs)
	_games.append(game)
	return game


## A game with one unit of [param count] models at (5, 5), and [param enemies].
func _with_enemies(enemies: Array[BattleUnit], count := 1, keywords := PackedStringArray()) -> GameController:
	var mover := RulesKit.unit("Mover", count, Vector2(5, 5), keywords)
	return _game([mover] as Array[BattleUnit], enemies)


func _enemy(at: Vector2, count := 1) -> BattleUnit:
	return RulesKit.unit("Enemy", count, at)


func _mover(game: GameController) -> BattleUnit:
	return game.battle.player.units[0]


func _spec(game: GameController, kind: MoveSpec.Kind, distance := 6.0) -> MoveSpec:
	return MoveSpec.create(_mover(game), kind, distance)


## The unit's positions shifted by [param by].
func _shifted(game: GameController, by: Vector2) -> PackedVector2Array:
	return MovementRules.shifted(_mover(game), by)


func _bad(game: GameController, spec: MoveSpec, positions: PackedVector2Array, kind: String) -> PackedInt32Array:
	return MovementRules.invalid_models(game, spec, positions)[kind]


# Distance and the battlefield

func test_a_move_within_the_distance_is_legal() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit])
	assert_true(MovementRules.is_legal(game, _spec(game, MoveSpec.Kind.NORMAL), _shifted(game, Vector2(4, 0))))


func test_a_move_that_stays_put_is_legal() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit])
	assert_true(MovementRules.is_legal(game, _spec(game, MoveSpec.Kind.NORMAL), _mover(game).positions))


func test_a_model_that_goes_too_far_is_named() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.NORMAL)
	assert_eq(_bad(game, spec, _shifted(game, Vector2(8, 0)), "too_far"), PackedInt32Array([0]))
	assert_false(MovementRules.problems(game, spec, _shifted(game, Vector2(8, 0))).is_empty())


func test_only_the_models_that_go_too_far_are_named() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit], 2)
	var moved := _shifted(game, Vector2(2, 0))
	moved[1] += Vector2(0, 7)
	assert_eq(_bad(game, _spec(game, MoveSpec.Kind.NORMAL), moved, "too_far"), PackedInt32Array([1]))


func test_a_model_cannot_leave_the_battlefield() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.NORMAL, 20.0)
	assert_eq(_bad(game, spec, PackedVector2Array([Vector2(-1, 5)]), "off_board"), PackedInt32Array([0]))


func test_a_model_on_the_edge_is_on_the_battlefield() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.NORMAL, 20.0)
	assert_true(_bad(game, spec, PackedVector2Array([Vector2(1, 5)]), "off_board").is_empty())


# Other models

func test_a_model_cannot_end_on_another_model() -> void:
	var game := _with_enemies([_enemy(Vector2(8, 12))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.FREE)
	assert_eq(_bad(game, spec, PackedVector2Array([Vector2(8, 12.3)]), "blocked"), PackedInt32Array([0]))


func test_a_model_cannot_move_through_another_model() -> void:
	var game := _with_enemies([_enemy(Vector2(8, 5))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.FREE)
	assert_eq(_bad(game, spec, PackedVector2Array([Vector2(11, 5)]), "blocked"), PackedInt32Array([0]))


func test_a_model_can_move_past_another_model() -> void:
	var game := _with_enemies([_enemy(Vector2(8, 9))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.FREE)
	assert_true(_bad(game, spec, PackedVector2Array([Vector2(11, 5)]), "blocked").is_empty())


func test_a_flyer_can_move_through_another_model() -> void:
	var game := _with_enemies([_enemy(Vector2(8, 5))] as Array[BattleUnit], 1, PackedStringArray(["FLY"]))
	var spec := _spec(game, MoveSpec.Kind.FREE)
	assert_true(_bad(game, spec, PackedVector2Array([Vector2(11, 5)]), "blocked").is_empty())


func test_a_flyer_still_cannot_end_on_another_model() -> void:
	var game := _with_enemies([_enemy(Vector2(8, 12))] as Array[BattleUnit], 1, PackedStringArray(["FLY"]))
	var spec := _spec(game, MoveSpec.Kind.FREE)
	assert_eq(_bad(game, spec, PackedVector2Array([Vector2(8, 12.3)]), "blocked"), PackedInt32Array([0]))


func test_a_friendly_model_blocks_too() -> void:
	var mover := RulesKit.unit("Mover", 1, Vector2(5, 5))
	var friend := RulesKit.unit("Friend", 1, Vector2(8, 5))
	var game := _game([mover, friend] as Array[BattleUnit], [_enemy(Vector2(25, 15))] as Array[BattleUnit])
	assert_eq(_bad(game, MoveSpec.create(mover, MoveSpec.Kind.FREE, 6.0), PackedVector2Array([Vector2(11, 5)]), "blocked"), PackedInt32Array([0]))


# Combat range

func test_a_normal_move_cannot_end_in_combat_range() -> void:
	var game := _with_enemies([_enemy(Vector2(12, 5))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.NORMAL)
	assert_eq(_bad(game, spec, _shifted(game, Vector2(4, 0)), "into_combat"), PackedInt32Array([0]))


func test_a_normal_move_cannot_pass_through_combat_range() -> void:
	# The enemy is 2" off the line, and the model ends well clear of it.
	var game := _with_enemies([_enemy(Vector2(7, 7))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.NORMAL)
	assert_eq(_bad(game, spec, _shifted(game, Vector2(6, 0)), "into_combat"), PackedInt32Array([0]))


func test_a_run_is_kept_out_of_combat_like_a_normal_move() -> void:
	var game := _with_enemies([_enemy(Vector2(7, 7))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.RUN)
	assert_eq(_bad(game, spec, _shifted(game, Vector2(6, 0)), "into_combat"), PackedInt32Array([0]))


func test_a_normal_move_clear_of_combat_range_is_legal() -> void:
	var game := _with_enemies([_enemy(Vector2(10, 14))] as Array[BattleUnit])
	assert_true(MovementRules.is_legal(game, _spec(game, MoveSpec.Kind.NORMAL), _shifted(game, Vector2(6, 0))))


func test_a_flyer_may_pass_over_combat_range_if_it_ends_clear() -> void:
	var game := _with_enemies([_enemy(Vector2(7, 7))] as Array[BattleUnit], 1, PackedStringArray(["FLY"]))
	assert_true(_bad(game, _spec(game, MoveSpec.Kind.NORMAL), _shifted(game, Vector2(6, 0)), "into_combat").is_empty())


func test_a_flyer_cannot_end_in_combat_range() -> void:
	var game := _with_enemies([_enemy(Vector2(12, 5))] as Array[BattleUnit], 1, PackedStringArray(["FLY"]))
	assert_eq(_bad(game, _spec(game, MoveSpec.Kind.NORMAL), _shifted(game, Vector2(4, 0)), "into_combat"), PackedInt32Array([0]))


func test_a_retreat_may_pass_through_combat_range() -> void:
	var game := _with_enemies([_enemy(Vector2(7, 7))] as Array[BattleUnit])
	assert_true(_bad(game, _spec(game, MoveSpec.Kind.RETREAT), _shifted(game, Vector2(6, 0)), "into_combat").is_empty())


func test_a_retreat_cannot_end_in_combat_range() -> void:
	var game := _with_enemies([_enemy(Vector2(7, 7))] as Array[BattleUnit])
	assert_eq(_bad(game, _spec(game, MoveSpec.Kind.RETREAT), _shifted(game, Vector2(5, 0)), "into_combat"), PackedInt32Array([0]))


# Charges

func test_a_charge_must_end_within_half_an_inch_of_an_enemy() -> void:
	var game := _with_enemies([_enemy(Vector2(12, 5))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.CHARGE)
	assert_true(MovementRules.is_legal(game, spec, _shifted(game, Vector2(5.4, 0))))
	assert_false(MovementRules.is_legal(game, spec, _shifted(game, Vector2(3, 0))), "Still 2.7\" away")


func test_a_charge_that_stops_short_says_why() -> void:
	var game := _with_enemies([_enemy(Vector2(12, 5))] as Array[BattleUnit])
	var problems := MovementRules.problems(game, _spec(game, MoveSpec.Kind.CHARGE), _shifted(game, Vector2(3, 0)))
	assert_eq(problems.size(), 1)


func test_a_charge_may_pass_through_another_units_combat_range() -> void:
	var game := _with_enemies([_enemy(Vector2(10, 7)), _enemy(Vector2(18, 5))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.CHARGE, 12.0)
	assert_true(_bad(game, spec, _shifted(game, Vector2(11.4, 0)), "into_combat").is_empty())


# Pile in

## A mover in combat with an enemy at (7.5, 5), and a second enemy [param other_at].
func _piling(other_at := Vector2(40, 40)) -> GameController:
	return _with_enemies([_enemy(Vector2(7.5, 5)), _enemy(other_at)] as Array[BattleUnit])


func _pile_in(game: GameController) -> MoveSpec:
	var spec := _spec(game, MoveSpec.Kind.PILE_IN, 3.0)
	spec.pile_in_target = game.battle.opponent.units[0]
	return spec


func test_a_pile_in_that_does_not_go_further_from_the_target_is_legal() -> void:
	var game := _piling()
	assert_true(MovementRules.is_legal(game, _pile_in(game), PackedVector2Array([Vector2(5.5, 5)])))


func test_a_pile_in_cannot_go_further_from_the_target() -> void:
	var game := _piling()
	var problems := MovementRules.problems(game, _pile_in(game), PackedVector2Array([Vector2(4, 5)]))
	assert_false(problems.is_empty())


func test_a_pile_in_cannot_go_further_than_its_distance() -> void:
	var game := _piling()
	var spec := _pile_in(game)
	assert_eq(_bad(game, spec, PackedVector2Array([Vector2(5, 8.5)]), "too_far"), PackedInt32Array([0]))


func test_a_pile_in_must_stay_in_combat_with_who_it_was_in_combat_with() -> void:
	# Combat with the target to the south and another enemy to the north: moving south leaves the second.
	var mover := RulesKit.unit("Mover", 1, Vector2(10, 10))
	var south := _enemy(Vector2(10, 12))
	var north := _enemy(Vector2(10, 6))
	var game := _game([mover] as Array[BattleUnit], [south, north] as Array[BattleUnit])
	var spec := MoveSpec.create(mover, MoveSpec.Kind.PILE_IN, 3.0)
	spec.pile_in_target = south
	assert_false(MovementRules.is_legal(game, spec, PackedVector2Array([Vector2(10, 10.5)])))
	assert_true(MovementRules.is_legal(game, spec, PackedVector2Array([Vector2(10, 10.2)])), "Staying within 3\" of both is fine")


# Coherency

func test_a_move_that_breaks_coherency_is_named() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit], 3)
	var moved := _shifted(game, Vector2(2, 0))
	moved[2] += Vector2(0, 5)
	assert_false(_bad(game, _spec(game, MoveSpec.Kind.NORMAL), moved, "incoherent").is_empty())
	assert_false(MovementRules.is_legal(game, _spec(game, MoveSpec.Kind.NORMAL), moved))


func test_a_move_that_keeps_coherency_has_none_named() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit], 3)
	assert_true(_bad(game, _spec(game, MoveSpec.Kind.NORMAL), _shifted(game, Vector2(2, 0)), "incoherent").is_empty())


# Must end in combat

func test_a_move_that_has_to_end_in_combat_does() -> void:
	var game := _with_enemies([_enemy(Vector2(12, 5))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.FREE)
	spec.must_end_in_combat = true
	assert_false(MovementRules.is_legal(game, spec, _shifted(game, Vector2(-3, 0))))
	assert_true(MovementRules.is_legal(game, spec, _shifted(game, Vector2(3, 0))))


func test_a_free_move_that_avoids_new_combat_can_still_end_beside_who_it_ignores() -> void:
	var game := _with_enemies([_enemy(Vector2(12, 5)), _enemy(Vector2(25, 15))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.FREE)
	spec.avoid_new_combat = true
	assert_false(MovementRules.is_legal(game, spec, _shifted(game, Vector2(3, 0))))
	spec.ignores_combat_of = [game.battle.opponent.units[0]] as Array[BattleUnit]
	assert_true(MovementRules.is_legal(game, spec, _shifted(game, Vector2(3, 0))))


# Planning

func test_plan_towards_gives_a_legal_move_towards_the_goal() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 18))] as Array[BattleUnit], 3)
	var spec := _spec(game, MoveSpec.Kind.NORMAL)
	var plan := MovementRules.plan_towards(game, spec, Vector2(25, 5))
	assert_eq(plan.size(), 3)
	assert_true(MovementRules.is_legal(game, spec, plan))
	assert_gt(plan[0].x, _mover(game).positions[0].x)


func test_plan_towards_does_not_go_further_than_the_move() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 18))] as Array[BattleUnit], 3)
	var spec := _spec(game, MoveSpec.Kind.NORMAL)
	var plan := MovementRules.plan_towards(game, spec, Vector2(25, 5))
	for i in plan.size():
		assert_lte(plan[i].distance_to(_mover(game).positions[i]), spec.max_distance + MovementRules.EPSILON)


func test_plan_towards_stops_at_the_goal_if_it_is_near() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 18))] as Array[BattleUnit])
	var plan := MovementRules.plan_towards(game, _spec(game, MoveSpec.Kind.NORMAL), Vector2(7, 5))
	assert_almost_eq(plan[0].x, 7.0, 0.1)


func test_plan_towards_goes_round_an_obstacle() -> void:
	var game := _with_enemies([_enemy(Vector2(8, 5), 3)] as Array[BattleUnit], 3)
	var spec := _spec(game, MoveSpec.Kind.NORMAL)
	var plan := MovementRules.plan_towards(game, spec, Vector2(25, 5))
	assert_true(plan.is_empty() or MovementRules.is_legal(game, spec, plan), "Whatever it returns is legal")


func test_plan_towards_with_nowhere_to_go_is_empty() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 18))] as Array[BattleUnit])
	assert_true(MovementRules.plan_towards(game, _spec(game, MoveSpec.Kind.NORMAL), _mover(game).positions[0]).is_empty())


func test_plan_towards_can_stop_short_of_the_goal() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 18))] as Array[BattleUnit])
	var plan := MovementRules.plan_towards(game, _spec(game, MoveSpec.Kind.NORMAL, 20.0), Vector2(15, 5), 4.0)
	assert_almost_eq(plan[0].x, 11.0, 0.1)


func test_plan_charge_ends_within_reach_of_the_enemy() -> void:
	var game := _with_enemies([_enemy(Vector2(12, 5))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.CHARGE, 9.0)
	var plan := MovementRules.plan_charge(game, spec, game.battle.opponent.units[0])
	assert_false(plan.is_empty())
	assert_true(MovementRules.is_legal(game, spec, plan))


func test_plan_charge_is_empty_if_the_enemy_is_too_far() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 5))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.CHARGE, 5.0)
	assert_true(MovementRules.plan_charge(game, spec, game.battle.opponent.units[0]).is_empty())


func test_plan_pile_in_moves_towards_the_target_and_is_legal() -> void:
	var game := _with_enemies([_enemy(Vector2(8.5, 5))] as Array[BattleUnit])
	var spec := _spec(game, MoveSpec.Kind.PILE_IN, 3.0)
	spec.pile_in_target = game.battle.opponent.units[0]
	var plan := MovementRules.plan_pile_in(game, spec)
	assert_false(plan.is_empty())
	assert_true(MovementRules.is_legal(game, spec, plan))
	assert_gt(plan[0].x, 5.0)


func test_spot_beside_is_free_and_coherent() -> void:
	var game := _with_enemies([_enemy(Vector2(25, 15))] as Array[BattleUnit], 3)
	var unit := _mover(game)
	var spot: Variant = MovementRules.spot_beside(game, unit, unit.bases[0])
	assert_not_null(spot)
	var positions := unit.positions.duplicate()
	positions.append(spot)
	var bases := unit.bases.duplicate()
	bases.append(unit.bases[0])
	assert_true(Coherency.is_coherent(positions, bases, unit.facing))
