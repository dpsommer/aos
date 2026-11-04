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
.githooks/ | Git hooks, enabled with `git config core.hooksPath .githooks` | <ul><li>pre-push: runs the refactor skills on the `.gd` files a push changes, then Git LFS (see `docs/technical/testing.md`)</li><li>post-checkout, post-commit, post-merge: Git LFS's hooks</li></ul>
assets/ | Contains game asset files | <ul><li>2d/: fonts and icons (`icons/aos/` is the AoS icon pack, in `white/` and `black/`), and `portraits/`, the unit icons baked from the models, stored in Git LFS (see `docs/technical/models.md`)</li><li>3d/: `placeholders/` holds placeholder materials; `models/` holds unit, manifestation and faction terrain models with their `.mtl` materials and `textures/`, in `<alliance>/<faction>/`, `shared/manifestations/` and `shared/spearhead/` (Spearhead terrain features and relics), stored in Git LFS (see `docs/technical/models.md`); `boards/` holds the Spearhead realm battlefields' printed boards, also in Git LFS</li><li>audio/</li><li>shaders/: `ui/` holds shaders for UI controls</li></ul>
data/ | Contains game data loaded at runtime, e.g. faction rules as JSON (see `docs/technical/faction-data.md`) | <ul><li>core/: core rules abilities, universal manifestation lores and the General's Handbook battlepack (see `docs/technical/core-rules-data.md`)<ul><li>spearhead/: a Spearhead battlepack per realm battlefield, e.g. `fire_and_jade.json`</li></ul></li><li>factions/</li><li>shared/: warscrolls and Armies of Renown used by several factions</li></ul>
docs/ | Contains all project documentation (index in `docs/README.md`) | <ul><li>design/</li><li>gameplay/</li><li>technical/</li></ul>
scenes/ | Contains Godot scene files. `main.tscn` is the main scene and owns screen flow. Every visible element is a scene (see [UI scenes](ui-scenes.md)) | <ul><li>ui/: the main menu and Settings</li><li>ui/common/: shared pieces, e.g. `option_card.tscn`, `art_placeholder.tscn`, `chip.tscn`, `banner_button.tscn`, `switch_row.tscn`, `setting_row.tscn`</li><li>ui/cards/: the rules cards and their parts (weapon tables, stat boxes, tactic rows)</li><li>ui/settings/: Settings' rows (reset, slider, key binding)</li><li>ui/forge/: the Forge, its cards and rows, and the faction browser</li><li>ui/forge/builder/: the army builder and its parts</li><li>ui/quick_play/: Quick Play's screens, pickers and their cards</li><li>ui/battle/: the loading screen and the game map's overlays, menus and their parts</li><li>battle/: the game map</li></ul>
scripts/ | Contains gdscript code. Script paths mirror their scene paths (e.g. `scenes/ui/main_menu.tscn` → `scripts/ui/main_menu.gd`); scripts without a scene are grouped by what they do | <ul><li>army/: armies built in the Forge, and the rules for building and checking them</li><li>battle/: setting up and showing a battle: `BattleSetup` (what the player chose in Quick Play), `BattleBuilder` and the `Battle` it makes with its armies and regiments, `PlaceholderDeployment` (automatic set-up), the game map (`BattleMap`) and its camera<ul><li>map/: builders for the board, terrain and models, and `ModelLibrary`, which finds a warscroll's 3D models</li><li>deployment/: the roll-off and the deployment phase: its rules (`Deployment`, `DeploymentRules`, `Coherency`, `Formations`, `DeploymentAbility`, `DeploymentAbilities`), the AI's mirroring (`MirrorDeployer`) and `DeploymentController`, which runs it on the game map</li></ul></li><li>settings/: the player's settings (`GameSettings`) and the remappable input actions (`InputBindings`)</li><li>data/: game data classes and their loaders<ul><li>rules/: the building blocks of rules shared by factions and the core rules: warscrolls, weapons, abilities, lores, enhancement tables and rules sections</li><li>faction/: factions, Grand Alliances, battle formations and Spearheads, with the faction catalog and loader</li><li>renown/: Armies of Renown with their rosters, and Regiments of Renown</li><li>core/: the core rules, the General's Handbook battlepack (battle tactics and battleplans) and the Spearhead battlepacks (realm battlefields, twist and battle tactic decks, deployment maps), with their catalog and loaders</li></ul></li><li>ui/: screens (`main_menu.gd`, `settings_screen.gd`)<ul><li>common/: the game-wide theme and control helpers (`ui_theme.gd`, `ui_builder.gd`, `unit_portraits.gd`, `dashed_style_box.gd`, `inline_line.gd`, `rules_formatter.gd`), and the scripts of the shared scenes (`option_card.gd`, `art_placeholder.gd`, `check_badge.gd`)</li><li>cards/: cards that show rules, used by the builder, faction browser and rules views (`AbilityCard`, `WarscrollCard`, `SummonedUnitCard`, `TacticCard`, `LoreCard`, `FormationCard`, `RenownArmyCard` and their base, `PressableCard`)</li><li>forge/</li><li>forge/builder/: the army builder and its parts</li><li>quick_play/: Quick Play's game mode and army screens, and the battleplan picker and map</li><li>battle/: the loading screen and its `Spinner`, and the game map's overlays (`BattleHud`, `PauseMenu`, `RollOffPanel` with its `DieFace`s and `RoleButton`s, `SpearheadOptionsPicker`, `DeploymentMapPicker`, `DeploymentHud`)</li></ul></li></ul>
test/ | Contains GUT tests | <ul><li>unit/</li><li>integration/</li><li>fixtures/: test data files</li><li>support/: shared test helpers, e.g. builders for small in-code factions and armies</li></ul>
tmp/ | Scratch output from `tools/`, e.g. `tools/store_360`. Gitignored, and has a `.gdignore` so Godot doesn't import it | <ul><li>store_360/: 360 degree view images</li><li>.browser-profile/: the Chromium profile `tools/store_360` uses</li></ul>
tools/ | Contains development scripts that aren't part of the game. Ignored by Godot (`tools/.gdignore`) | <ul><li>faction_import/: builds faction data from BSData and Wahapedia</li><li>icons/: generates icons the AoS icon pack lacks, e.g. `make_shield.py` for `assets/2d/icons/shield.svg` (`python3 tools/icons/make_shield.py assets/2d/icons/shield.svg`)</li><li>battleplan_maps/: reads objective, terrain and territory positions from the General's Handbook battleplan maps</li><li>spearhead_pdf/: extracts the text of Warhammer Community's Spearhead rules PDFs (`extract.py`) and prints a Spearhead from the faction data in the same order (`dump.py`), to check the data against an updated PDF</li><li>store_360/: downloads the 360 degree view images of a model from its warhammer.com store page (`python -I tools/store_360/fetch_360.py <url>`), into `tmp/store_360/<view>/` with a `manifest.json` of the rows (camera heights) and frames. The page is behind a bot check, so it opens a visible Chromium window (Playwright) with a profile saved in `tmp/.browser-profile/`; solve the CAPTCHA there if one appears</li><li>portraits/: renders the unit icons in `assets/2d/portraits/` from the models (`bake_portraits.gd`, see `docs/technical/models.md`)</li><li>tts_models/: builds `assets/3d/models/` from a Tabletop Simulator mod straight from Tabletop Simulator's cache (units from the Ulthuan mod; Spearhead terrain, relics and `assets/3d/boards/` from the Spearhead mod) (`build_models.py`, with `bundles.py` for asset bundles; see `docs/technical/models.md`)</li><li>bsdata/: local BSData checkout (gitignored, cloned by the import tool)</li></ul>

Placeholder assets, which stand in until the real art exists, are prefixed `p_`, e.g. `assets/2d/p_realm_art.svg`, `assets/3d/placeholders/p_battlefield.tres` and `assets/shaders/p_territory.gdshader`. Replace them, and drop the prefix, as the art arrives.

`default_bus_layout.tres`, in the project root where Godot looks for it, defines the audio buses: Master, with BGM and SFX sending to it (see [Settings](../design/settings.md)).
