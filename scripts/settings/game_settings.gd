class_name GameSettings
extends RefCounted
## The player's settings, saved in [member path]. [method current] is the one the game uses; the
## Settings screen changes it, applies the change and saves it.

## FPS limits the Settings screen offers; 0 is unlimited.
const FPS_LIMITS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]
const RENDER_SCALE_MIN := 0.5
const RENDER_SCALE_MAX := 2.0
## The least room, in UI units, every screen needs to fit: the Forge's columns need 1200 across. A low
## render scale enlarges text and controls only as far as leaves this much.
const MIN_UI_SIZE := Vector2(1280, 720)
## The settings on each of the Settings screen's tabs but Input, which [method reset] puts back.
const GENERAL: PackedStringArray = ["show_legends"]
const GRAPHICS: PackedStringArray = ["fullscreen", "display", "render_scale", "window_resizable", "vsync", "fps_limit"]
const SOUND: PackedStringArray = ["master_volume", "bgm_volume", "sfx_volume", "mute_in_background"]
const BGM_BUS := &"BGM"
const SFX_BUS := &"SFX"

## Where settings are saved. Tests point it elsewhere (test/support/sandbox.gd).
static var path := "user://settings.cfg"
static var _current: GameSettings

# General
## Whether the Forge offers Legends factions and Armies of Renown.
var show_legends := true

# Graphics
var fullscreen: bool = ProjectSettings.get_setting("display/window/size/mode") >= DisplayServer.WINDOW_MODE_FULLSCREEN
## The index of the screen the window is on.
var display := 0
## The resolution as a fraction of the window's, for the UI and the 3D alike. Like picking a lower
## display resolution, a lower scale makes text and controls bigger ([member Window.content_scale_factor],
## see [method ui_scale]) and renders 3D at fewer pixels ([member Viewport.scaling_3d_scale]). The UI is
## still drawn at the window's full resolution, so it stays sharp.
var render_scale := 1.0
## Whether the window's edges and corners can be dragged to resize it, when windowed.
var window_resizable: bool = ProjectSettings.get_setting("display/window/size/resizable")
var vsync: bool = ProjectSettings.get_setting("display/window/vsync/vsync_mode") != DisplayServer.VSYNC_DISABLED
## 0 is unlimited.
var fps_limit := 0

# Sound, each volume from 0 to 1
var master_volume := 1.0
var bgm_volume := 1.0
var sfx_volume := 1.0
## Whether the game is silent while its window isn't focused.
var mute_in_background := true

# Input
## Remapped key bindings, as [InputBindings] saves them, by action. Actions on their defaults aren't
## listed.
var key_bindings := {}


## The settings in use, loaded from [member path] on first use.
static func current() -> GameSettings:
	if _current == null:
		_current = load_from(path)
	return _current


## Forgets the settings in use, so [method current] loads them again, e.g. after [member path] changes.
static func reset_current() -> void:
	_current = null


## Settings read from [param file]: the defaults for anything it doesn't have, or if it doesn't exist.
static func load_from(file: String) -> GameSettings:
	var settings := GameSettings.new()
	var config := ConfigFile.new()
	if config.load(file) != OK:
		return settings
	settings.show_legends = config.get_value("general", "show_legends", settings.show_legends)
	settings.fullscreen = config.get_value("graphics", "fullscreen", settings.fullscreen)
	settings.display = config.get_value("graphics", "display", settings.display)
	settings.render_scale = clampf(config.get_value("graphics", "render_scale", settings.render_scale),
			RENDER_SCALE_MIN, RENDER_SCALE_MAX)
	settings.window_resizable = config.get_value("graphics", "window_resizable", settings.window_resizable)
	settings.vsync = config.get_value("graphics", "vsync", settings.vsync)
	settings.fps_limit = maxi(config.get_value("graphics", "fps_limit", settings.fps_limit), 0)
	for volume in ["master_volume", "bgm_volume", "sfx_volume"]:
		settings.set(volume, clampf(config.get_value("sound", volume, settings.get(volume)), 0.0, 1.0))
	settings.mute_in_background = config.get_value("sound", "mute_in_background", settings.mute_in_background)
	if config.has_section("input"):
		for action in config.get_section_keys("input"):
			if InputBindings.is_remappable(action):
				settings.key_bindings[action] = config.get_value("input", action)
	return settings


