"""Builds assets/3d/models/ from a Tabletop Simulator mod in Tabletop Simulator's cache.

Usage (from the project root, in the "aos" pyenv virtualenv with requirements.txt installed):

    python -I tools/tts_models/build_models.py <Mods folder> [<workshop id or save path>] [--only <warscroll>] [--out assets/3d/models] [--dry]

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
import hashlib
import io
import json
import math
import os
import re
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


def local_matrix(t, translate=True, rotate=True):
    """A Unity transform (Euler degrees applied Z, X, then Y) as a 4x4 matrix, and its rotation."""
    rx, ry, rz = (math.radians(t.get(k, 0.0) or 0.0) if rotate else 0.0 for k in ("rotX", "rotY", "rotZ"))
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    mx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    my = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    mz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    r = [[sum(my[i][k] * sum(mx[k][m] * mz[m][j] for m in range(3)) for k in range(3)) for j in range(3)] for i in range(3)]
    s = [t.get(k, 1.0) or 1.0 for k in ("scaleX", "scaleY", "scaleZ")]
    p = [t.get(k, 0.0) or 0.0 for k in ("posX", "posY", "posZ")] if translate else [0, 0, 0]
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], p[i]] for i in range(3)] + [[0, 0, 0, 1]], [row[:] for row in r]


def pieces(tree):
    """Each mesh of a model (its node) with its matrix from the mesh's file to the root's frame (the
    root's scale applied, but not its position or rotation, which only place it on the table), and
    its rotation alone."""
    result = []

    def walk(node, parent, parent_rotation):
        m, r = local_matrix(node["t"], translate=parent is not None, rotate=parent is not None)
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
        self.bundle_textures = {}  # bundle path -> its textures' path ids, sorted

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
            result = self._keep(path, lambda: bundles.load(path))
            self.bundle_textures.setdefault(path, sorted({m["texture"][1] for p in result for m in p["materials"] if m["texture"]}))
            return result
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
    """The model's pieces as one mesh in its root's frame, or None if it's only flat pieces. The mod
    turns each piece to face the root's front, -Z, and lines it up with the root's base (a ship
    along its oval), so pieces keep their turn. Faces keep their pieces' materials: fm[i] indexes
    face i's in materials."""
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
            parts.append({**piece, "v": points, "vn": normals})
    if not parts:
        return None
    out = {"v": [], "vt": [], "vn": [], "f": [], "fm": [], "materials": []}
    keys = {}
    for part in parts:
        ov, ot, on = len(out["v"]), len(out["vt"]), len(out["vn"])
        out["v"] += part["v"]
        out["vt"] += part["vt"]
        out["vn"] += part["vn"]
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
    """Writes each texture once, scaled down, as a .jpg, or a .png if it's a cutout, in the textures/
    of the folder of the first model in the save that uses it, named for that model (see
    [owners]), so where a texture goes doesn't depend on which models are built."""

    def __init__(self, cache, out, owners, files):
        self.cache, self.out, self.owners, self.files = cache, out, owners, files
        self.written = {}  # texture -> (path from out, cutout) or None if it can't be read

    def get(self, texture):
        if texture not in self.written:
            self.written[texture] = self._write(texture)
        return self.written[texture]

    def _name(self, texture):
        if texture[0] == "image":
            return self.owners[("image", texture[1])]
        bundle_path, path_id = texture
        folder, name = self.owners[("bundle", os.path.splitext(os.path.basename(bundle_path))[0])]
        k = self.cache.bundle_textures[bundle_path].index(path_id)
        return folder, name if k == 0 else f"{name}_{k + 1}"

    def _write(self, texture):
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
        folder, name = self._name(texture)
        path = f"{folder}/textures/{name}.{'png' if cutout else 'jpg'}"
        data = io.BytesIO()
        if cutout:
            image.save(data, "PNG", optimize=True)
        else:
            image.save(data, "JPEG", quality=85, optimize=True)
        self.files.write(path, data.getvalue())
        # Mipmaps and VRAM compression, as for any texture on a 3D model. Detecting 3D use is off,
        # or the editor reimports every texture again when it first loads the models. Written only
        # once: Godot adds the texture's uid to it.
        self.files.write(path + ".import", '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
                         "[params]\n\ncompress/mode=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n",
                         keep=True)
        return path, cutout


class Files:
    """Writes files under [out] only when their content changes, so Godot reimports only what did,
    and remembers what was written, so a full build can delete what it no longer makes."""

    def __init__(self, out, dry):
        self.out, self.dry = out, dry
        self.made = set()  # paths from out
        self.changed = []

    def write(self, path, data, keep=False):
        """Writes [data] (str or bytes) to out/path unless it's already there (or, with [keep], unless
        the file exists at all)."""
        self.made.add(path)
        full = os.path.join(self.out, path)
        data = data.encode() if isinstance(data, str) else data
        if os.path.exists(full) and (keep or open(full, "rb").read() == data):
            return
        self.changed.append(path)
        if not self.dry:
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "wb") as file:
                file.write(data)
            # Godot doesn't retry a file whose last import failed, even when it changes.
            imported = full + ".import"
            if os.path.exists(imported):
                text = open(imported).read()
                if "\nvalid=false\n" in text:
                    with open(imported, "w") as file:
                        file.write(text.replace("\nvalid=false\n", "\n"))

    def remove_stale(self):
        """Deletes the files under out that the build didn't make (and Godot's .import files of
        those), and empty folders. Returns how many."""
        removed = 0
        for folder, dirs, names in os.walk(self.out, topdown=False):
            for name in names:
                path = os.path.relpath(os.path.join(folder, name), self.out)
                source = path[: -len(".import")] if path.endswith(".import") else path
                if source not in self.made:
                    removed += 1
                    if not self.dry:
                        os.remove(os.path.join(folder, name))
            if not self.dry and folder != self.out and not os.listdir(folder):
                os.rmdir(folder)
        return removed


