"""R01 prefabs and props for the 봉천 계단마을 reference scene (first pass).
All drawn with palette tokens only; transparent outside the silhouette."""
import os, sys, random
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import palette as P

C = P.rgb
T = 32


def _img(w, h, col=None):
    return Image.new("RGBA", (w, h), (C(col) + (255,)) if col else (0, 0, 0, 0))


def concrete_slab(seed=0):
    """Poured alley concrete: 16px slabs with expansion joints, stains, patch repairs."""
    rnd = random.Random(seed)
    img = _img(T, T, "P06")
    d = ImageDraw.Draw(img)
    for y in (0, 16):
        d.line([0, y, T - 1, y], fill=C("P05"))
        d.line([0, y + 1, T - 1, y + 1], fill=C("P07"))
    d.line([rnd.choice([10, 15, 21]), 2, rnd.choice([10, 15, 21]), 15], fill=C("P05"))
    for _ in range(rnd.randint(1, 3)):  # water stain / tyre mark
        x, y = rnd.randrange(T), rnd.randrange(2, T - 2)
        w = rnd.randint(3, 7)
        for k in range(w):
            d.point(((x + k) % T, y), fill=C("P05"))
            if k % 2:
                d.point(((x + k) % T, y + 1), fill=C("P05"))
    if rnd.random() < 0.35:  # asphalt patch repair
        x, y = rnd.randrange(2, 20), rnd.randrange(3, 22)
        d.rectangle([x, y, x + rnd.randint(5, 9), y + rnd.randint(3, 6)], fill=C("P04"))
    if rnd.random() < 0.5:  # weed in a joint
        x = rnd.randrange(T)
        d.point((x, 15), fill=C("P31")); d.point((x + 1, 14), fill=C("P32")); d.point((x - 1, 14), fill=C("P30"))
    return img


def gutter(seed=0):
    """Open concrete drain channel with steel grate segment (runs east-west)."""
    img = concrete_slab(seed)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 22, T - 1, 29], fill=C("P03"))
    d.line([0, 22, T - 1, 22], fill=C("P05"))
    d.line([0, 30, T - 1, 30], fill=C("P07"))
    d.rectangle([0, 25, T - 1, 27], fill=C("P34"))     # trickle of dirty water
    d.line([0, 25, T - 1, 25], fill=C("P35"))
    for x in range(2, T, 4):                            # grate bars
        d.line([x, 22, x, 29], fill=C("P02"))
    return img


