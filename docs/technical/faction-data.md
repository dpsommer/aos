# Faction data

Each faction's rules live as JSON in `data/factions/<faction_id>/`. `FactionLoader` (`scripts/data/faction_loader.gd`) reads them into typed `Resource` classes in `scripts/data/`. `FactionCatalog` maps faction names to their data directories; a faction without one shows as "Coming soon" in the Forge.

## Files

**File** | **Required** | **Contents**
-- | -- | --
`faction.json` | Yes | `id`, `name`, `grand_alliance` (`order`, `chaos`, `death`, `destruction`), `battle_traits`, `battle_formations`, `enhancement_tables`, `lores`
`warscrolls.json` | No | `{"warscrolls": [...]}`: matched play warscrolls with battle profiles
`armies_of_renown.json` | No | `{"armies_of_renown": [...]}`: name, text (description and roster), battle traits, enhancement tables, lores
`spearhead.json` | No | `{"spearheads": [...]}`: army list (`general`, `units`), battle traits, regiment abilities, enhancements, and the Spearhead versions of warscrolls
`path_to_glory.json` | No | `{"sections": [...]}`: titled text sections, plus any warscrolls (e.g. the Anvil of Apotheosis hero)

## Schema

**Class** | **Fields** (required in bold)
-- | --
`Ability` | **`name`**, `category` (icon: offensive, movement, special…), `timing`, `frequency`, `declare`, `effect`, `text`, `keywords`, `options` (`[{name, text}]`), `points`, `casting_value` (spells), `chanting_value` (prayers), `source`
`Weapon` | **`name`**, `range` (inches, 0 for melee), **`attacks`**, **`hit`**, **`wound`**, `rend`, **`damage`**, `abilities`. Attacks and damage are strings because they can be dice, e.g. `"2D6"`
`Warscroll` | **`id`**, **`name`**, `source`, `legends`, **`points`**, **`unit_size`** (both optional in Spearhead and Path to Glory), `base_size`, `can_reinforce`, `regiment_options`, `notes`, **`move`**, **`health`**, **`save`**, `ward`, **`control`**, `banishment` (manifestations), `ranged_weapons`, `melee_weapons`, `abilities`, `keywords`, `composition`
`BattleFormation` | **`name`**, `points`, `abilities`
`EnhancementTable` | **`name`** (type, e.g. "Heroic Traits"), `group` (e.g. "Lords of the Sky-fleets"), `source`, `entries`
`Lore` | **`name`**, `kind` (spell, prayer, manifestation), `points`, `source`, `entries`
`Spearhead` | **`name`**, `text`, **`general`**, `units` (`[{count, name, notes}]`, names match the Spearhead's own warscrolls), `battle_traits`, `regiment_abilities`, `enhancements`, `warscrolls`
`RulesSection` | **`name`**, `text`, `warscrolls`

Characteristics such as `save`, `hit` and `wound` store the x of an x+ roll. `source` names the expansion a rule comes from (e.g. "Scourge of Aqshy"); it's empty for battletome rules. Path to Glory is stored as text because its content is too varied to model usefully yet.

The loader rejects the whole faction, collecting every problem in `errors`, if a file isn't valid JSON, a required field is missing, or a field has the wrong type.

## Sources

Faction data is built by `tools/faction_import/` from two sources:

- **[BSData](https://github.com/BSData/age-of-sigmar-4th) is the primary source.** It provides warscrolls (stats, weapons, abilities, keywords, base size, unit size), points, reinforcement, battle traits, battle formations, enhancements, spell and prayer lores, and the rules of each Army of Renown. Where BSData and Wahapedia disagree, BSData's value is used.
- **[Wahapedia](https://wahapedia.ru/aos4/) fills the gaps.** BSData has no Spearhead data, Path to Glory prose, regiment options, unit notes, unit composition text or Army of Renown descriptions, so these come from Wahapedia's faction and unit pages. Wahapedia is also the reference for the build's diff report, and its book order is used to order traits, formations and enhancements.

The "AoS Rules" NotebookLM notebook (`a30c0d6a-8127-4eab-b97e-e457c97a65fc`), which holds the battletome and General's Handbook, is useful for settling disagreements the diff report raises.

**Legends warscrolls** (those with `legends`) are checked against the "AoS Legends" NotebookLM notebook (`69365d24-6043-4353-bb04-2b0d3ecca253`), which is the source of truth for them and wins over both BSData and Wahapedia. Record any corrections in the faction's overrides file.

## Adding a faction

The import tool is in `tools/faction_import/` (Godot ignores `tools/`). It needs Python 3 with `requirements.txt` installed, ideally in a virtualenv outside the repo, and `git`.

BSData is read from a local shallow clone of the repository at `tools/bsdata/`, which is gitignored. `build.py` clones it the first time it runs; pass `--update-bsdata` to pull the latest catalogues, or `--bsdata <dir>` to use a checkout elsewhere. The report's first line names the BSData commit used.

**Module** | **Role**
-- | --
`fetch.py` | Downloads the Wahapedia faction and unit pages
`bsdata.py` | Manages the BSData checkout and reads the catalogues a faction needs (game system, `Lores.cat`, `<Faction>.cat`, its library, every `<Faction> - <Army of Renown>.cat` and the shared catalogues they link to): resolves links across files, converts BSData markup (`**^^Keyword^^**` → `KEYWORD`), maps profiles to warscrolls and abilities
`wahapedia.py` | Parses the Wahapedia pages
`merge.py` | Combines the two, adds Wahapedia-only content, matches names (including misspellings such as "Hobgrotz"/"Hobgrot") and produces the diff report
`schema.py` | Writes the canonical JSON shape
`build.py` | Runs the steps above, applies overrides and writes the five files

1. Download the Wahapedia pages into an empty directory outside the repo:
   ```sh
   python -I tools/faction_import/fetch.py helsmiths-of-hashut <download dir>
   ```
   Wahapedia links without a page of their own (such as the Path to Glory hero) are skipped with a warning.
2. Build the data and keep the report:
   ```sh
   python -I tools/faction_import/build.py <download dir> data/factions/<id> <id> "<BSData faction name>" \
       [--overrides tools/faction_import/overrides/<id>.json] [--update-bsdata] > report.txt
   ```
3. Read the report. It lists every field where BSData and Wahapedia disagree, names matched by similarity, and items only one source has. BSData wins by default. When BSData is wrong, add an override and rebuild. Override files are JSON:
   - `replace_with_wahapedia`: `{"<BSData ability name>": "<Wahapedia ability name>"}`. Uses Wahapedia's version of an ability where BSData has the wrong rule, e.g. Taar's Grand Forgehost's "Masterful Daemonworks". Applied before merging, so the replacement is ordered and compared like everything else.
   - `warscroll_names`: `{"<name>": "<name to use>"}`. Renames a warscroll everywhere and updates its id.
   - `fields`: `{"<target>": {"<field>": <value>}}`. Replaces fields after merging, e.g. a casting value, a missing keyword or a misspelt weapon name. A target is a warscroll id or name, an ability name, or a weapon name. Use `"<warscroll id> > <weapon or ability name>"` when a name alone is ambiguous, e.g. Thundrik's Profiteers have both a weapon and an ability called "Aethermatic Anatomiser".

   The report lists differences before overrides are applied, so overridden fields still appear in it.

   `build.py` stops if an override matches nothing, so stale overrides get noticed.
4. Add the name → directory entry to `_DATA_DIRS` in `scripts/data/faction_catalog.gd`.
5. Run the tool's tests and the game's tests. `test/integration/test_faction_data.gd` loads every available faction.
   ```sh
   PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider tools/faction_import/tests
   ```

How the BSData catalogues map to the data:

- Units are those `<Faction>.cat` links to, plus unlisted units in the library (e.g. units added during a battle) and units defined by Army of Renown catalogues (e.g. Grombrindal). The Anvil of Apotheosis hero is left out; it's in Path to Glory.
- Points and reinforcement come from the faction catalogue's link to each unit. `source` and `legends` come from the unit's publication, and a "(Scourge of …)" name suffix becomes the `source`.
- Ability icon categories come from the profile's `Type` attribute. `***Label:***` lines in an effect become `options`, and designer's notes become an option named "Designer’s Note". When several options each follow a short heading line, the heading prefixes the option name ("Battle Round 2: Daemonic Weaponry").
- Each shared entry group other than lores, formations, Paths and Battle Wounds is an enhancement type. A nested group becomes the table's `group`, and the publication becomes its `source`.
- Lores come from the Spell, Prayer and Manifestation Lores groups. Universal lores (core rules, General's Handbook) are skipped.
- An Army of Renown is each `<Faction> - <Name>.cat`, plus the shared catalogue it links to when its rules live there (e.g. `The Duardin Ascendant [LEGENDS].cat`).

The Wahapedia parsers rely on Wahapedia's page structure. They read the faction page's headings: Battle Traits, Battle Formations, `… Lore`, other enhancement types, and Armies of Renown (sections listing ROSTER OPTIONS), Path to Glory and Spearhead. Spearhead army lists sometimes shorten unit names ("Dominator Engine"); these are resolved to the Spearhead's warscroll by unique prefix.

## Exporting

`data/` holds plain JSON files, which Godot only exports if they match the export preset's include filter. When export presets are added, include `data/*`.
