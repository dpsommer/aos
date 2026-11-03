class_name ArtPlaceholder
extends ColorRect
## Diagonal stripes in a rounded box, standing in for unit and army art until there is some, with an
## optional caption (e.g. an army's initials) or icon in the middle. Mouse events pass through it.

## The rounded corners' radius in pixels.
var corner_radius := 8.0:
	set(value):
		corner_radius = value
		(material as ShaderMaterial).set_shader_parameter("radius", value)


## Placeholder art with corners of [param radius] pixels.
static func create(radius := 8.0) -> ArtPlaceholder:
	var art: ArtPlaceholder = load("res://scenes/ui/common/art_placeholder.tscn").instantiate()
	art.corner_radius = radius
	return art


func _init() -> void:
	resized.connect(func() -> void: (material as ShaderMaterial).set_shader_parameter("size", size))


## Shows [param text] in the middle at [param font_size].
func set_caption(text: String, font_size := 14) -> void:
	var caption: Label = %Caption
	caption.text = text
	caption.add_theme_font_size_override("font_size", font_size)
	caption.visible = true


## Shows [param texture] in the middle at [param icon_size] pixels, in the text colour.
func set_icon(texture: Texture2D, icon_size: int) -> void:
	var icon: TextureRect = %Icon
	icon.texture = texture
	icon.modulate = UITheme.TEXT
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	icon.visible = true
