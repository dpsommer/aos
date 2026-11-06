extends GutTest
## A unit's damage sequence, healing and the flags that last a turn.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()


## A game with [param unit] against a far-off enemy, to the east of it.
func _game_with(unit: BattleUnit, enemy_at := Vector2(25, 5)) -> GameController:
	var enemy := RulesKit.unit("Enemy", 1, enemy_at)
	var game := RulesKit.game([unit] as Array[BattleUnit], [enemy] as Array[BattleUnit])
	_games.append(game)
	return game


func _damage(game: GameController, unit: BattleUnit, points: int) -> String:
	return game.command(unit, Commands.DealDamage.new(points, game.battle.opponent))


func _unit(count := 5, health := 3, ward := 0) -> BattleUnit:
	return RulesKit.unit("Unit", count, Vector2(5, 5), PackedStringArray(), health, 4, [] as Array[Weapon], ward)


# Damage allocation

func test_damage_below_health_slays_no_model() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 2)
	assert_eq(unit.model_count(), 5)
	assert_eq(game.controller_of(unit).damage_points, 2)


func test_damage_up_to_health_slays_a_model_and_resets_the_points() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 3)
	assert_eq(unit.model_count(), 4)
	assert_eq(game.controller_of(unit).damage_points, 0)


func test_damage_over_health_carries_into_the_next_model() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 7)
	assert_eq(unit.model_count(), 3)
	assert_eq(game.controller_of(unit).damage_points, 1)


func test_one_count_is_kept_for_the_unit_across_damage() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 2)
	_damage(game, unit, 2)
	assert_eq(unit.model_count(), 4, "2 and 2 slay one model of health 3")
	assert_eq(game.controller_of(unit).damage_points, 1)


func test_no_damage_does_nothing() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 0)
	assert_eq(game.controller_of(unit).damage_points, 0)
	assert_true(game.events.log_entries.filter(func(e: BattleEvent) -> bool: return e.kind == BattleEvent.UNIT_DAMAGED).is_empty())


func test_bases_and_positions_stay_in_step_as_models_are_slain() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 9)
	assert_eq(unit.bases.size(), unit.positions.size())
	assert_eq(unit.slain_bases.size(), 3)
	assert_eq(unit.bases.size() + unit.slain_bases.size(), 5)


func test_the_model_furthest_from_the_enemy_is_slain_first() -> void:
	var unit := _unit()
	var game := _game_with(unit, Vector2(25, 5))
	var nearest_enemy := unit.positions[4]
	_damage(game, unit, 3)
	assert_true(nearest_enemy in unit.positions, "The model nearest the enemy stays")
	assert_false(Vector2(5, 5) in unit.positions, "The one furthest west went")


func test_models_that_break_coherency_are_slain_with_it() -> void:
	# Two pairs of models far from each other: no single model leaving makes the unit coherent.
	var unit := RulesKit.unit("Unit", 4, Vector2(5, 5), PackedStringArray(), 1, 4)
	unit.positions = PackedVector2Array([Vector2(5, 5), Vector2(6.5, 5), Vector2(15, 5), Vector2(25, 5)])
	var game := _game_with(unit, Vector2(40, 5))
	_damage(game, unit, 1)
	assert_lt(unit.model_count(), 3, "More than the one model went")
	assert_true(Coherency.is_coherent(unit.positions, unit.bases, unit.facing))
	assert_eq(unit.bases.size(), unit.positions.size())


func test_a_coherent_unit_loses_only_the_model_slain() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 3)
	assert_eq(unit.slain_bases.size(), 1)


func test_slaying_the_last_model_destroys_the_unit() -> void:
	var unit := _unit(2, 1)
	var game := _game_with(unit)
	_damage(game, unit, 2)
	assert_true(unit.destroyed)
	assert_eq(unit.model_count(), 0)


func test_damage_beyond_the_last_model_has_no_effect() -> void:
	var unit := _unit(1, 1)
	var game := _game_with(unit)
	_damage(game, unit, 50)
	assert_true(unit.destroyed)
	assert_eq(unit.slain_bases.size(), 1)
	assert_eq(game.controller_of(unit).damage_points, 0)


