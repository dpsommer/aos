extends GutTest
## Unit tests for a regiment in the army list (scripts/ui/forge/builder/regiment_panel.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")


## Redrawn sections are removed with queue_free, so let a frame pass for them to be freed before
## GUT counts orphans.
func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	await get_tree().process_frame
	Sandbox.end()


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


# --- Reordering: grips, drops and keyboard ---

## Regiments r1 (lead u1, grunt u2), r2 (wizard u3) and r3 (wizard u4).
func _three_regiments() -> Army:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt"]))
	army.regiments.append(Kit.regiment("r2", [Kit.unit("u3", "wizard")] as Array[ArmyUnit]))
	army.regiments.append(Kit.regiment("r3", [Kit.unit("u4", "wizard")] as Array[ArmyUnit]))
	return army


## The panel the builder drew for the regiment, with a size.
func _drawn_panel(builder: ArmyBuilder, id: String) -> RegimentPanel:
	var found := UIKit.find_all(builder.builder_list, func(n: Node) -> bool: return n is RegimentPanel and n.regiment.id == id)
	var panel: RegimentPanel = found[0]
	panel.size = Vector2(300, 100)
	return panel


func _ids(builder: ArmyBuilder) -> Array:
	return builder.editor.army.regiments.map(func(r: ArmyRegiment) -> String: return r.id)


func _reg(id: String) -> Dictionary:
	return {"kind": "reg", "regiment_id": id}


func _key(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_regiment_has_a_grip() -> void:
	var panel: RegimentPanel = _panel(UIKit.army_with_regiment())[0]
	assert_eq((UIKit.keyed(panel, "r1:grip") as Button).theme_type_variation, &"GripButton")


func test_regiment_of_renown_has_a_grip() -> void:
	var panel: RegimentPanel = _panel(_renown_army(), "r9")[0]
	assert_not_null(UIKit.keyed(panel, "r9:grip"))


func test_dropping_a_regiment_on_the_top_half_moves_it_before() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	var panel := _drawn_panel(builder, "r1")
	assert_true(panel._can_drop_data(Vector2(0, 0), _reg("r3")))
	panel._drop_data(Vector2(0, 0), _reg("r3"))
	assert_eq(_ids(builder), ["r3", "r1", "r2"])


func test_dropping_a_regiment_on_the_bottom_half_moves_it_after() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	var panel := _drawn_panel(builder, "r3")
	panel._drop_data(Vector2(0, panel.size.y), _reg("r1"))
	assert_eq(_ids(builder), ["r2", "r3", "r1"])


func test_dropping_a_regiment_just_after_the_one_before_it_keeps_the_order() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	var panel := _drawn_panel(builder, "r1")
	panel._drop_data(Vector2(0, panel.size.y), _reg("r2"))
	assert_eq(_ids(builder), ["r1", "r2", "r3"])


func test_regiment_drag_shows_the_line() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	_drawn_panel(builder, "r2")._can_drop_data(Vector2.ZERO, _reg("r1"))
	assert_true(builder.drag.line.visible)


func test_regiment_refuses_to_be_dropped_on_itself() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	assert_false(_drawn_panel(builder, "r1")._can_drop_data(Vector2.ZERO, _reg("r1")))


func test_regiment_refuses_data_that_is_not_a_dictionary() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	assert_false(_drawn_panel(builder, "r1")._can_drop_data(Vector2.ZERO, "text"))


func test_regiment_takes_a_roster_unit_at_its_end() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	var data := {"kind": "roster", "warscroll_id": "grunt"}
	var panel := _drawn_panel(builder, "r2")
	assert_true(panel._can_drop_data(Vector2.ZERO, data))
	panel._drop_data(Vector2.ZERO, data)
	var units := builder.editor.army.find_regiment("r2").units
	assert_eq([units.size(), units[-1].warscroll_id], [2, "grunt"])


func test_regiment_takes_a_unit_from_another_regiment_at_its_end() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	_drawn_panel(builder, "r2")._drop_data(Vector2.ZERO, {"kind": "unit", "uid": "u2"})
	var uids := builder.editor.army.find_regiment("r2").units.map(func(u: ArmyUnit) -> String: return u.uid)
	assert_eq(uids, ["u3", "u2"])


func test_full_regiment_refuses_a_roster_unit() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	while builder.editor.add_unit("r2", "grunt"):
		pass
	assert_false(_drawn_panel(builder, "r2")._can_drop_data(Vector2.ZERO, {"kind": "roster", "warscroll_id": "grunt"}))


func test_regiment_of_renown_refuses_units() -> void:
	var builder := UIKit.builder(self, _renown_army())
	var panel := _drawn_panel(builder, "r9")
	assert_false(panel._can_drop_data(Vector2.ZERO, {"kind": "roster", "warscroll_id": "grunt"}))
	assert_false(panel._can_drop_data(Vector2.ZERO, {"kind": "unit", "uid": "u1"}))


func test_regiment_of_renown_takes_a_regiment() -> void:
	var army := UIKit.army_with_regiment()
	army.regiments.append(Kit.ror_regiment("r9", "Band", [Kit.unit("u9", "grunt")] as Array[ArmyUnit]))
	var builder := UIKit.builder(self, army)
	var panel := _drawn_panel(builder, "r9")
	assert_true(panel._can_drop_data(Vector2.ZERO, _reg("r1")))
	panel._drop_data(Vector2.ZERO, _reg("r1"))
	assert_eq(_ids(builder), ["r1", "r9"])
	_drawn_panel(builder, "r1")._drop_data(Vector2.ZERO, _reg("r9"))
	assert_eq(_ids(builder), ["r9", "r1"])


func test_down_moves_a_regiment_after_the_next_one() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	(UIKit.keyed(_drawn_panel(builder, "r1"), "r1:grip") as Button).gui_input.emit(_key("ui_down"))
	assert_eq(_ids(builder), ["r2", "r1", "r3"])


func test_up_moves_a_regiment_before_the_previous_one() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	(UIKit.keyed(_drawn_panel(builder, "r3"), "r3:grip") as Button).gui_input.emit(_key("ui_up"))
	assert_eq(_ids(builder), ["r1", "r3", "r2"])


func test_up_on_the_first_regiment_does_nothing() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	(UIKit.keyed(_drawn_panel(builder, "r1"), "r1:grip") as Button).gui_input.emit(_key("ui_up"))
	assert_eq(_ids(builder), ["r1", "r2", "r3"])


func test_down_on_the_last_regiment_does_nothing() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	(UIKit.keyed(_drawn_panel(builder, "r3"), "r3:grip") as Button).gui_input.emit(_key("ui_down"))
	assert_eq(_ids(builder), ["r1", "r2", "r3"])


func test_other_keys_on_a_regiment_grip_do_nothing() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	(UIKit.keyed(_drawn_panel(builder, "r1"), "r1:grip") as Button).gui_input.emit(_key("ui_accept"))
	assert_eq(_ids(builder), ["r1", "r2", "r3"])


func test_the_regiment_grip_keeps_focus_after_the_regiment_moves() -> void:
	var builder := UIKit.builder(self, _three_regiments())
	var grip := UIKit.keyed(_drawn_panel(builder, "r1"), "r1:grip") as Button
	grip.grab_focus()
	grip.gui_input.emit(_key("ui_down"))
	var focused := builder.get_viewport().gui_get_focus_owner()
	assert_not_null(focused)
	assert_eq(focused.get_meta(&"focus_key", ""), "r1:grip")
