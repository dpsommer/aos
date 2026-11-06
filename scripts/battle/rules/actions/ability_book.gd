class_name AbilityBook
extends RefCounted
## Gathers every ability an army has in a battle with its effect data: the core rules it uses, the
## battleplan's or battlepack's, its army's, and each unit's. The army's own rules have no timing
## logic here: [GameController] picks from these by [AbilityTiming].

## Core abilities that only the Magic rules use. Spearhead doesn't (Spearhead sidebar, page 49).
const MAGIC_ONLY: PackedStringArray = ["Unbind", "Banish Manifestation", "Sacred Rites", "Magical Intervention", "Activate Place of Power"]


static func build(game: GameController, army: BattleArmy) -> Array[AbilityEntry]:
	var entries: Array[AbilityEntry] = []
	var battle := game.battle
	if game.core:
		for ability in game.core.abilities:
			if _core_applies(ability, game):
				_add(entries, ability, "core:%s" % ability.name, army, null, "Core")
	if battle.battlepack:
		for ability in battle.battlepack.abilities:
			_add(entries, ability, "pack:%s/%s" % [battle.battlepack.name, ability.name], army, null, "Battlepack")
	if battle.battleplan:
		for ability in battle.battleplan.abilities:
			_add(entries, ability, "battleplan:%s/%s" % [battle.battleplan.name, ability.name], army, null, "Battleplan")
	if army.spearhead:
		_add_spearhead(entries, army)
	else:
		_add_forge_army(entries, army)
	return entries


static func _core_applies(ability: Ability, game: GameController) -> bool:
	if not game.rules.uses_commands() and ability.type == "command":
		return false
	if game.battle.is_spearhead() and (ability.name in MAGIC_ONLY or ability.type in ["spell", "prayer"]):
		return false
	return true


## The effect data key of [param ability], a battle trait of [param spearhead].
static func spearhead_trait_key(spearhead: Spearhead, ability: Ability) -> String:
	return "spearhead:%s/trait/%s" % [spearhead.name, ability.name]


static func _add_spearhead(entries: Array[AbilityEntry], army: BattleArmy) -> void:
	var spearhead := army.spearhead
	var space := "spearhead:%s" % spearhead.name
	for ability in spearhead.battle_traits:
		_add(entries, ability, spearhead_trait_key(spearhead, ability), army, null, "Battle trait")
	for ability in spearhead.regiment_abilities:
		if ability.name == army.regiment_ability:
			_add(entries, ability, "%s/regiment/%s" % [space, ability.name], army, null, "Regiment ability")
	var general: BattleUnit = army.units[0] if not army.units.is_empty() else null
	for ability in spearhead.enhancements:
		if ability.name == army.enhancement:
			_add(entries, ability, "%s/enhancement/%s" % [space, ability.name], army, general, "Enhancement")
	for unit in army.units:
		if unit.warscroll == null:
			continue
		for ability in unit.warscroll.abilities:
			_add(entries, ability, "%s/%s/%s" % [space, unit.warscroll.id, ability.name], army, unit, "Warscroll")


static func _add_forge_army(entries: Array[AbilityEntry], army: BattleArmy) -> void:
	var space := faction_space(army)
	for ability in army.army_abilities:
		_add(entries, ability, "%s:trait/%s" % [space, ability.name], army, null, "Battle trait")
	for ability in army.lore_abilities:
		_add(entries, ability, "%s:lore/%s" % [space, ability.name], army, null, "Lore")
	for unit in army.units:
		for ability in unit.enhancements:
			_add(entries, ability, "%s:enhancement/%s" % [space, ability.name], army, unit, "Enhancement")
		if unit.warscroll:
			for ability in unit.warscroll.abilities:
				_add(entries, ability, "%s:warscroll/%s/%s" % [space, unit.warscroll.id, ability.name], army, unit, "Warscroll")


## The namespace of a Forge army's effect data: its faction's id.
static func faction_space(army: BattleArmy) -> String:
	return army.faction_name.to_lower().replace(" ", "_").replace("'", "")


static func _add(entries: Array[AbilityEntry], ability: Ability, key: String, army: BattleArmy, owner_unit: BattleUnit, source: String) -> void:
	entries.append(make_entry(ability, key, army, owner_unit, source))


static func make_entry(ability: Ability, key: String, army: BattleArmy, owner_unit: BattleUnit, source: String) -> AbilityEntry:
	var entry := AbilityEntry.new()
	entry.ability = ability
	entry.key = key
	entry.army = army
	entry.owner_unit = owner_unit
	entry.source = source
	entry.descriptor = EffectCatalog.descriptor(key, ability)
	entry.timing = AbilityTiming.parse(ability.timing)
	return entry
