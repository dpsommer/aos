extends GutTest
## The attack sequence and who can attack whom. Weapons are built so a roll's outcome is certain
## (a hit that needs 8 can't happen without more than the capped bonus), rather than by dice.

const RulesKit := preload("res://test/support/rules_kit.gd")
const MANY := "600"

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()


func _game(player_units: Array[BattleUnit], opponent_units: Array[BattleUnit], terrain: Array[BattleTerrain] = []) -> GameController:
	var game := RulesKit.game(player_units, opponent_units, terrain)
	_games.append(game)
	return game


## A lone attacker with [param weapon] in combat with a lone target, and the game.
func _duel(weapon: Weapon, target_keywords := PackedStringArray(), target_save := 0, attacker_keywords := PackedStringArray()) -> GameController:
	var attacker := RulesKit.unit("Attacker", 1, Vector2(5, 5), attacker_keywords, 1, 0, [weapon] as Array[Weapon])
	var target := RulesKit.unit("Target", 1, Vector2(6.5, 5), target_keywords, 100, target_save)
	return _game([attacker] as Array[BattleUnit], [target] as Array[BattleUnit])


func _attacker(game: GameController) -> BattleUnit:
	return game.battle.player.units[0]


func _target(game: GameController) -> BattleUnit:
	return game.battle.opponent.units[0]


func _resolve(game: GameController, weapon: Weapon) -> Dictionary:
	return game.attacks.resolve(Action.new(), _attacker(game), weapon, _target(game))


func _give_attacker(game: GameController, stat: StringName, by: int) -> void:
	RulesKit.give(game, _attacker(game), RulesKit.modifier(stat, by, game.battle.player))


func _give_target(game: GameController, stat: StringName, by: int) -> void:
	RulesKit.give(game, _target(game), RulesKit.modifier(stat, by, game.battle.opponent))


# Modifier caps

func test_a_hit_bonus_is_capped_at_one() -> void:
	var weapon := RulesKit.weapon(MANY, 8)
	var game := _duel(weapon)
	_give_attacker(game, &"hit", 3)
	assert_eq(_resolve(game, weapon).hits, 0, "6 and a capped +1 can't reach 8")


func test_a_hit_penalty_is_capped_at_one() -> void:
	var weapon := RulesKit.weapon(MANY, 1)
	var game := _duel(weapon)
	_give_attacker(game, &"hit", -4)
	var result := _resolve(game, weapon)
	assert_gt(float(result.hits), result.attacks * 0.7, "Only the unmodified 1s miss at -1")


func test_a_wound_bonus_is_capped_at_one() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 8)
	var game := _duel(weapon)
	_give_attacker(game, &"wound", 3)
	var result := _resolve(game, weapon)
	assert_gt(result.hits, 0)
	assert_eq(result.wounds, 0)


func test_a_wound_penalty_is_capped_at_one() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1)
	var game := _duel(weapon)
	_give_attacker(game, &"wound", -4)
	var result := _resolve(game, weapon)
	assert_gt(float(result.wounds), result.hits * 0.7)


func test_a_save_bonus_is_capped_at_one() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1)
	var game := _duel(weapon, PackedStringArray(), 8)
	_give_target(game, &"save", 3)
	var result := _resolve(game, weapon)
	assert_gt(result.wounds, 0)
	assert_eq(result.unsaved, result.wounds, "6 and a capped +1 can't reach 8")


func test_a_save_penalty_has_no_cap() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1)
	var game := _duel(weapon, PackedStringArray(), 2)
	_give_target(game, &"save", -10)
	var result := _resolve(game, weapon)
	assert_eq(result.unsaved, result.wounds)


func test_a_save_bonus_helps_the_save() -> void:
	# The +1 is added to the roll, so a 6+ save works on a 5: about twice as many are saved.
	var weapon := RulesKit.weapon(MANY, 2, 2)
	var plain := _duel(weapon, PackedStringArray(), 6)
	var without := _resolve(plain, weapon)
	var helped := _duel(weapon, PackedStringArray(), 6)
	RulesKit.give(helped, _target(helped), RulesKit.modifier(&"save", 1, helped.battle.opponent))
	var with_bonus := _resolve(helped, weapon)
	assert_lt(with_bonus.unsaved * 1.0 / with_bonus.wounds, without.unsaved * 1.0 / without.wounds - 0.05)


