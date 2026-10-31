# 治愈系拖网渔船（Blender 4.2 无界面运行）：blender -b -P ship.py -- out_dir
import sys, os, math, bmesh, bpy
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from mathutils import Vector

clear()
C = dict(
    cream=(0.98, 0.93, 0.82), teal=(0.24, 0.62, 0.62), tealDark=(0.17, 0.47, 0.50), navy=(0.15, 0.23, 0.38),
    wood=(0.70, 0.48, 0.30), woodDark=(0.48, 0.32, 0.20), brass=(0.93, 0.74, 0.40), charcoal=(0.20, 0.21, 0.24),
    coral=(0.93, 0.47, 0.38), keel=(0.55, 0.30, 0.24), rope=(0.84, 0.72, 0.52), white=(0.97, 0.97, 0.95),
    orange=(1.0, 0.60, 0.28), green=(0.42, 0.62, 0.48), glass=(0.20, 0.30, 0.40))
M = {k: mat(k, v, rough=0.55) for k, v in C.items()}
M['brass'] = mat('brassM', C['brass'], rough=0.3, metal=0.7)

SX, BX, BEAM = -4.3, 4.7, 1.65
def u(x): return (x - SX) / (BX - SX)
def hw(x):
    t = u(x)
    if t < 0.55: return BEAM * (0.84 + 0.16 * min(1, t / 0.25))
    k = (t - 0.55) / 0.45
    return max(0.03, BEAM * math.sqrt(max(0, 1 - k * k)) * (1 - 0.05 * k))
def top(x): t = u(x); return 1.30 + 0.55 * max(0, (t - 0.55) / 0.45) ** 2 + 0.10 * max(0, (0.12 - t) / 0.12) ** 2
def bot(x): t = u(x); return -0.75 + 0.75 * max(0, (t - 0.72) / 0.28) ** 2 + 0.25 * max(0, (0.1 - t) / 0.1) ** 2
def deck(x): return 0.95 + 0.35 * max(0, (u(x) - 0.6) / 0.4) ** 2

parts = []   # 烘焙合并的静态部件

def hull_mat():
    m = bpy.data.materials.new("hullM"); m.use_nodes = True; nt = m.node_tree
    b = nt.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.5
    tc = nt.nodes.new("ShaderNodeTexCoord"); sp = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sp.inputs[0])
    def math_(op, a, b=None):
        n = nt.nodes.new("ShaderNodeMath"); n.operation = op
        for i, v in enumerate([a, b]):
            if v is None: continue
            if isinstance(v, (int, float)): n.inputs[i].default_value = v
            else: nt.links.new(v, n.inputs[i])
        return n.outputs[0]
    uu = math_('DIVIDE', math_('SUBTRACT', sp.outputs["X"], SX), BX - SX)
    k = math_('MAXIMUM', math_('DIVIDE', math_('SUBTRACT', uu, 0.55), 0.45), 0.0)
    sheer = math_('MULTIPLY', math_('MULTIPLY', k, k), 0.55)
    v = math_('SUBTRACT', sp.outputs["Z"], sheer)
    r = nt.nodes.new("ShaderNodeValToRGB"); r.color_ramp.interpolation = 'CONSTANT'
    nt.links.new(v, r.inputs["Fac"])
    # Fac 映射：v 取 -1..2 → 0..1
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = -1; mr.inputs["From Max"].default_value = 2
    nt.links.new(v, mr.inputs["Value"]); nt.links.new(mr.outputs["Result"], r.inputs["Fac"])
    def f(z): return (z + 1) / 3
    stops = [(0.0, C['keel']), (f(0.06), C['tealDark']), (f(0.42), C['cream']), (f(0.88), C['teal']), (f(1.03), C['cream'])]
    els = r.color_ramp.elements
    while len(els) < len(stops): els.new(0.5)
    for e, (pos, col) in zip(els, stops): e.position = pos; e.color = (*srgb(col), 1)
    nt.links.new(r.outputs["Color"], b.inputs["Base Color"])
    return m

