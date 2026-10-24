# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Warhammer: Age of Sigmar battle simulator built in Godot 4.7 (Forward Plus renderer, Jolt Physics, GDScript). It mirrors the tabletop game: five battle rounds, objectives, battle tactics and battleplan missions, with fully rendered models that are deployed and moved freely on a 3D battlefield. Players build and save armies; the first mode is "quick battle" against an AI opponent.

The project is at an early stage. The main scene is `scenes/main.tscn` (`Main`), which owns screen flow and starts on the main menu. Forge (army builder) has Grand Alliance and faction selection and a read-only faction browser; Blades of Khorne, Cities of Sigmar, Daughters of Khaine, Disciples of Tzeentch, Flesh-eater Courts, Gloomspite Gitz, Hedonites of Slaanesh, Helsmiths of Hashut, Idoneth Deepkin, Kharadron Overlords, Lumineth Realm-lords, Maggotkin of Nurgle, Nighthaunt, Ogor Mawtribes and Sylvaneth have data. Quick Play and Settings have no screens yet. See `docs/design/`.

## Documentation

`docs/` is the project's documentation, indexed in `docs/README.md`. Read the relevant docs before starting work, and update them (and the index) when your change affects them.

- `docs/technical/`: engineering docs.
  - `layout.md`: folder structure. GDScript goes in `scripts/`, scenes in `scenes/`, assets in `assets/{2d,3d,audio,shaders}`. `addons/gut/` is vendored third-party code, so don't edit it.
  - `testing.md`: test layout, how to run tests headless, and the testing rules. Follow it when writing tests.
  - `rules-reference.md`: the official rules PDFs and how to use them.
  - `faction-data.md`: faction JSON format in `data/factions/`, sources (BSData first, Wahapedia for gaps), and how to add a faction with `tools/faction_import/`.
- `docs/design/`: game design (modes, UI, army builder, AI).
- `docs/gameplay/`: how tabletop rules are implemented in the simulator.

## Running Godot

`godot` is on the PATH. The test commands are in `docs/technical/testing.md`.
