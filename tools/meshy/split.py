import bpy,bmesh,sys
from mathutils import Vector
blend,out,obj,newname,expr,pivot=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=blend)
o=bpy.data.objects[obj];bpy.context.view_layer.objects.active=o;o.select_set(True)
bpy.ops.object.mode_set(mode='EDIT');bm=bmesh.from_edit_mesh(o.data)
for f in bm.faces:
  c=f.calc_center_median();x,y,z=c
  f.select=eval(expr)
n=sum(f.select for f in bm.faces);bmesh.update_edit_mesh(o.data)
bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
p=[x for x in bpy.context.selected_objects if x!=o][0];p.name=newname;p.data.name=newname
vs=[p.matrix_world@v.co for v in p.data.vertices];mn=Vector(map(min,*vs));mx=Vector(map(max,*vs))
c=(mn+mx)/2;piv={'top':Vector((c.x,c.y,mx.z)),'bottom':Vector((c.x,c.y,mn.z))}[pivot]
bpy.context.scene.cursor.location=piv;bpy.ops.object.select_all(action='DESELECT');p.select_set(True);bpy.context.view_layer.objects.active=p
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
print('SPLIT',newname,n,mn,mx,'pivot',piv)
bpy.ops.wm.save_as_mainfile(filepath=out.replace('.usdz','.blend'))
bpy.ops.wm.usd_export(filepath=out, export_materials=True, generate_preview_surface=True, export_textures=True,
  convert_orientation=True, export_global_forward_selection='NEGATIVE_Z', export_global_up_selection='Y',
  export_uvmaps=True, export_normals=True, overwrite_textures=True, export_animation=False, export_cameras=False, export_lights=False)
