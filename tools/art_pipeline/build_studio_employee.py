"""Build the original MovieStudio employee source and its runtime glTF."""

from math import cos, exp, sin, tau
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


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
    sides = 64
    sections = [
        (0.0, 1.0), (.19, 1.08), (.38, 1.067), (.57, .97),
        (.73, .78), (.86, .57), (.95, .35), (.99, .16), (1.0, .035),
    ]
    vertices = []
    for t, fullness in sections:
        for i in range(sides):
            theta = tau*i/sides
            front = max(0, -sin(theta))
            rear = max(0, sin(theta))
            hairline = 2.229 + (brow_height-2.229)*front**2 + (back_height-2.229)*rear**1.4
            hairline += sweep_amount*cos(theta)*front + wave * sin(theta*5+.45) * front
            strand = .005 * sin(theta * 13 + t * 3.5 * (1 if sweep_amount >= 0 else -1)) * sin(tau * (t+.04) / 2)
            x = (.232 + strand) * cos(theta)*fullness - sweep_amount*t*.57
            z = .026 + (.202 + strand) * sin(theta)*fullness + .026*t
            y = hairline + (crown_height-hairline)*t
            vertices.append((x, y, z))
    faces = [(base+i, base+i+sides, base+(i+1)%sides+sides, base+(i+1)%sides)
             for base in range(0, len(vertices)-sides, sides) for i in range(sides)]
    faces.extend([tuple(range(sides)), tuple(reversed(range(len(vertices)-sides, len(vertices))))])
    return mesh(name, vertices, faces, mat, "Head")


def eye_opening(name, x, y, z, mat):
    sections = [(-.044, 0, .013, .0015), (-.030, .001, .001, .011),
                (-.011, .002, -.004, .015), (.010, .002, -.004, .014),
                (.030, .001, .001, .009), (.044, -.001, .013, .0015)]
    return sweep(name, [(x+dx, y+dy, z+dz, width) for dx,dy,dz,width in sections], mat, "Head")


def complexion(obj):
    """Paint soft colour variation into the sculpt without introducing a skin-tone texture."""
    colors = obj.data.color_attributes.new(name="Complexion", type="BYTE_COLOR", domain="POINT")
    for vertex, color in zip(obj.data.vertices, colors.data):
        x, back, y = vertex.co
        front = max(0.0, min(1.0, (back + .04) / .20))
        cheek = exp(-((abs(x)-.137)/.078)**2 - ((y-2.140)/.058)**2)
        orbital = exp(-((abs(x)-.100)/.055)**2 - ((y-2.220)/.027)**2)
        jaw = exp(-((y-2.014)/.077)**2)
        color.color = (1-.06*orbital-.07*jaw,
                       1-front*(.10*cheek+.10*orbital)-.09*jaw,
                       1-front*(.15*cheek+.07*orbital)-.10*jaw, 1)
    obj.data.color_attributes.active_color = colors


