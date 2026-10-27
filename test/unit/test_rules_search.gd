extends GutTest
## Unit tests for the Forge search matching (scripts/army/rules_search.gd).

const Kit := preload("res://test/support/army_kit.gd")


func test_words_are_lowercased_and_split_on_spaces() -> void:
	assert_eq(RulesSearch.words("Fire  BALL"), PackedStringArray(["fire", "ball"]))


func test_words_of_a_blank_query_are_empty() -> void:
	assert_eq(RulesSearch.words("   ").size(), 0)


func test_empty_query_matches_anything() -> void:
	assert_true(RulesSearch.matches("anything", RulesSearch.words("")))


func test_matches_ignoring_case() -> void:
	assert_true(RulesSearch.matches("Lord-Celestant", RulesSearch.words("CELESTANT")))


func test_matches_a_partial_word() -> void:
	assert_true(RulesSearch.matches("Lord-Celestant", RulesSearch.words("celes")))


func test_every_word_must_be_present() -> void:
	assert_false(RulesSearch.matches("Lord-Celestant", RulesSearch.words("lord knight")))


func test_words_can_match_in_any_order() -> void:
	assert_true(RulesSearch.matches("Lord-Celestant on Dracoth", RulesSearch.words("dracoth lord")))


func test_warscroll_text_includes_name_keywords_weapons_and_abilities() -> void:
	var scroll := Kit.warscroll("lord", PackedStringArray(["HERO", "ORDER"]), 100, "Lord Name")
	scroll.source = "Scourge Pack"
	var weapon := Weapon.new()
	weapon.name = "Runeblade"
	scroll.melee_weapons.append(weapon)
	var ranged := Weapon.new()
	ranged.name = "Stormbow"
	scroll.ranged_weapons.append(ranged)
	scroll.abilities.append(Kit.ability("Rally Cry"))
	var text := RulesSearch.warscroll_text(scroll).to_lower()
	for expected in ["lord name", "scourge pack", "order", "runeblade", "stormbow", "rally cry"]:
		assert_string_contains(text, expected)


func test_ability_text_includes_its_rules_text_fields() -> void:
	var entry := Kit.ability("Smite")
	entry.timing = "Your Hero Phase"
	entry.declare = "Pick an enemy"
	entry.effect = "Inflict mortal damage"
	entry.text = "Extra note"
	entry.keywords = PackedStringArray(["SPELL"])
	var text := RulesSearch.ability_text(entry)
	for expected in ["Smite", "Your Hero Phase", "Pick an enemy", "Inflict mortal damage", "Extra note", "SPELL"]:
		assert_string_contains(text, expected)


func test_tactic_text_includes_card_text_and_each_tactic() -> void:
	var card := Kit.card("Slaughter")
	card.text = "Pick a hideout"
	var tactic := BattleTactic.new()
	tactic.name = "Bold Strike"
	tactic.kind = "strike"
	tactic.condition = "Control the objective"
	card.tactics.append(tactic)
	var text := RulesSearch.tactic_text(card)
	for expected in ["Slaughter", "Pick a hideout", "Bold Strike", "strike", "Control the objective"]:
		assert_string_contains(text, expected)


func test_regiment_text_includes_name_text_and_unit_names() -> void:
	var units: Array[RegimentUnit] = [Kit.renown_unit("Sky Captain", "captain")]
	var regiment := Kit.regiment_of_renown("Privateers", 100, units)
	regiment.text = "A rowdy crew"
	var text := RulesSearch.regiment_text(regiment)
	for expected in ["Privateers", "A rowdy crew", "Sky Captain"]:
		assert_string_contains(text, expected)


func test_regiment_text_includes_the_abilities() -> void:
	var regiment := Kit.regiment_of_renown("Privateers", 100, [] as Array[RegimentUnit])
	regiment.abilities.append(Kit.ability("Plunder"))
	assert_string_contains(RulesSearch.regiment_text(regiment), "Plunder")


func test_regiment_text_includes_the_home_faction_name_of_units() -> void:
	var units: Array[RegimentUnit] = [Kit.renown_unit("Sky Captain", "captain", "kharadron_overlords")]
	var regiment := Kit.regiment_of_renown("Privateers", 100, units)
	var faction_name := FactionCatalog.name_for_id("kharadron_overlords")
	assert_false(faction_name.is_empty(), "test relies on a faction directory named kharadron_overlords")
	assert_string_contains(RulesSearch.regiment_text(regiment), faction_name)


func test_regiment_text_lists_a_home_faction_once() -> void:
	var units: Array[RegimentUnit] = [Kit.renown_unit("A", "a", "kharadron_overlords"), Kit.renown_unit("B", "b", "kharadron_overlords")]
	var faction_name := FactionCatalog.name_for_id("kharadron_overlords")
	var text := RulesSearch.regiment_text(Kit.regiment_of_renown("Privateers", 100, units))
	assert_eq(text.count(faction_name), 1)


func test_regiment_text_ignores_units_of_unknown_factions() -> void:
	var units: Array[RegimentUnit] = [Kit.renown_unit("Hermit", "hermit", "no_such_faction")]
	var text := RulesSearch.regiment_text(Kit.regiment_of_renown("Solo", 100, units))
	assert_eq(text, "Solo  Hermit")


func test_regiment_search_by_faction_name_finds_the_regiment() -> void:
	var units: Array[RegimentUnit] = [Kit.renown_unit("Sky Captain", "captain", "kharadron_overlords")]
	var regiment := Kit.regiment_of_renown("Privateers", 100, units)
	assert_true(RulesSearch.matches(RulesSearch.regiment_text(regiment), RulesSearch.words("kharadron")))
