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
    if obj.data.shape_keys is None:
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
    skin = material("Skin", (0.62, 0.36, 0.22), .61)
    cloth = material("Cloth", (0.14, 0.22, 0.26), 0.79)
    hair = material("Hair", (0.12, 0.07, 0.045), .53)
    trousers = material("Trousers", (0.055, 0.076, 0.09), 0.92)
    leather = material("Leather", (0.064, 0.038, 0.025))
    shoe_upper = material("ShoeUpper", (0.064, 0.038, 0.025), .48)
    rubber = material("Rubber", (0.105, 0.12, 0.12))
    shirt = material("Cotton", (0.72, 0.66, 0.51), 0.88)
    brass = material("Brass", (0.53, 0.32, 0.095), 0.38, 0.6)
    knit = material("KnitTrim", (.16, .235, .235), .95)
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
        (1.62, 0, -.015, .282, .170), (1.72, 0, -.011, .300, .151),
        (1.79, 0, .001, .269, .138), (1.84, 0, .005, .184, .122),
        (1.90, 0, .005, .117, .095),
    ], cloth, chest_weight, 18)]
    clothes.append(loft("Waist", [
        (.75, 0, 0, .155, .10), (.84, 0, 0, .222, .14), (1.02, 0, 0, .221, .145),
        (1.06, 0, 0, .189, .121),
    ], trousers, "Pelvis", 14))
    trim = [loft("Neck", [
        (1.82, 0, .01, .105, .09), (1.90, 0, 0, .105, .09), (2.06, 0, -.01, .10, .095),
    ], skin, "Chest")]
    trim.append(loft("ShirtNeckband", [
        (1.872, 0, -.005, .115, .108), (1.891, 0, -.004, .106, .100),
        (1.917, 0, -.003, .105, .097),
    ], shirt, "Chest", 16))
    trim.append(panel("ShirtFront", [(-.052, 1.881, -.121), (.052, 1.881, -.121),
                                     (.035, 1.770, -.152), (0, 1.706, -.169),
                                     (-.035, 1.770, -.152)], shirt, "Chest", .014))
    for sign in (-1, 1):
        side = "Left" if sign < 0 else "Right"
        trim.append(panel("Lapel", [(sign*.082, 1.871, -.125), (sign*.15, 1.81, -.127),
                                    (sign*.115, 1.744, -.165), (sign*.132, 1.716, -.166),
                                    (sign*.029, 1.592, -.193), (sign*.070, 1.726, -.169)],
                          cloth, "Chest", .018))
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
        trim.append(loft("SleeveCuff", [(1.105, sign*.405, -.008, .057, .058),
                                        (1.145, sign*.408, -.007, .071, .071)],
                         shirt, arm_weight, 10))
        trim.append(loft("Hand", [
            (1.001, sign*.408, -.026, .028, .030), (1.026, sign*.407, -.022, .045, .038),
            (1.071, sign*.411, -.013, .053, .047), (1.143, sign*.404, -.006, .045, .041),
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
        shoe = [(0.013, sign*.143, -.059, .102, .161), (.043, sign*.143, -.064, .108, .169),
                (.059, sign*.143, -.064, .104, .164)]
        trim.append(loft("Sole", shoe, rubber, side + "Foot", 12))
        trim.append(loft("Shoe", [shoe[-1],
                                 (.09, sign*.143, -.072, .105, .158),
                                 (.128, sign*.143, -.054, .098, .115),
                                 (.153, sign*.143, -.023, .084, .100)],
                         shoe_upper, side + "Foot", 12))
        trim.append(panel("ShoeLaces", [(sign*.105, .14, -.128), (sign*.180, .14, -.128),
                                        (sign*.184, .11, -.164), (sign*.10, .11, -.164)],
                          shirt, side + "Foot"))
    body = join("WardrobeBody", clothes + trim, rig)
    shape(body, "TailoredSilhouette", lambda x, y, z: (
        x * (1.0 - 0.13 * max(0.0, 1 - abs(y - 1.77) / 0.57)
             + 0.07 * max(0.0, 1 - abs(y - 0.97) / 0.21)),
        y, z - 0.022 * max(0.0, 1 - abs(y - 1.57) / 0.19) if z < 0 else z,
    ))
    shape(body, "RelaxedFit", lambda x, y, z: (
        x * (1 + .084 * max(0, 1 - abs(y - 1.23) / .54)), y,
        z * (1 + .14 * max(0, 1 - abs(y - 1.34) / .41)),
    ))
    shape(body, "StructuredShoulders", lambda x, y, z: (
        x * (1 + .10 * max(0, 1 - abs(y - 1.70) / .27)), y, z,
    ))
    shape(body, "FittedLeggings", lambda x, y, z: (
        x * (.88 + .12 * min(1.0, abs(y - .54) / .46)),
        y, z * (.81 + .19 * min(1.0, abs(y - .54) / .46)),
    ) if .16 < y < 1 else (x, y, z))
    join("CollarCrew", [
        panel("KnitNeckline", [(-.089, 1.878, -.115), (.089, 1.878, -.115),
                              (.065, 1.815, -.150), (0, 1.795, -.160),
                              (-.065, 1.815, -.150)], knit, "Chest", .013),
    ], rig)
    join("CollarFold", [
        panel("CollarPoint", [(sign*.019, 1.891, -.113), (sign*.076, 1.895, -.106),
                              (sign*.087, 1.846, -.128), (sign*.048, 1.823, -.145)],
              shirt, "Chest", .011) for sign in (-1, 1)
    ], rig)
    def skirt_weight(point):
        x, y, _ = point
        leg = max(0.0, min(.84, (1.02 - y) * 3.8))
        right = min(1.0, max(0.0, .5 + x * 5.0))
        return {"Pelvis": 1 - leg, "LeftThigh": leg * (1 - right), "RightThigh": leg * right}

    join("WardrobeSkirt", [loft("Skirt", [
        (.625, 0, 0, .272, .145), (.667, 0, 0, .267, .150),
        (.862, 0, 0, .254, .163), (.97, 0, 0, .238, .155),
        (1.039, 0, 0, .218, .15),
    ], knit, skirt_weight, 16)], rig)

    face = [loft("Face", [
        (1.993, 0, -.045, .081, .077), (2.025, 0, -.034, .131, .122),
        (2.082, 0, -.026, .174, .157), (2.151, 0, -.022, .202, .183),
        (2.219, 0, -.019, .208, .182), (2.278, 0, .002, .198, .165),
        (2.348, 0, .019, .166, .141), (2.396, 0, .027, .083, .075),
    ], skin, "Head", 20)]
    face.append(loft("NoseBridge", [(2.141, 0, -.199, .025, .027),
                                    (2.157, 0, -.213, .035, .037),
                                    (2.178, 0, -.207, .029, .035),
                                    (2.23, 0, -.194, .019, .018)], skin, "Head", 10))
    for sign in (-1, 1):
        face.append(oval("Ear", (sign*.201, 2.179, .003), (.041, .064, .040), skin, "Head"))
        face.append(oval("NoseWing", (sign*.028, 2.153, -.215), (.018, .015, .023), skin, "Head", 8))
        face.append(oval("Eye", (sign*.083, 2.214, -.186), (.038, .015, .021), eye, "Head", 12))
        face.append(oval("Iris", (sign*.080, 2.215, -.203), (.014, .015, .009), pupil, "Head"))
        face.append(oval("EyeLight", (sign*.080-.003, 2.220, -.211), (.0035, .0035, .003), eye, "Head", 6))
        face.append(oval("UpperLid", (sign*.082, 2.230, -.191), (.039, .008, .021), skin, "Head"))
        face.append(panel("Eyebrow", [(sign*.044, 2.249, -.194), (sign*.078, 2.260, -.191),
                                     (sign*.104, 2.261, -.181), (sign*.126, 2.254, -.169),
                                     (sign*.105, 2.251, -.182), (sign*.080, 2.251, -.193),
                                     (sign*.046, 2.242, -.196)],
                          hair, "Head", .012))
    face_mesh = join("Face", face, rig)
    shape(face_mesh, "SoftJaw", lambda x, y, z: (
        x * (1.0 - 0.16 * max(0.0, 1 - abs(y - 2.055) / 0.16)), y, z,
    ))
    shape(face_mesh, "HighCheekbones", lambda x, y, z: (
        x * (1 + .082 * max(0, 1 - abs(y - 2.17) / .07)), y, z,
    ))
    join("MouthShape", [
        oval("LipLine", (0, 0, 0), (.050, .008, .010), lip, None),
        oval("SmileCorner", (-.039, .004, 0), (.015, .006, .009), lip, None, 8),
        oval("SmileCorner", (.039, .004, 0), (.015, .006, .009), lip, None, 8),
    ], None)

    for style in range(8):
        shapes = [loft("Scalp", [
            (2.21, 0, .079, .205, .094), (2.27, 0, .053, .216, .145),
            (2.35, 0, .022, .221, .181), (2.413, -.025, .007, .170, .130),
            (2.437 + (style%3)*.012, -.054, -.028, .088, .072),
        ], hair, "Head", 18)]
        if style == 0:
            shapes.append(loft("SweptFringe", [
                (2.320, -.111, -.120, .094, .059), (2.363, -.065, -.103, .153, .112),
                (2.412, -.034, -.069, .161, .126), (2.456, -.067, -.044, .100, .074),
            ], hair, "Head", 18))
            shapes.append(oval("SidePart", (.116, 2.352, -.095), (.085, .051, .093), hair, "Head", 12))
        elif style == 1:
            shapes.append(loft("Bob", [(2.046, 0, .100, .201, .078), (2.103, 0, .086, .218, .118),
                                        (2.249, 0, .080, .233, .118), (2.382, 0, .06, .191, .16)],
                               hair, "Head", 16))
            for sign in (-1, 1):
                shapes.append(loft("TempleLock", [
                    (2.125, sign*.185, -.074, .034, .044), (2.199, sign*.182, -.093, .051, .072),
                    (2.273, sign*.170, -.091, .071, .092), (2.356, sign*.124, -.065, .080, .091),
                ], hair, "Head", 14))
        elif style == 2:
            for x, h in [(-.132, 2.37), (-.061, 2.422), (.025, 2.43), (.11, 2.389)]:
                shapes.append(oval("Curl", (x, h, -.114), (.087, .065, .091), hair, "Head"))
        elif style == 3:
            shapes.append(oval("NapeBun", (.073, 2.225, .214), (.122, .115, .102), hair, "Head"))
            shapes.append(oval("SideSweep", (-.076, 2.352, -.117), (.16, .053, .111), hair, "Head"))
        elif style == 4:
            shapes.append(loft("Crop", [(2.323, 0, -.048, .199, .163),
                                        (2.407, -.014, -.044, .196, .153),
                                        (2.466, -.028, -.058, .135, .109),
                                        (2.485, -.031, -.040, .070, .065)], hair, "Head", 16))
        elif style == 5:
            shapes.append(loft("Layers", [(1.957, 0, .159, .144, .040),
                                           (2.040, 0, .112, .211, .103),
                                           (2.220, 0, .066, .225, .143),
                                           (2.390, 0, .021, .189, .161)], hair, "Head", 16))
            shapes.append(oval("Wave", (-.145, 2.300, -.127), (.100, .123, .071), hair, "Head"))
            shapes.append(oval("Wave", (.162, 2.336, -.106), (.086, .087, .076), hair, "Head"))
        elif style == 6:
            shapes.append(loft("RoundedRoll", [
                (2.323, .045, -.091, .161, .090), (2.371, .020, -.086, .190, .135),
                (2.437, .016, -.058, .166, .156), (2.488, -.021, -.005, .098, .088),
            ], hair, "Head", 18))
            shapes.append(oval("RearTaper", (0, 2.246, .103), (.192, .102, .080), hair, "Head", 14))
        else:
            shapes.append(loft("AsymmetricBob", [
                (2.016, -.035, .088, .137, .079), (2.079, -.031, .077, .216, .129),
                (2.195, -.012, .057, .229, .153), (2.324, .022, .031, .211, .168),
                (2.419, .014, .019, .138, .119),
            ], hair, "Head", 18))
            shapes.append(loft("LongSideSweep", [
                (2.108, -.177, -.080, .043, .060), (2.207, -.172, -.092, .063, .080),
                (2.326, -.124, -.104, .117, .088), (2.400, -.067, -.068, .135, .081),
            ], hair, "Head", 14))
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
