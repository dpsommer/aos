class_name AbilityCard
extends PanelContainer
## An ability laid out like the official warscrolls: an outer box in the ability's colour, with an
## icon for its kind, its frequency and timing (and casting value, points etc.) across the top, around
## an inner box holding its name, a rule, then its Declare and Effect, keywords and source.

## Phase names in timings, checked in order, e.g. "Your Hero Phase" or "Any Combat Phase".
const PHASE_WORDS := [
	["Deployment", "deployment"],
	["Hero", "hero"],
	["Movement", "movement"],
	["Shooting", "shooting"],
	["Charge", "charge"],
	["Combat", "combat"],
]
## A reaction's phase from the ability it reacts to, e.g. "Reaction: You declared a FIGHT ability".
const REACTION_WORDS := [
	["FIGHT", "combat"],
	["ATTACK", "combat"],
	["SHOOT", "shooting"],
	["CHARGE", "charge"],
	["RUN", "movement"],
	["RETREAT", "movement"],
	["MOVE", "movement"],
	["SPELL", "hero"],
	["PRAYER", "hero"],
	["UNBIND", "hero"],
]
## The colour ([member Ability.colour]) of each [method phase], for abilities whose data has none.
const PHASE_COLOURS := {
	"deployment": "black",
	"hero": "yellow",
	"movement": "grey",
	"shooting": "blue",
	"charge": "orange",
	"combat": "red",
	"end": "purple",
	"passive": "green",
}
## The icon in assets/2d/icons for each ability category.
const CATEGORY_ICONS := {
	"offensive": "aos/white/characteristics/strength",
	"defensive": "shield",
	"movement": "aos/white/characteristics/move",
	"shooting": "aos/white/characteristics/range",
	"rallying": "aos/white/misc/glove",
	"control": "aos/white/misc/active",
	"damage": "aos/white/weapons/blast",
	"special": "aos/white/misc/circle",
}
## The icon in assets/2d/icons for Battle Damaged abilities and the weapons they change: a cracked skull.
const BATTLE_DAMAGED_ICON := "aos/white/characteristics/damage"

var ability: Ability
## The chevron that folds the card, or null unless [method make_foldable] was called.
var fold_button: Button
## Whether the card shows only its header and name.
var folded := false
var _name_label: Label
## Everything under the name: the rule, rules text, keywords and source.
var _details: Array[Control] = []


func _init(rule: Ability) -> void:
	ability = rule
	var colors: Array = UITheme.ABILITY_COLOURS[colour(rule)]
	add_theme_stylebox_override("panel", UITheme.box(colors[0], colors[1], 8, 4))
	var header_text := header(rule)
	accessibility_name = rule.name
	accessibility_description = header_text

	var timing := UIBuilder.label(header_text.to_upper(), "AbilityTimingLabel", true)
	timing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top := UIBuilder.hbox([_icon(rule), timing], 6)
	for value in values(rule):
		var chip := UITheme.chip(value)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(chip)
	var header_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		header_margin.add_theme_constant_override("margin_" + side, 2)
	header_margin.add_child(top)

	_name_label = UIBuilder.label(rule.name, "AbilityNameLabel", true)
	_details.append(HSeparator.new())
	var body := RulesFormatter.ability_body(rule)
	if not body.is_empty():
		_details.append(UIBuilder.rich(body))
	if not rule.keywords.is_empty():
		_details.append(UIBuilder.label(" · ".join(rule.keywords).to_upper(), "KeywordsLabel", true))
	if not rule.source.is_empty():
		_details.append(UIBuilder.label("Source: %s" % rule.source, "MutedLabel", true))
	var inner := UIBuilder.vbox([_name_label] + _details, 6)
	var inner_box := UIBuilder.panel("", inner)
	inner_box.add_theme_stylebox_override("panel", UITheme.box(UITheme.ABILITY_INNER, Color.TRANSPARENT, 6, 10))

	add_child(UIBuilder.vbox([header_margin, inner_box], 4))


## Adds a chevron beside the name that folds the card down to its header and name, and unfolds it
## again. The card starts unfolded if [param open].
func make_foldable(open: bool) -> void:
	fold_button = UIBuilder.icon_button("chevron_down", "", func() -> void: set_folded(not folded), "", "SmallIconButton")
	fold_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# The name shares a row with the chevron, in the name's place.
	var inner := _name_label.get_parent()
	var index := _name_label.get_index()
	inner.remove_child(_name_label)
	var row := UIBuilder.hbox([_name_label, fold_button], 8)
	inner.add_child(row)
	inner.move_child(row, index)
	set_folded(not open)


