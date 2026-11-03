extends GutTest
## Unit tests for the deployment phase's overlay (scripts/ui/battle/deployment_hud.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")

var _battle: Battle
var _d: Deployment
var _me: BattleArmy


func before_each() -> void:
	Sandbox.begin()
	_battle = BattleKit.deployment_battle()
	_me = _battle.player
	_d = Deployment.new(_battle)


func after_each() -> void:
	Sandbox.end()


func _hud(state := {}) -> DeploymentHud:
	_d.start()
	var hud := DeploymentHud.create(_d, _me)
	add_child_autofree(hud)
	hud.refresh(state)
	return hud


func _unit(unit_name: String) -> BattleUnit:
	for unit in _me.units:
		if unit.name == unit_name:
			return unit
	return null


func _put(army: BattleArmy, unit_name: String, across := 30.0) -> void:
	var unit: BattleUnit = army.units.filter(func(u: BattleUnit) -> bool: return u.name == unit_name)[0]
	var anchor := Vector2(across, 5) if army == _battle.player else Vector2(across, 39)
	_d.place_unit(army, unit, Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, anchor, army.facing), army.facing)


func _reserve_entry(owner_name := "Aux") -> DeploymentAbility:
	var ability := BattleKit.ability("Hide", PackedStringArray(["DEPLOY"]), "Set up this unit in reserve in the clouds.", "Pick this unit.")
	var entry := BattleKit.deploy_entry(ability, "Warscroll", _unit(owner_name))
	_me.deployment_abilities.append(entry)
	return entry


func _record_entry() -> DeploymentAbility:
	var ability := BattleKit.ability("Scout", PackedStringArray(), "Do something.")
	ability.timing = DeploymentAbility.TIMING
	var entry := BattleKit.deploy_entry(ability)
	_me.deployment_abilities.append(entry)
	return entry


# banner

func test_banner_says_it_is_the_players_turn() -> void:
	assert_eq(_hud().banner_title.text, "Your deployment")


func test_banner_says_it_is_the_opponents_turn() -> void:
	var hud := _hud()
	_put(_me, "A1")
	hud.refresh({})
	assert_eq(hud.banner_title.text, "Opponent's deployment")


func test_banner_says_when_deployment_is_complete() -> void:
	for army in [_battle.player, _battle.opponent]:
		for unit: BattleUnit in army.units:
			unit.deployed = true
	var hud := _hud()
	assert_eq(hud.banner_title.text, "Deployment complete")


func test_banner_names_the_regiment_being_deployed() -> void:
	var hud := _hud()
	_d.begin_regiment(_me, _me.regiments[0])
	hud.refresh({})
	assert_string_contains(hud.banner_text.text, _me.regiments[0].name)


func test_banner_prompt_differs_by_whose_turn_it_is() -> void:
	var hud := _hud()
	var mine := hud.banner_text.text
	_put(_me, "A1")
	hud.refresh({})
	assert_ne(hud.banner_text.text, mine)


func test_banner_prompt_in_the_terrain_step_is_about_terrain() -> void:
	_me.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	assert_string_contains(_hud().banner_text.text.to_lower(), "terrain")


# tray

func test_tray_has_a_button_for_every_unit_and_regiment() -> void:
	var hud := _hud()
	for unit in _me.units:
		assert_true(hud.tray_buttons.has(unit), unit.name)
	for regiment in _me.regiments:
		assert_true(hud.tray_buttons.has(regiment), regiment.name)


func test_tray_is_visible_while_there_are_units_to_deploy() -> void:
	assert_true(_hud().is_tray_visible())


func test_tray_is_hidden_once_deployment_is_done() -> void:
	for army in [_battle.player, _battle.opponent]:
		for unit: BattleUnit in army.units:
			unit.deployed = true
	assert_false(_hud().is_tray_visible())


func test_player_can_pick_every_unit_on_their_turn() -> void:
	var hud := _hud()
	for unit in _me.units:
		assert_false(hud.tray_buttons[unit].disabled, unit.name)


func test_units_cannot_be_picked_on_the_opponents_turn() -> void:
	var hud := _hud()
	_put(_me, "A1")
	hud.refresh({})
	for unit in _me.undeployed_units():
		assert_true(hud.tray_buttons[unit].disabled, unit.name)


func test_units_cannot_be_picked_while_the_ai_is_busy() -> void:
	var hud := _hud({"busy": true})
	assert_true(hud.tray_buttons[_unit("A1")].disabled)


