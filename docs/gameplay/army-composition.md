# Army composition

How the Forge checks an army, in `ArmyValidator` (`scripts/army/army_validator.gd`). The rules come from the General's Handbook 2026-27: Army Composition (Core Rules 3.1-3.5 and 4.1-4.2), the Scourge of Aqshy and Ghyran warscroll rules, and Battle Tactics 2026-27. An Army of Renown's own roster comes from its `roster` data (see [Faction data](../technical/faction-data.md#builder-rules)).

Validation returns **problems**, which make the army invalid, and **warnings**, which are legal choices that are probably mistakes. With "Override army constraints" on, nothing is checked and the builder doesn't enforce its limits either.

## Problems

**Rule** | **Check**
-- | --
Regiments (3.1) | At least 1 and at most 5 regiments, not counting a Regiment of Renown. Each is led by a HERO, with up to 3 other units, or 4 in the general's regiment (3.2).
Regiment options (3.1) | Every unit after the leader fits one of the leader's regiment options, within each option's limit ("0-1"), and every required unit is included. A HERO fits an option only if the option names it or the role in its notes ("This HERO can join an eligible regiment as a …").
General (3.2, 3.5) | A general is picked, leads a regiment and isn't in a Regiment of Renown. If the army has a WARMASTER, the general is one.
Unique | No UNIQUE unit is included twice.
Scourge warscrolls | Every unit with the same name uses the same version of its warscroll: printed, Scourge of Aqshy or Scourge of Ghyran.
Regiments of Renown (3.5) | At most 1, and only ones the faction can include and its Army of Renown allows.
Enhancements (4.1) | At most 1 enhancement of each type in the army. None on UNIQUE units or units in a Regiment of Renown. Heroic traits and artefacts of power only on HEROES, and a table for certain units (its `units`, e.g. Great Endrinworks for Skyvessels) only on those units. Each must still be in the army's tables.
Lores (4.2) | Each picked lore is available to the army. Manifestation lores include the universal ones.
Battle formation | One is picked when the faction has any, unless the army is an Army of Renown.
Faction terrain | Still in the data, and allowed by the Army of Renown.
Battle tactics | At least 1 and at most 2 battle tactics cards from the battlepack, with no card picked twice.
Army of Renown roster | A unit with an `army_of_renown` (Allies of the Free Cities' allied units, the Iron March's Cogforts, Legion of the First Prince's daemons) is only in that Army of Renown. A unit from another faction (outside a Regiment of Renown) is one the Army of Renown includes, e.g. Kharadron Overlords in a Throngankor Alliance; switching Army of Renown can leave some that aren't. Every unit matches a roster entry and isn't one the roster excludes ("You cannot include Morathi-Khaine"). Units only a limited entry allows are limited to its maximum ("0-1", or "0-1 Gaunt Summoner or Gaunt Summoner on Disc of Tzeentch" counting both together) or to 1 for each unit it counts ("for each Conqueror Cogfort"). Required units are included, and the general is the one the roster names, which overrides the WARMASTER rule (Grombrindal leads a Duardin Ascendant army that includes an Auric Runefather). Units the roster allows gain the Army of Renown's keyword (MAGNATE’S CREW) and the roster's keywords, e.g. WARMASTER, which regiment options and roster leaders can name. A Big Waaagh! has as many regiments led by IRONJAWZ Heroes as by KRULEBOYZ Heroes (each Hero's own regiment options keep its units to its own faction); Kragnos, who has both keywords, can include the units of either faction's version of his warscroll but not both, and counts for that faction, or for whichever is short when his regiment has no units yet. Leaders also have the regiment options the roster gives them (Gorechosen Champions: "Any Bloodbound Warmongers can be added to a regiment led by a GORECHOSEN CHAMPIONS unit"). The Magnate's Crew can have an Arkanaut Ironclad as its general instead of a Hero, unless it includes Brokk Grungsson: as the general it can lead a regiment of any of the army's units and gains the HERO keyword, so it can take Heroic Traits and Artefacts of Power; otherwise it can't lead one. Some Armies of Renown let other non-Hero units lead regiments as if they were Heroes, without gaining the keyword: a Matriarch's Mob or Stomper Tribe Mancrusher Gargant can lead a regiment of LITTLE units. No manifestation lore if the roster forbids manifestations.
Points | The total is within the points limit.
Missing data | Every unit's warscroll is still in the faction data.

## Warnings

- Fewer than 2 battle tactics cards.
- A WIZARD with no spell lore, a PRIEST with no prayer lore, or either with no manifestation lore.

## Not checked yet

- Unit notes such as "You can include 1 unit of this type for each Lord-Celestant on Dracoth in your army" and the Skryre regiment limits.
- Legends units, enhancements and lores, which aren't legal in Matched Play, including those from a Scourge the battlepack doesn't use (Scourge of Ghyran); see [Scourge rules](../technical/faction-data.md#scourge-rules).
