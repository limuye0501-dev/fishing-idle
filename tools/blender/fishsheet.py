# 鱼模型总览图：blender -b -P fishsheet.py -- dir out.png [cols]
import bpy, sys, os, glob, math
a = sys.argv[sys.argv.index("--") + 1:]
d, out = a[0], a[1]; cols = int(a[2]) if len(a) > 2 else 7
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
files = sorted(glob.glob(os.path.join(d, "Fish_*.usdz")))
for i, f in enumerate(files):
    before = set(bpy.data.objects)
    bpy.ops.wm.usd_import(filepath=f)
    new = [o for o in bpy.data.objects if o not in before]
    r, c = divmod(i, cols)
    for o in new:
        if o.parent is None:
            o.location = (c * 2.6, 0, -r * 2.2)
            o.rotation_euler.z += -0.45; o.rotation_euler.x += 0.0
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.9, 0.95, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
bpy.ops.object.light_add(type='SUN', rotation=(0.6, 0.3, 0.8)); bpy.context.object.data.energy = 3.5
rows = math.ceil(len(files) / cols)
bpy.ops.object.camera_add(location=((cols - 1) * 1.3, -30, -(rows - 1) * 1.1 + 9.7), rotation=(math.radians(72), 0, 0))
cam = bpy.context.object; cam.data.type = 'ORTHO'; cam.data.ortho_scale = cols * 2.7
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.samples = 12; sc.cycles.use_denoising = True
sc.render.resolution_x = 1600; sc.render.resolution_y = int(1600 * rows * 2.2 / (cols * 2.6)) + 40
sc.view_settings.view_transform = 'AgX'
sc.render.filepath = out
try:
    bpy.ops.render.render(write_still=True)
except Exception as e:
    print("EEVEE failed", e); sc.render.engine = 'CYCLES'; sc.cycles.samples = 16; bpy.ops.render.render(write_still=True)
print("SHEET", len(files))
