extends GutTest
## What a characteristic or roll comes to, and which modifiers reach a unit.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()


func _game(player_units: Array[BattleUnit], opponent_units: Array[BattleUnit] = []) -> GameController:
	if opponent_units.is_empty():
		opponent_units = [RulesKit.unit("Enemy", 1, Vector2(25, 15))] as Array[BattleUnit]
	var game := RulesKit.game(player_units, opponent_units)
	_games.append(game)
	return game


func _solo(keywords := PackedStringArray()) -> GameController:
	return _game([RulesKit.unit("Solo", 1, Vector2(5, 5), keywords, 5, 4)] as Array[BattleUnit])


func _mine(game: GameController) -> BattleArmy:
	return game.battle.player


func _context(game: GameController, unit: BattleUnit) -> RuleContext:
	return RuleContext.of_unit(game, unit)


func _add(game: GameController, unit: BattleUnit, stat: StringName, by: int, op := Modifier.Op.ADD) -> Modifier:
	var modifier := RulesKit.modifier(stat, by, _mine(game), op)
	RulesKit.give(game, unit, modifier)
	return modifier


# Order and minimums

func test_set_then_halve_then_add() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	# Given in the wrong order: the order the rules say is what counts.
	_add(game, unit, &"move", 1)
	_add(game, unit, &"move", 0, Modifier.Op.HALVE)
	_add(game, unit, &"move", 6, Modifier.Op.SET)
	assert_eq(game.stats.modified(10, &"move", _context(game, unit)), 4, "Set 6, halved to 3, plus 1")


func test_halving_rounds_down() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"move", 0, Modifier.Op.HALVE)
	assert_eq(game.stats.modified(5, &"move", _context(game, unit)), 2)


func test_a_result_below_one_is_one() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"damage", -5)
	assert_eq(game.stats.modified(3, &"damage", _context(game, unit)), 1)


func test_halving_one_leaves_one() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"move", 0, Modifier.Op.HALVE)
	assert_eq(game.stats.modified(1, &"move", _context(game, unit)), 1)


func test_rend_can_go_down_to_nothing() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"rend", -5)
	assert_eq(game.stats.modified(1, &"rend", _context(game, unit)), 0)


func test_a_characteristic_that_starts_at_nothing_stays_at_nothing() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"ward", -2)
	assert_eq(game.stats.modified(0, &"ward", _context(game, unit)), 0)


func test_nothing_modified_is_the_base() -> void:
	var game := _solo()
	assert_eq(game.stats.modified(4, &"move", _context(game, game.battle.player.units[0])), 4)


func test_only_the_best_ward_counts() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"ward", 6, Modifier.Op.SET)
	assert_eq(game.stats.modified(5, &"ward", _context(game, unit)), 5, "A 6+ doesn't replace a 5+")
	_add(game, unit, &"ward", 4, Modifier.Op.SET)
	assert_eq(game.stats.modified(5, &"ward", _context(game, unit)), 4)


func test_set_replaces_other_stats() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"move", 2, Modifier.Op.SET)
	assert_eq(game.stats.modified(9, &"move", _context(game, unit)), 2)


func test_a_unit_stat_comes_from_the_warscroll_with_modifiers() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	var base := game.stats.value(unit, &"health")
	_add(game, unit, &"health", 2)
	assert_eq(game.stats.value(unit, &"health"), base + 2)


func test_a_roll_modifier_adds_up_without_a_cap() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"hit", 2)
	_add(game, unit, &"hit", 1)
	_add(game, unit, &"hit", -1)
	assert_eq(game.stats.roll_modifier(&"hit", _context(game, unit)), 2)


func test_a_modifier_of_another_stat_is_ignored() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"wound", 1)
	assert_eq(game.stats.roll_modifier(&"hit", _context(game, unit)), 0)


# Whose it is

