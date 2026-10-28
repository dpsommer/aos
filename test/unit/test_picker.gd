extends GutTest
## Unit tests for the builder's picker (scripts/ui/forge/builder/picker.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")


## Redrawn lists are removed with queue_free, so let a frame pass for them to be freed before GUT
## counts orphans.
func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	await get_tree().process_frame
	Sandbox.end()


func _core() -> CoreRules:
	return Kit.core(PackedStringArray(["Card A", "Card B"]))


func _builder(army: Army = null, faction: Faction = null) -> ArmyBuilder:
	return UIKit.builder(self, army if army else UIKit.army_with_regiment(), faction, _core())


func _faction_with_renown(renown: Array[RegimentOfRenown]) -> Faction:
	var faction := UIKit.faction()
	faction.regiments_of_renown = renown
	return faction


func _band(band_name := "Band", legends := false) -> RegimentOfRenown:
	var band := Kit.regiment_of_renown(band_name, 150, [Kit.renown_unit("Gotrek", "gotrek")] as Array[RegimentUnit],
			[Kit.warscroll("gotrek", PackedStringArray(["HERO"]))] as Array[Warscroll])
	band.legends = legends
	return band


func _warscrolls(ids: PackedStringArray) -> Callable:
	var scrolls: Array[Warscroll] = []
	for id in ids:
		scrolls.append(Kit.warscroll(id))
	return func() -> Array[Warscroll]: return scrolls


# --- Units ---

func test_open_units_adds_a_choice_per_warscroll() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a", "b"])), func(_id: String) -> void: pass)
	assert_not_null(UIKit.keyed(builder.picker, "pick:a"))
	assert_not_null(UIKit.keyed(builder.picker, "pick:b"))


func test_open_units_marks_the_picker_open() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a"])), func(_id: String) -> void: pass)
	assert_true(builder.picker.is_open())


func test_open_units_choice_calls_back_with_the_warscroll_id() -> void:
	var builder := _builder()
	var picked := []
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a", "b"])), func(id: String) -> void: picked.append(id))
	UIKit.keyed(builder.picker, "pick:b").pressed.emit()
	assert_eq(picked, ["b"])


func test_open_units_choices_are_labelled_add() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a"])), func(_id: String) -> void: pass)
	assert_eq((UIKit.keyed(builder.picker, "pick:a") as Button).text, "Add")


func test_open_units_shows_a_message_when_the_list_is_empty() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray()), func(_id: String) -> void: pass)
	assert_true(UIKit.has_label_containing(builder.picker, "No units"))


func test_open_units_focuses_the_first_choice() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray(["a", "b"])), func(_id: String) -> void: pass)
	assert_true(UIKit.keyed(builder.picker, "pick:a").has_focus())


func test_open_units_with_nothing_to_pick_focuses_the_close_button() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _warscrolls(PackedStringArray()), func(_id: String) -> void: pass)
	assert_true(UIKit.keyed(builder.picker, "picker:close").has_focus())


func test_open_units_title_is_shown() -> void:
	var builder := _builder()
	builder.picker.open_units("Choose a thing", _warscrolls(PackedStringArray(["a"])), func(_id: String) -> void: pass)
	assert_true(UIKit.has_label_containing(builder.picker, "Choose a thing"))


func _typed(entries: Array) -> Callable:
	var scrolls: Array[Warscroll] = []
	for entry: Array in entries:
		scrolls.append(Kit.warscroll(entry[0], PackedStringArray(entry[1])))
	return func() -> Array[Warscroll]: return scrolls


func test_open_units_groups_units_under_a_banner_per_type() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _typed([["h", ["HERO"]], ["i", ["INFANTRY"]]]), func(_id: String) -> void: pass)
	assert_not_null(UIKit.keyed(builder.picker, "picker:type:Hero"))
	assert_not_null(UIKit.keyed(builder.picker, "picker:type:Infantry"))
	assert_null(UIKit.keyed(builder.picker, "picker:type:Cavalry"))


func test_open_units_lists_a_unit_in_its_types_section() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _typed([["h", ["HERO"]], ["i", ["INFANTRY"]]]), func(_id: String) -> void: pass)
	var section := UIKit.keyed(builder.picker, "picker:type:Infantry").get_parent()
	assert_not_null(UIKit.keyed(section, "pick:i"))
	assert_null(UIKit.keyed(section, "pick:h"))


