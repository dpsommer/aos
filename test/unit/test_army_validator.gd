extends GutTest
## Unit tests for army validation (scripts/army/army_validator.gd).
##
## Problem messages are checked for the name they concern, not for their exact wording.

const Kit := preload("res://test/support/army_kit.gd")


func _scroll(id: String, keywords := PackedStringArray(), points := 100) -> Warscroll:
	return Kit.warscroll(id, keywords, points)


func _faction() -> Faction:
	var hero_a := Kit.hero("hero_a", PackedStringArray(["Any INFANTRY", "0-1 Hounds"]))
	var hero_b := Kit.hero("hero_b", PackedStringArray(["Any INFANTRY"]))
	var hero_req := Kit.hero("hero_req", PackedStringArray(["Grunt (required)"]))
	var hero_req_any := Kit.hero("hero_req_any", PackedStringArray(["Grunt (required)", "Any INFANTRY"]))
	var exemplar := Kit.hero("exemplar")
	exemplar.notes = "This HERO can join an eligible regiment as a TEST EXEMPLAR."
	var hero_role := Kit.hero("hero_role", PackedStringArray(["0-1 TEST EXEMPLAR"]))
	var scrolls: Array[Warscroll] = [
		hero_a, hero_b, hero_req, hero_req_any, exemplar, hero_role,
		Kit.hero("warmaster", PackedStringArray(["Any INFANTRY"]), PackedStringArray(["WARMASTER"])),
		Kit.hero("unique_hero", PackedStringArray(["Any INFANTRY"]), PackedStringArray(["UNIQUE"])),
		Kit.hero("wizard", PackedStringArray(), PackedStringArray(["WIZARD (1)"])),
		Kit.hero("priest", PackedStringArray(), PackedStringArray(["PRIEST"])),
		_scroll("grunt", PackedStringArray(["INFANTRY"])),
		_scroll("hounds", PackedStringArray(["BEAST"])),
		_scroll("monster", PackedStringArray(["MONSTER"])),
		_scroll("terrain", PackedStringArray(["FACTION TERRAIN"])),
		_scroll("plain_unit"),
		_scroll("pricey", PackedStringArray(["INFANTRY"]), 3000),
	]
	var aqshy := _scroll("grunt_aqshy", PackedStringArray(["INFANTRY"]))
	aqshy.name = "Grunt"
	aqshy.source = "Scourge of Aqshy"
	var ghyran := _scroll("grunt_ghyran", PackedStringArray(["INFANTRY"]))
	ghyran.name = "Grunt"
	ghyran.source = "Scourge of Ghyran"
	scrolls.append_array([aqshy, ghyran])
	var faction := Kit.faction(scrolls)
	faction.enhancement_tables = [
		Kit.table("Heroic Traits", [Kit.ability("Brave"), Kit.ability("Bold")] as Array[Ability]),
		Kit.table("Artefacts of Power", [Kit.ability("Sword")] as Array[Ability]),
		Kit.table("Banners", [Kit.ability("Flag")] as Array[Ability]),
		Kit.table("Great Works", [Kit.ability("Engine")] as Array[Ability]),
	] as Array[EnhancementTable]
	faction.enhancement_tables[3].units = PackedStringArray(["Grunt"])
	faction.lores = [Kit.lore("Fire", "spell"), Kit.lore("Hymns", "prayer")] as Array[Lore]
	faction.battle_formations = [Kit.formation("Vanguard")] as Array[BattleFormation]
	var members: Array[Warscroll] = [_scroll("ror_hero", PackedStringArray(["HERO", "WARMASTER", "WIZARD (1)"])),
			_scroll("ror_grunt", PackedStringArray(["INFANTRY"]))]
	faction.regiments_of_renown = [
		Kit.regiment_of_renown("Band", 100, [] as Array[RegimentUnit], members),
		Kit.regiment_of_renown("Other Band", 100, [] as Array[RegimentUnit], members),
	] as Array[RegimentOfRenown]
	return faction


func _catalog(faction: Faction = null) -> ArmyCatalog:
	var universal: Array[Lore] = [Kit.lore("Universal", "manifestation")]
	return Kit.catalog(faction if faction else _faction(), Kit.core(PackedStringArray(["Card A", "Card B", "Card C"]), universal))


## A valid army: hero_a leads one grunt and is the general.
func _army() -> Army:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "hero_a"), Kit.unit("u2", "grunt")] as Array[ArmyUnit], "Alpha"))
	army.general_uid = "u1"
	army.formation = "Vanguard"
	army.tactics = PackedStringArray(["Card A", "Card B"])
	return army


func _regiment(id: String, leader: String, others: Array[String] = []) -> ArmyRegiment:
	var units: Array[ArmyUnit] = [Kit.unit("%s_lead" % id, leader)]
	for i in others.size():
		units.append(Kit.unit("%s_%d" % [id, i], others[i]))
	return Kit.regiment(id, units, id)


func _grunts(count: int) -> Array[String]:
	var result: Array[String] = []
	for i in count:
		result.append("grunt")
	return result


func _problems(army: Army, catalog: ArmyCatalog = null) -> PackedStringArray:
	return ArmyValidator.validate(army, catalog if catalog else _catalog()).problems


func _warnings(army: Army, catalog: ArmyCatalog = null) -> PackedStringArray:
	return ArmyValidator.validate(army, catalog if catalog else _catalog()).warnings


func _mentions(messages: PackedStringArray, text: String) -> bool:
	for message in messages:
		if text.to_lower() in message.to_lower():
			return true
	return false


func _assert_problem(army: Army, text: String, catalog: ArmyCatalog = null) -> void:
	var problems := _problems(army, catalog)
	assert_true(_mentions(problems, text), "expected a problem mentioning '%s', got %s" % [text, problems])


func _assert_no_problem(army: Army, text: String, catalog: ArmyCatalog = null) -> void:
	var problems := _problems(army, catalog)
	assert_false(_mentions(problems, text), "unexpected problem mentioning '%s': %s" % [text, problems])


## A Regiment of Renown regiment whose units are the regiment's own hero and grunt.
func _ror(id := "rr", ror_name := "Band") -> ArmyRegiment:
	return Kit.ror_regiment(id, ror_name, [Kit.unit("%s_h" % id, "ror_hero"), Kit.unit("%s_g" % id, "ror_grunt")] as Array[ArmyUnit])


## An Army of Renown "Horde" with the given roster entries.
func _horde_catalog(entries: Array[RosterEntry]) -> ArmyCatalog:
	var faction := _faction()
	faction.armies_of_renown = [Kit.army_of_renown("Horde", entries)] as Array[ArmyOfRenown]
	return _catalog(faction)


func _horde_army() -> Army:
	var army := _army()
	army.army_of_renown = "Horde"
	army.formation = ""
	return army


# Baseline and override

func test_valid_army_has_no_problems() -> void:
	assert_eq(_problems(_army()).size(), 0, str(_problems(_army())))


func test_valid_army_has_no_warnings() -> void:
	assert_eq(_warnings(_army()).size(), 0, str(_warnings(_army())))


func test_valid_army_is_valid_and_not_overridden() -> void:
	var result := ArmyValidator.validate(_army(), _catalog())
	assert_true(result.is_valid())
	assert_false(result.overridden)


func test_overriding_constraints_skips_all_checks() -> void:
	var army := Kit.army()
	army.override_constraints = true
	var result := ArmyValidator.validate(army, _catalog())
	assert_true(result.overridden)
	assert_true(result.is_valid())
	assert_eq(result.warnings.size(), 0)


