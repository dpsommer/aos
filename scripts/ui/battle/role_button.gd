class_name RoleButton
extends Button
## A roll-off winner's choice of role: a preview of their territory beside the role's name and
## what it means. It grows taller to fit its description, as a button doesn't grow to fit its
## children. See [RollOffPanel].

## The button's smallest size.
const MIN_SIZE := Vector2(400, 104)


## A button for the attacker if [param attacks], else the defender, described by [param label], with
## [param preview] (e.g. a [BattleplanMap]) on its left.
static func create(attacks: bool, label: String, preview: Control) -> RoleButton:
	var button: RoleButton = load("res://scenes/ui/battle/role_button.tscn").instantiate()
	var role := "Attacker" if attacks else "Defender"
	button.name = role + "Button"
	button.accessibility_name = "%s: %s" % [role, label]
	(button.get_node(^"%Name") as Label).text = role
	(button.get_node(^"%Text") as Label).text = label
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = button.get_node(^"%Row")
	row.add_child(preview)
	row.move_child(preview, 0)
	button._fit_content.call_deferred()
	return button


func _fit_content() -> void:
	custom_minimum_size.y = maxf(MIN_SIZE.y, (%Margin as Control).get_combined_minimum_size().y)
