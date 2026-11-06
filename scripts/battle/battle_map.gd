class_name BattleMap
extends Node3D
## The game map: the battlefield at tabletop size with its terrain and objectives, a camera and the
## overlay. [LoadingScreen] builds it a step at a time ([method build_steps]); Main then shows it
## and calls [method start]: the roll-off decides who is the attacker; in Spearhead the attacker
## then picks its regiment ability and enhancement, then the defender, and the defender picks the
## side of the realm battlefield, the deployment map and the territories; the territories appear
## and the deployment phase sets both armies up ([DeploymentController]). See docs/design/battle.md.

## Surrender in the menu, once confirmed.
signal surrendered
## Save and Quit in the menu.
signal save_and_quit_requested
## Both armies are deployed.
signal deployment_finished
## The battle is over and the player has left the result.
signal battle_finished

## Where the battle is before the fighting starts.
enum Phase { BUILDING, ROLL_OFF, SPEARHEAD_OPTIONS, DEPLOYMENT_MAP, DEPLOYMENT, DEPLOYED, BATTLE }

const SETTINGS_SCENE := preload("res://scenes/ui/settings_screen.tscn")

## The loading screen's checklist: each step belongs to one of these.
const STAGES: PackedStringArray = ["Battlefield", "Terrain", "Objectives", "Your models", "Opponent's models"]
enum Stage { BATTLEFIELD, TERRAIN, OBJECTIVES, PLAYER_MODELS, OPPONENT_MODELS }

var battle: Battle
var camera: BattleCamera
var hud: BattleHud
var pause_menu: PauseMenu
## The Settings screen while it's open over the map, else null.
var settings_screen: SettingsScreen
var overlay: CanvasLayer
var terrain_root: Node3D
var objectives_root: Node3D
var armies_root: Node3D
var phase := Phase.BUILDING
## Picks the roll-off's dice, the AI's role, and in Spearhead the AI's regiment ability and
## enhancement and, if it defends, the battlefield.
var rng := RandomNumberGenerator.new()
var roll_off_panel: RollOffPanel
var options_picker: SpearheadOptionsPicker
var map_picker: DeploymentMapPicker
var deployment_controller: DeploymentController
## Runs the battle after deployment, or null before then.
var battle_controller: BattleMapController
## Each unit's models on the board, by unit: deployment adds them and the battle changes them.
var unit_nodes := {}
## Whether the menu is fading out after Resume.
var _menu_closing := false


func _init() -> void:
	rng.randomize()


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
	steps.append_array(_army_steps(battle.player, Stage.PLAYER_MODELS, "your"))
	steps.append_array(_army_steps(battle.opponent, Stage.OPPONENT_MODELS, "the opponent's"))
	return steps


