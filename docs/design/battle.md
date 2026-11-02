# Battle

After Quick Play's Play, the loading screen sets the battle up and builds the game map, then shows it. On the map, the roll-off decides who is the attacker, then both armies are deployed. The design is the "Quick Play Flow" canvas artifact: boards **3 · Loading**, **4 · Roll-off**, **5 · Deployment: faction terrain** and **6 · Deployment: armies**. The rules behind the roll-off and deployment are in [Deployment](../gameplay/deployment.md).

Art is placeholder for now, prefixed `p_` (see [Project layout](../technical/layout.md)).

## Setting the battle up

`BattleBuilder.build(setup, rng)` (`scripts/battle/battle_builder.gd`) turns the player's `BattleSetup` into a `Battle` (`scripts/battle/battle.gd`):

- **Random choices:**
  - In Matched Play, a Random battleplan is one of the battlepack's.
  - In Spearhead, a Random realm battlefield is any side of any Spearhead battlepack.
- **Left to the roll-off:** who is the attacker, and so each side's territory, and in Spearhead the deployment map and each side's terrain features (see [Deployment](../gameplay/deployment.md#roll-off)).
- **Armies** (`BattleArmy`, `BattleUnit`, `BattleRegiment`):
  - A Forge army's units come from its regiments and auxiliary units. Each has its warscroll's unit size in models, doubled if reinforced. Its points are `ArmyPoints.total()`, and its faction terrain comes with it.
  - Each of its regiments is a `BattleRegiment`, named after the regiment, its Regiment of Renown or "Regiment N". Auxiliary units are in none.
  - A Spearhead's units are its general and its units, with their counts, in no regiment. Their bases come from the faction's warscrolls of the same names (`Faction.find_warscroll()`), as a Spearhead's own warscrolls have no battle profile.
  - Each army has its deployment abilities (`DeploymentAbilities`).
  - In Spearhead, each player sets up the battlepack's terrain: in Sand and Bone, the defender takes terrain group A and the attacker B; in the other battlepacks each takes every feature that isn't mystical.
  - Each model has a base, from its warscroll's `base_size` (see [Base sizes](../technical/faction-data.md#base-sizes)), or 32mm if it has none.
- **Opponent:** the AI's army is a copy of the player's (`BattleArmy.mirror()`) until there's a way to choose one.
- **Battlefield:** Matched Play's is 60" × 44" (the battlepack's `battlefield`) and Spearhead's 30" × 22". The objectives and terrain are where the battleplan or realm battlefield puts them. A battleplan's terrain is a square 4" (small) or 6" (medium) wide, `MapFeature.TERRAIN_WIDTHS`. A Spearhead feature is a rectangle its `length` by `width` from the battlepack data, or 6" × 3" (large) and 3" × 2" (small) if the data gives none (`SpearheadTerrain.FOOTPRINTS`). Faction terrain takes its base's size, or its best guess for "Use model".

If the setup can't be used (e.g. its faction's data is missing), the loading screen emits `failed` and `Main` returns to the army step.

## Loading screen

Scene `scenes/ui/battle/loading_screen.tscn`, script `scripts/ui/battle/loading_screen.gd` (`LoadingScreen`), laid out for 1440 × 900 and styled by `UITheme`:

- **Background:** placeholder realm art (`assets/2d/p_realm_art.svg`), noted "[Realm art for the battleplan]".
- **Matchup:** "YOU" in blue with the army's name and "Faction · N pts" ("Faction · Spearhead" for a Spearhead), "VS" in gold, then "AI OPPONENT" in red with theirs.
- **Battleplan card:**
  - The map: a neutral `BattleplanMap`, or a `RealmMap` with no deployment map, as territories are blue and red only after the roll-off.
  - Its kind, e.g. "RANDOM BATTLE PLAN · TABLE 1" or "REALM BATTLEFIELD · FIRE AND JADE" ("RANDOM" when it was picked at random).
  - Its name.
  - The twist, or for a realm battlefield its side and battlepack, and that the defender picks the deployment map after the roll-off.
  - "5 objectives · 8 terrain features · 60" × 44"".
  - "Territories are shown neutral here: blue and red are assigned after the roll-off."