func test_a_deployed_unit_cannot_be_picked_again() -> void:
	var hud := _hud()
	_put(_me, "A1")
	_put(_battle.opponent, "A1")
	hud.refresh({})
	assert_true(hud.tray_buttons[_unit("A1")].disabled)


func test_only_the_regiments_units_can_be_picked_while_deploying_it() -> void:
	var hud := _hud()
	_d.begin_regiment(_me, _me.regiments[0])
	hud.refresh({})
	assert_false(hud.tray_buttons[_unit("A1")].disabled)
	assert_true(hud.tray_buttons[_unit("B1")].disabled)
	assert_true(hud.tray_buttons[_unit("Aux")].disabled)


func test_a_regiment_can_be_picked_while_it_is_whole() -> void:
	assert_false(_hud().tray_buttons[_me.regiments[0]].disabled)


func test_a_regiment_broken_up_cannot_be_picked() -> void:
	var hud := _hud()
	_put(_me, "A1")
	_put(_battle.opponent, "A1")
	hud.refresh({})
	assert_true(hud.tray_buttons[_me.regiments[0]].disabled)


func test_a_broken_regiment_says_why_in_its_tooltip() -> void:
	var hud := _hud()
	_put(_me, "A1")
	_put(_battle.opponent, "A1")
	hud.refresh({})
	assert_string_contains(hud.tray_buttons[_me.regiments[0]].tooltip_text, "A1")


func test_the_regiment_button_cannot_be_picked_in_the_terrain_step() -> void:
	_me.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	var hud := _hud()
	assert_false(hud.tray_buttons.has(_me.regiments[0]))


func test_tray_in_the_terrain_step_lists_the_terrain() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(feature)
	var hud := _hud()
	assert_true(hud.tray_buttons.has(feature))
	assert_false(hud.tray_buttons[feature].disabled)


func test_placed_terrain_cannot_be_picked() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(feature)
	var other := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(other)
	var hud := _hud()
	feature.placed = true
	hud.refresh({})
	assert_true(hud.tray_buttons[feature].disabled)


func test_terrain_cannot_be_picked_on_the_opponents_turn() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(feature)
	_battle.opponent.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.player_is_attacker = false
	var hud := _hud()
	assert_true(hud.tray_buttons[feature].disabled)


func test_the_tray_of_an_army_without_regiments_lists_only_its_units() -> void:
	_battle = BattleKit.battle()
	_me = _battle.player
	_d = Deployment.new(_battle)
	var hud := _hud()
	assert_eq(hud.tray_buttons.size(), _me.units.size())


func test_pressing_a_unit_tile_emits_unit_picked() -> void:
	var hud := _hud()
	watch_signals(hud)
	hud.tray_buttons[_unit("A1")].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "unit_picked", [_unit("A1")])


func test_pressing_a_regiment_emits_regiment_picked() -> void:
	var hud := _hud()
	watch_signals(hud)
	hud.tray_buttons[_me.regiments[1]].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "regiment_picked", [_me.regiments[1]])


func test_pressing_a_terrain_tile_emits_terrain_picked() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(feature)
	var hud := _hud()
	watch_signals(hud)
	hud.tray_buttons[feature].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "terrain_picked", [feature])


func test_the_picked_unit_is_shown_pressed() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	assert_true(hud.tray_buttons[_unit("A1")].button_pressed)
	assert_false(hud.tray_buttons[_unit("A2")].button_pressed)


func test_a_reserved_unit_says_where_it_is() -> void:
	var entry := _reserve_entry("Aux")
	var hud := _hud()
	_d.reserve(_me, entry, [_unit("Aux")] as Array[BattleUnit])
	hud.refresh({})
	assert_string_contains(hud.tray_buttons[_unit("Aux")].text, "in the clouds")


# placing panel

func test_nothing_is_being_placed_by_default() -> void:
	var hud := _hud()
	assert_null(hud.confirm_button)
	assert_false(hud.placing_panel.visible)


func test_placing_a_unit_shows_confirm_and_undo() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	assert_not_null(hud.confirm_button)
	assert_not_null(hud.undo_button)
	assert_true(hud.placing_panel.visible)


func test_confirm_and_undo_emit_their_signals() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	watch_signals(hud)
	hud.confirm_button.pressed.emit()
	hud.undo_button.pressed.emit()
	assert_signal_emitted(hud, "confirm_pressed")
	assert_signal_emitted(hud, "undo_pressed")


func test_the_alert_is_hidden_without_problems() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	assert_false(hud.alert.visible)
	assert_false(hud.confirm_button.disabled)


