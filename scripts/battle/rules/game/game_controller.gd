class_name GameController
extends RefCounted
## Runs a battle from the end of deployment to its result: battle rounds, turns and phases, and the
## overall state. It holds a stack of [GameFrame]s: [BattleSequence] at the bottom, then a phase, then
## abilities and reactions on top. [method next_decision] runs them until someone has to choose;
## [method answer] gives them the choice. Nothing here knows whether that's the player or the AI, or
## anything about nodes: headless, a battle is
## [code]while request: game.answer(ai.decide(request, game))[/code]. See docs/technical/rules-engine.md.

var battle: Battle
var core: CoreRules
var rng: RandomNumberGenerator
var deployment: Deployment
var rules: BattleRules
var state := GameState.new()
var events := EventBus.new()
var usage: UsageLedger
var stats: StatResolver
var attacks: AttackRules
var objectives: ObjectiveControl
## Each unit's controller, by [BattleUnit].
var controllers := {}
## Each terrain feature's controller, by [BattleTerrain].
var terrain_controllers := {}
## Passives that apply to a whole army rather than one unit, by [BattleArmy].
var army_holders := {}
## Each army's abilities, by [BattleArmy].
var books := {}
## Who summoned each manifestation, by [BattleUnit].
var _summoned_by := {}
## The current phase, or null.
var phase: PhaseController
## What each decision was answered with, for replaying.
var answers: Array[Dictionary] = []
## What the current Spearhead twist has picked: see [SpearheadTwists].
var twist_picks := {}

var _stack: Array[GameFrame] = []
var _pending: DecisionRequest
## Every holder of modifiers, for the [StatResolver]; rebuilt when one appears.
var _holders: Array[BattlefieldController] = []


func _init(of: Battle, with_rng: RandomNumberGenerator, with_core: CoreRules = null, from_deployment: Deployment = null) -> void:
	battle = of
	rng = with_rng
	core = with_core if with_core else CoreRulesCatalog.get_rules()
	deployment = from_deployment
	usage = UsageLedger.new(state)
	stats = StatResolver.new(self)
	attacks = AttackRules.new(self)
	objectives = ObjectiveControl.new(self)
	if of.is_spearhead():
		rules = SpearheadRules.new(self)
	else:
		rules = MatchedPlayRules.new(self)
	for army in armies():
		state.victory_points[army] = 0
		var holder := BattlefieldController.new(self)
		army_holders[army] = holder
		_holders.append(holder)
		for unit in army.units:
			_add_unit(unit, army)
		for feature in army.terrain:
			_add_terrain(feature, army)
	for feature in of.terrain:
		_add_terrain(feature, null)
	for army in armies():
		books[army] = AbilityBook.build(self, army)
		_apply_passives(books[army])
	events.subscribe(BattleEvent.UNIT_DESTROYED, _on_unit_destroyed)
	_stack.append(BattleSequence.new())


## Breaks the references between the game and its controllers, so they can be freed.
func dispose() -> void:
	events.clear_listeners()
	controllers.clear()
	terrain_controllers.clear()
	army_holders.clear()
	_holders.clear()
	books.clear()
	_stack.clear()
	phase = null
	_pending = null


func armies() -> Array[BattleArmy]:
	var result: Array[BattleArmy] = [battle.player, battle.opponent]
	return result


## What the log calls [param army]: both armies can have the same name.
func side_name(army: BattleArmy) -> String:
	return "Player" if army == battle.player else "Opponent"


func _add_unit(unit: BattleUnit, army: BattleArmy) -> UnitController:
	var controller := UnitController.new(self, unit, army)
	controllers[unit] = controller
	_holders.append(controller)
	return controller


func _add_terrain(feature: BattleTerrain, army: BattleArmy) -> void:
	var controller := TerrainController.new(self, feature)
	terrain_controllers[feature] = controller
	_holders.append(controller)
	# A faction terrain feature fights and takes damage as a unit (Terrain 1.5).
	if feature.kind == BattleTerrain.Kind.FACTION and feature.warscroll and army:
		var stand_in := BattleUnit.create(feature.name, feature.warscroll, 1)
		stand_in.positions = PackedVector2Array([feature.position])
		stand_in.deployed = feature.placed
		controller.proxy = _add_unit(stand_in, army)
		controller.proxy.is_terrain = true