# The sequence

func test_an_unmodified_one_never_hits() -> void:
	var weapon := RulesKit.weapon(MANY, 1)
	var game := _duel(weapon)
	var result := _resolve(game, weapon)
	assert_lt(result.hits, result.attacks)


func test_a_target_without_a_save_takes_every_wound() -> void:
	var weapon := RulesKit.weapon(MANY, 2, 2)
	var game := _duel(weapon, PackedStringArray(), 0)
	var result := _resolve(game, weapon)
	assert_gt(result.wounds, 0)
	assert_eq(result.unsaved, result.wounds)


func test_damage_goes_into_the_actions_pool() -> void:
	var weapon := RulesKit.weapon(MANY, 2, 2, 0, "3")
	var game := _duel(weapon)
	var action := Action.new()
	var result := game.attacks.resolve(action, _attacker(game), weapon, _target(game))
	assert_eq(action.damage_pool[_target(game)], result.damage)
	assert_eq(result.damage, result.unsaved * 3)


func test_rend_takes_away_from_the_save() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1, 3)
	var game := _duel(weapon, PackedStringArray(), 4)
	var result := _resolve(game, weapon)
	assert_gt(result.wounds, 0)
	assert_eq(result.unsaved, result.wounds, "A 6 less 3 can't make a 4+")


func test_without_rend_some_wounds_are_saved() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1, 0)
	var game := _duel(weapon, PackedStringArray(), 4)
	var result := _resolve(game, weapon)
	assert_lt(result.unsaved, result.wounds)


func test_a_rend_modifier_adds_rend() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1, 0)
	var game := _duel(weapon, PackedStringArray(), 4)
	_give_attacker(game, &"rend", 3)
	var result := _resolve(game, weapon)
	assert_eq(result.unsaved, result.wounds)


# Anti-X

func test_anti_gives_rend_against_the_keyword() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1, 0, "1", PackedStringArray(["Anti-INFANTRY (+1 Rend)"]))
	var game := _duel(weapon, PackedStringArray(["INFANTRY"]), 6)
	var result := _resolve(game, weapon)
	assert_eq(result.unsaved, result.wounds, "A 6 less 1 can't make a 6+")


func test_anti_does_nothing_against_another_keyword() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1, 0, "1", PackedStringArray(["Anti-INFANTRY (+1 Rend)"]))
	var game := _duel(weapon, PackedStringArray(["MONSTER"]), 6)
	var result := _resolve(game, weapon)
	assert_lt(result.unsaved, result.wounds)


func test_anti_abilities_are_cumulative() -> void:
	var both := RulesKit.weapon(MANY, 1, 1, 0, "1", PackedStringArray(["Anti-INFANTRY (+1 Rend)", "Anti-HERO (+1 Rend)"]))
	var one := RulesKit.weapon(MANY, 1, 1, 0, "1", PackedStringArray(["Anti-INFANTRY (+1 Rend)"]))
	var keywords := PackedStringArray(["INFANTRY", "HERO"])
	var with_both := _duel(both, keywords, 5)
	var result_both := _resolve(with_both, both)
	var with_one := _duel(one, keywords, 5)
	var result_one := _resolve(with_one, one)
	assert_eq(result_both.unsaved, result_both.wounds, "Rend 2 beats a 5+")
	assert_lt(result_one.unsaved, result_one.wounds, "Rend 1 doesn't")


func test_anti_charge_counts_against_a_target_that_charged() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1, 0, "1", PackedStringArray(["Anti-charge (+1 Rend)"]))
	var game := _duel(weapon, PackedStringArray(), 6)
	game.controller_of(_target(game)).charged = true
	var result := _resolve(game, weapon)
	assert_eq(result.unsaved, result.wounds)


func test_anti_charge_does_nothing_if_the_target_did_not_charge() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1, 0, "1", PackedStringArray(["Anti-charge (+1 Rend)"]))
	var game := _duel(weapon, PackedStringArray(), 6)
	var result := _resolve(game, weapon)
	assert_lt(result.unsaved, result.wounds)


