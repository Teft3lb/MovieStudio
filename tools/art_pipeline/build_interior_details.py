"""Additional shared furniture for the MovieStudio room layouts."""

from math import cos, sin, tau

from build_stage_equipment import assemble, box, rod
from build_studio_employee import material, oval, panel


def build_room_details(oak, edge, steel, dark, teal, paper, glass, amber):
    cream = material("GlazedPorcelain", (.79, .73, .58), .36)
    clay = material("BurntTerracotta", (.39, .155, .083), .86)
    plum = material("PlumTextile", (.145, .077, .096), .94)
    ice = material("SteelBluePaint", (.19, .34, .43), .57)
    front = .042

    for name, base, line in [("DiningInset", clay, paper), ("RestInset", plum, clay),
                             ("TechnicalInset", dark, ice)]:
        assemble(name, [
            box("Field", (0, .025, 0), (.99, .009, .99), base, .002),
            *[box("Border", (x, .031, 0), (.019, .009, .926), line, .002) for x in (-.462, .462)],
            *[box("Border", (0, .031, z), (.926, .009, .019), line, .002) for z in (-.462, .462)],
        ])

    assemble("WallClock", [
        rod("Rim", (0, 0, -.036), (0, 0, .031), .234, .234, edge, 24),
        rod("Face", (0, 0, .031), (0, 0, .041), .209, .209, paper, 24),
        rod("MinuteHand", (0, 0, front), (.022, .149, front), .010, .006, dark),
        rod("HourHand", (0, 0, front), (-.112, -.038, front), .012, .008, teal),
        *[rod("Marker", (cos(tau*i/12)*.177, sin(tau*i/12)*.177, front),
              (cos(tau*i/12)*.193, sin(tau*i/12)*.193, front), .007, .007, edge, 6)
          for i in range(12)],
    ])
    assemble("StoryboardFrames", [
        box("Panel", (0, 0, 0), (2.48, 1.07, .09), edge, .037),
        *[box("Frame", ((i-1.5)*.56, 0, .054), (.48, .70, .026), paper) for i in range(4)],
        *[box("Image", ((i-1.5)*.56, .048, .073), (.40, .48, .014), (ice, clay, teal, plum)[i], .006)
          for i in range(4)],
        *[rod("Composition", ((i-1.5)*.56-.17, -.14, .082), ((i-1.5)*.56+.11, .18, .082),
              .024, .008, cream, 6) for i in range(4)],
        *[box("Caption", ((i-1.5)*.56, -.24, .074), (.23, .023, .008), dark, .002)
          for i in range(4)],
    ])
    assemble("WallSconce", [
        box("Mount", (0, 0, 0), (.33, .24, .11), edge, .031),
        rod("Shade", (0, .09, .14), (0, -.09, .14), .081, .162, amber, 16),
        rod("OpalDiffuser", (0, -.084, .14), (0, -.105, .14), .134, .127, cream, 16),
    ])
    assemble("CafeMenu", [
        box("Frame", (0, 0, 0), (3.12, .93, .092), oak, .036),
        box("Slate", (0, 0, .053), (2.98, .80, .025), dark, .017),
        *[box("Header", (x, .25, .072), (.58, .062, .01), amber, .005) for x in (-.97, 0, .97)],
        *[box("MenuRow", (x-.11, y, .072), (w, .025, .01), paper, .003)
          for x in (-.97, 0, .97) for y, w in ((.08, .47), (-.085, .32), (-.25, .41))],
        *[box("Price", (x+.29, y, .072), (.10, .023, .01), cream, .003)
          for x in (-.97, 0, .97) for y in (.08, -.085, -.25)],
    ])
    assemble("ServiceCredenza", [
        *[box("Foot", (x, .095, z), (.10, .18, .1), dark) for x in (-.70, .70) for z in (-.19, .19)],
        box("Body", (0, .47, 0), (1.62, .70, .55), oak, .04),
        box("Worktop", (0, .86, 0), (1.70, .08, .62), cream, .032),
        *[box("Door", (x, .48, .282), (.49, .57, .052), teal, .019) for x in (-.53, 0, .53)],
        *[box("Pull", (x, .695, .32), (.16, .031, .033), steel) for x in (-.53, 0, .53)],
    ])
    assemble("KitchenFridge", [
        box("Shell", (0, .98, 0), (1.44, 1.95, .78), steel, .055),
        box("BottomPlinth", (0, .095, .027), (1.39, .19, .75), dark, .022),
        *[box("InsulatedDoor", (x, 1.05, .38), (.675, 1.58, .102), ice, .044) for x in (-.35, .35)],
        *[rod("Handle", (x, .85, .45), (x, 1.33, .45), .036, .036, cream) for x in (-.11, .11)],
        box("Status", (.47, 1.73, .445), (.22, .072, .019), teal, .008),
    ])
    assemble("KitchenSink", [
        box("Undercounter", (0, .46, 0), (1.42, .91, .66), teal, .043),
        box("Countertop", (0, .95, 0), (1.5, .09, .73), steel, .026),
        box("BasinInset", (-.22, 1.0, .05), (.68, .014, .44), dark, .006),
        *[box("DrainRail", (.39 + i*.06, 1.005, .035), (.013, .014, .41), cream, .003) for i in range(4)],
        rod("TapRiser", (-.23, .996, -.22), (-.23, 1.31, -.22), .035, .035, cream),
        rod("Spout", (-.23, 1.31, -.22), (-.23, 1.29, .03), .033, .027, cream),
    ])
    assemble("CupService", [
        box("Tray", (0, .02, 0), (.55, .034, .33), edge, .022),
        *[rod("Cup", (x, .036, z), (x, .139, z), .047, .06, m)
          for x, z, m in ((-.17, .04, cream), (.0, -.06, clay), (.17, .045, teal))],
    ])
    assemble("PrivacyScreen", [
        *[rod("Stanchion", (x, .02, 0), (x, 1.75, 0), .026, .024, edge) for x in (-.63, .63)],
        *[box("Shoe", (x, .035, 0), (.13, .07, .20), steel) for x in (-.63, .63)],
        box("Fabric", (0, 1.05, 0), (1.26, 1.31, .065), teal, .036),
        *[box("Pleat", (i*.145, 1.05, .008*(-1)**i), (.025, 1.25, .084), ice, .012)
          for i in range(-4, 5)],
    ])
    assemble("StudioSpeaker", [
        box("Body", (0, .18, 0), (.24, .35, .24), dark, .026),
        rod("Woofer", (0, .143, .118), (0, .143, .133), .078, .072, steel),
        rod("DustCap", (0, .143, .135), (0, .143, .142), .027, .021, teal),
        rod("Tweeter", (0, .278, .12), (0, .278, .139), .035, .028, amber, 10),
    ])
    assemble("AcousticBaffles", [
        box("Mount", (0, 0, 0), (1.62, 1.30, .08), dark, .032),
        *[box("Felt", (i*.18, 0, .055), (.126, 1.19, .07), (teal, ice, dark)[i%3], .022)
          for i in range(-4, 5)],
    ])
    assemble("TailorBench", [
        *[box("Leg", (x, .43, z), (.094, .85, .09), steel) for x in (-.81, .81) for z in (-.32, .32)],
        box("Top", (0, .875, 0), (1.91, .09, .88), oak, .04),
        box("Cloth", (-.53, .935, 0), (.55, .019, .55), plum, .007),
        box("MachineBase", (.34, .994, -.05), (.57, .145, .34), cream, .035),
        box("MachineUpright", (.53, 1.16, -.05), (.17, .34, .29), cream, .043),
        box("MachineArm", (.28, 1.32, -.05), (.50, .15, .25), cream, .049),
        rod("HandWheel", (.61, 1.28, -.05), (.67, 1.28, -.05), .095, .095, steel),
        rod("Needle", (.105, 1.10, -.026), (.105, 1.27, -.026), .011, .011, steel, 8),
        rod("Thread", (.32, 1.40, -.05), (.32, 1.50, -.05), .032, .032, clay, 10),
    ])
    assemble("DressForm", [
        rod("Foot", (0, .022, 0), (0, .08, 0), .255, .23, dark, 16),
        rod("Support", (0, .075, 0), (0, 1.21, 0), .034, .033, oak),
        oval("Hips", (0, .99, 0), (.29, .24, .16), paper, None, 14),
        oval("Torso", (0, 1.31, -.034), (.29, .32, .157), paper, None, 14),
        rod("NeckCap", (0, 1.52, -.021), (0, 1.66, -.021), .093, .082, oak),
    ])
    assemble("IronStation", [
        *[rod("FoldingLeg", (s*.55, .027, -.14), (-s*.50, .87, .14), .033, .032, steel)
          for s in (-1, 1)],
        box("PaddedBoard", (0, .91, 0), (1.37, .09, .45), teal, .045),
        box("IronRest", (.53, .956, 0), (.25, .056, .30), steel, .024),
        box("Soleplate", (.52, 1.003, .012), (.24, .037, .154), dark, .017),
        box("IronShell", (.54, 1.053, .012), (.207, .089, .13), cream, .031),
        rod("Grip", (.49, 1.12, .012), (.62, 1.13, .012), .025, .025, clay),
    ])
    assemble("LaundryHamper", [
        rod("Basket", (0, .025, 0), (0, .655, 0), .29, .39, oak, 16),
        rod("Rim", (0, .63, 0), (0, .675, 0), .406, .399, edge, 16),
        *[box("Fold", (x, .66, z), (.34, .14, .36), m, .042)
          for x, z, m in ((-.15, .024, paper), (.14, -.12, plum))],
    ])
    assemble("PrintStation", [
        box("Pedestal", (0, .47, 0), (1.15, .92, .63), teal, .041),
        box("Plotter", (0, 1.01, 0), (1.4, .38, .62), cream, .045),
        box("OutputSlot", (0, 1.005, .322), (1.16, .09, .035), dark, .009),
        box("PrintedSheet", (0, .99, .42), (.92, .018, .24), paper, .005),
        box("PrintProof", (0, 1.006, .443), (.76, .012, .155), clay, .005),
        box("Controls", (.47, 1.155, .315), (.18, .07, .031), glass, .012),
    ])
    assemble("PropStock", [
        box("SlattedBox", (-.43, .25, 0), (.79, .47, .65), oak, .038),
        *[box("Brace", (-.43+x, .254, .33), (.081, .45, .041), edge) for x in (-.29, .29)],
        box("RoadCase", (.43, .25, 0), (.76, .45, .65), dark, .043),
        box("CaseLid", (.43, .48, 0), (.78, .09, .67), steel, .023),
        box("CaseLabel", (.43, .293, .341), (.28, .11, .017), amber, .006),
        box("SmallBin", (.54, .66, 0), (.47, .25, .45), teal, .038),
    ])
    assemble("WorkshopBench", [
        box("Worktop", (0, .95, 0), (1.89, .11, .81), oak, .039),
        box("ToolCabinet", (-.60, .49, 0), (.60, .88, .69), steel, .043),
        *[box("DrawerPull", (-.60, y, .363), (.27, .039, .05), dark) for y in (.31, .50, .69)],
        *[box("Leg", (.72, .475, z), (.11, .94, .11), steel) for z in (-.30, .30)],
        box("RubberMat", (.24, 1.014, .07), (.72, .015, .46), dark, .006),
        rod("Handle", (.12, 1.062, .025), (.49, 1.062, .11), .039, .029, amber),
        rod("ToolHead", (.51, 1.061, .02), (.47, 1.061, .20), .051, .034, steel),
    ])
    assemble("CableReel", [
        box("Stand", (0, .14, 0), (.69, .27, .52), steel, .03),
        rod("CableDrum", (-.20, .41, 0), (.20, .41, 0), .215, .215, dark, 18),
        *[rod("Flange", (x, .41, 0), (x+.042, .41, 0), .30, .30, amber, 18)
          for x in (-.248, .21)],
        rod("Axle", (-.30, .41, 0), (.32, .41, 0), .074, .074, steel),
    ])
    assemble("DirectorChair", [
        *[rod("CrossBrace", (s*.29, .025, z), (-s*.31, .54, z), .036, .036, oak)
          for s in (-1, 1) for z in (-.22, .22)],
        *[rod("BackPost", (x, .50, .25), (x, 1.20, .34), .037, .036, oak) for x in (-.29, .29)],
        *[box("Armrest", (x, .76, .035), (.088, .051, .55), oak) for x in (-.30, .30)],
        box("CanvasSeat", (0, .54, .015), (.56, .069, .49), dark, .026),
        box("CanvasBack", (0, 1.055, .31), (.58, .24, .066), teal, .03),
    ])
    assemble("GymWeights", [
        *[rod("RackFoot", (0, .015, z), (0, 1.07, z), .056, .045, steel) for z in (-.68, .68)],
        *[box("Tray", (0, y, 0), (.52, .083, 1.62), ice) for y in (.42, .83)],
        *[rod("Handle", (x, y, z-.112), (x, y, z+.112), .023, .023, steel)
          for x, y in ((.03, .53), (-.02, .94)) for z in (-.56, -.18, .18, .56)],
        *[rod("Weight", (x, y, z+offset), (x, y, z+offset+.056), .079, .079, dark, 8)
          for x, y in ((.03, .53), (-.02, .94)) for z in (-.56, -.18, .18, .56) for offset in (-.154, .10)],
    ])
    assemble("AudienceSeat", [
        *[rod("SteelLeg", (x, .015, z), (x, .44, z*.89), .044, .039, steel)
          for x in (-.28, .28) for z in (-.27, .27)],
        box("UpholsteredSeat", (0, .465, 0), (.74, .15, .70), ice, .076),
        *[rod("Backframe", (x, .42, .27), (x, .99, .36), .043, .036, steel) for x in (-.28, .28)],
        box("BackCushion", (0, .832, .316), (.72, .37, .12), teal, .055),
    ])
    assemble("ConferenceTable", [
        box("Top", (0, .838, 0), (4.48, .105, 1.29), oak, .046),
        *[box("Pedestal", (x, .44, 0), (.20, .80, .88), steel, .041) for x in (-1.43, 1.43)],
        box("Grommet", (0, .90, 0), (.65, .018, .15), dark, .007),
        *[box("Proof", (x, .899, z), (.44, .015, .33), paper, .005)
          for x, z in ((-1.45, .32), (-.43, -.29), (.55, .29), (1.45, -.31))],
        *[box("Print", (x, .911, z), (.33, .014, .21), m, .005)
          for x, z, m in ((-1.45, .32, clay), (-.43, -.29, teal), (.55, .29, ice), (1.45, -.31, plum))],
    ])
    for name, sky, design in [
        ("PosterSummit", ice, [
            rod("Sun", (.44, .51, .038), (.44, .51, .053), .34, .34, amber, 24),
            panel("Peak", [(-.94, -.59, .043), (-.26, .83, .043), (.29, -.59, .043)], cream, None, .011),
            panel("Foothill", [(-.35, -.72, .051), (.51, .28, .051), (.95, -.72, .051)], teal, None, .011),
        ]),
        ("PosterPremiere", clay, [
            rod("IrisRim", (0, .33, .039), (0, .33, .049), .66, .66, dark, 24),
            rod("IrisGlass", (0, .33, .049), (0, .33, .058), .52, .52, teal, 24),
            rod("IrisCore", (0, .33, .058), (0, .33, .071), .28, .28, glass, 12),
            rod("Reflection", (.15, .53, .070), (.15, .53, .080), .093, .093, paper, 12),
        ]),
        ("PosterMidnight", plum, [
            *[box("Tower", (x, -.06 + height*.36, .045), (.35, height, .032), ink, .009)
              for x, height, ink in ((-.59, 1.04, dark), (-.16, 1.50, teal), (.27, 1.18, dark), (.68, .90, ice))],
            *[box("Window", (.025 * (i%2) - .2, .07 + i*.16, .065), (.09, .068, .012), amber, .004)
              for i in range(6)],
        ]),
    ]:
        assemble(name, [
            box("PrintStock", (0, 0, 0), (2.18, 2.62, .073), sky, .021),
            box("Footer", (0, -.94, .04), (1.94, .46, .018), dark, .005),
            *design,
        ])
    assemble("FittingMirror", [
        box("Frame", (0, 0, 0), (1.66, 2.42, .105), oak, .041),
        box("Mirror", (0, .045, .061), (1.47, 2.20, .039), glass, .03),
        rod("Reflection", (-.46, -.79, .085), (.44, .87, .085), .023, .023, ice, 6),
    ])
    assemble("TreadmillDeck", [
        box("Deck", (0, .15, 0), (.88, .24, 1.79), steel, .069),
        box("Belt", (0, .274, .09), (.64, .03, 1.42), dark, .014),
        *[box("GripRail", (x, .275, .024), (.083, .039, 1.53), ice, .014)
          for x in (-.381, .381)],
        *[rod("RearRoller", (x, .12, .68), (x+.09, .12, .68), .089, .089, teal)
          for x in (-.43, .34)],
    ])
    assemble("TreadmillConsole", [
        *[rod("Support", (x, .22, -.62), (x, 1.03, -.60), .043, .038, steel) for x in (-.33, .33)],
        *[rod("SafetyRail", (x, 1.0, -.65), (x, .92, .05), .045, .044, dark)
          for x in (-.36, .36)],
        box("ConsoleHood", (0, 1.19, -.62), (.78, .28, .26), dark, .052),
        box("Readout", (0, 1.23, -.474), (.46, .124, .035), glass, .014),
        box("ControlKey", (.26, 1.13, -.476), (.07, .062, .027), clay, .01),
    ])
