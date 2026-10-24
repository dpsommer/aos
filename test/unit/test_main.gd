extends GutTest
## Unit tests for top-level screen flow (scripts/main.gd).

const MainScene := preload("res://scenes/main.tscn")


## Screens and faction buttons are removed with queue_free, so let a frame pass for
## them to be freed before GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame


## Returns a fresh Main instance added to the tree, which shows its first screen on ready.
func _make_main() -> Main:
	var main: Main = MainScene.instantiate()
	add_child_autofree(main)
	return main


func test_starts_on_main_menu() -> void:
	var main := _make_main()
	assert_is(main.current_screen, MainMenu)


func test_starts_with_one_child() -> void:
	var main := _make_main()
	assert_eq(main.get_child_count(), 1)


func test_current_screen_is_a_child() -> void:
	var main := _make_main()
	assert_eq(main.current_screen.get_parent(), main)


func test_menu_forge_pressed_shows_forge() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	assert_is(main.current_screen, Forge)


func test_menu_forge_pressed_leaves_one_child() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	assert_eq(main.get_child_count(), 1)


func test_menu_forge_pressed_frees_menu() -> void:
	var main := _make_main()
	var menu := main.current_screen
	menu.forge_pressed.emit()
	assert_true(menu.is_queued_for_deletion())


func test_forge_back_pressed_shows_main_menu() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	(main.current_screen as Forge).back_pressed.emit()
	assert_is(main.current_screen, MainMenu)


func test_forge_back_pressed_leaves_one_child() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	(main.current_screen as Forge).back_pressed.emit()
	assert_eq(main.get_child_count(), 1)


func test_returned_main_menu_can_open_forge_again() -> void:
	var main := _make_main()
	(main.current_screen as MainMenu).forge_pressed.emit()
	(main.current_screen as Forge).back_pressed.emit()
	(main.current_screen as MainMenu).forge_pressed.emit()
	assert_is(main.current_screen, Forge)
