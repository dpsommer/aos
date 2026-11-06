class_name DecisionRequest
extends RefCounted
## What the battle is waiting on someone to choose. Everything needed to choose is here, so the
## player's HUD and the AI answer the same request, and the engine doesn't know which of them did.

enum Kind {
	## Whether [member army] takes the first turn this round.
	FIRST_TURN,
	## Which of [member options] to use next, or pass.
	ACTION,
	## Which reaction in [member options] to use, or pass.
	REACTION,
	## Which of [member units] to target ([member count] of them).
	TARGETS,
	## Which enemy each of [member weapons] attacks: [member weapon_targets] gives who it can.
	ATTACK_TARGETS,
	## Where the models of [member move].unit end up, or not to move.
	MOVE,
	## Where to set [member unit] up, more than [member min_enemy_gap] from all enemies.
	SET_UP,
	## Which of [member choices] to take.
	CHOICE,
}

var kind: Kind
## Who has to choose.
var army: BattleArmy
var prompt := ""
## Whether they can say no.
var can_pass := false
var options: Array[ActionOption] = []
var units: Array[BattleUnit] = []
var count := 1
## The action this is part of, or null.
var action: Action
var weapons: Array[Weapon] = []
## Each of [member weapons]' eligible targets, as an array of [BattleUnit].
var weapon_targets := {}
var attacker: BattleUnit
var move: MoveSpec
var unit: BattleUnit
var min_enemy_gap := 0.0
## Who it has to be set up wholly within [member near_reach] of, or null.
var near_unit: BattleUnit
var near_reach := 0.0
var choices := PackedStringArray()


static func create(of: Kind, by: BattleArmy, text := "") -> DecisionRequest:
	var request := DecisionRequest.new()
	request.kind = of
	request.army = by
	request.prompt = text
	return request
