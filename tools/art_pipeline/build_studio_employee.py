"""Build the original MovieStudio employee source and its runtime glTF."""

from math import cos, exp, sin, tau
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


def loft(name, rings, mat, weights, sides=12, deform=None):
    """Shape a closed mesh with horizontal elliptical sections."""
    vertices = []
    faces = []
    uvs = []
    for height, cx, cz, width, depth in rings:
        for index in range(sides):
            angle = tau * index / sides
            point = (cx + cos(angle) * width, height, cz + sin(angle) * depth)
            vertices.append(deform(*point) if deform else point)
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


def sweep(name, sections, mat, bone):
    """Small rounded forms that follow a curve across the face."""
    sides = 8
    vertices = [(x, y + radius * cos(tau*i/sides), z + radius * sin(tau*i/sides))
                for x, y, z, radius in sections for i in range(sides)]
    faces = [(base+i, base+(i+1)%sides, base+(i+1)%sides+sides, base+i+sides)
             for base in range(0, len(vertices)-sides, sides) for i in range(sides)]
    faces.extend([tuple(reversed(range(sides))), tuple(range(len(vertices)-sides, len(vertices)))])
    return mesh(name, vertices, faces, mat, bone)


def hair_shell(name, mat, brow_height, back_height, sweep_amount, wave, crown_height):
    """Continuous swept cap with a different hairline for each cut."""
    sides = 32
    sections = [
        (0.0, 1.0), (.19, 1.08), (.38, 1.067), (.57, .97),
        (.74, .78), (.88, .55), (.965, .30), (1.0, .075),
    ]
    vertices = []
    for t, fullness in sections:
        for i in range(sides):
            theta = tau*i/sides
            front = max(0, -sin(theta))
            rear = max(0, sin(theta))
            hairline = 2.229 + (brow_height-2.229)*front**2 + (back_height-2.229)*rear**1.4
            hairline += sweep_amount*cos(theta)*front + wave * sin(theta*5+.45) * front
            x = .235 * cos(theta)*fullness - sweep_amount*t*.86
            z = .021 + .206 * sin(theta)*fullness + .015*t
            y = hairline + (crown_height-hairline)*t
            vertices.append((x, y, z))
    faces = [(base+i, base+i+sides, base+(i+1)%sides+sides, base+(i+1)%sides)
             for base in range(0, len(vertices)-sides, sides) for i in range(sides)]
    faces.extend([tuple(range(sides)), tuple(reversed(range(len(vertices)-sides, len(vertices))))])
    return mesh(name, vertices, faces, mat, "Head")