func test_set_problems_shows_the_alert_and_disables_confirm() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	hud.set_problems(PackedStringArray(["1 model is outside your zone."]))
	assert_true(hud.alert.visible)
	assert_true(hud.confirm_button.disabled)
	assert_string_contains(hud.alert_label.text, "outside your zone")


func test_set_problems_lists_every_problem() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	hud.set_problems(PackedStringArray(["First problem.", "Second problem."]))
	assert_string_contains(hud.alert_label.text, "First problem.")
	assert_string_contains(hud.alert_label.text, "Second problem.")


func test_clearing_the_problems_hides_the_alert_and_enables_confirm() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	hud.set_problems(PackedStringArray(["Problem."]))
	hud.set_problems(PackedStringArray())
	assert_false(hud.alert.visible)
	assert_false(hud.confirm_button.disabled)


func test_problems_given_in_the_state_show_on_refresh() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1"), "problems": PackedStringArray(["Problem."])})
	assert_true(hud.alert.visible)
	assert_true(hud.confirm_button.disabled)


func test_set_problems_without_a_placing_panel_does_nothing_wrong() -> void:
	var hud := _hud()
	hud.set_problems(PackedStringArray(["Problem."]))
	assert_null(hud.alert)


func test_a_multi_model_unit_gets_a_single_model_toggle() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	assert_not_null(hud.single_model_button)
	assert_true(hud.single_model_button.toggle_mode)


func test_a_single_model_unit_gets_no_single_model_toggle() -> void:
	var single := BattleKit.unit("Solo", 1)
	_me.units.append(single)
	var hud := _hud({"mode": "unit", "unit": single})
	assert_null(hud.single_model_button)


func test_a_single_model_unit_still_gets_instructions() -> void:
	var single := BattleKit.unit("Solo", 1)
	_me.units.append(single)
	var hud := _hud({"mode": "unit", "unit": single})
	assert_true(UIKit.has_label_containing(hud.placing_panel, "drag"))


func test_the_toggle_is_not_pressed_when_single_model_mode_is_off() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1"), "single": false})
	assert_false(hud.single_model_button.button_pressed)


func test_the_toggle_is_pressed_when_single_model_mode_is_on() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1"), "single": true})
	assert_true(hud.single_model_button.button_pressed)


func test_the_toggle_text_follows_the_mode() -> void:
	var on := _hud({"mode": "unit", "unit": _unit("A1"), "single": true})
	var off := _hud({"mode": "unit", "unit": _unit("A1"), "single": false})
	assert_ne(on.single_model_button.text, off.single_model_button.text)


func test_the_toggle_accessibility_name_says_the_mode_and_key() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1"), "single": true})
	assert_string_contains(hud.single_model_button.accessibility_name, "on")
	assert_string_contains(hud.single_model_button.accessibility_name, BattleHud.key_for("single_model_mode"))


func test_pressing_the_toggle_emits_single_model_toggled() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	watch_signals(hud)
	hud.single_model_button.pressed.emit()
	assert_signal_emitted(hud, "single_model_toggled")


func test_the_unit_panel_has_no_formation_buttons() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	assert_false(hud.has_signal("formation_picked"))
	assert_false("formation_buttons" in hud)


func test_the_army_panel_offers_the_toggle_for_a_multi_model_unit() -> void:
	var hud := _army_hud({"mode": "army", "unit": _unit("A1")})
	assert_not_null(hud.single_model_button)


func test_the_army_panel_reflects_single_model_mode() -> void:
	var hud := _army_hud({"mode": "army", "unit": _unit("A1"), "single": true})
	assert_true(hud.single_model_button.button_pressed)


func test_the_army_panel_offers_no_toggle_with_no_unit_picked() -> void:
	var hud := _army_hud()
	assert_null(hud.single_model_button)


func test_the_army_toggle_emits_single_model_toggled() -> void:
	var hud := _army_hud({"mode": "army", "unit": _unit("A1")})
	watch_signals(hud)
	hud.single_model_button.pressed.emit()
	assert_signal_emitted(hud, "single_model_toggled")


func test_the_terrain_panel_has_no_single_model_toggle() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(feature)
	var hud := _hud({"mode": "terrain", "feature": feature})
	assert_null(hud.single_model_button)


func test_the_terrain_panel_says_dragging_turns_it() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(feature)
	var hud := _hud({"mode": "terrain", "feature": feature})
	assert_true(UIKit.has_label_containing(hud.placing_panel, "drag to turn"))


