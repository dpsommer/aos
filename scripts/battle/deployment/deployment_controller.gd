class_name DeploymentController
extends Node
## Runs the deployment phase on the game map: the [Deployment] rules, the AI's turns
## ([MirrorDeployer]), the [DeploymentHud], and placing units and terrain on the board with the
## mouse and keys. A unit or feature picked from the tray starts in a valid spot if there is one,
## picked up: it follows the mouse until a click puts it down. Pressing and dragging instead lines
## the unit up along the drag, from the press point, facing left of it, spread as wide as the drag
## and coherency allow (a terrain feature turns along the drag, about the press point). Clicking one
## of its models (or the feature) picks it up again; in single-model mode, just that model. Rings
## and outlines are blue where it can go while it's held, green once it's down, and red where it
## can't go. In Spearhead the player's whole army is set out at
## once, each unit in a valid spot if there is one; the player picks units up and moves them about,
## then confirms them all together. See docs/design/battle.md.

## Both armies are deployed.
signal finished

## How long the AI waits before each of its actions, in seconds, so the player can follow.
const AI_DELAY := 0.6
## How far the pointer moves, in pixels, before a press becomes a drag rather than a click.
const DRAG_PIXELS := 6.0
## Values of what's held.
const NOTHING := -2
const WHOLE := -1

var map: BattleMap
var battle: Battle
var deployment: Deployment
var mirror: MirrorDeployer
var hud: DeploymentHud
## Seconds the AI waits before acting; 0 acts at once (tests).
var ai_delay := AI_DELAY
## Each unit's models on the board, by unit.
var unit_nodes := {}
## Each terrain feature's node on the board, by feature.
var terrain_nodes := {}

## What the player is doing: see [method DeploymentHud.refresh].
var _state := {}
## Where the placement started, for Undo.
var _start_positions := PackedVector2Array()
var _start_facing := 0.0
var _start_at := Vector2.ZERO
## What's picked up: [constant WHOLE] for the whole unit or feature, a model's index for just that
## model, or [constant NOTHING].
var _held := NOTHING
## From the mouse to the middle of what's held, so it doesn't jump to the pointer.
var _hold_offset := Vector2.ZERO
var _ai_pending := false
## The step the board's no-deploy shading is for.
var _shaded_step := -1
## The player's units set out on the board but not yet deployed, in Spearhead (see
## [method stage_army]).
var _staged: Array[BattleUnit] = []
## Whether clicking a model picks up just that model rather than its whole unit.
var single_model := false
## Where the mouse was pressed on the board while holding something, or null: releasing puts it
## down, and dragging first lines it up ([method drag_to]).
var _press_at: Variant = null
## Where the press was on the screen, to tell a drag from a click.
var _press_screen := Vector2.ZERO
## Whether the press has become a drag.
var _dragged := false
## A held terrain feature's position and rotation when the press began, to turn it about the press
## point.
var _press_position := Vector2.ZERO
var _press_rotation := 0.0


func _init(on: BattleMap) -> void:
	map = on
	battle = on.battle
	name = "DeploymentController"
	deployment = Deployment.new(battle)
	mirror = MirrorDeployer.new(deployment, battle.opponent, battle.player)
	hud = DeploymentHud.new(deployment, battle.player)
	hud.unit_picked.connect(pick_unit)
	hud.regiment_picked.connect(pick_regiment)
	hud.terrain_picked.connect(pick_terrain)
	hud.ability_picked.connect(pick_ability)
	hud.single_model_toggled.connect(toggle_single_model)
	hud.target_toggled.connect(toggle_target)
	hud.confirm_pressed.connect(confirm)
	hud.undo_pressed.connect(undo)
	hud.cancel_pressed.connect(cancel)
	hud.call_off_pressed.connect(call_off_regiment)
	hud.pass_pressed.connect(pass_step)
	deployment.changed.connect(_on_changed)
	deployment.finished.connect(_on_finished)


