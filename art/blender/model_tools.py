"""Geometry and rigging helpers shared by the three Garbage Hero character sources."""
from pathlib import Path
from math import pi, cos, sin, radians

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Euler

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parents[1] / "game/assets/models"
TAU = pi * 2


def linear(channel):
    c = channel / 255
    return c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def color(rgb):
    return tuple(linear(int(rgb[i:i + 2], 16)) for i in (0, 2, 4)) + (1,)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 60
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.preferences.filepaths.save_version = 0


def surface_material(size=2048):
    # A seamless weave modulates the palette very lightly at close camera distances.
    mat = bpy.data.materials.new('Painted enamel and canvas')
    mat.use_nodes = True
    mat.use_backface_culling = False
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = .75
    shader.inputs['Specular IOR Level'].default_value = .25
    paint = nodes.new('ShaderNodeVertexColor')
    paint.layer_name = 'Paint'
    paint.location = (-420, 100)
    grain = nodes.new('ShaderNodeTexImage')
    grain.location = (-420, -110)
    patch = np.arange(64)
    weave = 246 + 3 * np.cos(patch[None, :] * pi / 2) + 3 * np.cos(patch[:, None] * pi / 4)
    pixels = np.ones((size, size, 4), dtype=np.float32)
    pixels[:, :, :3] = np.tile(weave, (size // 64, size // 64))[:, :, None] / 255
    tex = bpy.data.images.new('Cloth and enamel grain', width=size, height=size, alpha=False)
    tex.pixels.foreach_set(pixels.ravel())
    tex.pack()
    grain.image = tex
    mix = nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MULTIPLY'
    mix.inputs[0].default_value = 1
    links.new(grain.outputs['Color'], mix.inputs[1])
    links.new(paint.outputs['Color'], mix.inputs[2])
    links.new(mix.outputs[0], shader.inputs['Base Color'])
    return mat


class Geometry:
    def __init__(self):
        self.verts, self.faces, self.weights, self.paint = [], [], [], []
        self.smooth_faces = set()

    def vertex(self, pos, rgb, bone):
        self.verts.append(tuple(pos))
        self.weights.append({bone: 1} if isinstance(bone, str) else bone)
        self.paint.append(color(rgb))
        return len(self.verts) - 1

    def loft(self, sections, rgb, bone, smooth=False):
        rings = []
        for k, points in enumerate(sections):
            tone = rgb[k] if isinstance(rgb, list) else rgb
            weights = bone[k] if isinstance(bone, list) else bone
            rings.append([self.vertex(p, tone, weights) for p in points])
        self.faces.append(tuple(reversed(rings[0])))
        for lo, hi in zip(rings, rings[1:]):
            for i in range(len(lo)):
                j = (i + 1) % len(lo)
                if smooth:
                    self.smooth_faces.add(len(self.faces))
                self.faces.append((lo[i], lo[j], hi[j], hi[i]))
        self.faces.append(tuple(rings[-1]))

    def rings(self, levels, rgb, bone, n=20):
        """level tuples are center x, y, z and two section radii."""
        sections = [[(x + rx * cos(TAU*i/n), y + ry * sin(TAU*i/n), z)
                     for i in range(n)] for x,y,z,rx,ry in levels]
        self.loft(sections, rgb, bone, smooth=True)

    def oval(self, pos, dims, rgb, bone, n=16, steps=9, tilt=None):
        axis = Euler(tilt).to_matrix() if tilt else None
        rings = []
        for j in range(steps + 1):
            lat = pi * ((j + .035)/(steps + .07) - .5)
            ring = []
            for i in range(n):
                a = TAU*i/n
                v = Vector((dims[0]*cos(lat)*cos(a),dims[1]*cos(lat)*sin(a),dims[2]*sin(lat)))
                ring.append(Vector(pos) + (axis @ v if axis else v))
            rings.append(ring)
        self.loft(rings, rgb, bone, smooth=True)

    def tube(self, a, b, r1, r2, rgb, bone, n=10):
        a, b = Vector(a), Vector(b)
        ray = (b-a).normalized()
        basis = ray.cross(Vector((0,0,1)) if abs(ray.z) < .95 else Vector((0,1,0))).normalized()
        cross = ray.cross(basis)
        self.loft([[p + r * (basis * cos(TAU*i/n) + cross * sin(TAU*i/n))
                    for i in range(n)] for p,r in [(a,r1), (b,r2)]], rgb, bone)

    def line(self, points, radii, rgb, bone, n=8):
        for a,b,r1,r2 in zip(points,points[1:],radii,radii[1:]):
            self.tube(a,b,r1,r2,rgb,bone,n)

    def panel(self, pts, depth, rgb, bone):
        self.loft([pts,[Vector(p)+Vector(depth) for p in pts]],rgb,bone)

    def ribbon(self, points, spreads, widths, rgb, bone, ridge=(0,-.015,0)):
        """Lance-shaped solid with a raised central facet for hair, leaves and cloth."""
        rings = []
        for p, spread, w in zip(points, spreads, widths):
            p, v, rid = Vector(p), Vector(spread).normalized()*w, Vector(ridge)
            rings.append([p-v, p+rid, p+v, p-rid*.3])
        self.loft(rings, rgb, bone)

    def build(self, name, rig, mat):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.verts, [], self.faces)
        for i in self.smooth_faces:
            mesh.polygons[i].use_smooth=True
        mesh.update()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        layer = mesh.color_attributes.new(name='Paint', type='FLOAT_COLOR', domain='POINT')
        layer.data.foreach_set('color', np.asarray(self.paint,dtype=np.float32).ravel())
        uv = mesh.uv_layers.new(name='GrainUV')
        for poly in mesh.polygons:
            nx, ny, nz = map(abs,poly.normal)
            for index in poly.loop_indices:
                x,y,z = mesh.vertices[mesh.loops[index].vertex_index].co
                uv.data[index].uv = (x,y) if nz > max(nx,ny) else (y,z) if nx>ny else (x,z)
        obj = bpy.data.objects.new(name,mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(mat)
        groups = {}
        for i, weights in enumerate(self.weights):
            for bone, amount in weights.items():
                if bone not in groups:
                    groups[bone] = obj.vertex_groups.new(name=bone)
                groups[bone].add([i],amount,'REPLACE')
        obj.parent = rig
        mod = obj.modifiers.new('Deform', 'ARMATURE')
        mod.object = rig
        return obj


def armature(name,bones):
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, head, tail, parent in bones:
        b = data.edit_bones.new(name)
        b.head,b.tail=head,tail
        if parent:
            b.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for b in rig.pose.bones:
        b.rotation_mode = 'QUATERNION'
    rig.rotation_euler[2]=pi  # authors look along -Y; Godot actors look along -Z
    return rig


def action(rig, name, keyed_poses):
    bpy.context.scene.frame_set(1)
    if rig.animation_data is None:
        rig.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    tracked = set().union(*(pose.keys() for _,pose in keyed_poses))
    previous = {}
    for frame,pose in keyed_poses:
        for key in tracked:
            b = rig.pose.bones[key]
            values = pose.get(key,(0,0,0))
            rest = b.bone.matrix_local.to_quaternion()
            rotation = Euler([radians(x) for x in values[:3]], 'XYZ').to_quaternion()
            q = rest.inverted() @ rotation @ rest
            if key in previous:
                q.make_compatible(previous[key])
            previous[key] = q.copy()
            b.rotation_quaternion = q
            b.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=key)
            if any(len(p.get(key,())) > 3 for _,p in keyed_poses):
                b.location = rest.inverted() @ Vector(values[3:] if len(values)>3 else (0,0,0))
                b.keyframe_insert(data_path='location',frame=frame,group=key)
    rig.animation_data.action = None
    for b in rig.pose.bones:
        b.location=(0,0,0)
        b.rotation_quaternion=(1,0,0,0)
    return act


def save(name,rig):
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / (name + '.blend')),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(MODEL_DIR / (name + '.glb')),export_format='GLB',
        export_animations=True,export_animation_mode='ACTIONS',export_anim_single_armature=True,
        export_def_bones=True,export_all_vertex_colors=True,
        export_vertex_color='ACTIVE',export_frame_range=False,export_frame_step=1,
        export_cameras=False,export_lights=False)