func test_a_destroyed_unit_takes_no_more_damage() -> void:
	var unit := _unit(1, 1)
	var game := _game_with(unit)
	_damage(game, unit, 1)
	var before := game.events.log_entries.size()
	_damage(game, unit, 1)
	assert_eq(game.events.log_entries.size(), before)


func test_destroying_a_unit_publishes_one_event_with_who_destroyed_it() -> void:
	var unit := _unit(2, 1)
	var game := _game_with(unit)
	var heard: Array[BattleEvent] = []
	game.events.subscribe(BattleEvent.UNIT_DESTROYED, func(event: BattleEvent) -> void: heard.append(event))
	_damage(game, unit, 5)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0].data.unit, unit)
	assert_eq(heard[0].data.source_army, game.battle.opponent)


func test_a_unit_that_is_not_destroyed_publishes_no_destroyed_event() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	var heard: Array[BattleEvent] = []
	game.events.subscribe(BattleEvent.UNIT_DESTROYED, func(event: BattleEvent) -> void: heard.append(event))
	_damage(game, unit, 3)
	assert_true(heard.is_empty())


func test_the_destroy_command_removes_every_model() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	game.command(unit, Commands.Destroy.new(game.battle.opponent))
	assert_true(unit.destroyed)
	assert_eq(unit.bases.size(), unit.positions.size())


func test_destroying_a_unit_counts_for_the_enemy_this_turn() -> void:
	var unit := _unit(1, 1)
	var game := _game_with(unit)
	_damage(game, unit, 1)
	assert_eq(game.state.turn_stat(game.battle.opponent, &"enemy_destroyed"), 1)
	assert_eq(game.state.turn_stat(game.battle.player, &"own_destroyed"), 1)


# Ward rolls

func test_a_ward_that_always_succeeds_stops_all_damage() -> void:
	var unit := _unit(5, 3, 1)
	var game := _game_with(unit)
	_damage(game, unit, 30)
	assert_eq(unit.model_count(), 5)
	assert_eq(game.controller_of(unit).damage_points, 0)


func test_a_ward_that_cannot_succeed_stops_nothing() -> void:
	var unit := _unit(5, 3, 7)
	var game := _game_with(unit)
	_damage(game, unit, 3)
	assert_eq(unit.model_count(), 4)


func test_forbidding_ward_rolls_lets_all_the_damage_through() -> void:
	var unit := _unit(5, 3, 1)
	var game := _game_with(unit)
	RulesKit.give(game, unit, RulesKit.modifier(&"ward_rolls", 0, game.battle.opponent, Modifier.Op.FORBID))
	_damage(game, unit, 3)
	assert_eq(unit.model_count(), 4)


func test_the_damaged_event_says_how_many_were_warded() -> void:
	var unit := _unit(5, 3, 1)
	var game := _game_with(unit)
	var heard: Array[BattleEvent] = []
	game.events.subscribe(BattleEvent.UNIT_DAMAGED, func(event: BattleEvent) -> void: heard.append(event))
	_damage(game, unit, 4)
	assert_eq(heard[0].data.warded, 4)
	assert_eq(heard[0].data.points, 0)


func test_a_unit_without_a_ward_rolls_none() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	var heard: Array[BattleEvent] = []
	game.events.subscribe(BattleEvent.UNIT_DAMAGED, func(event: BattleEvent) -> void: heard.append(event))
	_damage(game, unit, 2)
	assert_eq(heard[0].data.warded, 0)


# Events wait for the command

func test_listeners_hear_slain_models_only_once_the_command_has_finished() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	var counts: Array[int] = []
	game.events.subscribe(BattleEvent.MODEL_SLAIN, func(_event: BattleEvent) -> void: counts.append(unit.model_count()))
	_damage(game, unit, 9)
	assert_eq(counts.size(), 3)
	for seen in counts:
		assert_eq(seen, 2, "They all see the unit as the command left it")


