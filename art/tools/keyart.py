"""Key art pic_keyart_first_seoul (SD-16 §12.3 #13, §13.6): 관악산 비탈에서 처음 내려다본 서울.
640x360 picture. Late-afternoon light from the west (left), haze thickening with distance.
Reads left->right as the real view north from 관악산: 여의도(금탑, 무너진 국회 돔) - 노들섬·한강대교 - 남산 송신탑 - 강남 세진전자 타워.
Only palette colours; 2x2 checker dither for gradients (§3.8). Writes samples/09_keyart_first_seoul(.png, _x2)."""
import os, sys, math, random
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import parse, upscale, check

ROOT = os.path.dirname(os.path.dirname(__file__))
W, H = 640, 360
FAR_ONLY = False  # True: 먼 풍경만(첫 풍경 컷신 배경)
CX = 320  # viewer's horizontal position (side faces flip around it)
_cache = {}


def C(t):
    if t not in _cache:
        _cache[t] = P.rgb(t) + (255,)
    return _cache[t]


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (W, H), C("P14"))
        self.px = self.img.load()

    def put(self, x, y, t):
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = C(t)

    def rect(self, x0, y0, x1, y1, t):
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                self.px[x, y] = C(t)

    def checker(self, x0, y0, x1, y1, a, b):
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                self.px[x, y] = C(a if (x + y) % 2 else b)

    def hline(self, x0, x1, y, t):
        self.rect(x0, y, x1, y, t)

    def vline(self, x, y0, y1, t):
        self.rect(x, y0, x, y1, t)

    def get(self, x, y):
        return self.px[x, y]


# ---------------------------------------------------------------- sky
SKY = [  # (y_start, token): solid bands, a 4px checker seam between neighbours
    (0, "P13"), (34, "P14"), (70, "P15"), (98, "P08"), (118, "P22"), (140, "P21"),
]


def sky(cv):
    for i, (y0, t) in enumerate(SKY):
        y1 = SKY[i + 1][0] - 1 if i + 1 < len(SKY) else 175
        cv.rect(0, y0, W - 1, y1, t)
        if i:
            cv.checker(0, y0 - 2, W - 1, y0 + 1, t, SKY[i - 1][1])
    # warm glow low in the west (sun is off-frame left, behind the viewer's shoulder)
    for y in range(80, 150):
        for x in range(0, 260):
            d = ((x + 40) / 300) ** 2 + ((y - 150) / 70) ** 2
            if d < 0.55:
                if y >= 98:
                    cv.put(x, y, "P21" if d < 0.25 else ("P22" if (x + y) % 2 or d < 0.4 else cv_tok(cv, x, y)))
    # long stratus streaks: lit top edge, flat body, darker belly
    rnd = random.Random(7)
    for (x0, y0, ln, th) in [(30, 34, 170, 3), (150, 44, 120, 2), (380, 30, 200, 3), (470, 52, 150, 2),
                             (230, 70, 140, 2), (520, 78, 110, 2), (10, 64, 90, 2), (300, 18, 120, 2)]:
        cloud(cv, x0, y0, ln, th, rnd)


def cv_tok(cv, x, y):
    """Token of the current pixel (only used for sky glow edges): fall back to band token."""
    for i in range(len(SKY) - 1, -1, -1):
        if y >= SKY[i][0]:
            return SKY[i][1]
    return SKY[0][1]


def cloud(cv, x0, y0, ln, th, rnd):
    band = cv_tok(cv, 0, y0)
    lighter = {"P13": "P14", "P14": "P15", "P15": "P08", "P08": "P09", "P22": "P08", "P21": "P22"}[band]
    darker = {"P13": "P12", "P14": "P13", "P15": "P14", "P08": "P15", "P22": "P21", "P21": "P20"}[band]
    x = x0
    segs = []
    while x < x0 + ln:
        w = rnd.randint(14, 40)
        segs.append((x, w, rnd.randint(-1, 1)))
        x += w - rnd.randint(2, 8)
    for sx, sw, dy in segs:
        t = th + (1 if sw > 28 else 0)
        y = y0 + dy
        cv.hline(sx + 3, sx + sw - 3, y - 1, lighter)
        cv.rect(sx, y, sx + sw, y + t - 1, lighter)
        cv.hline(sx + 2, sx + sw - 2, y + t, darker)
        # warm sunlit left tips
        cv.hline(sx, sx + 4, y, "P09" if band in ("P15", "P08", "P14") else lighter)


# ---------------------------------------------------------------- ridges (mountains / hills)
def ridge_line(points, jitter, seed, step=3):
    """Piecewise-linear ridge through (x, y) control points with stair-stepped jitter."""
    rnd = random.Random(seed)
    ys = [9999.0] * W
    for i in range(len(points) - 1):
        (xa, ya), (xb, yb) = points[i], points[i + 1]
        for x in range(max(0, xa), min(W, xb + 1)):
            t = (x - xa) / max(1, xb - xa)
            ys[x] = ya + (yb - ya) * t
    j = 0
    out = []
    for x in range(W):
        if x % step == 0:
            j = rnd.randint(-jitter, jitter)
        out.append(int(round(ys[x] + j)))
    return out


