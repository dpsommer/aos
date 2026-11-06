extends GutTest
## The limits on using abilities again: per phase, per turn, per round and per battle.

const BattleKit := preload("res://test/support/battle_kit.gd")

var _state := GameState.new()
var _ledger := UsageLedger.new(_state)
var _army := BattleArmy.new()
var _other_army := BattleArmy.new()
var _unit := BattleUnit.new()
var _other_unit := BattleUnit.new()


func before_each() -> void:
	_state = GameState.new()
	_state.round_number = 1
	_state.turn_serial = 1
	_state.window_serial = 1
	_ledger = UsageLedger.new(_state)
	_army = BattleArmy.new()
	_other_army = BattleArmy.new()
	_unit = BattleUnit.new()
	_other_unit = BattleUnit.new()


func _ability(ability_name: String, keywords := PackedStringArray(), type := "active", frequency := "") -> Ability:
	var ability := BattleKit.ability(ability_name, keywords, "", "", frequency)
	ability.type = type
	return ability


func _use(ability: Ability, user: BattleUnit = _unit, army: BattleArmy = _army) -> void:
	_ledger.mark(ability, army, user)


func _blocked(ability: Ability, user: BattleUnit = _unit, army: BattleArmy = _army) -> bool:
	return not _ledger.reason_unavailable(ability, army, user).is_empty()


func _next_phase() -> void:
	_state.window_serial += 1


func _next_turn() -> void:
	_state.turn_serial += 1
	_state.window_serial += 1


func _next_round() -> void:
	_state.round_number += 1
	_next_turn()


# Core abilities

func test_a_unit_can_use_one_core_ability_a_phase() -> void:
	var first := _ability("Run", PackedStringArray(["CORE"]))
	var second := _ability("Shoot", PackedStringArray(["CORE"]))
	_use(first)
	assert_true(_blocked(second))


func test_a_core_ability_is_available_again_next_phase() -> void:
	var second := _ability("Shoot", PackedStringArray(["CORE"]))
	_use(_ability("Run", PackedStringArray(["CORE"])))
	_next_phase()
	assert_false(_blocked(second))


func test_another_unit_can_use_a_core_ability_the_same_phase() -> void:
	var second := _ability("Shoot", PackedStringArray(["CORE"]))
	_use(_ability("Run", PackedStringArray(["CORE"])))
	assert_false(_blocked(second, _other_unit))


func test_a_core_ability_does_not_stop_one_that_is_not_core() -> void:
	_use(_ability("Run", PackedStringArray(["CORE"])))
	assert_false(_blocked(_ability("Rally")))


# The same ability

func test_a_unit_uses_the_same_ability_once_a_phase() -> void:
	var ability := _ability("Charge")
	_use(ability)
	assert_true(_blocked(ability))


func test_the_same_ability_is_available_next_phase() -> void:
	var ability := _ability("Charge")
	_use(ability)
	_next_phase()
	assert_false(_blocked(ability))


func test_another_unit_can_use_the_same_ability_the_same_phase() -> void:
	var ability := _ability("Charge")
	_use(ability)
	assert_false(_blocked(ability, _other_unit))


func test_the_player_uses_an_ability_once_a_phase_for_the_army() -> void:
	var ability := _ability("Command the Troops")
	_use(ability, null)
	assert_true(_blocked(ability, null))
	assert_false(_blocked(ability, null, _other_army))


func test_an_unlimited_ability_has_no_phase_limit() -> void:
	var ability := _ability("Fight", PackedStringArray(["UNLIMITED"]))
	_use(ability)
	assert_false(_blocked(ability))
	_use(ability, null)
	assert_false(_blocked(ability, null))


func test_unbinding_can_be_done_again_in_a_phase() -> void:
	var ability := _ability("Unbind", PackedStringArray(["UNBIND"]))
	_use(ability)
	assert_false(_blocked(ability))


# Once per

func test_once_per_turn_lasts_the_turn() -> void:
	var ability := _ability("Roar", PackedStringArray(), "active", "Once Per Turn")
	_use(ability)
	_next_phase()
	assert_true(_blocked(ability), "Another phase of the same turn")
	_next_turn()
	assert_false(_blocked(ability))


func test_once_per_turn_is_per_unit() -> void:
	var ability := _ability("Roar", PackedStringArray(), "active", "Once Per Turn")
	_use(ability)
	_next_phase()
	assert_false(_blocked(ability, _other_unit))


func test_once_per_turn_for_the_army_stops_every_unit() -> void:
	var ability := _ability("Roar", PackedStringArray(), "active", "Once Per Turn (Army)")
	_use(ability)
	_next_phase()
	assert_true(_blocked(ability, _other_unit))
	assert_false(_blocked(ability, _other_unit, _other_army), "The other army has its own")


func test_once_per_battle_round_lasts_the_round() -> void:
	var ability := _ability("Roar", PackedStringArray(), "active", "Once Per Battle Round")
	_use(ability)
	_next_turn()
	assert_true(_blocked(ability), "Another turn of the same round")
	_next_round()
	assert_false(_blocked(ability))