func test_identical_problems_are_reported_once() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "monster"))
	army.regiments[0].units.append(Kit.unit("u4", "monster"))
	var count := 0
	for problem in _problems(army):
		if "Monster" in problem:
			count += 1
	assert_eq(count, 1)


# Regiments

func test_army_without_regiments_needs_one() -> void:
	var army := _army()
	army.regiments.clear()
	_assert_problem(army, "at least 1 regiment")


func test_regiment_of_renown_does_not_count_as_a_built_regiment() -> void:
	var army := _army()
	army.regiments = [_ror()] as Array[ArmyRegiment]
	_assert_problem(army, "at least 1 regiment")


func test_five_regiments_are_allowed() -> void:
	var army := Kit.army()
	army.formation = "Vanguard"
	army.tactics = PackedStringArray(["Card A", "Card B"])
	for i in ArmyValidator.MAX_REGIMENTS:
		army.regiments.append(_regiment("r%d" % i, "hero_b"))
	army.general_uid = "r0_lead"
	_assert_no_problem(army, "at most")


func test_too_many_regiments_is_a_problem() -> void:
	var army := _army()
	for i in ArmyValidator.MAX_REGIMENTS:
		army.regiments.append(_regiment("x%d" % i, "hero_b"))
	_assert_problem(army, "at most")


func test_regiment_of_renown_does_not_count_towards_the_regiment_limit() -> void:
	var army := _army()
	for i in ArmyValidator.MAX_REGIMENTS - 1:
		army.regiments.append(_regiment("x%d" % i, "hero_b"))
	army.regiments.append(_ror())
	_assert_no_problem(army, "at most")


func test_regiment_led_by_a_non_hero_needs_a_hero_leader() -> void:
	var army := _army()
	army.regiments.append(_regiment("Bad Regiment", "grunt"))
	_assert_problem(army, "Bad Regiment needs a Hero")


func test_empty_regiment_needs_a_hero_leader() -> void:
	var army := _army()
	army.regiments.append(Kit.regiment("e1", [] as Array[ArmyUnit], "Empty Regiment"))
	_assert_problem(army, "Empty Regiment needs a Hero")


func test_regiment_can_hold_the_normal_number_of_units() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_b", _grunts(ArmyValidator.REGIMENT_UNITS)))
	_assert_no_problem(army, "Side has")


func test_regiment_over_the_normal_size_is_a_problem() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_b", _grunts(ArmyValidator.REGIMENT_UNITS + 1)))
	_assert_problem(army, "Side has")


func test_generals_regiment_can_hold_one_more_unit() -> void:
	var army := _army()
	army.regiments[0] = _regiment("Alpha", "hero_a", _grunts(ArmyValidator.GENERAL_REGIMENT_UNITS))
	army.general_uid = "Alpha_lead"
	_assert_no_problem(army, "Alpha has")


func test_generals_regiment_over_its_size_is_a_problem() -> void:
	var army := _army()
	army.regiments[0] = _regiment("Alpha", "hero_a", _grunts(ArmyValidator.GENERAL_REGIMENT_UNITS + 1))
	army.general_uid = "Alpha_lead"
	_assert_problem(army, "Alpha has")


func test_regiment_capacity_is_larger_for_the_general() -> void:
	var army := _army()
	assert_gt(ArmyValidator.regiment_capacity(army.regiments[0], army),
			ArmyValidator.regiment_capacity(_regiment("other", "hero_b"), army))


# Regiment options

func test_unit_matching_an_option_is_allowed() -> void:
	_assert_no_problem(_army(), "regiment options")


func test_unit_outside_the_options_is_a_problem_naming_it() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "monster"))
	_assert_problem(army, "Monster")


func test_option_limited_to_one_is_a_problem_on_the_second_unit() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "hounds"))
	army.regiments[0].units.append(Kit.unit("u4", "hounds"))
	_assert_problem(army, "another Hounds")


func test_option_limited_to_one_allows_the_first_unit() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "hounds"))
	_assert_no_problem(army, "Hounds")


func test_hero_joins_a_regiment_through_its_role() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_role", ["exemplar"]))
	_assert_no_problem(army, "Exemplar")


func test_hero_without_the_role_cannot_join() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_role", ["hero_b"]))
	_assert_problem(army, "Hero B")


func test_missing_required_unit_is_a_problem_naming_it() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_req"))
	_assert_problem(army, "Grunt")


func test_included_required_unit_satisfies_the_option() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_req", ["grunt"]))
	_assert_no_problem(army, "must include")


func test_required_unit_also_matching_an_any_option_satisfies_the_requirement() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_req_any", ["grunt"]))
	_assert_no_problem(army, "must include")


# General

func test_army_without_a_general_is_a_problem() -> void:
	var army := _army()
	army.general_uid = ""
	_assert_problem(army, "general")


func test_general_that_is_not_a_unit_in_the_army_is_a_problem() -> void:
	var army := _army()
	army.general_uid = "ghost"
	_assert_problem(army, "general")


func test_general_who_does_not_lead_a_regiment_is_a_problem() -> void:
	var army := _army()
	army.general_uid = "u2"
	_assert_problem(army, "lead a regiment")


func test_auxiliary_general_is_a_problem() -> void:
	var army := _army()
	army.auxiliary.append(Kit.unit("u9", "hero_b"))
	army.general_uid = "u9"
	_assert_problem(army, "lead a regiment")


func test_general_in_a_regiment_of_renown_is_a_problem() -> void:
	var army := _army()
	army.regiments.append(_ror())
	army.general_uid = "rr_h"
	_assert_problem(army, "Regiment of Renown")


func test_warmaster_must_be_the_general() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "warmaster"))
	_assert_problem(army, "Warmaster")


func test_warmaster_as_general_is_allowed() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "warmaster"))
	army.general_uid = "Side_lead"
	_assert_no_problem(army, "Warmaster")


func test_warmaster_in_a_regiment_of_renown_does_not_force_the_general() -> void:
	var army := _army()
	army.regiments.append(_ror())
	_assert_no_problem(army, "Warmaster")


# Unique units

func test_unique_unit_included_twice_is_a_problem_naming_it() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "unique_hero"))
	army.auxiliary.append(Kit.unit("u9", "unique_hero"))
	_assert_problem(army, "Unique Hero")


func test_unique_unit_included_once_is_allowed() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "unique_hero"))
	_assert_no_problem(army, "is Unique and")


func test_non_unique_unit_can_be_repeated() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "grunt"))
	_assert_no_problem(army, "is Unique and")


# Scourge versions

func test_mixing_printed_and_scourge_versions_is_a_problem() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "grunt_aqshy"))
	_assert_problem(army, "same warscroll")


func test_mixing_two_scourge_versions_is_a_problem() -> void:
	var army := _army()
	army.regiments[0].units = [Kit.unit("u1", "hero_a"), Kit.unit("u3", "grunt_aqshy"), Kit.unit("u4", "grunt_ghyran")] as Array[ArmyUnit]
	_assert_problem(army, "same warscroll")


func test_repeating_one_scourge_version_is_allowed() -> void:
	var army := _army()
	army.regiments[0].units = [Kit.unit("u1", "hero_a"), Kit.unit("u3", "grunt_aqshy"), Kit.unit("u4", "grunt_aqshy")] as Array[ArmyUnit]
	_assert_no_problem(army, "same warscroll")


# Regiments of Renown

func test_one_regiment_of_renown_is_allowed() -> void:
	var army := _army()
	army.regiments.append(_ror())
	assert_eq(_problems(army).size(), 0, str(_problems(army)))


