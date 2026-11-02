# 3D models

Unit, manifestation and faction terrain models live in `assets/3d/models/`, one Wavefront `.obj` per model, imported by Godot's OBJ importer as a `Mesh`. `ModelLibrary` (`scripts/battle/map/model_library.gd`) finds them by name, and the game map stands them on their bases (see [Battle](../design/battle.md#game-map)).

## Folders

```text
assets/3d/models/
├── <alliance>/<faction>/   # order, chaos, death, destruction; faction ids as in data/factions/
└── shared/
    └── manifestations/     # the universal manifestations in data/core/manifestation_lores.json
```

- A model goes in the folder of the faction whose warscroll it is. A unit two factions share (Fyreslayers' and Khazalite Holds' Auric Runefather) goes in the one that isn't Legends.
- A shared warscroll (`data/shared/warscrolls.json`, e.g. the Orruk manifestations) goes in the first faction that lists it.
- Faction manifestations and faction terrain go in their faction's folder, like units.

The folder is only for people: `ModelLibrary` finds a file anywhere under `assets/3d/models/`.

## File names

A model's file name is its warscroll's name as a slug (`ModelLibrary.slug()`): lower case, apostrophes dropped, and every run of other characters an underscore. "Skabbik's Plaguepack" is `skabbiks_plaguepack.obj`, and "Arkhan the Black, Mortarch of Sacrament" is `arkhan_the_black_mortarch_of_sacrament.obj`.

- **Variants:** a unit whose models differ has numbered files, `vulkyn_flameseekers_1.obj`, `_2` and so on, with no file of the bare name. The battle gives them to the unit's models in turn, so a unit of 10 with 3 variants has 4, 3 and 3 of each.
- **One file per model:** every file is a whole model, its pieces joined (the Arkanaut Frigate's two halves, a Mega-Gargant's legs and body), or the battle would show each piece as a separate variant.
- **Weapon options:** a warscroll named "X with Y" (e.g. "Vulkite Berzerkers with Fyresteel Weapons") falls back to the model of X when it has none of its own, so a model whose weapons can't be told apart can be named for the unit alone.
- **Lookup order:** a unit's own name, then its warscroll's (a Spearhead unit's name matches its faction's warscroll); a faction terrain feature's name, then its warscroll's. The first name with a model wins.

## Conventions

The models come from a Tabletop Simulator mod (see [Building the models](#building-the-models)), so they share its conventions:

- **Scale:** 1 unit is 1 inch, the game's scale, so a 25mm base is 0.98 units across.
- **Axes:** Y up, the model's front towards -Z.
- **Origin:** the middle of the model's own base, with its lowest point at about y = 0. The battle drops each model so its lowest point rests on the coloured base, whatever its origin height.
- **Textures:** each model's `.obj` has a `.mtl` beside it with a material per piece texture (or plain colour), whose images are in its folder's `textures/`: `.jpg`, or `.png` for a cutout (a texture with see-through parts, whose material's name ends in `_cutout`). A texture is written once, by the first model that uses it, so a model's `.mtl` can point into another folder's `textures/`. Textures are at most 1024 pixels on a side, imported with mipmaps and VRAM compression (their `.import` files are written with the textures). `ModelLibrary.prepare()` makes a model's materials draw both sides of each face, as some scans have flipped faces, and turns on alpha scissor for cutouts.
- **Placeholder materials:** a model with no materials of its own (a test fixture, or a hand-made `.obj` without a `.mtl`) is drawn with `p_model_player` (blue-grey), `p_model_opponent` (red-grey) or `p_model` (faction terrain), which also draw both sides of each face. Textured models look the same for both players; their coloured bases tell them apart.

## Building the models

`tools/tts_models/build_models.py` builds the whole folder from the [Ulthuan](https://steamcommunity.com/sharedfiles/filedetails/?id=3202337953) Tabletop Simulator mod, reading everything from Tabletop Simulator's cache (`~/Library/Tabletop Simulator/Mods` on macOS): the save from `Workshop/`, the `.obj` meshes from `Models/`, their textures from `Images/` and the models the mod ships as Unity asset bundles (the Arkanaut Ironclad, Lord-Celestant on Stardrake, Megaboss on Maw-krusha and about 240 more) from `Assetbundles/`. Subscribe to the mod and load it once in Tabletop Simulator so it downloads them all.

The script needs Pillow and [UnityPy](https://pypi.org/project/UnityPy/) (`tools/tts_models/requirements.txt`), and UnityPy needs a Python built with `lzma`. The `aos` pyenv virtualenv's Python isn't, so use a separate virtualenv, e.g. on Homebrew's Python:

```sh
python -I tools/tts_models/build_models.py > tmp/tts_models_build.json
godot --headless --import
```

It replaces everything in `assets/3d/models/` (`--dry` only reports) and prints a report of which nickname went to which file. A workshop id or save path picks another mod, and `--tts` another cache folder. It takes about 7 minutes, and Godot's import about 3.

How it works:

- **Models:** each faction tile in the save spawns its models from JSON kept in its Lua script. A model is a `Custom_Model` (often just a base) with the model's pieces attached as child objects, each with its own position, rotation and scale; asset bundle models are `Custom_Assetbundle` children. The pieces are joined into one mesh with their transforms (Tabletop Simulator is Unity, so `.obj` files have X mirrored, and rotations are Euler angles applied Z, X, then Y). Pieces no taller than 0.35" (bases, toppers, colliders) are left out, as the game draws its own bases. The mesh is turned so its biggest piece's front is -Z, and centred on the root's base.
- **Asset bundles:** `bundles.py` reads a bundle's rendered meshes (each on an enabled `MeshRenderer`) with their transforms, and their materials' main texture and colour.
- **Textures:** a `.obj` piece's texture is its `DiffuseURL` and its colour `ColorDiffuse`; an asset bundle's come from its materials. Normal maps are left out.
- **Names:** a model's nickname (e.g. "Chaos Warrior Champion (Scourge of Aqshy)", "Darkoath Fellrider w/Javelins") is matched to a warscroll in `data/`, among the factions of the tile it's on. Scourge tags, "w/" loadouts, counts such as "5/5" and roles (Champion, Musician, Standard Bearer, Banner) are dropped, then the name is matched exactly, as a plural, as the start of a single warscroll's name, or closely (`difflib`, 0.86). `overrides.json` gives the warscroll for nicknames that don't match that way, or `skip` for companions with no model of their own (Klonk, Thexa, Blot Toads). A target of `x:<faction>:<Name>` files a model under that faction with a name that isn't a warscroll's.
- **Variants:** a unit's different models (a champion, a musician, other poses or paint schemes) are its numbered variants. Copies of the same model are kept once.

Units with no model are drawn as their bases. Scuttletide has none, as its asset bundle isn't in the cache.

## Git LFS

The models are about 2.5 GB of `.obj` files and 400 MB of textures, so `.gitattributes` stores `assets/3d/models/**/*.obj`, `*.jpg` and `*.png` in [Git LFS](https://git-lfs.com/). Install it (`brew install git-lfs`, then `git lfs install`) before cloning, or the checkout has pointer files in place of models. The `.mtl` and `.import` files are ordinary text.
