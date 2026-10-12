"""Reference sample #12: effects (SD-16 §10). No outlines (§3.7); additive sprites are drawn in palette colours and
composited with additive blending in previews (the engine does the same).
- muzzle flash: pistol, 16 directions x 3 frames (16x16), pre-baked per angle (no runtime rotation)
- bullet: 2x1 slug + 4px trail, 16 directions
- melee trails (48x48 x 3): one-hand slash, thrust, two-hand swing, fist impact
- hit: white silhouette flash (1 tick), blood spatter x3, metal sparks, insect slime, critical star
- slime death: roach bursts into the shared green slime pile (debris sprite)
- vault door opening: white flash over the S-07 gate, dissolving into the first view of Seoul (key art)
Writes samples/19_fx_sheet_x4.png, 19_fx_combat.gif, 19_fx_vault_door.gif (+ 19_fx_vault_door_strip.png)."""
import os, sys, math, random
from PIL import Image, ImageDraw, ImageChops, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import upscale, parse, check

ROOT = os.path.dirname(os.path.dirname(__file__))
CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)
F10 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
DIRS16 = [i * 22.5 for i in range(16)]     # 0 = east, clockwise on screen (y down)


def put(img, x, y, tok):
    x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))      # round half up (round() alternates on .5)
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), C(tok))


# ---------------------------------------------------------------- muzzle flash + bullet
def muzzle(angle, frame, size=16):
    """Star cone along the barrel: core P09/P50, petals P60, rim P27. frame 0 big, 1 split, 2 fading.
    Inverse-mapped: every output pixel is tested against the cone in barrel space (no gaps at 45 degrees)."""
    img = Image.new("RGBA", (size, size), CLEAR)
    c = size // 2 - 1
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    L = [6.5, 5.0, 3.0][frame]
    W = [3.0, 2.2, 1.2][frame]
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            t = dx * ux + dy * uy                    # along the barrel
            s = -dx * uy + dy * ux                   # across
            if t < -1.2 or t > L + 0.5:
                continue
            width = W * (1 - max(0, t) / (L + 0.5)) + (0.7 if t < 1 else 0)
            tok = None
            if abs(s) <= width:
                core = abs(s) < width * 0.45 and t < L * 0.6
                tok = ("P09" if frame == 0 else "P50") if core else ("P60" if frame < 2 else "P27")
            elif frame < 2 and -0.6 < t < 1.6 and width < abs(s) <= width + 3 - frame:
                tok = "P60" if abs(s) < width + 1.6 else "P27"    # side petals
            if tok and not (frame == 2 and (x + y) % 2):
                img.putpixel((x, y), C(tok))
    return img


def bullet(angle, size=16):
    img = Image.new("RGBA", (size, size), CLEAR)
    c = size // 2 - 1
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    for k, tok in ((1, "P09"), (0, "P50"), (-1, "P60"), (-2, "P60"), (-3, "P27"), (-4, "P27"), (-5, "P58")):
        if k <= -4 and k % 2:
            continue
        put(img, c + k * ux + 2, c + k * uy, tok)
    return img


# ---------------------------------------------------------------- melee trails (48x48, 3 frames)
def arc_band(img, cx, cy, r, a0, a1, width, toks, fade=0):
    steps = max(8, int(abs(a1 - a0) / 3))
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(a0 + (a1 - a0) * t)
        w = max(1, int(round(width * (0.3 + 0.7 * t))))     # thickens toward the leading edge
        for k in range(w):
            rr = r - k
            tok = toks[min(len(toks) - 1, k)]
            if fade and (i + k) % 2:
                continue
            put(img, cx + rr * math.cos(a), cy + rr * math.sin(a), tok)


