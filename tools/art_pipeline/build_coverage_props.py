"""Room-scale joinery, stage infrastructure and storage for MovieStudio."""

from build_stage_equipment import assemble, box, rod
from build_studio_employee import material


def build_coverage_props(oak, edge, steel, dark, teal, paper, amber):
    woven = material("DeepWovenBlue", (.052, .136, .183), .92)
    clay = material("ApricotFabric", (.42, .194, .106), .88)
    linen = material("WarmLinen", (.64, .52, .39), .92)
    mint = material("JoineryGreen", (.095, .218, .196), .65)

    assemble("ScenicCart", [
        box("WheeledBase", (0, .182, 0), (1.92, .216, .64), steel, .033),
        *[rod("Wheel", (x-.04,.078,z),(x+.04,.078,z),.075,.075,dark,12)
          for x in (-.78,.78) for z in (-.26,.26)],
        *[rod("Post", (x,.26,-.19),(x,1.68,-.19),.035,.035,steel,10) for x in (-.81,.81)],
        rod("TopRail",(-.81,1.68,-.19),(.81,1.68,-.19),.033,.033,steel,10),
        *[box("ScenicFlat", (x, .31+h*.5, .018), (w,h,.102), color,.019)
          for x,w,h,color in ((-.52,.50,1.21,linen),(.02,.49,1.36,mint),(.54,.46,1.03,clay))],
        box("SecuringBatten", (0, .43, .104), (1.76,.093,.055), amber),
    ])
    assemble("GantryBatten", [
        *[rod("Rail",(-1.0,y,z),(1.0,y,z),.025,.025,steel,8)
          for y in (-.16,.16) for z in (-.15,.15)],
        *[rod("Web", (x,-.16,z),(x+.31,.16,z),.017,.017,steel,6)
          for x in (-.96,-.64,-.32,0,.32,.64) for z in (-.15,.15)],
        *[box("Clip", (x,-.204,.13),(.15,.062,.15),amber,.012) for x in (-.57,.57)],
    ])
    assemble("BroadcastWing", [
        box("Ballast", (0,.11,0),(1.77,.22,.46),dark,.037),
        box("TallBacking", (0,1.94,-.086),(1.68,3.74,.192),woven,.042),
        *[box("Upright",(.14*i,1.93,.042),(.047,3.55,.096),oak,.011) for i in range(-5,6)],
        box("TopRail",(0,3.77,.05),(1.62,.09,.17),steel,.014),
        box("Band",(0,1.12,.105),(1.52,.112,.065),amber,.016),
    ])
    assemble("PantryHatch", [
        box("OuterTrim",(0,0,0),(3.40,1.06,.20),edge,.031),
        box("ShadowBox",(0,0,.111),(3.18,.88,.055),dark,.018),
        *[box("Shelf",(0,y,.228),(3.18,.078,.37),oak,.028) for y in (-.39,-.008)],
        *[rod("BowlStack",(x,y,.201),(x,y+.12,.201),.115,.149,paper,16)
          for y in (-.347,.034) for x in (-1.27,-.91,-.55,.85,1.19)],
        *[rod("CupStack",(x,-.348,.214),(x,-.156,.214),.063,.088,mint,12)
          for x in (-.14,.095,.33,.545)],
        box("CenterRecess",(0,.209,.162),(.75,.272,.067),teal,.019),
    ])
    assemble("CanteenJoinery", [
        box("Kickplate",(0,.153,0),(7.18,.17,.13),edge,.018),
        box("PanelBacking",(0,.585,.012),(7.26,.79,.09),mint,.038),
        *[box("Inset",(x,.60,.070),(.948,.57,.045),oak,.025) for x in (-3.06,-2.04,-1.02,0,1.02,2.04,3.06)],
        *[box("Frame",(x,.60,.095),(.038,.61,.041),edge,.008) for x in (-3.54,-2.55,-1.53,-.51,.51,1.53,2.55,3.54)],
        box("TopTrim",(0,.936,.083),(7.23,.055,.10),amber,.008),
    ])
    assemble("ProjectWall", [
        box("Frame",(0,0,0),(2.42,1.63,.14),edge,.031),
        box("Felt",(0,0,.079),(2.27,1.47,.028),mint,.02),
        *[box("PinnedPanel",(x,y,.103),(w,h,.028),color,.010)
          for x,y,w,h,color in [(-.674,.25,.64,.46,linen),(.112,.21,.67,.56,paper),
                               (.777,.27,.49,.47,clay),(-.77,-.34,.36,.44,paper),
                               (-.26,-.37,.47,.31,clay),(.52,-.35,.79,.34,linen)]],
        *[box("Print",(x,y,.122),(w,.028,.008),steel,.003)
          for x,y,w in [(-.67,.30,.45),(-.72,.20,.35),(.10,.28,.48),(.09,.15,.45),
                        (.77,.28,.31),(.57,-.28,.56),(.54,-.38,.47)]],
        box("Sill",(0,-.755,.114),(2.28,.072,.19),oak,.018),
    ])
    assemble("MediaArchive", [
        box("Back",(0,1.00,-.18),(1.74,2.0,.13),edge,.026),
        *[box("Upright",(x,1.01,0),(.091,2.02,.45),oak,.025) for x in (-.86,.86)],
        *[box("Shelf",(0,y,0),(1.75,.063,.46),oak,.015) for y in (.15,.61,1.06,1.52,1.96)],
        *[box("Cassette",(x,.245+y,.031),(w,.24,.36),color,.021)
          for y in (0,.46,.91,1.37) for x,w,color in [(-.62,.30,woven),(-.23,.38,mint),(.21,.39,steel),(.62,.26,clay)]],
        *[box("SpineLabel",(x,.256+y,.218),(.115,.068,.017),paper,.005)
          for y in (0,.46,.91,1.37) for x in (-.62,-.23,.21,.62)],
    ])
    assemble("FabricStation", [
        box("Cabinet",(0,.35,0),(1.75,.67,.55),oak,.033),
        *[box("Panel",(x,.39,.29),(.49,.49,.065),color,.019)
          for x,color in ((-.576,edge),(0,mint),(.576,edge))],
        box("Counter",(0,.719,0),(1.84,.093,.65),linen,.041),
        *[rod("FabricRoll",(x,.87,-.15),(x,.87,.20),.102,.098,color,16)
          for x,color in ((-.65,clay),(-.40,teal),(-.14,linen),(.12,woven),(.37,mint),(.62,clay))],
        *[rod("Core",(x,.87,.198),(x,.87,.218),.026,.026,edge,10)
          for x in (-.65,-.40,-.14,.12,.37,.62)],
    ])
    assemble("ReadingBay", [
        box("Plinth",(0,.11,0),(1.95,.19,.61),edge,.027),
        box("BackPanel",(0,.78,-.23),(1.97,1.32,.11),oak,.045),
        box("Upholstery",(0,.941,-.15),(1.82,.84,.14),woven,.055),
        *[box("Channel",(i*.21,.947,-.065),(.086,.77,.09),woven,.033) for i in range(-4,5)],
        box("Seat",(0,.443,.016),(1.81,.18,.55),mint,.065),
        *[box("Pillow",(x,.626,.084),(.37,.274,.257),color,.091)
          for x,color in ((-.66,linen),(.65,clay))],
    ])
    assemble("SortingCage", [
        *[rod("Guard",(x,.017,z),(x,1.98,z),.037,.034,steel,8)
          for x in (-.83,.83) for z in (-.32,.32)],
        *[box("Shelf",(0,y,0),(1.70,.055,.65),steel,.016) for y in (.15,.74,1.34,1.95)],
        *[box("Case",(x,y+.19,.035),(.66,.37,.49),color,.023)
          for y in (.18,.77,1.37) for x,color in ((-.40,edge),(.40,teal))],
        *[box("CaseHandle",(x,y+.24,.286),(.136,.057,.032),amber,.006)
          for y in (.18,.77,1.37) for x in (-.40,.40)],
    ])