func test_anti_charge_stacks_with_a_keyword_anti() -> void:
	var weapon := RulesKit.weapon(MANY, 1, 1, 0, "1", PackedStringArray(["Anti-charge (+1 Rend)", "Anti-INFANTRY (+1 Rend)"]))
	var game := _duel(weapon, PackedStringArray(["INFANTRY"]), 5)
	game.controller_of(_target(game)).charged = true
	var result := _resolve(game, weapon)
	assert_eq(result.unsaved, result.wounds, "Rend 2 beats a 5+")


# Charge (+1 Damage)

func test_charge_damage_applies_after_charging() -> void:
	var weapon := RulesKit.weapon(MANY, 2, 2, 0, "1", PackedStringArray(["Charge (+1 Damage)"]))
	var game := _duel(weapon)
	game.controller_of(_attacker(game)).charged = true
	var result := _resolve(game, weapon)
	assert_eq(result.damage, result.unsaved * 2)


func test_charge_damage_does_not_apply_without_charging() -> void:
	var weapon := RulesKit.weapon(MANY, 2, 2, 0, "1", PackedStringArray(["Charge (+1 Damage)"]))
	var game := _duel(weapon)
	var result := _resolve(game, weapon)
	assert_eq(result.damage, result.unsaved)


# Critical hits. Hitting on 7 with a +1 means only a 6, so every hit is a critical hit.

func _only_crits(abilities: PackedStringArray, wound := 2) -> Weapon:
	return RulesKit.weapon(MANY, 7, wound, 0, "1", abilities)


func _duel_hitting_on_sixes(weapon: Weapon) -> GameController:
	var game := _duel(weapon)
	_give_attacker(game, &"hit", 1)
	return game


func test_crit_mortal_skips_the_wound_roll_and_the_save() -> void:
	var weapon := _only_crits(PackedStringArray(["Crit (Mortal)"]), 8)
	var game := _duel_hitting_on_sixes(weapon)
	var result := _resolve(game, weapon)
	assert_gt(result.crits, 0)
	assert_eq(result.wounds, 0, "No wound roll to make")
	assert_eq(result.damage, result.crits, "Each crit still does its damage")


func test_crit_mortal_does_not_apply_to_ordinary_hits() -> void:
	var weapon := RulesKit.weapon(MANY, 2, 8, 0, "1", PackedStringArray(["Crit (Mortal)"]))
	var game := _duel(weapon)
	var result := _resolve(game, weapon)
	assert_gt(result.hits, result.crits)
	assert_eq(result.damage, result.crits, "Only the crits do damage; nothing wounds on 8")


func test_crit_two_hits_counts_each_crit_twice() -> void:
	var weapon := _only_crits(PackedStringArray(["Crit (2 Hits)"]))
	var game := _duel_hitting_on_sixes(weapon)
	var result := _resolve(game, weapon)
	assert_gt(result.crits, 0)
	assert_eq(result.hits, result.crits * 2)


func test_a_crit_is_one_hit_without_the_ability() -> void:
	var weapon := _only_crits(PackedStringArray())
	var game := _duel_hitting_on_sixes(weapon)
	var result := _resolve(game, weapon)
	assert_eq(result.hits, result.crits)


func test_crit_auto_wound_skips_the_wound_roll() -> void:
	var weapon := _only_crits(PackedStringArray(["Crit (Auto-wound)"]), 8)
	var game := _duel_hitting_on_sixes(weapon)
	var result := _resolve(game, weapon)
	assert_gt(result.crits, 0)
	assert_eq(result.wounds, result.crits)


func test_without_auto_wound_a_crit_still_needs_to_wound() -> void:
	var weapon := _only_crits(PackedStringArray(), 8)
	var game := _duel_hitting_on_sixes(weapon)
	assert_eq(_resolve(game, weapon).wounds, 0)


