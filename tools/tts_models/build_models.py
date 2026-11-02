"""Builds assets/3d/models/ from a Tabletop Simulator mod in Tabletop Simulator's cache.

Usage (from the project root, in the "aos" pyenv virtualenv with requirements.txt installed):

    python -I tools/tts_models/build_models.py <Mods folder> [<workshop id or save path>] [--out assets/3d/models] [--dry]

The Mods folder is Tabletop Simulator's cache: ~/Library/Tabletop Simulator/Mods on macOS, and
Documents/My Games/Tabletop Simulator/Mods on Windows, unless Tabletop Simulator's settings move it.
The mod is the Ulthuan mod (workshop id 3202337953) unless another is given. Everything is read from
the Mods folder: the save from Workshop/, the .obj meshes from Models/, their textures from Images/ and the models the mod ships as
Unity asset bundles from Assetbundles/. Subscribe to the mod and load it once in Tabletop Simulator
so it caches them all.

The save names each model (its "Nickname") and says how it's put together: a root object, often
just a base, with the model's pieces attached as child objects at their own position, rotation and
scale. Each model is assembled from its pieces into one .obj with a .mtl of its pieces' textures,
named for the warscroll its nickname matches (see docs/technical/models.md). Flat pieces (bases,
toppers, colliders) are left out, as the game draws its own bases.
"""

import argparse
import difflib
import glob
import json
import math
import os
import re
import shutil
import sys
from collections import Counter, defaultdict

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(ROOT, "data")
sys.path.insert(0, HERE)  # for bundles.py, as -I leaves the script's folder out

# The Ulthuan mod (https://steamcommunity.com/sharedfiles/filedetails/?id=3202337953).
MOD = "3202337953"

# A piece no taller than this (inches) is a base, topper or collider.
FLAT = 0.35
# Textures are scaled down to at most this many pixels on a side.
TEXTURE_SIZE = 1024
# A texture with pixels more transparent than this is a cutout (leaves, banners, chains).
CUTOUT_ALPHA = 128

# The faction tiles of the mod, by nickname, and the factions whose warscrolls their models can be.
TILES = {
    "Fyreslayers": ["fyreslayers", "khazalite_holds"],
    "Kharadron Overlords": ["kharadron_overlords"],
    "Seraphon": ["seraphon"],
    "Stormcast Eternals": ["stormcast_eternals"],
    "Helsmiths of Hashut": ["helsmiths_of_hashut"],
    "Flesh Eater Courts": ["flesh_eater_courts"],
    "Disciples of Tzeentch": ["disciples_of_tzeentch"],
    "Hedonites of Slaanesh": ["hedonites_of_slaanesh"],
    "Khazalite Holds": ["khazalite_holds", "fyreslayers"],
    "Idoneth Derpkin": ["idoneth_deepkin"],
    "Lumineth Realm-lords": ["lumineth_realm_lords"],
    "Maggotkin of Nurgle": ["maggotkin_of_nurgle"],
    "Ossiarch Bone Reapers": ["ossiarch_bonereapers"],
    "Orruk Warclans": ["ironjawz", "kruleboyz", "bonesplitterz"],
    "Blades of Khorne": ["blades_of_khorne"],
    "Nighthaunt": ["nighthaunt"],
    "Gloomspite Gitz": ["gloomspite_gitz"],
    "Ogor Mawtribes/Sons of Behemat": ["ogor_mawtribes", "sons_of_behemat"],
    "Sylvaneth": ["sylvaneth"],
    "Skaven": ["skaven"],
    "Soulblight Gravelords": ["soulblight_gravelords"],
    "Daughters of Khaine": ["daughters_of_khaine"],
    "Manifestations": [],
}
ROLES = r"\b(champion|musician|standard bearer|hornblower|drummer|icon bearer|banner bearer|bannerman|banner|leader|sergeant|piper)\b"


def slug(text):
    """A warscroll name as a file name, as ModelLibrary.slug() makes it."""
    text = text.lower().replace("'", "").replace("’", "")
    return re.sub(r"[^a-z0-9]+", "_", text).strip("_")


