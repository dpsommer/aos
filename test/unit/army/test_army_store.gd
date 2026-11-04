extends GutTest
## Unit tests for saving armies to disk (scripts/army/army_store.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")


func before_each() -> void:
	Sandbox.begin()


## The builder frees redrawn content with queue_free, so let a frame pass before GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame
	Sandbox.end()


func _army() -> Army:
	var army := Kit.army()
	army.name = "Saved Army"
	army.army_of_renown = "Horde"
	army.formation = "Vanguard"
	army.points_limit = 1500
	army.show_legends = true
	army.override_constraints = true
	var leader := Kit.unit("u1", "hero_a")
	leader.label = "Boss"
	leader.enhancements = {"Heroic Traits": "Brave"}
	var grunt := Kit.unit("u2", "grunt")
	grunt.reinforced = true
	grunt.weapon_options = {"Hammer": 3}
	var renown_unit := Kit.unit("u3", "ror_grunt")
	renown_unit.faction_id = "home"
	army.regiments.append(Kit.regiment("r1", [leader, grunt] as Array[ArmyUnit], "Alpha"))
	army.regiments.append(Kit.ror_regiment("r2", "Band", [renown_unit] as Array[ArmyUnit]))
	army.auxiliary.append(Kit.unit("u4", "plain"))
	army.general_uid = "u1"
	army.tactics = PackedStringArray(["Card A", "Card B"])
	army.spell_lore = "Fire"
	army.prayer_lore = "Hymns"
	army.manifestation_lore = "Universal"
	army.faction_terrain = "terrain"
	return army


func _write_raw(id: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ArmyStore.directory)
	var file := FileAccess.open(ArmyStore.path(id), FileAccess.WRITE)
	file.store_string(text)


func _set_saved_at(id: String, saved_at: float) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArmyStore.path(id)))
	data.saved_at = saved_at
	_write_raw(id, JSON.stringify(data))


func _saved(army_name := "Army", saved_at := -1.0) -> Army:
	var army := Kit.army()
	army.name = army_name
	assert_eq(ArmyStore.save(army), OK)
	if saved_at >= 0.0:
		_set_saved_at(army.id, saved_at)
	return army


# --- Saving and reading ---

func test_save_succeeds() -> void:
	assert_eq(ArmyStore.save(_army()), OK)


func test_save_creates_the_directory() -> void:
	ArmyStore.save(_army())
	assert_true(DirAccess.dir_exists_absolute(ArmyStore.directory))


func test_save_writes_a_file_named_by_the_id() -> void:
	var army := _army()
	ArmyStore.save(army)
	assert_true(FileAccess.file_exists(ArmyStore.path(army.id)))


func test_save_assigns_an_id_to_a_new_army() -> void:
	var army := _army()
	ArmyStore.save(army)
	assert_false(army.id.is_empty())


func test_save_keeps_an_existing_id() -> void:
	var army := _army()
	army.id = "chosen"
	ArmyStore.save(army)
	assert_eq(army.id, "chosen")


func test_saving_again_keeps_the_id_and_the_file() -> void:
	var army := _army()
	ArmyStore.save(army)
	var id := army.id
	army.name = "Renamed"
	ArmyStore.save(army)
	assert_eq(army.id, id)
	assert_eq(ArmyStore.list().size(), 1)
	assert_eq(ArmyStore.load_army(id).name, "Renamed")


func test_new_ids_are_distinct() -> void:
	assert_ne(ArmyStore.new_id(), ArmyStore.new_id())


func test_new_ids_are_safe_file_names() -> void:
	var id := ArmyStore.new_id()
	assert_true(id.is_valid_hex_number())
	assert_eq(id.get_file(), id)


func test_round_trip_keeps_the_army_settings() -> void:
	var original := _army()
	ArmyStore.save(original)
	var loaded := ArmyStore.load_army(original.id)
	assert_eq([loaded.id, loaded.faction_id, loaded.name, loaded.army_of_renown, loaded.formation, loaded.points_limit,
			loaded.show_legends, loaded.override_constraints, loaded.general_uid, loaded.faction_terrain],
			[original.id, original.faction_id, original.name, original.army_of_renown, original.formation, original.points_limit,
			original.show_legends, original.override_constraints, original.general_uid, original.faction_terrain])


func test_round_trip_keeps_tactics_and_lores() -> void:
	var original := _army()
	ArmyStore.save(original)
	var loaded := ArmyStore.load_army(original.id)
	assert_eq(loaded.tactics, original.tactics)
	assert_eq([loaded.spell_lore, loaded.prayer_lore, loaded.manifestation_lore],
			[original.spell_lore, original.prayer_lore, original.manifestation_lore])


