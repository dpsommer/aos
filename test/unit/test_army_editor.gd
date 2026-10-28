extends GutTest
## Unit tests for editing armies (scripts/army/army_editor.gd).

const Kit := preload("res://test/support/army_kit.gd")


func _faction() -> Faction:
	var grunt := Kit.warscroll("grunt", PackedStringArray(["INFANTRY"]))
	grunt.unit_size = 10
	grunt.can_reinforce = true
	grunt.weapon_options.append(Kit.weapon_option("Hammer", 1, 5))
	var scrolls: Array[Warscroll] = [Kit.hero("hero_a"), Kit.hero("hero_b"), grunt, Kit.warscroll("plain")]
	var faction := Kit.faction(scrolls)
	faction.enhancement_tables = [
		Kit.table("Heroic Traits", [Kit.ability("Brave"), Kit.ability("Bold")] as Array[Ability]),
		Kit.table("Artefacts of Power", [Kit.ability("Sword")] as Array[Ability]),
	] as Array[EnhancementTable]
	faction.lores = [Kit.lore("Fire", "spell"), Kit.lore("Hymns", "prayer"), Kit.lore("Own Manifest", "manifestation")] as Array[Lore]
	faction.battle_formations = [Kit.formation("Vanguard")] as Array[BattleFormation]
	var members: Array[Warscroll] = [Kit.warscroll("ror_hero", PackedStringArray(["HERO"])), Kit.warscroll("ror_grunt")]
	var listed: Array[RegimentUnit] = [Kit.renown_unit("Captain", "ror_hero"), Kit.renown_unit("Guards", "ror_grunt", "", 2)]
	faction.regiments_of_renown = [
		Kit.regiment_of_renown("Band", 100, listed, members),
		Kit.regiment_of_renown("Other Band", 100, listed, members),
	] as Array[RegimentOfRenown]
	var horde := Kit.army_of_renown("Horde")
	horde.enhancement_tables = [Kit.table("Heroic Traits", [Kit.ability("Horde Trait")] as Array[Ability])] as Array[EnhancementTable]
	horde.lores = [Kit.lore("Horde Spell", "spell")] as Array[Lore]
	horde.roster.faction_terrain = false
	var no_renown := Kit.army_of_renown("Lone Wolves")
	no_renown.roster.regiments_of_renown = false
	var legend := Kit.army_of_renown("Old Legend")
	legend.legends = true
	faction.armies_of_renown = [horde, no_renown, legend] as Array[ArmyOfRenown]
	return faction


func _catalog() -> ArmyCatalog:
	return Kit.catalog(_faction())


func _editor(army: Army = null) -> ArmyEditor:
	var editor := ArmyEditor.new(army if army else Kit.army(), _catalog())
	watch_signals(editor)
	return editor


## An editor on an army with regiment r1 (hero_a leader, one grunt) and an auxiliary grunt.
func _populated() -> ArmyEditor:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "hero_a"), Kit.unit("u2", "grunt")] as Array[ArmyUnit]))
	army.auxiliary.append(Kit.unit("u3", "grunt"))
	return _editor(army)


func _uids(units: Array[ArmyUnit]) -> Array:
	return units.map(func(u: ArmyUnit) -> String: return u.uid)


func _fill(editor: ArmyEditor, regiment_id: String, count: int) -> void:
	for i in count:
		editor.add_unit(regiment_id, "grunt")


# create_army

func test_create_army_uses_the_catalogs_faction() -> void:
	assert_eq(ArmyEditor.create_army(_catalog()).faction_id, "test_faction")


func test_create_army_has_two_empty_tactic_slots() -> void:
	assert_eq(ArmyEditor.create_army(_catalog()).tactics, PackedStringArray(["", ""]))


func test_create_army_keeps_the_formation() -> void:
	assert_eq(ArmyEditor.create_army(_catalog(), "", "Vanguard").formation, "Vanguard")


func test_create_army_of_renown_has_no_formation() -> void:
	var army := ArmyEditor.create_army(_catalog(), "Horde", "Vanguard")
	assert_eq([army.army_of_renown, army.formation], ["Horde", ""])


func test_create_army_of_legends_renown_shows_legends() -> void:
	assert_true(ArmyEditor.create_army(_catalog(), "Old Legend").show_legends)


func test_create_army_of_regular_renown_hides_legends() -> void:
	assert_false(ArmyEditor.create_army(_catalog(), "Horde").show_legends)


func test_create_army_without_renown_hides_legends() -> void:
	assert_false(ArmyEditor.create_army(_catalog()).show_legends)


func test_set_legends_renown_turns_on_show_legends() -> void:
	var editor := _editor()
	editor.army.show_legends = false
	editor.set_army_of_renown("Old Legend")
	assert_true(editor.army.show_legends)


func test_set_regular_renown_leaves_show_legends_alone() -> void:
	var off := _editor()
	off.army.show_legends = false
	off.set_army_of_renown("Horde")
	var on := _editor()
	on.army.show_legends = true
	on.set_army_of_renown("Horde")
	assert_eq([off.army.show_legends, on.army.show_legends], [false, true])


func test_clearing_renown_leaves_show_legends_on() -> void:
	var editor := _editor()
	editor.army.show_legends = true
	editor.set_army_of_renown("Old Legend")
	editor.set_army_of_renown("")
	assert_true(editor.army.show_legends)


func test_create_army_names_the_army_after_its_rules() -> void:
	assert_string_contains(ArmyEditor.create_army(_catalog(), "Horde").name, "Horde")


# Regiments

func test_add_regiment_appends_an_empty_regiment() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment()
	assert_eq(editor.army.regiments, [regiment] as Array[ArmyRegiment])
	assert_eq(regiment.units.size(), 0)