func test_open_units_sections_follow_the_roster_order() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _typed([["i", ["INFANTRY"]], ["h", ["HERO"]]]), func(_id: String) -> void: pass)
	var hero := UIKit.keyed(builder.picker, "picker:type:Hero").get_parent()
	var infantry := UIKit.keyed(builder.picker, "picker:type:Infantry").get_parent()
	assert_lt(hero.get_index(), infantry.get_index())


func test_folding_a_section_hides_its_units() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _typed([["h", ["HERO"]], ["i", ["INFANTRY"]]]), func(_id: String) -> void: pass)
	UIKit.keyed(builder.picker, "picker:type:Hero").pressed.emit()
	await get_tree().process_frame
	assert_null(UIKit.keyed(builder.picker, "pick:h"))
	assert_not_null(UIKit.keyed(builder.picker, "pick:i"))


func test_reopening_the_picker_unfolds_its_sections() -> void:
	var builder := _builder()
	builder.picker.open_units("Pick", _typed([["h", ["HERO"]]]), func(_id: String) -> void: pass)
	UIKit.keyed(builder.picker, "picker:type:Hero").pressed.emit()
	builder.picker.open_units("Pick", _typed([["h", ["HERO"]]]), func(_id: String) -> void: pass)
	await get_tree().process_frame
	assert_not_null(UIKit.keyed(builder.picker, "pick:h"))


func test_refresh_redraws_the_list_from_the_callable() -> void:
	var builder := _builder()
	var ids := PackedStringArray(["a"])
	var scrolls := func() -> Array[Warscroll]:
		var result: Array[Warscroll] = []
		for id in ids:
			result.append(Kit.warscroll(id))
		return result
	builder.picker.open_units("Pick", scrolls, func(_id: String) -> void: pass)
	ids.append("b")
	builder.picker.refresh()
	await get_tree().process_frame
	assert_not_null(UIKit.keyed(builder.picker, "pick:b"))


func test_close_button_closes_the_picker() -> void:
	var builder := _builder()
	builder.pick_auxiliary()
	UIKit.keyed(builder.picker, "picker:close").pressed.emit()
	assert_false(builder.picker.is_open())


func test_close_emits_closed() -> void:
	var builder := _builder()
	watch_signals(builder.picker)
	builder.pick_auxiliary()
	builder.picker.close()
	assert_signal_emitted(builder.picker, "closed")


func test_refresh_does_nothing_when_closed() -> void:
	var builder := _builder()
	builder.picker.refresh()
	assert_false(builder.picker.is_open())


# --- Tactics ---

func _tactic(builder: ArmyBuilder, card_name: String) -> TacticCard:
	for found in UIKit.find_all(builder.picker, func(n: Node) -> bool: return n is TacticCard):
		if (found as TacticCard).card_name == card_name:
			return found
	return null


func test_open_tactics_lists_each_card_as_pressable_with_only_an_eye() -> void:
	var builder := _builder()
	builder.picker.open_tactics(0)
	for card_name in ["Card A", "Card B"]:
		var card := UIKit.keyed(builder.picker, "pick:" + card_name) as TacticCard
		assert_not_null(card, card_name)
		assert_true(card.pressable, card_name)
		assert_eq(UIKit.buttons(card).size(), 1, card_name)
		assert_not_null(UIKit.keyed(card, "picker:eye:" + card_name), card_name)


func test_pressing_a_card_fills_the_slot_and_closes() -> void:
	var army := Kit.army()
	var builder := _builder(army)
	builder.picker.open_tactics(1)
	(UIKit.keyed(builder.picker, "pick:Card B") as TacticCard).pressed.emit()
	assert_eq(army.tactics[1], "Card B")
	assert_false(builder.picker.is_open())


func test_open_tactics_focuses_the_first_card() -> void:
	var builder := _builder()
	builder.picker.open_tactics(0)
	assert_true(UIKit.keyed(builder.picker, "pick:Card A").has_focus())


func test_the_slots_current_card_is_not_listed() -> void:
	var army := Kit.army()
	army.tactics = PackedStringArray(["Card A", ""])
	var builder := _builder(army)
	builder.picker.open_tactics(0)
	assert_null(_tactic(builder, "Card A"))
	assert_true(_tactic(builder, "Card B").pressable)


func test_the_other_slots_card_is_not_listed() -> void:
	var army := Kit.army()
	army.tactics = PackedStringArray(["Card A", ""])
	var builder := _builder(army)
	builder.picker.open_tactics(1)
	assert_null(_tactic(builder, "Card A"))
	assert_not_null(_tactic(builder, "Card B"))