func test_second_regiment_of_renown_is_a_problem() -> void:
	var army := _army()
	army.regiments.append(_ror("rr1", "Band"))
	army.regiments.append(_ror("rr2", "Other Band"))
	_assert_problem(army, "only 1 Regiment of Renown")


func test_regiment_of_renown_the_faction_lacks_is_a_problem_naming_it() -> void:
	var army := _army()
	army.regiments.append(_ror("rr", "Phantom Band"))
	_assert_problem(army, "Phantom Band")


func test_army_of_renown_forbidding_regiments_of_renown_is_a_problem_naming_it() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("", PackedStringArray(["HERO"])), Kit.roster_entry("", PackedStringArray(["INFANTRY"]))]
	var faction := _faction()
	faction.armies_of_renown = [Kit.army_of_renown("Horde", entries)] as Array[ArmyOfRenown]
	faction.armies_of_renown[0].roster.regiments_of_renown = false
	var army := _horde_army()
	army.regiments.append(_ror())
	_assert_problem(army, "Horde", _catalog(faction))


# Missing warscrolls

func test_unit_missing_from_the_data_is_a_problem_naming_it() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "vanished_unit"))
	_assert_problem(army, "vanished_unit")


# Enhancements

func test_one_enhancement_per_type_is_allowed() -> void:
	var army := _army()
	army.regiments[0].units[0].enhancements = {"Heroic Traits": "Brave", "Artefacts of Power": "Sword"}
	assert_eq(_problems(army).size(), 0, str(_problems(army)))


func test_enhancement_the_army_lacks_is_a_problem_naming_it() -> void:
	var army := _army()
	army.regiments[0].units[0].enhancements = {"Heroic Traits": "Phantom Trait"}
	_assert_problem(army, "Phantom Trait")


func test_same_type_on_two_units_is_a_problem_naming_the_type() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_b"))
	army.regiments[0].units[0].enhancements = {"Heroic Traits": "Brave"}
	army.regiments[1].units[0].enhancements = {"Heroic Traits": "Bold"}
	_assert_problem(army, "Heroic Traits")


func test_same_enhancement_twice_is_a_problem() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "hero_b"))
	army.regiments[0].units[0].enhancements = {"Heroic Traits": "Brave"}
	army.regiments[1].units[0].enhancements = {"Heroic Traits": "Brave"}
	_assert_problem(army, "Heroic Traits")


func test_empty_enhancement_name_is_ignored() -> void:
	var army := _army()
	army.regiments[0].units[0].enhancements = {"Heroic Traits": ""}
	assert_eq(_problems(army).size(), 0, str(_problems(army)))


func test_unique_unit_cannot_have_an_enhancement() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "unique_hero"))
	army.regiments[1].units[0].enhancements = {"Heroic Traits": "Brave"}
	_assert_problem(army, "Unique Hero")


func test_unit_in_a_regiment_of_renown_cannot_have_an_enhancement() -> void:
	var army := _army()
	var band := _ror()
	band.units[1].enhancements = {"Banners": "Flag"}
	army.regiments.append(band)
	_assert_problem(army, "Ror Grunt")


func test_hero_enhancement_on_a_non_hero_is_a_problem_naming_the_unit() -> void:
	var army := _army()
	army.regiments[0].units[1].enhancements = {"Heroic Traits": "Brave"}
	_assert_problem(army, "Grunt")


func test_enhancement_for_certain_units_on_another_unit_is_a_problem_naming_the_unit() -> void:
	var army := _army()
	army.regiments[0].units[0].enhancements = {"Great Works": "Engine"}
	_assert_problem(army, "Hero A")


func test_enhancement_for_certain_units_names_the_units_it_is_for() -> void:
	var army := _army()
	army.regiments[0].units[0].enhancements = {"Great Works": "Engine"}
	_assert_problem(army, "only for Grunt")


func test_enhancement_for_certain_units_is_allowed_on_them() -> void:
	var army := _army()
	army.regiments[0].units[1].enhancements = {"Great Works": "Engine"}
	assert_eq(_problems(army).size(), 0, str(_problems(army)))


func test_other_enhancement_types_are_allowed_on_non_heroes() -> void:
	var army := _army()
	army.regiments[0].units[1].enhancements = {"Banners": "Flag"}
	assert_eq(_problems(army).size(), 0, str(_problems(army)))


# Lores

func test_unknown_lore_is_a_problem_naming_it() -> void:
	var army := _army()
	army.spell_lore = "Phantom Lore"
	_assert_problem(army, "Phantom Lore")


func test_lore_of_the_wrong_kind_is_a_problem() -> void:
	var army := _army()
	army.prayer_lore = "Fire"
	_assert_problem(army, "Fire")


func test_known_lores_are_allowed() -> void:
	var army := _army()
	army.spell_lore = "Fire"
	army.prayer_lore = "Hymns"
	army.manifestation_lore = "Universal"
	assert_eq(_problems(army).size(), 0, str(_problems(army)))


func test_wizard_without_a_spell_lore_is_a_warning() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "wizard"))
	army.manifestation_lore = "Universal"
	assert_true(_mentions(_warnings(army), "spell lore"))


func test_wizard_with_a_spell_lore_has_no_spell_warning() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "wizard"))
	army.spell_lore = "Fire"
	assert_false(_mentions(_warnings(army), "spell lore"))


func test_priest_without_a_prayer_lore_is_a_warning() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "priest"))
	assert_true(_mentions(_warnings(army), "prayer lore"))


func test_priest_with_a_prayer_lore_has_no_prayer_warning() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "priest"))
	army.prayer_lore = "Hymns"
	assert_false(_mentions(_warnings(army), "prayer lore"))


func test_caster_without_a_manifestation_lore_is_a_warning() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "wizard"))
	assert_true(_mentions(_warnings(army), "manifestation lore"))


func test_caster_with_a_manifestation_lore_has_no_manifestation_warning() -> void:
	var army := _army()
	army.regiments.append(_regiment("Side", "wizard"))
	army.manifestation_lore = "Universal"
	assert_false(_mentions(_warnings(army), "manifestation lore"))


func test_no_spell_lore_warning_when_the_faction_has_no_spell_lores() -> void:
	var faction := _faction()
	faction.lores = [] as Array[Lore]
	var army := _army()
	army.regiments.append(_regiment("Side", "wizard"))
	assert_false(_mentions(_warnings(army, _catalog(faction)), "spell lore"))


func test_wizard_in_a_regiment_of_renown_does_not_need_a_lore() -> void:
	var army := _army()
	army.regiments.append(_ror())
	assert_eq(_warnings(army).size(), 0, str(_warnings(army)))


# Battle formation and terrain

func test_missing_formation_is_a_problem() -> void:
	var army := _army()
	army.formation = ""
	_assert_problem(army, "formation")


func test_unknown_formation_is_a_problem_naming_it() -> void:
	var army := _army()
	army.formation = "Phantom Formation"
	_assert_problem(army, "Phantom Formation")


func test_faction_without_formations_needs_none() -> void:
	var faction := _faction()
	faction.battle_formations = [] as Array[BattleFormation]
	var army := _army()
	army.formation = ""
	_assert_no_problem(army, "formation", _catalog(faction))


func test_army_of_renown_needs_no_formation() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("", PackedStringArray(["HERO"])), Kit.roster_entry("", PackedStringArray(["INFANTRY"]))]
	_assert_no_problem(_horde_army(), "formation", _horde_catalog(entries))


func test_faction_terrain_is_allowed() -> void:
	var army := _army()
	army.faction_terrain = "terrain"
	assert_eq(_problems(army).size(), 0, str(_problems(army)))


