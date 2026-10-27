extends GutTest
## Unit tests for a regiment in the army list (scripts/ui/forge/builder/regiment_panel.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


## Redrawn sections are removed with queue_free, so let a frame pass for them to be freed before
## GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame


func _panel(army: Army, regiment_id := "r1") -> Array:
	var builder := UIKit.builder(self, army)
	var panel := RegimentPanel.new(builder, army.find_regiment(regiment_id))
	add_child_autofree(panel)
	return [panel, builder]


func _unit_rows(panel: Node) -> Array[Node]:
	return UIKit.find_all(panel, func(n: Node) -> bool: return n is UnitRow)


func _renown_army() -> Army:
	var army := Kit.army()
	army.regiments.append(Kit.ror_regiment("r9", "Band", [Kit.unit("u9", "grunt"), Kit.unit("u10", "grunt")] as Array[ArmyUnit]))
	return army


func test_shows_a_row_for_each_unit() -> void:
	var panel: RegimentPanel = _panel(UIKit.army_with_regiment(PackedStringArray(["grunt", "grunt"])))[0]
	assert_eq(_unit_rows(panel).size(), 3)


func test_collapsed_regiment_shows_no_units() -> void:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	var builder := UIKit.builder(self, army)
	builder.collapsed["r1"] = true
	var panel := RegimentPanel.new(builder, army.regiments[0])
	add_child_autofree(panel)
	assert_eq(_unit_rows(panel).size(), 0)
	assert_null(UIKit.keyed(panel, "r1:add"))


func test_collapse_button_toggles_collapsed() -> void:
	var parts := _panel(UIKit.army_with_regiment())
	UIKit.keyed(parts[0], "r1:collapse").pressed.emit()
	assert_true(parts[1].collapsed.has("r1"))


func test_empty_regiment_asks_for_a_leader() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [] as Array[ArmyUnit]))
	var panel: RegimentPanel = _panel(army)[0]
	assert_eq(UIKit.keyed(panel, "r1:add").text, "Choose a leader")


func test_choose_a_leader_opens_the_leader_picker() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [] as Array[ArmyUnit]))
	var parts := _panel(army)
	UIKit.keyed(parts[0], "r1:add").pressed.emit()
	assert_true(parts[1].picker.is_open())


func test_regiment_with_a_leader_offers_add_unit() -> void:
	var panel: RegimentPanel = _panel(UIKit.army_with_regiment())[0]
	var add := UIKit.keyed(panel, "r1:add") as Button
	assert_eq(add.text, "Add unit")
	assert_false(add.disabled)


func test_add_unit_opens_the_unit_picker() -> void:
	var parts := _panel(UIKit.army_with_regiment())
	UIKit.keyed(parts[0], "r1:add").pressed.emit()
	assert_true(parts[1].picker.is_open())


func test_add_unit_is_disabled_when_the_regiment_is_full() -> void:
	var army := UIKit.army_with_regiment()
	var members := PackedStringArray()
	members.resize(ArmyValidator.regiment_capacity(army.regiments[0], army))
	members.fill("grunt")
	army = UIKit.army_with_regiment(members)
	var panel: RegimentPanel = _panel(army)[0]
	assert_true((UIKit.keyed(panel, "r1:add") as Button).disabled)


func test_add_unit_is_enabled_when_full_but_constraints_are_overridden() -> void:
	var members := PackedStringArray()
	members.resize(ArmyValidator.GENERAL_REGIMENT_UNITS + 1)
	members.fill("grunt")
	var army := UIKit.army_with_regiment(members)
	army.override_constraints = true
	var panel: RegimentPanel = _panel(army)[0]
	assert_false((UIKit.keyed(panel, "r1:add") as Button).disabled)


func test_rename_button_starts_renaming() -> void:
	var parts := _panel(UIKit.army_with_regiment())
	UIKit.keyed(parts[0], "r1:rename").pressed.emit()
	assert_eq(parts[1].renaming, "r1")


func test_renaming_regiment_shows_a_name_field() -> void:
	var army := UIKit.army_with_regiment()
	var builder := UIKit.builder(self, army)
	builder.renaming = "r1"
	var panel := RegimentPanel.new(builder, army.regiments[0])
	add_child_autofree(panel)
	assert_true(UIKit.keyed(panel, "r1:name") is LineEdit)


func test_delete_button_removes_the_regiment() -> void:
	var army := UIKit.army_with_regiment()
	var panel: RegimentPanel = _panel(army)[0]
	UIKit.keyed(panel, "r1:delete").pressed.emit()
	assert_eq(army.regiments.size(), 0)


func test_regiment_of_renown_can_be_deleted() -> void:
	var army := _renown_army()
	var panel: RegimentPanel = _panel(army, "r9")[0]
	UIKit.keyed(panel, "r9:delete").pressed.emit()
	assert_eq(army.regiments.size(), 0)


func test_regiment_of_renown_cannot_be_renamed_or_added_to() -> void:
	var panel: RegimentPanel = _panel(_renown_army(), "r9")[0]
	assert_null(UIKit.keyed(panel, "r9:rename"))
	assert_null(UIKit.keyed(panel, "r9:add"))


func test_regiment_of_renown_shows_its_units() -> void:
	var panel: RegimentPanel = _panel(_renown_army(), "r9")[0]
	assert_eq(_unit_rows(panel).size(), 2)


func test_regiment_of_renown_panel_uses_the_renown_style() -> void:
	var renown: RegimentPanel = _panel(_renown_army(), "r9")[0]
	var plain: RegimentPanel = _panel(UIKit.army_with_regiment())[0]
	assert_ne(renown.theme_type_variation, plain.theme_type_variation)
