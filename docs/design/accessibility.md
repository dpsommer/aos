# Accessibility

What's implemented so far, by screen. Keys can be remapped in Settings (see [Settings](settings.md#input)); settings for text size and colour don't exist yet.

## Keyboard

Screens are built from standard focusable controls, so they can be used without a mouse.
- **Focus:** Tab and the arrow keys move focus, and Enter or Space presses the focused control. A focused control has a gold outline.
- **Esc:** goes back one step: it does the same as the visible Back button on each screen. On the main menu, it asks to quit, as Quit does. In the army builder, Esc first clears the search box (when it's focused and has text), then closes the picker, then cancels a rename. In a confirmation (quitting, deleting an army, leaving with unsaved changes), Esc cancels it. See [Forge](forge.md).

### Forge

- **Header:** Back is on every step. Its text names where it goes, and it does the same as Esc.
- **Cards:** the Grand Alliance, faction, Army of Renown and battle formation cards are buttons, and each has an accessibility name: the alliance, faction, army or formation, with "(Legends)" where it applies.
  - Unavailable factions are disabled, with the description "Coming soon".
  - Enter or Space on a card chooses it and moves to the next step. Going back to a step focuses the card chosen there.
- **Saved armies:** Duplicate and Delete are icon buttons named with the army, e.g. "Delete Vanguard strike force".

### Army builder
- **Reordering:** a unit's or regiment's grip moves it up or down with the Up and Down keys, as dragging it does. A unit stays within its regiment, and a Hero leader stays first, so it has no grip. To move a unit to another regiment without a mouse, remove it and add it there.
- **Focus after changes:** the army list is rebuilt after every change, and focus returns to the same control. A grip keeps focus while its unit or regiment moves. If that control is gone (a deleted unit, say), focus moves to the picker's first button while it's open, else to Back. Closing the picker, by picking or with Esc, returns focus to the button that opened it.
- **Links:** a unit's portrait and a short battle tactics card can be focused and pressed with Enter or Space. They open the unit or card in the info pane, which scrolls to it, highlights it and gives it focus.
- **Battle tactics cards:** every battle tactics card that can be focused (in the army list, the Rules tab and the picker) has a gold outline while it has keyboard focus. In the picker, the whole card is a button: Enter or Space chooses it, and the first card is focused when the picker opens.
- **Save:** Save army's tooltip names the `save_army` action's first key: by default Command+S on macOS, else Ctrl+S.

### Quick Play

- **Esc:** goes back one step. On the army screen it first closes a warscroll, Regiment of Renown or the battleplans and returns to the list, focusing the control that opened them; in the Spearhead search box with text, it clears the search.
- **Cards:** the mode cards, army and Spearhead cards, portraits, the battle plan card, battleplans and Spearhead choices can all be focused and pressed with Enter or Space. A Spearhead choice has a chevron and a battleplan card an eye toggle that shows their rules without choosing them.
- **Play:** while disabled, its tooltip says what's missing, e.g. "Choose a regiment ability and an enhancement to play". An army's "!" badge, named with its problems, isn't a tab stop: the problems are listed in the army's detail too.

### Settings

- **Esc:** goes back to the main menu, unless a key is being remapped: then it cancels the remap.
- **Rows:** switches, sliders and option lists are named for screen readers by their setting, and a slider's description is its shown value, e.g. "75% · 1440 × 810".
- **Key bindings:** every key, remove button, Add key and Reset is a button named for its action, e.g. "Change Confirm: Enter" or "Remove Space from Confirm". After a change, focus goes to the changed key; after removing a key or resetting, to the action's Add key. After a tab's Reset all, which is then disabled, focus goes to the tab's first setting.

## Colour

Chips (tags such as Legends, Scourge of Aqshy or a battle tactic's kind) have pale text with a WCAG contrast of at least 9:1 against their background, above the 7:1 of WCAG AAA, as their text is small. A unit test checks every chip colour.

[Ability cards](abilities.md) are coloured as on the warscrolls, but the colour is never the only cue: the header always spells out the timing. Its text has a contrast of at least 4.5:1 against every ability colour (`UITheme.ABILITY_COLOUR_MIN_CONTRAST`).

## Screen readers

Icon-only buttons (grips, General, Reinforce, Options, Copy, Remove, the settings tab, the saved armies' Duplicate and Delete, and others) have an accessibility name, which is also their tooltip. Fold buttons describe whether they're expanded or collapsed. An ability card's accessibility name is the ability's name and its description is its frequency and timing.
