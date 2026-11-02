class_name DeploymentController
extends Node
## Runs the deployment phase on the game map: the [Deployment] rules, the AI's turns
## ([MirrorDeployer]), the [DeploymentHud], and placing units and terrain on the board with the
## mouse and keys. A unit or feature picked from the tray starts in a valid spot if there is one,
## picked up: it follows the mouse until a click puts it down. Clicking one of its models (or the
## feature) picks it up again; Alt-clicking picks up just that model. The formation keys rearrange
## it and the turn key turns it. Rings and outlines are blue where it can go while it's held, green
## once it's down, and red where it can't go. See docs/design/battle.md.

## Both armies are deployed.
signal finished

## How long the AI waits before each of its actions, in seconds, so the player can follow.
const AI_DELAY := 0.6
## How far the turn key turns a unit or terrain feature.
const TURN_STEP := PI / 12
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
	hud.formation_picked.connect(set_formation)
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
	_drop_placing()
	var positions := PlaceholderDeployment.spot_for_unit(battle, player(), unit)
	if positions.is_empty():
		var middle := PlaceholderDeployment.centroid(DeploymentRules.unit_zone(battle, player()))
		positions = Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, middle, player().facing)
	unit.positions = positions
	unit.facing = player().facing
	_start_positions = positions.duplicate()
	_start_facing = unit.facing
	_state = {"mode": "unit", "unit": unit, "formation": -1}
	var node := ModelPlaceholder.build_unit(unit, unit.facing, true)
	map.armies_root.add_child(node)
	unit_nodes[unit] = node
	_hold(WHOLE, Vector2.ZERO)
	_validate()
	_refresh_hud()


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
	var node := TerrainPlaceholder.build(feature)
	map.terrain_root.add_child(node)
	terrain_nodes[feature] = node
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

## Arranges the unit being placed in formation [param kind] around its middle.
func set_formation(kind: int) -> void:
	if _state.get("mode") != "unit":
		return
	var unit: BattleUnit = _state.unit
	if unit.model_count() < 2:
		return
	unit.positions = Formations.arrange(kind as Formations.Kind, unit.bases, _middle(unit.positions), unit.facing)
	_state.formation = kind
	_moved()
	_refresh_hud()


## Turns what's being placed by [param amount] radians, clockwise.
func turn(amount: float) -> void:
	match _state.get("mode"):
		"unit":
			var unit: BattleUnit = _state.unit
			var middle := _middle(unit.positions)
			for i in unit.positions.size():
				unit.positions[i] = middle + (unit.positions[i] - middle).rotated(amount)
			unit.facing += amount
			_moved()
		"terrain":
			var feature: BattleTerrain = _state.feature
			feature.rotation += amount
			_moved()


## Moves what's being placed so its middle is at [param point].
func move_to(point: Vector2) -> void:
	match _state.get("mode"):
		"unit":
			var unit: BattleUnit = _state.unit
			_shift(unit, point - _middle(unit.positions))
			_moved()
		"terrain":
			var feature: BattleTerrain = _state.feature
			feature.position = point
			_moved()


## Moves model [param index] of the unit being placed by [param by], or the whole unit if
## [param index] is -1.
func move_model(index: int, by: Vector2) -> void:
	if _state.get("mode") != "unit":
		return
	var unit: BattleUnit = _state.unit
	if index < 0:
		_shift(unit, by)
	elif index < unit.positions.size():
		unit.positions[index] += by
		_state.formation = -1
	_moved()


## Puts what's being placed back where it started, and down.
func undo() -> void:
	_held = NOTHING
	match _state.get("mode"):
		"unit":
			var unit: BattleUnit = _state.unit
			unit.positions = _start_positions.duplicate()
			unit.facing = _start_facing
			_state.formation = -1
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
	var error := ""
	match placing.get("mode"):
		"unit":
			var unit: BattleUnit = placing.unit
			error = deployment.place_unit(player(), unit, unit.positions, unit.facing)
			if error.is_empty():
				ModelPlaceholder.show_rings(unit_nodes[unit], unit, PackedInt32Array(), false)
		"terrain":
			var feature: BattleTerrain = placing.feature
			var node: Node3D = terrain_nodes[feature]
			error = deployment.place_terrain(player(), feature, feature.position, feature.rotation)
			if error.is_empty():
				_remove_terrain_ring(node)
		"choose":
			var entry: DeploymentAbility = placing.entry
			var selected: Array[BattleUnit] = placing.selected
			if entry.kind() == DeploymentAbility.Kind.RESERVE:
				error = deployment.reserve(player(), entry, selected)
			else:
				error = deployment.record(player(), entry, selected[0] if not selected.is_empty() else null)
		_:
			error = "Nothing to confirm."
	if not error.is_empty():
		_state = placing
		hud.set_problems(PackedStringArray([error]))
	return error


## The player is done with the abilities step.
func pass_step() -> void:
	if is_player_turn():
		_drop_placing()
		deployment.pass_step(player())


# Input

## Whether something is picked up, following the mouse.
func is_holding() -> bool:
	return _held != NOTHING


