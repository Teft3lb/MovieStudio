"""Build the original MovieStudio employee source and its runtime glTF."""

from math import cos, sin, tau
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_source" / "characters" / "studio_employee.blend"
EXPORT = ROOT / "assets" / "models" / "characters" / "studio_employee.glb"


def xyz(point):
    """Convert Godot-style (right, up, back) coordinates to Blender."""
    x, y, z = point
    return (x, -z, y)


def material(name, color, roughness=0.72, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metal
    return mat


def mesh(name, vertices, faces, mat, weights, corner_uvs=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(point) for point in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for polygon in data.polygons:
        polygon.use_smooth = True
    uv = data.uv_layers.new(name="ProfileUV")
    extent_x = max(point[0] for point in vertices) - min(point[0] for point in vertices)
    extent_y = max(point[1] for point in vertices) - min(point[1] for point in vertices)
    origin_x = min(point[0] for point in vertices)
    origin_y = min(point[1] for point in vertices)
    for polygon in data.polygons:
        for corner, loop_id in enumerate(polygon.loop_indices):
            vertex = vertices[data.loops[loop_id].vertex_index]
            uv.data[loop_id].uv = (
                corner_uvs[polygon.index][corner] if corner_uvs
                else ((vertex[0] - origin_x) / max(extent_x, 0.001),
                      (vertex[1] - origin_y) / max(extent_y, 0.001))
            )
    if weights:
        groups = {}
        for index, point in enumerate(vertices):
            point_weights = {weights: 1.0} if isinstance(weights, str) else weights(point)
            for bone, strength in point_weights.items():
                if strength <= 0.0:
                    continue
                if bone not in groups:
                    groups[bone] = obj.vertex_groups.new(name=bone)
                groups[bone].add([index], strength, "REPLACE")
    return obj


def loft(name, rings, mat, weights, sides=12):
    """Shape a closed mesh with horizontal elliptical sections."""
    vertices = []
    faces = []
    uvs = []
    for height, cx, cz, width, depth in rings:
        for index in range(sides):
            angle = tau * index / sides
            vertices.append((cx + cos(angle) * width, height, cz + sin(angle) * depth))
    for ring in range(len(rings) - 1):
        for index in range(sides):
            a = ring * sides + index
            b = ring * sides + (index + 1) % sides
            faces.append((a, a + sides, b + sides, b))
            left, right = index / sides, (index + 1) / sides
            bottom = 0.15 + 0.85 * ring / (len(rings) - 1)
            top = 0.15 + 0.85 * (ring + 1) / (len(rings) - 1)
            uvs.append([(left, bottom), (left, top), (right, top), (right, bottom)])
    faces.append(tuple(range(sides)))
    faces.append(tuple(reversed(range(len(vertices) - sides, len(vertices)))))
    for x, face in zip((0.1, 0.3), faces[-2:]):
        uvs.append([(x + 0.06 * cos(tau * index / sides),
                     0.075 + 0.06 * sin(tau * index / sides)) for index in face])
    return mesh(name, vertices, faces, mat, weights, uvs)


def oval(name, center, size, mat, bone, sides=10):
    x, y, z = center
    width, height, depth = size
    profile = [(-1.0, 0.08), (-0.78, 0.64), (-0.38, 0.93), (0.0, 1.0),
               (0.38, 0.93), (0.78, 0.64), (1.0, 0.08)]
    return loft(name, [(y + height * level, x, z, width * radius, depth * radius)
                       for level, radius in profile], mat, bone, sides)


def panel(name, points, mat, bone, thickness=0.012):
    vertices = points + [(x, y, z + thickness) for x, y, z in points]
    n = len(points)
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    faces.extend((i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n))
    return mesh(name, vertices, faces, mat, bone)


def join(name, objects, rig):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if rig:
        obj.parent = rig
        armature = obj.modifiers.new("Employee skeleton", "ARMATURE")
        armature.object = rig
    return obj


def shape(obj, name, change):
    obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name=name)
    for vertex in key.data:
        x, minus_z, y = vertex.co
        vertex.co = xyz(change(x, y, -minus_z))


def make_rig():
    data = bpy.data.armatures.new("EmployeeSkeleton")
    rig = bpy.data.objects.new("EmployeeRig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name, position, parent=None):
        joint = data.edit_bones.new(name)
        joint.head = xyz(position)
        joint.tail = joint.head + Vector((0.0, 0.0, 0.22))
        if parent:
            joint.parent = data.edit_bones[parent]

    bone("Pelvis", (0.0, 0.88, 0.0))
    bone("Chest", (0.0, 1.27, 0.0), "Pelvis")
    bone("Head", (0.0, 2.17, 0.0), "Chest")
    for side, sign in [("Left", -1.0), ("Right", 1.0)]:
        bone(side + "Arm", (sign * 0.34, 1.76, 0.0), "Chest")
        bone(side + "Forearm", (sign * 0.40, 1.43, 0.0), side + "Arm")
        bone(side + "Thigh", (sign * 0.14, 0.83, 0.0), "Pelvis")
        bone(side + "Shin", (sign * 0.14, 0.37, 0.0), side + "Thigh")
        bone(side + "Foot", (sign * 0.14, 0.10, 0.0), side + "Shin")
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def animate(rig):
    clips = {
        "Idle": (88, {"Head": [(0.0, 0.0), (0.5, 0.045), (1.0, 0.0)],
                      "Chest": [(0.0, 0.0), (0.5, 0.025), (1.0, 0.0)]}),
        "IdleLook": (104, {"Head": [(0.0, 0.03), (0.25, -0.04), (0.65, 0.09), (1.0, 0.03)],
                          "Chest": [(0.0, 0.0), (0.5, -0.035), (1.0, 0.0)]}),
        "Walk": (23, {}),
        "Turn": (19, {"Chest": [(0, 0.0), (0.5, 0.09), (1, 0.0)],
                       "LeftThigh": [(0, 0), (0.5, -0.22), (1, 0)],
                       "RightThigh": [(0, 0), (0.5, 0.12), (1, 0)]}),
        "Gesture": (43, {"LeftForearm": [(0, 0.22), (0.35, 0.48), (1, 0.22)],
                          "RightForearm": [(0, 0.25), (0.65, 0.54), (1, 0.25)]}),
        "Typing": (25, {"LeftForearm": [(0, 0.78), (0.33, 0.91), (1, 0.78)],
                         "RightForearm": [(0, 0.86), (0.65, 0.76), (1, 0.86)]}),
        "DeskTyping": (49, {"Chest": [(0, .015), (.35, .031), (.64, -.012), (1, .015)],
                             "LeftForearm": [(0, .56), (.3, .65), (1, .56)],
                             "RightForearm": [(0, .62), (.7, .54), (1, .62)]}),
        "Camera": (60, {"LeftForearm": [(0, 0.42), (0.4, 0.58), (1, 0.42)],
                         "RightForearm": [(0, 0.52), (0.7, 0.68), (1, 0.52)]}),
        "Lift": (41, {"LeftForearm": [(0, 0.22), (0.45, 0.38), (1, 0.22)],
                        "RightForearm": [(0, 0.20), (0.55, 0.36), (1, 0.20)]}),
        "Eating": (60, {"LeftForearm": [(0, 0.3), (0.28, 0.65), (0.62, 0.15), (1, 0.3)],
                         "RightForearm": [(0, 0.22), (0.55, 0.10), (0.78, 0.56), (1, 0.22)]}),
        "Rest": (115, {"Chest": [(0, 0), (0.5, 0.015), (1, 0)]}),
    }
    for side, sign in [("Left", -1), ("Right", 1)]:
        clips["Walk"][1][side + "Arm"] = [(0, 0.42 * sign), (0.5, -0.42 * sign), (1, 0.42 * sign)]
        clips["Walk"][1][side + "Forearm"] = [(0, 0.17), (0.5, 0.28), (1, 0.17)]
        clips["Walk"][1][side + "Thigh"] = [(0, -0.44 * sign), (0.5, 0.44 * sign), (1, -0.44 * sign)]
        knee = [(0, -0.10), (0.25, -0.62), (0.5, -0.10), (0.75, -0.04), (1, -0.10)]
        clips["Walk"][1][side + "Shin"] = knee if side == "Left" else [
            (time, knee[(index + 2) % 4][1]) for index, (time, _) in enumerate(knee)
        ]
        clips["Walk"][1][side + "Foot"] = [(0, 0.08), (0.5, -0.07), (1, 0.08)]
    rig.animation_data_create()
    for name, (duration, tracks) in clips.items():
        rig.animation_data.action = None
        for joint in rig.pose.bones:
            joint.rotation_mode = "QUATERNION"
            joint.rotation_quaternion = Quaternion()
        for joint in rig.pose.bones:
            for time, angle in tracks.get(joint.name, [(0, 0), (1, 0)]):
                joint.rotation_quaternion = Quaternion((1, 0, 0), angle)
                joint.keyframe_insert("rotation_quaternion", frame=1 + duration * time)
        action = rig.animation_data.action
        action.name = name
        action.use_fake_user = True
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, action)
        track.mute = True
    for joint in rig.pose.bones:
        joint.rotation_quaternion = Quaternion()


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rig = make_rig()
    skin = material("Skin", (0.62, 0.36, 0.22))
    cloth = material("Cloth", (0.14, 0.22, 0.26), 0.86)
    hair = material("Hair", (0.12, 0.07, 0.045))
    trousers = material("Trousers", (0.055, 0.076, 0.09), 0.92)
    leather = material("Leather", (0.064, 0.038, 0.025))
    rubber = material("Rubber", (0.105, 0.12, 0.12))
    shirt = material("Cotton", (0.72, 0.66, 0.51), 0.88)
    brass = material("Brass", (0.53, 0.32, 0.095), 0.38, 0.6)
    pupil = material("Iris", (0.035, 0.018, 0.013), 0.33)
    eye = material("Eye", (0.88, 0.80, 0.67), 0.45)
    lip = material("Lip", (0.18, 0.057, 0.040))
    teal = material("EquipmentTeal", (0.05, 0.20, 0.20))
    orange = material("EquipmentOchre", (0.46, 0.20, 0.035))

    def chest_weight(point):
        strength = max(0.0, min(1.0, (point[1] - 1.05) / 0.40))
        return {"Chest": strength, "Pelvis": 1.0 - strength}

    clothes = [loft("TailoredJacket", [
        (0.96, 0, 0.01, .19, .10), (1.01, 0, 0, .245, .155),
        (1.20, 0, -.007, .223, .158), (1.43, 0, -.016, .258, .172),
        (1.65, 0, -.015, .302, .17), (1.77, 0, .001, .295, .137),
        (1.84, 0, .005, .20, .124), (1.90, 0, .005, .119, .095),
    ], cloth, chest_weight, 16)]
    clothes.append(loft("Waist", [
        (.75, 0, 0, .155, .10), (.84, 0, 0, .222, .14), (1.02, 0, 0, .221, .145),
        (1.06, 0, 0, .189, .121),
    ], trousers, "Pelvis", 14))
    trim = [loft("Neck", [
        (1.82, 0, .01, .105, .09), (1.90, 0, 0, .105, .09), (2.06, 0, -.01, .10, .095),
    ], skin, "Chest")]
    trim.append(panel("ShirtFront", [(-.079, 1.891, -.123), (.079, 1.891, -.123),
                                     (.054, 1.72, -.192), (0, 1.54, -.228),
                                     (-.054, 1.72, -.192)], shirt, "Chest", .039))
    for sign in (-1, 1):
        side = "Left" if sign < 0 else "Right"
        trim.append(panel("Lapel", [(sign*.096, 1.878, -.145), (sign*.181, 1.818, -.169),
                                    (sign*.141, 1.72, -.195), (sign*.153, 1.689, -.190),
                                    (sign*.033, 1.495, -.220), (sign*.078, 1.708, -.215)],
                          cloth, "Chest", .043))
        if sign < 0:
            for y in (1.14, 1.28, 1.42):
                trim.append(oval("Button", (.013, y, -.194), (.013, .013, .010), brass, "Chest", 8))

        def arm_weight(point, side=side):
            strength = max(0.0, min(1.0, (1.52 - point[1]) / 0.18))
            return {side + "Arm": 1.0 - strength, side + "Forearm": strength}

        clothes.append(loft("Sleeve", [
            (1.117, sign*.405, -.009, .069, .069), (1.154, sign*.414, -.006, .077, .075),
            (1.31, sign*.410, .006, .089, .082), (1.43, sign*.393, .014, .099, .091),
            (1.61, sign*.353, .004, .118, .103), (1.72, sign*.311, .002, .125, .113),
            (1.795, sign*.299, .004, .085, .09),
        ], cloth, arm_weight))
        trim.append(loft("Hand", [
            (1.006, sign*.405, -.025, .034, .040), (1.03, sign*.405, -.016, .056, .051),
            (1.095, sign*.408, -.009, .060, .054), (1.143, sign*.404, -.006, .047, .045),
        ], skin, side + "Forearm", 10))
        trim.append(oval("Thumb", (sign*.363, 1.065, -.039), (.025, .041, .03), skin, side + "Forearm", 8))

        def leg_weight(point, side=side):
            strength = max(0.0, min(1.0, (0.455 - point[1]) / 0.17))
            return {side + "Thigh": 1.0 - strength, side + "Shin": strength}

        clothes.append(loft("TailoredTrouserLeg", [
            (.086, sign*.142, .004, .078, .082), (.155, sign*.141, .01, .085, .081),
            (.35, sign*.139, .005, .096, .091), (.45, sign*.135, .004, .105, .106),
            (.65, sign*.126, 0, .116, .123), (.82, sign*.128, 0, .126, .129),
            (.89, sign*.119, 0, .111, .108),
        ], trousers, leg_weight))
        shoe = [(0.013, sign*.143, -.064, .108, .174), (.043, sign*.143, -.065, .113, .176),
                (.059, sign*.143, -.065, .108, .172)]
        trim.append(loft("Sole", shoe, rubber, side + "Foot", 12))
        trim.append(loft("Shoe", [shoe[-1],
                                 (.09, sign*.143, -.072, .105, .158),
                                 (.128, sign*.143, -.054, .098, .115),
                                 (.153, sign*.143, -.023, .084, .100)],
                         leather, side + "Foot", 12))
        trim.append(panel("ShoeLaces", [(sign*.105, .14, -.128), (sign*.180, .14, -.128),
                                        (sign*.184, .11, -.164), (sign*.10, .11, -.164)],
                          shirt, side + "Foot"))
    body = join("WardrobeBody", clothes + trim, rig)
    shape(body, "TailoredSilhouette", lambda x, y, z: (
        x * (1.0 - 0.13 * max(0.0, 1 - abs(y - 1.77) / 0.57)
             + 0.07 * max(0.0, 1 - abs(y - 0.97) / 0.21)),
        y, z - 0.022 * max(0.0, 1 - abs(y - 1.57) / 0.19) if z < 0 else z,
    ))

    face = [loft("Face", [
        (1.993, 0, -.045, .075, .073), (2.025, 0, -.033, .137, .116),
        (2.082, 0, -.022, .182, .15), (2.151, 0, -.022, .208, .183),
        (2.219, 0, -.019, .212, .182), (2.278, 0, .002, .202, .165),
        (2.348, 0, .019, .166, .141), (2.396, 0, .027, .083, .075),
    ], skin, "Head", 20)]
    face.append(loft("NoseBridge", [(2.141, 0, -.199, .025, .027),
                                    (2.157, 0, -.211, .047, .043),
                                    (2.178, 0, -.203, .033, .040),
                                    (2.23, 0, -.194, .019, .018)], skin, "Head", 10))
    for sign in (-1, 1):
        face.append(oval("Ear", (sign*.206, 2.179, .002), (.044, .068, .041), skin, "Head"))
        face.append(oval("Eye", (sign*.083, 2.217, -.195), (.045, .020, .018), eye, "Head"))
        face.append(oval("Iris", (sign*.080, 2.217, -.211), (.017, .016, .009), pupil, "Head"))
        face.append(oval("Eyebrow", (sign*.083, 2.262, -.189), (.05, .009, .013), hair, "Head"))
    face_mesh = join("Face", face, rig)
    shape(face_mesh, "SoftJaw", lambda x, y, z: (
        x * (1.0 - 0.16 * max(0.0, 1 - abs(y - 2.055) / 0.16)), y, z,
    ))
    join("MouthShape", [oval("LipLine", (0, 0, 0), (.054, .010, .012), lip, None)], None)

    for style in range(3):
        shapes = [loft("Scalp", [
            (2.21, 0, .079, .205, .094), (2.27, 0, .053, .216, .145),
            (2.35, 0, .022, .221, .181), (2.413, -.025, .007, .170, .130),
            (2.437 + style*.012, -.054, -.028, .088, .072),
        ], hair, "Head", 18)]
        if style == 0:
            shapes.append(oval("SweptCrown", (-.060, 2.377, -.095), (.146, .075, .120), hair, "Head"))
            shapes.append(oval("SidePart", (.131, 2.350, -.105), (.081, .056, .095), hair, "Head"))
        elif style == 1:
            shapes.append(loft("Bob", [(2.046, 0, .100, .201, .078), (2.103, 0, .086, .218, .118),
                                        (2.249, 0, .080, .233, .118), (2.382, 0, .06, .191, .16)],
                               hair, "Head", 16))
            for sign in (-1, 1):
                shapes.append(oval("TempleLock", (sign*.186, 2.222, -.094), (.054, .129, .074), hair, "Head"))
        else:
            for x, h in [(-.132, 2.37), (-.061, 2.422), (.025, 2.43), (.11, 2.389)]:
                shapes.append(oval("Curl", (x, h, -.114), (.087, .065, .091), hair, "Head"))
        join(f"Hair{style}", shapes, rig)

    cap = [loft("CapCrown", [(2.306, 0, .001, .221, .18), (2.34, 0, 0, .24, .205),
                             (2.437, 0, .02, .193, .17), (2.47, 0, .04, .09, .09)],
                teal, "Head", 16),
           panel("CapVisor", [(-.158, 2.33, -.17), (.158, 2.33, -.17), (.169, 2.313, -.27),
                              (.106, 2.30, -.345), (-.106, 2.30, -.345),
                              (-.169, 2.313, -.27)], teal, "Head", .025)]
    join("RoleDirector", cap, rig)
    for role, accent, bag_side in [("Camera", teal, -1), ("Technician", orange, 1),
                                   ("Writer", leather, 1), ("Editor", teal, 1),
                                   ("Office", brass, -1), ("Actor", shirt, -1)]:
        pieces = []
        if role in ("Camera", "Writer"):
            pieces.append(panel("Strap", [(-.21, 1.80, -.152), (-.145, 1.82, -.174),
                                          (.033, 1.53, -.233), (.22, 1.205, -.161),
                                          (.172, 1.168, -.173), (-.025, 1.505, -.230)],
                                accent, "Chest", .034))
        if role in ("Camera", "Technician", "Writer"):
            x = bag_side * .23
            pieces.append(loft("UtilityPouch", [
                (1.10, x, -.092, .085, .047), (1.13, x, -.098, .106, .066),
                (1.34, x, -.098, .109, .068), (1.361, x, -.099, .092, .058),
            ], accent, "Pelvis"))
            pieces.append(oval("Fastener", (x, 1.292, -.167), (.019, .016, .01), brass, "Pelvis"))
        if role == "Technician":
            for sign in (-1, 1):
                pieces.append(panel("HighVisibilityStripe", [(sign*.124, 1.78, -.177),
                                     (sign*.168, 1.77, -.172), (sign*.165, 1.37, -.176),
                                     (sign*.115, 1.37, -.184)], orange, "Chest", .025))
        if role == "Editor":
            for sign in (-1, 1):
                pieces.append(oval("Headphones", (sign*.138, 1.912, -.075), (.041, .060, .050), teal, "Chest"))
        if role in ("Office", "Actor"):
            pieces.append(panel("Scarf", [(-.10, 1.925, -.117), (.11, 1.925, -.117),
                                          (.051, 1.82, -.190), (.08, 1.71, -.219),
                                          (-.014, 1.75, -.214), (-.07, 1.84, -.170)],
                                accent, "Chest", .028))
        join("Role" + role, pieces, rig)

    join("CostumeWestern", [
        loft("WesternBrim", [(2.33, 0, 0, .325, .274), (2.36, 0, -.01, .34, .295),
                             (2.39, 0, 0, .31, .26)], leather, "Head", 20),
        loft("WesternCrown", [(2.355, 0, 0, .226, .193), (2.42, 0, 0, .214, .18),
                              (2.545, 0, .026, .169, .138), (2.57, 0, .024, .145, .112)],
             orange, "Head", 16),
        loft("HatBand", [(2.397, 0, 0, .224, .190), (2.426, 0, 0, .217, .184)],
             leather, "Head", 16),
    ], rig)
    join("CostumePeriod", [
        panel("Cravat", [(-.085, 1.91, -.113), (.087, 1.91, -.113), (.045, 1.82, -.174),
                         (.058, 1.72, -.216), (0, 1.675, -.233), (-.06, 1.73, -.216)],
              brass, "Chest"),
        oval("Brooch", (0, 1.829, -.179), (.022, .025, .016), leather, "Chest"),
    ], rig)
    join("CostumeFuturistic", [
        panel("HarnessPlate", [(-.188, 1.754, -.180), (.187, 1.754, -.180),
                                (.158, 1.59, -.220), (0, 1.54, -.241),
                                (-.158, 1.59, -.220)], teal, "Chest", .03),
        panel("CrewInsignia", [(0, 1.724, -.209), (.044, 1.663, -.243),
                               (0, 1.606, -.249), (-.044, 1.663, -.243)],
              brass, "Chest"),
    ], rig)

    animate(rig)
    bpy.context.scene.render.fps = 24
    bpy.context.scene.frame_set(1)
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB",
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True)


if __name__ == "__main__":
    build()
