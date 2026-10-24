class_name Main
extends Node
## Root of the game. Owns screen flow, keeping exactly one screen as a child.

const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const FORGE_SCENE := preload("res://scenes/ui/forge/forge.tscn")

var current_screen: Node


func _ready() -> void:
	show_main_menu()


func show_main_menu() -> void:
	var menu: MainMenu = _show_screen(MAIN_MENU_SCENE)
	menu.forge_pressed.connect(show_forge)


func show_forge() -> void:
	var forge: Forge = _show_screen(FORGE_SCENE)
	forge.back_pressed.connect(show_main_menu)


func _show_screen(scene: PackedScene) -> Node:
	if current_screen:
		remove_child(current_screen)
		current_screen.queue_free()
	current_screen = scene.instantiate()
	add_child(current_screen)
	return current_screen
