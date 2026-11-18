"""The acorn mouse and pine wasp, two first-encounter forest animals."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from model_tools import *
from forest_bosses import leaf, branch

SOOT='373b41'; FUR='a87859'; DARK='79513f'; PALE='f2d3a5'; PINK='d88b80'
CAP='926137'; ROOT='6a4d35'; GOLD='e8b45e'; LEAF='538a62'; HILITE='f7ffcf'
WASP='354957'; BAND='e3aa44'; HONEY='f7d885'; WING='b0dfc4'; VEIN='638c83'


def mouse():
    bones=[('Root',(0,0,0),(0,0,.1),None),('Body',(0,.085,.18),(0,-.07,.409),'Root'),
           ('Head',(0,-.061,.403),(0,-.18,.611),'Body'),
           ('Tail',(0,.179,.208),(.102,.384,.229),'Body'),
           ('TailTip',(.102,.384,.229),(.046,.518,.397),'Tail')]
    for s,side in [(1,'L'),(-1,'R')]:
        bones.extend([('Ear.'+side,(s*.118,-.064,.556),(s*.203,-.059,.68),'Head'),
            ('Paw.'+side,(s*.108,-.055,.34),(s*.148,-.165,.195),'Body'),
            ('Foot.'+side,(s*.133,.071,.203),(s*.159,-.022,.032),'Root')])
    rig=armature('AcornScout',bones); g=Geometry()
    g.oval((0,.058,.259),(.187,.199,.221),FUR,'Body',24,12)
    g.oval((0,-.073,.275),(.147,.096,.181),PALE,'Body',24,10)
    for s,side in [(1,'L'),(-1,'R')]:
        leg='Foot.'+side; arm='Paw.'+side; ear='Ear.'+side
        g.oval((s*.137,.084,.148),(.097,.116,.134),DARK,leg,20)
        g.rings([(s*.145,.005,0,.062,.098),(s*.145,-.003,.017,.069,.119),
            (s*.143,.006,.045,.066,.112),(s*.139,.042,.067,.045,.059)], [DARK,PINK,FUR,DARK],leg,20)
        for j in [-1,0,1]:
            g.tube((s*.145+j*.024,-.081,.031),(s*.146+j*.027,-.106,.024),.006,.002,PALE,leg)
        g.oval((s*.129,-.053,.34),(.054,.060,.079),FUR,arm)
        g.tube((s*.139,-.069,.33),(s*.145,-.138,.235),.04,.026,FUR,arm)
        g.oval((s*.143,-.143,.232),(.032,.045,.028),PINK,arm)
        for j in [-1,0,1]:
            g.tube((s*.143+.013*j,-.163,.235),(s*.144+.013*j,-.184,.226),.006,.004,PALE,arm)
        g.oval((s*.174,-.05,.608),(.086,.044,.100),DARK,ear,26,12,(0,s*.28,0))
        g.oval((s*.176,-.077,.613),(.066,.031,.079),PALE,ear,24,10,(0,s*.28,0))
        g.oval((s*.182,-.096,.616),(.052,.018,.063),PINK,ear,24,10,(0,s*.28,0))
    g.oval((0,-.098,.464),(.181,.172,.148),FUR,'Head',32,14)
    for s in [-1,1]:
        g.oval((s*.057,-.215,.427),(.081,.078,.059),PALE,'Head',22,10)
        g.oval((s*.098,-.207,.504),(.045,.043,.053),DARK,'Head',24)
        g.oval((s*.108,-.23,.507),(.034,.031,.044),SOOT,'Head',24)
        g.oval((s*.106,-.252,.514),(.018,.014,.022),'463c37','Head')
        g.oval((s*.104,-.264,.532),(.011,.006,.011),'fff5cf','Head')
        g.oval((s*.119,-.255,.505),(.005,.006,.005),HILITE,'Head')
        g.oval((s*.131,-.203,.457),(.026,.016,.011),PINK,'Head')
        for i in range(3):
            p=[(s*.112,-.254,.449+i*.01),(s*.178,-.252,.441+i*.02),
               (s*(.232+i*.01),-.240,.425+i*.032)]
            g.line(p,[.0035,.0028,.001],PALE,'Head',6)
    g.oval((0,-.276,.457),(.026,.024,.019),DARK,'Head',20)
    g.oval((0,-.285,.463),(.018,.015,.011),PINK,'Head')
    for s in [-1,1]:
        g.panel([(s*.002,-.273,.412),(s*.016,-.271,.413),(s*.015,-.271,.395),
            (s*.004,-.273,.396)],(0,.008,0),HILITE,'Head')
    # The layered acorn cup sits between the mouse's large ears, leaving their pink centers visible.
    g.rings([(0,-.071,.554,.158,.147),(0,-.067,.574,.175,.15),
        (.007,-.058,.615,.154,.133),(.015,-.049,.648,.103,.083),
        (.023,-.041,.666,.032,.04)],[ROOT,CAP,CAP,GOLD,CAP],'Head',32)
    for j in range(3):
        count=17-3*j
        for i in range(count):
            a=TAU*(i+.48*(j%2))/count
            rx=.173-.030*j; ry=.151-.023*j; z=.565+j*.032
            x=.005*j+rx*cos(a); y=-.068+.006*j+ry*sin(a)
            tangent=(-sin(a),cos(a),0)
            g.ribbon([(x*.97,y+.007,z+.028),(x+.005*cos(a),y+.005*sin(a),z+.010),
                (x+.008*cos(a),y+.008*sin(a),z-.008)],[tangent]*3,[.012,.030-.003*j,.006],
                [GOLD if (i+j)%5==0 else CAP,CAP,ROOT],'Head',(.004*cos(a),.004*sin(a),0))
    branch(g,[(.02,-.04,.647),(.039,-.031,.700),(.067,-.018,.725)],[.024,.016,.010],[ROOT,CAP],'Head')
    leaf(g,(.041,-.03,.69),(.094,.039,.034),.033,LEAF,'Head')
    # A long curling mouse tail is kept thin against the heavier acorn silhouette.
    g.line([(0,.18,.202),(.039,.285,.178),(.102,.384,.229)],[.025,.018,.014],PINK,'Tail',12)
    g.line([(.102,.384,.229),(.122,.46,.304),(.093,.51,.386),(.044,.513,.397),(.029,.49,.382)],
        [.014,.013,.011,.008,.003],PINK,'TailTip',10)
    g.build('AcornMouseMesh',rig,surface_material(1024))
    def move(s):
        return {'Body':(s*8,0,0,0,0,.014*abs(s)),'Head':(-s*5,0,0),'Foot.L':(s*29,0,0),
            'Foot.R':(-s*29,0,0),'Paw.L':(-s*36,0,0),'Paw.R':(s*36,0,0),
            'Tail':(-s*15,0,s*7),'TailTip':(s*13,0,s*9),'Ear.L':(s*5,0,0),'Ear.R':(-s*5,0,0)}
    action(rig,'Idle',[(1,{}),(28,{'Body':(-3,0,0),'Head':(-5,0,7),'Ear.L':(-18,0,-8),
        'TailTip':(15,0,8)}),(40,{'Head':(3,0,9),'Ear.L':(7,0,3)}),(70,{})])
    action(rig,'Run',[(1,move(1)),(6,move(0)),(11,move(-1)),(16,move(0)),(21,move(1))])
    ready={'Body':(-15,0,0,0,0,-.026),'Head':(-14,0,0),'Ear.L':(-25,0,0),'Ear.R':(-25,0,0),
           'Paw.L':(-27,0,0),'Paw.R':(-27,0,0),'Tail':(28,0,0)}
    bite={'Body':(41,0,0,0,-.07,.071),'Head':(-17,0,0),'Paw.L':(-57,0,0),'Paw.R':(-57,0,0),
          'Foot.L':(33,0,0),'Foot.R':(33,0,0),'Tail':(-36,0,0)}
    action(rig,'Windup',[(1,{}),(12,ready),(20,ready)])
    action(rig,'Attack',[(1,ready),(7,bite),(12,bite),(19,{'Body':(17,0,0),'Head':(-7,0,0)})])
    action(rig,'Recover',[(1,{'Body':(17,0,0),'Head':(-7,0,0)}),(17,{})])
    action(rig,'Hit',[(1,{}),(4,{'Body':(-24,0,10),'Head':(-11,0,0),'Ear.L':(31,0,0)}),(14,{})])
    fallen={'Root':(6,81,-9,0,0,.12),'Head':(7,0,23),'Paw.L':(-27,0,0),'TailTip':(7,0,24)}
    action(rig,'Death',[(1,{}),(6,ready),(19,fallen),(31,fallen)])
    save('acorn_mouse',rig)


def wasp():
    bones=[('Root',(0,0,0),(0,0,.10),None),('Thorax',(0,.02,.65),(0,-.10,.78),'Root'),
           ('Mask',(0,-.105,.74),(0,-.277,.73),'Thorax'),
           ('Abdomen',(0,.1,.68),(0,.37,.68),'Thorax'),('Sting',(0,.33,.69),(0,.58,.71),'Abdomen')]
    for s,side in [(1,'L'),(-1,'R')]:
        bones.append(('Wing.'+side,(s*.08,-.01,.771),(s*.46,.11,.86),'Thorax'))
        bones.append(('Legs.'+side,(s*.085,-.01,.64),(s*.15,.05,.45),'Thorax'))
    rig=armature('PineNeedleWasp',bones);g=Geometry()
    g.oval((0,-.005,.705),(.126,.153,.142),WASP,'Thorax',26,13)
    g.oval((0,-.001,.783),(.114,.135,.074),BAND,'Thorax',24,10)
    sections=[(.075,.696,.067,.057),(.145,.678,.102,.104),(.190,.670,.134,.124),
              (.248,.667,.147,.132),(.307,.672,.137,.125),(.356,.678,.122,.117),
              (.399,.686,.104,.094),(.457,.693,.065,.059),(.488,.70,.031,.036)]
    g.loft([[(cos(TAU*i/28)*x,y,z+sin(TAU*i/28)*h) for i in range(28)]
           for y,z,x,h in sections],[WASP,BAND,BAND,WASP,WASP,BAND,BAND,WASP,WASP],'Abdomen',True)
    branch(g,[(0,.461,.697),(0,.522,.702),(0,.638,.713)],[.036,.029,.001],
        [HONEY,'e6f2cf'],'Sting',8)
    g.oval((0,-.159,.736),(.148,.119,.111),BAND,'Mask',28,12)
    g.oval((0,-.213,.702),(.090,.081,.063),WASP,'Mask',24)
    for s,side in [(1,'L'),(-1,'R')]:
        wing='Wing.'+side; legs='Legs.'+side
        g.oval((s*.089,-.218,.755),(.069,.061,.077),WASP,'Mask',22,10)
        g.oval((s*.100,-.236,.759),(.059,.049,.064),'529a94','Mask',18,9)
        # Graphic compound-eye flecks and a sharp eyebrow around a bright silhouette.
        for j,(dx,dy,dz) in enumerate([(.0,-.046,.012),(.021,-.035,.030),(.032,-.026,-.009),
                (.018,-.039,-.023),(-.013,-.039,.029)]):
            g.oval((s*(.10+dx),-.236+dy,.756+dz),(.008,.004,.008),
                'addcb2' if j%2 else HILITE,'Mask',8,5)
        g.line([(s*.028,-.240,.813),(s*.084,-.235,.823),(s*.139,-.198,.815)],
            [.009,.015,.005],HONEY,'Mask')
        branch(g,[(s*.042,-.198,.823),(s*.070,-.222,.891),(s*.113,-.272,.921)],
            [.010,.009,.004],[WASP,BAND],'Mask')
        g.oval((s*.114,-.273,.923),(.013,.014,.014),HONEY,'Mask')
        branch(g,[(s*.051,-.244,.699),(s*.063,-.290,.676),(s*.042,-.318,.686)],
            [.021,.012,.002],[SOOT,HONEY],'Mask')
        for j in range(3):
            y=-.072+j*.076; z=.638
            branch(g,[(s*.082,y,z),(s*(.123+j*.008),y+.041,z-.059),
                (s*(.144+j*.014),y-.010,z-.115),(s*(.162+j*.019),y-.033,z-.133)],
                [.012,.009,.006,.002],[WASP,BAND,SOOT],legs)
        # Overlapping opaque cel-painted wings; each vein starts at the actual hinge.
        for rear in [False,True]:
            base=Vector((s*.087,.053 if rear else -.039,.785))
            end=Vector((s*(.479 if rear else .582),.294 if rear else .089,.863 if rear else .943))
            v=end-base
            spread=Vector((s*.02,.93,.24)).normalized()
            center=base+v*.57
            points=[base,base+v*.38-spread*.058,base+v*.77-spread*.077,end-spread*.032,
                end,base+v*.80+spread*.046,base+v*.43+spread*.053]
            g.panel(points,(0,0,-.009),VEIN,wing)
            c=base+v*.55
            inset=[c+(p-c)*.93+Vector((0,0,.007)) for p in points]
            g.panel(inset,(0,0,-.002),('89c4b1' if rear else WING),wing)
            g.line([base+Vector((0,0,.012)),center+Vector((0,0,.013)),end+Vector((0,0,.012))],
                [.012,.007,.001],VEIN,wing)
            for t in [.40,.64,.79]:
                a=base+v*t+Vector((0,0,.014))
                g.line([a,a+v*.12-spread*.050],[.004,.002],VEIN,wing)
        for j in range(3):
            base=(s*(.061+.012*j),.11+.07*j,.756+.011*j)
            leaf(g,base,(s*(.044+.005*j),.170,.083),.016,'6e935b' if j%2 else LEAF,'Abdomen')
    g.build('PineWaspMesh',rig,surface_material(1024))
    def flap(angle,pitch=0,offset=0):
        return {'Wing.L':(0,-angle,0),'Wing.R':(0,angle,0),'Thorax':(pitch,0,0,0,0,offset),
            'Legs.L':(-pitch,0,0),'Legs.R':(-pitch,0,0),'Abdomen':(-pitch*.5,0,0)}
    action(rig,'Idle',[(1,flap(24)),(5,flap(-20,2,.012)),(9,flap(24,3,.019)),
        (13,flap(-20,1,.012)),(17,flap(24))])
    action(rig,'Run',[(1,flap(35,16)),(4,flap(-31,18,.009)),(7,flap(35,16)),
        (10,flap(-31,15,.011)),(13,flap(35,16))])
    wind={**flap(30,-23,.092),'Sting':(17,0,0),'Mask':(14,0,0)}
    shoot={**flap(-26,30,-.02),'Mask':(-19,0,0),'Abdomen':(-29,0,0),'Sting':(-37,0,0)}
    action(rig,'Windup',[(1,flap(0)),(9,wind),(14,{**wind,'Wing.L':(0,19,0),'Wing.R':(0,-19,0)}),(22,wind)])
    action(rig,'Attack',[(1,wind),(5,shoot),(11,shoot),(19,flap(12,7))])
    action(rig,'Recover',[(1,flap(12,7)),(6,flap(-15,4)),(12,flap(13)),(19,flap(0))])
    action(rig,'Hit',[(1,flap(0)),(3,{**flap(0,-12,.05),'Thorax':(-12,27,6)}),(13,flap(0))])
    fallen={'Root':(56,61,-8,0,0,-.18),'Wing.L':(12,49,0),'Wing.R':(18,-44,0),'Abdomen':(-42,0,0)}
    action(rig,'Death',[(1,flap(0)),(8,flap(-46,-20)),(22,fallen),(36,fallen)])
    save('pine_wasp',rig)


if __name__=='__main__':
    reset(); mouse()
    reset(); wasp()