func test_placing_terrain_shows_confirm() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(feature)
	var hud := _hud({"mode": "terrain", "feature": feature})
	assert_not_null(hud.confirm_button)


func test_the_placing_panel_is_hidden_on_the_opponents_turn() -> void:
	var hud := _hud()
	_put(_me, "A1")
	hud.refresh({"mode": "unit", "unit": _unit("A2")})
	assert_false(hud.placing_panel.visible)
	assert_null(hud.confirm_button)


func test_the_placing_panel_is_hidden_while_the_ai_is_busy() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1"), "busy": true})
	assert_false(hud.placing_panel.visible)


func test_deploying_a_regiment_shows_its_panel_with_a_call_off_button() -> void:
	var hud := _hud()
	_d.begin_regiment(_me, _me.regiments[0])
	hud.refresh({})
	assert_true(hud.placing_panel.visible)
	assert_not_null(UIKit.button(hud.placing_panel, "Call off Deploy Regiment"))


func test_call_off_is_disabled_once_a_regiment_unit_is_down() -> void:
	var hud := _hud()
	_d.begin_regiment(_me, _me.regiments[0])
	_put(_me, "A1")
	hud.refresh({})
	assert_true(UIKit.button(hud.placing_panel, "Call off Deploy Regiment").disabled)


# abilities step and choosing

func test_the_abilities_step_offers_done_with_abilities() -> void:
	_record_entry()
	for army in [_battle.player, _battle.opponent]:
		for unit: BattleUnit in army.units:
			unit.deployed = true
	var hud := _hud()
	assert_not_null(hud.pass_button)


func test_done_with_abilities_emits_pass_pressed() -> void:
	_record_entry()
	for army in [_battle.player, _battle.opponent]:
		for unit: BattleUnit in army.units:
			unit.deployed = true
	var hud := _hud()
	watch_signals(hud)
	hud.pass_button.pressed.emit()
	assert_signal_emitted(hud, "pass_pressed")


func test_the_pass_button_is_only_offered_in_the_abilities_step() -> void:
	assert_null(_hud().pass_button)


func test_universal_abilities_have_no_button_press() -> void:
	var hud := _hud()
	watch_signals(hud)
	for button in hud.ability_buttons:
		button.pressed.emit()
	assert_signal_not_emitted(hud, "ability_picked")


func test_a_reserve_ability_can_be_picked_on_the_players_turn() -> void:
	var entry := _reserve_entry()
	var hud := _hud()
	watch_signals(hud)
	var enabled := hud.ability_buttons.filter(func(b: Button) -> bool: return not b.disabled)
	assert_eq(enabled.size(), 1)
	enabled[0].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "ability_picked", [entry])


func test_abilities_are_disabled_on_the_opponents_turn() -> void:
	_reserve_entry()
	var hud := _hud()
	_put(_me, "A1")
	hud.refresh({})
	for button in hud.ability_buttons:
		assert_true(button.disabled)


func test_a_used_ability_says_so() -> void:
	var entry := _reserve_entry()
	var hud := _hud()
	_d.reserve(_me, entry, [_unit("Aux")] as Array[BattleUnit])
	_put(_battle.opponent, "A1")
	hud.refresh({})
	var texts: Array = hud.ability_buttons.map(func(b: Button) -> String: return b.text)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("Used")))


func test_abilities_of_other_steps_are_not_listed() -> void:
	_record_entry()
	var hud := _hud()
	var texts: Array = hud.ability_buttons.map(func(b: Button) -> String: return b.text)
	assert_false(texts.any(func(t: String) -> bool: return t.contains("Scout")))


func test_choosing_targets_shows_a_chip_per_target() -> void:
	var entry := _reserve_entry("Aux")
	var targets: Array[BattleUnit] = [_unit("Aux"), _unit("A1")]
	var hud := _hud({"mode": "choose", "entry": entry, "targets": targets, "selected": [] as Array[BattleUnit], "multi": true})
	assert_eq(hud.target_buttons.size(), 2)


func test_selected_targets_are_shown_pressed() -> void:
	var entry := _reserve_entry("Aux")
	var targets: Array[BattleUnit] = [_unit("Aux"), _unit("A1")]
	var selected: Array[BattleUnit] = [_unit("A1")]
	var hud := _hud({"mode": "choose", "entry": entry, "targets": targets, "selected": selected, "multi": true})
	assert_false(hud.target_buttons[0].button_pressed)
	assert_true(hud.target_buttons[1].button_pressed)


