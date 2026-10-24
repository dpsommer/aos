"""Parse the Wahapedia AoS4 faction page into faction / AoR / spearhead / PtG JSON.

Usage: python -I fparse.py <faction page>.html > faction_raw.json
"""
import sys, re, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bs4 import BeautifulSoup, Tag
from wsparse import text, parse_ability, parse_warscroll, EXPANSIONS
from blocktext import prepare, section_text

LOGO_SOURCE = {"GHYRAN": "Scourge of Ghyran", "SoA": "Scourge of Aqshy", "WhiteDwarf": "White Dwarf"}

def logo_source(el):
    for img in el.find_all("img") if isinstance(el, Tag) else []:
        src = img.get("src", "")
        if "/expansions/" in src:
            key = os.path.basename(src).split("_logo")[0]
            if key in LOGO_SOURCE: return LOGO_SOURCE[key]
    return ""

def table_rows(tbl):
    rows = []
    for tr in tbl.find_all("tr"):
        cells = [text(td) for td in tr.find_all(["td", "th"], recursive=False)]
        cells = [c for c in cells if c]
        if cells: rows.append(cells)
    return rows

def points_table(rows):
    pts = {}
    for r in rows:
        if len(r) == 2 and re.fullmatch(r"\d+", r[1]): pts[r[0].upper()] = int(r[1])
    return pts

def dp(ab):
    m = re.search(r"\s*([+-]\d+)\s*DP\s*$", ab["timing"])
    if m:
        ab["destiny_points"] = int(m.group(1)); ab["timing"] = ab["timing"][:m.start()].strip()
    return ab