## One step per unit in [param army], loading its 3D models so deployment doesn't stall on them,
## or a single empty step if it has none, so the loading screen's checklist still ticks off its
## stage. The units are set up later, in the deployment phase.
func _army_steps(army: BattleArmy, stage: Stage, whose: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for i in army.units.size():
		steps.append(_step(stage, "Preparing %s models · %d of %d" % [whose, i + 1, army.units.size()],
				_load_models.bind(army.units[i])))
	if army.units.is_empty():
		steps.append(_step(stage, "Setting up %s models" % whose, func() -> void: pass))
	return steps


## Builds the whole map for [param of] at once.
func build(of: Battle) -> void:
	for step in build_steps(of):
		step.run.call()


func _step(stage: Stage, text: String, run: Callable) -> Dictionary:
	return {"stage": stage, "text": text, "run": run}


func _build_battlefield() -> void:
	_add_board()
	terrain_root = _group("Terrain")
	objectives_root = _group("Objectives")
	armies_root = _group("Armies")
	camera = BattleCamera.new()
	camera.name = "BattleCamera"
	var battlefield := Rect2(Vector2.ZERO, battle.battlefield_size)
	camera.bounds = battlefield
	camera.frame(battlefield, PI / 2)
	add_child(camera)
	var hoverable: Array[Node3D] = [terrain_root, objectives_root, armies_root]
	add_child(MapHover.new(camera, hoverable))
	_build_overlay()
	if battle.has_territories():
		_show_territories()


## The board, with its realm battlefield side's printed board, or its roads if there's no image.
func _add_board() -> void:
	var printed := BoardBuilder.board_print(battle.realm.name) if battle.realm else null
	add_child(BoardBuilder.board(battle.battlefield_size, printed))
	# A printed board has its roads on it.
	if not battle.roads.is_empty() and printed == null:
		add_child(BoardBuilder.roads(battle.roads))


## Redraws the board, the battlefield's terrain and the objectives for the side of the realm
## battlefield the defender picked.
func _show_realm() -> void:
	for node_name in ["Board", "Roads"]:
		_remove_child_named(node_name)
	_add_board()
	for root: Node3D in [terrain_root, objectives_root]:
		for child in root.get_children():
			_remove(child)
	for feature in battle.all_terrain():
		_add_terrain(feature)
	_build_objectives()
	hud.set_title(battle.title)


## The overlay: the HUD and the menu, wired to open and close each other.
func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.name = "Overlay"
	hud = BattleHud.create(battle)
	hud.menu_pressed.connect(open_menu)
	overlay.add_child(hud)
	pause_menu = PauseMenu.create()
	pause_menu.resume_pressed.connect(close_menu)
	pause_menu.settings_pressed.connect(open_settings)
	pause_menu.surrender_pressed.connect(surrendered.emit)
	pause_menu.save_and_quit_pressed.connect(save_and_quit_requested.emit)
	overlay.add_child(pause_menu)
	add_child(overlay)


func _add_terrain(feature: BattleTerrain) -> void:
	if feature.placed:
		terrain_root.add_child(TerrainPlaceholder.build(feature))


func _build_objectives() -> void:
	for objective in battle.objectives:
		objectives_root.add_child(BoardBuilder.objective(objective, battle.objective_radius(objective)))


func _load_models(unit: BattleUnit) -> void:
	var library := ModelLibrary.shared()
	if library:
		library.meshes_for(ModelPlaceholder.model_names(unit))


## Starts the battle once the map is showing: the roll-off first.
func start() -> void:
	if phase != Phase.BUILDING or battle == null or overlay == null:
		return
	phase = Phase.ROLL_OFF
	battle.roll_off = RollOff.roll(rng)
	roll_off_panel = RollOffPanel.create(battle, battle.roll_off, RollOff.ai_picks_attacker(rng))
	roll_off_panel.role_chosen.connect(_on_role_chosen)
	_add_to_overlay(roll_off_panel)


## The roll-off is settled: the player is the attacker if [param player_attacks].
func _on_role_chosen(player_attacks: bool) -> void:
	if phase != Phase.ROLL_OFF:
		return
	_remove(roll_off_panel)
	roll_off_panel = null
	battle.assign_roles(player_attacks)
	hud.refresh_roles()
	if battle.is_spearhead():
		_next_spearhead_options()
	else:
		_begin_deployment()


## Spearhead's Pre-battle Sequence, step 2: the attacker picks its regiment ability and
## enhancement, then the defender (the AI at random, the player on [SpearheadOptionsPicker]).
## Once both have, the defender picks the battlefield.
func _next_spearhead_options() -> void:
	phase = Phase.SPEARHEAD_OPTIONS
	for army: BattleArmy in [battle.attacker(), battle.defender()]:
		if not army.needs_spearhead_options():
			continue
		if army == battle.player:
			_open_options_picker()
			return
		_ai_chooses_options(army)
	_choose_battlefield()


## The AI picks a regiment ability and an enhancement at random.
func _ai_chooses_options(army: BattleArmy) -> void:
	army.choose_spearhead_options(_random_name(army.spearhead.regiment_abilities), _random_name(army.spearhead.enhancements))


func _random_name(abilities: Array[Ability]) -> String:
	return _pick(abilities).name if not abilities.is_empty() else ""


## One of [param items] at random, from [member rng].
func _pick(items: Array) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)]


func _open_options_picker() -> void:
	options_picker = SpearheadOptionsPicker.create(battle.player, battle.opponent, battle.player_is_attacker)
	options_picker.chosen.connect(_on_options_chosen)
	_add_to_overlay(options_picker)


func _on_options_chosen(regiment_ability: String, enhancement: String) -> void:
	if phase != Phase.SPEARHEAD_OPTIONS:
		return
	_remove(options_picker)
	options_picker = null
	battle.player.choose_spearhead_options(regiment_ability, enhancement)
	_next_spearhead_options()


## Spearhead's Pre-battle Sequence, steps 3 and 4: the defender picks the side of the realm
## battlefield, the deployment map and the territories.
func _choose_battlefield() -> void:
	if battle.has_territories():
		_begin_deployment()
	elif battle.player_is_attacker:
		_ai_chooses_deployment()
	else:
		_open_map_picker()


## The AI defends: it picks the side (unless the setup named one), the deployment map and the
## territories at random.
func _ai_chooses_deployment() -> void:
	var pack := battle.battlepack
	var side: RealmBattlefield = battle.realm if battle.realm else _pick(pack.realms)
	_on_deployment_chosen(side, _pick(pack.deployment_maps), rng.randi_range(0, 1) == 0)


## The player defends: they pick the side, the deployment map and the territories.
func _open_map_picker() -> void:
	phase = Phase.DEPLOYMENT_MAP
	map_picker = DeploymentMapPicker.create(battle)
	map_picker.chosen.connect(_on_deployment_chosen)
	_add_to_overlay(map_picker)


func _on_deployment_chosen(side: RealmBattlefield, map: DeploymentMap, player_has_a: bool) -> void:
	if map_picker:
		_remove(map_picker)
		map_picker = null
	if side != battle.realm:
		battle.choose_realm(side)
		_show_realm()
	battle.choose_deployment(map, player_has_a)
	_begin_deployment()


