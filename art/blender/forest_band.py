"""Moss boar, shield-husk beetle and the forest's mushroom drummer."""
import sys
from pathlib import Path
from math import sqrt
sys.path.insert(0,str(Path(__file__).resolve().parent))
from model_tools import *
from forest_bosses import leaf,branch,spindle

BLACK='343d43'; FUR='73503f'; OCHRE='b7824e'; CREAM='f1d9ac'; GOLD='e5ad59'
GREEN='588557'; LIME='93b564'; MOSS='63854b'; PINE='345f51'; COPPER='b66c43'
BRICK='be6244'; AMBER='f0a559'; SKIN='eace9f'; EYE='332e36'


def make_legged(name,center,head,hips,z):
    bones=[('Root',(0,0,0),(0,0,.1),None),('Body',center,(0,-.1,z+.09),'Root'),
        ('Head',head,(0,head[1]-.13,head[2]+.04),'Body')]
    joints=[]
    for s,side in [(-1,'R'),(1,'L')]:
        for i,h in enumerate(hips):
            x,y,hz=h
            a='Leg'+str(i)+'.'+side
            base=(s*x,y,hz); end=(s*(x+.026),y-.027,.06)
            bones.append((a,base,end,'Body'))
            joints.append((s,i,a,base,end))
    return bones,joints


def motions(rig,steps,windup,hit,ready=None):
    ready=ready or {}
    breathe={**ready,'Body':(-3,0,0,0,0,.009),'Head':(3,0,4)}
    action(rig,'Idle',[(1,ready),(40,breathe),(79,ready)])
    def stride(s):
        p={**ready,'Body':(5*s,0,0,0,0,.022*abs(s)),'Head':(-s*6,0,0)}
        for sign,i,b,_,_ in steps:
            p[b]=(s*sign*(-1 if i%2 else 1)*28,0,0)
        return p
    action(rig,'Run',[(1,stride(1)),(7,stride(0)),(13,stride(-1)),(19,stride(0)),(25,stride(1))])
    action(rig,'Windup',[(1,ready),(15,windup),(27,windup)])
    action(rig,'Attack',[(1,windup),(6,hit),(14,hit),(23,{**hit,'Body':(9,0,0)})])
    action(rig,'Recover',[(1,hit),(15,{**ready,'Head':(7,0,-5)}),(30,ready)])
    action(rig,'Hit',[(1,ready),(4,{**ready,'Body':(-15,-9,8),'Head':(-12,0,10)}),(15,ready)])
    fall={**ready,'Root':(5,79,-8,0,0,.18),'Head':(3,0,18)}
    action(rig,'Death',[(1,ready),(10,{**ready,'Body':(-18,10,0)}),(29,fall),(39,fall)])