func test_tactic_title_names_the_slot() -> void:
	var builder := _builder()
	builder.picker.open_tactics(1)
	assert_true(UIKit.has_label_containing(builder.picker, "2"))


# --- Lores ---

func _lore_faction() -> Faction:
	var faction := UIKit.faction()
	var lores: Array[Lore] = [Kit.lore("Fire", "spell"), Kit.lore("Ice", "spell"), Kit.lore("Hymns", "prayer")]
	faction.lores = lores
	return faction


func _lore_builder(army: Army = null, universal: Array[Lore] = []) -> ArmyBuilder:
	var core := Kit.core(PackedStringArray(["Card A", "Card B"]), universal)
	return UIKit.builder(self, army if army else UIKit.army_with_regiment(), _lore_faction(), core)


func test_open_lores_lists_each_lore_of_the_kind_as_pressable() -> void:
	var builder := _lore_builder()
	builder.picker.open_lores("spell", "Spell Lore")
	for lore_name in ["Fire", "Ice"]:
		var card := UIKit.keyed(builder.picker, "pick:lore:" + lore_name) as LoreCard
		assert_not_null(card, lore_name)
		assert_true(card.pressable, lore_name)
	assert_null(UIKit.keyed(builder.picker, "pick:lore:Hymns"))


func test_open_lores_cards_are_full_once_their_eye_is_toggled() -> void:
	var faction := _lore_faction()
	var fire: Lore = faction.lores[0]
	fire.entries = [Kit.ability("Scorch")] as Array[Ability]
	var builder := UIKit.builder(self, UIKit.army_with_regiment(), faction, _core())
	builder.picker.open_lores("spell", "Spell Lore")
	(UIKit.keyed(builder.picker, "picker:eye:Fire") as Button).button_pressed = true
	var card := UIKit.keyed(builder.picker, "pick:lore:Fire")
	assert_gt(UIKit.find_all(card, func(n: Node) -> bool: return n is AbilityCard).size(), 0)


func test_open_lores_shows_the_title() -> void:
	var builder := _lore_builder()
	builder.picker.open_lores("spell", "Spell Lore")
	assert_has(UIKit.label_texts(builder.picker), "Spell Lore")


func test_open_lores_marks_the_picker_open() -> void:
	var builder := _lore_builder()
	builder.picker.open_lores("spell", "Spell Lore")
	assert_true(builder.picker.is_open())


func test_open_lores_focuses_the_first_lore() -> void:
	var builder := _lore_builder()
	builder.picker.open_lores("spell", "Spell Lore")
	assert_true(UIKit.keyed(builder.picker, "pick:lore:Fire").has_focus())


func test_the_armys_current_lore_is_not_listed() -> void:
	var army := UIKit.army_with_regiment()
	army.spell_lore = "Fire"
	var builder := _lore_builder(army)
	builder.picker.open_lores("spell", "Spell Lore")
	assert_null(UIKit.keyed(builder.picker, "pick:lore:Fire"))
	assert_not_null(UIKit.keyed(builder.picker, "pick:lore:Ice"))


func test_the_other_kinds_current_lore_does_not_hide_a_lore() -> void:
	var army := UIKit.army_with_regiment()
	army.prayer_lore = "Fire"
	var builder := _lore_builder(army)
	builder.picker.open_lores("spell", "Spell Lore")
	assert_not_null(UIKit.keyed(builder.picker, "pick:lore:Fire"))


func test_pressing_a_lore_sets_it_and_closes() -> void:
	var army := UIKit.army_with_regiment()
	var builder := _lore_builder(army)
	builder.picker.open_lores("spell", "Spell Lore")
	(UIKit.keyed(builder.picker, "pick:lore:Ice") as LoreCard).pressed.emit()
	assert_eq(army.spell_lore, "Ice")
	assert_false(builder.picker.is_open())


func test_universal_manifestation_lores_are_marked_with_a_heading() -> void:
	var universal: Array[Lore] = [Kit.lore("Universal", "manifestation")]
	var builder := _lore_builder(null, universal)
	builder.picker.open_lores("manifestation", "Manifestation Lore")
	var card := UIKit.keyed(builder.picker, "pick:lore:Universal") as LoreCard
	assert_not_null(card)
	assert_not_null(card.heading_label)