def texture_owners(units, warscrolls):
    """Where each texture goes, by its source (("image", key) or ("bundle", key) for all of an asset
    bundle's): (folder, name) of the first model in the save that uses it, in the order models
    are built, as its name; a model's later textures are <name>_t2 and so on."""
    owners, count = {}, Counter()
    for target, models in sorted(units.items()):
        folder, name = warscrolls.folder(target), target_slug(target)
        for i, (nickname, tree) in enumerate(sorted(models, key=lambda m: m[0])):
            stem = name if len(models) == 1 else f"{name}_{i + 1}"
            for node, _, _ in pieces(tree):
                source = ("bundle", node["bundle"]) if node["bundle"] else ("image", node["diffuse"]) if node["diffuse"] else None
                if source and source not in owners:
                    count[(folder, stem)] += 1
                    n = count[(folder, stem)]
                    owners[source] = (folder, stem if n == 1 else f"{stem}_t{n}")
    return owners


def target_slug(target):
    return slug(target.split(":", 2)[2] if target.startswith("x:") else target)


def write_model(mesh, folder, stem, files, textures):
    """[mesh] as folder/stem.obj, with its materials in stem.mtl. Materials are named for their
    texture (or colour); a cutout's name ends in _cutout (ModelLibrary turns on alpha scissor)."""
    names, mtl = [], []
    for i, material in enumerate(mesh["materials"]):
        texture = textures.get(material["texture"]) if material["texture"] else None
        name = f"{stem}_{i + 1}" + ("_cutout" if texture and texture[1] else "")
        names.append(name)
        r, g, b = material["color"]
        mtl.append(f"newmtl {name}\nKd {r:.3f} {g:.3f} {b:.3f}\n")
        if texture:
            mtl.append(f"map_Kd {os.path.relpath(texture[0], folder)}\n")
        mtl.append("\n")
    mtl = "".join(mtl)
    files.write(f"{folder}/{stem}.mtl", mtl)
    complete(mesh)
    groups = defaultdict(list)
    for face, m in zip(mesh["f"], mesh["fm"]):
        groups[m].append(face)
    # Godot doesn't reimport an .obj when only its .mtl changes, so the .obj carries the .mtl's hash.
    obj = [f"# Assembled by tools/tts_models/build_models.py (mtl {hashlib.sha1(mtl.encode()).hexdigest()[:12]})\n"
           f"mtllib {stem}.mtl\no {stem}\n"]
    obj += [f"v {x:.4f} {y:.4f} {z:.4f}\n" for x, y, z in mesh["v"]]
    obj += [f"vt {u:.4f} {v:.4f}\n" for u, v in mesh["vt"]]
    obj += [f"vn {x:.3f} {y:.3f} {z:.3f}\n" for x, y, z in mesh["vn"]]
    for m, faces in sorted(groups.items()):
        obj.append(f"usemtl {names[m]}\n")
        obj += ["f " + " ".join(f"{a}/{b}/{c}" for a, b, c in face) + "\n" for face in faces]
    files.write(f"{folder}/{stem}.obj", "".join(obj))