func test_add_regiment_with_a_leader_creates_that_unit() -> void:
	var regiment := _editor().add_regiment("hero_a")
	assert_eq(regiment.leader().warscroll_id, "hero_a")


func test_add_regiment_emits_changed() -> void:
	var editor := _editor()
	editor.add_regiment()
	assert_signal_emitted(editor, "changed")


func test_new_regiments_get_distinct_ids() -> void:
	var editor := _editor()
	assert_ne(editor.add_regiment().id, editor.add_regiment().id)


func test_new_ids_do_not_collide_with_existing_ones() -> void:
	var editor := _populated()
	var regiment := editor.add_regiment("hero_b")
	assert_ne(regiment.id, "r1")
	assert_ne(regiment.leader().uid, "u1")
	var uids := _uids(editor.army.all_units())
	for uid in uids:
		assert_eq(uids.count(uid), 1, "duplicate uid %s" % uid)


func test_new_leader_gets_default_weapon_options() -> void:
	var unit := _editor().add_auxiliary("grunt")
	assert_eq(unit.weapon_options, {"Hammer": 2})


func test_remove_regiment_removes_it() -> void:
	var editor := _populated()
	editor.remove_regiment("r1")
	assert_eq(editor.army.regiments.size(), 0)


func test_remove_regiment_clears_a_general_in_it() -> void:
	var editor := _populated()
	editor.army.general_uid = "u1"
	editor.remove_regiment("r1")
	assert_eq(editor.army.general_uid, "")


func test_remove_regiment_keeps_a_general_elsewhere() -> void:
	var editor := _populated()
	editor.add_regiment("hero_b")
	editor.army.general_uid = editor.army.regiments[1].leader().uid
	editor.remove_regiment("r1")
	assert_ne(editor.army.general_uid, "")


func test_remove_unknown_regiment_emits_nothing() -> void:
	var editor := _populated()
	editor.remove_regiment("nope")
	assert_signal_not_emitted(editor, "changed")


func test_rename_regiment_trims_the_name() -> void:
	var editor := _populated()
	editor.rename_regiment("r1", "  Vanguard  ")
	assert_eq(editor.army.find_regiment("r1").name, "Vanguard")


func test_rename_regiment_ignores_a_blank_name() -> void:
	var editor := _populated()
	var before := editor.army.find_regiment("r1").name
	editor.rename_regiment("r1", "   ")
	assert_eq(editor.army.find_regiment("r1").name, before)
	assert_signal_not_emitted(editor, "changed")


func test_move_regiment_to_the_front() -> void:
	var editor := _populated()
	editor.add_regiment()
	editor.add_regiment()
	var last := editor.army.regiments[2]
	editor.move_regiment(last.id, 0)
	assert_eq(editor.army.regiments[0], last)


func test_move_regiment_to_the_end() -> void:
	var editor := _populated()
	editor.add_regiment()
	editor.add_regiment()
	var first := editor.army.regiments[0]
	editor.move_regiment(first.id, 3)
	assert_eq(editor.army.regiments[2], first)


func test_move_regiment_keeps_every_regiment() -> void:
	var editor := _populated()
	editor.add_regiment()
	editor.add_regiment()
	editor.move_regiment("r1", 2)
	assert_eq(editor.army.regiments.size(), 3)


func test_move_unknown_regiment_emits_nothing() -> void:
	var editor := _populated()
	editor.move_regiment("nope", 0)
	assert_signal_not_emitted(editor, "changed")


# Room in regiments

func test_empty_regiment_has_room() -> void:
	assert_true(_editor().has_room(Kit.regiment("r", [] as Array[ArmyUnit])))


func test_regiment_of_renown_has_no_room() -> void:
	assert_false(_editor().has_room(Kit.ror_regiment("r", "Band", [] as Array[ArmyUnit])))


func test_regiment_has_room_until_capacity() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment("hero_a")
	_fill(editor, regiment.id, ArmyValidator.REGIMENT_UNITS - 1)
	assert_true(editor.has_room(regiment))


func test_full_regiment_has_no_room() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment("hero_a")
	_fill(editor, regiment.id, ArmyValidator.REGIMENT_UNITS)
	assert_false(editor.has_room(regiment))


func test_generals_regiment_has_room_for_one_more() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment("hero_a")
	editor.set_general(regiment.leader().uid)
	_fill(editor, regiment.id, ArmyValidator.REGIMENT_UNITS)
	assert_true(editor.has_room(regiment))


func test_overriding_constraints_always_leaves_room() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment("hero_a")
	_fill(editor, regiment.id, ArmyValidator.GENERAL_REGIMENT_UNITS + 1)
	editor.army.override_constraints = true
	assert_true(editor.has_room(regiment))


# Units

func test_add_unit_to_an_empty_regiment_makes_it_the_leader() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment()
	var unit := editor.add_unit(regiment.id, "hero_a")
	assert_eq(regiment.leader(), unit)


func test_add_unit_appends_after_the_leader() -> void:
	var editor := _populated()
	var unit := editor.add_unit("r1", "grunt")
	assert_eq(editor.army.find_regiment("r1").units.back(), unit)


func test_add_unit_to_a_full_regiment_returns_null() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment("hero_a")
	_fill(editor, regiment.id, ArmyValidator.REGIMENT_UNITS)
	assert_null(editor.add_unit(regiment.id, "grunt"))
	assert_eq(regiment.units.size(), ArmyValidator.REGIMENT_UNITS + 1)


func test_add_unit_to_a_full_regiment_works_when_overriding() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment("hero_a")
	_fill(editor, regiment.id, ArmyValidator.REGIMENT_UNITS)
	editor.army.override_constraints = true
	assert_not_null(editor.add_unit(regiment.id, "grunt"))


