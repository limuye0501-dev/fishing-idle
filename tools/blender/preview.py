# 预览渲染：blender -b file.blend -P preview.py -- out.png [captain.blend]
import bpy, sys, math, os
from mathutils import Vector, Euler
args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
sc = bpy.context.scene
if len(args) > 1:
    with bpy.data.libraries.load(args[1]) as (src, dst): dst.objects = src.objects
    for o in dst.objects:
        if o is None: continue
        sc.collection.objects.link(o)
        if o.parent is None:
            o.location = (2.1, -0.75, 1.0 + o.location.z); o.rotation_euler = (0, 0, -0.5); o.scale = (1.5, 1.5, 1.5)
# 整船转向，露出右舷
for o in list(sc.objects):
    if o.parent is None and o.type in ('MESH', 'EMPTY', 'CURVE'):
        m = o.matrix_world.copy()
        o.matrix_world = __import__('mathutils').Matrix.Rotation(-0.42, 4, 'Z') @ m
# 海
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
sea = bpy.context.object
sm = bpy.data.materials.new("sea"); sm.use_nodes = True
b = sm.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.09, 0.50, 0.52, 1); b.inputs["Roughness"].default_value = 0.08
nt = sm.node_tree
tex = nt.nodes.new("ShaderNodeTexNoise"); tex.inputs["Scale"].default_value = 3; tex.inputs["Detail"].default_value = 6
bmp = nt.nodes.new("ShaderNodeBump"); bmp.inputs["Strength"].default_value = 0.08
nt.links.new(tex.outputs["Fac"], bmp.inputs["Height"]); nt.links.new(bmp.outputs["Normal"], b.inputs["Normal"])
sea.data.materials.append(sm)
# 天空：粉金渐变
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
wn = w.node_tree; bg = wn.nodes["Background"]
sky = wn.nodes.new("ShaderNodeTexGradient"); sky.gradient_type = 'LINEAR'
ramp = wn.nodes.new("ShaderNodeValToRGB")
coord = wn.nodes.new("ShaderNodeTexCoord"); sep = wn.nodes.new("ShaderNodeSeparateXYZ")
wn.links.new(coord.outputs["Generated"], sep.inputs[0])
wn.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
ramp.color_ramp.elements[0].position = 0.5; ramp.color_ramp.elements[0].color = (1.0, 0.72, 0.50, 1)
ramp.color_ramp.elements[1].position = 0.75; ramp.color_ramp.elements[1].color = (0.80, 0.42, 0.55, 1)
wn.links.new(ramp.outputs["Color"], bg.inputs["Color"]); bg.inputs["Strength"].default_value = 1.0
# 太阳
bpy.ops.object.light_add(type='SUN'); sun = bpy.context.object
sun.data.energy = 3.2; sun.data.color = (1.0, 0.85, 0.7); sun.data.angle = math.radians(8)
sun.rotation_euler = Euler((math.radians(65), 0, math.radians(200)))
# 相机：与游戏一致（SceneKit (0.4,5.6,12.2) → Blender (0.4,-12.2,5.6)，俯角 0.30）
bpy.ops.object.camera_add(location=(0.4, -12.2, 5.6)); cam = bpy.context.object
cam.rotation_euler = Euler((math.pi / 2 - 0.30, 0, 0)); cam.data.sensor_fit = 'HORIZONTAL'; cam.data.angle = math.radians(48)
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.samples = 48; sc.cycles.use_denoising = True; sc.cycles.device = 'CPU'
sc.render.resolution_x = 645; sc.render.resolution_y = 1400
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium Low Contrast'
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
