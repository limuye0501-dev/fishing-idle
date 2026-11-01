import bpy,math,sys
bpy.ops.wm.read_factory_settings(use_empty=True)
out=sys.argv[-1]
# 网兜：上口为环（半径0.75，z=0），下垂成袋（深1.3）
bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=18,radius=0.75)
o=bpy.context.object;o.name='NetBag'
me=o.data
import bmesh
bm=bmesh.new();bm.from_mesh(me)
for v in [v for v in bm.verts if v.co.z>0.001]: bm.verts.remove(v)
for v in bm.verts:
  v.co.z*=1.7; v.co.x*=1+0.15*(v.co.z/1.3); v.co.y*=1+0.15*(v.co.z/1.3)
orig=set(bm.edges)
bmesh.ops.poke(bm,faces=[f for f in bm.faces])
bmesh.ops.dissolve_edges(bm,edges=[e for e in orig if not e.is_boundary and e.is_valid],use_verts=False)
import random
random.seed(3)
for v in bm.verts:
  if v.co.z<-0.05: v.co.x+=random.uniform(-.02,.02);v.co.y+=random.uniform(-.02,.02)
bm.to_mesh(me);bm.free()
w=o.modifiers.new('w','WIREFRAME');w.thickness=0.016;w.use_even_offset=True
bpy.ops.object.modifier_apply(modifier='w')
bpy.ops.object.shade_smooth()
m=bpy.data.materials.new('NetRope');m.use_nodes=True;b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=(0.42,0.28,0.15,1);b.inputs['Roughness'].default_value=0.85
me.materials.append(m)
# 口部粗绳环
bpy.ops.mesh.primitive_torus_add(major_radius=0.76,minor_radius=0.045,major_segments=40,minor_segments=8)
r=bpy.context.object;r.name='NetRim'
m2=bpy.data.materials.new('Rim');m2.use_nodes=True;m2.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(0.55,0.38,0.2,1)
r.data.materials.append(m2)
print('TRIS',sum(len(p.vertices)-2 for ob in bpy.data.objects for p in ob.data.polygons))
bpy.ops.wm.usd_export(filepath=out,export_materials=True,generate_preview_surface=True,convert_orientation=True,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',export_normals=True,export_animation=False)