def boar():
    bones,legs=make_legged('Boar',(0,.11,.31),(0,-.26,.465),[(.161,-.201,.37),(.154,.226,.38)],.48)
    bones.append(('Tail',(0,.36,.46),(0,.52,.51),'Body'))
    rig=armature('MossBoar',bones); g=Geometry()
    spindle(g,[(-.36,.414,.104,.128),(-.278,.432,.201,.215),(-.106,.456,.244,.244),
        (.074,.458,.25,.231),(.241,.436,.217,.200),(.338,.425,.163,.156),
        (.39,.424,.063,.083)],[FUR,FUR,OCHRE,FUR,FUR,OCHRE,FUR],'Body',26)
    spindle(g,[(-.642,.341,.105,.076),(-.586,.354,.123,.099),(-.489,.393,.147,.13),
        (-.399,.463,.178,.180),(-.298,.487,.186,.16),(-.239,.50,.118,.108)],
        [OCHRE,FUR,OCHRE,FUR,FUR,FUR],'Head')
    g.oval((0,-.63,.359),(.115,.039,.066),'ab7765','Head',24)
    for s,_,leg,top,foot in legs:
        g.oval(top,(.080,.087,.128),FUR,leg,20)
        joint=(top[0]*1.05,top[1]+.005,.21)
        g.tube(top,joint,.076,.055,FUR,leg,14)
        g.tube(joint,foot,.052,.037,OCHRE,leg,14)
        g.rings([(foot[0],foot[1]-.020,0,.052,.063),(foot[0],foot[1]-.017,.031,.055,.065),
            (foot[0],foot[1],.083,.035,.044)],[BLACK,BLACK,FUR],leg,14)
        g.tube((foot[0],foot[1]-.073,.028),(foot[0],foot[1]-.079,.004),.005,.002,'a1917c',leg)
    for s in [-1,1]:
        g.oval((s*.047,-.665,.36),(.018,.006,.023),BLACK,'Head')
        g.oval((s*.137,-.466,.470),(.040,.059,.035),BLACK,'Head',20)
        g.oval((s*.159,-.495,.472),(.023,.028,.020),GOLD,'Head')
        g.oval((s*.176,-.51,.473),(.008,.011,.016),EYE,'Head')
        g.oval((s*.178,-.515,.481),(.005,.005,.005),CREAM,'Head')
        branch(g,[(s*.11,-.512,.313),(s*.17,-.549,.315),(s*.217,-.572,.375),
            (s*.217,-.592,.455),(s*.197,-.604,.483)],[.031,.031,.023,.012,.002],
            [OCHRE,CREAM,CREAM,CREAM],'Head',10)
        g.ribbon([(s*.103,-.342,.556),(s*.178,-.307,.60),(s*.223,-.269,.692)],
            [(1,0,0)]*3,[.045,.057,.002],[FUR,OCHRE,FUR],'Head',(0,-.036,0))
        g.line([(s*.097,-.512,.518),(s*.15,-.449,.55),(s*.173,-.389,.548)],
            [.021,.039,.015],FUR,'Head')
        for j in range(5):
            y=-.29+.099*j; a=j*.95
            g.ribbon([(s*.195,y,.545+.023*cos(a)),(s*.228,y+.034,.512),(s*.248,y+.063,.43)],
                     [(0,1,0)]*3,[.018,.041,.003],[OCHRE,FUR,FUR],'Body',(s*.014,0,0))
    branch(g,[(0,.352,.46),(.023,.424,.469),(.036,.472,.512),(.027,.491,.574)],
        [.019,.015,.013,.009],[FUR,OCHRE,FUR],'Tail')
    g.oval((.025,.49,.572),(.024,.021,.035),FUR,'Tail')
    for j in range(10):
        y=-.268+j*.064; z=.635+.028*cos(j*.47)
        g.oval((0,y,z),(.120+.029*sin(j*.7),.073,.056),MOSS,'Body',18,9)
        g.ribbon([(0,y,z+.008),(.014,y+.031,z+.068),(.033,y+.081,z+.116)],
            [(1,0,0)]*3,[.031,.043,.002],[PINE,GREEN,LIME],'Body',(0,-.016,0))
        for s in [-1,1]:
            leaf(g,(s*.063,y,z+.016),(s*(.09+.023*cos(j)),.039,.051+.027*sin(j*.9)),.037,
                 LIME if j%3==0 else GREEN,'Body')
    for i in range(3):
        x=.075+.018*i; y=-.138+.056*i; z=.685
        g.tube((x,y,z-.022),(x,y,z+.026),.008,.007,CREAM,'Body')
        g.oval((x,y,z+.024),(.02,.018,.012),COPPER,'Body')
    g.build('MossBoarMesh',rig,surface_material(1024))
    wind={'Body':(13,0,0,0,0,-.025),'Head':(33,0,-4),'Leg0.R':(-24,0,0),'Tail':(29,0,0)}
    hit={'Body':(8,0,0,0,-.048,.032),'Head':(-20,0,0),'Leg0.R':(-28,0,0),
         'Leg0.L':(-28,0,0),'Leg1.R':(25,0,0),'Leg1.L':(25,0,0),'Tail':(-21,0,0)}
    motions(rig,legs,wind,hit)
    save('moss_boar',rig)


