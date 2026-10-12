"""Preview frames of a grid file at scale on a background. Usage: preview.py <grid.txt> <out.png> [scale] [bg token]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import grid, palette
src, out = sys.argv[1], sys.argv[2]
k = int(sys.argv[3]) if len(sys.argv) > 3 else 6
bg = palette.rgb(sys.argv[4]) + (255,) if len(sys.argv) > 4 else (110, 100, 80, 255)
fr = grid.parse(src)
imgs = list(fr.values())
sh = grid.sheet(imgs, min(len(imgs), 8), pad=4, bg=bg)
grid.upscale(sh, k).save(out)
allowed = palette.allowed_set("S3", "H1", "UI")
for n, im in fr.items():
    p = grid.check(im, allowed)
    if p: print(n, p)
print("frames:", list(fr))