def mesh_key(url):
    """Tabletop Simulator's cache file name for a URL, without its extension."""
    return re.sub(r"[^A-Za-z0-9]", "", url or "")


def norm(text):
    return re.sub(r"[^a-z0-9]", "", text.lower().replace("’", "'"))


# ---------------------------------------------------------------------------------------------
# Game data


class Warscrolls:
    """Every warscroll name in data/, with the factions that have it and where its model goes."""

    def __init__(self):
        self.factions = defaultdict(set)  # name -> faction ids ("shared" for data/shared and core)
        self.manifestations = set()  # universal manifestations
        self.alliance = {}
        self.legends = {}
        shared_users = defaultdict(set)
        for path in glob.glob(os.path.join(DATA, "factions", "*", "faction.json")):
            faction = json.load(open(path))
            self.alliance[faction["id"]] = faction["grand_alliance"]
            self.legends[faction["id"]] = faction.get("legends", False)
            folder = os.path.dirname(path)
            for name in ("warscrolls.json", "path_to_glory.json", "spearhead.json"):
                file = os.path.join(folder, name)
                if os.path.exists(file):
                    for scroll in self._scrolls(json.load(open(file))):
                        if "shared" in scroll:
                            shared_users[scroll["shared"]].add(faction["id"])
                        else:
                            self.factions[scroll["name"]].add(faction["id"])
        self.shared_ids = {}
        for path in ("shared/warscrolls.json", "shared/regiments_of_renown.json"):
            for scroll in self._scrolls(json.load(open(os.path.join(DATA, path)))):
                self.factions[scroll["name"]].add("shared")
                self.shared_ids[scroll["name"]] = scroll.get("id")
        for scroll in self._scrolls(json.load(open(os.path.join(DATA, "core", "manifestation_lores.json")))):
            self.factions[scroll["name"]].add("shared")
            self.manifestations.add(scroll["name"])
        self.shared_users = shared_users

    @staticmethod
    def _scrolls(node):
        if isinstance(node, dict):
            if "name" in node and ("health" in node or "unit_size" in node or "move" in node) or "shared" in node and len(node) <= 8 and isinstance(node.get("shared"), str):
                yield node
            for value in node.values():
                yield from Warscrolls._scrolls(value)
        elif isinstance(node, list):
            for value in node:
                yield from Warscrolls._scrolls(value)

    def names_for(self, tile):
        allowed = TILES.get(tile)
        return {norm(name): name for name, factions in self.factions.items()
                if allowed is None or factions & set(allowed) or "shared" in factions}

    def folder(self, target):
        """Where a model of [target] goes: '<alliance>/<faction>' or 'shared/manifestations'."""
        if target.startswith("x:"):
            faction = target.split(":")[1]
            return f"{self.alliance[faction]}/{faction}"
        if target in self.manifestations:
            return "shared/manifestations"
        factions = self.factions[target] - {"shared"}
        if not factions:
            factions = self.shared_users.get(self.shared_ids.get(target), set())
        if not factions:
            return "shared/warscrolls"
        faction = sorted(factions, key=lambda f: (self.legends[f], f))[0]
        return f"{self.alliance[faction]}/{faction}"


def match(nickname, tile, warscrolls, overrides, cache):
    """The warscroll a model's nickname is, 'skip', or None."""
    if nickname in overrides:
        return overrides[nickname]
    names = cache.setdefault(tile, warscrolls.names_for(tile))
    text = nickname.replace("’", "'")
    text = re.sub(r"\(scourge of [^)]*\)", "", text, flags=re.I)
    text = re.sub(r"\b\d+/\d+\b|\b\d+mm\b", "", text)
    text = re.sub(r"^Orruk ", "", text)
    text = re.sub(r"\s+(w/|with)\s.*$", "", text, flags=re.I)
    text = re.sub(r"\s+", " ", text).strip(" ,-")
    forms = [text, re.sub(r"\([^)]*\)", "", text).strip()]
    forms.append(re.sub(r"\s+", " ", re.sub(ROLES, "", forms[1], flags=re.I)).strip())
    for form in list(forms):
        forms += [form + "s", form + "es", re.sub(r"y$", "ies", form), re.sub(r"man$", "men", form), re.sub(r"f$", "ves", form)]
    forms = [f for f in dict.fromkeys(forms) if f]
    for form in forms:
        if norm(form) in names:
            return names[norm(form)]
    for form in forms:
        starts = [name for key, name in names.items() if key.startswith(norm(form)) and len(norm(form)) >= 6]
        if len(starts) == 1:
            return starts[0]
    for form in forms:
        close = difflib.get_close_matches(norm(form), list(names), n=1, cutoff=0.86)
        if close:
            return names[close[0]]
    return None


