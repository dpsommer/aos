extends RefCounted
## Helpers for the army builder's UI tests: a small in-code faction, builder set-up and tree walking.
## Preload it: const UIKit := preload("res://test/support/ui_kit.gd")

const Kit := preload("res://test/support/army_kit.gd")
const BuilderScene := preload("res://scenes/ui/forge/builder/army_builder.tscn")


## A faction with a regiment leader ("lead", allows INFANTRY), a non-Hero ("grunt"), a unit the
## leader can't take ("beast"), a Legends unit ("legend"), a Unique Hero ("unique"), a Wizard Hero
## ("wizard") and a faction terrain ("terrain").
static func faction() -> Faction:
	var scrolls: Array[Warscroll] = [
		Kit.hero("lead", PackedStringArray(["Any INFANTRY"])),
		Kit.warscroll("grunt", PackedStringArray(["INFANTRY"])),
		Kit.warscroll("beast", PackedStringArray(["BEAST"])),
		Kit.warscroll("legend", PackedStringArray(["INFANTRY"])),
		Kit.hero("unique", PackedStringArray(["Any INFANTRY"]), PackedStringArray(["UNIQUE"])),
		Kit.hero("wizard", PackedStringArray(["Any INFANTRY"]), PackedStringArray(["WIZARD"])),
		Kit.warscroll("terrain", PackedStringArray(["FACTION TERRAIN"])),
	]
	scrolls[3].legends = true
	return Kit.faction(scrolls)


## An army with one regiment "r1" led by "lead" (uid "u1") followed by the given non-leader
## warscroll ids (uids "u2", "u3"...). The leader is the general.
static func army_with_regiment(member_ids := PackedStringArray()) -> Army:
	var units: Array[ArmyUnit] = [Kit.unit("u1", "lead")]
	for i in member_ids.size():
		units.append(Kit.unit("u%d" % (i + 2), member_ids[i]))
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", units))
	army.general_uid = "u1"
	return army


## An opened ArmyBuilder in [param test]'s tree.
static func builder(test: GutTest, army: Army, faction_data: Faction = null, core: CoreRules = null) -> ArmyBuilder:
	var node: ArmyBuilder = BuilderScene.instantiate()
	test.add_child_autofree(node)
	node.open(army, Kit.catalog(faction_data if faction_data else faction(), core))
	return node


static func find_all(node: Node, matches: Callable) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if matches.call(child):
			result.append(child)
		result.append_array(find_all(child, matches))
	return result


static func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for found in find_all(node, func(n: Node) -> bool: return n is Button and not n is OptionButton):
		result.append(found)
	return result


static func button_texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for button in buttons(node):
		result.append(button.text)
	return result


static func button(node: Node, text: String) -> Button:
	for candidate in buttons(node):
		if candidate.text == text:
			return candidate
	return null


## The control under [param node] with the focus_key meta [param key], visible or not.
static func keyed(node: Node, key: String) -> Control:
	var found := find_all(node, func(n: Node) -> bool: return n.get_meta(&"focus_key", "") == key)
	return found[0] if not found.is_empty() else null


static func label_texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for found in find_all(node, func(n: Node) -> bool: return n is Label):
		result.append((found as Label).text)
	return result


static func labels_with_variation(node: Node, variation: String) -> Array[Label]:
	var result: Array[Label] = []
	for found in find_all(node, func(n: Node) -> bool: return n is Label and n.theme_type_variation == variation):
		result.append(found)
	return result


static func has_label_containing(node: Node, text: String) -> bool:
	return Array(label_texts(node)).any(func(t: String) -> bool: return t.contains(text))
