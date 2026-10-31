# 39 种鱼 / 海洋生物的参数化可爱模型：blender -b -P fish.py -- outdir [id ...]
# 身体 = 沿脊线放样的椭圆截面（自带 UV：u 沿身长、v 绕一圈），花纹直接画在贴图上；
# 鳍、眼睛、触手等配件的 UV 指向贴图右侧的纯色色块，因此一张 512×256 贴图搞定一个物种。
import bpy, bmesh, math, sys, os, random
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(__file__))

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]; ONLY = set(args[1:])
os.makedirs(OUT, exist_ok=True)
TW, TH = 512, 256
BODY_U = 0.78            # 贴图左侧 78% 给身体
SW = {}                  # 色块名 -> (u, v)

def C(h):  # "#rrggbb" -> (r,g,b) 0..1
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))

# ---------------- 物种表 ----------------
# fam: fish / deep / long / shark / puffer / sunfish / flat / monk / crab / shrimp / lobster / squid / octopus / urchin / abalone / dragon / sword / skipper / coel
S = {
 "sardine":   dict(fam="fish", L=1.0, H=0.26, W=0.18, top="#4f86b8", belly="#eef6fb", fin="#9fc3dc", pat=[("spots_line", "#2f5b86")]),
 "mackerel":  dict(fam="fish", H=0.28, W=0.2, top="#3f8f8a", belly="#f3f1e6", fin="#9cc7b9", pat=[("bars", "#244f5c")]),
 "crab":      dict(fam="crab", top="#6f8fb8", belly="#f3e6d2", fin="#d9805e", legs="#7da0c8", pat=[("spots", "#f2f2f2")]),
 "seabream":  dict(fam="deep", H=0.55, W=0.16, top="#f08a8c", belly="#fde7df", fin="#f6a5a0", pat=[("spots", "#7ec8e3")]),
 "mudskipper":dict(fam="skipper", H=0.2, W=0.2, top="#8a7a5c", belly="#e9dfc9", fin="#a99a78", pat=[("spots", "#5ec0e0")]),
 "tigerprawn":dict(fam="shrimp", top="#5e6e7e", belly="#c9d3d8", fin="#e7a04f", pat=[("rings", "#2e3540")]),
 "mudcrab":   dict(fam="crab", top="#5c6e4f", belly="#e8dcc0", fin="#7c8a5c", legs="#6f7f58", pat=[]),
 "barramundi":dict(fam="fish", H=0.3, W=0.18, top="#7d8f8f", belly="#f1f1ea", fin="#a7b4ad", pat=[]),
 "clown":     dict(fam="deep", H=0.42, W=0.2, top="#ff8a3d", belly="#ffa45c", fin="#ff9a4a", pat=[("bands", "#ffffff", "#2a2a2a", [0.25, 0.55, 0.86])], finEdge="#2a2a2a"),
 "squid":     dict(fam="squid", top="#f2b8a8", belly="#fff1ea", fin="#f6c9bc", pat=[("dots", "#d77a6a")]),
 "lobster":   dict(fam="lobster", top="#4d8fa0", belly="#e9c98f", fin="#f2b84b", pat=[("rings", "#f4e2b0")]),
 "coraltrout":dict(fam="fish", H=0.32, W=0.2, top="#e2554e", belly="#f7a08e", fin="#e86a5d", pat=[("dots", "#7fd3ff")]),
 "urchin":    dict(fam="urchin", top="#7a5aa6", belly="#5e4588", fin="#9b7ac9", pat=[]),
 "abalone":   dict(fam="abalone", top="#8fae9a", belly="#f0dce8", fin="#c9b2d6", pat=[("swirl", "#c7a6d8")]),
 "yellowtail":dict(fam="fish", H=0.27, W=0.2, top="#5a8fb4", belly="#f5f5ef", fin="#f2d04b", pat=[("line", "#f2d04b")]),
 "seadragon": dict(fam="dragon", top="#d9a54a", belly="#f2d48a", fin="#8fbf6a", pat=[("dots", "#f6efe0")]),
 "tuna":      dict(fam="fish", L=1.0, H=0.33, W=0.26, top="#2f4f8a", belly="#eef1f5", fin="#f3cf3a", pat=[("line", "#e9c64a")]),
 "mahimahi":  dict(fam="fish", H=0.36, W=0.17, top="#3fa98a", belly="#f6dd55", fin="#4fb7c9", pat=[("dots", "#2f7fb0")]),
 "puffer":    dict(fam="puffer", top="#7b8f6a", belly="#fbf6e8", fin="#c9c9a3", pat=[("spots", "#3e4a36"), ("blotch", "#2e3828")]),
 "swordfish": dict(fam="sword", H=0.3, W=0.22, top="#4b5f86", belly="#e7ecf2", fin="#6b7fa3", pat=[]),
 "cod":       dict(fam="fish", H=0.3, W=0.22, top="#9c8a5e", belly="#f4efe1", fin="#b6a77e", pat=[("spots", "#6f6142"), ("line", "#f1ecd8")], barbel=True),
 "salmon":    dict(fam="fish", H=0.3, W=0.2, top="#6f8fa8", belly="#f7ecea", fin="#a2b6c4", pat=[("xspots", "#2f3e52")]),
 "charr":     dict(fam="fish", H=0.28, W=0.19, top="#5d7a6a", belly="#f28a5a", fin="#f07a50", pat=[("dots", "#f6c9c0")], finEdge="#ffffff"),
 "kingcrab":  dict(fam="crab", spiky=True, longLegs=True, top="#d9534a", belly="#f6d6c3", fin="#e2684f", legs="#d9534a", pat=[]),
 "monkfish":  dict(fam="monk", top="#9a7a5e", belly="#e9d7c4", fin="#b08d6e", pat=[("spots", "#6e5440")]),
 "octopus":   dict(fam="octopus", top="#e9876f", belly="#f8c7b2", fin="#f2a28c", pat=[("dots", "#c9624c")]),
 "giantsquid":dict(fam="squid", giant=True, top="#c96a6a", belly="#f2c0b0", fin="#d98a82", pat=[]),
 "oarfish":   dict(fam="long", top="#cfd8e2", belly="#f4f7fa", fin="#ef5a5a", pat=[("dashes", "#7e8fa6")]),
 "bluefin":   dict(fam="fish", H=0.36, W=0.28, top="#1f3f78", belly="#f0f3f7", fin="#f1c63c", pat=[("line", "#9fc0e0")]),
 "sunfish":   dict(fam="sunfish", top="#8d9aab", belly="#eef0f2", fin="#a3aebc", pat=[("blotch", "#c9d1db")]),
 "megamouth": dict(fam="shark", mega=True, top="#5c5c6e", belly="#e6e4ec", fin="#6e6e82", pat=[]),
 "coelacanth":dict(fam="coel", H=0.33, W=0.22, top="#3f5f94", belly="#6e86b0", fin="#4f6fa4", pat=[("spots", "#f2f2f2")]),
 "greenlandshark": dict(fam="shark", top="#6c6e6c", belly="#b9bdb8", fin="#7c7e7c", pat=[("dots", "#8a8c88")]),
 "polarcod":  dict(fam="fish", H=0.26, W=0.18, top="#9aa7b2", belly="#f1f3f4", fin="#b9c3cb", pat=[("dots", "#7c8894")]),
 "halibut":   dict(fam="flat", top="#7a6e5e", belly="#f2efe8", fin="#8d8170", pat=[("blotch", "#5f5546")]),
 "snowcrab":  dict(fam="crab", longLegs=True, top="#f09a6a", belly="#fbe7d6", fin="#f4b28a", legs="#f09a6a", pat=[]),
 "krill":     dict(fam="shrimp", krill=True, top="#ff8c7a", belly="#ffd6c9", fin="#ff9e8a", pat=[("dots", "#e85a4a")]),
 "toothfish": dict(fam="fish", H=0.3, W=0.22, top="#5c5866", belly="#c9c6d0", fin="#6e6a78", pat=[("blotch", "#47444f")], teeth=True),
 "icefish":   dict(fam="fish", H=0.24, W=0.16, top="#b9c9cf", belly="#eef4f6", fin="#d6e4e8", pat=[("bars", "#8fa6ae")], clear=True),
}

