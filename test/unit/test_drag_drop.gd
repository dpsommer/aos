extends GutTest
## Unit tests for drag and drop in the army builder (scripts/ui/forge/builder/drag_drop.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


## Redrawn sections are removed with queue_free, so let a frame pass for them to be freed before
## GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame


## Regiment r1 (general "lead" u1, grunts u2 and u3) and regiment r2 (non-general "wizard" u4 and
## grunt u5), with an auxiliary grunt u6.
func _army() -> Army:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt", "grunt"]))
	army.regiments.append(Kit.regiment("r2", [Kit.unit("u4", "wizard"), Kit.unit("u5", "grunt")] as Array[ArmyUnit]))
	army.auxiliary.append(Kit.unit("u6", "grunt"))
	return army


func _builder(army: Army = null) -> ArmyBuilder:
	return UIKit.builder(self, army if army else _army())


func _drag(builder: ArmyBuilder) -> BuilderDragDrop:
	return builder.drag


func _roster(warscroll_id := "grunt") -> Dictionary:
	return {"kind": "roster", "warscroll_id": warscroll_id}


func _unit(uid: String) -> Dictionary:
	return {"kind": "unit", "uid": uid}


## Fills the regiment with grunts until it has no room.
func _fill(builder: ArmyBuilder, regiment_id: String) -> void:
	while builder.editor.add_unit(regiment_id, "grunt"):
		pass


func _regiment(builder: ArmyBuilder, id: String) -> ArmyRegiment:
	return builder.editor.army.find_regiment(id)


func _uids(units: Array[ArmyUnit]) -> Array:
	return units.map(func(u: ArmyUnit) -> String: return u.uid)


func _panel(builder: ArmyBuilder, id: String) -> RegimentPanel:
	var found := UIKit.find_all(builder.builder_list, func(n: Node) -> bool: return n is RegimentPanel and n.regiment.id == id)
	return found[0]


# --- accepts_unit ---

func test_roster_unit_is_accepted_by_a_regiment_with_room() -> void:
	var builder := _builder()
	assert_true(_drag(builder).accepts_unit(_roster(), _regiment(builder, "r2")))


func test_roster_unit_is_refused_by_a_full_regiment() -> void:
	var builder := _builder()
	_fill(builder, "r2")
	assert_false(_drag(builder).accepts_unit(_roster(), _regiment(builder, "r2")))


func test_roster_unit_is_accepted_by_a_full_regiment_when_overriding() -> void:
	var builder := _builder()
	_fill(builder, "r2")
	builder.editor.set_override_constraints(true)
	assert_true(_drag(builder).accepts_unit(_roster(), _regiment(builder, "r2")))


func test_roster_unit_is_always_accepted_by_the_auxiliary_units() -> void:
	assert_true(_drag(_builder()).accepts_unit(_roster(), null))


func test_roster_unit_is_refused_by_a_regiment_of_renown() -> void:
	var army := _army()
	army.regiments.append(Kit.ror_regiment("r9", "Band", [Kit.unit("u9", "grunt")] as Array[ArmyUnit]))
	var builder := _builder(army)
	assert_false(_drag(builder).accepts_unit(_roster(), _regiment(builder, "r9")))


func test_unit_is_accepted_by_another_regiment_with_room() -> void:
	var builder := _builder()
	assert_true(_drag(builder).accepts_unit(_unit("u2"), _regiment(builder, "r2")))


func test_unit_is_refused_by_another_full_regiment() -> void:
	var builder := _builder()
	_fill(builder, "r2")
	assert_false(_drag(builder).accepts_unit(_unit("u2"), _regiment(builder, "r2")))


func test_unit_is_accepted_by_its_own_full_regiment() -> void:
	var builder := _builder()
	_fill(builder, "r2")
	assert_true(_drag(builder).accepts_unit(_unit("u5"), _regiment(builder, "r2")))


func test_unit_is_accepted_by_the_auxiliary_units() -> void:
	assert_true(_drag(_builder()).accepts_unit(_unit("u2"), null))