- **Progress:**
  - A spinner with the current step, e.g. "Placing terrain features · 5 of 8", and the percentage.
  - A gold bar (`LoadingBar`).
  - The checklist: Battlefield, Terrain, Objectives, Your models, Opponent's models. Done stages get a green check, and the current one a dot.
- **Tip:** the camera controls, with the keys as bound.

`open(setup)` builds the battle, then instantiates the game map and asks it for its build steps (`BattleMap.build_steps()`): one for the battlefield, one per terrain feature already on it, one for the objectives and one per unit, which loads the unit's 3D models ready for deployment.
- Steps run each frame for up to 12 ms, so the screen stays responsive.
- The screen shows for at least 1.5 seconds (`min_seconds`), then emits `finished(map)`.
- `finish()` runs the rest at once.
- If the screen is freed first, it frees the unfinished map.

## Game map

Scene `scenes/battle/battle_map.tscn`, script `scripts/battle/battle_map.gd` (`BattleMap`): a `Node3D` with a WorldEnvironment and a shadow-casting sun, to which the build steps add the board, terrain and objectives. `Main` then calls `start()`, which runs the phases below: the roll-off, the Spearhead deployment map, then deployment.

**Scale:** 1 Godot unit is 1 inch. The origin is the battlefield's north-west corner, with the data's x east (+X) and y south (+Z), so positions in inches from the data go straight into the world.

- **Board** (`BoardBuilder`): a slab the battlefield's size (`p_battlefield`).
  - Once the roll-off has decided them, each side's territory is striped and outlined, blue for the player and red for the opponent (`p_territory.gdshader`, its stripes moving each side's way). Until then there are none, and the camera looks at the whole battlefield.
  - The part of the player's territory too close to the enemy to deploy units in is shaded dark (`BoardBuilder.no_deploy`).
  - A realm battlefield has its printed board from the Spearhead Tabletop Simulator mod stretched over the top (`BoardBuilder.board_print`, from `assets/3d/boards/`), north at the top of the image, with its roads and objective markings printed on it. Without the board image (a checkout without Git LFS), its roads are drawn instead.
- **Objectives:**
  - A 40mm gold marker, its zone and its name.
  - The zone is Matched Play's 3" control range, or a Spearhead objective's own radius or rectangle.
- **Terrain** (`TerrainPlaceholder`): a block the feature's footprint in size, turned to face across its side's territory. Faction terrain with a 3D model (see [3D models](../technical/models.md)) is drawn as the model instead, with its textures (or in `p_model` if it has none). So is a Spearhead feature with a model: its long side along the footprint's length, centred on it and scaled evenly to fit inside it, so it covers the ground the rules use. A feature with more than one model (Ruined Domicile, Ravaged Shrine, Ruined Manor) shows one per player (`BattleTerrain.variant`).
  - Area terrain or obstacles are low slabs, obscuring terrain is tall and Places of Power are purple discs.
  - Spearhead features without a model are 1" or 2.5" tall.
  - Faction terrain is a disc on a round base, or a slab for "Use model".
  - Faction and Spearhead features are named.
- **Models** (`ModelPlaceholder`): each model has its base, so units take up the room they would on the tabletop. Round bases are discs and oval ones are discs stretched along the way the model faces. A "Use model" model is a slab its best-guess footprint in size.
  - Bases are blue for the player (`p_base_player`) and red for the opponent (`p_base_opponent`).
  - A unit whose name or warscroll has 3D models (`ModelLibrary`, see [3D models](../technical/models.md)) has them standing on its bases, facing the way the unit does, with their textures. A model without materials of its own is drawn blue-grey for the player (`p_model_player`) or red-grey for the opponent (`p_model_opponent`). A unit with several model variants gives them to its models in turn. Units without models are just their bases.
  - Each unit's models are one `MultiMeshInstance3D` per kind of base and per model mesh, with the unit's name floating above its tallest model, hidden from far away.
