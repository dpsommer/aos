class_name RegimentOption
extends RefCounted
## One entry in a Hero's regiment options, e.g. "Any WARRIOR CHAMBER", "0-1 Gryph-hounds" or
## "Neave's Companions (required)", parsed from [member Warscroll.regiment_options].

## Unlimited [member max].
const ANY := -1

static var _role_pattern := RegEx.create_from_string("can join an eligible regiment as (?:an? )?([^.]+)")

## The option as written.
var text: String
## How many units the regiment must include matching this option.
var min: int
## How many units the regiment can include matching this option, or [constant ANY].
var max := ANY
## A unit name or role (e.g. "Royal Attendant"), for an option that doesn't name keywords.
var unit: String
## What the option names, without its count: a unit name, a role or keywords. Roles can be written
## in capitals, as "STORMCAST EXEMPLAR" is.
var subject: String
## Runs of keywords a unit must have, e.g. ["WARRIOR CHAMBER"].
var keywords: PackedStringArray
var not_keywords: PackedStringArray


## Parses every option in [param options]. Text listing several required units, such as
## "Singri Brand (required), The Oathsworn Kin (required)", gives one option per unit.
static func parse_all(options: PackedStringArray) -> Array[RegimentOption]:
	var result: Array[RegimentOption] = []
	for option in options:
		var parts := option.split(", ")
		var all_required := parts.size() > 1
		for part in parts:
			all_required = all_required and part.ends_with("(required)")
		for part in (parts if all_required else PackedStringArray([option])):
			result.append(parse(part))
	return result


static func parse(option: String) -> RegimentOption:
	var parsed := RegimentOption.new()
	parsed.text = option
	var rest := option.strip_edges()
	if rest.ends_with("(required)"):
		rest = rest.trim_suffix("(required)").strip_edges()
		parsed.min = 1
		parsed.max = 1
	elif rest.begins_with("Any "):
		rest = rest.trim_prefix("Any ")
	elif rest.begins_with("0-1 "):
		rest = rest.trim_prefix("0-1 ")
		parsed.max = 1
	elif rest.begins_with("1 "):
		rest = rest.trim_prefix("1 ")
		parsed.min = 1
		parsed.max = 1
	for suffix in [" units", " unit"]:
		rest = rest.trim_suffix(suffix)
	parsed.subject = rest

	var words := rest.split(" ", false)
	var named := false
	for word in words:
		if not word.begins_with("non-") and word != word.to_upper():
			named = true
	if named:
		parsed.unit = rest
		return parsed
	var run := PackedStringArray()
	for word in words:
		if word.begins_with("non-"):
			parsed.not_keywords.append(word.trim_prefix("non-"))
			if not run.is_empty():
				parsed.keywords.append(" ".join(run))
				run.clear()
		else:
			run.append(word)
	if not run.is_empty():
		parsed.keywords.append(" ".join(run))
	return parsed


## The role a Hero can join another Hero's regiment as, from its notes, e.g. "STORMCAST EXEMPLAR".
## Empty if it has none.
static func role_of(warscroll: Warscroll) -> String:
	var found := _role_pattern.search(warscroll.notes)
	return found.get_string(1).strip_edges() if found else ""


## Whether [param warscroll] can fill this option. A Hero only fills an option naming it or its
## role, as Heroes join regiments in place of a non-Hero unit only where their profile says so.
func matches(warscroll: Warscroll) -> bool:
	if warscroll.has_keyword("HERO"):
		return _names(warscroll, subject) or role_of(warscroll).nocasecmp_to(subject) == 0
	for keyword in not_keywords:
		if warscroll.has_keyword(keyword):
			return false
	if not unit.is_empty():
		return _names(warscroll, unit) or warscroll.has_keyword(unit.to_upper())
	for run in keywords:
		if not _has_run(warscroll, run):
			return false
	return true


## Scourge of Aqshy and Ghyran warscrolls share their printed version's name, units with a size
## variant are named e.g. "Stormdrake Guard (1 model)", and options can leave out an epithet
## ("Lorai" for "Lorai, Child of the Abyss"); all of these match. Apostrophes are compared
## without regard to style, as options write "Neave’s Companions" for "Neave's Companions".
static func _names(warscroll: Warscroll, unit_name: String) -> bool:
	var full := _plain(warscroll.name)
	var short := _plain(unit_name)
	return full == short or full.begins_with(short + " (") or full.begins_with(short + ", ")


static func _plain(text: String) -> String:
	return text.to_lower().replace("’", "'")


## A run such as "WARRIOR CHAMBER" is one keyword, but "SYLVANETH MONSTER" would be two.
static func _has_run(warscroll: Warscroll, run: String) -> bool:
	if warscroll.has_keyword(run):
		return true
	for word in run.split(" "):
		if not warscroll.has_keyword(word):
			return false
	return true
