class_name ArmyEditor
extends RefCounted
## Changes an [Army] the way the Forge builder does, keeping the builder's limits (regiment sizes,
## one Regiment of Renown, one enhancement of each type) unless the army overrides its constraints.

## Emitted after every change to [member army].
signal changed

var army: Army
var catalog: ArmyCatalog
var _next_id := 0


func _init(army_data: Army, army_catalog: ArmyCatalog) -> void:
	army = army_data
	catalog = army_catalog
	for regiment in army.regiments:
		_next_id = maxi(_next_id, _id_number(regiment.id))
	for unit in army.all_units():
		_next_id = maxi(_next_id, _id_number(unit.uid))


## A new army of [param catalog]'s faction, with 2 empty battle tactics slots. A Legends Army of
## Renown shows Legends units.
static func create_army(army_catalog: ArmyCatalog, army_of_renown := "", formation := "") -> Army:
	var army_data := Army.new()
	army_data.faction_id = army_catalog.faction.id
	army_data.army_of_renown = army_of_renown
	var renown := army_catalog.army_of_renown(army_of_renown)
	army_data.show_legends = renown != null and renown.legends
	army_data.formation = "" if not army_of_renown.is_empty() else formation
	army_data.name = "New %s Army" % (army_of_renown if not army_of_renown.is_empty() else army_catalog.faction.name)
	army_data.tactics = PackedStringArray(["", ""])
	return army_data


static func _id_number(id: String) -> int:
	return id.substr(1).to_int()


func _new_id(prefix: String) -> String:
	_next_id += 1
	return "%s%d" % [prefix, _next_id]


func _new_unit(warscroll_id: String, faction_id := "") -> ArmyUnit:
	var unit := ArmyUnit.new()
	unit.uid = _new_id("u")
	unit.warscroll_id = warscroll_id
	unit.faction_id = faction_id
	var warscroll := catalog.faction.get_warscroll(warscroll_id) if faction_id.is_empty() else null
	if warscroll:
		unit.weapon_options = WeaponOptions.defaults(warscroll)
	return unit


## A unit of the army's faction, or of another faction its Army of Renown includes.
func _army_unit(warscroll_id: String) -> ArmyUnit:
	var faction_id := catalog.included_faction_id(army, warscroll_id)
	if faction_id.is_empty():
		return _new_unit(warscroll_id)
	var unit := _new_unit(warscroll_id, faction_id)
	unit.weapon_options = WeaponOptions.defaults(catalog.find_warscroll(army, warscroll_id))
	return unit


## Whether another unit fits in [param regiment]: its leader's slot while it's empty, then up to
## its capacity besides its leader. A regiment whose leader was removed keeps the slot for
## [method add_leader].
func has_room(regiment: ArmyRegiment) -> bool:
	if regiment.is_regiment_of_renown():
		return false
	if army.override_constraints or regiment.units.is_empty():
		return true
	return regiment.followers().size() < ArmyValidator.regiment_capacity(regiment, army)


## Whether a unit of [param warscroll_id] leads a regiment it's first in: a Hero, or a unit the
## Army of Renown lets lead instead of one.
func _leads(warscroll_id: String) -> bool:
	var warscroll := catalog.find_warscroll(army, warscroll_id)
	return warscroll != null and catalog.can_lead(army, warscroll)


## Adds a regiment, led by [param leader_id]'s warscroll if given.
func add_regiment(leader_id := "") -> ArmyRegiment:
	var regiment := ArmyRegiment.new()
	regiment.id = _new_id("r")
	regiment.name = "Regiment %d" % (army.regiments.size() + 1)
	if not leader_id.is_empty():
		regiment.units.append(_army_unit(leader_id))
	army.regiments.append(regiment)
	changed.emit()
	return regiment


