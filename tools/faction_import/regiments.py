"""Regiments of Renown from BSData and Wahapedia.

A Regiment of Renown is a pre-built group of units, with abilities of its own, that armies of other
factions can include. BSData splits each one across files: the game system's force entry has its
points and names the faction catalogues that can include it, and "Regiments of Renown.cat" has its
abilities (an upgrade entry) and its units (links shown when the force is picked). A unit the
catalogue defines itself, such as Gotrek Gurnisson, becomes the regiment's own warscroll; the
others are warscrolls of their home faction.

Wahapedia has a page for each regiment under every faction that can include it (they aren't linked
from the faction pages), with its description, the factions, its organisation, points and abilities.

read_regiments() returns BSData's regiments and parse_regiment_page() a Wahapedia page, both in the
raw shape described on each; merge() combines them, BSData first, and reports differences.
"""
import os, re

import bsdata, merge, schema

CATALOGUE = "Regiments of Renown"
PREFIX = "Regiment of Renown: "


def _conditions(el):
    return [c for c in el.iter() if bsdata.tag(c) == "condition"]


def _gated_by(el, force_id):
    return any(c.get("childId") == force_id for c in _conditions(el))


def _faction_names(cats, force, catalogue_id):
    """(factions, armies of renown) a regiment's force entry allows: the catalogues among its
    conditions. An Army of Renown ("Slaves to Darkness - Legion of the First Prince") comes with
    its faction, so it's listed apart, and the "[LEGENDS]" tag on a catalogue is dropped."""
    names = {r.get("id"): r.get("name") for r in cats.docs.values()}
    factions, armies = [], []
    for c in _conditions(force):
        name = names.get(c.get("childId"))
        if c.get("childId") == catalogue_id or name is None:
            continue
        # Shared Army of Renown catalogues are marked with a symbol: "þ The Duardin Ascendant".
        is_army = " - " in name or not re.match(r"[A-Za-z0-9]", name)
        name = bsdata.split_legends_tag(re.sub(r"^[^A-Za-z0-9]+", "", name).split(" - ", 1)[-1])[0]
        group = armies if is_army else factions
        if name not in group:
            group.append(name)
    return factions, armies


def _count(link, force_id):
    """How many of a unit a regiment has: the value the force's modifiers set its minimum to."""
    mins = {c.get("id") for c in bsdata.kids(link, "constraints", "constraint") if c.get("type") == "min"}
    for group in [link] + [g for g in link.iter() if bsdata.tag(g) == "modifierGroup"]:
        if group is not link and not _gated_by(group, force_id):
            continue
        for m in bsdata.kids(group, "modifiers", "modifier"):
            if m.get("type") == "set" and m.get("field") in mins and (group is not link or _gated_by(m, force_id)):
                return int(float(m.get("value")))
    return 1


def _file_of(cats, el):
    for name, root in cats.docs.items():
        if any(x is el for x in root.iter()):
            return name
    return ""


