class_name Spinner
extends Control
## A turning gold arc that shows a screen is working, e.g. the loading screen.


func _process(delta: float) -> void:
	rotation += TAU * delta
	pivot_offset = size / 2


func _draw() -> void:
	draw_arc(size / 2, size.x / 2 - 1.5, 0, TAU * 0.75, 24, UITheme.GOLD, 2.4, true)