## Starts the phase. The HUD goes in [param overlay], under the header and menu.
func start(overlay: Node) -> void:
	overlay.add_child(hud)
	overlay.move_child(hud, 0)
	for feature in battle.all_terrain():
		if feature.placed:
			terrain_nodes[feature] = null
	deployment.start()


## The player's army.
func player() -> BattleArmy:
	return battle.player


func is_player_turn() -> bool:
	return deployment.active == battle.player and not deployment.is_done()


# Picking what to place

## Starts placing [param unit], replacing anything being placed.
func pick_unit(unit: BattleUnit) -> void:
	if not is_player_turn() or not unit in deployment.pickable_units(player()):
		return
	if deployment.deploys_whole_army(player()):
		_pick_staged(unit)
		return
	_drop_placing()
	var positions := _starting_spot(unit)
	unit.positions = positions
	unit.facing = player().facing
	_start_positions = positions.duplicate()
	_start_facing = unit.facing
	_state = {"mode": "unit", "unit": unit}
	_add_unit_node(unit, true)
	_hold(WHOLE, Vector2.ZERO)
	_validate()
	_refresh_hud()


## Where [param unit] starts when it's picked or set out: a valid spot clear of [param staged] if
## there is one, else a block in the middle of the zone.
func _starting_spot(unit: BattleUnit, staged: Array[BattleUnit] = []) -> PackedVector2Array:
	var positions := PlaceholderDeployment.spot_for_unit(battle, player(), unit, [], staged)
	if positions.is_empty():
		var middle := PlaceholderDeployment.centroid(DeploymentRules.unit_zone(battle, player()))
		positions = Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, middle, player().facing)
	return positions


## Sets out every unit of the player's not yet deployed on the board at once, in Spearhead, each in
## a valid spot if there is one, without deploying them: the player moves them about, then
## confirms them all together. Units already set out keep where they are.
func stage_army() -> void:
	if not deployment.deploys_whole_army(player()):
		return
	_sync_staged()
	var new_units: Array[BattleUnit] = []
	for unit in deployment.pickable_units(player()):
		if not unit in _staged:
			new_units.append(unit)
	var spots := PlaceholderDeployment.spots_for_army(battle, player(), new_units, _staged)
	for unit in new_units:
		unit.facing = player().facing
		var positions: PackedVector2Array = spots.get(unit, PackedVector2Array())
		unit.positions = positions if not positions.is_empty() else _starting_spot(unit, _staged)
		_staged.append(unit)
		_add_unit_node(unit, true)
	_state = {"mode": "army", "unit": null}
	_held = NOTHING
	_validate()
	_refresh_hud()


## The units set out but not yet deployed, in Spearhead.
func staged_units() -> Array[BattleUnit]:
	return _staged.duplicate()


## Picks [param unit] of the army set out, for Undo.
func _pick_staged(unit: BattleUnit) -> void:
	if _state.get("mode") != "army":
		_drop_placing()
		stage_army()
	if not unit in _staged:
		return
	_select(unit)
	_validate()
	_refresh_hud()


func _select(unit: BattleUnit) -> void:
	_state.unit = unit
	_start_positions = unit.positions.duplicate()
	_start_facing = unit.facing


## Lets go of units set out that have since been deployed: set up, or put in reserve (taking them
## off the board).
func _sync_staged() -> void:
	for unit in _staged.duplicate():
		if unit.deployed:
			_staged.erase(unit)
			if not unit.is_on_battlefield():
				_free_node(unit_nodes, unit)


## Starts 'Deploy Regiment' for [param regiment], then places its first unit.
func pick_regiment(regiment: BattleRegiment) -> void:
	if not is_player_turn():
		return
	_drop_placing()
	if not deployment.begin_regiment(player(), regiment).is_empty():
		return
	var units := deployment.pickable_units(player())
	if not units.is_empty():
		pick_unit(units[0])


