# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Warhammer: Age of Sigmar battle simulator built in Godot 4.7 (Forward Plus renderer, Jolt Physics, GDScript). It mirrors the tabletop game: five battle rounds, objectives, battle tactics and battleplan missions, with fully rendered models that are deployed and moved freely on a 3D battlefield. Players build and save armies; the first mode is "quick battle" against an AI opponent.

The project is at an early stage. The main scene is the main menu (`scenes/ui/main_menu.tscn`); its Quick Play, Forge and Settings options emit signals but have no screens yet. See `docs/design/main-menu.md`.

## Documentation

`docs/` is the project's documentation, indexed in `docs/README.md`. Read the relevant docs before starting work, and update them (and the index) when your change affects them.

- `docs/technical/`: engineering docs.
  - `layout.md`: folder structure. GDScript goes in `scripts/`, scenes in `scenes/`, assets in `assets/{2d,3d,audio,shaders}`. `addons/gut/` is vendored third-party code, so don't edit it.
  - `testing.md`: test layout, how to run tests headless, and the testing rules. Follow it when writing tests.
  - `rules-reference.md`: the official rules PDFs and how to use them.
- `docs/design/`: game design (modes, UI, army builder, AI).
- `docs/gameplay/`: how tabletop rules are implemented in the simulator.

## Rules reference

`reference/` (gitignored) holds the official AoS rules PDFs. Treat them as the source of truth for game mechanics, and read the relevant section before you implement or change a rule. See `docs/technical/rules-reference.md`.

## Running Godot

`godot` isn't on PATH, so find the editor binary before running anything. The test commands are in `docs/technical/testing.md`.
