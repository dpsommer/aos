class_name RulesSearch
extends RefCounted
## Matches the Forge info pane's search query against warscrolls, rules, battle tactics cards and
## Regiments of Renown. Every word of the query must appear somewhere in an entry's text, ignoring
## case.


## The query's words, lowercased.
static func words(query: String) -> PackedStringArray:
	return query.to_lower().split(" ", false)


## Whether [param text] contains every one of [param query_words]. An empty query matches anything.
static func matches(text: String, query_words: PackedStringArray) -> bool:
	var lower := text.to_lower()
	for word in query_words:
		if not word in lower:
			return false
	return true


static func warscroll_text(warscroll: Warscroll) -> String:
	var parts := PackedStringArray([warscroll.name, warscroll.source, " ".join(warscroll.keywords)])
	for weapon in warscroll.ranged_weapons + warscroll.melee_weapons:
		parts.append(weapon.name)
	for ability in warscroll.abilities:
		parts.append(ability.name)
	return " ".join(parts)


static func ability_text(ability: Ability) -> String:
	return " ".join([ability.name, ability.timing, ability.declare, ability.effect, ability.text, " ".join(ability.keywords)])


static func tactic_text(card: BattleTacticCard) -> String:
	var parts := PackedStringArray([card.name, card.text])
	for tactic in card.tactics:
		parts.append_array([tactic.name, tactic.kind, tactic.condition])
	return " ".join(parts)


## Includes the names of the factions its units come from, and their Grand Alliances, so "Kharadron"
## and "Order" find Drekki's Privateers.
static func regiment_text(regiment: RegimentOfRenown) -> String:
	var parts := PackedStringArray([regiment.name, regiment.text])
	var factions := PackedStringArray()
	for unit in regiment.units:
		parts.append(unit.name)
		var faction_name := FactionCatalog.name_for_id(unit.faction_id)
		if not faction_name.is_empty() and not faction_name in factions:
			factions.append(faction_name)
	var alliances := PackedStringArray()
	for faction_name in factions:
		var alliance := FactionCatalog.alliance_of(faction_name)
		if alliance != -1 and not GrandAlliance.display_name(alliance) in alliances:
			alliances.append(GrandAlliance.display_name(alliance))
	parts.append_array(factions)
	parts.append_array(alliances)
	for ability in regiment.abilities:
		parts.append(ability_text(ability))
	return " ".join(parts)