## Shows only the card's header and name if [param on], or all of it.
func set_folded(on: bool) -> void:
	folded = on
	for control in _details:
		control.visible = not on
	if fold_button:
		fold_button.icon = UITheme.icon("chevron_right" if on else "chevron_down")
		var label := ("Unfold " if on else "Fold ") + ability.name
		fold_button.tooltip_text = label
		fold_button.accessibility_name = label
		fold_button.accessibility_description = "Collapsed" if on else "Expanded"


## [param rule]'s colour, a key of [constant UITheme.ABILITY_COLOURS]: its [member Ability.colour]
## from the data, as printed on its warscroll, or else its [method phase]'s colour.
static func colour(rule: Ability) -> String:
	if UITheme.ABILITY_COLOURS.has(rule.colour):
		return rule.colour
	return PHASE_COLOURS[phase(rule)]


## The phase of [param rule]'s timing, a key of [constant PHASE_COLOURS]. A reaction takes the phase
## named before it (e.g. "Your Movement Phase, Reaction: ..."), else the phase of the ability it
## reacts to, else any phase it names. Unknown timings are movement.
static func phase(rule: Ability) -> String:
	if rule.type == "passive" or rule.timing == "Passive":
		return "passive"
	var parts := rule.timing.split("Reaction:", true, 1)
	var found := _phase_in(parts[0])
	if not found.is_empty():
		return found
	# Some reactions leave out "Reaction:", e.g. "You declared a FIGHT ability for this unit".
	var reaction := parts[parts.size() - 1].to_upper()
	for pair: Array in REACTION_WORDS:
		if RegEx.create_from_string("\\b%s\\b" % pair[0]).search(reaction):
			return pair[1]
	if parts.size() > 1:
		found = _phase_in(parts[1])
		if not found.is_empty():
			return found
	return "movement"


## [param rule]'s frequency and timing, e.g. "Once Per Turn (Army) · Your Hero Phase".
static func header(rule: Ability) -> String:
	return " · ".join(Array([rule.frequency, rule.timing]).filter(func(part: String) -> bool: return not part.is_empty()))


## The values shown at the end of the header, e.g. "Casting value 7" or "20 pts".
static func values(rule: Ability) -> PackedStringArray:
	var result := PackedStringArray()
	if rule.casting_value > 0:
		result.append("Casting value %d" % rule.casting_value)
	if rule.chanting_value > 0:
		result.append("Chanting value %d" % rule.chanting_value)
	if rule.command_points > 0:
		result.append("%d CP" % rule.command_points)
	if rule.points > 0:
		result.append("%d pts" % rule.points)
	return result


## Whether [param rule] is a warscroll's Battle Damaged ability, which changes its characteristics
## once it has taken enough damage.
static func is_battle_damaged(rule: Ability) -> bool:
	return rule.name.to_lower() == "battle damaged"


## The icon for [param rule]'s category in assets/2d/icons ([constant CATEGORY_ICONS]). Abilities
## without a known category show the special icon. Battle Damaged shows [constant BATTLE_DAMAGED_ICON].
static func icon_name(rule: Ability) -> String:
	if is_battle_damaged(rule):
		return BATTLE_DAMAGED_ICON
	var category := "rallying" if rule.category == "rally" else rule.category
	return CATEGORY_ICONS.get(category, CATEGORY_ICONS.special)


static func _phase_in(timing: String) -> String:
	if timing.contains("End of"):
		return "end"
	if timing.contains("Start of"):
		return "deployment"
	for pair: Array in PHASE_WORDS:
		if timing.contains(pair[0]):
			return pair[1]
	return ""


func _icon(rule: Ability) -> PanelContainer:
	var icon := TextureRect.new()
	icon.texture = UITheme.icon(icon_name(rule))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(16, 16)
	icon.modulate = UITheme.TEXT
	var badge := UIBuilder.panel("", icon)
	badge.add_theme_stylebox_override("panel", UITheme.box(Color(0, 0, 0, 0.35), Color.TRANSPARENT, 12, 4))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.tooltip_text = rule.category.capitalize() if not rule.category.is_empty() else ""
	return badge