## A click on the board at [param point]: puts down what's held, or picks up what's under it (just
## one model if [param single]).
func click(point: Vector2, single := false) -> void:
	if is_holding():
		put_down()
		return
	match _state.get("mode"):
		"unit":
			var unit: BattleUnit = _state.unit
			var index := model_at(point)
			if index < 0:
				return
			if single:
				_hold(index, unit.positions[index] - point)
			else:
				_hold(WHOLE, _middle(unit.positions) - point)
		"terrain":
			var feature: BattleTerrain = _state.feature
			if Geometry2D.is_point_in_polygon(point, DeploymentRules.terrain_outline(feature, feature.position, feature.rotation)):
				_hold(WHOLE, feature.position - point)


## The mouse is over [param point] on the board: what's held follows it.
func hover(point: Vector2) -> void:
	if not is_holding():
		return
	if _held == WHOLE:
		move_to(point + _hold_offset)
	elif _state.get("mode") == "unit":
		var unit: BattleUnit = _state.unit
		move_model(_held, point + _hold_offset - unit.positions[_held])


## Puts down what's held where it is.
func put_down() -> void:
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
	elif event.is_action_pressed("rotate_selection"):
		turn(TURN_STEP)
	else:
		for kind in Formations.Kind.size():
			if event.is_action_pressed("formation_%d" % (kind + 1)):
				set_formation(kind)
				get_viewport().set_input_as_handled()
				return
		var point: Variant = null
		if (event is InputEventMouseButton or event is InputEventMouseMotion) and map.camera:
			point = map.camera.ground_point(event.position)
		if point == null:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			click(point, event.alt_pressed)
		elif event is InputEventMouseMotion and is_holding():
			hover(point)
		else:
			return
	get_viewport().set_input_as_handled()


## The model of the unit being placed under [param point], or -1.
func model_at(point: Vector2) -> int:
	if _state.get("mode") != "unit":
		return -1
	var unit: BattleUnit = _state.unit
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
		"unit":
			var unit: BattleUnit = _state.unit
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
			var invalid := PackedInt32Array()
			for key in ["outside", "overlapping", "incoherent"]:
				for i: int in bad[key]:
					if not i in invalid:
						invalid.append(i)
			ModelPlaceholder.show_rings(unit_nodes[unit], unit, invalid, true, is_holding())
			problems = DeploymentRules.unit_problems(battle, player(), unit, unit.positions, unit.facing)
		"terrain":
			var feature: BattleTerrain = _state.feature
			problems = deployment.terrain_problems(player(), feature, feature.position, feature.rotation)
			_terrain_outline(terrain_nodes[feature], feature, problems.is_empty())
		"choose":
			if _state.multi and _state.selected.is_empty():
				problems.append("Pick at least one unit.")
	_state["problems"] = problems
	hud.set_problems(problems)


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
				var node := ModelPlaceholder.build_unit(unit, unit.facing, army == battle.player)
				map.armies_root.add_child(node)
				unit_nodes[unit] = node
		for feature: BattleTerrain in army.terrain:
			if feature.placed and not terrain_nodes.has(feature):
				var node := TerrainPlaceholder.build(feature)
				map.terrain_root.add_child(node)
				terrain_nodes[feature] = node


func _refresh_hud() -> void:
	var state := _state.duplicate()
	state["busy"] = not is_player_turn()
	hud.refresh(state)
	if not _state.is_empty() and _state.has("problems"):
		hud.set_problems(_state.problems)
	map.hud.refresh_roles(deployment.remaining(battle.player), deployment.remaining(battle.opponent))
	var current := mini(deployment.step, deployment.step_names().size())
	map.hud.set_phase("DEPLOYMENT", deployment.step_names(), current)
	map.hud.set_controls_bottom(DeploymentHud.TRAY_HEIGHT + 14 if hud.is_tray_visible() else 0.0)
	map.hud.set_extra_controls(_placing_keys() if _state.get("mode") in ["unit", "terrain"] else PackedStringArray())


func _placing_keys() -> PackedStringArray:
	var keys := PackedStringArray(["Click  put down" if is_holding() else "Click  pick up",
			"%s  turn" % BattleHud.key_for("rotate_selection"), "%s  undo" % BattleHud.key_for("undo_placement")])
	if _state.get("mode") == "unit":
		keys.insert(0, "Click / Alt-click  pick up unit / model")
		keys.append("%s–%s  formation" % [BattleHud.key_for("formation_1"), BattleHud.key_for("formation_5")])
	return keys


func _on_changed() -> void:
	_sync_board()
	if deployment.step != _shaded_step:
		_shaded_step = deployment.step
		map.show_no_deploy(deployment.step == Deployment.Step.TERRAIN)
	if not is_player_turn():
		_drop_placing()
	elif _state.is_empty() and deployment.step == Deployment.Step.TERRAIN:
		var unplaced := player().unplaced_terrain()
		if not unplaced.is_empty():
			# There's nothing else to do in this step: start placing the next feature.
			pick_terrain.call_deferred(unplaced[0])
	elif _state.is_empty() and deployment.regiment and deployment.active == player():
		var next := deployment.pickable_units(player())
		if not next.is_empty():
			pick_unit.call_deferred(next[0])
	_refresh_hud()
	if deployment.active == battle.opponent and not deployment.is_done():
		_schedule_ai()


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
