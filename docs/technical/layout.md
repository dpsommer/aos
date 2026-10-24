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
├── docs/
│   ├── technical/
│   ├── design/
│   └── gameplay/
├── scenes/
├── scripts/
├── test/
├── project.godot
└── README.md
```

**Folder** | **Purpose** | **Subfolders**
-- | -- | --
addons/ | Contains Godot plugins | <ul><li>gut/</li></ul>
assets/ | Contains game asset files | <ul><li>2d/</li><li>3d/</li><li>audio/</li><li>shaders/</li></ul>
docs/ | Contains all project documentation (index in `docs/README.md`) | <ul><li>design/</li><li>gameplay/</li><li>technical/</li></ul>
scenes/ | Contains Godot scene files. `main.tscn` is the main scene and owns screen flow | <ul><li>ui/</li><li>ui/forge/</li></ul>
scripts/ | Contains gdscript code. Script paths mirror their scene paths (e.g. `scenes/ui/main_menu.tscn` → `scripts/ui/main_menu.gd`) | <ul><li>data/: game data such as Grand Alliances and the faction catalog</li><li>ui/</li><li>ui/forge/</li></ul>
test/ | Contains GUT tests | <ul><li>unit/</li><li>integration/</li></ul>
