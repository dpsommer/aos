class_name StatResolver
extends RefCounted
## Answers what a characteristic or roll comes to: a base from a [CharacteristicsController], changed
## by every [Modifier] that applies. It looks at everything holding modifiers, so an aura doesn't have
## to be attached and detached as its source moves. Works for any holder.

var game: GameController


func _init(on: GameController) -> void:
	game = on


## [param stat] of [param unit], with modifiers. A random one is rolled.
func value(unit: BattleUnit, stat: StringName, context: RuleContext = null) -> int:
	var holder := game.controller_of(unit)
	if holder == null:
		return 0
	var base := holder.characteristics.base(stat)
	return modified(base.roll(game.rng), stat, context if context else RuleContext.of_unit(game, unit))


## [param base] changed by what applies to [param stat] in [param context]: set, halve, add (Core
## Rules 27.0), never below 1 unless it started below 1 or it's Rend.
func modified(base: int, stat: StringName, context: RuleContext) -> int:
	var result := base
	var modifiers := gather(stat, context)
	for modifier in modifiers:
		if modifier.op == Modifier.Op.SET:
			# Only the best ward counts (18.1).
			result = mini(result, modifier.value) if stat == &"ward" and result > 0 else modifier.value
	for modifier in modifiers:
		if modifier.op == Modifier.Op.HALVE:
			result = floori(result / 2.0)
	for modifier in modifiers:
		if modifier.op == Modifier.Op.ADD:
			result += modifier.value
	var floor_value := 0 if stat == &"rend" or base <= 0 else 1
	return maxi(result, floor_value)


## [param stat] of [param unit], with what sets or halves it but not what adds to it: for a value
## whose roll takes the additions instead, such as a Save and its save roll.
func without_adding(unit: BattleUnit, stat: StringName, context: RuleContext) -> int:
	var holder := game.controller_of(unit)
	if holder == null:
		return 0
	var result := holder.characteristics.base(stat).roll(game.rng)
	var modifiers := gather(stat, context)
	for modifier in modifiers:
		if modifier.op == Modifier.Op.SET:
			result = modifier.value
	for modifier in modifiers:
		if modifier.op == Modifier.Op.HALVE:
			result = floori(result / 2.0)
	return result


## What's added to a roll of [param stat], uncapped.
func roll_modifier(stat: StringName, context: RuleContext) -> int:
	var total := 0
	for modifier in gather(stat, context):
		if modifier.op == Modifier.Op.ADD:
			total += modifier.value
	return total


## Whether [param unit] has [param keyword], from its warscroll or from a modifier.
func has_keyword(unit: BattleUnit, keyword: String, context: RuleContext = null) -> bool:
	if unit.has_keyword(keyword):
		return true
	# WIZARD and PRIEST carry their power level: "WIZARD (1)".
	if unit.warscroll and (keyword == "WIZARD" or keyword == "PRIEST"):
		for own in unit.warscroll.keywords:
			if own.begins_with(keyword + " ("):
				return true
	return has_grant(unit, keyword, context)


func has_grant(unit: BattleUnit, what: Variant, context: RuleContext = null) -> bool:
	return _has(Modifier.Op.GRANT, StringName(what), context if context else RuleContext.of_unit(game, unit))


func is_forbidden(unit: BattleUnit, what: StringName, context: RuleContext = null) -> bool:
	return _has(Modifier.Op.FORBID, what, context if context else RuleContext.of_unit(game, unit))


func is_permitted(unit: BattleUnit, what: StringName, context: RuleContext = null) -> bool:
	return _has(Modifier.Op.PERMIT, what, context if context else RuleContext.of_unit(game, unit))


func _has(op: Modifier.Op, what: StringName, context: RuleContext) -> bool:
	for modifier in gather(what, context):
		if modifier.op == op:
			return true
	return false


## Every modifier of [param stat] that applies in [param context], each passive once.
func gather(stat: StringName, context: RuleContext) -> Array[Modifier]:
	var result: Array[Modifier] = []
	var seen := {}
	for holder in game.modifier_holders():
		for modifier in holder.modifiers.modifiers:
			if modifier.stat != stat:
				continue
			if modifier.passive and seen.has(modifier.source_name):
				continue
			if _applies(modifier, holder, context):
				result.append(modifier)
				if modifier.passive:
					seen[modifier.source_name] = true
	return result


func _applies(modifier: Modifier, holder: BattlefieldController, context: RuleContext) -> bool:
	if modifier.action != null and modifier.action != context.action:
		return false
	if not _fits_weapon(modifier, context):
		return false
	context.holder = holder
	if not modifier.aura.is_empty():
		if not _in_aura(modifier, holder, context.subject):
			return false
	elif modifier.against:
		var held := holder as UnitController
		# Terrain's rolls against whoever its condition says; a unit's against itself.
		if held != null and held.unit != context.target:
			return false
	else:
		var held := holder as UnitController
		if held == null or held.unit != context.subject:
			return false
	return Predicates.all_hold(modifier.conditions, context)


func _fits_weapon(modifier: Modifier, context: RuleContext) -> bool:
	var weapon := context.weapon
	if weapon == null:
		return modifier.weapons.is_empty() and modifier.weapon_name.is_empty()
	match modifier.weapons:
		"melee":
			if not weapon.is_melee():
				return false
		"ranged":
			if weapon.is_melee():
				return false
	if not modifier.weapon_name.is_empty() and modifier.weapon_name != weapon.name:
		return false
	# A Companion weapon isn't affected by friendly abilities unless they're negative (20.0).
	if modifier.op != Modifier.Op.FORBID and modifier.is_positive() and not modifier.affects_companion and "Companion" in weapon.abilities \
			and modifier.source_army == game.army_of(context.attacker):
		return false
	return true


## Whether [param unit] is in [param modifier]'s aura around [param holder].
func _in_aura(modifier: Modifier, holder: BattlefieldController, unit: BattleUnit) -> bool:
	var source := holder as UnitController
	var aura := modifier.aura
	if unit == null or (aura.has("within") and (source == null or source.unit.positions.is_empty())):
		return false
	var friendly := game.army_of(unit) == modifier.source_army
	match aura.get("side", "friendly"):
		"friendly":
			if not friendly:
				return false
		"enemy":
			if friendly:
				return false
	if aura.get("others", false) and source and source.unit == unit:
		return false
	for keyword: String in aura.get("keywords", []):
		if not has_keyword(unit, keyword):
			return false
	if not aura.has("within"):
		return true
	return BattleGeometry.is_in_reach(unit, source.unit, float(aura.within), aura.get("wholly", false))
