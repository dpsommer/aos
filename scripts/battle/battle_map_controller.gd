class_name BattleMapController
extends Node
## Runs the battle on the game map: it asks the [GameController] what needs deciding, passes it to
## whoever commands that army ([Participant]), shows what happened from the event log, and gives the
## player the board and [TurnHud] to answer with. The rules know nothing about any of this. See
## docs/technical/rules-engine.md and docs/design/battle.md.

## The battle is over and the player has left the result.
signal finished

## How long the AI waits before each of its answers, in seconds, so the player can follow.
const AI_DELAY := 0.5
## How wide the HUD has to be, in its own units, to list all seven phases in the header.
const FULL_HEADER_WIDTH := 1300.0
## Values of what's held.
const WHOLE := -1
const NOTHING := -2

var map: BattleMap
var battle: Battle
var game: GameController
var hud: TurnHud
## Seconds the AI waits before answering; 0 answers on the next frame (tests).
var ai_delay := AI_DELAY
## Who commands each army, by [BattleArmy].
var participants := {}
## What the player is being asked, or null.
var request: DecisionRequest
var victory_panel: VictoryPanel

## How far through the event log the board has been brought up to date.
var _log_cursor := 0
## Where the models being moved or set up would go, before the player confirms.
var _preview := PackedVector2Array()
## What's held: [constant WHOLE] for the whole unit, a model's index, or [constant NOTHING].
var _held := NOTHING
## Whether clicking a model picks up just that model.
var single_model := false
var _ai_pending := false
## Units showing rings while a target or an action is being picked.
var _ringed: Array[BattleUnit] = []


func _init(on: BattleMap, with_game: GameController) -> void:
	map = on
	battle = on.battle
	game = with_game
	name = "BattleMapController"
	participants[battle.player] = PlayerParticipant.new()
	participants[battle.opponent] = AiParticipant.new()
	hud = TurnHud.create()
	hud.option_picked.connect(_on_option_picked)
	hud.pass_pressed.connect(_on_pass)
	hud.confirm_pressed.connect(_on_confirm)
	hud.reset_pressed.connect(_on_reset)
	hud.unit_picked.connect(_on_unit_picked)
	hud.choice_picked.connect(_on_choice_picked)


## Starts the battle. The HUD goes in [param overlay], under the header and menu.
func start(overlay: Node) -> void:
	overlay.add_child(hud)
	overlay.move_child(hud, 0)
	advance()


func _exit_tree() -> void:
	if game:
		game.dispose()
		game = null


# The loop

## Asks the battle what's next and passes it on.
func advance() -> void:
	if game == null:
		return
	request = null
	var next := game.next_decision()
	_catch_up()
	_refresh_header()
	if next == null:
		_show_result()
		return
	var participant: Participant = participants[next.army]
	if participant.answers_at_once():
		hud.show_waiting(game.side_name(next.army))
		_schedule_ai()
	else:
		request = next
		_show_request()


func _schedule_ai() -> void:
	if _ai_pending:
		return
	_ai_pending = true
	if ai_delay <= 0.0 or not is_inside_tree():
		_ai_turn.call_deferred()
	else:
		get_tree().create_timer(ai_delay).timeout.connect(_ai_turn)


func _ai_turn() -> void:
	_ai_pending = false
	if game == null:
		return
	var next := game.next_decision()
	if next == null:
		advance()
		return
	var reason := game.answer((participants[next.army] as Participant).decide(next, game))
	if not reason.is_empty():
		# Never stall the player's game on the AI's mistake.
		push_warning("The AI's answer was refused: %s" % reason)
		var fallback := Decision.pass_it() if next.can_pass or next.options.is_empty() else Decision.use(next.options[0])
		if not game.answer(fallback).is_empty():
			push_error("The AI can't answer: %s" % next.prompt)
			return
	advance()


## Hands the player's answer to the battle. If it's refused, the reason goes on the HUD.
func _answer(decision: Decision) -> void:
	var reason := game.answer(decision)
	if not reason.is_empty():
		hud.set_problems(PackedStringArray([reason]))
		return
	_clear_move()
	_clear_rings()
	advance()