# ---------------- 贴图 ----------------
def paint(sp, seed):
    rng = np.random.default_rng(seed)
    W = int(TW * BODY_U)
    u = np.linspace(0, 1, W)[None, :].repeat(TH, 0)          # 0 尾 → 1 头
    v = np.linspace(0, 1, TH)[:, None].repeat(W, 1)          # 0 背 → 0.5 腹 → 1 背
    z = np.cos(2 * np.pi * v)                                # 1 背，-1 腹
    top, belly = np.array(C(sp["top"])), np.array(C(sp["belly"]))
    k = np.clip((z + 0.25) / 0.9, 0, 1); k = k * k * (3 - 2 * k)
    img = belly[None, None] * (1 - k[..., None]) + top[None, None] * k[..., None]
    # 背部再深一点、腹部柔和高光
    img *= (0.92 + 0.08 * (1 - np.clip(z, 0, 1)))[..., None]
    def blend(mask, col, a=1.0):
        nonlocal img
        m = np.clip(mask, 0, 1)[..., None] * a
        img = img * (1 - m) + np.array(C(col))[None, None] * m
    side = np.minimum(np.abs(v - 0.25), np.abs(v - 0.75))   # 0 在体侧中线
    for p in sp.get("pat", []):
        kind = p[0]
        if kind == "bands":
            col, edge, pos = p[1], p[2], p[3]
            for c0 in pos:
                d = np.abs(u - c0)
                blend(np.clip((0.075 - d) / 0.01, 0, 1), edge)
                blend(np.clip((0.06 - d) / 0.01, 0, 1), col)
        elif kind == "bars":
            wav = np.sin(u * 60 + np.sin(v * 30) * 1.5)
            blend(np.clip((wav - 0.55) * 4, 0, 1) * np.clip((z - 0.05) * 3, 0, 1), p[1], 0.85)
        elif kind == "rings":
            wav = np.sin(u * 2 * np.pi * 7)
            blend(np.clip((wav - 0.55) * 5, 0, 1) * np.clip((z + 0.6) * 2, 0, 1), p[1], 0.9)
        elif kind == "line":
            blend(np.clip((0.035 - side) / 0.012, 0, 1) * (u > 0.12) * (u < 0.85), p[1], 0.9)
        elif kind in ("spots", "dots", "xspots", "spots_line", "dashes"):
            n = {"spots": 70, "dots": 110, "xspots": 60, "spots_line": 9, "dashes": 24}[kind]
            r = {"spots": 0.022, "dots": 0.014, "xspots": 0.016, "spots_line": 0.02, "dashes": 0.02}[kind]
            for _ in range(n):
                cu = rng.uniform(0.15, 0.88)
                if kind == "spots_line":
                    cv = 0.25 - 0.06; cu = 0.3 + 0.05 * _ 
                    for vv in (cv, 1 - cv):
                        d = np.sqrt(((u - cu) * 2.2) ** 2 + (v - vv) ** 2); blend(np.clip((r - d) / 0.006, 0, 1), p[1])
                    continue
                cv = rng.uniform(0.0, 1.0)
                if kind in ("xspots",) and abs(math.cos(2 * math.pi * cv)) < 0.0: continue
                if kind != "dots" and math.cos(2 * math.pi * cv) < -0.2: continue
                sx = 2.2 if kind != "dashes" else 0.7
                d = np.sqrt(((u - cu) * sx) ** 2 + np.minimum(np.abs(v - cv), 1 - np.abs(v - cv)) ** 2)
                blend(np.clip((r * rng.uniform(0.7, 1.3) - d) / 0.006, 0, 1), p[1])
        elif kind == "blotch":
            f = sum(np.sin(u * rng.uniform(8, 18) + rng.uniform(0, 6)) * np.sin(v * 2 * np.pi * rng.integers(2, 5) + rng.uniform(0, 6)) for _ in range(3))
            blend(np.clip((f - 0.8) * 2, 0, 1) * np.clip(z + 0.3, 0, 1), p[1], 0.55)
        elif kind == "swirl":
            f = np.sin((u * 12 + v * 6) * np.pi + np.sin(v * 12) * 2)
            blend(np.clip((f - 0.4) * 2, 0, 1), p[1], 0.6)
    # 头部柔和腮红区（可爱）
    full = np.ones((TH, TW, 3)); full[:, :W] = img
    # 色块
    sw = [("fin", sp["fin"]), ("finEdge", sp.get("finEdge", sp["fin"])), ("eyeW", "#ffffff"), ("pupil", "#2a2230"),
          ("blush", "#ff9fa4"), ("legs", sp.get("legs", sp["fin"])), ("mouth", "#7a3e3e"), ("tooth", "#fffaf0"), ("top", sp["top"]), ("belly", sp["belly"])]
    n = len(sw); cw = TW - W
    for i, (name, col) in enumerate(sw):
        y0, y1 = int(TH * i / n), int(TH * (i + 1) / n)
        full[y0:y1, W:] = C(col)
        SW[name] = ((W + cw / 2) / TW, 1 - (y0 + y1) / 2 / TH)
    return full

