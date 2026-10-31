# v5：手绘风程序化材质（烘焙进贴图集）：木板纹理、旧漆+边缘磨损、麻绳、金属
import bpy
from common import srgb

class NB:
    def __init__(self, m):
        self.nt = m.node_tree; self.n = self.nt.nodes; self.l = self.nt.links
        self.bsdf = self.n["Principled BSDF"]
    def node(self, t, **kw):
        x = self.n.new(t)
        for k, v in kw.items():
            if k in x.inputs: x.inputs[k].default_value = v
            else: setattr(x, k, v)
        return x
    def link(self, a, b): self.l.new(a, b)
    def coord(self, kind="Object"):
        if not hasattr(self, "_tc"): self._tc = self.node("ShaderNodeTexCoord")
        return self._tc.outputs[kind]
    def mix(self, fac, a, b, blend='MIX'):
        m = self.node("ShaderNodeMix", data_type='RGBA', blend_type=blend)
        for i, v in ((0, fac), (6, a), (7, b)):
            if isinstance(v, (float, int)): m.inputs[i].default_value = v
            elif isinstance(v, tuple): m.inputs[i].default_value = (*srgb(v), 1)
            else: self.link(v, m.inputs[i])
        return m.outputs[2]
    def ramp(self, fac, stops):
        r = self.node("ShaderNodeValToRGB"); self.link(fac, r.inputs[0])
        els = r.color_ramp.elements
        while len(els) < len(stops): els.new(0.5)
        for e, (p, c) in zip(els, stops): e.position = p; e.color = (*srgb(c), 1) if len(c) == 3 else c
        return r.outputs[0]
    def noise(self, scale, detail=4, rough=0.6, vec=None, dist=0.0):
        t = self.node("ShaderNodeTexNoise"); t.inputs["Scale"].default_value = scale
        t.inputs["Detail"].default_value = detail; t.inputs["Roughness"].default_value = rough; t.inputs["Distortion"].default_value = dist
        self.link(vec or self.coord(), t.inputs["Vector"]); return t.outputs["Fac"]
    def bump(self, h, strength=0.3, dist=0.02):
        b = self.node("ShaderNodeBump"); b.inputs["Strength"].default_value = strength; b.inputs["Distance"].default_value = dist
        self.link(h, b.inputs["Height"]); self.link(b.outputs["Normal"], self.bsdf.inputs["Normal"])
    def wear(self):
        """边缘磨损系数：几何凸起处（pointiness）+ 噪声"""
        g = self.node("ShaderNodeNewGeometry")
        mr = self.node("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = 0.53; mr.inputs["From Max"].default_value = 0.66
        self.link(g.outputs["Pointiness"], mr.inputs["Value"])
        n = self.noise(9, 6, 0.7)
        nm = self.node("ShaderNodeMapRange"); nm.inputs["From Min"].default_value = 0.45; nm.inputs["From Max"].default_value = 0.62
        self.link(n, nm.inputs["Value"])
        m = self.node("ShaderNodeMath", operation='MULTIPLY'); self.link(mr.outputs[0], m.inputs[0]); self.link(nm.outputs[0], m.inputs[1])
        # 随机小刮痕
        s = self.noise(26, 2, 0.5)
        sm = self.node("ShaderNodeMapRange"); sm.inputs["From Min"].default_value = 0.76; sm.inputs["From Max"].default_value = 0.79
        self.link(s, sm.inputs["Value"])
        a = self.node("ShaderNodeMath", operation='MAXIMUM', use_clamp=True); self.link(m.outputs[0], a.inputs[0]); self.link(sm.outputs[0], a.inputs[1])
        return a.outputs[0]

def painted(name, base, under=(0.55, 0.38, 0.24), wear_amt=1.0):
    """手绘旧漆：低频笔触色差 + 污渍 + 边缘露出木色"""
    m = bpy.data.materials.new(name); m.use_nodes = True; b = NB(m)
    b.bsdf.inputs["Roughness"].default_value = 0.6
    col = base_color_node(b, base)
    return finish_paint(b, col, under, wear_amt, m)

def base_color_node(b, base):
    v = b.noise(1.6, 3, 0.5)
    lighter = tuple(min(1, c * 1.07 + 0.02) for c in base); darker = tuple(c * 0.86 for c in base)
    c = b.ramp(v, [(0.3, darker), (0.7, lighter)])
    # 竖向流痕/污渍
    vec = b.node("ShaderNodeMapping"); vec.inputs["Scale"].default_value = (6, 6, 0.6); b.link(b.coord(), vec.inputs["Vector"])
    st = b.noise(3, 3, 0.5, vec.outputs[0])
    sm = b.node("ShaderNodeMapRange"); sm.inputs["From Min"].default_value = 0.55; sm.inputs["From Max"].default_value = 0.8; sm.inputs["To Max"].default_value = 0.22
    b.link(st, sm.inputs["Value"])
    return b.mix(sm.outputs[0], c, (0.45, 0.36, 0.30), 'MULTIPLY')

def finish_paint(b, col, under, wear_amt, m):
    w = b.wear()
    wm = b.node("ShaderNodeMath", operation='MULTIPLY', use_clamp=True); b.link(w, wm.inputs[0]); wm.inputs[1].default_value = wear_amt
    out = b.mix(wm.outputs[0], col, under)
    b.link(out, b.bsdf.inputs["Base Color"])
    hb = b.node("ShaderNodeMath", operation='MULTIPLY'); b.link(wm.outputs[0], hb.inputs[0]); hb.inputs[1].default_value = -1
    b.bump(hb.outputs[0], 0.4, 0.01)
    return m

def wood(name, base=(0.70, 0.48, 0.30), planks=True, plank_w=0.22):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = NB(m)
    b.bsdf.inputs["Roughness"].default_value = 0.7
    dark = tuple(c * 0.62 for c in base); light = tuple(min(1, c * 1.15) for c in base)
    # 木纹：拉伸噪声 + 波纹
    mp = b.node("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (0.6, 9, 9); b.link(b.coord(), mp.inputs["Vector"])
    wave = b.node("ShaderNodeTexWave", wave_type='BANDS', bands_direction='Y'); wave.inputs["Scale"].default_value = 2.5
    wave.inputs["Distortion"].default_value = 6; wave.inputs["Detail"].default_value = 3
    b.link(mp.outputs[0], wave.inputs["Vector"])
    grain = b.ramp(wave.outputs["Fac"], [(0.25, dark), (0.6, base), (0.95, light)])
    col = grain
    if planks:
        br = b.node("ShaderNodeTexBrick"); br.inputs["Scale"].default_value = 1.0
        br.inputs["Mortar Size"].default_value = 0.012; br.inputs["Brick Width"].default_value = 1.8; br.inputs["Row Height"].default_value = plank_w
        br.inputs["Color1"].default_value = (1, 1, 1, 1); br.inputs["Color2"].default_value = (0.72, 0.72, 0.72, 1)
        br.inputs["Mortar"].default_value = (*srgb((0.22, 0.13, 0.08)), 1); br.offset = 0.5
        mp2 = b.node("ShaderNodeMapping"); mp2.inputs["Rotation"].default_value = (0, 0, 0); b.link(b.coord(), mp2.inputs["Vector"])
        b.link(mp2.outputs[0], br.inputs["Vector"])
        col = b.mix(1.0, grain, br.outputs["Color"], 'MULTIPLY')
        b.bump(br.outputs["Fac"], 0.5, 0.02)
    else:
        b.bump(wave.outputs["Fac"], 0.15, 0.01)
    # 风化：边缘变浅
    w = b.wear()
    col = b.mix(w, col, tuple(min(1, c * 1.3 + 0.08) for c in base))
    b.link(col, b.bsdf.inputs["Base Color"])
    return m

def rope(name, base=(0.84, 0.72, 0.52)):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = NB(m)
    b.bsdf.inputs["Roughness"].default_value = 0.9
    wave = b.node("ShaderNodeTexWave", wave_type='BANDS', bands_direction='DIAGONAL'); wave.inputs["Scale"].default_value = 40
    wave.inputs["Distortion"].default_value = 1.5
    b.link(b.coord(), wave.inputs["Vector"])
    c = b.ramp(wave.outputs["Fac"], [(0.2, tuple(x * 0.65 for x in base)), (0.8, base)])
    b.link(c, b.bsdf.inputs["Base Color"]); b.bump(wave.outputs["Fac"], 0.6, 0.01)
    return m

def metal(name, base, rough=0.35):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = NB(m)
    b.bsdf.inputs["Roughness"].default_value = rough; b.bsdf.inputs["Metallic"].default_value = 0.0
    n = b.noise(6, 5, 0.7)
    c = b.ramp(n, [(0.35, tuple(x * 0.7 for x in base)), (0.65, base)])
    w = b.wear(); c = b.mix(w, c, tuple(min(1, x * 1.35) for x in base))
    b.link(c, b.bsdf.inputs["Base Color"])
    return m

def textured(C):
    M = {}
    for k in ('cream', 'teal', 'tealDark', 'navy', 'coral', 'white', 'orange', 'green', 'keel'):
        M[k] = painted(k + "P", C[k], wear_amt=0.9 if k != 'white' else 0.5)
    M['wood'] = wood("woodT", C['wood'], planks=False)
    M['woodDark'] = wood("woodDarkT", C['woodDark'], planks=False)
    M['deck'] = wood("deckT", C['wood'], planks=True)
    M['rope'] = rope("ropeT", C['rope'])
    M['brass'] = metal("brassT", C['brass'], 0.3)
    M['charcoal'] = metal("charT", C['charcoal'], 0.5)
    M['rust'] = metal("rustT", (0.45, 0.28, 0.18), 0.7)
    return M