func test_unit_from_a_regiment_of_renown_is_refused() -> void:
	var army := _army()
	army.regiments.append(Kit.ror_regiment("r9", "Band", [Kit.unit("u9", "grunt")] as Array[ArmyUnit]))
	var builder := _builder(army)
	assert_false(_drag(builder).accepts_unit(_unit("u9"), _regiment(builder, "r2")))
	assert_false(_drag(builder).accepts_unit(_unit("u9"), null))


func test_unit_is_refused_by_a_regiment_of_renown() -> void:
	var army := _army()
	army.regiments.append(Kit.ror_regiment("r9", "Band", [Kit.unit("u9", "grunt")] as Array[ArmyUnit]))
	var builder := _builder(army)
	assert_false(_drag(builder).accepts_unit(_unit("u2"), _regiment(builder, "r9")))


func test_unit_with_an_unknown_uid_is_refused() -> void:
	var builder := _builder()
	assert_false(_drag(builder).accepts_unit(_unit("nope"), null))


func test_other_kinds_of_drag_are_refused_as_units() -> void:
	var builder := _builder()
	assert_false(_drag(builder).accepts_unit({"kind": "reg", "regiment_id": "r2"}, null))
	assert_false(_drag(builder).accepts_unit({}, null))


# --- place_unit ---

func test_place_a_roster_unit_in_a_regiment_inserts_it_at_the_index() -> void:
	var builder := _builder()
	_drag(builder).place_unit(_roster(), _regiment(builder, "r1"), 2)
	var units := _regiment(builder, "r1").units
	assert_eq([units.size(), units[2].warscroll_id], [4, "grunt"])
	assert_false(units[2].uid in ["u1", "u2", "u3"])


func test_place_a_roster_unit_in_the_auxiliary_units_inserts_it_at_the_index() -> void:
	var builder := _builder()
	_drag(builder).place_unit(_roster("beast"), null, 0)
	assert_eq(builder.editor.army.auxiliary[0].warscroll_id, "beast")


func test_place_a_unit_moves_it_within_its_regiment() -> void:
	var builder := _builder()
	_drag(builder).place_unit(_unit("u3"), _regiment(builder, "r1"), 1)
	assert_eq(_uids(_regiment(builder, "r1").units), ["u1", "u3", "u2"])


func test_place_a_unit_moves_it_to_another_regiment() -> void:
	var builder := _builder()
	_drag(builder).place_unit(_unit("u2"), _regiment(builder, "r2"), 1)
	assert_eq(_uids(_regiment(builder, "r2").units), ["u4", "u2", "u5"])
	assert_eq(_uids(_regiment(builder, "r1").units), ["u1", "u3"])


func test_place_a_unit_moves_it_to_the_auxiliary_units() -> void:
	var builder := _builder()
	_drag(builder).place_unit(_unit("u2"), null, 0)
	assert_eq(_uids(builder.editor.army.auxiliary), ["u2", "u6"])
	assert_eq(_uids(_regiment(builder, "r1").units), ["u1", "u3"])


func test_place_an_auxiliary_unit_in_a_regiment() -> void:
	var builder := _builder()
	_drag(builder).place_unit(_unit("u6"), _regiment(builder, "r2"), 2)
	assert_eq(_uids(_regiment(builder, "r2").units), ["u4", "u5", "u6"])
	assert_true(builder.editor.army.auxiliary.is_empty())


func test_place_a_roster_unit_before_a_hero_leader_goes_after_it() -> void:
	var builder := _builder()
	_drag(builder).place_unit(_roster(), _regiment(builder, "r2"), 0)
	assert_eq(_regiment(builder, "r2").units[0].uid, "u4")


# --- pass_mouse ---

func test_pass_mouse_turns_stop_into_pass_below_the_node() -> void:
	var root := Control.new()
	var child := PanelContainer.new()
	var grandchild := Button.new()
	child.add_child(grandchild)
	root.add_child(child)
	add_child_autofree(root)
	BuilderDragDrop.pass_mouse(root)
	assert_eq([root.mouse_filter, child.mouse_filter, grandchild.mouse_filter],
			[Control.MOUSE_FILTER_PASS, Control.MOUSE_FILTER_PASS, Control.MOUSE_FILTER_PASS])


