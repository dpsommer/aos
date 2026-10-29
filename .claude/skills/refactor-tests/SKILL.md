---
name: refactor-tests
description: Refactor the test suite without touching production code. Find and fix test smells such as obscure or eager tests, testing implementation details, private methods or constants, duplicated setup, mystery guests, fragile assertions, conditional test logic, over-mocking, slow or interdependent tests, and tests at the wrong level of the test pyramid. Use when the user asks to refactor, clean up, tidy, speed up or review tests. Never edits production code; production refactoring is the separate `refactor` skill.
---

# Refactor tests

Make the tests easier to read, faster, more reliable and less tied to implementation, **without weakening what they check**. The production code is the safety net here, so **it stays exactly as it is**. This is the mirror image of the `refactor` skill.

The principles come from Martin Fowler's [Unit Test](https://martinfowler.com/bliki/UnitTest.html), Ham Vocke's [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html) and Kent Beck's *Test Driven Development: By Example*. They're summarised in [Principles](#principles) below. The smell catalogue is in [references/test-smells.md](references/test-smells.md).

## Ground rules

1. **Don't touch production code.** Never commit changes to `scripts/`, `scenes/`, `data/`, `addons/`, `project.godot` or `tools/`. If a test is hard to write because of the production code (hidden dependencies, no way to inject a double, logic buried in `_ready()`), report it as input for the `refactor` skill. The only exception is the temporary sabotage check in step 4, which must be reverted before you move on.
2. **Keep the same protection.** Every behaviour that was checked before must still be checked afterwards, by the same test or another one. Never delete or loosen an assertion just to make a test pass or to make it shorter. If a test fails after your change, the test refactor is wrong, not the code.
3. **Each refactored test must still be able to fail.** Prove it with the sabotage check in step 4. A test that can't fail protects nothing.
4. **Follow the project's testing rules** in `docs/technical/testing.md`. They take precedence over general advice. In particular, any test that touches saved armies, settings or the screens that load them uses `Sandbox.begin()` and `Sandbox.end()`, and tests must never touch the player's files in `user://`.
5. **Work in small steps, keeping the suite green.** Refactor one test file (or one smell across files) at a time, then run it. Beck: refactor only while the bar is green.
6. **Fit the codebase.** Use the existing helpers in `test/support/` (`army_kit.gd`, `ui_kit.gd`, `sandbox.gd`) and the existing naming and layout. Add to them rather than writing a parallel helper.

## Principles

**What a unit is (Fowler).** A unit is a unit of *behaviour*, not necessarily one class. Tests can be *sociable* (using real collaborators) or *solitary* (using test doubles). Prefer real collaborators when they're fast and deterministic. Use doubles only for awkward ones: the file system, `user://`, time, randomness, the scene tree when it isn't needed, or slow work. Unit tests must be fast enough to run after every change.

**Test behaviour, not implementation (Vocke).** Test through the public interface: what goes in and what comes out, signals emitted, and state other code can observe. Don't test private (`_`-prefixed) methods directly. If one seems to need its own tests, that's a sign the class is doing too much, so report it for the `refactor` skill. A test should only fail when behaviour changes, not when the code is restructured. Beck calls this being *structure-insensitive*.

**The test pyramid (Vocke).** Have many small, fast unit tests, fewer integration tests, and very few end-to-end tests. Push each check down to the lowest level that can prove it. Don't check the same behaviour at several levels: if a unit test proves an edge case, an integration test only needs to prove that the parts are wired together. Integration tests check one integration each (here, mostly the real faction, core and army data loading from disk).

**Readable tests (Vocke and Beck).** Treat test code with the same care as production code. Each test has a clear *Arrange, Act, Assert* (given, when, then) shape. Beck's *Evident Data*: inputs and expected values in the test make the relationship obvious (`90` points, reinforced, so `180`), and setup that doesn't matter to the test is hidden in helpers. The test name states the behaviour (`test_reinforced_unit_costs_double`), not the method under test (`test_unit_points_2`).

**One behaviour per test (Beck).** Each test checks one thing, so a failure points straight at the cause. Several assertions are fine if they describe the same behaviour. When one test checks unrelated things, split it.

**Isolated and deterministic (Beck).** Tests don't depend on each other or on the order they run in. They leave no state behind (use `autofree`, `add_child_autofree`, `before_each`/`after_each`, `Sandbox`), and they give the same result every time: no real time, unseeded randomness or arbitrary waits.

**Beck's test desiderata** are a checklist for each change: isolated, composable, deterministic, fast, writable, readable, behavioural, structure-insensitive, automated, specific and predictive. A refactor that improves one quality must not quietly give up another. For example, a shared fixture that removes duplication but couples tests together is a bad trade.

**Don't test the obvious (project rules and Vocke).** Avoid "A equals A" tests and tests that pin constant values (a colour, a font size, a points value copied from data). They fail when someone tunes a value and catch no real bugs. Test the rule that uses the constant instead.

## Workflow

### 1. Scope and baseline

- Confirm the target: the test files or folder the user named, or the tests for the area they named. Ask before taking on the whole suite.
- Check the working tree is clean (`git status`). If it isn't, tell the user and don't mix your changes with theirs.
- Run the full suite (commands in `docs/technical/testing.md`) and record the pass, fail, pending and assertion counts and the run time. **If the baseline isn't green, stop and report it.**
- Read the production code the tests cover, so you know which behaviours they're meant to protect.

### 2. Scan for smells

Read the target tests and look for the smells in [references/test-smells.md](references/test-smells.md). Some quick checks help:

```sh
# biggest test files (likely eager tests or general fixtures)
wc -l test/unit/*.gd test/integration/*.gd | sort -rn | head
# tests calling private methods or reading private fields
grep -rnE '\._[a-z]\w*' test --include='*.gd' | grep -v 'super\._'
# conditional or looping logic inside tests
grep -rnE '^\t(if|for|while|match) ' test --include='*.gd'
# arbitrary waits (sleepy tests)
grep -rnE 'wait_seconds|create_timer' test --include='*.gd'
# tests with no assertion
grep -nE '^func test_' test/unit/test_foo.gd   # then read each body
# file system use outside Sandbox
grep -rln 'user://' test --include='*.gd'
```

Also time the slowest files (run them one at a time with `-gtest=`), and look for the same check repeated in unit and integration tests.

### 3. Plan

List what you found, ordered by value and risk. For each item, give the file and test name, the smell, the change you plan to make, and the behaviours the test protects (so you can show afterwards that they're still covered). Show the plan to the user before starting if you'd delete, merge or move tests between levels, or change shared helpers in `test/support/` (that affects many files).

### 4. Refactor

For each item:

1. Make the change. Typical moves:
   - **Rename** a test to describe the behaviour it checks.
   - **Extract Helper** or **Creation Method** for repeated arrange code (add it to `test/support/` if several files need it). Keep the values that matter to the test visible in the test itself.
   - **Split** an eager test into one test per behaviour. **Merge** near-identical tests into a parameterised test (GUT's `use_parameters`) when that reads more clearly.
   - **Replace an implementation check with a behaviour check**: assert on public results, emitted signals (`watch_signals`, `assert_signal_emitted_with_parameters`) or visible state instead of private fields or calls.
   - **Inline** a general fixture (setup in `before_each` that only some tests use) into the tests that need it, or make a smaller one.
   - **Replace a double with the real collaborator** when it's fast and deterministic, or **add a double** (`double`, `partial_double`, `stub`) for a slow or non-deterministic one.
   - **Remove conditional logic** from a test: split it into one test per case.
   - **Replace waits** with awaiting the actual signal or a fixed number of frames.
   - **Move** a check down the pyramid, or **delete** a duplicate at a higher level (only once you've confirmed the lower-level test covers it).
   - **Delete** tautological or constant-pinning tests, after confirming that a real behaviour test covers what matters, or replace them with one.
2. Run the changed test file and confirm it passes.
3. **Sabotage check:** for each test you changed in a meaningful way (not just a rename), prove it can still fail for the right reason. Temporarily break the behaviour it covers in the production code (flip a condition, return a wrong value, skip a signal), run the test, and confirm it fails with a clear message. Then restore the file with `git checkout -- <file>` and confirm `git status -- scripts scenes data` is clean before going on. If the test still passes when the code is broken, your refactor has weakened it. Fix the test.
4. Check that nothing outside `test/` has changed (`git status`).

### 5. Verify and report

- Run the full suite and compare it with the baseline: all green, `git diff --stat` only lists files under `test/` (and `docs/` if needed), and the run time is the same or faster. Explain any change in the number of tests or assertions (split, merged, moved or deleted, and where the behaviour is covered now).
- Run the suite a second time if you touched anything timing-related, to catch erratic tests.
- Update `docs/technical/testing.md` if you added shared helpers or changed conventions.
- Report:
  - each change: what smell, where, what you did, and how you checked it (sabotage result)
  - tests you deleted or merged, and where their behaviour is covered now
  - smells you left alone and why
  - production code that made testing hard, as input for the `refactor` skill
  - untested behaviour you noticed (don't add tests for it unless asked; new tests are the `unit-writer` agent's job)
  - test results and run time before and after

Don't commit unless the user asks.
