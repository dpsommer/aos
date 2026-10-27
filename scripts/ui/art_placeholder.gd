class_name ArtPlaceholder
extends ColorRect
## Diagonal stripes in a rounded box, standing in for unit and army art until there is some.
## Mouse events pass through it.

const SHADER := preload("res://assets/shaders/ui/art_placeholder.gdshader")


func _init(corner_radius := 8.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("radius", corner_radius)
	resized.connect(func() -> void: material.set_shader_parameter("size", size))
