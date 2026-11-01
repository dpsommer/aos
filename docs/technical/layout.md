# Project layout

```text
aos/
├── addons/
│   └── gut/
├── assets/
│   ├── 2d/
│   ├── 3d/
│   ├── audio/
│   └── shaders/
├── data/
│   └── factions/
├── docs/
│   ├── technical/
│   ├── design/
│   └── gameplay/
├── scenes/
├── scripts/
├── test/
├── tmp/
├── tools/
├── default_bus_layout.tres
├── project.godot
└── README.md
```

**Folder** | **Purpose** | **Subfolders**
-- | -- | --
addons/ | Contains Godot plugins | <ul><li>gut/</li></ul>
assets/ | Contains game asset files | <ul><li>2d/: fonts and icons (`icons/aos/` is the AoS icon pack, in `white/` and `black/`)</li><li>3d/: `placeholders/` holds placeholder materials</li><li>audio/</li><li>shaders/: `ui/` holds shaders for UI controls</li></ul>
data/ | Contains game data loaded at runtime, e.g. faction rules as JSON (see `docs/technical/faction-data.md`) | <ul><li>core/: core rules abilities, universal manifestation lores and the General's Handbook battlepack (see `docs/technical/core-rules-data.md`)<ul><li>spearhead/: a Spearhead battlepack per realm battlefield, e.g. `fire_and_jade.json`</li></ul></li><li>factions/</li><li>shared/: warscrolls and Armies of Renown used by several factions</li></ul>
docs/ | Contains all project documentation (index in `docs/README.md`) | <ul><li>design/</li><li>gameplay/</li><li>technical/</li></ul>
scenes/ | Contains Godot scene files. `main.tscn` is the main scene and owns screen flow | <ul><li>ui/</li><li>ui/forge/</li><li>ui/forge/builder/</li><li>ui/quick_play/</li><li>ui/battle/: the loading screen</li><li>battle/: the game map</li></ul>
scripts/ | Contains gdscript code. Script paths mirror their scene paths (e.g. `scenes/ui/main_menu.tscn` → `scripts/ui/main_menu.gd`); scripts without a scene are grouped by what they do | <ul><li>army/: armies built in the Forge, and the rules for building and checking them</li><li>battle/: setting up and showing a battle: `BattleSetup` (what the player chose in Quick Play), `BattleBuilder` and the `Battle` it makes, `PlaceholderDeployment`, the game map (`BattleMap`) and its camera<ul><li>map/: builders for the board, terrain and model placeholders</li></ul></li><li>settings/: the player's settings (`GameSettings`) and the remappable input actions (`InputBindings`)</li><li>data/: game data classes and their loaders<ul><li>rules/: the building blocks of rules shared by factions and the core rules: warscrolls, weapons, abilities, lores, enhancement tables and rules sections</li><li>faction/: factions, Grand Alliances, battle formations and Spearheads, with the faction catalog and loader</li><li>renown/: Armies of Renown with their rosters, and Regiments of Renown</li><li>core/: the core rules, the General's Handbook battlepack (battle tactics and battleplans) and the Spearhead battlepacks (realm battlefields, twist and battle tactic decks, deployment maps), with their catalog and loaders</li></ul></li><li>ui/: screens (`main_menu.gd`, `settings_screen.gd`)<ul><li>common/: the game-wide theme and control helpers with no scene of their own (`ui_theme.gd`, `ui_builder.gd`, `option_card.gd`, `dashed_style_box.gd`, `art_placeholder.gd`, `rules_formatter.gd`)</li><li>cards/: cards that show rules, used by the builder, faction browser and rules views (`AbilityCard`, `WarscrollCard`, `SummonedUnitCard`, `TacticCard`, `LoreCard`, `FormationCard`, `RenownArmyCard` and their base, `PressableCard`)</li><li>forge/</li><li>forge/builder/: the army builder and its parts</li><li>quick_play/: Quick Play's game mode and army screens, and the battleplan picker and map</li><li>battle/: the loading screen and the game map's overlay (`BattleHud`)</li></ul></li></ul>
test/ | Contains GUT tests | <ul><li>unit/</li><li>integration/</li><li>fixtures/: test data files</li><li>support/: shared test helpers, e.g. builders for small in-code factions and armies</li></ul>
tmp/ | Scratch output from `tools/`, e.g. `tools/store_360`. Gitignored, and has a `.gdignore` so Godot doesn't import it | <ul><li>store_360/: 360 degree view images</li><li>.browser-profile/: the Chromium profile `tools/store_360` uses</li></ul>
tools/ | Contains development scripts that aren't part of the game. Ignored by Godot (`tools/.gdignore`) | <ul><li>faction_import/: builds faction data from BSData and Wahapedia</li><li>icons/: generates icons the AoS icon pack lacks, e.g. `make_shield.py` for `assets/2d/icons/shield.svg` (`python3 tools/icons/make_shield.py assets/2d/icons/shield.svg`)</li><li>battleplan_maps/: reads objective, terrain and territory positions from the General's Handbook battleplan maps</li><li>spearhead_pdf/: extracts the text of Warhammer Community's Spearhead rules PDFs (`extract.py`) and prints a Spearhead from the faction data in the same order (`dump.py`), to check the data against an updated PDF</li><li>store_360/: downloads the 360 degree view images of a model from its warhammer.com store page (`python -I tools/store_360/fetch_360.py <url>`), into `tmp/store_360/<view>/` with a `manifest.json` of the rows (camera heights) and frames. The page is behind a bot check, so it opens a visible Chromium window (Playwright) with a profile saved in `tmp/.browser-profile/`; solve the CAPTCHA there if one appears</li><li>bsdata/: local BSData checkout (gitignored, cloned by the import tool)</li></ul>

Placeholder assets, which stand in until the real art exists, are prefixed `p_`, e.g. `assets/2d/p_realm_art.svg`, `assets/3d/placeholders/p_battlefield.tres` and `assets/shaders/p_territory.gdshader`. Replace them, and drop the prefix, as the art arrives.

`default_bus_layout.tres`, in the project root where Godot looks for it, defines the audio buses: Master, with BGM and SFX sending to it (see [Settings](../design/settings.md)).