func test_missing_faction_terrain_is_a_problem() -> void:
	var army := _army()
	army.faction_terrain = "vanished_terrain"
	_assert_problem(army, "terrain")


func test_warscroll_that_is_not_faction_terrain_is_a_problem() -> void:
	var army := _army()
	army.faction_terrain = "grunt"
	_assert_problem(army, "terrain")


func test_army_of_renown_forbidding_terrain_is_a_problem_naming_it() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("", PackedStringArray(["HERO"])), Kit.roster_entry("", PackedStringArray(["INFANTRY"]))]
	var faction := _faction()
	faction.armies_of_renown = [Kit.army_of_renown("Horde", entries)] as Array[ArmyOfRenown]
	faction.armies_of_renown[0].roster.faction_terrain = false
	var army := _horde_army()
	army.faction_terrain = "terrain"
	_assert_problem(army, "Horde", _catalog(faction))


# Battle tactics

func test_no_tactics_cards_is_a_problem() -> void:
	var army := _army()
	army.tactics = PackedStringArray(["", ""])
	_assert_problem(army, "battle tactics")


func test_one_tactics_card_is_only_a_warning() -> void:
	var army := _army()
	army.tactics = PackedStringArray(["Card A", ""])
	assert_eq(_problems(army).size(), 0, str(_problems(army)))
	assert_true(_mentions(_warnings(army), "battle tactics"))


func test_two_tactics_cards_give_no_warning() -> void:
	assert_false(_mentions(_warnings(_army()), "battle tactics"))


func test_three_tactics_cards_is_a_problem() -> void:
	var army := _army()
	army.tactics = PackedStringArray(["Card A", "Card B", "Card C"])
	_assert_problem(army, "at most")


func test_unknown_tactics_card_is_a_problem_naming_it() -> void:
	var army := _army()
	army.tactics = PackedStringArray(["Card A", "Phantom Card"])
	_assert_problem(army, "Phantom Card")


func test_same_tactics_card_twice_is_a_problem_naming_it() -> void:
	var army := _army()
	army.tactics = PackedStringArray(["Card A", "Card A"])
	_assert_problem(army, "Card A")


# Army of Renown roster

func test_unit_in_the_roster_is_allowed() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt")]
	assert_eq(_problems(_horde_army(), _horde_catalog(entries)).size(), 0, str(_problems(_horde_army(), _horde_catalog(entries))))


func test_unit_outside_the_roster_is_a_problem_naming_it() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A")]
	_assert_problem(_horde_army(), "Grunt", _horde_catalog(entries))


func test_roster_entry_can_match_by_keyword() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("", PackedStringArray(["HERO"])), Kit.roster_entry("", PackedStringArray(["INFANTRY"]))]
	assert_eq(_problems(_horde_army(), _horde_catalog(entries)).size(), 0)


func test_roster_entry_excluding_a_keyword_rejects_units_with_it() -> void:
	var excluding := Kit.roster_entry("", PackedStringArray(["INFANTRY"]))
	excluding.not_keywords = PackedStringArray(["INFANTRY"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), excluding]
	_assert_problem(_horde_army(), "Grunt", _horde_catalog(entries))


