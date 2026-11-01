import bpy,bmesh,sys
from mathutils import Vector
out=sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=out.replace('Gull.usdz','Gull0.blend'))
o=bpy.data.objects['Body']
def sep(cond,name,piv):
  bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=o;o.select_set(True)
  bpy.ops.object.mode_set(mode='EDIT');bm=bmesh.from_edit_mesh(o.data)
  for f in bm.faces: c=f.calc_center_median(); f.select=cond(c)
  bmesh.update_edit_mesh(o.data);bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
  p=[x for x in bpy.context.selected_objects if x!=o][0];p.name=name;p.data.name=name
  bpy.context.scene.cursor.location=piv;bpy.ops.object.select_all(action='DESELECT');p.select_set(True);bpy.context.view_layer.objects.active=p
  bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
vs=[v.co for v in o.data.vertices if abs(v.co.y)<0.13];zc=sum(v.z for v in vs)/len(vs)
sep(lambda c:c.y>0.12,'WingL',Vector((0,0.12,zc+0.03)))
sep(lambda c:c.y<-0.12,'WingR',Vector((0,-0.12,zc+0.03)))
print('GULL',[(x.name,len(x.data.polygons)) for x in bpy.data.objects if x.type=='MESH'])
bpy.ops.wm.usd_export(filepath=out, export_materials=True, generate_preview_surface=True, export_textures=True,
  convert_orientation=True, export_global_forward_selection='NEGATIVE_Z', export_global_up_selection='Y',
  export_uvmaps=True, export_normals=True, overwrite_textures=True, export_animation=False)
