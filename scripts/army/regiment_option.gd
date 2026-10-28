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
## Whether a Hero with [member keywords] can fill the option, not only one it names (see
## [member RosterRegimentOptions.heroes]).
var heroes: bool


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


## Whether [param warscroll] can fill this option, with the keywords it [param gained] from the
## Army of Renown. A Hero only fills an option naming it or its role, as Heroes join regiments in
## place of a non-Hero unit only where their profile says so, unless the option allows [member heroes].
func matches(warscroll: Warscroll, gained := PackedStringArray()) -> bool:
	if warscroll.has_keyword("HERO") and (_names(warscroll, subject) or role_of(warscroll).nocasecmp_to(subject) == 0):
		return true
	if warscroll.has_keyword("HERO") and not (heroes and unit.is_empty()):
		return false
	for keyword in not_keywords:
		if _has(warscroll, keyword, gained):
			return false
	if not unit.is_empty():
		return _names(warscroll, unit) or _has(warscroll, unit.to_upper(), gained)
	for run in keywords:
		if not _has_run(warscroll, run, gained):
			return false
	return true


static func _has(warscroll: Warscroll, keyword: String, gained: PackedStringArray) -> bool:
	return warscroll.has_keyword(keyword) or keyword in gained


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
static func _has_run(warscroll: Warscroll, run: String, gained := PackedStringArray()) -> bool:
	return splits_into_keywords(run.split(" "), func(keyword: String) -> bool: return _has(warscroll, keyword, gained))


## Whether [param words] split into keywords that [param has] each one, e.g. "SCIONS OF NULAHMIA
## HERO" into "SCIONS OF NULAHMIA" and "HERO", trying the longest runs first.
static func splits_into_keywords(words: PackedStringArray, has: Callable) -> bool:
	if words.is_empty():
		return true
	for end in range(words.size(), 0, -1):
		if has.call(" ".join(words.slice(0, end))) and splits_into_keywords(words.slice(end), has):
			return true
	return false
