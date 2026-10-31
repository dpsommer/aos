# Battle

After Quick Play's Play, the loading screen sets the battle up and builds the game map, then shows it. The design is the "Quick Play Flow" canvas artifact: board **3 · Loading**, and the battlefield of boards **5 · Deployment: faction terrain** and **6 · Deployment: armies**. The roll-off and deployment screens (boards 4 to 6) come later. Until then the attacker is picked at random and both armies are set up for the player.

Art is placeholder for now, prefixed `p_` (see [Project layout](../technical/layout.md)).

## Setting the battle up

`BattleBuilder.build(setup, rng)` (`scripts/battle/battle_builder.gd`) turns the player's `BattleSetup` into a `Battle` (`scripts/battle/battle.gd`):

- **Random choices:**
  - In Matched Play, a Random battleplan is one of the battlepack's.
  - In Spearhead, a Random realm battlefield is any side of any Spearhead battlepack.
  - In Spearhead, the deployment map and which territory is whose are always picked at random (the defender's choice, for now).
- **Attacker:** picked at random. The player's territory is the attacker's or the defender's to match.
- **Armies** (`BattleArmy`, `BattleUnit`):
  - A Forge army's units come from its regiments and auxiliary units. Each has its warscroll's unit size in models, doubled if reinforced. Its points are `ArmyPoints.total()`, and its faction terrain comes with it.
  - A Spearhead's units are its general and its units, with their counts. Their bases come from the faction's warscrolls of the same names (`Faction.find_warscroll()`), as a Spearhead's own warscrolls have no battle profile.
  - Each player sets up the battlepack's terrain: in Sand and Bone, the defender takes terrain group A and the attacker B; in the other battlepacks each takes every feature that isn't mystical.
  - Each model has a base, from its warscroll's `base_size` (see [Base sizes](../technical/faction-data.md#base-sizes)), or 32mm if it has none.
- **Opponent:** the AI's army is a copy of the player's (`BattleArmy.mirror()`) until there's a way to choose one.
- **Battlefield:** Matched Play's is 60" × 44" (the battlepack's `battlefield`) and Spearhead's 30" × 22". The objectives and terrain are where the battleplan or realm battlefield puts them. A battleplan's terrain is a square 4" (small) or 6" (medium) wide, `MapFeature.TERRAIN_WIDTHS`. A Spearhead feature is 3" (small) or 6" (large), `SpearheadTerrain.WIDTHS`. Faction terrain takes its base's size, or its best guess for "Use model".

If the setup can't be used (e.g. its faction's data is missing), the loading screen emits `failed` and `Main` returns to the army step.

### Placeholder deployment

`PlaceholderDeployment.deploy(battle)` (`scripts/battle/placeholder_deployment.gd`) sets both armies up:

1. **Terrain:** each side's terrain features go wholly within its territory, nearest its middle. They're more than 3" from objectives and other terrain, or as far as the territory allows.
2. **Units:** each side's units go in blocks, filling the territory from the edge farthest from the enemy, then from the middle out along each rank.
   - A block's front rank is up to 10 models wide, in two ranks from 6 models.
   - A unit's models are ½" apart, and each unit is 1" clear of other units and terrain.
   - Every base is wholly within the territory.
   - A unit with no room for a block has each model set up wherever it fits.
3. **Facing:** models face the enemy territory.

## Loading screen

Scene `scenes/ui/battle/loading_screen.tscn`, script `scripts/ui/battle/loading_screen.gd` (`LoadingScreen`), laid out for 1440 × 900 and styled by `UITheme`:

- **Background:** placeholder realm art (`assets/2d/p_realm_art.svg`), noted "[Realm art for the battleplan]".
- **Matchup:** "YOU" in blue with the army's name and "Faction · N pts" ("Faction · Spearhead" for a Spearhead), "VS" in gold, then "AI OPPONENT" in red with theirs.
- **Battleplan card:**
  - The map: a neutral `BattleplanMap`, or a `RealmMap` with no deployment map, as territories are blue and red only after the roll-off.
  - Its kind, e.g. "RANDOM BATTLE PLAN · TABLE 1" or "REALM BATTLEFIELD · FIRE AND JADE" ("RANDOM" when it was picked at random).
  - Its name.
  - The twist, or for a realm battlefield its side, battlepack and deployment map.
  - "5 objectives · 8 terrain features · 60" × 44"".
  - "Territories are shown neutral here: blue and red are assigned after the roll-off."