def mountain(cv, ridge, base, lit, body, shade, top_lit=None, faces=(), depth=6):
    """Hazy silhouette: flat body, a sunlit rim stepping down the west-facing slopes, a shade rim on the
    east-facing ones, and a few bare granite faces under the main peaks (polygon facets)."""
    sm = []
    for x in range(W):
        win = [ridge[i] for i in range(max(0, x - 3), min(W, x + 4)) if ridge[i] < 9000]
        sm.append(sum(win) / len(win) if win else 9999)
    for x in range(W):
        y0 = ridge[x]
        if y0 >= base:
            continue
        cv.rect(x, y0, x, base, body)
        a, b = sm[max(0, x - 2)], sm[min(W - 1, x + 2)]
        sl = (b - a) / 4 if a < 9000 and b < 9000 else 0
        d = depth // 2 + int(round(1.5 * math.sin(x / 11) + math.sin(x / 4.3)))
        if sl < -0.15:
            cv.rect(x, y0, x, min(base, y0 + d), lit)
        elif sl > 0.15:
            cv.rect(x, y0 + 1, x, min(base, y0 + 2), shade)
        if top_lit and sl <= 0.15:
            cv.put(x, y0, top_lit)
    for px, py, w, h in faces:   # granite face: lit wedge on the west, shaded wedge on the east of a crease
        for i in range(h):
            y = py + i
            half = int(w * (i + 1) / h)
            for x in range(px - half, px + half // 2 + 1):
                if 0 <= x < W and ridge[x] < y <= base:
                    cv.put(x, y, lit if x < px else shade)
            if (i + px) % 3 == 0:
                cv.put(px - half // 2, y, body)


# ---------------------------------------------------------------- buildings
def building(cv, x, base, w, h, tones, rnd, side=None, win=(2, 3), broken=0, stair=False, number=None):
    """Apartment / office block. tones = (lit, body, shade, window, roof).
    side: width of the visible side face; it is on the right (east, shaded) left of the viewer
    and on the left (west, sunlit) right of the viewer."""
    lit, body, shade, wint, roof = tones
    top = base - h
    if side is None:
        side = max(0, min(4, int(abs(x + w / 2 - CX) / 80)))
    # damage: jagged top cut
    cut = [0] * (w + side)
    if broken:
        a = rnd.randint(0, w // 2)
        for i in range(w + side):
            d = abs(i - a)
            cut[i] = max(0, broken - d // 2 + rnd.randint(-1, 1)) if d < broken * 2 else 0
    if x + w / 2 < CX:   # front face, then shaded side to the right
        fx, sx, scol = x, x + w, shade
    else:                # sunlit side to the left, then front face
        fx, sx, scol = x + side, x, lit
    for i in range(w):
        cx = fx + i
        yt = top + cut[i]
        cv.vline(cx, yt, base, body)
        cv.put(cx, yt, roof)
    for i in range(side):
        cx = sx + i
        k = i if sx > fx else side - 1 - i
        yt = top + cut[min(len(cut) - 1, w + k)] + (k if sx > fx else 0) // 2
        cv.vline(cx, yt, base, scol)
        cv.put(cx, yt, roof)
    if sx < fx:   # west edge of the front face catches light
        cv.vline(fx, top + cut[0], base, lit)
    wx, wy = win
    if h >= 24 and w >= 14:
        # 아파트 front: per floor a pale balcony slab, a dark glass band, wall; some balconies blown out
        for yy in range(top + 2, base - 1, 3):
            for i in range(1, w - 1):
                if yy <= top + cut[i] + 1:
                    continue
                cv.put(fx + i, yy, roof if i > 1 else lit)
                if rnd.random() < 0.93:
                    cv.put(fx + i, yy + 1, wint)
            if rnd.random() < 0.25:                         # burnt-out unit: soot streak up the facade
                i = rnd.randint(2, max(2, w - 4))
                for k in range(rnd.randint(3, 8)):
                    if yy - k > top + cut[i] + 1:
                        cv.put(fx + i, yy - k, wint)
                        cv.put(fx + i + 1, yy - k + 1, shade)
    else:
        # windows: rows of 1px slots, floors every win[1] px
        for yy in range(top + 2, base - 1, wy):
            for i in range(1, w - 1, wx):
                if yy > top + cut[i] + 1 and rnd.random() < 0.9:
                    cv.put(fx + i, yy, wint)
    if broken:   # exposed dark floors under the cut
        for i in range(w):
            if cut[i] > 1:
                cv.vline(fx + i, top + cut[i], top + cut[i] + 1, wint)
    if stair and w > 16:   # stairwell column
        sx2 = fx + w // 2
        cv.vline(sx2, top + 1 + cut[w // 2], base, shade)
    if number and h > 30:
        glyphs(cv, fx + w // 2 - 6, top + 4 + max(cut), number, lit if sx > fx else roof)


DIG = {  # 3x5 digits for painted apartment block numbers
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
}


def glyphs(cv, x, y, s, t):
    for k, ch in enumerate(s):
        for r, row in enumerate(DIG[ch]):
            for c, v in enumerate(row):
                if v == "1":
                    cv.put(x + k * 4 + c, y + r, t)


def city_row(cv, x0, x1, base, hmin, hmax, wmin, wmax, tones, seed, broken_p=0.0, gap=(0, 3), skip=(), number_p=0.0):
    rnd = random.Random(seed)
    x = x0
    while x < x1:
        w = rnd.randint(wmin, wmax)
        h = rnd.randint(hmin, hmax)
        if not any(a <= x <= b for a, b in skip):
            b = rnd.randint(2, max(3, h // 3)) if rnd.random() < broken_p else 0
            num = str(rnd.randint(101, 118)) if rnd.random() < number_p else None
            building(cv, x, base + rnd.randint(-1, 1), w, h, tones, rnd, broken=b, stair=w > 24, number=num)
        x += w + rnd.randint(*gap)


# ---------------------------------------------------------------- landmarks
def namsan(cv):
    # wooded hill: dark olive-grey body, crown bumps lit from the west
    ridge = ridge_line([(326, 178), (344, 160), (362, 146), (380, 134), (398, 124), (412, 120), (426, 122), (444, 130), (458, 134), (474, 146), (494, 160), (520, 178)], 1, 31)
    for x in range(326, 521):
        cv.rect(x, ridge[x], x, 178, "P12")
    rnd = random.Random(5)
    mountain(cv, ridge, 178, "P13", "P12", "P11", depth=10)
    for _ in range(90):                                    # scattered crowns of the old Namsan woods
        xx = rnd.randint(330, 516)
        if ridge[xx] + 3 >= 176:
            continue
        yy = rnd.randint(ridge[xx] + 3, 176)
        lit_side = xx < 410 + (yy - 120) // 3
        cv.hline(xx - 1, xx + 1, yy, "P13" if lit_side else "P12")
        cv.put(xx + 2, yy + 1, "P11"); cv.put(xx - 2, yy + 1, "P13" if lit_side else "P12")
    for x in range(326, 521):                              # crisp skyline over the canopy
        cv.put(x, ridge[x], "P13" if ridge[x + 1] <= ridge[x] else "P12")
    # 남산 송신탑: shaft, observation pod, lattice mast, broadcast lights
    tx, tb = 412, 119
    cv.rect(tx - 2, tb - 6, tx + 2, tb, "P13")            # base building
    cv.hline(tx - 3, tx + 3, tb - 6, "P14")
    cv.rect(tx - 1, 74, tx + 1, tb - 7, "P13")            # shaft
    cv.vline(tx - 1, 74, tb - 7, "P15")                   # west face lit
    cv.rect(tx - 5, 66, tx + 5, 73, "P13")                # pod
    cv.hline(tx - 5, tx + 5, 66, "P15"); cv.vline(tx - 5, 67, 72, "P15")
    cv.hline(tx - 4, tx + 4, 69, "P11")                   # pod window band
    cv.put(tx - 3, 69, "P62"); cv.put(tx + 1, 69, "P62")   # broadcast room still lit (teal)
    cv.hline(tx - 4, tx + 4, 73, "P12")
    cv.rect(tx - 2, 60, tx + 2, 65, "P13"); cv.vline(tx - 2, 60, 65, "P15")
    cv.rect(tx - 1, 50, tx, 59, "P13"); cv.vline(tx - 1, 50, 59, "P14")
    cv.vline(tx, 40, 49, "P12")                           # antenna
    cv.put(tx, 39, "P53"); cv.put(tx, 46, "P53")
    # faint broadcast rings (SD-16 §10.8) as dotted arcs
    for r in (10, 16):
        for a in range(-60, 61, 12 if r == 10 else 9):
            ang = math.radians(a)
            cv.put(int(tx + r * math.sin(ang)), int(42 - r * math.cos(ang) * 0.6), "P15")


def yeouido(cv):
    # island ground + embankment
    for x in range(26, 236):
        t = (x - 26) / 210
        y0 = int(181 - 3 * math.sin(t * math.pi))
        y1 = int(191 - 2 * math.sin(t * math.pi))
        cv.rect(x, y0, x, y1, "P12")
        cv.put(x, y1, "P07"); cv.put(x, y1 - 1, "P13")   # concrete embankment catches the light
    tones = ("P14", "P13", "P12", "P12", "P14")
    rnd = random.Random(12)
    # office towers in the middle (old 금융가)
    for x, w, h, b in [(92, 9, 30, 0), (104, 7, 38, 3), (114, 10, 34, 0), (128, 8, 44, 0), (140, 9, 30, 4),
                       (152, 7, 26, 0), (162, 11, 22, 0), (178, 8, 18, 0), (70, 10, 16, 0), (84, 6, 20, 2)]:
        building(cv, x, 184, w, h, tones, rnd, side=2, win=(2, 2), broken=b)
    # collapsed parliament dome on the west tip: drum + broken shell
    dx, dy = 52, 183
    cv.rect(dx - 13, dy - 7, dx + 13, dy, "P13")
    for i in range(-13, 14, 3):
        cv.vline(dx + i, dy - 7, dy - 1, "P15")            # colonnade
    cv.hline(dx - 14, dx + 14, dy - 8, "P15")
    for x in range(dx - 11, dx + 12):
        h = int(math.sqrt(max(0, 121 - (x - dx) ** 2)) * 0.8)
        if not (dx - 2 <= x <= dx + 6):                    # the shell has caved in
            cv.vline(x, dy - 8 - h, dy - 9, "P14")
            cv.put(x, dy - 8 - h, "P15" if x < dx else "P13")
        else:
            cv.vline(x, dy - 10, dy - 9, "P12")
    for x, y in [(dx + 2, dy - 13), (dx + 3, dy - 15), (dx + 5, dy - 12)]:
        cv.vline(x, y, dy - 10, "P13")                     # bare ribs
    # 금탑 (gold tower) on the east tip: tapering gold glass slab, the 북서 waymarker
    gx, gb, gh = 206, 186, 66
    for i in range(gh):
        y = gb - i
        half = 7 - i * 4 // gh
        x0, x1 = gx - half, gx + half
        cv.hline(x0, x1, y, "P48")
        cv.put(x0, y, "R02.c"); cv.put(x0 + 1, y, "P49" if i % 3 else "R02.c")
        cv.put(x1, y, "P47")
        if i % 3 == 0:
            cv.hline(x0 + 2, x1 - 1, y, "R02.a")
    cv.hline(gx - 3, gx + 3, gb - gh, "P50")
    cv.put(gx - 2, gb - gh - 1, "P49")
    for y in range(gb - gh + 6, gb - 10, 7):               # sunlight glint running down the west edge
        cv.put(gx - 5, y, "P50")
    # IFC-like twin boxes beside it
    building(cv, 186, 186, 8, 26, tones, rnd, side=1, win=(2, 2))


def river(cv):
    """Han river band: north bank yn(x), south bank ys(x); the wide bend reads from 여의도 to 잠실."""
    yn = lambda x: int(176 + 4 * ((x - 330) / 330) ** 2 * -1 + 2)
    ys = lambda x: int(206 - 6 * ((x - 330) / 330) ** 2)
    rnd = random.Random(3)
    for x in range(W):
        a, b = yn(x), ys(x)
        cv.rect(x, a, x, b, "P35")
        cv.rect(x, a, x, a + 2, "P36")                    # far water reflects the bright haze
        cv.checker(x, a + 3, x, a + 5, "P36", "P35")
        cv.checker(x, b - 3, x, b, "P34", "P35")         # near water darker
    for _ in range(140):                                   # horizontal glints, warmer on the sun side
        x = rnd.randint(0, W - 12)
        y = rnd.randint(yn(x) + 3, ys(x) - 2)
        ln = rnd.randint(2, 9)
        t = "P22" if x < 240 and rnd.random() < 0.6 else "P37"
        cv.hline(x, x + ln, y, t)
    return yn, ys


def north_bank(cv, yn):
    # 강변 road + embankment, then 용산·마포 blocks (hazy)
    for x in range(W):
        cv.put(x, yn(x) - 1, "P07"); cv.put(x, yn(x) - 2, "P13")


def saetgang(cv):
    # thin channel south of 여의도
    for x in range(26, 240):
        cv.hline(x, x, 192, "P35"); cv.put(x, 193, "P36" if x % 5 else "P37")


def bridge(cv, xs, ys_, xn, yn_, gap, rnd):
    """Bridge deck from south bank (xs, ys_) to north bank (xn, yn_); gap = (t0, t1) broken span."""
    n = ys_ - yn_
    for i in range(n + 1):
        t = i / n
        y = ys_ - i
        x = int(round(xs + (xn - xs) * t))
        if gap[0] <= t <= gap[1]:
            continue
        w = 3 if t < 0.5 else 2
        cv.hline(x - w // 2, x + w - 1 - w // 2, y, "P07")
        cv.put(x + w - w // 2, y, "P04")                   # deck side in shade
        if i % 5 == 0:                                     # piers + their reflection
            cv.vline(x + 1, y + 1, y + 3, "P03")
            cv.put(x + 1, y + 4, "P34")
        if i % 4 == 2:                                     # steel arch tops
            cv.put(x - 1, y - 1, "P06")
    # fallen span: tilted slab in the water
    t = (gap[0] + gap[1]) / 2
    y = int(ys_ - n * t)
    x = int(xs + (xn - xs) * t)
    cv.hline(x - 2, x + 2, y + 1, "P05"); cv.hline(x - 1, x + 3, y + 2, "P34")


def sejin_tower(cv):
    """세진전자 타워: thin tapering supertall in 잠실/강남 haze; 관제망 standby lamp blinking amber on the spire."""
    tx, tb, top = 588, 214, 30
    hgt = tb - top
    for i in range(hgt):
        y = tb - i
        half = int(round(9 - i * 6.5 / hgt))
        x0, x1 = tx - half, tx + half
        cv.hline(x0, x1, y, "P13")
        cv.hline(x0, x0 + 1, y, "P15")                     # west face in the sun
        cv.put(x1, y, "P12")
        if i % 9 == 0:
            cv.hline(x0 + 1, x1 - 1, y, "P12")            # mechanical floor bands
        if i % 9 == 4 and i < hgt - 20:
            cv.put(tx + 1, y, "P11")
    # crown and spire
    cv.rect(tx - 2, top - 8, tx + 2, top, "P13"); cv.vline(tx - 2, top - 8, top, "P15")
    cv.vline(tx, top - 22, top - 9, "P13"); cv.vline(tx - 1, top - 16, top - 9, "P14")
    cv.put(tx, top - 23, "P60"); cv.put(tx - 1, top - 23, "P59"); cv.put(tx + 1, top - 23, "P59")
    cv.put(tx, top - 24, "P59")
    # broken cladding: a dark scar high on the east face
    for y in range(70, 92):
        cv.put(tx + 3 - (y - 70) // 8, y, "P11")


def vertibird(cv, x, y):
    """비상정부 버티버드 silhouette far over 강남 (청계산 is south-east)."""
    shape = [
        "..xx.........xx..",
        ".xxxx.......xxxx.",
        "....xxxxxxxxx....",
        "..xxxxxxxxxxxxx..",
        "...xxxxxxxxxx....",
        "......x...x......",
    ]
    for r, row in enumerate(shape):
        for c, v in enumerate(row):
            if v == "x":
                cv.put(x + c, y + r, "P11")


LIGHT = (-0.72, -0.48, 0.5)
_n = math.sqrt(sum(v * v for v in LIGHT))
LIGHT = tuple(v / _n for v in LIGHT)
ROCK = ["P03", "P04", "P05", "P06", "P07", "P08", "P09"]          # cool-dark shade -> warm sunlit cream
ROCK_FAR = ["P05", "P06", "P07", "R01.a", "P08", "P09", "P09"]
PINE = ["P01", "P28", "P28", "P29", "R01.b", "P30", "P31"]
MAPLE = ["P23", "P24", "P24", "P25", "P26", "P27", "P27"]
OAK = ["P16", "P17", "P18", "P19", "P19", "P20", "P21"]
SMOKE = ["P04", "P05", "P05", "P06", "P06", "P07", "P07"]
SMOKE_FAR = ["P05", "P06", "P06", "P07", "P07", "R01.a", "R01.a"]
THR = (-0.05, 0.2, 0.42, 0.62, 0.8, 0.93)


def blob(cv, cx, cy, rx, ry, seed, ramp, flat=0.55, ground=None, mask=None, outline=("P03", "P02"),
         wobble=(0.07, 0.05), cracks=True, sparse=None):
    """Lumpy ellipsoid lit from the west, quantised to a 7-step ramp. Used for granite, foliage and smoke."""
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    pts = []
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            th = math.atan2(dy, dx)
            wob = 1 + wobble[0] * math.sin(3 * th + ph[0]) + wobble[1] * math.sin(7 * th + ph[1])
            wob = round(wob * 12) / 12                      # stepped, not noisy
            if dx * dx + dy * dy <= wob * wob and (ground is None or y <= ground):
                if sparse is not None and (x + y) % 2 and (y - (cy - ry)) / (2 * ry) < sparse:
                    continue
                pts.append((x, y, dx / wob, dy / wob))
    S = {(x, y) for x, y, _, _ in pts}
    for x, y, nx, ny in pts:
        nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
        if ny < 0.2:
            nz = max(nz, flat)                             # broad flattened top
        ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1
        i = (nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / ln
        k = sum(i >= t for t in THR)
        if ny > 0.6:
            k = min(k, 1)                                  # contact shadow underneath
        tok = ramp[k]
        if outline and any((x + a, y + b) not in S for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            tok = outline[0] if (nx < 0 and ny < 0.3) else outline[1]
        cv.put(x, y, tok)
        if mask is not None:
            mask.add((x, y))
    if cracks:   # granite joints: broken lines with a lit lower lip
        for _ in range(max(1, int(rx * ry / 300))):
            x, y = cx + rnd.uniform(-rx * 0.5, rx * 0.5), cy + rnd.uniform(-ry * 0.6, ry * 0.2)
            ang = rnd.choice((rnd.uniform(0.2, 0.6), rnd.uniform(1.3, 1.8), rnd.uniform(2.5, 2.9)))
            for s in range(rnd.randint(5, max(6, int(min(rx, ry) * 1.2)))):
                x += math.cos(ang); y += math.sin(ang)
                ang += rnd.uniform(-0.25, 0.25)
                p = (int(x), int(y))
                if p in S and (p[0], p[1] + 1) in S and (p[0], p[1] - 1) in S:
                    cv.put(p[0], p[1], ramp[1])
                    cv.put(p[0] + 1, p[1] + 1, ramp[min(6, 4)])
    return S


def smoke(cv, x, y, height, drift, seed, near=False):
    """Column of round billows: narrow and dark at the fire, widening, paling and bending east with the wind."""
    rnd = random.Random(seed)
    ramp = SMOKE if near else SMOKE_FAR
    puffs = []
    t = 0.0
    while t < 1.0:
        r = 2.2 + t * (11 if near else 8)
        cx = x + drift * t ** 2 + rnd.uniform(-0.4, 0.4) * r
        cy = y - t * height
        puffs.append((cx, cy, r, t))
        if t > 0.35:                                       # side billows as the column spreads
            puffs.append((cx + rnd.choice((-1, 1)) * r * 0.7, cy + r * 0.3, r * 0.65, t))
        t += max(0.05, r * 0.5 / height)
    for cx, cy, r, t in reversed(puffs):
        blob(cv, cx, cy, r, r * 0.88, rnd.randint(0, 999), ramp, flat=0.2, outline=None, cracks=False,
             wobble=(0.1, 0.06), sparse=1.0 if t > 0.78 else None)
    cv.put(x, y, "P59"); cv.put(x + 1, y, "P27"); cv.put(x - 1, y + 1, "P27"); cv.put(x, y + 1, "P60")


def bush(cv, x, base, r, seed, ramp):
    """One shrub: a dome of 3-5 foliage lumps, back ones first."""
    rnd = random.Random(seed)
    lumps = [(x + rnd.uniform(-r, r) * 0.9, base - r * rnd.uniform(0.5, 1.1), r * rnd.uniform(0.45, 0.7))
             for _ in range(rnd.randint(2, 4))]
    lumps.sort(key=lambda l: l[1])
    lumps.append((x, base - r * 0.55, r * 0.75))
    cv.hline(int(x - r * 0.8), int(x + r * 1.1), int(base), "P16")
    for lx, ly, lr in lumps:
        blob(cv, lx, ly, lr * 1.2, lr, rnd.randint(0, 999), ramp, flat=0.3, outline=None, cracks=False,
             wobble=(0.2, 0.12))


def tree_clump(cv, x0, x1, base, seed, ramp, size=(3, 6), n=None, density=0.7, jitter=2):
    """Overgrowth: irregular run of shrubs with gaps, sizes and heights varying."""
    rnd = random.Random(seed)
    x = x0
    while x < x1:
        r = rnd.randint(*size)
        if rnd.random() < density:
            bush(cv, x, base + rnd.randint(-jitter, jitter), r, rnd.randint(0, 999), ramp)
        x += r + rnd.randint(1, r * 2)


def grass(cv, x, y, n, seed, cols=("P19", "P20", "P21", "P18")):
    rnd = random.Random(seed)
    for _ in range(n):
        gx = x + rnd.randint(-7, 7)
        h = rnd.randint(2, 7)
        lean = rnd.choice((-1, 0, 0, 1))
        col = rnd.choice(cols)
        for i in range(h):
            cv.put(gx + (lean if i > h // 2 else 0), y - i, col)
        cv.put(gx + lean, y - h, "P22" if col in ("P20", "P21") else col)


def pine(cv, x, base, h, seed, lean=0.0, pads=()):
    """Korean red pine: thick twisting trunk (grey bark below, rust-red above), flat layered crown pads."""
    rnd = random.Random(seed)
    pts = []
    xx = float(x)
    for i in range(h):
        xx += lean + math.sin(i / 11 + seed) * 0.3
        pts.append((xx, base - i))
    for i, (px, py) in enumerate(pts):
        w = int(round(7 - 4 * i / h))
        upper = i > h * 0.45
        for k in range(w):
            if k == 0:
                tok = "P26" if upper else "P18"
            elif k == w - 1:
                tok = "P01"
            elif k >= w - 2:
                tok = "P17" if upper else "P16"
            else:
                tok = "P24" if upper else "P17"
            cv.put(int(px) + k, py, tok)
        if not upper and i % 5 == 2:                       # bark plates
            cv.hline(int(px) + 1, int(px) + w - 3, py, "P16")
    for (frac, dx, rx, ry) in pads:
        px, py = pts[min(h - 1, int(h * frac))]
        bx = int(px + dx)
        step = 1 if dx > 0 else -1
        for k in range(abs(dx)):                           # branch
            cv.put(int(px) + 2 + k * step, py - k // 3, "P17")
            cv.put(int(px) + 2 + k * step, py - k // 3 + 1, "P01")
        sub = [(bx - rx * 0.45, py - ry * 0.4, rx * 0.6, ry * 0.8), (bx + rx * 0.45, py - ry * 0.3, rx * 0.6, ry * 0.75),
               (bx, py - ry * 0.75, rx * 0.75, ry * 0.85)]
        for sx, sy, srx, sry in sub:
            blob(cv, sx, sy, srx, sry, rnd.randint(0, 999), PINE, flat=0.7, outline=("P28", "P01"),
                 cracks=False, wobble=(0.22, 0.14))
        for _ in range(rx):                                # needle tufts along the sunlit top
            tx = bx + rnd.randint(-rx + 3, rx - 3)
            ty = int(py - ry * 1.55) + rnd.randint(0, 2)
            cv.put(tx, ty, "P30"); cv.put(tx + 1, ty + 1, "R01.b")


def signpost(cv, x, base):
    """Rusted 등산로 marker pointing back up the slope: green arm, white arrow, rust bleeding through."""
    cv.rect(x, base - 26, x + 1, base, "P24"); cv.vline(x, base - 26, base, "P26")
    cv.rect(x - 20, base - 26, x - 1, base - 20, "P29")
    cv.hline(x - 20, x - 1, base - 26, "P31"); cv.hline(x - 20, x - 1, base - 20, "P28")
    for c in range(3):                                     # arrow head
        cv.vline(x - 23 + c, base - 23 - c, base - 23 + c, "P29")
    cv.hline(x - 18, x - 4, base - 23, "P09")
    for c in range(3):
        cv.put(x - 18 + c, base - 23 - c, "P09"); cv.put(x - 18 + c, base - 23 + c, "P09")
    for c in (6, 11, 15):
        cv.put(x - c, base - 21, "P25"); cv.put(x - c, base - 22, "P25")
    cv.rect(x + 2, base - 18, x + 3, base - 14, "P03")


def foreground(cv):
    # earth slope under everything: autumn-dry soil, rising to the left
    for x in range(W):
        top = int(276 - 26 * max(0, (300 - x) / 300) ** 1.4 + 5 * math.sin(x / 37))
        if x > 470:
            top = int(top + (x - 470) * 0.18 - 6)
        cv.rect(x, top, x, H - 1, "P18")
        cv.put(x, top, "P20"); cv.put(x, top + 1, "P19")
        for y in range(top + 2, H):                        # soil darkens downhill toward the viewer
            if y > top + 30 or (y > top + 18 and (x + y) % 2):
                cv.put(x, y, "P17")
    # mid-slope: autumn shrubs (oak, maple) and embedded boulders
    tree_clump(cv, 290, 640, 284, 61, OAK, size=(4, 9), density=0.55, jitter=4)
    tree_clump(cv, 330, 640, 292, 62, MAPLE, size=(3, 7), density=0.35, jitter=5)
    tree_clump(cv, 300, 640, 296, 63, PINE, size=(4, 7), density=0.3, jitter=4)
    for (cx, cy, rx, ry, s) in [(470, 294, 26, 13, 1), (556, 304, 36, 16, 2), (392, 306, 18, 9, 3)]:
        blob(cv, cx, cy, rx, ry, s, ROCK, ground=int(cy + ry * 0.35))
    for gx, gy, n, s in [(420, 310, 16, 1), (520, 314, 14, 2), (340, 312, 12, 3), (600, 316, 12, 4)]:
        grass(cv, gx, gy, n, s)
    # the granite slab the protagonist stands on (left third) + its shoulder
    top_rock = set()
    blob(cv, 40, 300, 76, 46, 12, ROCK, flat=0.6)
    blob(cv, 150, 306, 116, 36, 11, ROCK, flat=0.55, mask=top_rock)
    blob(cv, 268, 330, 56, 28, 13, ROCK, flat=0.6)
    tree_clump(cv, 226, 300, 322, 64, OAK, size=(3, 6), density=0.6, jitter=3)
    # bottom edge: big near rocks, shrubs, grass
    for (cx, cy, rx, ry, s) in [(350, 360, 48, 24, 21), (470, 368, 64, 30, 22), (590, 356, 56, 30, 24),
                                (120, 370, 80, 26, 25)]:
        blob(cv, cx, cy, rx, ry, s, ROCK, flat=0.5)
    bush(cv, 408, 346, 9, 65, MAPLE)
    bush(cv, 532, 342, 8, 66, OAK)
    bush(cv, 286, 352, 7, 67, MAPLE)
    for gx, gy, n, s in [(300, 336, 16, 4), (404, 340, 14, 5), (530, 336, 18, 6), (220, 342, 12, 9),
                         (630, 330, 10, 10), (8, 344, 12, 8)]:
        grass(cv, gx, gy, n, s)
    return top_rock


def vault_exit(cv):
    """The S-07 gate the protagonist just walked out of (SD-09a L-R01-01 ②): concrete retaining wall with the round
    portal (the gear door rolled aside inside the vault, out of sight), the bronze plate, the 6x4 deck with its far-edge railing,
    12 steps down the slope and the exit checklist terminal. Seen obliquely from behind-left; sun from the west."""
    from PIL import ImageDraw
    d = ImageDraw.Draw(cv.img)
    T = lambda t: C(t)
    # retaining wall (옹벽): near and tall at the left, receding to the right
    wall = [(0, 150), (168, 198), (168, 300), (0, 312)]
    d.polygon(wall, fill=T("P06"))
    x, step = 6, 30.0
    while x < 168:                                          # formwork panel joints, closer together as they recede
        top = 150 + x * 48 / 168
        bot = 312 - x * 12 / 168
        d.line([x, top + 4, x, bot], fill=T("P05"))
        for k in range(3):                                   # form-tie holes in each panel
            ty = top + 18 + k * (bot - top - 30) / 2
            for hx in (x + step * 0.3, x + step * 0.7):
                if hx < 166:
                    cv.put(hx, ty, "P04")
        x += step; step *= 0.86
    for xx in range(0, 168):                                 # damp, darker lower third
        bot = 312 - xx * 12 / 168
        for yy in range(int(bot) - 22, int(bot)):
            if cv.get(xx, yy)[:3] == P.rgb("P06") and ((xx + yy) % 2 or yy > bot - 10):
                cv.put(xx, yy, "P05")
    for xx in range(0, 168):                                 # cap: sunlit top edge + shadow under the lip
        ty = 150 + xx * 48 / 168
        cv.put(xx, ty, "P08"); cv.put(xx, ty + 1, "R01.a"); cv.put(xx, ty + 2, "P07"); cv.put(xx, ty + 3, "P05")
    for sx, ln in ((22, 40), (58, 26), (131, 34), (150, 20)):          # rust/water streaks from the cap
        ty = 150 + sx * 48 / 168 + 4
        for k in range(ln):
            if k % 3 != 2:
                cv.put(sx, ty + k, "P05" if k < ln * 0.6 else "P06")
        cv.put(sx, ty, "P24")
    for xx in range(0, 168, 3):                              # moss at the foot
        by = 312 - xx * 12 / 168
        cv.put(xx, by - 1, "P29"); cv.put(xx + 1, by - 2, "P30")
    # bronze plate '서울 볼트 S-07 관악 / 한결건설 시공'
    d.polygon([(50, 180), (118, 200), (118, 213), (50, 193)], fill=T("P47"), outline=T("P02"))
    d.line([(52, 182), (116, 201)], fill=T("P49"))
    for k in range(3):
        d.line([(56, 186 + k * 3), (112, 202 + k * 3)], fill=T("P48") if k != 1 else T("P49"))
    # round portal (oblique ellipse) with the hazard ring, dark tunnel, lamps inside
    cx, cy, rx, ry = 86, 250, 31, 48
    d.ellipse([cx - rx - 5, cy - ry - 5, cx + rx + 5, cy + ry + 5], fill=T("P02"))
    for a in range(0, 360, 12):                              # hazard chevrons
        ra, rb = math.radians(a), math.radians(a + 6)
        d.polygon([(cx + (rx + 4) * math.cos(ra), cy + (ry + 4) * math.sin(ra)),
                   (cx + (rx + 4) * math.cos(rb), cy + (ry + 4) * math.sin(rb)),
                   (cx + (rx + 1) * math.cos(rb), cy + (ry + 1) * math.sin(rb)),
                   (cx + (rx + 1) * math.cos(ra), cy + (ry + 1) * math.sin(ra))], fill=T("P48"))
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=T("P03"))
    d.ellipse([cx - rx + 6, cy - ry + 6, cx + rx - 2, cy + ry - 4], fill=T("P02"))
    d.ellipse([cx - rx + 14, cy - ry + 16, cx + rx - 4, cy + ry - 12], fill=T("P01"))
    for ly in (226, 248, 270):                               # ceiling lamps down the tunnel
        cv.put(cx + 8, ly, "P15"); cv.put(cx + 9, ly, "P14")
    # the gear door rolled aside INSIDE the vault (its recess is behind the wall), so from outside only the empty
    # round portal and the dim gate corridor are visible

    # deck (6x4 tiles), lit by the low western sun; the wall throws a shadow band onto it
    deck = [(0, 312), (168, 300), (330, 304), (372, 360), (0, 360)]
    d.polygon(deck, fill=T("P07"))
    for k in range(1, 5):                                    # expansion joints
        y0 = 312 + k * 11
        d.line([(0, y0), (168 + k * 9, 300 + k * 11 - 6)], fill=T("P06"))
    for jx in (90, 200, 290):
        d.line([(jx, 305), (jx + 18, 360)], fill=T("P06"))
    for xx in range(0, 372):                                 # weathered, darker toward the viewer
        for yy in range(340, 360):
            if cv.get(xx, yy)[:3] == P.rgb("P07") and ((xx + yy) % 2 or yy > 352):
                cv.put(xx, yy, "P06")
    crack = [(120, 330), (128, 334), (131, 340), (140, 343), (146, 351), (150, 359)]
    for (ax, ay), (bx, by) in zip(crack, crack[1:]):
        d.line([(ax, ay), (bx, by)], fill=T("P05"))
        d.line([(ax + 1, ay + 1), (bx + 1, by + 1)], fill=T("P08"))
    for lx, ly, t in ((60, 334, "P26"), (64, 336, "P27"), (190, 322, "P20"), (280, 346, "P26"), (300, 330, "P21"),
                      (210, 352, "P25"), (34, 350, "P20")):    # fallen leaves (late October)
        cv.put(lx, ly, t); cv.put(lx + 1, ly, t); cv.put(lx, ly + 1, "P05")
    for xx in range(0, 170):                                 # wall shadow
        top = 312 - xx * 12 / 168
        for yy in range(int(top), int(top) + 10 - xx // 20):
            if cv.get(xx, yy)[:3] == P.rgb("P07"):
                cv.put(xx, yy, "P06")
    # far-edge railing (galvanised pipe)
    for k in range(11):
        t = k / 10
        x0, y0 = 168 + (330 - 168) * t, 300 + 4 * t
        d.line([(x0, y0), (x0, y0 - 13)], fill=T("P04")); cv.put(x0 - 1, y0 - 13, "P07")
    d.line([(168, 287), (330, 291)], fill=T("P05")); d.line([(168, 286), (330, 290)], fill=T("P08"))
    d.line([(168, 294), (330, 298)], fill=T("P05"))
    # 12 steps down the slope from the deck's right edge (the nearest 6 are in frame)
    for i in range(7):
        x0 = 336 + i * 9; y0 = 306 + i * 8
        d.polygon([(x0, y0), (x0 + 44, y0 + 2), (x0 + 46, y0 + 5), (x0 + 2, y0 + 3)], fill=T("P07"))
        d.polygon([(x0 + 2, y0 + 3), (x0 + 46, y0 + 5), (x0 + 46, y0 + 9), (x0 + 2, y0 + 8)], fill=T("P05"))
        d.line([(x0, y0), (x0 + 44, y0 + 2)], fill=T("P08"))
    # exit checklist terminal (출구 점검표 단말) at the top of the steps
    d.rectangle([326, 280, 327, 304], fill=T("P04"))
    d.rectangle([321, 272, 333, 282], fill=T("P08"), outline=T("P02"))
    d.rectangle([323, 274, 331, 279], fill=T("P59")); cv.put(324, 275, "P60")


def protagonist(cv, x, y):
    """Back-view idle frame (feet at 32,60) placed with its long western-sun shadow cast to the east."""
    fr = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_S.txt"))["idleN"]
    # shadow: flat sheared ellipse to the right on the rock top, one tone darker
    for i in range(0, 22):
        for j in range(-2, 3):
            if (i / 22) ** 2 + (j / 2.6) ** 2 <= 1:
                px, py = x + 2 + i, y + j // 2 + i // 9
                cur = cv.get(px, py)[:3]
                dark = {P.rgb(ROCK[k]): ROCK[max(0, k - 2)] for k in range(len(ROCK))}
                if cur in dark:
                    cv.put(px, py, dark[cur])
    cv.img.alpha_composite(fr, (x - 32, y - 60))


def vignette(cv):
    """Darken the outermost bottom corners by one palette step (keeps the eye on the city)."""
    step = {P.rgb(t): n for t, n in [("P22", "P08"), ("P08", "P07"), ("P07", "P06"), ("P06", "P05"),
                                      ("P05", "P04"), ("P04", "P03"), ("P18", "P17"), ("P17", "P16"),
                                      ("P19", "P18"), ("P20", "P19")]}
    for y in range(300, H):
        for x in list(range(0, 90)) + list(range(W - 90, W)):
            e = min(x, W - 1 - x)
            if (90 - e) / 90 + (y - 300) / 60 > 1.25 and (x + y) % 2 == 0 or (90 - e) / 90 + (y - 300) / 60 > 1.5:
                cur = cv.get(x, y)[:3]
                if cur in step:
                    cv.put(x, y, step[cur])


def build():
    cv = Canvas()
    sky(cv)
    # very far ranges (경기 북부) then 북한산·도봉산 massif
    far = ridge_line([(0, 118), (60, 112), (140, 116), (220, 108), (300, 114), (380, 104), (470, 110), (560, 100), (640, 108)], 0, 1, 4)
    mountain(cv, far, 160, "P08", "P15", "P15", depth=4)
    bh = ridge_line([(0, 132), (40, 126), (90, 114), (130, 106), (160, 96), (176, 88), (186, 92), (200, 86),
                     (214, 94), (240, 100), (262, 110), (300, 116), (340, 112), (372, 104), (396, 100),
                     (420, 106), (452, 100), (476, 92), (492, 97), (520, 106), (560, 114), (600, 120), (640, 118)], 1, 2, 5)
    mountain(cv, bh, 165, "P15", "P14", "P13", faces=[(176, 89, 6, 12), (200, 87, 7, 14), (476, 93, 6, 11),
                                                     (396, 101, 4, 8), (130, 107, 4, 8)])
    cv.rect(0, 156, W - 1, 180, "P13")                     # hazy ground plane behind the riverside blocks
    # 강북 시가 back row
    city_row(cv, 0, W, 158, 6, 16, 6, 18, ("P15", "P14", "P13", "P13", "P15"), 41)
    # 인왕산·북악산 (nearer, darker)
    ih = ridge_line([(150, 162), (190, 140), (222, 128), (246, 134), (270, 130), (300, 140), (330, 150), (360, 164)], 1, 4, 2)
    mountain(cv, ih, 166, "P14", "P13", "P12", faces=[(222, 129, 4, 7)])
    city_row(cv, 0, W, 170, 6, 18, 5, 16, ("P14", "P13", "P12", "P12", "P14"), 42)
    namsan(cv)
    # 용산·마포 riverside blocks
    city_row(cv, 236, W, 178, 4, 12, 6, 20, ("P14", "P13", "P12", "P11", "P14"), 43, broken_p=0.2, skip=[(330, 330)])
    yn, ys = river(cv)
    north_bank(cv, yn)
    yeouido(cv)
    saetgang(cv)
    rnd = random.Random(9)
    bridge(cv, 322, 205, 330, 178, (0.42, 0.62), rnd)     # 한강대교 through 노들섬
    bridge(cv, 446, 204, 440, 177, (0.55, 0.7), rnd)      # 동작대교
    bridge(cv, 150, 196, 156, 176, (0.3, 0.45), rnd)      # 마포대교 off 여의도
    # 노들섬
    for x in range(314, 342):
        cv.rect(x, 189, x, 192, "P29" if x % 4 else "P30")
        cv.put(x, 193, "P07")
    sejin_tower(cv)
    vertibird(cv, 520, 58)
    # south-bank ground under the 아파트 숲 (seen between the blocks): embankment road, then hazy earth
    for x in range(W):
        y0 = ys(x) + 1
        cv.hline(x, x, y0, "P08"); cv.put(x, y0 + 1, "P06")
        for y in range(y0 + 2, 300):
            tok = "P07" if y < 222 else "P06" if y < 246 else "P05"
            if y in (221, 222, 245, 246) and (x + y) % 2:
                tok = {"P07": "P06", "P06": "P07", "P05": "P06"}[tok]
            cv.put(x, y, tok)
    # 강남 skyline behind the tower's base, then south-bank 아파트 숲 rows (warmer, darker as they come closer)
    city_row(cv, 500, W, 212, 10, 26, 8, 18, ("P14", "P13", "P12", "P11", "P14"), 44, skip=[(578, 598)])
    city_row(cv, 0, W, 218, 8, 20, 12, 30, ("P08", "P07", "P06", "P05", "P08"), 45, broken_p=0.25)
    tree_clump(cv, 0, W, 220, 51, ["P05", "P29", "P29", "P30", "P30", "P31", "P31"], size=(2, 4), density=0.5)
    smoke(cv, 262, 222, 92, 22, 1)
    smoke(cv, 516, 214, 70, 18, 2)
    city_row(cv, -10, W, 242, 18, 34, 18, 40, ("R01.a", "P06", "P05", "P04", "P07"), 46, broken_p=0.35, number_p=0.3,
             gap=(1, 6))
    tree_clump(cv, 0, W, 244, 52, ["P04", "P28", "P29", "P29", "P30", "P30", "P31"], size=(3, 6), density=0.5, jitter=3)
    city_row(cv, -20, W, 270, 30, 52, 26, 54, ("P07", "P05", "P04", "P03", "P06"), 47, broken_p=0.45, number_p=0.5,
             gap=(3, 12))
    tree_clump(cv, 0, W, 272, 53, ["P03", "P28", "P28", "P29", "P29", "P30", "P26"], size=(3, 7), density=0.6, jitter=3)
    smoke(cv, 404, 258, 128, 34, 3, near=True)
    if FAR_ONLY:                                            # 첫 풍경 컷신(0-9): 먼 풍경만 — 앞쪽 비탈·볼트 출구·사람은 게임이 타일로 얹는다
        return cv.img
    top_rock = foreground(cv)
    pine(cv, 604, 350, 150, 3, lean=-0.16, pads=[(0.45, -18, 13, 5), (0.58, 12, 15, 6), (0.72, -14, 16, 6),
                                                 (0.84, 8, 18, 6), (0.97, -4, 20, 7)])
    vault_exit(cv)
    protagonist(cv, 236, 330)
    vignette(cv)
    return cv.img


if __name__ == "__main__":
    im = build()
    allowed = P.allowed_set(*P.REGION.keys(), "S3", "H1")
    bad = check(im, allowed)
    out = os.path.join(ROOT, "samples")
    im.convert("RGB").save(os.path.join(out, "09_keyart_first_seoul.png"))
    upscale(im, 2).convert("RGB").save(os.path.join(out, "09_keyart_first_seoul_x2.png"))
    print("off-palette:", bad if bad else 0)