func test_add_unit_to_an_unknown_regiment_returns_null() -> void:
	assert_null(_editor().add_unit("nope", "grunt"))


func test_add_unit_emits_changed() -> void:
	var editor := _populated()
	editor.add_unit("r1", "grunt")
	assert_signal_emitted(editor, "changed")


func test_add_unit_to_a_full_regiment_emits_nothing() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment("hero_a")
	_fill(editor, regiment.id, ArmyValidator.REGIMENT_UNITS)
	var before: int = get_signal_emit_count(editor, "changed")
	editor.add_unit(regiment.id, "grunt")
	assert_eq(get_signal_emit_count(editor, "changed"), before)


func test_add_auxiliary_appends_to_the_auxiliary_units() -> void:
	var editor := _populated()
	var unit := editor.add_auxiliary("plain")
	assert_eq(editor.army.auxiliary.back(), unit)


func test_remove_unit_removes_it_from_its_regiment() -> void:
	var editor := _populated()
	editor.remove_unit("u2")
	assert_null(editor.army.find_unit("u2"))


func test_remove_unit_removes_it_from_the_auxiliary_units() -> void:
	var editor := _populated()
	editor.remove_unit("u3")
	assert_eq(editor.army.auxiliary.size(), 0)


func test_remove_unit_clears_the_general() -> void:
	var editor := _populated()
	editor.army.general_uid = "u1"
	editor.remove_unit("u1")
	assert_eq(editor.army.general_uid, "")


func test_remove_unit_keeps_a_different_general() -> void:
	var editor := _populated()
	editor.army.general_uid = "u1"
	editor.remove_unit("u2")
	assert_eq(editor.army.general_uid, "u1")


func test_remove_unknown_unit_emits_nothing() -> void:
	var editor := _populated()
	editor.remove_unit("nope")
	assert_signal_not_emitted(editor, "changed")


# Regiments of Renown

func test_add_regiment_of_renown_adds_a_unit_per_model_listed() -> void:
	var regiment := _editor().add_regiment_of_renown("Band")
	assert_eq(regiment.units.size(), 3)


func test_regiment_of_renown_regiment_is_named_after_it() -> void:
	var regiment := _editor().add_regiment_of_renown("Band")
	assert_eq([regiment.name, regiment.regiment_of_renown], ["Band", "Band"])


func test_single_listed_unit_is_labelled_with_its_name() -> void:
	var regiment := _editor().add_regiment_of_renown("Band")
	assert_eq(regiment.units[0].label, "Captain")


func test_units_listed_more_than_once_are_unlabelled() -> void:
	var regiment := _editor().add_regiment_of_renown("Band")
	assert_eq([regiment.units[1].label, regiment.units[2].label], ["", ""])


func test_regiment_of_renown_units_have_distinct_uids() -> void:
	var regiment := _editor().add_regiment_of_renown("Band")
	assert_eq(_uids(regiment.units).size(), 3)
	assert_ne(regiment.units[1].uid, regiment.units[2].uid)


func test_unknown_regiment_of_renown_returns_null() -> void:
	assert_null(_editor().add_regiment_of_renown("Nope"))


func test_second_regiment_of_renown_returns_null() -> void:
	var editor := _editor()
	editor.add_regiment_of_renown("Band")
	assert_null(editor.add_regiment_of_renown("Other Band"))


func test_second_regiment_of_renown_is_allowed_when_overriding() -> void:
	var editor := _editor()
	editor.add_regiment_of_renown("Band")
	editor.army.override_constraints = true
	assert_not_null(editor.add_regiment_of_renown("Other Band"))


func test_regiment_of_renown_forbidden_by_the_army_of_renown_returns_null() -> void:
	var army := Kit.army()
	army.army_of_renown = "Lone Wolves"
	assert_null(_editor(army).add_regiment_of_renown("Band"))


func test_regiment_of_renown_emits_changed() -> void:
	var editor := _editor()
	editor.add_regiment_of_renown("Band")
	assert_signal_emitted(editor, "changed")


func test_unit_cannot_be_added_to_a_regiment_of_renown() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment_of_renown("Band")
	assert_null(editor.add_unit(regiment.id, "grunt"))


# Duplicating

func test_duplicate_unit_inserts_a_copy_after_the_original() -> void:
	var editor := _populated()
	var copy := editor.duplicate_unit("u1")
	assert_eq(editor.army.find_regiment("r1").units[1], copy)


func test_duplicate_unit_gets_a_new_uid() -> void:
	var editor := _populated()
	assert_ne(editor.duplicate_unit("u2").uid, "u2")


func test_duplicate_unit_drops_enhancements() -> void:
	var editor := _populated()
	editor.army.find_unit("u1").enhancements = {"Heroic Traits": "Brave"}
	assert_true(editor.duplicate_unit("u1").enhancements.is_empty())
	assert_eq(editor.army.find_unit("u1").enhancements, {"Heroic Traits": "Brave"})


func test_duplicate_unit_keeps_choices_independent_of_the_original() -> void:
	var editor := _populated()
	editor.army.find_unit("u2").weapon_options = {"Hammer": 1}
	var copy := editor.duplicate_unit("u2")
	copy.weapon_options["Hammer"] = 0
	assert_eq(editor.army.find_unit("u2").weapon_options["Hammer"], 1)


func test_duplicate_auxiliary_unit_stays_auxiliary() -> void:
	var editor := _populated()
	var copy := editor.duplicate_unit("u3")
	assert_eq(editor.army.auxiliary.find(copy), 1)


func test_duplicate_into_a_full_regiment_returns_null() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment("hero_a")
	_fill(editor, regiment.id, ArmyValidator.REGIMENT_UNITS)
	assert_null(editor.duplicate_unit(regiment.units[1].uid))


func test_duplicate_unknown_unit_returns_null() -> void:
	assert_null(_populated().duplicate_unit("nope"))