func test_pass_mouse_leaves_ignored_controls_alone() -> void:
	var root := Control.new()
	var child := Control.new()
	child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(child)
	add_child_autofree(root)
	BuilderDragDrop.pass_mouse(root)
	assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_pass_mouse_skips_nested_targets() -> void:
	var root := Control.new()
	var nested := PanelContainer.new()
	var inside := Button.new()
	nested.add_child(inside)
	root.add_child(nested)
	add_child_autofree(root)
	BuilderDragDrop.pass_mouse(nested)
	nested.mouse_filter = Control.MOUSE_FILTER_STOP
	inside.mouse_filter = Control.MOUSE_FILTER_STOP
	BuilderDragDrop.pass_mouse(root)
	assert_eq([nested.mouse_filter, inside.mouse_filter], [Control.MOUSE_FILTER_STOP, Control.MOUSE_FILTER_STOP])


func test_pass_mouse_marks_the_node_as_a_drop_target() -> void:
	var root := Control.new()
	add_child_autofree(root)
	BuilderDragDrop.pass_mouse(root)
	assert_true(root.has_meta(&"drop_target"))


# --- The line ---

func _box(parent: Control, rect: Rect2) -> Control:
	var box := Control.new()
	parent.add_child(box)
	box.position = rect.position
	box.size = rect.size
	return box


func test_show_line_above_a_rect_puts_the_line_over_its_top() -> void:
	var drag := _drag(_builder())
	drag.show_line(Control.new(), Rect2(10, 100, 200, 40), false)
	autofree(drag._line_owner)
	assert_true(drag.line.visible)
	assert_lt(drag.line.global_position.y + drag.line.size.y, 100.0)
	assert_eq([drag.line.global_position.x, drag.line.size.x], [10.0, 200.0])


func test_show_line_after_a_rect_puts_the_line_under_its_bottom() -> void:
	var drag := _drag(_builder())
	drag.show_line(Control.new(), Rect2(10, 100, 200, 40), true)
	autofree(drag._line_owner)
	assert_gt(drag.line.global_position.y, 140.0)


func test_hide_line_hides_it() -> void:
	var drag := _drag(_builder())
	drag.show_line(null, Rect2(0, 0, 10, 10), false)
	drag.hide_line()
	assert_false(drag.line.visible)


func test_show_line_in_goes_above_the_row_at_the_index() -> void:
	var drag := _drag(_builder())
	var parent := Control.new()
	add_child_autofree(parent)
	var rows: Array = [_box(parent, Rect2(0, 100, 50, 20)), _box(parent, Rect2(0, 200, 50, 20))]
	drag.show_line_in(parent, rows, 1, parent)
	assert_lt(drag.line.global_position.y, 200.0)
	assert_gt(drag.line.global_position.y, 120.0)


func test_show_line_in_past_the_last_row_goes_below_it() -> void:
	var drag := _drag(_builder())
	var parent := Control.new()
	add_child_autofree(parent)
	var rows: Array = [_box(parent, Rect2(0, 100, 50, 20)), _box(parent, Rect2(0, 200, 50, 20))]
	drag.show_line_in(parent, rows, 2, parent)
	assert_gt(drag.line.global_position.y, 220.0)


func test_show_line_in_with_no_rows_goes_below_the_fallback() -> void:
	var drag := _drag(_builder())
	var parent := Control.new()
	add_child_autofree(parent)
	var fallback := _box(parent, Rect2(0, 300, 50, 20))
	drag.show_line_in(parent, [], 0, fallback)
	assert_gt(drag.line.global_position.y, 320.0)


func test_process_hides_the_line_when_nothing_is_hovered() -> void:
	var drag := _drag(_builder())
	var owner_control := Control.new()
	add_child_autofree(owner_control)
	drag.show_line(owner_control, Rect2(0, 0, 10, 10), false)
	drag.process(0.0)
	assert_false(drag.line.visible)


func test_process_hides_the_line_when_its_owner_was_freed() -> void:
	var drag := _drag(_builder())
	var owner_control := Control.new()
	drag.show_line(owner_control, Rect2(0, 0, 10, 10), false)
	owner_control.free()
	drag.process(0.0)
	assert_false(drag.line.visible)