## Starts placing [param feature].
func pick_terrain(feature: BattleTerrain) -> void:
	if not is_player_turn() or deployment.step != Deployment.Step.TERRAIN or feature.placed or not feature in player().terrain:
		return
	_drop_placing()
	var spot := PlaceholderDeployment.first_terrain_spot(battle, player(), feature, deployment.is_cramped(player(), feature))
	feature.position = spot.get("at", PlaceholderDeployment.centroid(battle.territory_of(player())))
	feature.rotation = spot.get("rotation", player().facing + PI / 2)
	_start_at = feature.position
	_start_facing = feature.rotation
	_state = {"mode": "terrain", "feature": feature}
	_add_terrain_node(feature)
	_hold(WHOLE, Vector2.ZERO)
	_validate()
	_refresh_hud()


## Starts using [param entry]: picking its targets, or using it at once if it has a fixed target.
func pick_ability(entry: DeploymentAbility) -> void:
	if not deployment.can_use(player(), entry):
		return
	_drop_placing()
	var targets: Array[BattleUnit] = []
	var selected: Array[BattleUnit] = []
	var multi := entry.kind() == DeploymentAbility.Kind.RESERVE
	if multi:
		targets = deployment.reserve_targets(player(), entry)
		if entry.regiment or entry.targets_owner():
			selected = targets.duplicate()
	elif entry.owner:
		selected = [entry.owner]
	elif entry.ability.declare.to_lower().contains("pick"):
		for unit in player().units:
			if unit.deployed:
				targets.append(unit)
	_state = {"mode": "choose", "entry": entry, "targets": targets, "selected": selected, "multi": multi}
	_validate()
	_refresh_hud()


## Picks or unpicks [param unit] as a target of the ability being used.
func toggle_target(unit: BattleUnit) -> void:
	if _state.get("mode") != "choose":
		return
	var selected: Array[BattleUnit] = _state.selected
	if unit in selected:
		selected.erase(unit)
	elif _state.multi:
		selected.append(unit)
	else:
		selected.assign([unit])
	_validate()
	_refresh_hud()


# Arranging

## Moves what's being placed so its middle is at [param point].
func move_to(point: Vector2) -> void:
	match _state.get("mode"):
		"unit", "army":
			var unit := moving_unit()
			if unit == null:
				return
			_shift(unit, point - _middle(unit.positions))
			_moved()
		"terrain":
			var feature: BattleTerrain = _state.feature
			feature.position = point
			_moved()


## Moves model [param index] of the unit being placed by [param by], or the whole unit if
## [param index] is -1.
func move_model(index: int, by: Vector2) -> void:
	var unit := moving_unit()
	if unit == null:
		return
	if index < 0:
		_shift(unit, by)
	elif index < unit.positions.size():
		unit.positions[index] += by
	_moved()


## Puts what's being placed back where it started, and down.
func undo() -> void:
	_held = NOTHING
	match _state.get("mode"):
		"unit", "army":
			var unit := moving_unit()
			if unit == null:
				return
			unit.positions = _start_positions.duplicate()
			unit.facing = _start_facing
			_moved()
			_refresh_hud()
		"terrain":
			var feature: BattleTerrain = _state.feature
			feature.position = _start_at
			feature.rotation = _start_facing
			_moved()


## Stops what the player is doing without using anything.
func cancel() -> void:
	if _state.is_empty() and deployment.regiment and deployment.active == player():
		deployment.cancel_regiment(player())
		return
	_drop_placing()
	if deployment.deploys_whole_army(player()):
		stage_army()
		return
	_refresh_hud()


## Calls off 'Deploy Regiment' while none of its units is set up, dropping whatever is being
## placed.
func call_off_regiment() -> void:
	if not is_player_turn() or deployment.regiment == null or deployment.regiment.any_deployed():
		return
	_drop_placing()
	deployment.cancel_regiment(player())


## Commits what's being placed, or the ability being used. Returns why it couldn't, or empty.
func confirm() -> String:
	_held = NOTHING
	var placing := _state
	# Cleared first: the rules signal the change before returning, and the next pick depends on it.
	_state = {}
	var error := _commit(placing)
	if not error.is_empty():
		_state = placing
		hud.set_problems(PackedStringArray([error]))
	return error