func test_a_command_to_a_unit_the_game_does_not_know_is_refused() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	var stranger := RulesKit.unit("Stranger", 1, Vector2(1, 1))
	assert_ne(game.command(stranger, Commands.Heal.new(1)), "")


func test_a_command_the_unit_does_not_understand_is_refused() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	assert_ne(game.command(unit, RefCounted.new()), "")


# Healing

func test_healing_takes_points_off_the_damage() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 2)
	game.command(unit, Commands.Heal.new(1))
	assert_eq(game.controller_of(unit).damage_points, 1)


func test_healing_cannot_go_below_no_damage() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 1)
	game.command(unit, Commands.Heal.new(5))
	assert_eq(game.controller_of(unit).damage_points, 0)


func test_healing_does_not_bring_back_slain_models() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 3)
	game.command(unit, Commands.Heal.new(5))
	assert_eq(unit.model_count(), 4)


func test_healing_nothing_publishes_nothing() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	game.command(unit, Commands.Heal.new(2))
	assert_true(game.events.log_entries.filter(func(e: BattleEvent) -> bool: return e.kind == BattleEvent.UNIT_HEALED).is_empty())


# Returning models

func test_returned_models_come_back_to_the_unit() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 6)
	game.command(unit, Commands.ReturnModels.new(1))
	assert_eq(unit.model_count(), 4)
	assert_eq(unit.bases.size(), unit.positions.size())


func test_no_more_models_return_than_were_slain() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 3)
	game.command(unit, Commands.ReturnModels.new(4))
	assert_eq(unit.model_count(), 5)
	assert_true(unit.slain_bases.is_empty())


func test_a_returned_model_stands_in_coherency() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	_damage(game, unit, 6)
	game.command(unit, Commands.ReturnModels.new(2))
	assert_true(Coherency.is_coherent(unit.positions, unit.bases, unit.facing))


# Turn flags

func test_a_new_turn_clears_what_the_unit_did_last_turn() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	var controller := game.controller_of(unit)
	controller.charged = true
	controller.ran = true
	controller.retreated = true
	controller.moved = true
	game.events.publish(BattleEvent.TURN_STARTED, {"army": game.battle.player})
	assert_false(controller.charged)
	assert_false(controller.ran)
	assert_false(controller.retreated)
	assert_false(controller.moved)


func test_moving_sets_the_flag_for_the_kind_of_move() -> void:
	var cases := {MoveSpec.Kind.RUN: "ran", MoveSpec.Kind.RETREAT: "retreated", MoveSpec.Kind.CHARGE: "charged"}
	for kind: MoveSpec.Kind in cases:
		var unit := _unit()
		var game := _game_with(unit)
		var spec := MoveSpec.create(unit, kind, 6.0)
		game.command(unit, Commands.MoveModels.new(unit.positions, spec))
		var controller := game.controller_of(unit)
		assert_true(controller.get(cases[kind]), "%s sets %s" % [kind, cases[kind]])
		assert_true(controller.moved)


func test_a_normal_move_only_sets_moved() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	game.command(unit, Commands.MoveModels.new(unit.positions, MoveSpec.create(unit, MoveSpec.Kind.NORMAL, 6.0)))
	var controller := game.controller_of(unit)
	assert_true(controller.moved)
	assert_false(controller.ran or controller.charged or controller.retreated)


func test_a_counter_is_added_to() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	game.command(unit, Commands.ChangeCounter.new(&"momentum", 2))
	game.command(unit, Commands.ChangeCounter.new(&"momentum", -1))
	assert_eq(game.controller_of(unit).counter("momentum"), 1)


func test_removing_a_unit_takes_it_off_the_battlefield() -> void:
	var unit := _unit()
	var game := _game_with(unit)
	game.command(unit, Commands.Remove.new("in the clouds"))
	assert_false(unit.is_on_battlefield())
	assert_eq(unit.reserve, "in the clouds")
