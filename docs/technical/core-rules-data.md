# Core rules data

Rules every army uses live as JSON in `data/core/`, in the same shapes as faction data (see [Faction data](faction-data.md#schema)). `CoreRulesLoader` (`scripts/data/core_rules_loader.gd`) reads them into a `CoreRules` resource, collecting problems in `errors` as `FactionLoader` does.

## Files

**File** | **Contents** | **Source**
-- | -- | --
`abilities.json` | `abilities`: the universal abilities: deployment (Deploy Unit, Deploy Regiment, Deploy Faction Terrain), core (Normal Move, Run, Retreat, Shoot, Charge, Fight), passive (Fly, Ward Save, Guarded Hero, Champion, Musician, Standard Bearer), commands (Rally, Magical Intervention, Redeploy, At the Double, Covering Fire, Counter-charge, Forward to Victory, All-out Attack, All-out Defence, Power Through), Activate Place of Power, Unbind, Banish Manifestation and Tactical Gambit. `weapon_abilities`: the universal weapon abilities (Anti-X, Crit…). `terrain_abilities`: the universal terrain abilities (Cover, Obscuring…) | Written by hand
`manifestation_lores.json` | `lores`: the universal manifestation lores, which any army can take, with their points. `warscrolls`: the manifestations they summon | `tools/faction_import/build_core.py`

All are `Ability`, `Lore` and `Warscroll` objects. Commands have `command_points` (their cost), and reactions such as 'At the Double' have `used_by` in place of `declare`. Weapon and terrain abilities only have a `name`, a `type` of "passive", a `timing` of "Passive" and an `effect`. Every ability's `type` follows the same rules as faction data's (see [Ability types](faction-data.md#ability-types)).

## Abilities

`abilities.json` is transcribed from [The Rules](https://assets.warhammer-community.com/eng_aos_core&key_the-rules_apr25-t7q3fbv0zb-bit50crc5k.pdf) (April 2025: Core Rules and Advanced Rules, not Spearhead) with the [Rules Updates](https://assets.warhammer-community.com/eng_23-09_aos_core&key_rule_updates-eu6fu82jl3-dlyuiignte.pdf) (September 2026) errata applied: 'Deploy Regiment' and 'Companion' are the updated text. The April 2025 rules already include the other errata to these abilities. Section references such as "(see 16.0)" are the rules' own. Categories follow each ability's icon, using BSData's names. The example spell and prayer in the Magic module ('Mystic Shield', 'Resurrection') aren't universal, so they're left out. So are the rules' universal battle tactics: the current General's Handbook has players pick battle tactics from its own set of battle tactic cards.

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
