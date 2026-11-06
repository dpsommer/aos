extends GutTest
## Modify and grant: giving a unit a modifier.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _user: BattleUnit
var _other: BattleUnit


func before_each() -> void:
	_user = RulesKit.unit("User", 1, Vector2(10, 10))
	_other = RulesKit.unit("Other", 1, Vector2(13, 10))
	_game = RulesKit.game([_user, _other] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


func _modifiers(unit: BattleUnit) -> Array[Modifier]:
	return _game.controller_of(unit).modifiers.modifiers


func _apply(descriptor: Dictionary, targets: Array[BattleUnit] = []) -> Action:
	var action := RulesKit.action(_game, _user, targets, "Bless")
	RulesKit.effect(descriptor).resolve(action, _game)
	return action


func test_the_subject_gets_a_modifier_with_the_data() -> void:
	_apply({"op": "modify", "to": "user", "stat": "hit", "by": 1, "until": "turn"})
	var modifier := _modifiers(_user)[0]
	assert_eq(modifier.stat, &"hit")
	assert_eq(modifier.value, 1)
	assert_eq(modifier.until, Modifier.Until.END_OF_TURN)


func test_the_modifier_remembers_the_ability_and_army() -> void:
	_apply({"op": "modify", "to": "user", "stat": "hit", "by": 1})
	var modifier := _modifiers(_user)[0]
	assert_eq(modifier.source_name, "Bless")
	assert_eq(modifier.source_army, _game.battle.player)


func test_only_the_subjects_get_it() -> void:
	_apply({"op": "modify", "stat": "hit", "by": 1}, [_other] as Array[BattleUnit])
	assert_true(_modifiers(_user).is_empty())
	assert_eq(_modifiers(_other).size(), 1)


func test_every_subject_gets_its_own() -> void:
	_apply({"op": "modify", "to": "friendly", "stat": "hit", "by": 1})
	assert_eq(_modifiers(_user).size(), 1)
	assert_eq(_modifiers(_other).size(), 1)
	assert_ne(_modifiers(_user)[0], _modifiers(_other)[0])


func test_the_modifier_changes_what_the_stat_resolves_to() -> void:
	_apply({"op": "modify", "to": "user", "stat": "move", "by": 2})
	assert_eq(_game.stats.modified(6, &"move", RuleContext.of_unit(_game, _user)), 8)


func test_a_grant_gives_a_keyword() -> void:
	_apply({"op": "grant", "to": "user", "grant": "FLY"})
	assert_true(_game.stats.has_keyword(_user, "FLY"))
	assert_false(_game.stats.has_keyword(_other, "FLY"))


func test_a_number_of_dice_is_rolled_for_the_bonus() -> void:
	_apply({"op": "modify", "to": "user", "stat": "move", "by": "D3"})
	assert_between(_modifiers(_user)[0].value, 1, 3)


func test_a_dice_bonus_is_rolled_for_each_unit() -> void:
	var seen := {}
	for seed_value in 30:
		var game := RulesKit.game([RulesKit.unit("A", 1, Vector2(10, 10)), RulesKit.unit("B", 1, Vector2(13, 10))] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit], [] as Array[BattleTerrain], seed_value)
		RulesKit.effect({"op": "modify", "to": "friendly", "stat": "move", "by": "D6"}).resolve(RulesKit.action(game, game.battle.player.units[0]), game)
		var a := game.controller_of(game.battle.player.units[0]).modifiers.modifiers[0].value
		var b := game.controller_of(game.battle.player.units[1]).modifiers.modifiers[0].value
		seen[a == b] = true
		game.dispose()
	assert_true(seen.has(false), "Not always the same number for both")


func test_a_modifier_until_the_action_ends_is_tied_to_the_action() -> void:
	var action := _apply({"op": "modify", "to": "user", "stat": "hit", "by": 1, "until": "action"})
	assert_eq(_modifiers(_user)[0].action, action)


func test_a_modifier_of_the_parent_is_tied_to_the_parent_action() -> void:
	var parent := RulesKit.action(_game, _other)
	var action := RulesKit.action(_game, _user, [] as Array[BattleUnit], "React")
	action.parent = parent
	RulesKit.effect({"op": "modify", "to": "user", "stat": "hit", "by": 1, "until": "action", "of_parent": true}).resolve(action, _game)
	assert_eq(_modifiers(_user)[0].action, parent)


func test_a_destroyed_subject_gets_nothing() -> void:
	_game.command(_other, Commands.Destroy.new(_game.battle.opponent))
	_apply({"op": "modify", "stat": "hit", "by": 1}, [_other] as Array[BattleUnit])
	assert_true(_modifiers(_other).is_empty())
