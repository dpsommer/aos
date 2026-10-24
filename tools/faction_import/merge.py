"""Combine BSData (primary) with Wahapedia (supplements) and report where they disagree.

BSData values win. Wahapedia supplies what BSData lacks: regiment options, notes and
unit composition on warscrolls, Army of Renown text, Spearheads and Path to Glory. Items
only one source has are kept and reported.
"""
import difflib, re

import schema

# Commentary Wahapedia's parser keeps as an option; it isn't a rule, so it isn't compared.
COMMENTARY = {"designersnote"}


def norm(name):
    """Matching key for names that differ in case or punctuation between the sources."""
    return re.sub(r"[^a-z0-9]+", "", (name or "").lower().replace("’", "'"))


def norm_text(text):
    text = re.sub(r"(^|\n)\s*•\s*", r"\1", text or "")
    text = text.lower().replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    text = text.replace("–", "-").replace("—", "-").replace("‑", "-")
    text = re.sub(r"\s*[×x]\s*(?=\d)", "x", text)
    text = re.sub(r"\s+", " ", text)
    return re.sub(r"\s*([,.:;!?()'\"-])\s*", r"\1", text).strip()


def wahapedia_warscroll(raw):
    """A Wahapedia warscroll in the schema's shape (move without its inch mark). Wahapedia shows a
    manifestation's banishment value where other warscrolls show Control."""
    w = dict(raw)
    w["move"] = schema.move(raw.get("move"))
    if "MANIFESTATION" in w.get("keywords", []):
        w["banishment"], w["control"] = w.get("control", 0), 0
    return w


def order_like(items, reference, key=lambda x: x["name"]):
    """Sort items into the order their names appear in reference (book order on Wahapedia).
    Items without a match keep their relative order at the end."""
    rank = {norm(n): i for i, n in enumerate(reference)}
    return sorted(items, key=lambda x: rank.get(norm(key(x)), len(rank)))


def pair(report, where, bs_items, wh_items, key=lambda x: x["name"]):
    """Match BSData items to Wahapedia items by name, then by similar name for misspellings
    such as "Hobgrotz" for "Hobgrot". Returns [(bs, wh or None)] and unmatched Wahapedia items."""
    wh_left = list(wh_items)
    pairs = []
    for bs in bs_items:
        wh = next((w for w in wh_left if norm(key(w)) == norm(key(bs))), None)
        if wh is not None:
            wh_left.remove(wh)
        pairs.append([bs, wh])
    def words(x):
        return sorted(re.findall(r"[a-z0-9]+", key(x).lower().replace("’", "'")))
    for p in pairs:
        if p[1] is None:
            # Same words in another order: "Bloodthirster, Wrath of Khorne" / "Wrath of Khorne Bloodthirster".
            close = [w for w in wh_left if words(w) == words(p[0])] or \
                [w for w in wh_left if difflib.SequenceMatcher(None, norm(key(p[0])), norm(key(w))).ratio() >= 0.85]
            if len(close) == 1:
                p[1] = close[0]
                wh_left.remove(close[0])
                report.lines.append("%s: matched %r to Wahapedia's %r by similar name" % (where, key(p[0]), key(close[0])))
    return pairs, wh_left


class Report:
    def __init__(self):
        self.lines = []

    def differ(self, where, field, bsdata, wahapedia):
        self.lines.append("%s: %s differs (BSData %r, Wahapedia %r)" % (where, field, bsdata, wahapedia))

    def only(self, source, kind, name):
        self.lines.append("%s only in %s: %s" % (kind, source, name))


def compare_ability(report, where, bs, wh):
    for field in ("timing", "frequency", "casting_value", "chanting_value", "points"):
        if (bs.get(field) or "") != (wh.get(field) or "") and (bs.get(field) or wh.get(field)):
            if field == "timing" and norm_text(bs.get(field)).rstrip(".") == norm_text(wh.get(field)).rstrip("."):
                continue
            report.differ(where + " > " + bs["name"], field, bs.get(field), wh.get(field))
    for field in ("declare", "effect"):
        if norm_text(bs.get(field)) != norm_text(wh.get(field)):
            report.differ(where + " > " + bs["name"], field, bs.get(field), wh.get(field))
    bs_options = {norm(o["name"]): o["text"] for o in bs.get("options", []) if norm(o["name"]) not in COMMENTARY}
    wh_options = {norm(o["name"]): o["text"] for o in wh.get("options", []) if norm(o["name"]) not in COMMENTARY}
    if set(bs_options) != set(wh_options) or any(norm_text(bs_options[k]) != norm_text(wh_options[k]) for k in bs_options):
        report.differ(where + " > " + bs["name"], "options", bs.get("options"), wh.get("options"))


def compare_abilities(report, where, bs_list, wh_list):
    pairs, wh_left = pair(report, where, bs_list, wh_list)
    for a, wh in pairs:
        if wh is not None:
            compare_ability(report, where, a, wh)
        else:
            report.only("BSData", "ability", where + " > " + a["name"])
    for a in wh_left:
        report.only("Wahapedia", "ability", where + " > " + a["name"])


