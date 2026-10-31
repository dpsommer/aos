extends GutTest
## Unit tests for the loading screen (scripts/ui/battle/loading_screen.gd). It opens a real
## Spearhead, as the data it needs (battlepacks, faction) is loaded from the game's files.

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")
const LoadingScene := preload("res://scenes/ui/battle/loading_screen.tscn")


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	Sandbox.end()


## A screen opened for the first real Spearhead, which doesn't build by itself.
func _opened() -> LoadingScreen:
	var screen: LoadingScreen = LoadingScene.instantiate()
	screen.min_seconds = 0.0
	add_child_autofree(screen)
	screen.set_process(false)
	var setup := BattleKit.real_spearhead_setup()
	assert_not_null(setup, "the game data should have a Spearhead")
	screen.open(setup)
	return screen


func test_open_builds_the_battle() -> void:
	assert_is(_opened().battle, Battle)


func test_open_prepares_the_steps_without_running_them() -> void:
	var screen := _opened()
	assert_gt(screen.steps.size(), 0)
	assert_eq(screen.done, 0)


func test_open_shows_the_matchup() -> void:
	var screen := _opened()
	assert_true(UIKit.has_label_containing(screen, screen.battle.player.name))
	assert_true(UIKit.has_label_containing(screen, screen.battle.player.details()))


func test_progress_starts_at_zero() -> void:
	assert_eq(_opened().progress(), 0.0)


func test_advance_runs_one_step() -> void:
	var screen := _opened()
	screen.advance()
	assert_eq(screen.done, 1)


func test_advance_increases_progress() -> void:
	var screen := _opened()
	screen.advance()
	assert_gt(screen.progress(), 0.0)
	assert_lt(screen.progress(), 1.0)


func test_advance_says_whether_steps_remain() -> void:
	var screen := _opened()
	assert_true(screen.advance())
	while screen.done < screen.steps.size() - 1:
		screen.advance()
	assert_false(screen.advance())


func test_advance_after_the_last_step_does_nothing() -> void:
	var screen := _opened()
	while screen.advance():
		pass
	var done := screen.done
	screen.advance()
	assert_eq(screen.done, done)


func test_progress_bar_follows_the_steps() -> void:
	var screen := _opened()
	screen.advance()
	assert_almost_eq(screen.progress_bar.value, screen.progress() * 100, 0.01)


func test_step_label_shows_the_current_step() -> void:
	var screen := _opened()
	assert_eq(screen.step_label.text, screen.steps[0].text)
	screen.advance()
	assert_eq(screen.step_label.text, screen.steps[1].text)


func test_checklist_starts_with_the_first_stage_current() -> void:
	var screen := _opened()
	assert_true(screen.stage_labels[0].text.begins_with("●"))
	assert_false(screen.stage_labels[1].text.begins_with("●"))


func test_checklist_ticks_the_stages_that_are_done() -> void:
	var screen := _opened()
	while screen.steps[screen.done].stage <= BattleMap.Stage.TERRAIN:
		screen.advance()
	assert_true(screen.stage_labels[BattleMap.Stage.BATTLEFIELD].text.begins_with("✓"))
	assert_true(screen.stage_labels[BattleMap.Stage.TERRAIN].text.begins_with("✓"))
	assert_true(screen.stage_labels[BattleMap.Stage.OBJECTIVES].text.begins_with("●"))


func test_checklist_names_every_stage() -> void:
	var screen := _opened()
	for i in screen.stage_labels.size():
		assert_string_contains(screen.stage_labels[i].text, BattleMap.STAGES[i])


func test_finishing_ticks_every_stage() -> void:
	var screen := _opened()
	screen.finish()
	autofree(screen.map)
	for label in screen.stage_labels:
		assert_true(label.text.begins_with("✓"), label.text)


func test_finish_builds_every_step() -> void:
	var screen := _opened()
	screen.finish()
	autofree(screen.map)
	assert_eq(screen.done, screen.steps.size())
	assert_eq(screen.progress(), 1.0)


func test_finish_emits_finished_with_the_map() -> void:
	var screen := _opened()
	watch_signals(screen)
	screen.finish()
	autofree(screen.map)
	assert_signal_emitted_with_parameters(screen, "finished", [screen.map])
	assert_is(screen.map, BattleMap)


func test_finished_map_is_built() -> void:
	var screen := _opened()
	screen.finish()
	autofree(screen.map)
	assert_not_null(screen.map.camera)


func test_finished_is_emitted_once() -> void:
	var screen := _opened()
	watch_signals(screen)
	screen.finish()
	autofree(screen.map)
	screen.finish()
	assert_signal_emit_count(screen, "finished", 1)


func test_the_screen_hands_over_by_itself_once_built() -> void:
	var screen := _opened()
	screen.set_process(true)
	watch_signals(screen)
	await wait_for_signal(screen.finished, 5)
	autofree(screen.map)
	assert_signal_emitted(screen, "finished")


func test_the_screen_waits_for_its_minimum_time() -> void:
	var screen := _opened()
	screen.min_seconds = 3600.0
	screen.set_process(true)
	watch_signals(screen)
	await wait_process_frames(5)
	assert_eq(screen.done, screen.steps.size())
	assert_signal_not_emitted(screen, "finished")


func test_the_map_is_freed_with_the_screen_if_not_handed_over() -> void:
	var screen := _opened()
	var map := screen.map
	remove_child(screen)
	screen.free()
	assert_false(is_instance_valid(map))


func test_the_map_outlives_the_screen_once_handed_over() -> void:
	var screen := _opened()
	screen.finish()
	var map := screen.map
	remove_child(screen)
	screen.free()
	assert_true(is_instance_valid(map))
	map.free()


func test_an_unusable_setup_emits_failed() -> void:
	var screen: LoadingScreen = LoadingScene.instantiate()
	add_child_autofree(screen)
	watch_signals(screen)
	screen.open(BattleSetup.new())
	await wait_for_signal(screen.failed, 2)
	assert_signal_emitted(screen, "failed")


func test_failed_says_why() -> void:
	var screen: LoadingScreen = LoadingScene.instantiate()
	add_child_autofree(screen)
	watch_signals(screen)
	screen.open(BattleSetup.new())
	await wait_for_signal(screen.failed, 2)
	assert_false(get_signal_parameters(screen, "failed")[0].is_empty())


func test_a_failed_screen_has_no_map_and_never_finishes() -> void:
	var screen: LoadingScreen = LoadingScene.instantiate()
	add_child_autofree(screen)
	watch_signals(screen)
	screen.open(BattleSetup.new())
	await wait_for_signal(screen.failed, 2)
	assert_null(screen.map)
	assert_eq(screen.steps.size(), 0)
	assert_signal_not_emitted(screen, "finished")


func test_a_failed_screen_has_no_progress() -> void:
	var screen: LoadingScreen = LoadingScene.instantiate()
	add_child_autofree(screen)
	screen.open(BattleSetup.new())
	assert_eq(screen.progress(), 0.0)
