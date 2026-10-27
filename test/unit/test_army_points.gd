extends GutTest
## Unit tests for army points (scripts/army/army_points.gd).

const Kit := preload("res://test/support/army_kit.gd")


func _faction() -> Faction:
	var scrolls: Array[Warscroll] = [Kit.hero("hero"), Kit.warscroll("grunt", PackedStringArray(), 90),
			Kit.warscroll("terrain", PackedStringArray(["FACTION TERRAIN"]), 30)]
	scrolls[1].can_reinforce = true
	var faction := Kit.faction(scrolls)
	faction.enhancement_tables = [Kit.table("Artefacts of Power", [Kit.ability("Sword", 20)] as Array[Ability])] as Array[EnhancementTable]
	faction.lores = [Kit.lore("Fire", "spell", 10), Kit.lore("Hymns", "prayer", 15)] as Array[Lore]
	faction.battle_formations = [Kit.formation("Vanguard", 25)] as Array[BattleFormation]
	var members: Array[RegimentUnit] = [Kit.renown_unit("Grunt", "grunt")]
	faction.regiments_of_renown = [Kit.regiment_of_renown("Band", 150, members)] as Array[RegimentOfRenown]
	return faction


func _catalog() -> ArmyCatalog:
	var universal: Array[Lore] = [Kit.lore("Universal", "manifestation", 5)]
	return Kit.catalog(_faction(), Kit.core(PackedStringArray(), universal))


func _regiment() -> ArmyRegiment:
	return Kit.regiment("r1", [Kit.unit("u1", "hero"), Kit.unit("u2", "grunt")] as Array[ArmyUnit])


func test_unit_points_are_the_warscroll_points() -> void:
	assert_eq(ArmyPoints.unit_points(Kit.unit("u", "grunt"), null, Kit.army(), _catalog()), 90)


func test_reinforced_unit_costs_double() -> void:
	var unit := Kit.unit("u", "grunt")
	unit.reinforced = true
	assert_eq(ArmyPoints.unit_points(unit, null, Kit.army(), _catalog()), 180)


func test_enhancement_points_are_added() -> void:
	var unit := Kit.unit("u", "hero")
	unit.enhancements = {"Artefacts of Power": "Sword"}
	assert_eq(ArmyPoints.unit_points(unit, null, Kit.army(), _catalog()), 120)


func test_enhancement_points_count_only_enhancements() -> void:
	var unit := Kit.unit("u", "hero")
	unit.enhancements = {"Artefacts of Power": "Sword"}
	var catalog := _catalog()
	var army := Kit.army()
	assert_eq(ArmyPoints.enhancement_points(unit, null, army, catalog),
			ArmyPoints.unit_points(unit, null, army, catalog) - catalog.faction.get_warscroll("hero").points)


func test_enhancement_points_are_zero_without_enhancements() -> void:
	assert_eq(ArmyPoints.enhancement_points(Kit.unit("u", "hero"), null, Kit.army(), _catalog()), 0)


func test_enhancement_points_are_zero_in_a_regiment_of_renown() -> void:
	var unit := Kit.unit("u", "grunt")
	unit.enhancements = {"Artefacts of Power": "Sword"}
	var regiment := Kit.ror_regiment("r9", "Band", [unit] as Array[ArmyUnit])
	assert_eq(ArmyPoints.enhancement_points(unit, regiment, Kit.army(), _catalog()), 0)


func test_enhancement_points_are_not_doubled_by_reinforcing() -> void:
	var unit := Kit.unit("u", "grunt")
	unit.reinforced = true
	unit.enhancements = {"Artefacts of Power": "Sword"}
	assert_eq(ArmyPoints.unit_points(unit, null, Kit.army(), _catalog()), 200)


func test_unknown_enhancement_costs_nothing() -> void:
	var unit := Kit.unit("u", "grunt")
	unit.enhancements = {"Artefacts of Power": "Nope"}
	assert_eq(ArmyPoints.unit_points(unit, null, Kit.army(), _catalog()), 90)


func test_unit_with_missing_warscroll_costs_nothing() -> void:
	assert_eq(ArmyPoints.unit_points(Kit.unit("u", "gone"), null, Kit.army(), _catalog()), 0)


func test_unit_in_a_regiment_of_renown_costs_nothing() -> void:
	var regiment := Kit.ror_regiment("r", "Band", [Kit.unit("u", "grunt")] as Array[ArmyUnit])
	assert_eq(ArmyPoints.unit_points(regiment.units[0], regiment, Kit.army(), _catalog()), 0)


func test_regiment_points_sum_its_units() -> void:
	assert_eq(ArmyPoints.regiment_points(_regiment(), Kit.army(), _catalog()), 190)


func test_regiment_of_renown_costs_the_regiments_points() -> void:
	var regiment := Kit.ror_regiment("r", "Band", [Kit.unit("u", "grunt")] as Array[ArmyUnit])
	assert_eq(ArmyPoints.regiment_points(regiment, Kit.army(), _catalog()), _catalog().regiment_of_renown("Band").points)


func test_unknown_regiment_of_renown_costs_nothing() -> void:
	var regiment := Kit.ror_regiment("r", "Nope", [] as Array[ArmyUnit])
	assert_eq(ArmyPoints.regiment_points(regiment, Kit.army(), _catalog()), 0)


func test_army_rule_points_are_zero_without_choices() -> void:
	assert_eq(ArmyPoints.army_rule_points(Kit.army(), _catalog()), 0)


func test_army_rule_points_include_each_lore() -> void:
	var army := Kit.army()
	army.spell_lore = "Fire"
	army.prayer_lore = "Hymns"
	army.manifestation_lore = "Universal"
	assert_eq(ArmyPoints.army_rule_points(army, _catalog()), 30)


func test_army_rule_points_include_the_formation() -> void:
	var army := Kit.army()
	army.formation = "Vanguard"
	assert_eq(ArmyPoints.army_rule_points(army, _catalog()), 25)


func test_army_rule_points_include_faction_terrain() -> void:
	var army := Kit.army()
	army.faction_terrain = "terrain"
	assert_eq(ArmyPoints.army_rule_points(army, _catalog()), 30)


func test_army_rule_points_ignore_unknown_choices() -> void:
	var army := Kit.army()
	army.spell_lore = "Nope"
	army.formation = "Nope"
	army.faction_terrain = "nope"
	assert_eq(ArmyPoints.army_rule_points(army, _catalog()), 0)


func test_total_adds_regiments_auxiliary_units_and_rules() -> void:
	var army := Kit.army()
	army.regiments.append(_regiment())
	army.auxiliary.append(Kit.unit("u3", "grunt"))
	army.spell_lore = "Fire"
	assert_eq(ArmyPoints.total(army, _catalog()), 190 + 90 + 10)


func test_total_counts_a_regiment_of_renown_once() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.ror_regiment("r", "Band", [Kit.unit("u", "grunt"), Kit.unit("v", "grunt")] as Array[ArmyUnit]))
	assert_eq(ArmyPoints.total(army, _catalog()), _catalog().regiment_of_renown("Band").points)


func test_total_of_empty_army_is_zero() -> void:
	assert_eq(ArmyPoints.total(Kit.army(), _catalog()), 0)
