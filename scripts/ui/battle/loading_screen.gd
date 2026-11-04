class_name LoadingScreen
extends Control
## Shown between Quick Play's Play and the game map: the matchup, the battleplan (its map with
## territories neutral, as the roll-off hasn't happened) and a progress bar while the map is built a
## step at a time. When it's done it emits [signal finished] with the map, which Main shows. See
## docs/design/battle.md.

signal finished(map: BattleMap)
## The battle couldn't be set up, e.g. its faction data is missing.
signal failed(message: String)

const BATTLE_MAP_SCENE := preload("res://scenes/battle/battle_map.tscn")
## Shortest time the screen shows, so it can be read.
const MIN_SECONDS := 1.5
## Most time per frame spent building, so the screen stays responsive.
const FRAME_BUDGET_MSEC := 12
const MAP_SIZE := Vector2(360, 264)

var min_seconds := MIN_SECONDS
var battle: Battle
## The map being built; it belongs to this screen until [signal finished] hands it over.
var map: BattleMap
var steps: Array[Dictionary] = []
## How many steps have run.
var done := 0

var step_label: Label
var percent_label: Label
var progress_bar: ProgressBar
## A label per [constant BattleMap.STAGES].
var stage_labels: Array[Label] = []
var spinner: Spinner
var _elapsed := 0.0
var _handed_over := false


func _ready() -> void:
	theme = UITheme.get_theme()


## Sets up the battle for [param setup] and starts building its map. [param rng] picks Random
## choices; it defaults to a randomly seeded one.
func open(setup: BattleSetup, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	battle = BattleBuilder.build(setup, rng)
	if battle == null:
		set_process(false)
		failed.emit.call_deferred("The battle couldn't be set up: its army or battleplan data is missing.")
		return
	map = BATTLE_MAP_SCENE.instantiate()
	steps = map.build_steps(battle)
	_build_layout()
	_update()


## Runs the next step. Returns whether any are left.
func advance() -> bool:
	if done < steps.size():
		steps[done].run.call()
		done += 1
		_update()
	return done < steps.size()


## How much of the map is built, from 0 to 1.
func progress() -> float:
	return float(done) / steps.size() if not steps.is_empty() else 0.0


## Builds the rest of the map at once and hands it over.
func finish() -> void:
	while advance():
		pass
	_hand_over()


func _process(delta: float) -> void:
	if battle == null or _handed_over:
		return
	_elapsed += delta
	var start := Time.get_ticks_msec()
	while done < steps.size() and Time.get_ticks_msec() - start < FRAME_BUDGET_MSEC:
		advance()
	if done >= steps.size() and _elapsed >= min_seconds:
		_hand_over()


func _hand_over() -> void:
	if _handed_over or map == null:
		return
	_handed_over = true
	finished.emit(map)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and map and not _handed_over:
		map.free()


func _update() -> void:
	if step_label == null:
		return
	var current := mini(done, steps.size() - 1)
	step_label.text = steps[current].text if done < steps.size() else "Ready"
	percent_label.text = "%d%%" % roundi(progress() * 100)
	progress_bar.value = progress() * 100
	var stage: int = steps[current].stage if done < steps.size() else BattleMap.STAGES.size()
	for i in stage_labels.size():
		var label := stage_labels[i]
		if i < stage:
			label.text = "✓ " + BattleMap.STAGES[i]
			label.add_theme_color_override("font_color", UITheme.GOOD)
		elif i == stage:
			label.text = "● " + BattleMap.STAGES[i]
			label.add_theme_color_override("font_color", UITheme.TEXT)
		else:
			label.text = BattleMap.STAGES[i]
			label.add_theme_color_override("font_color", UITheme.MUTED)


func _build_layout() -> void:
	%Layout.visible = true
	(%PlayerName as Label).text = battle.player.name
	(%PlayerDetails as Label).text = battle.player.details()
	(%OpponentName as Label).text = battle.opponent.name
	(%OpponentDetails as Label).text = battle.opponent.details()
	_fill_battleplan_card()
	step_label = %Step
	percent_label = %Percent
	progress_bar = %Bar
	spinner = %Spinner
	var checklist: HBoxContainer = %Checklist
	for stage in BattleMap.STAGES:
		if not stage_labels.is_empty():
			checklist.add_child(UIBuilder.spacer())
		var label := UIBuilder.label(stage, "MutedLabel")
		stage_labels.append(label)
		checklist.add_child(label)
	(%Tip as RichTextLabel).text = "[center][color=#D9A84A][b]Tip:[/b][/color] Hold the right mouse button or use %s to move the camera; hold the middle mouse button or use %s to rotate it.[/center]" \
			% [BattleHud.move_keys(), BattleHud.turn_keys()]


func _fill_battleplan_card() -> void:
	var preview: Control
	if battle.battleplan:
		var plan_map := BattleplanMap.new(battle.battleplan, battle.battlefield_size, true)
		plan_map.neutral = true
		preview = plan_map
	elif battle.realm:
		preview = RealmMap.new(battle.battlepack, battle.realm, true)
	else:
		preview = _sides()
	%Frame.add_child(preview)
	(%Kind as Label).text = _kind_text()
	(%PlanTitle as Label).text = battle.title
	(%Description as Label).text = _description()
	(%Facts as Label).text = _facts()


## A Spearhead realm battlefield's sides, side by side, before the defender picks one.
func _sides() -> Control:
	var row := UIBuilder.hbox([], 12)
	for side in battle.battlepack.realms:
		var realm_map := RealmMap.new(battle.battlepack, side)
		realm_map.custom_minimum_size = Vector2(MAP_SIZE.x / 2 - 6, (MAP_SIZE.x / 2 - 6) * battle.battlefield_size.y / battle.battlefield_size.x)
		var side_map := RealmPicker.captioned_map(realm_map, side.name)
		side_map.add_theme_constant_override("separation", 6)
		(side_map.get_node(^"%Caption") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(side_map)
	return row


## "4 objectives · 8 terrain features · 30" × 22"", or the sides to pick from in Spearhead before
## the defender picks one.
func _facts() -> String:
	if battle.is_spearhead() and battle.realm == null:
		var sides := PackedStringArray()
		for side in battle.battlepack.realms:
			sides.append(side.name)
		return "Sides: %s · %s" % [" or ".join(sides), battle.battlefield_text()]
	return "%d objectives · %d terrain features · %s" % [battle.objectives.size(), battle.all_terrain().size(), battle.battlefield_text()]


## "RANDOM BATTLE PLAN · TABLE 1", or "REALM BATTLEFIELD · FIRE AND JADE" in Spearhead.
func _kind_text() -> String:
	var text := "BATTLE PLAN · TABLE %d" % battle.table if battle.battleplan else "REALM BATTLEFIELD · %s" % battle.battlepack.name.to_upper()
	return ("RANDOM " + text) if battle.was_random else text


func _description() -> String:
	if not battle.twist.is_empty():
		return battle.twist
	if battle.realm == null:
		return "After the roll-off, each side picks its regiment ability and enhancement, then the defender picks the side of the realm battlefield, the deployment map and the territories."
	return "The %s side of the %s realm battlefield. After the roll-off, each side picks its regiment ability and enhancement, and the defender picks the deployment map." \
			% [battle.title, battle.battlepack.name]