func test_mortal_is_used_before_auto_wound_and_two_hits() -> void:
	var weapon := _only_crits(PackedStringArray(["Crit (2 Hits)", "Crit (Auto-wound)", "Crit (Mortal)"]), 8)
	var game := _duel_hitting_on_sixes(weapon)
	var result := _resolve(game, weapon)
	assert_eq(result.hits, result.crits, "Not doubled")
	assert_eq(result.wounds, 0)


func test_auto_wound_is_used_before_two_hits() -> void:
	var weapon := _only_crits(PackedStringArray(["Crit (2 Hits)", "Crit (Auto-wound)"]), 8)
	var game := _duel_hitting_on_sixes(weapon)
	var result := _resolve(game, weapon)
	assert_eq(result.hits, result.crits)
	assert_eq(result.wounds, result.crits)


func test_a_granted_crit_ability_works() -> void:
	var weapon := _only_crits(PackedStringArray(), 8)
	var game := _duel_hitting_on_sixes(weapon)
	RulesKit.give(game, _attacker(game), RulesKit.modifier(&"Crit (Mortal)", 0, game.battle.player, Modifier.Op.GRANT))
	var result := _resolve(game, weapon)
	assert_eq(result.damage, result.crits)


# Companion

func test_companion_ignores_a_friendly_bonus() -> void:
	var weapon := RulesKit.weapon(MANY, 7, 2, 0, "1", PackedStringArray(["Companion"]))
	var game := _duel(weapon)
	_give_attacker(game, &"hit", 1)
	assert_eq(_resolve(game, weapon).hits, 0)


func test_a_friendly_bonus_applies_without_companion() -> void:
	var weapon := RulesKit.weapon(MANY, 7, 2)
	var game := _duel(weapon)
	_give_attacker(game, &"hit", 1)
	assert_gt(_resolve(game, weapon).hits, 0)


func test_companion_takes_a_friendly_bonus_that_says_it_affects_companions() -> void:
	var weapon := RulesKit.weapon(MANY, 7, 2, 0, "1", PackedStringArray(["Companion"]))
	var game := _duel(weapon)
	var bonus := RulesKit.modifier(&"hit", 1, game.battle.player)
	bonus.affects_companion = true
	RulesKit.give(game, _attacker(game), bonus)
	assert_gt(_resolve(game, weapon).hits, 0)


func test_companion_still_takes_a_friendly_penalty() -> void:
	var weapon := RulesKit.weapon(MANY, 6, 2, 0, "1", PackedStringArray(["Companion"]))
	var game := _duel(weapon)
	_give_attacker(game, &"hit", -1)
	assert_eq(_resolve(game, weapon).hits, 0, "A 6 less 1 can't make a 6+")


func test_companion_takes_a_bonus_from_the_enemy() -> void:
	var weapon := RulesKit.weapon(MANY, 7, 2, 0, "1", PackedStringArray(["Companion"]))
	var game := _duel(weapon)
	RulesKit.give(game, _attacker(game), RulesKit.modifier(&"hit", 1, game.battle.opponent))
	assert_gt(_resolve(game, weapon).hits, 0)


# Who attacks

func test_only_models_in_range_attack() -> void:
	var weapon := RulesKit.weapon("1", 2)
	var attacker := RulesKit.unit("Attacker", 5, Vector2(0, 5), PackedStringArray(), 1, 0, [weapon] as Array[Weapon])
	var target := RulesKit.unit("Target", 1, Vector2(8.5, 5))
	var game := _game([attacker] as Array[BattleUnit], [target] as Array[BattleUnit])
	var result := game.attacks.resolve(Action.new(), attacker, weapon, target)
	assert_eq(result.attacks, 2, "Two of the five are within 3\"")


func test_attacks_are_per_model() -> void:
	var weapon := RulesKit.weapon("2", 2)
	var attacker := RulesKit.unit("Attacker", 2, Vector2(5, 5), PackedStringArray(), 1, 0, [weapon] as Array[Weapon])
	var target := RulesKit.unit("Target", 1, Vector2(6.5, 5))
	var game := _game([attacker] as Array[BattleUnit], [target] as Array[BattleUnit])
	assert_eq(game.attacks.resolve(Action.new(), attacker, weapon, target).attacks, 4)