def complete(mesh):
    """Gives every face corner of [mesh] a normal and texture coordinates, as Godot can't import a
    surface whose faces only some have them, nor make tangents for a textured surface without
    normals. A missing normal is the vertex's smooth normal over the faces without normals (their
    corners wind counter-clockwise, as the pieces' own normals agree); a missing UV is (0, 0)."""
    sums = {}
    for face in mesh["f"]:
        if all(c for _, _, c in face):
            continue
        a, b, c = (mesh["v"][corner[0] - 1] for corner in face[:3])
        u = [b[i] - a[i] for i in range(3)]
        w = [c[i] - a[i] for i in range(3)]
        n = (u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0])
        for corner in face:
            if not corner[2]:
                s = sums.setdefault(corner[0], [0.0, 0.0, 0.0])
                for i in range(3):
                    s[i] += n[i]
    index = {}
    for vertex, (x, y, z) in sums.items():
        length = math.sqrt(x * x + y * y + z * z) or 1.0
        mesh["vn"].append((x / length, y / length, z / length) if length > 1e-12 else (0.0, 1.0, 0.0))
        index[vertex] = len(mesh["vn"])
    blank = 0
    if any(not b for face in mesh["f"] for _, b, _ in face):
        mesh["vt"].append((0.0, 0.0))
        blank = len(mesh["vt"])
    mesh["f"] = [[(a, b or blank, c or index[a]) for a, b, c in face] for face in mesh["f"]]


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
    parser.add_argument("--only", action="append", default=[], metavar="NAME",
                        help="build only this warscroll's models (repeatable); nothing is deleted")
    parser.add_argument("--dry", action="store_true", help="report what would be written, changed and removed")
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
    cache = Cache(args.tts)
    files = Files(args.out, args.dry)
    textures = Textures(cache, args.out, texture_owners(units, warscrolls), files)
    only = {norm(name) for name in args.only}
    for target, models in sorted(units.items()):
        name = target_slug(target)
        if only and norm(target) not in only and norm(name) not in only:
            continue
        folder = warscrolls.folder(target)
        meshes = []
        for nickname, tree in sorted(models, key=lambda m: m[0]):
            mesh = assemble(tree, cache)
            if mesh:
                meshes.append((nickname, mesh))
        report["units"][target] = []
        for i, (nickname, mesh) in enumerate(meshes):
            stem = name if len(meshes) == 1 else f"{name}_{i + 1}"
            report["units"][target].append({"file": f"{folder}/{stem}.obj", "nickname": nickname})
            write_model(mesh, folder, stem, files, textures)
        print(f"{target}: {len(meshes)}", file=sys.stderr)
    report["textures"] = len(textures.written)
    report["changed"] = sorted(files.changed)
    if not only:
        report["removed"] = files.remove_stale()
    json.dump(report, sys.stdout, indent=1)


if __name__ == "__main__":
    main()
