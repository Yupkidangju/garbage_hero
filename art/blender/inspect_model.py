"""Render the source model from a fixed orthographic angle for visual review."""
import bpy
import sys
from math import pi, sin, cos, radians
from mathutils import Vector
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:]
name=args[0]
folder=Path(__file__).resolve().parent
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=6
scene.cycles.use_denoising=True
scene.render.resolution_x=640; scene.render.resolution_y=640; scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio environment')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.33,.38,.43,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65
scale={'hero':1.76,'wheelback':3.7,'trap_antler':2.65,'acorn_mouse':.76,'pine_wasp':1.12,
       'moss_boar':1.04,'husk_shield':.91,'drum_shroom':.79}[name]
focus=Vector((0,0,.74 if name=='pine_wasp' else scale*.50))
cam=bpy.data.cameras.new('Review')
obj=bpy.data.objects.new('Review',cam); scene.collection.objects.link(obj)
obj.location=focus+Vector((-.32,2.9,1.02))*scale
obj.rotation_euler=(focus-obj.location).to_track_quat('-Z','Y').to_euler()
cam.type='ORTHO'; cam.ortho_scale=scale*1.24
scene.camera=obj
for loc,brightness,size in [((-.9,1.7,2.5),110,2),((1.5,-1.8,1.6),100,1.5)]:
    light=bpy.data.lights.new('Softbox','AREA')
    light.energy=brightness*scale**2; light.shape='DISK'; light.size=size*scale
    node=bpy.data.objects.new('Softbox',light); scene.collection.objects.link(node)
    node.location=focus+Vector(loc)*scale
    node.rotation_euler=(focus-node.location).to_track_quat('-Z','Y').to_euler()
for mesh in bpy.data.objects:
    if mesh.name.startswith('Grade'): mesh.hide_render=True
scene.view_settings.view_transform='Standard'
def render(path):
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)


if len(args)==1:
    render(folder/(name+'_review.png'))
else:
    dest=Path(args[1])
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    scene.render.resolution_x=320; scene.render.resolution_y=320
    scene.cycles.samples=4
    cam.ortho_scale=scale*(1.60 if name in ['hero','pine_wasp'] else 1.27)
    def angle(deg):
        a=radians(deg)
        obj.location=focus+Vector((sin(a)*3,cos(a)*3,2.344))*scale
        obj.rotation_euler=(focus-obj.location).to_track_quat('-Z','Y').to_euler()
    rig.animation_data.action=bpy.data.actions['Idle']
    scene.frame_set(1)
    for i in range(8):
        angle(i*45)
        render(dest/(str(i)+'.png'))
    attack='Attack3' if name=='hero' else 'Attack'
    if name=='hero':
        poses=[(attack,1),(attack,16),(attack,21),(attack,37)]
    else:
        poses=[('Windup',1),('Windup',int(bpy.data.actions['Windup'].frame_range[1])),
               ('Attack',8),('Recover',int(bpy.data.actions['Recover'].frame_range[1]*.6))]
    angle(35)
    for i,(act,f) in enumerate(poses):
        rig.animation_data.action=bpy.data.actions[act]
        scene.frame_set(f)
        render(dest/(str(8+i)+'.png'))