func test_duplicate_unit_in_a_regiment_of_renown_returns_null() -> void:
	var editor := _editor()
	var regiment := editor.add_regiment_of_renown("Band")
	assert_null(editor.duplicate_unit(regiment.units[0].uid))


# Moving units

func test_move_unit_to_another_regiment() -> void:
	var editor := _populated()
	var other := editor.add_regiment("hero_b")
	assert_true(editor.move_unit("u2", other.id, 1))
	assert_eq(editor.army.regiment_of("u2"), other)


func test_move_unit_into_the_auxiliary_units() -> void:
	var editor := _populated()
	assert_true(editor.move_unit("u2", "", 0))
	assert_null(editor.army.regiment_of("u2"))
	assert_eq(editor.army.auxiliary[0].uid, "u2")


func test_move_auxiliary_unit_into_a_regiment() -> void:
	var editor := _populated()
	assert_true(editor.move_unit("u3", "r1", 2))
	assert_eq(editor.army.regiment_of("u3").id, "r1")


func test_move_unit_within_its_regiment_to_the_end() -> void:
	var editor := _populated()
	editor.add_unit("r1", "grunt")
	editor.move_unit("u2", "r1", 3)
	assert_eq(editor.army.find_regiment("r1").units.back().uid, "u2")


func test_move_unit_into_a_full_regiment_fails() -> void:
	var editor := _populated()
	var other := editor.add_regiment("hero_b")
	_fill(editor, other.id, ArmyValidator.REGIMENT_UNITS)
	assert_false(editor.move_unit("u2", other.id, 1))
	assert_eq(editor.army.regiment_of("u2").id, "r1")


func test_move_unit_into_an_unknown_regiment_fails() -> void:
	assert_false(_populated().move_unit("u2", "nope", 0))


func test_move_unknown_unit_fails() -> void:
	assert_false(_populated().move_unit("nope", "r1", 0))


func test_move_unit_out_of_a_regiment_of_renown_fails() -> void:
	var editor := _populated()
	var band := editor.add_regiment_of_renown("Band")
	assert_false(editor.move_unit(band.units[0].uid, "r1", 1))


func test_move_unit_into_a_regiment_of_renown_fails() -> void:
	var editor := _populated()
	var band := editor.add_regiment_of_renown("Band")
	assert_false(editor.move_unit("u3", band.id, 0))


func test_failed_move_emits_nothing() -> void:
	var editor := _populated()
	editor.move_unit("nope", "r1", 0)
	assert_signal_not_emitted(editor, "changed")


func test_hero_moved_to_the_front_stays_behind_the_hero_leader() -> void:
	var editor := _populated()
	var other := editor.add_regiment("hero_b")
	editor.move_unit(other.leader().uid, "r1", 0)
	assert_eq(editor.army.find_regiment("r1").leader().uid, "u1")


func test_nothing_moves_in_front_of_a_hero_leader() -> void:
	var editor := _populated()
	editor.move_unit("u3", "r1", 0)
	assert_eq(editor.army.find_regiment("r1").units[0].uid, "u1")


func test_hero_moved_into_an_empty_regiment_leads_it() -> void:
	var editor := _populated()
	var empty := editor.add_regiment()
	editor.move_unit("u3", empty.id, 5)
	assert_eq(empty.units[0].uid, "u3")


func test_moving_the_general_out_of_leadership_clears_the_general() -> void:
	var editor := _populated()
	editor.army.general_uid = "u1"
	editor.move_unit("u1", "", 0)
	assert_eq(editor.army.general_uid, "")


# General

func test_set_general_makes_a_leader_the_general() -> void:
	var editor := _populated()
	editor.set_general("u1")
	assert_eq(editor.army.general_uid, "u1")


func test_set_general_again_clears_the_general() -> void:
	var editor := _populated()
	editor.set_general("u1")
	editor.set_general("u1")
	assert_eq(editor.army.general_uid, "")


func test_set_general_replaces_the_previous_general() -> void:
	var editor := _populated()
	var other := editor.add_regiment("hero_b")
	editor.set_general("u1")
	editor.set_general(other.leader().uid)
	assert_eq(editor.army.general_uid, other.leader().uid)


func test_non_leader_cannot_be_the_general() -> void:
	var editor := _populated()
	editor.set_general("u2")
	assert_eq(editor.army.general_uid, "")
	assert_signal_not_emitted(editor, "changed")


func test_auxiliary_unit_cannot_be_the_general() -> void:
	var editor := _populated()
	editor.set_general("u3")
	assert_eq(editor.army.general_uid, "")


func test_non_leader_can_be_the_general_when_overriding() -> void:
	var editor := _populated()
	editor.army.override_constraints = true
	editor.set_general("u2")
	assert_eq(editor.army.general_uid, "u2")


# Unit choices

func test_set_label_trims_the_label() -> void:
	var editor := _populated()
	editor.set_label("u2", "  Gilded Shields ")
	assert_eq(editor.army.find_unit("u2").label, "Gilded Shields")


func test_set_label_on_unknown_unit_emits_nothing() -> void:
	var editor := _populated()
	editor.set_label("nope", "x")
	assert_signal_not_emitted(editor, "changed")


func test_set_reinforced_marks_the_unit() -> void:
	var editor := _populated()
	editor.set_reinforced("u2", true)
	assert_true(editor.army.find_unit("u2").reinforced)


func test_set_reinforced_raises_weapon_options_at_their_cap() -> void:
	var editor := _populated()
	var unit := editor.army.find_unit("u2")
	unit.weapon_options = {"Hammer": 2}
	editor.set_reinforced("u2", true)
	assert_eq(unit.weapon_options["Hammer"], 4)


