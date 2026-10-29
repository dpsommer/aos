# Test smell catalogue

Mostly from Gerard Meszaros's *xUnit Test Patterns*, plus the advice in Fowler's [Unit Test](https://martinfowler.com/bliki/UnitTest.html), Vocke's [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html) and Beck's *Test Driven Development*. A smell is a hint, not a rule: fix it only when the test is clearly better afterwards and protects just as much.

## Readability

Smell | Signs | Typical fix
-- | -- | --
**Obscure test** | You can't tell what's being tested or why the expected value is right without reading other files | Evident Data: put the values that matter in the test; hide the rest in a creation method; Arrange, Act, Assert layout
**Unclear name** | `test_1`, `test_points`, or a name that no longer matches what the test does | Rename to the behaviour: `test_<subject>_<does what>_<when>`
**Irrelevant information** | Setup full of values that don't affect the result | Creation method with defaults; pass only what matters
**Mystery guest** | The test depends on a fixture file, autoload or global state that isn't visible in the test | Build the data in code with `test/support/` helpers, or name the fixture clearly where it's used
**Assertion roulette** | Many assertions with no messages, so you can't tell which one failed or why | Split into separate tests, or add a message to each assertion
**Magic numbers in expectations** | `assert_eq(x, 37)` with no clue where 37 comes from | Derive it in the test (`base * 2`) or name it

## Design

Smell | Signs | Typical fix
-- | -- | --
**Eager test** | One test checks several unrelated behaviours | Split into one test per behaviour
**General fixture** | `before_each` builds a large world, and each test uses a small part of it | Smaller fixtures, or move the setup into the tests that need it
**Test code duplication** | The same arrange block copied across tests or files | Extract a helper, or a parameterised test (`use_parameters`)
**Conditional test logic** | `if`, `for` or `match` in a test body; the test can pass without running its assertions | One test per case; parameterised test
**Testing private methods** | Calls to `_foo()` or reads of `_bar` from a test | Test through the public interface; report the class to the `refactor` skill if that's too hard
**Testing implementation** | Asserting on internal calls, child node order or structure rather than results | Assert on outputs, signals and visible state
**Over-mocking** | Doubles for fast, deterministic collaborators; the test mostly checks that the mocks were called | Use the real collaborator (a sociable test); keep doubles for awkward dependencies
**Under-isolation** | Unit tests that hit the real file system, `user://`, the network or real time | Double the awkward dependency; use `Sandbox` for saved files
**Tautological test** | The expected value is computed the same way as the code under test, or the test re-checks a value it just set ("A equals A") | Use an independent, evident expected value; delete if nothing real is checked
**Constant pinning** | Asserting a colour, size, string or data value copied from the source | Test the rule that uses the constant; delete the pin
**Missing assertion** | A test that only runs code (it passes as long as nothing errors) | Add the assertion it was meant to make, or delete it if it adds nothing
**Wrong level** | Edge cases checked through the whole UI or real data files; the same behaviour checked at several levels | Push the check down to a unit test; keep one higher-level test for the wiring
**Test logic in production** | Production code that exists only for tests (`if testing:` flags, test-only setters) | Report it for the `refactor` skill; don't change production code here

## Reliability and speed

Smell | Signs | Typical fix
-- | -- | --
**Fragile test** | Breaks when unrelated code changes, such as layout, wording, ordering or node names | Assert on behaviour; look things up by meaning, not position; avoid exact text unless the text is the behaviour
**Interdependent tests** | A test relies on state left by an earlier one; results change with order | Fresh setup in `before_each`; free nodes (`autofree`, `add_child_autofree`); reset statics in `after_each`
**Erratic test** | Sometimes passes, sometimes fails | Remove timing, randomness (seed it or double it) and shared state
**Sleepy test** | `wait_seconds` or timers used to "let things settle" | Await the actual signal (`await wait_for_signal(...)`) or a fixed number of frames
**Slow test** | A unit test that takes noticeably longer than its neighbours: loading real faction data, building whole screens, awaiting many frames | Smaller data from `army_kit.gd`; build only the control under test; move the check down the pyramid
**Leaky test** | Orphan nodes or files left behind (GUT reports orphans) | `autofree`, `queue_free` in `after_each`, `Sandbox.end()`
