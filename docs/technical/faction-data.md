# Faction data

Each faction's rules live as JSON in `data/factions/<faction_id>/`. `FactionLoader` (`scripts/data/faction/faction_loader.gd`) reads them into typed `Resource` classes in `scripts/data/` (see [Project layout](layout.md)). `FactionCatalog` maps faction names to their data directories; a faction without one shows as "Coming soon" in the Forge.

## Files

**File** | **Required** | **Contents**
-- | -- | --
`faction.json` | Yes | `id`, `name`, `grand_alliance` (`order`, `chaos`, `death`, `destruction`), `legends` (the whole faction has moved to Legends), `battle_traits`, `battle_formations`, `enhancement_tables`, `lores`
`warscrolls.json` | No | `{"warscrolls": [...]}`: matched play warscrolls with battle profiles
`armies_of_renown.json` | No | `{"armies_of_renown": [...]}`: name, source, `legends`, text (description and roster), battle traits, enhancement tables, lores
`spearhead.json` | No | `{"spearheads": [...]}`: army list (`general`, `units`), battle traits, regiment abilities, enhancements, and the Spearhead versions of warscrolls
`path_to_glory.json` | No | `{"sections": [...]}`: titled text sections, plus any warscrolls (e.g. the Anvil of Apotheosis hero)

### Shared warscrolls and Armies of Renown

A warscroll or Army of Renown that several factions use, such as Nagash, Kragnos, Grombrindal, the Orruk manifestations (Foot of Gork, Gork-Roara, Morkspit Marsh) or the Armies of Renown Big Waaagh!, Legions of Nagash and The Duardin Ascendant, is stored once in `data/shared/warscrolls.json` (`{"warscrolls": [...]}`) or `data/shared/armies_of_renown.json` (`{"armies_of_renown": [...]}`), in the same format as a faction's. Each faction lists a reference in its own file instead, which the loader resolves:

