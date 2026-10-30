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
├── tools/
├── default_bus_layout.tres
├── project.godot
└── README.md
```

**Folder** | **Purpose** | **Subfolders**
-- | -- | --
addons/ | Contains Godot plugins | <ul><li>gut/</li></ul>
assets/ | Contains game asset files | <ul><li>2d/: fonts and icons (`icons/aos/` is the AoS icon pack, in `white/` and `black/`)</li><li>3d/</li><li>audio/</li><li>shaders/: `ui/` holds shaders for UI controls</li></ul>
data/ | Contains game data loaded at runtime, e.g. faction rules as JSON (see `docs/technical/faction-data.md`) | <ul><li>core/: core rules abilities, universal manifestation lores and the General's Handbook battlepack (see `docs/technical/core-rules-data.md`)</li><li>factions/</li><li>shared/: warscrolls and Armies of Renown used by several factions</li></ul>
docs/ | Contains all project documentation (index in `docs/README.md`) | <ul><li>design/</li><li>gameplay/</li><li>technical/</li></ul>
scenes/ | Contains Godot scene files. `main.tscn` is the main scene and owns screen flow | <ul><li>ui/</li><li>ui/forge/</li><li>ui/forge/builder/</li></ul>
scripts/ | Contains gdscript code. Script paths mirror their scene paths (e.g. `scenes/ui/main_menu.tscn` → `scripts/ui/main_menu.gd`); scripts without a scene are grouped by what they do | <ul><li>army/: armies built in the Forge, and the rules for building and checking them</li><li>settings/: the player's settings (`GameSettings`) and the remappable input actions (`InputBindings`)</li><li>data/: game data classes and their loaders<ul><li>rules/: the building blocks of rules shared by factions and the core rules: warscrolls, weapons, abilities, lores, enhancement tables and rules sections</li><li>faction/: factions, Grand Alliances, battle formations and Spearheads, with the faction catalog and loader</li><li>renown/: Armies of Renown with their rosters, and Regiments of Renown</li><li>core/: the core rules and the General's Handbook battlepack (battle tactics and battleplans), with their catalog and loader</li></ul></li><li>ui/: screens (`main_menu.gd`, `settings_screen.gd`)<ul><li>common/: the game-wide theme and control helpers with no scene of their own (`ui_theme.gd`, `ui_builder.gd`, `option_card.gd`, `dashed_style_box.gd`, `art_placeholder.gd`, `rules_formatter.gd`)</li><li>cards/: cards that show rules, used by the builder, faction browser and rules views (`AbilityCard`, `WarscrollCard`, `SummonedUnitCard`, `TacticCard`, `LoreCard`, `FormationCard`, `RenownArmyCard` and their base, `PressableCard`)</li><li>forge/</li><li>forge/builder/: the army builder and its parts</li></ul></li></ul>
test/ | Contains GUT tests | <ul><li>unit/</li><li>integration/</li><li>fixtures/: test data files</li><li>support/: shared test helpers, e.g. builders for small in-code factions and armies</li></ul>
tools/ | Contains development scripts that aren't part of the game. Ignored by Godot (`tools/.gdignore`) | <ul><li>faction_import/: builds faction data from BSData and Wahapedia</li><li>icons/: generates icons the AoS icon pack lacks, e.g. `make_shield.py` for `assets/2d/icons/shield.svg` (`python3 tools/icons/make_shield.py assets/2d/icons/shield.svg`)</li><li>battleplan_maps/: reads objective, terrain and territory positions from the General's Handbook battleplan maps</li><li>bsdata/: local BSData checkout (gitignored, cloned by the import tool)</li></ul>

`default_bus_layout.tres`, in the project root where Godot looks for it, defines the audio buses: Master, with BGM and SFX sending to it (see [Settings](../design/settings.md)).
