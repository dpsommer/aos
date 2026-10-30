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
Quick Play | Set up and play a quick battle against an AI opponent: game mode, army and battleplan (see [Quick Play](quick-play.md)) | Choosing implemented; no battle yet
Forge | Army builder: create, edit and save armies (see [Forge](forge.md)) | Implemented
Settings | General, graphics, sound and input settings (see [Settings](settings.md)) | Implemented
Quit | Asks "Are you sure you want to quit?" (Cancel or Quit), then closes the game | Implemented

## Quitting

Pressing Quit or Escape opens a confirmation dialog, "Are you sure you want to quit?", with Cancel and Quit buttons. Cancel is focused, so Enter or Escape closes it without quitting. Like every dialog, it's a pane-coloured window, styled by `UITheme`; `UITheme.style_dialog()` sets its title and buttons in Cinzel, with Quit as the gold button.

## Signals

`MainMenu` emits one signal per option: `quick_play_pressed`, `forge_pressed`, `settings_pressed` and `quit_pressed`. The menu doesn't navigate on its own. `Main` (`scripts/main.gd`), the root scene, owns screen flow: it connects to these signals and swaps screens. `quick_play_pressed`, `forge_pressed` and `settings_pressed` are connected. Quit is the exception: once the player confirms, the menu emits `quit_pressed` and closes the game itself. Cancelling emits nothing.