func test_faction_lores_have_no_universal_heading() -> void:
	var builder := _lore_builder()
	builder.picker.open_lores("spell", "Spell Lore")
	assert_null((UIKit.keyed(builder.picker, "pick:lore:Fire") as LoreCard).heading_label)


func test_a_faction_manifestation_lore_has_no_universal_heading() -> void:
	var faction := _lore_faction()
	faction.lores.append(Kit.lore("Own", "manifestation"))
	var universal: Array[Lore] = [Kit.lore("Universal", "manifestation")]
	var builder := UIKit.builder(self, UIKit.army_with_regiment(), faction, Kit.core(PackedStringArray(), universal))
	builder.picker.open_lores("manifestation", "Manifestation Lore")
	assert_null((UIKit.keyed(builder.picker, "pick:lore:Own") as LoreCard).heading_label)
	assert_not_null((UIKit.keyed(builder.picker, "pick:lore:Universal") as LoreCard).heading_label)


func test_open_lores_shows_a_message_when_there_is_nothing_else_to_pick() -> void:
	var army := UIKit.army_with_regiment()
	army.prayer_lore = "Hymns"
	var builder := _lore_builder(army)
	builder.picker.open_lores("prayer", "Prayer Lore")
	assert_eq(UIKit.find_all(builder.picker, func(n: Node) -> bool: return n is LoreCard).size(), 0)
	assert_true(UIKit.has_label_containing(builder.picker, "no other"))


func test_open_lores_with_nothing_to_pick_focuses_the_close_button() -> void:
	var army := UIKit.army_with_regiment()
	army.prayer_lore = "Hymns"
	var builder := _lore_builder(army)
	builder.picker.open_lores("prayer", "Prayer Lore")
	assert_true(UIKit.keyed(builder.picker, "picker:close").has_focus())


# --- Regiments of Renown ---

