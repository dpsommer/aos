# Testing

Tests are written using the [GUT (Godot Unit Testing)](https://github.com/bitwes/Gut) addon, vendored in `addons/gut/`. The GUT editor plugin is enabled in `project.godot`.

## Layout

```text
test/
├── unit/          # fast, isolated tests of a single function, class or module
└── integration/   # tests of a single interaction between components
```

GUT only collects files with the `test_` prefix by default (e.g. `test/unit/test_dice.gd`). Test scripts extend `GutTest`. No `.gutconfig.json` exists yet, so options are passed on the command line.

## Running tests

`godot` isn't necessarily on `PATH`; substitute the path to your Godot 4.7 editor binary (on macOS, `/path/to/Godot.app/Contents/MacOS/Godot`). Run from the project root:

```sh
# all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
# unit or integration tests only
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/integration -gexit
# a single test script
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_foo.gd -gexit
# a single test function within a script
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_foo.gd -gunit_test_name=test_bar -gexit
```

Tests can also be run from the GUT panel in the editor.

On a fresh checkout (no `.godot/` folder), run `godot --headless --import` first so `class_name` scripts resolve.

## CI

The Claude GitHub Actions workflows (`.github/workflows/claude.yml` and `claude-code-review.yml`) install Godot with `.github/actions/setup-godot/`, which puts it on `PATH` as `godot` and imports the project. Claude is allowed to run `godot --headless -s addons/gut/gut_cmdln.gd ...`, so it can run any of the commands above. Bump the action's `version` input when the project moves to a new Godot release.

## Refactor hook

`.githooks/pre-push` runs the project's refactor skills with Claude Code before each push: the `refactor` skill on the production `.gd` files the push changes, then the `refactor-tests` skill on the changed files under `test/`. Each only edits those files, runs the full suite, and commits its changes as a "Refactor" or "Refactor tests" commit. If either commits, the push stops so the commits can be looked over; push again to send them. The hook then runs Git LFS's own pre-push, which uploads the models.

- **Enable it** once per clone: `git config core.hooksPath .githooks`. `.githooks/` also has Git LFS's other hooks, as Git then no longer runs those in `.git/hooks/`.
- **Needs** Claude Code (`claude`) on `PATH`; without it, the hook says so and the push goes ahead.
- **Clean tree:** the hook stops the push if there are uncommitted changes, as the skills commit theirs.
- **Skip it** for one push with `SKIP_REFACTOR_HOOK=1 git push` (Git LFS still runs), or every hook with `git push --no-verify`. It doesn't run again on a push whose newest commit is its own (they end with `Refactor-Hook: yes`).

## Key practices

**Unit tests:**

- Must run quickly
- Success or failure of a test must be irrelevant for the success of another. No state should be maintained in the test suite
- Tests must be isolated from external dependencies
- Tests must never touch the player's files in `user://`. Any test that creates the Forge, `Main`, an army builder or the Settings screen, or reads `GameSettings.current()`, calls `Sandbox.begin()` in `before_each` and `Sandbox.end()` in `after_each` (`test/support/sandbox.gd`). It points saved armies, favourites and settings at temporary paths (named with the process id, so test runs going at the same time don't wipe each other's data) and deletes them afterwards, starts settings at their defaults, and puts the keys and audio volumes back to their defaults
- Every real faction has data, so tests of how a faction without data is shown list a fixture one instead. `FactionFixture.use(fixture)` (`test/support/faction_fixture.gd`) lists the factions in `test/fixtures/factions/<fixture>/factions.json`, by Grand Alliance id, in place of an alliance's real ones: `faction_without_data` lists one beside a faction with data, and `alliance_without_data` leaves an alliance with no faction that has data. Call `FactionFixture.end()` in `after_each` to list the real factions again
- Tests of 3D models never load the real ones in `assets/3d/models/` (CI checks them out as Git LFS pointers). They pass a `ModelLibrary` rooted at a fixture folder from `test/support/model_kit.gd`: `ModelKit.library()` (untextured models in `test/fixtures/models/`), `ModelKit.textured_library()` (a model with its own material) or `ModelKit.unimported_library()` (a Git LFS pointer Godot fails to import)
- Tests never depend on the real portraits in `assets/2d/portraits/` either, as they're in Git LFS too. A test of what a portrait shows points `UnitPortraits.use()` at a fixture and calls `UnitPortraits.end()` in `after_each`
- UI tests look for what's shown: scenes keep optional parts hidden, so use `UIKit.find_shown()`, `label_texts()` or `labels_with_variation()` (`test/support/ui_kit.gd`), which skip hidden controls, rather than `find_all()` when a hidden control shouldn't count (see [UI scenes](ui-scenes.md))
- Tests should check one single, specific aspect of a function, class, or module
- Avoid "A equals A" tests that simply check code values against identical test values
- Avoid fragile testing patterns, such as testing for specific constant values. Most of the time, updating a constant should not cause test failures

**Integration tests:**

- Should test a single integration, mocking or stubbing any other dependent components
- Should be used sparingly to test critical interactions between components or third-party dependencies
- Should mirror the real-world integration as closely as possible
- Should setup and teardown required state within the suite context