func test_set_reinforced_ignores_units_that_cannot_reinforce() -> void:
	var editor := _populated()
	editor.set_reinforced("u1", true)
	assert_false(editor.army.find_unit("u1").reinforced)
	assert_signal_not_emitted(editor, "changed")


func test_set_reinforced_to_the_current_state_emits_nothing() -> void:
	var editor := _populated()
	editor.set_reinforced("u2", false)
	assert_signal_not_emitted(editor, "changed")


func test_unreinforcing_lowers_weapon_options_above_the_normal_cap() -> void:
	var editor := _populated()
	editor.set_reinforced("u2", true)
	editor.set_reinforced("u2", false)
	assert_eq(editor.army.find_unit("u2").weapon_options["Hammer"], 2)


func test_set_weapon_option_stores_the_count() -> void:
	var editor := _populated()
	editor.set_weapon_option("u2", "Hammer", 1)
	assert_eq(editor.army.find_unit("u2").weapon_options["Hammer"], 1)


func test_set_weapon_option_clamps_to_the_cap() -> void:
	var editor := _populated()
	editor.set_weapon_option("u2", "Hammer", 99)
	assert_eq(editor.army.find_unit("u2").weapon_options["Hammer"], 2)


func test_set_weapon_option_clamps_to_zero() -> void:
	var editor := _populated()
	editor.set_weapon_option("u2", "Hammer", -3)
	assert_eq(editor.army.find_unit("u2").weapon_options["Hammer"], 0)


func test_set_unknown_weapon_option_emits_nothing() -> void:
	var editor := _populated()
	editor.set_weapon_option("u2", "Phantom Axe", 1)
	assert_signal_not_emitted(editor, "changed")
	assert_false(editor.army.find_unit("u2").weapon_options.has("Phantom Axe"))


# Enhancements

func test_set_enhancement_gives_the_unit_the_enhancement() -> void:
	var editor := _populated()
	editor.set_enhancement("u1", "Heroic Traits", "Brave")
	assert_eq(editor.army.find_unit("u1").enhancements, {"Heroic Traits": "Brave"})


func test_set_enhancement_moves_it_from_another_unit_of_the_type() -> void:
	var editor := _populated()
	var other := editor.add_regiment("hero_b")
	editor.set_enhancement("u1", "Heroic Traits", "Brave")
	editor.set_enhancement(other.leader().uid, "Heroic Traits", "Bold")
	assert_false(editor.army.find_unit("u1").enhancements.has("Heroic Traits"))
	assert_eq(other.leader().enhancements["Heroic Traits"], "Bold")


func test_set_enhancement_keeps_other_types_on_other_units() -> void:
	var editor := _populated()
	var other := editor.add_regiment("hero_b")
	editor.set_enhancement("u1", "Artefacts of Power", "Sword")
	editor.set_enhancement(other.leader().uid, "Heroic Traits", "Bold")
	assert_eq(editor.army.find_unit("u1").enhancements["Artefacts of Power"], "Sword")


func test_set_enhancement_keeps_other_types_on_the_same_unit() -> void:
	var editor := _populated()
	editor.set_enhancement("u1", "Artefacts of Power", "Sword")
	editor.set_enhancement("u1", "Heroic Traits", "Brave")
	assert_eq(editor.army.find_unit("u1").enhancements.size(), 2)


func test_set_enhancement_allows_repeats_when_overriding() -> void:
	var editor := _populated()
	var other := editor.add_regiment("hero_b")
	editor.army.override_constraints = true
	editor.set_enhancement("u1", "Heroic Traits", "Brave")
	editor.set_enhancement(other.leader().uid, "Heroic Traits", "Bold")
	assert_true(editor.army.find_unit("u1").enhancements.has("Heroic Traits"))


func test_empty_enhancement_name_removes_the_enhancement() -> void:
	var editor := _populated()
	editor.set_enhancement("u1", "Heroic Traits", "Brave")
	editor.set_enhancement("u1", "Heroic Traits", "")
	assert_true(editor.army.find_unit("u1").enhancements.is_empty())


func test_set_enhancement_on_unknown_unit_emits_nothing() -> void:
	var editor := _populated()
	editor.set_enhancement("nope", "Heroic Traits", "Brave")
	assert_signal_not_emitted(editor, "changed")


# Battle tactics

func test_set_tactic_fills_the_slot() -> void:
	var editor := _editor()
	editor.army.tactics = PackedStringArray(["", ""])
	editor.set_tactic(1, "Card A")
	assert_eq(editor.army.tactics, PackedStringArray(["", "Card A"]))


func test_set_tactic_replaces_the_card_in_the_slot() -> void:
	var editor := _editor()
	editor.army.tactics = PackedStringArray(["Card A", "Card B"])
	editor.set_tactic(0, "Card C")
	assert_eq(editor.army.tactics, PackedStringArray(["Card C", "Card B"]))


func test_set_tactic_moves_a_card_picked_in_the_other_slot() -> void:
	var editor := _editor()
	editor.army.tactics = PackedStringArray(["Card A", "Card B"])
	editor.set_tactic(1, "Card A")
	assert_eq(editor.army.tactics, PackedStringArray(["", "Card A"]))


func test_set_tactic_to_the_same_slot_keeps_the_card() -> void:
	var editor := _editor()
	editor.army.tactics = PackedStringArray(["Card A", "Card B"])
	editor.set_tactic(0, "Card A")
	assert_eq(editor.army.tactics, PackedStringArray(["Card A", "Card B"]))


func test_clearing_a_tactic_slot_leaves_the_other_slot() -> void:
	var editor := _editor()
	editor.army.tactics = PackedStringArray(["Card A", ""])
	editor.set_tactic(1, "")
	assert_eq(editor.army.tactics, PackedStringArray(["Card A", ""]))