def villa(seed=0, floors=2, door_at=1, sign=None):
    """Korean 다세대 빌라, 4 tiles wide: flat roof (green waterproof paint, parapet, water tank) + floors.
    Returns (image, ground_y). Facade = south face only (SD-16 §3.1)."""
    rnd = random.Random(seed)
    w = 4 * T
    roof_h = 30
    floor_h = 32
    h = roof_h + floors * floor_h
    img = _img(w, h)
    d = ImageDraw.Draw(img)
    # roof slab seen from above
    d.rectangle([0, 0, w - 1, roof_h - 1], fill=C("P31"))
    d.rectangle([3, 3, w - 4, roof_h - 6], fill=C("P30"))
    for _ in range(5):  # peeling paint showing concrete
        x, y = rnd.randrange(6, w - 12), rnd.randrange(5, roof_h - 9)
        d.rectangle([x, y, x + rnd.randint(2, 6), y + rnd.randint(1, 2)], fill=C("P07"))
    d.rectangle([0, 0, w - 1, 2], fill=C("P08"))                       # parapet top (lit)
    d.rectangle([0, 0, 2, roof_h - 1], fill=C("P07"))
    d.rectangle([w - 3, 0, w - 1, roof_h - 1], fill=C("P05"))
    d.rectangle([0, roof_h - 5, w - 1, roof_h - 1], fill=C("P06"))     # parapet front edge
    d.line([0, roof_h - 1, w - 1, roof_h - 1], fill=C("P04"))
    tx = rnd.choice([10, 80])                                           # rooftop water tank (rusted)
    d.ellipse([tx, 4, tx + 22, 18], fill=C("P01")); d.ellipse([tx + 1, 5, tx + 21, 17], fill=C("P25"))
    d.ellipse([tx + 4, 7, tx + 18, 14], fill=C("P26")); d.ellipse([tx + 7, 8, tx + 12, 11], fill=C("P27"))
    # facade floors
    for f in range(floors):
        y0 = roof_h + f * floor_h
        brick = "R01.d"
        d.rectangle([0, y0, w - 1, y0 + floor_h - 1], fill=C("P26"))
        for row in range(8):
            y = y0 + row * 4
            off = 4 if row % 2 else 0
            for bx in range(-8, w, 8):
                x0 = bx + off
                d.rectangle([x0, y, x0 + 6, y + 2], fill=C(brick))
                d.line([x0 + 6, y, x0 + 6, y + 2], fill=C("P25"))
            d.line([0, y + 3, w - 1, y + 3], fill=C("P07"))
        d.rectangle([0, y0, w - 1, y0 + 1], fill=C("P07"))             # floor slab band
        d.line([0, y0 + 2, w - 1, y0 + 2], fill=C("P05"))
        ground = f == floors - 1
        for i, wx in enumerate((8, 40, 72, 104)):
            if ground and i == door_at:
                # entrance: aluminium-framed glass door + canopy + house number plate (no glyphs)
                d.rectangle([wx - 2, y0 + 5, wx + 19, y0 + floor_h - 1], fill=C("P05"))
                d.rectangle([wx, y0 + 7, wx + 17, y0 + floor_h - 1], fill=C("P10"))
                d.line([wx + 8, y0 + 7, wx + 8, y0 + floor_h - 1], fill=C("P06"))
                d.line([wx + 9, y0 + 7, wx + 9, y0 + floor_h - 1], fill=C("P04"))
                d.line([wx, y0 + 8, wx + 6, y0 + 8], fill=C("R01.c"))
                d.rectangle([wx - 4, y0 + 3, wx + 21, y0 + 5], fill=C("P13"))  # canopy
                d.line([wx - 4, y0 + 6, wx + 21, y0 + 6], fill=C("P11"))
                d.rectangle([wx + 20, y0 + 10, wx + 23, y0 + 12], fill=C("P45"))  # blue number plate
                continue
            if rnd.random() < 0.12:
                continue  # bricked-up window
            d.rectangle([wx, y0 + 7, wx + 17, y0 + 24], fill=C("P05"))
            glass = rnd.choice(["P10", "P10", "P11"])
            d.rectangle([wx + 1, y0 + 8, wx + 16, y0 + 23], fill=C(glass))
            d.line([wx + 8, y0 + 8, wx + 8, y0 + 23], fill=C("P06"))
            d.line([wx + 1, y0 + 8, wx + 6, y0 + 8], fill=C("R01.c"))
            d.point((wx + 2, y0 + 9), fill=C("P14"))
            if rnd.random() < 0.5:   # burglar bars
                for x in range(wx + 2, wx + 16, 3):
                    d.line([x, y0 + 8, x, y0 + 23], fill=C("P24"))
            if rnd.random() < 0.4:   # torn curtain inside
                d.rectangle([wx + 10, y0 + 9, wx + 15, y0 + 18], fill=C("P20"))
            d.rectangle([wx - 1, y0 + 25, wx + 18, y0 + 26], fill=C("P07"))
            d.line([wx - 1, y0 + 27, wx + 18, y0 + 27], fill=C("P04"))
        # gas pipe running along the facade (yellow, realistic Korean detail)
        gx = rnd.choice([30, 62, 94])
        d.line([gx, y0, gx, y0 + floor_h - 1], fill=C("P48"))
        d.line([gx + 1, y0, gx + 1, y0 + floor_h - 1], fill=C("P47"))
        if ground:
            d.rectangle([gx - 3, y0 + 18, gx + 3, y0 + 25], fill=C("P05"))   # gas meter box
            d.rectangle([gx - 2, y0 + 19, gx + 2, y0 + 21], fill=C("P08"))
    d.line([0, h - 1, w - 1, h - 1], fill=C("P02"))
    d.line([w - 1, roof_h, w - 1, h - 1], fill=C("P24"))
    return img


def utility_pole():
    """Concrete telephone/power pole, 3.5 tiles tall, crossarm + transformer can. Origin bottom-centre (8, h)."""
    w, h = 40, 112
    img = _img(w, h)
    d = ImageDraw.Draw(img)
    cx = 20
    d.rectangle([cx - 2, 10, cx + 2, h - 1], fill=C("P07"))
    d.line([cx - 2, 10, cx - 2, h - 1], fill=C("P08"))
    d.line([cx + 2, 10, cx + 2, h - 1], fill=C("P05"))
    d.line([cx - 3, 10, cx - 3, h - 1], fill=C("P01")); d.line([cx + 3, 10, cx + 3, h - 1], fill=C("P01"))
    for y in range(40, h - 6, 6):  # climbing steps
        d.line([cx - 5, y, cx - 3, y], fill=C("P04"))
    d.rectangle([2, 12, w - 3, 14], fill=C("P05")); d.line([2, 12, w - 3, 12], fill=C("P06"))  # crossarm
    d.line([2, 15, w - 3, 15], fill=C("P01"))
    for x in (4, 13, 27, 36):  # insulators
        d.rectangle([x - 1, 9, x + 1, 11], fill=C("P09")); d.point((x, 8), fill=C("P08"))
    d.rectangle([cx + 4, 22, cx + 13, 36], fill=C("P01"))  # transformer can
    d.rectangle([cx + 5, 23, cx + 12, 35], fill=C("P05"))
    d.line([cx + 5, 23, cx + 5, 35], fill=C("P06"))
    d.line([cx + 5, 29, cx + 12, 29], fill=C("P04"))
    d.rectangle([cx - 1, 60, cx + 1, 72], fill=C("P09"))   # pasted notice sheets (no glyphs)
    d.rectangle([cx - 2, 64, cx + 1, 70], fill=C("P08"))
    d.point((cx, 66), fill=C("P53"))
    d.line([cx - 3, h - 1, cx + 3, h - 1], fill=C("P01"))
    return img


