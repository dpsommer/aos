extends GutTest
## Effect data and whether it still matches the rules text it was written from.

const RulesKit := preload("res://test/support/rules_kit.gd")
const KEY := "faction:test/entry"


func after_each() -> void:
	RulesKit.forget_abilities()


func _ability(effect := "Does a thing.") -> Ability:
	var ability := Ability.new()
	ability.name = "Entry"
	ability.timing = "Your Hero Phase"
	ability.declare = "Pick a unit."
	ability.effect = effect
	return ability


func _add(ability: Ability, extra := {}) -> void:
	var entry := {"do": [{"op": "heal"}], "hash": EffectCatalog.hash_of(ability)}
	entry.merge(extra, true)
	EffectCatalog.add_entries({KEY: entry})


func test_an_entry_with_the_current_hash_is_found() -> void:
	var ability := _ability()
	_add(ability)
	assert_false(EffectCatalog.descriptor(KEY, ability).is_empty())


func test_the_descriptor_is_the_entry() -> void:
	var ability := _ability()
	_add(ability)
	assert_eq(EffectCatalog.descriptor(KEY, ability).do, [{"op": "heal"}])


func test_an_entry_whose_text_has_changed_is_stale_and_empty() -> void:
	var ability := _ability()
	_add(ability)
	ability.effect = "Does another thing."
	assert_true(EffectCatalog.descriptor(KEY, ability).is_empty())


func test_a_stale_entry_is_still_there_raw() -> void:
	var ability := _ability()
	_add(ability)
	ability.effect = "Does another thing."
	assert_false(EffectCatalog.raw(KEY).is_empty())


func test_an_entry_with_the_wrong_hash_is_stale() -> void:
	var ability := _ability()
	_add(ability, {"hash": "00000000"})
	assert_true(EffectCatalog.descriptor(KEY, ability).is_empty())


func test_an_entry_without_a_hash_is_stale() -> void:
	EffectCatalog.add_entries({KEY: {"do": [{"op": "heal"}]}})
	assert_true(EffectCatalog.descriptor(KEY, _ability()).is_empty())


func test_a_key_with_no_entry_is_empty() -> void:
	assert_true(EffectCatalog.descriptor("faction:test/nothing", _ability()).is_empty())
	assert_true(EffectCatalog.raw("faction:test/nothing").is_empty())


func test_the_hash_follows_the_timing_declare_effect_and_text() -> void:
	var base := _ability()
	var seen := {EffectCatalog.hash_of(base): true}
	for field in ["timing", "declare", "effect", "text"]:
		var changed := _ability()
		changed.set(field, "Something else")
		seen[EffectCatalog.hash_of(changed)] = true
	assert_eq(seen.size(), 5, "Each field's change makes a new hash")


func test_the_hash_ignores_what_the_data_does_not_hash() -> void:
	var first := _ability()
	var second := _ability()
	second.name = "Renamed"
	second.keywords = PackedStringArray(["SPELL"])
	second.command_points = 2
	assert_eq(EffectCatalog.hash_of(first), EffectCatalog.hash_of(second))


func test_the_hash_is_short_and_the_same_each_time() -> void:
	var ability := _ability()
	assert_eq(EffectCatalog.hash_of(ability).length(), 8)
	assert_eq(EffectCatalog.hash_of(ability), EffectCatalog.hash_of(ability))


func test_keys_lists_what_was_added() -> void:
	_add(_ability())
	assert_true(KEY in EffectCatalog.keys())
	assert_true("core:Run" in EffectCatalog.keys(), "And what the data files hold")
