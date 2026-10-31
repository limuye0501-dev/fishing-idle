# 用 CI 模拟器截图合成 6.9" App Store 宣传图（1320x2868）
# 用法：python3 tools/appstore_shots.py <截图目录> <输出目录>
import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
src, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
W, H = 1320, 2868
F = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
SHOTS = [
 ("demo-tab0.png", "小熊船长自己出海打鱼", "Bear captains fish on their own"),
 ("demo-offline.png", "离线也在赚，回来收钱", "Earn while you're away"),
 ("demo-tab2.png", "解锁 8 片真实海域", "Explore 8 real-world seas"),
 ("ency-sardine.png", "收集 32 种真实鱼类", "Collect 32 real fish species"),
 ("demo-tab4.png", "打造你的私人鱼缸", "Build your own aquarium"),
]
def grad():
    g = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(g)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(166 + (74 - 166) * t), int(235 + (166 - 235) * t), int(221 + (216 - 221) * t)))
    return g
for lang in ("zh", "en"):
    for i, (f, zh, en) in enumerate(SHOTS):
        p = os.path.join(src, f if lang == "zh" else "en-" + f)
        if not os.path.exists(p): continue
        img = grad(); d = ImageDraw.Draw(img)
        cap = zh if lang == "zh" else en
        size = 110 if lang == "zh" else 92
        font = ImageFont.truetype(F, size)
        tw = d.textlength(cap, font=font)
        while tw > W - 120:
            size -= 4; font = ImageFont.truetype(F, size); tw = d.textlength(cap, font=font)
        d.text(((W - tw) / 2 + 4, 214), cap, font=font, fill=(40, 90, 110))
        d.text(((W - tw) / 2, 210), cap, font=font, fill="white")
        sh = Image.open(p).convert("RGB")
        sw = int(W * 0.80); shh = int(sh.height * sw / sh.width)
        sh = sh.resize((sw, shh), Image.LANCZOS)
        r = 70
        m = Image.new("L", (sw, shh), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, sw, shh], r, fill=255)
        x, y = (W - sw) // 2, 420
        shadow = Image.new("L", (W, H), 0); ImageDraw.Draw(shadow).rounded_rectangle([x, y + 20, x + sw, y + shh + 20], r, fill=110)
        img.paste((30, 70, 90), (0, 0), shadow.filter(ImageFilter.GaussianBlur(30)))
        ImageDraw.Draw(img).rounded_rectangle([x - 14, y - 14, x + sw + 14, y + shh + 14], r + 14, fill="white")
        img.paste(sh, (x, y), m)
        img.save(os.path.join(out, f"appstore-{lang}-{i+1}.png"))
print("done")
