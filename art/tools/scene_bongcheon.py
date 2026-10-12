"""Reference scene (samples #3/#11 preview): 봉천 계단마을, daytime, PC HUD.
640x360 native + x2/x3 previews. Layout: villa row -> upper alley -> retaining wall + stairs -> terrace garden -> main alley + gutter -> road."""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageChops
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import tiles_r01 as TR
import props_r01 as PR
from grid import parse, upscale

ROOT = os.path.dirname(os.path.dirname(__file__))
C = P.rgb
T = 32
W, H = 640, 360
tiles = TR.all_tiles()


def tile_at(kind, tx, ty):
    s = tx * 31 + ty * 17
    return {
        "slab": lambda: PR.concrete_slab(s),
        "gutter": lambda: PR.gutter(s),
        "dirt": lambda: TR.dirt(s, grass=s % 3),
        "dirtg": lambda: TR.dirt(s, grass=4 + s % 4),
        "asphalt": lambda: TR.asphalt(s),
        "wallcap": lambda: TR.wall_face(s, top=True),
        "wall": lambda: TR.wall_face(s + 5, top=False),
    }.get(kind, lambda: tiles[kind])()


ROWS = [
    ["slab"] * 20, ["slab"] * 20, ["slab"] * 20,                     # 0-2 (behind villas)
    ["slab"] * 20,                                                   # 3 upper alley
    ["wallcap"] * 9 + ["stairs_rail", "stairs"] + ["wallcap"] * 9,   # 4 retaining wall + stairs
    ["wall"] * 9 + ["stairs_rail", "stairs"] + ["wall"] * 9,         # 5
    ["dirtg", "dirt"] * 4 + ["dirt", "slab", "slab", "dirt"] + ["dirt", "dirtg"] * 4,   # 6 terrace garden
    ["dirt", "dirtg"] * 4 + ["dirt", "slab", "slab", "dirt"] + ["dirtg", "dirt"] * 4,   # 7
    ["slab"] * 20,                                                   # 8 main alley
    ["gutter"] * 20,                                                 # 9
    ["asphalt"] * 20, ["asphalt"] * 20,                              # 10-11 road
]


RUNTIME = True      # False = asset-only render for QA: shadows as one palette step, no region tone


def _step_region(img, box, mask=None):
    px = img.load()
    for y in range(max(0, box[1]), min(img.height, box[3])):
        for x in range(max(0, box[0]), min(img.width, box[2])):
            if mask is None or mask.getpixel((x - box[0], y - box[1])):
                r, g, b, a = px[x, y]
                px[x, y] = P.step((r, g, b), -1) + (a,)


def shade_rect(img, box, k=0.65):
    """Multiply-darken a region (runtime shadow layer, SD-16 §3.9)."""
    if not RUNTIME:
        return _step_region(img, box)
    reg = img.crop(box)
    reg = ImageChops.multiply(reg, Image.new("RGBA", reg.size, (int(255 * k),) * 3 + (255,)))
    img.paste(reg, box[:2])