def basin_planter(seed=0, crop="leaf"):
    """Red rubber basin (고무 대야) used as a planter: 20x14 + plants."""
    rnd = random.Random(seed)
    img = _img(24, 22)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 8, 22, 15], fill=C("P01"))
    d.rectangle([2, 12, 21, 19], fill=C("P01"))
    d.rectangle([3, 12, 20, 18], fill=C("P53"))
    d.line([3, 12, 3, 18], fill=C("P54")); d.line([20, 12, 20, 18], fill=C("P52"))
    d.ellipse([2, 9, 21, 14], fill=C("P54"))
    d.ellipse([4, 10, 19, 13], fill=C("P17"))            # soil
    d.line([2, 20, 21, 20], fill=C("P01"))
    if crop == "leaf":  # lettuce / perilla clumps
        for _ in range(5):
            x, y = rnd.randrange(5, 18), rnd.randrange(3, 10)
            d.ellipse([x - 2, y - 2, x + 2, y + 1], fill=C("R01.b"))
            d.point((x - 1, y - 2), fill=C("P31")); d.point((x, y - 1), fill=C("P32"))
    else:  # chilli on stakes
        for x in (7, 12, 17):
            d.line([x, 2, x, 11], fill=C("P19"))
            d.point((x - 1, 4), fill=C("R01.b")); d.point((x + 1, 6), fill=C("R01.b")); d.point((x - 1, 8), fill=C("P31"))
            d.point((x + 1, 7), fill=C("P53")); d.point((x + 1, 8), fill=C("P52"))
    return img


def wires(img, poles, sag=10, col="P01"):
    """Draw sagging cables between pole tops (list of (x, y))."""
    d = ImageDraw.Draw(img)
    for (x0, y0), (x1, y1) in zip(poles, poles[1:]):
        for k in range(3):
            pts = []
            n = max(2, abs(x1 - x0))
            for i in range(n + 1):
                t = i / n
                x = x0 + (x1 - x0) * t
                y = y0 + (y1 - y0) * t + sag * 4 * t * (1 - t) + k * 3
                pts.append((round(x), round(y)))
            d.line(pts, fill=C(col))


def _font(size=8):
    from PIL import ImageFont
    root = os.path.dirname(os.path.dirname(__file__))
    return ImageFont.truetype(os.path.join(root, "fonts/Galmuri7.ttf"), size)


def poster(kind="loyalty"):
    """2077 government poster pasted on concrete (faded, torn corner). Static prop, may contain glyphs."""
    img = _img(30, 36)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.rectangle([0, 0, 29, 35], fill=C("P01"))
    d.rectangle([1, 1, 28, 34], fill=C("P08"))
    d.rectangle([1, 1, 28, 10], fill=C("P53"))                  # red header band
    f = _font(8)
    if kind == "loyalty":
        d.text((3, 1), "충성", font=f, fill=C("P09"))
        d.ellipse([8, 13, 21, 26], fill=C("P45"))                # emblem: blue disc + amber keyhole
        d.rectangle([13, 16, 16, 23], fill=C("P59")); d.ellipse([12, 15, 17, 19], fill=C("P59"))
        d.text((3, 26), "등록", font=f, fill=C("P02"))
    d.polygon([(22, 35), (29, 28), (29, 35)], fill=C("P06"))     # torn corner
    d.line([2, 20, 6, 31], fill=C("P07"))                        # weather streak
    return img


def store_sign(text="번개24"):
    """Convenience-store fascia (청솔식품 번개24): orange band, white glyphs, lightning mark."""
    f = _font(8)
    w = 56
    img = _img(w, 12)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.rectangle([0, 0, w - 1, 11], fill=C("P01"))
    d.rectangle([1, 1, w - 2, 10], fill=C("P27"))
    d.line([1, 1, w - 2, 1], fill=C("P50"))
    d.polygon([(4, 2), (8, 2), (6, 5), (9, 5), (4, 10), (6, 6), (3, 6)], fill=C("P50"))  # lightning
    d.text((12, 1), text, font=f, fill=C("P09"))
    d.point((w - 6, 3), fill=C("P24")); d.point((w - 5, 8), fill=C("P24"))   # rust dots
    return img


def gap_stairs(w, h):
    """Narrow stepped alley climbing north between villas (fills a gap)."""
    img = _img(w, h, "P05")
    d = ImageDraw.Draw(img)
    for y in range(0, h, 8):
        d.line([0, y, w - 1, y], fill=C("P07"))
        d.rectangle([0, y + 1, w - 1, y + 4], fill=C("P06"))
        d.rectangle([0, y + 5, w - 1, y + 7], fill=C("P04"))
    d.line([0, 0, 0, h - 1], fill=C("P02")); d.line([w - 1, 0, w - 1, h - 1], fill=C("P02"))
    return img
