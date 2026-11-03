# UI scenes

## Rule: prefer scenes for anything visible

Build visible elements (screens, modals, menus, HUDs, panels, cards, rows) as Godot scenes (`.tscn` in `scenes/`, with any script at the mirrored path in `scripts/`), and instantiate them. Don't build their node trees in code with `Control.new()`, `Label.new()`, `UIBuilder.hbox()` and the like.

Scenes can be seen and changed in the editor, keep layout out of the logic, and give code and tests stable unique names (`%Name`).

Code is still fine for:

- Filling a scene with data: text, icons, colours, visibility, and freeing the parts a case doesn't use.
- Lists whose length comes from data: a plain container (a `VBoxContainer`, `HFlowContainer` or `GridContainer`) holding scene instances, or single built-in controls such as a label, a button or a `UITheme.chip()`.
- Styleboxes from `UITheme` constants (`UITheme.box()`, `UITheme.pill()`, `UITheme.chip_style()`), as the theme itself is built in code (`UITheme.get_theme()`), and `DashedStyleBox`.
- A dialog's extra buttons (`AcceptDialog.add_button()`), which a scene can't declare.
- Custom-drawn controls (`BattleplanMap`, `RealmMap`, `DieFace`, `Spinner`) and non-visual helpers (`UIBuilder.find_descendant()`, the drag line in `BuilderDragDrop`).

## How the scenes are written

- **A `create()` factory.** A scene whose script needs data has a static `create(...)` that instantiates the scene and fills it, e.g. `AbilityCard.create(rule)`, `UnitRow.create(builder, unit, regiment)`. Scripts take no `_init()` arguments, as a scene can't pass them. Load the scene with `load()` inside `create()`: a script that preloads its own scene is a cyclic reference.
- **Child nodes before `_ready()`.** Factories run before the node enters the tree, so `@onready` variables are still null. Look nodes up with `get_node(^"%Name")` (unique names resolve outside the tree), or assign the script's node variables in `_notification(NOTIFICATION_SCENE_INSTANTIATED)`, which runs as soon as the scene is instantiated (see `PauseMenu`, `BattleHud`, `InfoPane`).
- **Signals in the scene.** Connect a scene's own buttons to its script in the `.tscn` (`[connection ...]`), as `pause_menu.tscn` and `info_pane.tscn` do. Don't also connect them in `_init()`: when an inherited scene swaps the root script, `_init()` runs once per script, and the second connection fails.
- **Inherited scenes for subclasses.** A card that extends another card's script inherits its scene and swaps the script, e.g. `tactic_card.tscn` inherits `pressable_card.tscn`, and `ability_choice_card.tscn` inherits `ability_card.tscn` and adds the check. The same goes for option cards inheriting `option_card.tscn`. A subclass's `create()` may add parameters after its parent's, but not before.
- **Optional parts.** A part only some cases show is in the scene, hidden, and shown when there's something in it. Free it instead when finding it would be wrong even while hidden, e.g. a row's rename button that a Regiment of Renown unit doesn't have, which tests and focus code look up by its `focus_key`.
- **Focus keys.** Give a static button its `focus_key` as `metadata/focus_key` in the scene; give a button whose key comes from data its key in code.
- **Unique names.** Each `unique_name_in_owner` name is unique within its scene, including names in a scene it inherits.

Tests should look for what's shown: `UIKit.find_shown()`, `UIKit.label_texts()` and `UIKit.labels_with_variation()` (`test/support/ui_kit.gd`) skip hidden controls and everything under them.

## What is still built in code

All the screens, overlays, modals, cards and rows are scenes. What's left in code is the kind of thing the rule allows:

- The lists in each screen: plain containers of scene instances, labels and chips, e.g. the army builder's sections, the info pane's tabs, the picker's lists, the Spearhead detail's columns.
- The deployment HUD's placing panel, whose rows of explanation text change with what the player is doing, and the battle HUD's phase steps.
- The fields that replace a name while it's renamed (a `LineEdit` in the army builder, a regiment or a unit row).
- `UIBuilder`'s single-control helpers: `label()`, `button()`, `icon_button()`, `icon_toggle()`, `toggle()`, `select()`, `rich()`, `spacer()` and `breadcrumb()`'s labels.
