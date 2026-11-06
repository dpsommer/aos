extends GutTest
## The rules that are written rather than described.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _user: BattleUnit
var _friend: BattleUnit
var _enemy: BattleUnit


func before_each() -> void:
	_user = RulesKit.unit("User", 1, Vector2(10, 10), PackedStringArray(), 5)
	_friend = RulesKit.unit("Friend", 1, Vector2(2, 2))
	_enemy = RulesKit.unit("Enemy", 1, Vector2(25, 18), PackedStringArray(), 1)
	_game = RulesKit.game([_user, _friend] as Array[BattleUnit], [_enemy] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


func _hook(hook_name: String, action: Action, extra := {}) -> void:
	var descriptor := {"op": "hook", "name": hook_name}
	descriptor.merge(extra)
	RulesKit.effect(descriptor).resolve(action, _game)


func _reaction(parent: Action) -> Action:
	var action := RulesKit.action(_game, _user, [] as Array[BattleUnit], "Reaction")
	action.parent = parent
	return action


func test_a_hook_that_changes_the_ability_it_reacts_to_needs_that_ability() -> void:
	var action := RulesKit.action(_game, _user)
	_hook("at_the_double", action)
	_hook("no_retreat_damage", action)
	assert_true(action.flags.is_empty())


func test_at_the_double_adds_six_inches_and_skips_the_run_roll() -> void:
	var parent := RulesKit.action(_game, _user)
	_hook("at_the_double", _reaction(parent))
	assert_true(parent.flags.has("no_run_roll"))
	assert_eq(parent.flags["added_move"], 6)


func test_no_retreat_damage_is_flagged_on_the_retreat() -> void:
	var parent := RulesKit.action(_game, _user)
	_hook("no_retreat_damage", _reaction(parent))
	assert_true(parent.flags.has("no_retreat_damage"))


func test_all_friendly_targets_picks_every_friendly_unit_not_set_up_this_turn() -> void:
	var parent := RulesKit.action(_game, _user)
	_game.command(_friend, Commands.SetUp.new(_friend.positions))
	_hook("all_friendly_targets", _reaction(parent))
	assert_eq(parent.targets, [_user] as Array[BattleUnit])


func test_re_rolling_the_parents_roll_makes_a_new_roll() -> void:
	var parent := RulesKit.action(_game, _user)
	_game.make_roll(parent, "charge", DiceExpr.parse("2D6"))
	var before := _game.events.log_entries.size()
	_hook("reroll_parent", _reaction(parent), {"roll": "charge", "dice": "2D6"})
	assert_eq(_game.events.log_entries.size(), before + 1)
	assert_between(parent.rolls["charge"], 2, 12)


func test_return_on_rolls_returns_models_for_each_roll_that_succeeds() -> void:
	var unit := RulesKit.unit("Unit", 4, Vector2(10, 14), PackedStringArray(), 1)
	_game.dispose()
	_game = RulesKit.game([unit] as Array[BattleUnit], [_enemy] as Array[BattleUnit])
	_game.command(unit, Commands.DealDamage.new(3))
	assert_eq(unit.model_count(), 1)
	_hook("return_on_rolls", RulesKit.action(_game, unit), {"on": 1})
	assert_eq(unit.model_count(), 4)


func test_return_on_rolls_with_a_roll_that_cannot_succeed_returns_none() -> void:
	var unit := RulesKit.unit("Unit", 4, Vector2(10, 14), PackedStringArray(), 1)
	_game.dispose()
	_game = RulesKit.game([unit] as Array[BattleUnit], [_enemy] as Array[BattleUnit])
	_game.command(unit, Commands.DealDamage.new(3))
	_hook("return_on_rolls", RulesKit.action(_game, unit), {"on": 7})
	assert_eq(unit.model_count(), 1)


func test_sacred_rites_banks_the_chanting_roll_as_ritual_points() -> void:
	var action := RulesKit.action(_game, _user)
	action.rolls["chanting"] = 5
	_hook("sacred_rites", action)
	assert_eq(_game.controller_of(_user).counter(EffectHooks.RITUAL_POINTS), 5)


func test_beat_health_does_a_mortal_wound_for_each_dice_over_the_targets_health() -> void:
	var action := RulesKit.action(_game, _user, [_enemy] as Array[BattleUnit])
	_hook("beat_health", action, {"dice": 600})
	assert_gt(action.damage_pool[_enemy], 400, "Five in six beat a Health of 1")
	assert_lt(action.damage_pool[_enemy], 600)


func test_beat_health_does_nothing_against_a_health_no_dice_can_beat() -> void:
	var tough := RulesKit.unit("Tough", 1, Vector2(25, 5), PackedStringArray(), 6)
	_game.dispose()
	_game = RulesKit.game([_user] as Array[BattleUnit], [tough] as Array[BattleUnit])
	var action := RulesKit.action(_game, _user, [tough] as Array[BattleUnit])
	_hook("beat_health", action, {"dice": 50})
	assert_true(action.damage_pool.is_empty())


func test_rally_heals_a_damaged_unit() -> void:
	_game.dispose()
	_game = RulesKit.game([_user] as Array[BattleUnit], [_enemy] as Array[BattleUnit], [] as Array[BattleTerrain], RulesKit.seed_with_rolls_at_least(6, 4))
	_game.command(_user, Commands.DealDamage.new(3))
	_hook("rally", RulesKit.action(_game, _user))
	assert_eq(_game.controller_of(_user).damage_points, 0)


func test_rally_returns_a_slain_model_for_its_health_in_points() -> void:
	var unit := RulesKit.unit("Unit", 4, Vector2(10, 14), PackedStringArray(), 2)
	_game.dispose()
	_game = RulesKit.game([unit] as Array[BattleUnit], [_enemy] as Array[BattleUnit], [] as Array[BattleTerrain], RulesKit.seed_with_rolls_at_least(6, 4))
	_game.command(unit, Commands.DealDamage.new(4))
	assert_eq(unit.model_count(), 2)
	_hook("rally", RulesKit.action(_game, unit))
	assert_eq(unit.model_count(), 4, "Six points is enough for both at Health 2")
