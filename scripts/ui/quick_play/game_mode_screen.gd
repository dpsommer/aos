class_name GameModeScreen
extends Control
## Quick Play's first step: a card for each game mode, Spearhead and Matched Play. Pressing one
## emits [signal mode_chosen]; Back (or Escape) emits [signal back_pressed]. See
## docs/design/quick-play.md.

signal back_pressed
signal mode_chosen(mode: BattleSetup.Mode)

## Quick Play's steps, as the breadcrumb names them.
const STEPS: PackedStringArray = ["Quick Play", "Game mode", "Army"]
const ICONS := {
	BattleSetup.Mode.SPEARHEAD: "aos/white/weapons/spear",
	BattleSetup.Mode.MATCHED_PLAY: "aos/white/fighters/frenzied",
}
const DESCRIPTIONS := {
	BattleSetup.Mode.SPEARHEAD: "Small, fixed forces from each faction's Spearhead box. Pick one and play: Spearhead armies can't be edited.",
	BattleSetup.Mode.MATCHED_PLAY: "Bring an army you built in the Forge. Points limit and rules come from the army's settings.",
}

## The mode cards by [enum BattleSetup.Mode].
var mode_cards := {}

@onready var back_button: Button = %BackButton
@onready var breadcrumb: HBoxContainer = %Breadcrumb
@onready var modes: HBoxContainer = %Modes


func _ready() -> void:
	theme = UITheme.get_theme()
	back_button.icon = UITheme.icon("back")
	back_button.pressed.connect(back_pressed.emit)
	breadcrumb.add_child(UIBuilder.breadcrumb(STEPS, 1, "Quick Play steps"))
	for mode: BattleSetup.Mode in [BattleSetup.Mode.SPEARHEAD, BattleSetup.Mode.MATCHED_PLAY]:
		mode_cards[mode] = _mode_card(mode)
		modes.add_child(mode_cards[mode])
	focus_mode_card(BattleSetup.Mode.SPEARHEAD)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


## Gives [param mode]'s card keyboard focus, e.g. the mode the player chose before going back.
func focus_mode_card(mode: BattleSetup.Mode) -> void:
	mode_cards[mode].grab_focus()


## The chips under a mode's description, as [text, chip kind] pairs.
static func mode_chips(mode: BattleSetup.Mode) -> Array:
	if mode == BattleSetup.Mode.SPEARHEAD:
		var count := shown_spearheads().size()
		return [["%d Spearhead%s" % [count, "" if count == 1 else "s"], ""], ["Fixed rosters", ""]]
	var result := [["Your Forge armies", ""]]
	var core := CoreRulesCatalog.get_rules()
	if core and core.battlepack:
		result.append([core.battlepack.name, "gold"])
	return result


## The Spearheads Quick Play offers: every faction's ([method FactionCatalog.spearheads]), without
## Legends factions' unless Settings shows them.
static func shown_spearheads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in FactionCatalog.spearheads():
		if GameSettings.current().show_legends or not FactionCatalog.is_legends(entry.faction):
			result.append(entry)
	return result


func _mode_card(mode: BattleSetup.Mode) -> OptionCard:
	var title := BattleSetup.display_name(mode)
	var card := OptionCard.new()
	card.accessibility_name = title
	card.accessibility_description = DESCRIPTIONS[mode]
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art := UIBuilder.icon_art(UITheme.icon(ICONS[mode]), 132)
	art.get_child(0).modulate = UITheme.GOLD
	art.custom_minimum_size.y = 240
	card.add(art)
	var heading := UIBuilder.label(title, "CardHeadingLabel")
	heading.add_theme_font_size_override("font_size", 30)
	card.add(heading)
	card.add(UIBuilder.label(DESCRIPTIONS[mode], "DescriptionLabel", true))
	var chips := HFlowContainer.new()
	for chip: Array in mode_chips(mode):
		chips.add_child(UITheme.chip(chip[0], chip[1]))
	card.add(chips)
	card.pressed.connect(mode_chosen.emit.bind(mode))
	return card
