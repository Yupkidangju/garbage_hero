"""Original salvage equipment library. Run with Blender --background --python.

Blender +Z is the shaft axis, -Y is the painted front; glTF converts to +Y/-Z.
The same selected mesh is exported to GLB and rendered to its UI icon.
"""
import sys, json, math, argparse
from pathlib import Path
from mathutils import Vector, Quaternion
import bpy

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'art/blender'))
from model_tools import Geometry, color

P = math.pi
OUT = ROOT / 'game/assets/models/items'
ICONS = ROOT / 'game/assets/ui/items'
SOURCE = ROOT / 'art/ui_030'
for folder in (OUT, ICONS):
    folder.mkdir(parents=True, exist_ok=True)


def material(name, rough, metallic=0, emission=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    attr = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Paint'
    mat.node_tree.links.new(attr.outputs['Color'], shader.inputs['Base Color'])
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = rough
    if emission:
        mat.node_tree.links.new(attr.outputs['Color'], shader.inputs['Emission Color'])
        shader.inputs['Emission Strength'].default_value = emission
    return mat


class Item(Geometry):
    def __init__(self, row, mats):
        super().__init__()
        v = row['visual']
        self.row, self.mats, self.roles = row, mats, []
        self.palette = dict(body=v['color'].lstrip('#'), accent=v['accent'].lstrip('#'),
            steel='d8e7dd', dark='253746', wood='744832', leather='935736',
            light='f4d58a', glow=v['accent'].lstrip('#'), red='b84735', cream='c5cdb6')
        self.role_names = list(self.palette)

    def vertex(self, pos, rgb, bone):
        self.roles.append(self.role_names.index(rgb) if rgb in self.palette else 0)
        index=super().vertex(pos, self.palette.get(rgb, rgb), {})
        # Tonal paint variation is part of exported vertex color, rather than a
        # Blender-only noise node that would disappear from the runtime mesh.
        x,y,z=pos
        grain=.96+.035*math.sin(x*109+z*73)+.022*math.sin(y*131-x*47+z*91)
        self.paint[-1]=tuple(min(1,max(0,c*grain)) for c in self.paint[-1][:3])+(1,)
        return index

    def tube(self, a, b, r1, r2=None, rgb='accent', bone=None, n=12):
        return super().tube(a, b, r1, r1 if r2 is None else r2, rgb, None, n)

    def line(self, pts, r=.02, rgb='accent', bone=None, n=10):
        return super().line(pts, [r]*len(pts) if isinstance(r,(int,float)) else r, rgb, None, n)

    def ball(self, pos, dims, rgb='body', n=16, steps=8):
        return super().oval(pos, dims, rgb, None, n, steps)

    def panel(self, pts, depth=(0,.05,0), rgb='body', bone=None):
        return super().panel(pts, depth, rgb, None)

    def plate(self, pts, y=0, thick=.035, rgb='body'):
        return self.panel([(x,y,z) for x,z in pts],(0,thick,0),rgb)

    def box(self, pos, dims, rgb='body'):
        x,y,z = pos; a,b,c = [d/2 for d in dims]
        self.panel([(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y-b,z+c),(x-a,y-b,z+c)],(0,b*2,0),rgb)

    def ring(self, pos, radius, tube=.02, rgb='accent', normal=(0,1,0), n=32, start=0, end=2*P):
        center, axis = Vector(pos), Vector(normal).normalized()
        a = axis.cross(Vector((0,0,1)) if abs(axis.z)<.95 else Vector((0,1,0))).normalized()
        b = axis.cross(a)
        sections=[]
        for k in range(n+1):
            t=start+(end-start)*k/n
            radial=a*math.cos(t)+b*math.sin(t)
            sections.append([center+radial*(radius+tube*math.cos(j*P/3))+axis*tube*math.sin(j*P/3) for j in range(6)])
        self.loft(sections,rgb,None,smooth=True)

    def disc(self, pos, radius, thick=.05, rgb='body', n=24):
        p=Vector(pos)
        self.tube(p,p+Vector((0,thick,0)),radius,radius,rgb,n=n)

    def leaf(self, base, tip, width=.07, rgb='body', depth=.025):
        base,tip=Vector(base),Vector(tip)
        across=(tip-base).cross(Vector((0,1,0))).normalized()*width
        mid=base.lerp(tip,.52)
        self.panel([base,mid-across,tip,mid+across],(0,depth,0),rgb)
        self.line([base-Vector((0,.004,0)),tip-Vector((0,.004,0))],.007,'light')

    def rivet(self, pos, r=.014):
        self.ball(pos,(r,r*.45,r),'steel',8,4)

    def handle(self, end=.42, start=-.2, radius=.042):
        self.tube((0,0,start),(0,0,end),radius,radius,'wood')
        self.tube((0,0,start),(0,0,.19),radius*1.1,radius*1.1,'leather')
        for i in range(7):
            z=start+(i+.3)*(.19-start)/7
            self.ring((0,0,z),radius*1.12,.006,'accent',normal=(0,0,1),n=12)
        self.tube((0,0,start-.045),(0,0,start),radius*1.3,radius*1.3,'accent')
        self.tube((0,0,end-.025),(0,0,end+.025),radius*1.6,radius*1.6,'accent')

    def gear(self, pos, radius=.2, teeth=8, rgb='accent', hole=.08):
        x,y,z=pos
        self.ring(pos,radius-.023,.04,rgb,n=32)
        for i in range(teeth):
            a=i*2*P/teeth
            self.line([(x+math.cos(a)*hole,y,z+math.sin(a)*hole),
                       (x+math.cos(a)*(radius+.035),y,z+math.sin(a)*(radius+.035))],.024,rgb)
            self.ball((x+math.cos(a)*radius,y,z+math.sin(a)*radius),(.043,.035,.043),rgb,8,4)
        self.ring(pos,hole,.024,'steel',n=24)

    def bell(self, pos, size=.2, rgb='accent'):
        x,y,z=pos
        self.rings([(x,y,z-size*.55,size*.63,size*.52),(x,y,z-size*.4,size*.61,size*.50),
                    (x,y,z+size*.27,size*.35,size*.31),(x,y,z+size*.5,size*.15,size*.15)],rgb,None,20)
        self.ring((x,y,z-size*.52),size*.6,size*.06,'light',normal=(0,0,1),n=24)
        self.ball((x,y,z-size*.62),(size*.15,size*.15,size*.18),'dark',12,6)
        self.ring((x,y,z+size*.54),size*.15,size*.04,'accent',n=16)

    def crystal(self, base, tip, radius=.08, rgb='glow', n=6):
        b,t=Vector(base),Vector(tip)
        d=t-b
        self.tube(b,b+d*.22,radius*.55,radius,rgb,n=n)
        self.tube(b+d*.22,t,radius,0,rgb,n=n)

    def build_mesh(self):
        obj=super().build('Item_%03d_%s'%(self.row['id'],self.row['visual']['shape']),None,self.mats[0])
        obj.modifiers.clear()
        for mat in self.mats[1:]: obj.data.materials.append(mat)
        for poly,face in zip(obj.data.polygons,self.faces):
            poly.material_index=self.roles[face[0]]
        bevel=obj.modifiers.new('Rounded worn edges','BEVEL')
        bevel.width=.0035 if self.row['kind'] not in ('ring','necklace') else .0018
        bevel.segments=2; bevel.limit_method='ANGLE'; bevel.angle_limit=1.20
        obj['design_id']=self.row['id']; obj['shape']=self.row['visual']['shape']
        obj['feature']=self.row['visual']['feature']; obj['axis']='shaft +Z, front -Y'
        return obj


def sword(g,v):
    g.handle(.36)
    g.box((0,0,.255),(.40,.10,.055),'accent')
    if v==0:
        p=[(-.13,.29),(.20,.29),(.20,.68),(.14,.72),(.20,.76),(.20,1.13),(.10,1.21),(.02,1.17),(-.02,1.22),(-.16,1.18),(-.19,.86),(-.13,.83)]
        g.plate(p,y=-.035,thick=.09,rgb='dark')
        g.plate([(x*.84,z) for x,z in p],y=-.048,thick=.012,rgb='red')
        g.plate([(-.045,.48),(.045,.48),(.045,.87),(.105,.87),(0,1.04),(-.105,.87),(-.045,.87)],y=-.064,thick=.008,rgb='light')
        for x,z in [(-.12,.41),(.145,.41),(-.11,1.10),(.13,1.08)]:g.rivet((x,-.061,z),.014)
    elif v==1:
        g.plate([(-.07,.29),(.09,.29),(.11,.65),(.23,1.17),(.13,1.31),(-.01,1.09),(-.08,.70)],y=-.026,thick=.065)
        for z in [.60,.80,1.0]:g.plate([(-.04,z),(-.24,z-.10),(-.20,z+.11),(.02,z+.15)],y=-.035,thick=.07)
        g.line([(.05,-.04,.37),(.06,-.04,.77),(.16,-.04,1.17)],.014,'accent')
    elif v==2:
        pts=[(-.11,.31),(.14,.31),(.20,1.13),(0,1.31),(-.14,1.1)]
        for i in range(5):pts.extend([(-.18,.99-i*.12),(-.30,1.01-i*.12),(-.18,.91-i*.12)])
        g.plate(pts,y=-.02,thick=.065)
        g.crystal((.04,-.065,.4),(.07,-.065,1.21),.04,'glow')
    elif v==3:
        g.plate([(-.095,.30),(.095,.30),(.095,1.17),(0,1.36),(-.095,1.17)],y=-.03,thick=.065)
        g.plate([(-.018,.36),(.018,.36),(.018,1.18),(0,1.24),(-.018,1.18)],y=-.046,thick=.012,rgb='light')
        g.line([(0,0,-.24),(.08,0,-.32),(.08,0,-.38)],.015,'accent');g.bell((.08,0,-.42),.11)
    elif v==4:
        g.plate([(-.07,.31),(.06,.31),(.13,.77),(.40,1.14),(.61,1.19),(.41,1.28),(.20,1.18),(-.08,.88)],y=-.025,thick=.05)
        for s in [-1,1]:g.leaf((0,-.02,.28),(s*.25,-.03,.48),.06,'accent')
    elif v==5:
        g.plate([(-.09,.29),(.13,.29),(.13,.9),(.22,1.28),(.04,1.11),(-.06,1.31),(-.15,.91)],y=-.02,thick=.075)
        for i in range(5):g.crystal((-.10,-.02,.43+i*.14),(-.24,-.02,.58+i*.14),.047,'steel')
        g.line([(.045,-.065,.4),(.045,-.065,1.07)],.015,'glow')
    elif v==6:
        g.plate([(-.12,.29),(.15,.29),(.23,.52),(.28,1.05),(.12,1.25),(-.16,1.12)],y=-.04,thick=.11)
        g.box((.045,-.062,.78),(.18,.03,.29),'dark')
        for i in range(3):g.box((.045,-.085,.69+i*.08),(.14,.012,.026),'glow')
        g.line([(-.11,-.05,.33),(-.14,-.05,1.1),(.10,-.05,1.21)],.015,'steel')
    else:
        g.plate([(-.075,.27),(.075,.27),(.095,1.28),(0,1.46),(-.095,1.28)],y=-.03,thick=.06,rgb='steel')
        g.gear((0,-.005,.34),.22,6,'accent',.08)
        g.crystal((0,-.07,.42),(0,-.07,1.31),.026,'glow')


def bow(g,v):
    g.handle(.13,-.13,.046)
    tips=[]
    for s in [-1,1]:
        if v==0:pts=[(0,0,0),(.045,0,s*.22),(.09,0,s*.46),(.25,0,s*.69)]
        elif v==1:pts=[(0,0,0),(-.12,0,s*.23),(-.20,0,s*.48),(.08,0,s*.73),(.22,0,s*.66)]
        elif v==2:pts=[(0,0,0),(-.22,0,s*.19),(-.26,0,s*.58),(.18,0,s*.83)]
        elif v==3:pts=[(0,0,0),(-.25,0,s*.18),(-.25,0,s*.44),(.18,0,s*.44)]
        elif v==4:pts=[(0,0,0),(-.23,0,s*.22),(-.28,0,s*.48),(.13,0,s*.67)]
        elif v==5:pts=[(0,0,0),(-.19,0,s*.26),(-.21,0,s*.54),(.11,0,s*.73),(.23,0,s*.61)]
        elif v==6:pts=[(0,0,0),(-.17,0,s*.15),(-.19,0,s*.52),(.12,0,s*.70)]
        else:pts=[(-.25*math.sin(i*P/12),0,s*.72*i/6) for i in range(7)]
        g.line(pts,[.042]+[.051]*(len(pts)-2)+[.026],'body')
        g.line([(x,-.049,z) for x,y,z in pts],.012,'accent')
        tips.append(pts[-1])
        if v==0:g.ring(pts[2],.066,.012,'light',normal=(0,0,1),n=12)
        if v==1:
            for k in [1,2]:g.leaf(pts[k],Vector(pts[k])+Vector((-.13,-.01,s*.13)),.043)
        if v==2:g.line([(x+.06,.045,z) for x,y,z in pts],.025,'accent')
        if v==3:g.bell((-.21,0,s*.46),.095)
        if v==4:g.leaf(pts[1],pts[-1],.15)
        if v==5:g.crystal(pts[-2],Vector(pts[-2])+Vector((.16,0,s*.2)),.08,'steel')
        if v==6:g.gear(pts[-1],.13,8,'accent',.06)
        if v==7:g.crystal(pts[-1],Vector(pts[-1])+Vector((.04,0,s*.14)),.065,'glow')
    g.line([tips[0],(.28,0,0),tips[1]],.008,'cream')
    if v==0:g.plate([(-.08,.25),(-.08,.1),(-.23,.14),(-.20,.25)],y=-.04,thick=.01,rgb='red')
    if v==1:
        for z in [-.1,0,.1]:g.ball((-.04,-.03,z),(.068,.06,.07),'wood',10,6)
    if v==2:
        g.tube((-.1,0,-.16),(-.1,0,0),.09,.02,'glow',n=8)
        g.tube((-.1,0,0),(-.1,0,.16),.02,.09,'glow',n=8)
    if v==4:g.disc((-.08,-.02,0),.12,.05)
    if v==6:
        for i in range(5):g.box((-.05,0,(i-2)*.055),(.16,.14,.025),'red')
    if v==7:g.ring((-.08,0,0),.38,.023,'accent',n=40)


def staff(g,v):
    g.handle(.91,-.43,.035)
    if v==0:
        g.line([(0,0,.90),(.02,0,1.07),(.20,0,1.13),(.28,0,1.0)],.045,'accent')
        g.ball((.28,0,.94),(.11,.11,.14),'light');g.tube((.28,0,1.02),(.28,0,1.1),.05,.05,'steel')
    elif v==1:
        for s in [-1,1]:g.line([(0,0,.76),(s*.18,0,1.02),(s*.13,0,1.25),(0,0,1.31)],.035,'wood')
        g.ball((0,0,1.06),(.14,.12,.18),'glow')
        for i in range(6):
            a=i*P/3;g.line([(.07*math.cos(a),.07*math.sin(a),.9),(.14*math.cos(a),.14*math.sin(a),1.07),(.1*math.cos(a),.1*math.sin(a),1.22)],.018,'accent')
        g.ball((0,0,1.23),(.15,.13,.07),'wood')
    elif v==2:
        g.disc((0,-.02,1.07),.17,.06,'accent');g.disc((0,-.06,1.07),.1,.02,'glow')
        for i in range(7):
            a=i*2*P/7;g.crystal((math.cos(a)*.16,0,1.07+math.sin(a)*.16),(math.cos(a)*.31,0,1.07+math.sin(a)*.31),.05,'glow')
    elif v==3:
        for x,z in [(-.23,1.1),(0,1.3),(.23,1.18)]:
            g.line([(0,0,.84),(x,0,.94),(x,0,z-.1)],.028,'accent');g.tube((x,0,z-.1),(x,0,z),.045,.043,'cream');g.crystal((x,0,z),(x,0,z+.10),.027,'glow')
    elif v==4:
        g.gear((0,0,.84),.18,8,'accent',.05)
        for i in range(5):
            a=i*2*P/5;g.leaf((0,0,1.02),(.24*math.cos(a),.17*math.sin(a),1.19),.09)
        g.ball((0,0,1.12),(.08,.08,.08),'glow')
    elif v==5:
        g.crystal((0,0,.76),(0,0,1.48),.11,'glow')
        for s in [-1,1]:g.crystal((s*.14,0,.94),(s*.20,0,1.30+s*.08),.06,'steel')
    elif v==6:
        g.ball((0,0,1.04),(.16,.13,.22),'dark')
        for i in range(6):
            a=i*P/3;g.line([(.08*math.cos(a),.08*math.sin(a),.82),(.18*math.cos(a),.15*math.sin(a),1.03),(.10*math.cos(a),.10*math.sin(a),1.22)],.024,'accent')
        g.ball((0,-.1,1.03),(.075,.045,.13),'glow')
        for x,z in [(-.22,1.2),(0,1.39),(.22,1.23)]:g.line([(0,0,1.10),(x,0,1.12),(x,0,z)],.035,'body')
    else:
        for i in range(3):g.ring((0,0,1.08),.23,.018,'accent',normal=(math.sin(i*P/3),math.cos(i*P/3),.45),n=40)
        g.crystal((0,0,.94),(0,0,1.27),.072,'glow');g.ring((0,0,1.08),.09,.018,'steel',n=24)


def spear(g,v):
    g.handle(1.02,-.62,.033)
    if v==0:
        for x in [-.17,0,.17]:g.line([(0,0,.91),(x,0,1.03),(x,0,1.36-abs(x)*.35),(x*.8,0,1.43-abs(x)*.35)],.027,'steel')
    elif v==1:
        for s in [-1,1]:g.line([(0,0,.93),(s*.20,0,1.17),(s*.17,0,1.43),(s*.07,0,1.49)],.035,'body')
        g.ball((0,0,.99),(.09,.075,.14),'wood')
    elif v==2:
        pts=[(0,0,.98),(.10,0,1.15),(.16,0,1.30),(.12,0,1.47),(-.02,0,1.55)]
        g.line(pts,[.075,.07,.065,.045,.002],'accent')
        for i in range(1,4):g.ring(pts[i],.074-i*.009,.013,'body',normal=(0,0,1),n=12)
        for s in [-1,1]:g.crystal((0,0,1.06),(s*.19,0,1.26),.066,'glow')
    elif v==3:
        g.plate([(-.12,1.0),(.12,1.0),(.12,1.35),(.06,1.48),(-.06,1.48),(-.12,1.35)],y=-.03,thick=.07)
        g.plate([(.06,.99),(.34,.92),(.28,.78),(.37,.72),(.08,.77)],y=.025,thick=.012,rgb='dark')
        g.box((0,-.07,1.28),(.16,.02,.035),'accent')
    elif v==4:
        g.leaf((0,0,.98),(0,0,1.56),.115,'steel')
        for x in [-.025,.025]:g.line([(x,0,-.59),(x,0,.95)],.018,'body')
        for z in [.88,.96]:g.ring((0,0,z),.057,.01,'accent',normal=(0,0,1),n=16)
    elif v==5:
        g.crystal((0,0,.99),(0,0,1.60),.087,'glow')
        for s in [-1,1]:g.line([(s*.03,0,1.0),(s*.19,0,1.13),(s*.24,0,1.33),(s*.16,0,1.43)], [.052,.045,.03,.003],'cream')
    elif v==6:
        g.box((0,0,1.09),(.18,.14,.34),'body')
        for z in [1.0,1.1,1.2]:g.box((0,-.081,z),(.12,.018,.041),'dark');g.box((0,-.093,z),(.07,.008,.022),'glow')
        g.crystal((0,0,1.23),(0,0,1.66),.055,'glow')
    else:
        g.gear((0,0,1.14),.17,8,'accent',.06)
        for s in [-1,1]:g.line([(0,0,.99),(s*.25,0,1.18),(s*.25,0,1.45),(s*.17,0,1.59)], [.044,.039,.025,.003],'accent')
        g.crystal((0,0,1.23),(0,0,1.63),.07,'glow')


def mace(g,v):
    g.handle(.74,-.19,.043)
    if v==0:
        g.ring((0,0,.82),.22,.085,'body',n=6)
        g.ring((0,-.08,.82),.22,.012,'steel',n=6)
        g.ring((0,.08,.82),.22,.012,'accent',n=6)
    elif v==1:
        g.ball((0,0,.86),(.20,.17,.25),'wood',16,10)
        g.ball((0,0,1.05),(.23,.19,.10),'body')
        g.ring((0,0,.87),.195,.025,'accent',normal=(0,0,1),n=24)
        for x in [-.10,0,.10]:g.line([(x,-.15,.70),(x*1.4,-.18,.88),(x,-.14,1.02)],.013,'light')
    elif v==2:
        for x in [-.18,.18]:g.box((x,0,.85),(.055,.30,.30),'accent')
        for y in [-.14,.14]:g.box((0,y,.85),(.40,.05,.30),'body')
        for x,z in [(-.10,1.12),(0,1.17),(.1,1.10)]:g.crystal((x,0,.85),(x,0,z),.065,'glow')
    elif v==3:g.bell((0,0,.87),.33)
    elif v==4:
        g.gear((0,0,.85),.28,8,'accent',.10)
        g.box((-.31,0,.86),(.13,.18,.20),'steel');g.box((.31,0,.86),(.13,.18,.20),'steel')
    elif v==5:
        g.line([(-.19,0,.68),(-.19,0,1.07),(.19,0,1.07),(.19,0,.68)],.03,'accent')
        g.crystal((0,0,.63),(0,0,1.02),.18,'glow')
    elif v==6:
        g.plate([(-.32,.70),(.34,.7),(.38,.81),(.20,.9),(.20,1.04),(-.21,1.04),(-.24,.92),(-.40,.89)],y=-.12,thick=.24)
        for x in [-.11,0,.11]:g.box((x,-.132,.87),(.037,.018,.20),'glow')
    else:
        for s in [-1,1]:
            g.box((s*.24,0,.88),(.19,.24,.32),'body')
            g.box((s*.25,-.13,.88),(.13,.02,.18),'accent')
        g.tube((-.25,0,.87),(.25,0,.87),.066,.066,'steel')
        g.ring((0,0,.88),.12,.025,'glow')


def armor(g,v):
    # Canonical torso is .42 wide, .50 tall and .27 deep; front=-Y.
    g.rings([(0,0,-.24,.17,.115),(0,0,-.06,.19,.13),(0,0,.18,.20,.135)],'leather',None,12)
    g.ring((0,0,.17),.13,.022,'accent',normal=(0,0,1),n=24)
    if v==0:
        g.plate([(-.16,-.2),(.16,-.2),(.18,.17),(-.17,.17)],y=-.145,thick=.025)
        g.box((0,-.17,-.04),(.16,.018,.065),'dark')
        for x in [-.135,.135]:
            for z in [-.17,.14]:g.rivet((x,-.17,z),.012)
        g.plate([(-.16,-.18),(.16,-.18),(.19,-.28),(-.18,-.28)],y=-.14,thick=.015,rgb='dark')
    elif v==1:
        for j in range(4):
            for i in range(5):
                x=(i-2)*.074;z=.15-j*.105
                g.leaf((x,-.15,z+.05),(x+.012,-.155,z-.07),.045,'body',.025)
        g.ball((.22,0,.18),(.09,.11,.12),'wood',10,7)
    elif v==2:
        g.plate([(-.13,-.23),(.13,-.23),(.17,.17),(-.17,.17)],y=-.145,thick=.025)
        for z in [-.12,-.03,.06]:g.box((0,-.177,z),(.22,.014,.022),'dark')
        for x in [-.23,.23]:g.ball((x,0,.2),(.14,.15,.055),'accent')
    elif v==3:
        g.plate([(-.13,-.23),(.13,-.23),(.17,.11),(.10,.24),(-.10,.24),(-.17,.11)],y=-.15,thick=.038)
        g.box((0,-.2,.025),(.035,.022,.35),'accent');g.box((0,-.2,.04),(.27,.022,.035),'accent')
        g.plate([(-.19,.16),(-.10,.16),(.18,-.25),(.06,-.28)],y=-.217,thick=.014,rgb='dark')
    elif v==4:
        for j in range(3):
            z=.15-j*.135
            g.plate([(-.19,z),(-.13,z+.055),(.13,z+.055),(.19,z),(.13,z-.12),(0,z-.16),(-.13,z-.12)],y=-.15-j*.008,thick=.03)
            g.line([(-.17,-.19-j*.008,z),(.0,-.2-j*.008,z-.06),(.17,-.19-j*.008,z)],.012,'accent')
    elif v==5:
        for x in [-.1,0,.1]:
            for z in [-.15,-.04,.07,.18]:
                g.box((x,-.145,z),(.09,.045,.095),'body')
                g.line([(x-.038,-.174,z+.04),(x+.038,-.174,z+.04)],.005,'steel')
        for i in range(12):
            a=i*P/6;g.ball((.19*math.cos(a),.13*math.sin(a),.19),(.048,.035,.046),'cream',10,5)
    elif v==6:
        g.ball((0,-.12,0),(.19,.09,.23),'body')
        for x in [-.23,.23]:g.ball((x,-.025,.18),(.13,.14,.075),'dark');g.box((x,-.16,.17),(.17,.035,.11),'accent')
        for z in [-.10,0,.10]:g.box((0,-.22,z),(.2,.018,.028),'glow')
    else:
        g.box((0,-.14,0),(.31,.08,.39),'dark')
        for x in [-.15,-.075,.075,.15]:g.line([(x,-.20,-.2),(x*1.13,-.215,.08),(x,-.18,.22)],.015,'accent')
        g.ball((-.032,-.23,.04),(.07,.045,.08),'red');g.ball((.032,-.23,.04),(.07,.045,.08),'red')
        g.plate([(-.09,.04),(.09,.04),(0,-.10)],y=-.24,thick=.04,rgb='glow')


def shield(g,v):
    if v==0:
        g.disc((0,0,0),.25,.08,'body');g.ring((0,-.008,0),.25,.02,'steel',n=40)
        g.ball((0,-.04,0),(.07,.065,.07),'accent')
        g.line([(-.18,-.01,.12),(-.14,-.026,.04),(-.19,-.01,-.05)],.009,'dark')
    elif v==1:
        g.disc((0,0,0),.235,.065,'wood');g.ring((0,-.008,0),.23,.025,'accent')
        for j in range(4):
            for i in range(4):
                x=(i-1.5)*.093;z=(j-1.5)*.093
                if x*x+z*z<.037:g.leaf((x,-.06,z+.05),(x,-.065,z-.055),.058)
    elif v==2:
        p=[(0,-.34),(.23,.04),(.18,.25),(0,.33),(-.18,.25),(-.23,.04)]
        g.plate(p,y=-.02,thick=.09)
        for s in [-1,1]:g.plate([(s*.10,.02),(s*.31,.22),(s*.25,.36),(s*.17,.20)],y=-.08,thick=.06,rgb='accent')
        g.crystal((0,-.12,-.14),(0,-.12,.20),.04,'glow')
    elif v==3:
        g.plate([(-.08,-.32),(.08,-.32),(.08,-.08),(.25,-.08),(.25,.10),(.08,.10),(.08,.31),(-.08,.31),(-.08,.10),(-.25,.10),(-.25,-.08),(-.08,-.08)],y=-.025,thick=.09)
        g.disc((0,-.07,0),.09,.02,'accent',8)
        for x,z in [(-.19,.02),(.19,.02),(0,.25),(0,-.24)]:g.rivet((x,-.055,z),.018)
    elif v==4:
        pts=[]
        for a in [P*.35+k*P*1.3/24 for k in range(25)]:pts.append((math.cos(a)*.28,math.sin(a)*.30))
        for a in [P*1.65-k*P*1.3/24 for k in range(25)]:pts.append((.075+math.cos(a)*.15,math.sin(a)*.19))
        g.plate(pts,y=-.03,thick=.07);g.box((0,-.06,0),(.45,.04,.058),'accent')
    elif v==5:
        g.plate([(math.cos(i*P/3)*.28,math.sin(i*P/3)*.30) for i in range(6)],y=-.03,thick=.075,rgb='body')
        for i in range(3):
            a=i*2*P/3;g.line([(0,-.08,0),(math.cos(a)*.24,-.08,math.sin(a)*.26)],.016,'steel')
        g.disc((0,-.07,0),.055,.015,'glow',6)
    elif v==6:
        p=[(-.20,-.30),(.18,-.30),(.24,.1),(.13,.33),(-.22,.28),(-.25,-.11)]
        g.plate(p,y=-.03,thick=.12)
        g.box((0,-.10,0),(.065,.025,.40),'dark');g.box((0,-.117,0),(.032,.01,.33),'glow')
        for x,z in [(-.16,.23),(.12,.24),(-.16,-.22),(.13,-.23)]:g.rivet((x,-.065,z),.018)
    else:g.gear((0,0,0),.28,8,'accent',.07);g.disc((.04,-.06,.03),.08,.09,'body');g.disc((.04,-.075,.03),.045,.02,'glow')


def boots(g,v):
    g.box((0,-.035,-.073),(.17,.31,.045),'dark')
    g.ball((0,-.055,-.02),(.085,.155,.066),'leather',16,7)
    g.rings([(0,.025,-.07,.073,.075),(0,.025,.09,.071,.068),(0,.025,.15,.083,.075)],'body',None,16)
    g.ring((0,.025,.145),.078,.017,'accent',normal=(0,0,1),n=24)
    for i in range(4):g.line([(-.045,-.052,.02+i*.026),(.045,-.052,.03+i*.026)],.006,'light')
    if v==0:
        g.box((-.035,-.16,-.013),(.065,.025,.058),'body');g.box((.043,-.15,-.015),(.035,.022,.04),'steel')
    elif v==1:
        for s in [-1,1]:g.leaf((s*.06,0,.10),(s*.10,.02,.24),.052)
        g.leaf((0,-.12,-.01),(0,-.23,0),.06,'body')
    elif v==2:
        for s in [-1,1]:g.panel([(s*.07,.03,.04),(s*.15,.06,.25),(s*.08,-.06,.14)],(s*.012,0,0),'accent')
    elif v==3:
        g.line([(0,-.12,-.01),(0,-.21,.01),(0,-.23,.08)], [.06,.035,.005],'body');g.bell((0,.11,-.015),.045)
    elif v==4:
        for x in [-.09,-.045,0,.045,.09]:g.line([(x,-.2,-.07),(x,.14,-.07)],.022,'wood')
        for z in [.03,.075,.12]:g.ring((0,.025,z),.079,.007,'accent',normal=(0,0,1),n=16)
    elif v==5:
        for i in range(10):
            a=i*P/5;g.ball((math.cos(a)*.078,.025+math.sin(a)*.07,.15),(.028,.025,.035),'cream',8,5)
        for x in [-.06,.06]:
            for y in [-.14,.09]:g.crystal((x,y,-.085),(x,y,-.15),.025,'steel')
    elif v==6:
        for z in [-.06,-.02,.02,.06]:g.box((0,.088,z),(.14,.06,.018),'red')
        for s in [-1,1]:g.tube((s*.07,.10,.04),(s*.12,.13,.08),.022,.026,'accent')
    else:
        for z in [-.05,.02,.09]:g.box((0,-.025,z),(.185,.09,.025),'accent')
        g.ring((.09,.025,.04),.067,.016,'accent',normal=(1,0,0),n=24)
        g.ball((.10,.025,.04),(.015,.035,.035),'glow')


def helmet(g,v):
    g.rings([(0,0,-.09,.17,.16),(0,0,.04,.17,.16),(0,0,.12,.13,.12),(0,0,.16,.015,.015)],'body',None,24)
    g.ring((0,0,-.075),.17,.018,'accent',normal=(0,0,1),n=32)
    if v==0:
        g.line([(.13,0,-.01),(.25,0,.04),(.27,0,.10)], [.06,.055,.04],'body')
        g.ring((-.16,0,.02),.08,.018,'accent',normal=(0,1,0),n=24)
        g.box((0,0,.18),(.06,.05,.04),'dark')
    elif v==1:
        for i in range(12):
            a=i*P/6;g.line([(.165*math.cos(a),.155*math.sin(a),-.06),(.15*math.cos(a),.14*math.sin(a),.06),(.04*math.cos(a),.04*math.sin(a),.17)],.012,'wood')
        g.line([(0,0,.14),(.02,0,.24),(.07,0,.25)],.021,'wood')
    elif v==2:
        g.tube((0,0,-.065),(0,0,-.045),.285,.27,'accent',n=32)
        for x in [-.08,0,.08]:g.box((x,-.148,.02),(.023,.018,.065),'dark')
    elif v==3:
        g.rings([(0,0,-.14,.215,.195),(0,0,-.10,.19,.17),(0,0,.08,.14,.13)],'body',None,24)
        for x in [-.06,.06]:g.box((x,-.176,-.04),(.024,.015,.105),'dark')
        g.ring((0,0,-.14),.21,.015,'accent',normal=(0,0,1),n=32)
    elif v==4:
        for i in range(5):
            a=i*2*P/5;g.leaf((.07*math.cos(a),.07*math.sin(a),.04),(.21*math.cos(a),.21*math.sin(a),.23),.07)
        for x in [-.10,-.05,0,.05,.10]:g.line([(x,-.16,-.13),(x,-.18,.04)],.009,'accent')
    elif v==5:
        for i in range(12):
            a=i*P/6;g.ball((.168*math.cos(a),.16*math.sin(a),-.04),(.035,.035,.04),'cream',10,5)
        for s in [-1,1]:g.line([(s*.13,0,.06),(s*.25,.01,.12),(s*.28,.04,.23),(s*.19,.05,.27)], [.055,.048,.03,.002],'cream')
    elif v==6:
        g.box((0,-.14,-.015),(.31,.075,.27),'body');g.box((0,-.185,.04),(.20,.012,.055),'dark');g.box((0,-.195,.04),(.15,.01,.025),'glow')
        g.line([(.11,.03,.10),(.11,.03,.23),(.19,.03,.28)],.035,'dark')
    else:
        g.disc((.055,-.18,.035),.10,.07,'accent');g.disc((.055,-.193,.035),.075,.01,'glow')
        g.ring((.055,-.202,.035),.077,.009,'steel',n=24)
        for s in [-1,1]:g.line([(s*.14,0,.03),(s*.21,0,.12),(s*.17,0,.19)],.016,'accent')


def ring(g,v):
    g.ring((0,0,0),.15,.032,'accent',normal=(0,1,0),n=40)
    if v==0:
        g.ring((0,-.028,0),.15,.014,'body',n=40)
        g.line([(-.04,-.06,.15),(.02,-.035,.18),(.06,-.065,.13)],.023,'steel')
    elif v==1:
        for j in [-1,1]:g.ring((0,j*.02,0),.15,.015,'wood',n=36)
        g.ball((0,0,.18),(.075,.055,.10),'body');g.line([(-.045,-.06,.13),(0,-.075,.24),(.045,-.06,.15)],.009,'light')
    elif v==2:
        pts=[(.12,0,.06),(.18,0,.13),(.17,0,.24),(.08,0,.30),(-.01,0,.24)]
        g.line(pts,[.035,.032,.028,.021,.005],'accent')
        for x in [-.07,.05]:g.crystal((x,0,.14),(x-.08,0,.23),.043,'glow')
    elif v==3:
        g.tube((0,0,.13),(0,0,.22),.09,.11,'body',n=8)
        g.plate([(-.04,.15),(.04,.15),(.025,.20),(-.025,.20)],y=-.095,thick=.012,rgb='accent')
    elif v==4:
        g.ring((0,-.035,.015),.145,.043,'body',n=32,start=-P*.2,end=P*1.6)
        g.ball((-.11,-.045,.13),(.05,.04,.05),'red')
    elif v==5:
        for i in range(6):
            a=i*P/3;end=(math.cos(a)*.14,-.02,.19+math.sin(a)*.14)
            g.line([(0,-.02,.19),end],.012,'steel')
            mid=Vector(end)*.80+Vector((0,-.004,.19*.20))
            for side in [-1,1]:g.line([mid,Vector(end)+Vector((math.cos(a+side*.9)*.045,0,math.sin(a+side*.9)*.045))],.009,'steel')
        g.ball((0,-.02,.19),(.035,.025,.035),'glow')
    elif v==6:
        g.ring((0,0,.005),.15,.045,'dark',n=32)
        g.tube((0,0,.13),(0,0,.22),.065,.10,'body',n=12);g.ring((0,0,.22),.1,.015,'accent',normal=(0,0,1),n=20)
        g.ball((0,0,.23),(.07,.06,.025),'glow')
    else:
        for y in [-.04,.04]:g.ring((0,y,0),.15,.018,'accent',n=32)
        for x in [-.035,.035]:g.ball((x,-.01,.19),(.048,.035,.055),'red')
        g.plate([(-.076,.18),(.076,.18),(0,.09)],y=-.045,thick=.07,rgb='red')
        for s in [-1,1]:g.line([(s*.10,0,.13),(s*.12,0,.26),(s*.17,0,.26)],.016,'steel')


def necklace(g,v):
    # Deliberately larger authoring size for readable jewelry icons; runtime scales it.
    g.ring((0,0,.19),.20,.013,'wood' if v in [0,1,4] else 'accent',n=40)
    g.ring((0,0,-.03),.035,.008,'accent',n=16)
    if v==0:
        g.ring((0,0,-.18),.125,.035,'body',n=32);g.ring((0,-.036,-.18),.125,.008,'steel',n=32)
        g.disc((0,-.014,-.18),.062,.03,'accent');g.disc((0,-.029,-.18),.023,.01,'dark')
    elif v==1:
        g.ball((0,0,-.16),(.085,.065,.13),'wood');g.ball((0,0,-.07),(.095,.074,.04),'body')
        g.disc((0,-.062,-.15),.02,.006,'dark');g.leaf((0,0,.15),(.14,0,.10),.05)
    elif v==2:
        for z in [-.07,-.29]:g.disc((0,0,z),.10,.04,'accent',3)
        for x in [-.08,.08]:g.line([(x,0,-.28),(x,0,-.06)],.012,'accent')
        g.tube((0,0,-.26),(0,0,-.17),.063,.008,'glow',n=12);g.tube((0,0,-.17),(0,0,-.08),.008,.063,'glow',n=12)
    elif v==3:g.bell((0,0,-.17),.17)
    elif v==4:
        for i in range(5):
            a=i*2*P/5;g.leaf((0,0,-.16),(math.cos(a)*.15,0,-.16+math.sin(a)*.15),.05,'body')
        g.ball((0,-.035,-.16),(.07,.03,.07),'accent');g.disc((0,-.068,-.16),.024,.008,'dark')
    elif v==5:
        g.crystal((0,0,-.08),(0,0,-.34),.085,'glow');g.ball((0,0,-.08),(.09,.07,.045),'steel',8,5)
    elif v==6:
        for x in [-.04,.04]:g.ball((x,0,-.14),(.067,.05,.075),'red')
        g.plate([(-.11,-.14),(.11,-.14),(0,-.30)],y=-.035,thick=.07,rgb='red')
        for z in [-.11,-.15,-.19]:g.box((0,-.057,z),(.13,.016,.012),'accent')
        for s in [-1,1]:g.line([(s*.07,0,-.12),(s*.12,0,-.04),(s*.15,0,-.04)],.018,'accent')
    else:
        g.gear((0,0,-.18),.16,6,'accent',.045)
        g.plate([(0,-.02),(.035,-.18),(0,-.32),(-.035,-.18)],y=-.04,thick=.02,rgb='glow')


BUILDERS=dict(sword=sword,bow=bow,staff=staff,spear=spear,mace=mace,armor=armor,shield=shield,boots=boots,helmet=helmet,ring=ring,necklace=necklace)


def lights(scene):
    world=bpy.data.worlds.new('Slate studio ambient');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.46,.55,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.42
    scene.world=world
    for name,pos,power,col,size in [('Warm key',(-3,-4,5),550,(1,.82,.60),4),('Cool fill',(3,-2,2),400,(.54,.82,1),3),('Gold rim',(1,3,4),700,(1,.68,.32),3)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=col;data.shape='DISK';data.size=size
        ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=pos
        ob.rotation_euler=(Vector((0,0,.3))-ob.location).to_track_quat('-Z','Y').to_euler()
    camdata=bpy.data.cameras.new('Catalog Camera');cam=bpy.data.objects.new('Catalog Camera',camdata)
    scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.lens=55
    return cam


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    scene=bpy.context.scene
    try:scene.render.engine='BLENDER_EEVEE_NEXT'
    except (TypeError,ValueError):scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=384;scene.render.resolution_y=384
    scene.render.resolution_percentage=100;scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.render.image_settings.color_depth='8';scene.render.image_settings.compression=75
    scene.view_settings.view_transform='AgX'
    try:scene.view_settings.look='AgX - Medium High Contrast'
    except TypeError:pass
    eevee=getattr(scene,'eevee',None)
    if eevee and hasattr(eevee,'taa_render_samples'):eevee.taa_render_samples=48
    mats=[material('Enamel',.32,.45),material('Brass edge',.28,.70),material('Worn steel',.30,.74),
          material('Dark recessed iron',.50,.35),material('Warm timber',.70),material('Leather grip',.72),
          material('Ivory gold paint',.42,.28),material('Luminous inset',.25,.30,.35),
          material('Red sign enamel',.4,.25),material('Canvas and fur',.85)]
    return scene,mats,lights(scene)


def render_icon(obj,row,scene,cam):
    obj.hide_render=False
    bpy.context.view_layer.update()
    corners=[obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo=Vector(tuple(min(p[i] for p in corners) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in corners) for i in range(3)))
    center=(lo+hi)*.5;extent=max((hi-lo).x,(hi-lo).z,(hi-lo).y)
    cam.location=center+Vector((2.4,-6,2.2)).normalized()*max(extent*5,2)
    rot=(center-cam.location).to_track_quat('-Z','Y')
    if row['kind'] in ('sword','spear','staff','mace'):rot=rot @ Quaternion((0,0,1),-.31)
    cam.rotation_euler=rot.to_euler()
    # Fit the projected bounds including camera pitch and icon roll. Using only
    # the largest world axis can crop a thick apron or a wide mechanical hat.
    projected=[rot.inverted() @ (p-center) for p in corners]
    span=max(max(p[i] for p in projected)-min(p[i] for p in projected) for i in (0,1))
    cam.data.ortho_scale=span*1.18
    scene.render.filepath=str(ICONS/('item_%03d.png'%row['id']))
    bpy.ops.render.render(write_still=True)
    obj.hide_render=True


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--ids',default='all');parser.add_argument('--no-render',action='store_true');parser.add_argument('--render-only',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    rows=json.loads((ROOT/'game/data/item_catalog.json').read_text(encoding='utf-8'))
    selected=set(range(88)) if args.ids=='all' else {int(x) for x in args.ids.split(',')}
    priority=[0,1,29,52,58,64,70,76,82]
    rows=sorted([r for r in rows if r['id'] in selected],key=lambda r:(0,priority.index(r['id'])) if r['id'] in priority else (1,r['id']))
    scene,mats,cam=setup();manifest=[];objects=[]
    for row in rows:
        g=Item(row,mats);BUILDERS[row['kind']](g,row['visual']['variant']);obj=g.build_mesh()
        objects.append((obj,row));obj.hide_render=True
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        if not args.render_only:
            bpy.ops.export_scene.gltf(filepath=str(OUT/('item_%03d.glb'%row['id'])),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
        deps=bpy.context.evaluated_depsgraph_get();evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        manifest.append(dict(id=row['id'],kind=row['kind'],shape=row['visual']['shape'],feature=row['visual']['feature'],triangles=len(mesh.loop_triangles),dimensions=list(obj.dimensions),icon='res://assets/ui/items/item_%03d.png'%row['id'],model='res://assets/models/items/item_%03d.glb'%row['id']))
        evaluated.to_mesh_clear()
        print('EXPORTED_ITEM',row['id'],row['kind'],flush=True)
    filename='items_library.blend' if len(rows)==88 else 'items_sample.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/filename))
    (SOURCE/('item_manifest.json' if len(rows)==88 else 'sample_manifest.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    if not args.no_render:
        for obj,row in objects:
            render_icon(obj,row,scene,cam)
            print('RENDERED_ITEM',row['id'],flush=True)
    print('ITEM_ART_COMPLETE',len(rows),flush=True)


if __name__=='__main__':main()
