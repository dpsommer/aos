extends GutTest
## When modifiers run out, as the battle's events say.

var _events := EventBus.new()
var _holder := ModifierController.new()
var _mine := BattleArmy.new()
var _theirs := BattleArmy.new()


func before_each() -> void:
	_events = EventBus.new()
	_holder = ModifierController.new()
	_holder.listen(_events)
	_mine = BattleArmy.new()
	_theirs = BattleArmy.new()


func _add(until: Modifier.Until, army: BattleArmy = null, action: Action = null) -> Modifier:
	var modifier := Modifier.new()
	modifier.until = until
	modifier.source_army = army
	modifier.action = action
	_holder.add(modifier)
	return modifier


func test_a_modifier_is_held_once_added() -> void:
	var modifier := _add(Modifier.Until.PERMANENT)
	assert_true(modifier in _holder.modifiers)


func test_the_end_of_a_phase_ends_phase_modifiers_only() -> void:
	var phase := _add(Modifier.Until.END_OF_PHASE)
	var turn := _add(Modifier.Until.END_OF_TURN)
	var the_round := _add(Modifier.Until.END_OF_ROUND)
	var kept := _add(Modifier.Until.PERMANENT)
	_events.publish(BattleEvent.PHASE_ENDED)
	assert_false(phase in _holder.modifiers)
	assert_true(turn in _holder.modifiers)
	assert_true(the_round in _holder.modifiers)
	assert_true(kept in _holder.modifiers)


func test_the_end_of_a_turn_ends_turn_modifiers_only() -> void:
	var phase := _add(Modifier.Until.END_OF_PHASE)
	var turn := _add(Modifier.Until.END_OF_TURN)
	var the_round := _add(Modifier.Until.END_OF_ROUND)
	_events.publish(BattleEvent.TURN_ENDED)
	assert_false(turn in _holder.modifiers)
	assert_true(phase in _holder.modifiers, "Only its own event ends it")
	assert_true(the_round in _holder.modifiers)


func test_the_end_of_a_round_ends_round_modifiers_only() -> void:
	var turn := _add(Modifier.Until.END_OF_TURN)
	var the_round := _add(Modifier.Until.END_OF_ROUND)
	_events.publish(BattleEvent.ROUND_ENDED)
	assert_false(the_round in _holder.modifiers)
	assert_true(turn in _holder.modifiers)


func test_permanent_modifiers_survive_every_ending() -> void:
	var kept := _add(Modifier.Until.PERMANENT, _mine)
	for kind in [BattleEvent.PHASE_ENDED, BattleEvent.TURN_ENDED, BattleEvent.ROUND_ENDED]:
		_events.publish(kind)
	_events.publish(BattleEvent.TURN_STARTED, {"army": _mine})
	assert_true(kept in _holder.modifiers)


func test_until_the_start_of_your_next_turn_ends_when_the_source_army_starts_a_turn() -> void:
	var modifier := _add(Modifier.Until.START_OF_NEXT_TURN, _mine)
	_events.publish(BattleEvent.TURN_STARTED, {"army": _mine})
	assert_false(modifier in _holder.modifiers)


func test_until_the_start_of_your_next_turn_outlasts_the_other_armys_turn() -> void:
	var modifier := _add(Modifier.Until.START_OF_NEXT_TURN, _mine)
	_events.publish(BattleEvent.TURN_STARTED, {"army": _theirs})
	assert_true(modifier in _holder.modifiers)


func test_the_start_of_a_turn_does_not_end_other_durations() -> void:
	var turn := _add(Modifier.Until.END_OF_TURN, _mine)
	_events.publish(BattleEvent.TURN_STARTED, {"army": _mine})
	assert_true(turn in _holder.modifiers)


func test_an_action_modifier_ends_when_its_action_is_resolved() -> void:
	var action := Action.new()
	var modifier := _add(Modifier.Until.END_OF_ACTION, null, action)
	_events.publish(BattleEvent.ABILITY_RESOLVED, {"action": action})
	assert_false(modifier in _holder.modifiers)


func test_an_action_modifier_outlasts_another_action() -> void:
	var modifier := _add(Modifier.Until.END_OF_ACTION, null, Action.new())
	_events.publish(BattleEvent.ABILITY_RESOLVED, {"action": Action.new()})
	assert_true(modifier in _holder.modifiers)


func test_only_the_ended_modifiers_go() -> void:
	var first := _add(Modifier.Until.END_OF_PHASE)
	var second := _add(Modifier.Until.END_OF_PHASE)
	var kept := _add(Modifier.Until.END_OF_TURN)
	_events.publish(BattleEvent.PHASE_ENDED)
	assert_eq(_holder.modifiers, [kept] as Array[Modifier])
	assert_false(first in _holder.modifiers or second in _holder.modifiers)