# Showing what happened

## Brings the board and the log up to date with what's happened.
func _catch_up() -> void:
	var entries := game.events.log_entries
	while _log_cursor < entries.size():
		_show_event(entries[_log_cursor])
		_log_cursor += 1


func _show_event(event: BattleEvent) -> void:
	if not event.text().is_empty():
		hud.add_log(event.text())
	match event.kind:
		BattleEvent.UNIT_MOVED:
			_update_node(event.data.unit)
		BattleEvent.MODEL_SLAIN, BattleEvent.MODEL_RETURNED, BattleEvent.UNIT_SET_UP:
			_rebuild_node(event.data.unit)
		BattleEvent.UNIT_DESTROYED:
			_remove_node(event.data.unit)


func _update_node(unit: BattleUnit) -> void:
	var node: Node3D = map.unit_nodes.get(unit)
	if node:
		ModelPlaceholder.update_unit(node, unit)


## Its models' indices no longer match the instances, so it's built again.
func _rebuild_node(unit: BattleUnit) -> void:
	_remove_node(unit)
	if unit.is_on_battlefield():
		_add_node(unit)


func _add_node(unit: BattleUnit) -> void:
	var node := ModelPlaceholder.build_unit(unit, unit.facing, game.army_of(unit) == battle.player)
	map.armies_root.add_child(node)
	map.unit_nodes[unit] = node


func _remove_node(unit: BattleUnit) -> void:
	var node: Node3D = map.unit_nodes.get(unit)
	if node:
		map.unit_nodes.erase(unit)
		node.get_parent().remove_child(node)
		node.queue_free()


func _refresh_header() -> void:
	var state := game.state
	var steps := PackedStringArray()
	var current := -1
	for i in AbilityTiming.TURN_WINDOWS.size():
		var window: AbilityTiming.Moment = AbilityTiming.TURN_WINDOWS[i]
		steps.append(AbilityTiming.WINDOW_NAMES[window])
		if window == state.window:
			current = i
	if map.hud.size.x < FULL_HEADER_WIDTH:
		# No room for all seven at a large render scale: just the current one, in the badge.
		map.hud.set_phase("ROUND %d · %s" % [state.round_number, steps[current].to_upper()] if current >= 0 else "ROUND %d" % state.round_number)
	else:
		map.hud.set_phase("ROUND %d" % state.round_number, steps, current)
	map.hud.player_pill_label.text = _pill_text("You", battle.player)
	map.hud.opponent_pill_label.text = _pill_text("Opponent", battle.opponent)


func _pill_text(who: String, army: BattleArmy) -> String:
	var parts := PackedStringArray([who, "%d VP" % game.state.points_of(army)])
	if game.rules.uses_commands():
		parts.append("%d CP" % game.state.commands_of(army))
	if army == game.state.active:
		parts.append("turn")
	return " · ".join(parts)


func _show_result() -> void:
	hud.visible = false
	if victory_panel:
		return
	victory_panel = VictoryPanel.create(game.state, battle)
	victory_panel.closed.connect(finished.emit)
	map.overlay.add_child(victory_panel)


# Asking the player

func _show_request() -> void:
	match request.kind:
		DecisionRequest.Kind.ACTION, DecisionRequest.Kind.REACTION:
			hud.show_options(request, _unsupported_names())
		DecisionRequest.Kind.FIRST_TURN, DecisionRequest.Kind.CHOICE:
			hud.show_choices(request.prompt, request.choices)
		DecisionRequest.Kind.TARGETS:
			hud.show_units(request.prompt, request.units)
			_ring_units(request.units)
		DecisionRequest.Kind.ATTACK_TARGETS:
			var units := _attack_targets_of(request)
			hud.show_units(request.prompt, units)
			_ring_units(units)
		DecisionRequest.Kind.MOVE, DecisionRequest.Kind.SET_UP:
			_begin_move()


