extends GutTest
## Heal (N).

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _unit: BattleUnit


func before_each() -> void:
	_unit = RulesKit.unit("Unit", 3, Vector2(10, 10), PackedStringArray(), 5)
	_game = RulesKit.game([_unit] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])
	_game.command(_unit, Commands.DealDamage.new(3))


func after_each() -> void:
	_game.dispose()


func _heal(amount: String) -> void:
	RulesKit.effect({"op": "heal", "to": "user", "amount": amount}).resolve(RulesKit.action(_game, _unit), _game)


func test_healing_takes_damage_points_off_the_unit() -> void:
	_heal("2")
	assert_eq(_game.controller_of(_unit).damage_points, 1)


func test_dice_are_rolled_for_the_amount() -> void:
	_heal("D3")
	assert_between(_game.controller_of(_unit).damage_points, 0, 2)


func test_the_amount_is_one_by_default() -> void:
	RulesKit.effect({"op": "heal", "to": "user"}).resolve(RulesKit.action(_game, _unit), _game)
	assert_eq(_game.controller_of(_unit).damage_points, 2)


func test_healing_more_than_the_damage_stops_at_none() -> void:
	_heal("10")
	assert_eq(_game.controller_of(_unit).damage_points, 0)