# ---------------------------------------------------------------------------------------------
# The save


def color_of(obj):
    c = obj.get("ColorDiffuse") or {}
    return (c.get("r", 1.0), c.get("g", 1.0), c.get("b", 1.0))


def definitions(save):
    """Every model in the save: {name, tile, tree}. A tree node is {mesh, bundle, diffuse, color, t,
    children}: its .obj mesh or asset bundle (cache keys), its texture's cache key and colour, its
    transform and its child objects."""
    result = []

    def tree(obj):
        custom = obj.get("CustomMesh") or {}
        bundle = (obj.get("CustomAssetbundle") or {}).get("AssetbundleURL")
        return {"mesh": mesh_key(custom.get("MeshURL")), "bundle": mesh_key(bundle),
                "diffuse": mesh_key(custom.get("DiffuseURL")), "color": color_of(obj),
                "t": obj.get("Transform", {}), "children": [tree(c) for c in obj.get("ChildObjects") or []]}

    def collect(obj, tile):
        if obj.get("Name") == "Custom_Model" and (obj.get("CustomMesh") or {}).get("MeshURL"):
            result.append({"name": (obj.get("Nickname") or "").strip(), "tile": tile, "tree": tree(obj)})
        for child in obj.get("ContainedObjects") or []:
            collect(child, tile)
        for state in (obj.get("States") or {}).values():
            collect(state, tile)

    for obj in save["ObjectStates"]:
        tile = (obj.get("Nickname") or obj.get("Name") or "").strip()
        collect(obj, tile)
        # Faction tiles spawn their models from JSON kept in their Lua script.
        for block in re.findall(r"\[\[(\{.*?\})\]\]", obj.get("LuaScript") or "", re.S):
            collect(json.loads(block), tile)
    return result


# ---------------------------------------------------------------------------------------------
# Assembling a model


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def local_matrix(t, translate=True):
    """A Unity transform (Euler degrees applied Z, X, then Y) as a 4x4 matrix."""
    rx, ry, rz = (math.radians(t.get(k, 0.0) or 0.0) for k in ("rotX", "rotY", "rotZ"))
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    mx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    my = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    mz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    r = [[sum(my[i][k] * sum(mx[k][m] * mz[m][j] for m in range(3)) for k in range(3)) for j in range(3)] for i in range(3)]
    s = [t.get(k, 1.0) or 1.0 for k in ("scaleX", "scaleY", "scaleZ")]
    p = [t.get(k, 0.0) or 0.0 for k in ("posX", "posY", "posZ")] if translate else [0, 0, 0]
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], p[i]] for i in range(3)] + [[0, 0, 0, 1]], [row[:] for row in r]


def pieces(tree):
    """Each mesh of a model (its node) with its matrix from the mesh's file to the root's position
    (the root's rotation and scale applied, its position not), and its rotation alone."""
    result = []

    def walk(node, parent, parent_rotation):
        m, r = local_matrix(node["t"], translate=parent is not None)
        world = matmul(parent, m) if parent else m
        rotation = [[sum(parent_rotation[i][k] * r[k][j] for k in range(3)) for j in range(3)] for i in range(3)] if parent_rotation else r
        if node["mesh"] or node["bundle"]:
            result.append((node, world, rotation))
        for child in node["children"]:
            walk(child, world, rotation)

    walk(tree, None, None)
    return result