func _begin_deployment() -> void:
	phase = Phase.DEPLOYMENT
	_show_territories()
	camera.frame(_bounds_of(battle.player_territory), battle.player.facing)
	deployment_controller = DeploymentController.new(self)
	deployment_controller.finished.connect(_on_deployed)
	add_child(deployment_controller)
	deployment_controller.start(overlay)


func _on_deployed() -> void:
	phase = Phase.DEPLOYED
	deployment_finished.emit()
	start_battle.call_deferred()


## Starts the battle rounds: the deployment HUD goes and the [BattleMapController] takes over.
func start_battle() -> void:
	if phase != Phase.DEPLOYED or not is_inside_tree():
		return
	phase = Phase.BATTLE
	deployment_controller.hud.visible = false
	# Deployment's shading has done its job.
	for node_name in ["PlayerTerritory", "OpponentTerritory", "NoDeploy"]:
		_remove_child_named(node_name)
	hud.set_extra_controls(PackedStringArray())
	hud.set_controls_bottom(0.0)
	camera.frame(Rect2(Vector2.ZERO, battle.battlefield_size), battle.player.facing)
	battle_controller = BattleMapController.new(self, GameController.new(battle, rng, null, deployment_controller.deployment))
	battle_controller.finished.connect(battle_finished.emit)
	add_child(battle_controller)
	battle_controller.start(overlay)


## Draws each side's territory, and the part of the player's they can't deploy units in.
func _show_territories() -> void:
	for node_name in ["PlayerTerritory", "OpponentTerritory", "NoDeploy"]:
		_remove_child_named(node_name)
	add_child(BoardBuilder.territory(battle.player_territory, true))
	add_child(BoardBuilder.territory(battle.opponent_territory, false))
	if battle.roles_assigned:
		show_no_deploy(false)


## Shades the part of the player's territory they can't set up in: for terrain features if
## [param terrain] (Spearhead's 3" from enemy territory and the long edges, and around terrain
## already set up: 6" in Spearhead, 3" in Matched Play), else for units (9" from enemy territory,
## 6" in Spearhead).
func show_no_deploy(terrain: bool) -> void:
	_remove_child_named("NoDeploy")
	var zone: Array[PackedVector2Array]
	# Terrain's is shaded without a label: the placing panel says where terrain can go.
	var text := ""
	var blocked: Array[PackedVector2Array] = []
	if terrain:
		zone = DeploymentRules.terrain_zone(battle, battle.player)
		blocked = DeploymentRules.terrain_keep_out(battle)
	else:
		zone = DeploymentRules.unit_zone(battle, battle.player)
		text = "Within %d\" of enemy territory" % int(DeploymentRules.unit_gap(battle))
	add_child(BoardBuilder.no_deploy(battle.player_territory, zone, text, battle.player.facing, blocked))


func _remove_child_named(node_name: String) -> void:
	_remove(get_node_or_null(node_name))


## Adds [param control] to the overlay under the menu.
func _add_to_overlay(control: Control) -> void:
	overlay.add_child(control)
	overlay.move_child(control, pause_menu.get_index())


func _remove(node: Node) -> void:
	if node and node.get_parent():
		node.get_parent().remove_child(node)
		node.queue_free()


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


## Whether the menu is open (Settings opens over it, so it's open then too).
func is_menu_open() -> bool:
	return pause_menu != null and pause_menu.visible and not _menu_closing


## Opens the menu: dims the battlefield, slides the header away and stops the camera.
func open_menu() -> void:
	if pause_menu == null:
		return
	_menu_closing = false
	pause_menu.open()
	hud.set_header_hidden(true)
	_set_map_controls_active(false)


## Closes the menu, bringing the header back and the camera with it.
func close_menu() -> void:
	if not is_menu_open():
		return
	_menu_closing = true
	pause_menu.close()
	hud.set_header_hidden(false)
	_set_map_controls_active(true)


## Opens the Settings screen over the menu. Its Back returns to the menu.
func open_settings() -> void:
	if settings_screen:
		return
	settings_screen = SETTINGS_SCENE.instantiate()
	settings_screen.back_pressed.connect(close_settings)
	overlay.add_child(settings_screen)


## Closes the Settings screen, back to the menu, showing any keys rebound there.
func close_settings() -> void:
	if settings_screen == null:
		return
	settings_screen.queue_free()
	settings_screen = null
	hud.refresh_controls()
	pause_menu.settings_button.grab_focus()


func _set_map_controls_active(active: bool) -> void:
	if camera:
		camera.set_process(active)
		camera.set_process_unhandled_input(active)
	if deployment_controller:
		deployment_controller.set_process_unhandled_input(active)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and pause_menu and not is_menu_open():
		get_viewport().set_input_as_handled()
		open_menu()