func save(file := path) -> Error:
	var config := ConfigFile.new()
	config.set_value("general", "show_legends", show_legends)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "display", display)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "window_resizable", window_resizable)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "fps_limit", fps_limit)
	config.set_value("sound", "master_volume", master_volume)
	config.set_value("sound", "bgm_volume", bgm_volume)
	config.set_value("sound", "sfx_volume", sfx_volume)
	config.set_value("sound", "mute_in_background", mute_in_background)
	for action: String in key_bindings:
		config.set_value("input", action, key_bindings[action])
	return config.save(file)


## How much [param scale] (a render scale) enlarges text and controls: its inverse, but no more than
## [method max_ui_scale].
static func ui_scale(scale: float) -> float:
	return minf(1.0 / scale, max_ui_scale())


## The most text and controls can be enlarged while leaving [constant MIN_UI_SIZE] to lay screens out
## in. The window's stretch aspect is "expand", so at a scale of 1 the UI always has at least the
## project's base size, whatever the window's size.
static func max_ui_scale() -> float:
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	return minf(base.x / MIN_UI_SIZE.x, base.y / MIN_UI_SIZE.y)


## Puts [param properties] (e.g. [constant GRAPHICS]) back to their defaults. Doesn't apply or save them.
func reset(properties: PackedStringArray) -> void:
	var defaults := GameSettings.new()
	for property in properties:
		set(property, defaults.get(property))


## Whether [param properties] all have their default values.
func is_default(properties: PackedStringArray) -> bool:
	var defaults := GameSettings.new()
	for property in properties:
		var value: Variant = get(property)
		var default: Variant = defaults.get(property)
		if not (is_equal_approx(value, default) if value is float else value == default):
			return false
	return true


## Sets [member fullscreen] to whether [param window] is fullscreen, e.g. after starting fullscreen
## from the command line or when the platform couldn't change its mode.
func read_window(window: Window) -> void:
	fullscreen = window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


## Applies every setting to [param window] (the game's main window), the audio buses and the input map.
func apply(window: Window) -> void:
	apply_graphics(window)
	apply_sound()
	apply_input()


func apply_graphics(window: Window) -> void:
	var screens := DisplayServer.get_screen_count()
	if screens > 0 and window.current_screen != clampi(display, 0, screens - 1):
		window.current_screen = clampi(display, 0, screens - 1)
	var mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if window.mode != mode:
		window.mode = mode
	window.unresizable = not window_resizable
	window.content_scale_factor = ui_scale(render_scale)
	window.scaling_3d_scale = render_scale
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED,
			window.get_window_id())
	Engine.max_fps = fps_limit


func apply_sound() -> void:
	for bus: Array in [[&"Master", master_volume], [BGM_BUS, bgm_volume], [SFX_BUS, sfx_volume]]:
		var index := AudioServer.get_bus_index(bus[0])
		if index >= 0:
			AudioServer.set_bus_volume_linear(index, bus[1])


## Mutes the game while [param focused] is false, if [member mute_in_background] is on.
func apply_focus(focused: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), mute_in_background and not focused)


## Sets every remappable action's keys: [member key_bindings]' where remapped, else the defaults.
func apply_input() -> void:
	for action in InputBindings.actions():
		if key_bindings.has(action):
			InputBindings.set_keys(action, InputBindings.decode(key_bindings[action]))
		else:
			InputBindings.set_keys(action, InputBindings.default_keys(action))


## Records the remappable actions' keys from the [InputMap] in [member key_bindings], e.g. after
## remapping one.
func store_input() -> void:
	key_bindings.clear()
	for action in InputBindings.actions():
		if not InputBindings.is_default(action):
			key_bindings[action] = InputBindings.encode(InputBindings.keys(action))