def tailored_trousers(profile, mat):
    """Join both legs to one continuous waistband, with a skinned crotch seam."""
    sides = 24
    quarter = sides // 4
    points = []
    faces = []
    tube_length = sides * len(profile)
    for sign in (-1, 1):
        offset = len(points)
        for ring, (y, cx, cz, width, depth) in enumerate(profile):
            for step in range(sides):
                theta = tau * step / sides
                side = sign*cos(theta)
                height = y + .058*side if ring == len(profile)-1 else y
                points.append((sign*cx + width*cos(theta), height, cz + depth*sin(theta)))
        faces.append(tuple(range(offset, offset + sides)))
        for ring in range(len(profile)-1):
            for step in range(sides):
                a = offset + ring*sides + step
                b = offset + ring*sides + (step+1) % sides
                faces.append((a,a+sides,b+sides,b))

    def hip_ring_vertex(side, step):
        return side*tube_length + tube_length-sides + step % sides

    outer = [hip_ring_vertex(0, step) for step in range(quarter, 3*quarter+1)]
    outer += [hip_ring_vertex(1, step) for step in range(3*quarter, 5*quarter+1)]
    for step in range(2*quarter):
        left = 3*quarter+step
        right = 3*quarter-step
        faces.append((hip_ring_vertex(0, left), hip_ring_vertex(0, left+1),
                      hip_ring_vertex(1, right-1), hip_ring_vertex(1, right)))
    count = len(outer)
    for y, width, depth in ((.909,.216,.136), (1.025,.215,.143), (1.113,.202,.127), (1.162,.192,.116)):
        inner = []
        for index in range(count):
            theta = tau*(index/count + .25)
            inner.append(len(points))
            points.append((width*cos(theta), y, .007+depth*sin(theta)))
        for index in range(count):
            following = (index+1) % count
            faces.append((outer[index],inner[index],inner[following],outer[following]))
        outer = inner
    faces.append(tuple(reversed(outer)))

    def weights(point):
        x, y, _ = point
        shin = min(1.0, max(0.0, (.455-y)/.17))
        pelvis = min(1.0, max(0.0, (y-.66)/.29))
        upper = 1.0 - shin - pelvis
        right = min(1.0, max(0.0, .5+x/.11))
        return {"Pelvis": pelvis, "LeftThigh": upper*(1-right), "RightThigh": upper*right,
                "RightShin" if x > 0 else "LeftShin": shin}

    return mesh("TailoredTrousers", points, faces, mat, weights)


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
    if len(objects) > 1:
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