func test_round_trip_keeps_regiments_and_their_units() -> void:
	var original := _army()
	ArmyStore.save(original)
	var loaded := ArmyStore.load_army(original.id)
	var ids := []
	for regiment in loaded.regiments:
		ids.append([regiment.id, regiment.name, regiment.units.map(func(u: ArmyUnit) -> String: return u.uid)])
	assert_eq(ids, [["r1", "Alpha", ["u1", "u2"]], ["r2", "Band", ["u3"]]])


func test_round_trip_keeps_the_regiment_of_renown() -> void:
	var original := _army()
	ArmyStore.save(original)
	var loaded := ArmyStore.load_army(original.id)
	assert_eq(loaded.regiments[1].regiment_of_renown, "Band")
	assert_eq(loaded.regiments[1].units[0].faction_id, "home")


func test_round_trip_keeps_enhancements_and_weapon_options() -> void:
	var original := _army()
	ArmyStore.save(original)
	var loaded := ArmyStore.load_army(original.id)
	assert_eq(loaded.regiments[0].units[0].enhancements, {"Heroic Traits": "Brave"})
	assert_eq(loaded.regiments[0].units[1].weapon_options, {"Hammer": 3})


func test_round_trip_keeps_unit_flags_and_auxiliary_units() -> void:
	var original := _army()
	ArmyStore.save(original)
	var loaded := ArmyStore.load_army(original.id)
	assert_eq(loaded.regiments[0].units[0].label, "Boss")
	assert_true(loaded.regiments[0].units[1].reinforced)
	assert_eq(loaded.auxiliary[0].warscroll_id, "plain")


func test_read_sets_the_id_from_the_file_name() -> void:
	var army := _army()
	ArmyStore.save(army)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArmyStore.path(army.id)))
	data.id = "somebody else"
	_write_raw(army.id, JSON.stringify(data))
	assert_eq(ArmyStore.load_army(army.id).id, army.id)


func test_read_records_when_it_was_saved() -> void:
	var army := _saved()
	var before := Time.get_unix_time_from_system()
	ArmyStore.save(army)
	assert_between(ArmyStore.read(army.id).saved_at, before - 1.0, Time.get_unix_time_from_system() + 1.0)


func test_read_passes_serializer_errors_through() -> void:
	var army := _army()
	ArmyStore.save(army)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArmyStore.path(army.id)))
	data.name = 5
	_write_raw(army.id, JSON.stringify(data))
	var entry := ArmyStore.read(army.id)
	assert_not_null(entry.army)
	assert_gt(entry.errors.size(), 0)


func test_read_of_an_unsupported_version_has_no_army_and_an_error() -> void:
	var army := _army()
	ArmyStore.save(army)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArmyStore.path(army.id)))
	data.version = 999
	_write_raw(army.id, JSON.stringify(data))
	var entry := ArmyStore.read(army.id)
	assert_null(entry.army)
	assert_gt(entry.errors.size(), 0)


# --- Unreadable files ---

func test_read_of_invalid_json_has_no_army_and_an_error() -> void:
	_write_raw("broken", "this is { not json")
	var entry := ArmyStore.read("broken")
	assert_null(entry.army)
	assert_gt(entry.errors.size(), 0)


func test_read_of_a_json_array_has_no_army() -> void:
	_write_raw("array", "[1, 2, 3]")
	assert_null(ArmyStore.read("array").army)


func test_read_of_an_empty_file_has_no_army() -> void:
	_write_raw("empty", "")
	assert_null(ArmyStore.read("empty").army)


func test_read_of_a_missing_file_has_no_army() -> void:
	assert_null(ArmyStore.read("missing").army)


func test_load_army_of_an_unreadable_file_is_null() -> void:
	_write_raw("broken", "nope")
	assert_null(ArmyStore.load_army("broken"))


func test_unreadable_file_still_appears_in_the_list() -> void:
	_write_raw("broken", "nope")
	var entries := ArmyStore.list()
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].id, "broken")


func test_list_ignores_other_file_types() -> void:
	_saved()
	var file := FileAccess.open(ArmyStore.directory.path_join("notes.txt"), FileAccess.WRITE)
	file.store_string("hello")
	file.close()
	assert_eq(ArmyStore.list().size(), 1)


# --- Listing ---

func test_list_without_a_directory_is_empty() -> void:
	assert_eq(ArmyStore.list().size(), 0)


func test_list_of_an_empty_directory_is_empty() -> void:
	DirAccess.make_dir_recursive_absolute(ArmyStore.directory)
	assert_eq(ArmyStore.list().size(), 0)


func test_list_returns_every_saved_army() -> void:
	var a := _saved("A")
	var b := _saved("B")
	var ids := PackedStringArray()
	for entry in ArmyStore.list():
		ids.append(entry.id)
	ids.sort()
	var expected := PackedStringArray([a.id, b.id])
	expected.sort()
	assert_eq(ids, expected)


