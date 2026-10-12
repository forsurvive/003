"""R01 관악·봉천 exterior tiles (sample #3, first pass).
Clustered, palette-locked generators (no per-pixel noise; SD-16 §3.8) + hand-drawn structures.
Every tile is 32x32 RGBA. Run directly to write samples/03_tiles_r01*.png
"""
import os, sys, random
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import upscale, sheet, check

T = 32
C = P.rgb


def new(col=None):
    return Image.new("RGBA", (T, T), (C(col) + (255,)) if col else (0, 0, 0, 0))


def put(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), C(col) + (255,))


def blob(img, rnd, cx, cy, r, col, wrap=True):
    """Small organic cluster (2..r px), wrapping so tiles stay seamless."""
    pts = [(cx, cy)]
    n = rnd.randint(r, r * 2)
    for _ in range(n):
        x, y = rnd.choice(pts)
        dx, dy = rnd.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
        pts.append((x + dx, y + dy))
    for x, y in pts:
        if wrap:
            put(img, x % T, y % T, col)
        else:
            put(img, x, y, col)
    return pts


def dirt(seed=1, grass=0):
    rnd = random.Random(seed)
    img = new("P18")
    for _ in range(4):  # broad darker earth patches
        blob(img, rnd, rnd.randrange(T), rnd.randrange(T), 9, "P17")
    for _ in range(3):  # sunlit raised patches
        blob(img, rnd, rnd.randrange(T), rnd.randrange(T), 6, "P19")
    for _ in range(2):  # pebbles: 2px stone, lit top-left, contact shadow below
        x, y = rnd.randrange(T), rnd.randrange(T)
        put(img, x, y, "P07"); put(img, (x + 1) % T, y, "P06"); put(img, x, (y + 1) % T, "P16"); put(img, (x + 1) % T, (y + 1) % T, "P16")
    for _ in range(grass):  # dry grass tufts (lit tips, dark roots)
        x, y = rnd.randrange(T), rnd.randrange(3, T)
        shape = rnd.choice([[(0, 0), (-1, -1), (1, -1), (0, -2), (-2, -2), (2, -3)], [(0, 0), (1, -1), (-1, -1), (1, -2), (2, -3), (0, -3)]])
        for i, (dx, dy) in enumerate(shape):
            put(img, (x + dx) % T, (y + dy) % T, ["P29", "P31", "P31", "P20", "P21", "P32"][i])
        put(img, x % T, (y + 1) % T, "P16")
    return img


def asphalt(seed=2, lane=False):
    rnd = random.Random(seed)
    img = new("P04")
    for _ in range(10):
        blob(img, rnd, rnd.randrange(T), rnd.randrange(T), 3, "P03")
    for _ in range(5):
        blob(img, rnd, rnd.randrange(T), rnd.randrange(T), 2, "P05")
    if lane:  # faded centre dashes (paint worn: alternating paper / grey)
        for y in range(4, 28):
            put(img, 15, y, "P08" if y % 5 else "P06"); put(img, 16, y, "P07" if y % 4 else "P06")
    # crack: 1px line with 1:2 / 2:1 steps, lit lip on the upper-left
    x, y = rnd.randrange(4, 12), 0
    while y < T:
        put(img, x % T, y, "P01"); put(img, (x - 1) % T, y, "P05")
        y += 1
        if rnd.random() < 0.45:
            x += rnd.choice([-1, 1])
    for _ in range(3):  # weeds in the crack
        yy = rnd.randrange(T)
    return img


