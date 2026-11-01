import bpy,sys,math,os
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
src,dst,rotz,axis,size,zmin,maxtri,name=sys.argv[sys.argv.index('--')+1:]
bpy.ops.import_scene.gltf(filepath=src)
o=[x for x in bpy.context.scene.objects if x.type=='MESH'][0]
for x in list(bpy.context.scene.objects):
  if x!=o: o.matrix_world=o.matrix_world.copy()
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
o.parent=None if o.parent is None else o.parent
mw=o.matrix_world.copy();o.parent=None;o.matrix_world=mw
for x in list(bpy.context.scene.objects):
  if x!=o: bpy.data.objects.remove(x)
from mathutils import Matrix
o.matrix_world=Matrix.Rotation(math.radians(float(rotz)),4,'Z')@o.matrix_world
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bb=[Vector(v) for v in o.bound_box];mn=Vector(map(min,*bb));mx=Vector(map(max,*bb))
s=float(size)/(mx-mn)['xyz'.index(axis)]
o.scale=(s,s,s);bpy.ops.object.transform_apply(scale=True)
bb=[Vector(v) for v in o.bound_box];mn=Vector(map(min,*bb));mx=Vector(map(max,*bb))
o.location=(-(mn.x+mx.x)/2,-(mn.y+mx.y)/2,float(zmin)-mn.z);bpy.ops.object.transform_apply(location=True)
t=sum(len(f.vertices)-2 for f in o.data.polygons)
if t>int(maxtri):
  m=o.modifiers.new('d','DECIMATE');m.ratio=int(maxtri)/t*0.98;bpy.ops.object.modifier_apply(modifier='d')
o.name=name;o.data.name=name
for im in bpy.data.images:
  T=int(os.environ.get('MAXTEX','2048'))
  if im.size[0]>T: im.scale(T,T)
  if im.size[0]>0:
    im.filepath_raw=os.path.join(os.path.dirname(dst),name+'_tex.jpg');im.file_format='JPEG';im.save();im.unpack(method='REMOVE') if im.packed_file else None
bb=[Vector(v) for v in o.bound_box]
print('OUT',name,Vector(map(min,*bb)),Vector(map(max,*bb)),sum(len(f.vertices)-2 for f in o.data.polygons),[(i.name,tuple(i.size)) for i in bpy.data.images])
bpy.ops.wm.save_as_mainfile(filepath=dst.replace('.usdz','.blend'))
bpy.ops.wm.usd_export(filepath=dst, export_materials=True, generate_preview_surface=True, export_textures=True,
  convert_orientation=True, export_global_forward_selection='NEGATIVE_Z', export_global_up_selection='Y',
  export_uvmaps=True, export_normals=True, overwrite_textures=True, export_animation=False, export_cameras=False, export_lights=False)
