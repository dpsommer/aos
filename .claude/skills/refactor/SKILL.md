---
name: refactor
description: Find and fix code smells in production code without changing behaviour, such as duplicate or dead code, deep nesting, long functions, large classes, tight coupling, shallow interfaces, feature envy, primitive obsession and message chains. Use when the user asks to refactor, clean up, tidy, simplify or reduce tech debt in a file, folder or the whole project, or asks for a code smell review. Never edits tests; test refactoring is the separate `refactor-tests` skill.
---

# Refactor

Improve the structure of production code without changing what it does. The existing tests are the safety net, so **they stay exactly as they are**.

## Ground rules

1. **Don't touch tests.** Never create, edit, move, rename or delete anything under `test/` (including `test/support/` and `test/fixtures/`). Test refactoring is the separate `refactor-tests` skill. An unchanged test suite is what shows that behaviour hasn't changed.
2. **Preserve behaviour.** A refactor changes structure, not results: same outputs, signals, side effects, saved file formats and error handling. If you find a bug, report it and leave it as it is. Fixing it is a separate change.
3. **Keep the API the tests use.** If a test calls a function, reads a property, connects to a signal, loads a scene by path or finds a node by name, keep that name, signature and path. If a refactor would break a test, change the plan (for example, keep the old name as a thin wrapper) or skip that refactor and report it. Never change the test to fit the new code.
4. **Stay in scope.** Only refactor production code: `scripts/`, the scripts in `scenes/`, and `tools/` if asked. Never edit `addons/` (vendored), `data/` (generated faction data; see `docs/technical/faction-data.md`) or `.uid` and `.import` files. Godot manages those.
5. **Make small steps and check each one.** Make one refactor at a time and run the tests after each. If they fail, undo or fix that step before going on.
6. **Fit the codebase.** Keep the existing naming, comment density, typing style and idioms. Don't bring in new patterns, frameworks or abstractions the code doesn't need.

## Workflow

### 1. Scope and baseline

- Confirm the target: the files or folder the user named, or the files changed on the branch (`git diff --name-only main...`) if they named none. Ask before refactoring the whole project.
- Check the working tree is clean (`git status`). If it isn't, tell the user and don't mix your changes with theirs.
- Read the docs for the area (`docs/README.md` index), then run the full test suite (commands in `docs/technical/testing.md`) and record the result. **If the baseline isn't green, stop and report it.** A refactor can't be checked against failing tests.
- Note which tests cover the target code (grep `test/` for its class names, `preload` paths and function names). Code with no tests is riskier, so make only mechanical, clearly safe refactors there and say so in the report.

### 2. Scan for smells

Read the target code and look for the smells in [references/smells.md](references/smells.md). Some quick checks help:

```sh
# long files (likely large classes)
find scripts scenes -name '*.gd' -exec wc -l {} + | sort -rn | head -20
# deep indentation (4+ tab levels in GDScript)
grep -rnE '^\t{4,}[^\t]' scripts --include='*.gd'
# functions, so you can spot long ones and long parameter lists
grep -rnE '^(static )?func ' scripts --include='*.gd'
# possible dead code: find each symbol's uses, including in .tscn signal connections
grep -rn 'symbol_name' scripts scenes test
```

For dead code, a symbol counts as unused only if nothing references it in `scripts/`, `scenes/` (`.tscn` files hold signal connections and script paths), `project.godot` (autoloads, input actions) **or `test/`**. Code used only by tests isn't dead, so leave it and mention it.

### 3. Plan

List what you found, ordered by value and risk: high-value, low-risk fixes first. For each one, give the location, the smell, the refactoring you plan to use (Extract Function, Guard Clause, Move Function and so on) and the tests that cover it. If the list is long or a change is risky (it crosses many files, changes a public API or the code has no tests), show the plan to the user before starting.

### 4. Refactor

For each item:

1. Make the smallest change that removes the smell.
2. Run the tests that cover it (a single script with `-gtest=`), and run the full suite after any change that crosses files.
3. Check `git diff --stat -- test/` is empty.

Prefer these well-known, behaviour-preserving moves:

- **Extract Function or Variable**: name a block or expression by what it does.
- **Guard Clauses** and **Decompose Conditional**: flatten nesting with early returns and well-named predicates.
- **Replace Conditional with Polymorphism or a lookup table**: replace repeated `match` statements or if-chains on the same type tag.
- **Introduce Parameter Object** and **Preserve Whole Object**: replace data clumps and long parameter lists.
- **Move Function or Field**: fix feature envy and inappropriate intimacy.
- **Hide Delegate** and **Remove Middle Man**: deal with message chains and pointless forwarding.
- **Inline Function or Class**: remove lazy classes, shallow wrappers and speculative generality.
- **Rename**: fix uncommunicative or inconsistent names (only if no test or scene depends on the name).
- **Remove Dead Code**: delete it rather than commenting it out. Git keeps the history.

Godot-specific care:

- Renaming a node, scene, script path, `class_name`, signal or exported property can break `.tscn` files, `preload`/`load` paths, `$NodePath` and `get_node` lookups, and saved data. Grep for each one before renaming.
- Moving or renaming a `.gd` file also moves its `.uid` file. Let Godot keep that pair in step (`git mv` both together) rather than editing UIDs.
- Don't change JSON keys, `user://` file formats or `ConfigFile` sections and keys. Players' saved armies and settings depend on them.

### 5. Verify and report

- Run the full suite and compare it with the baseline: the same pass count, no new failures, and no changes under `test/` (`git status -- test/`).
- Update `docs/` if a refactor changed something they describe, such as file locations, class names or how parts fit together.
- Report:
  - each change: what smell, where, which refactoring
  - smells you left alone and why (no tests, risky, would need test changes, possible bug)
  - places where the tests could be improved, as input for the `refactor-tests` skill
  - the test results before and after

Don't commit unless the user asks.
