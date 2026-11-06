class_name Predicates
extends RefCounted
## The closed list of conditions effect data can ask about (see docs/technical/effect-data.md). A
## condition is a name ("charged"), a one-key dictionary ({"target_has": "HERO"}), or a combination
## ({"any": [...]}, {"all": [...]}, {"not": ...}).


## Whether every one of [param conditions] holds.
static func all_hold(conditions: Array, context: RuleContext) -> bool:
	for condition: Variant in conditions:
		if not holds(condition, context):
			return false
	return true


## Whether [param condition] holds. One it doesn't know is an error and doesn't hold.
static func holds(condition: Variant, context: RuleContext) -> bool:
	if condition is String or condition is StringName:
		return _named(String(condition), null, context)
	if condition is Dictionary and condition.size() >= 1:
		var key: String = condition.keys()[0]
		if condition.size() > 1 and key != "within":
			push_error("A condition has more than one key: %s" % str(condition))
		return _named(key, condition[key] if key != "within" else condition, context)
	push_error("Not a condition: %s" % str(condition))
	return false


static func _state_of(unit: BattleUnit, context: RuleContext) -> UnitController:
	return context.game.controller_of(unit) if unit else null


static func _named(key: String, argument: Variant, context: RuleContext) -> bool:
	var game := context.game
	var subject := context.subject
	var unit := _state_of(subject, context)
	match key:
		"all":
			return all_hold(argument, context)
		"any":
			for condition: Variant in argument:
				if holds(condition, context):
					return true
			return false
		"not":
			return not holds(argument, context)
		"charged":
			return unit != null and unit.charged
		"ran":
			return unit != null and unit.ran
		"retreated":
			return unit != null and unit.retreated
		"set_up_this_turn":
			return unit != null and unit.set_up_serial == game.state.turn_serial
		"in_combat":
			return unit != null and game.in_combat(subject)
		"damaged":
			return unit != null and unit.damage_points > 0
		"general":
			return subject != null and subject.is_general
		"subject_has":
			return subject != null and game.stats.has_keyword(subject, argument)
		"subject_has_any":
			for keyword: String in argument:
				if subject != null and game.stats.has_keyword(subject, keyword):
					return true
			return false
		"has_ranged":
			return subject != null and subject.warscroll != null and not subject.warscroll.ranged_weapons.is_empty()
		"has_melee":
			return subject != null and subject.warscroll != null and not subject.warscroll.melee_weapons.is_empty()
		"can_fight":
			return unit != null and (unit.charged or game.in_combat(subject))
		"health_at_most":
			return subject != null and game.stats.value(subject, &"health") <= int(argument)
		"models_at_least":
			return subject != null and subject.model_count() >= int(argument)
		"permitted":
			return subject != null and game.stats.is_permitted(subject, StringName(argument))
		"enemy_within":
			if subject != null:
				for enemy in game.enemies_on_battlefield(game.army_of(subject)):
					if BattleGeometry.is_within(subject, enemy, float(argument)):
						return true
			return false
		"can_shoot":
			return subject != null and game.attacks.has_targets(subject, false)
		"damage_points_at_least":
			return unit != null and unit.damage_points >= int(argument)
		"target_health_greater":
			return subject != null and context.target != null and game.stats.value(context.target, &"health") > game.stats.value(subject, &"health")
		"near_friendly":
			# {"near_friendly": {"keywords": ["WIZARD", "PRIEST"], "within": 12, "wholly": true}}: any of them.
			return subject != null and _near_friendly(argument, subject, game)
		"subject_named":
			return subject != null and subject.warscroll != null and subject.warscroll.name == argument
		"has_slain_models":
			return subject != null and not subject.slain_bases.is_empty()
		"counter_at_least":
			return unit != null and unit.counter(argument.name) >= int(argument.value)
		"on_objective":
			return subject != null and game.objectives.contests_any(subject)
		"target_has":
			return context.target != null and game.stats.has_keyword(context.target, argument)
		"target_charged":
			var target := _state_of(context.target, context)
			return target != null and target.charged
		"target_contests":
			return context.target != null and game.objectives.contests_named(context.target, argument)
		"target_contests_large_terrain":
			return context.target != null and game.objectives.contests_large_terrain(context.target)
		"attacker_has":
			return context.attacker != null and game.stats.has_keyword(context.attacker, argument)
		"melee":
			return context.is_melee()
		"shooting":
			return context.is_shooting()
		"weapon_has":
			return context.weapon != null and game.attacks.weapon_has(context.weapon, argument, context)
		"holder_charged":
			var holder: UnitController = context.holder as UnitController
			return holder != null and holder.charged
		"holder_in_combat_with_subject":
			var holder: UnitController = context.holder as UnitController
			return holder != null and subject != null and BattleGeometry.in_combat_with(holder.unit, subject)
		"within":
			# {"within": 6, "of": "holder", "wholly": true}
			var of_unit := _unit_named(argument.get("of", "holder"), context)
			if of_unit == null or subject == null:
				return false
			var reach := float(argument.within)
			return BattleGeometry.is_wholly_within(subject, of_unit, reach) if argument.get("wholly", false) \
					else BattleGeometry.is_within(subject, of_unit, reach)
		"covered_by_holder":
			var terrain := context.holder as TerrainController
			return terrain != null and terrain.covers(context.attacker, context.target)
		"underdog":
			return subject != null and game.army_of(subject) == game.state.underdog
		"round_at_least":
			return game.state.round_number >= int(argument)
		"your_turn":
			return subject != null and game.army_of(subject) == game.state.active
	push_error("Unknown condition '%s'" % key)
	return false


static func _unit_named(which: String, context: RuleContext) -> BattleUnit:
	match which:
		"holder":
			var holder := context.holder as UnitController
			return holder.unit if holder else null
		"target":
			return context.target
		"attacker":
			return context.attacker
	return null


static func _near_friendly(spec: Dictionary, subject: BattleUnit, game: GameController) -> bool:
	for friend in game.on_battlefield(game.army_of(subject)):
		if friend == subject:
			continue
		var fits: bool = spec.get("keywords", []).is_empty()
		for keyword: String in spec.get("keywords", []):
			fits = fits or game.stats.has_keyword(friend, keyword)
		if not fits:
			continue
		var reach := float(spec.get("within", 0))
		var near: bool = BattleGeometry.is_wholly_within(subject, friend, reach) if spec.get("wholly", false) else BattleGeometry.is_within(subject, friend, reach)
		if near:
			return true
	return false
