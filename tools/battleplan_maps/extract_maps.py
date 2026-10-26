"""Read objective, terrain and territory positions from General's Handbook battleplan maps.

Usage: python -I extract_maps.py <battleplans.json> <map dir> [--overlays <dir>]
e.g.   python -I extract_maps.py data/core/battleplans.json /tmp/maps --overlays /tmp/overlays

Each battleplan in battleplans.json names its map image in "map"; the images are Wahapedia's
(https://wahapedia.ru/aos4/img/battleplans/<map>). The battleplans' "objectives", "terrain",
"attacker_territory" and "defender_territory" are replaced with what the map shows and the file is
rewritten. --overlays writes each map with the detected circles labelled, for checking by eye.

The maps are drawn north up on a 60" x 44" battlefield. Positions are in inches from the north-west
corner, rounded to the nearest half inch. Objective and terrain icons are circles with a gold rim,
found with a Hough transform; territories are the red (attacker) and blue (defender) 15" x 11"
blocks of the map's grid.
"""
import argparse, json, os
import numpy as np
from PIL import Image, ImageDraw

WIDTH, DEPTH = 60, 44
BLOCK_WIDTH, BLOCK_DEPTH = 15, 11
# Medium terrain icons have a radius of about 3.8", objectives 3.5" and small terrain 2.3".
SMALL_RADIUS = 3.1
MIN_SCORE = 5.0


def gold_rim(pixels):
    r, g, b = pixels[..., 0], pixels[..., 1], pixels[..., 2]
    return (r > 90) & (r - b > 50) & (g > 0.55 * r) & (g < 0.95 * r) & (r < 240)