# ---------------- 网格 ----------------
def loft(name, spine, hs, ws, M=28, sq=1.0, side=Vector((0, 1, 0))):
    """spine: [Vector]，hs/ws: 半高/半宽；返回 bmesh 对象（带 UV）"""
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap")
    N = len(spine); rings = []
    for i in range(N):
        a = spine[max(i - 1, 0)]; b = spine[min(i + 1, N - 1)]
        tng = (b - a).normalized(); up = tng.cross(side).normalized() * -1
        if up.z < 0: up = -up
        sd = up.cross(tng).normalized()
        ring = []
        for j in range(M):
            ang = 2 * math.pi * j / M
            cz, sz = math.cos(ang), math.sin(ang)
            cz2 = math.copysign(abs(cz) ** sq, cz); sz2 = math.copysign(abs(sz) ** sq, sz)
            ring.append(bm.verts.new(spine[i] + up * hs[i] * cz2 + sd * ws[i] * sz2))
        rings.append(ring)
    for i in range(N - 1):
        for j in range(M):
            f = bm.faces.new((rings[i][j], rings[i][(j + 1) % M], rings[i + 1][(j + 1) % M], rings[i + 1][j]))
            for l, (ii, jj) in zip(f.loops, [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]):
                l[uvl].uv = (BODY_U * (1 - ii / (N - 1)) * 0.995 + 0.002, 1 - jj / M)
    for end, ii in ((0, 0), (N - 1, N - 1)):
        c = bm.verts.new(spine[ii])
        for j in range(M):
            vs = (rings[ii][j], rings[ii][(j + 1) % M], c) if end else (rings[ii][(j + 1) % M], rings[ii][j], c)
            f = bm.faces.new(vs)
            for l in f.loops: l[uvl].uv = (BODY_U * (1 - ii / (N - 1)) * 0.995 + 0.002, 0.5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    for p in me.polygons: p.use_smooth = True
    return o

def solid_uv(o, sw):
    me = o.data
    if not me.uv_layers: me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0]
    for l in uv.data: l.uv = SW[sw]
    for p in me.polygons: p.use_smooth = True
    return o

def prim(kind, sw, loc, scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    if kind == "sphere": bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("seg", 20), ring_count=kw.get("rings", 12), radius=1)
    elif kind == "cone": bpy.ops.mesh.primitive_cone_add(vertices=kw.get("seg", 12), radius1=1, radius2=kw.get("r2", 0), depth=2)
    elif kind == "cyl": bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("seg", 12), radius=1, depth=2)
    elif kind == "torus": bpy.ops.mesh.primitive_torus_add(major_radius=1, minor_radius=kw.get("minor", 0.25), major_segments=24, minor_segments=8)
    o = bpy.context.object; o.location = loc; o.scale = scale; o.rotation_euler = rot
    return solid_uv(o, sw)