def beetle():
    bones,legs=make_legged('Husk',(0,.06,.26),(0,-.197,.23),
        [(.150,-.135,.26),(.182,.032,.24),(.153,.19,.25)],.35)
    for s,side in [(-1,'R'),(1,'L')]:
        bones.append(('Shield.'+side,(s*.020,-.141,.334),(s*.155,.207,.442),'Body'))
    rig=armature('HuskShield',bones); g=Geometry()
    g.oval((0,.033,.252),(.214,.293,.15),BLACK,'Body',24)
    g.oval((0,-.221,.234),(.144,.129,.087),PINE,'Head',20)
    for s,i,leg,base,foot in legs:
        y=base[1]; z=base[2]
        knee=(s*(.285+.018*(i==1)),y+.048*(i-1),z+.035)
        ankle=(s*(.306+.016*(i==1)),y-.027,z*.39)
        toe=(s*(.349+.024*(i==1)),y-.096,.009)
        branch(g,[base,knee,ankle,toe],[.033,.026,.016,.003],[OCHRE,BLACK,COPPER],leg,10)
        g.oval(knee,(.030,.029,.028),GOLD,leg,12,6)
        g.panel([toe,(toe[0]-s*.025,toe[1]+.048,.001),(toe[0]+s*.012,toe[1]+.027,0)],
            (0,0,.008),BLACK,leg)
    for s,side in [(-1,'R'),(1,'L')]:
        shield='Shield.'+side
        # Each half of the wood-grain carapace rises as a separate shield.
        rows=[]
        for j in range(15):
            t=j/14
            y=-.257+.63*t
            w=.008+.239*(sin(pi*t)**.72)
            h=.048+.165*(sin(pi*t)**.71)
            row=[]
            for i in range(9):
                u=i/8
                row.append((s*(.009+w*u),y,.317+h*sqrt(max(0,1-u*u))-.050*u))
            rows.append(row)
        for j in range(14):
            colors=['b69c5c','b19759','ae8b52','9e764a','99734c',
                    'ac8952','806645','627758']
            for i in range(8):
                rgb=colors[i]
                g.panel([rows[j][i],rows[j][i+1],rows[j+1][i+1],rows[j+1][i]],(0,0,-.011),
                        rgb,shield)
        for i in [0,3,7]:
            pts=[Vector(row[i])+Vector((0,0,.006)) for row in rows[1:-1]]
            g.line(pts,[.004 if i==3 else .006]*len(pts),PINE if i==7 else GOLD,shield,6)
        for j in [3,6,9,12]:
            a=Vector(rows[j][4]); b=Vector(rows[min(14,j+2)][6])
            g.line([a+Vector((0,0,.009)),b+Vector((0,0,.009))],[.006,.002],CREAM,shield,6)
            g.oval(Vector(rows[j][7])+Vector((0,0,.008)),(.012,.012,.008),GOLD,shield,8,5)
        g.oval((s*.094,-.299,.249),(.043,.041,.026),BLACK,'Head')
        g.oval((s*.101,-.325,.25),(.030,.017,.014),GOLD,'Head')
        branch(g,[(s*.104,-.314,.197),(s*.152,-.376,.203),(s*.163,-.404,.239),
            (s*.126,-.434,.252)],[.027,.022,.017,.001],[COPPER,OCHRE,CREAM],'Head')
        branch(g,[(s*.072,-.286,.285),(s*.097,-.326,.325),(s*.162,-.351,.349)],
            [.009,.007,.002],[BLACK,OCHRE],'Head')
        for j in range(3):
            yy=-.15+j*.131
            leaf(g,(s*.14,yy,.440),(s*.042,.094,.027),.017,MOSS,shield)
    # A pentagonal rim, umbo and pale split chevrons give the face its shield silhouette.
    outline=[(-.047,-.300,.554),(.133,-.266,.504),(.197,-.284,.418),(.183,-.308,.305),
             (0,-.348,.208),(-.183,-.308,.305),(-.197,-.284,.418),(-.133,-.266,.504)]
    g.panel(outline,(0,.039,0),PINE,'Head')
    center=Vector((0,-.326,.393))
    g.panel([center+(Vector(v)-center)*.9+Vector((0,-.008,0)) for v in outline],(0,.019,0),GOLD,'Head')
    g.panel([center+(Vector(v)-center)*.80+Vector((0,-.016,0)) for v in outline],(0,.019,0),GREEN,'Head')
    for s in [-1,1]:
        g.panel([(s*.052,-.344,.458),(s*.139,-.324,.433),(s*.126,-.334,.405),(s*.049,-.351,.438)],
            (0,.009,0),CREAM,'Head')
    g.oval((0,-.351,.395),(.046,.019,.051),COPPER,'Head',14)
    g.oval((0,-.367,.398),(.030,.012,.032),GOLD,'Head',12)
    g.build('ShieldBeetleMesh',rig,surface_material(1024))
    wind={'Head':(-16,0,0),'Shield.L':(0,-22,0),'Shield.R':(0,22,0),'Body':(-9,0,0)}
    hit={'Head':(21,0,0),'Shield.L':(0,-8,0),'Shield.R':(0,8,0),'Body':(18,0,0,0,-.043,.016)}
    motions(rig,legs,wind,hit)
    save('husk_shield',rig)


