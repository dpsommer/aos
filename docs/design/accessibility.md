# Accessibility

What's implemented so far, by screen. Settings for accessibility (text size, colour, input remapping) don't exist yet.

## Keyboard

Screens are built from standard focusable controls, so they can be used without a mouse.
- **Focus:** Tab and the arrow keys move focus, and Enter or Space presses the focused control. A focused control has a gold outline.
- **Esc:** goes back one step: it does the same as the visible Back button on each screen. In the army builder, Esc first clears the search box (when it's focused and has text), then closes the picker, then cancels a rename. In a confirmation (deleting an army, leaving with unsaved changes), Esc cancels it. See [Forge](forge.md).

### Forge

- **Header:** Back is on every step. Its text names where it goes, and it does the same as Esc.
- **Cards:** the Grand Alliance, faction, Army of Renown and battle formation cards are buttons, and each has an accessibility name: the alliance, faction, army or formation, with "(Legends)" where it applies.
  - Army of Renown and formation cards are toggle buttons, so they report whether they're chosen.
  - Unavailable factions are disabled, with the description "Coming soon".
  - After choosing, Tab reaches the footer's Continue button.
- **Saved armies:** Duplicate and Delete are icon buttons named with the army, e.g. "Delete Vanguard strike force".

### Army builder
- **Reordering:** a unit's or regiment's grip moves it up or down with the Up and Down keys, as dragging it does. A unit stays within its regiment, and a Hero leader stays first, so it has no grip. To move a unit to another regiment without a mouse, remove it and add it there.
- **Focus after changes:** the army list is rebuilt after every change, and focus returns to the same control. A grip keeps focus while its unit or regiment moves.
- **Links:** a unit's portrait and a short battle tactics card can be focused and pressed with Enter or Space. They open the unit or card in the info pane, which scrolls to it, highlights it and gives it focus.

## Screen readers

Icon-only buttons (grips, General, Reinforce, Options, Copy, Remove, the settings tab, the saved armies' Duplicate and Delete, and others) have an accessibility name, which is also their tooltip. Fold buttons describe whether they're expanded or collapsed.
