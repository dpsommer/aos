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
	var table := enhancement_table(army, type, enhancement_name)
	if table:
		for entry in table.entries:
			if entry.name == enhancement_name:
				return entry
	return null


## The table of [param type] holding the enhancement called [param enhancement_name], or null.
func enhancement_table(army: Army, type: String, enhancement_name: String) -> EnhancementTable:
	for table in enhancement_tables(army):
		if table.name == type:
			for entry in table.entries:
				if entry.name == enhancement_name:
					return table
	return null


## Whether a unit with [param warscroll] can be given enhancements from [param table]: one of the
## table's [member EnhancementTable.units] if it lists any, and a Hero for Heroic Traits and
## Artefacts of Power. Unique units and units in Regiments of Renown are checked separately.
static func can_take(table: EnhancementTable, warscroll: Warscroll) -> bool:
	if not table.units.is_empty():
		return warscroll.name in table.units
	return not table.name in ArmyValidator.HERO_ENHANCEMENTS or warscroll.has_keyword("HERO")


## The tables of [param type] to offer a unit with [param warscroll]: those it [method can_take],
## leaving out Legends tables unless the army shows Legends. The table holding [param selected], the
## unit's current enhancement of the type, is always included, so it can still be seen and cleared.
func enhancement_choices(army: Army, warscroll: Warscroll, type: String, selected := "") -> Array[EnhancementTable]:
	var current: EnhancementTable = enhancement_table(army, type, selected) if not selected.is_empty() else null
	var result: Array[EnhancementTable] = []
	for table in enhancement_tables(army):
		if table.name != type:
			continue
		if table == current or (can_take(table, warscroll) and (army.show_legends or not table.legends)):
			result.append(table)
	return result


## Lores of [param kind] ("spell", "prayer" or "manifestation") the army can pick. Manifestation
## lores include the universal ones, unless the Army of Renown forbids manifestations.
func lores(army: Army, kind: String) -> Array[Lore]:
	var renown := army_of_renown(army.army_of_renown)
	var result: Array[Lore] = []
	if kind == "manifestation" and renown and renown.roster and not renown.roster.manifestations:
		return result
	for lore in (renown.lores if renown else faction.lores):
		if lore.kind == kind:
			result.append(lore)
	if kind == "manifestation" and core:
		result.append_array(core.manifestation_lores)
	return result


## The lores of [param kind] to offer: [method lores] without Legends lores unless the army shows
## Legends, though the picked lore, [param selected], is always included.
func lore_choices(army: Army, kind: String, selected := "") -> Array[Lore]:
	var result: Array[Lore] = []
	for candidate in lores(army, kind):
		if army.show_legends or not candidate.legends or candidate.name == selected:
			result.append(candidate)
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


## The manifestations [param ability] sets up, from its [member Ability.summons]: the faction's
## own, the core rules' universal ones, or another faction's, which a shared Army of Renown such
## as Legions of Nagash or a Regiment of Renown can summon. Ids that name no manifestation are
## skipped.
func summoned(ability: Ability) -> Array[Warscroll]:
	var result: Array[Warscroll] = []
	for warscroll_id in ability.summons:
		var found := faction.get_warscroll(warscroll_id)
		if (not found or not found.has_keyword("MANIFESTATION")) and core:
			found = core.get_manifestation(warscroll_id)
		if not found:
			var home_id := FactionCatalog.manifestation_faction(warscroll_id)
			var home: Faction = _load_faction.call(home_id) if not home_id.is_empty() else null
			found = home.get_warscroll(warscroll_id) if home else null
		if found and found.has_keyword("MANIFESTATION"):
			result.append(found)
	return result


func battle_tactic_card(card_name: String) -> BattleTacticCard:
	return core.battlepack.get_battle_tactic_card(card_name) if core and core.battlepack else null