func test_per_entry_allows_one_unit_for_each_keyword_holder() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.per = PackedStringArray(["HERO"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited]
	_assert_no_problem(_horde_army(), "for each", _horde_catalog(entries))


func test_per_entry_over_its_allowance_is_a_problem() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.per = PackedStringArray(["HERO"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited]
	var army := _horde_army()
	army.regiments[0].units.append(Kit.unit("u3", "grunt"))
	_assert_problem(army, "for each HERO", _horde_catalog(entries))


func test_per_entry_can_match_by_unit_name() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.per = PackedStringArray(["Hero A"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited]
	_assert_no_problem(_horde_army(), "for each", _horde_catalog(entries))


func test_per_entry_naming_a_unit_not_in_the_army_allows_none() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.per = PackedStringArray(["Hero B"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited]
	_assert_problem(_horde_army(), "for each", _horde_catalog(entries))


func test_per_item_with_two_keywords_needs_a_unit_with_both() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.per = PackedStringArray(["HERO WARMASTER"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited]
	_assert_problem(_horde_army(), "for each", _horde_catalog(entries))


func test_per_item_with_two_keywords_counts_a_unit_with_both() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.per = PackedStringArray(["HERO WARMASTER"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Warmaster"), limited]
	var army := _horde_army()
	army.regiments.append(_regiment("Side", "warmaster"))
	_assert_no_problem(army, "for each", _horde_catalog(entries))


func test_per_entry_counts_a_unit_matching_any_of_its_items() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.per = PackedStringArray(["Hero B", "HERO"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited]
	_assert_no_problem(_horde_army(), "for each", _horde_catalog(entries))


func test_max_entry_allows_units_up_to_its_max() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.max = 2
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited]
	var army := _horde_army()
	army.regiments[0].units.append(Kit.unit("u3", "grunt"))
	_assert_no_problem(army, "at most", _horde_catalog(entries))


func test_max_entry_over_its_max_is_a_problem() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.max = 1
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited]
	var army := _horde_army()
	army.regiments[0].units.append(Kit.unit("u3", "grunt"))
	_assert_problem(army, "at most", _horde_catalog(entries))


func test_unit_also_matched_by_an_unlimited_entry_is_not_limited() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.max = 1
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), limited, Kit.roster_entry("", PackedStringArray(["INFANTRY"]))]
	var army := _horde_army()
	army.regiments[0].units.append(Kit.unit("u3", "grunt"))
	_assert_no_problem(army, "at most", _horde_catalog(entries))


func test_regiment_of_renown_units_do_not_count_against_a_max() -> void:
	var limited := Kit.roster_entry("Ror Grunt")
	limited.max = 1
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt"), limited]
	var army := _horde_army()
	army.regiments.append(_ror())
	_assert_no_problem(army, "at most", _horde_catalog(entries))


func _excluding_catalog(excluded: Array[String]) -> ArmyCatalog:
	var entries: Array[RosterEntry] = [Kit.roster_entry("", PackedStringArray(["HERO"])), Kit.roster_entry("", PackedStringArray(["INFANTRY"]))]
	var catalog := _horde_catalog(entries)
	catalog.faction.armies_of_renown[0].roster.excluded_units = PackedStringArray(excluded)
	return catalog


func test_excluded_unit_matching_a_roster_entry_is_a_problem_naming_it() -> void:
	_assert_problem(_horde_army(), "Hero A", _excluding_catalog(["Hero A"]))


func test_excluded_unit_is_reported_once() -> void:
	var problems := _problems(_horde_army(), _excluding_catalog(["Hero A"]))
	var mentioning := Array(problems).filter(func(p: String) -> bool: return "hero a" in p.to_lower())
	assert_eq(mentioning.size(), 1, str(problems))


func test_excluded_unit_is_not_reported_as_outside_the_roster() -> void:
	var problems := _problems(_horde_army(), _excluding_catalog(["Hero A"]))
	assert_false(Array(problems).any(func(p: String) -> bool: return "roster" in p.to_lower()), str(problems))


func test_unit_not_excluded_is_still_allowed() -> void:
	_assert_no_problem(_horde_army(), "Grunt", _excluding_catalog(["Hero A"]))


func test_excluded_unit_is_matched_by_name_ignoring_an_epithet() -> void:
	var catalog := _excluding_catalog(["Hero A"])
	for scroll in catalog.faction.warscrolls:
		if scroll.name == "Hero A":
			scroll.name = "Hero A, the Bold"
	_assert_problem(_horde_army(), "Hero A, the Bold", catalog)


func test_excluded_unit_in_a_regiment_of_renown_is_not_reported() -> void:
	var army := _horde_army()
	army.regiments.append(_ror())
	_assert_no_problem(army, "Ror Grunt", _excluding_catalog(["Ror Grunt"]))


func test_roster_keyword_matches_a_keyword_with_a_value() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt"), Kit.roster_entry("", PackedStringArray(["WIZARD"]))]
	var army := _horde_army()
	army.regiments.append(_regiment("Side", "wizard"))
	_assert_no_problem(army, "Wizard", _horde_catalog(entries))


func test_required_keyword_entry_that_is_missing_is_a_problem_naming_the_keyword() -> void:
	var required := Kit.roster_entry("", PackedStringArray(["EIDOLON"]))
	required.required = true
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt"), required]
	_assert_problem(_horde_army(), "EIDOLON", _horde_catalog(entries))


func test_required_keyword_entry_that_is_included_is_allowed() -> void:
	var required := Kit.roster_entry("", PackedStringArray(["HERO"]))
	required.required = true
	var entries: Array[RosterEntry] = [required, Kit.roster_entry("Grunt")]
	_assert_no_problem(_horde_army(), "must include", _horde_catalog(entries))


func _one_of(names: Array[String]) -> RosterEntry:
	var entry := Kit.roster_entry()
	entry.one_of = PackedStringArray(names)
	return entry


func test_one_of_entry_allows_a_unit_named_in_it() -> void:
	var entries: Array[RosterEntry] = [_one_of(["Hero A", "Hero B"]), Kit.roster_entry("Grunt")]
	assert_eq(_problems(_horde_army(), _horde_catalog(entries)).size(), 0, str(_problems(_horde_army(), _horde_catalog(entries))))


func test_unit_named_in_no_one_of_entry_is_a_problem_naming_it() -> void:
	var entries: Array[RosterEntry] = [_one_of(["Hero A", "Hero B"])]
	_assert_problem(_horde_army(), "Grunt", _horde_catalog(entries))


func test_one_of_entry_with_a_max_allows_one_listed_unit() -> void:
	var limited := _one_of(["Hero A", "Hero B"])
	limited.max = 1
	var entries: Array[RosterEntry] = [limited, Kit.roster_entry("Grunt")]
	_assert_no_problem(_horde_army(), "at most", _horde_catalog(entries))


func test_one_of_entry_with_a_max_rejects_two_different_listed_units() -> void:
	var limited := _one_of(["Hero A", "Hero B"])
	limited.max = 1
	var entries: Array[RosterEntry] = [limited, Kit.roster_entry("Grunt")]
	var army := _horde_army()
	army.regiments.append(_regiment("Side", "hero_b"))
	_assert_problem(army, "Hero A", _horde_catalog(entries))
	_assert_problem(army, "Hero B", _horde_catalog(entries))


func test_required_one_of_entry_is_satisfied_by_either_unit() -> void:
	var required := _one_of(["Hero B", "Hero A"])
	required.required = true
	var entries: Array[RosterEntry] = [required, Kit.roster_entry("Grunt")]
	_assert_no_problem(_horde_army(), "must include", _horde_catalog(entries))


func test_required_one_of_entry_with_none_included_is_a_problem_naming_the_alternatives() -> void:
	var required := _one_of(["Hero B", "Wizard"])
	required.required = true
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt"), required]
	_assert_problem(_horde_army(), "Hero B", _horde_catalog(entries))
	_assert_problem(_horde_army(), "Wizard", _horde_catalog(entries))


func test_roster_general_overrides_the_warmaster_rule() -> void:
	var must_lead := Kit.roster_entry("Hero A")
	must_lead.general = true
	var entries: Array[RosterEntry] = [must_lead, Kit.roster_entry("Grunt"), Kit.roster_entry("Warmaster")]
	var army := _horde_army()
	army.regiments.append(_regiment("Side", "warmaster"))
	_assert_no_problem(army, "Warmaster", _horde_catalog(entries))


func test_warmaster_still_forces_the_general_when_the_general_is_not_a_roster_general() -> void:
	var other := Kit.roster_entry("Hero B")
	other.general = true
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), other, Kit.roster_entry("Grunt"), Kit.roster_entry("Warmaster")]
	var army := _horde_army()
	army.regiments.append(_regiment("Side", "warmaster"))
	_assert_problem(army, "Warmaster", _horde_catalog(entries))


## A Horde catalog whose roster allows the base army and whose manifestations are forbidden.
func _no_manifestations_catalog() -> ArmyCatalog:
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt"), Kit.roster_entry("Wizard")]
	var catalog := _horde_catalog(entries)
	catalog.army_of_renown("Horde").roster.manifestations = false
	return catalog


func test_manifestation_lore_in_an_army_forbidding_manifestations_is_a_problem() -> void:
	var army := _horde_army()
	army.manifestation_lore = "Universal"
	_assert_problem(army, "Universal", _no_manifestations_catalog())


func test_manifestation_lore_in_an_army_allowing_manifestations_is_allowed() -> void:
	var army := _horde_army()
	army.manifestation_lore = "Universal"
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt")]
	_assert_no_problem(army, "Universal", _horde_catalog(entries))


func test_caster_has_no_manifestation_warning_when_manifestations_are_forbidden() -> void:
	var army := _horde_army()
	army.regiments.append(_regiment("Side", "wizard"))
	assert_false(_mentions(_warnings(army, _no_manifestations_catalog()), "manifestation lore"))


func test_required_roster_unit_that_is_missing_is_a_problem_naming_it() -> void:
	var required := Kit.roster_entry("Hero B")
	required.required = true
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt"), required]
	_assert_problem(_horde_army(), "Hero B", _horde_catalog(entries))


func test_required_roster_unit_that_is_included_is_allowed() -> void:
	var required := Kit.roster_entry("Hero A")
	required.required = true
	var entries: Array[RosterEntry] = [required, Kit.roster_entry("Grunt")]
	_assert_no_problem(_horde_army(), "must include", _horde_catalog(entries))


func test_roster_general_that_is_not_the_general_is_a_problem_naming_it() -> void:
	var must_lead := Kit.roster_entry("Hero B")
	must_lead.general = true
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt"), must_lead]
	var army := _horde_army()
	army.regiments.append(_regiment("Side", "hero_b"))
	_assert_problem(army, "Hero B", _horde_catalog(entries))


func test_roster_general_that_is_the_general_is_allowed() -> void:
	var must_lead := Kit.roster_entry("Hero A")
	must_lead.general = true
	var entries: Array[RosterEntry] = [must_lead, Kit.roster_entry("Grunt")]
	_assert_no_problem(_horde_army(), "must be your general", _horde_catalog(entries))


func test_roster_can_grant_the_warmaster_keyword() -> void:
	var gains := Kit.roster_entry("Hero B")
	gains.gains_keywords = PackedStringArray(["WARMASTER"])
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt"), gains]
	var army := _horde_army()
	army.regiments.append(_regiment("Side", "hero_b"))
	_assert_problem(army, "Warmaster", _horde_catalog(entries))


func test_regiment_of_renown_units_are_not_checked_against_the_roster() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero A"), Kit.roster_entry("Grunt")]
	var army := _horde_army()
	army.regiments.append(_ror())
	_assert_no_problem(army, "Ror", _horde_catalog(entries))


# Points

func test_army_over_its_points_limit_is_a_problem() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "pricey"))
	_assert_problem(army, "over")


func test_army_at_its_points_limit_is_allowed() -> void:
	var army := _army()
	army.points_limit = ArmyPoints.total(army, _catalog())
	assert_eq(_problems(army).size(), 0, str(_problems(army)))