def main(path):
    soup = BeautifulSoup(open(path, encoding="utf-8").read(), "lxml")
    for t in soup.select(".tooltip_templates, script, style, .noprint, .ShowFluff, .picSearch, .faqErrataSpoilerBody, .faqErrataHead"):
        t.decompose()
    tsoup = BeautifulSoup(open(path, encoding="utf-8").read(), "lxml")
    for t in tsoup.select(".tooltip_templates, script, style, .noprint, .ShowFluff, .picSearch, .faqErrataSpoilerBody, .faqErrataHead, .wsDataRow_short, .wsDataCell_short, .datasheet"):
        t.decompose()
    prepare(tsoup)
    theads = {}
    for h in tsoup.find_all(["h1", "h2", "h3"]):
        theads.setdefault(text(h), []).append(h)
    def sec_text(title, occurrence=0):
        hs = theads.get(title, [])
        return section_text(hs[occurrence]) if len(hs) > occurrence else ""
    start = soup.find("h2", string=re.compile("Faction Rules"))
    events = []  # (kind, payload) in document order
    for el in start.find_all_next(True):
        if el.find_parent(class_="datasheet") is not None and "datasheet" not in (el.get("class") or []):
            continue
        cls = el.get("class") or []
        if el.name in ("h1", "h2", "h3"):
            events.append(("h", el.name, text(el), el))
        elif "datasheet" in cls:
            events.append(("ws", el))
        elif "abBody" in cls:
            blk = el.find_parent(class_="BreakInsideAvoid")
            if blk is not None and blk.select_one(".abHeader") is None:
                blk = blk.find_parent(class_="BreakInsideAvoid") or blk
            a = parse_ability(blk) if blk is not None else None
            if a: events.append(("ab", dp(a)))
        elif el.name == "table" and not el.find_parent("table") and not el.select(".abHeader") and not el.find_parent(class_="abBody"):
            events.append(("table", table_rows(el)))
        elif el.name == "p" and not el.find_parent("table"):
            t = text(el)
            if t: events.append(("p", t))

    faction = {"battle_traits": [], "battle_formations": [], "enhancement_tables": [], "lores": []}
    aors, spearheads, ptg = [], [], []
    h2, h3, src = None, None, ""
    pts = {}
    mode = "faction"
    cur_aor = cur_sh = cur_ptg = cur_table = cur_formation = None

    def new_table(name, group=""):
        t = {"name": name, "entries": []}
        if group: t["group"] = group
        if src: t["source"] = src
        return t

    def new_lore(name, heading):
        lore = {"name": name, "kind": heading.split()[0].lower(), "entries": []}
        if pts.get(name.upper()): lore["points"] = pts[name.upper()]
        return lore

    for ev in events:
        kind = ev[0]
        if kind == "h":
            _, tag, title, el = ev
            sec_src = ""
            for e2 in el.next_elements:
                if getattr(e2, "name", None) in ("h1", "h2", "h3") and e2 is not el: break
                if getattr(e2, "name", None) == "img" and "/expansions/" in e2.get("src", ""):
                    k = os.path.basename(e2["src"]).split("_logo")[0]
                    sec_src = LOGO_SOURCE.get(k, ""); break
            if tag == "h2" and mode in ("faction", "aor") and "ROSTER OPTIONS" in sec_text(title):
                mode = "aor"; cur_aor = {"name": title, "text": sec_text(title), "battle_traits": [], "enhancement_tables": [], "lores": []}
                if sec_src: cur_aor["source"] = sec_src
                aors.append(cur_aor); h3 = None; continue
            if title.upper() == "PATH TO GLORY":
                mode = "ptg"; cur_ptg = None; continue
            if title.upper() == "SPEARHEAD":
                mode = "spearhead"; continue
            if mode == "spearhead" and tag == "h2":
                cur_sh = {"name": title, "army_text": sec_text(title), "army": [], "battle_traits": [], "regiment_abilities": [], "enhancements": [], "warscrolls": []}
                spearheads.append(cur_sh); h3 = None; continue
            if mode == "ptg":
                if tag in ("h3", "h1") and title != "Your Hero's Warscroll":
                    cur_ptg = {"name": title, "text": sec_text(title), "warscrolls": []}
                    ptg.append(cur_ptg)
                continue
            if mode == "aor":
                h3 = title
                if title.endswith("Lore"):
                    cur_table = new_lore(title, title); cur_aor["lores"].append(cur_table)
                elif title != "Battle Traits":
                    cur_table = {"name": title, "entries": []}; cur_aor["enhancement_tables"].append(cur_table)
                continue
            if mode == "spearhead":
                h3 = title; continue
            # Faction mode. An h2 is Battle Traits, Battle Formations, a lore type ("Spell Lore",
            # "Prayer Lore", "Manifestation Lore") or an enhancement type ("Heroic Traits",
            # "Great Endrinworks"...). An h3 under it names a formation, lore or enhancement table.
            if tag == "h2":
                h2, h3, src = title, None, sec_src
                cur_table = cur_formation = None
            else:
                h3 = title; src = sec_src
                if h2 == "Battle Formations":
                    cur_formation = {"name": title, "points": pts.get(title.upper(), 0), "abilities": []}
                    faction["battle_formations"].append(cur_formation)
                elif h2.endswith("Lore"):
                    cur_table = new_lore(title, h2); faction["lores"].append(cur_table)
                elif h2 != "Battle Traits":
                    cur_table = new_table(h2, title); faction["enhancement_tables"].append(cur_table)
            continue
        if kind == "table":
            rows = ev[1]
            if rows and rows[0][0].startswith("Q:"): continue
            pts.update(points_table(rows))
            if mode == "spearhead" and cur_sh is not None and not cur_sh["army"]:
                cur_sh["army"] = rows
            continue
        if kind == "p":
            if mode == "ptg" and cur_ptg is None:
                cur_ptg = {"name": "Path to Glory", "text": ev[1], "warscrolls": []}; ptg.append(cur_ptg)
            continue
        if kind == "ws":
            el = ev[1]
            if mode == "spearhead" and cur_sh is not None: cur_sh["warscrolls"].append(parse_warscroll(el, "spearhead"))
            elif mode == "ptg" and cur_ptg is not None: cur_ptg["warscrolls"].append(parse_warscroll(el, "ptg"))
            continue
        a = ev[1]
        if mode == "faction":
            if h2 == "Battle Traits": faction["battle_traits"].append(a)
            elif h2 == "Battle Formations":
                if cur_formation is not None: cur_formation["abilities"].append(a)
            elif h2.endswith("Lore"):
                if cur_table is None:
                    cur_table = new_lore(h2, h2); faction["lores"].append(cur_table)
                cur_table["entries"].append(a)
            else:
                # Abilities straight under an enhancement h2 form a table with no group.
                if cur_table is None:
                    cur_table = new_table(h2); faction["enhancement_tables"].append(cur_table)
                a["points"] = pts.get(a["name"].upper(), 0); cur_table["entries"].append(a)
        elif mode == "aor":
            if h3 == "Battle Traits": cur_aor["battle_traits"].append(a)
            elif cur_table is not None and all(e["name"] != a["name"] for e in cur_table["entries"]): cur_table["entries"].append(a)
        elif mode == "spearhead" and cur_sh is not None:
            key = {"Battle Traits": "battle_traits", "Regiment Abilities": "regiment_abilities", "Enhancements": "enhancements"}.get(h3)
            if key: cur_sh[key].append(a)
        elif mode == "ptg":
            pass  # PtG abilities are kept in the section text
    json.dump({"faction": faction, "armies_of_renown": aors, "spearheads": spearheads, "path_to_glory": ptg},
              sys.stdout, indent=1, ensure_ascii=False)

if __name__ == "__main__":
    main(sys.argv[1])