def shadow_ellipse(img, cx, cy, w, h, k=0.6):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).ellipse([0, 0, w - 1, h - 1], fill=255)
    box = (cx - w // 2, cy - h // 2, cx - w // 2 + w, cy - h // 2 + h)
    if not RUNTIME:
        return _step_region(img, box, m)
    reg = img.crop(box)
    dark = ImageChops.multiply(reg, Image.new("RGBA", reg.size, (int(255 * k),) * 3 + (255,)))
    reg.paste(dark, (0, 0), m)
    img.paste(reg, box[:2])


def tint(img, r, g, b, grey):
    """Region daytime tone [R,G,B,grey] (SD-16 §4.4): runtime colour grade."""
    if not RUNTIME:
        return
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            R, G, B, A = px[x, y]
            L = (R * 299 + G * 587 + B * 114) // 1000
            R += (L - R) * grey // 255; G += (L - G) * grey // 255; B += (L - B) * grey // 255
            px[x, y] = (max(0, min(255, R + r)), max(0, min(255, G + g)), max(0, min(255, B + b)), A)


def build(hud=True):
    base = Image.new("RGBA", (W, H), C("P18") + (255,))
    for ty, row in enumerate(ROWS):
        for tx, kind in enumerate(row):
            base.alpha_composite(tile_at(kind, tx, ty), (tx * T, ty * T))

    # stepped alleys in the gaps between villas (climb further uphill)
    for gx, gw in ((104, 32), (264, 80), (472, 32)):
        base.alpha_composite(PR.gap_stairs(gw, 96), (gx, 0))
        shade_rect(base, (gx, 0, gx + 8, 96), 0.7)
    # villas (ground line y=96)
    for i, vx in enumerate([-24, 136, 344, 504]):
        v = PR.villa(seed=i * 7 + 3, door_at=(1, 2, 0, 3)[i])
        base.alpha_composite(v, (vx, 96 - v.height))
        shade_rect(base, (max(0, vx + 8), 96, min(W, vx + 136), 104), 0.72)
    base.alpha_composite(PR.store_sign(), (344 + 4, 96 - 30))      # 번개24 fascia over villa 3 ground floor
    base.alpha_composite(PR.poster(), (200, 140))                 # 2077 loyalty-registration poster
    base.alpha_composite(PR.poster(), (520, 146))
    shade_rect(base, (0, 192, 288, 200), 0.75)       # retaining wall shadow on terrace
    shade_rect(base, (352, 192, W, 200), 0.75)
    shade_rect(base, (352, 128, 360, 192), 0.8)      # stair cheek

    # clutter: basin planters on the upper alley and terrace (settlement crops)
    items = [(20, 100, 1, "leaf"), (44, 104, 2, "chili"), (200, 102, 3, "leaf"), (420, 100, 4, "chili"), (600, 104, 5, "leaf")]
    for i, x in enumerate([24, 56, 88, 120, 152, 200, 232]):
        for j, y in enumerate([200, 228]):
            if (i + j) % 3 != 2:
                items.append((x, y, i * 5 + j, "leaf" if (i + j) % 2 else "chili"))
    items += [(392, 200, 40, "leaf"), (424, 200, 41, "leaf"), (456, 200, 42, "chili")]
    for x, y, s, crop in sorted(items, key=lambda k: k[1]):
        shadow_ellipse(base, x + 12, y + 20, 22, 5, 0.7)
        base.alpha_composite(PR.basin_planter(s, crop), (x, y))
    for x in (504, 536, 568, 600):
        base.alpha_composite(tiles["scrap_barrier"], (x, 210))
    for name, x, y in [("granite_rock", 470, 222), ("drum", 8, 258), ("drum", 30, 264)]:
        shadow_ellipse(base, x + 18, y + 30, 22, 6, 0.7)
        base.alpha_composite(tiles[name], (x, y))

    # characters
    pc = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_S.txt"))
    roach = parse(os.path.join(ROOT, "src/sprites/cr_roach.txt"))["E_idle0"].transpose(Image.FLIP_LEFT_RIGHT)
    px, py = 300, 284
    shadow_ellipse(base, px, py, 14, 5, 0.6)
    base.alpha_composite(pc["idleE"], (px - 32, py - 60))
    rx, ry = 384, 292
    shadow_ellipse(base, rx, ry, 12, 4, 0.6)
    base.alpha_composite(roach, (rx - 16, ry - 26))

    # poles (in front of villas) + sagging wires over everything
    for x, y in [(120, 100), (456, 100)]:
        pole = PR.utility_pole()
        shadow_ellipse(base, x, y, 10, 4, 0.6)
        base.alpha_composite(pole, (x - 20, y - pole.height))
    PR.wires(base, [(-10, -2), (102, 0), (138, -2), (436, -4), (474, -2), (650, 2)], sag=14)

    tint(base, 8, 4, -8, 10)
    if hud:
        draw_hud(base)
    return base


def draw_hud(base):
    """PC HUD (SD-16 §9.1): Pip-Boy green, 1px U0 border, no backing panels."""
    F10 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
    F12 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri11.ttf"), 12)
    d = ImageDraw.Draw(base)
    d.fontmode = "1"
    U = lambda i: C(f"U{i}")

    def text(xy, s, font, col=5):
        x, y = xy
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            d.text((x + dx, y + dy), s, font=font, fill=U(0))
        d.text((x, y), s, font=font, fill=U(col))

    def bar(x, y, w, frac, label):
        d.rectangle([x - 1, y - 1, x + w, y + 6], fill=U(0))
        d.rectangle([x, y, x + w - 1, y + 5], fill=U(2))
        d.rectangle([x, y, x + int(w * frac) - 1, y + 5], fill=U(5))
        for k in range(1, 10):
            d.line([x + k * w // 10, y + 4, x + k * w // 10, y + 5], fill=U(1))
        text((x, y - 13), label, F10)

    bar(12, 332, 120, 0.82, "HP")
    bar(508, 332, 120, 0.64, "AP")
    text((568, 312), "12/48", F12)
    cx, cy = 200, 340
    d.rectangle([cx - 1, cy - 1, cx + 240, cy + 12], fill=U(0))
    d.rectangle([cx, cy, cx + 239, cy + 11], fill=U(1))
    for k in range(0, 240, 12):
        d.line([cx + k, cy + 8, cx + k, cy + 11], fill=U(3))
    for lab, off in (("서", 30), ("북", 120), ("동", 210)):
        text((cx + off - 4, cy), lab, F10, 6)
    d.rectangle([cx + 156, cy + 2, cx + 158, cy + 9], fill=C("P54"))
    d.polygon([(cx + 92, cy + 2), (cx + 96, cy + 6), (cx + 92, cy + 10), (cx + 88, cy + 6)], fill=U(6))
    text((8, 8), "장소 발견: 봉천 계단마을", F12, 6)
    text((8, 24), "+10 XP", F10, 5)
    text((292, 8), "[주의]", F12, 6)
    text((296, 132), "E 올라간다", F10, 6)


if __name__ == "__main__":
    out = os.path.join(ROOT, "samples")
    img = build()
    img.convert("RGB").save(os.path.join(out, "05_scene_bongcheon.png"))
    upscale(img, 2).convert("RGB").save(os.path.join(out, "05_scene_bongcheon_x2.png"))
    upscale(img, 3).convert("RGB").save(os.path.join(out, "05_scene_bongcheon_x3.png"))
    print("ok")