## What this phase can't do yet, for the HUD to say so.
func _unsupported_names() -> PackedStringArray:
	var names := PackedStringArray()
	if request.kind == DecisionRequest.Kind.ACTION and game.state.window >= 0:
		for entry in game.unsupported_in(game.state.window as AbilityTiming.Moment, request.army):
			var label := entry.ability.name
			if not label in names:
				names.append(label)
	return names


func _attack_targets_of(of: DecisionRequest) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	for weapon in of.weapons:
		for target: BattleUnit in of.weapon_targets[weapon]:
			if not target in units:
				units.append(target)
	return units


func _ring_units(units: Array[BattleUnit]) -> void:
	_clear_rings()
	for unit in units:
		var node: Node3D = map.unit_nodes.get(unit)
		if node:
			ModelPlaceholder.show_rings(node, unit, PackedInt32Array(), true, true)
			_ringed.append(unit)


func _clear_rings() -> void:
	for unit in _ringed:
		var node: Node3D = map.unit_nodes.get(unit)
		if node:
			ModelPlaceholder.show_rings(node, unit, PackedInt32Array(), false)
	_ringed.clear()


func _on_option_picked(option: ActionOption) -> void:
	if request:
		_answer(Decision.use(option))


func _on_pass() -> void:
	if request:
		_answer(Decision.pass_it())


func _on_choice_picked(index: int) -> void:
	if request:
		_answer(Decision.choose(index))


func _on_unit_picked(unit: BattleUnit) -> void:
	if request == null:
		return
	match request.kind:
		DecisionRequest.Kind.TARGETS:
			var picks: Array[BattleUnit] = [unit]
			_answer(Decision.pick(picks))
		DecisionRequest.Kind.ATTACK_TARGETS:
			_answer(Decision.attack(attack_all_at(request, unit)))


## Every weapon of the request at [param target] if it can reach it, or at the first it can.
static func attack_all_at(of: DecisionRequest, target: BattleUnit) -> Dictionary:
	var chosen := {}
	for weapon in of.weapons:
		var eligible: Array = of.weapon_targets[weapon]
		chosen[weapon] = target if target in eligible else eligible[0]
	return chosen


# Moving models

func _moving_unit() -> BattleUnit:
	if request == null:
		return null
	return request.move.unit if request.kind == DecisionRequest.Kind.MOVE else request.unit


func _begin_move() -> void:
	var unit := _moving_unit()
	_preview = unit.positions.duplicate()
	_held = NOTHING
	# A unit coming on from reserve has nothing on the board to move about yet.
	if not map.unit_nodes.has(unit):
		_add_node(unit)
	hud.show_move(request.prompt, request.can_pass, single_model)
	_validate_move()


func _clear_move() -> void:
	var unit := _moving_unit()
	if unit:
		var node: Node3D = map.unit_nodes.get(unit)
		if node:
			ModelPlaceholder.show_rings(node, unit, PackedInt32Array(), false)
			ModelPlaceholder.update_unit(node, unit)
		# It stayed in reserve.
		if not unit.is_on_battlefield():
			_remove_node(unit)
	_preview = PackedVector2Array()
	_held = NOTHING


func _on_confirm() -> void:
	if _is_moving():
		_answer(Decision.move_to(_preview))


func _on_reset() -> void:
	if _is_moving():
		_preview = _moving_unit().positions.duplicate()
		_held = NOTHING
		_validate_move()


func toggle_single_model() -> void:
	single_model = not single_model
	_held = NOTHING
	if request and request.kind == DecisionRequest.Kind.MOVE:
		hud.show_move(request.prompt, request.can_pass, single_model)


## Whether the models are where they can go, showing rings and reasons.
func _validate_move() -> void:
	var unit := _moving_unit()
	var problems := PackedStringArray()
	var invalid := PackedInt32Array()
	if request.kind == DecisionRequest.Kind.MOVE:
		problems = MovementRules.problems(game, request.move, _preview)
		invalid = _all_invalid(MovementRules.invalid_models(game, request.move, _preview))
	else:
		problems = game.set_up_problems(unit, _preview, request.min_enemy_gap, request.near_unit, request.near_reach)
	_draw_preview(unit, invalid)
	hud.set_problems(problems)
	hud.set_confirm_enabled(problems.is_empty())


