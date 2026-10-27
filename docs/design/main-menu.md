# Main menu

The main menu is the first screen `Main` shows on launch (`scenes/ui/main_menu.tscn`, script `scripts/ui/main_menu.gd`). It shows the title and four options, with Quick Play focused on launch for keyboard and gamepad navigation.

It's styled by `UITheme`, like every screen (see [Forge](forge.md#look)):
- **Layout:** the title in Cinzel, with "Battle simulator" below it, and the options in a 360 px column on the left.
- **Buttons:**
  - Quick Play is the gold primary button;
  - Forge and Settings are standard buttons;
  - Quit is outlined.

**Option** | **Destination** | **Status**
-- | -- | --
Quick Play | Set up and play a quick battle against an AI opponent | Not implemented
Forge | Army builder: create, edit and save armies (see [Forge](forge.md)) | Implemented
Settings | Graphics, audio and control settings | Not implemented
Quit | Closes the game | Implemented

## Signals

`MainMenu` emits one signal per option: `quick_play_pressed`, `forge_pressed`, `settings_pressed` and `quit_pressed`. The menu doesn't navigate on its own. `Main` (`scripts/main.gd`), the root scene, owns screen flow: it connects to these signals and swaps screens. Only `forge_pressed` is connected so far. Quit is the exception: after emitting `quit_pressed` the menu closes the game itself.
