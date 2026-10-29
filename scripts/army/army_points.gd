class_name ArmyPoints
extends RefCounted
## Points costs of an army and its units.


## A unit's warscroll points (doubled when reinforced) plus its enhancements. Units in a Regiment of
## Renown cost nothing on their own; the regiment has the cost.
static func unit_points(unit: ArmyUnit, regiment: ArmyRegiment, army: Army, catalog: ArmyCatalog) -> int:
	if regiment and regiment.is_regiment_of_renown():
		return 0
	var warscroll := catalog.warscroll(unit, regiment)
	var points := warscroll.points * (2 if unit.reinforced else 1) if warscroll else 0
	return points + enhancement_points(unit, regiment, army, catalog)


## The part of [method unit_points] that comes from the unit's enhancements.
static func enhancement_points(unit: ArmyUnit, regiment: ArmyRegiment, army: Army, catalog: ArmyCatalog) -> int:
	if regiment and regiment.is_regiment_of_renown():
		return 0
	var points := 0
	for type: String in unit.enhancements:
		var entry := catalog.enhancement(army, type, unit.enhancements[type])
		points += entry.points if entry else 0
	return points


static func regiment_points(regiment: ArmyRegiment, army: Army, catalog: ArmyCatalog) -> int:
	if regiment.is_regiment_of_renown():
		var renown := catalog.regiment_of_renown(regiment.regiment_of_renown)
		return renown.points if renown else 0
	var points := 0
	for unit in regiment.units:
		points += unit_points(unit, regiment, army, catalog)
	return points


## Lores, the battle formation and faction terrain.
static func army_rule_points(army: Army, catalog: ArmyCatalog) -> int:
	var points := 0
	for kind: String in ["spell", "prayer", "manifestation"]:
		var lore := catalog.lore(army, kind, army.lore_name(kind))
		points += lore.points if lore else 0
	var formation := catalog.battle_formation(army, army.formation)
	points += formation.points if formation else 0
	var terrain := catalog.faction.get_warscroll(army.faction_terrain) if not army.faction_terrain.is_empty() else null
	points += terrain.points if terrain else 0
	return points


static func total(army: Army, catalog: ArmyCatalog) -> int:
	var points := army_rule_points(army, catalog)
	for regiment in army.regiments:
		points += regiment_points(regiment, army, catalog)
	for unit in army.auxiliary:
		points += unit_points(unit, null, army, catalog)
	return points