func test_once_per_battle_lasts_the_battle() -> void:
	var ability := _ability("Roar", PackedStringArray(), "active", "Once Per Battle")
	_use(ability)
	_next_round()
	_next_round()
	assert_true(_blocked(ability))


func test_once_per_battle_is_per_unit() -> void:
	var ability := _ability("Roar", PackedStringArray(), "active", "Once Per Battle")
	_use(ability)
	_next_round()
	assert_false(_blocked(ability, _other_unit))


func test_once_per_battle_for_the_army_is_per_army() -> void:
	var ability := _ability("Roar", PackedStringArray(), "active", "Once Per Battle (Army)")
	_use(ability)
	_next_round()
	assert_true(_blocked(ability, _other_unit))
	assert_false(_blocked(ability, _other_unit, _other_army))


func test_once_per_phase_is_stopped_for_the_phase() -> void:
	var ability := _ability("Roar", PackedStringArray(["UNLIMITED"]), "active", "Once Per Phase")
	_use(ability)
	assert_true(_blocked(ability))
	_next_phase()
	assert_false(_blocked(ability))


func test_an_ability_with_no_frequency_is_not_limited_across_turns() -> void:
	var ability := _ability("Roar")
	_use(ability)
	_next_turn()
	assert_false(_blocked(ability))


func test_a_once_per_limit_is_per_ability() -> void:
	var ability := _ability("Roar", PackedStringArray(), "active", "Once Per Battle")
	_use(ability)
	_next_round()
	assert_false(_blocked(_ability("Howl", PackedStringArray(), "active", "Once Per Battle")))


# Commands

func test_a_unit_can_be_given_one_command_a_phase() -> void:
	_use(_ability("Rally", PackedStringArray(), "command"))
	assert_true(_blocked(_ability("Inspire", PackedStringArray(), "command")))


func test_a_unit_that_was_commanded_is_free_next_phase() -> void:
	_use(_ability("Rally", PackedStringArray(), "command"))
	_next_phase()
	assert_false(_blocked(_ability("Inspire", PackedStringArray(), "command")))


func test_a_different_unit_can_be_given_another_command() -> void:
	_use(_ability("Rally", PackedStringArray(), "command"))
	assert_false(_blocked(_ability("Inspire", PackedStringArray(), "command"), _other_unit))


func test_each_command_is_used_once_a_phase_by_the_army() -> void:
	var ability := _ability("Rally", PackedStringArray(), "command")
	_use(ability)
	assert_true(_blocked(ability, _other_unit), "The army has used it")
	assert_false(_blocked(ability, _other_unit, _other_army))


# Spells and prayers

func test_a_spell_is_cast_once_a_turn_by_the_army() -> void:
	var spell := _ability("Fireball", PackedStringArray(), "spell")
	_use(spell)
	_next_phase()
	assert_true(_blocked(spell, _other_unit))


func test_a_spell_can_be_cast_again_next_turn() -> void:
	var spell := _ability("Fireball", PackedStringArray(), "spell")
	_use(spell)
	_next_turn()
	assert_false(_blocked(spell, _other_unit))


func test_the_other_army_can_cast_the_same_spell() -> void:
	var spell := _ability("Fireball", PackedStringArray(), "spell")
	_use(spell)
	_next_phase()
	assert_false(_blocked(spell, _other_unit, _other_army))


func test_a_prayer_is_chanted_once_a_turn_by_the_army() -> void:
	var prayer := _ability("Blessing", PackedStringArray(), "prayer")
	_use(prayer)
	_next_phase()
	assert_true(_blocked(prayer, _other_unit))


func test_an_unlimited_spell_can_be_cast_more_than_once_a_turn() -> void:
	var spell := _ability("Fireball", PackedStringArray(["UNLIMITED"]), "spell")
	_use(spell)
	_next_phase()
	assert_false(_blocked(spell, _other_unit))


func test_a_different_spell_can_be_cast_the_same_turn() -> void:
	_use(_ability("Fireball", PackedStringArray(), "spell"))
	_next_phase()
	assert_false(_blocked(_ability("Frostbolt", PackedStringArray(), "spell"), _other_unit))


# Casts

func test_a_unit_that_has_cast_nothing_has_no_casts() -> void:
	assert_eq(_ledger.casts_this_phase(_unit), 0)


func test_casts_are_counted_for_the_unit() -> void:
	_ledger.mark_cast(_unit)
	_ledger.mark_cast(_unit)
	assert_eq(_ledger.casts_this_phase(_unit), 2)
	assert_eq(_ledger.casts_this_phase(_other_unit), 0)


func test_casts_start_again_next_phase() -> void:
	_ledger.mark_cast(_unit)
	_next_phase()
	assert_eq(_ledger.casts_this_phase(_unit), 0)
	_ledger.mark_cast(_unit)
	assert_eq(_ledger.casts_this_phase(_unit), 1)
