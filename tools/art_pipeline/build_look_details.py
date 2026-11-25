"""Original scenic, broadcast and desk props for MovieStudio."""

from math import cos

from build_stage_equipment import assemble, box, rod
from build_studio_employee import material


def build_look_details(oak, steel, dark, teal, paper, glass, amber):
    brass = material("BrushedBrassAccent", (.49, .287, .105), .41, .40)
    indigo = material("BroadcastIndigo", (.055, .125, .232), .54, .21)
    smoke = material("CycloramaPaint", (.205, .255, .272), .79)
    linen = material("UnbleachedLinen", (.57, .414, .255), .90)
    opal = material("BroadcastOpal", (.51, .79, .88), .34)
    core = opal.node_tree.nodes.get("Principled BSDF")
    core.inputs["Emission Color"].default_value = (.12, .42, .56, 1)
    core.inputs["Emission Strength"].default_value = .43

    assemble("ScenicBackdropBay", [
        box("PaintedFlat", (0, 1.18, 0), (1.79, 2.35, .083), smoke, .022),
        box("ToeStrip", (0, .068, .046), (1.73, .134, .061), dark, .012),
        box("JoinStrip", (.85, 1.20, .045), (.048, 2.19, .048), steel, .006),
        box("Header", (0, 2.30, .051), (1.70, .09, .07), steel, .012),
    ])
    assemble("PlaybackMonitor", [
        box("Shell", (0, .28, 0), (.87, .48, .105), dark, .033),
        box("Screen", (0, .291, .061), (.76, .368, .027), glass, .017),
        box("Inset", (-.13, .304, .079), (.37, .245, .010), indigo, .006),
        *[box("Meter", (.13 + i*.054, .205+h*.5, .080), (.032, h, .014), m, .003)
          for i, (h, m) in enumerate(((.12, teal), (.18, opal), (.105, teal), (.21, amber)))],
        box("Support", (0, .029, .012), (.36, .055, .24), steel, .013),
    ])
    assemble("StageReadinessBoard", [
        box("Frame", (0, 0, 0), (2.03, .98, .097), dark, .02),
        box("Enamel", (0, 0, .052), (1.92, .87, .021), glass, .014),
        box("Legend", (-.31, .258, .067), (1.04, .071, .016), amber, .005),
        *[box("Row", (-.37, y, .068), (.92, .023, .013), paper, .003) for y in (.072, -.078, -.229)],
        *[box("Magnet", (x, y, .069), (.121, .085, .027), color, .012)
          for x, y, color in ((.34,.07,amber), (.61,-.08,opal), (.36,-.229,teal), (.61,.07,teal))],
    ])
    assemble("StageWaitBench", [
        *[box("Foot", (x, .21, 0), (.093, .41, .43), steel) for x in (-.63,.63)],
        box("Seat", (0, .45, 0), (1.56, .095, .46), oak, .028),
        box("Back", (0, .747, -.223), (1.54, .326, .076), teal, .032),
        *[rod("BackPost", (x, .43, -.19), (x, .89, -.235), .023, .023, steel, 8)
          for x in (-.64,.64)],
        box("SideCrate", (.66, .51, .065), (.23, .03, .20), amber, .009),
    ])
    assemble("BroadcastDesk", [
        box("RecessedFoot", (0, .165, 0), (3.67, .29, .87), dark, .081),
        box("RoundedBody", (0, .57, 0), (4.24, .81, 1.08), indigo, .131),
        box("FrontInset", (0, .57, .544), (3.75, .425, .079), dark, .035),
        *[box("Fin", ((i-10)*.167, .566, .591), (.029, .32, .035), opal if i%5==0 else steel, .006)
          for i in range(21)],
        box("OnAirBand", (0, .813, .550), (3.93, .049, .08), brass, .016),
        box("Top", (0, 1.058, .018), (4.59, .144, 1.22), oak, .107),
        box("DeskMat", (.71, 1.135, -.05), (.72, .017, .39), dark, .018),
    ])
    for name, band in [("BroadcastPanelCool", glass), ("BroadcastPanelWarm", brass)]:
        assemble(name, [
            box("Frame", (0, 0, 0), (2.66, 3.57, .098), dark, .039),
            box("Screen", (0, 0, .055), (2.57, 3.48, .026), indigo, .019),
            box("HorizontalBand", (0, -.86, .073), (2.56, .61, .014), band, .006),
            *[box("Signal", ((i-3.5)*.272, -.70+.08*cos(i), .084), (.086, .13+.043*(i%3), .014), opal, .005)
              for i in range(8)],
            *[box("Index", (.91, y, .073), (.23, .029, .012), opal, .005) for y in (.79,.95,1.11,1.27)],
            rod("ScreenMark", (-.46, .48, .075), (-.46, .48, .090), .355, .355, band, 24),
            rod("ScreenMarkInset", (-.46, .48, .091), (-.46, .48, .101), .288, .288, indigo, 24),
        ])
    assemble("BroadcastSoftbox", [
        box("Housing", (0, .060, -.023), (1.24, .237, .77), dark, .056),
        box("Diffuser", (0, -.045, .038), (1.07, .053, .63), opal, .033),
        *[box("Louver", (x, -.080, .038), (.07, .056, .67), steel, .012) for x in (-.41,-.20,0,.20,.41)],
        box("Yoke", (0, .182, -.055), (.43, .10, .29), steel),
    ])
    assemble("FoleyReels", [
        box("Tray", (0, .022, 0), (.64, .035, .38), dark, .022),
        *[rod("Reel", (x, .039, .02), (x, .095, .02), .129, .129, color, 16)
          for x,color in ((-.145,steel),(.150,amber))],
        *[rod("Hub", (x, .092, .02), (x, .111, .02), .045, .045, dark, 10) for x in (-.145,.150)],
    ])
    assemble("ScriptFolio", [
        box("Folder", (0, .014, 0), (.36, .026, .28), teal, .012),
        box("Manuscript", (.024, .029, .011), (.30, .014, .245), paper, .010),
        *[box("Print", (.022, .039, -.058+i*.029), (.18-.02*(i%3), .004, .007), steel, .001) for i in range(5)],
        rod("Pencil", (-.14, .045, -.105), (-.082, .046, .098), .009, .006, amber, 8),
    ])
    assemble("WardrobeNotions", [
        box("Textile", (-.16, .047, .02), (.34, .089, .36), linen, .031),
        box("Swatch", (-.14, .106, .01), (.27, .026, .26), teal, .014),
        *[rod("Spool", (x,.018,z), (x,.14,z), .048,.043,color,10)
          for x,z,color in ((.16,-.09,amber),(.25,.066,steel),(.12,.115,teal))],
    ])
    assemble("CanteenTray", [
        box("Base", (0, .016, 0), (.52, .031, .34), steel, .021),
        rod("Bowl", (-.094,.032,.012), (-.094,.10,.012), .087,.102,paper,16),
        rod("Cup", (.116,.033,-.041), (.116,.148,-.041), .043,.064,teal,14),
        box("Napkin", (.114,.043,.09), (.112,.015,.087), linen, .010),
    ])