# --- highlight ---

func test_highlight_sets_the_variation_and_unhighlight_restores_it() -> void:
	var drag := _drag(_builder())
	var control := PanelContainer.new()
	control.theme_type_variation = "RowPanel"
	add_child_autofree(control)
	drag.highlight(control, "DropRegimentPanel")
	assert_eq(control.theme_type_variation, &"DropRegimentPanel")
	drag.unhighlight(control)
	assert_eq(control.theme_type_variation, &"RowPanel")


func test_highlighting_twice_still_restores_the_original_variation() -> void:
	var drag := _drag(_builder())
	var control := PanelContainer.new()
	control.theme_type_variation = "RowPanel"
	add_child_autofree(control)
	drag.highlight(control, "DropRegimentPanel")
	drag.highlight(control, "RemoveDropOnPanel")
	drag.unhighlight(control)
	assert_eq(control.theme_type_variation, &"RowPanel")


# --- begin and end ---

func test_begin_highlights_regiments_that_accept_the_drag() -> void:
	var builder := _builder()
	_fill(builder, "r2")
	_drag(builder).begin(_roster())
	assert_eq(_panel(builder, "r1").theme_type_variation, &"DropRegimentPanel")
	assert_ne(_panel(builder, "r2").theme_type_variation, &"DropRegimentPanel")


func test_begin_highlights_the_auxiliary_box() -> void:
	var builder := _builder()
	_drag(builder).begin(_roster())
	assert_eq(builder.auxiliary_box.theme_type_variation, &"DropBoxOnPanel")


func test_begin_does_not_highlight_for_a_regiment_drag() -> void:
	var builder := _builder()
	_drag(builder).begin({"kind": "reg", "regiment_id": "r1"})
	assert_ne(_panel(builder, "r1").theme_type_variation, &"DropRegimentPanel")
	assert_ne(builder.auxiliary_box.theme_type_variation, &"DropBoxOnPanel")


func test_begin_shows_the_remove_overlay_for_a_unit_drag() -> void:
	var builder := _builder()
	_drag(builder).begin(_unit("u2"))
	assert_true(builder.remove_overlay.visible)


func test_begin_keeps_the_remove_overlay_hidden_for_other_drags() -> void:
	var builder := _builder()
	for data in [_roster(), {"kind": "reg", "regiment_id": "r1"}, {"kind": "ror", "name": "Band"}]:
		_drag(builder).begin(data)
		assert_false(builder.remove_overlay.visible, "kind %s" % data.kind)
		_drag(builder).end()


func test_begin_ignores_data_that_is_not_a_dictionary() -> void:
	var builder := _builder()
	_drag(builder).begin("text")
	assert_false(builder.remove_overlay.visible)
	assert_false(builder.is_processing())


func test_begin_enables_processing_and_end_disables_it() -> void:
	var builder := _builder()
	_drag(builder).begin(_unit("u2"))
	assert_true(builder.is_processing())
	_drag(builder).end()
	assert_false(builder.is_processing())


func test_end_restores_highlights() -> void:
	var builder := _builder()
	var before := _panel(builder, "r1").theme_type_variation
	var box_before := builder.auxiliary_box.theme_type_variation
	_drag(builder).begin(_roster())
	_drag(builder).end()
	assert_eq([_panel(builder, "r1").theme_type_variation, builder.auxiliary_box.theme_type_variation], [before, box_before])


func test_end_hides_the_remove_overlay_and_the_line() -> void:
	var builder := _builder()
	_drag(builder).begin(_unit("u2"))
	_drag(builder).show_line(null, Rect2(0, 0, 10, 10), false)
	_drag(builder).end()
	assert_false(builder.remove_overlay.visible)
	assert_false(_drag(builder).line.visible)


func test_end_restores_the_lifted_control() -> void:
	var builder := _builder()
	var control := Control.new()
	add_child_autofree(control)
	_drag(builder).lifted = control
	control.modulate.a = 0.4
	_drag(builder).end()
	assert_eq(control.modulate.a, 1.0)
	assert_null(_drag(builder).lifted)


