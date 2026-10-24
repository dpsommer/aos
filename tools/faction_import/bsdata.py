"""Reader for BSData Age of Sigmar 4th edition catalogues.

Produces a faction's rules, warscrolls and Armies of Renown in the game's JSON shape
(see docs/technical/faction-data.md). BSData has no Spearhead, Path to Glory prose,
regiment options, unit composition or Army of Renown text; merge.py adds those from Wahapedia.

Catalogues are read from a local checkout of the BSData repository, by default tools/bsdata
(gitignored). ensure_checkout() clones it on first use and pulls it on request.
"""
import glob, os, re, subprocess, sys
import xml.etree.ElementTree as ET

REPOSITORY = "https://github.com/BSData/age-of-sigmar-4th.git"
DEFAULT_CHECKOUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bsdata")

ALLIANCES = ("ORDER", "CHAOS", "DEATH", "DESTRUCTION")


def is_ability(profile):
    """Ability profiles: Passive, Activated, Spell, Prayer, Command, and faction-specific
    types such as "Ability (Blood Tithe)"."""
    return (profile.get("typeName") or "").startswith("Ability (")

LORE_GROUPS = {"Spell Lores": "spell", "Prayer Lores": "prayer", "Manifestation Lores": "manifestation"}
# Shared entry groups that aren't enhancements: campaign content and lores.
NOT_ENHANCEMENTS = {"Paths", "Battle Wounds + Scars", *LORE_GROUPS}
# Categories on units that aren't keywords.
NOT_KEYWORDS = {"Legends", "General"}
FREQUENCY = re.compile(r"^(Once Per (?:Battle|Turn|Phase)(?: \((?:Army|Army, Each Player)\))?),?\s*(.*)$")


def tag(el):
    return el.tag.rsplit("}", 1)[-1]


def kids(el, container, child=None):
    """Children of el's <container> element, optionally only those with tag `child`."""
    for c in el:
        if tag(c) == container:
            return [k for k in c if child is None or tag(k) == child]
    return []


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("’", "").replace("'", "")).strip("_")


def markup(text):
    """BSData text to plain text: **^^Keyword^^** becomes KEYWORD, other emphasis is dropped."""
    text = (text or "").replace("\xa0", " ")
    text = re.sub(r"\*{0,3}\^\^(.+?)\^\^\*{0,3}", lambda m: m.group(1).upper(), text)
    text = text.replace("*", "")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    return text.strip()


def int_or(value, default=0):
    m = re.search(r"-?\d+", value or "")
    return int(m.group()) if m else default


def ensure_checkout(path=DEFAULT_CHECKOUT, update=False):
    """Clone the BSData repository to `path` if it isn't there; pull it if `update`."""
    if not os.path.isdir(os.path.join(path, ".git")):
        print("cloning %s into %s" % (REPOSITORY, path), file=sys.stderr)
        subprocess.run(["git", "clone", "--depth", "1", "--quiet", REPOSITORY, path], check=True)
    elif update:
        subprocess.run(["git", "-C", path, "pull", "--ff-only", "--quiet"], check=True)
    return path


def checkout_version(path):
    """Short commit hash and date of the checkout, for the build report."""
    result = subprocess.run(["git", "-C", path, "log", "-1", "--format=%h %cs"], capture_output=True, text=True)
    return result.stdout.strip() or "unknown"


def faction_files(directory, faction):
    """The catalogue files a faction needs: the game system, Lores.cat, <Faction>.cat, every
    "<Faction> - *.cat" (library and Armies of Renown) and the shared catalogues those link
    to, one level deep. Link names carry a decorative prefix ("❖ Lores", "þ The Duardin
    Ascendant [LEGENDS]"). Path to Glory campaigns and other factions' libraries aren't needed."""
    names = set(os.listdir(directory))
    if faction + ".cat" not in names:
        raise SystemExit("no BSData catalogue named %r in %s" % (faction + ".cat", directory))
    own = [n for n in names if n == faction + ".cat" or n.startswith(faction + " - ")]
    wanted = set(own) | {n for n in names if n.endswith(".gst") or n == "Lores.cat"}
    for name in own:
        with open(os.path.join(directory, name), encoding="utf-8") as fh:
            for link in re.findall(r'<catalogueLink [^>]*name="([^"]+)"', fh.read()):
                linked = re.sub(r"^[^A-Za-z0-9]+", "", link).replace("&apos;", "'").replace("&amp;", "&") + ".cat"
                if linked in names and not linked.startswith("Path to Glory") and (
                        not linked.endswith(" - Library.cat") or linked.startswith(faction + " - ")):
                    wanted.add(linked)
    return sorted(wanted)


