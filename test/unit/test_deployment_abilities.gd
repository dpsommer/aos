extends GutTest
## Unit tests for gathering deployment abilities (scripts/battle/deployment/deployment_abilities.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Kit := preload("res://test/support/army_kit.gd")

var DEPLOY := PackedStringArray(["DEPLOY"])


func _names(entries: Array[DeploymentAbility]) -> PackedStringArray:
	var result := PackedStringArray()
	for entry in entries:
		result.append(entry.name())
	return result


func _entry_named(army: BattleArmy, ability_name: String) -> DeploymentAbility:
	return army.deployment_ability(ability_name)


## A battle army made the way BattleBuilder does, from [param army]'s units in order, so
## [method DeploymentAbilities.for_army] can pair them up.
func _battle_army(army: Army, catalog: ArmyCatalog) -> BattleArmy:
	var result := BattleArmy.new()
	for regiment in army.regiments:
		var battle_regiment := BattleRegiment.new()
		battle_regiment.name = regiment.name
		for unit in regiment.units:
			var battle_unit := BattleUnit.create(unit.uid, catalog.warscroll(unit, regiment), 1)
			battle_unit.regiment = battle_regiment
			battle_regiment.units.append(battle_unit)
			result.units.append(battle_unit)
		result.regiments.append(battle_regiment)
	for unit in army.auxiliary:
		result.units.append(BattleUnit.create(unit.uid, catalog.warscroll(unit), 1))
	return result


func _faction(scrolls: Array[Warscroll]) -> Faction:
	return Kit.faction(scrolls)


func _catalog(faction: Faction, core: CoreRules = null) -> ArmyCatalog:
	return Kit.catalog(faction, core)


func _scroll_with(ability: Ability, id := "grunt") -> Warscroll:
	var scroll := Kit.warscroll(id)
	scroll.abilities = [ability] as Array[Ability]
	return scroll


# universal

func test_universal_gives_one_entry_per_name_in_order() -> void:
	var names := PackedStringArray([DeploymentAbility.DEPLOY_UNIT, DeploymentAbility.DEPLOY_REGIMENT])
	assert_eq(_names(DeploymentAbilities.universal(names, null)), names)


func test_universal_entries_have_the_universal_source() -> void:
	for entry in DeploymentAbilities.universal(DeploymentAbilities.MATCHED_PLAY_UNIVERSAL, null):
		assert_eq(entry.source, DeploymentAbility.UNIVERSAL)


func test_universal_without_core_rules_still_gets_the_right_kinds() -> void:
	var kinds: Array[DeploymentAbility.Kind] = []
	for entry in DeploymentAbilities.universal(DeploymentAbilities.MATCHED_PLAY_UNIVERSAL, null):
		kinds.append(entry.kind())
	assert_eq(kinds, [DeploymentAbility.Kind.DEPLOY_TERRAIN, DeploymentAbility.Kind.DEPLOY_UNIT, DeploymentAbility.Kind.DEPLOY_REGIMENT])


func test_universal_without_core_rules_puts_terrain_in_the_terrain_step() -> void:
	var entries := DeploymentAbilities.universal(PackedStringArray([DeploymentAbility.DEPLOY_FACTION_TERRAIN]), null)
	assert_eq(entries[0].step(), DeploymentAbility.Step.TERRAIN)


func test_universal_uses_the_core_rules_ability_when_it_has_it() -> void:
	var core := Kit.core()
	var ability := BattleKit.ability(DeploymentAbility.DEPLOY_UNIT, DEPLOY, "Core text.")
	core.abilities = [ability] as Array[Ability]
	var entries := DeploymentAbilities.universal(PackedStringArray([DeploymentAbility.DEPLOY_UNIT]), core)
	assert_same(entries[0].ability, ability)


func test_universal_falls_back_for_names_the_core_rules_lack() -> void:
	var core := Kit.core()
	core.abilities = [BattleKit.ability(DeploymentAbility.DEPLOY_UNIT)] as Array[Ability]
	var names := PackedStringArray([DeploymentAbility.DEPLOY_UNIT, DeploymentAbility.DEPLOY_REGIMENT])
	assert_eq(_names(DeploymentAbilities.universal(names, core)), names)


