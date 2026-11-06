class_name Modifier
extends RefCounted
## A buff or debuff: what it changes, for how long and under what conditions. It knows nothing about
## units, so a unit, a terrain feature or anything else with a [ModifierController] can hold one.
## Applied in the order set, halve, add (Core Rules 27.0).

enum Op {
	## Sets [member stat] to [member value].
	SET,
	## Halves [member stat], rounding down.
	HALVE,
	## Adds [member value] to [member stat], which may be negative.
	ADD,
	## Gives a keyword or weapon ability, named in [member stat], e.g. STRIKE-FIRST.
	GRANT,
	## Stops something, named in [member stat], e.g. contest.
	FORBID,
	## Allows what a rule otherwise stops, named in [member stat], e.g. charge_after_run.
	PERMIT,
}
## How long it lasts.
enum Until { PERMANENT, END_OF_PHASE, END_OF_TURN, END_OF_ROUND, START_OF_NEXT_TURN, END_OF_ACTION }

const UNTIL_NAMES := {
	"phase": Until.END_OF_PHASE, "turn": Until.END_OF_TURN, "round": Until.END_OF_ROUND,
	"start_next_turn": Until.START_OF_NEXT_TURN, "action": Until.END_OF_ACTION, "battle": Until.PERMANENT,
}

## What it changes: a characteristic or a roll, e.g. hit, save, attacks, charge.
var stat: StringName
var op := Op.ADD
var value := 0
var until := Until.PERMANENT
## The ability it comes from, for the HUD and for applying a passive once (Rules of One).
var source_name := ""
## The army whose ability it is: friendly and enemy are worked out from it. Null for neutral terrain.
var source_army: BattleArmy
## Whether it changes rolls against its holder (attacks that target it), rather than its own.
var against := false
## Which weapons it's for: "melee", "ranged", or empty for all.
var weapons := ""
## Which one weapon it's for, by name, or empty for all.
var weapon_name := ""
## Conditions, in the form [Predicates] reads. All must hold.
var conditions: Array = []
## Its aura, if it reaches other units, in the form [member RuleContext] reads: [code]within[/code],
## [code]wholly[/code], [code]side[/code] ("friendly" or "enemy"), [code]keywords[/code],
## [code]others[/code]. Empty if it's only for its holder.
var aura := {}
## The action it's for, if only that one: 'All-out Attack' is for the attacks of one ability.
var action: Action
## Whether it applies to Companion weapons even though it's friendly and positive (Core Rules 20.0).
var affects_companion := false
## Whether it's a passive ability's, which can't stack with itself.
var passive := false


## A modifier from an effect descriptor: see docs/technical/effect-data.md.
static func from_descriptor(descriptor: Dictionary, source: String, army: BattleArmy, from_action: Action = null) -> Modifier:
	var modifier := Modifier.new()
	modifier.source_name = source
	modifier.source_army = army
	if descriptor.has("grant"):
		modifier.op = Op.GRANT
		modifier.stat = StringName(descriptor.grant)
	elif descriptor.has("forbid"):
		modifier.op = Op.FORBID
		modifier.stat = StringName(descriptor.forbid)
	elif descriptor.has("permit"):
		modifier.op = Op.PERMIT
		modifier.stat = StringName(descriptor.permit)
	else:
		modifier.stat = StringName(descriptor.get("stat", ""))
		if descriptor.has("set"):
			modifier.op = Op.SET
			modifier.value = int(descriptor.set)
		elif descriptor.get("halve", false):
			modifier.op = Op.HALVE
		else:
			modifier.value = int(descriptor.get("by", 0))
	modifier.until = UNTIL_NAMES.get(descriptor.get("until", ""), Until.PERMANENT)
	modifier.against = descriptor.get("against", false)
	modifier.weapons = descriptor.get("weapons", "")
	modifier.weapon_name = descriptor.get("weapon", "")
	modifier.conditions = descriptor.get("when", [])
	modifier.aura = descriptor.get("aura", {})
	modifier.affects_companion = descriptor.get("companion", false)
	if modifier.until == Until.END_OF_ACTION:
		modifier.action = from_action
	return modifier


## Whether this makes a roll or characteristic better for whoever it's on.
func is_positive() -> bool:
	return op == Op.ADD and value > 0 or op == Op.SET or op == Op.GRANT