func test_open_regiments_of_renown_lists_available_regiments() -> void:
	var faction := _faction_with_renown([_band("Band"), _band("Other")] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	assert_not_null(UIKit.keyed(builder.picker, "pick:add:Band"))
	assert_not_null(UIKit.keyed(builder.picker, "pick:add:Other"))


func test_regiments_of_renown_hides_legends_unless_shown() -> void:
	var faction := _faction_with_renown([_band("Old Band", true)] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	assert_null(UIKit.keyed(builder.picker, "pick:add:Old Band"))


func test_regiments_of_renown_shows_legends_when_enabled() -> void:
	var faction := _faction_with_renown([_band("Old Band", true)] as Array[RegimentOfRenown])
	var army := UIKit.army_with_regiment()
	army.show_legends = true
	var builder := _builder(army, faction)
	builder.picker.open_regiments_of_renown()
	assert_not_null(UIKit.keyed(builder.picker, "pick:add:Old Band"))


func test_regiments_of_renown_shows_a_message_when_there_are_none() -> void:
	var builder := _builder()
	builder.picker.open_regiments_of_renown()
	assert_true(UIKit.has_label_containing(builder.picker, "can't include any"))


func test_regiments_of_renown_empty_when_the_army_of_renown_forbids_them() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var renown := Kit.army_of_renown("Solo")
	renown.roster.regiments_of_renown = false
	faction.armies_of_renown.append(renown)
	var army := UIKit.army_with_regiment()
	army.army_of_renown = "Solo"
	var builder := _builder(army, faction)
	builder.picker.open_regiments_of_renown()
	assert_null(UIKit.keyed(builder.picker, "pick:add:Band"))


func test_adding_a_regiment_of_renown_adds_it_and_closes() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var army := UIKit.army_with_regiment()
	var builder := _builder(army, faction)
	builder.picker.open_regiments_of_renown()
	UIKit.keyed(builder.picker, "pick:add:Band").pressed.emit()
	assert_true(army.regiments.any(func(r: ArmyRegiment) -> bool: return r.regiment_of_renown == "Band"))
	assert_false(builder.picker.is_open())


func _warscroll_count(builder: ArmyBuilder) -> int:
	return UIKit.find_all(builder.picker, func(n: Node) -> bool: return n is WarscrollCard).size()


func test_unit_subhead_starts_collapsed() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	assert_false(builder.expanded.has("pick:Band:0"))
	assert_not_null(UIKit.keyed(builder.picker, "pick:Band:0"))


func test_pressing_a_unit_subhead_shows_its_warscroll() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	var before := _warscroll_count(builder)
	UIKit.keyed(builder.picker, "pick:Band:0").pressed.emit()
	await get_tree().process_frame
	assert_gt(_warscroll_count(builder), before)


func test_pressing_a_unit_subhead_again_hides_its_warscroll() -> void:
	var faction := _faction_with_renown([_band()] as Array[RegimentOfRenown])
	var builder := _builder(null, faction)
	builder.picker.open_regiments_of_renown()
	var before := _warscroll_count(builder)
	UIKit.keyed(builder.picker, "pick:Band:0").pressed.emit()
	await get_tree().process_frame
	UIKit.keyed(builder.picker, "pick:Band:0").pressed.emit()
	await get_tree().process_frame
	assert_eq(_warscroll_count(builder), before)


func test_a_second_regiment_of_renown_has_no_add_button_without_override() -> void:
	var faction := _faction_with_renown([_band("Band"), _band("Other")] as Array[RegimentOfRenown])
	var builder := _builder(UIKit.army_with_regiment(), faction)
	builder.editor.add_regiment_of_renown("Band")
	builder.picker.open_regiments_of_renown()
	assert_null(UIKit.keyed(builder.picker, "pick:add:Other"))


# --- Expanding cards ---

func _detailed_core() -> CoreRules:
	var core := _core()
	for card in core.battlepack.battle_tactic_cards:
		var tactic := BattleTactic.new()
		tactic.name = "Do it"
		tactic.kind = "strike"
		tactic.condition = "Achieve the goal."
		tactic.victory_points = 3
		card.tactics.append(tactic)
	return core


func _eye(builder: ArmyBuilder, card_name: String) -> Button:
	return UIKit.keyed(builder.picker, "picker:eye:" + card_name) as Button


func _tactics_builder() -> ArmyBuilder:
	var builder := UIKit.builder(self, UIKit.army_with_regiment(), null, _detailed_core())
	builder.picker.open_tactics(0)
	return builder


func test_tactic_cards_start_brief() -> void:
	var builder := _tactics_builder()
	assert_true(UIKit.has_label_containing(builder.picker, "Do it"))
	assert_false(UIKit.has_label_containing(builder.picker, "Achieve the goal."))
	assert_false(_eye(builder, "Card A").button_pressed)


func test_toggling_the_eye_shows_the_tactic_card_in_full() -> void:
	var builder := _tactics_builder()
	_eye(builder, "Card A").button_pressed = true
	assert_true(UIKit.has_label_containing(UIKit.keyed(builder.picker, "pick:Card A"), "Achieve the goal."))


func test_expanding_one_card_leaves_the_others_brief() -> void:
	var builder := _tactics_builder()
	_eye(builder, "Card A").button_pressed = true
	assert_false(UIKit.has_label_containing(UIKit.keyed(builder.picker, "pick:Card B"), "Achieve the goal."))


func test_toggling_the_eye_off_reverts_to_brief() -> void:
	var builder := _tactics_builder()
	_eye(builder, "Card A").button_pressed = true
	_eye(builder, "Card A").button_pressed = false
	assert_false(UIKit.has_label_containing(builder.picker, "Achieve the goal."))
	assert_false(builder.picker.expanded.has("Card A"))


func test_expanding_records_the_name() -> void:
	var builder := _tactics_builder()
	_eye(builder, "Card B").button_pressed = true
	assert_true(builder.picker.expanded.has("Card B"))
	assert_false(builder.picker.expanded.has("Card A"))


func test_expanding_replaces_the_card_at_the_same_position() -> void:
	var builder := _tactics_builder()
	var list := UIKit.keyed(builder.picker, "pick:Card B").get_parent()
	var old := UIKit.keyed(builder.picker, "pick:Card A")
	var index := old.get_index()
	_eye(builder, "Card A").button_pressed = true
	var replacement := UIKit.keyed(builder.picker, "pick:Card A")
	assert_ne(replacement, old)
	assert_eq(replacement.get_index(), index)
	assert_eq(replacement.get_parent(), list)
	assert_eq(list.get_child_count(), 2)


func test_expanded_replacement_stays_in_the_same_slot_when_not_first() -> void:
	var builder := _tactics_builder()
	var index := UIKit.keyed(builder.picker, "pick:Card B").get_index()
	_eye(builder, "Card B").button_pressed = true
	assert_eq(UIKit.keyed(builder.picker, "pick:Card B").get_index(), index)


func test_expanding_moves_focus_to_the_new_eye() -> void:
	var builder := _tactics_builder()
	builder.picker.show()
	_eye(builder, "Card A").button_pressed = true
	assert_true(_eye(builder, "Card A").has_focus())


func test_collapsing_moves_focus_to_the_new_eye() -> void:
	var builder := _tactics_builder()
	builder.picker.show()
	_eye(builder, "Card A").button_pressed = true
	_eye(builder, "Card A").button_pressed = false
	assert_true(_eye(builder, "Card A").has_focus())


func test_expanded_replacement_is_still_pressable_and_picks() -> void:
	var army := Kit.army()
	var builder := UIKit.builder(self, army, null, _detailed_core())
	builder.picker.open_tactics(0)
	_eye(builder, "Card B").button_pressed = true
	var card := UIKit.keyed(builder.picker, "pick:Card B") as TacticCard
	assert_true(card.pressable)
	card.pressed.emit()
	assert_eq(army.tactics[0], "Card B")
	assert_false(builder.picker.is_open())


func test_the_eye_keeps_its_own_clicks_on_a_pressable_card() -> void:
	var builder := _tactics_builder()
	assert_ne(_eye(builder, "Card A").mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_reopening_the_picker_clears_expanded_cards() -> void:
	var builder := _tactics_builder()
	_eye(builder, "Card A").button_pressed = true
	builder.picker.open_tactics(0)
	assert_true(builder.picker.expanded.is_empty())
	assert_false(UIKit.has_label_containing(builder.picker, "Achieve the goal."))


func _rules_lore_builder() -> ArmyBuilder:
	var faction := _lore_faction()
	(faction.lores[0] as Lore).entries = [Kit.ability("Scorch")] as Array[Ability]
	(faction.lores[1] as Lore).entries = [Kit.ability("Freeze")] as Array[Ability]
	var builder := UIKit.builder(self, UIKit.army_with_regiment(), faction, _core())
	builder.picker.open_lores("spell", "Spell Lore")
	return builder


func _rich_count(node: Node) -> int:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is RichTextLabel).size()


func test_lore_cards_start_short_with_an_eye() -> void:
	var builder := _rules_lore_builder()
	assert_eq(_rich_count(UIKit.keyed(builder.picker, "pick:lore:Fire")), 0)
	assert_not_null(_eye(builder, "Fire"))
	assert_not_null(_eye(builder, "Ice"))


func test_toggling_a_lores_eye_off_reverts_it_to_short() -> void:
	var builder := _rules_lore_builder()
	_eye(builder, "Fire").button_pressed = true
	_eye(builder, "Fire").button_pressed = false
	assert_eq(_rich_count(UIKit.keyed(builder.picker, "pick:lore:Fire")), 0)
	assert_false(builder.picker.expanded.has("Fire"))


func test_expanding_a_lore_replaces_it_in_place_and_records_it() -> void:
	var builder := _rules_lore_builder()
	var index := UIKit.keyed(builder.picker, "pick:lore:Ice").get_index()
	_eye(builder, "Ice").button_pressed = true
	assert_eq(UIKit.keyed(builder.picker, "pick:lore:Ice").get_index(), index)
	assert_true(builder.picker.expanded.has("Ice"))
	assert_eq(_rich_count(UIKit.keyed(builder.picker, "pick:lore:Fire")), 0)


func test_expanding_a_lore_moves_focus_to_its_new_eye() -> void:
	var builder := _rules_lore_builder()
	builder.picker.show()
	_eye(builder, "Fire").button_pressed = true
	assert_true(_eye(builder, "Fire").has_focus())


func test_expanded_lore_is_still_pressable_and_picks() -> void:
	var builder := _rules_lore_builder()
	_eye(builder, "Ice").button_pressed = true
	var card := UIKit.keyed(builder.picker, "pick:lore:Ice") as LoreCard
	assert_true(card.pressable)
	card.pressed.emit()
	assert_eq(builder.editor.army.spell_lore, "Ice")


func test_reopening_lores_clears_expanded() -> void:
	var builder := _rules_lore_builder()
	_eye(builder, "Fire").button_pressed = true
	builder.picker.open_lores("spell", "Spell Lore")
	assert_true(builder.picker.expanded.is_empty())
	assert_eq(_rich_count(UIKit.keyed(builder.picker, "pick:lore:Fire")), 0)