func test_end_copes_with_a_lifted_control_that_was_freed() -> void:
	var builder := _builder()
	var control := Control.new()
	_drag(builder).lifted = control
	control.free()
	_drag(builder).end()
	assert_null(_drag(builder).lifted)


func test_end_copes_with_highlighted_controls_freed_by_a_redraw() -> void:
	var builder := _builder()
	_drag(builder).begin(_roster())
	builder.editor.add_auxiliary("grunt")
	await get_tree().process_frame
	_drag(builder).end()
	assert_false(builder.is_processing())


func test_drag_notifications_begin_and_end_the_drag() -> void:
	var builder := _builder()
	var source := Control.new()
	builder.add_child(source)
	source.force_drag(_unit("u2"), null)
	assert_true(builder.remove_overlay.visible)
	builder.get_viewport().gui_cancel_drag()
	assert_false(builder.remove_overlay.visible)


# --- Remove overlay ---

func test_dropping_a_unit_on_the_overlay_removes_it() -> void:
	var builder := _builder()
	assert_true(builder._can_drop_remove(Vector2.ZERO, _unit("u2")))
	builder._drop_remove(Vector2.ZERO, _unit("u2"))
	assert_null(builder.editor.army.find_unit("u2"))


func test_the_overlay_highlights_when_a_unit_is_over_it() -> void:
	var builder := _builder()
	builder._can_drop_remove(Vector2.ZERO, _unit("u2"))
	assert_eq(builder.remove_overlay.theme_type_variation, &"RemoveDropOnPanel")


func test_the_overlay_refuses_other_drags_and_unknown_units() -> void:
	var builder := _builder()
	assert_false(builder._can_drop_remove(Vector2.ZERO, _roster()))
	assert_false(builder._can_drop_remove(Vector2.ZERO, _unit("nope")))


# --- Auxiliary units ---

func test_auxiliary_box_accepts_a_roster_unit_and_appends_it() -> void:
	var builder := _builder()
	var box := builder.auxiliary_box.get_child(0)
	var add := UIKit.keyed(builder.auxiliary_box, "army:add_aux")
	assert_true(builder._can_drop_auxiliary(Vector2.ZERO, _roster("beast"), box, add))
	builder._drop_auxiliary(Vector2.ZERO, _roster("beast"))
	assert_eq(builder.editor.army.auxiliary[-1].warscroll_id, "beast")


func test_auxiliary_box_moves_a_regiment_unit_to_the_end() -> void:
	var builder := _builder()
	builder._drop_auxiliary(Vector2.ZERO, _unit("u2"))
	assert_eq(_uids(builder.editor.army.auxiliary), ["u6", "u2"])


func test_auxiliary_box_refuses_regiment_drags() -> void:
	var builder := _builder()
	var box := builder.auxiliary_box.get_child(0)
	var add := UIKit.keyed(builder.auxiliary_box, "army:add_aux")
	assert_false(builder._can_drop_auxiliary(Vector2.ZERO, {"kind": "reg", "regiment_id": "r1"}, box, add))


func test_auxiliary_box_shows_the_line_when_it_accepts() -> void:
	var builder := _builder()
	var box := builder.auxiliary_box.get_child(0)
	var add := UIKit.keyed(builder.auxiliary_box, "army:add_aux")
	builder._can_drop_auxiliary(Vector2.ZERO, _roster(), box, add)
	assert_true(_drag(builder).line.visible)


# --- Regiments of Renown ---

func test_army_list_takes_a_regiment_of_renown() -> void:
	var faction := UIKit.faction()
	faction.regiments_of_renown = [Kit.regiment_of_renown("Band", 100, [Kit.renown_unit("Cap", "lead")] as Array[RegimentUnit],
			[] as Array[Warscroll])] as Array[RegimentOfRenown]
	var builder := UIKit.builder(self, _army(), faction)
	var data := {"kind": "ror", "name": "Band"}
	var section := Control.new()
	add_child_autofree(section)
	assert_true(builder._can_drop_regiment_of_renown(Vector2.ZERO, data, section, section))
	builder._drop_regiment_of_renown(Vector2.ZERO, data)
	assert_true(builder.editor.army.regiments[-1].is_regiment_of_renown())


