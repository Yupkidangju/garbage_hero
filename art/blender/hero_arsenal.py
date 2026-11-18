"""Salvaged headlamp, leaf spring, spike and wrench builds for the repairer's rig."""
from math import cos, sin, pi, degrees
from mathutils import Euler, Matrix, Quaternion, Vector
from model_tools import Geometry, action


def equipment(rig, material, grip, along, width, normal):
    iron, chrome, brass, hide, teal = '526273', 'dfe5ce', 'f2bb62', '815337', '29998c'
    bone = 'WeaponGrip'
    def at(length, w=0, n=0):
        return grip + length*along + w*width + n*normal
    def shaft(g, a, b, radius, color):
        g.tube(at(a), at(b), radius, radius, color, bone, 10)
    def bind(g, start, end):
        shaft(g, start, end, .047, hide)
        for i in range(5):
            p = start + i*(end-start)/5
            shaft(g, p, p+.018, .050, brass)
    def store(g, name):
        obj = g.build('Loadout'+name, rig, material)
        obj.hide_render = True
        obj.hide_set(True)

    g = Geometry()
    shaft(g, -.16, .72, .04, iron)
    bind(g, -.13, .17)
    g.tube(at(.58), at(.81), .14, .19, iron, bone, 8)
    g.tube(at(.81), at(.93), .19, .11, chrome, bone, 8)
    for i in range(6):
        radial = width*cos(i*pi/3) + normal*sin(i*pi/3)
        arc = along.cross(radial)*.039
        g.panel([at(.54)+radial*.10-arc, at(.68)+radial*.24-arc,
                 at(.84)+radial*.24-arc, at(.94)+radial*.10-arc], arc*2,
                brass if i%2 else chrome, bone)
    shaft(g, .55, .60, .115, brass)
    store(g, 'Mace')

    g = Geometry()
    shaft(g, -.49, 1.08, .036, hide)
    bind(g, -.11, .17)
    shaft(g, 1.0, 1.11, .057, brass)
    shaft(g, -.51, -.44, .05, iron)
    g.ribbon([at(1.05),at(1.20),at(1.52)], [width]*3, [.047,.135,.001],
             [iron,chrome,chrome],bone,normal*.055)
    g.ribbon([at(.98),at(1.0,-.10),at(.86,-.17)], [width]*3, [.045,.037,.002],
             brass,bone,normal*.028)
    store(g, 'Spear')

    g = Geometry()
    shaft(g, -.43, .87, .041, hide)
    shaft(g, -.46, -.39, .058, brass)
    bind(g, -.1, .2)
    g.tube(at(.78),at(.89),.081,.12,iron,bone,8)
    for i in range(3):
        radial = width*cos(i*2*pi/3) + normal*sin(i*2*pi/3)
        g.line([at(.83),at(.97)+radial*.17,at(1.12)+radial*.15,at(1.18)+radial*.06],
               [.042,.036,.030,.022],brass,bone)
    g.tube(at(.91),at(1.04),.01,.118,'348da2',bone,6)
    g.tube(at(1.04),at(1.17),.118,.002,'95ffdf',bone,6)
    store(g, 'Staff')

    g = Geometry()
    nock = grip + Vector((0,.21,0))
    for sign in (-1,1):
        points = [grip + Vector((sign*x,y,sign*z)) for x,y,z in
                  [(0,0,0),(.025,-.045,.17),(.065,.01,.37),(.11,.20,.63),(.115,.21,.7)]]
        g.ribbon(points, [(1,0,0)]*5, [.035,.079,.065,.042,.022],
                 [hide,brass,teal,iron,brass],bone,(0,-.035,0))
        # String outer tips follow the limb, its inner end follows the animated nock.
        end = points[-1]
        across = Vector((.009,0,0))
        depth = Vector((0,.008,0))
        g.loft([[p+v for v in [across,depth,-across,-depth]] for p in [end,nock]],
               chrome,[bone,'BowNock'])
    g.tube(grip-Vector((0,0,.095)),grip+Vector((0,0,.095)),.047,.047,hide,bone)
    store(g, 'Bow')

    g = Geometry()
    center = Vector((.39,-.07,.86))
    shield_bone = 'Hand.L'
    def face(w,h,d):
        return center + Vector((d,w,h))
    rim = [(-.23,.17),(-.15,.29),(.15,.29),(.23,.17),(.20,-.08),(0,-.32),(-.20,-.08)]
    for scale, d, tone in [(1,0,brass),(.85,.017,teal)]:
        g.panel([face(w*scale,h*scale,d) for w,h in rim],(-.03,0,0),tone,shield_bone)
    g.oval(face(0,.012,.032),(.055,.088,.088),brass,shield_bone,12,7)
    for w,h in rim:
        g.oval(face(w*.92,h*.92,.017),(.013,.016,.016),chrome,shield_bone,8,4)
    store(g, 'Shield')


