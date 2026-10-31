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
const REALM_ART := preload("res://assets/2d/p_realm_art.svg")
## Shortest time the screen shows, so it can be read.
const MIN_SECONDS := 1.5
## Most time per frame spent building, so the screen stays responsive.
const FRAME_BUDGET_MSEC := 12
const PLAYER_COLOUR := Color("#7FA9D6")
const OPPONENT_COLOUR := Color("#E58A80")
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
	var art := TextureRect.new()
	art.name = "RealmArt"
	art.texture = REALM_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var art_note := UIBuilder.label("[Realm art for the battleplan]", "MutedLabel")
	art_note.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	art_note.position = Vector2(-220, 24)
	art_note.add_theme_color_override("font_color", Color("#6E7582"))
	add_child(art_note)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 88)
	margin.add_theme_constant_override("margin_bottom", 64)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	add_child(margin)
	var column := UIBuilder.vbox([_matchup(), _battleplan_card(), UIBuilder.spacer(), _progress()], 40)
	for child in column.get_children():
		child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.get_child(2).size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)


func _matchup() -> Control:
	var you := _side("YOU", battle.player, PLAYER_COLOUR, HORIZONTAL_ALIGNMENT_RIGHT)
	var them := _side("AI OPPONENT", battle.opponent, OPPONENT_COLOUR, HORIZONTAL_ALIGNMENT_LEFT)
	var versus := UIBuilder.label("VS", "PageTitleLabel")
	versus.add_theme_color_override("font_color", UITheme.GOLD)
	versus.add_theme_font_size_override("font_size", 28)
	var row := UIBuilder.hbox([you, versus, them], 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	you.custom_minimum_size.x = 420
	them.custom_minimum_size.x = 420
	return row


func _side(who: String, army: BattleArmy, colour: Color, align: HorizontalAlignment) -> Control:
	var tag := UIBuilder.label(who, "StatNameLabel")
	tag.add_theme_color_override("font_color", colour)
	tag.add_theme_font_size_override("font_size", 12)
	var army_name := UIBuilder.label(army.name, "PageTitleLabel")
	army_name.add_theme_font_size_override("font_size", 30)
	var details := UIBuilder.label(army.details(), "DescriptionLabel")
	details.add_theme_font_size_override("font_size", 14)
	for label: Label in [tag, army_name, details]:
		label.horizontal_alignment = align
	return UIBuilder.vbox([tag, army_name, details], 6)


func _battleplan_card() -> Control:
	var preview: Control
	if battle.battleplan:
		var plan_map := BattleplanMap.new(battle.battleplan, battle.battlefield_size, true)
		plan_map.neutral = true
		preview = plan_map
	else:
		preview = RealmMap.new(battle.battlepack, battle.realm, true)
	var frame := VBoxContainer.new()
	frame.custom_minimum_size = MAP_SIZE
	frame.add_child(preview)
	var info := UIBuilder.vbox([
		UIBuilder.label(_kind_text(), "StatNameLabel"),
		_title(),
		UIBuilder.label(_description(), "DescriptionLabel", true),
		UIBuilder.label("%d objectives · %d terrain features · %s" % [battle.objectives.size(), battle.all_terrain().size(),
				battle.battlefield_text()], "BodyLabel"),
		UIBuilder.label("Territories are shown neutral here: blue and red are assigned after the roll-off.", "MutedLabel", true),
	], 12)
	info.custom_minimum_size.x = 420
	var card := UIBuilder.panel("CardPanel", UIBuilder.hbox([frame, info], 40))
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.09, 0.102, 0.122, 0.92), UITheme.BORDER, 12, 28))
	return card


func _title() -> Label:
	var title := UIBuilder.label(battle.title, "PageTitleLabel")
	title.add_theme_font_size_override("font_size", 40)
	return title


## "RANDOM BATTLE PLAN · TABLE 1", or "REALM BATTLEFIELD · FIRE AND JADE" in Spearhead.
func _kind_text() -> String:
	var text := "BATTLE PLAN · TABLE %d" % battle.table if battle.battleplan else "REALM BATTLEFIELD · %s" % battle.battlepack.name.to_upper()
	return ("RANDOM " + text) if battle.was_random else text


func _description() -> String:
	if not battle.twist.is_empty():
		return battle.twist
	return "The %s side of the %s realm battlefield, with the %s deployment map." % [battle.title, battle.battlepack.name,
			battle.deployment.name.to_lower()]


func _progress() -> Control:
	spinner = Spinner.new()
	step_label = UIBuilder.label("")
	percent_label = UIBuilder.label("", "MutedLabel")
	percent_label.add_theme_font_size_override("font_size", 14)
	var status := UIBuilder.hbox([spinner, step_label, UIBuilder.spacer(), percent_label], 10)
	progress_bar = ProgressBar.new()
	progress_bar.theme_type_variation = &"LoadingBar"
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 8
	progress_bar.accessibility_name = "Loading battle"
	var checklist := HBoxContainer.new()
	for stage in BattleMap.STAGES:
		if not stage_labels.is_empty():
			checklist.add_child(UIBuilder.spacer())
		var label := UIBuilder.label(stage, "MutedLabel")
		stage_labels.append(label)
		checklist.add_child(label)
	var tip := UIBuilder.rich("[center][color=#D9A84A][b]Tip:[/b][/color] Hold the right mouse button or use %s to move the camera; hold the middle mouse button or use %s to rotate it.[/center]"
			% [BattleHud.move_keys(), BattleHud.turn_keys()])
	tip.add_theme_color_override("default_color", UITheme.MUTED)
	var column := UIBuilder.vbox([status, progress_bar, checklist, tip], 14)
	column.custom_minimum_size.x = 720
	return column


## A turning arc that shows the screen is working.
class Spinner:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(18, 18)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		rotation += TAU * delta
		pivot_offset = size / 2

	func _draw() -> void:
		draw_arc(size / 2, size.x / 2 - 1.5, 0, TAU * 0.75, 24, UITheme.GOLD, 2.4, true)
