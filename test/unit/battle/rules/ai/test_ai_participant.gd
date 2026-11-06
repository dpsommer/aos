extends GutTest
## What the AI chooses when asked.

const RulesKit := preload("res://test/support/rules_kit.gd")
const M := AbilityTiming.Moment

var _ai := AiParticipant.new()
var _game: GameController
var _user: BattleUnit
var _enemy: BattleUnit


func before_each() -> void:
	_user = RulesKit.unit("User", 3, Vector2(5, 5), PackedStringArray(), 1, 0, [RulesKit.weapon()] as Array[Weapon])
	_enemy = RulesKit.unit("Enemy", 1, Vector2(25, 15))
	RulesKit.add_ability(_user, RulesKit.ability("Order", "Your Hero Phase", "command"), {"do": [{"op": "heal", "to": "user"}]})
	RulesKit.add_ability(_user, RulesKit.ability("Trick", "Your Hero Phase"), {"do": [{"op": "heal", "to": "user"}]})
	_game = RulesKit.matched_game([_user] as Array[BattleUnit], [_enemy] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()
	RulesKit.forget_abilities()


func _option(ability_name: String) -> ActionOption:
	for entry: AbilityEntry in _game.books[_game.battle.player]:
		if entry.ability.name == ability_name:
			return ActionOption.create(entry, _user)
	return null


func _request(kind: DecisionRequest.Kind, options: Array[ActionOption] = [], can_pass := true) -> DecisionRequest:
	var request := DecisionRequest.create(kind, _game.battle.player, "Test")
	request.options = options
	request.can_pass = can_pass
	return request


func test_the_ai_answers_at_once() -> void:
	assert_true(_ai.answers_at_once())


func test_it_goes_first() -> void:
	var decision := _ai.decide(_request(DecisionRequest.Kind.FIRST_TURN), _game)
	assert_eq(decision.choice, 0)


func test_it_takes_the_first_choice_of_a_list() -> void:
	assert_eq(_ai.decide(_request(DecisionRequest.Kind.CHOICE), _game).choice, 0)


func test_it_passes_when_nothing_is_worth_doing() -> void:
	var request := _request(DecisionRequest.Kind.ACTION, [_option("Order"), _option("Retreat")] as Array[ActionOption])
	assert_true(_ai.decide(request, _game).passed)


func test_it_passes_with_no_options() -> void:
	assert_true(_ai.decide(_request(DecisionRequest.Kind.ACTION), _game).passed)


func test_it_uses_something_worth_doing() -> void:
	var trick := _option("Trick")
	var decision := _ai.decide(_request(DecisionRequest.Kind.ACTION, [_option("Order"), trick] as Array[ActionOption]), _game)
	assert_false(decision.passed)
	assert_eq(decision.option, trick)


func test_it_prefers_to_fight() -> void:
	var fight := _option("Fight")
	var normal_move := _option("Normal Move")
	var decision := _ai.decide(_request(DecisionRequest.Kind.ACTION, [normal_move, fight] as Array[ActionOption]), _game)
	assert_eq(decision.option, fight)


func test_it_uses_the_first_option_if_it_must_choose_one_it_does_not_want() -> void:
	var order := _option("Order")
	var decision := _ai.decide(_request(DecisionRequest.Kind.ACTION, [order] as Array[ActionOption], false), _game)
	assert_eq(decision.option, order)


func test_it_passes_on_a_reaction_it_has_no_taste_for() -> void:
	var decision := _ai.decide(_request(DecisionRequest.Kind.REACTION, [_option("Order")] as Array[ActionOption]), _game)
	assert_true(decision.passed)


func test_it_unbinds() -> void:
	var unbind := _option("Unbind")
	var decision := _ai.decide(_request(DecisionRequest.Kind.REACTION, [unbind] as Array[ActionOption]), _game)
	assert_eq(decision.option, unbind)


func _targets_request(units: Array[BattleUnit]) -> DecisionRequest:
	var request := _request(DecisionRequest.Kind.TARGETS)
	request.units = units
	request.action = RulesKit.action(_game, _user)
	return request


func test_it_picks_the_nearest_target() -> void:
	var near := RulesKit.unit("Near", 1, Vector2(8, 5))
	var far := RulesKit.unit("Far", 1, Vector2(25, 5))
	var request := _targets_request([far, near] as Array[BattleUnit])
	assert_eq(_ai.decide(request, _game).units, [near] as Array[BattleUnit])


func test_it_picks_as_many_targets_as_it_is_asked_for() -> void:
	var near := RulesKit.unit("Near", 1, Vector2(8, 5))
	var far := RulesKit.unit("Far", 1, Vector2(25, 5))
	var request := _targets_request([far, near] as Array[BattleUnit])
	request.count = 2
	assert_eq(_ai.decide(request, _game).units.size(), 2)


func test_it_aims_each_weapon_at_the_unit_with_the_fewest_models() -> void:
	var small := RulesKit.unit("Small", 1, Vector2(8, 5))
	var large := RulesKit.unit("Large", 5, Vector2(8, 9))
	var weapon: Weapon = _user.warscroll.melee_weapons[0]
	var request := _request(DecisionRequest.Kind.ATTACK_TARGETS)
	request.weapons = [weapon] as Array[Weapon]
	request.weapon_targets = {weapon: [large, small] as Array[BattleUnit]}
	assert_eq(_ai.decide(request, _game).attack_targets, {weapon: small})


func _move_request(distance: float) -> DecisionRequest:
	var request := _request(DecisionRequest.Kind.MOVE)
	request.move = MoveSpec.create(_user, MoveSpec.Kind.NORMAL, distance)
	request.unit = _user
	return request


func test_it_answers_a_move_with_a_legal_move_or_a_pass() -> void:
	var request := _move_request(6.0)
	var decision := _ai.decide(request, _game)
	assert_false(decision.passed, "There is room to move")
	assert_true(MovementRules.is_legal(_game, request.move, decision.positions))


func test_it_moves_towards_the_enemy() -> void:
	var before := BattleGeometry.middle(_user).distance_to(_enemy.positions[0])
	_user.positions = _ai.decide(_move_request(6.0), _game).positions
	assert_lt(BattleGeometry.middle(_user).distance_to(_enemy.positions[0]), before)


func test_it_passes_a_move_with_nowhere_to_go() -> void:
	assert_true(_ai.decide(_move_request(0.0), _game).passed)


func test_it_sets_a_unit_up_where_it_is_allowed() -> void:
	var unit := RulesKit.unit("Redeploying", 2, Vector2(5, 15))
	_game.dispose()
	_game = RulesKit.matched_game([_user, unit] as Array[BattleUnit], [_enemy] as Array[BattleUnit])
	var request := _request(DecisionRequest.Kind.SET_UP)
	request.unit = unit
	request.min_enemy_gap = 9.0
	var decision := _ai.decide(request, _game)
	assert_false(decision.passed)
	assert_eq(_game.set_up_problems(unit, decision.positions, 9.0), PackedStringArray())


func test_it_passes_a_reaction_with_nothing_to_react_with() -> void:
	assert_true(_ai.decide(_request(DecisionRequest.Kind.REACTION), _game).passed)