def aimed_pose(rig, trunk, grips):
    """Bake wrist and hand orientations for both hands into the same FK clips as the hero."""
    pose = dict(trunk)
    def relative(bone):
        head = rig.data.bones[bone].head_local
        angles = tuple(v*pi/180 for v in pose.get(bone,(0,0,0))[:3])
        pos = Vector(pose.get(bone,())[3:] or (0,0,0))
        return Matrix.Translation(head+pos) @ Euler(angles).to_matrix().to_4x4() @ Matrix.Translation(-head)
    torso = Matrix.Identity(4)
    for bone in ['Root','Pelvis','Spine','Chest']:
        torso = torso @ relative(bone)
    for side,(palm, orient) in grips.items():
        names = [key+'.'+side for key in ('UpperArm','Forearm','Hand')]
        arm, fore, hand = [rig.data.bones[key].head_local for key in names]
        parent = torso @ relative('Collar.'+side)
        shoulder = parent @ arm
        rest_palm = Vector((.338 if side=='L' else -.338,-.049,.765))
        wrist = Vector(palm) - orient @ (rest_palm-hand)
        aim = (wrist-shoulder).normalized()
        a,b = (fore-arm).length,(hand-fore).length
        dist = max(abs(a-b)+.0001,min((wrist-shoulder).length,a+b-.0001))
        elbow_out = Vector((.8 if side=='L' else -.8,.5,-1.0))
        pole = (elbow_out - aim*elbow_out.dot(aim)).normalized()
        length = (a*a+dist*dist-b*b)/(2*dist)
        elbow = shoulder+aim*length+pole*max(0,a*a-length*length)**.5
        q0 = (fore-arm).rotation_difference(elbow-shoulder)
        q1 = (q0 @ (hand-fore)).rotation_difference(shoulder+aim*dist-elbow) @ q0
        for name, rotation in zip(names,[parent.to_quaternion().inverted() @ q0,q0.inverted() @ q1,q1.inverted() @ orient]):
            pose[name] = tuple(degrees(v) for v in rotation.to_euler())
    return pose


def moves(rig, idle, shaft_axis):
    straight = Quaternion()
    up = Vector((0,0,1))
    forward = Vector((0,-1,0))
    def hands(body, right, angle, left, left_angle=straight):
        return aimed_pose(rig,body,{'R':(right,angle),'L':(left,left_angle)})
    draw = hands({'Chest':(2,0,-12)}, (-.17,-.43,1.14),straight,(-.17,-.02,1.14))
    draw['BowNock'] = (0,0,0,0,.2,0)
    loose = hands({'Chest':(-5,0,-9)}, (-.17,-.44,1.14),straight,(-.13,.02,1.16))
    loose['BowNock'] = (0,0,0,0,-.018,0)
    action(rig,'BowDraw',[(1,idle),(9,draw),(12,draw),(14,loose),(19,loose),(27,idle)])
    aim = shaft_axis.rotation_difference(forward)
    retract = hands({'Chest':(-6,0,-17)},(-.22,-.05,.99),aim,(-.11,-.24,1.01))
    thrust = hands({'Chest':(10,0,12)},(-.13,-.36,1.03),aim,(-.12,-.48,1.03))
    action(rig,'SpearThrust',[(1,idle),(9,retract),(12,thrust),(15,thrust),(22,retract),(31,idle)])
    vertical = shaft_axis.rotation_difference(up)
    gather = hands({'Chest':(-8,0,-8)},(-.18,-.20,1.14),vertical,(-.18,-.20,.99))
    release = hands({'Chest':(7,0,12)},(-.12,-.34,1.03),aim,(-.12,-.46,1.03))
    action(rig,'StaffCast',[(1,idle),(10,gather),(14,gather),(18,release),(25,release),(36,idle)])
    raised = {'Chest':(-16,0,-19),'UpperArm.R':(-147,4,-12),'Forearm.R':(-59,0,8),
              'UpperArm.L':(-39,0,18),'Forearm.L':(-60,0,0),'Thigh.L':(-15,0,0)}
    crush = {'Chest':(34,0,22),'UpperArm.R':(-28,3,18),'Forearm.R':(-9,0,0),
             'UpperArm.L':(11,0,-23),'Pelvis':(0,0,11,0,-.018,-.048),'Thigh.L':(-34,0,0),'Shin.L':(44,0,0)}
    action(rig,'MaceCrush',[(1,idle),(13,raised),(18,raised),(22,crush),(28,crush),(43,idle)])
    gather_shards = {'Chest':(-8,0,-38),'UpperArm.R':(-53,7,-33),'Forearm.R':(-85,0,-5),
                     'UpperArm.L':(-49,0,31),'Forearm.L':(-57,0,0)}
    fan = {'Chest':(12,0,33),'UpperArm.R':(-86,-20,37),'Forearm.R':(-9,0,8),
           'UpperArm.L':(-66,8,-32),'Forearm.L':(-17,0,-12),'Scarf':(-33,0,-22)}
    action(rig,'Volley',[(1,idle),(10,gather_shards),(13,fan),(18,fan),(31,idle)])
    coil = {'Chest':(23,0,0),'Pelvis':(0,0,0,0,0,-.07),'UpperArm.R':(-38,19,-28),
            'UpperArm.L':(-38,-19,28),'Forearm.R':(-81,0,0),'Forearm.L':(-81,0,0),
            'Thigh.L':(-25,0,0),'Thigh.R':(-25,0,0),'Shin.L':(34,0,0),'Shin.R':(34,0,0)}
    burst = {'Chest':(-14,0,0),'UpperArm.L':(-67,-29,-63),'UpperArm.R':(-67,29,63),
             'Forearm.L':(-14,0,0),'Forearm.R':(-14,0,0),'Scarf':(-39,0,-16)}
    action(rig,'Nova',[(1,idle),(15,coil),(19,coil),(22,burst),(31,burst),(47,idle)])
    start = {**coil,'Chest':(34,-5,-12),'Thigh.R':(-43,0,0),'Shin.R':(55,0,0)}
    drive = {**thrust,'Chest':(19,0,10),'Thigh.L':(-34,0,0),'Shin.L':(40,0,0),
             'Thigh.R':(37,0,0),'Scarf':(-60,0,0),'Apron':(-20,0,0)}
    action(rig,'Rush',[(1,idle),(7,start),(11,drive),(18,drive),(23,crush),(35,idle)])
