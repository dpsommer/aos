"""Reads the meshes and textures of Tabletop Simulator asset bundles (.unity3d), for models a mod
ships as asset bundles rather than .obj files. Needs UnityPy, which needs a Python built with lzma.

Each rendered mesh (one on a MeshFilter with an enabled MeshRenderer, not a collider) is a piece in
the same space as Tabletop Simulator's .obj models: X mirrored from Unity's, as Unity imports .obj
files. A piece's faces each have a material: the texture (_MainTex) and colour (_Color) of the
renderer's material for the face's submesh.
"""

import UnityPy
from UnityPy.helpers.MeshHelper import MeshHandler


def _quat_rotate(q, v):
    x, y, z, w = q.x, q.y, q.z, q.w
    vx, vy, vz = v
    # v' = q v q*
    tx, ty, tz = 2 * (y * vz - z * vy), 2 * (z * vx - x * vz), 2 * (x * vy - y * vx)
    return (vx + w * tx + (y * tz - z * ty), vy + w * ty + (z * tx - x * tz), vz + w * tz + (x * ty - y * tx))


def _chain(transform):
    """[transform] and its parents, innermost first."""
    result = []
    while transform is not None:
        result.append(transform)
        father = transform.m_Father
        transform = father.read() if father and father.path_id else None
    return result


def _to_root(chain, v, scale=True):
    for t in chain:
        if scale:
            s = t.m_LocalScale
            v = (v[0] * s.x, v[1] * s.y, v[2] * s.z)
        v = _quat_rotate(t.m_LocalRotation, v)
        if scale:
            p = t.m_LocalPosition
            v = (v[0] + p.x, v[1] + p.y, v[2] + p.z)
    return v


def _material(bundle_path, ref):
    """{"texture": (bundle path, texture path id) or None, "color": (r, g, b)} for a Material."""
    texture, color = None, (1.0, 1.0, 1.0)
    if not ref or not ref.path_id:
        return {"texture": None, "color": color}
    try:
        material = ref.read()
    except FileNotFoundError:  # one of Unity's built-in materials
        return {"texture": None, "color": color}
    properties = material.m_SavedProperties
    for name, env in properties.m_TexEnvs:
        if name == "_MainTex" and env.m_Texture and env.m_Texture.path_id:
            texture = (bundle_path, env.m_Texture.path_id)
    for name, c in properties.m_Colors:
        if name == "_Color":
            color = (c.r, c.g, c.b)
    return {"texture": texture, "color": color}


def load(bundle_path):
    """The bundle's pieces, each {"v", "vt", "vn", "f", "fm", "materials"}: faces are lists of
    (v, vt, vn) corners, 1-based (0 when missing), and fm[i] indexes face i's material."""
    env = UnityPy.load(bundle_path)
    renderers = {}
    for obj in env.objects:
        if obj.type.name == "MeshRenderer":
            renderer = obj.read()
            if renderer.m_Enabled:
                renderers[renderer.m_GameObject.path_id] = renderer
    pieces = []
    for obj in env.objects:
        if obj.type.name != "MeshFilter":
            continue
        mesh_filter = obj.read()
        renderer = renderers.get(mesh_filter.m_GameObject.path_id)
        if renderer is None or not mesh_filter.m_Mesh or not mesh_filter.m_Mesh.path_id:
            continue
        game_object = mesh_filter.m_GameObject.read()
        if not game_object.m_IsActive:
            continue
        try:
            mesh = mesh_filter.m_Mesh.read()
        except FileNotFoundError:
            continue  # one of Unity's built-in meshes (a cube or quad), not part of the model
        handler = MeshHandler(mesh)
        handler.process()
        if not handler.m_Vertices:
            continue
        chain = _chain(game_object.m_Transform.read())
        piece = {"v": [], "vt": [], "vn": [], "f": [], "fm": [], "materials": []}
        for p in handler.m_Vertices:
            wx, wy, wz = _to_root(chain, (p[0], p[1], p[2]))
            piece["v"].append((-wx, wy, wz))
        uvs = bool(handler.m_UV0)
        if uvs:
            piece["vt"] = [(uv[0], uv[1]) for uv in handler.m_UV0]
        normals = bool(handler.m_Normals)
        if normals:
            for n in handler.m_Normals:  # sometimes with a fourth component
                wx, wy, wz = _to_root(chain, (n[0], n[1], n[2]), scale=False)
                piece["vn"].append((-wx, wy, wz))
        materials = list(renderer.m_Materials)
        for i, triangles in enumerate(handler.get_triangles()):
            if i >= len(materials):
                break  # Unity doesn't draw submeshes past the renderer's materials
            piece["materials"].append(_material(bundle_path, materials[i]))
            m = len(piece["materials"]) - 1
            for a, b, c in triangles:
                # Mirroring X flips the winding, so the corners go in reverse.
                piece["f"].append([(k + 1, k + 1 if uvs else 0, k + 1 if normals else 0) for k in (c, b, a)])
                piece["fm"].append(m)
        if piece["f"]:
            pieces.append(piece)
    return pieces


_texture_env = {}


def texture_image(texture):
    """The PIL image of a texture from [load]'s materials."""
    bundle_path, path_id = texture
    if bundle_path not in _texture_env:
        _texture_env.clear()
        _texture_env[bundle_path] = UnityPy.load(bundle_path)
    env = _texture_env[bundle_path]
    for obj in env.objects:
        if obj.path_id == path_id:
            return obj.read().image
    raise KeyError(f"no texture {path_id} in {bundle_path}")
