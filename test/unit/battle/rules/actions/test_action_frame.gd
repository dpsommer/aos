extends GutTest
## Using an ability: targets, casting and chanting, reactions, the gate roll and the damage sequence.

const RulesKit := preload("res://test/support/rules_kit.gd")

const HERO := "Hero"

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()
	RulesKit.forget_abilities()


func _unit(unit_name: String, at: Vector2, keywords := PackedStringArray()) -> BattleUnit:
	return RulesKit.unit(unit_name, 1, at, keywords, 100, 0)


func _game(mine: Array[BattleUnit], theirs: Array[BattleUnit], seed_value := 1) -> GameController:
	var game := RulesKit.matched_game(mine, theirs, seed_value)
	_games.append(game)
	return game


## The ability [param ability_name] on [param unit], for [param timing], doing [param effects] to
## the nearest enemy.
func _give(unit: BattleUnit, ability_name: String, type: String, effects: Array, extra := {}, keywords := PackedStringArray()) -> Ability:
	var ability := RulesKit.ability(ability_name, "Your Hero Phase", type, keywords)
	var descriptor := {"target": {"side": "enemy", "within": 30}, "do": effects}
	descriptor.merge(extra, true)
	RulesKit.add_ability(unit, ability, descriptor)
	return ability


func _mortal(amount := "5") -> Array:
	return [{"op": "mortal", "amount": amount}]


## Plays to the player's hero phase and uses [param ability_name] with its first user. Reactions are
## answered by [param on_reaction] (Callable of the request, giving a Decision). Returns what it was asked.
func _use(game: GameController, ability_name: String, on_reaction := Callable()) -> Array[DecisionRequest]:
	var asked: Array[DecisionRequest] = []
	var used := [false]
	RulesKit.drive(game, func(request: DecisionRequest) -> Decision:
		asked.append(request)
		if request.kind == DecisionRequest.Kind.ACTION and not used[0]:
			for option in request.options:
				if option.ability_name() == ability_name:
					used[0] = true
					return Decision.use(option)
		if request.kind == DecisionRequest.Kind.REACTION and on_reaction.is_valid():
			return on_reaction.call(request)
		if request.kind == DecisionRequest.Kind.TARGETS:
			return Decision.pick([request.units[0]] as Array[BattleUnit])
		if used[0] and request.kind == DecisionRequest.Kind.ACTION:
			return null
		return RulesKit.pass_on(request), 200)
	return asked


func _damage_of(game: GameController, unit: BattleUnit) -> int:
	return game.controller_of(unit).damage_points


func _caster_game(spell_type: String, value: int, effects := _mortal(), seed_value := 1, extra := {}, caster_keywords := ["WIZARD (1)"]) -> GameController:
	var caster := _unit("Caster", Vector2(10, 10), PackedStringArray(caster_keywords))
	var enemy := _unit("Enemy", Vector2(20, 10), PackedStringArray(["WIZARD (1)"]))
	var spell := _give(caster, "Test Spell", spell_type, effects, extra, PackedStringArray(["SPELL"] if spell_type == "spell" else ["PRAYER"]))
	spell.casting_value = value if spell_type == "spell" else 0
	spell.chanting_value = value if spell_type == "prayer" else 0
	# The ability's hash includes its text, not these, so the descriptor stays valid.
	return _game([caster] as Array[BattleUnit], [enemy] as Array[BattleUnit], seed_value)


func _rolls(game: GameController, roll_name: String) -> Array[int]:
	var result: Array[int] = []
	for event in game.events.log_entries:
		if event.kind == BattleEvent.ROLL_MADE and event.data.get("name") == roll_name:
			result.append(event.data.value)
	return result


# Casting

func test_a_spell_cast_with_a_high_enough_roll_has_its_effect() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([3, 4]))
	_use(game, "Test Spell")
	assert_eq(_rolls(game, "casting"), [7] as Array[int], "The dice went as planned")
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 5)


func test_a_spell_cast_with_a_low_roll_has_no_effect() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([1, 2]))
	_use(game, "Test Spell")
	assert_eq(_rolls(game, "casting"), [3] as Array[int])
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 0)


func test_a_casting_modifier_adds_to_the_roll() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([2, 4]))
	RulesKit.give(game, game.battle.player.units[0], RulesKit.modifier(&"casting", 1, game.battle.player))
	_use(game, "Test Spell")
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 5, "6 and +1 reaches 7")


func test_a_miscast_has_no_effect_even_if_the_total_is_enough() -> void:
	var game := _caster_game("spell", 2, _mortal(), RulesKit.seed_for([1, 1]))
	_use(game, "Test Spell")
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 0)


func test_a_miscast_hurts_the_caster() -> void:
	var game := _caster_game("spell", 2, _mortal(), RulesKit.seed_for([1, 1]))
	_use(game, "Test Spell")
	var hurt := _damage_of(game, game.battle.player.units[0])
	assert_between(hurt, 1, 3)