# ---------- 船体（壳体 + 实心化 + 细分）----------
def hull():
    N, Mh = 30, 7
    bm = bmesh.new(); rings = []
    for i in range(N + 1):
        x = SX + (BX - SX) * i / N
        w, t, b = hw(x), top(x), bot(x)
        ring = []
        pts = []
        for j in range(Mh + 1):   # 右舷（-y）自上而下
            s = j / Mh
            z = t - (t - b) * s
            k = max(0, (s - 0.35) / 0.65)
            pts.append((x, -w * math.sqrt(max(0, 1 - k * k)), z))
        full = pts + [(p[0], -p[1], p[2]) for p in reversed(pts[:-1])]
        rings.append([bm.verts.new(p) for p in full])
    for i in range(N):
        for j in range(len(rings[0]) - 1):
            bm.faces.new((rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))   # 尾板
    o = mesh_obj("hull", bm)
    o.data.materials.append(M['cream'])
    sd = o.modifiers.new("sol", "SOLIDIFY"); sd.thickness = 0.09; sd.offset = -1
    subsurf(o, 2)
    o.data.materials.clear(); o.data.materials.append(hull_mat())
    return o
parts.append(hull())

# 舷边木扶手
for side in (-1, 1):
    pts = [(x, side * (hw(x) - 0.02), top(x) + 0.03) for x in [SX + 0.02 + (BX - 0.05 - SX) * i / 40 for i in range(41)]]
    parts.append(smooth_tube("rail", pts, 0.06, M['wood']))
# 甲板
def deck_mesh():
    bm = bmesh.new(); N = 30; prev = None
    for i in range(N + 1):
        x = SX + 0.1 + (BX - 0.35 - SX) * i / N
        w = hw(x) - 0.08
        a = bm.verts.new((x, -w, deck(x))); b = bm.verts.new((x, w, deck(x)))
        if prev: bm.faces.new((prev[0], a, b, prev[1]))
        prev = (a, b)
    return mesh_obj("deck", bm, M['wood'])
parts.append(deck_mesh())
# 甲板木条纹（细长条凸起）
for k in range(-6, 7):
    y = k * 0.24
    xs = [x for x in [SX + 0.15 + i * 0.25 for i in range(40)] if hw(x) - 0.12 > abs(y) and x < BX - 0.5]
    if len(xs) > 1:
        parts.append(box("plank", (xs[-1] - xs[0], 0.015, 0.012), ((xs[-1] + xs[0]) / 2, y, deck((xs[-1] + xs[0]) / 2) + 0.004), M['woodDark'], bev=0))

# 舷窗（两舷）
for side in (-1, 1):
    for x in [-3.3, -2.5, -1.7, -0.9]:
        y = side * (hw(x) + 0.0)
        parts.append(torus("port", 0.17, 0.045, (x, y, 0.80), M['brass'], rot=(math.pi / 2, 0, 0)))
        parts.append(cyl("portglass", 0.15, 0.04, (x, y, 0.80), M['glass'], rot=(math.pi / 2, 0, 0)))
# 锚徽（右舷）
for side in (-1, 1):
    x = 3.0; y = side * (hw(x) + 0.03); ang = math.atan((hw(x + 0.05) - hw(x - 0.05)) / 0.1) * side
    g = []
    g.append(cyl("emb", 0.38, 0.05, (0, 0, 0), M['navy'], rot=(math.pi / 2, 0, 0)))
    g.append(torus("embrim", 0.38, 0.035, (0, 0, 0), M['brass'], rot=(math.pi / 2, 0, 0)))
    d = -side * 0.0
    g.append(cyl("shank", 0.03, 0.44, (0, side * 0.04, 0.0), M['brass']))
    g.append(cyl("stock", 0.026, 0.28, (0, side * 0.04, 0.13), M['brass'], rot=(0, math.pi / 2, 0)))
    g.append(torus("eye", 0.05, 0.02, (0, side * 0.04, 0.26), M['brass'], rot=(math.pi / 2, 0, 0)))
    arc = [(0.17 * math.sin(a), side * 0.04, -0.06 - 0.17 * math.cos(a)) for a in [(-1.2 + 2.4 * i / 12) for i in range(13)]]
    g.append(tube("arc", arc, 0.026, M['brass']))
    for sx in (-1, 1):
        g.append(cyl("fluke", 0.05, 0.02, (sx * 0.16, side * 0.04, -0.02), M['brass'], seg=3, rot=(math.pi / 2, 0, 0)))
    em = join(g, "emblem")
    em.location = (x, y, 0.98); em.rotation_euler = (0, 0, -ang)
    parts.append(em)

# 系缆桩、锚链孔
for side in (-1, 1):
    parts.append(torus("hawse", 0.1, 0.035, (4.0, side * (hw(4.0) + 0.02), 1.32), M['charcoal'], rot=(math.pi / 2, 0, 0)))

