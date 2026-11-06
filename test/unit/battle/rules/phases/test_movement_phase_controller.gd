extends GutTest
## Who can still move in the movement phase, and who has.

const RulesKit := preload("res://test/support/rules_kit.gd")
const M := AbilityTiming.Moment

var _game: GameController
var _phase: MovementPhaseController


func before_each() -> void:
	var mine: Array[BattleUnit] = [RulesKit.unit("A", 1, Vector2(2, 3)), RulesKit.unit("B", 1, Vector2(2, 8))]
	var theirs: Array[BattleUnit] = [RulesKit.unit("Enemy", 1, Vector2(28, 15))]
	_game = RulesKit.matched_game(mine, theirs)
	_game.state.active = _game.battle.player
	_game.state.window = M.MOVEMENT
	_phase = MovementPhaseController.new(M.MOVEMENT)


func after_each() -> void:
	_game.dispose()


func _a() -> BattleUnit:
	return _game.battle.player.units[0]


func _b() -> BattleUnit:
	return _game.battle.player.units[1]


func _use(unit: BattleUnit, ability_name: String) -> void:
	for option in _phase.options_for(_game, _game.battle.player):
		if option.user == unit and option.ability_name() == ability_name:
			var action := Action.create(option)
			_game.declare_action(action)
			_game.command(unit, Commands.MoveModels.new(unit.positions, MoveSpec.create(unit, MoveSpec.Kind.NORMAL, 6.0)))
			_phase.record_use(action)
			return
	fail_test("%s can't use %s" % [unit.name, ability_name])


func test_every_unit_can_move_at_the_start() -> void:
	var movers := _phase.units_that_can_move(_game, _game.battle.player)
	assert_true(_a() in movers)
	assert_true(_b() in movers)


func test_each_unit_is_listed_once() -> void:
	var movers := _phase.units_that_can_move(_game, _game.battle.player)
	assert_eq(movers.count(_a()), 1, "Though it can Normal Move or Run")


func test_the_other_army_is_not_listed_in_your_phase() -> void:
	assert_true(_phase.units_that_can_move(_game, _game.battle.opponent).is_empty())


func test_a_unit_that_has_moved_cannot_move_again() -> void:
	_use(_a(), "Normal Move")
	var movers := _phase.units_that_can_move(_game, _game.battle.player)
	assert_false(_a() in movers)
	assert_true(_b() in movers)


func test_a_unit_that_moved_is_listed_as_having_moved() -> void:
	_use(_a(), "Normal Move")
	assert_eq(_phase.units_that_moved(_game, _game.battle.player), [_a()] as Array[BattleUnit])


func test_no_unit_has_moved_before_any_does() -> void:
	assert_true(_phase.units_that_moved(_game, _game.battle.player).is_empty())


func test_a_unit_that_moved_but_not_in_this_phase_is_not_listed() -> void:
	_game.controller_of(_a()).moved = true
	assert_true(_phase.units_that_moved(_game, _game.battle.player).is_empty())


func test_a_unit_in_combat_can_only_retreat() -> void:
	_game.battle.opponent.units[0].positions = PackedVector2Array([Vector2(3.5, 3)])
	var names: Array[String] = []
	for option in _phase.options_for(_game, _game.battle.player):
		if option.user == _a() and "MOVE" in option.entry.ability.keywords:
			names.append(option.ability_name())
	assert_eq(names, ["Retreat"] as Array[String])


func test_a_unit_set_up_this_turn_cannot_move() -> void:
	_game.command(_a(), Commands.SetUp.new(_a().positions))
	var movers := _phase.units_that_can_move(_game, _game.battle.player)
	assert_false(_a() in movers)
	assert_true(_b() in movers)
