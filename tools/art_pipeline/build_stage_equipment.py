"""Build production camera and Fresnel models for the sound stages."""

from math import cos, sin, tau
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.dont_write_bytecode = True
from build_studio_employee import join, material, xyz


ROOT = Path(__file__).resolve().parents[2]


def apply_shape(obj, edge):
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Machined edges", "BEVEL")
    bevel.width = edge
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    normals = obj.modifiers.new("Face normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=normals.name)


def box(name, center, size, mat, edge=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=xyz(center))
    obj = bpy.context.object
    obj.name = name
    obj.scale = xyz((size[0], size[1], -size[2]))
    obj.data.materials.append(mat)
    apply_shape(obj, edge)
    return obj


def rod(name, start, end, r1, r2, mat, sides=12):
    a, b = Vector(xyz(start)), Vector(xyz(end))
    direction = b - a
    bpy.ops.mesh.primitive_cone_add(
        vertices=sides, radius1=r1, radius2=r2, depth=direction.length, location=(a + b) / 2,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = len(polygon.vertices) <= 4
    return obj


def bake_origins(pieces):
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def assemble(name, pieces):
    bake_origins(pieces)
    return join(name, pieces, None)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    iron = material("PowderCoat", (.042, .049, .054), .48, .35)
    silver = material("BrushedAlloy", (.23, .26, .28), .32, .67)
    rubber = material("GripRubber", (.016, .021, .023), .94)
    red = material("FocusRed", (.43, .075, .035), .46)
    lens = material("CoatedGlass", (.035, .21, .22), .16, .72)
    source = material("FresnelGlass", (.96, .55, .22), .28)
    shader = source.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Emission Color"].default_value = (.9, .43, .16, 1.0)
    shader.inputs["Emission Strength"].default_value = 0.7

    # Camera head coordinates are local to the fluid head. The base stays on the floor.
    camera = [
        box("MachinedHousing", (0, .04, .025), (.50, .40, .56), iron, .034),
        box("Battery", (0, .01, .35), (.44, .32, .12), rubber, .027),
        box("ShoulderPad", (0, -.23, .19), (.39, .08, .31), rubber),
        box("TopRail", (0, .28, .02), (.19, .047, .51), silver),
        box("HandleGrip", (0, .43, .03), (.14, .085, .32), rubber, .025),
        box("FrontHandleSupport", (0, .365, -.085), (.10, .14, .073), iron),
        box("RearHandleSupport", (0, .365, .148), (.10, .14, .073), iron),
        box("SidePlate", (-.257, .025, .07), (.025, .29, .37), silver, .01),
        box("ScreenHousing", (-.354, .28, .09), (.055, .22, .33), rubber),
        box("Display", (-.388, .28, .09), (.018, .168, .267), lens, .005),
        box("MatteBox", (0, .075, -.63), (.52, .405, .11), iron, .022),
        box("MatteMask", (0, .075, -.692), (.412, .306, .021), rubber, .009),
    ]
    for radius, start, end, mat in [
        (.156, -.226, -.375, silver), (.168, -.37, -.49, rubber),
        (.173, -.482, -.532, red), (.174, -.532, -.615, iron),
        (.139, -.69, -.705, lens),
    ]:
        camera.append(rod("LensBarrel", (0, .074, start), (0, .074, end), radius, radius, mat, 20))
    for index in range(3):
        camera.append(rod("ControlDial", (-.27, .095, -.04 + index * .089),
                          (-.302, .095, -.04 + index * .089), .024, .020, red if index == 0 else rubber))
    camera.append(rod("PanHandle", (.14, -.18, .13), (.32, -.28, .73), .024, .019, silver))
    camera.append(rod("PanGrip", (.29, -.266, .64), (.35, -.3, .84), .041, .032, rubber))
    assemble("CinemaCameraBody", camera)

    tripod = [rod("Bowl", (0, 1.12, 0), (0, 1.26, 0), .16, .20, iron),
              rod("FluidHead", (0, 1.22, 0), (0, 1.30, 0), .13, .13, silver)]
    stand = [rod("Upright", (0, .12, 0), (0, 2.39, 0), .045, .036, silver),
             rod("Spigot", (0, 2.28, 0), (0, 2.51, 0), .052, .042, iron)]
    for index in range(3):
        angle = tau * index / 3 + 0.32
        dx, dz = cos(angle), sin(angle)
        foot = (.43 * dx, .055, .43 * dz)
        tripod.extend([
            rod("TripodLeg", (.108 * dx, 1.19, .108 * dz), foot, .042, .052, silver, 8),
            rod("Spreader", (0, .32, 0), (.34 * dx, .32, .34 * dz), .019, .021, iron, 8),
            rod("Shoe", (foot[0], .017, foot[2]), foot, .066, .055, rubber),
        ])
        stand.extend([
            rod("StandLeg", (0, .46, 0), (.48 * dx, .04, .48 * dz), .032, .036, iron, 8),
            rod("StandFoot", (.48 * dx, .016, .48 * dz), (.48 * dx, .06, .48 * dz), .046, .04, rubber),
        ])
    assemble("CameraTripodBase", tripod)
    assemble("LightStand", stand)

    lamp = [
        rod("FresnelHousing", (0, 2.57, .23), (0, 2.57, -.10), .22, .27, iron, 16),
        rod("FresnelTrim", (0, 2.57, -.09), (0, 2.57, -.15), .27, .27, silver, 20),
        rod("FresnelLens", (0, 2.57, -.15), (0, 2.57, -.17), .221, .233, source, 24),
        box("YokeBase", (0, 2.35, .01), (.59, .062, .09), iron),
        box("LeftYoke", (-.29, 2.49, .01), (.047, .26, .09), iron),
        box("RightYoke", (.29, 2.49, .01), (.047, .26, .09), iron),
        box("TopBarnDoor", (0, 2.805, -.215), (.53, .063, .18), iron),
        box("BottomBarnDoor", (0, 2.34, -.215), (.53, .063, .18), iron),
        box("LeftBarnDoor", (-.267, 2.57, -.215), (.064, .47, .18), iron),
        box("RightBarnDoor", (.267, 2.57, -.215), (.064, .47, .18), iron),
    ]
    assemble("StudioLight", lamp)

    source_file = ROOT / "art_source" / "equipment" / "stage_equipment.blend"
    export_file = ROOT / "assets" / "models" / "equipment" / "stage_equipment.glb"
    source_file.parent.mkdir(parents=True, exist_ok=True)
    export_file.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source_file))
    bpy.ops.export_scene.gltf(filepath=str(export_file), export_format="GLB", export_animations=False)


if __name__ == "__main__":
    build()
