"""Build every original 3D asset for Breakout Royale 3D.

    blender -b -P Blender/build_assets.py

Writes editable .blend files next to this script and GLBs into
Assets/Models/props/. Everything is authored from primitives, so the source is
reproducible instead of a binary black box.
"""

import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "Assets", "Models", "props")
BLEND_DIR = os.path.join(ROOT, "Blender")
os.makedirs(MODELS, exist_ok=True)

MATS = {}


def srgb(hex_value):
    value = hex_value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mat(name, color, rough=0.55, metal=0.0, emission=None, strength=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    rgb = srgb(color) if isinstance(color, str) else color
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission:
        er = srgb(emission) if isinstance(emission, str) else emission
        bsdf.inputs["Emission Color"].default_value = (*er, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength or 1.0
    MATS[name] = m
    return m


def _paint(obj, m, name, flat=False):
    obj.name = name
    obj.data.materials.clear()
    if m is not None:
        obj.data.materials.append(m)
    if flat:
        for poly in obj.data.polygons:
            poly.use_smooth = False
    return obj


def box(name, size, loc, m, rot=(0, 0, 0), flat=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _paint(o, m, name, flat)


def sphere(name, radius, loc, m, scale=(1, 1, 1), subdiv=2, flat=False):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _paint(o, m, name, flat)


def cyl(name, radius, depth, loc, m, verts=12, rot=(0, 0, 0), flat=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    return _paint(bpy.context.object, m, name, flat)


def cone(name, r1, r2, depth, loc, m, verts=8, rot=(0, 0, 0), flat=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth,
                                    location=loc, rotation=rot)
    return _paint(bpy.context.object, m, name, flat)


def torus(name, major, minor, loc, m, rot=(0, 0, 0), segments=18, minor_segments=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=segments, minor_segments=minor_segments,
                                     location=loc, rotation=rot)
    return _paint(bpy.context.object, m, name)


def bevel(obj, width=0.055, segments=2):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return joined


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    rna = bpy.ops.export_scene.gltf.get_rna_type().properties
    kwargs = {
        "filepath": path,
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": True,
        "export_yup": True,
        "export_animations": False,
        "export_materials": "EXPORT",
        "export_cameras": False,
        "export_lights": False,
    }
    kwargs = {k: v for k, v in kwargs.items() if k in rna}
    bpy.ops.export_scene.gltf(**kwargs)
    print("exported", os.path.relpath(path, ROOT))


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def palette():
    MATS.clear()
    return {
        "body": mat("shell", "#dfe7f5", 0.28, metal=0.55),
        "trim": mat("trim", "#2b3350", 0.35, metal=0.7),
        "glow": mat("glow", "#bff8ff", 0.3, emission="#63e9ff", strength=3.4),
        "glow_pink": mat("glow_pink", "#ffd6f6", 0.3, emission="#ff3fd8", strength=3.0),
        "glow_amber": mat("glow_amber", "#fff0c8", 0.3, emission="#ffb23d", strength=3.0),
        "brick": mat("brick_body", "#8d93b8", 0.35, metal=0.2),
        "brick_edge": mat("brick_edge", "#f4f7ff", 0.3, emission="#c9d6ff", strength=0.6),
        "steel": mat("steel_body", "#7d8496", 0.22, metal=0.9),
        "dark": mat("dark", "#1a1c2c", 0.4, metal=0.5),
        "crystal": mat("crystal", "#c7b0ff", 0.2, emission="#8f6bff", strength=1.2),
    }


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return palette()


# --------------------------------------------------------------------------
# assets
# --------------------------------------------------------------------------

def build_paddle():
    p = new_scene()
    parts = [
        box("hull", (2.9, 0.42, 0.34), (0, 0, 0), p["body"]),
        box("keel", (2.2, 0.3, 0.16), (0, -0.12, -0.18), p["trim"]),
        box("strip_l", (0.9, 0.1, 0.1), (-0.75, 0.22, 0.05), p["glow"]),
        box("strip_r", (0.9, 0.1, 0.1), (0.75, 0.22, 0.05), p["glow_pink"]),
        box("nose", (0.5, 0.5, 0.2), (0, 0, 0.14), p["trim"]),
        sphere("core", 0.16, (0, 0.16, 0.06), p["glow"], subdiv=1),
    ]
    for side, sign in (("l", 1), ("r", -1)):
        parts.append(cone("fin_" + side, 0.24, 0.02, 0.6, (1.45 * sign, -0.05, -0.02), p["trim"],
                          verts=3, rot=(0, 0.0, 0.0)))
    obj = join(parts, "paddle")
    bevel(obj, 0.04)
    export(obj, os.path.join(MODELS, "paddle.glb"))


def build_ball():
    p = new_scene()
    parts = [
        sphere("core", 0.26, (0, 0, 0), p["glow"], subdiv=2),
        torus("ring", 0.32, 0.022, (0, 0, 0), p["glow_pink"], rot=(math.pi / 2, 0, 0), segments=20),
        torus("ring2", 0.32, 0.018, (0, 0, 0), p["glow_pink"], rot=(0, 0, 0), segments=20),
    ]
    obj = join(parts, "ball")
    export(obj, os.path.join(MODELS, "ball.glb"))


def build_brick(name, thick, accent, plate, p):
    parts = [
        box("body", (0.9, thick, 0.42), (0, 0, 0), p["brick"]),
        box("rim", (0.98, thick * 0.32, 0.5), (0, 0, 0), p["brick_edge"]),
        box("face", (0.72, thick * 0.55, 0.14), (0, thick * 0.28, 0), accent),
    ]
    if plate:
        for i in range(4):
            x = -0.32 + i * 0.21
            parts.append(cyl("rivet%d" % i, 0.045, 0.06, (x, thick * 0.32, 0.09), p["steel"],
                             verts=6, rot=(math.pi / 2, 0, 0)))
    obj = join(parts, name)
    bevel(obj, 0.035)
    export(obj, os.path.join(MODELS, name + ".glb"))


def build_bricks():
    p = new_scene()
    build_brick("brick", 0.44, p["glow"], False, p)
    build_brick("brick_armor", 0.5, p["glow_amber"], True, p)
    build_brick("brick_steel", 0.56, p["dark"], True, p)
    build_brick("brick_bomb", 0.46, p["glow_pink"], False, p)
    build_brick("brick_crystal", 0.44, p["crystal"], False, p)


def build_capsule():
    p = new_scene()
    parts = [
        sphere("shell", 0.3, (0, 0, 0), p["body"], scale=(1.0, 1.0, 1.35), subdiv=2),
        cyl("band", 0.315, 0.1, (0, 0, 0), p["trim"], verts=14, rot=(math.pi / 2, 0, 0)),
        cyl("core", 0.16, 0.34, (0, 0, 0), p["glow_amber"], verts=10),
    ]
    obj = join(parts, "capsule")
    export(obj, os.path.join(MODELS, "capsule.glb"))


def build_boss_core():
    p = new_scene()
    parts = [
        sphere("shell", 1.5, (0, 0, 0), p["body"], scale=(1.0, 0.85, 1.0), subdiv=2),
        torus("ring", 1.6, 0.14, (0, 0, 0), p["steel"], rot=(math.pi / 2, 0, 0), segments=24),
        torus("ring2", 1.35, 0.1, (0, 0, 0), p["trim"], rot=(0, math.pi / 2, 0), segments=22),
        sphere("eye", 0.6, (0, -1.1, 0), p["glow_pink"], scale=(1.0, 0.5, 0.8), subdiv=2),
        sphere("eye_core", 0.3, (0, -1.32, 0), p["glow_amber"], subdiv=2),
    ]
    for i in range(6):
        a = i * math.tau / 6
        parts.append(box("plate%d" % i, (0.5, 0.3, 0.7),
                         (math.cos(a) * 1.35, math.sin(a) * 1.35, 0), p["steel"],
                         rot=(0, 0, a)))
    obj = join(parts, "boss_core")
    export(obj, os.path.join(MODELS, "boss_core.glb"))


def build_arena():
    p = new_scene()
    parts = [
        box("left", (0.36, 0.5, 19.0), (-4.4, 0, 0), p["trim"]),
        box("right", (0.36, 0.5, 19.0), (4.4, 0, 0), p["trim"]),
        box("top", (9.2, 0.5, 0.4), (0, 0, 9.2), p["trim"]),
        box("strip_l", (0.08, 0.14, 18.4), (-4.2, 0.2, 0), p["glow"]),
        box("strip_r", (0.08, 0.14, 18.4), (4.2, 0.2, 0), p["glow"]),
        box("strip_t", (8.8, 0.14, 0.08), (0, 0.2, 9.0), p["glow_pink"]),
    ]
    obj = join(parts, "arena")
    export(obj, os.path.join(MODELS, "arena.glb"))


def build_portal():
    p = new_scene()
    parts = [
        torus("ring", 1.5, 0.12, (0, 0, 0), p["glow"], rot=(0, math.pi / 2, 0), segments=26),
        torus("ring2", 1.12, 0.07, (0, 0, 0), p["glow_pink"], rot=(0, math.pi / 2, 0), segments=22),
    ]
    for i in range(4):
        a = i * math.tau / 4 + 0.4
        parts.append(box("clamp%d" % i, (0.34, 0.34, 0.34),
                         (0, math.cos(a) * 1.5, math.sin(a) * 1.5), p["trim"],
                         rot=(a, 0, 0)))
    obj = join(parts, "portal")
    export(obj, os.path.join(MODELS, "portal.glb"))


def build_decor():
    p = new_scene()
    parts = [
        box("base", (1.6, 1.2, 0.4), (0, 0, 0), p["trim"]),
        cone("shard", 0.5, 0.04, 2.4, (0, 0, 1.4), p["crystal"], verts=5),
        cone("shard2", 0.3, 0.03, 1.5, (0.5, 0.2, 1.0), p["crystal"], verts=5, rot=(0, 0.3, 0)),
        sphere("glow", 0.16, (0, 0, 2.7), p["glow"], subdiv=1),
    ]
    obj = join(parts, "crystal")
    export(obj, os.path.join(MODELS, "crystal.glb"))


if __name__ == "__main__":
    build_paddle()
    build_ball()
    build_bricks()
    build_capsule()
    build_boss_core()
    build_arena()
    build_portal()
    build_decor()
    print("asset build complete")
