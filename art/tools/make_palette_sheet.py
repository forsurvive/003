"""Sample #1: palette sheet (SD-16 §4). Output native 640x360-family sheet + x2 preview."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import upscale

ROOT = os.path.dirname(os.path.dirname(__file__))
F9 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
F11 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri11.ttf"), 12)
W, H = 640, 470
img = Image.new("RGB", (W, H), P.rgb("P01"))
d = ImageDraw.Draw(img)
d.fontmode = "1"
ink, paper, dim = P.rgb("P09"), P.rgb("P08"), P.rgb("P06")
d.text((8, 4), "폴아웃 : 서울 팔레트 시트 (SD-16 §4)", font=F11, fill=paper)
ramps = [("잉크·중성", 0, 10), ("냉회청", 10, 6), ("흙·황토", 16, 7), ("녹·적갈", 23, 5), ("올리브", 28, 5),
         ("물", 33, 5), ("피부 S3", 38, 5), ("볼트 청", 43, 4), ("볼트 황", 47, 4), ("경고 적", 51, 4),
         ("방사능", 55, 3), ("앰버", 58, 3), ("청록", 61, 3)]
y = 22
for name, s, n in ramps:
    d.text((8, y + 3), name, font=F9, fill=dim)
    for k in range(n):
        x = 70 + k * 40
        d.rectangle([x, y, x + 37, y + 15], fill=P.rgb(f"P{s + k:02d}"))
        d.text((x + 2, y + 17), f"P{s + k:02d}", font=F9, fill=dim)
    y += 30 if name != "잉크·중성" else 30
# right column: skin, hair, region, UI
x0 = 480
d.text((x0, 22), "피부·구울", font=F9, fill=dim)
yy = 34
for k, v in P.SKIN.items():
    d.text((x0, yy), k, font=F9, fill=dim)
    for i, c in enumerate(v):
        d.rectangle([x0 + 24 + i * 14, yy, x0 + 36 + i * 14, yy + 9], fill=P.rgb(c))
    yy += 12
d.text((x0, yy + 4), "머리색", font=F9, fill=dim)
yy += 16
for k, v in P.HAIR.items():
    d.text((x0, yy), k, font=F9, fill=dim)
    for i, c in enumerate(v):
        d.rectangle([x0 + 24 + i * 14, yy, x0 + 36 + i * 14, yy + 9], fill=P.rgb(c))
    yy += 12
d.text((x0, yy + 4), "UI 핍-보이 / 관제망", font=F9, fill=dim)
yy += 16
for row in (P.UI_GREEN, P.UI_AMBER):
    for i, c in enumerate(row):
        d.rectangle([x0 + i * 18, yy, x0 + 16 + i * 18, yy + 9], fill=P.rgb(c))
    yy += 12
# region strip at bottom
y = H - 30
d.text((8, y - 12), "권역 보조색 R01~R11", font=F9, fill=dim)
for r, (k, v) in enumerate(P.REGION.items()):
    x = 8 + r * 57
    d.text((x, y + 12), k, font=F9, fill=dim)
    for i, c in enumerate(v):
        d.rectangle([x + i * 13, y, x + 11 + i * 13, y + 10], fill=P.rgb(c))
out = os.path.join(ROOT, "samples")
img.save(os.path.join(out, "01_palette_sheet.png"))
upscale(img.convert("RGBA"), 2).save(os.path.join(out, "01_palette_sheet_x2.png"))
print("ok")
