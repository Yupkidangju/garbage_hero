"""The forest's snare-antler stag and wheelback elder, authored in metres."""
import sys
from pathlib import Path
from math import sqrt
sys.path.insert(0,str(Path(__file__).resolve().parent))
from model_tools import *

BARK='664c40'; HEART='9a6850'; GOLD='e9a950'; BONE='e6ce96'; IRON='495864'
RIM='7d8078'; DARK='343b40'; LEAF='478467'; LIGHT='85b677'; MOSS='66874e'
FUR='a8573e'; TAN='cd8154'; CREAM='eed2a2'; EYE='ffd772'


def spindle(g,sections,rgb,bone,n=28):
    rings=[[(cos(i*TAU/n)*rx,y,z+sin(i*TAU/n)*rz) for i in range(n)] for y,z,rx,rz in sections]
    g.loft(rings,rgb,bone,smooth=True)


def branch(g,points,radii,shades,bone,sides=8):
    for i in range(len(points)-1):
        g.tube(points[i],points[i+1],radii[i],radii[i+1],shades[i%len(shades)],bone,sides)
        if i and radii[i]>.03:
            r=radii[i]
            g.oval(points[i],(r,r,r),shades[i%len(shades)],bone,10,5)


def leaf(g,base,direction,width,rgb,bone):
    a=Vector(base); v=Vector(direction)
    spread=v.cross(Vector((0,1,0)))
    if spread.length<.04: spread=Vector((1,0,0))
    g.ribbon([a,a+v*.35,a+v*.67,a+v],[spread]*4,[.006,width,width*.67,.001],
             rgb,bone,(0,-width*.17,width*.10))


def hoop(g,center,radius,width,depth,rgb,bone,n=32):
    x,y,z=center
    rings=[]
    for i in range(n+1):
        a=TAU*i/n
        rings.append([(x+cos(a)*r,y+d,z+sin(a)*r) for r,d in
                      [(radius-width,-depth),(radius,-depth),(radius,depth),(radius-width,depth)]])
    g.loft(rings,rgb,bone)


