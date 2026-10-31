# 合成：Blender 透明渲染 + AI 绘制天空（天空图的海平线在高度 0.89 处）
import sys
from PIL import Image
render, sky, out = sys.argv[1:4]
r = Image.open(render).convert("RGBA"); hz = float(open(render + ".hz").read())
W, H = r.size; s = Image.open(sky).convert("RGB")
scale = max(W / s.width, (hz * H) / (0.89 * s.height)) * 1.02
s = s.resize((int(s.width * scale), int(s.height * scale)), Image.LANCZOS)
top = int(0.89 * s.height - hz * H); left = (s.width - W) // 2
bg = s.crop((left, top, left + W, top + H)).convert("RGBA")
bg.alpha_composite(r); bg.convert("RGB").save(out, quality=92)
