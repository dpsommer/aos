class_name RuleContext
extends RefCounted
## What's being asked about when a modifier's conditions are checked: read-only, and made fresh for
## each question.

var game: GameController
## The unit whose characteristic or roll this is.
var subject: BattleUnit
## In an attack, who's making it and who it targets.
var attacker: BattleUnit
var target: BattleUnit
var weapon: Weapon
## In an action, which one.
var action: Action
## The [BattlefieldController] holding the modifier being checked.
var holder: BattlefieldController


static func of_unit(on: GameController, unit: BattleUnit) -> RuleContext:
	var context := RuleContext.new()
	context.game = on
	context.subject = unit
	return context


## An attack by [param by] on [param at] with [param with]; the subject is the attacker until a
## question about the target says otherwise.
static func of_attack(on: GameController, by: BattleUnit, at: BattleUnit, with: Weapon, in_action: Action = null) -> RuleContext:
	var context := of_unit(on, by)
	context.attacker = by
	context.target = at
	context.weapon = with
	context.action = in_action
	return context


## Whether this is about a melee or a shooting attack.
func is_melee() -> bool:
	return weapon != null and weapon.is_melee()


func is_shooting() -> bool:
	return weapon != null and not weapon.is_melee()