def stag():
    bones=[('Root',(0,0,0),(0,0,.3),None),('Body',(0,.32,1.05),(0,-.32,1.24),'Root'),
           ('Neck',(0,-.34,1.25),(0,-.66,1.63),'Body'),
           ('Head',(0,-.66,1.63),(0,-.99,1.59),'Neck'),('Tail',(0,.5,1.23),(0,.72,1.27),'Body')]
    legs=[]
    for s,side in [(-1,'R'),(1,'L')]:
        for back,part in [(False,'Fore'),(True,'Hind')]:
            y=.34 if back else -.34
            top=(s*.20,y,1.17); knee=(s*.22,y+(.095 if back else -.025),.67)
            hock=(s*.235,y+(.15 if back else .01),.38); foot=(s*.24,y-.035,.13)
            a,b,c=[part+t+'.'+side for t in ['Upper','Lower','Hoof']]
            bones.extend([(a,top,knee,'Body'),(b,knee,foot,a),(c,foot,(s*.24,y-.115,.04),b)])
            legs.append((a,b,c,top,knee,hock,foot,s,back))
    rig=armature('SnareStag',bones); g=Geometry()
    spindle(g,[(-.53,1.17,.105,.16),(-.44,1.18,.196,.303),(-.28,1.16,.256,.324),
        (0,1.14,.228,.253),(.24,1.17,.233,.246),(.41,1.16,.242,.265),(.54,1.18,.16,.17),
        (.58,1.20,.054,.08)], [CREAM,TAN,FUR,FUR,FUR,TAN,TAN,CREAM],'Body')
    g.rings([(0,-.32,1.14,.214,.223),(0,-.39,1.35,.20,.194),
        (0,-.50,1.51,.151,.157),(0,-.62,1.68,.118,.126)], [CREAM,TAN,FUR,TAN],
        ['Body',{'Body':.45,'Neck':.55},'Neck','Neck'])
    spindle(g,[(-1.055,1.57,.058,.042),(-.99,1.576,.078,.066),(-.86,1.62,.117,.085),
        (-.73,1.67,.143,.137),(-.62,1.69,.142,.135),(-.552,1.707,.077,.084)], 
        [DARK,CREAM,TAN,FUR,TAN,TAN],'Head',32)
    g.oval((0,-1.041,1.598),(.062,.033,.033),DARK,'Head')
    g.oval((0,-1.065,1.602),(.027,.01,.008),'818b83','Head')
    for a,b,c,top,knee,hock,foot,s,back in legs:
        g.oval(top,(.112,.150,.215),FUR,a,20)
        g.tube(top,knee,.107,.05,TAN,a,16)
        g.oval(knee,(.055,.061,.076),DARK,b)
        g.tube(knee,hock,.047,.036,back and TAN or CREAM,b,12)
        g.tube(hock,foot,.041,.030,DARK,b,12)
        g.rings([(foot[0],foot[1]-.018,0,.049,.065),
            (foot[0],foot[1]-.016,.058,.051,.068),(foot[0],foot[1],.131,.034,.036)],
            [DARK,IRON,DARK],c,12)
        g.tube((foot[0],foot[1],.146),(foot[0],foot[1],.170),.039,.040,BONE,b)
    g.ribbon([(0,.49,1.24),(0,.608,1.25),(.02,.747,1.312)],
        [(1,0,0)]*3,[.056,.068,.002],[TAN,CREAM,CREAM],'Tail',(0,0,.036))
    for s in [-1,1]:
        g.ribbon([(s*.09,-.63,1.75),(s*.20,-.567,1.795),(s*.34,-.52,1.87)],
            [(0,0,1)]*3,[.03,.055,.001],[FUR,CREAM,TAN],'Head',(0,-.045,.004))
        # The raised metal half-jaws and teeth identify the trapping antlers in silhouette.
        rail=[(s*.087,-.645,1.78),(s*.16,-.576,1.954),(s*.26,-.53,2.068),
              (s*.49,-.46,2.119),(s*.69,-.41,2.26),(s*.77,-.45,2.43),(s*.75,-.49,2.54)]
        branch(g,rail,[.054,.048,.046,.051,.044,.023,.004],[HEART,HEART,IRON,IRON,RIM,BONE],'Head',9)
        for i,(x,y,z,h) in enumerate([(.27,-.53,2.07,.20),(.408,-.47,2.11,.17),
                                      (.564,-.44,2.178,.15),(.671,-.413,2.253,.16)]):
            branch(g,[(s*x,y,z),(s*(x-.02),y-.038,z+h*.55),(s*(x-.066),y-.06,z+h)],
                   [.031,.022,.002],[RIM,BONE],'Head',7)
        branch(g,[rail[2],(s*.228,-.37,2.21),(s*.204,-.27,2.37)],
               [.038,.021,.003],[HEART,BONE],'Head')
        for p in [rail[1],rail[3],rail[4]]:
            g.oval(p,(.055,.054,.051),GOLD,'Head',12,6)
        g.oval((s*.111,-.795,1.682),(.032,.061,.043),DARK,'Head',18)
        g.oval((s*.133,-.816,1.683),(.018,.035,.025),EYE,'Head')
        g.oval((s*.15,-.823,1.684),(.006,.011,.017),DARK,'Head')
        g.oval((s*.154,-.83,1.694),(.006,.007,.006),'fff1bf','Head')
        g.line([(s*.116,-.843,1.710),(s*.14,-.786,1.74),(s*.130,-.73,1.743)],
            [.010,.019,.006],BONE,'Head')
        for i in range(6):
            y=-.08+i*.09
            x=.217+.013*cos(i*1.7)
            g.oval((s*x,y,1.27+.04*sin(i*1.7)),(.013,.022,.018),CREAM,'Body')
        g.ribbon([(s*.124,-.697,1.63),(s*.14,-.63,1.525),(s*.141,-.60,1.43)],
            [(1,0,0)]*3,[.024,.047,.003],[CREAM,TAN,CREAM],'Neck',(0,-.026,0))
        for yy,zz in [(-.24,1.25),(.32,1.22)]:
            for j in range(3):
                x=s*(.231+.016*cos(j)); y=yy+.043*j; z=zz+.077*cos(j*.9)
                g.ribbon([(x,y,z),(x+s*.014,y+.018,z-.039),(x+s*.009,y+.026,z-.081)],
                    [(0,1,0)]*3,[.006,.019,.001],[TAN,CREAM,TAN],'Body',(s*.009,0,0))
        g.ribbon([(s*.16,-.44,1.36),(s*.14,-.48,1.245),(s*.11,-.47,1.08)],
            [(1,0,0)]*3,[.04,.058,.003],[CREAM,CREAM,TAN],'Neck',(0,-.018,0))
    for y,z,r in [(-.412,1.385,.191),(-.436,1.422,.182)]:
        g.rings([(0,y,z,r,r*.94),(0,y-.007,z+.024,r-.003,r*.92)],IRON,'Neck')
    hoop(g,(0,-.605,1.383),.065,.016,.01,GOLD,'Neck')
    for s in [-1,1]:
        leaf(g,(s*.14,-.56,1.936),(s*.12,.017,.13),.034,LEAF,'Head')
        leaf(g,(s*.15,-.56,1.938),(s*.095,-.045,.047),.030,LIGHT,'Head')
    g.build('StagMesh',rig,surface_material())
    stag_motion(rig)
    save('trap_antler',rig)