def pavers(seed=3, broken=2):
    rnd = random.Random(seed)
    img = new("P04")
    d = ImageDraw.Draw(img)
    for by in range(0, T, 8):
        off = 4 if (by // 8) % 2 else 0
        for bx in range(-8, T, 8):
            x0 = bx + off
            # each block: lit top-left edge, shaded bottom-right edge
            col = rnd.choice(["P05", "P05", "P06"])
            d.rectangle([x0, by, x0 + 7, by + 7], fill=C(col))
            d.line([x0, by, x0 + 6, by], fill=C("P07" if col == "P06" else "P06"))
            d.line([x0 + 7, by, x0 + 7, by + 7], fill=C("P04"))
            d.line([x0, by + 7, x0 + 7, by + 7], fill=C("P03"))
    for _ in range(broken):  # missing block -> earth showing through
        bx, by = rnd.randrange(0, 4) * 8 + (4 if rnd.random() < .5 else 0), rnd.randrange(0, 4) * 8
        d.rectangle([bx + 1, by + 1, bx + 6, by + 6], fill=C("P17"))
        d.line([bx + 1, by + 1, bx + 6, by + 1], fill=C("P16"))
        put(img, bx + 3, by + 4, "P31"); put(img, bx + 4, by + 3, "P30")
    return img


def stairs():
    """Concrete steps climbing north. 4 steps per tile: tread 5px (lit), riser 3px (shade)."""
    img = new("P06")
    for i in range(4):
        y = i * 8
        for x in range(T):
            put(img, x, y, "P08")          # nosing highlight
            for k in range(1, 5):
                put(img, x, y + k, "P07")  # tread
            put(img, x, y + 5, "P05")      # riser top (shadowed)
            put(img, x, y + 6, "P05")
            put(img, x, y + 7, "P04")      # riser bottom / contact shadow
        for x in (3, 4, 17, 25, 26):       # chips and wear on nosing
            put(img, x, y, "P06")
        put(img, 9 + i * 5, y + 2, "P06"); put(img, 10 + i * 5, y + 2, "P06")  # foot-worn hollow
    return img


def stair_rail_left():
    img = stairs()
    for y in range(T):  # cheek wall on the left with rusted handrail post
        put(img, 0, y, "P02"); put(img, 1, y, "P05"); put(img, 2, y, "P06")
    for y in range(0, T, 16):
        for k in range(10):
            put(img, 4, y + k, "P25" if k else "P26")
            put(img, 5, y + k, "P24")
    return img


def wall_face(seed=5, top=True):
    """Retaining wall, south face. Top 3px = cap (lit), then poured concrete with form lines and stains."""
    rnd = random.Random(seed)
    img = new("P06")
    d = ImageDraw.Draw(img)
    if top:
        d.rectangle([0, 0, T - 1, 2], fill=C("P08"))
        d.line([0, 3, T - 1, 3], fill=C("P05"))
    for y in (12, 22):  # formwork joints
        d.line([0, y, T - 1, y], fill=C("P05"))
        d.line([0, y + 1, T - 1, y + 1], fill=C("P07"))
    for _ in range(3):  # rust/water streaks running down
        x = rnd.randrange(2, T - 2)
        y0 = rnd.randrange(4, 14)
        for y in range(y0, min(T, y0 + rnd.randrange(8, 18))):
            put(img, x, y, "P20" if y < y0 + 3 else "P19")
    for _ in range(4):
        blob(img, rnd, rnd.randrange(T), rnd.randrange(5, T), 2, "P05")
    if rnd.random() < 0.35:  # hairline crack (not on every tile)
        x = rnd.randrange(8, 24)
        for y in range(5, 20):
            put(img, x, y, "P03")
            if y % 3 == 0:
                x += 1
    if rnd.random() < 0.5:  # weep-hole drain pipe with dark stain below
        x = rnd.randrange(6, 26)
        d.rectangle([x, 15, x + 3, 17], fill=C("P02")); d.line([x, 14, x + 3, 14], fill=C("P05"))
        for y in range(18, 26):
            put(img, x + 1, y, "P05")
        put(img, x + 2, 18, "P05")
    for _ in range(rnd.randint(0, 2)):  # moss at the foot
        x = rnd.randrange(T)
        put(img, x, T - 2, "P30"); put(img, (x + 1) % T, T - 2, "P29"); put(img, x, T - 3, "R01.b")
    d.line([0, T - 1, T - 1, T - 1], fill=C("P02"))  # ground contact line (SD-16 §3.7)
    return img


def brick_wall(window=False):
    """Villa wall: R01.d brick, 8x4 courses with mortar, optional aluminium window."""
    img = new("P26")
    d = ImageDraw.Draw(img)
    brick = C("R01.d")
    for row in range(8):
        y = row * 4
        off = 4 if row % 2 else 0
        for bx in range(-8, T, 8):
            x0 = bx + off
            d.rectangle([x0, y, x0 + 6, y + 2], fill=brick)
            d.line([x0, y, x0 + 5, y], fill=C("P27") if (row + bx) % 3 == 0 else brick)
            d.line([x0 + 6, y, x0 + 6, y + 2], fill=C("P25"))
        d.line([0, y + 3, T - 1, y + 3], fill=C("P07"))  # mortar course
    if window:
        d.rectangle([7, 6, 24, 25], fill=C("P05"))      # frame
        d.rectangle([8, 7, 23, 24], fill=C("P10"))      # dark glass
        d.line([15, 7, 15, 24], fill=C("P06")); d.line([16, 7, 16, 24], fill=C("P04"))
        d.line([8, 7, 14, 7], fill=C("R01.c"))          # sky reflection strip
        d.line([8, 8, 11, 8], fill=C("P14"))
        for x in range(9, 23, 2):                       # burglar bars (rusted)
            d.line([x, 7, x, 24], fill=C("P24"))
        d.rectangle([6, 26, 25, 27], fill=C("P07")); d.line([6, 28, 25, 28], fill=C("P04"))  # sill + shadow
    return img


def granite_rock(seed=7):
    """Boulder prop on transparent bg (R01.a granite), lit from upper-left."""
    rnd = random.Random(seed)
    img = new()
    d = ImageDraw.Draw(img)
    d.ellipse([3, 9, 28, 30], fill=C("P01"))
    d.ellipse([4, 10, 27, 29], fill=C("P06"))
    d.ellipse([5, 10, 22, 24], fill=C("P07"))
    d.ellipse([6, 11, 16, 18], fill=C("R01.a"))
    d.line([18, 13, 23, 20], fill=C("P05")); d.line([12, 22, 17, 26], fill=C("P05"))
    for _ in range(6):  # feldspar speckles in clusters of 2
        x, y = rnd.randrange(7, 24), rnd.randrange(12, 26)
        if img.getpixel((x, y))[3]:
            put(img, x, y, "P05"); put(img, x + 1, y, "P08")
    d.arc([4, 10, 27, 29], 20, 160, fill=C("P04"))
    return img


def scrap_barrier(seed=9):
    """Corrugated sheet barrier panel (south face): mixed rusted and grey sheets on posts."""
    rnd = random.Random(seed)
    img = new()
    sheets = [(0, 3, "rust"), (11, 1, "grey"), (21, 4, "rust")]
    for x0, y0, kind in sheets:
        w = 11
        ramp = ["P24", "P25", "P26"] if kind == "rust" else ["P04", "P05", "P06"]
        for x in range(x0, min(T, x0 + w)):
            for y in range(y0, T - 1):
                ph = (x - x0) % 3
                put(img, x, y, ramp[ph])
        for x in range(x0, min(T, x0 + w)):
            put(img, x, y0, "P01")
        for y in range(y0, T - 1):
            put(img, x0, y, "P01")
        for _ in range(3):
            blob(img, rnd, rnd.randrange(x0, x0 + w), rnd.randrange(y0 + 2, T - 2), 2, "P23" if kind == "grey" else "P27", wrap=False)
        put(img, x0 + 2, y0 + 3, "P09"); put(img, x0 + 8, y0 + 3, "P09")  # bolt heads
    for x in range(T):
        put(img, x, T - 1, "P01")
    return img


def drum():
    """Rusty oil drum prop (top ellipse + south face), 32x32."""
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([8, 10, 23, 29], fill=C("P01"))
    d.rectangle([9, 11, 22, 28], fill=C("P25"))
    d.rectangle([9, 11, 12, 28], fill=C("P26"))
    d.rectangle([19, 11, 22, 28], fill=C("P24"))
    for y in (16, 23):
        d.line([9, y, 22, y], fill=C("P23")); d.line([9, y - 1, 22, y - 1], fill=C("P27"))
    d.ellipse([8, 6, 23, 14], fill=C("P01"))
    d.ellipse([9, 7, 22, 13], fill=C("P24"))
    d.ellipse([10, 8, 21, 12], fill=C("P23"))
    d.point([(17, 9), (18, 9)], fill=C("P05"))  # bung
    d.line([9, 29, 22, 29], fill=C("P01"))
    # faded hazard stencil band (no readable text): yellow chevron block
    d.rectangle([13, 18, 18, 21], fill=C("P48"))
    d.line([13, 18, 18, 21], fill=C("P24"))
    return img


def all_tiles():
    return {
        "dirt_a": dirt(1), "dirt_b": dirt(4), "dirt_grass_a": dirt(2, grass=5), "dirt_grass_b": dirt(6, grass=8),
        "asphalt": asphalt(2), "asphalt_lane": asphalt(8, lane=True), "pavers": pavers(3), "pavers_b": pavers(11, 1),
        "stairs": stairs(), "stairs_rail": stair_rail_left(), "wall_face_cap": wall_face(5), "wall_face": wall_face(12, top=False),
        "brick": brick_wall(), "brick_window": brick_wall(True), "granite_rock": granite_rock(), "scrap_barrier": scrap_barrier(),
        "drum": drum(),
    }


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(__file__))
    tiles = all_tiles()
    allowed = P.allowed_set("R01")
    for n, im in tiles.items():
        pr = check(im, allowed)
        if pr:
            print(n, pr)
    bg = Image.new("RGBA", (T, T), C("P18") + (255,))
    shown = []
    for n, im in tiles.items():
        b = bg.copy() if im.getpixel((0, 0))[3] == 0 else Image.new("RGBA", (T, T))
        b.alpha_composite(im)
        shown.append(b)
    s = sheet(shown, 9, pad=2)
    s.save(os.path.join(root, "samples/03_tiles_r01.png"))
    upscale(s, 4).save(os.path.join(root, "samples/03_tiles_r01_x4.png"))
    print("ok", len(tiles))