func test_an_attacks_modifier_changes_the_attacks() -> void:
	var weapon := RulesKit.weapon("2", 2)
	var game := _duel(weapon)
	_give_attacker(game, &"attacks", 1)
	assert_eq(_resolve(game, weapon).attacks, 3)


func test_a_ranged_weapon_reaches_its_range() -> void:
	var weapon := RulesKit.weapon("1", 2, 2, 0, "1", PackedStringArray(), 12)
	var near := RulesKit.unit("Near", 1, Vector2(10, 5))
	var far := RulesKit.unit("Far", 1, Vector2(25, 5))
	var attacker := RulesKit.unit("Attacker", 1, Vector2(0, 5), PackedStringArray(), 1, 0, [weapon] as Array[Weapon])
	var game := _game([attacker] as Array[BattleUnit], [near, far] as Array[BattleUnit])
	assert_eq(game.attacks.targets_for(attacker, weapon), [near] as Array[BattleUnit])


# Shooting restrictions

func _shooter_in_combat(extra: PackedStringArray) -> GameController:
	var gun := RulesKit.weapon("1", 2, 2, 0, "1", extra, 24)
	var shooter := RulesKit.unit("Shooter", 1, Vector2(5, 5), PackedStringArray(), 1, 0, [gun] as Array[Weapon])
	var fighting := RulesKit.unit("Fighting", 1, Vector2(6.5, 5))
	var distant := RulesKit.unit("Distant", 1, Vector2(15, 5))
	return _game([shooter] as Array[BattleUnit], [fighting, distant] as Array[BattleUnit])


func test_a_unit_in_combat_cannot_shoot() -> void:
	var game := _shooter_in_combat(PackedStringArray())
	var shooter := _attacker(game)
	assert_true(game.attacks.targets_for(shooter, shooter.warscroll.ranged_weapons[0]).is_empty())
	assert_false(game.attacks.has_targets(shooter, false))


func test_shoot_in_combat_lets_it_shoot_what_it_fights() -> void:
	var game := _shooter_in_combat(PackedStringArray(["Shoot in Combat"]))
	var shooter := _attacker(game)
	var targets := game.attacks.targets_for(shooter, shooter.warscroll.ranged_weapons[0])
	assert_eq(targets, [game.battle.opponent.units[0]] as Array[BattleUnit], "Only the enemy it is in combat with")


func test_a_unit_not_in_combat_can_shoot() -> void:
	var gun := RulesKit.weapon("1", 2, 2, 0, "1", PackedStringArray(), 24)
	var shooter := RulesKit.unit("Shooter", 1, Vector2(5, 5), PackedStringArray(), 1, 0, [gun] as Array[Weapon])
	var game := _game([shooter] as Array[BattleUnit], [RulesKit.unit("Far", 1, Vector2(15, 5))] as Array[BattleUnit])
	assert_true(game.attacks.has_targets(shooter, false))


func _across_terrain(kind: BattleTerrain.Kind, target_keywords := PackedStringArray()) -> GameController:
	var gun := RulesKit.weapon("1", 2, 2, 0, "1", PackedStringArray(), 30)
	var shooter := RulesKit.unit("Shooter", 1, Vector2(2, 5), PackedStringArray(), 1, 0, [gun] as Array[Weapon])
	var target := RulesKit.unit("Target", 1, Vector2(18, 5), target_keywords)
	var wall := BattleKit.terrain(kind, 4.0, Vector2(10, 5))
	return _game([shooter] as Array[BattleUnit], [target] as Array[BattleUnit], [wall] as Array[BattleTerrain])


const BattleKit := preload("res://test/support/battle_kit.gd")


func test_obscuring_terrain_blocks_shooting_past_it() -> void:
	var game := _across_terrain(BattleTerrain.Kind.OBSCURING)
	var shooter := _attacker(game)
	assert_true(game.attacks.targets_for(shooter, shooter.warscroll.ranged_weapons[0]).is_empty())


func test_other_terrain_does_not_block_shooting() -> void:
	var game := _across_terrain(BattleTerrain.Kind.AREA_OR_OBSTACLE)
	var shooter := _attacker(game)
	assert_false(game.attacks.targets_for(shooter, shooter.warscroll.ranged_weapons[0]).is_empty())