class Obj:
    """A Wavefront .obj's vertices, texture coordinates, normals and faces (1-based, resolved)."""

    def __init__(self, path):
        self.v, self.vt, self.vn, self.f = [], [], [], []
        for raw in open(path, "rb"):
            line = raw.decode("latin-1").split()
            if not line:
                continue
            if line[0] == "v":
                self.v.append(tuple(float(x) for x in line[1:4]))
            elif line[0] == "vt":
                self.vt.append(tuple(float(x) for x in line[1:3]))
            elif line[0] == "vn":
                self.vn.append(tuple(float(x) for x in line[1:4]))
            elif line[0] == "f":
                face = []
                for token in line[1:]:
                    parts = (token.split("/") + ["", ""])[:3]
                    counts = (len(self.v), len(self.vt), len(self.vn))
                    face.append(tuple((int(x) if int(x) > 0 else counts[k] + 1 + int(x)) if x else 0 for k, x in enumerate(parts)))
                self.f.append(face)


class Cache:
    """Tabletop Simulator's cache: the .obj meshes, asset bundles and images, by cache key. The
    meshes are big, so only the last one read is kept."""

    def __init__(self, tts):
        self.tts = tts
        self.images = self._index("Images")
        self._last = (None, None)

    def _index(self, folder):
        path = os.path.join(self.tts, folder)
        return {os.path.splitext(n)[0]: os.path.join(path, n) for n in os.listdir(path)} if os.path.isdir(path) else {}

    def _keep(self, key, read):
        if self._last[0] != key:
            self._last = (key, read())
        return self._last[1]

    def pieces(self, node):
        """The pieces of a node's mesh (see bundles.load), or [] if it isn't cached."""
        if node["bundle"]:
            path = os.path.join(self.tts, "Assetbundles", node["bundle"] + ".unity3d")
            if not os.path.exists(path):
                return []
            import bundles  # needs UnityPy, only for asset bundles
            return self._keep(path, lambda: bundles.load(path))
        path = os.path.join(self.tts, "Models", node["mesh"] + ".obj")
        if not os.path.exists(path):
            return []
        obj = self._keep(path, lambda: Obj(path))
        texture = ("image", node["diffuse"]) if node["diffuse"] in self.images else None
        return [{"v": obj.v, "vt": obj.vt, "vn": obj.vn, "f": obj.f, "fm": None,
                 "materials": [{"texture": texture, "color": node["color"]}]}]

    def image(self, texture):
        if texture[0] == "image":
            return Image.open(self.images[texture[1]])
        import bundles
        return bundles.texture_image(texture)


def transform_point(m, p):
    # File space to Unity space mirrors X; back again after the transform.
    x, y, z = -p[0], p[1], p[2]
    return (-(m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3]),
            m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3],
            m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3])


def material_key(material):
    return (material["texture"], tuple(round(c, 3) for c in material["color"]))


def assemble(tree, cache):
    """The model's pieces as one mesh in its main piece's frame (the main piece's rotation undone, so
    its front stays -Z), centred on the root, or None if it's only flat pieces. Faces keep their
    pieces' materials: fm[i] indexes face i's in materials."""
    parts = []
    for node, world, rotation in pieces(tree):
        for piece in cache.pieces(node):
            points = [transform_point(world, p) for p in piece["v"]]
            if not points:
                continue
            height = max(p[1] for p in points) - min(p[1] for p in points)
            if height <= FLAT:
                continue
            normals = [transform_point([r + [0] for r in rotation] + [[0, 0, 0, 1]], n) for n in piece["vn"]]
            parts.append({**piece, "v": points, "vn": normals, "rotation": rotation, "size": len(points)})
    if not parts:
        return None
    main = max(parts, key=lambda p: p["size"])
    # Undo the main piece's turn about the vertical axis (in file space, where X is mirrored).
    r = main["rotation"]
    yaw = math.atan2(r[0][2], r[2][2])
    c, s = math.cos(yaw), math.sin(yaw)

    def unturn(p):
        x, y, z = -p[0], p[1], p[2]
        x, z = c * x - s * z, s * x + c * z
        return (-x, y, z)

    out = {"v": [], "vt": [], "vn": [], "f": [], "fm": [], "materials": []}
    keys = {}
    for part in parts:
        ov, ot, on = len(out["v"]), len(out["vt"]), len(out["vn"])
        out["v"] += [unturn(p) for p in part["v"]]
        out["vt"] += part["vt"]
        out["vn"] += [unturn(n) for n in part["vn"]]
        index = []
        for material in part["materials"]:
            key = material_key(material)
            if key not in keys:
                keys[key] = len(out["materials"])
                out["materials"].append(material)
            index.append(keys[key])
        for i, face in enumerate(part["f"]):
            out["f"].append([(a + ov if a else 0, b + ot if b else 0, cc + on if cc else 0) for a, b, cc in face])
            out["fm"].append(index[part["fm"][i] if part["fm"] else 0])
    return out


