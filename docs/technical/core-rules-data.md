# Core rules data

Rules every army uses live as JSON in `data/core/`, in the same shapes as faction data (see [Faction data](faction-data.md#schema)). `CoreRulesLoader` (`scripts/data/core_rules_loader.gd`) reads them into a `CoreRules` resource, collecting problems in `errors` as `FactionLoader` does.

## Files

**File** | **Contents** | **Source**
-- | -- | --
`abilities.json` | `abilities`: the universal abilities: deployment (Deploy Unit, Deploy Regiment, Deploy Faction Terrain), core (Normal Move, Run, Retreat, Shoot, Charge, Fight), passive (Fly, Ward Save, Guarded Hero, Champion, Musician, Standard Bearer), commands (Rally, Magical Intervention, Redeploy, At the Double, Covering Fire, Counter-charge, Forward to Victory, All-out Attack, All-out Defence, Power Through), Activate Place of Power, Unbind, Banish Manifestation and Tactical Gambit. `weapon_abilities`: the universal weapon abilities (Anti-X, Crit…). `terrain_abilities`: the universal terrain abilities (Cover, Obscuring…) | Written by hand
`manifestation_lores.json` | `lores`: the universal manifestation lores, which any army can take, with their points. `warscrolls`: the manifestations they summon | `tools/faction_import/build_core.py`
`battlepack.json` | The General's Handbook 2026-27 matched play battlepack: `name`, `battle_rounds`, `battlefield` (`width`, `depth` in inches), `sections` (its rules, e.g. Glorious Victory, and Using the Scourge of Aqshy Rules), `battleplan_tables` (two lists of 6 battleplan names, in D6 order), `season_rules` (Raising the Heat, Simmering Rage, Eruption of Fury, Fight Through the Pain), `updated_abilities` (its version of Activate Place of Power) and `faqs` | Written by hand
`battle_tactics.json` | `sections`: the Battle Tactics 2026-27 rules. `cards`: the 6 battle tactics cards | Written by hand
`battleplans.json` | `sections`: the Battleplan Maps key. `battleplans`: the 12 battleplans with their maps | Written by hand; maps from `tools/battleplan_maps/extract_maps.py`

All the files must be present; the loader rejects the core rules if any is missing. The battlepack files load into `CoreRules.battlepack`, a `Battlepack`.

All are `Ability`, `Lore` and `Warscroll` objects. Commands have `command_points` (their cost), and reactions such as 'At the Double' have `used_by` in place of `declare`. Weapon and terrain abilities only have a `name`, a `type` of "passive", a `timing` of "Passive" and an `effect`. Every ability's `type` follows the same rules as faction data's (see [Ability types](faction-data.md#ability-types)).

## Abilities

`abilities.json` is transcribed from [The Rules](https://assets.warhammer-community.com/eng_aos_core&key_the-rules_apr25-t7q3fbv0zb-bit50crc5k.pdf) (April 2025: Core Rules and Advanced Rules, not Spearhead) with the [Rules Updates](https://assets.warhammer-community.com/eng_23-09_aos_core&key_rule_updates-eu6fu82jl3-dlyuiignte.pdf) (September 2026) errata applied: 'Deploy Regiment' and 'Companion' are the updated text. The April 2025 rules already include the other errata to these abilities. Section references such as "(see 16.0)" are the rules' own. Categories follow each ability's icon, using BSData's names. The example spell and prayer in the Magic module ('Mystic Shield', 'Resurrection') aren't universal, so they're left out. So are the rules' universal battle tactics: the current General's Handbook has players pick battle tactics from its own set of battle tactics cards (see [General's Handbook battlepack](#generals-handbook-battlepack)).

When a rules update changes one of these abilities, edit the file to match.

## Universal manifestation lores

Built from Wahapedia's [Endless Spells](https://wahapedia.ru/aos4/factions/endless-spells/) page, which applies the rules updates' errata and lists each lore's Battle Profile points:

```sh
python -I tools/faction_import/fetch.py endless-spells <download dir>
python -I tools/faction_import/build_core.py <download dir>/endless-spells.html data/core \
    --overrides tools/faction_import/overrides/core.json > report.txt
```

Wahapedia prints ability names in capitals, so names come from BSData's game system and `Lores.cat`, and the report lists where BSData's warscrolls and spells differ from Wahapedia's, as `build.py`'s does. Wahapedia's values are kept: fix one with a `fields` override in `overrides/core.json`, in `build.py`'s format (see [Adding a faction](faction-data.md#adding-a-faction)), targeted by a warscroll id, lore name or `"<warscroll id> > <ability name>"`. The current overrides fix typos on Wahapedia's page ('Scything Blade', 'Mechanisms of Time', 'Wild Form') and the Umbral Spellportal's save, which is 6+ (Wahapedia shows 5+).

The report also shows that BSData's summon spells say "endless spell" where the Endless Spells page doesn't; Wahapedia's wording is kept.

Manifestations have no battle profile, so their `points` are 0 and `unit_size` 1. The lore's points are what an army pays.

## General's Handbook battlepack

`battlepack.json`, `battle_tactics.json` and `battleplans.json` are transcribed from Wahapedia's [General's Handbook 2026-27](https://wahapedia.ru/aos4/the-rules/general-s-handbook-2026-27/) page. They hold the Matched Play Battlepack, Season Rules 2026-27, Using the Scourge of Aqshy Rules, Battle Tactics 2026-27, the battleplans and the FAQs on those sections. The Aqshian Crusades (campaign and team-event formats) and the Tournament Organiser Pack aren't game rules, so they're left out. So are the core rules extracts, FAQs and errata that Wahapedia shows in its tooltips, which aren't the handbook's. Flavour text is dropped, as in the rest of the data, and rules sections are condensed where they only introduce a list.

When the next General's Handbook replaces this one, replace these three files.

### Schema

**Class** | **Fields** (required in bold)
-- | --
`Battlepack` | **`name`**, **`battle_rounds`**, `battlefield_size` (from `battlefield`), `sections`, `battleplan_tables`, `season_rules`, `updated_abilities`, `faqs`, plus `battle_tactic_rules` and `battle_tactic_cards` (from `battle_tactics.json`) and `battleplan_rules` and `battleplans` (from `battleplans.json`)
`BattleTacticCard` | **`number`**, **`name`**, `text` (rules for the whole card, e.g. picking the enemy hideout), `tactics`, `faqs`
`BattleTactic` | **`name`**, **`kind`** (`affray`, `strike` or `domination`, in the order they must be completed), **`condition`**, **`victory_points`**
`Battleplan` | **`number`**, **`table`** (1 or 2), **`name`**, `map` (the Wahapedia map image, used by the map tool; not loaded), `text` (set-up rules), `twist`, `abilities`, `scoring` (one victory point rule per entry), `objectives`, `terrain`, `attacker_territory`, `defender_territory`, `faqs`
`MapFeature` | **`type`**, `size` (**required** for terrain), **`x`**, **`y`** (loaded into `position`)

FAQs are `{"about", "question", "answer"}`, where `about` names the rule or section the ruling is on (the battlepack's FAQs cover several) and may be left out. Sections are `RulesSection`s and abilities are `Ability`s, as in faction data.

`updated_abilities` are the battlepack's versions of core abilities: each replaces the core ability of the same name in battles using the battlepack. Its 'Activate Place of Power' (from the Terrain 2026-27 Advanced Rules) adds the Ignite Fury option, which gives rage dice; the core version stays in `abilities.json`.

### Errata

Errata the page lists are applied to the text: Flanking Firestorm's 'Ambuscade' says "non-FACTION TERRAIN terrain features" (Wahapedia has applied this), and Hidden Under Ash-clouds' 'Rolling Ash-clouds' includes terrain features in each bullet point (Wahapedia hasn't).

### Battleplan maps

Map positions are in inches from the battlefield's north-west corner (the top left of the printed map, which is drawn north up): `x` runs east across the 60" width and `y` south across the 44" depth.

- **Objectives** are `{type, x, y}`: one of the Aqshian objectives "Sun Seekers", "Golden Lions", "Heldenhain" or "Scions of the Comet", at the objective's centre.
- **Terrain** is `{type, size, x, y}`: `type` is `area_or_obstacle` (the map's "area terrain or obstacle" icon, so the player picks), `obscuring` or `place_of_power`, and `size` is `small` or `medium`.
- **Territories** are lists of `{x, y, width, depth}` rectangles, loaded as `Rect2`s. Every map's territories follow its 15" × 11" grid. The rest of the battlefield is neutral territory (Hidden Under Ash-clouds uses it).

`tools/battleplan_maps/extract_maps.py` reads these from Wahapedia's map images and writes them into `battleplans.json`. It finds the gold-rimmed icons with a Hough transform, tells objectives apart by colour and terrain by size and colour (realmgates are Places of Power, woods are obscuring, ruins are area terrain or obstacles), and reads territories from each grid block's colour. Positions are rounded to the nearest half inch and are accurate to about ±0.5": where a map clearly means a grid line (e.g. 45") the tool can give 44.5". To rebuild the maps, download each battleplan's `map` image from `https://wahapedia.ru/aos4/img/battleplans/<map>` into an empty directory outside the repo, then:

```sh
pip install -r tools/battleplan_maps/requirements.txt   # numpy and Pillow, in a virtualenv
python -I tools/battleplan_maps/extract_maps.py data/core/battleplans.json <map dir> --overlays <overlay dir>
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider tools/battleplan_maps/tests
```

Check each overlay (the map with every detected icon circled and labelled) against the map before committing. `test/integration/test_core_rules_data.gd` checks that features lie on the battlefield, territories don't overlap and no map uses more objectives of a type than the battlepack has.
