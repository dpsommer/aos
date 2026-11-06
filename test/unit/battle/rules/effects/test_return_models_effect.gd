extends GutTest
## Returning slain models.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _unit: BattleUnit


func before_each() -> void:
	_unit = RulesKit.unit("Unit", 5, Vector2(10, 10), PackedStringArray(), 1)
	_game = RulesKit.game([_unit] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])
	_game.command(_unit, Commands.DealDamage.new(3))


func after_each() -> void:
	_game.dispose()


func _return(amount: String) -> void:
	RulesKit.effect({"op": "return_models", "to": "user", "amount": amount}).resolve(RulesKit.action(_game, _unit), _game)


func test_models_return_to_the_unit() -> void:
	_return("2")
	assert_eq(_unit.model_count(), 4)
	assert_eq(_unit.bases.size(), _unit.positions.size())


func test_no_more_return_than_were_slain() -> void:
	_return("5")
	assert_eq(_unit.model_count(), 5)


func test_the_amount_is_one_by_default() -> void:
	RulesKit.effect({"op": "return_models", "to": "user"}).resolve(RulesKit.action(_game, _unit), _game)
	assert_eq(_unit.model_count(), 3)


func test_dice_are_rolled_for_the_amount() -> void:
	_return("D3")
	assert_between(_unit.model_count(), 3, 5)
