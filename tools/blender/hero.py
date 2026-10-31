# 宣传/图标渲染：blender -b ship_baked.blend -P hero.py -- out.png W H camx camy camz [captain.blend]
# 透明背景渲染（海面不透明），之后用 tools/hero_composite.py 合成 AI 绘制的天空
import bpy, sys, math
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
a = sys.argv[sys.argv.index("--") + 1:]
out, W, H = a[0], int(a[1]), int(a[2]); cx, cy, cz = map(float, a[3:6])
sc = bpy.context.scene
if len(a) > 6:
    with bpy.data.libraries.load(a[6]) as (src, dst): dst.objects = src.objects
    for o in dst.objects:
        if o is None: continue
        sc.collection.objects.link(o)
        if o.parent is None:
            o.location = (2.1, -0.75, 1.0 + o.location.z); o.rotation_euler = (0, 0, float(__import__("os").environ.get("CAPROT", "-1.75"))); o.scale = (1.5, 1.5, 1.5)
bpy.context.view_layer.update()
for o in list(sc.objects):
    if o.parent is None and o.type in ('MESH', 'EMPTY', 'CURVE'):
        o.matrix_world = Matrix.Rotation(-0.42, 4, 'Z') @ o.matrix_world
# 海：粉蓝绿，近处通透
bpy.ops.mesh.primitive_plane_add(size=600); sea = bpy.context.object
m = bpy.data.materials.new("sea"); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.05, 0.42, 0.45, 1); b.inputs["Roughness"].default_value = 0.16
b.inputs["Coat Weight"].default_value = 0.0
nz = nt.nodes.new("ShaderNodeTexWave"); nz.wave_type = 'BANDS'; nz.inputs["Scale"].default_value = 0.35
nz.inputs["Distortion"].default_value = 14; nz.inputs["Detail"].default_value = 6
n2 = nt.nodes.new("ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = 1.4; n2.inputs["Detail"].default_value = 10
mx = nt.nodes.new("ShaderNodeMath"); mx.operation = "MULTIPLY_ADD"; mx.inputs[1].default_value = 0.45
tc = nt.nodes.new("ShaderNodeTexCoord")
nt.links.new(tc.outputs["Object"], nz.inputs["Vector"]); nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
nt.links.new(nz.outputs["Fac"], mx.inputs[0]); nt.links.new(n2.outputs["Fac"], mx.inputs[2])
bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = 0.45; bm.inputs["Distance"].default_value = 0.3
nt.links.new(mx.outputs[0], bm.inputs["Height"]); nt.links.new(bm.outputs["Normal"], b.inputs["Normal"])
sea.data.materials.append(m)
# 世界：粉金
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = (1.0, 0.70, 0.66, 1); bg.inputs["Strength"].default_value = 0.9
bpy.ops.object.light_add(type='SUN'); s = bpy.context.object
s.data.energy = 3.4; s.data.color = (1.0, 0.82, 0.66); s.data.angle = math.radians(10)
s.rotation_euler = (math.radians(68), 0, math.radians(160))
bpy.ops.object.camera_add(location=(cx, cy, cz)); cam = bpy.context.object
tgt = Vector((0.6, 0.0, 1.3)); d = tgt - cam.location
cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 35; sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.samples = 96; sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.render.film_transparent = True
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium Low Contrast'
hz = world_to_camera_view(sc, cam, cam.location + Vector((d.x, d.y, 0)).normalized() * 290)
open(out + ".hz", "w").write(str(1 - hz.y))
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
