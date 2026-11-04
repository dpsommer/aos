# GDScript warnings

Keep the Godot debugger's Errors tab empty. The GDScript analyzer reports these warnings when a script compiles, so they show up there and in the script editor's Warnings panel, but not in the headless test output: a clean test run doesn't mean clean scripts. Fix the cause rather than adding `@warning_ignore`. The one exception so far is integer division that's meant to truncate.

## Shadowing

### `SHADOWED_VARIABLE`: a local hides a member of the same class

A parameter, local or `for` variable has the same name as one of the class's own variables or functions. Functions count too, even though the code looks like it only uses a variable.

```gdscript
static func warscroll(id: String) -> Warscroll: ...

func can_lead(army: Army, warscroll: Warscroll) -> bool: # warns: hides warscroll()
```

While the local is in scope, the name means the local, so assigning to it or calling it doesn't do what it appears to. Rename the local. This project usually uses `scroll` for a local `Warscroll`, and `is_open` or `on_open` where a class has an `open()` function.

### `SHADOWED_VARIABLE_BASE_CLASS`: a local hides an inherited member

The same, for something the class inherits, including engine classes. Names to avoid as locals and parameters:

Base class | Names
-- | --
`Node` (tests too: `GutTest` is a `Node`) | `name`, `owner`
`CanvasItem` | `hidden` (a signal), `show`, `hide`
`Control` | `size`, `scale`, `position`
`Button` | `text`

Prefer a name that says what it holds: `faction_name`, `owner_unit`, `screen_size`, `header_hidden`.

### `SHADOWED_GLOBAL_IDENTIFIER`: a name hides a built-in function

Don't name a variable, parameter or property after a built-in function such as `max`, `min`, `range`, `print` or `wrap`. A `max` property stops `max()` meaning the built-in inside that class.

Say what the value counts instead. JSON keys are a separate namespace, so the faction data keeps its short keys and the loader maps them:

Class | Property | JSON key
-- | -- | --
`Weapon` | `range_inches` | `range`
`WeaponOption` | `max_models` | `max`
`RosterEntry` | `max_units` | `max`
`EnhancementTable` | `max_taken` | `max`
`RegimentOption` | `min_units`, `max_units` | none: parsed from the option's text

When renaming a property, look for uses inside its own class as well as `.name` accesses: they have no dot, and an untyped access only fails when it runs.

### `CONFUSABLE_LOCAL_DECLARATION`: an inner block reuses a name declared later

An inner block declares a name that its parent block goes on to declare further down. The code runs correctly, but the same name is two variables in one function.

```gdscript
if packed:
	var spots := _packed_spots(zone, back) # warns: declared below in the parent block
	...
var spots := _spots(zone, back)
```

Give the inner one its own name (`packed_spots`).

## Numbers and enums

### `INTEGER_DIVISION`: dividing two integers drops the remainder

`7 / 2` is `3`. If that's a mistake, make either side a float (`days / 7.0`). If you do want the whole-number result, keep the integer arithmetic and mark the line, which tells the next reader it's deliberate:

```gdscript
@warning_ignore("integer_division")
return count if option.choice else count / option.per * option.max_models
```

The annotation covers only the statement below it. Don't wrap the division in `floori(a / float(b))` to silence the warning: it goes through floats, rounds negative numbers differently, and turns a divide-by-zero error into infinity.

### `INT_AS_ENUM_WITHOUT_CAST`: an `int` assigned to an enum

Bitwise operators return an `int`, even on enum values, as do functions declared to return one. Cast once the value is known to be valid:

```gdscript
key.keycode = (value & KEY_CODE_MASK) as Key
faction.grand_alliance = alliance as GrandAlliance.Type # after checking it isn't -1
```

`:=` picks up the enum type too. A variable that holds a key with modifiers masks in is really an `int`, so declare it as one (`var code: int = key.get_keycode_with_modifiers()`) instead of casting a value that isn't a single `Key`.

## Unused and unassigned

### `UNASSIGNED_VARIABLE`: read before anything is assigned

`var faction: Faction` starts as `null`, but reading it before assigning looks like a mistake. If `null` is the intended start, say so: `var faction: Faction = null`.

### `UNUSED_VARIABLE`: declared and never read

Remove the variable. If the call is only there for its side effects, keep the call without the assignment. An underscore prefix silences the warning, but use that only when the name helps explain the code.

## Finding them from the command line

The analyzer only sends these to an attached debugger. Godot's `--remote-debug tcp://127.0.0.1:<port>` connects to any listener that reads its packets (`PacketPeerStream`, messages named `error`). Without one running, open each script in the editor, or run the game from the editor and read the Errors tab. A script only reports when it's compiled, so load every `.gd` file (`ResourceLoader.load`) to cover the ones a run doesn't reach. A listener also has to answer `debug_enter` with `continue`, or the game hangs at the first script error.

The tests deliberately trigger a few `push_error` calls, such as "No data for faction 'Not A Real Faction'", and check them with `assert_push_error_count`. Those are expected in the test output.
