# 3D models

Unit, manifestation, faction terrain and Spearhead terrain models live in `assets/3d/models/`, one Wavefront `.obj` per model, imported by Godot's OBJ importer as a `Mesh`. `ModelLibrary` (`scripts/battle/map/model_library.gd`) finds them by name, and the game map stands them on their bases (see [Battle](../design/battle.md#game-map)).

## Folders

```text
assets/3d/models/
├── <alliance>/<faction>/   # order, chaos, death, destruction; faction ids as in data/factions/
└── shared/
    ├── manifestations/     # the universal manifestations in data/core/manifestation_lores.json
    └── spearhead/          # Spearhead terrain features and relics (data/core/spearhead/)
```

The Spearhead realm battlefields' printed boards are in `assets/3d/boards/`, one `.jpg` per realm named as a slug (`ashen_bastion.jpg`). See [Spearhead terrain and boards](#spearhead-terrain-and-boards).

- A model goes in the folder of the faction whose warscroll it is. A unit two factions share (Fyreslayers' and Khazalite Holds' Auric Runefather) goes in the one that isn't Legends.
- A shared warscroll (`data/shared/warscrolls.json`, e.g. the Orruk manifestations) goes in the first faction that lists it.
- Faction manifestations and faction terrain go in their faction's folder, like units.

The folder is only for people: `ModelLibrary` finds a file anywhere under `assets/3d/models/`.

## File names

A model's file name is its warscroll's name as a slug (`ModelLibrary.slug()`): lower case, apostrophes dropped, and every run of other characters an underscore. "Skabbik's Plaguepack" is `skabbiks_plaguepack.obj`, and "Arkhan the Black, Mortarch of Sacrament" is `arkhan_the_black_mortarch_of_sacrament.obj`.

- **Variants:** a unit whose models differ has numbered files, `vulkyn_flameseekers_1.obj`, `_2` and so on, with no file of the bare name. The battle gives them to the unit's models in turn, so a unit of 10 with 3 variants has 4, 3 and 3 of each.
- **One file per model:** every file is a whole model, its pieces joined (the Arkanaut Frigate's two halves, a Mega-Gargant's legs and body), or the battle would show each piece as a separate variant.
- **Weapon options:** a warscroll named "X with Y" (e.g. "Vulkite Berzerkers with Fyresteel Weapons") falls back to the model of X when it has none of its own, so a model whose weapons can't be told apart can be named for the unit alone.
- **Aliases:** `ModelLibrary.ALIASES` gives the models of a warscroll with none of its own, by slug, for a warscroll that's the same miniature as another under a different name: a different spelling (Maulbeast Cavalry uses `maulbeast_raiders`), another faction's or a Regiment's copy (Legion of the First Prince Bloodletters uses `bloodletters`), a warscroll for fewer models (Crypt Horrors (2 Models) uses `crypt_horrors`), or a Spearhead's unit with no weapon option in its name, which uses the option that Spearhead has (Kurnoth Hunters uses `kurnoth_hunters_with_greatbows`). A warscroll that's a different miniature, such as Skabbik's Plaguepack or Tzaangor Enlightened on Foot, has no alias, even with a similar name.
- **Lookup order:** a unit's own name, then its warscroll's (a Spearhead unit's name matches its faction's warscroll); a faction terrain feature's name, then its warscroll's. The first name with a model wins.

## Conventions