## Every model in [param bad] ([method MovementRules.invalid_models]), once.
func _all_invalid(bad: Dictionary) -> PackedInt32Array:
	var invalid := PackedInt32Array()
	for key: String in bad:
		for i: int in bad[key]:
			if not i in invalid:
				invalid.append(i)
	return invalid


## Draws [param unit] where the preview has it, without changing the unit: the rules still need to
## know where it started.
func _draw_preview(unit: BattleUnit, invalid: PackedInt32Array) -> void:
	var node: Node3D = map.unit_nodes.get(unit)
	if node == null:
		return
	var real := unit.positions
	unit.positions = _preview
	ModelPlaceholder.update_unit(node, unit)
	ModelPlaceholder.show_rings(node, unit, invalid, true, _held != NOTHING)
	unit.positions = real


## Picks the models up at [param point], or moves them there if nothing is held.
func press(point: Vector2) -> void:
	if not _is_moving():
		return
	if single_model:
		_held = _preview_model_at(point)
		if _held == -1:
			_held = NOTHING
		return
	_held = WHOLE
	drag_to(point)


## Moves what's held to [param point], no further than it's allowed.
func drag_to(point: Vector2) -> void:
	if not _is_moving() or _held == NOTHING:
		return
	var unit := _moving_unit()
	if _held == WHOLE:
		var from := BattleGeometry.middle(unit)
		_preview = MovementRules.shifted(unit, _limited(point - from))
	else:
		_preview[_held] = unit.positions[_held] + _limited(point - unit.positions[_held])
	_validate_move()


func release() -> void:
	_held = NOTHING
	if _is_moving():
		_validate_move()


func _limited(by: Vector2) -> Vector2:
	if request.kind == DecisionRequest.Kind.SET_UP:
		return by
	return by.limit_length(request.move.max_distance)


func _is_moving() -> bool:
	return request != null and request.kind in [DecisionRequest.Kind.MOVE, DecisionRequest.Kind.SET_UP]


func _preview_model_at(point: Vector2) -> int:
	var unit := _moving_unit()
	var best := -1
	var best_distance := INF
	for i in _preview.size():
		var distance := _preview[i].distance_to(point)
		if distance <= DeploymentRules.reach_of(unit.bases[i]) and distance < best_distance:
			best = i
			best_distance = distance
	return best


## The unit on the board under [param point], or null.
func unit_at(point: Vector2) -> BattleUnit:
	for army in game.armies():
		for unit in game.on_battlefield(army):
			for i in unit.positions.size():
				if unit.positions[i].distance_to(point) <= DeploymentRules.reach_of(unit.bases[i]):
					return unit
	return null


func _unhandled_input(event: InputEvent) -> void:
	if request == null or game == null:
		return
	if _is_moving() and event.is_action_pressed("single_model_mode"):
		toggle_single_model()
		get_viewport().set_input_as_handled()
	elif _is_moving() and event.is_action_pressed("undo_placement"):
		_on_reset()
		get_viewport().set_input_as_handled()
	elif _pointer(event):
		get_viewport().set_input_as_handled()


## Handles the mouse on the board. Returns whether [param event] was used up here.
func _pointer(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion) or map.camera == null:
		return false
	var point: Variant = map.camera.ground_point(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if point == null:
			return false
		if event.pressed:
			_click(point)
		else:
			release()
		return true
	if event is InputEventMouseMotion and _held != NOTHING and point != null:
		drag_to(point)
		# The camera pans and turns with the right and middle buttons.
		return not event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)
	return false


func _click(point: Vector2) -> void:
	if _is_moving():
		press(point)
		return
	var unit := unit_at(point)
	if unit == null:
		return
	match request.kind:
		DecisionRequest.Kind.TARGETS:
			if unit in request.units:
				_on_unit_picked(unit)
		DecisionRequest.Kind.ATTACK_TARGETS:
			if unit in _attack_targets_of(request):
				_on_unit_picked(unit)
		DecisionRequest.Kind.ACTION, DecisionRequest.Kind.REACTION:
			hud.filter_options(unit)
