"""Download a Wahapedia AoS4 faction page and every unit page it links to.

Usage: python -I fetch.py <faction slug> <out dir>
e.g.   python -I fetch.py helsmiths-of-hashut /tmp/hoh

Writes <out dir>/<faction slug>.html and <out dir>/units/<Unit-Name>.html.
"""
import os, re, sys, time, urllib.request

BASE = "https://wahapedia.ru/aos4/factions/"
HEADERS = {"User-Agent": "Mozilla/5.0"}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as response:
        return response.read().decode("utf-8")


def main(slug, out_dir):
    os.makedirs(os.path.join(out_dir, "units"), exist_ok=True)
    page = get(BASE + slug + "/")
    with open(os.path.join(out_dir, slug + ".html"), "w", encoding="utf-8") as fh:
        fh.write(page)
    units = sorted(set(re.findall(r'href="/aos4/factions/%s/([^"#/?]+)"' % re.escape(slug), page)))
    for unit in units:
        time.sleep(1)
        try:
            html = get(BASE + slug + "/" + unit)
        except urllib.error.HTTPError as error:
            # Some links, such as the Path to Glory hero, have no page of their own.
            print("skipped %s: %s" % (unit, error), file=sys.stderr)
            continue
        with open(os.path.join(out_dir, "units", unit + ".html"), "w", encoding="utf-8") as fh:
            fh.write(html)
        print(unit, file=sys.stderr)


if __name__ == "__main__":
    main(*sys.argv[1:3])