func test_raising_the_limit_clears_the_points_problem() -> void:
	var army := _army()
	army.regiments[0].units.append(Kit.unit("u3", "pricey"))
	army.points_limit = 5000
	_assert_no_problem(army, "over")


# Units included from other factions

## A catalog whose Army of Renown "Horde" includes the faction "home"'s unit "Away" when [param includes].
func _including_catalog(includes := true) -> ArmyCatalog:
	var faction := _faction()
	var away_entry: Array[RosterEntry] = [Kit.roster_entry("Awayunit")]
	var renown := Kit.army_of_renown("Horde", away_entry)
	renown.roster.included_units = [] as Array[RosterInclusion]
	if includes:
		var inclusion := RosterInclusion.new()
		inclusion.faction = "home"
		renown.roster.included_units.append(inclusion)
	faction.armies_of_renown = [renown, Kit.army_of_renown("Plain", away_entry)] as Array[ArmyOfRenown]
	var home := Kit.faction([Kit.warscroll("away", PackedStringArray(), 100, "Awayunit")] as Array[Warscroll], "home")
	var loader := func(faction_id: String) -> Faction: return home if faction_id == "home" else null
	return ArmyCatalog.new(faction, Kit.core(), loader)


func _included_army(army_of_renown := "Horde") -> Army:
	var army := _horde_army()
	army.army_of_renown = army_of_renown
	var unit := Kit.unit("away_u", "away")
	unit.faction_id = "home"
	army.auxiliary.append(unit)
	return army


func test_included_unit_of_an_army_of_renown_that_includes_it_is_not_a_problem() -> void:
	_assert_no_problem(_included_army(), "Awayunit", _including_catalog())


func test_included_unit_after_leaving_the_army_of_renown_is_a_problem_naming_it() -> void:
	_assert_problem(_included_army(""), "Awayunit", _including_catalog())


func test_included_unit_in_an_army_of_renown_without_the_inclusion_is_a_problem_naming_it() -> void:
	_assert_problem(_included_army("Plain"), "Awayunit", _including_catalog())


func test_included_unit_in_a_regiment_is_a_problem_when_no_longer_included() -> void:
	var army := _included_army("")
	army.regiments[0].units.append(army.auxiliary.pop_back())
	_assert_problem(army, "Awayunit", _including_catalog())


func test_regiment_of_renown_units_with_a_faction_are_not_reported() -> void:
	var army := _army()
	var regiment := _ror()
	for unit in regiment.units:
		unit.faction_id = "home"
	army.regiments.append(regiment)
	_assert_no_problem(army, "can't include")


# Roster filtering

func _scroll_of(catalog: ArmyCatalog, id: String) -> Warscroll:
	return catalog.faction.get_warscroll(id)


func test_roster_allows_a_unit_matching_an_entry() -> void:
	var catalog := _horde_catalog([Kit.roster_entry("Grunt")] as Array[RosterEntry])
	var roster := catalog.faction.armies_of_renown[0].roster
	assert_true(ArmyValidator.roster_allows(roster, _scroll_of(catalog, "grunt")))


func test_roster_does_not_allow_a_unit_matching_no_entry() -> void:
	var catalog := _horde_catalog([Kit.roster_entry("Grunt")] as Array[RosterEntry])
	var roster := catalog.faction.armies_of_renown[0].roster
	assert_false(ArmyValidator.roster_allows(roster, _scroll_of(catalog, "hounds")))


func test_roster_does_not_allow_an_excluded_unit_matching_an_entry() -> void:
	var catalog := _excluding_catalog(["Hero A"])
	var roster := catalog.faction.armies_of_renown[0].roster
	assert_false(ArmyValidator.roster_allows(roster, _scroll_of(catalog, "hero_a")))


func test_roster_allows_a_unit_only_a_limited_entry_matches() -> void:
	var limited := Kit.roster_entry("Grunt")
	limited.max = 1
	var catalog := _horde_catalog([limited] as Array[RosterEntry])
	var roster := catalog.faction.armies_of_renown[0].roster
	assert_true(ArmyValidator.roster_allows(roster, _scroll_of(catalog, "grunt")))


# Units only one Army of Renown can include

## A catalog with Armies of Renown "Horde" and "March", both with rosters allowing everything, where
## the unit "Grunt" can only be included in "March".
func _march_catalog() -> ArmyCatalog:
	var faction := _faction()
	var entries: Array[RosterEntry] = [Kit.roster_entry("", PackedStringArray(["HERO"])), Kit.roster_entry("", PackedStringArray(["INFANTRY"]))]
	var more: Array[RosterEntry] = entries.duplicate()
	faction.armies_of_renown = [Kit.army_of_renown("Horde", entries), Kit.army_of_renown("March", more)] as Array[ArmyOfRenown]
	for scroll in faction.warscrolls:
		if scroll.id == "grunt":
			scroll.army_of_renown = "March"
	return _catalog(faction)


func _march_army(aor_name := "March") -> Army:
	var army := _horde_army()
	army.army_of_renown = aor_name
	return army


func test_army_of_renown_unit_in_its_own_army_of_renown_is_allowed() -> void:
	_assert_no_problem(_march_army(), "Grunt", _march_catalog())


func test_army_of_renown_unit_in_a_faction_army_is_a_problem_naming_it() -> void:
	_assert_problem(_army(), "Grunt", _march_catalog())


func test_army_of_renown_unit_in_another_army_of_renown_is_a_problem_naming_it() -> void:
	_assert_problem(_march_army("Horde"), "Grunt", _march_catalog())


func test_army_of_renown_unit_in_another_army_of_renown_is_a_problem_naming_its_army_of_renown() -> void:
	_assert_problem(_march_army("Horde"), "March", _march_catalog())


func test_army_of_renown_unit_in_a_regiment_of_renown_is_not_reported() -> void:
	var catalog := _march_catalog()
	catalog.faction.get_warscroll("grunt").army_of_renown = ""
	for scroll in catalog.faction.regiments_of_renown[0].warscrolls:
		scroll.army_of_renown = "March"
	var army := _horde_army()
	army.regiments.append(_ror())
	_assert_no_problem(army, "March", catalog)


# Paired leaders (Big Waaagh!)

func _dual(options: PackedStringArray) -> Warscroll:
	return Kit.hero("kragnos", options, PackedStringArray(["IRONJAWZ", "KRULEBOYZ"]))


## A catalog for the Army of Renown "Horde", paired IRONJAWZ/KRULEBOYZ, including the whole of the
## faction "home". The own faction is Ironjawz (ij_hero, ij_grunt, kragnos); "home" is Kruleboyz
## (kb_hero, kb_grunt, and its own version of kragnos).
func _paired_catalog(paired := PackedStringArray(["IRONJAWZ", "KRULEBOYZ"])) -> ArmyCatalog:
	var own: Array[Warscroll] = [
		Kit.hero("ij_hero", PackedStringArray(["Any IRONJAWZ"]), PackedStringArray(["IRONJAWZ"])),
		_scroll("ij_grunt", PackedStringArray(["IRONJAWZ"])),
		_dual(PackedStringArray(["Any IRONJAWZ"])),
	]
	var home_scrolls: Array[Warscroll] = [
		Kit.hero("kb_hero", PackedStringArray(["Any KRULEBOYZ"]), PackedStringArray(["KRULEBOYZ"])),
		_scroll("kb_grunt", PackedStringArray(["KRULEBOYZ"])),
		_dual(PackedStringArray(["Any KRULEBOYZ"])),
	]
	var home := Kit.faction(home_scrolls, "home")
	var faction := Kit.faction(own)
	faction.armies_of_renown = [Kit.army_of_renown("Horde")] as Array[ArmyOfRenown]
	var roster := faction.armies_of_renown[0].roster
	roster.paired_leaders = paired
	var inclusion := RosterInclusion.new()
	inclusion.faction = "home"
	roster.included_units = [inclusion] as Array[RosterInclusion]
	for scroll in own + home_scrolls:
		roster.entries.append(Kit.roster_entry(scroll.name))
	return Kit.catalog(faction, null, func(faction_id: String) -> Faction: return home if faction_id == "home" else null)