def fit_adult_head():
    # Keep all headwear, face morphs, and the animated lips in the same proportions.
    chin = 1.969
    proportions = Matrix.Diagonal((.72, .86, .67, 1.0))
    fit = Matrix.Translation((0, 0, 1.943)) @ proportions @ Matrix.Translation((0, 0, -chin))
    for obj in bpy.context.scene.objects:
        if obj.name in {"Face", "RoleDirector", "CostumeWestern"} or obj.name.startswith("Hair"):
            obj.data.transform(fit, shape_keys=True)
    bpy.data.objects["MouthShape"].data.transform(proportions)


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
    hair = material("Hair", (0.12, 0.07, 0.045), .84)
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
    lip = material("Lip", (0.18, 0.072, 0.062))
    teal = material("EquipmentTeal", (0.05, 0.20, 0.20))
    orange = material("EquipmentOchre", (0.46, 0.20, 0.035))

    def chest_weight(point):
        strength = max(0.0, min(1.0, (point[1] - 1.05) / 0.40))
        return {"Chest": strength, "Pelvis": 1.0 - strength}

    jacket = loft("TailoredJacket", [
        (1.085, 0, .009, .205, .128), (1.112, 0, .009, .225, .147),
        (1.21, 0, .004, .211, .136), (1.33, 0, .008, .219, .143),
        (1.49, 0, -.005, .250, .164), (1.62, 0, -.007, .274, .161),
        (1.71, 0, -.004, .300, .146), (1.754, 0, .001, .292, .139),
        (1.795, 0, .003, .251, .127), (1.838, 0, .004, .177, .111),
        (1.885, 0, .003, .111, .087),
    ], cloth, chest_weight, 28)
    leg = [
        (.090, .143, .005, .064, .068), (.135, .143, .008, .071, .077),
        (.237, .143, .012, .080, .083), (.322, .141, .014, .086, .087),
        (.384, .136, .008, .086, .084), (.440, .133, -.001, .085, .092),
        (.525, .128, -.009, .093, .107), (.679, .126, -.008, .109, .120),
        (.804, .119, .002, .114, .119),
    ]
    sleeves = []
    tights = []
    trim = [loft("Neck", [
        (1.819, 0, .012, .115, .100), (1.872, 0, .014, .097, .086),
        (1.925, 0, .018, .085, .075), (1.974, 0, .014, .086, .078),
        (1.993, 0, .005, .077, .072),
    ], skin, "Chest", 20)]
    trim.append(loft("ShirtNeckband", [
        (1.856, 0, .006, .100, .087), (1.878, 0, .006, .090, .081),
        (1.909, 0, .006, .083, .076),
    ], shirt, "Chest", 16))
    trim.append(panel("ShirtPlacket", [(-.047, 1.875, -.122), (.047, 1.875, -.122),
                                       (.040, 1.824, -.136), (.024, 1.764, -.151),
                                       (.008, 1.742, -.155), (-.008, 1.742, -.155),
                                       (-.024, 1.764, -.151), (-.040, 1.824, -.136)],
                          shirt, "Chest", .012))
    tailoring = material("TailoringEdge", (.168, .202, .215), .94)
    jacket_details = []
    for sign in (-1, 1):
        side = "Left" if sign < 0 else "Right"
        jacket_details.append(panel("NotchedLapel", [
            (sign*.065, 1.872, -.098), (sign*.130, 1.827, -.119),
            (sign*.113, 1.772, -.142), (sign*.149, 1.765, -.143),
            (sign*.041, 1.570, -.169), (sign*.062, 1.761, -.150),
        ], tailoring, "Chest", .010))
        jacket_details.append(panel("WeltPocket", [
            (sign*.095, 1.273, -.128), (sign*.188, 1.288, -.099),
            (sign*.191, 1.272, -.098), (sign*.095, 1.258, -.127),
        ], tailoring, chest_weight, .009))
        if sign < 0:
            for y, z in ((1.195, -.145), (1.30, -.148), (1.405, -.160)):
                jacket_details.append(oval("Button", (.013, y, z), (.009, .009, .005), brass, "Chest", 8))

        def arm_weight(point, side=side):
            strength = max(0.0, min(1.0, (1.52 - point[1]) / 0.18))
            shoulder = max(0.0, min(.48, (point[1] - 1.66) * 3.4))
            return {"Chest": shoulder, side + "Arm": 1.0 - strength - shoulder, side + "Forearm": strength}

        sleeves.append(loft("Sleeve", [
            (1.105, sign*.407, -.010, .051, .052), (1.142, sign*.408, -.009, .056, .059),
            (1.218, sign*.413, -.005, .065, .067), (1.325, sign*.407, .006, .079, .073),
            (1.425, sign*.392, .009, .081, .079), (1.493, sign*.382, .010, .088, .085),
            (1.612, sign*.351, .004, .100, .093), (1.704, sign*.312, .003, .103, .097),
            (1.751, sign*.282, .003, .087, .087), (1.779, sign*.251, .005, .061, .072),
        ], cloth, arm_weight, 20))
        trim.append(loft("SleeveCuff", [(1.088, sign*.407, -.010, .046, .047),
                                        (1.116, sign*.408, -.009, .052, .053)],
                         shirt, arm_weight, 16))
        trim.append(loft("ShapedPalm", [
            (.998, sign*.413, -.024, .024, .029), (1.017, sign*.411, -.019, .033, .033),
            (1.051, sign*.410, -.011, .034, .043), (1.080, sign*.408, -.008, .034, .039),
            (1.112, sign*.407, -.008, .033, .034),
        ], skin, side + "Forearm", 14))
        trim.append(loft("ShapedThumb", [
            (.984, sign*.382, -.049, .007, .007), (1.011, sign*.378, -.046, .012, .012),
            (1.041, sign*.381, -.032, .016, .016), (1.064, sign*.392, -.024, .018, .017),
        ], skin, side + "Forearm", 10))
        for offset, reach in ((-.030, .035), (-.010, .056), (.011, .051), (.031, .032)):
            trim.append(loft("RelaxedFinger", [
                (1.006-reach, sign*.396, offset-.032, .006, .006),
                (1.018-reach, sign*.403, offset-.027, .009, .009),
                (1.011, sign*.417, offset-.010, .010, .010),
                (1.027, sign*.418, offset-.006, .010, .010),
            ], skin, side + "Forearm", 8))

        def leg_weight(point, side=side):
            strength = max(0.0, min(1.0, (0.455 - point[1]) / 0.17))
            return {side + "Thigh": 1.0 - strength, side + "Shin": strength}

        tights.append(loft("TightLeg", [
            (y, sign*cx, cz, width*(.90 if y < .61 else .68), depth*(.84 if y < .61 else .66))
            for y,cx,cz,width,depth in leg
        ], trousers, leg_weight, 22))
        shoe = [(.008, sign*.146, -.066, .085, .153), (.020, sign*.146, -.074, .093, .161),
                (.039, sign*.145, -.073, .092, .159), (.049, sign*.145, -.070, .090, .158)]
        trim.append(loft("Sole", shoe, rubber, side + "Foot", 16))
        trim.append(loft("Shoe", [shoe[-1],
                                 (.071, sign*.146, -.072, .090, .152),
                                 (.093, sign*.145, -.060, .081, .132),
                                 (.121, sign*.143, -.038, .068, .101),
                                 (.151, sign*.143, -.013, .063, .078)],
                         shoe_upper, side + "Foot", 22))
        for row in range(3):
            yy = .118 - row*.008
            zz = -.137 - row*.015
            trim.append(panel("ShoeLace", [(sign*.113, yy, zz), (sign*.174, yy, zz),
                                          (sign*.174, yy-.004, zz-.006), (sign*.113, yy-.004, zz-.006)],
                              shirt, side + "Foot", .004))
    def tailored(x, y, z):
        return (
            x * (1.0 - 0.13 * max(0.0, 1 - abs(y - 1.77) / 0.57)
                 + 0.07 * max(0.0, 1 - abs(y - 0.97) / 0.21)),
            y, z - 0.022 * max(0.0, 1 - abs(y - 1.57) / 0.19) if z < 0 else z,
        )

    def relaxed(x, y, z):
        return (
            x * (1 + .084 * max(0, 1 - abs(y - 1.23) / .54)), y,
            z * (1 + .14 * max(0, 1 - abs(y - 1.34) / .41)),
        )

    def structured(x, y, z):
        return x * (1 + .10 * max(0, 1 - abs(y - 1.70) / .27)), y, z

    body = join("WardrobeBody", sleeves + trim, rig)
    join("Trousers", [tailored_trousers(leg, trousers)], rig)
    join("Tights", tights, rig)
    jacket = join("Jacket", [jacket] + jacket_details, rig)
    for part in (body, jacket):
        shape(part, "TailoredSilhouette", tailored)
        shape(part, "RelaxedFit", relaxed)
        shape(part, "StructuredShoulders", structured)
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
        (.631, 0, .005, .236, .155), (.647, 0, .005, .235, .156),
        (.764, 0, .004, .242, .161), (.890, 0, .002, .253, .169),
        (1.004, 0, .000, .249, .170), (1.130, 0, -.001, .225, .150),
    ], knit, skirt_weight, 26, lambda x,y,z: (x,y,z + .005*cos(x*42) * max(0, (1.04-y)/.41)))], rig)

    def facial_planes(x, y, z):
        front = min(1.0, max(0.0, (-z-.037)/.115))
        ax = abs(x)
        socket = .026 * exp(-((ax-.096)/.061)**2 - ((y-2.236)/.049)**2)
        cheek = .017 * exp(-((ax-.142)/.068)**2 - ((y-2.162)/.067)**2)
        bridge = .039 * exp(-(x/.047)**2 - ((y-2.197)/.068)**2)
        tip = .048 * exp(-(x/.052)**2 - ((y-2.153)/.031)**2)
        nostril_wing = .018 * exp(-((ax-.032)/.025)**2 - ((y-2.139)/.017)**2)
        muzzle = .027 * exp(-(x/.090)**2 - ((y-2.086)/.049)**2)
        return x, y, z + front * (socket-cheek-bridge-tip-nostril_wing-muzzle)

    face = [loft("SculptedHead", [
        (1.969,0,-.058,.074,.081), (1.988,0,-.044,.112,.111),
        (2.013,0,-.031,.149,.143), (2.044,0,-.016,.176,.166),
        (2.079,0,-.009,.193,.178), (2.110,0,-.003,.208,.184),
        (2.137,0,.004,.223,.188), (2.146,0,.004,.226,.189),
        (2.156,0,.002,.228,.190), (2.164,0,0,.230,.192),
        (2.173,0,-.002,.231,.194), (2.192,0,-.002,.230,.198),
        (2.214,0,.002,.231,.201), (2.232,0,.005,.232,.198),
        (2.253,0,.008,.232,.195), (2.280,0,.014,.232,.190),
        (2.316,0,.026,.223,.185), (2.352,0,.032,.201,.165),
        (2.390,0,.041,.167,.137), (2.425,0,.040,.114,.095),
        (2.451,0,.024,.051,.053),
    ], skin, "Head", 48, facial_planes)]
    for sign in (-1, 1):
        x = sign*.098
        face.append(oval("Ear", (sign*.222, 2.171, .022), (.032, .050, .024), skin, "Head", 16))
        face.append(oval("Concha", (sign*.239, 2.172, .005), (.012, .027, .011), skin_shade, "Head"))
        face.append(eye_opening("AlmondEye", x, 2.231, -.171, eye))
        face.append(oval("ColoredIris", (x, 2.232, -.182), (.013, .013, .006), iris, "Head", 14))
        face.append(oval("Pupil", (x, 2.232, -.187), (.007, .010, .004), pupil, "Head", 12))
        face.append(oval("Catchlight", (x-.004, 2.236, -.190), (.0028, .0028, .0020), eye, "Head", 8))
        lid = [(x-.043,2.231,-.157,.0025), (x-.027,2.242,-.171,.0045),
               (x,2.245,-.179,.005), (x+.026,2.241,-.170,.0045), (x+.043,2.229,-.156,.002)]
        face.append(sweep("UpperLidFold", lid, skin_shade, "Head"))
        face.append(sweep("LowerLid", [(x-.041, 2.231, -.150, .002), (x-.023, 2.222, -.165, .004),
                                      (x, 2.219, -.172, .004), (x+.021, 2.222, -.165, .004),
                                      (x+.041, 2.229, -.149, .002)], skin, "Head"))
        face.append(oval("Nostril", (sign*.031, 2.143, -.224), (.011, .0050, .0035), skin_shade, "Head", 10))
        arch = [(sign*.049,2.273,-.184,.0035),(sign*.078,2.284,-.184,.008),
                (sign*.110,2.286,-.173,.0077),(sign*.139,2.279,-.159,.0061),
                (sign*.157,2.269,-.143,.0025)]
        face.append(sweep("ExpressiveBrow", sorted(arch), hair, "Head"))
    face_mesh = join("Face", face, rig)
    complexion(face_mesh)
    shape(face_mesh, "SoftJaw", lambda x,y,z: (
        x * (1-.14*max(0,1-abs(y-2.038)/.145)), y, z,
    ))
    shape(face_mesh, "HighCheekbones", lambda x,y,z: (
        x * (1+.065*max(0,1-abs(y-2.163)/.062)), y, z,
    ))
    lower_lip = material("LowerLip", (.28, .106, .079), .73)
    join("MouthShape", [
        sweep("LipSeam", [(-.055,.003,.013,.002),(-.036,.001,.007,.0033),
                          (-.014,.001,-.001,.0046),(0,0,-.004,.0038),
                          (.016,.001,-.001,.0047),(.038,.002,.007,.0033),
                          (.055,.004,.013,.002)], lip, None),
        sweep("LowerLip", [(-.040,-.002,.008,.0009),(-.024,-.006,-.001,.0023),
                           (0,-.010,-.005,.0045),(.024,-.006,-.001,.0023),
                           (.041,-.001,.008,.0009)], lower_lip, None),
    ], None)

    hair_profiles = [
        (2.339,2.199,.047,.009,2.495), (2.339,2.065,-.046,.010,2.500),
        (2.350,2.196,.010,.026,2.493), (2.351,2.192,.027,.009,2.499),
        (2.359,2.239,-.004,.004,2.469), (2.365,1.991,.037,.008,2.505),
        (2.379,2.213,-.039,.008,2.519), (2.346,2.043,.057,.009,2.505),
    ]
    for style,profile in enumerate(hair_profiles):
        pieces = [hair_shell("SculptedHair", hair, *profile)]
        if style == 2:
            for x,y,z in [(-.138,2.429,-.088),(-.075,2.460,-.111),(.008,2.474,-.103),(.098,2.454,-.081)]:
                pieces.append(oval("Coil",(x,y,z),(.064,.040,.051),hair,"Head",14))
        if style == 3:
            pieces.append(oval("TiedChignon",(.021,2.246,.221),(.109,.085,.083),hair,"Head",20))
        if style in (1,5,7):
            for sign in (-1,1):
                tip = 2.026 if style == 5 else 2.116
                pieces.append(loft("TaperedSideSection", [
                    (tip,sign*.198,.034,.018,.036),
                    (tip+.046,sign*.213,.032,.036,.062),
                    (2.218,sign*.212,.025,.039,.092),
                    (2.270,sign*.206,.022,.040,.122),
                    (2.318,sign*.200,.023,.039,.119),
                    (2.360,sign*.172,.026,.040,.099),
                ], hair, "Head", 22))
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

    def work_vest(name, fabric):
        vest = join(name, [loft("TailoredWorkVest", [
            (1.092,0,.008,.211,.138), (1.127,0,.005,.223,.149),
            (1.230,0,.004,.216,.153), (1.343,0,.002,.231,.158),
            (1.510,0,-.003,.258,.178), (1.654,0,-.002,.280,.169),
            (1.740,0,.001,.273,.151), (1.796,0,.006,.214,.131),
            (1.845,0,.007,.139,.104), (1.874,0,.007,.109,.087),
        ], fabric, chest_weight, 36)], rig)
        shape(vest, "TailoredSilhouette", tailored)
        shape(vest, "RelaxedFit", relaxed)
        shape(vest, "StructuredShoulders", structured)

    work_vest("CanvasVest", canvas)
    work_vest("WoolVest", washed_wool)
    for role, accent, bag_side in [("Camera", teal, -1), ("Technician", orange, 1),
                                   ("Writer", leather, 1), ("Editor", teal, 1),
                                   ("Office", brass, -1), ("Actor", shirt, -1)]:
        pieces = []
        if role in ("Technician", "Camera", "Writer"):
            for direction in (-1, 1):
                x = direction * .11
                pieces.append(panel("VestWelt", [
                    (x-direction*.039,1.249,-.169), (x+direction*.056,1.263,-.138),
                    (x+direction*.057,1.247,-.137), (x-direction*.037,1.231,-.165),
                ], accent, chest_weight, .009))
        if role in ("Camera", "Writer"):
            pieces.append(panel("Strap", [(-.20, 1.80, -.103), (-.153, 1.81, -.134),
                                          (.024, 1.52, -.200), (.223, 1.246, -.109),
                                          (.192, 1.223, -.126), (-.016, 1.517, -.201)],
                                accent, chest_weight, .017))
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
            pieces.append(loft("WrappedScarf", [(1.861,0,.006,.105,.090),
                                                (1.881,0,.003,.099,.089),
                                                (1.906,0,.006,.090,.082)], knit, "Chest", 24))
            pieces.append(panel("ScarfFold", [(-.027,1.884,-.104),(.029,1.885,-.102),
                                              (.041,1.784,-.142),(-.011,1.756,-.150)],
                                knit, "Chest", .017))
        variant = join("Role" + role, pieces, rig)
        if role in ("Technician", "Camera", "Writer"):
            shape(variant, "TailoredSilhouette", tailored)
            shape(variant, "RelaxedFit", relaxed)
            shape(variant, "StructuredShoulders", structured)

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

    fit_adult_head()
    animate(rig)
    bpy.context.scene.render.fps = 24
    bpy.context.scene.frame_set(1)
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", export_vertex_color="ACTIVE",
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True)


if __name__ == "__main__":
    build()