- An Army of Renown reference is `{"shared": "<name>"}`.
- A warscroll reference is `{"shared": "<id>", ...}`. Its other fields are what that faction's version has of its own: keywords are added to the shared profile's (e.g. `"keywords": ["NIGHTHAUNT"]` on Nagash, Supreme Lord of the Undead), each ability replaces the shared ability of the same name or is added (Flesh-eater Courts' Nagash has its own Invocation of Nagash and Utter Contempt), and any other field, such as `regiment_options` or `points`, replaces the shared value.

Fix a typo in a shared entry once, in `tools/faction_import/shared.json`, not in each faction's overrides.

## Schema

**Class** | **Fields** (required in bold)
-- | --
`Ability` | **`name`**, `type` (`active`, `passive`, `command`, `spell` or `prayer`; see [Ability types](#ability-types)), `category` (icon: offensive, movement, special…), `timing`, `colour` (see [Ability colours](#ability-colours)), `frequency`, `declare`, `used_by` (reactions), `effect`, `text`, `keywords`, `options` (`[{name, text}]`), `points`, `command_points` (commands), `casting_value` (spells), `chanting_value` (prayers), `source`, `summons` (see [Summons](#summons))
`Weapon` | **`name`**, `range` (inches, 0 for melee), **`attacks`**, **`hit`**, **`wound`**, `rend`, **`damage`**, `abilities`. Attacks and damage are strings because they can be dice, e.g. `"2D6"` A weapon that skips the attack sequence (Wahapedia prints "See below", e.g. the Spearhead Bladelords' Perfect Strike) has `hit`, `wound` and `rend` of 0 and `damage` of `"-"`
`Warscroll` | **`id`**, **`name`**, `source`, `legends`, `army_of_renown` (the only Army of Renown that can include the unit, e.g. "The Iron March" for its Immolator Cogfort; set through the faction's overrides file), **`points`**, **`unit_size`** (both optional in Spearhead and Path to Glory), `base_size`, `can_reinforce`, `regiment_options`, `notes`, **`move`** (string: inches, or dice such as `"D6+3"` for units that roll their move; `"0"` if the unit can't move), **`health`**, **`save`**, `ward`, **`control`**, `banishment` (manifestations), `ranged_weapons`, `melee_weapons`, `abilities`, `keywords`, `composition`, `weapon_options` (see [Builder rules](#builder-rules))
`WeaponOption` | **`name`** (the weapon models can take), **`replaces`** (the weapon it replaces), **`max`** and **`per`** (`max` models per `per` models in the unit; both required unless `choice`), `choice` (every model can take it), `note` (further restrictions, e.g. "The champion cannot replace their weapon")
`ArmyOfRenown` | **`name`**, `source`, `legends`, `keyword` (the keyword its units gain, e.g. "MAGNATE’S CREW"; the importer takes it from the text's "All units in your army gain the … keyword", and an override can give it where the text doesn't, as for the Armies of Renown whose text is only a BSData roster list), `text` (description and roster as written), `roster` (see [Builder rules](#builder-rules)), `battle_traits`, `enhancement_tables`, `lores`
`ArmyRoster` | `entries` (`RosterEntry` list: every unit in the army must match one), `included_units` (`RosterInclusion` list: other factions' units the army can draw from as well as its own), `regiment_options` (`RosterRegimentOptions` list: regiment options the army's leaders gain as well as their own), `non_hero_general` (`{"unit", "unless"}`: a unit that can be the general instead of a Hero, gaining the HERO keyword, unless the army includes one of the `unless` units, as The Magnate's Crew's Arkanaut Ironclad can without Brokk Grungsson; only as the general can it lead a regiment, with the options `regiment_options` gives it ("Any MAGNATE’S CREW", with `heroes`)), `non_hero_leaders` (unit names or keywords, matched like a `RosterRegimentOptions`' `leaders`: units that can lead regiments as if they were Heroes without gaining the HERO keyword, as Matriarch's Mob and Stomper Tribe Mancrusher Gargants can; their options come from `regiment_options` ("Any LITTLE")), `regiments_of_renown`, `faction_terrain` and `manifestations` (whether the army can include them, `manifestations` meaning a manifestation lore; default true), `excluded_units` (warscroll names the army can't include even if an entry matches them, e.g. Morathi-Khaine and the Shadow Queen in the Croneseer's Pariahs), `paired_leaders` (2 keywords, e.g. `["IRONJAWZ", "KRULEBOYZ"]` for Big Waaagh!: the army needs as many regiments led by Heroes with the first as by Heroes with the second. A Hero with both, Kragnos, can use the regiment options of its warscroll in any faction `included_units` includes whole, but not mix units of both keywords, and counts for the keyword its units have)
`RosterEntry` | `unit` (a warscroll name), `one_of` (warscroll names, any of which matches; `max`, `required` and `general` count them together, so "0-1 Gaunt Summoner or Gaunt Summoner on Disc of Tzeentch" is `{"one_of": [...], "max": 1}`), or `keywords` and `not_keywords` (a unit with all of the first and none of the second; `WIZARD` matches `WIZARD (2)`), plus `per` (unit names or keywords: one such unit for each unit in the army matching any of them, where `"HERO MONSTER"` needs both keywords), `max` (at most this many such units, e.g. "0-1"; with neither, any number), `required` (the army must include it), `general` (it must be the general), `gains_keywords` (e.g. `WARMASTER`)
`RosterRegimentOptions` | `leaders` (unit names or keywords, matched like a `RosterEntry`'s `per` and including the keywords units gain from the Army of Renown, e.g. `"GORECHOSEN CHAMPIONS"` or `"SCIONS OF NULAHMIA HERO"`; absent for every leader), **`options`** (regiment options as warscrolls write them, e.g. `"Any Bloodbound Warmonger"`; Heroes are matched by name or by the role their notes give them, so `"Any Pyrozealot"` lets the Pyrofane Fusil-Major join), `heroes` (Heroes with the options' keywords can join too, as an Endrinmaster with Dirigible Suit can join the Magnate's Crew Ironclad's regiment through "Any MAGNATE’S CREW units")
`RosterInclusion` | **`faction`** (a faction id, e.g. `kharadron_overlords`), `units` (names of its warscrolls to include; absent for all its units, as for the Throngankor Alliance's Kharadron Overlords, Big Waaagh!'s Ironjawz and Kruleboyz, or Legions of Nagash's four Death factions). The army's own faction is skipped, so a shared Army of Renown can list every faction it's for. Included units are offered in the builder, saved with their `faction`, and still have to match the roster's `entries`
`BattleFormation` | **`name`**, `points`, `abilities`
`EnhancementTable` | **`name`** (type, e.g. "Heroic Traits"), `group` (e.g. "Lords of the Sky-fleets"), `source`, `units` (names of the only warscrolls that can be given its enhancements, e.g. the Skyvessels for Great Endrinworks; absent when the table has no restriction of its own, though Heroic Traits and Artefacts of Power still need a HERO), `max` (how many of its enhancements an army can include, from BSData's roster-wide `max` constraint on the group, e.g. 3 for the Swords of Chaos' First Circle Titles; absent for the usual 1), `entries`
`Lore` | **`name`**, `kind` (spell, prayer, manifestation), `points` (always written in `faction.json`, usually 0), `source`, `entries`
`RegimentOfRenown` | **`name`**, `source`, `legends`, **`points`**, `factions` (ids of the factions whose armies can include it), `text` (rules and notes for the whole regiment, e.g. a keyword its units gain), `units` (`[{count, name, faction, warscroll, notes}]`, see below), `abilities`, `warscrolls` (units the regiment defines itself)
`RegimentUnit` | **`count`**, **`name`**, `faction` (the home faction's id; empty for a unit in the regiment's own `warscrolls`), **`warscroll`** (the warscroll's id there), `notes` (which size or model, e.g. "10 models", "the Aelsling")
`Spearhead` | **`name`**, `text`, **`general`**, `units` (`[{count, name, notes}]`, names match the Spearhead's own warscrolls), `battle_traits`, `regiment_abilities`, `enhancements`, `warscrolls`
`RulesSection` | **`name`**, `text`, `warscrolls`

### Ability types

`schema.ability` sets every ability's `type` from its own fields, in this order: a `timing` of "Passive" is `passive`; a `casting_value` or SPELL keyword is `spell`; a `chanting_value` or PRAYER keyword is `prayer`; a `command_points` cost is `command`; anything else, including reactions and abilities that spend a faction resource (Blades of Khorne's Blood Tithe, Disciples of Tzeentch's fate points), is `active`. BSData's profile types say the same for all but a few profiles it mislabels (Ironjawz's 'Tireless Warmaker' is "Activated" but Passive), so they aren't used.

### Ability colours

An ability's `colour` is the colour of its box on its warscroll: `black`, `yellow`, `grey`, `blue`, `orange`, `red`, `purple` or `green`. It comes from the `Color` attribute of BSData's ability profiles (`bsdata.colour()`), which spells grey both ways and has a few typos ("Yelllow", "Orance"); those are normalised, and values that aren't colours (a few profiles have a category such as "Movement", or nothing) are dropped. It mostly follows the timing, but not always: passive abilities, for example, take the colour of the phase they affect, and Battle Damaged is black. Wahapedia-only abilities (Spearheads, Path to Glory, and abilities swapped in by `replace_with_wahapedia`) take Wahapedia's colour, from the `bgcolor` of the ability's header (`wahapedia.HEADER_COLOUR`). A Spearhead ability's colour can differ from its matched play version's, as its timing can (the Khainite Shadow Coven's 'Consecrated Revulsion' is a yellow Hero Phase ability, where the warscroll's is a green passive). The diff report lists colours BSData and Wahapedia disagree on. Abilities without a colour (the core rules and battleplans) are coloured from their timing in the game (see [Ability cards](../design/abilities.md)).

A command's `command_points` is its cost: BSData's "Ability (Command)" profiles have it as a Cost characteristic, and Wahapedia shows it in the ability's top-right corner, which the parser reads for Wahapedia-only abilities such as Spearheads'. The diff report compares the two. Wahapedia marks Disciples of Tzeentch's 'Vision of Defiant Supremacy' as a 1 CP command where BSData has an activated ability; BSData's is kept until the battletome settles it.

Characteristics such as `save`, `hit` and `wound` store the x of an x+ roll. `source` names the expansion a rule comes from (e.g. "Scourge of Aqshy"); it's empty for battletome rules. Path to Glory is stored as text because its content is too varied to model usefully yet.

### Scourge rules

Each General's Handbook comes with a Scourge expansion of seasonal rules: alternative warscrolls, enhancement tables and lores, marked by their `source` ("Scourge of Ghyran" for the General's Handbook 2025-26, "Scourge of Aqshy" for 2026-27). The data keeps that marker and never writes `legends` for Scourge content. Instead the battlepack names its Scourge (`scourge` in `data/core/battlepack.json`), `FactionCatalog` passes it to `FactionLoader.scourge`, and the loader sets `legends` on every warscroll, enhancement table and lore from any other Scourge. So with the General's Handbook 2026-27, Scourge of Ghyran content is Legends (hidden in the Forge unless Legends are shown) and Scourge of Aqshy content is current. Supporting another handbook edition only means loading factions with that edition's Scourge.

The loader rejects the whole faction, collecting every problem in `errors`, if a file isn't valid JSON, a required field is missing, a field has the wrong type, or a reference names no shared entry.

### Summons

An ability that sets up manifestations, such as a summoning spell, Jacobus Vyne's Summon Wisper or the Incarnate of the Deep's Grasping Tendrils, lists their warscroll ids in `summons`. "Summon Horror of the Necropolis" lists all three it can pick from. `ArmyCatalog.summoned()` looks each id up in the faction's warscrolls, then the universal manifestations in `data/core/`, then other factions' (`FactionCatalog.manifestation_faction()`), as a shared Army of Renown such as Legions of Nagash summons Nighthaunt, Soulblight Gravelords, Flesh-eater Courts and Ossiarch Bonereapers manifestations.

An ability can also set up a unit that an army can't include on its own, such as the Zontari Endrin Dock's Release the Auto-Endrins (`auto_endrin`). `FactionLoader` marks a faction's warscroll (not a manifestation) that any of its abilities summons as `Warscroll.summoned`. `ArmyCatalog.unit_warscrolls()` leaves it out, and `summoned()` finds it among the faction's own warscrolls.

`build.py`, `build_core.py` and `build_regiments.py` set it with `link_summons()` after the overrides: an ability with the SUMMON keyword, or whose rules "set up" something, summons each manifestation its rules name (its own name counts only as "Summon <manifestation>"). It also links the faction's summoned units: warscrolls with no points that aren't manifestations or faction terrain (`is_summoned_unit()`). It looks in the faction's and the universal manifestations first, then in other factions' committed data. A Regiment of Renown looks in its own units first (the Sigil Convocation's spell summons its three Lumineth manifestations), then in the universal and every faction's manifestations. A `fields` override that sets `summons` (an empty list to unlink) replaces the linking for that ability. Kharadron Overlords' Market Dominance, which only changes the roll for setting up a replacement Auto-Endrin, is unlinked this way. The integration tests check that every `summons` id names a manifestation or a summoned unit and that every manifestation is summoned by something.

### Builder rules

The army builder needs two rules that the sources only give as prose: the wargear choices in a warscroll's `composition` ("1/5 models can replace their Warhammer with a Grandhammer"), and an Army of Renown's roster options in its `text`. These are transcribed by hand into `weapon_options` and `roster` through the faction's overrides file (`"fields": {"<warscroll id>": {"weapon_options": [...]}, "<Army of Renown name>": {"roster": {...}}}`). Shared Armies of Renown take their `roster` in `shared.json`'s `fields`. Only Stormcast Eternals has `weapon_options` so far; every Army of Renown has a `roster`. A warscroll without `weapon_options` has no wargear choices in the builder, and an Army of Renown without a `roster` doesn't have its roster checked. Some roster rules have no field and aren't checked; see [Army composition](../gameplay/army-composition.md#not-checked-yet). Roster lines naming another faction's units (Throngankor Alliance's Kharadron Overlords, Ironsunz's Tyrant and Gluttons) need that faction in `included_units`.

## Sources

The core rules' abilities and the universal manifestation lores are in `data/core/`; see [Core rules data](core-rules-data.md).

Faction data is built by `tools/faction_import/` from two sources:

- **[BSData](https://github.com/BSData/age-of-sigmar-4th) is the primary source.** It provides warscrolls (stats, weapons, abilities, keywords, base size, unit size), points, reinforcement, battle traits, battle formations, enhancements, spell and prayer lores, and the rules of each Army of Renown. Where BSData and Wahapedia disagree, BSData's value is used.
- **[Wahapedia](https://wahapedia.ru/aos4/) fills the gaps.** BSData has no Spearhead data, Path to Glory prose, regiment options, unit notes, unit composition text or Army of Renown descriptions, so these come from Wahapedia's faction and unit pages. Wahapedia is also the reference for the build's diff report, and its book order is used to order traits, formations and enhancements.

**Khazalite Holds is built from BSData alone**, from BSData's `khazalite-holds` branch, as its battletome isn't released and Wahapedia doesn't have it yet. It has no Spearhead, Path to Glory, regiment options, unit notes or composition text, and its Armies of Renown have their roster as text. Don't check it against Wahapedia or the notebooks below until the battletome is out; then rebuild it with Wahapedia from BSData's `main` branch.

The "AoS Rules" NotebookLM notebook (`a30c0d6a-8127-4eab-b97e-e457c97a65fc`), which holds the battletome and General's Handbook, is useful for settling disagreements the diff report raises.

**Legends warscrolls** (those with `legends`) are checked against the "AoS Legends" NotebookLM notebook (`69365d24-6043-4353-bb04-2b0d3ecca253`), which is the source of truth for them and wins over both BSData and Wahapedia. For a Legends unit the notebook doesn't have, Wahapedia's values win over BSData's. Record any corrections in the faction's overrides file.

## Adding a faction

The import tool is in `tools/faction_import/` (Godot ignores `tools/`). It needs Python 3 with `requirements.txt` installed, ideally in a virtualenv outside the repo, and `git`.

BSData is read from a local shallow clone of the repository at `tools/bsdata/`, which is gitignored. `build.py` clones it the first time it runs; pass `--update-bsdata` to pull the latest catalogues, or `--bsdata <dir>` to use a checkout elsewhere. The report's first line names the BSData commit used.

**Module** | **Role**
-- | --
`fetch.py` | Downloads the Wahapedia faction and unit pages
`bsdata.py` | Manages the BSData checkout and reads the catalogues a faction needs (game system, `Lores.cat`, `<Faction>.cat`, its library and any library it links (Ironjawz and Kruleboyz share "Orruk Warclans - Library"), another faction's library an Army of Renown links for its roster (Khazalite Holds' Throngankor Alliance has Kharadron Overlords units), every `<Faction> - <Army of Renown>.cat` and the shared catalogues they link to): resolves links across files, converts BSData markup (`**^^Keyword^^**` → `KEYWORD`), maps profiles to warscrolls and abilities
`wahapedia.py` | Parses the Wahapedia pages
`merge.py` | Combines the two, adds Wahapedia-only content, matches names (including misspellings such as "Hobgrotz"/"Hobgrot") and produces the diff report
`schema.py` | Writes the canonical JSON shape
`shared.py` | Moves the warscrolls and Armies of Renown listed in `shared.json` to `data/shared/` and writes references to them
`build.py` | Runs the steps above, applies overrides and writes the five files

1. Download the Wahapedia pages into an empty directory outside the repo:
   ```sh
   python -I tools/faction_import/fetch.py helsmiths-of-hashut <download dir>
   ```
   Wahapedia links without a page of their own (such as the Path to Glory hero) are skipped with a warning. Only units the faction page links are downloaded: Beasts of Chaos' page leaves out eight of its Legends units (Chaos Gargant, Chimera, Herdstone and others), which its unit pages link, so download any unit the report lists as "only in BSData" from `https://wahapedia.ru/aos4/factions/<slug>/<Unit-Name>` into `<download dir>/units/` and rebuild.

   For a faction Wahapedia doesn't have yet, skip this step and pass `-` as the download directory in the next one, to build from BSData alone. The report then only lists shared entry differences. To build from a BSData branch, clone it outside `tools/bsdata/` and pass it with `--bsdata`, e.g. for Khazalite Holds:
   ```sh
   git clone --depth 1 --branch khazalite-holds https://github.com/BSData/age-of-sigmar-4th.git <bsdata dir>
   python -I tools/faction_import/build.py - data/factions/khazalite_holds khazalite_holds "Khazalite Holds" --bsdata <bsdata dir>
   ```
2. Build the data and keep the report:
   ```sh
   python -I tools/faction_import/build.py <download dir> data/factions/<id> <id> "<BSData faction name>" \
       [--overrides tools/faction_import/overrides/<id>.json] [--update-bsdata] > report.txt
   ```
3. Read the report. It lists every field where BSData and Wahapedia disagree, names matched by similarity, and items only one source has. BSData wins by default. When BSData is wrong, add an override and rebuild. Override files are JSON:
   - `replace_with_wahapedia`: `{"<BSData ability name>": "<Wahapedia ability name>"}`. Uses Wahapedia's version of an ability where BSData has the wrong rule, e.g. Taar's Grand Forgehost's "Masterful Daemonworks". Applied before merging, so the replacement is ordered and compared like everything else Use `"<warscroll id or Army of Renown name> > <ability name>"` when a name alone is ambiguous, e.g. Zainthar Kai's "Explosive Fury", which is really "Cursed Heritage" and shares its name with a Champions of the Arena trait.
   - `warscroll_names`: `{"<name>": "<name to use>"}`. Renames a warscroll everywhere and updates its id.
   - `army_names`: `{"<BSData name>": "<name to use>"}`. Renames an Army of Renown before merging, so it pairs with Wahapedia's, e.g. BSData's "New Summercourt" is Wahapedia's "The Knights of New Summercourt".
   - `armies_of_renown_from`: `["<BSData catalogue name>"]`. Reads other factions' Army of Renown catalogues (named without `.cat`) as the faction's own, for an Army of Renown a rules update has moved to the faction before BSData has. The [Rules Updates](https://assets.warhammer-community.com/eng_28-10_aos_core_rules_and_key_downloads_rules_updates-aghvsvstmk-u8wyh173fe.pdf) (October 2026) move Lofnir Drothkeepers and The Duardin Ascendant to Khazalite Holds, which reads `"Fyreslayers - Lofnir Drothkeepers"` and `"Fyreslayers - The Duardin Ascendant [LEGENDS]"`.
   - `remove_armies_of_renown`: `["<Army of Renown name>"]`. Drops one of the faction's own Armies of Renown before merging, e.g. The Duardin Ascendant from Fyreslayers. Fyreslayers keep their own Lofnir Drothkeepers, as the rules update tells Faction Pack: Fyreslayers players to ignore its Khazalite Holds changes.
   - `wahapedia_warscroll_names`: `{"<Wahapedia name>": "<BSData name>"}`. Renames a Wahapedia unit before merging, so it pairs with BSData's when the names are too different to match, e.g. Wahapedia's "Monsta-killaz" is BSData's "Kruleboyz Monsta-killaz".
   - `faction`: `{"<field>": <value>}`. Sets fields of the faction itself after merging, e.g. `{"legends": true}` for Fyreslayers, which are being folded into Khazalite Holds, Beasts of Chaos and Bonesplitterz; BSData doesn't mark a whole faction as Legends. A Legends faction's unit notes drop Wahapedia's "This unit will move to Warhammer Legends on …" notice, since the move has happened.
   - `fields`: `{"<target>": {"<field>": <value>}}`. Replaces fields after merging, e.g. a casting value, a missing keyword or a misspelt weapon name. A target is a warscroll id or name, an Army of Renown name (e.g. to set `legends`), an ability name, or a weapon name. Use `"<owner> > <weapon or ability name>"` when a name alone is ambiguous, e.g. Thundrik's Profiteers have both a weapon and an ability called "Aethermatic Anatomiser", and "Summon Chalice of Ushoran" is in two Flesh-eater Courts Armies of Renown. An owner is a warscroll id, an Army of Renown name, or a faction enhancement table or lore name, written `"<name> (<source>)"` when several share a name (Fyreslayers have a "Vulkyn Gifts" lore from both Scourge of Ghyran and Scourge of Aqshy).
   - `path_to_glory`: `{"<section name>": {"<text>": "<replacement>"}}`. Replaces text in a Path to Glory section, which is stored as text, e.g. an erratum Wahapedia lists but hasn't applied to the text (Flesh-eater Courts' "Powerful Maw" timing). Each text must appear in its section exactly once.

   The report lists differences before overrides are applied, so overridden fields still appear in it.

   `build.py` stops if an override matches nothing, so stale overrides get noticed.
   If the faction has a warscroll or Army of Renown another faction also has (e.g. a Death faction's Nagash), list it in `tools/faction_import/shared.json` and rebuild; see [Shared entries](#shared-entries).
4. Add the name → directory entry to `_DATA_DIRS` in `scripts/data/faction/faction_catalog.gd`. If the faction is Legends, also add it to `_LEGENDS`, which the Forge uses to label it without loading its data; `test_faction_data.gd` checks it agrees with `faction.json`.
5. Rerun `build_regiments.py` so the Regiments of Renown the faction can include list its id and any regiment with its units can find their warscrolls; see [Regiments of Renown](#regiments-of-renown).
6. Run the tool's tests and the game's tests. `test/integration/test_faction_data.gd` loads every available faction.
   ```sh
   PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider tools/faction_import/tests
   ```

### Shared entries

`tools/faction_import/shared.json` lists the shared warscrolls (by id) and Armies of Renown (by name), and holds their field overrides, in the same `fields` format as a faction's overrides, targeted by `"<warscroll id or Army of Renown name>"` or `"<... > <weapon or ability name>"`:

```json
{
	"warscrolls": {"nagash_supreme_lord_of_the_undead": {"faction_keyword": true}, "grombrindal_the_white_dwarf": {}},
	"armies_of_renown": ["Legions of Nagash"],
	"fields": {"Legions of Nagash > The Gaze of Nagash": {"declare": "..."}}
}
```

`faction_keyword` marks a warscroll whose every version carries only its own faction's keyword (Nagash is NIGHTHAUNT in Nighthaunt and FLESH-EATER COURTS in Flesh-eater Courts); the shared profile leaves it out and each reference adds it. Without it, keywords naming several factions (Nagash, Supreme Lord of the Underworlds) stay in the shared profile. A `shared.json` override must name a listed warscroll or Army of Renown, but one naming a weapon or ability is skipped for a faction whose version lacks it, since versions can differ.

The first faction built with a shared entry writes it to `data/shared/` (or `--shared <dir>`). Later builds keep the shared entry and report where their version differs as `shared warscroll …` or `shared army of renown …` lines, except for the battle profile, abilities and the faction's own keywords, which go in the reference. Fix such a difference with a `shared.json` override, or pass `--update-shared` to replace the shared entries with this faction's versions; then rebuild the other factions that use them, since their references are computed against the shared entry.

How the BSData catalogues map to the data:

- Units are those `<Faction>.cat` links to, one warscroll per link (a second link can rename the unit, e.g. "Crypt Flayers (2 Models)"), plus unlisted units in the library or a library it links (e.g. units added during a battle, or the Orruk manifestations), except a copy of a listed unit under another id (Sons of Behemat's library has a second Gatebreaker Mega-Gargant (Scourge of Aqshy) for King Brodd's Stomp) and units defined by Army of Renown catalogues (e.g. Grombrindal). The Anvil of Apotheosis hero is left out; it's in Path to Glory.
- Points and reinforcement come from the faction catalogue's link to each unit. `source` and `legends` come from the unit's publication, and a "(Scourge of …)" name suffix becomes the `source`.
- Abilities include shared profiles an entry links to with an `infoLink`, such as each Flesh-eater Courts hero's Delusion, except core rules abilities (profiles named like one in the game system, e.g. Beast).
- `non-<KEYWORD>` categories (Ogor Mawtribes' `non-BEASTCLAW`) only restrict list building, so they aren't keywords.
- Ability icon categories come from the profile's `Type` attribute. `***Label:***` (or `***Label*:**`) lines in an effect become `options`, and designer's notes become an option named "Designer’s Note". When several options each follow a short heading line, the heading prefixes the option name ("Battle Round 2: Daemonic Weaponry").
- Battle traits are the catalogue's "Battle Traits: <name>" entry, or its only Battle Traits entry when the name differs (Da King's Gitz has "Battle Traits: The King's Gitz") or has no army name (Hedonites of Slaanesh has plain "Battle Traits"). Battle formations likewise come from a "Battle Formations: <name>" or plain "Battle Formations" group.
- Each shared entry group other than lores, formations, Paths and Battle Wounds is an enhancement type. A nested group becomes the table's `group`, and the publication becomes its `source`.
- BSData only offers an enhancement group to the units whose entry, or the catalogue's link to them, links it. A table linked by any set of units other than exactly the non-UNIQUE HEROES gets those units' names as `units`, shared by every table nested in the group: Kharadron Overlords' Great Endrinworks name the Skyvessels, Stormcast Eternals' Scars of War the non-HERO units, and Cities of Sigmar's Heroic Traits every HERO but the Cogforts. An Army of Renown's tables are checked against its roster's units. A group no unit links has no `units`.
- Lores come from the Spell, Prayer and Manifestation Lores groups. Universal lores (core rules, General's Handbook) are skipped. A lore's points come from its option in the group. They match the [Battle Profiles](https://assets.warhammer-community.com/eng_23-09_aos_core&key_battle_profiles-5zexz8yaxd-kamikjxgsp.pdf) (September 2026), which price every faction lore at 0. Scourge of Ghyran lores and Khazalite Holds aren't in that document, so they keep BSData's points (e.g. Bloodshadow Rites 20).
- An Army of Renown is each `<Faction> - <Name>.cat` and each catalogue in `armies_of_renown_from` (a `[LEGENDS]` tag in the name, even without its closing bracket, marks it `legends`), plus the shared catalogue it links to when its rules live there (e.g. `The Duardin Ascendant [LEGENDS].cat`). Catalogue links are followed by target id, since a link's name can differ from the file's ("þ Legions of Nagash" is `Legions of Nagash [LEGENDS].cat`).

The Wahapedia parsers rely on Wahapedia's page structure. A unit page whose sheet is a Regiment of Renown (Slaves to Darkness links the Curse-Steel Battery) is skipped, since it holds the regiment's rules rather than a warscroll. They read the faction page's headings: Battle Traits, Battle Formations, `… Lore`, other enhancement types, and Armies of Renown (sections with a ROSTER OPTIONS heading, or that mention roster options, since Beastclaw Alfrostun's heading is missing), Path to Glory and Spearhead. A Spearhead army list's General and Units headings may be upper case (Ironjawz Bigmob). Spearhead army lists sometimes use the singular ("Sunsteala Wheela"), shorten unit names ("Dominator Engine") or reorder their words ("Freeguild Command Corps Whisperblade" for "Whisperblade, Freeguild Command Corps"); these are resolved to the Spearhead's warscroll by unique prefix, by matching words, or by a close spelling ("lronguts" for "Ironguts"). Each list item is its own entry; a unit listed without a count (a named character, or a hero such as "Varghulf Courtier") counts as 1, and notes ("with 1 Blackpowder Squire token", "with Venomites token", "with 1 Blissbrew Homonculus", or a parenthetical) become the unit's `notes`, as does a closing line for every unit of a kind ("Each unit of Gutter Runners has 1 Bomb Rat token."); the general's notes are dropped, except a designer's note (Scrapglutt's Mantrappers), which is added to the Spearhead's `text`. Text under a Spearhead's Battle Traits heading that isn't in an ability block is kept: when an ability follows, it's that ability's `text` (which units start in reserve before the ability that sets them up, e.g. the Bad Moon Madmob's "Squigalanche"); otherwise it's a battle trait of its own, named by its title, with any table rows ("18+ | SADISTIC SPITE: …") as `options` named "18+: Sadistic Spite" (the Blades of the Lurid Dream's "Temptations of Slaanesh"). The title, text and table may each sit in a block of their own (the Heartflayer Troupe's "Blood Rites"), and an "Effect:" label in a row is dropped.

## Regiments of Renown

A Regiment of Renown is a pre-built group of units with abilities of its own that armies of other factions can include (core rules 3.5). Each is stored once in `data/shared/regiments_of_renown.json` (`{"regiments_of_renown": [...]}`, in the `RegimentOfRenown` shape), with the ids of the factions that can include it in `factions`; the loader gives each faction the regiments that list its id. Unlike shared warscrolls and Armies of Renown, factions don't reference regiments, as a reference would carry nothing of the faction's own, and listing the factions on the regiment matches the Battle Profiles, which say per regiment which factions can include it. `test_faction_data.gd` checks every listed id is a faction. A regiment's units point at the warscrolls of their home faction by faction and warscroll id (Arkhan the Black is `ossiarch_bonereapers` / `arkhan_the_black_mortarch_of_sacrament`), so the loader doesn't load other factions; `test_faction_data.gd` checks every unit resolves. A unit the regiments catalogue defines itself (Gotrek Gurnisson, Mask of the Deceiver, the Outlaw Cogforts) has no faction and is in the regiment's `warscrolls`.

`tools/faction_import/build_regiments.py` builds them all, after the factions they draw units from:

```sh
python -I tools/faction_import/fetch.py --regiments <download dir>
python -I tools/faction_import/build_regiments.py <download dir> > report.txt
```

It writes the shared file, listing for each regiment the factions in `data/factions/` that can include it, so rerun it after adding a faction. A unit that resolves to no warscroll stops the build.

- **BSData** (`Regiments of Renown.cat` and the game system) is the primary source. Each regiment's force entry in the game system has its points and the faction catalogues it is allowed for, the catalogue's "Regiment of Renown: <name>" upgrade entry has its abilities, and its unit links shown for that force are its units, with the count each link's minimum is set to. Regiments only for Path to Glory campaigns (the Ravaged Coast's Realmstone Innovator, Sinister Nullifier, Warped Saboteur and Weird-Crafta, and the Regiment of Ghyran) are left out. Factions that aren't built get no references; the report lists them.
- **Wahapedia** has a page for each regiment under every faction that can include it, which faction pages don't link, so `fetch.py --regiments` tries each allowed faction and spellings of the name; names it can't derive go in the overrides' `wahapedia_names`. The page supplies unit size notes, units BSData misses (the Sigil Convocation's three manifestations), notes such as Krittok's Clawpack's keyword, each unit's home faction (from its link), and the order of units and abilities. Its unit counts sometimes count models ("5 Vanari Dawnriders" is one unit), so counts come from BSData. Its background description is left out.

The report lists points, legends, factions, unit names and abilities that differ. Wahapedia also lists Armies of Renown (Legion of the First Prince) among the factions; those BSData allows with their faction aren't reported. Fix BSData with `tools/faction_import/overrides/regiments_of_renown.json`: `wahapedia_names`, `replace_with_wahapedia` (which keeps BSData's `colour` where Wahapedia's box has none) and `fields` as for a faction (targets are `"<regiment>"` or `"<regiment> > <ability or unit name>"`; a unit's `faction` and `warscroll` can be set to point it at another warscroll), plus `add_from_wahapedia`, a list of `"<regiment> > <Wahapedia ability>"` only Wahapedia prints (the Godmarked Ascendant's 'Gifts of Chaos'), and `remove`, a list of `"<regiment> > <ability>"` that BSData gives the wrong regiment (its Heralds of the Bone-tithe has the Dawnrider Lance's 'Masters of All Terrain'). An ability can be the regiment's or one of its own warscrolls' (Mask of the Deceiver's 'Forceful Command', which BSData calls 'Unstoppable Battle Fury'). `add_factions` (`{"<regiment>": ["<faction name>"]}`) lets more factions include a regiment than BSData allows: the [Battle Profiles](https://assets.warhammer-community.com/eng_28-10_aos_core_rules_and_key_downloads_battle_profiles-vg9lopzmfl-isgqhhvp10.pdf) (October 2026) let Khazalite Holds include the regiments Fyreslayers could, except Gotrek Gurnisson and Fjori's Flamebearers. Fyreslayers keep them, as they are Legends. The [Regiments of Renown PDF](https://assets.warhammer-community.com/eng_sept25_aos_regiments_of_renown-fmuoilpm8f-06hzdipnzs.pdf) (September 2025) has the regiments not in a battletome and settles their disagreements.

## Exporting

`data/` holds plain JSON files, which Godot only exports if they match the export preset's include filter. When export presets are added, include `data/*`.
