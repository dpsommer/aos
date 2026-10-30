# Core rules data

Rules every army uses live as JSON in `data/core/`, in the same shapes as faction data (see [Faction data](faction-data.md#schema)). `CoreRulesLoader` (`scripts/data/core/core_rules_loader.gd`) reads them into a `CoreRules` resource, collecting problems in `errors` as `FactionLoader` does.

## Files

**File** | **Contents** | **Source**
-- | -- | --
`abilities.json` | `abilities`: the universal abilities: deployment (Deploy Unit, Deploy Regiment, Deploy Faction Terrain), core (Normal Move, Run, Retreat, Shoot, Charge, Fight), passive (Fly, Ward Save, Guarded Hero, Champion, Musician, Standard Bearer), commands (Rally, Magical Intervention, Redeploy, At the Double, Covering Fire, Counter-charge, Forward to Victory, All-out Attack, All-out Defence, Power Through), Activate Place of Power, Unbind, Sacred Rites and Banish Manifestation. `weapon_abilities`: the universal weapon abilities (Anti-X, Crit…). `terrain_abilities`: the universal terrain abilities (Cover, Obscuring…) | Written by hand
`manifestation_lores.json` | `lores`: the universal manifestation lores, which any army can take, with their points. `warscrolls`: the manifestations they summon | `tools/faction_import/build_core.py`
`battlepack.json` | The General's Handbook 2026-27 matched play battlepack: `name`, `scourge` (the Scourge expansion whose seasonal rules it uses, "Scourge of Aqshy"; see [Scourge rules](faction-data.md#scourge-rules)), `battle_rounds`, `battlefield` (`width`, `depth` in inches), `sections` (its rules, e.g. Glorious Victory, and Using the Scourge of Aqshy Rules), `battleplan_tables` (two lists of 6 battleplan names, in D6 order), `season_rules` (Raising the Heat, Simmering Rage, Eruption of Fury, Fight Through the Pain) and `faqs` | Written by hand
`battle_tactics.json` | `sections`: the Battle Tactics 2026-27 rules. `cards`: the 6 battle tactics cards | Written by hand
`battleplans.json` | `sections`: the Battleplan Maps key. `battleplans`: the 12 battleplans with their maps | Written by hand; maps from `tools/battleplan_maps/extract_maps.py`

All the files must be present; the loader rejects the core rules if any is missing. The battlepack files load into `CoreRules.battlepack`, a `Battlepack`.

All are `Ability`, `Lore` and `Warscroll` objects. Commands have `command_points` (their cost), and reactions such as 'At the Double' have `used_by` in place of `declare`. Weapon and terrain abilities only have a `name`, a `type` of "passive", a `timing` of "Passive" and an `effect`. Every ability's `type` follows the same rules as faction data's (see [Ability types](faction-data.md#ability-types)).

## Abilities

`abilities.json` follows Wahapedia's [Core Rules](https://wahapedia.ru/aos4/the-rules/the-core-rules/) page: the Core Rules and the Advanced Rules 2026-27 (Commands, Terrain, Magic, Army Composition and Command Models) that the General's Handbook 2026-27 battlepack uses, with the errata the page lists applied. The page's text was first transcribed from [The Rules](https://assets.warhammer-community.com/eng_aos_core&key_the-rules_apr25-t7q3fbv0zb-bit50crc5k.pdf) (April 2025) and the [Rules Updates](https://assets.warhammer-community.com/eng_23-09_aos_core&key_rule_updates-eu6fu82jl3-dlyuiignte.pdf) (September 2026). The Advanced Rules 2026-27 changed 'Magical Intervention' (it can also use a BANISH ability), 'All-out Defence' (lasts until the ATTACK ability is resolved), 'Banish Manifestation' (not a manifestation summoned this turn), 'Activate Place of Power' (Ignite Fury, Channel Wrath and Dizzying Rage options) and the Obscuring terrain ability (units within 1" are only visible within combat range), and dropped 'Tactical Gambit', as battle tactics now come from the battlepack's cards (see [General's Handbook battlepack](#generals-handbook-battlepack)).

Section references such as "(see 16.0)" are the rules' own. Categories follow each ability's icon, using BSData's names. 'Sacred Rites' is included because all PRIESTS know it. The example spell and prayer in the Magic module ('Mystic Shield', 'Resurrection') aren't known by any WIZARD or PRIEST (they only know the spells and prayers on their warscroll and in their lores), so they're left out. So are faction abilities that the page quotes in FAQs, such as 'The Hand of Gork'.

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

Each summoning spell's `summons` holds its manifestation's warscroll id (see [Summons](faction-data.md#summons)).

Manifestations have no battle profile, so their `points` are 0 and `unit_size` 1. The lore's points are what an army pays.

## General's Handbook battlepack

`battlepack.json`, `battle_tactics.json` and `battleplans.json` are transcribed from Wahapedia's [General's Handbook 2026-27](https://wahapedia.ru/aos4/the-rules/general-s-handbook-2026-27/) page. They hold the Matched Play Battlepack, Season Rules 2026-27, Using the Scourge of Aqshy Rules, Battle Tactics 2026-27, the battleplans and the FAQs on those sections. The Aqshian Crusades (campaign and team-event formats) and the Tournament Organiser Pack aren't game rules, so they're left out. So are the core rules extracts, FAQs and errata that Wahapedia shows in its tooltips, which aren't the handbook's. Flavour text is dropped, as in the rest of the data, and rules sections are condensed where they only introduce a list.

When the next General's Handbook replaces this one, replace these three files.

### Schema

**Class** | **Fields** (required in bold)
-- | --
`Battlepack` | **`name`**, **`battle_rounds`**, `battlefield_size` (from `battlefield`), `sections`, `battleplan_tables`, `season_rules`, `faqs`, plus `battle_tactic_rules` and `battle_tactic_cards` (from `battle_tactics.json`) and `battleplan_rules` and `battleplans` (from `battleplans.json`)
`BattleTacticCard` | **`number`**, **`name`**, `text` (rules for the whole card, e.g. picking the enemy hideout), `tactics`, `faqs`
`BattleTactic` | **`name`**, **`kind`** (`affray`, `strike` or `domination`, in the order they must be completed), **`condition`**, **`victory_points`**
`Battleplan` | **`number`**, **`table`** (1 or 2), **`name`**, `map` (the Wahapedia map image, used by the map tool; not loaded), `text` (set-up rules), `twist`, `abilities`, `scoring` (one victory point rule per entry), `objectives`, `terrain`, `attacker_territory`, `defender_territory`, `faqs`
`MapFeature` | **`type`**, `size` (**required** for terrain), **`x`**, **`y`** (loaded into `position`)

FAQs are `{"about", "question", "answer"}`, where `about` names the rule or section the ruling is on (the battlepack's FAQs cover several) and may be left out. Sections are `RulesSection`s and abilities are `Ability`s, as in faction data.

The handbook's Advanced Rules 2026-27 change some universal abilities, such as 'Activate Place of Power', which gains the Ignite Fury option for the season's rage dice. Those are in `abilities.json` (see [Abilities](#abilities)), not here.

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

## Spearhead battlepacks

Spearhead is played on a 30" × 22" realm battlefield with its own battlepack: each double-sided realm battlefield comes with a battleplan and a Spearhead deck (a twist deck for each side and two identical battle tactic decks). Each battlepack is one JSON file in `data/core/spearhead/`, listed in `CoreRulesCatalog.SPEARHEAD_FILES`. `SpearheadLoader` (`scripts/data/core/spearhead_loader.gd`) reads one into a `SpearheadBattlepack`, collecting problems in `errors`; `CoreRulesCatalog.spearhead_battlepacks()` loads them all once. The Spearhead armies themselves (warscrolls, battle traits, regiment abilities and enhancements) are faction data (see [Faction data](faction-data.md)).

**File** | **Battlepack** | **Source**
-- | -- | --
`fire_and_jade.json` | Fire and Jade: the Aqshy and Ghyran sides | Written by hand
`sand_and_bone.json` | Sand and Bone: the Dolorum and Ossia sides of a Shyish battlefield | Written by hand
`city_of_ash.json` | City of Ash: the Shattered Crossroads and Ashen Bastion sides of Embergard, its relics and the Hidden in the Ashes campaign | Written by hand

Fire and Jade is the battlepack in [The Rules](https://assets.warhammer-community.com/eng_aos_core&key_the-rules_apr25-t7q3fbv0zb-bit50crc5k.pdf) (April 2025, pages 49–58). The PDF only shows the cards as illustrations, so the twist and battle tactic cards, and the rules text with its errata (the "behind a terrain feature" sentence in 5.0 Terrain) and FAQ, come from Wahapedia's [Fire and Jade](https://wahapedia.ru/aos4/the-rules/fire-and-jade/) page. Sand and Bone comes from Wahapedia's [Sand and Bone](https://wahapedia.ru/aos4/the-rules/sand-and-bone/) page, whose errata (the 'Survivor’s Grief' twist, 'Monument of Living Bone' and the Crypt of Blood set-up step) Wahapedia has applied. Flavour text is dropped and the battlepacks' introductory sections are condensed, as in the General's Handbook files. Wahapedia's typos are fixed ("lgnax", "scores l", "roll I dice", "For each 5+. Heal"). Wahapedia's Dolorum twist 'Darkened Skies' only says what happens "if there is no underdog"; the card probably also has the underdog pick the objective, but this isn't added until it can be checked.

City of Ash comes from Wahapedia's [City of Ash](https://wahapedia.ru/aos4/the-rules/city-of-ash/) page. It adds rectangular objectives (`MapFeature.extent` and `rotation`; `SpearheadBattlepack.is_on_objective()`), roads (`RealmBattlefield.roads`, polygons), relics (`SpearheadBattlepack.relics`, abilities named after each relic, with each realm's `starting_relics` and each twist's `relic` to place) and a campaign (`SpearheadBattlepack.campaign`: a `SpearheadCampaign` of `CampaignBattle`s, each with its realm, rules, starting relics and own deployment map; `fixed_territories` means territory A is the attacker's). Its objective positions, sizes and road widths are measured from the faint boards under Wahapedia's City of Ash deployment and campaign maps (`CoA_1.png`–`CoA_5.png`), to about ±0.5"; the roads are modelled as two 3.5" bands through the junction at the objectives' −15° tilt. The small objectives' names are guesses (the symbols can't be read at that size): check them, and the dais battle tactics that depend on them, against the board.

### Schema

**Class** | **Fields** (required in bold)
-- | --
`SpearheadBattlepack` | **`name`**, **`battle_rounds`**, **`battlefield_size`** (from `battlefield`), `sections` (the battlepack's rules, e.g. 5.0 Terrain), `abilities` (e.g. 'Call for Reinforcements', and the mystical terrain's 'Unholy Draught'), `terrain_abilities` (the battlepack's own Cover, Obscuring and Unstable, which differ from the core rules', and e.g. Unholy), `terrain_features`, `terrain_groups`, `objective_names`, **`objective_radius`**, `realms`, `deployment_maps`, `battleplan_name`, `battleplan_sections` and `scoring` (from **`battleplan`**: `name`, `sections`, `scoring`), `battle_tactic_cards`, `relics` (abilities named after each relic), `campaign`, `faqs`
`SpearheadTerrain` | **`name`**, **`size`** (`large` or `small`), `mystical` (set up by the battleplan or a twist, not by the players), `abilities` (names of the battlepack's `terrain_abilities`)
Terrain group | `{"name", "features"}`: terrain feature names. The defender picks a group and the attacker takes the other (Sand and Bone). Without groups, each player sets up one large and one small terrain feature (Fire and Jade)
`RealmBattlefield` | **`name`** (the side, e.g. "Aqshy"), `objectives` (`MapFeature`s whose `type` is one of `objective_names`, with an optional `radius`), `terrain` (`MapFeature`s naming terrain features set up before the players', e.g. Ossia's Crypt of Blood), `roads` (polygons, e.g. the Shattered Crossroads'), `starting_relics`, `twists`
`TwistCard` | **`name`**, **`text`**, `options` (named effects the underdog picks from, as an ability's), `relic` (the relic the twist has a player place)
`DeploymentMap` | **`name`** ("Horizontal" or "Diagonal"), **`territory_a`**, **`territory_b`**: polygons of at least 3 `{x, y}` corners, loaded as `PackedVector2Array`s. The defender picks the map and which territory is theirs
`SpearheadTacticCard` | **`name`**, **`condition`** (the battle tactic), **`command`** (an `Ability` of type "command" with no command points)
`SpearheadCampaign` | **`name`**, `sections`, `battles` (in the order they're played)
`CampaignBattle` | **`name`**, **`realm`** (a realm's name), `text`, `starting_relics`, **`deployment_map`**, `fixed_territories` (territory A is the attacker's)

Map positions are in inches from the battlefield's north-west corner, as for battleplans. A rectangular objective has `width` and `depth` (loaded as `MapFeature.extent`) and a clockwise `rotation` in degrees; `MapFeature.corners()` gives its corners.

### Objectives

Spearhead objectives are printed on the realm battlefield and a model contests one while it is on it (wholly or partially), so each has a centre and a radius rather than a 3" control zone: the battlepack's `objective_radius`, or the objective's own `radius` where it differs (`SpearheadBattlepack.radius_of()`), e.g. Dolorum's large central Grief objective. An objective on a battlefield edge overhangs it, so its centre is inside the battlefield but its circle isn't. Not every side has every objective: Ossia has 4 of Sand and Bone's 5.

Positions and sizes are measured from the board photos and realm maps on Wahapedia's [Spearhead Doubles](https://wahapedia.ru/aos4/the-rules/spearhead-doubles/) page (`SD_1.png`–`SD_4.png` show each side north up), rounded to the nearest half inch. Each board is point-symmetric about its centre, and the positions are rounded so that they stay symmetric. Objectives are named by matching their symbols to the battlepack's objective key (Wahapedia's `Obj_Spearhead.png` and `Objectives_SnB.png`). Fire and Jade's objectives are 6" across. Sand and Bone's are 5" across, except Dolorum's Grief, which is about 6". The photos are small, so the names of Ossia's objectives are less certain than the others: Delusion is clear, Necropolis and Blood (the central pair the 'Dais' battle tactics name) are likely, and Night is a guess.
