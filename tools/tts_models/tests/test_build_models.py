import json, os, sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import build_models


def spearhead_pieces(tmp_path, monkeypatch):
    """SpearheadPieces over one tiny battlepack in a temporary data folder."""
    folder = tmp_path / "core" / "spearhead"
    folder.mkdir(parents=True)
    pack = {
        "terrain_features": [{"name": "Crypt of Blood"}, {"name": "Ruined Wall"}],
        "relics": [{"name": "Golden Idol"}],
        "realms": [{"name": "Ashen Bastion"}],
    }
    (folder / "pack.json").write_text(json.dumps(pack))
    monkeypatch.setattr(build_models, "DATA", str(tmp_path))
    return build_models.SpearheadPieces()


def model(name, mesh="mesh", states=None, contained=None, lua=None):
    obj = {"Name": "Custom_Model", "Nickname": name, "CustomMesh": {"MeshURL": mesh}}
    if states:
        obj["States"] = {str(i + 2): s for i, s in enumerate(states)}
    if contained:
        obj["ContainedObjects"] = contained
    if lua:
        obj["LuaScript"] = lua
    return obj


def names(definitions):
    return sorted(d["name"] for d in definitions)


# SpearheadPieces

def test_model_matches_terrain_feature_name(tmp_path, monkeypatch):
    assert spearhead_pieces(tmp_path, monkeypatch).model("Ruined Wall", {}) == "Ruined Wall"


def test_model_ignores_a_bracketed_suffix(tmp_path, monkeypatch):
    assert spearhead_pieces(tmp_path, monkeypatch).model("Crypt of Blood (Ossia)", {}) == "Crypt of Blood"


def test_model_matches_relics(tmp_path, monkeypatch):
    assert spearhead_pieces(tmp_path, monkeypatch).model("golden idol", {}) == "Golden Idol"


def test_model_override_wins(tmp_path, monkeypatch):
    pieces = spearhead_pieces(tmp_path, monkeypatch)
    assert pieces.model("Ruined Wall", {"Ruined Wall": "skip"}) == "skip"


def test_model_override_names_an_otherwise_unknown_nickname(tmp_path, monkeypatch):
    pieces = spearhead_pieces(tmp_path, monkeypatch)
    assert pieces.model("Odd Name", {"Odd Name": "Ruined Wall"}) == "Ruined Wall"


def test_unknown_model_is_none(tmp_path, monkeypatch):
    assert spearhead_pieces(tmp_path, monkeypatch).model("Scoresheet", {}) is None


def test_realm_matches_name(tmp_path, monkeypatch):
    assert spearhead_pieces(tmp_path, monkeypatch).realm("ashen bastion") == "Ashen Bastion"


def test_realm_ignores_a_bracketed_suffix(tmp_path, monkeypatch):
    assert spearhead_pieces(tmp_path, monkeypatch).realm("Ashen Bastion (Side B)") == "Ashen Bastion"


def test_unknown_realm_is_none(tmp_path, monkeypatch):
    assert spearhead_pieces(tmp_path, monkeypatch).realm("Nowhere") is None


# definitions

def test_top_level_definitions_ignore_contained_objects():
    save = {"ObjectStates": [{"Name": "Bag", "Nickname": "Bag", "ContainedObjects": [model("Inside")]}]}
    assert names(build_models.definitions(save, top_level=True)) == []


def test_top_level_definitions_ignore_lua_spawned_models():
    lua = '[[{"Name": "Custom_Model", "Nickname": "Spawned", "CustomMesh": {"MeshURL": "m"}}]]'
    save = {"ObjectStates": [{"Name": "Tile", "Nickname": "Tile", "LuaScript": lua}]}
    assert names(build_models.definitions(save, top_level=True)) == []


def test_top_level_definitions_include_states():
    save = {"ObjectStates": [model("Main", states=[model("Other")])]}
    assert names(build_models.definitions(save, top_level=True)) == ["Main", "Other"]


def test_definitions_include_contained_objects_by_default():
    save = {"ObjectStates": [{"Name": "Bag", "Nickname": "Bag", "ContainedObjects": [model("Inside")]}]}
    assert names(build_models.definitions(save)) == ["Inside"]