class Catalogues:
    """Catalogues from a directory, with ids indexed so links resolve across files.
    `files` limits which are read (see faction_files); by default every catalogue is."""

    def __init__(self, directory, files=None):
        self.docs = {}
        paths = [os.path.join(directory, f) for f in files] if files is not None else \
            glob.glob(os.path.join(directory, "*.cat")) + glob.glob(os.path.join(directory, "*.gst"))
        for path in sorted(paths):
            self.docs[os.path.basename(path)] = ET.parse(path).getroot()
        self.by_id = {}
        for root in self.docs.values():
            for el in root.iter():
                if el.get("id") and tag(el) != "constraint":
                    self.by_id.setdefault(el.get("id"), el)
        self.publications = {el.get("id"): el.get("name") for root in self.docs.values()
                             for el in root.iter() if tag(el) == "publication"}

    def catalogue(self, name):
        root = self.docs.get(name + ".cat")
        if root is None:
            raise SystemExit("missing catalogue %r" % (name + ".cat"))
        return root

    def resolve(self, link):
        return self.by_id.get(link.get("targetId"))

    def publication(self, el):
        return self.publications.get(el.get("publicationId"), "")


def source_of(publication):
    """The `source` field for a publication: empty for battletomes and core books."""
    if publication.startswith("Scourge of"):
        return publication
    if publication.startswith("White Dwarf"):
        return "White Dwarf"
    return ""


def characteristics(profile):
    return {c.get("name"): c.text or "" for c in kids(profile, "characteristics", "characteristic")}


def ability(profile, name=None):
    chars = characteristics(profile)
    attrs = {a.get("name"): a.text or "" for a in kids(profile, "attributes", "attribute")}
    is_passive = profile.get("typeName") == "Ability (Passive)"
    timing = "Passive" if is_passive else markup(chars.get("Timing"))
    frequency = ""
    m = FREQUENCY.match(timing)
    if m:
        frequency, timing = m.group(1), m.group(2)
    effect, options = split_options(chars.get("Effect", ""))
    out = {"name": name or profile.get("name"), "category": attrs.get("Type", "").lower(), "timing": timing}
    if frequency:
        out["frequency"] = frequency
    if markup(chars.get("Declare")):
        out["declare"] = markup(chars.get("Declare"))
    out["effect"] = effect
    if chars.get("Casting Value"):
        out["casting_value"] = int_or(chars["Casting Value"])
    if chars.get("Chanting Value"):
        out["chanting_value"] = int_or(chars["Chanting Value"])
    keywords = [k.strip() for k in markup(chars.get("Keywords")).upper().split(",") if k.strip()]
    if keywords:
        out["keywords"] = keywords
    if options:
        out["options"] = options
    return out


def split_options(effect):
    """Split '***Label:*** text' lines and designer's notes out of an effect into named options.
    When several options each follow a short heading line, such as "Battle Round 2:", the
    heading prefixes the option's name. A single such line ("Pick 1 of the following:") is
    lead text and stays in the effect."""
    # "***Label:***", "***Label***:" or "***Label*:**".
    option_line = re.compile(r"\s*\*{3}([^*]+?)(?:\*:\*{2}|:?\*{3}:?)\s*(.*)$")
    source = (effect or "").split("\n")
    headings = {i for i, line in enumerate(source[:-1])
                if option_line.match(source[i + 1]) and re.fullmatch(r"[^.:]{1,40}:", markup(line))}
    if len(headings) < 2:
        headings = set()
    lines, options, heading = [], [], ""
    for i, line in enumerate(source):
        # Bold, bold italic or italic: "**Designer's Note:** …", "***Designer's Note**: …*".
        note = re.match(r"\s*\*{1,3}Designer's Note:?\*{0,3}:?\s*(.*?)\**\s*$", line)
        m = option_line.match(line)
        if note:
            # Commentary rather than rules; kept apart from the effect as Wahapedia does.
            options.append({"name": "Designer’s Note", "text": markup(note.group(1))})
        elif m:
            name = markup(m.group(1)).rstrip(":")
            options.append({"name": heading + name, "text": markup(m.group(2))})
            heading = ""
        elif i in headings:
            heading = markup(line) + " "
        elif options and line.strip():
            options[-1]["text"] += "\n" + markup(line)
        else:
            lines.append(line)
    return markup("\n".join(lines)), options


