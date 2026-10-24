class_name FactionCatalog
extends RefCounted
## Faction names grouped by Grand Alliance.
##
## Placeholder until factions are defined as resources with their own units and rules.

const _FACTIONS := {
	GrandAlliance.Type.ORDER: [
		"Cities of Sigmar",
		"Daughters of Khaine",
		"Fyreslayers",
		"Idoneth Deepkin",
		"Kharadron Overlords",
		"Lumineth Realm-lords",
		"Seraphon",
		"Stormcast Eternals",
		"Sylvaneth",
	],
	GrandAlliance.Type.CHAOS: [
		"Blades of Khorne",
		"Disciples of Tzeentch",
		"Hedonites of Slaanesh",
		"Helsmiths of Hashut",
		"Maggotkin of Nurgle",
		"Skaven",
		"Slaves to Darkness",
	],
	GrandAlliance.Type.DEATH: [
		"Flesh-eater Courts",
		"Nighthaunt",
		"Ossiarch Bonereapers",
		"Soulblight Gravelords",
	],
	GrandAlliance.Type.DESTRUCTION: [
		"Gloomspite Gitz",
		"Ironjawz",
		"Kruleboyz",
		"Ogor Mawtribes",
		"Sons of Behemat",
	],
}


## Data directories for factions whose rules have been added. See docs/technical/faction-data.md.
const _DATA_DIRS := {
	"Kharadron Overlords": "res://data/factions/kharadron_overlords",
}

static var _loaded := {}


## Returns a copy of the faction names for [param alliance], in display order.
static func factions_for(alliance: GrandAlliance.Type) -> PackedStringArray:
	return PackedStringArray(_FACTIONS[alliance])


## Whether [param faction] has rules data and can be opened.
static func is_available(faction: String) -> bool:
	return _DATA_DIRS.has(faction)


## Loads [param faction]'s data, caching it. Returns null and reports errors if it can't be loaded.
static func load_faction(faction: String) -> Faction:
	if _loaded.has(faction):
		return _loaded[faction]
	if not is_available(faction):
		push_error("No data for faction '%s'" % faction)
		return null
	var loader := FactionLoader.new()
	var data := loader.load_faction(_DATA_DIRS[faction])
	for error in loader.errors:
		push_error(error)
	if data:
		_loaded[faction] = data
	return data
