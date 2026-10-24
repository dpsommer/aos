"""Download a faction's BSData catalogues and Wahapedia pages.

Usage: python -I fetch.py "<BSData faction name>" <wahapedia slug> <out dir>
e.g.   python -I fetch.py "Helsmiths of Hashut" helsmiths-of-hashut /tmp/hoh

Writes:
  <out dir>/bsdata/      the game system, Lores.cat, <Faction>.cat and every "<Faction> - *.cat"
  <out dir>/wahapedia/   <slug>.html and units/<Unit-Name>.html
"""
import json, os, re, sys, time, urllib.error, urllib.parse, urllib.request

BSDATA_REPO = "BSData/age-of-sigmar-4th"
BSDATA_API = "https://api.github.com/repos/%s/contents" % BSDATA_REPO
BSDATA_RAW = "https://raw.githubusercontent.com/%s/main/" % BSDATA_REPO
WAHAPEDIA = "https://wahapedia.ru/aos4/factions/"
HEADERS = {"User-Agent": "Mozilla/5.0"}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as response:
        return response.read().decode("utf-8")


def save(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def fetch_bsdata(faction, out_dir):
    names = [entry["name"] for entry in json.loads(get(BSDATA_API))]
    wanted = [n for n in names if n.endswith(".gst") or n == "Lores.cat"
              or n == faction + ".cat" or n.startswith(faction + " - ")]
    if faction + ".cat" not in wanted:
        sys.exit("no BSData catalogue named %r" % (faction + ".cat"))
    linked = set()
    for name in wanted:
        xml = get(BSDATA_RAW + urllib.parse.quote(name))
        save(os.path.join(out_dir, "bsdata", name), xml)
        print("bsdata", name, file=sys.stderr)
        if name == faction + ".cat" or name.startswith(faction + " - "):
            linked.update(shared_catalogues(xml, faction, names))
    # One level only: shared catalogues link to every faction's library, which isn't needed.
    for name in sorted(linked - set(wanted)):
        save(os.path.join(out_dir, "bsdata", name), get(BSDATA_RAW + urllib.parse.quote(name)))
        print("bsdata", name, "(linked)", file=sys.stderr)


def shared_catalogues(xml, faction, names):
    """Catalogues a faction catalogue links to, e.g. an Army of Renown shared by several factions.
    Link names carry a decorative prefix ("❖ Lores", "þ The Duardin Ascendant [LEGENDS]");
    Path to Glory campaigns and other factions' libraries aren't needed."""
    out = []
    for link in re.findall(r'<catalogueLink [^>]*name="([^"]+)"', xml):
        name = re.sub(r"^[^A-Za-z0-9]+", "", link).replace("&apos;", "'").replace("&amp;", "&") + ".cat"
        if name in names and not name.startswith("Path to Glory") and (
                not name.endswith(" - Library.cat") or name.startswith(faction + " - ")):
            out.append(name)
    return out


def fetch_wahapedia(slug, out_dir):
    page = get(WAHAPEDIA + slug + "/")
    save(os.path.join(out_dir, "wahapedia", slug + ".html"), page)
    units = sorted(set(re.findall(r'href="/aos4/factions/%s/([^"#/?]+)"' % re.escape(slug), page)))
    for unit in units:
        time.sleep(1)
        try:
            html = get(WAHAPEDIA + slug + "/" + unit)
        except urllib.error.HTTPError as error:
            # Some links, such as the Path to Glory hero, have no page of their own.
            print("skipped %s: %s" % (unit, error), file=sys.stderr)
            continue
        save(os.path.join(out_dir, "wahapedia", "units", unit + ".html"), html)
        print("wahapedia", unit, file=sys.stderr)


if __name__ == "__main__":
    faction, slug, out = sys.argv[1:4]
    fetch_bsdata(faction, out)
    fetch_wahapedia(slug, out)
