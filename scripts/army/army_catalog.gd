class_name ArmyCatalog
extends RefCounted
## Looks up the rules an army's choices refer to: its faction's warscrolls, enhancements, lores and
## Regiments of Renown, or its Army of Renown's, plus the core rules' manifestation lores and battle
## tactics.

var faction: Faction
var core: CoreRules
## Takes a faction id and returns that [Faction], for units in Regiments of Renown.
var _load_faction: Callable


## [param load_faction] defaults to loading from [FactionCatalog].
func _init(faction_data: Faction, core_rules: CoreRules, load_faction := Callable()) -> void:
	faction = faction_data
	core = core_rules
	_load_faction = load_faction if load_faction.is_valid() else _from_catalog


static func _from_catalog(faction_id: String) -> Faction:
	var faction_name := FactionCatalog.name_for_id(faction_id)
	return FactionCatalog.load_faction(faction_name) if not faction_name.is_empty() else null


func army_of_renown(army_name: String) -> ArmyOfRenown:
	for army in faction.armies_of_renown:
		if army.name == army_name:
			return army
	return null


## The roster restrictions of [param army]'s Army of Renown, or null if it has none.
func roster(army: Army) -> ArmyRoster:
	var renown := army_of_renown(army.army_of_renown)
	return renown.roster if renown else null


## An Army of Renown uses its own enhancements and lores instead of the faction's.
func enhancement_tables(army: Army) -> Array[EnhancementTable]:
	var renown := army_of_renown(army.army_of_renown)
	return renown.enhancement_tables if renown else faction.enhancement_tables


## Enhancement types in table order, e.g. ["Heroic Traits", "Artefacts of Power"].
func enhancement_types(army: Army) -> PackedStringArray:
	var types := PackedStringArray()
	for table in enhancement_tables(army):
		if not table.name in types:
			types.append(table.name)
	return types


## The enhancement called [param enhancement_name] in a table of [param type], or null.
func enhancement(army: Army, type: String, enhancement_name: String) -> Ability:
	for table in enhancement_tables(army):
		if table.name == type:
			for entry in table.entries:
				if entry.name == enhancement_name:
					return entry
	return null


## Lores of [param kind] ("spell", "prayer" or "manifestation") the army can pick. Manifestation
## lores include the universal ones.
func lores(army: Army, kind: String) -> Array[Lore]:
	var renown := army_of_renown(army.army_of_renown)
	var result: Array[Lore] = []
	for lore in (renown.lores if renown else faction.lores):
		if lore.kind == kind:
			result.append(lore)
	if kind == "manifestation" and core:
		result.append_array(core.manifestation_lores)
	return result


func lore(army: Army, kind: String, lore_name: String) -> Lore:
	for candidate in lores(army, kind):
		if candidate.name == lore_name:
			return candidate
	return null


## Armies of Renown have no battle formations.
func battle_formations(army: Army) -> Array[BattleFormation]:
	var none: Array[BattleFormation] = []
	return none if army_of_renown(army.army_of_renown) else faction.battle_formations


func battle_formation(army: Army, formation_name: String) -> BattleFormation:
	for formation in battle_formations(army):
		if formation.name == formation_name:
			return formation
	return null


## Warscrolls that can be units in the army: not manifestations or faction terrain.
func unit_warscrolls() -> Array[Warscroll]:
	var result: Array[Warscroll] = []
	for warscroll in faction.warscrolls:
		if not warscroll.has_keyword("MANIFESTATION") and not warscroll.has_keyword("FACTION TERRAIN"):
			result.append(warscroll)
	return result


func terrain_warscrolls() -> Array[Warscroll]:
	var result: Array[Warscroll] = []
	for warscroll in faction.warscrolls:
		if warscroll.has_keyword("FACTION TERRAIN"):
			result.append(warscroll)
	return result


func regiment_of_renown(regiment_name: String) -> RegimentOfRenown:
	for regiment in faction.regiments_of_renown:
		if regiment.name == regiment_name:
			return regiment
	return null


## Regiments of Renown the army can include: none if its Army of Renown forbids them.
func regiments_of_renown(army: Army) -> Array[RegimentOfRenown]:
	var none: Array[RegimentOfRenown] = []
	var army_roster := roster(army)
	return none if army_roster and not army_roster.regiments_of_renown else faction.regiments_of_renown


## The warscroll of [param unit] in [param regiment] (null for an auxiliary unit), or null if the
## data no longer has it.
func warscroll(unit: ArmyUnit, regiment: ArmyRegiment = null) -> Warscroll:
	if regiment and regiment.is_regiment_of_renown():
		if not unit.faction_id.is_empty():
			var home: Faction = _load_faction.call(unit.faction_id)
			return home.get_warscroll(unit.warscroll_id) if home else null
		var renown := regiment_of_renown(regiment.regiment_of_renown)
		return renown.get_warscroll(unit.warscroll_id) if renown else null
	return faction.get_warscroll(unit.warscroll_id)


func battle_tactic_card(card_name: String) -> BattleTacticCard:
	return core.battlepack.get_battle_tactic_card(card_name) if core and core.battlepack else null