def compare_warscroll(report, bs, wh):
    where = "warscroll " + bs["name"] + (" (%s)" % bs["source"] if bs.get("source") else "")
    for field in ("points", "unit_size", "move", "health", "save", "control", "ward", "banishment", "can_reinforce", "legends"):
        if (bs.get(field) or 0) != (wh.get(field) or 0):
            report.differ(where, field, bs.get(field), wh.get(field))
    if norm_text(bs.get("base_size")) != norm_text(wh.get("base_size")):
        report.differ(where, "base_size", bs.get("base_size"), wh.get("base_size"))
    for kind in ("ranged_weapons", "melee_weapons"):
        pairs, wh_left = pair(report, where, bs.get(kind, []), wh.get(kind, []))
        for x, y in pairs:
            if y is None:
                report.only("BSData", "weapon", where + " > " + x["name"])
                continue
            for field in ("range", "attacks", "hit", "wound", "rend", "damage"):
                if norm_text(str(x.get(field))) != norm_text(str(y.get(field))):
                    report.differ(where + " > " + x["name"], field, x.get(field), y.get(field))
            if {norm(a) for a in x.get("abilities", [])} != {norm(a) for a in y.get("abilities", [])}:
                report.differ(where + " > " + x["name"], "abilities", x.get("abilities"), y.get("abilities"))
        for y in wh_left:
            report.only("Wahapedia", "weapon", where + " > " + y["name"])
    compare_abilities(report, where, bs.get("abilities", []), wh.get("abilities", []))
    bs_kw, wh_kw = {norm(k) for k in bs.get("keywords", [])}, {norm(k) for k in wh.get("keywords", [])}
    if bs_kw != wh_kw:
        report.differ(where, "keywords", sorted(bs.get("keywords", [])), sorted(wh.get("keywords", [])))


def merge_warscrolls(report, bs_list, wh_raw):
    wh_list = [wahapedia_warscroll(w) for w in wh_raw]
    key = lambda w: w["name"] + " " + w.get("source", "")
    pairs, wh_left = pair(report, "warscrolls", bs_list, wh_list, key)
    merged = []
    for bs, wh in pairs:
        if wh is None:
            report.only("BSData", "warscroll", bs["name"])
            merged.append(bs)
            continue
        compare_warscroll(report, bs, wh)
        out = dict(bs)
        for field in ("regiment_options", "notes", "composition"):
            if wh.get(field):
                out[field] = wh[field]
        merged.append(out)
    for wh in wh_left:
        report.only("Wahapedia", "warscroll", wh["name"])
        merged.append(dict(wh, id=schema.slug(((wh["source"] + " ") if wh.get("source", "").startswith("Scourge of") else "") + wh["name"])))
    return sorted(merged, key=lambda w: (norm(w["name"]), w.get("source", "")))


def merge_tables(report, where, bs_tables, wh_tables):
    """Enhancement tables or lores: BSData entries in Wahapedia's order, each entry compared."""
    wh_entries = [e for t in wh_tables for e in t["entries"]]
    bs_entries = [e for t in bs_tables for e in t["entries"]]
    pairs, wh_left = pair(report, where, bs_entries, wh_entries)
    # Book position of each BSData entry, taken from its Wahapedia match.
    rank = {}
    for bs, wh in pairs:
        if wh is None:
            report.only("BSData", "enhancement or spell", where + " > " + bs["name"])
        else:
            compare_ability(report, where, bs, wh)
            rank[id(bs)] = wh_entries.index(wh)
    for wh in wh_left:
        report.only("Wahapedia", "enhancement or spell", where + " > " + wh["name"])
    last = len(wh_entries)
    for t in bs_tables:
        t["entries"].sort(key=lambda e: rank.get(id(e), last))
    return sorted(bs_tables, key=lambda t: min((rank.get(id(e), last) for e in t["entries"]), default=last))


def merge_faction(report, bs, wh):
    out = dict(bs)
    compare_abilities(report, "battle traits", bs["battle_traits"], wh["battle_traits"])
    out["battle_traits"] = order_like(bs["battle_traits"], [a["name"] for a in wh["battle_traits"]])
    wh_forms = {norm(f["name"]): f for f in wh["battle_formations"]}
    for f in bs["battle_formations"]:
        w = wh_forms.pop(norm(f["name"]), None)
        if w is None:
            report.only("BSData", "battle formation", f["name"])
            continue
        if f["points"] != w["points"]:
            report.differ("battle formation " + f["name"], "points", f["points"], w["points"])
        compare_abilities(report, "battle formation " + f["name"], f["abilities"], w["abilities"])
    for w in wh_forms.values():
        report.only("Wahapedia", "battle formation", w["name"])
    out["battle_formations"] = order_like(bs["battle_formations"], [f["name"] for f in wh["battle_formations"]])
    out["enhancement_tables"] = merge_tables(report, "enhancements", bs["enhancement_tables"], wh["enhancement_tables"])
    out["lores"] = merge_tables(report, "lores", bs["lores"], wh["lores"])
    return out