func test_list_puts_the_most_recently_saved_first() -> void:
	var old := _saved("Old", 100.0)
	var mid := _saved("Mid", 200.0)
	var new := _saved("New", 300.0)
	var ids := PackedStringArray()
	for entry in ArmyStore.list():
		ids.append(entry.id)
	assert_eq(ids, PackedStringArray([new.id, mid.id, old.id]))


func test_resaving_moves_an_army_to_the_front() -> void:
	var old := _saved("Old", 100.0)
	_saved("Other", 200.0)
	ArmyStore.save(old)
	assert_eq(ArmyStore.list()[0].id, old.id)


func test_files_without_saved_at_sort_last() -> void:
	var dated := _saved("Dated", 50.0)
	var data := ArmySerializer.to_dict(_army())
	_write_raw("undated", JSON.stringify(data))
	assert_eq(ArmyStore.list()[0].id, dated.id)


# --- Deleting and copying ---

func test_delete_removes_the_file() -> void:
	var army := _saved()
	assert_eq(ArmyStore.delete(army.id), OK)
	assert_false(FileAccess.file_exists(ArmyStore.path(army.id)))


func test_delete_removes_the_army_from_the_list() -> void:
	var army := _saved()
	ArmyStore.delete(army.id)
	assert_eq(ArmyStore.list().size(), 0)


func test_delete_of_a_missing_army_is_an_error() -> void:
	assert_ne(ArmyStore.delete("missing"), OK)


func test_delete_leaves_other_armies() -> void:
	var keep := _saved("Keep")
	var gone := _saved("Gone")
	ArmyStore.delete(gone.id)
	assert_eq(ArmyStore.list()[0].id, keep.id)


func test_copy_has_a_new_id() -> void:
	var army := _saved()
	assert_ne(ArmyStore.copy(army.id).id, army.id)


func test_copy_is_named_as_a_copy() -> void:
	var army := _saved("Vanguard")
	assert_eq(ArmyStore.copy(army.id).name, "Vanguard (copy)")


func test_copy_is_saved() -> void:
	var army := _saved()
	var copy := ArmyStore.copy(army.id)
	assert_eq(ArmyStore.load_army(copy.id).name, copy.name)
	assert_eq(ArmyStore.list().size(), 2)


func test_copy_keeps_the_original_unchanged() -> void:
	var army := _saved("Vanguard")
	ArmyStore.copy(army.id)
	assert_eq(ArmyStore.load_army(army.id).name, "Vanguard")


func test_copy_keeps_the_armys_contents() -> void:
	var original := _army()
	ArmyStore.save(original)
	var copy := ArmyStore.load_army(ArmyStore.copy(original.id).id)
	assert_eq(copy.regiments.size(), original.regiments.size())
	assert_eq(copy.tactics, original.tactics)


func test_copy_of_an_unreadable_army_is_null() -> void:
	_write_raw("broken", "nope")
	assert_null(ArmyStore.copy("broken"))


# --- Faction data that has changed ---

## An army with a unit whose warscroll is not in UIKit's faction.
func _army_with_removed_unit() -> Army:
	var army := UIKit.army_with_regiment(PackedStringArray(["grunt", "removed"]))
	army.name = "Old list"
	ArmyStore.save(army)
	return army


func test_unit_missing_from_the_faction_still_loads() -> void:
	var army := _army_with_removed_unit()
	var loaded := ArmyStore.load_army(army.id)
	assert_not_null(loaded)
	assert_eq(loaded.regiments[0].units[2].warscroll_id, "removed")


func test_unit_missing_from_the_faction_loads_without_errors() -> void:
	var army := _army_with_removed_unit()
	assert_eq(ArmyStore.read(army.id).errors.size(), 0)


func test_validator_reports_a_unit_missing_from_the_faction() -> void:
	var army := _army_with_removed_unit()
	var loaded := ArmyStore.load_army(army.id)
	var result := ArmyValidator.validate(loaded, Kit.catalog(UIKit.faction()))
	var found := Array(result.problems).any(func(p: String) -> bool: return p.ends_with("warscroll is no longer in the faction data."))
	assert_true(found, "problems: %s" % str(result.problems))


func test_builder_opens_an_army_with_a_unit_missing_from_the_faction() -> void:
	var army := _army_with_removed_unit()
	var builder := UIKit.builder(self, ArmyStore.load_army(army.id))
	assert_not_null(builder.editor)


func test_builder_row_says_the_unit_is_no_longer_in_the_faction_data() -> void:
	var army := _army_with_removed_unit()
	var builder := UIKit.builder(self, ArmyStore.load_army(army.id))
	assert_true(UIKit.has_label_containing(builder, "No longer in the faction data"))
