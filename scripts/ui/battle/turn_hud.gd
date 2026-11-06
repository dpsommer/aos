class_name TurnHud
extends Control
## What the player uses during the battle: on the right, what they're being asked and their options;
## on the left, a log of what's happened. See docs/design/battle.md.

## The player picked an ability to use.
signal option_picked(option: ActionOption)
## The player passed, or chose not to move.
signal pass_pressed
## The player confirmed where the models go.
signal confirm_pressed
## The player put the models back.
signal reset_pressed
## The player picked a unit, as a target.
signal unit_picked(unit: BattleUnit)
## The player took a choice, by its index.
signal choice_picked(index: int)

## How many lines of the log are kept.
const MAX_LOG_LINES := 60

var _request: DecisionRequest
var _not_supported := PackedStringArray()


static func create() -> TurnHud:
	return load("res://scenes/ui/battle/turn_hud.tscn").instantiate()


func _init() -> void:
	theme = UITheme.get_theme()


func _on_confirm_pressed() -> void:
	confirm_pressed.emit()


func _on_reset_pressed() -> void:
	reset_pressed.emit()


func _on_pass_pressed() -> void:
	pass_pressed.emit()


## Adds [param line] to the log and scrolls to it.
func add_log(line: String) -> void:
	var lines: VBoxContainer = get_node(^"%Lines")
	lines.add_child(UIBuilder.label(line, "MutedLabel", true))
	while lines.get_child_count() > MAX_LOG_LINES:
		var oldest := lines.get_child(0)
		lines.remove_child(oldest)
		oldest.queue_free()
	_scroll_log.call_deferred()


func _scroll_log() -> void:
	var scroll: ScrollContainer = get_node(^"%Scroll")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


## Shows that [param who] is thinking.
func show_waiting(who: String) -> void:
	_reset("%s is deciding…" % who)


## Shows the abilities [param of] offers, and the phase's abilities the game can't use yet.
func show_options(of: DecisionRequest, not_supported: PackedStringArray) -> void:
	_request = of
	_not_supported = not_supported
	_fill_options(null)


## Shows only the options for [param unit], or all of them for the same unit again.
func filter_options(unit: BattleUnit) -> void:
	if _request:
		_fill_options(unit)


func _fill_options(only: BattleUnit) -> void:
	_reset(_request.prompt)
	var options: VBoxContainer = get_node(^"%Options")
	for option in _request.options:
		if only == null or option.user == only:
			var picked := option
			var button := UIBuilder.button(option.label(), func() -> void: option_picked.emit(picked))
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.tooltip_text = _rules_text(option.entry.ability)
			options.add_child(button)
	var pass_button: Button = get_node(^"%Pass")
	pass_button.visible = _request.can_pass
	var not_supported: Label = get_node(^"%NotSupported")
	not_supported.visible = not _not_supported.is_empty()
	not_supported.text = "Not supported yet: %s." % ", ".join(_not_supported)


func _rules_text(ability: Ability) -> String:
	var parts := PackedStringArray()
	for part in [ability.declare, ability.effect]:
		if not part.is_empty():
			parts.append(part)
	return "\n\n".join(parts)


## Shows [param choices] as buttons.
func show_choices(prompt: String, choices: PackedStringArray) -> void:
	_reset(prompt)
	var options: VBoxContainer = get_node(^"%Options")
	for i in choices.size():
		var index := i
		options.add_child(UIBuilder.button(choices[i], func() -> void: choice_picked.emit(index)))


## Shows [param units] to pick from.
func show_units(prompt: String, units: Array[BattleUnit]) -> void:
	_reset(prompt)
	var options: VBoxContainer = get_node(^"%Options")
	for unit in units:
		var picked := unit
		options.add_child(UIBuilder.button("%s (%d)" % [unit.name, unit.model_count()], func() -> void: unit_picked.emit(picked)))


## Shows the keys and buttons for moving models.
func show_move(prompt: String, can_pass: bool, single_model: bool) -> void:
	_reset(prompt)
	var keys: Label = get_node(^"%Keys")
	keys.visible = true
	keys.text = "Click or drag on the board to move %s.\n%s  single model: %s\n%s  put back" % [
		"a model" if single_model else "the unit",
		BattleHud.key_for("single_model_mode"), "on" if single_model else "off",
		BattleHud.key_for("undo_placement"),
	]
	(get_node(^"%Confirm") as Button).visible = true
	(get_node(^"%Reset") as Button).visible = true
	var pass_button: Button = get_node(^"%Pass")
	pass_button.visible = can_pass
	pass_button.text = "Don't move"


func set_confirm_enabled(enabled: bool) -> void:
	(get_node(^"%Confirm") as Button).disabled = not enabled


## Shows why the player can't do what they're trying to, or nothing if [param problems] is empty.
func set_problems(problems: PackedStringArray) -> void:
	var label: Label = get_node(^"%Problems")
	label.visible = not problems.is_empty()
	label.text = "\n".join(problems)


func _reset(prompt: String) -> void:
	(get_node(^"%Prompt") as Label).text = prompt
	set_problems(PackedStringArray())
	UIBuilder.clear(get_node(^"%Options"))
	for part: NodePath in [^"%NotSupported", ^"%Keys", ^"%Confirm", ^"%Reset", ^"%Pass"]:
		(get_node(part) as Control).visible = false
	(get_node(^"%Pass") as Button).text = "Pass"
