# 近景检查渲染：blender -b file.blend -P closeup.py -- out.png
import bpy, sys, math
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
sc = bpy.context.scene
for o in list(sc.objects):
    if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o)
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (1.0, 0.75, 0.6, 1)
bpy.ops.object.light_add(type='SUN'); s = bpy.context.object; s.data.energy = 3; s.rotation_euler = (math.radians(55), 0, math.radians(-30)); s.data.color = (1, .85, .7)
bpy.ops.object.camera_add(location=(4.5, -7.5, 3.6)); cam = bpy.context.object
d = Vector((0.3, 0, 1.4)) - cam.location; cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler(); cam.data.lens = 35
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.samples = 32; sc.cycles.device = 'CPU'
sc.render.resolution_x = 1000; sc.render.resolution_y = 1000
sc.view_settings.view_transform = 'AgX'
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