func test_spearhead_sets_up_units_but_not_regiments_or_terrain() -> void:
	var names := _names(DeploymentAbilities.universal(DeploymentAbilities.SPEARHEAD_UNIVERSAL, null))
	assert_true(DeploymentAbility.DEPLOY_UNIT in names)
	assert_false(DeploymentAbility.DEPLOY_REGIMENT in names)
	assert_false(DeploymentAbility.DEPLOY_FACTION_TERRAIN in names)


# for_army

func test_for_army_starts_with_the_universal_abilities() -> void:
	var army := Kit.army()
	var result := BattleArmy.new()
	DeploymentAbilities.for_army(result, army, _catalog(_faction([] as Array[Warscroll])))
	assert_eq(_names(result.deployment_abilities), DeploymentAbilities.MATCHED_PLAY_UNIVERSAL)


func test_for_army_adds_faction_battle_traits_that_are_deployment_abilities() -> void:
	var faction := _faction([] as Array[Warscroll])
	faction.battle_traits = [BattleKit.ability("Trait", DEPLOY), BattleKit.ability("Other", PackedStringArray())] as Array[Ability]
	var result := BattleArmy.new()
	DeploymentAbilities.for_army(result, Kit.army(), _catalog(faction))
	assert_not_null(_entry_named(result, "Trait"))
	assert_null(_entry_named(result, "Other"))
	assert_eq(_entry_named(result, "Trait").source, "Battle trait")


func test_for_army_adds_army_of_renown_traits_instead_of_the_factions() -> void:
	var faction := _faction([] as Array[Warscroll])
	faction.battle_traits = [BattleKit.ability("Faction trait", DEPLOY)] as Array[Ability]
	var renown := Kit.army_of_renown("Renown")
	renown.battle_traits = [BattleKit.ability("Renown trait", DEPLOY)] as Array[Ability]
	faction.armies_of_renown = [renown] as Array[ArmyOfRenown]
	var army := Kit.army()
	army.army_of_renown = "Renown"
	var result := BattleArmy.new()
	DeploymentAbilities.for_army(result, army, _catalog(faction))
	assert_null(_entry_named(result, "Faction trait"))
	assert_eq(_entry_named(result, "Renown trait").source, "Army of Renown")


func test_for_army_adds_the_battle_formations_abilities() -> void:
	var faction := _faction([] as Array[Warscroll])
	var formation := Kit.formation("Formation")
	formation.abilities = [BattleKit.ability("Formation ability", DEPLOY)] as Array[Ability]
	faction.battle_formations = [formation] as Array[BattleFormation]
	var army := Kit.army()
	army.formation = "Formation"
	var result := BattleArmy.new()
	DeploymentAbilities.for_army(result, army, _catalog(faction))
	assert_eq(_entry_named(result, "Formation ability").source, "Battle formation")


func test_for_army_ignores_formations_it_did_not_choose() -> void:
	var faction := _faction([] as Array[Warscroll])
	var formation := Kit.formation("Formation")
	formation.abilities = [BattleKit.ability("Formation ability", DEPLOY)] as Array[Ability]
	faction.battle_formations = [formation] as Array[BattleFormation]
	var result := BattleArmy.new()
	DeploymentAbilities.for_army(result, Kit.army(), _catalog(faction))
	assert_null(_entry_named(result, "Formation ability"))


func test_for_army_adds_warscroll_abilities_owned_by_their_unit() -> void:
	var ability := BattleKit.ability("Sneak", DEPLOY, "Set up in reserve.")
	var faction := _faction([_scroll_with(ability)] as Array[Warscroll])
	var army := Kit.army()
	army.auxiliary = [Kit.unit("u1", "grunt")] as Array[ArmyUnit]
	var catalog := _catalog(faction)
	var result := _battle_army(army, catalog)
	DeploymentAbilities.for_army(result, army, catalog)
	var entry := _entry_named(result, "Sneak")
	assert_same(entry.owner, result.units[0])
	assert_eq(entry.source, "Warscroll")


