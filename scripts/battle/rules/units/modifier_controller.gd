class_name ModifierController
extends RefCounted
## The [Modifier]s held by one thing, and when they run out. Listens to the battle's events for that,
## so whatever holds it doesn't have to.

var modifiers: Array[Modifier] = []


## Starts listening to [param events] for modifiers running out.
func listen(events: EventBus) -> void:
	events.subscribe(BattleEvent.PHASE_ENDED, func(_event: BattleEvent) -> void: _expire(Modifier.Until.END_OF_PHASE))
	events.subscribe(BattleEvent.TURN_ENDED, func(_event: BattleEvent) -> void: _expire(Modifier.Until.END_OF_TURN))
	events.subscribe(BattleEvent.ROUND_ENDED, func(_event: BattleEvent) -> void: _expire(Modifier.Until.END_OF_ROUND))
	events.subscribe(BattleEvent.TURN_STARTED, _on_turn_started)
	events.subscribe(BattleEvent.ABILITY_RESOLVED, _on_ability_resolved)


func add(modifier: Modifier) -> void:
	modifiers.append(modifier)


func _expire(until: Modifier.Until) -> void:
	modifiers = modifiers.filter(func(modifier: Modifier) -> bool: return modifier.until != until)


## 'Until the start of your next turn' ends when the army that used it starts a turn.
func _on_turn_started(event: BattleEvent) -> void:
	var army: BattleArmy = event.data.army
	modifiers = modifiers.filter(func(modifier: Modifier) -> bool:
		return not (modifier.until == Modifier.Until.START_OF_NEXT_TURN and modifier.source_army == army))


func _on_ability_resolved(event: BattleEvent) -> void:
	var action: Action = event.data.action
	modifiers = modifiers.filter(func(modifier: Modifier) -> bool:
		return not (modifier.until == Modifier.Until.END_OF_ACTION and modifier.action == action))