## Hands what [param placing] holds to the rules. Returns why they refused it, or empty.
func _commit(placing: Dictionary) -> String:
	match placing.get("mode"):
		"unit":
			var unit: BattleUnit = placing.unit
			var error := deployment.place_unit(player(), unit, unit.positions, unit.facing)
			if error.is_empty():
				_settle_rings(unit)
			return error
		"army":
			var units: Array[BattleUnit] = _staged.duplicate()
			var error := deployment.place_army(player(), units)
			if error.is_empty():
				for unit: BattleUnit in units:
					_settle_rings(unit)
			return error
		"terrain":
			var feature: BattleTerrain = placing.feature
			var node: Node3D = terrain_nodes[feature]
			var error := deployment.place_terrain(player(), feature, feature.position, feature.rotation)
			if error.is_empty():
				_remove_terrain_ring(node)
			return error
		"choose":
			var entry: DeploymentAbility = placing.entry
			var selected: Array[BattleUnit] = placing.selected
			if entry.kind() == DeploymentAbility.Kind.RESERVE:
				return deployment.reserve(player(), entry, selected)
			return deployment.record(player(), entry, selected[0] if not selected.is_empty() else null)
	return "Nothing to confirm."


## Shows [param unit]'s rings as set up: valid and not held.
func _settle_rings(unit: BattleUnit) -> void:
	ModelPlaceholder.show_rings(unit_nodes[unit], unit, PackedInt32Array(), false)


## The player is done with the abilities step.
func pass_step() -> void:
	if is_player_turn():
		_drop_placing()
		deployment.pass_step(player())


# Input

## Whether something is picked up, following the mouse.
func is_holding() -> bool:
	return _held != NOTHING


## A quick click on the board at [param point]: puts down what's held where it is, or picks up
## what's under it (just one model in single-model mode, or if [param single]).
func click(point: Vector2, single := false) -> void:
	if is_holding():
		put_down()
		return
	single = single or single_model
	match _state.get("mode"):
		"unit":
			_pick_up(_state.unit, point, single)
		"army":
			var unit := staged_unit_at(point)
			if unit == null:
				return
			if unit != _state.unit:
				_select(unit)
			_pick_up(unit, point, single)
			_refresh_hud()
		"terrain":
			var feature: BattleTerrain = _state.feature
			if Geometry2D.is_point_in_polygon(point, DeploymentRules.terrain_outline(feature, feature.position, feature.rotation)):
				_hold(WHOLE, feature.position - point)


## Picks up [param unit] (or just its model under [param point], if [param single]) by the model
## under [param point], if there is one.
func _pick_up(unit: BattleUnit, point: Vector2, single: bool) -> void:
	var index := _model_index(unit, point)
	if index < 0:
		return
	if single:
		_hold(index, unit.positions[index] - point)
	else:
		_hold(WHOLE, _middle(unit.positions) - point)


## The mouse button goes down at [param point] on the board. While holding something, it waits to
## see whether this is a click or a drag ([method drag_to], [method release]); otherwise it picks up
## what's under the pointer.
func press(point: Vector2) -> void:
	if not is_holding():
		click(point)
		return
	_press_at = point
	_dragged = false
	if _state.get("mode") == "terrain":
		var feature: BattleTerrain = _state.feature
		_press_position = feature.position
		_press_rotation = feature.rotation
	_refresh_hud()


## Whether the mouse button is down after a press while holding something.
func is_pressing() -> bool:
	return _press_at != null


## The pointer is dragged to [param point] after [method press]: a held unit is lined up from the
## press point to here ([method orient]), a held terrain feature turned along the drag. A single
## model held stays where it is.
func drag_to(point: Vector2) -> void:
	if not is_pressing() or not is_holding():
		return
	_dragged = true
	orient(_press_at, point)


## The mouse button comes up: what's held is put down, lined up if it was dragged.
func release() -> void:
	if not is_pressing():
		return
	_press_at = null
	_dragged = false
	put_down()


