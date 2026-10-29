# Settings

The Settings screen opens from the main menu's Settings option (`scenes/ui/settings_screen.tscn`, script `scripts/ui/settings_screen.gd`, `SettingsScreen`). It has a header with Back ("Main menu") and four tabs: General, Graphics, Sound and Input. Each tab is a column of setting rows, built with `UIBuilder.switch_row()` and `UIBuilder.setting_row()`, the same rows as the army builder's Army settings.

Every change is applied and saved straight away; there's no Apply or Cancel. Each tab has a **Reset all** button at the top right that puts that tab's settings back to their defaults (see [Saving](#saving)), applies and saves them, then focuses the tab's first setting. It's disabled while the tab's settings are all defaults. The General, Graphics and Sound tabs' settings are listed in `GameSettings.GENERAL`, `GRAPHICS` and `SOUND`, and `GameSettings.reset()` and `is_default()` take those lists; the Input tab's Reset all resets every key (see [Input](#input)). Back or Esc emits `back_pressed`, and `Main` returns to the main menu.

## Tabs

**Tab** | **Setting** | **Control** | **Effect**
-- | -- | -- | --
General | Show Legends armies | Switch | Offers Legends factions (Beasts of Chaos, Fyreslayers) and Legends Armies of Renown when starting an army in the Forge. When off, they're hidden and the Grand Alliance cards' faction counts leave them out. It doesn't change saved armies, the faction browser, or the army builder's own "Show Legends units" setting, though it also hides Legends Armies of Renown in the army builder's settings.
Graphics | Fullscreen | Switch | Fullscreen or windowed (`Window.mode`). The switch shows whether the window really is fullscreen: it's read from the window on launch and whenever the Settings screen opens (`GameSettings.read_window()`), e.g. after starting with `--fullscreen`, or when the window can't change mode, as when it's embedded in the editor.
Graphics | Display | Option list | The screen the window is on (`Window.current_screen`), listed with its resolution. Disabled with only one screen.
Graphics | Render scale | Slider, 50% to 200% | The resolution as a share of the window's, shown with the resolution it gives. It works like picking a display resolution: a lower scale makes text and controls bigger (the root window's `content_scale_factor` is 1 ÷ the scale) and renders 3D at fewer pixels (`Viewport.scaling_3d_scale` is the scale); a higher one makes them smaller and the 3D sharper. The UI is still drawn at the window's full resolution, so it stays sharp. Both are what the Godot manual's [multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) page suggests offering, rather than changing the monitor's resolution. Since the change resizes the slider itself, a drag applies when it ends; keyboard changes apply straight away. Text and controls are enlarged only as far as leaves 1280 × 720 to lay screens out in (`GameSettings.MIN_UI_SIZE`, which fits the Forge's 1200-wide columns): with the project's 1920 × 1080 base size and "expand" stretch aspect, that caps them at 1.5× (`GameSettings.ui_scale()`), so below 67% only the 3D resolution keeps dropping. The slider's note says so. If a screen ever needs more room, raise `MIN_UI_SIZE`.
Graphics | Window resizing | Switch | Whether the window's edges and corners can be dragged to resize it (`Window.unresizable`). Applies when not fullscreen.
Graphics | VSync | Switch | `DisplayServer.window_set_vsync_mode()`, enabled or disabled.
Graphics | FPS limit | Option list | Unlimited, or 30 to 240 FPS (`Engine.max_fps`).
Sound | Master, BGM and SFX volume | Sliders, 0% to 100% | The volume of the Master, BGM and SFX audio buses (`default_bus_layout.tres`). BGM and SFX send to Master. Music should play on BGM and sound effects on SFX.
Sound | Mute in background | Switch | Mutes the Master bus while the game's window isn't focused. `Main` handles the application focus notifications.
Input | Key bindings | See [Input](#input) | Remaps the keys for every action.

## Input

The Input tab lists the remappable actions (`InputBindings.SECTIONS`, `scripts/settings/input_bindings.gd`) by section:
- **Menus:** Confirm (`ui_accept`), Back (`ui_cancel`), Up, Down, Left, Right (`ui_up` and so on), Next control and Previous control (`ui_focus_next`, `ui_focus_prev`).
- **Forge:** Save army (`save_army`, defined in `project.godot`; Command+S on macOS, else Ctrl+S). The army builder's Save button uses it as its shortcut.

Each action's row has three parts: its name, its keys, and Add key and Reset on the right. The keys wrap onto more lines when there are several, and never move or overlap Add key and Reset. Each key is a chip (`KeyChipPanel`) holding the key's button and its remove button; the chip turns gold (`KeyChipListeningPanel`) while that key waits for a new one. An action with no keys says "No keys".

What each part does:
- **A key's button** changes it: it shows "Press a key…", and the next key press, with any modifiers, replaces it. Esc or a click cancels. Pressing only a modifier (Shift, Ctrl, Alt, Command) is ignored.
- **The remove button** (×) beside a key removes it.
- **Add key** listens the same way, adding the key.
- **Reset** puts the action's default keys back. It's disabled while the action has its defaults. **Reset all**, at the top, resets every action.

A key belongs to one action at a time: binding a key that another action has takes it from that action, and a note says so, e.g. "Space was removed from Confirm." Esc can't be bound while listening, as it cancels, but Reset gives Back its Escape key again.

Only keys are remapped. An action's other events, such as gamepad buttons, are kept. New actions that the player should be able to remap go in `InputBindings.SECTIONS`.

## Saving

`GameSettings` (`scripts/settings/game_settings.gd`) holds the settings and saves them as a `ConfigFile` in `user://settings.cfg`, with sections `general`, `graphics`, `sound` and `input`. `GameSettings.current()` is the one the game uses, read on first use; missing or unreadable values take their defaults. The input section lists only remapped actions, each as its keys' codes with modifiers (`InputEventKey.get_keycode_with_modifiers()`), and actions on their defaults are left out.

Defaults:
- Fullscreen, window resizing and VSync follow `project.godot`'s display settings.
- Show Legends armies and Mute in background are on.
- Render scale and the volumes are 100%.
- The FPS limit is Unlimited.

On launch, `Main` applies the saved settings to the window, audio buses and input map (`GameSettings.apply()`), then reads back whether the window is fullscreen. It only does so when it's the running scene, so tests that create `Main` leave the test runner's window alone.
