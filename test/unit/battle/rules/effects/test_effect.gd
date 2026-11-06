extends GutTest
## What every effect shares: how it's built, the rolls it waits on and who it acts on.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _user: BattleUnit
var _friend: BattleUnit
var _far_friend: BattleUnit
var _enemy: BattleUnit


func before_each() -> void:
	_user = RulesKit.unit("User", 1, Vector2(10, 10))
	_friend = RulesKit.unit("Friend", 1, Vector2(13, 10))
	_far_friend = RulesKit.unit("Far friend", 1, Vector2(25, 10))
	_enemy = RulesKit.unit("Enemy", 1, Vector2(20, 18))
	_game = RulesKit.game([_user, _friend, _far_friend] as Array[BattleUnit], [_enemy] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


func _subjects(params: Dictionary, targets: Array[BattleUnit] = []) -> Array[BattleUnit]:
	return RulesKit.effect(params).subjects(RulesKit.action(_game, _user, targets), _game)


func test_each_op_the_data_uses_builds_an_effect() -> void:
	var ops := {"modify": ModifyEffect, "grant": ModifyEffect, "mortal": MortalEffect, "heal": HealEffect, "move": MoveEffect,
			"pick_attacks": PickAttacksEffect, "attack": AttackEffect, "setup": SetUpEffect, "counter": CounterEffect,
			"return_models": ReturnModelsEffect, "summon": SummonEffect, "hook": HookEffect}
	for op: String in ops:
		var built := Effect.build_all([{"op": op}])
		assert_eq(built.size(), 1, op)
		assert_true(is_instance_of(built[0], ops[op]), op)


func test_effects_are_built_in_order_and_keep_their_data() -> void:
	var built := Effect.build_all([{"op": "heal", "amount": "2"}, {"op": "mortal", "amount": "3"}])
	assert_true(built[0] is HealEffect)
	assert_true(built[1] is MortalEffect)
	assert_eq(built[1].params.amount, "3")


func test_no_descriptors_build_nothing() -> void:
	assert_true(Effect.build_all([]).is_empty())


# Waiting on a roll

func test_an_effect_that_needs_a_roll_waits_for_it() -> void:
	var effect := RulesKit.effect({"op": "heal", "if_roll": {"name": "chanting", "at_least": 8}})
	var action := RulesKit.action(_game, _user)
	assert_false(effect.roll_allows(action), "No roll yet")
	action.rolls["chanting"] = 7
	assert_false(effect.roll_allows(action))
	action.rolls["chanting"] = 8
	assert_true(effect.roll_allows(action))


func test_an_effect_that_needs_a_roll_not_to_be_made_stops_when_it_is() -> void:
	var effect := RulesKit.effect({"op": "heal", "unless_roll": {"name": "gate", "at_least": 4}})
	var action := RulesKit.action(_game, _user)
	assert_true(effect.roll_allows(action), "No roll at all")
	action.rolls["gate"] = 3
	assert_true(effect.roll_allows(action))
	action.rolls["gate"] = 4
	assert_false(effect.roll_allows(action))


func test_an_effect_with_no_roll_condition_is_always_allowed() -> void:
	assert_true(RulesKit.effect({"op": "heal"}).roll_allows(RulesKit.action(_game, _user)))


# Who it acts on

func test_the_user_is_who_it_acts_on_when_it_says_so() -> void:
	assert_eq(_subjects({"op": "heal", "to": "user"}, [_enemy] as Array[BattleUnit]), [_user] as Array[BattleUnit])


func test_the_targets_are_who_it_acts_on_by_default() -> void:
	assert_eq(_subjects({"op": "heal"}, [_enemy, _friend] as Array[BattleUnit]), [_enemy, _friend] as Array[BattleUnit])


func test_with_no_targets_it_acts_on_the_user() -> void:
	assert_eq(_subjects({"op": "heal"}), [_user] as Array[BattleUnit])


func test_the_parents_user_and_targets_are_who_a_reaction_acts_on() -> void:
	var action := RulesKit.action(_game, _enemy)
	action.parent = RulesKit.action(_game, _user, [_friend] as Array[BattleUnit])
	assert_eq(RulesKit.effect({"op": "heal", "to": "parent_user"}).subjects(action, _game), [_user] as Array[BattleUnit])
	assert_eq(RulesKit.effect({"op": "heal", "to": "parent_targets"}).subjects(action, _game), [_friend] as Array[BattleUnit])


func test_a_reaction_without_a_parent_acts_on_nobody() -> void:
	assert_true(_subjects({"op": "heal", "to": "parent_user"}).is_empty())
	assert_true(_subjects({"op": "heal", "to": "parent_targets"}).is_empty())


func test_friendly_is_every_friendly_unit_on_the_battlefield() -> void:
	var subjects := _subjects({"op": "heal", "to": "friendly"})
	assert_eq(subjects.size(), 3)
	assert_false(_enemy in subjects)


func test_friendly_can_be_limited_to_those_within_reach_of_the_user() -> void:
	var subjects := _subjects({"op": "heal", "to": "friendly", "within": 6})
	assert_true(_friend in subjects)
	assert_true(_user in subjects)
	assert_false(_far_friend in subjects)


func test_friendly_can_be_limited_to_those_wholly_within_reach() -> void:
	# The friend's centre is 3" off, so its near edge is within 2.5" but its far edge isn't.
	assert_true(_friend in _subjects({"op": "heal", "to": "friendly", "within": 2.5}))
	var wholly := _subjects({"op": "heal", "to": "friendly", "within": 2.5, "wholly": true})
	assert_false(_friend in wholly)
	assert_true(_user in wholly)


func test_destroyed_units_are_left_out() -> void:
	_game.command(_friend, Commands.Destroy.new(_game.battle.opponent))
	assert_false(_friend in _subjects({"op": "heal", "to": "friendly"}))
	assert_true(_subjects({"op": "heal"}, [_friend] as Array[BattleUnit]).is_empty())
