extends GutTest
## Unit tests for the army select detail pane's heading (scripts/ui/quick_play/army_heading.gd).

const LONG_NAME := "A Very Long Army Name That Cannot Fit On One Line Of A Narrow Heading"


func _heading(title: String, width: float) -> ArmyHeading:
	var holder := Control.new()
	add_child_autofree(holder)
	var heading := ArmyHeading.create(title, "Subtitle", "0 / 2000 pts")
	var pill := Label.new()
	pill.text = "3 problems"
	heading.get_node(^"%TitleRow").add_child(pill)
	holder.add_child(heading)
	heading.size = Vector2(width, 0)
	return heading


func _title(heading: ArmyHeading) -> Label:
	return heading.get_node(^"%Title")


func test_a_short_name_keeps_its_own_width() -> void:
	var heading := _heading("Iron Sky", 1000)
	await wait_process_frames(2)
	assert_almost_eq(_title(heading).custom_minimum_size.x, ceilf(heading.title_width()), 1.0)


func test_a_long_name_wraps_to_leave_room_for_the_rest_of_its_row() -> void:
	var heading := _heading(LONG_NAME, 400)
	await wait_process_frames(2)
	assert_lt(heading.get_node(^"%TitleRow").get_combined_minimum_size().x, 400.1)
	assert_gt(_title(heading).get_line_count(), 1)


func test_a_long_name_does_not_widen_the_heading() -> void:
	var heading := _heading(LONG_NAME, 400)
	await wait_process_frames(2)
	assert_lt(heading.get_combined_minimum_size().x, 400.1)
