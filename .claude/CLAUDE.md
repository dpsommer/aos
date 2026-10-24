# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Warhammer: Age of Sigmar battle simulator built in Godot 4.7 (Forward Plus renderer, Jolt Physics, GDScript). It mirrors the tabletop game: five battle rounds, objectives, battle tactics and battleplan missions, with fully rendered models that are deployed and moved freely on a 3D battlefield. Players build and save armies; the first mode is "quick battle" against an AI opponent.

The project is at the bootstrap stage. `scenes/`, `scripts/` and `assets/` exist but are still empty, and no main scene is set yet.

## Rules reference

`reference/` (gitignored) holds the official AoS rules PDFs: core rules (Apr 2025), the quickstart guide and the battle profiles. Treat them as the source of truth for game mechanics. Read the relevant section before you implement or change a rule.

## Layout

See `docs/technical/layout.md`. In short: GDScript goes in `scripts/`, scenes in `scenes/`, and assets in `assets/{2d,3d,audio,shaders}`. Documentation lives in `docs/{design,gameplay,technical}`. `addons/gut/` is vendored third-party code, so don't edit it.

## Testing

Tests use the vendored [GUT](https://github.com/bitwes/Gut) addon. No test directory or `.gutconfig.json` exists yet, and the GUT plugin isn't enabled in `project.godot`. `godot` isn't on PATH, so find the editor binary before running anything. Headless CLI usage:

```sh
# all tests in a directory
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
# a single test script
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_foo.gd -gexit
# a single test function within a script
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_foo.gd -gunit_test_name=test_bar -gexit
```

`docs/technical/testing.md` sets the project's testing rules:
- Unit tests are fast and fully isolated, with no shared state between tests. Each one checks a single behavior.
- Avoid tautological "A equals A" tests and tests that pin specific constant values. Changing a constant shouldn't normally break a test.
- Use integration tests sparingly, for critical interactions only. Each covers one integration and mocks or stubs everything else. Set up and tear down state within the suite.