func test_set_tactic_pads_missing_slots() -> void:
	var editor := _editor()
	editor.army.tactics = PackedStringArray()
	editor.set_tactic(1, "Card A")
	assert_eq(editor.army.tactics, PackedStringArray(["", "Card A"]))


# Lores, formation and terrain

func test_set_lore_sets_each_kind() -> void:
	var editor := _editor()
	editor.set_lore("spell", "Fire")
	editor.set_lore("prayer", "Hymns")
	editor.set_lore("manifestation", "Own Manifest")
	assert_eq([editor.army.spell_lore, editor.army.prayer_lore, editor.army.manifestation_lore], ["Fire", "Hymns", "Own Manifest"])


func test_set_lore_with_empty_name_clears_it() -> void:
	var editor := _editor()
	editor.set_lore("spell", "Fire")
	editor.set_lore("spell", "")
	assert_eq(editor.army.spell_lore, "")


func test_set_lore_of_unknown_kind_emits_nothing() -> void:
	var editor := _editor()
	editor.set_lore("nonsense", "Fire")
	assert_signal_not_emitted(editor, "changed")


func test_set_formation_and_faction_terrain() -> void:
	var editor := _editor()
	editor.set_formation("Vanguard")
	editor.set_faction_terrain("plain")
	assert_eq([editor.army.formation, editor.army.faction_terrain], ["Vanguard", "plain"])


# Army of Renown

func _horde_editor() -> ArmyEditor:
	var editor := _populated()
	editor.army.formation = "Vanguard"
	editor.army.spell_lore = "Fire"
	editor.army.prayer_lore = "Hymns"
	editor.army.manifestation_lore = "Own Manifest"
	editor.army.faction_terrain = "plain"
	editor.set_enhancement("u1", "Heroic Traits", "Brave")
	editor.set_enhancement("u1", "Artefacts of Power", "Sword")
	return editor


func test_switching_to_an_army_of_renown_sets_it() -> void:
	var editor := _horde_editor()
	editor.set_army_of_renown("Horde")
	assert_eq(editor.army.army_of_renown, "Horde")


func test_switching_to_an_army_of_renown_clears_the_formation() -> void:
	var editor := _horde_editor()
	editor.set_army_of_renown("Horde")
	assert_eq(editor.army.formation, "")


func test_switching_to_an_army_of_renown_clears_lores_it_lacks() -> void:
	var editor := _horde_editor()
	editor.set_army_of_renown("Horde")
	assert_eq([editor.army.spell_lore, editor.army.prayer_lore], ["", ""])


func test_switching_keeps_universal_manifestation_lores() -> void:
	var editor := _horde_editor()
	editor.army.manifestation_lore = "Universal"
	var core_lores: Array[Lore] = [Kit.lore("Universal", "manifestation")]
	editor.catalog = Kit.catalog(_faction(), Kit.core(PackedStringArray(), core_lores))
	editor.set_army_of_renown("Horde")
	assert_eq(editor.army.manifestation_lore, "Universal")


func test_switching_clears_enhancements_it_lacks() -> void:
	var editor := _horde_editor()
	editor.set_army_of_renown("Horde")
	assert_true(editor.army.find_unit("u1").enhancements.is_empty())


func test_switching_keeps_enhancements_it_offers() -> void:
	var editor := _horde_editor()
	editor.set_enhancement("u1", "Heroic Traits", "Horde Trait")
	editor.set_army_of_renown("Horde")
	assert_eq(editor.army.find_unit("u1").enhancements, {"Heroic Traits": "Horde Trait"})


func test_switching_clears_faction_terrain_the_roster_forbids() -> void:
	var editor := _horde_editor()
	editor.set_army_of_renown("Horde")
	assert_eq(editor.army.faction_terrain, "")


func test_switching_keeps_faction_terrain_the_roster_allows() -> void:
	var editor := _horde_editor()
	editor.set_army_of_renown("Lone Wolves")
	assert_eq(editor.army.faction_terrain, "plain")


func test_switching_back_to_faction_rules_clears_lores_only_the_army_of_renown_offered() -> void:
	var editor := _horde_editor()
	editor.army.army_of_renown = "Horde"
	editor.army.spell_lore = "Horde Spell"
	editor.set_army_of_renown("")
	assert_eq(editor.army.spell_lore, "")


func test_switching_army_of_renown_emits_changed() -> void:
	var editor := _horde_editor()
	editor.set_army_of_renown("Horde")
	assert_signal_emitted(editor, "changed")


# Army settings

func test_set_army_name_trims_the_name() -> void:
	var editor := _editor()
	editor.set_army_name("  My Army ")
	assert_eq(editor.army.name, "My Army")


func test_set_army_name_ignores_blank_names() -> void:
	var editor := _editor()
	var before := editor.army.name
	editor.set_army_name("  ")
	assert_eq(editor.army.name, before)
	assert_signal_not_emitted(editor, "changed")


func test_set_points_limit_stores_the_limit() -> void:
	var editor := _editor()
	editor.set_points_limit(1000)
	assert_eq(editor.army.points_limit, 1000)


func test_set_points_limit_is_never_negative() -> void:
	var editor := _editor()
	editor.set_points_limit(-50)
	assert_eq(editor.army.points_limit, 0)


func test_set_show_legends_and_override_constraints() -> void:
	var editor := _editor()
	editor.set_show_legends(true)
	editor.set_override_constraints(true)
	assert_true(editor.army.show_legends)
	assert_true(editor.army.override_constraints)
	assert_signal_emit_count(editor, "changed", 2)


# Insert positions

## An editor on an army with regiment r1 (hero_a leader, grunts u2 and u3) and auxiliary grunts u4 and u5.
func _ordered() -> ArmyEditor:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "hero_a"), Kit.unit("u2", "grunt"), Kit.unit("u3", "grunt")] as Array[ArmyUnit]))
	army.auxiliary.append(Kit.unit("u4", "grunt"))
	army.auxiliary.append(Kit.unit("u5", "grunt"))
	return _editor(army)