## How many casts [param game]'s first player unit has used when its first ability is resolved.
func _casts_when_resolved(game: GameController, ability_name: String) -> int:
	var caster := game.battle.player.units[0]
	var seen: Array[int] = []
	game.events.subscribe(BattleEvent.ABILITY_RESOLVED, func(_event: BattleEvent) -> void: seen.append(game.usage.casts_this_phase(caster)))
	_use(game, ability_name)
	return seen[0] if not seen.is_empty() else -1


func test_a_miscast_uses_up_the_casters_power_for_the_phase() -> void:
	var game := _caster_game("spell", 2, _mortal(), RulesKit.seed_for([1, 1]))
	assert_gte(_casts_when_resolved(game, "Test Spell"), game.power_level(game.battle.player.units[0]))


func test_a_spell_cast_counts_against_the_casters_power() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([3, 4]))
	assert_eq(_casts_when_resolved(game, "Test Spell"), 1)


func test_a_wizard_that_has_used_its_power_cannot_cast_another_spell() -> void:
	var caster := _unit("Caster", Vector2(10, 10), PackedStringArray(["WIZARD (1)"]))
	var other := _give(caster, "Other Spell", "spell", _mortal(), {}, PackedStringArray(["SPELL"]))
	other.casting_value = 2
	var first := _give(caster, "Test Spell", "spell", _mortal(), {}, PackedStringArray(["SPELL"]))
	first.casting_value = 2
	var game := _game([caster] as Array[BattleUnit], [_unit("Enemy", Vector2(20, 10))] as Array[BattleUnit], RulesKit.seed_for([3, 4]))
	var asked := _use(game, "Test Spell")
	assert_false(asked.is_empty())
	var entry: AbilityEntry
	for each: AbilityEntry in game.books[game.battle.player]:
		if each.ability.name == "Other Spell":
			entry = each
	assert_ne(game.reason_unavailable(entry, caster), "")


func test_a_unit_that_is_not_a_wizard_cannot_cast() -> void:
	var game := _caster_game("spell", 2, _mortal(), 1, {}, [])
	var asked := _use(game, "Test Spell")
	var offered := false
	for request in asked:
		for option in request.options:
			offered = offered or option.ability_name() == "Test Spell"
	assert_false(offered)


# Unbinding

func _unbinder(request: DecisionRequest) -> Decision:
	for option in request.options:
		if option.ability_name() == "Unbind":
			return Decision.use(option)
	return Decision.pass_it()


func test_an_unbinding_roll_that_beats_the_casting_roll_stops_the_spell() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([3, 4, 6, 5]))
	_use(game, "Test Spell", _unbinder)
	assert_eq(_rolls(game, "unbinding"), [11] as Array[int])
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 0)


func test_an_unbinding_roll_that_does_not_beat_the_casting_roll_leaves_the_spell() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([3, 4, 1, 2]))
	_use(game, "Test Spell", _unbinder)
	assert_eq(_rolls(game, "unbinding"), [3] as Array[int])
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 5)


func test_an_unbinding_roll_that_equals_the_casting_roll_leaves_the_spell() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([3, 4, 3, 4]))
	_use(game, "Test Spell", _unbinder)
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 5)


func test_a_spell_that_failed_to_cast_cannot_be_unbound() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([1, 2]))
	var asked := _use(game, "Test Spell", _unbinder)
	for request in asked:
		assert_ne(request.kind, DecisionRequest.Kind.REACTION)


func test_unbinding_is_not_limited_to_the_power_of_the_unbinder() -> void:
	var game := _caster_game("spell", 7, _mortal(), RulesKit.seed_for([3, 4, 1, 2]))
	var enemy := game.battle.opponent.units[0]
	var seen: Array[int] = []
	game.events.subscribe(BattleEvent.ABILITY_RESOLVED, func(_event: BattleEvent) -> void: seen.append(game.usage.casts_this_phase(enemy)))
	_use(game, "Test Spell", _unbinder)
	assert_false(seen.is_empty())
	assert_eq(seen.max(), 0, "Unbinding doesn't use the unbinder's power")


# Banishing

func _banish_game(manifestations: int, banishment: int, seed_value: int) -> GameController:
	var caster := _unit("Caster", Vector2(10, 10), PackedStringArray(["WIZARD (1)"]))
	var theirs: Array[BattleUnit] = []
	for i in manifestations:
		var manifestation := _unit("Manifestation %d" % i, Vector2(20, 5 + 3 * i), PackedStringArray(["MANIFESTATION"]))
		manifestation.warscroll.banishment = banishment
		theirs.append(manifestation)
	return _game([caster] as Array[BattleUnit], theirs, seed_value)


