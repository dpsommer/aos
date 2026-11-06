class_name UsageLedger
extends RefCounted
## Every limit on using abilities in one place (Core Rules 5.3 and 28.2, Commands 1.2): the Rules of
## One, the Once Per timings and command limits. Phases only ask it.

var _state: GameState
## When each key was last used: the window, turn and round serials.
var _uses := {}
## Abilities used with a limit that lasts the battle, or the round, by key.
var _battle := {}
var _casts := {}
var _casts_window := {}


func _init(state: GameState) -> void:
	_state = state


## Why [param army] (with [param user], null for the player) can't use [param ability] again now, or
## empty if it can.
func reason_unavailable(ability: Ability, army: BattleArmy, user: BattleUnit) -> String:
	if user != null and _used_this_window(["core", user]) and "CORE" in ability.keywords:
		return "Already used a core ability this phase."
	if user != null and not "UNLIMITED" in ability.keywords and not "UNBIND" in ability.keywords and _used_this_window(["ability", ability, user]):
		return "Already used this phase."
	if user == null and not "UNLIMITED" in ability.keywords and _used_this_window(["ability", ability, army]):
		return "Already used this phase."
	# Each spell or prayer once per army per turn (Magic 5.0).
	if ability.type in ["spell", "prayer"] and not "UNLIMITED" in ability.keywords:
		if _uses.get(["cast", ability.name, army], -1) == _state.turn_serial:
			return "Your army has used this already this turn."
	if ability.type == "command":
		if user != null and _used_this_window(["command", user]):
			return "This unit has used a command this phase."
		if _used_this_window(["ability", ability.name, army]):
			return "Your army has used this command this phase."
	var frequency := ability.frequency.to_lower()
	if frequency.is_empty():
		return ""
	# The holder of a limit: the whole army if it says so or the player uses it, else the unit.
	var holder := _limit_holder(frequency, army, user)
	var key := [ability, holder]
	if frequency.contains("round"):
		return "Used: once per battle round." if _uses.get(key + ["round"], -1) == _state.round_number else ""
	if frequency.contains("battle"):
		return "Used: once per battle." if _battle.has(key) else ""
	if frequency.contains("turn"):
		return "Used: once per turn." if _uses.get(key + ["turn"], -1) == _state.turn_serial else ""
	if frequency.contains("phase"):
		return "Used: once per phase." if _used_this_window(key + ["window"]) else ""
	return ""


## How many spells, prayers and banishes [param user] has used this phase.
func casts_this_phase(user: BattleUnit) -> int:
	return _casts.get(user, 0) if _casts_window.get(user, -1) == _state.window_serial else 0


func mark_cast(user: BattleUnit, by := 1) -> void:
	_casts[user] = casts_this_phase(user) + by
	_casts_window[user] = _state.window_serial


## Records that [param ability] was used.
func mark(ability: Ability, army: BattleArmy, user: BattleUnit) -> void:
	_mark_window(["ability", ability, _limit_holder("", army, user)])
	if "CORE" in ability.keywords and user:
		_mark_window(["core", user])
	if ability.type == "command":
		_mark_window(["ability", ability.name, army])
		if user:
			_mark_window(["command", user])
	if ability.type in ["spell", "prayer"]:
		_uses[["cast", ability.name, army]] = _state.turn_serial
	var frequency := ability.frequency.to_lower()
	if not frequency.is_empty():
		var holder := _limit_holder(frequency, army, user)
		var key := [ability, holder]
		_battle[key] = true
		_uses[key + ["round"]] = _state.round_number
		_uses[key + ["turn"]] = _state.turn_serial
		_mark_window(key + ["window"])


## Who a limit counts against: the army if it says so or the player uses it, else the unit.
func _limit_holder(frequency: String, army: BattleArmy, user: BattleUnit) -> RefCounted:
	if user == null or frequency.contains("army"):
		return army
	return user


func _mark_window(key: Array) -> void:
	_uses[key] = _state.window_serial


func _used_this_window(key: Array) -> bool:
	return _uses.get(key, -1) == _state.window_serial