func test_add_unit_at_an_index_inserts_there() -> void:
	var editor := _ordered()
	var unit := editor.add_unit("r1", "grunt", 2)
	assert_eq(editor.army.regiments[0].units[2], unit)


func test_add_unit_without_an_index_appends() -> void:
	var editor := _ordered()
	var unit := editor.add_unit("r1", "grunt")
	assert_eq(editor.army.regiments[0].units[-1], unit)


func test_add_unit_at_an_index_past_the_end_appends() -> void:
	var editor := _ordered()
	var unit := editor.add_unit("r1", "grunt", 99)
	assert_eq(editor.army.regiments[0].units[-1], unit)


func test_add_unit_never_goes_before_a_hero_leader() -> void:
	var editor := _ordered()
	editor.add_unit("r1", "grunt", 0)
	assert_eq(editor.army.regiments[0].units[0].uid, "u1")


func test_add_unit_at_the_start_of_a_regiment_led_by_a_non_hero_goes_first() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "grunt")] as Array[ArmyUnit]))
	var editor := _editor(army)
	var unit := editor.add_unit("r1", "grunt", 0)
	assert_eq(army.regiments[0].units[0], unit)


func test_add_unit_to_a_full_regiment_at_an_index_returns_null() -> void:
	var editor := _ordered()
	_fill(editor, "r1", 10)
	assert_null(editor.add_unit("r1", "grunt", 1))


func test_add_auxiliary_at_an_index_inserts_there() -> void:
	var editor := _ordered()
	var unit := editor.add_auxiliary("grunt", 1)
	assert_eq(editor.army.auxiliary[1], unit)


func test_add_auxiliary_without_an_index_appends() -> void:
	var editor := _ordered()
	var unit := editor.add_auxiliary("grunt")
	assert_eq(editor.army.auxiliary[-1], unit)


func test_add_auxiliary_at_an_index_past_the_end_appends() -> void:
	var editor := _ordered()
	var unit := editor.add_auxiliary("grunt", 99)
	assert_eq(editor.army.auxiliary[-1], unit)


# insertion_index

func test_insertion_index_is_zero_in_an_empty_regiment() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [] as Array[ArmyUnit]))
	assert_eq(_editor(army).insertion_index(army.regiments[0], 5), 0)


func test_insertion_index_keeps_a_position_after_a_hero_leader() -> void:
	var editor := _ordered()
	assert_eq(editor.insertion_index(editor.army.regiments[0], 2), 2)


func test_insertion_index_moves_a_position_before_a_hero_leader_after_it() -> void:
	var editor := _ordered()
	assert_eq(editor.insertion_index(editor.army.regiments[0], 0), 1)


func test_insertion_index_clamps_to_the_end() -> void:
	var editor := _ordered()
	assert_eq(editor.insertion_index(editor.army.regiments[0], 99), 3)


func test_insertion_index_clamps_a_negative_index_to_the_start_without_a_hero_leader() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "grunt")] as Array[ArmyUnit]))
	assert_eq(_editor(army).insertion_index(army.regiments[0], -3), 0)


# insertion_index with a non-Hero general

func _crew_editor(general_in_regiment := "ironclad") -> ArmyEditor:
	var faction := _faction()
	faction.warscrolls.append(Kit.warscroll("ironclad", PackedStringArray(), 100, "Ironclad"))
	var crew := Kit.army_of_renown("Crew")
	crew.roster.non_hero_general = "Ironclad"
	faction.armies_of_renown.append(crew)
	var army := Kit.army()
	army.army_of_renown = "Crew"
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", general_in_regiment), Kit.unit("u2", "grunt")] as Array[ArmyUnit]))
	return ArmyEditor.new(army, Kit.catalog(faction))


func test_insertion_index_moves_a_position_before_a_non_hero_general_leader_after_it() -> void:
	var editor := _crew_editor()
	assert_eq(editor.insertion_index(editor.army.regiments[0], 0), 1)


func test_insertion_index_allows_the_start_before_a_leader_that_cannot_lead() -> void:
	var editor := _crew_editor("grunt")
	assert_eq(editor.insertion_index(editor.army.regiments[0], 0), 0)


# can_add_regiment_of_renown

func test_can_add_an_allowed_regiment_of_renown() -> void:
	assert_true(_editor().can_add_regiment_of_renown("Band"))


func test_cannot_add_an_unknown_regiment_of_renown() -> void:
	assert_false(_editor().can_add_regiment_of_renown("Nope"))


func test_cannot_add_a_regiment_of_renown_the_army_of_renown_forbids() -> void:
	var army := Kit.army()
	army.army_of_renown = "Lone Wolves"
	assert_false(_editor(army).can_add_regiment_of_renown("Band"))


func test_cannot_add_a_second_regiment_of_renown() -> void:
	var editor := _editor()
	editor.add_regiment_of_renown("Band")
	assert_false(editor.can_add_regiment_of_renown("Other Band"))


func test_can_add_a_second_regiment_of_renown_when_overriding() -> void:
	var editor := _editor()
	editor.add_regiment_of_renown("Band")
	editor.set_override_constraints(true)
	assert_true(editor.can_add_regiment_of_renown("Other Band"))


func test_overriding_does_not_allow_an_unknown_regiment_of_renown() -> void:
	var editor := _editor()
	editor.set_override_constraints(true)
	assert_false(editor.can_add_regiment_of_renown("Nope"))


# Units included from other factions