def read_regiments(cats):
    """Every Regiment of Renown in BSData:
    {name, legends, points, publication, factions: [BSData faction names], armies: [names of the
     Armies of Renown it lists, which come with their faction],
     units: [{count, name, library, notes}], abilities, warscrolls}
    where library is the catalogue defining the unit ("Ossiarch Bonereapers - Library.cat") and
    warscrolls holds the units the regiments catalogue defines itself."""
    root = cats.catalogue(CATALOGUE)
    gst = next(r for f, r in cats.docs.items() if f.endswith(".gst"))
    entries = bsdata.kids(root, "sharedSelectionEntries", "selectionEntry")
    links = bsdata.kids(root, "entryLinks", "entryLink")
    files = {}
    out = []
    for force in gst.iter():
        if bsdata.tag(force) != "forceEntry" or not _gated_by(force, root.get("id")):
            continue
        fid = force.get("id")
        name, legends = bsdata.split_legends_tag(force.get("name"))
        factions, armies = _faction_names(cats, force, root.get("id"))
        regiment = {"name": name, "points": bsdata.points(force), "factions": factions, "armies": armies,
                    "units": [], "abilities": [], "warscrolls": [], "publication": ""}
        if legends:
            regiment["legends"] = True
        for e in entries:
            if e.get("type") == "upgrade" and _gated_by(e, fid):
                regiment["abilities"] += bsdata.abilities_in(cats, e)
                regiment["publication"] = cats.publication(e)
        for link in links:
            unit = cats.resolve(link)
            if unit is None or unit.get("type") != "unit" or not _gated_by(link, fid):
                continue
            if unit.get("id") not in files:
                files[unit.get("id")] = _file_of(cats, unit)
            entry = {"count": _count(link, fid), "name": unit.get("name"), "library": files[unit.get("id")]}
            # A link can rename its unit to say which size it is: "Stormdrake Guard (1 model)".
            renamed = bsdata.link_name(link)
            m = re.match(re.escape(unit.get("name")) + r"\s*\((.+)\)$", renamed or "")
            if m:
                entry["notes"] = m.group(1)
            regiment["units"].append(entry)
            if entry["library"] == CATALOGUE + ".cat":
                w = bsdata.warscroll(cats, unit)
                if all(x["id"] != w["id"] for x in regiment["warscrolls"]):
                    regiment["warscrolls"].append(w)
            if not regiment["publication"]:
                regiment["publication"] = cats.publication(unit)
        out.append(regiment)
    return sorted(out, key=lambda r: merge.norm(r["name"]))


# Wahapedia.

def parse_regiment_page(path):
    """A Wahapedia regiment page:
    {name, legends, text, factions: [names], units: [{count, name, faction, notes}], points,
     abilities, warscrolls}
    where text is the organisation's notes, a unit's faction is the Wahapedia slug of the faction
    its link points to and warscrolls are any other sheets on the page. The description is
    background, which the data leaves out."""
    from bs4 import BeautifulSoup
    import wahapedia
    soup = BeautifulSoup(open(path, encoding="utf-8").read(), "lxml")
    for t in soup.select(".tooltip_templates, script, style, .noprint, .picSearch"):
        t.decompose()
    sheets = soup.select(".datasheet")
    sheet = next((s for s in sheets if wahapedia.is_regiment_of_renown(s)), None)
    if sheet is None:
        raise SystemExit("no Regiment of Renown sheet in %s" % path)
    out = {"name": wahapedia.text(sheet.select_one(".wsHeaderIn")), "text": "", "factions": [], "units": [],
           "points": 0, "abilities": [], "warscrolls": []}
    logos = {os.path.basename(i.get("src", "")) for i in sheet.select("img[src*='/expansions/']")}
    if "Legends_logo3.png" in logos:
        out["legends"] = True
    for block in sheet.select(".BreakInsideAvoid"):
        header = block.select_one(".wsAbilityHeader")
        title = wahapedia.text(header).upper() if header is not None else ""
        if title == "INCLUSION":
            out["factions"] = [wahapedia.text(li) for li in block.select("li")]
        elif title == "ORGANISATION":
            # Units are list items ("1 Daemonsmith"), or paragraphs for a single named hero
            # ("Drycha Hamadreth") or a unit with its size ("Nurglings unit with 3 models"), with
            # or without a link to the unit. Any other paragraph is a rule or note for the
            # regiment ("Each unit in this Regiment of Renown has the KRITTOK'S CLAWPACK keyword.",
            # "The Beast-skewer Killbow in this Regiment of Renown has the HERO keyword.", a
            # designer's note), which becomes its text.
            text = []
            for item in block.select("li, p.wsOrgP"):
                if not wahapedia.text(item):
                    continue
                if item.name == "p" and not _is_unit_paragraph(item, wahapedia):
                    text.append(wahapedia.text(item))
                    continue
                unit = _organisation_entry(item, wahapedia)
                if all(u["name"] != unit["name"] for u in out["units"]):
                    out["units"].append(unit)
            out["text"] = "\n".join(text)
    profile = sheet.select_one(".PitchedBattleProfile")
    if profile is not None:
        out["points"] = wahapedia.parse_profile(profile)["points"]
    for blk in sheet.select(".BreakInsideAvoid"):
        if blk.select_one(".abBody") is None or blk.find_parent(class_="abBody"):
            continue
        if any(b.select_one(".abBody") for b in blk.select(".BreakInsideAvoid")):
            continue
        a = wahapedia.parse_ability(blk)
        if not a or a in out["abilities"]:
            continue
        # An errata box after the sheet reprints a corrected ability (Da Kountin' Krew's
        # 'Snatch 'Em Up!'), which replaces the sheet's.
        same = [i for i, x in enumerate(out["abilities"]) if merge.norm(x["name"]) == merge.norm(a["name"])]
        if blk.find_parent(class_="faqErrataColumns") is not None and same:
            out["abilities"][same[0]] = a
        else:
            out["abilities"].append(a)
    out["warscrolls"] = [wahapedia.parse_warscroll(s, "regiment") for s in sheets
                         if not wahapedia.is_regiment_of_renown(s)]
    return out