func test_pressing_a_target_emits_target_toggled() -> void:
	var entry := _reserve_entry("Aux")
	var targets: Array[BattleUnit] = [_unit("Aux")]
	var hud := _hud({"mode": "choose", "entry": entry, "targets": targets, "selected": [] as Array[BattleUnit], "multi": false})
	watch_signals(hud)
	hud.target_buttons[0].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "target_toggled", [_unit("Aux")])


func test_choosing_a_reserve_names_the_reserve_on_the_confirm_button() -> void:
	var entry := _reserve_entry("Aux")
	var hud := _hud({"mode": "choose", "entry": entry, "targets": [_unit("Aux")] as Array[BattleUnit], "selected": [] as Array[BattleUnit]})
	assert_string_contains(hud.confirm_button.text, "in the clouds")


func test_cancelling_a_choice_emits_cancel_pressed() -> void:
	var entry := _reserve_entry("Aux")
	var hud := _hud({"mode": "choose", "entry": entry, "targets": [] as Array[BattleUnit], "selected": [] as Array[BattleUnit]})
	watch_signals(hud)
	hud.undo_button.pressed.emit()
	assert_signal_emitted(hud, "cancel_pressed")


# layout

func test_the_placing_panel_is_pinned_to_the_right_edge() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	assert_eq([hud.placing_panel.anchor_left, hud.placing_panel.anchor_right], [1.0, 1.0])
	assert_lt(hud.placing_panel.offset_right, 0.0)


func test_the_abilities_panel_is_pinned_to_the_left_edge() -> void:
	var hud := _hud()
	assert_eq([hud.abilities_panel.anchor_left, hud.abilities_panel.anchor_right], [0.0, 0.0])
	assert_gt(hud.abilities_panel.offset_right, 0.0)


func test_the_banner_is_anchored_to_the_middle_of_the_screen() -> void:
	var hud := _hud()
	assert_eq([hud.banner.anchor_left, hud.banner.anchor_right], [0.5, 0.5])


# cramped terrain note

## A HUD placing a faction terrain feature 3" across.
func _terrain_hud() -> DeploymentHud:
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me.terrain.append(feature)
	return _hud({"mode": "terrain", "feature": feature})


func test_the_terrain_panel_has_no_cramped_note_when_there_is_room() -> void:
	var hud := _terrain_hud()
	assert_eq(UIKit.labels_with_variation(hud.placing_panel, "WarningLabel").size(), 0)


func test_the_terrain_panel_notes_when_the_feature_is_cramped() -> void:
	_battle.player_territory = [BattleKit.rect_polygon(0, 0, 10, 10)] as Array[PackedVector2Array]
	_battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5)))
	var hud := _terrain_hud()
	assert_eq(UIKit.labels_with_variation(hud.placing_panel, "WarningLabel").size(), 1)



# Spearhead army panel

## A HUD for a Spearhead game, the player first, with [param state] as what the player is doing.
func _army_hud(state := {"mode": "army", "unit": null}) -> DeploymentHud:
	_battle = BattleKit.spearhead_deployment_battle()
	_me = _battle.player
	_d = Deployment.new(_battle)
	return _hud(state)


func test_the_army_panel_has_its_own_heading() -> void:
	var hud := _army_hud()
	assert_true(UIKit.has_label_containing(hud.placing_panel, "DEPLOY YOUR ARMY"))


func test_the_army_panel_confirm_button_deploys_the_army() -> void:
	var hud := _army_hud()
	assert_eq(hud.confirm_button.text, "Confirm deployment")


func test_undo_is_disabled_when_no_unit_is_picked() -> void:
	var hud := _army_hud()
	assert_true(hud.undo_button.disabled)


func test_undo_is_enabled_when_a_unit_is_picked() -> void:
	var hud := _army_hud({"mode": "army", "unit": _unit("A1")})
	assert_false(hud.undo_button.disabled)


func test_the_army_panel_names_the_picked_unit() -> void:
	var hud := _army_hud({"mode": "army", "unit": _unit("A1")})
	assert_true(UIKit.has_label_containing(hud.placing_panel, "A1"))


func test_the_army_panel_shows_the_problems_it_is_given() -> void:
	var hud := _army_hud({"mode": "army", "unit": null, "problems": PackedStringArray(["A1: 3 models are outside"])})
	assert_true(hud.alert.visible)
	assert_string_contains(hud.alert_label.text, "A1")


func test_the_banner_asks_the_player_to_move_their_units_then_confirm() -> void:
	var hud := _army_hud()
	assert_string_contains(hud.banner_text.text.to_lower(), "confirm")