## Lines what's held up along the line [param from] to [param to]. A unit stands with its front
## rank running from [param from] towards [param to], as wide as that is (as far as coherency
## allows, and in a deep column if it's short), facing left of the line: dragged left to right,
## it faces up the screen. A terrain feature's length turns along the line, about [param from].
func orient(from: Vector2, to: Vector2) -> void:
	var line := to - from
	if line.length() < 0.01:
		return
	match _state.get("mode"):
		"unit", "army":
			var unit := moving_unit()
			if unit == null or _held != WHOLE:
				return
			var facing := line.angle() - PI / 2
			unit.positions = Formations.spread(unit.bases, from, facing, line.length())
			unit.facing = facing
			_moved()
		"terrain":
			var feature: BattleTerrain = _state.feature
			feature.rotation = line.angle()
			feature.position = from + (_press_position - from).rotated(feature.rotation - _press_rotation)
			_moved()


## Turns single-model mode on or off: clicking a model picks up just that model.
func toggle_single_model() -> void:
	single_model = not single_model
	_refresh_hud()


## The mouse is over [param point] on the board: what's held follows it.
func hover(point: Vector2) -> void:
	if not is_holding() or is_pressing():
		return
	if _held == WHOLE:
		move_to(point + _hold_offset)
	elif moving_unit():
		move_model(_held, point + _hold_offset - moving_unit().positions[_held])


## Puts down what's held where it is.
func put_down() -> void:
	_press_at = null
	_dragged = false
	if not is_holding():
		return
	_held = NOTHING
	_validate()
	_refresh_hud()


func _hold(what: int, offset: Vector2) -> void:
	_held = what
	_hold_offset = offset
	_validate()


func _unhandled_input(event: InputEvent) -> void:
	if not is_player_turn():
		return
	if event.is_action_pressed("undo_placement"):
		undo()
	elif event.is_action_pressed("single_model_mode") and _is_placing_units():
		toggle_single_model()
	elif not _pointer(event):
		return
	get_viewport().set_input_as_handled()