func remove_regiment(regiment_id: String) -> void:
	var regiment := army.find_regiment(regiment_id)
	if regiment == null:
		return
	if army.regiment_of(army.general_uid) == regiment:
		army.general_uid = ""
	army.regiments.erase(regiment)
	changed.emit()


func rename_regiment(regiment_id: String, regiment_name: String) -> void:
	var regiment := army.find_regiment(regiment_id)
	if regiment and not regiment_name.strip_edges().is_empty():
		regiment.name = regiment_name.strip_edges()
		changed.emit()


## Moves the regiment to [param index] in the army list.
func move_regiment(regiment_id: String, index: int) -> void:
	var regiment := army.find_regiment(regiment_id)
	if regiment == null:
		return
	var from := army.regiments.find(regiment)
	army.regiments.remove_at(from)
	army.regiments.insert(clampi(index - (1 if from < index else 0), 0, army.regiments.size()), regiment)
	changed.emit()


## Adds a unit of [param warscroll_id] to a regiment at [param index], or the end if it's -1, as
## its leader if it's empty. Returns null if the regiment is full.
func add_unit(regiment_id: String, warscroll_id: String, index := -1) -> ArmyUnit:
	var regiment := army.find_regiment(regiment_id)
	if regiment == null or not has_room(regiment):
		return null
	var unit := _army_unit(warscroll_id)
	_insert(regiment, unit, regiment.units.size() if index < 0 else index)
	changed.emit()
	return unit


## Fills the empty leader's slot of a regiment with a unit of [param warscroll_id], or adds its
## first unit. Returns null if it already has a leader.
func add_leader(regiment_id: String, warscroll_id: String) -> ArmyUnit:
	var regiment := army.find_regiment(regiment_id)
	if regiment == null or not (regiment.leaderless or regiment.units.is_empty()):
		return null
	var unit := _army_unit(warscroll_id)
	regiment.units.insert(0, unit)
	regiment.leaderless = false
	changed.emit()
	return unit


## Adds an auxiliary unit at [param index], or the end if it's -1.
func add_auxiliary(warscroll_id: String, index := -1) -> ArmyUnit:
	var unit := _army_unit(warscroll_id)
	army.auxiliary.insert(army.auxiliary.size() if index < 0 else clampi(index, 0, army.auxiliary.size()), unit)
	changed.emit()
	return unit


## Whether the army can include the Regiment of Renown: one its faction allows, if it has none yet,
## or any when it overrides its constraints.
func can_add_regiment_of_renown(regiment_name: String) -> bool:
	var renown := catalog.regiment_of_renown(regiment_name)
	if renown == null:
		return false
	return army.override_constraints or (renown in catalog.regiments_of_renown(army)
			and not army.regiments.any(func(r: ArmyRegiment) -> bool: return r.is_regiment_of_renown()))


## Adds the Regiment of Renown with one army unit per unit it lists. Returns null if the army can't
## include it, or already has one.
func add_regiment_of_renown(regiment_name: String) -> ArmyRegiment:
	if not can_add_regiment_of_renown(regiment_name):
		return null
	var renown := catalog.regiment_of_renown(regiment_name)
	var regiment := ArmyRegiment.new()
	regiment.id = _new_id("r")
	regiment.name = renown.name
	regiment.regiment_of_renown = renown.name
	for listed in renown.units:
		for i in listed.count:
			var unit := _new_unit(listed.warscroll_id, listed.faction_id)
			unit.label = listed.name if listed.count == 1 else ""
			regiment.units.append(unit)
	army.regiments.append(regiment)
	changed.emit()
	return regiment


func remove_unit(uid: String) -> void:
	var unit := army.find_unit(uid)
	if unit == null:
		return
	var regiment := army.regiment_of(uid)
	if regiment:
		_take_out(regiment, unit)
	else:
		army.auxiliary.erase(unit)
	if army.general_uid == uid:
		army.general_uid = ""
	changed.emit()


