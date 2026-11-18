"""Measure grip attachment and the contact phase of the authored 5 m/s run cycle."""
from mathutils import Vector
import bpy
from mathutils import Matrix

scene=bpy.context.scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
hand=rig.pose.bones['Hand.R']
grip=rig.pose.bones['WeaponGrip']
bind_hand=hand.bone.matrix_local
reference=bind_hand.inverted() @ grip.bone.head_local
def use_action(a):
    rig.animation_data.action=None
    for bone in rig.pose.bones:
        bone.matrix_basis=Matrix.Identity(4)
    rig.animation_data.action=a

worst=0
for a in bpy.data.actions:
    use_action(a)
    for f in range(int(a.frame_range[0]),int(a.frame_range[1])+1):
        scene.frame_set(f)
        worst=max(worst,(hand.matrix@reference-grip.head).length)
assert worst<.02
print(f'Maximum hand-to-grip attachment displacement: {worst:.6f} m')

use_action(bpy.data.actions['Run'])
length=int(rig.animation_data.action.frame_range[1])-1
for side in ['L','R']:
    foot=rig.pose.bones['Foot.'+side]
    for label,ycoord in [('heel',.073),('toe',-.165)]:
        last=[]
        spans=[]
        minimum=99.
        for f in range(length*2):
            scene.frame_set(1+f%length)
            point=rig.matrix_world @ (foot.matrix @ (foot.bone.matrix_local.inverted() @
                Vector((foot.bone.head_local.x,ycoord,0))))
            minimum=min(minimum,point.z)
            if point.z<.02:
                last.append((f,point.y+f*5/60))
            elif last:
                if last[0][0]<length and len(last)>=2:
                    travel=max(p[1] for p in last)-min(p[1] for p in last)
                    spans.append((last[0][0]+1,last[-1][0]+1,round(travel,4)))
                last=[]
        print(f'{side} {label} contact intervals and travel (m): {spans}. Minimum height {minimum:.4f} m')
        assert spans and all(span[2]<=.05 for span in spans)
