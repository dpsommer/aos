"""Canonical shape of the game's faction JSON (see docs/technical/faction-data.md).

Each function takes a loosely built dict and returns it with the schema's key order,
empty optional fields dropped and defaults filled in, so output diffs stay small.
"""
import base_size
import re

# The comma can come before "(Army)" as well as after it (Wahapedia's "Once Per Battle, (Army) Your
# Movement Phase" for the Bad Moon Madmob's 'The Hand of Gork').
FREQUENCY = re.compile(r"^(Once Per (?:Battle Round|Battle|Turn|Phase))(?:,?\s*(\((?:Army|Army, Each Player)\)))?,?\s*(.*)$", re.I)


def split_frequency(timing):
    """Splits "Once Per Turn (Army), Any Combat Phase" into its frequency and timing. Catalogues
    sometimes write "Once per" or "(army)", so the frequency is title-cased."""
    m = FREQUENCY.match(timing)
    if not m:
        return "", timing
    return " ".join(g for g in m.group(1, 2) if g).title(), m.group(3)


def move(value):
    """A Move characteristic without its inch mark: "6", or dice such as "D6+3" for units that roll
    their move. "0" for units that can't move, which the sources show as "-" or leave out."""
    m = re.fullmatch(r"\s*(\d*D?\d+(?:\+\d+)?)\s*[\"”]?\s*", value or "", re.I)
    return m.group(1).upper() if m else "0"


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("’", "").replace("'", "")).strip("_")


def ability_type(a):
    """"passive", "spell", "prayer", "command" or "active", from the ability's own fields rather than
    BSData's profile type, which mislabels a few (Ironjawz's passive 'Tireless Warmaker' is Activated)."""
    keywords = a.get("keywords") or []
    if a.get("timing") == "Passive":
        return "passive"
    if a.get("casting_value") or "SPELL" in keywords:
        return "spell"
    if a.get("chanting_value") or "PRAYER" in keywords:
        return "prayer"
    if a.get("command_points"):
        return "command"
    return "active"


def ability(a):
    out = {"name": a["name"], "type": ability_type(a), "category": a.get("category", ""), "timing": a.get("timing", "")}
    for k in ("colour", "frequency", "declare", "used_by", "effect", "text", "casting_value", "chanting_value",
              "keywords", "options", "points", "command_points", "source", "summons"):
        if a.get(k):
            out[k] = a[k]
    return out


def weapon(w):
    out = {k: w[k] for k in ("name", "range", "attacks", "hit", "wound", "rend", "damage")}
    if w.get("abilities"):
        out["abilities"] = w["abilities"]
    return out


def warscroll(w, with_profile=True):
    """Spearhead and Path to Glory warscrolls have no battle profile."""
    out = {"id": w.get("id") or slug(w["name"]), "name": w["name"]}
    if w.get("source"):
        out["source"] = w["source"]
    if w.get("legends"):
        out["legends"] = True
    if w.get("army_of_renown"):
        out["army_of_renown"] = w["army_of_renown"]
    if with_profile:
        out["points"] = w.get("points") or 0
        out["unit_size"] = w.get("unit_size") or 1
        base = base_size.parse(w.get("base_size"))
        if base:
            out["base_size"] = base
        out["can_reinforce"] = bool(w.get("can_reinforce"))
        if w.get("regiment_options"):
            out["regiment_options"] = w["regiment_options"]
        if w.get("notes"):
            out["notes"] = w["notes"]
    out["move"] = w.get("move", "0")
    for k in ("health", "save", "control"):
        out[k] = w.get(k, 0)
    if w.get("ward"):
        out["ward"] = w["ward"]
    if w.get("banishment"):
        out["banishment"] = w["banishment"]
    out["ranged_weapons"] = [weapon(x) for x in w.get("ranged_weapons", [])]
    out["melee_weapons"] = [weapon(x) for x in w.get("melee_weapons", [])]
    out["abilities"] = [ability(a) for a in w.get("abilities", [])]
    out["keywords"] = w.get("keywords", [])
    if w.get("composition"):
        out["composition"] = w["composition"]
    if w.get("weapon_options"):
        out["weapon_options"] = w["weapon_options"]
    return out


def table(t, points=False):
    """An enhancement table or a lore. `points` writes them even when 0, as faction lores have."""
    out = {"name": t["name"]}
    for k in ("group", "source", "kind"):
        if t.get(k):
            out[k] = t[k]
    if points or t.get("points"):
        out["points"] = t.get("points") or 0
    if t.get("units"):
        out["units"] = t["units"]
    if t.get("max", 1) > 1:
        out["max"] = t["max"]
    out["entries"] = [ability(e) for e in t["entries"]]
    return out


def faction(f):
    out = {"id": f["id"], "name": f["name"], "grand_alliance": f["grand_alliance"]}
    if f.get("legends"):
        out["legends"] = True
    return out | {
        "battle_traits": [ability(a) for a in f["battle_traits"]],
        "battle_formations": [{"name": b["name"], "points": b.get("points", 0),
                               "abilities": [ability(a) for a in b["abilities"]]} for b in f["battle_formations"]],
        "enhancement_tables": [table(t) for t in f["enhancement_tables"]],
        "lores": [table(t, points=True) for t in f["lores"]],
    }


# "All units in your army gain the MAGNATE’S CREW keyword."
AOR_KEYWORD = re.compile(r"units in your army gain the (.+?) keyword")


def army_of_renown(a):
    out = {"name": a["name"]}
    if a.get("source"):
        out["source"] = a["source"]
    if a.get("legends"):
        out["legends"] = True
    # The keyword all of the army's units gain, unless an override gives it.
    found = AOR_KEYWORD.search(a.get("text", ""))
    keyword = a.get("keyword") or (found.group(1) if found else "")
    if keyword:
        out["keyword"] = keyword
    out["text"] = a.get("text", "")
    if a.get("roster"):
        out["roster"] = a["roster"]
    out["battle_traits"] = [ability(x) for x in a["battle_traits"]]
    out["enhancement_tables"] = [table(t) for t in a["enhancement_tables"]]
    out["lores"] = [table(t) for t in a["lores"]]
    return out


def spearhead(s):
    return {
        "name": s["name"], "text": s.get("text", ""), "general": s["general"], "units": s["units"],
        "battle_traits": [ability(x) for x in s["battle_traits"]],
        "regiment_abilities": [ability(x) for x in s["regiment_abilities"]],
        "enhancements": [ability(x) for x in s["enhancements"]],
        "warscrolls": [warscroll(w, with_profile=False) for w in s["warscrolls"]],
    }


def rules_section(p):
    out = {"name": p["name"], "text": p["text"]}
    if p.get("warscrolls"):
        out["warscrolls"] = [warscroll(w, with_profile=False) for w in p["warscrolls"]]
    return out


def tidy(o):
    """Normalise spacing left over from inline tags inside quotes in Wahapedia text, and its
    fraction-slash halves ("1⁄2") to the "½" BSData uses."""
    if isinstance(o, str):
        o = o.replace("1⁄2", "½")
        o = re.sub(r"‘\s+", "‘", o)
        return re.sub(r"\s+’(?![A-Za-z])", "’", o)
    if isinstance(o, list):
        return [tidy(x) for x in o]
    if isinstance(o, dict):
        return {k: tidy(v) for k, v in o.items()}
    return o