## Adds a copy of the unit after it, without its enhancements, as an army can't include the same
## enhancement twice. Returns null if its regiment is full.
func duplicate_unit(uid: String) -> ArmyUnit:
	var unit := army.find_unit(uid)
	var regiment := army.regiment_of(uid)
	if unit == null or (regiment and not has_room(regiment)) or (regiment and regiment.is_regiment_of_renown()):
		return null
	var copy := unit.duplicate(true) as ArmyUnit
	copy.uid = _new_id("u")
	copy.enhancements = {}
	if regiment:
		regiment.units.insert(regiment.units.find(unit) + 1, copy)
	else:
		army.auxiliary.insert(army.auxiliary.find(unit) + 1, copy)
	changed.emit()
	return copy


## Moves the unit to [param index] in another or the same regiment, or into the auxiliary units
## when [param regiment_id] is empty. Returns false if the target is full. Units in a Regiment of
## Renown stay in it.
func move_unit(uid: String, regiment_id: String, index: int) -> bool:
	var unit := army.find_unit(uid)
	var from := army.regiment_of(uid)
	var to := army.find_regiment(regiment_id) if not regiment_id.is_empty() else null
	if unit == null or (from and from.is_regiment_of_renown()) or (to and to.is_regiment_of_renown()):
		return false
	if not regiment_id.is_empty() and to == null:
		return false
	if to and to != from and not has_room(to):
		return false
	var source: Array[ArmyUnit] = from.units if from else army.auxiliary
	var at := source.find(unit)
	if from and from != to:
		_take_out(from, unit)
	else:
		source.remove_at(at)
	if from == to and at < index:
		index -= 1
	if to:
		_insert(to, unit, index)
	else:
		army.auxiliary.insert(clampi(index, 0, army.auxiliary.size()), unit)
	if army.general_uid == uid and (to == null or to.leader() != unit):
		army.general_uid = ""
	changed.emit()
	return true


## Where a unit placed at [param index] in [param regiment] goes: nothing goes before a Hero
## leader, or a unit the Army of Renown lets be the general instead of one.
func insertion_index(regiment: ArmyRegiment, index: int) -> int:
	if regiment.units.is_empty():
		return 0
	var leader := regiment.leader()
	if leader and _leads(leader.warscroll_id):
		index = maxi(index, 1)
	return clampi(index, 0, regiment.units.size())


## Takes [param unit] out of [param regiment]. Taking out its leader leaves the leader's slot
## empty rather than the next unit leading it.
func _take_out(regiment: ArmyRegiment, unit: ArmyUnit) -> void:
	if regiment.leader() == unit:
		regiment.leaderless = true
	regiment.units.erase(unit)
	if regiment.units.is_empty():
		regiment.leaderless = false


## Keeps a Hero leader first: a unit added to an empty regiment leads it, and nothing is placed
## before an existing Hero leader.
func _insert(regiment: ArmyRegiment, unit: ArmyUnit, index: int) -> void:
	regiment.units.insert(insertion_index(regiment, index), unit)


## Makes the unit the general, or clears the general if it already is. Only a regiment leader can
## be the general unless the army overrides its constraints.
func set_general(uid: String) -> void:
	if army.general_uid == uid:
		army.general_uid = ""
	else:
		var regiment := army.regiment_of(uid)
		if not army.override_constraints and (regiment == null or regiment.leader() == null or regiment.leader().uid != uid):
			return
		army.general_uid = uid
	changed.emit()


func set_label(uid: String, label: String) -> void:
	var unit := army.find_unit(uid)
	if unit:
		unit.label = label.strip_edges()
		changed.emit()


func set_reinforced(uid: String, reinforced: bool) -> void:
	var unit := army.find_unit(uid)
	var warscroll := catalog.warscroll(unit, army.regiment_of(uid)) if unit else null
	if warscroll == null or unit.reinforced == reinforced or (reinforced and not warscroll.can_reinforce):
		return
	WeaponOptions.set_reinforced(unit, warscroll, reinforced)
	changed.emit()