def abilities_in(el):
    """Ability profiles directly on an entry (not inside enhancements it links to)."""
    return [ability(p) for p in kids(el, "profiles", "profile") if is_ability(p)]


def unit_profiles(unit):
    """Profiles on a unit, its models and their wargear; links to other entries aren't followed."""
    found = []
    def walk(el):
        for p in kids(el, "profiles", "profile"):
            found.append(p)
        for container in ("selectionEntries", "selectionEntryGroups"):
            for child in kids(el, container):
                walk(child)
    walk(unit)
    return found


def models(unit):
    out = []
    def walk(el):
        for container in ("selectionEntries", "selectionEntryGroups"):
            for child in kids(el, container):
                if tag(child) == "selectionEntry" and child.get("type") == "model":
                    out.append(child)
                walk(child)
    walk(unit)
    return out


def min_count(entry):
    for c in kids(entry, "constraints", "constraint"):
        if c.get("type") == "min" and c.get("field") == "selections":
            return int(float(c.get("value")))
    return 0


def base_size(unit):
    sizes = {}
    def size_of(rule):
        # "75x42mm" -> "75 × 42mm", the battletome's style.
        return re.sub(r"(\d)\s*x\s*(\d)", r"\1 × \2", markup(rule.findtext("{*}description")))
    for model in models(unit):
        for rule in model.iter():
            if tag(rule) == "rule" and rule.get("name") == "Base Size":
                sizes.setdefault(size_of(rule), []).append(model.get("name"))
    for rule in kids(unit, "rules", "rule"):
        if rule.get("name") == "Base Size":
            sizes.setdefault(size_of(rule), []).append(unit.get("name"))
    if len(sizes) <= 1:
        return next(iter(sizes), "")
    def names(n):
        return n[0] if len(n) == 1 else ", ".join(n[:-1]) + " and " + n[-1]
    return ", ".join("%s: %s" % (names(n), size) for size, n in sizes.items())


def warscroll(cats, unit, link=None):
    publication = cats.publication(unit)
    source = source_of(publication)
    name = re.sub(r"\s*\((Scourge of [^)]+)\)$", "", unit.get("name"))
    m = re.search(r"\((Scourge of [^)]+)\)$", unit.get("name"))
    if m:
        source = m.group(1)
    out = {"id": slug(((source + " ") if source.startswith("Scourge of") else "") + name), "name": name}
    if source:
        out["source"] = source
    keywords = [c.get("name") for c in kids(unit, "categoryLinks", "categoryLink") if c.get("hidden") != "true"]
    if publication == "Warhammer Legends" or "Legends" in keywords:
        out["legends"] = True
    if link is not None:
        costs = {c.get("name"): c.get("value") for c in kids(link, "costs", "cost")}
        out["points"] = int(float(costs.get("pts", 0)))
        out["can_reinforce"] = any(l.get("name") == "Reinforced" for l in kids(link, "entryLinks", "entryLink"))
    out["unit_size"] = sum(min_count(m) for m in models(unit)) or 1
    if base_size(unit):
        out["base_size"] = base_size(unit)
    profiles = unit_profiles(unit)
    # Manifestations have a Manifestation profile (Move, Health, Save, Banishment) instead.
    stats = next((characteristics(p) for p in profiles if p.get("typeName") in ("Unit", "Manifestation")), {})
    out["move"] = int_or(stats.get("Move"))
    out["health"] = int_or(stats.get("Health"))
    out["save"] = int_or(stats.get("Save"))
    out["control"] = int_or(stats.get("Control"))
    if stats.get("Banishment"):
        out["banishment"] = int_or(stats["Banishment"])
    ward = next((int_or(k) for k in keywords if k.upper().startswith("WARD")), 0)
    if ward:
        out["ward"] = ward
    out["ranged_weapons"], out["melee_weapons"] = weapons(profiles)
    seen, out["abilities"] = set(), []
    for p in profiles:
        if is_ability(p) and p.get("name") not in seen:
            seen.add(p.get("name"))
            out["abilities"].append(ability(p))
    out["keywords"] = [k.upper() for k in keywords if k not in NOT_KEYWORDS]
    return out


