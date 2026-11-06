extends GutTest
## Changing a unit's counter.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _unit: BattleUnit


func before_each() -> void:
	_unit = RulesKit.unit("Unit", 1, Vector2(10, 10))
	_game = RulesKit.game([_unit] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


func _change(descriptor: Dictionary) -> void:
	descriptor["op"] = "counter"
	descriptor["to"] = "user"
	RulesKit.effect(descriptor).resolve(RulesKit.action(_game, _unit), _game)


func test_the_counter_goes_up_by_the_amount() -> void:
	_change({"name": "momentum", "by": 3})
	assert_eq(_game.controller_of(_unit).counter("momentum"), 3)


func test_the_counter_goes_up_by_one_by_default() -> void:
	_change({"name": "momentum"})
	assert_eq(_game.controller_of(_unit).counter("momentum"), 1)


func test_the_counter_can_go_down() -> void:
	_change({"name": "momentum", "by": 3})
	_change({"name": "momentum", "by": -2})
	assert_eq(_game.controller_of(_unit).counter("momentum"), 1)


func test_counters_are_kept_apart() -> void:
	_change({"name": "momentum", "by": 3})
	assert_eq(_game.controller_of(_unit).counter("other"), 0)