func test_for_army_adds_enhancements_owned_by_the_unit_that_has_them() -> void:
	var enhancement := BattleKit.ability("Enhanced", DEPLOY)
	var faction := _faction([Kit.warscroll("grunt"), Kit.warscroll("other")] as Array[Warscroll])
	faction.enhancement_tables = [Kit.table("Artefacts of Power", [enhancement] as Array[Ability])] as Array[EnhancementTable]
	var army := Kit.army()
	var holder := Kit.unit("u2", "grunt")
	holder.enhancements = {"Artefacts of Power": "Enhanced"}
	army.auxiliary = [Kit.unit("u1", "other"), holder] as Array[ArmyUnit]
	var catalog := _catalog(faction)
	var result := _battle_army(army, catalog)
	DeploymentAbilities.for_army(result, army, catalog)
	var entry := _entry_named(result, "Enhanced")
	assert_same(entry.owner, result.units[1])
	assert_eq(entry.source, "Enhancement")


func test_for_army_ties_a_regiment_of_renowns_abilities_to_its_regiment() -> void:
	var faction := _faction([] as Array[Warscroll])
	var renown := Kit.regiment_of_renown("Renowned", 0, [] as Array[RegimentUnit])
	renown.abilities = [BattleKit.ability("Renowned ability", DEPLOY)] as Array[Ability]
	var scroll := Kit.warscroll("hero")
	renown.warscrolls = [scroll] as Array[Warscroll]
	faction.regiments_of_renown = [renown] as Array[RegimentOfRenown]
	var army := Kit.army()
	army.regiments = [Kit.regiment("r1", [Kit.unit("u1", "unused")] as Array[ArmyUnit]),
			Kit.ror_regiment("r2", "Renowned", [Kit.unit("u2", "hero")] as Array[ArmyUnit])] as Array[ArmyRegiment]
	var catalog := _catalog(faction)
	var result := _battle_army(army, catalog)
	DeploymentAbilities.for_army(result, army, catalog)
	var entry := _entry_named(result, "Renowned ability")
	assert_same(entry.regiment, result.regiments[1])
	assert_eq(entry.source, "Regiment of Renown")
	assert_null(entry.owner)


func test_for_army_skips_a_regiment_of_renown_the_data_lacks() -> void:
	var army := Kit.army()
	army.regiments = [Kit.ror_regiment("r1", "Missing", [Kit.unit("u1", "hero")] as Array[ArmyUnit])] as Array[ArmyRegiment]
	var result := BattleArmy.new()
	result.regiments = [BattleRegiment.new()] as Array[BattleRegiment]
	DeploymentAbilities.for_army(result, army, _catalog(_faction([] as Array[Warscroll])))
	assert_eq(result.deployment_abilities.size(), DeploymentAbilities.MATCHED_PLAY_UNIVERSAL.size())


# for_spearhead

func _spearhead() -> Spearhead:
	var spearhead := Spearhead.new()
	spearhead.name = "Test"
	spearhead.battle_traits = [BattleKit.ability("Trait", DEPLOY)] as Array[Ability]
	spearhead.regiment_abilities = [BattleKit.ability("Chosen", DEPLOY), BattleKit.ability("Unchosen", DEPLOY)] as Array[Ability]
	spearhead.enhancements = [BattleKit.ability("Picked", DEPLOY), BattleKit.ability("Skipped", DEPLOY)] as Array[Ability]
	return spearhead


func _spearhead_army() -> BattleArmy:
	var result := BattleArmy.new()
	result.units.append(BattleKit.unit("General", 1))
	result.units.append(BattleKit.unit("Other", 2))
	return result


func _setup() -> BattleSetup:
	var setup := BattleSetup.new()
	setup.regiment_ability = "Chosen"
	setup.enhancement = "Picked"
	return setup


func test_for_spearhead_has_deploy_unit_only_from_the_universal_abilities() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead(result, _spearhead(), _setup(), null)
	assert_eq(result.deployment_abilities[0].name(), DeploymentAbility.DEPLOY_UNIT)
	assert_null(_entry_named(result, DeploymentAbility.DEPLOY_REGIMENT))
	assert_null(_entry_named(result, DeploymentAbility.DEPLOY_FACTION_TERRAIN))


