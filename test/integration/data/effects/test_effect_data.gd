extends GutTest
## data/effects/*.json against the rules data and the engine: every entry is written for an ability
## that exists with the text it was written from, and uses only ops, conditions and hooks the engine has.

const RulesKit := preload("res://test/support/rules_kit.gd")
const DIRECTORY := "res://data/effects"
## Keys that aren't abilities, so they have no text to hash.
const UNHASHED: PackedStringArray = ["scoring:", "tactic:", "twist:"]


func _entries() -> Dictionary:
	var result := {}
	for file_name in DirAccess.get_files_at(DIRECTORY):
		if file_name.ends_with(".json"):
			result.merge(JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIRECTORY, file_name])))
	return result


func _is_ability_key(key: String) -> bool:
	for prefix in UNHASHED:
		if key.begins_with(prefix):
			return false
	return true


func _named(abilities: Array, ability_name: String) -> Ability:
	for ability: Ability in abilities:
		if ability.name == ability_name:
			return ability
	return null


## The ability [param key] is the effect data of, found the way tools/effects/stamp_hashes.py does.
func _locate(key: String) -> Ability:
	var space := key.get_slice(":", 0)
	var parts := key.substr(space.length() + 1).split("/")
	var path := key.substr(space.length() + 1)
	match space:
		"core":
			return CoreRulesCatalog.get_rules().get_ability(path)
		"spearhead":
			return _locate_in_spearhead(parts)
		"pack":
			var pack := CoreRulesCatalog.get_spearhead_battlepack(parts[0])
			if pack == null:
				return null
			if parts[1] == "card":
				for card in pack.battle_tactic_cards:
					if card.name == parts[2]:
						return card.command
				return null
			return _named(pack.abilities, "/".join(parts.slice(1)))
		"battleplan":
			for plan in CoreRulesCatalog.get_rules().battlepack.battleplans:
				if plan.name == parts[0]:
					return _named(plan.abilities, parts[1])
			return null
	return _locate_in_faction(space, parts)


func _locate_in_spearhead(parts: PackedStringArray) -> Ability:
	for entry in FactionCatalog.spearheads():
		if entry.name != parts[0]:
			continue
		for spearhead in FactionCatalog.load_faction(entry.faction).spearheads:
			if spearhead.name != parts[0]:
				continue
			var ability_name := "/".join(parts.slice(2))
			match parts[1]:
				"trait":
					return _named(spearhead.battle_traits, ability_name)
				"regiment":
					return _named(spearhead.regiment_abilities, ability_name)
				"enhancement":
					return _named(spearhead.enhancements, ability_name)
			for scroll in spearhead.warscrolls:
				if scroll.id == parts[1]:
					return _named(scroll.abilities, ability_name)
	return null


func _locate_in_faction(space: String, parts: PackedStringArray) -> Ability:
	var faction_name := FactionCatalog.name_for_id(space)
	if faction_name.is_empty():
		return null
	var faction := FactionCatalog.load_faction(faction_name)
	var ability_name := "/".join(parts.slice(1))
	match parts[0]:
		"trait":
			var found := _named(faction.battle_traits, ability_name)
			for formation in faction.battle_formations:
				found = found if found else _named(formation.abilities, ability_name)
			return found
		"enhancement":
			for table in faction.enhancement_tables:
				var found := _named(table.entries, ability_name)
				if found:
					return found
		"lore":
			for lore in faction.lores:
				var found := _named(lore.entries, ability_name)
				if found:
					return found
		"warscroll":
			var scroll := faction.get_warscroll(parts[1])
			return _named(scroll.abilities, "/".join(parts.slice(2))) if scroll else null
	return null


func test_each_entry_is_for_an_ability_that_exists() -> void:
	var missing: Array[String] = []
	for key: String in _entries():
		if _is_ability_key(key) and _locate(key) == null:
			missing.append(key)
	assert_eq(missing, [] as Array[String], "Entries whose ability isn't in the rules data")


