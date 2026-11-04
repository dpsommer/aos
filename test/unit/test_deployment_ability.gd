extends GutTest
## Unit tests for deployment abilities (scripts/battle/deployment/deployment_ability.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


func _entry(keywords: PackedStringArray, effect := "", source := "Warscroll", ability_name := "Ability") -> DeploymentAbility:
	return BattleKit.deploy_entry(BattleKit.ability(ability_name, keywords, effect), source)


func _reserve_name(effect: String) -> String:
	return _entry(PackedStringArray(["DEPLOY"]), effect).reserve_name()


# is_deployment

func test_deploy_keyword_marks_a_deployment_ability() -> void:
	assert_true(DeploymentAbility.is_deployment(BattleKit.ability("A", PackedStringArray(["DEPLOY"]))))


func test_deploy_terrain_keyword_marks_a_deployment_ability() -> void:
	assert_true(DeploymentAbility.is_deployment(BattleKit.ability("A", PackedStringArray(["DEPLOY TERRAIN"]))))


func test_deployment_phase_timing_marks_a_deployment_ability() -> void:
	var ability := BattleKit.ability("A", PackedStringArray())
	ability.timing = DeploymentAbility.TIMING
	assert_true(DeploymentAbility.is_deployment(ability))


func test_other_abilities_are_not_deployment_abilities() -> void:
	var ability := BattleKit.ability("A", PackedStringArray(["MOVE"]))
	ability.timing = "Your Hero Phase"
	assert_false(DeploymentAbility.is_deployment(ability))


func test_null_is_not_a_deployment_ability() -> void:
	assert_false(DeploymentAbility.is_deployment(null))


# step

func test_deploy_terrain_keyword_is_the_terrain_step() -> void:
	assert_eq(_entry(PackedStringArray(["DEPLOY TERRAIN"])).step(), DeploymentAbility.Step.TERRAIN)


func test_deploy_keyword_is_the_units_step() -> void:
	assert_eq(_entry(PackedStringArray(["DEPLOY"])).step(), DeploymentAbility.Step.UNITS)


func test_no_keyword_is_the_other_step() -> void:
	assert_eq(_entry(PackedStringArray()).step(), DeploymentAbility.Step.OTHER)


# kind

func test_universal_deploy_unit_is_deploy_unit() -> void:
	var entry := _entry(PackedStringArray(["DEPLOY"]), "", DeploymentAbility.UNIVERSAL, DeploymentAbility.DEPLOY_UNIT)
	assert_eq(entry.kind(), DeploymentAbility.Kind.DEPLOY_UNIT)


func test_universal_deploy_regiment_is_deploy_regiment() -> void:
	var entry := _entry(PackedStringArray(["DEPLOY"]), "", DeploymentAbility.UNIVERSAL, DeploymentAbility.DEPLOY_REGIMENT)
	assert_eq(entry.kind(), DeploymentAbility.Kind.DEPLOY_REGIMENT)


func test_universal_deploy_faction_terrain_is_deploy_terrain() -> void:
	var entry := _entry(PackedStringArray(["DEPLOY TERRAIN"]), "", DeploymentAbility.UNIVERSAL, DeploymentAbility.DEPLOY_FACTION_TERRAIN)
	assert_eq(entry.kind(), DeploymentAbility.Kind.DEPLOY_TERRAIN)


func test_an_ability_named_like_a_universal_one_is_not_universal_unless_the_source_says_so() -> void:
	var entry := _entry(PackedStringArray(["DEPLOY"]), "", "Warscroll", DeploymentAbility.DEPLOY_UNIT)
	assert_eq(entry.kind(), DeploymentAbility.Kind.UNSUPPORTED)


func test_deploy_ability_that_sets_up_in_reserve_is_a_reserve() -> void:
	assert_eq(_entry(PackedStringArray(["DEPLOY"]), "Set up this unit in reserve.").kind(), DeploymentAbility.Kind.RESERVE)


func test_reserve_detection_ignores_case() -> void:
	assert_eq(_entry(PackedStringArray(["DEPLOY"]), "Set up this unit IN RESERVE.").kind(), DeploymentAbility.Kind.RESERVE)


func test_reserve_needs_the_deploy_keyword() -> void:
	assert_ne(_entry(PackedStringArray(), "Set up this unit in reserve.").kind(), DeploymentAbility.Kind.RESERVE)


func test_deploy_ability_with_another_effect_is_unsupported() -> void:
	assert_eq(_entry(PackedStringArray(["DEPLOY"]), "Do something else.").kind(), DeploymentAbility.Kind.UNSUPPORTED)


func test_deploy_terrain_ability_that_is_not_universal_is_unsupported() -> void:
	assert_eq(_entry(PackedStringArray(["DEPLOY TERRAIN"]), "Set up in reserve.").kind(), DeploymentAbility.Kind.UNSUPPORTED)


func test_deployment_phase_ability_is_recorded() -> void:
	var ability := BattleKit.ability("A", PackedStringArray(), "Something.")
	ability.timing = DeploymentAbility.TIMING
	assert_eq(BattleKit.deploy_entry(ability).kind(), DeploymentAbility.Kind.RECORD)