The models come from a Tabletop Simulator mod (see [Building the models](#building-the-models)), so they share its conventions:

- **Scale:** 1 unit is 1 inch, the game's scale, so a 25mm base is 0.98 units across.
- **Axes:** Y up, the model's front towards -Z.
- **Origin:** the middle of the model's own base, with its lowest point at about y = 0. The battle drops each model so its lowest point rests on the coloured base, whatever its origin height.
- **Textures:** each model's `.obj` has a `.mtl` beside it with a material per piece texture (or plain colour), whose images are in its folder's `textures/`: `.jpg`, or `.png` for a cutout (a texture with see-through parts, whose material's name ends in `_cutout`). A texture is written once, by the first model that uses it, so a model's `.mtl` can point into another folder's `textures/`. Textures are at most 1024 pixels on a side, imported with mipmaps and VRAM compression (their `.import` files are written with the textures). `ModelLibrary.prepare()` makes a model's materials draw both sides of each face, as some scans have flipped faces, and turns on alpha scissor for cutouts.
- **Placeholder materials:** a model with no materials of its own (a test fixture, or a hand-made `.obj` without a `.mtl`) is drawn with `p_model_player` (blue-grey), `p_model_opponent` (red-grey) or `p_model` (faction terrain), which also draw both sides of each face. Textured models look the same for both players; their coloured bases tell them apart.

## Building the models

`tools/tts_models/build_models.py` builds the whole folder from the [Ulthuan](https://steamcommunity.com/sharedfiles/filedetails/?id=3202337953) Tabletop Simulator mod, reading everything from Tabletop Simulator's cache, its `Mods` folder (`~/Library/Tabletop Simulator/Mods` on macOS, `Documents/My Games/Tabletop Simulator/Mods` on Windows, unless Tabletop Simulator's settings move it): the save from `Workshop/`, the `.obj` meshes from `Models/`, their textures from `Images/` and the models the mod ships as Unity asset bundles (the Arkanaut Ironclad, Lord-Celestant on Stardrake, Megaboss on Maw-krusha and about 240 more) from `Assetbundles/`. Subscribe to the mod and load it once in Tabletop Simulator so it downloads them all.

The script needs Pillow and [UnityPy](https://pypi.org/project/UnityPy/) (`tools/tts_models/requirements.txt`), installed in the `aos` pyenv virtualenv (UnityPy needs a Python built with `lzma`). Pass the `Mods` folder first:

```sh
python -I tools/tts_models/build_models.py "$HOME/Library/Tabletop Simulator/Mods" > tmp/tts_models_build.json
godot --headless --import
```

It writes a file in `assets/3d/models/` only when its content changes, so Godot reimports only what did, and prints a report of which nickname went to which file and which files changed. A full build deletes the files it no longer makes (with their `.import` files); `--dry` only reports.

- **One unit at a time:** `--only <warscroll>` (repeatable) builds just those units and deletes nothing, e.g. `--only "Arkanaut Ironclad"` to check a change before building everything. It takes seconds; a full build takes about 7 minutes.
- **UIDs:** the `.import` files Godot writes are left alone, so UIDs don't change between builds. A texture's `.import` file is written only once, with its import settings.
- **Failed imports:** Godot doesn't retry a file whose import failed (`valid=false` in its `.import` file) even when it changes, so the build drops that line when it rewrites the file.
- **Materials:** Godot doesn't reimport an `.obj` when only its `.mtl` changes, so each `.obj`'s first line has its `.mtl`'s hash.
- **Textures:** a texture goes in the `textures/` folder of the first model in the save that uses it, named for that model, so its name doesn't depend on which units are built. An asset bundle's further textures add `_2`, `_3` and so on.

A workshop id or save path after the `Mods` folder picks another mod. Close the Godot editor during a full build, as it reimports files while they're being written.

How it works:

- **Models:** each faction tile in the save spawns its models from JSON kept in its Lua script. A model is a `Custom_Model` (often just a base) with the model's pieces attached as child objects, each with its own position, rotation and scale; asset bundle models are `Custom_Assetbundle` children. The pieces are joined into one mesh with their transforms (Tabletop Simulator is Unity, so `.obj` files have X mirrored, and rotations are Euler angles applied Z, X, then Y). Pieces no taller than 0.35" (bases, toppers, colliders) are left out, as the game draws its own bases. The mod lines each piece up with the root's base, so a ship lies along its oval base and the origin is the middle of the base, but the meshes face every way, and the mod turns each model's root on the table to make it face forwards (a Skywarden's root at 90°, one with a Skyrigger Heavy Weapon at 225°). So the mesh takes the root's turn about Y, which makes every model face -Z, but not its position or tilt, which only place it on the table. A model's other states take the turn of the object they replace, as Tabletop Simulator gives them its transform, and a model whose copies are turned differently takes the commonest turn. A model on an oval base already lies along its oval, as the game has it face along the oval, but the mod often shows one side-on (a Freeguild Cavalier-Marshal at 90°), so its turn is only taken to the nearest half turn: 180° turns it round, and 90° or 270° leaves it be. The mod turns some models the wrong way itself (its Arkanaut Company and Champion face the other way to the rest of the unit), so `turns.json` gives further turns by file name (`"arkanaut_company_1": 180`), in degrees anticlockwise seen from above. A model's file name is its place among its unit's variants, so check the entry still names the right model if a unit's variants change. Spearhead terrain keeps its own frame, as the game fits it to its feature's footprint.
- **Asset bundles:** `bundles.py` reads a bundle's rendered meshes (each on an enabled `MeshRenderer`) with their transforms, and their materials' main texture and colour.
- **Normals:** every face gets a normal and texture coordinates, as Godot can't import a surface where only some faces have them, or make tangents for a textured surface without normals. A face without a normal gets its vertices' smooth normals, and one without texture coordinates gets (0, 0).
- **Textures:** a `.obj` piece's texture is its `DiffuseURL` and its colour `ColorDiffuse`; an asset bundle's come from its materials. Normal maps are left out.
- **Names:** a model's nickname (e.g. "Chaos Warrior Champion (Scourge of Aqshy)", "Darkoath Fellrider w/Javelins") is matched to a warscroll in `data/`, among the factions of the tile it's on. Scourge tags, "w/" loadouts, counts such as "5/5" and roles (Champion, Musician, Standard Bearer, Banner) are dropped, then the name is matched exactly, as a plural, as the start of a single warscroll's name, or closely (`difflib`, 0.86). `overrides.json` gives the warscroll for nicknames that don't match that way, or `skip` for companions with no model of their own (Klonk, Thexa, Blot Toads). A target of `x:<faction>:<Name>` files a model under that faction with a name that isn't a warscroll's.
- **Variants:** a unit's different models (a champion, a musician, other poses or paint schemes) are its numbered variants. Copies of the same model are kept once.

Units with no model are drawn as their bases.

### Spearhead terrain and boards

The [Age of Sigmar Spearhead](https://steamcommunity.com/sharedfiles/filedetails/?id=3352713596) mod has the Spearhead battlepacks' terrain features, relics and realm battlefields. Load it once in Tabletop Simulator, and switch the battlefield tile through each of its states (Aqshy, Ghyran, Ossia, Dolorum, Ashen Bastion, Shattered Crossroads) so Tabletop Simulator caches every board. Then build them with the same script:

```sh
python -I tools/tts_models/build_models.py "$HOME/Library/Tabletop Simulator/Mods" 3352713596 > tmp/tts_spearhead_build.json
godot --headless --import
```

The mod's workshop id is in `SPEARHEAD_MODS`, so it's built this way automatically; `--spearhead` does it for another save.

- **Models:** only the objects on the table are read (not the units in the faction bags). A model's nickname is matched to a terrain feature or relic in `data/core/spearhead/` by name, without a bracketed realm ("Crypt of Blood (Ossia)"). They go in `shared/spearhead/`, with flat pieces kept (a manhole is flat). Ruined Domicile, Ravaged Shrine and Ruined Manor have two models each, `_1` and `_2`. The City of Ash relics have a plain grey texture in the mod.
- **Boards:** each state of the battlefield tile named for a realm battlefield is written to `assets/3d/boards/<realm>.jpg`, scaled down to 4096 pixels on its long side. The image covers the battlefield exactly, north at the top. The report lists any board not in the cache under `missing_boards`.
- **Cleaning up:** a Spearhead build only deletes stale files in `shared/spearhead/` and `assets/3d/boards/`, and a unit build never deletes anything in `shared/spearhead/`.
- **Size:** in game a model is fitted to its feature's footprint from the battlepack data (see [Battle](../design/battle.md#game-map)), so the rules and the model agree. Scuttletide has none, as its asset bundle isn't in the cache.

## Portraits

Unit icons (`UIBuilder.portrait()`) are renders of the models, baked ahead of time, as loading a whole model and its textures for every icon in a list would be too slow. `tools/portraits/bake_portraits.gd` writes them to `assets/2d/portraits/`, and bakes again after a model changes:

```sh
godot --path . -s tools/portraits/bake_portraits.gd -- [--only "<warscroll>"]...
godot --headless --import
```

It opens a window, as `--headless` has no renderer to draw with. It only reads the imported models, so it doesn't rebuild or reimport any. It doesn't delete portraits whose models have gone.

- **What's baked:** a unit's only model or its first variant (`x` or `x_1`). Spearhead terrain in `shared/spearhead/` and later variants have none. `--only` bakes just the named units.
- **The picture:** a close-up from straight in front, in an orthographic view, framed around the model's head so that units look alike, with the face in the upper half and the base out of sight. The tool first renders the model's depth (`find_head()`). It leaves out anything well behind the body (packs, wings) and to its sides (weapons), then takes the highest row wide enough to be a head, which skips spears and staffs. The view is centred on the body and as wide as the model from the head down, but between 50% and 75% of the height from the head to the feet, so a wide model is cut off at the sides. It shows at most 18% of the picture above the head, so whatever rises higher is cut off. This is an estimate from the model's shape: a face can't be detected on a painted miniature (macOS's face detection found one in 7% of them), and a model built differently, with its head under a balloon or inside a large body, can still be framed by the wrong part.
- **Side views:** a long war machine or monster that isn't a Hero (the `WAR MACHINE` or `MONSTER` keyword and no `HERO`, with a model at least 4.5" long and 1.25 times longer than wide, such as a Kharadron ship, a chariot or a Stonehorn) is drawn from its side instead, facing right, as its front would show little of it. The view is as wide as the model is long, up to 1.5 times its height, centred along its length and staying above the bottom 15% of its height, so the base stays out of sight. Upright monsters (Gargants) and small war machines keep the close-up.
- **Every picture:** it has a transparent background and fixed lighting with no shadows, rendered at 512 pixels and scaled down to 256 for the largest icon (112 pixels at 200% render scale). Import settings are lossless with mipmaps, written once with the portrait.
- **Finding one:** `UnitPortraits` asks `ModelLibrary.paths_for()` for a name's models and takes the first's portrait, at the same path under `assets/2d/portraits/` with `.png`, so a name finds its portrait by the [rules for its model](#file-names). A unit with no model, or no portrait, shows its initials.

## Git LFS

The models are about 2.5 GB of `.obj` files and 400 MB of textures, so `.gitattributes` stores `assets/3d/models/**/*.obj`, `*.jpg` and `*.png`, the boards in `assets/3d/boards/` and the portraits in `assets/2d/portraits/`, in [Git LFS](https://git-lfs.com/). Install it (`brew install git-lfs`, then `git lfs install`) before cloning, or the checkout has pointer files in place of models. Godot fails to import those (`valid=false` in their `.import` files), and `ModelLibrary.is_imported()` leaves them out, so units are drawn as their bases without errors. CI checks out without Git LFS, so tests never depend on the real models. The `.mtl` and `.import` files are ordinary text.