func test_for_spearhead_includes_the_chosen_regiment_ability_only() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead(result, _spearhead(), _setup(), null)
	assert_not_null(_entry_named(result, "Chosen"))
	assert_null(_entry_named(result, "Unchosen"))


func test_for_spearhead_gives_the_chosen_enhancement_to_the_general() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead(result, _spearhead(), _setup(), null)
	assert_same(_entry_named(result, "Picked").owner, result.units[0])
	assert_null(_entry_named(result, "Skipped"))


func test_for_spearhead_includes_battle_traits() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead(result, _spearhead(), _setup(), null)
	assert_not_null(_entry_named(result, "Trait"))


func test_for_spearhead_without_a_setup_has_no_chosen_abilities() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead(result, _spearhead(), null, null)
	assert_null(_entry_named(result, "Chosen"))
	assert_null(_entry_named(result, "Picked"))


func test_for_spearhead_adds_unit_warscroll_abilities() -> void:
	var result := _spearhead_army()
	result.units[1].warscroll = _scroll_with(BattleKit.ability("Own", DEPLOY))
	DeploymentAbilities.for_spearhead(result, _spearhead(), _setup(), null)
	assert_same(_entry_named(result, "Own").owner, result.units[1])


# for_spearhead_choices

func test_for_spearhead_choices_includes_the_named_regiment_ability_only() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead_choices(result, _spearhead(), "Unchosen", "", null)
	assert_not_null(_entry_named(result, "Unchosen"))
	assert_null(_entry_named(result, "Chosen"))


func test_for_spearhead_choices_gives_the_named_enhancement_to_the_general() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead_choices(result, _spearhead(), "", "Skipped", null)
	assert_same(_entry_named(result, "Skipped").owner, result.units[0])
	assert_null(_entry_named(result, "Picked"))


func test_for_spearhead_choices_labels_the_sources() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead_choices(result, _spearhead(), "Chosen", "Picked", null)
	assert_eq(_entry_named(result, "Chosen").source, "Regiment ability")
	assert_eq(_entry_named(result, "Picked").source, "Enhancement")


func test_for_spearhead_choices_with_nothing_chosen_has_the_traits_and_deploy_unit() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead_choices(result, _spearhead(), "", "", null)
	assert_not_null(_entry_named(result, "Trait"))
	assert_not_null(_entry_named(result, DeploymentAbility.DEPLOY_UNIT))
	assert_null(_entry_named(result, "Chosen"))
	assert_null(_entry_named(result, "Picked"))


func test_for_spearhead_choices_with_unknown_names_adds_nothing_extra() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead_choices(result, _spearhead(), "Nope", "Nada", null)
	assert_eq(result.deployment_abilities.size(), 2)


func test_for_spearhead_choices_replaces_what_was_there() -> void:
	var result := _spearhead_army()
	DeploymentAbilities.for_spearhead_choices(result, _spearhead(), "Chosen", "Picked", null)
	DeploymentAbilities.for_spearhead_choices(result, _spearhead(), "Unchosen", "Skipped", null)
	assert_null(_entry_named(result, "Chosen"))
	assert_null(_entry_named(result, "Picked"))
	assert_not_null(_entry_named(result, "Unchosen"))
	assert_not_null(_entry_named(result, "Skipped"))


func test_for_spearhead_choices_adds_unit_warscroll_abilities() -> void:
	var result := _spearhead_army()
	result.units[1].warscroll = _scroll_with(BattleKit.ability("Own", DEPLOY))
	DeploymentAbilities.for_spearhead_choices(result, _spearhead(), "", "", null)
	assert_same(_entry_named(result, "Own").owner, result.units[1])


func test_for_spearhead_matches_for_spearhead_choices() -> void:
	var from_setup := _spearhead_army()
	var from_names := _spearhead_army()
	DeploymentAbilities.for_spearhead(from_setup, _spearhead(), _setup(), null)
	DeploymentAbilities.for_spearhead_choices(from_names, _spearhead(), "Chosen", "Picked", null)
	assert_eq(_names(from_setup.deployment_abilities), _names(from_names.deployment_abilities))
