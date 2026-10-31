# 烘焙船体 AO + 颜色到一张贴图，并导出 USDZ：blender -b -P bake_export.py -- ship.blend captain.blend outdir
import bpy, sys, os, numpy as np
args = sys.argv[sys.argv.index("--") + 1:]
ship_blend, cap_blend, out = args
RES = 2048

def export(path):
    bpy.ops.wm.usd_export(filepath=path, export_materials=True, generate_preview_surface=True, export_textures=True,
                          convert_orientation=True, export_global_forward_selection='NEGATIVE_Z', export_global_up_selection='Y',
                          export_uvmaps=True, export_normals=True, evaluation_mode='RENDER', overwrite_textures=True,
                          export_animation=False, export_cameras=False, export_lights=False)

bpy.ops.wm.open_mainfile(filepath=ship_blend)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 64
ship = bpy.data.objects["ShipBody"]
bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active = ship; ship.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.002)
bpy.ops.object.mode_set(mode='OBJECT')

def bake(kind, name):
    img = bpy.data.images.new(name, RES, RES, alpha=False)
    for slot in ship.material_slots:
        nt = slot.material.node_tree
        n = nt.nodes.get("BAKE") or nt.nodes.new("ShaderNodeTexImage"); n.name = "BAKE"; n.image = img
        nt.nodes.active = n
    if kind == 'DIFFUSE':
        sc.render.bake.use_pass_direct = False; sc.render.bake.use_pass_indirect = False; sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 6
    bpy.ops.object.bake(type=kind)
    return img
alb = bake('DIFFUSE', "alb")
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0.0)); water = bpy.context.object
bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active = ship; ship.select_set(True)
sc.cycles.samples = 48
ao = bake('AO', "ao")
bpy.data.objects.remove(water)

A = np.array(alb.pixels[:]).reshape(RES, RES, 4)
O = np.array(ao.pixels[:]).reshape(RES, RES, 4)[..., :1]
O = np.clip(O, 0, 1) ** 0.8
warm = np.array([0.30, 0.16, 0.14, 1.0])
F = A * (0.45 + 0.55 * O) + warm * (1 - O) * 0.06
F[..., 3] = 1
tex = bpy.data.images.new("ShipBaked", RES, RES, alpha=False)
tex.pixels[:] = F.ravel()
os.makedirs(out, exist_ok=True)
tex.filepath_raw = os.path.join(out, "ShipBaked.png"); tex.file_format = 'PNG'; tex.save()

m = bpy.data.materials.new("ShipBakedM"); m.use_nodes = True; nt = m.node_tree
b = nt.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.62
t = nt.nodes.new("ShaderNodeTexImage"); t.image = tex
nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
ship.data.materials.clear(); ship.data.materials.append(m)
for o in list(bpy.data.objects):
    if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "ship_baked.blend"))
export(os.path.join(out, "Ship.usdz"))

bpy.ops.wm.open_mainfile(filepath=cap_blend)
for o in list(bpy.data.objects):
    if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o)
export(os.path.join(out, "Captain.usdz"))
print("DONE")
