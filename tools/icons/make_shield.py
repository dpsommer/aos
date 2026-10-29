"""Generates a battle-worn heraldic shield icon in the style of the AoS icon pack.

Usage: python3 tools/icons/make_shield.py assets/2d/icons/shield.svg
The seed is fixed, so the output is the same each run.
"""
import math, random, sys

random.seed(7)
CX, TOP, HW, H = 107.5, 18.0, 78.0, 180.0  # centre x, top y, half width, height


def outline(n=480):
    """Points around a heraldic shield, clockwise from the top left corner."""
    pts = []
    seg = n // 4
    for i in range(seg):  # top edge with a slight dip in the middle
        u = -1 + 2 * i / seg
        pts.append((u, 0.035 * (1 - u * u)))
    for i in range(seg // 2):  # right side
        pts.append((1, 0.5 * i / (seg // 2)))
    for i in range(seg):  # right curve to the point
        t = i / seg
        p0, p1, p2 = (1, 0.5), (1, 0.86), (0, 1)
        pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    right = pts[seg:]
    left = [(-u, v) for u, v in reversed(right)]
    pts = pts[:seg] + right + left
    return [(CX + u * HW, TOP + v * H) for u, v in pts]


def normals(pts):
    """Unit normals pointing into the shape."""
    out, n = [], len(pts)
    for i in range(n):
        (x0, y0), (x1, y1) = pts[i - 1], pts[(i + 1) % n]
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length, dx / length
        cy = TOP + H * 0.45
        if (CX - pts[i][0]) * nx + (cy - pts[i][1]) * ny < 0:
            nx, ny = -nx, -ny
        out.append((nx, ny))
    return out


def noise(n, amp, waves=6):
    phases = [(random.uniform(0, 6.3), random.randint(7, 60), random.uniform(0.3, 1)) for _ in range(waves)]
    total = sum(w for _, _, w in phases)
    return [amp * sum(w * math.sin(f * 2 * math.pi * i / n + p) for p, f, w in phases) / total for i in range(n)]


def chips(n, count, depth, width):
    """Sharp V-shaped nicks: inward offsets at random positions."""
    out = [0.0] * n
    for _ in range(count):
        c, d, w = random.randrange(n), random.uniform(*depth), random.randint(*width)
        for k in range(-w, w + 1):
            out[(c + k) % n] = max(out[(c + k) % n], d * (1 - abs(k) / (w + 1)))
    return out


def ring(base, inset, rough, nick_count=0, nick_depth=(0, 0), nick_width=(2, 4)):
    n = len(base)
    nrm = normals(base)
    jitter = noise(n, rough)
    nick = chips(n, nick_count, nick_depth, nick_width) if nick_count else [0.0] * n
    # fine grit on top of the smooth noise
    grit = [random.uniform(-rough * 0.5, rough * 0.5) for _ in range(n)]
    return [(x + nx * (inset + j + c + g), y + ny * (inset + j + c + g))
            for (x, y), (nx, ny), j, c, g in zip(base, nrm, jitter, nick, grit)]


def path(pts):
    return "M" + " L".join("%.2f,%.2f" % p for p in pts) + " Z"


def crack(start, end, width, kinks):
    """A jagged gash from start to end, as a thin closed polygon."""
    (x0, y0), (x1, y1) = start, end
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    spine = []
    for i in range(kinks + 1):
        t = i / kinks
        off = 0 if i in (0, kinks) else random.uniform(-6, 6)
        spine.append((x0 + dx * t + nx * off, y0 + dy * t + ny * off))
    side_a, side_b = [], []
    for i, (x, y) in enumerate(spine):
        t = i / kinks
        w = width * math.sin(math.pi * min(max(t, 0.08), 0.92))  # tapered ends
        side_a.append((x + nx * w, y + ny * w))
        side_b.append((x - nx * w, y - ny * w))
    return side_a + list(reversed(side_b))


base = outline()
outer = ring(base, 0, 1.2, nick_count=6, nick_depth=(5, 10), nick_width=(3, 6))
gap = ring(base, 15, 1.0)
field = ring(base, 24, 1.0, nick_count=3, nick_depth=(3, 6), nick_width=(3, 5))
gash = crack((152, 48), (96, 132), 5.5, 6)
branch = crack((122, 94), (150, 116), 3.5, 3)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="215" height="215" viewBox="0 0 215 215">
  <title>shield</title>
  <path fill="#ffffff" fill-rule="evenodd" d="{path(outer)} {path(gap)}"/>
  <path fill="#ffffff" fill-rule="evenodd" d="{path(field)} {path(gash)} {path(branch)}"/>
</svg>
'''
open(sys.argv[1], "w").write(svg)
