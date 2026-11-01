import bpy,sys,math
from mathutils import Vector
blend,out,az=sys.argv[-3],sys.argv[-2],float(sys.argv[-1])
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE_NEXT'; sc.render.resolution_x=1024; sc.render.resolution_y=1024
w=bpy.data.worlds.new('w'); w.use_nodes=True; bg=w.node_tree.nodes['Background']; bg.inputs[0].default_value=(.93,.85,.8,1); bg.inputs[1].default_value=1.2; sc.world=w
sc.view_settings.view_transform='Standard'
o=[x for x in sc.objects if x.type=='MESH'][0]
bb=[o.matrix_world@Vector(v) for v in o.bound_box];mn=Vector(map(min,*bb));mx=Vector(map(max,*bb));c=(mn+mx)/2;r=(mx-mn).length
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c'));sc.collection.objects.link(cam);sc.camera=cam;cam.data.lens=50
sun=bpy.data.objects.new('s',bpy.data.lights.new('s','SUN'));sun.data.energy=2.5;sun.rotation_euler=(0.8,0.1,-0.6);sc.collection.objects.link(sun)
d=Vector((math.cos(math.radians(az)),math.sin(math.radians(az)),0.42)).normalized()
cam.location=c+d*r*1.55; cam.rotation_euler=(c-cam.location).to_track_quat('-Z','Y').to_euler()
sc.render.filepath=out; bpy.ops.render.render(write_still=True)