def stag_motion(rig):
    action(rig,'Idle',[(1,{}),(56,{'Neck':(-4,0,-3),'Head':(2,0,5),'Tail':(13,0,4)}),(111,{})])
    def stride(phase):
        p={'Body':(phase*3,0,0,0,0,-.025),'Neck':(phase*4,0,0),'Head':(-phase*3,0,0),'Tail':(phase*12,0,0)}
        for s,side in [(-1,'R'),(1,'L')]:
            for k,part in [(-1,'Fore'),(1,'Hind')]:
                step=phase*k*s
                p[part+'Upper.'+side]=(step*27,0,0)
                p[part+'Lower.'+side]=(max(0,-step)*38,0,0)
                p[part+'Hoof.'+side]=(-step*8,0,0)
        return p
    action(rig,'Run',[(1,stride(1)),(8,stride(0)),(15,stride(-1)),(22,stride(0)),(29,stride(1))])
    scrape={'Neck':(32,0,-6),'Head':(19,0,0),'ForeUpper.R':(-24,0,0),'ForeLower.R':(47,0,0),'Tail':(-17,0,0)}
    ram={**stride(1),'Neck':(39,0,0),'Head':(28,0,0)}
    action(rig,'Windup',[(1,{}),(18,scrape),(30,{**scrape,'ForeUpper.R':(12,0,0)}),(45,scrape)])
    action(rig,'Attack',[(1,scrape),(8,ram),(18,{**ram,'ForeUpper.L':(-24,0,0)}),(29,ram)])
    action(rig,'Recover',[(1,ram),(22,{'Neck':(16,0,-10),'Head':(8,0,7)}),(45,{})])
    action(rig,'Hit',[(1,{}),(5,{'Neck':(-20,0,12),'Body':(-6,4,0)}),(17,{})])
    fallen={'Root':(3,78,-8,0,0,.24),'Neck':(22,6,0),'Head':(15,-9,0),'ForeUpper.L':(-36,0,0)}
    action(rig,'Death',[(1,{}),(15,{'ForeLower.R':(53,0,0),'ForeUpper.R':(-49,0,0),'Body':(16,0,0)}),
                        (36,fallen),(53,fallen)])