def melee(kind, frame):
    img = Image.new("RGBA", (48, 48), CLEAR)
    toks = ("P09", "P08", "P07")
    if kind == "slash":            # one-hand: short arc
        spans = [(-110, -40), (-80, 10), (-30, 40)]
        a0, a1 = spans[frame]
        arc_band(img, 20, 26, 18, a0, a1, 3, toks, fade=frame == 2)
    elif kind == "thrust":         # straight streaks
        L = [10, 18, 22][frame]
        for k in range(L):
            for j, tok in ((-1, "P08"), (0, "P09"), (1, "P08")):
                if frame == 2 and k % 2:
                    continue
                if k > L - 4 or j == 0:
                    put(img, 10 + k, 24 + j, tok)
        for j in (-3, 3):
            for k in range(L // 2):
                put(img, 12 + k * 2, 24 + j, "P07")
    elif kind == "swing":          # two-hand: wide arc
        spans = [(-150, -60), (-120, 20), (-60, 60)]
        a0, a1 = spans[frame]
        arc_band(img, 22, 26, 21, a0, a1, 5, toks + ("P07",), fade=frame == 2)
    elif kind == "fist":           # impact burst
        r = [3, 6, 9][frame]
        for a in range(0, 360, 30):
            ra = math.radians(a)
            for k in range(2):
                if frame == 2 and k == 0:
                    continue
                put(img, 24 + (r + k) * math.cos(ra), 24 + (r + k) * math.sin(ra), "P09" if k == 0 else "P08")
        if frame == 0:
            for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
                put(img, 24 + dx, 24 + dy, "P09")
    return img


# ---------------------------------------------------------------- hit effects
def splat(seed, ramp, size=16, n=7):
    """Spatter: a central blot + droplets thrown away from the hit direction (east -> west spray)."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size, size), CLEAR)
    c = size // 2
    for x in range(c - 2, c + 2):
        for y in range(c - 1, c + 2):
            put(img, x, y, ramp[1])
    put(img, c - 1, c - 1, ramp[2])
    for _ in range(n):
        a = math.radians(rnd.uniform(140, 220))
        d = rnd.uniform(3, c - 1)
        x, y = c + d * math.cos(a), c + d * math.sin(a)
        put(img, x, y, ramp[0] if d > c / 2 else ramp[1])
        if rnd.random() < 0.5:
            put(img, x + 1, y, ramp[1])
    return img


BLOOD = ("P51", "P52", "P53")
SLIME = ("P29", "P31", "P57")


def sparks(frame, size=16):
    img = Image.new("RGBA", (size, size), CLEAR)
    c = size // 2
    for k, a in enumerate((150, 190, 215, 240, 120)):
        r = 2 + frame * 2 + k % 2
        ra = math.radians(a)
        put(img, c + r * math.cos(ra), c + r * math.sin(ra), "P50" if frame < 2 else "P60")
        if frame == 0:
            put(img, c + (r - 1) * math.cos(ra), c + (r - 1) * math.sin(ra), "P09")
    return img


def crit_star(frame, size=32):
    img = Image.new("RGBA", (size, size), CLEAR)
    c = size // 2
    L = [12, 9, 5][frame]
    for a in range(0, 360, 45):
        ra = math.radians(a)
        ln = L if a % 90 == 0 else L * 0.55
        for k in range(int(ln)):
            put(img, c + k * math.cos(ra), c + k * math.sin(ra), "P09" if k < ln * 0.5 else "P50")
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            put(img, c + dx, c + dy, "P09")
    return img


def white_flash(sprite):
    """Hit flash: the sprite's silhouette in white for one tick (FX layer over the sprite)."""
    out = Image.new("RGBA", sprite.size, CLEAR)
    px, po = sprite.load(), out.load()
    for y in range(sprite.height):
        for x in range(sprite.width):
            if px[x, y][3]:
                po[x, y] = C("P09")
    return out


# ---------------------------------------------------------------- slime death (roach)
def roach():
    g = parse(os.path.join(ROOT, "src/sprites/cr_roach.txt"))
    return list(g.values())[0].transpose(Image.FLIP_LEFT_RIGHT)


def slime_pile(seed=3, w=20):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (32, 16), CLEAR)
    for x in range(16 - w // 2, 16 + w // 2):
        h = int(3 * math.sin(math.pi * (x - (16 - w // 2)) / w)) + rnd.choice((0, 0, 1))
        for y in range(12 - h, 13):
            put(img, x, y, "P29" if y > 12 - h + 1 else "P31")
        put(img, x, 13, "P28")
    for x, y in ((12, 9), (17, 8), (21, 10)):
        put(img, x, y, "P57")                                  # wet highlights
    for x, y in ((6, 12), (25, 12), (27, 11), (4, 13)):
        put(img, x, y, "P30")                                  # droplets
    for x, y in ((14, 11), (18, 11), (15, 12)):
        put(img, x, y, "P17")                                  # shell bits
    return img


def slime_death():
    r = roach()
    frames = []
    base = Image.new("RGBA", (32, 32), CLEAR)
    base.alpha_composite(r)
    f0 = base.copy(); f0.alpha_composite(white_flash(r))                       # hit flash
    frames.append(f0)
    f1 = Image.new("RGBA", (32, 32), CLEAR)                                     # swell: squash 1px up
    f1.alpha_composite(r, (0, 1))
    frames.append(f1)
    f2 = Image.new("RGBA", (32, 32), CLEAR)                                     # burst
    f2.alpha_composite(splat(11, SLIME, 32, 18), (0, 2))
    f2.alpha_composite(slime_pile(4, 12), (0, 16))
    frames.append(f2)
    f3 = Image.new("RGBA", (32, 32), CLEAR)
    f3.alpha_composite(splat(12, SLIME, 32, 10), (0, 4))
    f3.alpha_composite(slime_pile(5, 18), (0, 16))
    frames.append(f3)
    f4 = Image.new("RGBA", (32, 32), CLEAR)
    f4.alpha_composite(slime_pile(3, 20), (0, 16))
    frames.append(f4)
    return frames


# ---------------------------------------------------------------- composites
def add(base, fx, xy):
    """Additive composite of an FX sprite (engine blend mode)."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.alpha_composite(fx, xy)
    rgb = ImageChops.add(base.convert("RGB"), Image.composite(layer.convert("RGB"), Image.new("RGB", base.size), layer.split()[3]))
    out = rgb.convert("RGBA")
    return out


def sheet():
    W = 16 * 20 + 16
    sh = Image.new("RGBA", (W, 300), C("P02"))
    d = ImageDraw.Draw(sh); d.fontmode = "1"
    y = 4
    d.text((4, y), "총구 화염 16방향", font=F10, fill=C("P08")); y += 12
    for i, a in enumerate(DIRS16):
        sh.alpha_composite(muzzle(a, 0), (8 + i * 20, y))
    y += 20
    d.text((4, y), "탄환 16방향", font=F10, fill=C("P08")); y += 12
    for i, a in enumerate(DIRS16):
        sh.alpha_composite(bullet(a), (8 + i * 20, y))
    y += 20
    d.text((4, y), "총구 화염 3프레임(동)  ·  피 튐 3종  ·  금속 불꽃  ·  점액", font=F10, fill=C("P08")); y += 12
    x = 8
    for f in range(3):
        sh.alpha_composite(muzzle(0, f), (x, y)); x += 20
    x += 8
    for s in (1, 2, 3):
        sh.alpha_composite(splat(s, BLOOD), (x, y)); x += 20
    x += 8
    for f in range(3):
        sh.alpha_composite(sparks(f), (x, y)); x += 20
    x += 8
    sh.alpha_composite(splat(7, SLIME), (x, y)); x += 28
    for f in range(3):
        sh.alpha_composite(crit_star(f).resize((16, 16), Image.NEAREST) if False else crit_star(f).crop((8, 8, 24, 24)), (x, y)); x += 20
    y += 24
    d.text((4, y), "근접 궤적: 한손 베기 · 찌르기 · 양손 휘두름 · 주먹 충격 (각 3프레임)", font=F10, fill=C("P08")); y += 12
    x = 4
    for kind in ("slash", "thrust", "swing", "fist"):
        for f in range(3):
            sh.alpha_composite(melee(kind, f).crop((0, 4, 48, 44)), (x, y)); x += 26 if False else 0
            x += 26
        x += 4
    y += 44
    d.text((4, y), "점액 사망: 피격 섬광 → 부풂 → 터짐 → 퍼짐 → 공용 잔해(녹 점액 더미)", font=F10, fill=C("P08")); y += 12
    for i, f in enumerate(slime_death()):
        sh.alpha_composite(f, (8 + i * 40, y))
    y += 36
    d.text((4, y), "피격 흰 실루엣(1틱)", font=F10, fill=C("P08")); y += 12
    r = roach()
    sh.alpha_composite(r, (8, y)); sh.alpha_composite(white_flash(r), (48, y))
    return sh.crop((0, 0, W, y + 34))


def combat_gif():
    """PC fires the pistol at a roach on the S-07 floor: flash, bullet, hit, slime death."""
    import tiles_s07 as TS
    import weapons as WP
    floor = Image.new("RGBA", (192, 80))
    for tx in range(6):
        for ty in range(3):
            floor.alpha_composite(TS.panel_floor((tx + ty) % 5), (tx * 32, ty * 32))
    ups, fulls = WP.bases("T01", None)
    shooter = [WP.aim_frame("pistol", "E", f, ups, fulls) for f in range(4)]
    rch = roach(); death = slime_death()
    frames, durs = [], []
    hand = (52, 24)                                              # muzzle point in scene coords
    tx, ty = 150, 52
    timeline = [("aim", 300), ("fire0", 40), ("fire1", 40), ("b1", 40), ("b2", 40), ("hit", 60), ("d1", 80), ("d2", 80),
                ("d3", 120), ("d4", 600)]
    for i, (st, ms) in enumerate(timeline):
        fr = floor.copy()
        sf = shooter[1] if st in ("fire0", "fire1") else shooter[0]
        fr.alpha_composite(sf, (0, 66 - 60))
        if st.startswith("d"):
            k = int(st[1])
            fr.alpha_composite(death[k], (tx - 16, ty - 26))
        elif st == "hit":
            fr.alpha_composite(death[0], (tx - 16, ty - 26))
        else:
            fr.alpha_composite(rch, (tx - 16, ty - 26))
        mx, my = 48, 43 - (1 if st in ("fire0", "fire1") else 0)    # pistol muzzle tip (E pose, scene coords)
        if st == "fire0":
            fr = add(fr, muzzle(0, 0), (mx - 7, my - 7))
        if st == "fire1":
            fr = add(fr, muzzle(0, 1), (mx - 7, my - 7))
            fr = add(fr, bullet(0), (mx + 12 - 7, my - 7))
        if st in ("b1", "b2"):
            fr = add(fr, bullet(0), (mx + 40 + (st == "b2") * 36 - 7, 43 - 7))
        if st == "hit":
            fr = add(fr, sparks(0), (tx - 12, ty - 22))
            fr.alpha_composite(splat(7, SLIME), (tx - 10, ty - 16))
            fr = add(fr, crit_star(0), (tx - 22, ty - 30))
        frames.append(upscale(fr, 3).convert("P", palette=Image.ADAPTIVE)); durs.append(ms)
    frames[0].save(os.path.join(ROOT, "samples", "19_fx_combat.gif"), save_all=True, append_images=frames[1:], duration=durs, loop=0)


def vault_door_gif():
    """MQ-P4 S7 '첫 풍경': the gear door rolls aside, white light floods in, dissolves into the key art."""
    import tiles_s07 as TS
    import keyart as KA
    W, H = 640, 360
    room = Image.new("RGBA", (W, H), C("P10"))
    fr_ = TS.gear_door_frame()
    room.alpha_composite(fr_, ((W - fr_.width) // 2, 40))
    for x in range(0, W, 32):                                   # grate floor strip
        for y in (264, 296, 328):
            room.alpha_composite(TS.grate((x // 32 + y) % 3), (x, y))
    door_c = (W // 2, 40 + 108)
    key = KA.build()
    frames, durs, strip = [], [], []
    for k in range(18):
        im = room.copy()
        # door rolls to the right over the first 6 frames
        roll = min(1.0, k / 6)
        door = TS.gear_door(k % 8)
        dx = int(roll * 210)
        hole = int(roll * 96)
        # light through the opening: white disc growing behind the door
        if k >= 2:
            glow = Image.new("RGBA", (W, H), CLEAR)
            gd = ImageDraw.Draw(glow)
            r = 20 + hole + max(0, k - 6) * 40
            for i, tok in enumerate(("P15", "P08", "P09")):
                rr = r - i * 10
                if rr > 0:
                    gd.ellipse([door_c[0] - rr, door_c[1] - rr, door_c[0] + rr, door_c[1] + rr], fill=C(tok))
            im = add(im, glow, (0, 0)) if k < 8 else im
            if k >= 8:
                im.alpha_composite(glow)
        im.alpha_composite(door, (door_c[0] - 96 + dx, door_c[1] - 96))
        # whiteout, then a checker dissolve into the first view of Seoul
        if k >= 9:
            white = Image.new("RGBA", (W, H), C("P09"))
            im.alpha_composite(white)
        if k >= 11:
            t = (k - 11) / 6
            m = Image.new("L", (W, H), 0)
            px = m.load()
            bayer = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
            for y in range(H):
                for x in range(W):
                    if bayer[y % 4][x % 4] < t * 16:
                        px[x, y] = 255
            im = Image.composite(key, im, m)
        frames.append(upscale(im, 1).convert("P", palette=Image.ADAPTIVE))
        durs.append(90 if k < 8 else (300 if k == 9 else 110))
        if k in (0, 3, 6, 9, 13, 17):
            strip.append(im.resize((W // 4, H // 4), Image.NEAREST))
    durs[-1] = 1500
    frames[0].save(os.path.join(ROOT, "samples", "19_fx_vault_door.gif"), save_all=True, append_images=frames[1:], duration=durs, loop=0)
    s = Image.new("RGBA", (len(strip) * (W // 4 + 4), H // 4), C("P02"))
    for i, f in enumerate(strip):
        s.alpha_composite(f, (i * (W // 4 + 4), 0))
    s.save(os.path.join(ROOT, "samples", "19_fx_vault_door_strip.png"))


if __name__ == "__main__":
    out = os.path.join(ROOT, "samples")
    sh = sheet()
    bad = check(sh, P.allowed_set())
    upscale(sh, 4).save(os.path.join(out, "19_fx_sheet_x4.png"))
    combat_gif()
    vault_door_gif()
    print("fx sheet off-palette:", bad or 0)
