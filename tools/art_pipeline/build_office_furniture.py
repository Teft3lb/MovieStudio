"""Build the original MovieStudio office furniture mesh library."""

from math import cos, sin, tau
from pathlib import Path
import sys

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.dont_write_bytecode = True
from build_stage_equipment import assemble, box, rod
from build_studio_employee import material, oval
from build_interior_details import build_room_details


def tint_with_grain(finish, color, name, textile=False):
    size = 96
    image = bpy.data.images.new(name, width=size, height=size, alpha=False)
    samples = []
    for row in range(size):
        v = tau * row / size
        for column in range(size):
            u = tau * column / size
            if textile:
                value = .96 + .025 * cos(u*24) * cos(v*24) + .015 * sin(u*5 + v*3)
            else:
                wave = v*9 + .53*sin(u*2 + v) + .22*cos(u*3-v*2)
                value = .91 + .055*sin(wave) + .024*cos(wave*2) + .011*sin(v*31)
            samples.extend([*((channel * value) ** (1 / 2.2) for channel in color), 1.0])
    image.pixels.foreach_set(samples)
    image.pack()
    graph = finish.node_tree
    texture = graph.nodes.new("ShaderNodeTexImage")
    texture.image = image
    graph.links.new(texture.outputs["Color"], graph.nodes.get("Principled BSDF").inputs["Base Color"])


