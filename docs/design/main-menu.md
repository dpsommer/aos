# Main menu

The main menu is the game's entry point (`scenes/ui/main_menu.tscn`, script `scripts/ui/main_menu.gd`). It shows the title and four options, with Quick Play focused on launch for keyboard and gamepad navigation.

**Option** | **Destination** | **Status**
-- | -- | --
Quick Play | Set up and play a quick battle against an AI opponent | Not implemented
Forge | Army builder: create, edit and save armies | Not implemented
Settings | Graphics, audio and control settings | Not implemented
Quit | Closes the game | Implemented

## Signals

`MainMenu` emits one signal per option: `quick_play_pressed`, `forge_pressed`, `settings_pressed` and `quit_pressed`. The menu doesn't navigate on its own; whatever owns screen flow connects to these signals and changes screen. Quit is the exception: after emitting `quit_pressed` it closes the game.