- **Overlay** (`BattleHud`, `scripts/ui/battle/battle_hud.gd`):
  - The header has, from the left:
    - The phase badge: "PRE-BATTLE", then "DEPLOYMENT".
    - In deployment, its steps: "Faction terrain › Armies › Abilities", or "Terrain › Armies › Abilities" in Spearhead. Steps done are ticked green and the current one is gold.
    - The battleplan's or realm's name.
    - The pills: "You" (blue) and "Opponent" (red). After the roll-off they say each side's role, e.g. "You · Attacker", and in deployment how much each side has left to set up, e.g. "· 2 left".
    - A settings gear at the top right, 20px in like the pills. Its tooltip names the first key bound to Back (`ui_cancel`), e.g. "Menu (Esc)", or is just "Menu" if Back has no key.
  - The camera controls are in the bottom-left corner, above the deployment tray while it shows. While a unit or terrain feature is being placed, they also list the placing keys.
  - The gear or Back (Esc by default) opens the menu.

### Roll-off

`RollOffPanel` (`scripts/ui/battle/roll_off_panel.gd`, board 4) opens over the dimmed battlefield as soon as the map shows.

- **Header:** "Roll-off", and "The winner picks who is the attacker. The attacker deploys first."
- **Dice:** the player's (blue pips, "YOU") and the opponent's (red pips, "OPPONENT") tumble for 0.9 seconds (`DieFace`), then land with their numbers below. A tie says "Tie: rolling again" and they roll again.
- **If the player won:** "You won the roll-off. Choose your role." with Attacker and Defender buttons.
  - Each button says what the role means, e.g. "Deploy first. Your territory is shown in blue."
  - In Matched Play, each has the battleplan's map with the player's territory for that role in blue.
- **If the AI won:** it says which role the AI chose and which the player has, with Continue.

### Deployment map (Spearhead)

If the player is the defender in Spearhead, `DeploymentMapPicker` (`scripts/ui/battle/deployment_map_picker.gd`) asks for the deployment map and the player's territory: a tab per map, the realm battlefield with that map's territories (A lighter than B), Territory A or B, and Confirm. If the AI defends, it picks both at random.

### Deployment

`DeploymentController` (`scripts/battle/deployment/deployment_controller.gd`) runs the phase on the map. `DeploymentHud` (`scripts/ui/battle/deployment_hud.gd`, boards 5 and 6) is its overlay. The rules are in [Deployment](../gameplay/deployment.md).

- **Banner,** top middle: "Your deployment · Set up your faction terrain", "Your deployment · Deploy Regiment: Admiral's Perch", "Opponent's deployment · Deploying units" (red edge), or "Deployment complete".
- **Side panels:** both are pinned to the screen's edges, 20px in and just under the header, whatever the window's size, so the middle of the board stays clear.
- **Deployment abilities,** on the left: the current step's abilities.
  - Each shows its source and what it does, or why it can't be used, e.g. "Unavailable: Tyrant on Glutthorn was deployed on its own".
  - Its status is "In use", "Used" or "Once per battle".
  - Reserve and recorded abilities are buttons that start using them. Their effect is the tooltip.
- **Placing,** on the right:
  - **A unit:** its name and model count, the regiment's units as chips while one is being deployed, and the formations with their keys, or "Single-model unit: pick it up and put it down, and turn it with R."
  - **A Spearhead army:** "Deploy your army", the picked unit's name and formations (or "Pick a unit on the board or in the tray…" while none is picked), and "Confirm deployment" for all of them. Undo is for the picked unit.
  - **A terrain feature:** its name, the rule for where it goes and how to move and turn it. If no spot left meets the gap from other terrain, it says the gap is waived.
  - **An ability:** its declare and effect, its targets as chips to pick and "Its use is recorded; its effect isn't applied yet." for one that isn't a reserve.
  - **Problems:** any problems, in red, e.g. "2 models are outside your deployable zone…".
  - **Buttons:** Undo (or Cancel for an ability), and Confirm with who goes next, e.g. "Confirm · opponent next". Confirm is disabled while there are problems.
  - **In the Abilities step:** "Done with abilities" ends the player's part of it.
- **Tray,** along the bottom: what's left to set up.
  - **Terrain step:** the faction terrain (or Spearhead terrain features).
  - **Armies step:** each regiment, its name a button that starts 'Deploy Regiment', with a tile per unit (a button for 'Deploy Unit'). Auxiliary units come last ("Units" in Spearhead).
  - **Tile badges:** "Deployed" or "In reserve: in the clouds".
  - **Regiment badges:** "Deploying", "Deployed", or "Deploy unit by unit" with the reason as its tooltip.

**Placing:**