## A regiment led by [param leader] (of the own faction unless "kb_hero") with the given units,
## where ids starting with "kb_" come from "home".
func _paired_regiment(id: String, leader: String, others: Array[String] = []) -> ArmyRegiment:
	var regiment := _regiment(id, leader, others)
	for unit in regiment.units:
		if unit.warscroll_id.begins_with("kb_"):
			unit.faction_id = "home"
	return regiment


func _paired_army(regiments: Array[ArmyRegiment]) -> Army:
	var army := _horde_army()
	army.regiments.clear()
	for regiment in regiments:
		army.regiments.append(regiment)
	return army


const PAIRED_PROBLEM := "as many regiments led by"


func test_paired_leaders_balanced_regiments_are_allowed() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "kb_hero")] as Array[ArmyRegiment])
	_assert_no_problem(army, PAIRED_PROBLEM, _paired_catalog())


func test_paired_leaders_unbalanced_regiments_are_a_problem_naming_the_counts() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "ij_hero")] as Array[ArmyRegiment])
	_assert_problem(army, "IRONJAWZ Heroes as by KRULEBOYZ Heroes (2 and 0)", _paired_catalog())


func test_paired_leaders_problem_names_the_army_of_renown() -> void:
	var army := _paired_army([_paired_regiment("a", "kb_hero")] as Array[ArmyRegiment])
	_assert_problem(army, "Horde armies need", _paired_catalog())


func test_paired_leaders_empty_dual_leader_balances_a_lone_side() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "kragnos")] as Array[ArmyRegiment])
	_assert_no_problem(army, PAIRED_PROBLEM, _paired_catalog())


func test_paired_leaders_empty_dual_leader_cannot_fix_an_even_split() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "kb_hero"),
			_paired_regiment("c", "kragnos")] as Array[ArmyRegiment])
	_assert_problem(army, PAIRED_PROBLEM, _paired_catalog())


func test_paired_leaders_two_empty_dual_leaders_balance_each_other() -> void:
	var army := _paired_army([_paired_regiment("a", "kragnos"), _paired_regiment("b", "kragnos")] as Array[ArmyRegiment])
	_assert_no_problem(army, PAIRED_PROBLEM, _paired_catalog())


func test_paired_leaders_dual_leader_counts_for_the_keyword_of_its_units() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "kragnos", ["kb_grunt"])] as Array[ArmyRegiment])
	_assert_no_problem(army, PAIRED_PROBLEM, _paired_catalog())


func test_paired_leaders_dual_leader_with_units_of_the_same_side_does_not_balance_it() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "kragnos", ["ij_grunt"])] as Array[ArmyRegiment])
	_assert_problem(army, "(2 and 0)", _paired_catalog())


func test_paired_leaders_dual_leader_with_mixed_units_counts_as_either() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "kragnos", ["ij_grunt", "kb_grunt"])] as Array[ArmyRegiment])
	_assert_no_problem(army, PAIRED_PROBLEM, _paired_catalog())


func test_paired_leaders_non_heroes_do_not_count() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "kb_hero")] as Array[ArmyRegiment])
	army.regiments[0].units[0].warscroll_id = "ij_grunt"
	army.regiments[1].units[0].warscroll_id = "ij_grunt"
	_assert_no_problem(army, PAIRED_PROBLEM, _paired_catalog())


func test_no_paired_leaders_check_without_paired_leaders() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero"), _paired_regiment("b", "ij_hero")] as Array[ArmyRegiment])
	_assert_no_problem(army, PAIRED_PROBLEM, _paired_catalog(PackedStringArray()))


func test_no_paired_leaders_check_for_a_faction_army() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero")] as Array[ArmyRegiment])
	army.army_of_renown = ""
	_assert_no_problem(army, PAIRED_PROBLEM, _paired_catalog())


func test_dual_leader_can_include_the_other_factions_units() -> void:
	var army := _paired_army([_paired_regiment("a", "kragnos", ["kb_grunt"])] as Array[ArmyRegiment])
	_assert_no_problem(army, "regiment options", _paired_catalog())


func test_dual_leader_can_include_its_own_factions_units() -> void:
	var army := _paired_army([_paired_regiment("a", "kragnos", ["ij_grunt"])] as Array[ArmyRegiment])
	_assert_no_problem(army, "regiment options", _paired_catalog())


func test_dual_leader_with_units_of_both_sides_is_a_problem_naming_both() -> void:
	var army := _paired_army([_paired_regiment("a", "kragnos", ["ij_grunt", "kb_grunt"])] as Array[ArmyRegiment])
	_assert_problem(army, "either IRONJAWZ or KRULEBOYZ units in its regiment, not both", _paired_catalog())


func test_dual_leader_with_units_of_one_side_is_not_a_mixing_problem() -> void:
	var army := _paired_army([_paired_regiment("a", "kragnos", ["kb_grunt", "kb_grunt"])] as Array[ArmyRegiment])
	_assert_no_problem(army, "not both", _paired_catalog())


func test_single_keyword_leader_cannot_include_the_other_sides_units() -> void:
	var army := _paired_army([_paired_regiment("a", "ij_hero", ["kb_grunt"])] as Array[ArmyRegiment])
	_assert_problem(army, "regiment options", _paired_catalog())


# names_or_keywords

func _wizard() -> Warscroll:
	return Kit.warscroll("Sorcerer Lord", PackedStringArray(["HERO", "WIZARD (2)", "CHAOS"]), 100, "Sorcerer Lord")


func test_names_or_keywords_matches_the_unit_name() -> void:
	assert_true(ArmyValidator.names_or_keywords(_wizard(), PackedStringArray(["Other", "Sorcerer Lord"])))


func test_names_or_keywords_matches_a_name_ignoring_case() -> void:
	assert_true(ArmyValidator.names_or_keywords(_wizard(), PackedStringArray(["sorcerer lord"])))


func test_names_or_keywords_matches_a_keyword() -> void:
	assert_true(ArmyValidator.names_or_keywords(_wizard(), PackedStringArray(["CHAOS"])))


func test_names_or_keywords_matches_a_keyword_with_a_value() -> void:
	assert_true(ArmyValidator.names_or_keywords(_wizard(), PackedStringArray(["WIZARD"])))


func test_names_or_keywords_matches_when_all_space_separated_keywords_are_held() -> void:
	assert_true(ArmyValidator.names_or_keywords(_wizard(), PackedStringArray(["HERO CHAOS"])))


func test_names_or_keywords_rejects_when_one_space_separated_keyword_is_missing() -> void:
	assert_false(ArmyValidator.names_or_keywords(_wizard(), PackedStringArray(["HERO ORDER"])))


func test_names_or_keywords_rejects_an_unrelated_item() -> void:
	assert_false(ArmyValidator.names_or_keywords(_wizard(), PackedStringArray(["Gryph-hound", "ORDER"])))


func test_names_or_keywords_rejects_no_items() -> void:
	assert_false(ArmyValidator.names_or_keywords(_wizard(), PackedStringArray()))


