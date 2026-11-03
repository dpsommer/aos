class_name DeploymentAbilities
extends RefCounted
## Gathers the abilities each army can use in the deployment phase (see [DeploymentAbility]): the
## universal ones, then its battle traits, battle formation, enhancements, Regiments of Renown and
## warscrolls. See docs/gameplay/deployment.md.

## The universal abilities a Matched Play army uses, in step order.
const MATCHED_PLAY_UNIVERSAL: PackedStringArray = [
	DeploymentAbility.DEPLOY_FACTION_TERRAIN, DeploymentAbility.DEPLOY_UNIT, DeploymentAbility.DEPLOY_REGIMENT]
## A Spearhead sets its units up one at a time, without regiments or faction terrain (Spearhead:
## Deployment).
const SPEARHEAD_UNIVERSAL: PackedStringArray = [DeploymentAbility.DEPLOY_UNIT]


## The universal abilities [param names], from [param core] where it has them, else with just
## their names and keywords.
static func universal(names: PackedStringArray, core: CoreRules) -> Array[DeploymentAbility]:
	var result: Array[DeploymentAbility] = []
	for ability_name in names:
		var ability := core.get_ability(ability_name) if core else null
		if ability == null:
			ability = Ability.new()
			ability.name = ability_name
			ability.timing = DeploymentAbility.TIMING
			ability.keywords = PackedStringArray(["DEPLOY TERRAIN" if ability_name == DeploymentAbility.DEPLOY_FACTION_TERRAIN else "DEPLOY"])
		result.append(DeploymentAbility.create(ability, DeploymentAbility.UNIVERSAL))
	return result


## Fills in [param result]'s deployment abilities for the Forge [param army], whose units and
## regiments it already has in the army's order.
static func for_army(result: BattleArmy, army: Army, catalog: ArmyCatalog) -> void:
	var list := universal(MATCHED_PLAY_UNIVERSAL, catalog.core)
	var renown := catalog.army_of_renown(army.army_of_renown) if not army.army_of_renown.is_empty() else null
	if renown:
		_add(list, renown.battle_traits, "Army of Renown")
	else:
		_add(list, catalog.faction.battle_traits, "Battle trait")
	var formation := catalog.battle_formation(army, army.formation) if not army.formation.is_empty() else null
	if formation:
		_add(list, formation.abilities, "Battle formation")
	var units := _units_by_army_unit(result, army)
	for regiment_index in army.regiments.size():
		var regiment := army.regiments[regiment_index]
		if regiment.is_regiment_of_renown() and regiment_index < result.regiments.size():
			var renown_regiment := catalog.regiment_of_renown(regiment.regiment_of_renown)
			if renown_regiment:
				_add(list, renown_regiment.abilities, "Regiment of Renown", null, result.regiments[regiment_index])
	for army_unit: ArmyUnit in units:
		var unit: BattleUnit = units[army_unit]
		for type: String in army_unit.enhancements:
			var enhancement := catalog.enhancement(army, type, army_unit.enhancements[type])
			if enhancement:
				_add(list, [enhancement] as Array[Ability], "Enhancement", unit)
	for unit in result.units:
		if unit.warscroll:
			_add(list, unit.warscroll.abilities, "Warscroll", unit)
	result.deployment_abilities = list


## Fills in [param result]'s deployment abilities for [param spearhead], with the regiment
## ability and enhancement chosen in [param setup] (none if it's null).
static func for_spearhead(result: BattleArmy, spearhead: Spearhead, setup: BattleSetup, core: CoreRules) -> void:
	for_spearhead_choices(result, spearhead, setup.regiment_ability if setup else "", setup.enhancement if setup else "", core)


## Fills in [param result]'s deployment abilities for [param spearhead], with the regiment ability
## called [param regiment_ability] and the enhancement called [param enhancement] (either empty
## for none yet).
static func for_spearhead_choices(result: BattleArmy, spearhead: Spearhead, regiment_ability: String, enhancement: String,
		core: CoreRules) -> void:
	var list := universal(SPEARHEAD_UNIVERSAL, core)
	_add(list, spearhead.battle_traits, "Battle trait")
	for ability in spearhead.regiment_abilities:
		if ability.name == regiment_ability:
			_add(list, [ability] as Array[Ability], "Regiment ability")
	var general: BattleUnit = result.units[0] if not result.units.is_empty() else null
	for ability in spearhead.enhancements:
		if ability.name == enhancement:
			_add(list, [ability] as Array[Ability], "Enhancement", general)
	for unit in result.units:
		if unit.warscroll:
			_add(list, unit.warscroll.abilities, "Warscroll", unit)
	result.deployment_abilities = list


static func _add(list: Array[DeploymentAbility], abilities: Array[Ability], source: String,
		owner: BattleUnit = null, regiment: BattleRegiment = null) -> void:
	for ability in abilities:
		if DeploymentAbility.is_deployment(ability):
			list.append(DeploymentAbility.create(ability, source, owner, regiment))


## Each of the Forge army's units by the battle unit made from it, assuming [param result]'s units
## were made in the army's order (regiments, then auxiliary units).
static func _units_by_army_unit(result: BattleArmy, army: Army) -> Dictionary:
	var map := {}
	var army_units: Array[ArmyUnit] = []
	for regiment in army.regiments:
		army_units.append_array(regiment.units)
	army_units.append_array(army.auxiliary)
	for i in mini(army_units.size(), result.units.size()):
		map[army_units[i]] = result.units[i]
	return map
