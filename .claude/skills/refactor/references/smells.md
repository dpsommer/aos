# Code smell catalogue

Based on Jeff Atwood's [Code Smells](https://blog.codinghorror.com/code-smells/) (drawn from Fowler's *Refactoring*), plus a few more from *A Philosophy of Software Design*. A smell is a hint, not a rule: fix it only when the result is clearly easier to read or change.

## Within a class or file

Smell | Signs | Typical fix
-- | -- | --
**Duplicated code** | The same or near-same logic in two or more places, often copy-pasted with small changes | Extract Function, pulling the differences out as parameters; move shared helpers to a common place
**Dead code** | Functions, variables, signals, parameters, branches or `class_name`s that nothing uses; commented-out code; conditions that are always true or false | Delete (but check `.tscn`, `project.godot` and `test/` first)
**Long function** | Does several things; needs comments to mark its sections; hard to name | Extract Function for each step; the outer function reads like a summary
**Deep nesting** | 3+ levels of `if`/`for`/`match`; arrow-shaped code | Guard clauses, Extract Function for the inner body, Decompose Conditional
**Conditional complexity** | Long `if/elif` chains or `match` on a type or string tag, repeated in several places | Lookup table (Dictionary), polymorphism, or one function that owns the decision
**Long parameter list** | 4+ parameters, or boolean flag parameters that switch behaviour | Introduce Parameter Object, Preserve Whole Object, split the function per flag value
**Large class** | Many fields and responsibilities; several unrelated groups of methods; a file of hundreds of lines | Extract Class or child component; split along the groups
**Comments that explain what** | Comments needed to explain unclear code (not *why* comments) | Rename or Extract Function so the code says it; keep comments that explain why
**Uncommunicative name** | `data`, `tmp`, `do_stuff`, single letters outside short loops, abbreviations | Rename
**Inconsistent names** | The same idea under different names (`unit`/`model`/`entry`), or mixed verb styles | Rename to the term the rest of the codebase and docs use
**Type embedded in name** | `unit_array`, `name_str`, `get_dict` | Rename; let static types say the type
**Magic numbers and strings** | Repeated literals with hidden meaning | Named constant or enum
**Speculative generality** | Hooks, parameters, base classes or options "for later" that nothing uses | Inline, remove unused parameters, collapse the hierarchy
**Oddball solution** | The same problem solved different ways in different places | Pick the best one and use it everywhere
**Temporary field** | A member variable only set or used during one operation | Make it a local or parameter, or extract the operation into its own object
**Combinatorial explosion** | Many near-identical functions for each combination of options | One function with parameters or data-driven behaviour

## Between classes

Smell | Signs | Typical fix
-- | -- | --
**Tight coupling / inappropriate intimacy** | A class reaches into another's private fields (`_foo`) or child nodes (`other.get_node("A/B")`); two classes that always change together | Move Function, add a narrow public method, use signals for upward communication ("call down, signal up")
**Feature envy** | A method uses another object's data more than its own | Move the method to the class whose data it uses
**Message chains** | `a.get_b().get_c().do()`, long `$A/B/C` paths across scene boundaries | Hide Delegate: ask the nearest object for what you need
**Middle man** | A class whose methods mostly just forward to another | Remove Middle Man and call the real object
**Shallow interface** | A module whose interface is about as complex as what it does: pass-through methods, wrappers that add nothing, many tiny classes the caller must wire together | Merge into a deeper module with a simple interface that hides more; inline trivial wrappers
**Indecent exposure** | Internal state or helpers that are public without need | Make them private (`_` prefix) if nothing outside uses them (check tests and scenes)
**Primitive obsession** | Dictionaries or arrays of loose values standing in for a concept; string tags for states | Small typed class, `enum`, or `Resource`
**Data clumps** | The same group of values always passed or stored together | Introduce Parameter Object or a small class
**Data class** | A class with only fields and no behaviour while other classes work on its data | Move that behaviour into it (Move Function)
**Lazy class** | A class that does too little to earn its place | Inline Class
**Refused bequest** | A subclass that overrides parent methods to do nothing, or uses little of what it inherits | Composition instead of inheritance; push the methods down
**Alternative classes with different interfaces** | Two classes do the same job with different method names | Rename and unify, then remove one
**Divergent change** | One class is edited for many unrelated reasons | Split by reason for change
**Shotgun surgery** | One change needs small edits in many classes | Move the related behaviour into one place
**Solution sprawl** | One feature's code is spread across many classes | Gather it into one module
**Parallel inheritance hierarchies** | Adding a subclass in one hierarchy needs one in another | Merge them, or make one refer to the other
**Incomplete library class** | Helper code repeatedly works around a missing engine or library feature | One shared extension or helper in a clear place
**Global state** | Autoloads or static vars used as hidden inputs or outputs | Pass the dependency in, or keep it behind one clear interface

## GDScript-specific

- **Untyped code** in a typed file: add static types where the surrounding code uses them.
- **`get_node` in hot paths** or repeated lookups: cache with `@onready var`.
- **Upward calls** (`get_parent().do()`, `owner.foo`): replace with a signal the parent connects to.
- **Huge `_ready()`**: building whole UI trees in code; extract builder functions, or move static layout into the `.tscn` if the codebase does that elsewhere.
- **String-typed signals and methods** (`connect("pressed", ...)`, `call("name")`): use `pressed.connect(...)` and direct calls where the codebase does.
