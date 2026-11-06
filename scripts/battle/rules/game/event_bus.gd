class_name EventBus
extends RefCounted
## The battle's events. [method publish] logs an event and queues it; listeners hear it when the
## queue drains, which only happens once the current command has finished, so a listener can't
## re-enter what's still being resolved (a [constant BattleEvent.MODEL_SLAIN] listener can't change a
## unit in the middle of allocating damage). A listener may issue commands: what they publish joins
## the end of the queue.

## Every event so far, in order.
var log_entries: Array[BattleEvent] = []

var _listeners := {}
var _queue: Array[BattleEvent] = []
var _draining := false
## How many commands are being handled: the queue waits for them.
var _holds := 0


func subscribe(kind: StringName, listener: Callable) -> void:
	if not _listeners.has(kind):
		_listeners[kind] = []
	_listeners[kind].append(listener)


## Logs an event of [param kind] and hands it to its listeners, once nothing is being resolved.
func publish(kind: StringName, data: Dictionary = {}) -> BattleEvent:
	var event := BattleEvent.new(kind, data)
	log_entries.append(event)
	_queue.append(event)
	drain()
	return event


## Holds the queue while a command is handled.
func hold() -> void:
	_holds += 1


## Lets the queue go again, and drains it if nothing else is holding it.
func release() -> void:
	_holds -= 1
	drain()


func drain() -> void:
	if _draining or _holds > 0:
		return
	_draining = true
	while not _queue.is_empty():
		var event: BattleEvent = _queue.pop_front()
		for listener: Callable in _listeners.get(event.kind, []):
			listener.call(event)
	_draining = false


## Forgets its listeners, which point back at the controllers.
func clear_listeners() -> void:
	_listeners.clear()


## The log as text: the same seed and answers give the same text.
func log_text() -> String:
	var lines := PackedStringArray()
	for event in log_entries:
		lines.append("%s: %s" % [event.kind, event.text()])
	return "\n".join(lines)
