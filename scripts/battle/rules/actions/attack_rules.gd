class_name AttackRules
extends RefCounted
## Who can attack whom, and the attack sequence (Core Rules 16.0-20.0). See docs/gameplay/attacks.md.
## The result goes into the action's damage pool, for the damage sequence afterwards.

## The order a weapon uses its critical hit abilities in, if it has more than one.
const CRITS: PackedStringArray = ["Crit (Mortal)", "Crit (Auto-wound)", "Crit (2 Hits)"]
## Guarded Hero: how close a shooter has to be (Core Rules 25.0).
const GUARDED_RANGE := 12.0

var game: GameController


func _init(on: GameController) -> void:
	game = on


## [param unit]'s weapons for the attack type.
func weapons_of(unit: BattleUnit, melee: bool) -> Array[Weapon]:
	if unit.warscroll == null:
		return []
	return unit.warscroll.melee_weapons if melee else unit.warscroll.ranged_weapons


## Who [param unit] can attack with [param weapon] (16.0).
func targets_for(unit: BattleUnit, weapon: Weapon) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var in_combat := game.in_combat(unit)
	if not weapon.is_melee() and in_combat and not weapon_has(weapon, "Shoot in Combat", RuleContext.of_attack(game, unit, null, weapon)):
		return result
	for enemy in game.attackable_by(unit):
		if in_combat and not BattleGeometry.in_combat_with(unit, enemy):
			continue
		if attackers_with(unit, weapon, enemy) > 0 and _can_target(unit, weapon, enemy):
			result.append(enemy)
	return result


## Whether [param unit] has anything to attack with this type of attack.
func has_targets(unit: BattleUnit, melee: bool) -> bool:
	for weapon in weapons_of(unit, melee):
		if not targets_for(unit, weapon).is_empty():
			return true
	return false


func _can_target(unit: BattleUnit, weapon: Weapon, target: BattleUnit) -> bool:
	if weapon.is_melee():
		return true
	if game.stats.is_forbidden(target, &"be_shot", RuleContext.of_attack(game, unit, target, weapon)):
		return false
	if _is_guarded_from(unit, target):
		return false
	for terrain in game.terrain_controllers.values():
		if terrain.blocks_shooting(unit, target):
			return false
	return true


## An INFANTRY Guarded Hero can't be shot from more than 12" (25.0).
func _is_guarded_from(unit: BattleUnit, target: BattleUnit) -> bool:
	return is_guarded(target) and game.stats.has_keyword(target, "INFANTRY") and not BattleGeometry.is_within(target, unit, GUARDED_RANGE)


## Whether [param hero] has the Guarded Hero ability working (25.0).
func is_guarded(hero: BattleUnit) -> bool:
	if not game.stats.has_keyword(hero, "HERO") or game.stats.has_keyword(hero, "MONSTER") or game.stats.has_keyword(hero, "WAR MACHINE"):
		return false
	for friend in game.on_battlefield(game.army_of(hero)):
		if friend != hero and not game.stats.has_keyword(friend, "HERO") and BattleGeometry.is_within(hero, friend, BattleGeometry.COMBAT_RANGE):
			return true
	return false


## How many of [param unit]'s models can use [param weapon] on [param target].
func attackers_with(unit: BattleUnit, weapon: Weapon, target: BattleUnit) -> int:
	var reach := BattleGeometry.COMBAT_RANGE if weapon.is_melee() else float(weapon.range_inches)
	return BattleGeometry.models_within(unit, target, reach)


## Whether [param weapon] has the weapon ability [param what], itself or from a modifier.
func weapon_has(weapon: Weapon, what: String, context: RuleContext) -> bool:
	if what in weapon.abilities:
		return true
	for modifier in game.stats.gather(StringName(what), context):
		if modifier.op == Modifier.Op.GRANT:
			return true
	return false