func test_a_modifier_is_for_its_holder_only() -> void:
	var game := _game([RulesKit.unit("A", 1, Vector2(5, 5)), RulesKit.unit("B", 1, Vector2(8, 5))] as Array[BattleUnit])
	var a := game.battle.player.units[0]
	var b := game.battle.player.units[1]
	_add(game, a, &"hit", 1)
	assert_eq(game.stats.roll_modifier(&"hit", _context(game, a)), 1)
	assert_eq(game.stats.roll_modifier(&"hit", _context(game, b)), 0)


func test_a_modifier_against_its_holder_applies_to_attacks_on_it() -> void:
	var game := _game([RulesKit.unit("A", 1, Vector2(5, 5)), RulesKit.unit("B", 1, Vector2(8, 5))] as Array[BattleUnit])
	var a := game.battle.player.units[0]
	var b := game.battle.player.units[1]
	var modifier := _add(game, a, &"hit", -1)
	modifier.against = true
	var weapon := RulesKit.weapon()
	assert_eq(game.stats.roll_modifier(&"hit", RuleContext.of_attack(game, b, a, weapon)), -1, "An attack on A")
	assert_eq(game.stats.roll_modifier(&"hit", RuleContext.of_attack(game, a, b, weapon)), 0, "A's own attack")


func test_a_condition_has_to_hold() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	var modifier := _add(game, unit, &"hit", 1)
	modifier.conditions = ["charged"]
	assert_eq(game.stats.roll_modifier(&"hit", _context(game, unit)), 0)
	game.controller_of(unit).charged = true
	assert_eq(game.stats.roll_modifier(&"hit", _context(game, unit)), 1)


func test_an_action_modifier_is_only_for_its_action() -> void:
	var game := _game([RulesKit.unit("A", 1, Vector2(5, 5), PackedStringArray(), 1, 0, [RulesKit.weapon()] as Array[Weapon]), RulesKit.unit("B", 1, Vector2(6.5, 5))] as Array[BattleUnit])
	var a := game.battle.player.units[0]
	var b := game.battle.player.units[1]
	var modifier := _add(game, a, &"hit", 1)
	modifier.action = Action.new()
	var weapon := a.warscroll.melee_weapons[0]
	assert_eq(game.stats.roll_modifier(&"hit", RuleContext.of_attack(game, a, b, weapon, modifier.action)), 1)
	assert_eq(game.stats.roll_modifier(&"hit", RuleContext.of_attack(game, a, b, weapon, Action.new())), 0)
	assert_eq(game.stats.roll_modifier(&"hit", RuleContext.of_attack(game, a, b, weapon)), 0)


# Weapons

func _weapon_game() -> GameController:
	var melee := RulesKit.weapon()
	melee.name = "Axe"
	var ranged := RulesKit.weapon("1", 2, 2, 0, "1", PackedStringArray(), 12)
	ranged.name = "Bow"
	return _game([RulesKit.unit("A", 1, Vector2(5, 5), PackedStringArray(), 1, 0, [melee, ranged] as Array[Weapon]), RulesKit.unit("B", 1, Vector2(30, 5))] as Array[BattleUnit])


func _hit_modifier(game: GameController, weapon: Weapon) -> int:
	var a := game.battle.player.units[0]
	return game.stats.roll_modifier(&"hit", RuleContext.of_attack(game, a, game.battle.player.units[1], weapon))


func test_a_melee_modifier_is_not_for_ranged_weapons() -> void:
	var game := _weapon_game()
	var a := game.battle.player.units[0]
	_add(game, a, &"hit", 1).weapons = "melee"
	assert_eq(_hit_modifier(game, a.warscroll.melee_weapons[0]), 1)
	assert_eq(_hit_modifier(game, a.warscroll.ranged_weapons[0]), 0)


func test_a_ranged_modifier_is_not_for_melee_weapons() -> void:
	var game := _weapon_game()
	var a := game.battle.player.units[0]
	_add(game, a, &"hit", 1).weapons = "ranged"
	assert_eq(_hit_modifier(game, a.warscroll.melee_weapons[0]), 0)
	assert_eq(_hit_modifier(game, a.warscroll.ranged_weapons[0]), 1)