# ---------- 驾驶室 ----------
HX = -1.6; hz = deck(HX)
parts.append(box("house", (1.8, 2.3, 1.5), (HX, 0, hz + 0.75), M['cream'], bev=0.09))
parts.append(box("houseBase", (1.86, 2.36, 0.14), (HX, 0, hz + 0.07), M['teal'], bev=0.03))
parts.append(box("roof", (2.25, 2.75, 0.16), (HX + 0.05, 0, hz + 1.58), M['teal'], bev=0.06))
parts.append(box("roofTrim", (2.29, 2.79, 0.05), (HX + 0.05, 0, hz + 1.49), M['cream'], bev=0.02))
windows = []
for y in [-0.65, 0, 0.65]:   # 前窗
    parts.append(box("wf", (0.06, 0.56, 0.56), (HX + 0.9, y, hz + 1.0), M['wood'], bev=0.02))
    windows.append(box("w", (0.04, 0.44, 0.44), (HX + 0.93, y, hz + 1.0), None, bev=0.01))
for side in (-1, 1):
    for x in [HX - 0.45, HX + 0.25]:
        parts.append(box("wf", (0.54, 0.06, 0.52), (x, side * 1.15, hz + 1.0), M['wood'], bev=0.02))
        windows.append(box("w", (0.42, 0.04, 0.40), (x, side * 1.18, hz + 1.0), None, bev=0.01))
    parts.append(box("door", (0.55, 0.06, 1.0), (HX + 0.55, side * 1.15, hz + 0.55), M['wood'], bev=0.03))
    parts.append(sphere("knob", 0.035, (HX + 0.72, side * 1.19, hz + 0.55), M['brass']))
    parts.append(cyl("doorwin", 0.12, 0.04, (HX + 0.55, side * 1.17, hz + 0.82), M['glass'], rot=(math.pi / 2, 0, 0)))
# 救生圈（右舷）
lr = torus("lifering", 0.22, 0.07, (HX - 0.45, -1.2, hz + 0.45), M['coral'], rot=(math.pi / 2, 0, 0))
parts.append(lr)
for k in range(4):
    a = k * math.pi / 2 + math.pi / 4
    parts.append(box("band", (0.09, 0.16, 0.16), (HX - 0.45 + 0.22 * math.cos(a), -1.2, hz + 0.45 + 0.22 * math.sin(a)), M['white'], bev=0.02, rot=(0, -a, 0)))
# 顶部栏杆、雷达桅、探照灯
for side in (-1, 1):
    parts.append(tube("tr", [(HX - 1.0, side * 1.25, hz + 1.95), (HX + 1.05, side * 1.25, hz + 1.95)], 0.025, M['white']))
    for x in [HX - 1.0, HX, HX + 1.05]:
        parts.append(tube("tp", [(x, side * 1.25, hz + 1.66), (x, side * 1.25, hz + 1.95)], 0.02, M['white']))
parts.append(tube("tr", [(HX + 1.05, -1.25, hz + 1.95), (HX + 1.05, 1.25, hz + 1.95)], 0.025, M['white']))
parts.append(cyl("rmast", 0.05, 0.7, (HX - 0.3, 0, hz + 2.0), M['white']))
parts.append(cyl("spot", 0.11, 0.18, (HX + 0.7, -0.75, hz + 1.78), M['brass'], rot=(0, math.pi / 2, 0)))
parts.append(cyl("horn", 0.06, 0.25, (HX + 0.7, 0.75, hz + 1.8), M['brass'], r2=0.1, rot=(0, math.pi / 2, 0)))

# ---------- 烟囱 ----------
FX = -2.95; fz = deck(FX)
fun = [cyl("funnel", 0.32, 2.6, (0, 0, 1.3), M['charcoal'], seg=40, r2=0.30),
       cyl("fband", 0.335, 0.3, (0, 0, 2.1), M['teal'], seg=40),
       cyl("fwhite", 0.337, 0.07, (0, 0, 1.92), M['cream'], seg=40),
       torus("ftop", 0.31, 0.05, (0, 0, 2.6), M['charcoal'])]
f = join(fun, "funnelG"); f.location = (FX, -0.1, fz); f.rotation_euler = (0, -0.12, 0); parts.append(f)

