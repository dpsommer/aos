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
├── project.godot
└── README.md
```

**Folder** | **Purpose** | **Subfolders**
-- | -- | --
addons/ | Contains Godot plugins | <ul><li>gut/</li></ul>
assets/ | Contains game asset files | <ul><li>2d/</li><li>3d/</li><li>audio/</li><li>shaders/</li></ul>
data/ | Contains game data loaded at runtime, e.g. faction rules as JSON (see `docs/technical/faction-data.md`) | <ul><li>core/: core rules abilities, universal manifestation lores and the General's Handbook battlepack (see `docs/technical/core-rules-data.md`)</li><li>factions/</li><li>shared/: warscrolls and Armies of Renown used by several factions</li></ul>
docs/ | Contains all project documentation (index in `docs/README.md`) | <ul><li>design/</li><li>gameplay/</li><li>technical/</li></ul>
scenes/ | Contains Godot scene files. `main.tscn` is the main scene and owns screen flow | <ul><li>ui/</li><li>ui/forge/</li></ul>
scripts/ | Contains gdscript code. Script paths mirror their scene paths (e.g. `scenes/ui/main_menu.tscn` → `scripts/ui/main_menu.gd`) | <ul><li>data/: game data classes, the faction catalog and the faction and core rules loaders</li><li>ui/</li><li>ui/forge/</li></ul>
test/ | Contains GUT tests | <ul><li>unit/</li><li>integration/</li><li>fixtures/: test data files</li></ul>
tools/ | Contains development scripts that aren't part of the game. Ignored by Godot (`tools/.gdignore`) | <ul><li>faction_import/: builds faction data from BSData and Wahapedia</li><li>battleplan_maps/: reads objective, terrain and territory positions from the General's Handbook battleplan maps</li><li>bsdata/: local BSData checkout (gitignored, cloned by the import tool)</li></ul>