# ---------------------------------------------------------------------------------------------
# Writing a model


class Textures:
    """The textures written so far, by texture: each is written once, scaled down, next to the first
    model that uses it, in its folder's textures/, as a .jpg, or a .png if it's a cutout."""

    def __init__(self, cache, out, dry):
        self.cache, self.out, self.dry = cache, out, dry
        self.written = {}  # texture -> (path from out, cutout) or None if it can't be read
        self.names = set()

    def get(self, texture, folder, stem):
        if texture not in self.written:
            self.written[texture] = self._write(texture, folder, stem)
        return self.written[texture]

    def _write(self, texture, folder, stem):
        try:
            image = self.cache.image(texture)
            image.load()
        except Exception as error:  # a missing or unreadable image leaves the model untextured
            print(f"texture {texture}: {error}", file=sys.stderr)
            return None
        cutout = False
        if image.mode in ("RGBA", "LA", "PA") or (image.mode == "P" and "transparency" in image.info):
            image = image.convert("RGBA")
            cutout = image.getchannel("A").getextrema()[0] < CUTOUT_ALPHA
        image = image.convert("RGBA" if cutout else "RGB")
        image.thumbnail((TEXTURE_SIZE, TEXTURE_SIZE), Image.Resampling.LANCZOS)
        n, name = 1, stem
        while f"{folder}/textures/{name}" in self.names:
            n += 1
            name = f"{stem}_t{n}"
        self.names.add(f"{folder}/textures/{name}")
        path = f"{folder}/textures/{name}.{'png' if cutout else 'jpg'}"
        if not self.dry:
            os.makedirs(os.path.join(self.out, folder, "textures"), exist_ok=True)
            if cutout:
                image.save(os.path.join(self.out, path), optimize=True)
            else:
                image.save(os.path.join(self.out, path), quality=85, optimize=True)
            # Mipmaps and VRAM compression, as for any texture on a 3D model. Detecting 3D use is
            # off, or the editor reimports every texture again when it first loads the models.
            with open(os.path.join(self.out, path + ".import"), "w") as file:
                file.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
                           "[params]\n\ncompress/mode=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n")
        return path, cutout


def write_model(mesh, folder, stem, out, textures):
    """[mesh] as out/folder/stem.obj, with its materials in stem.mtl. Materials are named for their
    texture (or colour); a cutout's name ends in _cutout (ModelLibrary turns on alpha scissor)."""
    names = []
    with open(os.path.join(out, folder, stem + ".mtl"), "w") as mtl:
        for i, material in enumerate(mesh["materials"]):
            texture = textures.get(material["texture"], folder, stem) if material["texture"] else None
            name = f"{stem}_{i + 1}" + ("_cutout" if texture and texture[1] else "")
            names.append(name)
            r, g, b = material["color"]
            mtl.write(f"newmtl {name}\nKd {r:.3f} {g:.3f} {b:.3f}\n")
            if texture:
                mtl.write(f"map_Kd {os.path.relpath(texture[0], folder)}\n")
            mtl.write("\n")
    groups = defaultdict(list)
    for face, m in zip(mesh["f"], mesh["fm"]):
        groups[m].append(face)
    with open(os.path.join(out, folder, stem + ".obj"), "w") as file:
        file.write(f"# Assembled by tools/tts_models/build_models.py\nmtllib {stem}.mtl\no {stem}\n")
        file.writelines(f"v {x:.4f} {y:.4f} {z:.4f}\n" for x, y, z in mesh["v"])
        file.writelines(f"vt {u:.4f} {v:.4f}\n" for u, v in mesh["vt"])
        file.writelines(f"vn {x:.3f} {y:.3f} {z:.3f}\n" for x, y, z in mesh["vn"])
        for m, faces in sorted(groups.items()):
            # Godot can't import a surface whose faces only some have normals (or UVs), as when a
            # piece without them joins one with: then they're left out for the whole surface.
            corners = [corner for face in faces for corner in face]
            uvs = all(b for _, b, _ in corners)
            normals = all(c for _, _, c in corners)
            file.write(f"usemtl {names[m]}\n")
            for face in faces:
                file.write("f " + " ".join(
                    f"{a}/{b}/{c}" if uvs and normals else f"{a}//{c}" if normals else f"{a}/{b}" if uvs else str(a)
                    for a, b, c in face) + "\n")


