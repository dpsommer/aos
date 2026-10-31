class_name BattleMap
extends Node3D
## The game map: the battlefield at tabletop size with its territories, terrain, objectives and
## both armies, each model shown by its base, a camera and the overlay. [LoadingScreen] builds it a
## step at a time ([method build_steps]); Main then shows it. See docs/design/battle.md.

signal menu_requested

## The loading screen's checklist: each step belongs to one of these.
const STAGES: PackedStringArray = ["Battlefield", "Terrain", "Objectives", "Your models", "Opponent's models"]
enum Stage { BATTLEFIELD, TERRAIN, OBJECTIVES, PLAYER_MODELS, OPPONENT_MODELS }

var battle: Battle
var camera: BattleCamera
var hud: BattleHud
var terrain_root: Node3D
var objectives_root: Node3D
var armies_root: Node3D


## The steps that build the map for [param of], in order. Each is a dictionary with
## [code]stage[/code] (a [enum Stage]), [code]text[/code] (what the loading screen says, e.g.
## "Placing terrain features · 5 of 8") and [code]run[/code] (a [Callable]).
func build_steps(of: Battle) -> Array[Dictionary]:
	battle = of
	var steps: Array[Dictionary] = []
	steps.append(_step(Stage.BATTLEFIELD, "Preparing the battlefield", _build_battlefield))
	var terrain := battle.all_terrain()
	for i in terrain.size():
		steps.append(_step(Stage.TERRAIN, "Placing terrain features · %d of %d" % [i + 1, terrain.size()], _add_terrain.bind(terrain[i])))
	steps.append(_step(Stage.OBJECTIVES, "Placing objectives", _build_objectives))
	for side: Array in [[battle.player, true, Stage.PLAYER_MODELS, "your"], [battle.opponent, false, Stage.OPPONENT_MODELS, "the opponent's"]]:
		var army: BattleArmy = side[0]
		for i in army.units.size():
			steps.append(_step(side[2], "Setting up %s models · %d of %d" % [side[3], i + 1, army.units.size()],
					_add_unit.bind(army.units[i], army.facing, side[1])))
		if army.units.is_empty():
			steps.append(_step(side[2], "Setting up %s models" % side[3], func() -> void: pass))
	return steps


## Builds the whole map for [param of] at once.
func build(of: Battle) -> void:
	for step in build_steps(of):
		step.run.call()


func _step(stage: Stage, text: String, run: Callable) -> Dictionary:
	return {"stage": stage, "text": text, "run": run}


func _build_battlefield() -> void:
	PlaceholderDeployment.deploy(battle)
	add_child(BoardBuilder.board(battle.battlefield_size))
	if not battle.roads.is_empty():
		add_child(BoardBuilder.roads(battle.roads))
	add_child(BoardBuilder.territory(battle.player_territory, true))
	add_child(BoardBuilder.territory(battle.opponent_territory, false))
	terrain_root = _group("Terrain")
	objectives_root = _group("Objectives")
	armies_root = _group("Armies")
	camera = BattleCamera.new()
	camera.name = "BattleCamera"
	camera.bounds = Rect2(Vector2.ZERO, battle.battlefield_size)
	camera.frame(_bounds_of(battle.player_territory), battle.player.facing)
	add_child(camera)
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	hud = BattleHud.new(battle)
	hud.menu_pressed.connect(menu_requested.emit)
	layer.add_child(hud)
	add_child(layer)


func _add_terrain(feature: BattleTerrain) -> void:
	if feature.placed:
		terrain_root.add_child(TerrainPlaceholder.build(feature))


func _build_objectives() -> void:
	for objective in battle.objectives:
		objectives_root.add_child(BoardBuilder.objective(objective, battle.objective_radius(objective)))


func _add_unit(unit: BattleUnit, facing: float, is_player: bool) -> void:
	armies_root.add_child(ModelPlaceholder.build_unit(unit, facing, is_player))


func _group(group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	add_child(node)
	return node


func _bounds_of(polygons: Array[PackedVector2Array]) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, battle.battlefield_size)
	var first := true
	for polygon in polygons:
		for point in polygon:
			bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
			first = false
	return bounds


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()