# ---------- 桅杆、吊杆 ----------
MX = 0.7; mz = deck(MX); MT = mz + 4.6
parts.append(cyl("mast", 0.09, 4.6, (MX, 0, mz + 2.3), M['cream'], r2=0.07))
parts.append(cyl("cross", 0.05, 1.7, (MX, 0, MT - 1.0), M['cream'], rot=(math.pi / 2, 0, 0)))
parts.append(sphere("mtop", 0.09, (MX, 0, MT + 0.05), M['white']))
boomTip = (MX + 2.9, -2.5, mz + 4.0)
parts.append(tube("boom", [(MX, -0.1, mz + 1.0), boomTip], 0.065, M['cream']))
parts.append(tube("boomP", [(MX, 0.1, mz + 1.0), (MX - 0.6, 1.6, mz + 3.9)], 0.06, M['cream']))
parts.append(torus("boomRing", 0.08, 0.02, (MX, 0, mz + 1.0), M['charcoal'], rot=(0, 0, 0)))
# 索具（略微下垂）
rig = [(( MX, 0, MT), boomTip, 0.05), ((MX, 0, MT), (BX - 0.3, 0, top(BX - 0.3) + 0.25), 0.08),
       ((MX, 0, MT), (HX, 0, hz + 2.3), 0.05), ((MX, 0, MT), (MX - 0.6, 1.6, mz + 3.9), 0.03)]
for side in (-1, 1):
    rig.append(((MX, side * 0.85, MT - 1.0), (MX - 0.2, side * (hw(MX) - 0.05), top(MX) + 0.1), 0.02))
for a, b, d in rig:
    parts.append(tube("rig", sag(a, b, d), 0.014, M['woodDark']))
# 灯笼（夜间发光，SceneKit 控制）
parts.append(cyl("lanternTop", 0.07, 0.06, (HX + 0.95, -1.2, hz + 1.38), M['charcoal']))

# ---------- 船尾绞车 + A 字架 ----------
WX = -3.75; wz = deck(WX)
parts.append(cyl("drum", 0.32, 1.7, (WX, 0, wz + 0.4), M['green'], rot=(math.pi / 2, 0, 0)))
for y in (-0.9, 0.9):
    parts.append(cyl("flange", 0.4, 0.08, (WX, y, wz + 0.4), M['coral'], rot=(math.pi / 2, 0, 0), bev=0.02))
for k in range(9):   # 网的纹理绕在滚筒上
    parts.append(torus("wrap", 0.33, 0.02, (WX, -0.8 + k * 0.2, wz + 0.4), M['tealDark'], rot=(math.pi / 2, 0, 0), seg=32, mseg=8))
for side in (-1, 1):
    parts.append(tube("aframe", [(-4.1, side * 1.2, deck(-4.1)), (-4.25, side * 0.6, deck(-4.1) + 2.0)], 0.065, M['coral']))
parts.append(tube("aframeT", [(-4.25, -0.6, deck(-4.1) + 2.0), (-4.25, 0.6, deck(-4.1) + 2.0)], 0.065, M['coral']))

# ---------- 甲板杂物 ----------
def crate(x, y, s, yaw, stack=0):
    g = [box("c", (s, s, s), (0, 0, 0), M['wood'], bev=0.025)]
    for dz in (-0.3, 0.3):
        g.append(box("cs", (s * 1.03, s * 1.03, s * 0.13), (0, 0, s * dz), M['woodDark'], bev=0.01))
    o = join(g, "crate"); o.location = (x, y, deck(x) + s / 2 + stack * s); o.rotation_euler = (0, 0, yaw); parts.append(o)
crate(1.35, -0.85, 0.42, 0.2); crate(1.4, -0.82, 0.36, -0.1, 1); crate(1.6, 0.8, 0.36, 0.5); crate(-0.35, 0.9, 0.4, 0.1)
crate(2.7, 0.6, 0.32, -0.3)
def barrel(x, y):
    g = [cyl("b", 0.2, 0.5, (0, 0, 0), M['wood'], r2=0.2)]
    b = g[0]; sb = b.modifiers.new("s", "SIMPLE_DEFORM"); sb.deform_method = 'TAPER'; sb.factor = 0.0
    for dz in (-0.16, 0.16):
        g.append(torus("hoop", 0.205, 0.015, (0, 0, dz), M['charcoal'], mseg=8))
    o = join(g, "barrel"); o.location = (x, y, deck(x) + 0.25); parts.append(o)
