"""Canonical shape of the game's faction JSON (see docs/technical/faction-data.md).

Each function takes a loosely built dict and returns it with the schema's key order,
empty optional fields dropped and defaults filled in, so output diffs stay small.
"""
import re


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("’", "").replace("'", "")).strip("_")


def ability(a):
    out = {"name": a["name"], "category": a.get("category", ""), "timing": a.get("timing", "")}
    for k in ("frequency", "declare", "effect", "text", "casting_value", "chanting_value",
              "keywords", "options", "points", "source"):
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
    if with_profile:
        out["points"] = w.get("points") or 0
        out["unit_size"] = w.get("unit_size") or 1
        if w.get("base_size"):
            out["base_size"] = w["base_size"]
        out["can_reinforce"] = bool(w.get("can_reinforce"))
        if w.get("regiment_options"):
            out["regiment_options"] = w["regiment_options"]
        if w.get("notes"):
            out["notes"] = w["notes"]
    for k in ("move", "health", "save", "control"):
        out[k] = w.get(k, 0)
    if w.get("ward"):
        out["ward"] = w["ward"]
    out["ranged_weapons"] = [weapon(x) for x in w.get("ranged_weapons", [])]
    out["melee_weapons"] = [weapon(x) for x in w.get("melee_weapons", [])]
    out["abilities"] = [ability(a) for a in w.get("abilities", [])]
    out["keywords"] = w.get("keywords", [])
    if w.get("composition"):
        out["composition"] = w["composition"]
    return out


def table(t):
    """An enhancement table or a lore."""
    out = {"name": t["name"]}
    for k in ("group", "source", "kind", "points"):
        if t.get(k):
            out[k] = t[k]
    out["entries"] = [ability(e) for e in t["entries"]]
    return out


def faction(f):
    return {
        "id": f["id"], "name": f["name"], "grand_alliance": f["grand_alliance"],
        "battle_traits": [ability(a) for a in f["battle_traits"]],
        "battle_formations": [{"name": b["name"], "points": b.get("points", 0),
                               "abilities": [ability(a) for a in b["abilities"]]} for b in f["battle_formations"]],
        "enhancement_tables": [table(t) for t in f["enhancement_tables"]],
        "lores": [table(t) for t in f["lores"]],
    }


def army_of_renown(a):
    out = {"name": a["name"]}
    if a.get("source"):
        out["source"] = a["source"]
    out["text"] = a.get("text", "")
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
    """Normalise spacing left over from inline tags inside quotes in Wahapedia text."""
    if isinstance(o, str):
        o = re.sub(r"‘\s+", "‘", o)
        return re.sub(r"\s+’(?![A-Za-z])", "’", o)
    if isinstance(o, list):
        return [tidy(x) for x in o]
    if isinstance(o, dict):
        return {k: tidy(v) for k, v in o.items()}
    return o