- A unit or terrain feature picked from the tray starts in a valid spot if there is one, already picked up: it follows the mouse once the pointer is over the board, and a click puts it down. Clicking it again picks it up again, so it can be moved as often as needed before Confirm.
- Each model has a ring under it, and a terrain feature an outline around its footprint. While it's picked up they're blue where it can go and red where it can't, so the player can sweep it round to find a valid spot. Put down, they're green or red.
- The terrain step picks the next feature by itself, as there's nothing else to do.
- While a regiment is being deployed, its next unit is picked by itself after each Confirm.
- **Spearhead armies:** when the player's turn in the Armies step comes, all their units are set out at once, each in a valid spot clear of the others (`DeploymentController.stage_army()`, with `PlaceholderDeployment.spots_for_army()`; see [Deployment](../gameplay/deployment.md#the-ai)), but not yet deployed. Clicking any of them picks it up (and picks it for the formation and turn keys); clicking a tray tile picks it without picking it up. Every unit's rings are checked against the rules and the other units, the problems are listed with the unit's name, and "Confirm deployment" sets the whole army up together (`Deployment.place_army()`). Undo puts the picked unit back where it was when it was picked. A reserve ability can still be used first: its units leave the board and the rest stay where they are.

**Control** | **Does**
-- | --
Left-click a model of the unit, or the terrain feature | Pick it up; it follows the mouse
Alt + left-click a model | Pick up just that model
Left-click while holding something | Put it down there
1 to 5 (`formation_1`…`formation_5`) | Line, wide block, narrow block, loose, wedge, around the unit's middle
R (`rotate_selection`) | Turn the unit or feature 15°
Ctrl+Z (`undo_placement`), or Undo | Put it back where it started

**The AI's turn:** each action comes 0.6 seconds after the last, and its units and terrain appear on the board.

When both armies are deployed, the banner says "Deployment complete", the map stays explorable and `BattleMap` emits `deployment_finished`.

### Menu

`PauseMenu` (`scripts/ui/battle/pause_menu.gd`) opens over the map. The battlefield is dimmed, the header slides up out of view and the camera stops until the menu closes.

**Option** | **Does**
-- | --
Resume (or Back) | Closes the menu. The header slides back.
Settings | Opens the Settings screen over the map. Its Back returns to the menu, and the camera controls and the gear's tooltip show any keys rebound there.
Surrender (red) | A red button. Opens a dialog, "Are you sure?", that reads "Surrendering will result in a loss." with Cancel (focused) and Surrender. Cancel or Esc returns to the menu with Surrender focused; Surrender emits `surrendered`. For now `Main` returns to the main menu.
Save and Quit | Emits `save_and_quit_requested`. There's no saving yet, so `Main` returns to the main menu.

### Camera

`BattleCamera` (`scripts/battle/battle_camera.gd`) orbits a point on the board, which can't leave the battlefield. It starts behind the player's territory, looking towards the enemy.

**Control** | **Does**
-- | --
W A S D, or right-drag | Move the camera (`camera_forward`, `camera_left`, `camera_back`, `camera_right`)
Q E, or middle-drag | Turn the camera (`camera_rotate_left`, `camera_rotate_right`); middle-drag also tilts it
Wheel | Zoom, 6" to 90" away

The keys, and deployment's placing keys, are remappable in Settings › Input, Battle (see [Settings](settings.md#input)).

## Signals

**Signal** | **When**
-- | --
`ArmySelect.play_requested(setup)` | `Main.show_loading()` opens the loading screen.
`LoadingScreen.finished(map)` | The map is built. `Main.show_battle_map()` shows it in the loading screen's place and calls `BattleMap.start()`.
`RollOffPanel.role_chosen(player_attacks)` | The roll-off is settled. `BattleMap` assigns the roles, then shows the deployment map picker (Spearhead, player defends) or starts deployment.
`DeploymentMapPicker.chosen(map, player_has_a)` | `BattleMap` sets the territories and starts deployment.
`BattleMap.deployment_finished` | Both armies are deployed. Nothing listens yet: battle rounds come next.
`LoadingScreen.failed(message)` | The battle couldn't be set up. `Main` returns to the army step.
`BattleMap.surrendered` | Surrender in the game map's menu, once confirmed. `Main` returns to the main menu.
`BattleMap.save_and_quit_requested` | Save and Quit in the game map's menu. `Main` returns to the main menu.
