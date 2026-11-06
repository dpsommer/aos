extends RefCounted
## Builders for small battles run by a [GameController], shared by the rules engine's tests: units
## with chosen characteristics and weapons standing at chosen spots, so a test controls what a roll
## needs. Preload it: const RulesKit := preload("res://test/support/rules_kit.gd")

const BattleKit := preload("res://test/support/battle_kit.gd")


static func weapon(attacks := "1", hit := 2, wound := 2, rend := 0, damage := "1", abilities := PackedStringArray(), range_inches := 0) -> Weapon:
	var result := Weapon.new()
	result.name = "Weapon"
	result.range_inches = range_inches
	result.attacks = attacks
	result.hit = hit
	result.wound = wound
	result.rend = rend
	result.damage = damage
	result.abilities = abilities
	return result


## A unit of [param count] models in a row from [param at], 1.5" apart (coherent on 32mm bases),
## on the battlefield. [param weapons] go on its warscroll as melee or ranged by their range.
static func unit(unit_name: String, count: int, at: Vector2, keywords := PackedStringArray(), health := 1, save := 0, weapons: Array[Weapon] = [], ward := 0, spacing := 1.5) -> BattleUnit:
	var scroll := BattleKit.warscroll(unit_name, count)
	scroll.keywords = keywords
	scroll.health = health
	scroll.save = save
	scroll.ward = ward
	scroll.move = "6"
	scroll.control = 1
	for each in weapons:
		if each.is_melee():
			scroll.melee_weapons.append(each)
		else:
			scroll.ranged_weapons.append(each)
	var result := BattleUnit.create(unit_name, scroll, count)
	for i in count:
		result.positions.append(at + Vector2(spacing * i, 0))
	result.deployed = true
	return result


## A game between armies of [param player_units] and [param opponent_units], with
## [param terrain] on the battlefield. Call [method GameController.dispose] afterwards.
static func game(player_units: Array[BattleUnit], opponent_units: Array[BattleUnit], terrain: Array[BattleTerrain] = [], seed_value := 1, mode := BattleSetup.Mode.SPEARHEAD) -> GameController:
	var battle := BattleKit.battle()
	battle.mode = mode
	battle.player.units.assign(player_units)
	battle.opponent.units.assign(opponent_units)
	battle.terrain.assign(terrain)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return GameController.new(battle, rng)


static func modifier(stat: StringName, by: int, army: BattleArmy, op := Modifier.Op.ADD) -> Modifier:
	var result := Modifier.new()
	result.stat = stat
	result.op = op
	result.value = by
	result.source_army = army
	return result


## Gives [param unit] a [param modifier] of its own.
static func give(on_game: GameController, to_unit: BattleUnit, given: Modifier) -> void:
	on_game.command(to_unit, Commands.ApplyModifier.new(given))


## A Matched Play game: command points, magic and the General's Handbook's five rounds.
static func matched_game(player_units: Array[BattleUnit], opponent_units: Array[BattleUnit], seed_value := 1) -> GameController:
	return game(player_units, opponent_units, [] as Array[BattleTerrain], seed_value, BattleSetup.Mode.MATCHED_PLAY)


## An ability for [method add_ability].
static func ability(ability_name: String, timing: String, type := "active", keywords := PackedStringArray()) -> Ability:
	var result := BattleKit.ability(ability_name, keywords)
	result.timing = timing
	result.type = type
	return result


## Gives [param unit]'s warscroll [param of], and the effect data [param descriptor] for it, the
## way a faction's would be found for a [BattleKit] army. Call before making the game, and
## [method forget_abilities] afterwards.
static func add_ability(to_unit: BattleUnit, of: Ability, descriptor: Dictionary) -> void:
	to_unit.warscroll.abilities.append(of)
	var entry := descriptor.duplicate(true)
	entry["hash"] = EffectCatalog.hash_of(of)
	EffectCatalog.add_entries({"faction:warscroll/%s/%s" % [to_unit.warscroll.id, of.name]: entry})


## Namespace of the battle tactic effect data [method add_tactic] adds.
const TEST_PACK := "Test Pack"


## Adds effect data for the battle tactic [param tactic_name] (named "Test ..." so it's taken out
## again) of [param space], [constant TEST_PACK] by default, which [param check] says how to check.
static func add_tactic(tactic_name: String, check: String, extra := {}, space := TEST_PACK) -> void:
	var entry := {"check": check}
	entry.merge(extra)
	EffectCatalog.add_entries({TacticChecks.key_of(space, tactic_name): entry})


## Takes the effect data [method add_ability] and [method add_tactic] added out of the catalog.
static func forget_abilities() -> void:
	for key: String in EffectCatalog.keys():
		if key.begins_with("faction:") or (key.begins_with("tactic:") and key.contains("/Test ")):
			EffectCatalog._entries.erase(key)


## Answers each request with [param handler], a Callable taking the [DecisionRequest] and giving a
## [Decision], or null to stop there. Returns the request it stopped at, or null if the battle ended
## or [param limit] answers were given.
static func drive(on_game: GameController, handler: Callable, limit := 400) -> DecisionRequest:
	var request := on_game.next_decision()
	var steps := 0
	while request and steps < limit:
		var decision: Decision = handler.call(request)
		if decision == null:
			return request
		on_game.answer(decision)
		request = on_game.next_decision()
		steps += 1
	return null


## A decision that goes along with whatever is asked: first turn, then pass everything else.
static func pass_on(request: DecisionRequest) -> Decision:
	if request.kind == DecisionRequest.Kind.FIRST_TURN:
		return Decision.choose(0)
	return Decision.pass_it()


## A seed whose first rolls of a six-sided die are [param rolls], for a test that needs to know what
## the dice give.
static func seed_for(rolls: Array[int]) -> int:
	var rng := RandomNumberGenerator.new()
	for candidate in 100000:
		rng.seed = candidate
		var matches := true
		for roll in rolls:
			if rng.randi_range(1, 6) != roll:
				matches = false
				break
		if matches:
			return candidate
	return -1


## A seed whose first [param count] rolls of a six-sided die are all at least [param at_least].
static func seed_with_rolls_at_least(count: int, at_least: int) -> int:
	var rng := RandomNumberGenerator.new()
	for candidate in 100000:
		rng.seed = candidate
		var all := true
		for _i in count:
			all = all and rng.randi_range(1, 6) >= at_least
		if all:
			return candidate
	return -1


## An action of an ability called [param ability_name] by [param user] on [param targets], for
## testing an effect without going through its phase.
static func action(on_game: GameController, user: BattleUnit, targets: Array[BattleUnit] = [], ability_name := "Test Ability") -> Action:
	var entry := AbilityEntry.new()
	entry.ability = BattleKit.ability(ability_name, PackedStringArray())
	var result := Action.new()
	result.entry = entry
	result.army = on_game.army_of(user)
	result.user = user
	result.targets = targets
	return result


## The first effect built from [param descriptor].
static func effect(descriptor: Dictionary) -> Effect:
	return Effect.build_all([descriptor])[0]
