# Q 版小船长（面朝 +X）：blender -b -P captain.py -- out_dir
import sys, os, math, bpy, bmesh
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from mathutils import Vector
clear()
skin = mat("skin", (1.0, 0.86, 0.76), rough=0.7)
coat = mat("coat", (0.22, 0.55, 0.66), rough=0.75)
coatD = mat("coatD", (0.17, 0.44, 0.54), rough=0.75)
pants = mat("pants", (0.17, 0.21, 0.32), rough=0.8)
boots = mat("boots", (0.52, 0.33, 0.20), rough=0.6)
hair = mat("hair", (0.36, 0.22, 0.14), rough=0.7)
white = mat("capWhite", (0.98, 0.98, 0.96), rough=0.5)
navy = mat("capNavy", (0.13, 0.19, 0.32), rough=0.6)
visor = mat("visor", (0.08, 0.08, 0.11), rough=0.25)
gold = mat("gold", (0.97, 0.78, 0.38), rough=0.3, metal=0.8)
eye = mat("eye", (0.16, 0.10, 0.08), rough=0.15)
eyeHi = mat("eyeHi", (1, 1, 1), rough=0.1, emit=(0.6, 0.6, 0.6))
blush = mat("blush", (1.0, 0.64, 0.64), rough=0.9)
mouthM = mat("mouth", (0.62, 0.30, 0.26), rough=0.7)
shirt = mat("shirt", (0.97, 0.95, 0.90), rough=0.7)

def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None); link(e); e.location = loc
    if parent: e.parent = parent
    return e
def parent(objs, p):
    for o in objs:
        o.parent = p; o.location = o.location - p_world(p)
def p_world(p):
    v = Vector(p.location); q = p.parent
    while q: v += q.location; q = q.parent
    return v

root = empty("Captain", (0, 0, 0))
body = []
# 靴子、腿
for y in (-0.1, 0.1):
    b = sphere("boot", 0.09, (0.03, y, 0.06), boots, scale=(1.45, 1.0, 0.85)); body.append(b)
    body.append(cyl("bootTop", 0.075, 0.08, (0, y, 0.12), boots))
    body.append(cyl("leg", 0.068, 0.2, (0, y, 0.24), pants))
# 外套：锥形 + 细分
bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.24, radius2=0.155, depth=0.4)
c = mesh_obj("coat", bm, coat); c.location = (0, 0, 0.5); bevel(c, 0.04, 3); body.append(c)
body.append(torus("hem", 0.235, 0.025, (0, 0, 0.31), coatD))
# 衣襟、扣子、腰带
# body.append(box("lapel", (0.02, 0.06, 0.32), (0.205, 0, 0.5), shirt, bev=0.008, rot=(0, 0.2, 0)))
for k in range(3):
    body.append(sphere("btn", 0.022, (0.215 - k * 0.012, 0.055, 0.6 - k * 0.09), gold))
body.append(torus("belt", 0.205, 0.022, (0, 0, 0.4), boots))
body.append(box("buckle", (0.03, 0.07, 0.05), (0.215, 0, 0.4), gold, bev=0.01))
body.append(torus("collar", 0.13, 0.04, (0, 0, 0.69), shirt))
# 肩章
for y in (-0.17, 0.17):
    body.append(sphere("ep", 0.05, (0, y, 0.68), gold, scale=(1.2, 0.8, 0.4)))
for o in body: o.parent = root

# 手臂（ArmL 自然下垂，ArmR 挥手）
def arm(name, y, up):
    a = empty(name, (0, y, 0.66), root)
    sl = sphere("sleeve", 0.06, (0, 0, -0.14 if not up else 0.14), coat, scale=(1, 1, 2.5)); sl.parent = a
    sl.location = (0, 0, -0.14 if not up else 0.14)
    cu = torus("cuff", 0.055, 0.018, (0, 0, -0.27 if not up else 0.27), shirt); cu.parent = a; cu.location = (0, 0, -0.27 if not up else 0.27)
    h = sphere("hand", 0.055, (0, 0, 0), skin); h.parent = a; h.location = (0, 0, -0.31 if not up else 0.31)
    return a
aL = arm("ArmL", 0.2, False); aL.rotation_euler = (0.2, 0, 0)
aR = arm("ArmR", -0.2, True); aR.rotation_euler = (0.5, 0, 0)

# 大头
head = empty("Head", (0, 0, 1.0), root)
hp = []
hp.append(sphere("face", 0.3, (0, 0, 0), skin, scale=(1.0, 1.05, 0.95)))
hp.append(sphere("hairBack", 0.31, (-0.05, 0, 0.03), hair, scale=(0.95, 1.07, 0.97)))
for dy, dz, s in [(-0.16, 0.13, 0.11), (-0.05, 0.16, 0.12), (0.07, 0.16, 0.12), (0.18, 0.12, 0.1), (-0.25, 0.0, 0.09), (0.26, 0.0, 0.09), (-0.24, -0.12, 0.07), (0.25, -0.12, 0.07)]:
    hp.append(sphere("bang", s, (0.2 if abs(dy) < 0.2 else 0.08, dy, dz), hair, scale=(0.7, 1.0, 1.0)))
for y in (-0.11, 0.11):
    hp.append(sphere("eye", 0.075, (0.255, y, -0.03), eye, scale=(0.45, 0.85, 1.15)))
    hp.append(sphere("hi", 0.02, (0.285, y + 0.02, 0.0), eyeHi))
    hp.append(sphere("hi2", 0.01, (0.285, y - 0.02, -0.06), eyeHi))
    hp.append(sphere("blush", 0.055, (0.235, y * 1.75, -0.12), blush, scale=(0.4, 1.0, 0.6)))
hp.append(sphere("nose", 0.02, (0.3, 0, -0.08), skin))
smile = smooth_tube("smile", [(0.285, -0.045, -0.15), (0.295, 0, -0.17), (0.285, 0.045, -0.15)], 0.009, mouthM); hp.append(smile)
for y in (-0.3, 0.3):
    hp.append(sphere("ear", 0.06, (0.0, y, -0.03), skin, scale=(0.6, 0.5, 1.0)))
for o in hp: o.parent = head
# 船长帽
cap = empty("Cap", (0, 0, 0.17), head); cap.rotation_euler = (0, 0.12, 0)
cp = []
bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.29, radius2=0.37, depth=0.17)
cr = mesh_obj("crown", bm, white); cr.location = (0, 0, 0.1); bevel(cr, 0.05, 4); cp.append(cr)
cp.append(cyl("band", 0.298, 0.085, (0, 0, 0.035), navy))
cp.append(torus("cord", 0.30, 0.012, (0, 0, 0.075), gold))
v = sphere("visor", 0.22, (0.21, 0, -0.02), visor, scale=(0.85, 1.15, 0.13)); cp.append(v)
cp.append(cyl("badge", 0.06, 0.02, (0.3, 0, 0.09), gold, rot=(0, math.pi / 2 - 0.1, 0)))
cp.append(sphere("badgeIn", 0.03, (0.312, 0, 0.09), mat("badgeIn", (1, 0.9, 0.5), rough=0.2, metal=0.6), scale=(0.4, 1, 1)))
for o in cp: o.parent = cap

# 修正子物体位置为相对父节点
def fix(o, acc):
    pass
# 上面的 sphere/cyl 直接用了父空间坐标（设置 parent 后 location 解释为父空间），无需修正

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/capout"
os.makedirs(out, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "captain_raw.blend"))
print("OK")