# The decision loop

## What needs answering next, running the battle until something does. Null when the battle is over.
func next_decision() -> DecisionRequest:
	var guard := 0
	while _pending == null and not _stack.is_empty():
		var frame: GameFrame = _stack.back()
		_pending = frame.advance(self)
		if _pending == null and frame.finished:
			_stack.erase(frame)
		guard += 1
		if guard > 100000:
			push_error("The battle isn't moving on.")
			return null
	return _pending


## Answers what [method next_decision] asked. Returns why it can't be done, or empty.
func answer(decision: Decision) -> String:
	if _pending == null:
		return "Nothing is being asked."
	var reason: String = _stack.back().answer(self, _pending, decision)
	if reason.is_empty():
		answers.append({"kind": _pending.kind, "army": _pending.army, "decision": decision})
		_pending = null
	return reason


## Runs [param frame] before going on with the current one.
func push(frame: GameFrame) -> void:
	_stack.append(frame)


func is_over() -> bool:
	return state.is_over()


# Things to ask about the battlefield

func controller_of(unit: BattleUnit) -> UnitController:
	return controllers.get(unit)


func army_of(unit: BattleUnit) -> BattleArmy:
	var controller := controller_of(unit)
	return controller.army if controller else null


## Everything holding modifiers, for the [StatResolver].
func modifier_holders() -> Array[BattlefieldController]:
	return _holders


## [param army]'s units on the battlefield.
func on_battlefield(army: BattleArmy) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in army.units:
		if unit.is_on_battlefield() and not unit.destroyed:
			result.append(unit)
	return result


## The units of [param army]'s enemy on the battlefield, faction terrain included.
func enemies_on_battlefield(army: BattleArmy) -> Array[BattleUnit]:
	var enemy := battle.enemy_of(army)
	var result := on_battlefield(enemy)
	for feature in enemy.terrain:
		var controller: TerrainController = terrain_controllers.get(feature)
		if controller and controller.proxy and feature.placed and not controller.proxy.unit.destroyed:
			controller.proxy.unit.positions = PackedVector2Array([feature.position])
			controller.proxy.unit.deployed = true
			result.append(controller.proxy.unit)
	return result


## Who [param unit] could attack.
func attackable_by(unit: BattleUnit) -> Array[BattleUnit]:
	return enemies_on_battlefield(army_of(unit))


func in_combat(unit: BattleUnit) -> bool:
	if not unit.is_on_battlefield():
		return false
	for enemy in enemies_on_battlefield(army_of(unit)):
		if BattleGeometry.in_combat_with(unit, enemy):
			return true
	return false