## Handles the left button going down or up, or a mouse move while holding something, on the
## board. Returns whether [param event] was one.
func _pointer(event: InputEvent) -> bool:
	var point: Variant = null
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and map.camera:
		point = map.camera.ground_point(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and point != null:
			_press_screen = event.position
			press(point)
		elif not event.pressed and is_pressing():
			release()
		else:
			return false
		return true
	if point == null or not event is InputEventMouseMotion or not is_holding():
		return false
	if is_pressing():
		# A small wobble during a click isn't a drag.
		if _dragged or event.position.distance_to(_press_screen) > DRAG_PIXELS:
			drag_to(point)
	else:
		hover(point)
	return true


## The unit being moved: the one being placed, or the one picked in the army set out; null if none.
func moving_unit() -> BattleUnit:
	return _state.get("unit") if _is_placing_units() else null


## Whether the player is placing a unit or arranging an army set out, rather than terrain or an
## ability.
func _is_placing_units() -> bool:
	return _state.get("mode") in ["unit", "army"]


## The model of the unit being placed under [param point], or -1.
func model_at(point: Vector2) -> int:
	var unit := moving_unit()
	return _model_index(unit, point) if unit else -1


## The unit set out under [param point], the picked one first, or null.
func staged_unit_at(point: Vector2) -> BattleUnit:
	var picked := moving_unit()
	if picked and _model_index(picked, point) >= 0:
		return picked
	for unit in _staged:
		if _model_index(unit, point) >= 0:
			return unit
	return null


## The model of [param unit] under [param point], the nearest if several, or -1.
func _model_index(unit: BattleUnit, point: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for i in unit.positions.size():
		var distance := unit.positions[i].distance_to(point)
		if distance <= DeploymentRules.reach_of(unit.bases[i]) and distance < best_distance:
			best = i
			best_distance = distance
	return best


# Keeping the board and the HUD in step

func _shift(unit: BattleUnit, by: Vector2) -> void:
	for i in unit.positions.size():
		unit.positions[i] += by


func _middle(positions: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for position in positions:
		total += position
	return total / maxi(positions.size(), 1)


## Redraws what's being placed where it now is, and checks it.
func _moved() -> void:
	match _state.get("mode"):
		"unit", "army":
			var unit := moving_unit()
			if unit:
				ModelPlaceholder.update_unit(unit_nodes[unit], unit)
		"terrain":
			var feature: BattleTerrain = _state.feature
			var node: Node3D = terrain_nodes[feature]
			node.position = ModelPlaceholder.to_world(feature.position)
			node.rotation.y = ModelPlaceholder.yaw(feature.rotation)
	_validate()


## Checks what's being placed, showing its problems and its rings.
func _validate() -> void:
	var problems := PackedStringArray()
	match _state.get("mode"):
		"unit":
			var unit: BattleUnit = _state.unit
			var bad := DeploymentRules.invalid_models(battle, player(), unit, unit.positions, unit.facing)
			ModelPlaceholder.show_rings(unit_nodes[unit], unit, _all_invalid(bad), true, is_holding())
			problems = DeploymentRules.unit_problems(battle, player(), unit, unit.positions, unit.facing)
		"army":
			problems = _validate_army()
		"terrain":
			var feature: BattleTerrain = _state.feature
			problems = deployment.terrain_problems(player(), feature, feature.position, feature.rotation)
			_terrain_outline(terrain_nodes[feature], feature, problems.is_empty())
		"choose":
			if _state.multi and _state.selected.is_empty():
				problems.append("Pick at least one unit.")
	_state["problems"] = problems
	hud.set_problems(problems)


## Checks every unit set out against the rules and each other, ringing each model, and returns
## their problems, each starting with its unit's name.
func _validate_army() -> PackedStringArray:
	var problems := PackedStringArray()
	var zone := DeploymentRules.unit_zone(battle, player())
	for unit in _staged:
		var bad := DeploymentRules.invalid_models(battle, player(), unit, unit.positions, unit.facing, zone, _staged)
		var held := is_holding() and unit == moving_unit()
		ModelPlaceholder.show_rings(unit_nodes[unit], unit, _all_invalid(bad), true, held)
		for problem in DeploymentRules.unit_problems(battle, player(), unit, unit.positions, unit.facing, zone, _staged):
			problems.append("%s: %s" % [unit.name, problem])
	return problems


## Every model in [param bad] ([method DeploymentRules.invalid_models]), once.
func _all_invalid(bad: Dictionary) -> PackedInt32Array:
	var invalid := PackedInt32Array()
	for key in ["outside", "overlapping", "incoherent"]:
		for i: int in bad[key]:
			if not i in invalid:
				invalid.append(i)
	return invalid


## The outline of [param feature] being placed, around its footprint: coloured by
## [method ModelPlaceholder.ring_colour].
func _terrain_outline(node: Node3D, feature: BattleTerrain, valid: bool) -> void:
	var ring := node.get_node_or_null("Ring") as MeshInstance3D
	if ring == null:
		ring = MeshInstance3D.new()
		ring.name = "Ring"
		# In the node's own frame, which turns with the feature: x along its rotation.
		ring.mesh = ModelPlaceholder.outline_mesh(DeploymentRules.terrain_outline(feature, Vector2.ZERO, 0.0), ModelPlaceholder.RING_HEIGHT)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.material_override = ModelPlaceholder.marker_material()
		node.add_child(ring)
	ring.material_override.albedo_color = ModelPlaceholder.ring_colour(valid, is_holding())


func _remove_terrain_ring(node: Node3D) -> void:
	var ring := node.get_node_or_null("Ring")
	if ring:
		node.remove_child(ring)
		ring.queue_free()


## Takes back whatever is being placed (not yet confirmed) off the board.
func _drop_placing() -> void:
	match _state.get("mode"):
		"unit":
			var unit: BattleUnit = _state.unit
			if not unit.deployed:
				unit.positions = PackedVector2Array()
				_free_node(unit_nodes, unit)
		"terrain":
			var feature: BattleTerrain = _state.feature
			if not feature.placed:
				_free_node(terrain_nodes, feature)
	_state = {}
	_held = NOTHING
	_press_at = null
	_dragged = false


func _free_node(nodes: Dictionary, key: Variant) -> void:
	var node: Node = nodes.get(key)
	nodes.erase(key)
	if node:
		node.get_parent().remove_child(node)
		node.queue_free()


## Adds to the board whatever the rules have set up that isn't drawn yet: the AI's units and
## terrain, mostly.
func _sync_board() -> void:
	for army in [battle.player, battle.opponent]:
		for unit: BattleUnit in army.units:
			if unit.is_on_battlefield() and not unit_nodes.has(unit):
				_add_unit_node(unit, army == battle.player)
		for feature: BattleTerrain in army.terrain:
			if feature.placed and not terrain_nodes.has(feature):
				_add_terrain_node(feature)


func _add_unit_node(unit: BattleUnit, is_player: bool) -> void:
	var node := ModelPlaceholder.build_unit(unit, unit.facing, is_player)
	map.armies_root.add_child(node)
	unit_nodes[unit] = node


func _add_terrain_node(feature: BattleTerrain) -> void:
	var node := TerrainPlaceholder.build(feature)
	map.terrain_root.add_child(node)
	terrain_nodes[feature] = node


func _refresh_hud() -> void:
	var state := _state.duplicate()
	state["busy"] = not is_player_turn()
	state["single"] = single_model
	hud.refresh(state)
	if not _state.is_empty() and _state.has("problems"):
		hud.set_problems(_state.problems)
	map.hud.refresh_roles(deployment.remaining(battle.player), deployment.remaining(battle.opponent))
	var current := mini(deployment.step, deployment.step_names().size())
	map.hud.set_phase("DEPLOYMENT", deployment.step_names(), current)
	map.hud.set_controls_bottom(DeploymentHud.TRAY_HEIGHT + 14 if hud.is_tray_visible() else 0.0)
	map.hud.set_extra_controls(_placing_keys() if _state.get("mode") in ["unit", "terrain", "army"] else PackedStringArray())


func _placing_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	var is_unit := _is_placing_units()
	if is_holding():
		keys.append("Click  put down")
		if _held == WHOLE:
			keys.append("Drag  line up and face left of the drag" if is_unit else "Drag  turn along the drag")
	else:
		keys.append("Click  pick up model" if is_unit and single_model else "Click  pick up")
	if is_unit:
		keys.append("%s  single-model mode: %s" % [BattleHud.key_for("single_model_mode"), "on" if single_model else "off"])
	keys.append("%s  undo" % BattleHud.key_for("undo_placement"))
	return keys


func _on_changed() -> void:
	_sync_staged()
	_sync_board()
	if deployment.step != _shaded_step:
		_shaded_step = deployment.step
		map.show_no_deploy(deployment.step == Deployment.Step.TERRAIN)
	if not is_player_turn():
		_drop_placing()
	elif _state.is_empty():
		_start_next_pick()
	_refresh_hud()
	if deployment.active == battle.opponent and not deployment.is_done():
		_schedule_ai()


## On the player's turn with nothing picked, picks up what they must place next, if anything.
func _start_next_pick() -> void:
	if deployment.deploys_whole_army(player()):
		# Spearhead: the whole army is set out at once, to move about and confirm together.
		stage_army()
	elif deployment.step == Deployment.Step.TERRAIN:
		var unplaced := player().unplaced_terrain()
		if not unplaced.is_empty():
			# There's nothing else to do in this step: start placing the next feature.
			pick_terrain.call_deferred(unplaced[0])
	elif deployment.regiment and deployment.active == player():
		var next := deployment.pickable_units(player())
		if not next.is_empty():
			pick_unit.call_deferred(next[0])


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
	if deployment.active != battle.opponent or deployment.is_done():
		return
	if not mirror.take_turn():
		# The AI couldn't act: pass it along rather than stall.
		push_warning("The AI couldn't take its deployment turn.")


func _on_finished() -> void:
	_drop_placing()
	_sync_board()
	_refresh_hud()
	finished.emit()