def signature(tree):
    def round_t(t):
        return tuple(round(t.get(k, 0.0) or 0.0, 2) for k in ("rotX", "rotY", "rotZ", "scaleX", "scaleY", "scaleZ")) + \
               tuple(round(t.get(k, 0.0) or 0.0, 2) for k in ("posX", "posY", "posZ"))

    def sig(node, root):
        return (node["mesh"], node["bundle"], node["diffuse"], () if root else round_t(node["t"]),
                tuple(sorted(sig(c, False) for c in node["children"])))

    t = tree["t"]
    return (sig(tree, True), tuple(round(t.get(k, 1.0) or 1.0, 2) for k in ("scaleX", "scaleY", "scaleZ")))


# ---------------------------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("tts", help="Tabletop Simulator's Mods folder, e.g. ~/Library/Tabletop Simulator/Mods")
    parser.add_argument("save", nargs="?", default=MOD, help="the mod's workshop id, or a path to its save")
    parser.add_argument("--out", default=os.path.join(ROOT, "assets", "3d", "models"))
    parser.add_argument("--overrides", default=os.path.join(HERE, "overrides.json"))
    parser.add_argument("--dry", action="store_true", help="report what would be written")
    args = parser.parse_args()
    args.tts = os.path.expanduser(args.tts)
    save_path = os.path.join(args.tts, "Workshop", args.save + ".json") if args.save.isdigit() else args.save

    warscrolls = Warscrolls()
    overrides = json.load(open(args.overrides))
    names = {}
    units = defaultdict(list)  # target -> [(nickname, tree)]
    unmatched = Counter()
    seen = set()
    for model in definitions(json.load(open(save_path))):
        target = match(model["name"], model["tile"], warscrolls, overrides, names)
        if not target:
            unmatched[(model["tile"], model["name"])] += 1
            continue
        if target == "skip":
            continue
        key = (target, signature(model["tree"]))
        if key in seen:
            continue
        seen.add(key)
        units[target].append((model["name"], model["tree"]))

    report = {"unmatched": sorted(f"{t} :: {n}" for t, n in unmatched), "units": {}}
    if not args.dry and os.path.isdir(args.out):
        for path in glob.glob(os.path.join(args.out, "*")):
            shutil.rmtree(path) if os.path.isdir(path) else os.remove(path)
    cache = Cache(args.tts)
    textures = Textures(cache, args.out, args.dry)
    for target, models in sorted(units.items()):
        folder = warscrolls.folder(target)
        name = slug(target.split(":", 2)[2] if target.startswith("x:") else target)
        meshes = []
        for nickname, tree in sorted(models, key=lambda m: m[0]):
            mesh = assemble(tree, cache)
            if mesh:
                meshes.append((nickname, mesh))
        files = []
        for i, (nickname, mesh) in enumerate(meshes):
            stem = name if len(meshes) == 1 else f"{name}_{i + 1}"
            files.append({"file": f"{folder}/{stem}.obj", "nickname": nickname})
            if args.dry:
                for material in mesh["materials"]:
                    if material["texture"]:
                        textures.written.setdefault(material["texture"], None)
            else:
                os.makedirs(os.path.join(args.out, folder), exist_ok=True)
                write_model(mesh, folder, stem, args.out, textures)
        report["units"][target] = files
        print(f"{target}: {len(files)}", file=sys.stderr)
    report["textures"] = len(textures.written)
    json.dump(report, sys.stdout, indent=1)


if __name__ == "__main__":
    main()
