extends GutTest
## Unit tests for the controller that runs a battle on the game map (scripts/battle/battle_map_controller.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const RulesKit := preload("res://test/support/rules_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const MapScene := preload("res://scenes/battle/battle_map.tscn")
const UIKit := preload("res://test/support/ui_kit.gd")


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	RulesKit.forget_abilities()
	Sandbox.end()


## A controller for a Matched Play game of one unit a side, started, with the player the attacker
## unless [param player_first] is false. With [param played_out] the battle is already over.
func _started(player_first := true, played_out := false) -> BattleMapController:
	var mine: Array[BattleUnit] = [RulesKit.unit("Mine", 2, Vector2(5, 5))]
	var theirs: Array[BattleUnit] = [RulesKit.unit("Theirs", 2, Vector2(25, 15))]
	var game := RulesKit.matched_game(mine, theirs)
	game.battle.player_is_attacker = player_first
	if played_out:
		RulesKit.drive(game, RulesKit.pass_on, 2000)
	return _controller_of(game)


## A controller on the map of [param game], started from wherever the game has got to.
func _controller_of(game: GameController) -> BattleMapController:
	var map: BattleMap = MapScene.instantiate()
	add_child_autofree(map)
	map.build(game.battle)
	var controller := BattleMapController.new(map, game)
	controller.ai_delay = 0.0
	add_child_autofree(controller)
	controller.start(map.overlay)
	return controller


func test_the_player_chosen_to_go_first_is_asked_who_goes_first() -> void:
	var controller := _started()
	assert_not_null(controller.request)
	assert_eq(controller.request.kind, DecisionRequest.Kind.FIRST_TURN)
	assert_eq(controller.request.army, controller.battle.player)
	assert_eq(UIKit.buttons(controller.hud.get_node(^"%Options")).size(), 2, "Go first or go second")


func test_pressing_a_choice_answers_the_request() -> void:
	var controller := _started()
	var buttons := UIKit.buttons(controller.hud.get_node(^"%Options"))
	buttons[1].pressed.emit()
	assert_eq(controller.game.state.first_this_round, controller.battle.opponent, "The second choice is to go second")


func test_after_an_answer_the_next_request_is_asked() -> void:
	var controller := _started()
	UIKit.buttons(controller.hud.get_node(^"%Options"))[0].pressed.emit()
	assert_ne(controller.request.kind, DecisionRequest.Kind.FIRST_TURN)


func test_what_happens_is_written_to_the_log() -> void:
	var controller := _started()
	assert_true(UIKit.has_label_containing(controller.hud, "Battle round 1"))


func test_the_ai_answers_for_itself() -> void:
	var controller := _started(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(controller.game.state.first_this_round, "The AI chose")
	assert_not_null(controller.request, "And the player is being asked something")
	assert_eq(controller.request.army, controller.battle.player)


func test_while_the_ai_decides_the_hud_says_so() -> void:
	var controller := _started(false)
	assert_true(UIKit.has_label_containing(controller.hud, "deciding"))
	assert_null(controller.request)


func test_the_header_shows_the_round() -> void:
	var controller := _started()
	assert_true(UIKit.has_label_containing(controller.map.hud, "ROUND 1"))


func test_a_weapon_is_aimed_at_the_picked_target_if_it_can_reach_it() -> void:
	var near := BattleKit.unit("Near", 1)
	var far := BattleKit.unit("Far", 1)
	var reaches := RulesKit.weapon()
	var misses := RulesKit.weapon()
	var request := DecisionRequest.create(DecisionRequest.Kind.ATTACK_TARGETS, null)
	request.weapons = [reaches, misses] as Array[Weapon]
	request.weapon_targets = {reaches: [near, far] as Array[BattleUnit], misses: [far] as Array[BattleUnit]}
	var chosen := BattleMapController.attack_all_at(request, near)
	assert_eq(chosen[reaches], near)
	assert_eq(chosen[misses], far, "It can't reach the picked one, so the first it can")


func test_a_finished_battle_shows_the_result() -> void:
	var controller := _started(true, true)
	assert_not_null(controller.victory_panel)
	assert_false(controller.hud.visible)


func test_leaving_the_result_finishes_the_controller() -> void:
	var controller := _started(true, true)
	watch_signals(controller)
	UIKit.buttons(controller.victory_panel)[0].pressed.emit()
	assert_signal_emitted(controller, "finished")


## A started controller offering the player [code]Arrive[/code], which sets up a unit in reserve.
func _offering_arrive() -> BattleMapController:
	var arriving := RulesKit.unit("Arriving", 2, Vector2(5, 5))
	arriving.start_in_reserve()
	RulesKit.add_ability(arriving, RulesKit.ability("Arrive", "Your Hero Phase"), {"user": {"from": "reserve"}, "do": [{"op": "setup", "to": "user"}]})
	var game := RulesKit.matched_game([arriving] as Array[BattleUnit], [RulesKit.unit("Theirs", 2, Vector2(25, 15))] as Array[BattleUnit])
	game.battle.player_is_attacker = true
	var offer := RulesKit.drive(game, func(request: DecisionRequest) -> Decision:
		return null if _arrive_in(request) else RulesKit.pass_on(request))
	assert_not_null(offer, "Arrive was offered")
	return _controller_of(game)


func _arrive_in(request: DecisionRequest) -> ActionOption:
	for option in request.options:
		if option.ability_name() == "Arrive":
			return option
	return null


func _press_arrive(controller: BattleMapController) -> void:
	controller.hud.option_picked.emit(_arrive_in(controller.request))


func test_a_set_up_request_for_a_unit_with_no_node_adds_one_for_the_preview() -> void:
	var controller := _offering_arrive()
	var unit: BattleUnit = controller.battle.player.units[0]
	assert_false(controller.map.unit_nodes.has(unit), "In reserve, so not on the board yet")
	_press_arrive(controller)
	assert_eq(controller.request.kind, DecisionRequest.Kind.SET_UP)
	assert_true(controller.map.unit_nodes.has(unit))


func test_passing_a_set_up_removes_the_preview_again() -> void:
	var controller := _offering_arrive()
	var unit: BattleUnit = controller.battle.player.units[0]
	_press_arrive(controller)
	controller.hud.pass_pressed.emit()
	assert_false(controller.map.unit_nodes.has(unit))
	await get_tree().process_frame
