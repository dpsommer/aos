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


## Returns a copy of the faction names for [param alliance], in display order.
static func factions_for(alliance: GrandAlliance.Type) -> PackedStringArray:
	return PackedStringArray(_FACTIONS[alliance])