func test_a_modifier_for_a_named_weapon_is_only_for_it() -> void:
	var game := _weapon_game()
	var a := game.battle.player.units[0]
	_add(game, a, &"hit", 1).weapon_name = "Bow"
	assert_eq(_hit_modifier(game, a.warscroll.melee_weapons[0]), 0)
	assert_eq(_hit_modifier(game, a.warscroll.ranged_weapons[0]), 1)


func test_a_weapon_modifier_does_not_apply_to_a_question_about_no_weapon() -> void:
	var game := _weapon_game()
	var a := game.battle.player.units[0]
	_add(game, a, &"hit", 1).weapons = "melee"
	assert_eq(game.stats.roll_modifier(&"hit", _context(game, a)), 0)


# Auras

## A source with an aura at the west, an ally [param ally_gap] centres east of it, and an enemy
## beside the ally.
func _aura_game(aura: Dictionary, ally_distance: float, ally_keywords := PackedStringArray()) -> GameController:
	var source := RulesKit.unit("Source", 1, Vector2(5, 5))
	var ally := RulesKit.unit("Ally", 1, Vector2(5 + ally_distance, 5), ally_keywords)
	var enemy := RulesKit.unit("Enemy", 1, Vector2(5 + ally_distance, 15))
	var game := _game([source, ally] as Array[BattleUnit], [enemy] as Array[BattleUnit])
	_add(game, source, &"hit", 1).aura = aura
	return game


func _aura_on(game: GameController, unit: BattleUnit) -> int:
	return game.stats.roll_modifier(&"hit", _context(game, unit))


func test_an_aura_reaches_friendly_units_within_its_range() -> void:
	var game := _aura_game({"within": 6}, 4.0)
	assert_eq(_aura_on(game, game.battle.player.units[1]), 1)


func test_an_aura_does_not_reach_a_unit_out_of_range() -> void:
	var game := _aura_game({"within": 6}, 15.0)
	assert_eq(_aura_on(game, game.battle.player.units[1]), 0)


func test_a_wholly_within_aura_needs_the_whole_unit_in_range() -> void:
	# Close enough to be within 6" but with the far side of its base outside it.
	var game := _aura_game({"within": 6, "wholly": true}, 6.8)
	var ally := game.battle.player.units[1]
	assert_eq(_aura_on(game, ally), 0)
	var within := _aura_game({"within": 6}, 6.8)
	assert_eq(_aura_on(within, within.battle.player.units[1]), 1)


func test_a_wholly_within_aura_reaches_a_unit_well_inside() -> void:
	var game := _aura_game({"within": 6, "wholly": true}, 3.0)
	assert_eq(_aura_on(game, game.battle.player.units[1]), 1)


func test_a_friendly_aura_does_not_reach_the_enemy() -> void:
	var game := _aura_game({"within": 30, "side": "friendly"}, 4.0)
	assert_eq(_aura_on(game, game.battle.opponent.units[0]), 0)


func test_an_enemy_aura_reaches_the_enemy_not_friends() -> void:
	var game := _aura_game({"within": 30, "side": "enemy"}, 4.0)
	assert_eq(_aura_on(game, game.battle.opponent.units[0]), 1)
	assert_eq(_aura_on(game, game.battle.player.units[1]), 0)


func test_an_aura_for_a_keyword_only_reaches_units_with_it() -> void:
	var with := _aura_game({"within": 6, "keywords": ["INFANTRY"]}, 4.0, PackedStringArray(["INFANTRY"]))
	assert_eq(_aura_on(with, with.battle.player.units[1]), 1)
	var without := _aura_game({"within": 6, "keywords": ["INFANTRY"]}, 4.0, PackedStringArray(["CAVALRY"]))
	assert_eq(_aura_on(without, without.battle.player.units[1]), 0)