def drummer():
    bones=[('Root',(0,0,0),(0,0,.11),None),('Body',(0,.015,.20),(0,0,.47),'Root'),
           ('Head',(0,0,.47),(0,0,.67),'Body'),('Drum',(0,-.092,.319),(0,-.231,.33),'Body')]
    legs=[]
    for s,side in [(-1,'R'),(1,'L')]:
        foot='Leg0.'+side; base=(s*.083,.016,.20); tip=(s*.102,-.031,.045)
        legs.append((s,0,foot,base,tip))
        bones.extend([(foot,base,tip,'Body'),
                      ('Mallet.'+side,(s*.116,-.003,.394),(s*.194,-.105,.282),'Body')])
    rig=armature('SporeDrummer',bones); g=Geometry()
    g.rings([(0,.016,.133,.091,.079),(0,.018,.176,.125,.098),(0,.014,.266,.143,.101),
        (0,.008,.358,.137,.098),(0,.005,.449,.115,.100),(0,.004,.499,.124,.102)],
        [OCHRE,SKIN,SKIN,SKIN,CREAM,CREAM],'Body',26)
    for s,side in [(-1,'R'),(1,'L')]:
        foot='Leg0.'+side; mallet='Mallet.'+side
        g.tube((s*.08,.016,.19),(s*.102,.002,.071),.046,.035,SKIN,foot)
        g.rings([(s*.102,-.035,0,.052,.074),(s*.102,-.036,.027,.057,.081),
            (s*.102,-.020,.06,.049,.065),(s*.102,.002,.074,.035,.039)],
            [ROOT_BROWN,COPPER,OCHRE,CREAM],foot,18)
        g.oval((s*.130,.007,.392),(.040,.044,.042),SKIN,mallet)
        g.tube((s*.127,0,.389),(s*.202,-.081,.294),.035,.026,SKIN,mallet)
        g.oval((s*.202,-.086,.295),(.036,.041,.033),CREAM,mallet)
        a=(s*.220,-.041,.266); b=(s*.170,-.246,.402)
        g.tube(a,b,.009,.011,ROOT_BROWN,mallet,12)
        g.oval(b,(.032,.035,.032),AMBER,mallet,18)
        g.oval((b[0],b[1]-.005,b[2]+.011),(.025,.026,.020),GOLD,mallet)
    # The cap slopes down to an uneven, cream-edged brim with radial gills below.
    cap_start=len(g.verts)
    rings=[]; colors=[]
    for r,z,tone in [(.075,.476,CREAM),(.17,.478,SKIN),(.255,.495,CREAM),
            (.276,.51,CREAM),(.272,.532,AMBER),(.244,.575,BRICK),
            (.202,.633,BRICK),(.141,.689,'d9784a'),(.077,.727,AMBER),(.016,.739,AMBER)]:
        row=[]
        for i in range(40):
            a=TAU*i/40
            wave=(.004+.009*r/.276)*sin(3*a+.3)+.005*cos(5*a)
            row.append((r*cos(a)-.018*(z-.48),.015+r*.91*sin(a),z+wave))
        rings.append(row);colors.append(tone)
    g.loft(rings,colors,'Head',True)
    for i in range(22):
        a=TAU*i/22
        g.line([(.096*cos(a),.015+.087*sin(a),.472),(.177*cos(a),.015+.163*sin(a),.476),
             (.255*cos(a),.015+.231*sin(a),.493+.01*sin(3*a+.3))],
             [.004,.008,.003],OCHRE,'Head',7)
    for j,(ring,n,z,r,spot) in enumerate([(0,13,.548,.260,.018),(1,10,.606,.220,.025),
            (2,7,.659,.175,.020),(3,4,.703,.112,.024)]):
        for i in range(n):
            a=TAU*(i+.42*(j%2))/n
            if cos(a*1.3+j)> .95: continue
            p=(r*cos(a),.015+r*.91*sin(a),z+.009*sin(3*a+.3))
            g.oval(p,(spot*1.2,spot,spot*.72),CREAM,'Head',12,6)
    pivot=Vector((0,.01,.49))
    tilt=Euler((radians(-13),0,radians(-4))).to_matrix()
    for i in range(cap_start,len(g.verts)):
        g.verts[i]=tuple(pivot+tilt@(Vector(g.verts[i])-pivot))
    for s in [-1,1]:
        g.oval((s*.057,-.093,.427),(.017,.009,.027),EYE,'Body',16)
        g.oval((s*.056,-.102,.439),(.005,.003,.007),CREAM,'Body',8,5)
        g.oval((s*.088,-.082,.406),(.023,.008,.011),'cb927b','Body',12)
        g.line([(s*.039,-.092,.451),(s*.068,-.088,.463)],[.004,.005],ROOT_BROWN,'Body')
    g.line([(-.016,-.103,.398),(0,-.108,.391),(.015,-.105,.397)],[.002,.004,.002],ROOT_BROWN,'Body')
    # A real pair of hide heads, rope lacing and a bronze center sun on the waist drum.
    drum='Drum'
    g.rings([(0,-.146,.177,.157,.110),(0,-.155,.192,.163,.117),
        (0,-.161,.244,.168,.121),(0,-.168,.31,.163,.118),(0,-.171,.326,.165,.12)],
        [ROOT_BROWN,COPPER,COPPER,ROOT_BROWN,CREAM],drum,24)
    g.rings([(0,-.171,.321,.169,.122),(0,-.171,.334,.169,.122)],GOLD,drum,28)
    g.rings([(0,-.171,.334,.159,.114),(0,-.171,.335,.159,.114)],CREAM,drum,28)
    for i in range(12):
        a=TAU*i/12; b=a+TAU/24;c=a+TAU/12
        g.line([(.166*cos(a),-.17+.120*sin(a),.315),(.164*cos(b),-.153+.120*sin(b),.197),
             (.166*cos(c),-.17+.120*sin(c),.315)],[.004,.004,.004],GOLD,drum,6)
    for s in [-1,1]:
        g.ribbon([(s*.097,.064,.42),(s*.100,-.064,.395),(s*.114,-.119,.306)],
            [(1,0,0)]*3,[.011,.014,.014],GREEN,'Body',(0,-.006,0))
    g.build('SporeDrummerMesh',rig,surface_material(1024))
    idle={'Mallet.L':(-23,0,0),'Mallet.R':(-8,0,0)}
    wind={**idle,'Body':(-8,0,0),'Head':(-9,0,0),'Mallet.L':(-87,0,-12),'Mallet.R':(-108,0,9)}
    impact={'Body':(16,0,0,0,0,-.015),'Head':(-13,0,0),'Mallet.L':(27,0,-4),
        'Mallet.R':(19,0,6),'Drum':(9,0,0)}
    motions(rig,legs,wind,impact,idle)
    # A drum cadence alternates the two sticks on the same head, matching the support pulse.
    old=bpy.data.actions.get('Attack'); bpy.data.actions.remove(old)
    left={**impact,'Mallet.L':(-61,0,-3),'Mallet.R':(25,0,0)}
    right={**impact,'Mallet.L':(25,0,0),'Mallet.R':(-59,0,4)}
    action(rig,'Attack',[(1,wind),(7,left),(14,right),(21,left),(28,impact),(35,idle)])
    save('drum_shroom',rig)


ROOT_BROWN='75503c'
if __name__=='__main__':
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['boar','beetle','drummer']
    for name in chosen:
        reset()
        {'boar':boar,'beetle':beetle,'drummer':drummer}[name]()