# Army of Renown regiment options

## An Army of Renown "Horde" giving the leaders named [param leaders] (every leader if empty) the
## regiment options [param options].
func _options_catalog(leaders: PackedStringArray, options: PackedStringArray) -> ArmyCatalog:
	var faction := _faction()
	faction.armies_of_renown = [Kit.army_of_renown("Horde", _horde_roster())] as Array[ArmyOfRenown]
	var added := RosterRegimentOptions.new()
	added.leaders = leaders
	added.options = options
	faction.armies_of_renown[0].roster.regiment_options = [added] as Array[RosterRegimentOptions]
	return _catalog(faction)


func _horde_roster() -> Array[RosterEntry]:
	var entries: Array[RosterEntry] = []
	for unit_name in ["Hero A", "Hero B", "Unique Hero", "Monster", "Exemplar"]:
		entries.append(Kit.roster_entry(unit_name))
	return entries


func _monster_army(leader := "hero_b") -> Army:
	var army := _horde_army()
	army.regiments[0] = _regiment("Side", leader, ["monster"])
	army.general_uid = "Side_lead"
	return army


func test_added_regiment_option_allows_a_unit_the_leader_alone_does_not() -> void:
	var catalog := _options_catalog(PackedStringArray(["Hero B"]), PackedStringArray(["Any MONSTER"]))
	_assert_no_problem(_monster_army(), "regiment options", catalog)


func test_added_regiment_option_for_every_leader_allows_the_unit() -> void:
	var catalog := _options_catalog(PackedStringArray(), PackedStringArray(["Any MONSTER"]))
	_assert_no_problem(_monster_army(), "regiment options", catalog)


func test_added_regiment_option_for_a_leader_keyword_allows_the_unit() -> void:
	var catalog := _options_catalog(PackedStringArray(["UNIQUE"]), PackedStringArray(["Any MONSTER"]))
	_assert_no_problem(_monster_army("unique_hero"), "regiment options", catalog)


func test_unit_is_still_rejected_without_the_army_of_renown() -> void:
	var army := _monster_army()
	army.army_of_renown = ""
	_assert_problem(army, "regiment options", _options_catalog(PackedStringArray(["Hero B"]), PackedStringArray(["Any MONSTER"])))


func test_unit_is_still_rejected_in_an_army_of_renown_without_added_options() -> void:
	var faction := _faction()
	faction.armies_of_renown = [Kit.army_of_renown("Horde", _horde_roster())] as Array[ArmyOfRenown]
	_assert_problem(_monster_army(), "regiment options", _catalog(faction))


func test_added_regiment_option_is_not_given_to_a_non_matching_leader() -> void:
	var catalog := _options_catalog(PackedStringArray(["Hero B"]), PackedStringArray(["Any MONSTER"]))
	var army := _monster_army("hero_a")
	_assert_problem(army, "regiment options", catalog)


func test_hero_joins_a_regiment_through_an_added_option() -> void:
	var catalog := _options_catalog(PackedStringArray(["Hero B"]), PackedStringArray(["Any TEST EXEMPLAR"]))
	var army := _horde_army()
	army.regiments[0] = _regiment("Side", "hero_b", ["exemplar"])
	army.general_uid = "Side_lead"
	_assert_no_problem(army, "regiment options", catalog)


func test_hero_cannot_join_by_role_without_the_added_option() -> void:
	var army := _horde_army()
	army.regiments[0] = _regiment("Side", "hero_b", ["exemplar"])
	army.general_uid = "Side_lead"
	_assert_problem(army, "regiment options", _catalog())


# Non-Hero general

## An Army of Renown "Crew" whose Ironclad can be the general instead of a Hero, unless Brokk is
## included, and whose Ironclad regiments can include any Grunt.
func _crew_catalog() -> ArmyCatalog:
	var faction := _faction()
	faction.warscrolls.append(Kit.warscroll("ironclad", PackedStringArray(["WAR MACHINE"]), 100, "Ironclad"))
	faction.warscrolls.append(Kit.hero("brokk"))
	var crew := Kit.army_of_renown("Crew")
	crew.roster.non_hero_general = "Ironclad"
	crew.roster.non_hero_general_unless = PackedStringArray(["Brokk"])
	crew.roster.regiment_options = [_grunt_options()] as Array[RosterRegimentOptions]
	crew.enhancement_tables = faction.enhancement_tables
	faction.armies_of_renown = [crew] as Array[ArmyOfRenown]
	return _catalog(faction)


func _grunt_options() -> RosterRegimentOptions:
	var added := RosterRegimentOptions.new()
	added.leaders = PackedStringArray(["Ironclad"])
	added.options = PackedStringArray(["Any Grunt"])
	return added


## A Crew army with the Ironclad leading regiment "Fleet" with a grunt, and as the general.
func _crew_army() -> Army:
	var army := Kit.army()
	army.army_of_renown = "Crew"
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "ironclad"), Kit.unit("u2", "grunt")] as Array[ArmyUnit], "Fleet"))
	army.general_uid = "u1"
	army.tactics = PackedStringArray(["Card A", "Card B"])
	return army


func test_non_hero_general_can_lead_a_regiment() -> void:
	_assert_no_problem(_crew_army(), "needs a Hero", _crew_catalog())


func test_non_hero_general_leads_a_regiment_with_the_regiment_options_it_gains() -> void:
	_assert_no_problem(_crew_army(), "regiment options", _crew_catalog())


func test_non_hero_general_regiment_still_rejects_units_outside_its_options() -> void:
	var army := _crew_army()
	army.regiments[0].units.append(Kit.unit("u3", "monster"))
	_assert_problem(army, "Monster", _crew_catalog())


func test_non_hero_that_is_not_the_general_cannot_lead_and_the_message_says_so() -> void:
	var army := _crew_army()
	army.regiments.append(Kit.regiment("r2", [Kit.unit("u3", "hero_a"), Kit.unit("u4", "ironclad")] as Array[ArmyUnit], "Second"))
	army.regiments[1].units.reverse()
	_assert_problem(army, "Second needs a Hero leader: Ironclad can only lead it as your general", _crew_catalog())


func test_non_hero_general_blocked_by_another_unit_names_the_blocker() -> void:
	var army := _crew_army()
	army.regiments.append(Kit.regiment("r2", [Kit.unit("u3", "brokk")] as Array[ArmyUnit], "Second"))
	_assert_problem(army, "Fleet needs a Hero leader: Ironclad can't be your general while your army includes Brokk", _crew_catalog())


func test_unit_the_roster_does_not_name_gets_the_plain_hero_leader_problem() -> void:
	var army := _crew_army()
	army.regiments.append(_regiment("Plain", "grunt"))
	var problems := _problems(army, _crew_catalog())
	assert_true("Plain needs a Hero leader." in problems, str(problems))


func test_non_hero_general_can_be_given_a_heroic_trait() -> void:
	var army := _crew_army()
	army.regiments[0].units[0].enhancements = {"Heroic Traits": "Brave"}
	_assert_no_problem(army, "Heroic Traits", _crew_catalog())
	_assert_no_problem(army, "isn't a Hero", _crew_catalog())


func test_non_hero_that_is_not_the_general_cannot_be_given_a_heroic_trait() -> void:
	var army := _crew_army()
	army.regiments.append(Kit.regiment("r2", [Kit.unit("u3", "hero_a"), Kit.unit("u4", "ironclad")] as Array[ArmyUnit], "Second"))
	army.regiments[1].units[1].enhancements = {"Heroic Traits": "Brave"}
	_assert_problem(army, "Ironclad isn't a Hero", _crew_catalog())