func test_an_aura_for_others_leaves_out_its_source() -> void:
	var game := _aura_game({"within": 6, "others": true}, 4.0)
	assert_eq(_aura_on(game, game.battle.player.units[0]), 0)
	assert_eq(_aura_on(game, game.battle.player.units[1]), 1)


func test_an_aura_reaches_its_source_unless_it_is_for_others() -> void:
	var game := _aura_game({"within": 6}, 4.0)
	assert_eq(_aura_on(game, game.battle.player.units[0]), 1)


func test_an_aura_without_a_range_reaches_every_friendly_unit() -> void:
	var game := _aura_game({"side": "friendly"}, 25.0)
	assert_eq(_aura_on(game, game.battle.player.units[1]), 1)


func test_an_aura_from_a_unit_off_the_battlefield_reaches_nobody() -> void:
	var game := _aura_game({"within": 30}, 4.0)
	game.battle.player.units[0].positions = PackedVector2Array()
	assert_eq(_aura_on(game, game.battle.player.units[1]), 0)


# Passives

func _two_sources(passive: bool) -> GameController:
	var first := RulesKit.unit("First", 1, Vector2(5, 5))
	var second := RulesKit.unit("Second", 1, Vector2(8, 5))
	var ally := RulesKit.unit("Ally", 1, Vector2(11, 5))
	var game := _game([first, second, ally] as Array[BattleUnit])
	for unit in [first, second]:
		var modifier := _add(game, unit, &"hit", 1)
		modifier.aura = {"within": 12}
		modifier.passive = passive
		modifier.source_name = "Banner"
	return game


func test_the_same_passive_from_two_sources_counts_once() -> void:
	var game := _two_sources(true)
	assert_eq(_aura_on(game, game.battle.player.units[2]), 1)


func test_the_same_modifier_that_is_not_passive_stacks() -> void:
	var game := _two_sources(false)
	assert_eq(_aura_on(game, game.battle.player.units[2]), 2)


func test_different_passives_both_count() -> void:
	var game := _two_sources(true)
	var extra := _add(game, game.battle.player.units[0], &"hit", 1)
	extra.aura = {"within": 12}
	extra.passive = true
	extra.source_name = "Other banner"
	assert_eq(_aura_on(game, game.battle.player.units[2]), 2)


# Keywords and permissions

func test_a_warscroll_keyword_is_had() -> void:
	var game := _solo(PackedStringArray(["HERO"]))
	assert_true(game.stats.has_keyword(game.battle.player.units[0], "HERO"))
	assert_false(game.stats.has_keyword(game.battle.player.units[0], "MONSTER"))


func test_a_power_level_keyword_counts_as_wizard() -> void:
	var game := _solo(PackedStringArray(["WIZARD (2)"]))
	assert_true(game.stats.has_keyword(game.battle.player.units[0], "WIZARD"))
	assert_false(game.stats.has_keyword(game.battle.player.units[0], "PRIEST"))


func test_a_granted_keyword_is_had() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	_add(game, unit, &"FLY", 0, Modifier.Op.GRANT)
	assert_true(game.stats.has_keyword(unit, "FLY"))


func test_forbidding_and_permitting_are_reported() -> void:
	var game := _solo()
	var unit := game.battle.player.units[0]
	assert_false(game.stats.is_forbidden(unit, &"contest"))
	assert_false(game.stats.is_permitted(unit, &"charge_after_run"))
	_add(game, unit, &"contest", 0, Modifier.Op.FORBID)
	_add(game, unit, &"charge_after_run", 0, Modifier.Op.PERMIT)
	assert_true(game.stats.is_forbidden(unit, &"contest"))
	assert_true(game.stats.is_permitted(unit, &"charge_after_run"))
	assert_false(game.stats.is_permitted(unit, &"contest"), "Forbid is not permit")