def weapons(profiles):
    ranged, melee, seen = [], [], set()
    for p in profiles:
        kind = p.get("typeName")
        if kind not in ("Ranged Weapon", "Melee Weapon") or (kind, p.get("name")) in seen:
            continue
        seen.add((kind, p.get("name")))
        c = characteristics(p)
        w = {"name": p.get("name").strip(), "range": int_or(c.get("Rng")) if kind == "Ranged Weapon" else 0,
             "attacks": markup(c.get("Atk")), "hit": int_or(c.get("Hit")), "wound": int_or(c.get("Wnd")),
             "rend": int_or(c.get("Rnd")), "damage": markup(c.get("Dmg"))}
        abilities = [a.strip() for a in markup(c.get("Ability")).split(",") if a.strip() and a.strip() != "-"]
        if abilities:
            w["abilities"] = abilities
        (ranged if kind == "Ranged Weapon" else melee).append(w)
    return ranged, melee


def points(entry):
    costs = {c.get("name"): c.get("value") for c in kids(entry, "costs", "cost")}
    return int(float(costs.get("pts", 0)))


def enhancement(cats, entry):
    profile = next((p for p in kids(entry, "profiles", "profile") if is_ability(p)), None)
    out = ability(profile, entry.get("name")) if profile is not None else {"name": entry.get("name"), "category": "", "timing": "", "effect": ""}
    if points(entry):
        out["points"] = points(entry)
    return out


def short_name(name, owner):
    """'Heroic Traits: Pioneer Outpost' -> 'Heroic Traits' when owner is the Army of Renown."""
    head, _, tail = name.partition(":")
    return head.strip() if owner and tail.strip() == owner else name


def enhancement_tables(cats, root, owner=""):
    tables = []
    for group in kids(root, "sharedSelectionEntryGroups", "selectionEntryGroup"):
        name = group.get("name")
        if name in NOT_ENHANCEMENTS or name.startswith("Battle Formations"):
            continue
        direct = [enhancement(cats, e) for e in kids(group, "selectionEntries", "selectionEntry")]
        if direct:
            tables.append({"name": name, "source": source_of(cats.publication(group)), "entries": direct})
        for sub in kids(group, "selectionEntryGroups", "selectionEntryGroup"):
            table = {"name": name}
            group_name = short_name(sub.get("name"), owner)
            if group_name != name:
                table["group"] = group_name
            if source_of(cats.publication(sub)):
                table["source"] = source_of(cats.publication(sub))
            table["entries"] = [enhancement(cats, e) for e in kids(sub, "selectionEntries", "selectionEntry")]
            tables.append(table)
    return [t for t in tables if t["entries"]]


def lores(cats, root, owner=""):
    """Faction lores. Universal lores (core rules, General's Handbook) are skipped."""
    out = []
    for group in kids(root, "sharedSelectionEntryGroups", "selectionEntryGroup"):
        kind = LORE_GROUPS.get(group.get("name"))
        if not kind:
            continue
        for option in kids(group, "selectionEntries", "selectionEntry"):
            for link in kids(option, "entryLinks", "entryLink"):
                target = cats.resolve(link)
                if target is None or cats.publication(target).startswith(("Core Rules", "General's Handbook")):
                    continue
                lore = {"name": short_name(option.get("name"), owner), "kind": kind}
                source = source_of(cats.publication(target)) or source_of(cats.publication(option))
                if source:
                    lore["source"] = source
                if points(option):
                    lore["points"] = points(option)
                lore["entries"] = [a for e in kids(target, "selectionEntries", "selectionEntry") for a in abilities_in(e)]
                out.append(lore)
    return out


def battle_traits(root, name):
    for entry in kids(root, "sharedSelectionEntries", "selectionEntry"):
        if entry.get("name") == "Battle Traits: " + name:
            return abilities_in(entry)
    return []


def battle_formations(root, name):
    for group in kids(root, "sharedSelectionEntryGroups", "selectionEntryGroup"):
        if group.get("name") == "Battle Formations: " + name:
            return [{"name": e.get("name"), "points": points(e), "abilities": abilities_in(e)}
                    for e in kids(group, "selectionEntries", "selectionEntry")]
    return []


def unit_links(cats, root):
    """(unit entry, link) for every unit the catalogue lists."""
    out = []
    for link in kids(root, "entryLinks", "entryLink"):
        target = cats.resolve(link)
        if target is not None and target.get("type") == "unit":
            out.append((target, link))
    return out