## An editor whose Army of Renown "Horde" includes the faction "home"'s hero, grunt and plain unit.
func _including_editor() -> ArmyEditor:
	var faction := _faction()
	var inclusion := RosterInclusion.new()
	inclusion.faction = "home"
	faction.armies_of_renown[0].roster.included_units = [inclusion] as Array[RosterInclusion]
	var scrolls: Array[Warscroll] = [Kit.hero("away_hero"), Kit.warscroll("away_grunt")]
	scrolls[1].weapon_options.append(Kit.weapon_option("Axe", 1, 5))
	var home := Kit.faction(scrolls, "home")
	var loader := func(faction_id: String) -> Faction: return home if faction_id == "home" else null
	var army := Kit.army()
	army.army_of_renown = "Horde"
	return ArmyEditor.new(army, Kit.catalog(faction, null, loader))


func test_added_included_unit_records_its_faction() -> void:
	var editor := _including_editor()
	var regiment := editor.add_regiment("hero_a")
	assert_eq(editor.add_unit(regiment.id, "away_grunt").faction_id, "home")


func test_added_included_unit_gets_default_weapon_options() -> void:
	var editor := _including_editor()
	var regiment := editor.add_regiment("hero_a")
	assert_false(editor.add_unit(regiment.id, "away_grunt").weapon_options.is_empty())


func test_added_own_unit_has_no_faction() -> void:
	var editor := _including_editor()
	var regiment := editor.add_regiment("hero_a")
	assert_eq(editor.add_unit(regiment.id, "grunt").faction_id, "")


func test_included_hero_can_lead_a_new_regiment() -> void:
	var editor := _including_editor()
	var regiment := editor.add_regiment("away_hero")
	assert_eq([regiment.units.size(), regiment.units[0].faction_id], [1, "home"])


func test_included_hero_leader_leaves_room_for_more_units() -> void:
	var editor := _including_editor()
	var regiment := editor.add_regiment("away_hero")
	assert_not_null(editor.add_unit(regiment.id, "grunt"))


func test_added_included_auxiliary_unit_records_its_faction() -> void:
	assert_eq(_including_editor().add_auxiliary("away_grunt").faction_id, "home")


func test_added_own_auxiliary_unit_has_no_faction() -> void:
	assert_eq(_including_editor().add_auxiliary("grunt").faction_id, "")


# Leaderless regiments

func test_removing_the_leader_leaves_the_regiment_leaderless() -> void:
	var editor := _populated()
	editor.remove_unit("u1")
	var regiment := editor.army.regiments[0]
	assert_true(regiment.leaderless)
	assert_null(regiment.leader())
	assert_eq(_uids(regiment.units), ["u2"])


func test_removing_a_follower_keeps_the_leader() -> void:
	var editor := _populated()
	editor.remove_unit("u2")
	assert_false(editor.army.regiments[0].leaderless)


func test_removing_the_last_unit_clears_leaderless() -> void:
	var editor := _populated()
	editor.remove_unit("u1")
	editor.remove_unit("u2")
	assert_false(editor.army.regiments[0].leaderless)


func test_moving_the_leader_to_auxiliary_leaves_the_regiment_leaderless() -> void:
	var editor := _populated()
	assert_true(editor.move_unit("u1", "", 0))
	assert_true(editor.army.regiments[0].leaderless)


func test_moving_the_leader_to_another_regiment_leaves_the_source_leaderless() -> void:
	var editor := _populated()
	editor.add_regiment("hero_b")
	var other := editor.army.regiments[1]
	assert_true(editor.move_unit("u1", other.id, 1))
	assert_true(editor.army.regiments[0].leaderless)


func test_moving_the_only_unit_out_does_not_leave_the_regiment_leaderless() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "hero_a")] as Array[ArmyUnit]))
	var editor := _editor(army)
	editor.move_unit("u1", "", 0)
	assert_false(army.regiments[0].leaderless)


func test_reordering_within_a_regiment_keeps_the_leader() -> void:
	var editor := _populated()
	editor.move_unit("u2", "r1", 1)
	assert_false(editor.army.regiments[0].leaderless)


func test_add_leader_puts_the_unit_first_and_clears_leaderless() -> void:
	var editor := _populated()
	editor.remove_unit("u1")
	var leader := editor.add_leader("r1", "hero_b")
	var regiment := editor.army.regiments[0]
	assert_eq(regiment.leader(), leader)
	assert_false(regiment.leaderless)
	assert_eq(regiment.units[1].uid, "u2")


func test_add_leader_is_refused_when_the_regiment_has_a_leader() -> void:
	var editor := _populated()
	assert_null(editor.add_leader("r1", "hero_b"))
	assert_eq(editor.army.regiments[0].units.size(), 2)


func test_add_leader_works_on_an_empty_regiment() -> void:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [] as Array[ArmyUnit]))
	var editor := _editor(army)
	assert_not_null(editor.add_leader("r1", "hero_a"))
	assert_eq(army.regiments[0].units.size(), 1)


func test_add_leader_is_null_for_an_unknown_regiment() -> void:
	assert_null(_populated().add_leader("nope", "hero_a"))


func test_add_leader_emits_changed() -> void:
	var editor := _populated()
	editor.remove_unit("u1")
	editor.add_leader("r1", "hero_b")
	assert_signal_emitted(editor, "changed")


func test_has_room_counts_followers_of_a_leaderless_regiment() -> void:
	var editor := _populated()
	editor.remove_unit("u1")
	var regiment := editor.army.regiments[0]
	var capacity := ArmyValidator.regiment_capacity(regiment, editor.army)
	_fill(editor, "r1", capacity - 1)
	assert_false(editor.has_room(regiment))


func test_insertion_index_allows_the_start_of_a_leaderless_regiment() -> void:
	var editor := _populated()
	editor.remove_unit("u1")
	assert_eq(editor.insertion_index(editor.army.regiments[0], 0), 0)