## Resolves [param weapon]'s attacks by [param attacker] against [param target], adding what gets
## through to [param action]'s damage pool. Returns what happened, for the log: [code]attacks[/code],
## [code]hits[/code], [code]wounds[/code], [code]unsaved[/code] and [code]damage[/code].
func resolve(action: Action, attacker: BattleUnit, weapon: Weapon, target: BattleUnit) -> Dictionary:
	var rng := game.rng
	var stats := game.stats
	var context := RuleContext.of_attack(game, attacker, target, weapon, action)
	var defending := RuleContext.of_attack(game, target, target, weapon, action)
	defending.attacker = attacker
	var result := {"attacks": 0, "hits": 0, "wounds": 0, "unsaved": 0, "damage": 0, "crits": 0}

	var attacks_dice := DiceExpr.parse(weapon.attacks)
	for _model in attackers_with(attacker, weapon, target):
		result.attacks += stats.modified(attacks_dice.roll(rng), &"attacks", context)

	var guarded := -1 if not weapon.is_melee() and is_guarded(target) else 0
	var hit_modifier: int = clampi(stats.roll_modifier(&"hit", context) + guarded, -1, 1)
	var wound_modifier: int = clampi(stats.roll_modifier(&"wound", context), -1, 1)
	var save_modifier: int = mini(stats.roll_modifier(&"save", defending), 1)
	var rend := _rend(weapon, attacker, target, context)
	var damage_dice := DiceExpr.parse(weapon.damage)
	var damage_bonus := 1 if weapon_has(weapon, "Charge (+1 Damage)", context) and game.controller_of(attacker).charged else 0
	# Bonuses go on the roll, not the characteristic as well: only what sets a save changes this.
	var save_value := stats.without_adding(target, &"save", defending)
	var crit := _crit_ability(weapon, context)
	var sixes_only := stats.is_forbidden(target, &"hit_below_6", context)

	for _attack in result.attacks:
		var roll := rng.randi_range(1, 6)
		if roll == 1 or roll + hit_modifier < weapon.hit or (sixes_only and roll != 6):
			continue
		var is_crit := roll == 6
		result.crits += 1 if is_crit else 0
		var hits := 2 if is_crit and crit == "Crit (2 Hits)" else 1
		result.hits += hits
		if is_crit and crit == "Crit (Mortal)":
			var mortal := _damage_of(damage_dice, damage_bonus, context)
			result.damage += mortal
			action.add_damage(target, mortal)
			continue
		for _hit in hits:
			if not (is_crit and crit == "Crit (Auto-wound)"):
				var wound_roll := rng.randi_range(1, 6)
				if wound_roll == 1 or wound_roll + wound_modifier < weapon.wound:
					continue
			result.wounds += 1
			var save_roll := rng.randi_range(1, 6)
			if save_roll != 1 and save_value > 0 and save_roll + save_modifier - rend >= save_value:
				continue
			result.unsaved += 1
			var points := _damage_of(damage_dice, damage_bonus, context)
			result.damage += points
			action.add_damage(target, points)
	return result


func _damage_of(dice: DiceExpr, bonus: int, context: RuleContext) -> int:
	return game.stats.modified(dice.roll(game.rng) + bonus, &"damage", context)


func _rend(weapon: Weapon, attacker: BattleUnit, target: BattleUnit, context: RuleContext) -> int:
	if game.stats.is_forbidden(target, &"rend", context):
		return 0
	var base := weapon.rend + _anti_bonus(weapon, target)
	return game.stats.modified(base, &"rend", context) if attacker else base


## Anti-X (+1 Rend), cumulative (20.0): X is a keyword or "charge" for a target that charged.
func _anti_bonus(weapon: Weapon, target: BattleUnit) -> int:
	var total := 0
	for ability in weapon.abilities:
		if not ability.begins_with("Anti-"):
			continue
		var name_end := ability.find(" (")
		var wanted := ability.substr(5, name_end - 5 if name_end > 0 else -1)
		if wanted.to_lower() == "charge":
			if game.controller_of(target).charged:
				total += 1
		elif game.stats.has_keyword(target, wanted.to_upper()):
			total += 1
	return total


## The critical hit ability [param weapon] uses, or empty.
func _crit_ability(weapon: Weapon, context: RuleContext) -> String:
	for crit in CRITS:
		if weapon_has(weapon, crit, context):
			return crit
	return ""