def elder():
    bones=[('Root',(0,0,0),(0,0,.37),None),('Pelvis',(0,0,1.04),(0,0,1.54),'Root'),
           ('Trunk',(0,0,1.54),(0,0,2.41),'Pelvis'),('Crown',(0,0,2.41),(0,0,3.09),'Trunk')]
    for s,side in [(-1,'R'),(1,'L')]:
        bones.extend([('Wheel.'+side,(s*.75,.052,2.44),(s*.75,-.10,2.44),'Trunk'),
            ('Arm.'+side,(s*.66,0,2.38),(s*.99,-.045,1.85),'Trunk'),
            ('Claw.'+side,(s*.99,-.045,1.85),(s*1.18,-.162,1.08),'Arm.'+side),
            ('Leg.'+side,(s*.38,0,1.29),(s*.49,-.05,.73),'Pelvis'),
            ('Foot.'+side,(s*.49,-.05,.73),(s*.53,-.065,.16),'Leg.'+side)])
    rig=armature('WheelbackElder',bones); g=Geometry()
    g.rings([(0,0,1.08,.38,.31),(0,.01,1.32,.48,.365),(0,0,1.53,.44,.37),
        (0,0,1.86,.54,.397),(0,.008,2.16,.681,.44),(0,.015,2.40,.62,.42),
        (0,.018,2.61,.45,.36),(0,.016,2.89,.413,.32),(0,.006,3.03,.448,.34)],
        [BARK,HEART,BARK,HEART,BARK,HEART,HEART,BARK,HEART],
        ['Pelvis','Pelvis',{'Pelvis':.5,'Trunk':.5},'Trunk','Trunk','Trunk',
         {'Trunk':.25,'Crown':.75},'Crown','Crown'],26)
    # Sawn growth rings inside the hollow crown, including scarred broken bark spikes.
    layers=[(.439,.330,HEART),(.388,.286,BONE),(.352,.257,HEART),(.32,.227,BONE),
            (.28,.206,HEART),(.228,.162,BONE),(.184,.134,HEART),(.130,.10,BONE),(.066,.05,HEART)]
    for i,(rx,ry,m) in enumerate(layers):
        g.rings([(.019,.012,3.032+i*.001,rx,ry),(.019,.012,3.034+i*.001,rx,ry)],m,'Crown',27)
    for i in range(23):
        a=TAU*i/23
        xx,yy=cos(a),sin(a)
        spread=(-yy,xx,0)
        if yy>-.64 or abs(xx)>.77:
            g.ribbon([(.41*xx,.318*yy,1.29),(.458*xx,.36*yy,1.59),(.557*xx,.401*yy,1.986),
                (.620*xx,.420*yy,2.35),(.444*xx,.337*yy,2.67)],
                [spread]*5,[.019,.070,.078,.053,.014],
                [DARK,BARK,HEART if i%3==0 else BARK,BARK,HEART],'Trunk',(.022*xx,.022*yy,.003))
        if i%2==0:
            high=.13+.14*(.5+.5*cos(i*2.7))
            g.ribbon([(.404*xx,.312*yy,2.83),(.436*xx,.339*yy,3.01),
                (.461*xx,.365*yy,3.03+high)], [spread]*3,[.055,.073,.003],
                [BARK,HEART,BONE],'Crown',(.024*xx,.024*yy,.003))
    for s,side in [(-1,'R'),(1,'L')]:
        arm,claw,leg,foot='Arm.'+side,'Claw.'+side,'Leg.'+side,'Foot.'+side
        g.oval((s*.70,.015,2.32),(.30,.32,.32),BARK,arm)
        branch(g,[(s*.69,.0,2.36),(s*.806,-.003,2.12),(s*.984,-.045,1.82)],
               [.226,.213,.157],[HEART,BARK],arm,13)
        g.oval((s*.985,-.039,1.84),(.190,.198,.177),MOSS,claw)
        branch(g,[(s*.991,-.05,1.82),(s*1.094,-.09,1.56),(s*1.176,-.155,1.18)],
               [.158,.213,.163],[HEART,BARK],claw,13)
        for j in range(4):
            offset=(j-1.5)*.096
            branch(g,[(s*(1.165+offset),-.15,1.22),(s*(1.207+offset*1.27),-.202,1.06),
                (s*(1.19+offset*1.43),-.264,.882-.061*(j%2))],[.065,.051,.007],[HEART,BONE],claw)
        branch(g,[(s*1.034,-.203,1.38),(s*.946,-.23,1.265),(s*.912,-.239,1.16)],
               [.067,.05,.009],[HEART,BONE],claw)
        branch(g,[(s*.38,.006,1.35),(s*.432,-.029,1.06),(s*.491,-.05,.727)],
               [.231,.206,.155],[BARK,HEART],leg,13)
        g.oval((s*.485,-.054,.729),(.188,.187,.167),MOSS,foot)
        branch(g,[(s*.49,-.044,.72),(s*.527,-.043,.389),(s*.53,-.068,.151)],
               [.153,.191,.204],[BARK,HEART],foot,14)
        for dx in [-.19,-.062,.085,.202]:
            g.ribbon([(s*(.53+dx*.27),-.07,.296),(s*(.53+dx*.67),-.14,.17),
                (s*(.53+dx),-.33-.11*cos(dx*8),.0114)],
                 [(1,0,0)]*3,[.068,.111,.019],[BARK,HEART,BONE],foot,(0,0,.038))
        for offset in [-.18,.13]:
            g.ribbon([(s*(.53+offset*.3),.03,.237),(s*(.53+offset*.89),.125,.129),
                (s*(.53+offset*1.2),.279,.009)],[(1,0,0)]*3,[.064,.101,.017],
                [BARK,HEART,BONE],foot,(0,0,.030))
        wheel='Wheel.'+side
        x,y,z=s*.794,.120,2.453
        g.tube((x,y-.207,z),(x,y+.235,z),.145,.172,IRON,wheel,18)
        hoop(g,(x,y,z),.578,.104,.101,HEART,wheel,36)
        hoop(g,(x,y,z),.598,.034,.112,IRON,wheel,36)
        hoop(g,(x,y-.121,z),.578,.031,.012,RIM,wheel,36)
        hoop(g,(x,y+.115,z),.578,.031,.012,RIM,wheel,36)
        for i in range(9):
            a=TAU*i/9+(.083 if s==1 else 0)
            u,v=cos(a),sin(a)
            g.tube((x+.09*u,y,z+.09*v),(x+.506*u,y,z+.506*v),.055,.038,'ba8258',wheel,8)
            for sign in [-1,1]:
                g.tube((x+.553*u,y+sign*.128,z+.553*v),(x+.553*u,y+sign*.142,z+.553*v),
                    .016,.011,GOLD,wheel,8)
        g.tube((x,y-.171,z),(x,y+.171,z),.123,.123,IRON,wheel,16)
        g.tube((x,y-.198,z),(x,y-.17,z),.071,.083,GOLD,wheel,8)
        # Branch crowns frame the round man-made shoulders.
        branch(g,[(s*.22,.029,2.93),(s*.36,.05,3.17),(s*.54,.082,3.30),
            (s*.596,.115,3.46)],[.083,.058,.043,.008],[HEART,BARK,BONE],'Crown')
        branch(g,[(s*.36,.05,3.17),(s*.331,.081,3.37),(s*.263,.075,3.48)],
               [.041,.028,.005],[HEART,BONE],'Crown')
        for j in range(5):
            a=j*2.399
            leaf(g,(s*(.42+.032*j),.06+.009*j,3.21+.041*j),
                 (s*(.18*cos(a)),.13*sin(a),.128),.063,LEAF if j%2 else LIGHT,'Crown')
        # Layered brow, amber sap eye, angular cheek guard and carved jaw.
        def face(points,tone,y=-.408):
            g.panel([(s*xx,y+.13*xx*xx,zz) for xx,zz in points],(0,.034,0),tone,'Crown')
        face([(.059,2.50),(.142,2.624),(.386,2.65),(.338,2.51),(.166,2.459)],DARK,-.411)
        face([(.113,2.516),(.197,2.582),(.330,2.605),(.285,2.535),(.167,2.498)],GOLD,-.427)
        face([(.181,2.512),(.213,2.565),(.233,2.572),(.222,2.525)],'fff0ab',-.438)
        face([(.028,2.572),(.116,2.719),(.325,2.729),(.473,2.817),
            (.370,2.648),(.178,2.619),(.075,2.544)],BARK,-.449)
        face([(.089,2.633),(.157,2.713),(.335,2.734),(.195,2.678)],HEART,-.469)
        face([(.159,2.429),(.365,2.526),(.455,2.449),(.334,2.299),(.207,2.256)],HEART,-.432)
    g.ribbon([(0,-.36,2.75),(0,-.438,2.60),(0,-.47,2.437),(0,-.48,2.371)],
        [(1,0,0)]*4,[.047,.083,.102,.012],[HEART,HEART,BARK,BONE],'Crown',(0,-.055,0))
    g.panel([(-.22,-.431,2.337),(-.089,-.451,2.362),(0,-.456,2.334),(.118,-.451,2.362),
        (.216,-.431,2.334),(.11,-.444,2.277),(-.026,-.454,2.263)],(0,.032,0),DARK,'Crown')
    for i in range(11):
        x=(i-5)*.053
        leaf(g,(x,-.40+.17*x*x,2.33-.045*(1-abs(i-5)/5)),
            (x*.318,-.081,-.20-.14*cos(x*5)),.047,LEAF if i%3 else MOSS,'Trunk')
    # Front bark follows a lightning split around a knot of luminous amber heartwood.
    profiles=[(-.47,-.096,2.14),(-.35,-.265,2.13),(-.22,-.344,2.18),(-.095,-.397,2.08),
              (.055,-.408,2.12),(.178,-.378,2.17),(.304,-.306,2.09),(.435,-.21,2.16)]
    for j,(x,y,z) in enumerate(profiles):
        g.ribbon([(x*1.12,y-.031,z+.10),(x,y-.066,z-.012),(x*.87+.016,y-.066,z-.20),
            (x*.79-.017,y-.055,z-.43),(x*.91+.033,y-.021,z-.69)],[(1,0,.025)]*5,
            [.015,.081,.063,.046,.003],[BARK,HEART if j%2 else BARK,HEART,BARK,DARK],
            'Trunk',(0,-.043,.001))
    for s in [-1,1]:
        branch(g,[(s*.22,-.405,2.14),(s*.16,-.463,1.99),(s*.094,-.502,1.94),
            (s*.078,-.488,1.82),(s*.009,-.457,1.741)],
            [.045,.043,.039,.034,.014],[BARK,HEART,BARK,HEART],'Trunk',9)
    g.oval((0,-.469,1.923),(.076,.039,.130),DARK,'Trunk',20)
    g.ribbon([(0,-.515,2.016),(-.031,-.526,1.936),(.006,-.531,1.879),
        (.012,-.513,1.821)],[(1,0,0)]*4,[.005,.040,.024,.002],
         [BONE,GOLD,'ffcf75',GOLD],'Trunk',(0,-.01,0))
    for s,side in [(-1,'R'),(1,'L')]:
        for j in range(3):
            x=s*(.878+.099*j); y=-.128-.033*j
            g.ribbon([(x,y,2.063-.052*j),(x+s*.058,y-.062,1.96-.091*j),
                (x+s*.083,y-.037,1.76-.089*j)],[(1,0,0)]*3,[.012,.035,.004],
                 [BARK,HEART,BARK],'Arm.'+side,(0,-.021,0))
        for j in range(6):
            x=s*(.606+.067*(j%3)); y=-.064-.064*(j//3); z=2.56-.038*(j%3)
            leaf(g,(x,y,z),(s*(.12+.014*j),-.063,-.10-.047*(j%3)),.057,
                MOSS if j%2 else LIGHT,'Arm.'+side)
    for i in range(21):
        a=TAU*i/21; x=.48*cos(a); y=.322*sin(a)
        if y<-.16: continue
        leaf(g,(x,y,2.91+.057*sin(a*3)),(.13*cos(a),.12*sin(a),.105+.05*cos(i*1.7)),
             .084,MOSS if i%2==0 else LIGHT,'Crown')
    # Layered shelf fungi growing from the old wheelwright's torso.
    for i,(x,y,z,r) in enumerate([(.44,-.28,1.8,.115),(.48,-.25,1.734,.087),
            (-.46,.18,2.02,.096),(.29,.312,2.57,.10),(-.39,-.20,1.48,.071)]):
        g.oval((x,y,z),(r,r*.72,r*.30),BONE,'Trunk',14,6)
        g.oval((x,y,z+.015),(r*.96,r*.70,r*.26),'ca8a4e','Trunk',14,6)
    g.build('ElderMesh',rig,surface_material())
    elder_motion(rig)
    save('wheelback',rig)


def elder_motion(rig):
    def gesture(tilt,arm,rear=0):
        return {'Trunk':(tilt,0,0),'Crown':(-tilt*.6,0,0),'Arm.L':(arm,-rear,0),
            'Arm.R':(arm,rear,0),'Claw.L':(-max(4,abs(arm)*.35),0,0),
            'Claw.R':(-max(4,abs(arm)*.35),0,0)}
    action(rig,'Idle',[(1,{}),(67,{**gesture(-3,5,2),'Wheel.R':(0,5,0),'Crown':(2,0,5)}),(133,{})])
    def walk(s):
        return {'Trunk':(4,-s*4,s*6),'Leg.R':(s*22,0,0),'Leg.L':(-s*22,0,0),
            'Foot.R':(max(0,-s)*25,0,0),'Foot.L':(max(0,s)*25,0,0),
            'Arm.R':(-s*19,0,0),'Arm.L':(s*19,0,0),'Crown':(-3,0,-s*4),
            'Wheel.R':(0,s*14,0),'Wheel.L':(0,-s*14,0)}
    action(rig,'Run',[(1,walk(1)),(14,walk(0)),(27,walk(-1)),(40,walk(0)),(53,walk(1))])
    wind={**gesture(-14,-132,20),'Crown':(-10,0,10),'Wheel.L':(0,83,0),'Wheel.R':(0,-80,0)}
    hit={**gesture(32,-31,9),'Pelvis':(0,0,0,0,-.06,-.095),'Crown':(-19,0,0)}
    action(rig,'Windup',[(1,{}),(32,wind),(55,{**wind,'Wheel.L':(0,113,0),'Wheel.R':(0,-113,0)})])
    action(rig,'Attack',[(1,wind),(8,hit),(15,{**hit,'Claw.L':(13,0,0),'Claw.R':(13,0,0)}),(34,hit)])
    action(rig,'Recover',[(1,hit),(30,{**hit,'Trunk':(22,0,-8)}),(66,{})])
    action(rig,'Hit',[(1,{}),(6,gesture(-11,17,6)),(18,{})])
    fallen={'Root':(-78,0,8,0,0,.5),'Trunk':(-5,12,-6),'Arm.R':(-18,13,12),'Arm.L':(-30,-16,0),
            'Wheel.R':(0,134,0),'Wheel.L':(0,-76,0)}
    action(rig,'Death',[(1,{}),(16,gesture(21,32,4)),(33,{'Root':(-28,0,8),'Trunk':(-12,0,0)}),
                        (54,fallen),(72,fallen)])


if __name__=='__main__':
    reset()
    target=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'both'
    if target in ['stag','both']: stag()
    if target in ['elder','both']:
        reset()
        elder()