func test_banishing_with_a_roll_that_reaches_the_banishment_value_destroys_the_manifestation() -> void:
	var game := _banish_game(1, 7, RulesKit.seed_for([4, 3]))
	_use(game, "Banish Manifestation")
	assert_true(game.battle.opponent.units[0].destroyed)


func test_banishing_with_a_low_roll_leaves_the_manifestation() -> void:
	var game := _banish_game(1, 7, RulesKit.seed_for([1, 2]))
	_use(game, "Banish Manifestation")
	assert_false(game.battle.opponent.units[0].destroyed)


func test_each_other_manifestation_adds_one_to_the_banishing_roll() -> void:
	var game := _banish_game(2, 7, RulesKit.seed_for([3, 3]))
	_use(game, "Banish Manifestation")
	assert_true(game.battle.opponent.units[0].destroyed, "6 and 1 for the other one reaches 7")


func test_banishing_uses_up_the_casters_power() -> void:
	var game := _banish_game(1, 7, RulesKit.seed_for([1, 2]))
	assert_eq(_casts_when_resolved(game, "Banish Manifestation"), 1)


# Chanting

func _chanter_game(value: int, seed_roll: int, effects := _mortal()) -> GameController:
	return _caster_game("prayer", value, effects, RulesKit.seed_for([seed_roll]), {}, ["PRIEST (1)"])


func _ritual(game: GameController) -> int:
	return game.controller_of(game.battle.player.units[0]).counter(EffectHooks.RITUAL_POINTS)


func test_a_chanting_roll_that_reaches_the_value_answers_the_prayer() -> void:
	var game := _chanter_game(4, 4)
	_use(game, "Test Spell")
	assert_eq(_rolls(game, "chanting"), [4] as Array[int])
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 5)


func test_a_chanting_roll_that_falls_short_is_banked_as_ritual_points() -> void:
	var game := _chanter_game(6, 4)
	_use(game, "Test Spell")
	assert_eq(_ritual(game), 4)
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 0)


func test_ritual_points_add_to_the_next_chanting_roll() -> void:
	var game := _chanter_game(6, 4)
	game.command(game.battle.player.units[0], Commands.ChangeCounter.new(EffectHooks.RITUAL_POINTS, 2))
	_use(game, "Test Spell")
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 5, "4 and 2 reaches 6")


func test_answering_a_prayer_spends_the_ritual_points() -> void:
	var game := _chanter_game(6, 4)
	game.command(game.battle.player.units[0], Commands.ChangeCounter.new(EffectHooks.RITUAL_POINTS, 2))
	_use(game, "Test Spell")
	assert_eq(_ritual(game), 0)


func test_a_chanting_modifier_adds_to_the_roll() -> void:
	var game := _chanter_game(6, 4)
	RulesKit.give(game, game.battle.player.units[0], RulesKit.modifier(&"chanting", 2, game.battle.player))
	_use(game, "Test Spell")
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 5)


func test_an_unmodified_one_loses_ritual_points_and_fails() -> void:
	var game := _chanter_game(2, 1)
	game.command(game.battle.player.units[0], Commands.ChangeCounter.new(EffectHooks.RITUAL_POINTS, 3))
	_use(game, "Test Spell")
	assert_lt(_ritual(game), 3)
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 0, "Even with points enough to answer it")


func test_an_unmodified_one_cannot_lose_more_points_than_there_are() -> void:
	var game := _chanter_game(6, 1)
	_use(game, "Test Spell")
	assert_eq(_ritual(game), 0)


# The gate roll

func test_a_failed_gate_roll_stops_the_effect() -> void:
	var game := _caster_game("spell", 2, _mortal(), RulesKit.seed_for([3, 4]), {"gate": {"name": "gate", "dice": "D6", "at_least": 7}})
	_use(game, "Test Spell")
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 0)


func test_a_passed_gate_roll_lets_the_effect_happen() -> void:
	var game := _caster_game("spell", 2, _mortal(), RulesKit.seed_for([3, 4]), {"gate": {"name": "gate", "dice": "D6", "at_least": 1}})
	_use(game, "Test Spell")
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 5)


# Picking targets

func _two_enemies_game() -> GameController:
	var user := _unit("User", Vector2(10, 10))
	var first := _unit("First", Vector2(20, 10))
	var second := _unit("Second", Vector2(20, 14))
	_give(user, "Strike", "active", _mortal("3"))
	return _game([user] as Array[BattleUnit], [first, second] as Array[BattleUnit])


func _at_targets(game: GameController) -> DecisionRequest:
	var used := [false]
	return RulesKit.drive(game, func(request: DecisionRequest) -> Decision:
		if request.kind == DecisionRequest.Kind.TARGETS:
			return null
		if request.kind == DecisionRequest.Kind.ACTION and not used[0]:
			for option in request.options:
				if option.ability_name() == "Strike":
					used[0] = true
					return Decision.use(option)
		return RulesKit.pass_on(request))