func enemies_in_combat_with(unit: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for enemy in enemies_on_battlefield(army_of(unit)):
		if BattleGeometry.in_combat_with(unit, enemy):
			result.append(enemy)
	return result


## The nearest enemy [param unit] is in combat with, or null.
func nearest_in_combat(unit: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_gap := INF
	for enemy in enemies_in_combat_with(unit):
		var gap := BattleGeometry.unit_gap(unit, enemy)
		if gap < best_gap:
			best = enemy
			best_gap = gap
	return best


func was_set_up_this_turn(unit: BattleUnit) -> bool:
	return controller_of(unit).set_up_serial == state.turn_serial


## What's wrong with setting [param unit] up at [param positions], anywhere more than
## [param min_enemy_gap] from all enemies.
func set_up_problems(unit: BattleUnit, positions: PackedVector2Array, min_enemy_gap: float, near_unit: BattleUnit = null, near_reach := 0.0) -> PackedStringArray:
	var result := PackedStringArray()
	if near_unit:
		var placed := MovementRules._at(unit, positions)
		if not BattleGeometry.is_wholly_within(placed, near_unit, near_reach):
			result.append("It has to be wholly within %d\" of %s." % [int(near_reach), near_unit.name])
	if positions.size() != unit.model_count():
		result.append("Every model has to be set up.")
		return result
	var enemies := enemies_on_battlefield(army_of(unit))
	var others := MovementRules._other_units(self, unit)
	var solid := MovementRules._impassable_terrain(self)
	for i in positions.size():
		if not BattleGeometry.is_on_battlefield(unit.bases[i], positions[i], unit.facing, battle.battlefield_size):
			result.append("A model is off the battlefield.")
			break
		var too_near := false
		for enemy in enemies:
			if BattleGeometry.model_gap_at(unit.bases[i], positions[i], unit.facing, enemy) <= min_enemy_gap:
				too_near = true
		if too_near:
			result.append("A model is too near an enemy.")
			break
		if MovementRules._ends_on_other(unit.bases[i], positions[i], unit.facing, others, solid):
			result.append("A model is on another model.")
			break
	if not Coherency.is_coherent(positions, unit.bases, unit.facing):
		result.append("The unit isn't coherent.")
	return result


# Using abilities

## What [param army] can use in [param window] now.
func options_in(window: AbilityTiming.Moment, army: BattleArmy) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	var is_your_turn := army == state.active
	for entry: AbilityEntry in books[army]:
		if not entry.is_supported() or not entry.timing.fits(window, is_your_turn):
			continue
		if entry.timing.first_round_only and state.round_number != 1:
			continue
		for user: Variant in _users_for(entry, null):
			if reason_unavailable(entry, user).is_empty():
				result.append(ActionOption.create(entry, user))
	return result


## [param army]'s abilities for [param window] that have no effect data yet: for the HUD to show.
func unsupported_in(window: AbilityTiming.Moment, army: BattleArmy) -> Array[AbilityEntry]:
	var result: Array[AbilityEntry] = []
	var is_your_turn := army == state.active
	for entry: AbilityEntry in books[army]:
		if not entry.is_supported() and entry.timing.fits(window, is_your_turn) and entry.source != "Core":
			if entry.owner_unit == null or entry.owner_unit.is_on_battlefield():
				result.append(entry)
	return result


## What [param army] can react to [param action] with.
func reaction_options(action: Action, army: BattleArmy) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	for entry: AbilityEntry in books[army]:
		if entry.timing.window != AbilityTiming.Moment.REACTION or not entry.is_supported():
			continue
		if not _reaction_fits(entry, action, army):
			continue
		if entry.descriptor.get("once_per_parent", false) and action.flags.has(entry.ability.name):
			continue
		for user: Variant in _users_for(entry, action):
			if reason_unavailable(entry, user).is_empty() and _reaction_user_fits(entry, action, user):
				result.append(ActionOption.create(entry, user))
	return result


func _reaction_fits(entry: AbilityEntry, action: Action, army: BattleArmy) -> bool:
	var timing := entry.timing
	if timing.to_opponent != (action.army != army):
		return false
	if timing.within_window != AbilityTiming.Moment.UNKNOWN and timing.within_window != state.window:
		return false
	if not timing.trigger_ability.is_empty():
		return timing.trigger_ability.to_lower() == action.ability().name.to_lower()
	if timing.trigger_command:
		return action.ability().type == "command"
	for keyword in timing.trigger_excludes:
		if action.has_keyword(keyword):
			return false
	if timing.reacts_to_any:
		return true
	if timing.trigger_keywords.is_empty():
		return false
	for keyword in timing.trigger_keywords:
		if action.has_keyword(keyword):
			return true
	return false


func _reaction_user_fits(entry: AbilityEntry, action: Action, user: Variant) -> bool:
	var timing := entry.timing
	if timing.this_unit_only and user != action.user:
		return false
	if timing.this_unit_targeted and not user in action.targets:
		return false
	return true


## Who can use [param entry]: a list of units, or [code][null][/code] if the player does.
func _users_for(entry: AbilityEntry, parent: Action) -> Array:
	var spec: Dictionary = entry.descriptor.get("user", {})
	var from: String = spec.get("from", _default_user_source(entry))
	var candidates: Array = []
	match from:
		"owner":
			if entry.owner_unit:
				candidates.append(entry.owner_unit)
		"parent_user":
			if parent and parent.user:
				candidates.append(parent.user)
		"parent_targets":
			if parent:
				candidates.append_array(parent.targets.filter(func(unit: BattleUnit) -> bool: return army_of(unit) == entry.army))
		"any":
			candidates.append_array(on_battlefield(entry.army))
		"reserve":
			return _reserves_for(entry, spec)
		_:
			return [null]
	return candidates.filter(func(unit: BattleUnit) -> bool:
		if spec.has("within_parent_user") and (parent == null or parent.user == null or not BattleGeometry.is_within(unit, parent.user, float(spec.within_parent_user))):
			return false
		return _user_qualifies(unit, spec))


## The units in reserve that can use [param entry]: those [code]names[/code] says, or all of them.
func _reserves_for(entry: AbilityEntry, spec: Dictionary) -> Array:
	var names: Array = spec.get("names", [])
	return entry.army.units.filter(func(unit: BattleUnit) -> bool:
		if unit.destroyed or unit.reserve.is_empty() or not (names.is_empty() or unit.name in names):
			return false
		return Predicates.all_hold(spec.get("when", []), RuleContext.of_unit(self, unit)))


## Without being told, a warscroll's ability is its unit's, a reaction's user comes from its "Used
## By" line, and anything else is the player's.
func _default_user_source(entry: AbilityEntry) -> String:
	var used_by := entry.ability.used_by.to_lower()
	if used_by.contains("using that"):
		return "parent_user"
	if used_by.contains("targeted by"):
		return "parent_targets"
	return "owner" if entry.owner_unit else "player"


func _user_qualifies(unit: BattleUnit, spec: Dictionary) -> bool:
	if not unit.is_on_battlefield():
		return false
	for keyword: String in spec.get("keywords", []):
		if not stats.has_keyword(unit, keyword):
			return false
	return Predicates.all_hold(spec.get("when", []), RuleContext.of_unit(self, unit))


## Why [param user] can't use [param entry] now, or empty if it can: what [method options_in] and the
## HUD go by.
func reason_unavailable(entry: AbilityEntry, user: BattleUnit) -> String:
	if not entry.is_supported():
		return "Not supported yet."
	var ability := entry.ability
	var limit := usage.reason_unavailable(ability, entry.army, user)
	if not limit.is_empty():
		return limit
	if rules.uses_magic() and user and (ability.type in ["spell", "prayer"] or "BANISH" in ability.keywords):
		if usage.casts_this_phase(user) >= power_level(user):
			return "This unit has used its power this phase."
	if user and user.destroyed:
		return "This unit is destroyed."
	if rules.uses_commands() and ability.command_points > state.commands_of(entry.army):
		return "Not enough command points."
	# A unit set up this turn can't use MOVE abilities in the movement phase (24.0).
	if user and "MOVE" in ability.keywords and state.window == AbilityTiming.Moment.MOVEMENT and was_set_up_this_turn(user):
		return "Set up this turn."
	var target_spec: Dictionary = entry.descriptor.get("target", {})
	if not target_spec.is_empty():
		var probe := Action.new()
		probe.entry = entry
		probe.army = entry.army
		probe.user = user
		if eligible_targets(probe, target_spec).is_empty():
			return "No target."
	return ""


## Who the ability can target, from its data: [code]side[/code], [code]within[/code] of the user,
## [code]wholly[/code], [code]keywords[/code], [code]not_keywords[/code], [code]when[/code] and
## [code]closest[/code] to take only the nearest. See docs/technical/effect-data.md.
func eligible_targets(action: Action, spec: Dictionary) -> Array[BattleUnit]:
	var side: String = spec.get("side", "enemy")
	var pool: Array[BattleUnit] = on_battlefield(action.army) if side == "friendly" else enemies_on_battlefield(action.army)
	var result: Array[BattleUnit] = []
	for unit in pool:
		if _target_fits(unit, action, spec):
			result.append(unit)
	if spec.get("closest", false) and action.user and result.size() > 1:
		var nearest := result[0]
		for unit in result:
			if BattleGeometry.unit_gap(action.user, unit) < BattleGeometry.unit_gap(action.user, nearest):
				nearest = unit
		var only: Array[BattleUnit] = [nearest]
		return only
	return result


func _target_fits(unit: BattleUnit, action: Action, spec: Dictionary) -> bool:
	for keyword: String in spec.get("keywords", []):
		if not stats.has_keyword(unit, keyword):
			return false
	for keyword: String in spec.get("not_keywords", []):
		if stats.has_keyword(unit, keyword):
			return false
	if spec.has("within") and action.user:
		var reach := float(spec.within)
		var inside := BattleGeometry.is_wholly_within(unit, action.user, reach) if spec.get("wholly", false) \
				else BattleGeometry.is_within(unit, action.user, reach)
		if not inside:
			return false
	if spec.get("others", false) and unit == action.user:
		return false
	if spec.get("lower_health_than_user", false) and action.user and stats.value(unit, &"health") >= stats.value(action.user, &"health"):
		return false
	return Predicates.all_hold(spec.get("when", []), RuleContext.of_unit(self, unit))


## Records that an ability is being used, pays for it and tells everyone.
func declare_action(action: Action) -> void:
	usage.mark(action.ability(), action.army, action.user)
	if action.user and (action.ability().type in ["spell", "prayer"] or action.has_keyword("BANISH")):
		usage.mark_cast(action.user)
	if rules.uses_commands() and action.ability().command_points > 0:
		state.command_points[action.army] = state.commands_of(action.army) - action.ability().command_points
	if action.entry.card and rules is SpearheadRules:
		(rules as SpearheadRules).discard(action.army, action.entry.card)
	var by := "%s (%s)" % [action.ability().name, action.user.name] if action.user else action.ability().name
	events.publish(BattleEvent.ABILITY_DECLARED, {"action": action, "text": "%s uses %s." % [side_name(action.army), by]})


func finish_action(action: Action) -> void:
	if phase:
		phase.record_use(action)
	if action.user and action.has_keyword("FIGHT"):
		controller_of(action.user).fought_serial = state.turn_serial
		state.count_turn(action.army, &"fought")
	events.publish(BattleEvent.ABILITY_RESOLVED, {"action": action, "text": ""})


## Sends [param command] to [param unit]'s controller, holding events until it has finished.
func command(unit: BattleUnit, what: RefCounted) -> String:
	var controller := controller_of(unit)
	if controller == null:
		return "No such unit."
	events.hold()
	var reason := controller.handle(what)
	events.release()
	return reason


## Rolls [param dice] for [param action] as [param roll_name] and tells everyone.
func make_roll(action: Action, roll_name: String, dice: DiceExpr) -> int:
	var rolled := dice
	if roll_name == "charge" and action.user:
		# 'Grasping Vines' takes a dice away.
		rolled = DiceExpr.parse("%dD%d" % [maxi(dice.count + stats.roll_modifier(&"charge_dice", RuleContext.of_unit(self, action.user)), 1), dice.sides])
	var result := rolled.roll(rng)
	action.rolls[roll_name] = result
	events.publish(BattleEvent.ROLL_MADE, {"action": action, "name": roll_name, "value": result, "unit": action.user,
			"text": "%s rolls %d for %s." % [action.user.name if action.user else side_name(action.army), result, action.ability().name if roll_name == "gate" else roll_name]})
	return result


# Passives, triggers and cards

func _apply_passives(entries: Array[AbilityEntry]) -> void:
	for entry in entries:
		var holder: BattlefieldController = controller_of(entry.owner_unit) if entry.owner_unit else army_holders[entry.army]
		for descriptor: Dictionary in entry.descriptor.get("passive", []):
			var modifier := Modifier.from_descriptor(descriptor, entry.ability.name, entry.army)
			modifier.passive = true
			if entry.owner_unit == null and modifier.aura.is_empty():
				modifier.aura = {"side": "friendly"}
			holder.modifiers.add(modifier)
		var trigger: Dictionary = entry.descriptor.get("trigger", {})
		if not trigger.is_empty():
			events.subscribe(StringName(trigger.get("event", "")), _on_trigger.bind(entry, trigger))


## A passive ability's effect, on the event it waits for. Only effects that ask nothing can trigger.
func _on_trigger(event: BattleEvent, entry: AbilityEntry, trigger: Dictionary) -> void:
	var data := event.data
	var unit: BattleUnit = data.get("unit")
	if unit == null or army_of(unit) != entry.army:
		return
	if trigger.has("roll") and data.get("name") != trigger.roll:
		return
	if trigger.has("at_least") and int(data.get("value", 0)) < int(trigger.at_least):
		return
	if not Predicates.all_hold(trigger.get("when", []), RuleContext.of_unit(self, unit)):
		return
	var action := Action.new()
	action.entry = entry
	action.army = entry.army
	action.user = unit
	for effect in Effect.build_all(trigger.get("do", [])):
		effect.resolve(action, self)


## The commands on the cards in each hand, as abilities. Called when a hand changes.
func refresh_card_abilities() -> void:
	if not rules is SpearheadRules:
		return
	var spearhead_rules := rules as SpearheadRules
	var pack_name := battle.battlepack.name
	for army in armies():
		var kept: Array[AbilityEntry] = []
		for entry: AbilityEntry in books[army]:
			if entry.card == null:
				kept.append(entry)
		for card: SpearheadTacticCard in spearhead_rules.hand_of(army):
			if card.command:
				var entry := AbilityBook.make_entry(card.command, "pack:%s/card/%s" % [pack_name, card.name], army, null, "Battle tactic card")
				entry.card = card
				kept.append(entry)
		books[army] = kept


# Scoring

func add_points(army: BattleArmy, points: int, why: String) -> void:
	state.victory_points[army] = state.points_of(army) + points
	events.publish(BattleEvent.POINTS_SCORED, {"army": army, "points": points, "text": "%s scores %d: %s" % [side_name(army), points, why]})


func complete_tactic(army: BattleArmy, tactic_name: String) -> void:
	state.tactics_completed[army] = state.tactics_of(army) + 1
	state.count_turn(army, &"tactics")
	events.publish(BattleEvent.TACTIC_COMPLETED, {"army": army, "tactic": tactic_name, "text": "%s completes %s." % [side_name(army), tactic_name]})


func _on_unit_destroyed(event: BattleEvent) -> void:
	var army: BattleArmy = event.data.army
	var unit: BattleUnit = event.data.unit
	state.count_turn(army, &"own_destroyed")
	state.count_turn(battle.enemy_of(army), &"enemy_destroyed")
	if unit.is_general:
		state.count_turn(battle.enemy_of(army), &"general_slain")
		state.generals_slain[army] = true
	_sever_connections(unit)


## A manifestation goes when its summoner is slain (Magic 7.1).
func _sever_connections(summoner: BattleUnit) -> void:
	for manifestation: BattleUnit in _summoned_by.keys():
		if _summoned_by[manifestation] == summoner:
			_summoned_by.erase(manifestation)
			command(manifestation, Commands.Destroy.new())


## Makes the manifestation with warscroll id [param warscroll_id] for [param army], not set up yet,
## or null if there's no such warscroll, or it's already on the battlefield (Magic 7.0).
func summon(warscroll_id: String, army: BattleArmy, summoner: BattleUnit) -> BattleUnit:
	for unit in army.units:
		if unit.warscroll and unit.warscroll.id == warscroll_id and unit.is_on_battlefield():
			return null
	var scroll := core.get_manifestation(warscroll_id) if core else null
	if scroll == null:
		var faction := FactionCatalog.load_faction(army.faction_name)
		scroll = faction.get_warscroll(warscroll_id) if faction else null
	if scroll == null:
		return null
	var unit := BattleUnit.create(scroll.name, scroll, maxi(scroll.unit_size, 1))
	unit.facing = army.facing
	lay_out(unit, BattleGeometry.middle(summoner) if summoner else battle.battlefield_size / 2)
	army.units.append(unit)
	_add_unit(unit, army)
	if summoner:
		_summoned_by[unit] = summoner
	return unit


## Stands [param unit], not on the battlefield yet, in a block around [param at], for whoever's
## setting it up to move about.
func lay_out(unit: BattleUnit, at: Vector2) -> void:
	unit.positions = Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, at, unit.facing)


## How many spells, prayers and banishes [param unit] can use each phase: its power level (Magic 1.1).
func power_level(unit: BattleUnit) -> int:
	if unit.warscroll == null:
		return 0
	for keyword in unit.warscroll.keywords:
		if keyword.begins_with("WIZARD (") or keyword.begins_with("PRIEST ("):
			return keyword.get_slice("(", 1).to_int()
	return 0
