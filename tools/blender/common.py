import bpy, bmesh, math
from mathutils import Vector, Matrix

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

_mats = {}
def mat(name, color, rough=0.6, metal=0.0, emit=None):
    if name in _mats: return _mats[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(color), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(emit), 1); b.inputs["Emission Strength"].default_value = 1.0
    _mats[name] = m
    return m

def srgb(c):
    def f(x): return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return tuple(f(x) for x in c)

def link(o, coll=None):
    (coll or bpy.context.scene.collection).objects.link(o); return o

def mesh_obj(name, bm, m=None):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); link(o)
    if m: o.data.materials.append(m)
    return o

def smooth(o, angle=40):
    for p in o.data.polygons: p.use_smooth = True
    try:
        o.data.set_sharp_from_angle(angle=math.radians(angle))
    except Exception: pass
    return o

def bevel(o, w=0.03, seg=3):
    md = o.modifiers.new("bev", "BEVEL"); md.width = w; md.segments = seg; md.limit_method = 'ANGLE'
    smooth(o, 35); return o

def subsurf(o, lv=2):
    md = o.modifiers.new("sub", "SUBSURF"); md.levels = lv; md.render_levels = lv
    smooth(o, 180); return o

def box(name, size, loc, m, bev=0.03, rot=(0,0,0)):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    o = mesh_obj(name, bm, m); o.location = loc; o.rotation_euler = rot
    if bev: bevel(o, bev)
    return o

def cyl(name, r, h, loc, m, seg=32, bev=0.0, rot=(0,0,0), r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    o = mesh_obj(name, bm, m); o.location = loc; o.rotation_euler = rot
    if bev: bevel(o, bev, 2)
    else: smooth(o, 50)
    return o

def sphere(name, r, loc, m, scale=(1,1,1), seg=32):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg//2, radius=r)
    o = mesh_obj(name, bm, m); o.location = loc; o.scale = scale; smooth(o, 180); return o

def torus(name, R, r, loc, m, rot=(0,0,0), seg=48, mseg=16):
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = 2*math.pi*i/seg
        row = []
        for j in range(mseg):
            b = 2*math.pi*j/mseg
            p = Vector(((R + r*math.cos(b))*math.cos(a), (R + r*math.cos(b))*math.sin(a), r*math.sin(b)))
            row.append(bm.verts.new(p))
        verts.append(row)
    for i in range(seg):
        for j in range(mseg):
            bm.faces.new((verts[i][j], verts[(i+1)%seg][j], verts[(i+1)%seg][(j+1)%mseg], verts[i][(j+1)%mseg]))
    o = mesh_obj(name, bm, m); o.location = loc; o.rotation_euler = rot; smooth(o, 180); return o

def tube(name, pts, r, m, res=8):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 3; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts): p.co = (*q, 1)
    o = bpy.data.objects.new(name, cu); link(o); o.data.materials.append(m)
    return o

def smooth_tube(name, pts, r, m):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 4; cu.use_fill_caps = True; cu.resolution_u = 12
    sp = cu.splines.new('BEZIER'); sp.bezier_points.add(len(pts) - 1)
    for p, q in zip(sp.bezier_points, pts):
        p.co = q; p.handle_left_type = p.handle_right_type = 'AUTO'
    o = bpy.data.objects.new(name, cu); link(o); o.data.materials.append(m)
    return o

def sag(a, b, droop, n=10):
    a, b = Vector(a), Vector(b)
    return [tuple(a.lerp(b, t) - Vector((0, 0, droop * 4 * t * (1 - t)))) for t in [i/n for i in range(n+1)]]

def to_mesh_all(objs):
    out = []
    for o in objs:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = o; o.select_set(True)
        bpy.ops.object.convert(target='MESH')
        out.append(bpy.context.view_layer.objects.active)
    return out

def join(objs, name):
    objs = to_mesh_all(objs)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = name; o.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o