def test_definitions_include_lua_spawned_models_by_default():
    lua = '[[{"Name": "Custom_Model", "Nickname": "Spawned", "CustomMesh": {"MeshURL": "m"}}]]'
    save = {"ObjectStates": [{"Name": "Tile", "Nickname": "Tile", "LuaScript": lua}]}
    assert names(build_models.definitions(save)) == ["Spawned"]


# boards

def tile(name, url, states=None):
    obj = {"Name": "Custom_Tile", "Nickname": name, "CustomImage": {"ImageURL": url}}
    if states:
        obj["States"] = {str(i + 2): s for i, s in enumerate(states)}
    return obj


def test_boards_are_the_image_tiles():
    save = {"ObjectStates": [tile("Aqshy", "http://x/a.jpg")]}
    assert build_models.boards(save) == [("Aqshy", build_models.mesh_key("http://x/a.jpg"))]


def test_boards_include_a_tiles_other_states():
    save = {"ObjectStates": [tile("Aqshy", "http://x/a", states=[tile("Ghur", "http://x/g")])]}
    assert [name for name, _ in build_models.boards(save)] == ["Aqshy", "Ghur"]


def test_boards_skip_other_objects_and_tiles_without_images():
    save = {"ObjectStates": [model("Wall"), {"Name": "Custom_Tile", "Nickname": "Blank", "CustomImage": {}}]}
    assert build_models.boards(save) == []


def test_boards_strip_the_nickname():
    save = {"ObjectStates": [tile("  Aqshy ", "http://x/a")]}
    assert build_models.boards(save)[0][0] == "Aqshy"


# Files.remove_stale

def make(root, *paths):
    for path in paths:
        full = root / path
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text("x")


def test_remove_stale_deletes_unmade_files_within(tmp_path):
    make(tmp_path, "shared/spearhead/old.obj", "shared/spearhead/old.obj.import")
    files = build_models.Files(str(tmp_path), False)
    assert files.remove_stale(within="shared/spearhead") == 2
    assert not (tmp_path / "shared/spearhead/old.obj").exists()


def test_remove_stale_keeps_files_that_were_made(tmp_path):
    make(tmp_path, "shared/spearhead/new.obj", "shared/spearhead/new.obj.import")
    files = build_models.Files(str(tmp_path), False)
    files.made.add("shared/spearhead/new.obj")
    assert files.remove_stale(within="shared/spearhead") == 0
    assert (tmp_path / "shared/spearhead/new.obj.import").exists()


def test_remove_stale_leaves_files_outside_within(tmp_path):
    make(tmp_path, "order/unit.obj")
    build_models.Files(str(tmp_path), False).remove_stale(within="shared/spearhead")
    assert (tmp_path / "order/unit.obj").exists()


def test_remove_stale_never_touches_the_left_folders(tmp_path):
    make(tmp_path, "shared/spearhead/terrain.obj", "order/unit.obj")
    files = build_models.Files(str(tmp_path), False)
    assert files.remove_stale(leave=("shared/spearhead",)) == 1
    assert (tmp_path / "shared/spearhead/terrain.obj").exists()
    assert not (tmp_path / "order/unit.obj").exists()


def test_remove_stale_removes_emptied_folders_but_not_within(tmp_path):
    make(tmp_path, "shared/spearhead/sub/old.obj")
    build_models.Files(str(tmp_path), False).remove_stale(within="shared/spearhead")
    assert not (tmp_path / "shared/spearhead/sub").exists()
    assert (tmp_path / "shared/spearhead").exists()


def test_remove_stale_dry_run_deletes_nothing(tmp_path):
    make(tmp_path, "old.obj")
    assert build_models.Files(str(tmp_path), True).remove_stale() == 1
    assert (tmp_path / "old.obj").exists()


# assemble

class FakeCache:
    """One piece: a triangle [height] tall."""

    def __init__(self, height):
        self.height = height

    def pieces(self, node):
        return [{"v": [[0, 0, 0], [1, 0, 0], [0, self.height, 0]], "vt": [], "vn": [], "f": [[(1, 0, 0), (2, 0, 0), (3, 0, 0)]],
                 "fm": [], "materials": [{"texture": None, "color": (1, 1, 1)}]}]


TREE = {"mesh": "m", "bundle": "", "diffuse": "", "color": (1, 1, 1), "t": {}, "children": []}