def find_circles(pixels):
    """[(x, y, radius)] in pixels of each gold-rimmed circle, strongest first."""
    height, width = pixels.shape[:2]
    ys, xs = np.nonzero(gold_rim(pixels))
    candidates = []
    for radius in range(38, 82, 2):
        votes = np.zeros((height, width), np.int32)
        for angle in np.linspace(0, 2 * np.pi, 72, endpoint=False):
            cx = (xs - radius * np.cos(angle)).round().astype(int)
            cy = (ys - radius * np.sin(angle)).round().astype(int)
            ok = (cx >= 0) & (cx < width) & (cy >= 0) & (cy < height)
            np.add.at(votes, (cy[ok], cx[ok]), 1)
        # Sum each 3x3 neighbourhood to tolerate rounding.
        blurred = sum(np.roll(np.roll(votes, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        score = blurred / 72.0
        for index in np.argsort(score, axis=None)[-600:]:
            y, x = divmod(int(index), width)
            candidates.append((float(score[y, x]), x, y, radius))
    candidates.sort(reverse=True)
    circles = []
    for score, x, y, radius in candidates:
        if score < MIN_SCORE:
            break
        if all((x - cx) ** 2 + (y - cy) ** 2 >= (0.6 * max(radius, cr)) ** 2 for cx, cy, cr in circles):
            circles.append((x, y, radius))
    return circles


def classify(pixels, x, y, radius, scale):
    """("objective", type) or (size, terrain type) from the colours inside a circle."""
    height, width = pixels.shape[:2]
    yy, xx = np.ogrid[:height, :width]
    inside = pixels[(xx - x) ** 2 + (yy - y) ** 2 < (0.55 * radius) ** 2]
    r, g, b = inside[:, 0], inside[:, 1], inside[:, 2]
    if ((r > 200) & (g > 150) & (b < 80)).mean() > 0.3:
        return "objective", "Sun Seekers"
    if ((r > 180) & (g < 60) & (b < 60)).mean() > 0.1:
        return "objective", "Golden Lions"
    if ((b > 150) & (r < 60)).mean() > 0.3:
        return "objective", "Scions of the Comet"
    if ((r < 40) & (g < 40) & (b < 40)).mean() > 0.3:
        return "objective", "Heldenhain"
    size = "small" if radius / scale < SMALL_RADIUS else "medium"
    # Realmgates are Places of Power; small icons are otherwise always woods (obscuring), and
    # medium woods have far more green than ruins (area terrain or obstacle).
    if ((b > 200) & (g > 200) & (b - r > 40)).mean() > 0.015:
        return size, "place_of_power"
    if size == "small" or ((g > r + 10) & (g > b + 10)).mean() > 0.07:
        return size, "obscuring"
    return size, "area_or_obstacle"


def territory_blocks(pixels, circles):
    """4x4 grid of "attacker", "defender" or "" (neutral) for the map's 15" x 11" blocks."""
    height, width = pixels.shape[:2]
    yy, xx = np.ogrid[:height, :width]
    background = np.ones((height, width), bool)
    for x, y, radius in circles:
        background &= (xx - x) ** 2 + (yy - y) ** 2 > (radius + 4) ** 2
    columns, rows = WIDTH // BLOCK_WIDTH, DEPTH // BLOCK_DEPTH
    blocks = []
    for row in range(rows):
        blocks.append([])
        for column in range(columns):
            x0, x1 = column * width // columns + 4, (column + 1) * width // columns - 4
            y0, y1 = row * height // rows + 4, (row + 1) * height // rows - 4
            r, g, b = np.median(pixels[y0:y1, x0:x1][background[y0:y1, x0:x1]], 0)
            if r > g + 30 and r > b + 30:
                blocks[-1].append("attacker")
            elif b > r + 30 and g > r + 20:
                blocks[-1].append("defender")
            else:
                blocks[-1].append("")
    return blocks


def rectangles(blocks, owner):
    """The blocks [owner] holds, merged into as few {x, y, width, depth} rectangles as rows allow:
    runs of blocks in a row, then identical runs in consecutive rows."""
    runs = []
    for row, cells in enumerate(blocks):
        column = 0
        while column < len(cells):
            if cells[column] != owner:
                column += 1
                continue
            end = column
            while end < len(cells) and cells[end] == owner:
                end += 1
            runs.append([column, end, row, row + 1])
            column = end
    merged = []
    for run in runs:
        above = next((m for m in merged if m[0] == run[0] and m[1] == run[1] and m[3] == run[2]), None)
        if above:
            above[3] = run[3]
        else:
            merged.append(run)
    return [{"x": c0 * BLOCK_WIDTH, "y": r0 * BLOCK_DEPTH, "width": (c1 - c0) * BLOCK_WIDTH,
             "depth": (r1 - r0) * BLOCK_DEPTH} for c0, c1, r0, r1 in merged]


def half_inch(value):
    return float(np.floor(value * 2 + 0.5) / 2)


def read_map(path, overlay_path=None):
    image = Image.open(path).convert("RGB")
    pixels = np.asarray(image).astype(int)
    scale = pixels.shape[1] / WIDTH
    circles = find_circles(pixels)
    objectives, terrain = [], []
    draw = ImageDraw.Draw(image) if overlay_path else None
    for x, y, radius in sorted(circles, key=lambda c: (c[1], c[0])):
        kind, kind_type = classify(pixels, x, y, radius, scale)
        position = {"x": half_inch(x / scale), "y": half_inch(y / (pixels.shape[0] / DEPTH))}
        if kind == "objective":
            objectives.append(dict(type=kind_type, **position))
        else:
            terrain.append(dict(type=kind_type, size=kind, **position))
        if draw:
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], outline=(255, 0, 255), width=3)
            draw.text((x - radius + 8, y), "%s %s\n%s" % (kind_type, "" if kind == "objective" else kind,
                                                          (position["x"], position["y"])), fill=(255, 255, 0))
    blocks = territory_blocks(pixels, circles)
    if draw:
        image.save(overlay_path)
    return {
        "objectives": objectives,
        "terrain": terrain,
        "attacker_territory": rectangles(blocks, "attacker"),
        "defender_territory": rectangles(blocks, "defender"),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("battleplans")
    parser.add_argument("map_dir")
    parser.add_argument("--overlays")
    args = parser.parse_args()
    with open(args.battleplans, encoding="utf-8") as fh:
        data = json.load(fh)
    if args.overlays:
        os.makedirs(args.overlays, exist_ok=True)
    for battleplan in data["battleplans"]:
        overlay = os.path.join(args.overlays, battleplan["map"]) if args.overlays else None
        battleplan.update(read_map(os.path.join(args.map_dir, battleplan["map"]), overlay))
        print("%s: %d objectives, %d terrain features" % (battleplan["name"], len(battleplan["objectives"]),
                                                        len(battleplan["terrain"])))
    with open(args.battleplans, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent="\t")
        fh.write("\n")


if __name__ == "__main__":
    main()
