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
`Warscroll` | **`id`**, **`name`**, `source`, `legends`, **`points`**, **`unit_size`** (both optional in Spearhead and Path to Glory), `base_size`, `can_reinforce`, `regiment_options`, `notes`, **`move`**, **`health`**, **`save`**, `ward`, **`control`**, `ranged_weapons`, `melee_weapons`, `abilities`, `keywords`, `composition`
`BattleFormation` | **`name`**, `points`, `abilities`
`EnhancementTable` | **`name`** (type, e.g. "Heroic Traits"), `group` (e.g. "Lords of the Sky-fleets"), `source`, `entries`
`Lore` | **`name`**, `kind` (spell, prayer, manifestation), `points`, `entries`
`Spearhead` | **`name`**, `text`, **`general`**, `units` (`[{count, name, notes}]`, names match the Spearhead's own warscrolls), `battle_traits`, `regiment_abilities`, `enhancements`, `warscrolls`
`RulesSection` | **`name`**, `text`, `warscrolls`

Characteristics such as `save`, `hit` and `wound` store the x of an x+ roll. `source` names the expansion a rule comes from (e.g. "Scourge of Aqshy"); it's empty for battletome rules. Path to Glory is stored as text because its content is too varied to model usefully yet.

The loader rejects the whole faction, collecting every problem in `errors`, if a file isn't valid JSON, a required field is missing, or a field has the wrong type.

## Sources

Faction data is extracted from Wahapedia's faction page and each unit's page (e.g. `https://wahapedia.ru/aos4/factions/kharadron-overlords/`), which include current errata. Values are then cross-checked:

- Formation and enhancement points and unit sizes against the "AoS Rules" NotebookLM notebook (`a30c0d6a-8127-4eab-b97e-e457c97a65fc`), which holds the battletome and General's Handbook.
- Unit points against the BSData catalogue (`<Faction>.cat` in [BSData/age-of-sigmar-4th](https://github.com/BSData/age-of-sigmar-4th)).

## Adding a faction

The extraction scripts are in `tools/faction_import/` (Godot ignores `tools/`). They need Python 3 with `requirements.txt` installed, ideally in a virtualenv outside the repo.

1. Download the Wahapedia faction page and every unit page it links to into an empty directory outside the repo. Links without a page of their own (such as the Path to Glory hero) are skipped with a warning:
   ```sh
   python -I tools/faction_import/fetch.py <wahapedia slug, e.g. helsmiths-of-hashut> <download dir>
   ```
2. Parse them:
   ```sh
   python -I tools/faction_import/wsparse.py <download dir>/units/*.html > warscrolls_raw.json
   python -I tools/faction_import/fparse.py <download dir>/<wahapedia slug>.html > faction_raw.json
   python -I tools/faction_import/build.py warscrolls_raw.json faction_raw.json data/factions/<id> <id> "<Name>" <alliance> [tools/faction_import/overrides/<id>.json]
   ```
   The optional overrides file corrects Wahapedia data where it disagrees with BSData. Currently it supports `warscroll_names` (`{"<Wahapedia name>": "<BSData name>"}`), which renames a warscroll everywhere it appears and updates its id. `build.py` stops if an override matches no warscroll.
3. Cross-check names, points and unit sizes against the sources above, adding name overrides where needed, and spot-check a few warscrolls against the page.
4. Add the name → directory entry to `_DATA_DIRS` in `scripts/data/faction_catalog.gd`.
5. Run the tests. `test/integration/test_faction_data.gd` loads every available faction.

How the faction page is read:

- Each `h2` under Faction Rules is Battle Traits, Battle Formations, a lore type (any heading ending in "Lore", e.g. "Spell Lore") or an enhancement type (anything else, e.g. "Heroic Traits", "Accursed Devices"). An `h3` under it names a formation, a lore, or an enhancement table's `group`.
- Points come from the "Name | Points" table before each group. A section's expansion `source` comes from the expansion logo after its heading.
- Spell and prayer values come from the ability header; ability keywords (e.g. `SPELL`, `RAMPAGE`) from the keyword block under each ability.
- An `h2` whose section lists ROSTER OPTIONS starts an Army of Renown. PATH TO GLORY and SPEARHEAD start those parts.
- Spearhead army lists sometimes shorten unit names ("Dominator Engine"); `build.py` resolves each to the Spearhead's warscroll by unique prefix and stops if it can't.

The parsers rely on Wahapedia's page structure and may need adjusting for other factions, e.g. manifestation lores, whose manifestations have warscrolls of their own.

## Exporting

`data/` holds plain JSON files, which Godot only exports if they match the export preset's include filter. When export presets are added, include `data/*`.
