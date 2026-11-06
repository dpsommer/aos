extends GutTest
## The battle's events: logged at once, heard once nothing is being resolved.

var _bus := EventBus.new()
var _heard: Array[String] = []


func before_each() -> void:
	_bus = EventBus.new()
	_heard = []


func _listen(kind: StringName, label: String) -> void:
	_bus.subscribe(kind, func(_event: BattleEvent) -> void: _heard.append(label))


func test_a_listener_hears_an_event_of_its_kind() -> void:
	_listen(BattleEvent.UNIT_MOVED, "moved")
	_bus.publish(BattleEvent.UNIT_MOVED)
	assert_eq(_heard, ["moved"] as Array[String])


func test_a_listener_does_not_hear_other_kinds() -> void:
	_listen(BattleEvent.UNIT_MOVED, "moved")
	_bus.publish(BattleEvent.UNIT_DAMAGED)
	assert_true(_heard.is_empty())


func test_every_listener_of_the_kind_hears_it_in_the_order_they_listened() -> void:
	_listen(BattleEvent.UNIT_MOVED, "first")
	_listen(BattleEvent.UNIT_MOVED, "second")
	_bus.publish(BattleEvent.UNIT_MOVED)
	assert_eq(_heard, ["first", "second"] as Array[String])


func test_the_listener_gets_the_event_with_its_data() -> void:
	var got: Array[BattleEvent] = []
	_bus.subscribe(BattleEvent.UNIT_MOVED, func(event: BattleEvent) -> void: got.append(event))
	_bus.publish(BattleEvent.UNIT_MOVED, {"text": "It moved."})
	assert_eq(got[0].text(), "It moved.")


func test_an_event_is_logged_even_without_listeners() -> void:
	_bus.publish(BattleEvent.UNIT_MOVED, {"text": "It moved."})
	assert_eq(_bus.log_entries.size(), 1)


func test_events_wait_while_held() -> void:
	_listen(BattleEvent.UNIT_MOVED, "moved")
	_bus.hold()
	_bus.publish(BattleEvent.UNIT_MOVED)
	assert_true(_heard.is_empty())
	assert_eq(_bus.log_entries.size(), 1, "But they're logged")


func test_released_events_are_heard_in_the_order_they_happened() -> void:
	_listen(BattleEvent.UNIT_MOVED, "moved")
	_listen(BattleEvent.UNIT_DAMAGED, "damaged")
	_bus.hold()
	_bus.publish(BattleEvent.UNIT_DAMAGED)
	_bus.publish(BattleEvent.UNIT_MOVED)
	_bus.release()
	assert_eq(_heard, ["damaged", "moved"] as Array[String])


func test_events_wait_until_every_hold_is_released() -> void:
	_listen(BattleEvent.UNIT_MOVED, "moved")
	_bus.hold()
	_bus.hold()
	_bus.publish(BattleEvent.UNIT_MOVED)
	_bus.release()
	assert_true(_heard.is_empty())
	_bus.release()
	assert_eq(_heard.size(), 1)


func test_an_event_is_heard_once() -> void:
	_listen(BattleEvent.UNIT_MOVED, "moved")
	_bus.publish(BattleEvent.UNIT_MOVED)
	_bus.drain()
	assert_eq(_heard.size(), 1)


func test_what_a_listener_publishes_joins_the_end_of_the_queue() -> void:
	_bus.subscribe(BattleEvent.UNIT_MOVED, func(_event: BattleEvent) -> void:
		_heard.append("moved")
		_bus.publish(BattleEvent.UNIT_HEALED))
	_listen(BattleEvent.UNIT_HEALED, "healed")
	_listen(BattleEvent.UNIT_DAMAGED, "damaged")
	_bus.hold()
	_bus.publish(BattleEvent.UNIT_MOVED)
	_bus.publish(BattleEvent.UNIT_DAMAGED)
	_bus.release()
	assert_eq(_heard, ["moved", "damaged", "healed"] as Array[String])


func test_a_listener_is_not_called_again_while_it_is_being_called() -> void:
	# [calls so far, how deep the calls were, how deep they are now]
	var calls := [0, 0, 0]
	_bus.subscribe(BattleEvent.UNIT_MOVED, func(_event: BattleEvent) -> void:
		calls[0] += 1
		calls[2] += 1
		calls[1] = maxi(calls[1], calls[2])
		if calls[0] < 3:
			_bus.publish(BattleEvent.UNIT_MOVED)
		calls[2] -= 1)
	_bus.publish(BattleEvent.UNIT_MOVED)
	assert_eq(calls[0], 3, "Each event it published was heard")
	assert_eq(calls[1], 1, "But never inside itself")


func test_cleared_listeners_hear_nothing() -> void:
	_listen(BattleEvent.UNIT_MOVED, "moved")
	_bus.clear_listeners()
	_bus.publish(BattleEvent.UNIT_MOVED)
	assert_true(_heard.is_empty())


func test_the_log_text_is_one_line_a_kind_and_text_in_order() -> void:
	_bus.publish(BattleEvent.UNIT_MOVED, {"text": "A moves."})
	_bus.publish(BattleEvent.UNIT_HEALED, {"text": "B heals."})
	assert_eq(_bus.log_text(), "%s: A moves.\n%s: B heals." % [BattleEvent.UNIT_MOVED, BattleEvent.UNIT_HEALED])