- **Progress:**
  - A spinner with the current step, e.g. "Placing terrain features · 5 of 8", and the percentage.
  - A gold bar (`LoadingBar`).
  - The checklist: Battlefield, Terrain, Objectives, Your models, Opponent's models. Done stages get a green check, and the current one a dot.
- **Tip:** the camera controls, with the keys as bound.

`open(setup)` builds the battle, then instantiates the game map and asks it for its build steps (`BattleMap.build_steps()`): one for the battlefield, one per terrain feature, one for the objectives and one per unit.
- Steps run each frame for up to 12 ms, so the screen stays responsive.
- The screen shows for at least 1.5 seconds (`min_seconds`), then emits `finished(map)`.
- `finish()` runs the rest at once.
- If the screen is freed first, it frees the unfinished map.

## Game map

Scene `scenes/battle/battle_map.tscn`, script `scripts/battle/battle_map.gd` (`BattleMap`): a `Node3D` with a WorldEnvironment and a shadow-casting sun, to which the build steps add the rest.

**Scale:** 1 Godot unit is 1 inch. The origin is the battlefield's north-west corner, with the data's x east (+X) and y south (+Z), so positions in inches from the data go straight into the world.

- **Board** (`BoardBuilder`): a slab the battlefield's size (`p_battlefield`).
  - Each side's territory is striped and outlined, blue for the player and red for the opponent (`p_territory.gdshader`, its stripes moving each side's way).
  - Realm battlefields have their roads.
- **Objectives:**
  - A 40mm gold marker, its zone and its name.
  - The zone is Matched Play's 3" control range, or a Spearhead objective's own radius or rectangle.
- **Terrain** (`TerrainPlaceholder`): a block the feature's footprint in size, turned to face across its side's territory.
  - Area terrain or obstacles are low slabs, obscuring terrain is tall and Places of Power are purple discs.
  - Spearhead features are 1" or 2.5" tall.
  - Faction terrain is a disc on a round base, or a slab for "Use model".
  - Faction and Spearhead features are named.
- **Models** (`ModelPlaceholder`): each model is its base, so units take up the room they would on the tabletop. Round bases are discs and oval ones are discs stretched along the way the model faces. A "Use model" model is a slab its best-guess footprint in size.
  - Bases are blue for the player (`p_base_player`) and red for the opponent (`p_base_opponent`).
  - Each unit's models are one `MultiMeshInstance3D` per kind of base, with the unit's name floating above them, hidden from far away.
- **Overlay** (`BattleHud`, `scripts/ui/battle/battle_hud.gd`):
  - The header has Menu, the battleplan's or realm's name, and pills "You · Attacker" (blue) and "Opponent · Defender" (red), or the other way round.
  - The camera controls are in the bottom-left corner.
  - Menu or Esc emits `menu_requested`, and `Main` returns to the main menu.

### Camera

`BattleCamera` (`scripts/battle/battle_camera.gd`) orbits a point on the board, which can't leave the battlefield. It starts behind the player's territory, looking towards the enemy.

**Control** | **Does**
-- | --
W A S D, or right-drag | Move the camera (`camera_forward`, `camera_left`, `camera_back`, `camera_right`)
Q E, or middle-drag | Turn the camera (`camera_rotate_left`, `camera_rotate_right`); middle-drag also tilts it
Wheel | Zoom, 6" to 90" away

The keys are remappable in Settings › Input, Battle (see [Settings](settings.md#input)).

## Signals

**Signal** | **When**
-- | --
`ArmySelect.play_requested(setup)` | `Main.show_loading()` opens the loading screen.
`LoadingScreen.finished(map)` | The map is built. `Main.show_battle_map()` shows it in the loading screen's place.
`LoadingScreen.failed(message)` | The battle couldn't be set up. `Main` returns to the army step.
`BattleMap.menu_requested` | Menu or Esc on the game map. `Main` returns to the main menu.