func test_obscuring_terrain_does_not_hide_a_flyer() -> void:
	var game := _across_terrain(BattleTerrain.Kind.OBSCURING, PackedStringArray(["FLY"]))
	var shooter := _attacker(game)
	assert_false(game.attacks.targets_for(shooter, shooter.warscroll.ranged_weapons[0]).is_empty())


# Guarded Hero

func _guarded_hero(hero_at: Vector2, friend_keywords := PackedStringArray(), hero_keywords := PackedStringArray(["HERO", "INFANTRY"])) -> GameController:
	var gun := RulesKit.weapon(MANY, 7, 2, 0, "1", PackedStringArray(), 30)
	var shooter := RulesKit.unit("Shooter", 1, Vector2(0, 5), PackedStringArray(), 1, 0, [gun] as Array[Weapon])
	var hero := RulesKit.unit("Hero", 1, hero_at, hero_keywords)
	var friend := RulesKit.unit("Friend", 1, hero_at + Vector2(2, 0), friend_keywords)
	return _game([shooter] as Array[BattleUnit], [hero, friend] as Array[BattleUnit])


func test_a_hero_beside_a_unit_is_guarded() -> void:
	var game := _guarded_hero(Vector2(8, 5))
	assert_true(game.attacks.is_guarded(game.battle.opponent.units[0]))


func test_a_hero_alone_is_not_guarded() -> void:
	var game := _guarded_hero(Vector2(8, 5), PackedStringArray(["HERO"]))
	assert_false(game.attacks.is_guarded(game.battle.opponent.units[0]), "The only friend nearby is a hero")


func test_a_monster_hero_is_not_guarded() -> void:
	var game := _guarded_hero(Vector2(8, 5), PackedStringArray(), PackedStringArray(["HERO", "MONSTER"]))
	assert_false(game.attacks.is_guarded(game.battle.opponent.units[0]))


func test_a_unit_that_is_not_a_hero_is_not_guarded() -> void:
	var game := _guarded_hero(Vector2(8, 5), PackedStringArray(), PackedStringArray(["INFANTRY"]))
	assert_false(game.attacks.is_guarded(game.battle.opponent.units[0]))


func test_a_guarded_hero_takes_a_penalty_to_be_hit_by_shooting() -> void:
	var game := _guarded_hero(Vector2(8, 5))
	var shooter := _attacker(game)
	var weapon := shooter.warscroll.ranged_weapons[0]
	_give_attacker(game, &"hit", 1)
	var hero := game.battle.opponent.units[0]
	assert_eq(game.attacks.resolve(Action.new(), shooter, weapon, hero).hits, 0, "A 6 with +1 less 1 can't make a 7+")
	var friend := game.battle.opponent.units[1]
	assert_gt(game.attacks.resolve(Action.new(), shooter, weapon, friend).hits, 0)


func test_a_guarded_infantry_hero_cannot_be_shot_from_far_away() -> void:
	var game := _guarded_hero(Vector2(20, 5))
	var shooter := _attacker(game)
	var targets := game.attacks.targets_for(shooter, shooter.warscroll.ranged_weapons[0])
	assert_false(game.battle.opponent.units[0] in targets)
	assert_true(game.battle.opponent.units[1] in targets)


func test_a_guarded_infantry_hero_can_be_shot_from_within_twelve_inches() -> void:
	var game := _guarded_hero(Vector2(8, 5))
	var shooter := _attacker(game)
	assert_true(game.battle.opponent.units[0] in game.attacks.targets_for(shooter, shooter.warscroll.ranged_weapons[0]))


func test_a_guarded_hero_that_is_not_infantry_can_be_shot_from_far_away() -> void:
	var game := _guarded_hero(Vector2(20, 5), PackedStringArray(), PackedStringArray(["HERO", "CAVALRY"]))
	var shooter := _attacker(game)
	assert_true(game.battle.opponent.units[0] in game.attacks.targets_for(shooter, shooter.warscroll.ranged_weapons[0]))
