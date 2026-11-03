extends PanelContainer
## The gold check a selected card shows in its corner.


func _init() -> void:
	add_theme_stylebox_override("panel", UITheme.box(UITheme.GOLD, Color.TRANSPARENT, 12, 5))
