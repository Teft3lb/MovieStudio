"""Build the original MovieStudio office furniture mesh library."""

from math import cos, sin, tau
from pathlib import Path
import sys

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.dont_write_bytecode = True
from build_stage_equipment import assemble, box, rod
from build_studio_employee import material


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    oak = material("StudioWalnut", (.35, .17, .065), .62)
    edge = material("WalnutEdge", (.18, .075, .035), .65)
    steel = material("SlateSteel", (.12, .18, .20), .55, .35)
    charcoal = material("DarkPolymer", (.038, .053, .063), .69)
    teal = material("FeltTeal", (.043, .19, .20), .94)
    paper = material("IvoryPaper", (.71, .64, .49), .94)
    key = material("KeyboardKeys", (.28, .32, .31), .78)
    caster = material("CasterHousing", (.19, .22, .22), .72, .18)
    screen = material("MonitorGlass", (.036, .18, .22), .32)
    accent = material("InterfaceAmber", (.66, .31, .075), .63)
    signal = material("InterfaceCyan", (.11, .40, .44), .61)

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