def _is_unit_paragraph(p, wahapedia):
    """Whether an ORGANISATION paragraph names a unit rather than stating a rule: it is a linked
    unit name followed only by its size, or, unlinked, a name that isn't a sentence."""
    s = wahapedia.text(p)
    link = p.find("a", href=re.compile(r"^/aos4/factions/[^/]+/."))
    if link is not None:
        rest = re.sub(r"^\d+\s+", "", s)[len(wahapedia.text(link)):].strip()
        return rest == "" or re.match(r"(\(|units? with |with )", rest) is not None
    return not s.endswith(".") and ":" not in s


def _organisation_entry(item, wahapedia):
    """{count, name, faction, notes} from an ORGANISATION entry. The count is how many units, or
    sometimes models ("5 Vanari Dawnriders"), and a unit appears once per copy, so counts are
    taken from BSData. The notes say which size or model it is: "1 Man-skewer Boltboyz (unit
    with 3 models)" has notes "3 models", "1 Arkanaut Frigate (the Aelsling)" "the Aelsling"."""
    link = item.find("a")
    # "0-1 Edmark Valoran the Manticore Knight": an optional unit (the Heroes of the Jade Abbey).
    m = re.match(r"(?:(\d+)-)?(\d+)\s+(.+)$", wahapedia.text(item))
    count, rest = (int(m.group(2)), m.group(3)) if m else (1, wahapedia.text(item))
    optional = m.group(1) + "-" + m.group(2) if m and m.group(1) else ""
    # Unlinked, the name ends where its size starts: "Dreadscythe Harridans unit with 10 models".
    name = wahapedia.text(link) if link is not None else re.split(r"\s+(?=\(|units? with |with )", rest)[0]
    # A link can hold the size: "Stormdrake Guard (1 model)".
    m = re.match(r"(.+?)\s*\((.+)\)$", name)
    unit = {"count": count, "name": m.group(1) if m else name}
    # Some entries end in a full stop ("1 Lord-Aquilor.", "1 Chaos Knights unit with 5 models."),
    # which isn't part of the notes.
    notes = m.group(2) if m else re.sub(r"^\((.*)\)$", r"\1", rest[len(name):].strip(" ,."))
    notes = re.sub(r"^(?:units? )?with ", "", notes)
    notes = ", ".join(n for n in (optional, notes) if n)
    if notes:
        unit["notes"] = notes
    m = re.match(r"/aos4/factions/([^/]+)/", link.get("href", "") if link is not None else "")
    unit["faction"] = m.group(1) if m else ""
    return unit


def wahapedia_slug(name):
    """Wahapedia's page name for a regiment or faction: "The Liche's Hand" -> "The-Liche-s-Hand"."""
    return re.sub(r"[^A-Za-z0-9]+", "-", name.replace("’", "'")).strip("-")