func test_each_entrys_hash_matches_its_abilitys_text() -> void:
	var stale: Array[String] = []
	var entries := _entries()
	for key: String in entries:
		if not _is_ability_key(key):
			continue
		var ability := _locate(key)
		if ability != null and entries[key].get("hash", "") != EffectCatalog.hash_of(ability):
			stale.append(key)
	assert_eq(stale, [] as Array[String], "Stale entries: run tools/effects/stamp_hashes.py after checking them")


func test_the_hash_the_python_tool_stamps_is_the_one_the_engine_checks() -> void:
	var ability := Ability.new()
	ability.timing = "Your Hero Phase"
	ability.declare = "Pick a unit."
	ability.effect = "It heals."
	ability.text = ""
	var expected := ("Your Hero Phase\nPick a unit.\nIt heals.\n").md5_text().substr(0, 8)
	assert_eq(EffectCatalog.hash_of(ability), expected)


# What the entries use

## Every dictionary in [param node], at any depth, that has [param key], as a [code]key's value[/code].
func _collect(node: Variant, key: String, into: Array) -> void:
	if node is Dictionary:
		for each: Variant in node:
			if each == key:
				into.append(node[each])
			_collect(node[each], key, into)
	elif node is Array:
		for each: Variant in node:
			_collect(each, key, into)


func test_every_op_is_one_the_engine_has() -> void:
	var ops: Array = []
	_collect(_entries(), "op", ops)
	assert_gt(ops.size(), 10, "The data uses ops")
	var unknown := {}
	for op: String in ops:
		if Effect._build(op) == null:
			unknown[op] = true
	assert_eq(unknown.keys(), [], "Ops the engine doesn't know")


func test_every_condition_is_one_the_engine_knows() -> void:
	var lists: Array = []
	_collect(_entries(), "when", lists)
	assert_gt(lists.size(), 10, "The data uses conditions")
	var game := RulesKit.game([RulesKit.unit("Mine", 1, Vector2(5, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(25, 15))] as Array[BattleUnit])
	var context := RuleContext.of_unit(game, game.battle.player.units[0])
	var unknown := {}
	for list: Array in lists:
		for condition: Variant in list:
			var before := get_errors().size()
			Predicates.holds(condition, context)
			var errors := get_errors()
			for index in range(before, errors.size()):
				unknown[str(condition)] = true
				errors[index].handled = true
	game.dispose()
	assert_eq(unknown.keys(), [], "Conditions the engine doesn't know")


func test_every_hook_is_one_the_engine_has() -> void:
	var hooks := {}
	for each: Variant in _hook_names():
		hooks[each] = true
	assert_gt(hooks.size(), 3, "The data uses hooks")
	var game := RulesKit.game([RulesKit.unit("Mine", 1, Vector2(5, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(25, 15))] as Array[BattleUnit])
	var unknown := {}
	for hook_name: String in hooks:
		var before := get_errors().size()
		# With nobody to act on, a hook that exists does nothing.
		EffectHooks.run(hook_name, Action.new(), game, {})
		var errors := get_errors()
		for index in range(before, errors.size()):
			unknown[hook_name] = true
			errors[index].handled = true
	game.dispose()
	assert_eq(unknown.keys(), [], "Hooks the engine doesn't know")


func _hook_names() -> Array:
	var result: Array = []
	var stack: Array = [_entries()]
	while not stack.is_empty():
		var node: Variant = stack.pop_back()
		if node is Dictionary:
			if node.get("op") == "hook":
				result.append(node.get("name", ""))
			stack.append_array(node.values())
		elif node is Array:
			stack.append_array(node)
	return result


func test_every_duration_is_one_a_modifier_knows() -> void:
	var durations: Array = []
	_collect(_entries(), "until", durations)
	var unknown := {}
	for duration: String in durations:
		if not Modifier.UNTIL_NAMES.has(duration):
			unknown[duration] = true
	assert_eq(unknown.keys(), [], "Durations Modifier doesn't read")


func test_every_kind_of_move_is_one_the_engine_has() -> void:
	var kinds: Array = []
	_collect(_entries(), "kind", kinds)
	var unknown := {}
	for kind: String in kinds:
		if not MoveEffect.KINDS.has(kind):
			unknown[kind] = true
	assert_eq(unknown.keys(), [], "Kinds of move MoveEffect doesn't have")