# reserve_name

func test_reserve_name_follows_in_reserve() -> void:
	assert_eq(_reserve_name("Set up all of those units in reserve in the clouds."), "in the clouds")


func test_reserve_name_stops_at_a_following_clause() -> void:
	assert_eq(_reserve_name("Set up this unit in reserve stalking the prey or set up this unit on the battlefield."), "stalking the prey")


func test_reserve_name_is_the_default_when_the_effect_does_not_name_one() -> void:
	assert_eq(_reserve_name("Set up this unit in reserve."), DeploymentAbility.DEFAULT_RESERVE)


func test_reserve_name_is_the_default_when_a_clause_follows() -> void:
	assert_eq(_reserve_name("Set up this unit in reserve and cannot be targeted by attacks."), DeploymentAbility.DEFAULT_RESERVE)


func test_reserve_name_is_the_default_before_a_dash() -> void:
	assert_eq(_reserve_name("Set up this unit in reserve – even your army."), DeploymentAbility.DEFAULT_RESERVE)


func test_reserve_name_is_the_default_before_to() -> void:
	assert_eq(_reserve_name("Set up this unit in reserve to arrive later."), DeploymentAbility.DEFAULT_RESERVE)


func test_reserve_name_is_the_default_without_in_reserve() -> void:
	assert_eq(_reserve_name("Nothing about that."), DeploymentAbility.DEFAULT_RESERVE)


# frequency

func test_once_per_battle_is_detected() -> void:
	var entry := BattleKit.deploy_entry(BattleKit.ability("A", PackedStringArray(["DEPLOY"]), "", "", "Once Per Battle"))
	assert_true(entry.is_once_per_battle())


func test_once_per_battle_army_is_per_army_too() -> void:
	var entry := BattleKit.deploy_entry(BattleKit.ability("A", PackedStringArray(["DEPLOY"]), "", "", "Once Per Battle (Army)"))
	assert_true(entry.is_once_per_battle())
	assert_true(entry.is_once_per_army())


func test_once_per_battle_without_army_is_not_per_army() -> void:
	var entry := BattleKit.deploy_entry(BattleKit.ability("A", PackedStringArray(["DEPLOY"]), "", "", "Once Per Battle"))
	assert_false(entry.is_once_per_army())


func test_no_frequency_is_not_limited() -> void:
	assert_false(_entry(PackedStringArray(["DEPLOY"])).is_once_per_battle())


# targets_owner

func test_ability_saying_this_unit_targets_its_owner() -> void:
	var ability := BattleKit.ability("A", PackedStringArray(["DEPLOY"]), "", "You must pick this unit.")
	assert_true(BattleKit.deploy_entry(ability, "Warscroll", BattleKit.unit("U", 1)).targets_owner())


func test_ability_with_no_declare_targets_its_owner() -> void:
	var ability := BattleKit.ability("A")
	assert_true(BattleKit.deploy_entry(ability, "Warscroll", BattleKit.unit("U", 1)).targets_owner())


func test_ability_picking_friendly_units_does_not_target_its_owner() -> void:
	var ability := BattleKit.ability("A", PackedStringArray(["DEPLOY"]), "", "Pick up to 2 friendly units.")
	assert_false(BattleKit.deploy_entry(ability, "Warscroll", BattleKit.unit("U", 1)).targets_owner())


func test_ability_without_an_owner_does_not_target_it() -> void:
	assert_false(_entry(PackedStringArray(["DEPLOY"])).targets_owner())


# mirrored

func test_mirrored_maps_the_owner_and_regiment_to_the_copies() -> void:
	var owner_unit := BattleKit.unit("U", 1)
	var unit_copy := BattleKit.unit("U", 1)
	var members: Array[BattleUnit] = [owner_unit]
	var regiment := BattleKit.regiment("R", members)
	var regiment_copy := BattleKit.regiment("R", [unit_copy] as Array[BattleUnit])
	var entry := BattleKit.deploy_entry(BattleKit.ability("A"), "Regiment of Renown", owner_unit, regiment)
	var copy := entry.mirrored({owner_unit: unit_copy}, {regiment: regiment_copy})
	assert_same(copy.owner, unit_copy)
	assert_same(copy.regiment, regiment_copy)


func test_mirrored_keeps_the_ability_and_source() -> void:
	var entry := BattleKit.deploy_entry(BattleKit.ability("A"), "Battle trait")
	var copy := entry.mirrored({}, {})
	assert_same(copy.ability, entry.ability)
	assert_eq(copy.source, "Battle trait")


func test_mirrored_without_an_owner_has_none() -> void:
	assert_null(BattleKit.deploy_entry(BattleKit.ability("A")).mirrored({}, {}).owner)


# label

func test_label_names_the_owner() -> void:
	var entry := BattleKit.deploy_entry(BattleKit.ability("Hidden Hunters"), "Warscroll", BattleKit.unit("Saurus", 1))
	assert_eq(entry.label(), "Hidden Hunters (Saurus)")


func test_label_is_the_name_without_an_owner() -> void:
	assert_eq(BattleKit.deploy_entry(BattleKit.ability("Deploy Unit")).label(), "Deploy Unit")