def page_names(regiment, wahapedia_names=None):
    """Wahapedia page names to try for a BSData regiment, most likely first. BSData's force entry
    and Wahapedia sometimes capitalises differently ("Hargax's Pit-beasts" is "Hargax-s-Pit-Beasts"),
    or drops or adds a leading "The". [wahapedia_names] maps a BSData name to Wahapedia's where
    it's spelt differently ("Big Drogg Fort-kicker" is "Big Drogg Fort-Kicka"), or capitalised
    in a way the rules miss ("Heroes of The Jade Abbey"); that name is tried first."""
    out = []
    alias = (wahapedia_names or {}).get(regiment["name"])
    if alias:
        out.append(wahapedia_slug(alias))
    for n in (regiment["name"], re.sub(r"^The ", "", regiment["name"]), "The " + regiment["name"]):
        # Title case leaves a possessive's "s" alone: "Hargax-s-Pit-Beasts".
        title = "-".join(w if w == "s" else w[:1].upper() + w[1:] for w in wahapedia_slug(n).split("-"))
        for slug in (wahapedia_slug(n), title):
            if slug not in out:
                out.append(slug)
    return out


# Merging.

def merge_regiments(report, bs_list, wh_list):
    """BSData's regiments with Wahapedia's organisation notes, unit notes, units it alone lists,
    units and abilities in Wahapedia's order and Wahapedia's faction for each unit. Points,
    legends, factions, unit names and abilities are compared; unit counts aren't, as Wahapedia's
    sometimes count models."""
    pairs, wh_left = merge.pair(report, "regiments of renown", bs_list, wh_list)
    out = []
    for bs, wh in pairs:
        r = dict(bs)
        where = "regiment of renown " + bs["name"]
        if wh is None:
            report.only("BSData", "regiment of renown", bs["name"])
            r["units"] = [dict(u, faction="") for u in bs["units"]]
            out.append(r)
            continue
        if bs["points"] != wh["points"]:
            report.differ(where, "points", bs["points"], wh["points"])
        if bool(bs.get("legends")) != bool(wh.get("legends")):
            report.differ(where, "legends", bool(bs.get("legends")), bool(wh.get("legends")))
        if wh.get("text"):
            r["text"] = wh["text"]
        # Wahapedia lists Armies of Renown that BSData allows with their faction ("Legion of the
        # First Prince") as factions of their own.
        armies = {merge.norm(a) for a in bs.get("armies", [])}
        wh_names = [f for f in wh["factions"] if merge.norm(f) not in armies]
        if {merge.norm(f) for f in bs["factions"]} != {merge.norm(f) for f in wh_names}:
            report.differ(where, "factions", sorted(bs["factions"]), sorted(wh_names))
        units, wh_units = merge.pair(report, where, bs["units"], wh["units"])
        for u, w in units:
            if w is None:
                report.only("BSData", "regiment unit", where + " > " + u["name"])
                u["faction"] = ""
                continue
            u["faction"] = w["faction"]
            if w.get("notes") and not u.get("notes"):
                u["notes"] = w["notes"]
        # Kept: BSData leaves out some units, such as the Sigil Convocation's manifestations.
        for w in wh_units:
            report.only("Wahapedia", "regiment unit", where + " > " + w["name"])
        r["units"] = merge.order_like([u for u, _ in units] + [dict(w) for w in wh_units],
                                      [w["name"] for w in wh["units"]])
        merge.compare_abilities(report, where, bs["abilities"], wh["abilities"])
        r["abilities"] = merge.order_like(bs["abilities"], [a["name"] for a in wh["abilities"]])
        out.append(r)
    for wh in wh_left:
        report.only("Wahapedia", "regiment of renown", wh["name"])
    return out


def regiment(r):
    """A regiment in the schema's shape. Each unit names its home faction's id and its
    warscroll's id; a unit the regiment defines itself has no faction and is in its warscrolls."""
    out = {"name": r["name"]}
    if r.get("source"):
        out["source"] = r["source"]
    if r.get("legends"):
        out["legends"] = True
    out["points"] = r["points"]
    if r.get("text"):
        out["text"] = r["text"]
    out["units"] = []
    for u in r["units"]:
        unit = {"count": u["count"], "name": u["name"]}
        if u.get("faction_id"):
            unit["faction"] = u["faction_id"]
        unit["warscroll"] = u["warscroll"]
        if u.get("notes"):
            unit["notes"] = u["notes"]
        out["units"].append(unit)
    out["abilities"] = [schema.ability(a) for a in r["abilities"]]
    if r.get("warscrolls"):
        out["warscrolls"] = [schema.warscroll(w) for w in r["warscrolls"]]
    return out