barrel(0.15, -1.05); barrel(-0.25, -1.12); barrel(2.6, 0.9)
for x, y in [(1.1, 1.2), (2.0, 1.05), (-0.6, -1.25), (2.3, -1.15)]:
    parts.append(sphere("buoy", 0.15, (x, y, deck(x) + 0.15), M['orange']))
    parts.append(torus("buoyband", 0.15, 0.02, (x, y, deck(x) + 0.15), M['white']))
# 缆绳盘
coil = [(3.5 + (0.3 - 0.012 * k) * math.cos(a), -0.3 + (0.3 - 0.012 * k) * math.sin(a), deck(3.5) + 0.05 + 0.055 * (k // 24))
        for k in range(24 * 4) for a in [2 * math.pi * (k % 24) / 24]]
parts.append(smooth_tube("coil", coil[::2], 0.05, M['rope']))
# 绳梯（右舷）
LX = 0.1; ly = -(hw(LX) + 0.07)
for dx in (-0.2, 0.2):
    parts.append(smooth_tube("lad", [(LX + dx, ly + 0.02, top(LX) + 0.35), (LX + dx, ly - 0.02, 0.6), (LX + dx, ly - 0.06, -0.05)], 0.018, M['rope']))
for k in range(6):
    z = top(LX) + 0.15 - k * 0.25
    parts.append(cyl("rung", 0.025, 0.46, (LX, ly - 0.01 * k, z), M['wood'], rot=(0, math.pi / 2, 0)))
# 船头小灯笼柱、旗杆
parts.append(cyl("bowpost", 0.035, 0.9, (BX - 0.45, 0, top(BX - 0.45) + 0.4), M['wood']))

ship = join(parts, "ShipBody")

# 动态部件（不烘焙）
wm = mat("Windows", C['glass'], rough=0.08)
wn = join(windows, "Windows"); wn.data.materials.clear(); wn.data.materials.append(wm)
lan = sphere("Lantern", 0.12, (HX + 0.95, -1.2, hz + 1.22), mat("LanternM", C['coral'], rough=0.35, emit=(0.5, 0.15, 0.05)), scale=(1, 1, 1.25))
# 雷达
rad = join([box("r1", (0.12, 0.95, 0.07), (0, 0, 0), M['white'], bev=0.02), cyl("r2", 0.05, 0.1, (0, 0, -0.06), M['charcoal'])], "Radar")
rad.location = (HX - 0.3, 0, hz + 2.4)
# 旗
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=8, y_segments=4, size=0.5)
for v in bm.verts: v.co = Vector((v.co.x * 0.55 - 0.28, 0.06 * math.sin(v.co.x * 6), v.co.y * 0.3))
fl = mesh_obj("Flag", bm, M['teal']); fl.location = (MX - 0.0, 0, MT - 0.1)
# 网：锥形线框网 + 网兜 + 鱼 + 浮子
ng = []
bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=False, segments=20, radius1=0.78, radius2=0.14, depth=1.7)
bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.1], cuts=7)
cone = mesh_obj("netc", bm, M['rope']); cone.location = (0, 0, -1.45)
wf = cone.modifiers.new("wf", "WIREFRAME"); wf.thickness = 0.022; ng.append(cone)
bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=10, radius=0.78)
for v in bm.verts: v.co.z *= 0.6
bag = mesh_obj("bag", bm, M['rope']); bag.location = (0, 0, -2.25)
wf = bag.modifiers.new("wf", "WIREFRAME"); wf.thickness = 0.022; ng.append(bag)
fishM = [mat("fish1", (0.72, 0.82, 0.90), rough=0.25, metal=0.3), mat("fish2", (0.98, 0.62, 0.45), rough=0.3)]
for k in range(7):
    ng.append(sphere("fish", 0.13, ((k % 3) * 0.22 - 0.22, (k % 2) * 0.25 - 0.12, -2.3 - (k // 3) * 0.13), fishM[k % 2], scale=(1.7, 0.6, 0.75)))
for k in range(8):
    a = 2 * math.pi * k / 8
    ng.append(sphere("float", 0.075, (0.78 * math.cos(a), 0.78 * math.sin(a), -2.25), M['orange']))
ng.append(cyl("netrope", 0.015, 0.6, (0, 0, -0.3), M['woodDark']))
net = join(ng, "Net"); net.location = boomTip

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/shipout"
os.makedirs(out, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "ship_raw.blend"))
print("TRIS", sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'))
