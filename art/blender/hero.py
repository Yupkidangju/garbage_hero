"""Build the playable repairer. Run Blender in background with --python hero.py."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from model_tools import *
import hero_arsenal

INK='222537'; NAVY='344453'; BLUE='4c6370'; LEATHER='794634'; SEAM='ffc988'
CLOTH='d46b3d'; LIGHT='ffa95d'; DARK='954d37'; SCARF='2ba49c'; AQUA='8ae8cb'
HAIR='343653'; STRAND='555277'; SHINE='9c93b5'; SKIN='f4b491'; BLUSH='db8c7c'
BRASS='efb552'; STEEL='b6cac6'; SILVER='eef4da'
grip=Vector((-.338,-.049,.765))
blade_dir=Vector((-.58,-.72,.34)).normalized()
blade_w=(Vector((0,0,1))-blade_dir*blade_dir.z).normalized()
blade_n=blade_dir.cross(blade_w).normalized()
def sword(x,w=0,n=0):
    return grip + blade_dir*x + blade_w*w + blade_n*n

def skeleton():
    bones=[('Root',(0,0,0),(0,0,.17),None),('Pelvis',(0,0,.68),(0,0,.87),'Root'),
        ('Spine',(0,0,.87),(0,0,1.13),'Pelvis'),('Chest',(0,0,1.13),(0,0,1.27),'Spine'),
        ('Head',(0,0,1.27),(0,0,1.72),'Chest'),
        ('Apron',(0,-.09,.84),(.03,-.14,.59),'Pelvis'),
        ('Scarf',(0,.09,1.22),(.20,.20,.96),'Chest')]
    for side,s in [('L',1),('R',-1)]:
        def add(name,a,b,parent):
            bones.append((name+'.'+side,(s*a[0],*a[1:]),(s*b[0],*b[1:]),parent))
        add('Collar',(.025,0,1.2),(.185,0,1.2),'Chest')
        add('UpperArm',(.185,0,1.2),(.297,.014,.997),'Collar.'+side)
        add('Forearm',(.297,.014,.997),(.336,-.037,.825),'UpperArm.'+side)
        add('ArmTwist',(.319,-.014,.90),(.336,-.037,.825),'Forearm.'+side)
        add('Hand',(.336,-.037,.825),(.339,-.057,.725),'Forearm.'+side)
        add('Thigh',(.108,0,.737),(.117,-.018,.419),'Pelvis')
        add('Shin',(.117,-.018,.419),(.124,.007,.139),'Thigh.'+side)
        add('Foot',(.124,.007,.139),(.124,-.14,.060),'Shin.'+side)
    nock = grip + Vector((0,.21,0))
    bones.extend([('WeaponGrip',grip,sword(.10),'Hand.R'),
                  ('BowNock',nock,nock+Vector((0,.1,0)),'WeaponGrip'),
                  ('SwordBase',sword(.13),sword(.19),'WeaponGrip'),
                  ('SwordTip',sword(1.04),sword(1.08),'WeaponGrip')])
    return armature('Repairer',bones)


def outfit(g):
    g.rings([(0,0,.67,.13,.09),(0,0,.72,.165,.11),(0,.002,.84,.144,.104),
        (0,0,.99,.155,.115),(0,0,1.14,.194,.135),(0,.004,1.21,.183,.117),
        (0,0,1.25,.079,.074)], [NAVY,NAVY,BLUE,CLOTH,CLOTH,LIGHT,DARK],
        ['Pelvis','Pelvis',{'Pelvis':.55,'Spine':.45},'Spine',
         {'Spine':.4,'Chest':.6},'Chest','Chest'],28)
    g.rings([(0,0,1.21,.068,.066),(0,0,1.34,.069,.065)],SKIN,'Chest')
    # A broad canvas bib and asymmetric hem keep the repairer readable at field scale.
    g.panel([(-.112,-.114,1.15),(.099,-.119,1.15),(.144,-.115,.86),
        (-.14,-.119,.86)],(0,.013,0),NAVY,'Spine')
    g.panel([(-.144,-.120,.85),(.139,-.115,.85),(.173,-.141,.645),
        (.068,-.157,.58),(-.143,-.14,.628)],(0,.018,0),NAVY,'Apron')
    g.line([(-.140,-.145,.639),(.066,-.160,.597),(.158,-.147,.652)],
           [.004,.004,.004],SEAM,'Apron')
    g.panel([(-.09,-.133,1.045),(.038,-.140,1.045),(.033,-.140,.972),
        (-.02,-.143,.949),(-.086,-.135,.977)],(0,.01,0),BLUE,'Spine')
    g.line([(-.085,-.138,1.035),(.034,-.144,1.035)],[.004,.004],SEAM,'Spine')
    for s in [-1,1]:
        for front in [-1,1]:
            g.ribbon([(s*.102,front*.117,1.115),(s*.135,front*.096,1.21),
                (s*.111,front*.035,1.237)],[(1,0,0)]*3,[.018,.016,.014],LEATHER,'Chest')
        g.oval((s*.106,-.125,1.122),(.011,.006,.011),BRASS,'Chest')
    g.rings([(0,0,.815,.157,.123),(0,0,.865,.157,.122)],LEATHER,'Pelvis',28)
    g.panel([(-.027,-.13,.821),(.028,-.13,.821),(.028,-.13,.86),
        (-.027,-.13,.86)],(0,.008,0),BRASS,'Pelvis')
    g.panel([(-.015,-.137,.832),(.016,-.137,.832),(.016,-.137,.849),
        (-.015,-.137,.849)],(0,.007,0),INK,'Pelvis')
    # Rolled collar and a split scarf that catches air behind the shoulders.
    g.rings([(0,0,1.188,.131,.113),(0,-.008,1.219,.144,.119),
        (0,0,1.253,.112,.093),(0,0,1.273,.09,.079)],
        [SCARF,SCARF,AQUA,SCARF],'Chest')
    g.panel([(-.079,-.11,1.225),(.085,-.108,1.226),(.022,-.144,1.128)],
            (0,.012,.003),SCARF,'Chest')
    for s,lenmult in [(1,1),(-1,.76)]:
        g.ribbon([(.031,.098,1.228),(.049+s*.06,.146,1.188),
            (.060+s*.13,.167,1.094),(.07+s*.19,.197,1.23-.29*lenmult)],
            [(1,0,0)]*4,[.042,.054,.036,.003],[AQUA,SCARF,SCARF,AQUA],'Scarf',(0,.016,0))
    # Two crossed straps and a stitched canvas roll on the back.
    for s in [-1,1]:
        g.ribbon([(s*.13,.093,1.21),(s*.091,.125,1.12),(-s*.122,.104,.874)],
            [(1,0,0)]*3,[.014,.014,.018],LEATHER,'Spine',(0,.008,0))
    g.tube((-.147,.117,.89),(.131,.117,.89),.05,.05,BLUE,'Pelvis',14)
    for x in [-.105,.087]:
        g.tube((x-.011,.117,.89),(x+.011,.117,.89),.054,.054,SEAM,'Pelvis',14)
    for s,side in [(1,'L'),(-1,'R')]:
        a='UpperArm.'+side; f='Forearm.'+side; h='Hand.'+side
        g.oval((s*.19,0,1.17),(.08,.091,.092),CLOTH,a,20)
        g.tube((s*.205,0,1.16),(s*.284,.012,1.024),.080,.064,CLOTH,a,16)
        if side=='L':
            g.oval((s*.21,-.008,1.189),(.082,.098,.054),SEAM,a,22)
            g.oval((s*.211,-.008,1.199),(.083,.10,.046),BLUE,a,22)
            for z,y in [(1.20,-.1),(1.175,-.09)]:
                g.oval((s*.232,y,z),(.009,.005,.009),BRASS,a)
        else:
            g.oval((s*.214,-.010,1.175),(.079,.093,.035),DARK,a,18)
            g.oval((s*.212,-.010,1.183),(.081,.094,.034),CLOTH,a,18)
        g.tube((s*.278,.012,1.036),(s*.304,.013,.994),.074,.066,LIGHT,a,16)
        g.oval((s*.295,.013,.997),(.056,.054,.056),NAVY,f)
        g.tube((s*.30,.013,.997),(s*.326,-.017,.89),.049,.044,SKIN,f)
        twist='ArmTwist.'+side
        g.tube((s*.319,-.007,.928),(s*.341,-.038,.827),.059,.052,LEATHER,{twist:.65,f:.35},16)
        for t in [0,.057]:
            g.tube((s*(.32+t*.19),-.01-t*.30,.925-t),(s*(.323+t*.19),-.015-t*.30,.91-t),
                .062-t*.09,.061-t*.09,BRASS if side=='R' else SEAM,f,16)
        g.oval((s*.338,-.041,.786),(.061,.064,.074),LEATHER,h,20)
        g.oval((s*.342,-.050,.77),(.058,.061,.052),DARK,h,20)
        g.oval((s*.301,-.082,.788),(.022,.029,.044),LEATHER,h)
        for j in range(3):
            g.oval((s*(.314+j*.023),-.098,.773),(.012,.008,.019),SEAM,h,10,5)
        thigh,shin,foot='Thigh.'+side,'Shin.'+side,'Foot.'+side
        g.rings([(s*.11,0,.736,.094,.091),(s*.109,0,.644,.091,.084),
            (s*.112,0,.535,.081,.072),(s*.117,-.017,.427,.061,.058)],
            [NAVY,BLUE,NAVY,NAVY],[thigh,thigh,thigh,{thigh:.75,shin:.25}])
        g.rings([(s*.117,-.017,.43,.061,.054),(s*.117,0,.35,.059,.060),
            (s*.124,.006,.15,.049,.049)],NAVY,[{thigh:.3,shin:.7},shin,shin])
        g.rings([(s*.121,0,.198,.065,.066),(s*.12,0,.312,.071,.070),
            (s*.119,-.002,.341,.069,.065)],LEATHER,shin)
        g.rings([(s*.12,0,.298,.073,.071),(s*.12,0,.326,.073,.07)],SEAM,shin)
        g.oval((s*.12,-.05,.216),(.048,.025,.063),DARK,shin)
        g.rings([(s*.124,-.047,0,.076,.126),(s*.124,-.047,.049,.08,.130),
            (s*.124,-.041,.087,.076,.126),(s*.124,-.02,.13,.065,.096),
            (s*.124,.006,.20,.060,.062)], [INK,INK,LEATHER,DARK,LEATHER],foot)
        for z,y in [(.098,-.096),(.121,-.069)]:
            g.tube((s*.124-.044,y,z),(s*.124+.044,y,z),.007,.007,SEAM,foot)
    g.oval((.159,-.005,.79),(.064,.074,.073),LEATHER,'Pelvis')
    g.panel([(.169,-.073,.829),(.204,-.066,.819),(.207,-.074,.779),
        (.163,-.084,.78)],(0,.012,0),SEAM,'Pelvis')
    for x in [.136,.175]:
        g.tube((x,.024,.81),(x+.018,.034,.925),.009,.012,STEEL,'Pelvis')
        g.tube((x+.018,.034,.921),(x+.023,.037,.953),.017,.010,BRASS,'Pelvis')
    # A patched knee, a hex badge and hand-sewn pockets break up the workwear.
    g.oval((-.119,-.06,.447),(.051,.019,.059),LEATHER,'Thigh.R',16)
    g.oval((-.119,-.073,.447),(.036,.009,.041),DARK,'Thigh.R',16)
    for j in range(3):
        x=.046+j*.025
        g.tube((x,-.147,.745),(x+.015,-.147,.748),.0025,.0025,SEAM,'Apron')
    g.panel([(.034,-.143,.81),(.113,-.139,.807),(.12,-.148,.754),(.093,-.151,.736),
        (.039,-.151,.746)],(0,.005,0),BLUE,'Apron')
    g.oval((.060,-.136,1.097),(.024,.004,.024),BRASS,'Spine',6,5)
    g.oval((.060,-.140,1.097),(.012,.004,.012),NAVY,'Spine',6,5)
    for s in [-1,1]:
        for j in range(3):
            x=s*(.11+j*.007); z=1.105-j*.047
            g.tube((x,-.123,z),(x+s*.003,-.124,z-.018),.002,.002,SEAM,'Spine')


def head(g):
    b='Head'
    g.rings([(0,-.013,1.272,.034,.060),(0,-.009,1.292,.082,.093),
        (0,-.006,1.323,.124,.121),(0,-.002,1.371,.160,.145),
        (0,0,1.443,.182,.151),(0,.005,1.523,.19,.149),
        (0,.012,1.592,.163,.129),(0,.01,1.648,.087,.082)],SKIN,b,48)
    def face(x,z,offset):
        return (x,-.151 * (max(.12,1-(x/.194)**2))**.5 + offset,z)
    for s in [-1,1]:
        g.oval((s*.17,0,1.405),(.028,.036,.054),SKIN,b,18)
        g.oval((s*.186,-.016,1.407),(.013,.018,.031),BLUSH,b)
        g.oval((s*.176,-.002,1.356),(.012,.012,.015),BRASS,b)
        def eye(points, tone, off):
            pts = [face(s*x,z,off) for x,z in points]
            # Curved almond with a center fan to follow the rounded cheek.
            cx,cz=np.mean(points,axis=0)
            c=g.vertex(face(s*cx,cz,off-.002),tone,b)
            ring=[g.vertex(p,tone,b) for p in pts]
            for a,d in zip(ring,ring[1:]+ring[:1]):
                g.faces.append((a,d,c) if s==1 else (d,a,c))
        eye([(.023,1.442),(.048,1.475),(.082,1.489),(.115,1.482),(.141,1.493),
             (.131,1.457),(.109,1.426),(.075,1.416),(.042,1.422)],INK,-.006)
        eye([(.026,1.441),(.050,1.466),(.084,1.477),(.119,1.469),(.123,1.456),
             (.105,1.430),(.075,1.422),(.043,1.428)],'fff1dc',-.009)
        for cx,cz,rx,rz,tone,depth in [(.081,1.449,.026,.027,INK,-.013),
            (.081,1.448,.021,.024,'3d8079',-.018),(.082,1.457,.012,.018,'263c47',-.022),
            (.078,1.431,.014,.006,'88d6b6',-.023),(.073,1.464,.008,.007,'ffffdf',-.028),
            (.092,1.447,.003,.003,'e7ffe2',-.026)]:
            eye([(cx+rx*cos(TAU*k/18),cz+rz*sin(TAU*k/18)) for k in range(18)],tone,depth)
        eye([(.037,1.49),(.082,1.507),(.12,1.502),(.116,1.508),(.083,1.514),(.037,1.501)],HAIR,-.01)
        for dx in [.0,.012,.024]:
            g.tube(face(s*(.104+dx),1.410,-.008),face(s*(.100+dx),1.405,-.008),.0016,.001,BLUSH,b,6)
    g.panel([(-.009,-.152,1.396),(.006,-.164,1.379),(.014,-.149,1.382)],
            (0,.008,0),'e4a180',b)
    g.line([(-.024,-.141,1.344),(.002,-.149,1.339),(.025,-.141,1.347)],
           [.0014,.0025,.0014],LEATHER,b)
    # Swept deep-indigo bob, with longer shells behind the ears.
    center=Vector((0,.012,1.494))
    caps=[]
    for j in range(13):
        row=[]
        for i in range(52):
            a=TAU*i/52
            bottom=1.86 + .65*sin(a) + .05*cos(3*a)
            t=.015+(bottom-.015)*j/12
            row.append(center+Vector((.201*sin(t)*cos(a),.170*sin(t)*sin(a),.192*cos(t))))
        caps.append(row)
    g.loft(caps,HAIR,b,smooth=True)
    for i in range(17):
        a=TAU*i/17
        if sin(a)<-.50:
            continue
        spread=(-sin(a),cos(a),-.10)
        p=[(.127*cos(a),.012+.106*sin(a),1.635),(.192*cos(a),.016+.165*sin(a),1.555),
           (.201*cos(a),.023+.172*sin(a),1.459),(.194*cos(a+.075),.031+.175*sin(a+.075),1.32+.048*cos(3*a))]
        g.ribbon(p,[spread]*4,[.025,.048,.041,.001],[HAIR,STRAND if i%3==1 else HAIR,HAIR,HAIR],b,
                 (.012*cos(a),.012*sin(a),.003))
    # Seven independently faceted bangs frame the eyes without masking the gaze.
    for i,(start,end,tip,w) in enumerate([(-.12,-.167,1.38,.035),(-.08,-.124,1.472,.049),
            (-.036,-.084,1.499,.049),(.012,-.043,1.47,.05),(.060,.009,1.497,.051),
            (.104,.067,1.505,.043),(.141,.132,1.463,.042)]):
        z1=1.622+.025*(1-abs(start)/.15)
        points=[(start,-.104,z1),((start+end)*.5,-.145,1.577),
            (end+.020,face(end,tip,-.016)[1],tip+.041),(end,face(end,tip,-.021)[1],tip)]
        g.ribbon(points,[(1,0,.19)]*4,[w*.45,w,w*.70,.0008],
                 [STRAND if i%3==1 else HAIR,STRAND,HAIR,HAIR],b,(0,-.015,.002))
        if i in [1,3,4]:
            g.ribbon([points[0],(points[1][0]-.007,points[1][1]-.017,1.589),
                (points[2][0]+.008,points[2][1]-.014,points[2][2]+.012)],
                [(1,0,0)]*3,[.001,.007,.001],SHINE,b,(0,-.001,0))
    g.ribbon([(.027,.022,1.634),(.064,.055,1.709),(.129,.069,1.745),(.163,.052,1.726)],
        [(1,0,0),(1,0,0),(.4,0,1),(.4,0,1)],[.031,.039,.019,.001],
        [HAIR,STRAND,STRAND,HAIR],b,(0,-.012,0))
    # Round brass goggles above the fringe, glazed and riveted.
    for s in [-1,1]:
        g.line([(s*.088,-.122,1.604),(s*.157,-.073,1.606),(s*.182,.006,1.574),
            (s*.157,.099,1.537)],[.019,.018,.017,.014],LEATHER,b)
        g.oval((s*.074,-.132,1.617),(.058,.026,.046),INK,b,24)
        g.oval((s*.074,-.151,1.619),(.056,.017,.044),BRASS,b,28)
        g.oval((s*.074,-.160,1.620),(.044,.014,.033),'337d83',b,26)
        g.oval((s*.067,-.173,1.633),(.016,.003,.006),'aeefdc',b)
    g.line([(-.028,-.144,1.617),(0,-.145,1.622),(.028,-.144,1.617)],
        [.011,.012,.011],LEATHER,b)


def weapon(g):
    b='WeaponGrip'
    g.tube(sword(-.14),sword(.112),.024,.026,LEATHER,b,14)
    for t in [-.125,-.092,-.06,-.027,.014,.052,.083]:
        g.tube(sword(t),sword(t+.012),.027,.027,SEAM,b,14)
    g.oval(sword(-.145),(.033,.034,.034),BRASS,b)
    def plate(points,depth,tone,bone=b):
        g.panel([sword(x,w,depth) for x,w in points],blade_n*-.009,tone,bone)
    outline=[(.119,-.052),(.212,-.096),(.707,-.121),(.748,-.115),(.796,-.134),
        (.903,-.139),(1.040,.038),(.998,.105),(.881,.122),(.846,.101),
        (.778,.105),(.758,.125),(.338,.107),(.292,.083),(.171,.079)]
    g.panel([sword(x,w,-.022) for x,w in outline],blade_n*.044,INK,b)
    for sign in [-1,1]:
        d=sign*.026
        plate([(x,w*.95) for x,w in outline],d,'819893')
        plate([(.182,.052),(.224,-.066),(.87,-.109),(.988,.030),(.963,.073),
            (.863,.092),(.824,.075),(.767,.085),(.745,.099),(.34,.084),(.29,.063)],d*1.5,'ad4939')
        plate([(.244,-.046),(.425,-.058),(.418,-.039),(.243,-.029)],d*1.8,'f2d29a')
        plate([(.414,-.010),(.712,-.024),(.68,-.056),(.834,-.012),(.714,.063),
            (.728,.025),(.418,.037)],d*1.8,'ffe4a8')
        plate([(.24,-.082),(.71,-.11),(.75,-.101),(.79,-.121),(.90,-.125),(.99,-.01),
            (.873,-.103),(.78,-.098),(.725,-.095),(.36,-.061)],d*1.65,SILVER)
        for x,w in [(.224,.043),(.246,-.056),(.866,.062),(.879,-.077)]:
            g.tube(sword(x,w,sign*.032),sword(x,w,sign*.047),.011,.009,BRASS,b)
        for x,w in [(.35,.066),(.57,.068),(.49,-.053),(.91,.049)]:
            plate([(x,w),(x+.055,w+.006),(x+.011,w+.009)],d*1.85,'e7b899')
    g.tube(sword(.124,-.112),sword(.124,.117),.023,.020,BRASS,b,10)
    g.tube(sword(.129,-.101),sword(.13,-.137),.022,.015,INK,b,10)


def upgrades(rig,mat):
    for grade in range(1,7):
        g=Geometry(); b='WeaponGrip'
        if grade==1:
            for x in [-.12,-.076,-.032,.012,.056]:
                g.tube(sword(x),sword(x+.022),.029,.030,SCARF,b,16)
        elif grade==2:
            for x in [.223,.319]:
                g.tube(sword(x,-.083,.050),sword(x+.049,.093,.050),.015,.015,BRASS,b)
        elif grade==3:
            for x in [.42,.54,.66,.78]:
                g.panel([sword(x,.1,.012),sword(x+.025,.157,.012),sword(x+.096,.11,.012)],
                        -blade_n*.023,STEEL,b)
        elif grade==4:
            for s in [-1,1]:
                g.oval(sword(.19,0,.061*s),(.027,.026,.030),'3dd4bd',b)
        elif grade==5:
            for s in [-1,1]:
                g.line([sword(.34,-.074,s*.063),sword(.73,-.084,s*.063),sword(.88,-.099,s*.063),
                    sword(1.0,.031,s*.063)],[.005,.008,.009,.002],AQUA,b)
        else:
            for x,w in [(.9,.17),(1.02,.13),(1.07,.063)]:
                g.ribbon([sword(x-.04,w),sword(x,w+.019),sword(x+.028,w+.006)], [blade_w]*3,
                         [.001,.018,.001],BRASS,b,blade_n*.01)
        g.build('Grade'+str(grade),rig,mat)


def controls(rig):
    # Source-side unparented IK goals can be blended with authored FK in Pose mode.
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for side in ['L','R']:
        for label,tip in [('Foot','Shin'),('Hand','Forearm')]:
            joint=rig.data.edit_bones[tip+'.'+side]
            ctrl=rig.data.edit_bones.new('IK_'+label+'.'+side)
            ctrl.head=joint.tail; ctrl.tail=joint.tail+Vector((0,-.09,0))
            ctrl.use_deform=False
    bpy.ops.object.mode_set(mode='OBJECT')
    for side in ['L','R']:
        twist=rig.pose.bones['ArmTwist.'+side].constraints.new('COPY_ROTATION')
        twist.name='Distribute wrist twist'; twist.target=rig; twist.subtarget='Hand.'+side
        twist.target_space='LOCAL'; twist.owner_space='LOCAL'
        twist.use_x=False; twist.use_z=False; twist.influence=.5
        for label,tip in [('Foot','Shin'),('Hand','Forearm')]:
            chain=rig.pose.bones[tip+'.'+side].constraints.new('IK')
            chain.name='IK blend'; chain.target=rig; chain.subtarget='IK_'+label+'.'+side
            chain.chain_count=2; chain.influence=0


def animate(rig):
    idle={'UpperArm.R':(5,-5,0),'Forearm.R':(-10,0,0),'UpperArm.L':(0,3,0),
          'Forearm.L':(-10,1,0),'Scarf':(4,0,0)}
    breathe={**idle,'Chest':(-2,0,1),'Head':(2,0,-2),'Scarf':(-6,2,1),
             'UpperArm.R':(8,-6,0),'Forearm.L':(-13,1,0)}
    action(rig,'Idle',[(1,idle),(58,breathe),(115,idle)])
    def run(side):
        other='L' if side=='R' else 'R'
        return {'Spine':(10,0,4 if side=='R' else -4),'Head':(-9,0,0),
            'Pelvis':(0,0,0,0,0,-.026),'Thigh.'+side:(-39,0,0),'Shin.'+side:(17,0,0),
            'Foot.'+side:(16,0,0),'Thigh.'+other:(33,0,0),'Shin.'+other:(23,0,0),
            'Foot.'+other:(-15,0,0),'UpperArm.'+side:(27,0,0),'UpperArm.'+other:(-24,0,0),
            'Forearm.L':(-32,0,0),'Forearm.R':(-26,0,0),'Scarf':(-25,3,0),'Apron':(-8,0,0)}
    def passing(side):
        return {'Spine':(11,0,0),'Head':(-8,0,0),'Pelvis':(0,0,0,0,0,.013),
            'Thigh.'+side:(-6,0,0),'Shin.'+side:(62,0,0),'Foot.'+side:(-24,0,0),
            'Forearm.L':(-30,0,0),'Forearm.R':(-30,0,0),'Scarf':(-32,0,0),'Apron':(-14,0,0)}
    action(rig,'Run',[(1,run('L')),(9,passing('R')),(17,run('R')),(25,passing('L')),(33,run('L'))])
    def strike(chest,upper,fore,hips,extra=None):
        p={**idle,'Chest':chest,'UpperArm.R':upper,'Forearm.R':fore,'Pelvis':hips,
           'Head':(-chest[0]*.55,0,-chest[2]*.55),'UpperArm.L':(-16,12,0),
           'Forearm.L':(-48,0,0),'Scarf':(-21,0,-chest[2]*.4),'Apron':(-9,0,0)}
        if extra: p.update(extra)
        return p
    low=strike((8,-8,-25),(27,22,-48),(-11,0,-10),(0,0,-12))
    high=strike((-6,9,32),(-67,-18,32),(-31,-8,29),(0,0,18))
    across=strike((12,-5,-33),(-52,25,-38),(-20,0,-29),(0,0,-19))
    overhead=strike((-12,6,-13),(-149,12,-8),(-39,0,12),(0,0,-11))
    down=strike((29,-7,13),(-42,5,19),(-6,-2,0),(0,0,11,0,-.025,-.054),
        {'Thigh.L':(-20,0,0),'Shin.L':(30,0,0),'Scarf':(-35,0,0)})
    action(rig,'Attack1',[(1,idle),(8,low),(12,high),(17,high),(25,idle)])
    action(rig,'Attack2',[(1,idle),(10,high),(15,across),(20,across),(29,idle)])
    action(rig,'Attack3',[(1,idle),(12,overhead),(16,overhead),(22,down),(28,down),(43,idle)])
    action(rig,'Slam',[(1,idle),(15,overhead),(23,overhead),(28,down),(40,down),(54,idle)])
    reach=strike((15,2,18),(-84,-9,9),(-4,-4,1),(0,0,12))
    pull=strike((-13,-4,-18),(16,12,-13),(-82,0,0),(0,0,-12))
    action(rig,'Hook',[(1,idle),(13,pull),(16,reach),(18,reach),(24,pull),(36,idle)])
    spin=strike((5,0,0),(-22,53,-12),(-6,0,0),(0,0,0))
    turn=[(1,idle),(11,low)]
    for k in range(9):
        turn.append((12+k*2,{**spin,'Root':(0,0,k*86),'Scarf':(-39,0,-28)}))
    turn.extend([(34,{**across,'Root':(0,0,710)}),(47,idle)])
    action(rig,'Spin',turn)
    crouch={'Pelvis':(0,0,0,0,0,-.11),'Spine':(23,0,0),'Head':(-16,0,0),
        'Thigh.L':(-42,0,0),'Thigh.R':(-39,0,0),'Shin.L':(72,0,0),'Shin.R':(70,0,0),
        'UpperArm.L':(26,0,0),'UpperArm.R':(17,0,0),'Scarf':(-45,0,0),'Apron':(-20,0,0)}
    glide={**crouch,'Thigh.R':(26,0,0),'Shin.R':(24,0,0),'UpperArm.R':(-35,0,0)}
    action(rig,'Dodge',[(1,idle),(5,crouch),(8,glide),(13,glide),(17,crouch),(25,idle)])
    recoil=strike((-16,-7,-12),(20,21,-7),(-37,0,0),(0,0,0,0,.023,-.02))
    action(rig,'Hit',[(1,idle),(4,recoil),(9,recoil),(18,idle)])
    fall={**recoil,'Root':(-81,0,-13,0,0,.16),'Head':(12,6,0),
          'UpperArm.L':(-24,-32,0),'Forearm.L':(-8,0,0),'Thigh.L':(-17,0,0)}
    action(rig,'Death',[(1,idle),(8,recoil),(20,{**crouch,'Root':(-21,2,-8)}),
        (36,fall),(49,fall)])
    hero_arsenal.moves(rig,idle,blade_dir)


if __name__=='__main__':
    reset()
    rig=skeleton()
    mat=surface_material()
    g=Geometry()
    outfit(g); head(g)
    g.build('RepairerMesh',rig,mat)
    blade=Geometry(); weapon(blade); blade.build('WeaponBase',rig,mat)
    upgrades(rig,mat)
    hero_arsenal.equipment(rig,mat,grip,blade_dir,blade_w,blade_n)
    controls(rig); animate(rig)
    save('hero',rig)