func set_weapon_option(uid: String, option_name: String, count: int) -> void:
	var unit := army.find_unit(uid)
	var warscroll := catalog.warscroll(unit, army.regiment_of(uid)) if unit else null
	if warscroll == null:
		return
	for option in warscroll.weapon_options:
		if option.name == option_name:
			unit.weapon_options[option_name] = clampi(count, 0, WeaponOptions.cap(option, warscroll, unit.reinforced))
			changed.emit()
			return


## Gives the unit [param enhancement_name] of [param type], or removes its enhancement of that type
## when empty. As an army can usually only include 1 enhancement of each type, any other unit's
## enhancement of that type is removed. Where the type allows more (3 First Circle Titles), only
## another unit with the same enhancement loses it, as an army can't include it twice.
func set_enhancement(uid: String, type: String, enhancement_name: String) -> void:
	var unit := army.find_unit(uid)
	if unit == null:
		return
	if enhancement_name.is_empty():
		unit.enhancements.erase(type)
	else:
		if not army.override_constraints:
			var single := catalog.enhancement_limit(army, type) == 1
			for other in army.all_units():
				if single or other.enhancements.get(type, "") == enhancement_name:
					other.enhancements.erase(type)
		unit.enhancements[type] = enhancement_name
	changed.emit()


## Sets battle tactics card [param slot] (0 or 1). A card already in the other slot moves here.
func set_tactic(slot: int, card_name: String) -> void:
	while army.tactics.size() < ArmyValidator.MAX_TACTICS:
		army.tactics.append("")
	var other := army.tactics.find(card_name)
	if not card_name.is_empty() and other >= 0 and other != slot:
		army.tactics[other] = ""
	army.tactics[slot] = card_name
	changed.emit()


## Sets the spell, prayer or manifestation lore ([param kind]), or clears it when empty.
func set_lore(kind: String, lore_name: String) -> void:
	match kind:
		"spell":
			army.spell_lore = lore_name
		"prayer":
			army.prayer_lore = lore_name
		"manifestation":
			army.manifestation_lore = lore_name
		_:
			return
	changed.emit()


func set_formation(formation_name: String) -> void:
	army.formation = formation_name
	changed.emit()


func set_faction_terrain(warscroll_id: String) -> void:
	army.faction_terrain = warscroll_id
	changed.emit()


## Switches to an Army of Renown, or back to the faction's rules when empty. Choices the new rules
## don't offer are cleared: the battle formation, lores, enhancements and, if the Army of Renown
## forbids it, the faction terrain. A Legends Army of Renown turns on showing Legends units.
func set_army_of_renown(army_name: String) -> void:
	army.army_of_renown = army_name
	var renown := catalog.army_of_renown(army_name)
	if renown and renown.legends:
		army.show_legends = true
	if not army_name.is_empty():
		army.formation = ""
	for kind: String in ["spell", "prayer", "manifestation"]:
		var picked: String = army.get("%s_lore" % kind)
		if not picked.is_empty() and catalog.lore(army, kind, picked) == null:
			army.set("%s_lore" % kind, "")
	for unit in army.all_units():
		for type: String in unit.enhancements.keys():
			if catalog.enhancement(army, type, unit.enhancements[type]) == null:
				unit.enhancements.erase(type)
	var army_roster := catalog.roster(army)
	if army_roster and not army_roster.faction_terrain:
		army.faction_terrain = ""
	changed.emit()


func set_army_name(army_name: String) -> void:
	if not army_name.strip_edges().is_empty():
		army.name = army_name.strip_edges()
		changed.emit()


func set_points_limit(points: int) -> void:
	army.points_limit = maxi(points, 0)
	changed.emit()


func set_show_legends(show: bool) -> void:
	army.show_legends = show
	changed.emit()


func set_override_constraints(override: bool) -> void:
	army.override_constraints = override
	changed.emit()