func test_army_list_refuses_a_regiment_of_renown_the_army_cannot_add() -> void:
	var builder := _builder()
	var section := Control.new()
	add_child_autofree(section)
	assert_false(builder._can_drop_regiment_of_renown(Vector2.ZERO, {"kind": "ror", "name": "Unknown"}, section, section))
	assert_false(builder._can_drop_regiment_of_renown(Vector2.ZERO, _roster(), section, section))


# --- Drag sources, with a real drag in a viewport of its own ---

## A builder in a viewport big enough to lay out, so a drag can start from one of its controls.
func _viewport_builder(army: Army, faction: Faction = null) -> Array:
	var sub := SubViewport.new()
	sub.size = Vector2i(1280, 720)
	add_child_autofree(sub)
	var builder: ArmyBuilder = UIKit.BuilderScene.instantiate()
	sub.add_child(builder)
	builder.open(army, Kit.catalog(faction if faction else UIKit.faction()))
	await get_tree().process_frame
	await get_tree().process_frame
	return [sub, builder]


## Starts dragging from [param control] and returns the dragged data.
func _start_drag(sub: SubViewport, control: Control) -> Variant:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = control.get_global_rect().get_center()
	press.global_position = press.position
	sub.push_input(press)
	var move := InputEventMouseMotion.new()
	move.position = press.position + Vector2(30, 0)
	move.global_position = move.position
	move.relative = Vector2(30, 0)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	sub.push_input(move)
	return sub.gui_get_drag_data()


func test_dragging_a_unit_grip_carries_the_unit() -> void:
	var parts := await _viewport_builder(_army())
	var data = _start_drag(parts[0], UIKit.keyed(parts[1], "u2:grip"))
	assert_eq(data, _unit("u2"))
	parts[0].gui_cancel_drag()


func test_dragging_a_unit_dims_its_row_until_the_drag_ends() -> void:
	var parts := await _viewport_builder(_army())
	_start_drag(parts[0], UIKit.keyed(parts[1], "u2:grip"))
	var row: Control = parts[1].drag.lifted
	assert_lt(row.modulate.a, 1.0)
	assert_true(row is UnitRow)
	parts[0].gui_cancel_drag()
	assert_eq(row.modulate.a, 1.0)


func test_dragging_a_unit_shows_the_remove_overlay_until_the_drag_ends() -> void:
	var parts := await _viewport_builder(_army())
	_start_drag(parts[0], UIKit.keyed(parts[1], "u2:grip"))
	assert_true(parts[1].remove_overlay.visible)
	parts[0].gui_cancel_drag()
	assert_false(parts[1].remove_overlay.visible)


func test_dragging_a_regiment_grip_carries_the_regiment() -> void:
	var parts := await _viewport_builder(_army())
	var data = _start_drag(parts[0], UIKit.keyed(parts[1], "r1:grip"))
	assert_eq(data, {"kind": "reg", "regiment_id": "r1"})
	assert_eq(parts[1].drag.lifted, _panel(parts[1], "r1"))
	parts[0].gui_cancel_drag()


func test_dragging_a_roster_card_carries_the_warscroll() -> void:
	var parts := await _viewport_builder(_army())
	var data = _start_drag(parts[0], UIKit.keyed(parts[1], "info:card:grunt"))
	assert_eq(data, _roster("grunt"))
	parts[0].gui_cancel_drag()


func test_dragging_a_regiment_of_renown_card_carries_its_name() -> void:
	var faction := UIKit.faction()
	faction.regiments_of_renown = [Kit.regiment_of_renown("Band", 100, [Kit.renown_unit("Cap", "lead")] as Array[RegimentUnit],
			[] as Array[Warscroll])] as Array[RegimentOfRenown]
	var parts := await _viewport_builder(_army(), faction)
	parts[1].info_pane.set_tab("renown")
	await get_tree().process_frame
	await get_tree().process_frame
	var cards := UIKit.find_all(parts[1].info_pane, func(n: Node) -> bool: return n is RenownCard)
	var data = _start_drag(parts[0], cards[0])
	assert_eq(data, {"kind": "ror", "name": "Band"})
	parts[0].gui_cancel_drag()
