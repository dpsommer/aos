"""Assemble the game's faction JSON from parsed Wahapedia output.

Usage: python -I build.py warscrolls_raw.json faction_raw.json <out dir> <id> <name> <grand alliance>
"""
import sys, json, re, os

raw_ws, raw_f, out_dir, faction_id, faction_name, alliance = sys.argv[1:7]
ws_list = json.load(open(raw_ws)); fac = json.load(open(raw_f))

def ability(a):
    out = {"name": a["name"], "category": a.get("category", ""), "timing": a.get("timing", "")}
    for k in ("frequency", "declare", "effect", "text"):
        if a.get(k): out[k] = a[k]
    if a.get("keywords"): out["keywords"] = a["keywords"]
    if a.get("options"): out["options"] = a["options"]
    if a.get("points"): out["points"] = a["points"]
    if a.get("source"): out["source"] = a["source"]
    return out

def move_inches(m):
    m = (m or "").strip()
    mm = re.match(r"(\d+)", m)
    return int(mm.group(1)) if mm else 0

def warscroll(w, with_profile=True):
    out = {"id": w["id"] or re.sub(r"[^a-z0-9]+", "_", w["name"].lower().replace("’", "")).strip("_"),
           "name": w["name"]}
    if w.get("source"): out["source"] = w["source"]
    if w.get("legends"): out["legends"] = True
    if with_profile:
        out["points"] = w.get("points") or 0
        out["unit_size"] = w.get("unit_size") or 1
        if w.get("base_size"): out["base_size"] = w["base_size"]
        out["can_reinforce"] = bool(w.get("can_reinforce"))
        if w.get("regiment_options"): out["regiment_options"] = w["regiment_options"]
        if w.get("notes"): out["notes"] = w["notes"]
    out["move"] = move_inches(w.get("move"))
    out["health"] = w.get("health", 0); out["save"] = w.get("save", 0); out["control"] = w.get("control", 0)
    if w.get("ward"): out["ward"] = w["ward"]
    out["ranged_weapons"] = w["ranged_weapons"]; out["melee_weapons"] = w["melee_weapons"]
    out["abilities"] = [ability(a) for a in w["abilities"]]
    out["keywords"] = w["keywords"]
    if w.get("composition"): out["composition"] = w["composition"]
    return out

def table(t):
    out = {"name": t["name"]}
    if t.get("group"): out["group"] = t["group"]
    if t.get("source"): out["source"] = t["source"]
    if t.get("kind"): out["kind"] = t["kind"]
    out["entries"] = [ability(e) for e in t["entries"]]
    return out

f = fac["faction"]
faction = {
    "id": faction_id, "name": faction_name, "grand_alliance": alliance,
    "battle_traits": [ability(a) for a in f["battle_traits"]],
    "battle_formations": [{"name": b["name"], "points": b["points"], "abilities": [ability(a) for a in b["abilities"]]} for b in f["battle_formations"]],
    "enhancement_tables": [table(t) for t in f["enhancement_tables"]],
    "lores": [],
}

aors = []
for a in fac["armies_of_renown"]:
    o = {"name": a["name"]}
    if a.get("source"): o["source"] = a["source"]
    o["text"] = a["text"]
    o["battle_traits"] = [ability(x) for x in a["battle_traits"]]
    o["enhancement_tables"] = [table(t) for t in a["enhancement_tables"]]
    o["lores"] = [table(t) for t in a["lores"]]
    aors.append(o)

spearheads = []
for s in fac["spearheads"]:
    army = " ".join(c for row in s["army"] for c in row)
    m = re.search(r"General\s+(.+?)\s+Units\s+(.+)$", army)
    general, units = m.group(1), []
    for c, n in re.findall(r"(\d+)\s+(.+?)(?=\s+\d+\s+|$)", m.group(2)):
        u = {"count": int(c), "name": n.strip()}
        mm = re.match(r"(.+?)\s*\((.+)\)$", u["name"])
        if mm: u["name"], u["notes"] = mm.group(1), mm.group(2)
        units.append(u)
    text = s["army_text"].split("This Spearhead army consists")[0].strip()
    spearheads.append({
        "name": s["name"], "text": text, "general": general, "units": units,
        "battle_traits": [ability(x) for x in s["battle_traits"]],
        "regiment_abilities": [ability(x) for x in s["regiment_abilities"]],
        "enhancements": [ability(x) for x in s["enhancements"]],
        "warscrolls": [warscroll(dict(w, id=""), with_profile=False) for w in s["warscrolls"]],
    })

ptg = [{"name": p["name"], "text": p["text"], **({"warscrolls": [warscroll(dict(w, id=""), with_profile=False) for w in p["warscrolls"]]} if p["warscrolls"] else {})} for p in fac["path_to_glory"]]

def tidy(o):
    """Normalise spacing left over from inline tags inside quotes."""
    if isinstance(o, str):
        o = re.sub(r"‘\s+", "‘", o)
        o = re.sub(r"\s+’(?![A-Za-z])", "’", o)
        return o
    if isinstance(o, list): return [tidy(x) for x in o]
    if isinstance(o, dict): return {k: tidy(v) for k, v in o.items()}
    return o

os.makedirs(out_dir, exist_ok=True)
def dump(name, obj):
    with open(os.path.join(out_dir, name), "w", encoding="utf-8") as fh:
        json.dump(tidy(obj), fh, indent="\t", ensure_ascii=False); fh.write("\n")
dump("faction.json", faction)
dump("warscrolls.json", {"warscrolls": [warscroll(w) for w in ws_list]})
dump("armies_of_renown.json", {"armies_of_renown": aors})
dump("spearhead.json", {"spearheads": spearheads})
dump("path_to_glory.json", {"sections": ptg})