def build_interior_details(oak, edge, steel, charcoal, teal, paper, screen, accent):
    rust = material("TerracottaUpholstery", (.42, .13, .077), .92)
    leaf = material("BroadLeaf", (.10, .27, .095), .86)
    brass = material("BrushedBrass", (.52, .32, .117), .44, .42)
    assemble("ScriptLibrary", [
        box("Back", (0, 1.04, -.21), (2.08, 2.03, .10), edge),
        *[box("Side", (x, 1.04, 0), (.08, 2.06, .48), oak) for x in (-1.03, 1.03)],
        *[box("Shelf", (0, y, 0), (2.12, .073, .50), oak)
          for y in (.14, .54, .97, 1.39, 1.80, 2.08)],
        *[box("Binder", (-.88 + i*.178, y + .155 + (i%3)*.013, .015),
              (.12, .238 + (i%3)*.026, .33), (paper, teal, rust, edge)[(i+j)%4], .009)
          for j, y in enumerate((.14, .54, .97, 1.39)) for i in range(11) if (i+j)%5 != 4],
    ])
    assemble("StoryBoard", [
        box("Frame", (0, 0, 0), (2.12, 1.3, .095), oak, .035),
        box("Cork", (0, 0, .049), (1.96, 1.14, .024), edge),
        *[box("BeatCard", ((i%4-1.5)*.435, .28-(i//4)*.49 + (i%3)*.032, .069),
              (.32, .29, .012), (paper, paper, accent, teal)[i%4], .008) for i in range(8)],
        *[box("NoteLine", ((i%4-1.5)*.435, .30-(i//4)*.49 + (i%3)*.032, .078),
              (.22, .018, .005), edge, .001) for i in range(8)],
    ])
    assemble("TaskLamp", [
        rod("Foot", (0, .005, 0), (0, .043, 0), .118, .104, charcoal),
        rod("LowerArm", (0, .041, 0), (0, .31, -.08), .017, .019, brass),
        rod("UpperArm", (0, .31, -.08), (0, .41, .12), .019, .018, brass),
        rod("Shade", (0, .36, .15), (0, .48, .11), .106, .043, teal),
        rod("Diffuser", (0, .356, .152), (0, .369, .148), .078, .078, paper),
    ])
    assemble("EquipmentRack", [
        box("Chassis", (0, .87, 0), (1.20, 1.74, .58), charcoal, .028),
        *[box("Rail", (x, .89, .29), (.057, 1.64, .06), steel) for x in (-.55, .55)],
        *[box("Case", (0, y, .296), (1.01, .23, .06), steel, .014) for y in (.27, .57, .87, 1.17, 1.47)],
        *[box("Pull", (0, y, .341), (.26, .041, .049), edge) for y in (.27, .57, .87, 1.17, 1.47)],
        *[box("Status", (.39, y, .334), (.078, .036, .022), accent) for y in (.27, .57, .87, 1.17, 1.47)],
    ])
    assemble("PreviewWall", [
        box("Housing", (0, 0, 0), (3.38, 1.52, .13), charcoal, .06),
        box("Glass", (0, .05, .076), (3.24, 1.31, .025), screen, .025),
        *[box("Track", (-1.4+w*.5, -0.04-i*.128, .094),
              (w, .067, .008), (teal, accent, paper)[i%3], .005)
          for i, w in enumerate((2.25, 1.70, 2.78, 1.23))],
        box("Playhead", (.28, -.24, .106), (.028, .56, .007), paper, .001),
    ])
    assemble("CoffeeMachine", [
        box("Base", (0, .065, 0), (.69, .13, .57), charcoal, .034),
        box("Boiler", (0, .37, -.13), (.68, .63, .32), steel, .06),
        box("Header", (0, .60, .063), (.69, .17, .39), teal, .038),
        box("Buttons", (.14, .602, .269), (.26, .055, .021), charcoal),
        box("Display", (-.145, .6, .271), (.13, .063, .023), accent),
        *[rod("Cup", (x, .131, .16), (x, .25, .16), .047, .062, paper) for x in (-.14, .12)],
        *[rod("Nozzle", (x, .47, .13), (x, .54, .13), .034, .043, charcoal) for x in (-.14, .12)],
    ])
    assemble("WaterCooler", [
        box("Pedestal", (0, .49, 0), (.45, .98, .48), paper, .048),
        box("TapTray", (0, .67, .25), (.36, .073, .17), charcoal, .017),
        box("Tap", (0, .865, .263), (.10, .09, .095), teal),
        rod("Bottle", (0, .98, -.035), (0, 1.40, -.035), .189, .183, screen, 14),
        rod("BottleShoulder", (0, 1.40, -.035), (0, 1.46, -.035), .183, .092, teal, 14),
    ])
    assemble("WasteStation", [
        box("Bin", (0, .38, 0), (.79, .75, .47), steel, .042),
        box("Lid", (0, .77, 0), (.83, .10, .51), charcoal, .025),
        *[box("Slot", (x, .802, .07), (.22, .052, .16), m, .016)
          for x, m in ((-.20, teal), (.20, accent))],
    ])
    assemble("ServingLine", [
        *[box("Insert", (x, .027, 0), (.57, .054, .39), steel, .023) for x in (-.64, 0, .64)],
        *[box("FoodPan", (x, .059, 0), (.47, .026, .29), m, .021)
          for x, m in ((-.64, leaf), (0, accent), (.64, rust))],
        *[rod("Upright", (x, 0, -.22), (x, .36, -.22), .025, .025, steel) for x in (-1.0, 1.0)],
        box("Rail", (0, .36, -.22), (2.07, .063, .068), steel),
    ])
    for name, width, upholstery in [("ClubSofa", 1.94, rust), ("ClubChair", 1.03, teal)]:
        assemble(name, [
            box("Frame", (0, .32, 0), (width, .21, .87), oak, .048),
            box("Back", (0, .73, -.33), (width-.07, .62, .22), upholstery, .087),
            *[box("Seat", (x, .465, .035), (width/(2 if width > 1.1 else 1)-.22, .19, .65),
                  upholstery, .075) for x in ((-.43, .43) if width > 1.1 else (0,))],
            *[box("Arm", (x, .55, .06), (.16, .46, .77), upholstery, .066)
              for x in (-width/2+.084, width/2-.084)],
            *[box("Foot", (x, .109, z), (.095, .21, .093), charcoal, .021)
              for x in (-width/2+.17, width/2-.17) for z in (-.31,.31)],
        ])
    for name, width, height, depth, finish in [
        ("Locker", .79, 1.88, .55, steel),
        ("Wardrobe", 1.15, 2.15, .80, oak),
        ("Nightstand", .76, .70, .65, oak),
    ]:
        assemble(name, [
            box("Carcass", (0, height*.5, 0), (width, height, depth), edge, .028),
            *[box("Door", (0, y, depth*.5), (width-.072, height*.43, .073), finish, .03)
              for y in (height*.26, height*.74)],
            *[box("Handle", (width*.20, y, depth*.5+.058), (.17, .033, .04), brass)
              for y in (height*.38, height*.61)],
        ])
    assemble("ClubTable", [
        box("Top", (0, .59, 0), (1.78, .12, 1.04), oak, .047),
        *[box("Leg", (x, .285, z), (.093, .56, .095), steel)
          for x in (-.70, .70) for z in (-.36, .36)],
        box("Magazine", (.23, .666, .02), (.35, .028, .39), teal, .01),
        box("Cover", (.23, .685, .02), (.29, .011, .28), paper, .008),
        rod("Mug", (-.37, .66, -.21), (-.37, .79, -.21), .053, .066, paper),
    ])
    plant = [rod("Pot", (0, .015, 0), (0, .47, 0), .23, .32, rust, 14),
             rod("Soil", (0, .455, 0), (0, .478, 0), .29, .29, edge, 14)]
    for i in range(7):
        angle = i*tau/7
        x, z = cos(angle)*(.28+(i%2)*.10), sin(angle)*(.28+(i%2)*.10)
        y = .85+(i%3)*.13
        plant.append(rod("Stem", (0, .43, 0), (x, y, z), .013, .01, leaf, 6))
        blade = oval("Leaf", (x, y, z), (.131, .24, .071), leaf, None, 8)
        blade.rotation_euler.y = -.43 if x > 0 else .43
        plant.append(blade)
    assemble("FloorPlant", plant)
    assemble("FlightCaseCart", [
        box("Case", (0, .385, 0), (1.18, .57, .69), charcoal, .034),
        box("Lid", (0, .70, 0), (1.21, .12, .72), steel, .031),
        *[box("CornerBand", (x, .385, .348), (.058, .57, .037), steel) for x in (-.54, .54)],
        *[box("Latch", (x, .586, .371), (.108, .10, .04), brass) for x in (-.30, .30)],
        *[box("Wheel", (x, .055, z), (.125, .11, .145), charcoal, .032)
          for x in (-.49, .49) for z in (-.25, .25)],
    ])
    assemble("CostumeRail", [
        *[rod("Post", (x, .06, 0), (x, 1.68, 0), .036, .034, steel) for x in (-.72, .72)],
        *[box("Foot", (x, .038, 0), (.10, .075, .50), charcoal) for x in (-.72, .72)],
        rod("Rail", (-.73, 1.65, 0), (.73, 1.65, 0), .024, .024, brass),
        *[box("Garment", (x, 1.105 + (i%2)*.13, 0), (.17, .91 - (i%2)*.26, .39),
              (rust, paper, teal)[i%3], .065)
          for i, x in enumerate((-.52, -.30, -.08, .14, .36, .56))],
    ])
    assemble("CableRun", [
        box("Guard", (0, .028, 0), (.35, .055, 2.22), charcoal, .015),
        *[box("Stripe", (0, .056, z), (.35, .01, .052), accent, .002)
          for z in (-.92, -.46, 0, .46, .92)],
    ])


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    oak = material("StudioWalnut", (.32, .166, .085), .58)
    edge = material("WalnutEdge", (.18, .075, .035), .65)
    steel = material("SlateSteel", (.12, .18, .20), .44, .43)
    charcoal = material("DarkPolymer", (.038, .053, .063), .69)
    teal = material("FeltTeal", (.054, .153, .158), .92)
    paper = material("IvoryPaper", (.71, .64, .49), .94)
    key = material("KeyboardKeys", (.28, .32, .31), .78)
    caster = material("CasterHousing", (.19, .22, .22), .72, .18)
    screen = material("MonitorGlass", (.026, .13, .166), .26)
    accent = material("InterfaceAmber", (.66, .31, .075), .63)
    signal = material("InterfaceCyan", (.11, .40, .44), .61)
    tint_with_grain(oak, (.32, .166, .085), "Studio walnut grain")
    tint_with_grain(teal, (.054, .153, .158), "Tight upholstery weave", textile=True)

    for name, width, depth, finish in [
        ("WriterDesk", 1.75, .85, oak), ("EditingDesk", 2.45, .95, steel),
    ]:
        pieces = [
            box("Countertop", (0, .855, 0), (width, .09, depth), finish, .035),
            box("EdgeBand", (0, .795, 0), (width - .045, .05, depth - .025), edge, .014),
            box("CableRail", (0, .61, -depth*.36), (width-.29, .14, .085), steel),
        ]
        for side in (-1, 1):
            for z in (-depth*.34, depth*.34):
                x = side * (width*.5-.13)
                pieces.append(box("TaperedLeg", (x, .40, z), (.095, .79, .095), steel, .012))
                pieces.append(box("RubberFoot", (x, .045, z), (.109, .06, .109), charcoal))
        if name == "WriterDesk":
            pieces.extend([
                box("Drawer", (-.61, .698, .07), (.34, .19, .55), finish),
                box("DrawerPull", (-.61, .68, .371), (.14, .028, .039), steel),
                box("ScriptStack", (.61, .925, -.14), (.26, .047, .32), paper, .007),
                box("Folder", (.60, .901, -.136), (.29, .025, .36), teal, .006),
            ])
        assemble(name, pieces)

    chair = [
        box("Seat", (0, .48, .05), (.65, .115, .62), teal, .052),
        box("SeatShell", (0, .408, .05), (.60, .075, .57), charcoal, .03),
        box("Backrest", (0, .805, .327), (.58, .56, .105), teal, .05),
        box("LumbarFrame", (0, .65, .382), (.43, .37, .066), charcoal, .029),
        rod("Spindle", (0, .11, .04), (0, .41, .04), .049, .067, steel),
    ]
    for index in range(5):
        angle = tau * index / 5
        foot = (cos(angle)*.30, .08, .04 + sin(angle)*.30)
        chair.append(rod("CasterBase", (0, .134, .04), foot, .056, .043, caster, 8))
        chair.append(box("Caster", (foot[0], .05, foot[2]), (.094, .078, .098), charcoal, .025))
    assemble("OfficeChair", chair)

    monitor = [
        box("DisplayHousing", (0, .282, 0), (.73, .448, .075), charcoal, .018),
        box("Display", (0, .299, .04), (.67, .378, .012), screen, .014),
        box("Foot", (0, .026, .006), (.31, .048, .22), steel, .016),
        box("Neck", (0, .135, -.014), (.10, .207, .071), steel),
        box("PowerLight", (.29, .095, .045), (.023, .009, .01), accent, .002),
    ]
    for index, width in enumerate((.44, .51, .29, .47, .33)):
        monitor.append(box("DisplayLine", (-.28+width*.5, .388-index*.038, .048),
                           (width, .012, .003), signal, .001))
    assemble("OfficeMonitor", monitor)

    keyboard = [box("Chassis", (0, .018, 0), (.57, .032, .203), charcoal, .013)]
    for row in range(4):
        for col in range(13):
            if row == 0 and 4 <= col <= 8:
                continue
            keyboard.append(box("Key", ((col-6)*.041, .036, .067-row*.043),
                                (.032, .008, .032), key, .002))
    keyboard.append(box("SpaceBar", (0, .036, .067), (.194, .008, .032), key, .002))
    assemble("OfficeKeyboard", keyboard)

    mixer = [box("MixerHousing", (0, .07, 0), (.58, .14, .37), steel, .024)]
    for index in range(7):
        x = (index - 3) * .068
        mixer.append(box("FaderTrack", (x, .144, .072), (.017, .009, .152), charcoal, .003))
        mixer.append(box("FaderCap", (x, .154, .016 + (index % 3)*.034),
                         (.038, .022, .026), paper, .005))
        mixer.append(rod("GainKnob", (x, .142, -.096), (x, .179, -.096), .021, .017, accent))
    assemble("AudioMixer", mixer)

    dining = [box("Tabletop", (0, .835, 0), (2.1, .10, 1.25), oak, .044),
              box("Apron", (0, .747, 0), (1.98, .103, 1.10), edge, .021)]
    dining_chair = [box("DiningSeat", (0, .485, 0), (.60, .105, .59), teal, .042)]
    for sign in (-1, 1):
        for z in (-.44, .44):
            dining.append(box("TableLeg", (sign*.85, .389, z), (.096, .77, .096), steel, .012))
        for z in (-.23, .23):
            dining_chair.append(rod("DiningLeg", (sign*.22, .465, z),
                                    (sign*.258, .044, z*1.17), .032, .038, steel, 8))
        dining_chair.append(rod("BackSupport", (sign*.23, .46, .24),
                                (sign*.23, .89, .31), .033, .034, steel, 8))
    for x in (-.50, .50):
        for z in (-.34, .34):
            dining.append(rod("Plate", (x, .886, z), (x, .908, z), .108, .126, paper, 18))
            dining.append(rod("Glass", (x+.18, .882, z*.55), (x+.18, .98, z*.55), .037, .045, screen))
            dining.append(box("Cutlery", (x-.174, .89, z), (.027, .017, .193), steel, .006))
    assemble("DiningTable", dining)
    assemble("DiningChair", dining_chair)
    assemble("DiningChairBack", [box("DiningBack", (0, 0, 0), (.58, .33, .12), teal, .033)])

    bed = [
        box("BedPlatform", (0, .233, 0), (1.55, .19, 1.95), oak, .036),
        box("Headboard", (0, .52, -.94), (1.52, .76, .12), edge, .054),
        box("HeadboardInlay", (0, .675, -.869), (1.29, .29, .05), teal, .037),
    ]
    for side in (-1, 1):
        for end in (-1, 1):
            bed.append(box("BedFoot", (side*.646, .101, end*.819), (.139, .186, .14), edge, .022))
    assemble("BedFrame", bed)
    mattress = [
        box("MattressCore", (0, 0, 0), (1.42, .201, 1.82), paper, .063),
        box("MattressSeam", (0, -.039, 0), (1.435, .027, 1.83), key, .012),
        box("FoldedBlanket", (0, .093, .67), (1.36, .045, .39), teal, .027),
    ]
    assemble("BedMattress", mattress)
    assemble("BedPillow", [box("Cushion", (0, 0, 0), (.78, .154, .46), paper, .068)])
    build_interior_details(oak, edge, steel, charcoal, teal, paper, screen, accent)
    build_room_details(oak, edge, steel, charcoal, teal, paper, screen, accent)

    root = HERE.parents[1]
    source = root / "art_source" / "furniture" / "office_furniture.blend"
    target = root / "assets" / "models" / "furniture" / "office_furniture.glb"
    source.parent.mkdir(parents=True, exist_ok=True)
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", export_animations=False)


if __name__ == "__main__":
    build()