def linked_roots(cats, root, aor_name):
    """An Army of Renown catalogue plus the shared catalogue holding its rules, if any.
    Several factions' "<Faction> - The Duardin Ascendant" link to "þ The Duardin Ascendant".
    Other links (libraries, lores, Path to Glory) aren't part of the Army of Renown."""
    roots = [root]
    for link in kids(root, "catalogueLinks", "catalogueLink"):
        target = next((r for r in cats.docs.values() if r.get("id") == link.get("targetId")), None)
        if target is not None and re.sub(r"^[^A-Za-z0-9]+", "", target.get("name", "")) == aor_name:
            roots.append(target)
    return roots


def units_of(cats, name, aor_roots):
    """Every unit of the faction: those its catalogue lists, unlisted library units (such as
    units added during a battle) and units defined by its Armies of Renown. The Path to Glory
    Anvil of Apotheosis hero is left out; Wahapedia's Path to Glory section covers it."""
    root = cats.catalogue(name)
    # The faction catalogue's link sets points and reinforcement. An Army of Renown's link is
    # only used for units the faction catalogue doesn't price, such as Grombrindal.
    links = {}
    for r in [root] + aor_roots:
        for unit, link in unit_links(cats, r):
            current = links.get(unit.get("id"))
            if current is None or (not points_of_link(current) and points_of_link(link)):
                links[unit.get("id")] = link
    units = [unit for unit, _ in unit_links(cats, root) if not unit.get("name").startswith("Anvil of Apotheosis")]
    shared = [u for r in [cats.docs.get(name + " - Library.cat")] + aor_roots if r is not None
              for u in kids(r, "sharedSelectionEntries", "selectionEntry") if u.get("type") == "unit"]
    for unit in shared:
        if unit not in units and not unit.get("name").startswith("Anvil of Apotheosis"):
            units.append(unit)
    return [(unit, links.get(unit.get("id"))) for unit in units]


def aor_file_name(faction, file_name):
    """'Kharadron Overlords - The Duardin Ascendant [LEGENDS].cat' -> 'The Duardin Ascendant [LEGENDS]'"""
    return file_name[len(faction + " - "):-len(".cat")]


def split_legends_tag(aor_name):
    """'The Duardin Ascendant [LEGENDS]' -> ('The Duardin Ascendant', True). The tag's closing
    bracket is sometimes missing ('Cities of Sigmar - Lethis [LEGENDS.cat')."""
    return re.sub(r"\s*\[LEGENDS\]?", "", aor_name).strip(), "[LEGENDS" in aor_name


def points_of_link(link):
    return any(c.get("name") == "pts" and float(c.get("value")) for c in kids(link, "costs", "cost"))


def read_faction(cats, name):
    """faction, warscrolls and armies_of_renown for the BSData faction `name`."""
    root = cats.catalogue(name)
    aor_files = [f for f in sorted(cats.docs) if f.startswith(name + " - ") and not f.endswith("Library.cat")]
    aor_roots = [r for f in aor_files for r in linked_roots(cats, cats.docs[f], aor_file_name(name, f))]
    units = units_of(cats, name, aor_roots)
    warscrolls = [warscroll(cats, unit, link) for unit, link in units]
    alliance = next((k.lower() for unit, _ in units for k in
                     (c.get("name") for c in kids(unit, "categoryLinks", "categoryLink")) if k in ALLIANCES), "")
    faction = {
        "name": name,
        "grand_alliance": alliance,
        "battle_traits": battle_traits(root, name),
        "battle_formations": battle_formations(root, name),
        "enhancement_tables": enhancement_tables(cats, root),
        "lores": lores(cats, root),
    }
    armies = []
    for file_name in aor_files:
        roots = linked_roots(cats, cats.docs[file_name], aor_file_name(name, file_name))
        aor_name, legends = split_legends_tag(aor_file_name(name, file_name))
        army = {"name": aor_name}
        if legends:
            army["legends"] = True
        army["roster"] = [unit.get("name") for r in roots for unit, _ in unit_links(cats, r)]
        army["battle_traits"] = [a for r in roots for a in battle_traits(r, aor_name)]
        army["enhancement_tables"] = [t for r in roots for t in enhancement_tables(cats, r, aor_name)]
        army["lores"] = [l for r in roots for l in lores(cats, r, aor_name)]
        armies.append(army)
    return faction, warscrolls, armies