def test_assemble_drops_a_flat_piece_by_default():
    assert build_models.assemble(TREE, FakeCache(build_models.FLAT / 2)) is None


def test_assemble_keeps_a_flat_piece_with_no_flat_limit():
    assert build_models.assemble(TREE, FakeCache(build_models.FLAT / 2), flat=0.0) is not None


def test_assemble_keeps_a_tall_piece_by_default():
    assert build_models.assemble(TREE, FakeCache(build_models.FLAT * 4)) is not None


# turns

def turned(name, degrees, **kwargs):
    obj = model(name, **kwargs)
    obj["Transform"] = {"rotY": degrees}
    return obj


def test_definitions_record_the_roots_turn():
    save = {"ObjectStates": [turned("Main", 180.0)]}
    assert build_models.definitions(save)[0]["tree"]["turn"] == 180.0


def test_a_state_takes_the_turn_of_the_object_it_replaces():
    save = {"ObjectStates": [turned("Main", 90.0, states=[turned("Other", 0.0)])]}
    turns = {d["name"]: d["tree"]["turn"] for d in build_models.definitions(save)}
    assert turns == {"Main": 90.0, "Other": 90.0}


def test_a_contained_object_keeps_its_own_turn():
    bag = turned("Bag", 90.0)
    bag["Name"] = "Bag"
    bag["ContainedObjects"] = [turned("Inside", 45.0)]
    save = {"ObjectStates": [bag]}
    assert build_models.definitions(save)[0]["tree"]["turn"] == 45.0


def front_of(mesh):
    """The mesh's furthest point along -Z."""
    return min(mesh["v"], key=lambda p: p[2])


class PointerCache:
    """One tall piece whose tip points along +Z in the mesh's file."""

    def pieces(self, node):
        return [{"v": [[0, 0, 0], [0, 1, 0], [0, 0, 2]], "vt": [], "vn": [], "f": [[(1, 0, 0), (2, 0, 0), (3, 0, 0)]],
                 "fm": [], "materials": [{"texture": None, "color": (1, 1, 1)}]}]


def test_assemble_takes_the_roots_turn():
    mesh = build_models.assemble({**TREE, "turn": 180.0}, PointerCache())
    assert front_of(mesh)[2] < -1.9


def test_assemble_without_turn_keeps_the_meshes_frame():
    mesh = build_models.assemble({**TREE, "turn": 180.0}, PointerCache(), turn=False)
    assert front_of(mesh)[2] > -0.1


def test_assemble_ignores_the_roots_tilt():
    tree = {**TREE, "t": {"rotX": 90.0, "rotZ": 90.0}, "turn": 0.0}
    mesh = build_models.assemble(tree, PointerCache())
    assert max(p[1] for p in mesh["v"]) > 0.9


def test_turn_of_is_the_commonest_turn():
    assert build_models.turn_of(Counter({90: 3, 240: 1}), oval=False) == 90


def test_turn_of_an_oval_based_model_keeps_a_half_turn():
    assert build_models.turn_of(Counter({180: 1}), oval=True) == 180


def test_turn_of_an_oval_based_model_drops_a_quarter_turn():
    assert build_models.turn_of(Counter({90: 1}), oval=True) == 0
    assert build_models.turn_of(Counter({270: 1}), oval=True) == 0


def test_turn_of_an_oval_based_model_rounds_to_the_nearest_half_turn():
    assert build_models.turn_of(Counter({240: 1}), oval=True) == 180
    assert build_models.turn_of(Counter({75: 1}), oval=True) == 0


def test_turn_mesh_turns_the_front_to_the_side():
    mesh = {"v": [(0.0, 1.0, -1.0)], "vn": [(0.0, 0.0, -1.0)]}
    build_models.turn_mesh(mesh, 90)
    assert [round(c, 6) for c in mesh["v"][0]] == [-1.0, 1.0, 0.0]
    assert [round(c, 6) for c in mesh["vn"][0]] == [-1.0, 0.0, 0.0]


def test_turn_mesh_half_turn_faces_the_back():
    mesh = {"v": [(0.0, 0.0, -1.0)], "vn": []}
    build_models.turn_mesh(mesh, 180)
    assert [round(c, 6) for c in mesh["v"][0]] == [0.0, 0.0, 1.0]
