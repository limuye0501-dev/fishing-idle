import bpy, math, sys
from mathutils import Euler
out = sys.argv[sys.argv.index("--") + 1]
sc = bpy.context.scene
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.9, 0.75, 0.7, 1)
bpy.ops.object.light_add(type='SUN'); s = bpy.context.object; s.data.energy = 3; s.rotation_euler = Euler((0.8, 0.2, 0.6))
bpy.ops.object.camera_add(location=(2.6, -0.9, 1.0)); c = bpy.context.object
c.rotation_euler = Euler((math.radians(85), 0, math.radians(70))); c.data.lens = 60; sc.camera = c
sc.render.engine = 'CYCLES'; sc.cycles.samples = 32; sc.render.resolution_x = 500; sc.render.resolution_y = 600
sc.view_settings.view_transform = 'AgX'; sc.render.filepath = out
bpy.ops.render.render(write_still=True)