def merge_armies(report, bs_list, wh_list):
    wh_by = {norm(a["name"]): a for a in wh_list}
    merged = []
    for bs in bs_list:
        wh = wh_by.pop(norm(bs["name"]), None)
        out = {k: v for k, v in bs.items() if k != "roster"}
        if wh is None:
            report.only("BSData", "army of renown", bs["name"])
            out["text"] = "Roster options:\n" + "\n".join(bs["roster"])
        else:
            out["text"] = wh["text"]
            if wh.get("source"):
                out["source"] = wh["source"]
            where = "army of renown " + bs["name"]
            compare_abilities(report, where, bs["battle_traits"], wh["battle_traits"])
            out["battle_traits"] = order_like(bs["battle_traits"], [a["name"] for a in wh["battle_traits"]])
            out["enhancement_tables"] = merge_tables(report, where, bs["enhancement_tables"], wh["enhancement_tables"])
            out["lores"] = merge_tables(report, where, bs["lores"], wh["lores"])
        merged.append(out)
    for wh in wh_by.values():
        report.only("Wahapedia", "army of renown", wh["name"])
    return merged


def resolve(name, names):
    """Match a Spearhead army list entry to a warscroll name. Lists sometimes shorten names,
    e.g. "Dominator Engine" for "Dominator Engine with Immolation Cannons", or reorder them,
    e.g. "Freeguild Command Corps Whisperblade" for "Whisperblade, Freeguild Command Corps", or
    use the singular, e.g. "Sunsteala Wheela" for "Sunsteala Wheelas", or misspell them, e.g.
    "lronguts" for "Ironguts"."""
    if name in names:
        return name
    if name + "s" in names:
        return name + "s"
    matches = [n for n in names if n.startswith(name + " ")]
    if not matches:
        words = sorted(re.findall(r"[\w'’-]+", name.lower()))
        matches = [n for n in names if sorted(re.findall(r"[\w'’-]+", n.lower())) == words]
    if not matches:
        matches = [n for n in names if difflib.SequenceMatcher(None, norm(name), norm(n)).ratio() >= 0.85]
    if len(matches) != 1:
        raise SystemExit("cannot resolve Spearhead unit %r among %s" % (name, names))
    return matches[0]


def spearheads(wh_list, bs_names):
    """Spearheads from Wahapedia, with warscroll names normalised to BSData's spelling."""
    canonical = {norm(n): n for n in bs_names}
    out = []
    for s in wh_list:
        warscrolls = [dict(wahapedia_warscroll(w), id="", name=canonical.get(norm(w["name"]), w["name"])) for w in s["warscrolls"]]
        names = [w["name"] for w in warscrolls]
        army = "\n".join(c for row in s["army"] for c in row)
        m = re.search(r"General\s+(.+?)\s+Units\s+(.+)$", army, re.S)
        # The general can carry token notes, e.g. "Jorvan Kreel (Thexa, the ash panther, is a token)"
        # or "Mantrappers with 3 Gnoblar tokens, ...", and a designer's note, which joins the text.
        general, _, note = m.group(1).partition("\nDesigner’s Note:")
        general = re.sub(r"(\s*\([^()]*\))+$|\s+with \d+ .+$", "", general)
        general = resolve(canonical.get(norm(general), general), names)
        units = []
        # Entries start at a new cell or at a count, except a named character listed without one. A
        # count after "with" is part of the entry ("5 Freeguild Fusiliers with 1 Blackpowder Squire token").
        for entry in re.split(r"\s*\n\s*|(?<!\bwith)\s+(?=\d+\s)", m.group(2)):
            count, name = re.match(r"(?:(\d+)\s+)?(.+)$", entry).groups()
            unit = {"count": int(count or 1), "name": name.strip()}
            mm = re.match(r"(.+?)\s*\((.+)\)$", unit["name"]) or \
                re.match(r"(.+?)\s+(with \d+ .+)$", unit["name"])
            if mm:
                unit["name"], unit["notes"] = mm.group(1), mm.group(2)
            unit["name"] = resolve(canonical.get(norm(unit["name"]), unit["name"]), names)
            units.append(unit)
        text = s["army_text"].split("This Spearhead army consists")[0].strip()
        if note.strip():
            text += "\nDesigner’s Note: " + " ".join(note.split())
        out.append({
            "name": s["name"], "text": text,
            "general": general, "units": units,
            "battle_traits": s["battle_traits"], "regiment_abilities": s["regiment_abilities"],
            "enhancements": s["enhancements"], "warscrolls": warscrolls,
        })
    return out


def path_to_glory(wh_list):
    return [{"name": p["name"], "text": p["text"],
             "warscrolls": [dict(wahapedia_warscroll(w), id="") for w in p["warscrolls"]]} for p in wh_list]