def eye_opening(name, x, y, z, mat):
    sections = [(-.050, 0, .019, .003), (-.034, .001, .005, .017),
                (-.013, .002, -.005, .023), (.011, .003, -.005, .022),
                (.036, .001, .005, .015), (.050, -.001, .019, .003)]
    return sweep(name, [(x+dx, y+dy, z+dz, width) for dx,dy,dz,width in sections], mat, "Head")


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
    skin = material("Skin", (0.62, 0.36, 0.22), .69)
    skin_shade = material("SkinShade", (0.42, 0.22, 0.15), .73)
    cloth = material("Cloth", (0.14, 0.22, 0.26), 0.82)
    hair = material("Hair", (0.12, 0.07, 0.045), .67)
    trousers = material("Trousers", (0.055, 0.076, 0.09), 0.92)
    leather = material("Leather", (0.064, 0.038, 0.025))
    shoe_upper = material("ShoeUpper", (0.064, 0.038, 0.025), .48)
    rubber = material("Rubber", (0.105, 0.12, 0.12))
    shirt = material("Cotton", (0.72, 0.66, 0.51), 0.88)
    brass = material("Brass", (0.53, 0.32, 0.095), 0.38, 0.6)
    knit = material("KnitTrim", (.16, .235, .235), .95)
    iris = material("Iris", (0.12, 0.069, 0.040), .37)
    pupil = material("Pupil", (.010, .007, .009), .32)
    eye = material("Eye", (0.88, 0.80, 0.67), 0.45)
    lip = material("Lip", (0.18, 0.057, 0.040))
    teal = material("EquipmentTeal", (0.05, 0.20, 0.20))
    orange = material("EquipmentOchre", (0.46, 0.20, 0.035))

    def chest_weight(point):
        strength = max(0.0, min(1.0, (point[1] - 1.05) / 0.40))
        return {"Chest": strength, "Pelvis": 1.0 - strength}

    clothes = [loft("TailoredJacket", [
        (0.96, 0, 0.01, .19, .10), (1.01, 0, 0, .245, .155),
        (1.16, 0, -.007, .218, .157), (1.37, 0, -.014, .252, .188), (1.49, 0, -.014, .271, .190),
        (1.62, 0, -.012, .284, .173), (1.72, 0, -.010, .296, .155),
        (1.77, 0, .001, .270, .147), (1.82, 0, .004, .206, .135), (1.875, 0, .005, .145, .111),
        (1.90, 0, .005, .117, .095),
    ], cloth, chest_weight, 18)]
    clothes.append(loft("Waist", [
        (.75, 0, 0, .155, .10), (.84, 0, 0, .222, .14), (1.02, 0, 0, .221, .145),
        (1.06, 0, 0, .189, .121),
    ], trousers, "Pelvis", 14))
    trim = [loft("Neck", [
        (1.82, 0, .011, .110, .098), (1.91, 0, -.004, .101, .089),
        (1.980, 0, -.020, .093, .090), (2.055, 0, -.016, .111, .104),
    ], skin, "Chest")]
    trim.append(loft("ShirtNeckband", [
        (1.872, 0, -.005, .115, .108), (1.891, 0, -.004, .106, .100),
        (1.932, 0, -.005, .106, .098),
    ], shirt, "Chest", 16))
    trim.append(panel("ShirtPlacket", [(-.047, 1.875, -.122), (.047, 1.875, -.122),
                                       (.040, 1.824, -.136), (.024, 1.764, -.151),
                                       (.008, 1.742, -.155), (-.008, 1.742, -.155),
                                       (-.024, 1.764, -.151), (-.040, 1.824, -.136)],
                      shirt, "Chest", .012))
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
            (1.61, sign*.353, .004, .111, .103), (1.70, sign*.319, .003, .122, .110),
            (1.758, sign*.303, .003, .110, .102), (1.802, sign*.289, .004, .078, .086),
        ], cloth, arm_weight))
        trim.append(loft("SleeveCuff", [(1.105, sign*.405, -.008, .057, .058),
                                        (1.145, sign*.408, -.007, .071, .071)],
                         shirt, arm_weight, 10))
        trim.append(loft("ShapedPalm", [
            (1.007, sign*.407, -.031, .027, .025), (1.027, sign*.410, -.027, .042, .031),
            (1.049, sign*.412, -.020, .051, .036), (1.079, sign*.410, -.013, .055, .042),
            (1.104, sign*.404, -.009, .047, .041), (1.143, sign*.404, -.006, .041, .037),
        ], skin, side + "Forearm", 14))
        trim.append(loft("ShapedThumb", [
            (1.030, sign*.368, -.048, .012, .013), (1.055, sign*.366, -.041, .021, .021),
            (1.081, sign*.373, -.028, .028, .022), (1.103, sign*.381, -.019, .026, .018),
        ], skin, side + "Forearm", 10))

        def leg_weight(point, side=side):
            strength = max(0.0, min(1.0, (0.455 - point[1]) / 0.17))
            return {side + "Thigh": 1.0 - strength, side + "Shin": strength}

        clothes.append(loft("TailoredTrouserLeg", [
            (.086, sign*.143, .006, .074, .078), (.154, sign*.143, .009, .086, .085),
            (.269, sign*.141, .013, .094, .092), (.386, sign*.137, .010, .096, .097),
            (.486, sign*.133, .003, .108, .111),
            (.65, sign*.127, -.007, .120, .124), (.82, sign*.127, -.003, .127, .133),
            (.89, sign*.119, 0, .111, .108),
        ], trousers, leg_weight))
        shoe = [(.013, sign*.146, -.065, .101, .161), (.030, sign*.146, -.069, .109, .173),
                (.052, sign*.145, -.067, .107, .171), (.063, sign*.145, -.064, .103, .164)]
        trim.append(loft("Sole", shoe, rubber, side + "Foot", 16))
        trim.append(loft("Shoe", [shoe[-1],
                                 (.088, sign*.146, -.074, .103, .158),
                                 (.111, sign*.145, -.059, .098, .132),
                                 (.136, sign*.143, -.037, .089, .105),
                                 (.153, sign*.143, -.023, .082, .092)],
                         shoe_upper, side + "Foot", 16))
        for row in range(3):
            yy = .134 - row*.008
            zz = -.126 - row*.014
            trim.append(panel("ShoeLace", [(sign*.108, yy, zz), (sign*.179, yy, zz),
                                          (sign*.179, yy-.006, zz-.006), (sign*.108, yy-.006, zz-.006)],
                              shirt, side + "Foot", .004))
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
        x * (1 - .20 * min(1.0, max(0.0, (y-.43)/.25))),
        y, z * (1 - .22 * min(1.0, max(0.0, (y-.43)/.25))),
    ) if y < 1.04 else (x, y, z))
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
        (.625, 0, 0, .280, .165), (.667, 0, 0, .275, .169),
        (.862, 0, 0, .263, .176), (.97, 0, 0, .249, .169),
        (1.039, 0, 0, .224, .155),
    ], knit, skirt_weight, 16)], rig)

    def facial_planes(x, y, z):
        front = min(1.0, max(0.0, (-z-.037)/.115))
        ax = abs(x)
        socket = .028 * exp(-((ax-.096)/.055)**2 - ((y-2.239)/.044)**2)
        cheek = .024 * exp(-((ax-.129)/.071)**2 - ((y-2.147)/.052)**2)
        bridge = .031 * exp(-(x/.037)**2 - ((y-2.203)/.069)**2)
        tip = .063 * exp(-(x/.044)**2 - ((y-2.158)/.030)**2)
        muzzle = .018 * exp(-(x/.089)**2 - ((y-2.088)/.039)**2)
        return x, y, z + front * (socket-cheek-bridge-tip-muzzle)

    face = [loft("SculptedHead", [
        (1.969,0,-.025,.065,.073), (1.988,0,-.032,.111,.106),
        (2.013,0,-.031,.152,.132), (2.044,0,-.026,.180,.156),
        (2.079,0,-.023,.203,.169), (2.110,0,-.018,.217,.179),
        (2.137,0,-.012,.231,.184), (2.156,0,-.009,.232,.190),
        (2.173,0,-.006,.231,.195), (2.192,0,-.004,.230,.198),
        (2.214,0,.002,.231,.201), (2.232,0,.005,.232,.198),
        (2.253,0,.008,.232,.195), (2.280,0,.014,.232,.190),
        (2.316,0,.020,.226,.181), (2.352,0,.026,.205,.160),
        (2.390,0,.032,.169,.134), (2.425,0,.029,.115,.095),
        (2.451,0,.024,.051,.053),
    ], skin, "Head", 48, facial_planes)]
    for sign in (-1, 1):
        x = sign*.098
        face.append(oval("Ear", (sign*.229, 2.179, .016), (.034, .057, .029), skin, "Head", 12))
        face.append(oval("Concha", (sign*.244, 2.181, -.006), (.017, .035, .009), skin_shade, "Head"))
        face.append(eye_opening("AlmondEye", x, 2.233, -.168, eye))
        face.append(oval("ColoredIris", (x, 2.235, -.189), (.021, .021, .008), iris, "Head", 14))
        face.append(oval("Pupil", (x, 2.236, -.196), (.012, .015, .005), pupil, "Head", 12))
        face.append(oval("Catchlight", (x-.006, 2.245, -.200), (.0044, .0044, .0028), eye, "Head", 8))
        lid = [(x-.049,2.234,-.153,.0035), (x-.030,2.251,-.176,.0058),
               (x,2.256,-.182,.0061), (x+.028,2.251,-.175,.0055), (x+.049,2.233,-.153,.003)]
        face.append(sweep("UpperLidFold", lid, skin_shade, "Head"))
        arch = [(sign*.049,2.273,-.184,.0035),(sign*.078,2.284,-.184,.008),
                (sign*.110,2.286,-.173,.0077),(sign*.139,2.279,-.159,.0061),
                (sign*.157,2.269,-.143,.0025)]
        face.append(sweep("ExpressiveBrow", sorted(arch), hair, "Head"))
    face_mesh = join("Face", face, rig)
    shape(face_mesh, "SoftJaw", lambda x,y,z: (
        x * (1-.14*max(0,1-abs(y-2.038)/.145)), y, z,
    ))
    shape(face_mesh, "HighCheekbones", lambda x,y,z: (
        x * (1+.065*max(0,1-abs(y-2.163)/.062)), y, z,
    ))
    join("MouthShape", [sweep("Smile", [
        (-.056,.010,.015,.003),(-.041,.004,.006,.0061),(-.019,-.001,-.002,.0072),
        (0,-.004,-.005,.0076),(.019,-.001,-.002,.0072),(.042,.004,.006,.0061),(.056,.010,.015,.003),
    ], lip, None)], None)

    hair_profiles = [
        (2.340,2.183,.052,.007,2.514), (2.370,2.061,-.036,.004,2.514),
        (2.335,2.201,.013,.029,2.543), (2.355,2.198,.031,.008,2.510),
        (2.366,2.217,-.005,.005,2.488), (2.352,1.991,.038,.009,2.519),
        (2.378,2.174,-.040,.005,2.557), (2.375,2.043,.063,.005,2.524),
    ]
    for style,profile in enumerate(hair_profiles):
        pieces = [hair_shell("SculptedHair", hair, *profile)]
        if style == 2:
            for x,y,z in [(-.145,2.441,-.102),(-.077,2.481,-.132),(.017,2.504,-.117),(.105,2.477,-.098)]:
                pieces.append(oval("Coil",(x,y,z),(.072,.051,.073),hair,"Head",12))
        if style == 3:
            pieces.append(oval("TiedChignon",(.021,2.260,.232),(.111,.111,.094),hair,"Head",18))
        if style in (1,5,7):
            for sign in (-1,1):
                length = .157 if style == 5 else .111
                pieces.append(oval("SideSweep",(sign*.196,2.213,-.048),(.063,length,.093),hair,"Head",14))
        join(f"Hair{style}", pieces, rig)

    cap = [loft("CapCrown", [(2.306, 0, .001, .221, .18), (2.34, 0, 0, .24, .205),
                             (2.437, 0, .02, .193, .17), (2.47, 0, .04, .09, .09)],
                teal, "Head", 16),
           panel("CapVisor", [(-.158, 2.33, -.17), (.158, 2.33, -.17), (.169, 2.313, -.27),
                              (.106, 2.30, -.345), (-.106, 2.30, -.345),
                              (-.169, 2.313, -.27)], teal, "Head", .025)]
    join("RoleDirector", cap, rig)
    canvas = material("WorkwearCanvas", (.16,.185,.149), .89)
    washed_wool = material("WoolWaistcoat", (.26,.123,.069), .87)
    for role, accent, bag_side in [("Camera", teal, -1), ("Technician", orange, 1),
                                   ("Writer", leather, 1), ("Editor", teal, 1),
                                   ("Office", brass, -1), ("Actor", shirt, -1)]:
        pieces = []
        if role in ("Technician", "Camera", "Writer"):
            finish = washed_wool if role == "Writer" else canvas
            pieces.append(loft("TailoredWorkVest", [
                (1.106,0,-.007,.251,.184), (1.175,0,-.013,.271,.203),
                (1.340,0,-.013,.286,.233), (1.510,0,-.018,.309,.232),
                (1.671,0,-.011,.328,.216), (1.772,0,.002,.306,.180),
                (1.827,0,.004,.223,.155),
            ], finish, chest_weight, 22))
        if role in ("Camera", "Writer"):
            pieces.append(panel("Strap", [(-.21, 1.80, -.173), (-.145, 1.82, -.189),
                                          (.033, 1.53, -.263), (.24, 1.205, -.179),
                                          (.187, 1.168, -.190), (-.025, 1.505, -.263)],
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
                pieces.append(panel("HighVisibilityStripe", [(sign*.124, 1.78, -.182),
                                     (sign*.168, 1.77, -.178), (sign*.165, 1.37, -.222),
                                     (sign*.115, 1.37, -.242)], orange, "Chest", .025))
        if role == "Editor":
            for sign in (-1, 1):
                pieces.append(oval("Headphones", (sign*.138, 1.912, -.075), (.041, .060, .050), teal, "Chest"))
        if role == "Office":
            pieces.append(panel("Credential", [( .091,1.702,-.181),(.168,1.709,-.163),
                                               (.171,1.578,-.182),(.098,1.572,-.199)],
                                brass, "Chest", .018))
        if role == "Actor":
            pieces.append(loft("WrappedScarf", [(1.874,0,-.004,.117,.111),
                                                (1.913,0,-.010,.119,.108),
                                                (1.949,0,-.009,.109,.099)], knit, "Chest", 18))
            pieces.append(panel("ScarfFold", [(-.037,1.901,-.133),(.038,1.901,-.132),
                                              (.062,1.777,-.175),(.008,1.746,-.185)],
                                knit, "Chest", .026))
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