def fin(sw, pts, thick=0.012):
    """平面鳍：pts 为 XZ 平面多边形（y=0），挤出薄厚度"""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in pts]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]: v.co.y += thick
    for v in bm.verts: v.co.y -= thick / 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("fin"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("fin", me); bpy.context.scene.collection.objects.link(o)
    solid_uv(o, sw)
    md = o.modifiers.new("s", "SUBSURF"); md.levels = 1; md.render_levels = 1
    return o

def tube(sw, pts, r0, r1=None, M=10):
    pts = [Vector(p) for p in pts]; n = len(pts); r1 = r0 if r1 is None else r1
    rs = [r0 + (r1 - r0) * i / (n - 1) for i in range(n)]
    side = Vector((0, 0, 1)) if abs((pts[-1] - pts[0]).normalized().z) < 0.9 else Vector((1, 0, 0))
    o = loft("tube", pts, rs, rs, M=M, side=side)
    return solid_uv(o, sw)

def eyes(x, z, yoff, r, big=1.0, top=False):
    out = []
    for s in (1, -1):
        y = s * yoff
        if top:
            out.append(prim("sphere", "eyeW", (x, s * yoff, z), (r, r, r)))
            out.append(prim("sphere", "pupil", (x + r * 0.25, s * (yoff + r * 0.35), z + r * 0.55), (r * 0.55,) * 3))
            out.append(prim("sphere", "eyeW", (x + r * 0.45, s * (yoff + r * 0.45), z + r * 0.9), (r * 0.18,) * 3))
        else:
            out.append(prim("sphere", "eyeW", (x, y, z), (r * 0.9, r * 0.5, r)))
            out.append(prim("sphere", "pupil", (x + r * 0.08, s * (yoff + r * 0.32), z - r * 0.05), (r * 0.62, r * 0.3, r * 0.72)))
            out.append(prim("sphere", "eyeW", (x + r * 0.26, s * (yoff + r * 0.5), z + r * 0.28), (r * 0.2, r * 0.1, r * 0.2)))
        out.append(prim("sphere", "blush", (x - r * 0.1, s * (yoff - r * 0.05), z - r * 1.25), (r * 0.45, r * 0.12, r * 0.28)))
    return out

def fish_body(sp, L=2.0, H=0.3, W=0.2, N=26, head="round", tailPinch=0.12):
    spine, hs, ws = [], [], []
    for i in range(N):
        t = i / (N - 1)                       # 0 尾 → 1 头
        x = -L / 2 + L * t
        prof = math.sin(math.pi * min(1, (t * 0.92 + 0.04))) ** 0.75
        if head == "blunt": prof = max(prof, math.sin(math.pi * min(t, 0.6) / 1.2) ** 0.6 if t > 0.5 else prof)
        hh = max(tailPinch * H, H * prof); ww = max(tailPinch * W * 0.8, W * prof)
        if t > 0.97: hh *= 0.6; ww *= 0.6
        spine.append(Vector((x, 0, 0.02 * math.sin(t * math.pi)))); hs.append(hh); ws.append(ww)
    return loft("body", spine, hs, ws)

def tail_fin(x, h, sw="fin", fork=0.35, ln=0.5):
    return fin(sw, [(x + 0.06, 0, 0.06), (x - ln, 0, h), (x - ln * (1 - fork), 0, 0), (x - ln, 0, -h), (x + 0.06, 0, -0.06)])

def build_fish(sp, fam):
    parts = []
    H, W = sp.get("H", 0.28), sp.get("W", 0.2)
    if fam == "deep": H, W = sp.get("H", 0.55), sp.get("W", 0.16)
    L = 1.7
    head = sp.get("head", "round")
    if fam == "skipper": L = 1.8
    body = fish_body(sp, L=L, H=H, W=W, head=head); parts.append(body)
    xt = -L / 2
    if fam == "coel":
        parts.append(tail_fin(xt, H * 0.9, fork=0.0, ln=0.4))
        for dx, dz, sz in [(0.2, H * 0.95, 0.18), (-0.25, H * 0.85, 0.16), (-0.25, -H * 0.85, 0.16)]:
            parts.append(prim("sphere", "fin", (dx, 0, dz), (sz, 0.05, sz * 0.7), rot=(0, 0.4 * (1 if dz > 0 else -1), 0)))
    else:
        parts.append(tail_fin(xt, H * (1.3 if fam == "deep" else 1.1), fork=0.45 if fam in ("fish", "sword") else 0.2, ln=0.45))
    # 背鳍
    dh = H * (0.9 if fam != "deep" else 0.55)
    if sp.get("id") == "mahimahi":
        parts.append(fin("fin", [(0.7, 0, H * 0.9), (0.45, 0, H * 1.5), (-0.6, 0, H * 0.9), (-0.7, 0, H * 0.3), (0.5, 0, H * 0.6)]))
    else:
        parts.append(fin("finEdge" if sp.get("finEdge") else "fin", [(0.25, 0, H * 0.85), (0.0, 0, H + dh * 0.7), (-0.3, 0, H * 0.75), (-0.2, 0, H * 0.5), (0.2, 0, H * 0.6)]))
    # 胸鳍（两侧，微微张开）
    for s in (1, -1):
        f = fin("fin", [(0.35, 0, -0.02), (0.05, 0, -0.16), (0.12, 0, 0.05)])
        f.location = (0.05, s * W * 0.95, -H * 0.25); f.rotation_euler = (s * 0.5, 0, 0)
        parts.append(f)
    # 腹鳍、臀鳍
    parts.append(fin("fin", [(-0.15, 0, -H * 0.7), (-0.35, 0, -H - 0.12), (-0.5, 0, -H * 0.5)]))
    ex = L / 2 - 0.2
    if fam == "skipper":
        parts += eyes(ex - 0.05, H * 0.95, W * 0.45, 0.085, top=True)
    else:
        parts += eyes(ex - 0.02, H * 0.25, W * 0.62, 0.09)
    # 嘴
    parts.append(prim("torus", "mouth", (L / 2 - 0.035, 0, -H * 0.2), (0.035, 0.05, 0.03), rot=(0, math.pi / 2, 0), minor=0.3))
    if fam == "sword":
        parts.append(tube("top", [(L / 2 - 0.05, 0, H * 0.1), (L / 2 + 0.8, 0, H * 0.18)], 0.045, 0.008))
    if sp.get("barbel"):
        parts.append(tube("fin", [(L / 2 - 0.08, 0, -H * 0.55), (L / 2 - 0.1, 0, -H * 0.85)], 0.012, 0.006))
    if sp.get("teeth"):
        for s in (1, -1): parts.append(prim("cone", "tooth", (L / 2 - 0.03, s * 0.025, -H * 0.12), (0.012, 0.012, 0.03), rot=(math.pi, 0, 0)))
    return parts

def build(sid, sp):
    fam = sp["fam"]; sp["id"] = sid
    parts = []
    if fam in ("fish", "deep", "skipper", "sword", "coel"):
        parts = build_fish(sp, fam)
    elif fam == "shark":
        mega = sp.get("mega")
        spine, hs, ws = [], [], []
        for i in range(26):
            t = i / 25; x = -1.0 + 2.0 * t
            prof = math.sin(math.pi * min(1, t * 0.95 + 0.03)) ** 0.6
            spine.append(Vector((x, 0, 0))); hs.append(max(0.05, 0.3 * prof)); ws.append(max(0.05, (0.34 if mega else 0.3) * prof))
        parts.append(loft("body", spine, hs, ws))
        parts.append(fin("fin", [(-0.95, 0, 0.0), (-1.4, 0, 0.45), (-1.2, 0, 0.0), (-1.3, 0, -0.22)]))
        parts.append(fin("fin", [(0.15, 0, 0.25), (-0.05, 0, 0.62), (-0.3, 0, 0.25)]))
        for s in (1, -1):
            f = fin("fin", [(0.35, 0, 0), (0.0, 0, -0.35), (0.0, 0, 0)]); f.location = (0.1, s * 0.25, -0.12); f.rotation_euler = (s * 0.9, 0, 0); parts.append(f)
        parts += eyes(0.72, 0.08, 0.2, 0.07)
        if mega: parts.append(prim("sphere", "mouth", (0.93, 0, -0.08), (0.08, 0.2, 0.06)))
        else: parts.append(prim("torus", "mouth", (0.9, 0, -0.12), (0.06, 0.1, 0.04), rot=(0, math.pi / 2, 0), minor=0.3))
    elif fam == "long":
        spine, hs, ws = [], [], []
        for i in range(40):
            t = i / 39; x = -1.6 + 3.2 * t
            spine.append(Vector((x, 0, 0.12 * math.sin(t * math.pi * 3)))); hs.append(max(0.03, 0.16 * math.sin(math.pi * min(1, t * 0.9 + 0.1)) ** 0.4)); ws.append(max(0.02, 0.06 * math.sin(math.pi * min(1, t * 0.9 + 0.1)) ** 0.4))
        parts.append(loft("body", spine, hs, ws))
        pts = [(spine[i].x, 0, spine[i].z + hs[i] * 0.9) for i in range(4, 40, 2)]
        crest = [(p[0], 0, p[2] + 0.1) for p in pts]
        parts.append(fin("fin", pts + crest[::-1]))
        for k in range(3): parts.append(tube("fin", [(1.5, 0, 0.15), (1.55 - k * 0.05, 0, 0.45 + k * 0.08), (1.4 - k * 0.1, 0, 0.6 + k * 0.08)], 0.02, 0.01))
        parts += eyes(1.45, 0.05, 0.05, 0.05)
    elif fam == "puffer":
        spine = [Vector((x, 0, 0)) for x in np.linspace(-0.6, 0.6, 22)]
        prof = [math.sin(math.pi * min(1, i / 21 * 0.9 + 0.08)) ** 0.5 for i in range(22)]
        parts.append(loft("body", spine, [max(0.08, 0.5 * p) for p in prof], [max(0.08, 0.48 * p) for p in prof]))
        parts.append(tail_fin(-0.6, 0.22, fork=0.1, ln=0.3))
        parts.append(fin("fin", [(-0.2, 0, 0.42), (-0.35, 0, 0.62), (-0.45, 0, 0.3)]))
        for s in (1, -1):
            f = fin("fin", [(0.2, 0, 0), (-0.05, 0, -0.14), (0.0, 0, 0.1)]); f.location = (0.05, s * 0.46, 0); f.rotation_euler = (s * 0.4, 0, 0); parts.append(f)
        for k in range(26):
            a = random.uniform(0, 2 * math.pi); b = random.uniform(-1, 1)
            d = Vector((random.uniform(-0.4, 0.45), math.cos(a) * 0.48, math.sin(a) * 0.48))
            parts.append(prim("cone", "belly", d * 1.0, (0.02, 0.02, 0.05), rot=(-a + math.pi / 2, 0, 0), seg=6))
        parts += eyes(0.4, 0.15, 0.3, 0.1)
        parts.append(prim("torus", "mouth", (0.6, 0, -0.05), (0.04, 0.05, 0.035), rot=(0, math.pi / 2, 0), minor=0.35))
    elif fam == "sunfish":
        spine = [Vector((x, 0, 0)) for x in np.linspace(-0.7, 0.7, 22)]
        prof = [math.sin(math.pi * min(1, i / 21 * 0.85 + 0.12)) ** 0.5 for i in range(22)]
        parts.append(loft("body", spine, [max(0.2, 0.7 * p) for p in prof], [max(0.05, 0.16 * p) for p in prof]))
        parts.append(fin("fin", [(-0.65, 0, 0.6), (-0.9, 0, 0.3), (-0.95, 0, 0), (-0.9, 0, -0.3), (-0.65, 0, -0.6)]))
        parts.append(fin("fin", [(-0.2, 0, 0.55), (-0.45, 0, 1.25), (-0.6, 0, 0.5)]))
        parts.append(fin("fin", [(-0.2, 0, -0.55), (-0.45, 0, -1.25), (-0.6, 0, -0.5)]))
        parts += eyes(0.45, 0.15, 0.13, 0.08)
        parts.append(prim("torus", "mouth", (0.69, 0, -0.05), (0.03, 0.04, 0.03), rot=(0, math.pi / 2, 0), minor=0.35))
    elif fam == "flat":
        spine = [Vector((x, 0, 0)) for x in np.linspace(-0.8, 0.8, 24)]
        prof = [math.sin(math.pi * min(1, i / 23 * 0.92 + 0.05)) ** 0.6 for i in range(24)]
        b = loft("body", spine, [max(0.03, 0.08 * p) for p in prof], [max(0.08, 0.5 * p) for p in prof]); parts.append(b)
        parts.append(fin("fin", [(-0.78, 0, 0), (-1.1, 0, 0.0)]  and [(-0.75, -0.06, 0), (-1.1, -0.3, 0), (-1.0, 0, 0), (-1.1, 0.3, 0), (-0.75, 0.06, 0)]))
        parts[-1].rotation_euler = (math.pi / 2, 0, 0)
        for s in (1, -1):
            pts = [(x, 0, 0) for x in []]
        for s in (1, -1):
            parts.append(prim("sphere", "fin", (0.0, s * 0.48, 0), (0.62, 0.08, 0.02)))
        for s in (1, -1):
            parts.append(prim("sphere", "eyeW", (0.55, s * 0.08, 0.07), (0.07,) * 3))
            parts.append(prim("sphere", "pupil", (0.58, s * 0.09, 0.12), (0.04,) * 3))
        parts.append(prim("torus", "mouth", (0.79, 0.0, 0.0), (0.04, 0.05, 0.02), rot=(0, math.pi / 2, 0), minor=0.3))
    elif fam == "monk":
        spine = [Vector((x, 0, 0)) for x in np.linspace(-0.8, 0.7, 24)]
        prof = [(i / 23) ** 0.7 for i in range(24)]
        parts.append(loft("body", spine, [max(0.06, 0.28 * math.sin(math.pi * min(1, p * 0.95 + 0.03)) ** 0.6) for p in prof],
                          [max(0.06, 0.55 * p ** 1.5 * math.sin(math.pi * min(1, p * 0.9 + 0.08)) ** 0.3) for p in prof], sq=0.8))
        parts.append(tail_fin(-0.8, 0.18, fork=0.0, ln=0.3))
        parts.append(prim("sphere", "mouth", (0.62, 0, -0.04), (0.08, 0.38, 0.06)))
        for k in range(7): parts.append(prim("cone", "tooth", (0.63, -0.3 + k * 0.1, 0.0), (0.012, 0.012, 0.04), rot=(math.pi, 0, 0), seg=6))
        parts.append(tube("fin", [(0.4, 0, 0.25), (0.6, 0, 0.6), (0.8, 0, 0.62)], 0.015, 0.01))
        parts.append(prim("sphere", "blush", (0.82, 0, 0.62), (0.05,) * 3))
        parts += eyes(0.35, 0.22, 0.2, 0.08, top=True)
        for s in (1, -1):
            f = fin("fin", [(0.0, 0, 0), (-0.3, 0, -0.1), (-0.2, 0, 0.1)]); f.location = (0.0, s * 0.45, -0.1); f.rotation_euler = (s * 1.3, 0, 0); parts.append(f)
    elif fam == "crab":
        long = sp.get("longLegs")
        spine = [Vector((x, 0, 0.3)) for x in np.linspace(-0.45, 0.45, 18)]
        prof = [math.sin(math.pi * min(1, i / 17 * 0.9 + 0.05)) ** 0.5 for i in range(18)]
        parts.append(loft("body", spine, [max(0.05, 0.22 * p) for p in prof], [max(0.1, 0.62 * p) for p in prof], sq=0.8))
        for s in (1, -1):
            for k in range(4):
                bx = 0.25 - k * 0.18; L1 = 0.55 if long else 0.38
                a = Vector((bx, s * 0.5, 0.25)); b = Vector((bx - 0.05, s * (0.5 + L1), 0.42)); c = Vector((bx - 0.12, s * (0.55 + L1 * 1.6), 0.0))
                parts.append(tube("legs", [a, b], 0.05, 0.04)); parts.append(tube("legs", [b, c], 0.04, 0.015))
            # 钳子
            a = Vector((0.4, s * 0.35, 0.3)); b = Vector((0.65, s * 0.55, 0.35))
            parts.append(tube("legs", [a, b], 0.06, 0.06))
            parts.append(prim("sphere", "fin", (0.78, s * 0.6, 0.38), (0.16, 0.1, 0.1)))
            parts.append(prim("cone", "fin", (0.95, s * 0.6, 0.42), (0.05, 0.04, 0.09), rot=(0, math.pi / 2 - 0.2, 0)))
            parts.append(prim("cone", "fin", (0.93, s * 0.6, 0.32), (0.04, 0.035, 0.07), rot=(0, math.pi / 2 + 0.2, 0)))
            # 眼柄
            parts.append(tube("legs", [(0.38, s * 0.12, 0.42), (0.42, s * 0.14, 0.62)], 0.025))
            parts.append(prim("sphere", "eyeW", (0.42, s * 0.14, 0.66), (0.06,) * 3))
            parts.append(prim("sphere", "pupil", (0.46, s * 0.15, 0.68), (0.035,) * 3))
            parts.append(prim("sphere", "blush", (0.4, s * 0.3, 0.38), (0.06, 0.06, 0.03)))
        if sp.get("spiky"):
            for k in range(20):
                parts.append(prim("cone", "top", (random.uniform(-0.3, 0.3), random.uniform(-0.45, 0.45), 0.5), (0.025, 0.025, 0.05), seg=6))
        parts.append(prim("torus", "mouth", (0.45, 0, 0.27), (0.03, 0.05, 0.02), rot=(0, math.pi / 2, 0), minor=0.3))
    elif fam in ("shrimp", "lobster"):
        lob = fam == "lobster"; kr = sp.get("krill")
        spine, hs, ws = [], [], []
        for i in range(26):
            t = i / 25
            ang = (1 - t) * (1.6 if not lob else 0.5)
            spine.append(Vector((-0.2 + math.cos(math.pi / 2 + ang) * 0 + (t - 0.5) * 1.6 * math.cos(ang * 0.6), 0, -0.35 * (1 - t) ** 2 * (1.6 if not lob else 0.3))))
            hs.append(max(0.04, 0.2 * math.sin(math.pi * min(1, t * 0.85 + 0.12)) ** 0.6)); ws.append(max(0.04, (0.22 if lob else 0.17) * math.sin(math.pi * min(1, t * 0.85 + 0.12)) ** 0.6))
        parts.append(loft("body", spine, hs, ws))
        tail = spine[0]
        f = fin("fin", [(tail.x + 0.05, 0, tail.z), (tail.x - 0.25, -0.0, tail.z - 0.15), (tail.x - 0.3, 0, tail.z + 0.05)])
        parts.append(f)
        for s in (1, -1):
            parts.append(tube("fin", [spine[-1] + Vector((0, s * 0.05, 0.08)), spine[-1] + Vector((0.5, s * 0.35, 0.5)), spine[-1] + Vector((0.6, s * 0.6, 0.3))], 0.012, 0.005))
            for k in range(5 if not lob else 4):
                p = spine[8 + k * 3]
                parts.append(tube("legs", [p + Vector((0, s * 0.08, -0.1)), p + Vector((0.05, s * 0.22, -0.32))], 0.02, 0.01))
            if lob:
                parts.append(tube("legs", [spine[-4] + Vector((0, s * 0.15, -0.05)), spine[-1] + Vector((0.35, s * 0.35, -0.05))], 0.04, 0.03))
            parts.append(prim("sphere", "pupil", spine[-2] + Vector((0.02, s * 0.12, 0.12)), (0.055,) * 3))
            parts.append(prim("sphere", "eyeW", spine[-2] + Vector((0.05, s * 0.15, 0.15)), (0.016,) * 3))
    elif fam == "squid":
        g = sp.get("giant")
        spine = [Vector((x, 0, 0)) for x in np.linspace(-0.7, 0.3, 20)]
        prof = [math.sin(math.pi * min(1, (i / 19) * 0.55 + 0.02)) ** 0.6 for i in range(20)]
        parts.append(loft("body", spine, [max(0.05, 0.24 * p) for p in prof], [max(0.05, 0.24 * p) for p in prof]))
        parts.append(fin("fin", [(-0.72, 0, 0), (-0.45, 0.32, 0), (-0.3, 0, 0), (-0.45, -0.32, 0)])); parts[-1].rotation_euler = (math.pi / 2, 0, 0)
        parts.append(prim("sphere", "belly", (0.38, 0, 0), (0.14, 0.17, 0.17)))
        for s in (1, -1):
            parts.append(prim("sphere", "eyeW", (0.38, s * 0.15, 0.04), (0.08, 0.05, 0.08)))
            parts.append(prim("sphere", "pupil", (0.41, s * 0.19, 0.04), (0.05, 0.03, 0.055)))
        n = 8
        Ln = 1.3 if g else 0.6
        for k in range(n + 2):
            a = 2 * math.pi * k / n
            r = 0.1
            L2 = Ln * (1.6 if k >= n else 1.0)
            y, z = math.cos(a) * r, math.sin(a) * r
            parts.append(tube("top", [(0.48, y, z), (0.48 + L2 * 0.5, y * 2.2, z * 2.2 + 0.05 * math.sin(k)), (0.48 + L2, y * 1.6, z * 1.6 - 0.08)], 0.035, 0.008))
    elif fam == "octopus":
        parts.append(loft("body", [Vector((-0.05 - 0.45 * (1 - t), 0, 0.35 + 0.15 * (1 - t))) for t in np.linspace(0, 1, 18)],
                          [max(0.06, 0.38 * math.sin(math.pi * min(1, t * 0.9 + 0.1)) ** 0.6) for t in np.linspace(0, 1, 18)],
                          [max(0.06, 0.38 * math.sin(math.pi * min(1, t * 0.9 + 0.1)) ** 0.6) for t in np.linspace(0, 1, 18)]))
        for k in range(8):
            a = 2 * math.pi * k / 8 + 0.2
            d = Vector((math.cos(a), math.sin(a), 0))
            p0 = Vector((0.0, 0, 0.15)) + d * 0.15
            parts.append(tube("top", [p0, p0 + d * 0.4 + Vector((0, 0, -0.15)), p0 + d * 0.75 + Vector((0, 0, -0.05)), p0 + d * 0.9 + Vector((0, 0, 0.12))], 0.08, 0.015))
        for s in (1, -1):
            parts.append(prim("sphere", "eyeW", (0.25, s * 0.17, 0.42), (0.08,) * 3))
            parts.append(prim("sphere", "pupil", (0.31, s * 0.19, 0.42), (0.05,) * 3))
            parts.append(prim("sphere", "blush", (0.28, s * 0.26, 0.3), (0.05, 0.05, 0.03)))
    elif fam == "urchin":
        spine = [Vector((0, 0, z)) for z in np.linspace(-0.3, 0.3, 16)]
        prof = [math.sin(math.pi * min(1, i / 15 * 0.92 + 0.04)) ** 0.5 for i in range(16)]
        parts.append(loft("body", spine, [max(0.05, 0.42 * p) for p in prof], [max(0.05, 0.42 * p) for p in prof], side=Vector((1, 0, 0))))
        rnd = random.Random(3)
        for k in range(70):
            u = rnd.uniform(-0.9, 1); a = rnd.uniform(0, 2 * math.pi); r = math.sqrt(1 - u * u)
            d = Vector((r * math.cos(a), r * math.sin(a), u))
            p = d * 0.38
            o = prim("cone", "fin", p + d * 0.18, (0.022, 0.022, 0.2), seg=6)
            o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
            parts.append(o)
        for s in (1, -1):
            parts.append(prim("sphere", "eyeW", (0.38, s * 0.12, 0.1), (0.06,) * 3))
            parts.append(prim("sphere", "pupil", (0.42, s * 0.13, 0.1), (0.035,) * 3))
    elif fam == "abalone":
        spine = [Vector((x, 0, 0.1)) for x in np.linspace(-0.55, 0.55, 20)]
        prof = [math.sin(math.pi * min(1, i / 19 * 0.94 + 0.03)) ** 0.5 for i in range(20)]
        parts.append(loft("body", spine, [max(0.03, 0.2 * p * (0.6 + 0.4 * i / 19)) for i, p in enumerate(prof)], [max(0.05, 0.42 * p) for p in prof], sq=0.7))
        parts.append(prim("sphere", "belly", (0, 0, -0.02), (0.5, 0.36, 0.07)))
        for k in range(6): parts.append(prim("sphere", "pupil", (-0.3 + k * 0.1, 0.28, 0.22), (0.03, 0.03, 0.015)))
        for s in (1, -1):
            parts.append(prim("sphere", "eyeW", (0.52, s * 0.1, 0.05), (0.05,) * 3))
            parts.append(prim("sphere", "pupil", (0.56, s * 0.11, 0.05), (0.03,) * 3))
    elif fam == "dragon":
        spine, hs, ws = [], [], []
        for i in range(30):
            t = i / 29
            spine.append(Vector((-0.9 + 1.7 * t, 0, 0.35 * math.sin(t * 4) * (1 - t) - 0.2 * (1 - t) ** 3))); hs.append(max(0.02, 0.1 * math.sin(math.pi * min(1, t * 0.9 + 0.1)) ** 0.5)); ws.append(max(0.02, 0.07 * math.sin(math.pi * min(1, t * 0.9 + 0.1)) ** 0.5))
        parts.append(loft("body", spine, hs, ws))
        parts.append(tube("top", [spine[-1], spine[-1] + Vector((0.3, 0, -0.05))], 0.03, 0.02))
        for k in range(9):
            p = spine[3 + k * 3]
            for s in (1, -1):
                l = prim("sphere", "fin", p + Vector((0, s * 0.05, (0.15 if k % 2 else -0.12))), (0.11, 0.015, 0.05), rot=(s * 0.4, 0.6 * (1 if k % 2 else -1), 0))
                parts.append(l)
        parts += eyes(0.72, 0.06, 0.06, 0.05)
    return parts

def build_species(sid, sp, outdir):
    for o in list(bpy.data.objects): bpy.data.objects.remove(o)
    for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)
    random.seed(hash(sid) % 1000)
    img_arr = paint(sp, abs(hash(sid)) % 10000)
    parts = build(sid, sp)
    # 合并、归一化到长度 2（头朝 +X）
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = "Fish_" + sid; o.data.name = "Fish_" + sid
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bb = [Vector(c) for c in o.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb))); mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    ctr = (mn + mx) / 2; ext = max(mx.x - mn.x, (mx.y - mn.y) * 0.9, (mx.z - mn.z) * 0.9)
    s = 2.0 / ext
    for v in o.data.vertices: v.co = (v.co - ctr) * s
    for p in o.data.polygons: p.use_smooth = True
    # 贴图 + 材质
    img = bpy.data.images.new("Fish_%s_tex" % sid, TW, TH, alpha=False)
    rgba = np.concatenate([img_arr, np.ones((TH, TW, 1))], -1)[::-1]
    img.pixels[:] = rgba.astype(np.float32).ravel()
    path = os.path.join(outdir, "Fish_%s.png" % sid)
    img.filepath_raw = path; img.file_format = 'PNG'; img.save()
    m = bpy.data.materials.new("FishMat_" + sid); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.45
    t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.image = img
    m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
    o.data.materials.clear(); o.data.materials.append(m)
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.wm.usd_export(filepath=os.path.join(outdir, "Fish_%s.usdz" % sid), selected_objects_only=True, export_materials=True,
                          generate_preview_surface=True, export_textures=True, convert_orientation=True,
                          export_global_forward_selection='NEGATIVE_Z', export_global_up_selection='Y', export_uvmaps=True,
                          export_normals=True, evaluation_mode='RENDER', overwrite_textures=True, export_animation=False)
    print("FISH", sid, len(o.data.polygons))
    return o

bpy.ops.wm.read_factory_settings(use_empty=True)
for sid, sp in S.items():
    if ONLY and sid not in ONLY: continue
    build_species(sid, sp, OUT)
    if "--blend" in sys.argv: pass
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "fish_last.blend"))
print("DONE")