func test_with_two_targets_to_choose_from_the_player_is_asked() -> void:
	var game := _two_enemies_game()
	var request := _at_targets(game)
	assert_not_null(request)
	assert_eq(request.kind, DecisionRequest.Kind.TARGETS)
	assert_eq(request.units.size(), 2)


func test_the_picked_target_takes_the_damage() -> void:
	var game := _two_enemies_game()
	var request := _at_targets(game)
	var second := game.battle.opponent.units[1]
	assert_eq(game.answer(Decision.pick([second] as Array[BattleUnit])), "")
	game.next_decision()
	assert_eq(_damage_of(game, second), 3)
	assert_eq(_damage_of(game, game.battle.opponent.units[0]), 0)
	assert_not_null(request)


func test_a_unit_that_is_not_eligible_cannot_be_picked() -> void:
	var game := _two_enemies_game()
	_at_targets(game)
	var mine := game.battle.player.units[0]
	assert_ne(game.answer(Decision.pick([mine] as Array[BattleUnit])), "")


func test_the_wrong_number_of_targets_is_refused() -> void:
	var game := _two_enemies_game()
	_at_targets(game)
	assert_ne(game.answer(Decision.pick(game.battle.opponent.units.duplicate())), "")
	assert_ne(game.answer(Decision.pick([] as Array[BattleUnit])), "")


func test_a_single_eligible_target_is_picked_without_asking() -> void:
	var game := _caster_game("spell", 2, _mortal(), RulesKit.seed_for([3, 4]))
	var asked := _use(game, "Test Spell")
	for request in asked:
		assert_ne(request.kind, DecisionRequest.Kind.TARGETS)


func test_a_target_out_of_range_is_not_eligible() -> void:
	var user := _unit("User", Vector2(2, 10))
	var far := _unit("Far", Vector2(28, 10))
	_give(user, "Strike", "active", _mortal("3"), {"target": {"side": "enemy", "within": 10}})
	var game := _game([user] as Array[BattleUnit], [far] as Array[BattleUnit])
	var entry: AbilityEntry
	for each: AbilityEntry in game.books[game.battle.player]:
		if each.ability.name == "Strike":
			entry = each
	assert_eq(game.reason_unavailable(entry, user), "No target.")


func test_a_target_of_all_hits_every_eligible_unit() -> void:
	var user := _unit("User", Vector2(10, 10))
	var first := _unit("First", Vector2(20, 10))
	var second := _unit("Second", Vector2(20, 14))
	_give(user, "Strike", "active", _mortal("3"), {"target": {"side": "enemy", "within": 30, "count": "all"}})
	var game := _game([user] as Array[BattleUnit], [first, second] as Array[BattleUnit])
	_use(game, "Strike")
	assert_eq(_damage_of(game, first), 3)
	assert_eq(_damage_of(game, second), 3)


# The damage sequence

func test_the_active_players_units_are_damaged_first() -> void:
	var user := _unit("User", Vector2(10, 10))
	var enemy := _unit("Enemy", Vector2(20, 10))
	# The enemy is added to the pool first.
	_give(user, "Strike", "active", [{"op": "mortal", "amount": "1"}, {"op": "mortal", "to": "user", "amount": "1"}])
	var game := _game([user] as Array[BattleUnit], [enemy] as Array[BattleUnit])
	_use(game, "Strike")
	var order: Array[String] = []
	for event in game.events.log_entries:
		if event.kind == BattleEvent.UNIT_DAMAGED:
			order.append(event.data.unit.name)
	assert_eq(order, ["User", "Enemy"] as Array[String])


func test_damage_is_dealt_in_the_name_of_the_army_using_the_ability() -> void:
	var game := _caster_game("spell", 2, [{"op": "mortal", "amount": "100"}], RulesKit.seed_for([3, 4]))
	var heard: Array[BattleEvent] = []
	game.events.subscribe(BattleEvent.UNIT_DESTROYED, func(event: BattleEvent) -> void: heard.append(event))
	_use(game, "Test Spell")
	assert_eq(heard.size(), 1)
	assert_eq(heard[0].data.source_army, game.battle.player)


func test_an_ability_is_declared_and_resolved_with_events() -> void:
	var game := _caster_game("spell", 2, _mortal(), RulesKit.seed_for([3, 4]))
	_use(game, "Test Spell")
	var kinds := game.events.log_entries.map(func(e: BattleEvent) -> StringName: return e.kind)
	assert_true(BattleEvent.ABILITY_DECLARED in kinds)
	assert_true(BattleEvent.ABILITY_RESOLVED in kinds)
	assert_lt(kinds.find(BattleEvent.ABILITY_DECLARED), kinds.find(BattleEvent.ABILITY_RESOLVED))