func test_the_banner_prompt_differs_from_matched_plays() -> void:
	var matched := _hud().banner_text.text
	assert_ne(_army_hud().banner_text.text, matched)


func test_the_deploy_unit_hint_says_the_units_are_set_out() -> void:
	var hud := _army_hud()
	var texts: Array = hud.ability_buttons.map(func(b: Button) -> String: return b.text)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("set out")))


func test_tray_tiles_of_undeployed_units_say_to_pick_them_to_move() -> void:
	var hud := _army_hud()
	assert_string_contains(hud.tray_buttons[_unit("A1")].tooltip_text, "move")


func test_tray_tile_tooltips_in_matched_play_do_not_mention_moving() -> void:
	var hud := _hud()
	assert_false(hud.tray_buttons[_unit("A1")].tooltip_text.contains("to move"))


func test_the_matched_play_unit_panel_is_unaffected() -> void:
	var hud := _hud({"mode": "unit", "unit": _unit("A1")})
	assert_false(UIKit.has_label_containing(hud.placing_panel, "DEPLOY YOUR ARMY"))


# Deploy Regiment staging panel

## A Matched Play HUD with the first regiment begun and staged, [param state] on top of the army mode.
func _regiment_hud(state := {}) -> DeploymentHud:
	var hud := _hud()
	_d.begin_regiment(_me, _me.regiments[0])
	var full := {"mode": "army", "unit": null}
	full.merge(state, true)
	hud.refresh(full)
	return hud


func test_the_regiment_panel_has_its_own_heading() -> void:
	var hud := _regiment_hud()
	assert_true(UIKit.has_label_containing(hud.placing_panel, "DEPLOY REGIMENT"))


func test_the_regiment_panel_is_not_the_army_panel() -> void:
	var hud := _regiment_hud()
	assert_false(UIKit.has_label_containing(hud.placing_panel, "DEPLOY YOUR ARMY"))


func test_the_regiment_panel_names_the_regiment() -> void:
	var hud := _regiment_hud()
	assert_true(UIKit.has_label_containing(hud.placing_panel, _me.regiments[0].name))


func test_the_regiment_panel_confirm_button_says_regiment() -> void:
	var hud := _regiment_hud()
	assert_string_contains(hud.confirm_button.text.to_lower(), "regiment")


func test_the_regiment_panel_offers_to_call_it_off() -> void:
	var hud := _regiment_hud()
	var call_off := UIKit.button(hud.placing_panel, "Call off Deploy Regiment")
	assert_not_null(call_off)
	assert_false(call_off.disabled)


func test_the_regiment_panel_names_the_picked_unit() -> void:
	var hud := _regiment_hud({"unit": _unit("A1")})
	assert_true(UIKit.has_label_containing(hud.placing_panel, "A1"))


func test_the_regiment_panel_shows_the_problems_it_is_given() -> void:
	var hud := _regiment_hud({"problems": PackedStringArray(["A2: 1 model is outside"])})
	assert_true(hud.alert.visible)
	assert_string_contains(hud.alert_label.text, "A2")


func test_the_regiment_panel_undo_follows_whether_a_unit_is_picked() -> void:
	assert_true(_regiment_hud().undo_button.disabled)
	assert_false(_regiment_hud({"unit": _unit("A1")}).undo_button.disabled)


func test_pressing_call_off_in_the_regiment_panel_emits_the_signal() -> void:
	var hud := _regiment_hud()
	watch_signals(hud)
	UIKit.button(hud.placing_panel, "Call off Deploy Regiment").pressed.emit()
	assert_signal_emitted(hud, "call_off_pressed")


func test_the_regiment_panel_has_no_unit_chips() -> void:
	var hud := _regiment_hud()
	assert_false(UIKit.button_texts(hud.placing_panel).has("A1 ×%d" % _unit("A1").model_count()))


func test_a_regiment_unit_tile_says_to_pick_it_to_move() -> void:
	var hud := _regiment_hud()
	assert_string_contains(hud.tray_buttons[_unit("A1")].tooltip_text, "move")


func test_a_unit_outside_the_regiment_does_not_say_to_move_it() -> void:
	var hud := _regiment_hud()
	assert_false(hud.tray_buttons[_unit("Aux")].tooltip_text.contains("to move"))


func test_the_spearhead_army_panel_still_says_confirm_deployment() -> void:
	assert_eq(_army_hud().confirm_button.text, "Confirm deployment")
