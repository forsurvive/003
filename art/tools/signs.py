"""#14 간판 기준 샘플 (SD-16 §11, §12.3 #14): 봉천 상가 간판 5, S-07 표어 화면 4, 간판 대 글자 세트 초판 150자.
글자는 모두 hangul16 (직접 그린 16×16 자모 조합)으로 찍는다. 간판은 2077년 원본을 2277년 상태(빛바램·녹물·
떨어진 글자·깨진 아크릴)로 낡힌다. 빛은 왼쪽 위(§3.9). 번개24는 지금도 문을 여는 가게라 밤 점등판을 함께 둔다.
python3 tools/signs.py  ->  samples/20_*"""
import os, sys, random
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import hangul16 as H
from grid import check

ROOT = os.path.dirname(os.path.dirname(__file__))
OUT = os.path.join(ROOT, "samples")
C = lambda t: P.rgb(t) + (255,)

RAMPS = [[f"P{i:02d}" for i in r] for r in (range(0, 10), range(10, 16), range(16, 23), range(23, 28), range(28, 33),
                                             range(33, 38), range(38, 43), range(43, 47), range(47, 51),
                                             range(51, 55), range(55, 58), range(58, 61), range(61, 64))]
RAMPS += [[f"U{i}" for i in range(8)], [f"A{i}" for i in range(8)]]
_POS = {}
for _r in RAMPS:
    for _i, _t in enumerate(_r):
        _POS.setdefault(P.rgb(_t), (_r, _i))


def shift(rgb, k):
    """move a colour k steps along its own ramp (darker < 0 < lighter)."""
    if rgb not in _POS:
        return rgb
    r, i = _POS[rgb]
    return P.rgb(r[max(0, min(len(r) - 1, i + k))])


# ------------------------------------------------------------------------------------------------ text
def text_mask(s, track=1):
    S, x = set(), 0
    for ch in s:
        if ch != " ":
            S |= {(gx + x, gy) for gx, gy in H.glyph(ch)}
        x += H.advance(ch) + (track - 1 if ch != " " else 0)
    w = max((p[0] for p in S), default=-1) + 1
    return S, w


def vtext_mask(s, gap=2):
    """세로 돌출 간판: glyphs stacked, each centred in a 15px column."""
    S = set()
    for i, ch in enumerate(s):
        S |= {(gx, gy + i * (H.EM + gap)) for gx, gy in H.glyph(ch)}
    return S, len(s) * (H.EM + gap) - gap


def stamp(img, mask, ox, oy, fill, shadow=None, hi=None, rim=None):
    """letters: optional 1px rim (outline), drop shadow down-right (light from upper left), top-edge highlight."""
    px = img.load()
    W, Hh = img.size
    m = {(x + ox, y + oy) for x, y in mask}
    def put(p, col):
        if 0 <= p[0] < W and 0 <= p[1] < Hh:
            px[p] = C(col) if isinstance(col, str) else col + (255,)
    if rim:
        for x, y in m:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                q = (x + dx, y + dy)
                if q not in m:
                    put(q, rim)
    if shadow:
        for x, y in m:
            q = (x + 1, y + 1)
            if q not in m:
                put(q, shadow)
    for p in m:
        put(p, fill)
    if hi:
        for x, y in m:
            if (x, y - 1) not in m and (x - 1, y) in m | {(x - 1, y)} and (x, y + 1) in m:
                put((x, y), hi)
    return m


# ------------------------------------------------------------------------------------------------ panels
def panel(d, x0, y0, x1, y1, face, frame="P03", lip="P06", hi=None, lo=None):
    """sign box: dark rim, metal lip, face. Top/left lip catch the light, bottom/right fall into shade."""
    d.rectangle([x0, y0, x1, y1], fill=C(frame))
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C(lip))
    d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=C(shift_t(lip, 2)))
    d.line([x0 + 1, y0 + 1, x0 + 1, y1 - 1], fill=C(shift_t(lip, 1)))
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=C(shift_t(lip, -2)))
    d.line([x1 - 1, y0 + 1, x1 - 1, y1 - 1], fill=C(shift_t(lip, -1)))
    d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], fill=C(face))
    if hi:
        d.line([x0 + 2, y0 + 2, x1 - 2, y0 + 2], fill=C(hi))
    if lo:
        d.line([x0 + 2, y1 - 2, x1 - 2, y1 - 2], fill=C(lo))


def shift_t(tok, k):
    return "#%02X%02X%02X" % shift(P.rgb(tok), k)


def bolt(d, x, y):
    d.point((x, y), fill=C("P07")); d.point((x + 1, y + 1), fill=C("P03")); d.point((x + 1, y), fill=C("P05"))
    d.point((x, y + 1), fill=C("P04"))


# ------------------------------------------------------------------------------------------------ weathering
def rust_streak(img, x, y, length, rnd, box=None):
    """녹물: runs down from a bolt or seam, dense near the source, thinning to single drops."""
    px = img.load()
    W, Hh = img.size
    for i in range(length):
        yy = y + i
        if yy >= Hh or (box and yy > box[3]):
            break
        x = max(0, min(W - 1, x))
        t = i / max(length, 1)
        if rnd.random() < 1.0 - t * 0.85:
            p = px[x, yy]
            if p[3]:
                tgt = P.rgb("P25") if t < 0.35 else P.rgb("P24")
                px[x, yy] = tgt + (255,) if rnd.random() < 0.7 else shift(p[:3], -1) + (255,)
        if i > 2 and rnd.random() < 0.18:
            x += rnd.choice((-1, 1)) if box is None or box[0] < x < box[2] else 0


def blotch(img, box, rnd, k, n=6, r=(3, 8), keep=None):
    """sun fade (k>0) or grime (k<0) blobs, dithered at the rim so the edge is never a hard line."""
    px = img.load()
    x0, y0, x1, y1 = box
    for _ in range(n):
        cx, cy = rnd.randint(x0, x1), rnd.randint(y0, y1)
        rx, ry = rnd.randint(*r), rnd.randint(max(2, r[0] // 2), max(3, r[1] // 2))
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if not (x0 <= x <= x1 and y0 <= y <= y1):
                    continue
                e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if e > 1:
                    continue
                if e > 0.55 and (x + y) % 2:
                    continue
                p = px[x, y]
                if p[3] and (keep is None or p[:3] in keep):
                    px[x, y] = shift(p[:3], k) + (255,)


def fade_top(img, box, keep, rows=10, k=1):
    """sun-bleach: the sun-facing top of a face is lighter, thinning out downwards (ordered dither, no blobs)."""
    px = img.load()
    x0, y0, x1, y1 = box
    bayer = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
    for y in range(y0, min(y1, y0 + rows) + 1):
        dens = 1 - (y - y0) / rows
        for x in range(x0, x1 + 1):
            if bayer[y % 4][x % 4] / 16 < dens * 0.75:
                p = px[x, y]
                if p[3] and p[:3] in keep:
                    px[x, y] = shift(p[:3], k) + (255,)


def water_stain(img, x0, x1, y, rnd, length=(4, 16), every=(2, 6), k=-1):
    """rain streaks under a sill/slab edge: thin vertical darker runs of random length."""
    px = img.load()
    W, Hh = img.size
    x = x0
    while x <= x1:
        ln = rnd.randint(*length)
        for i in range(ln):
            yy = y + i
            if yy >= Hh or (i > ln * 0.6 and (i + x) % 2):
                continue
            p = px[x, yy]
            if p[3]:
                px[x, yy] = shift(p[:3], k) + (255,)
        x += rnd.randint(*every)


def grime_bottom(img, box, rows=4):
    px = img.load()
    x0, y0, x1, y1 = box
    for i in range(rows):
        y = y1 - i
        for x in range(x0, x1 + 1):
            if i < rows // 2 or (x + y) % 2 == 0:
                p = px[x, y]
                if p[3]:
                    px[x, y] = shift(p[:3], -1) + (255,)


def chip(img, mask, rnd, n, under="P06"):
    """paint chipped off letters: small clusters show the primer, with a 1px dark lip below each chip."""
    px = img.load()
    pts = sorted(mask)
    for _ in range(n):
        x, y = rnd.choice(pts)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (rnd.choice((-1, 1)), 0)):
            if (x + dx, y + dy) in mask:
                px[x + dx, y + dy] = C(under)
        if (x, y + 2) in mask:
            px[x, y + 2] = C(shift_t(under, -2))


def crack(img, pts, col="P02", hi=None):
    d = ImageDraw.Draw(img)
    d.line(pts, fill=C(col))
    if hi:
        d.line([(x + 1, y + 1) for x, y in pts], fill=C(hi))


def bullet_hole(img, x, y):
    px = img.load()
    px[x, y] = C("P00"); px[x + 1, y] = C("P01"); px[x, y + 1] = C("P01")
    for dx, dy in ((-1, -1), (2, 0), (0, 2), (2, 2), (-1, 1)):
        p = px[x + dx, y + dy]
        if p[3]:
            px[x + dx, y + dy] = shift(p[:3], 2) + (255,)


# ------------------------------------------------------------------------------------------------ 봉천 상가 간판 5
def sign_bungae():
    """① 번개24 봉천점 — 처마 띠 라이트박스 (청솔식품: 하늘청 P46 + 주황 P27 + 흰 P09). 로고는 '24' 숫자 뒤를 지나는
    번개. 석라희가 지금도 고쳐 쓰는 가게라 낡음은 덜하고, 깨진 오른쪽 끝을 함석으로 덧댔다.
    밤 점등은 facade(night=True)가 면 전체를 켠다(라이트박스)."""
    w, h = 172, 28
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, w - 1, h - 1, "P46", frame="P02", lip="P06", hi="P15")
    d.rectangle([2, 21, w - 3, 23], fill=C("P27")); d.line([2, 21, w - 3, 21], fill=C("P50"))
    d.line([2, 24, w - 3, 24], fill=C("P25"))
    # logo: orange tile, a yellow bolt running behind the white '24'
    d.rectangle([4, 3, 27, 20], fill=C("P27")); d.line([4, 3, 27, 3], fill=C("P50")); d.line([27, 4, 27, 20], fill=C("P26"))
    d.polygon([(20, 3), (13, 12), (17, 12), (11, 20), (22, 10), (18, 10), (23, 3)], fill=C("P50"))
    d.line([(20, 3), (13, 12)], fill=C("P09"))
    m24, w24 = text_mask("24", 1)
    stamp(img, m24, 4 + (24 - w24) // 2, 4, "P09", shadow="P25")
    mt, wt = text_mask("번개24", 1)
    letters = stamp(img, mt, 33, 4, "P09", shadow="P44")
    ms, ws = text_mask("봉천점", 1)
    sx = w - 16 - ws - 7
    d.rectangle([sx, 3, sx + ws + 6, 19], fill=C("P09")); d.line([sx, 19, sx + ws + 6, 19], fill=C("P07"))
    d.line([sx + ws + 6, 3, sx + ws + 6, 19], fill=C("P08"))
    stamp(img, ms, sx + 3, 4, "P44", shadow="P14")
    rnd = random.Random(24)
    # patched right end: a tin sheet riveted over the cracked acrylic
    d.rectangle([w - 14, 2, w - 3, 25], fill=C("P06")); d.line([w - 14, 2, w - 14, 25], fill=C("P04"))
    d.line([w - 13, 2, w - 3, 2], fill=C("P07")); d.line([w - 13, 14, w - 3, 14], fill=C("P05"))
    for y in (5, 12, 18, 23):
        d.point((w - 11, y), fill=C("P03")); d.point((w - 5, y), fill=C("P03"))
    crack(img, [(w - 15, 6), (w - 21, 9), (w - 24, 8)], "P44")
    rust_streak(img, w - 11, 6, 14, rnd); rust_streak(img, w - 5, 13, 10, rnd)
    for bx in (3, w // 2, w - 16):
        rust_streak(img, bx, 25, 3, rnd)
    chip(img, letters, rnd, 3)
    grime_bottom(img, (2, 2, w - 3, 25), 2)
    for bx in (2, w // 2, w - 4):
        bolt(d, bx, 25)
    return img


LIT_BUNGAE = (2, 2, 172 - 17, 24)                 # lightbox face for the night pass


def sign_pharmacy():
    """② 봉천약국 — 흰 아크릴 라이트박스 + 붉은 '약' 원판. 2277: 누렇게 바랜 아크릴, 오른쪽이 깨져 안쪽 형광관
    자리(어둠)가 보인다. 하숙자 약국이 이 간판을 그대로 쓴다."""
    w, h = 134, 30
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, w - 1, h - 1, "P09", frame="P02", lip="P05", lo="P08")
    d.ellipse([4, 3, 27, 26], fill=C("P53")); d.arc([4, 3, 27, 26], 200, 290, fill=C("P54"))
    d.arc([4, 3, 27, 26], 20, 110, fill=C("P52"))
    m, mw = text_mask("약")
    stamp(img, m, 4 + (24 - 15) // 2, 7, "P09")
    mt, wt = text_mask("봉천약국", 1)
    letters = stamp(img, mt, 33, 7, "P44", shadow="P14")
    rnd = random.Random(7)
    blotch(img, (2, 2, w - 3, h - 3), rnd, -1, n=3, r=(10, 18), keep={P.rgb("P09")})      # yellowed acrylic
    px = img.load()
    for y in range(2, h - 2):
        for x in range(2, w - 2):
            if px[x, y][:3] == P.rgb("P08") and (x * 3 + y) % 5 == 0:
                px[x, y] = C("P22")
    # broken corner: a hole in the acrylic showing the dark box and a tube stub
    o = 12
    hole = [(98 + o, 2), (131, 2), (131, 27), (112 + o, 27), (108 + o, 20), (101 + o, 16), (103 + o, 9)]
    d.polygon(hole, fill=C("P01"))
    d.line([(103 + o, 9), (101 + o, 16), (108 + o, 20), (112 + o, 27)], fill=C("P07"))      # lit broken edge
    d.line([105 + o, 12, 131, 12], fill=C("P05")); d.line([105 + o, 13, 131, 13], fill=C("P03"))   # tube
    d.point((110 + o, 22), fill=C("P04")); d.point((114 + o, 18), fill=C("P03"))
    crack(img, [(98 + o, 2), (93 + o, 8), (95 + o, 13)], "P06")
    crack(img, [(101 + o, 16), (92 + o, 22), (89 + o, 27)], "P06")
    chip(img, letters, rnd, 3, under="P14")
    rust_streak(img, 2, 28, 2, rnd)
    for bx in (2, 60):
        rust_streak(img, bx, 3, 8, rnd)
    grime_bottom(img, (2, 2, w - 3, h - 3), 3)
    return img


def atom(d, cx, cy, r, ring="P46", core="P50"):
    """2077 원자 마크: three flattened orbits and a hot nucleus."""
    d.ellipse([cx - r, cy - r // 3, cx + r, cy + r // 3], outline=C(ring))
    for ang in (60, 120):
        import math
        pts = []
        for i in range(48):
            t = i / 48 * 2 * math.pi
            x, y = r * math.cos(t), r / 3 * math.sin(t)
            a = math.radians(ang)
            pts.append((round(cx + x * math.cos(a) - y * math.sin(a)), round(cy + x * math.sin(a) + y * math.cos(a))))
        d.point(pts, fill=C(ring))
    d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=C(core)); d.point((cx - 1, cy - 1), fill=C("P09"))


def sign_academy():
    """③ 원자학원 — 2단 간판. 위: 남색 판에 노란 입체 글자 + 원자 마크. 아래: 흰 띠 '적성 평가 대비반'.
    오른쪽 위 붉은 별 딱지 '97%'. 2277: 남색이 바래고 노란 칠이 벗겨졌다. 총알 자국 셋."""
    w, h = 150, 50
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, w - 1, 29, "P43", frame="P01", lip="P05", hi="P44")
    panel(d, 0, 29, w - 1, h - 1, "P09", frame="P01", lip="P05", lo="P08")
    atom(d, 17, 15, 11)
    mt, wt = text_mask("원자학원", 2)
    tx = 34
    letters = stamp(img, mt, tx, 7, "P49", shadow="P47", hi="P50")
    mb, wb = text_mask("적성 평가 대비반", 1)
    lower = stamp(img, mb, (w - wb) // 2, 32, "P43", shadow="P14")
    # starburst sticker
    bx, by = w - 22, 14
    import math
    pts = []
    for i in range(16):
        r = 13 if i % 2 == 0 else 10
        a = math.pi * 2 * i / 16 - math.pi / 2
        pts.append((round(bx + r * math.cos(a)), round(by + r * math.sin(a))))
    d.polygon(pts, fill=C("P53"), outline=C("P51"))
    d.line([(bx - 8, by - 8), (bx - 3, by - 11)], fill=C("P54"))
    m97, w97 = text_mask("97%", 1)
    m97 = {(x, y) for x, y in m97}
    stamp(img, m97, bx - w97 // 2, by - 7, "P09", shadow="P51")
    rnd = random.Random(97)
    fade_top(img, (2, 2, w - 3, 27), {P.rgb("P43")}, rows=14)
    chip(img, letters, rnd, 9, under="P05")
    water_stain(img, 3, w - 4, 31, rnd, length=(2, 8), every=(3, 9))
    for x, y in ((62, 20), (71, 24), (118, 38)):
        bullet_hole(img, x, y)
    for x in (3, 76, w - 4):
        rust_streak(img, x, 27, 10, rnd)
    grime_bottom(img, (2, 31, w - 3, h - 3), 3)
    for bx_, by_ in ((2, 2), (w - 4, 2), (2, h - 4), (w - 4, h - 4)):
        bolt(d, bx_, by_)
    return img


def sign_laundry():
    """④ 아토믹 빨래방 — 청록 판 + 세탁기 창 겸 원자 마크, 아래 호박색 띠 '24시 코인 세탁'.
    2277: '래' 글자가 떨어져 나가 나사 구멍과 덜 바랜 글자 자국만 남았다('빨 방')."""
    w, h = 156, 46
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, w - 1, 27, "P61", frame="P01", lip="P05", hi="P62")
    panel(d, 0, 27, w - 1, h - 1, "P59", frame="P01", lip="P05", hi="P60", lo="P58")
    # porthole + orbit
    d.ellipse([5, 4, 24, 23], fill=C("P05")); d.ellipse([7, 6, 22, 21], fill=C("P63"))
    d.ellipse([9, 8, 20, 19], fill=C("P62")); d.arc([9, 8, 20, 19], 200, 260, fill=C("P09"))
    d.ellipse([1, 11, 28, 16], outline=C("P50"))
    d.point((14, 13), fill=C("P50"))
    words = "아토믹 빨래방"
    mt, wt = text_mask(words, 1)
    tx = 32
    letters = stamp(img, mt, tx, 6, "P09", shadow="P61" if False else "P01", hi=None)
    # '래' fell off: find its column span and replace with a ghost (less-faded face) + two screw holes
    x_lae = tx + sum(H.advance(c) for c in "아토믹 빨")
    ghost = {(x, y) for x, y in letters if x_lae <= x < x_lae + 15}
    px = img.load()
    for x, y in ghost:
        px[x, y] = C("P62") if (x + y) % 2 == 0 else C("P61")
    for x, y in {(x + 1, y + 1) for x, y in ghost} - ghost:
        if px[x, y][:3] == P.rgb("P01"):
            px[x, y] = C("P61")
    px[x_lae + 3, 9] = C("P00"); px[x_lae + 11, 17] = C("P00")
    mb, wb = text_mask("24시 코인 세탁", 1)
    stamp(img, mb, (w - wb) // 2, 29, "P16", shadow=None)
    rnd = random.Random(5)
    fade_top(img, (2, 2, w - 3, 25), {P.rgb("P61")}, rows=12)
    water_stain(img, 3, w - 4, 29, rnd, length=(2, 7), every=(3, 9))
    chip(img, letters - ghost, rnd, 5, under="P07")
    for x in (2, 54, 110, w - 3):
        rust_streak(img, x, 26, 12, rnd)
    crack(img, [(120, 2), (124, 9), (122, 15)], "P01")
    grime_bottom(img, (2, 29, w - 3, h - 3), 3)
    return img


def sign_terminal():
    """⑤ 단말기실 — 세로 돌출 간판(2077년 PC방 → 단말기실, §2.3). 붉은 판, 흰 글자 세로 4자, 머리에 녹색 CRT 아이콘.
    벽에서 내민 철 팔걸이에 매달렸다. 2277: 아래쪽 칠이 녹물에 잠기고 팔걸이가 녹슬었다."""
    pw, ph = 25, 98
    w, h = pw + 9, ph + 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # wall bracket (left): two arms + brace
    for y in (6, ph - 10):                              # wall plates + square tube arms
        d.rectangle([0, y - 3, 2, y + 5], fill=C("P04")); d.line([0, y - 3, 0, y + 5], fill=C("P06"))
        d.point((1, y - 2), fill=C("P02")); d.point((1, y + 4), fill=C("P02"))
        d.rectangle([3, y, 9, y + 2], fill=C("P04")); d.line([3, y, 9, y], fill=C("P06"))
        d.line([3, y + 2, 9, y + 2], fill=C("P02"))
    for i in range(12):                                 # diagonal brace under the top arm
        d.point((3 + i // 2, 20 - i), fill=C("P04")); d.point((3 + i // 2, 21 - i), fill=C("P02"))
    ox = 9
    panel(d, ox, 0, ox + pw - 1, ph - 1, "P52", frame="P01", lip="P05", hi="P53")
    # CRT icon
    d.rectangle([ox + 5, 4, ox + 19, 15], fill=C("P08")); d.rectangle([ox + 7, 6, ox + 17, 13], fill=C("U2"))
    d.line([ox + 8, 8, ox + 13, 8], fill=C("U6")); d.line([ox + 8, 10, ox + 11, 10], fill=C("U5"))
    d.rectangle([ox + 10, 16, ox + 14, 17], fill=C("P06"))
    mv, hv = vtext_mask("단말기실", 3)
    letters = stamp(img, mv, ox + (pw - 15) // 2, 21, "P09", shadow="P51")
    rnd = random.Random(4)
    # rust water rising from the bottom
    px = img.load()
    for y in range(ph - 26, ph - 2):
        for x in range(ox + 2, ox + pw - 2):
            t = (y - (ph - 26)) / 24
            if rnd.random() < t * 0.9:
                p = px[x, y]
                if p[:3] == P.rgb("P52"):
                    px[x, y] = C("P25" if rnd.random() < 0.6 else "P51")
                elif p[:3] == P.rgb("P09") and rnd.random() < t * 0.6:
                    px[x, y] = C("P21")
    fade_top(img, (ox + 2, 2, ox + pw - 3, ph - 30), {P.rgb("P52")}, rows=20)
    chip(img, letters, rnd, 5, under="P06")
    for y in (6, ph - 10):
        rust_streak(img, 4, y + 3, 8, rnd)
    bolt(d, ox + 2, 2); bolt(d, ox + pw - 4, 2); bolt(d, ox + 2, ph - 4); bolt(d, ox + pw - 4, ph - 4)
    return img


# ------------------------------------------------------------------------------------------------ S-07 표어 화면 4
CRT_W, CRT_H = 160, 64


def crt(lines, flicker=0, frame=0, graffiti=False, accent=None):
    """표어 화면: 아트리움 벽걸이 대형 CRT (5×2타일). 크림 하우징(P08) + 볼트 청 받침, 녹색 형광(U) 글자에 1px 번짐,
    주사선. lines: [(text, y)] 가운데 정렬. flicker: 0~1 (frame 별 밝기 변조, GIF용)."""
    img = Image.new("RGBA", (CRT_W, CRT_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, CRT_W - 1, CRT_H - 1], radius=5, fill=C("P08"), outline=C("P02"))
    d.line([4, 1, CRT_W - 5, 1], fill=C("P09")); d.line([1, 4, 1, CRT_H - 5], fill=C("P09"))
    d.line([4, CRT_H - 2, CRT_W - 5, CRT_H - 2], fill=C("P06")); d.line([CRT_W - 2, 4, CRT_W - 2, CRT_H - 5], fill=C("P06"))
    sx0, sy0, sx1, sy1 = 6, 5, CRT_W - 7, CRT_H - 11
    d.rounded_rectangle([sx0 - 1, sy0 - 1, sx1 + 1, sy1 + 1], radius=4, fill=C("P03"))
    d.rounded_rectangle([sx0, sy0, sx1, sy1], radius=4, fill=C("U1"))
    # tube curvature: brighter centre band, darker corners
    for y in range(sy0, sy1 + 1):
        for x in range(sx0, sx1 + 1):
            ex = ((x - (sx0 + sx1) / 2) / ((sx1 - sx0) / 2)) ** 2 + ((y - (sy0 + sy1) / 2) / ((sy1 - sy0) / 2)) ** 2
            if ex > 1.25 and img.getpixel((x, y))[:3] == P.rgb("U1"):
                img.putpixel((x, y), C("U0"))
    lit = set()
    for text, y in lines:
        m, w = text_mask(text, 1)
        lit |= {(x + (CRT_W - w) // 2, yy + y) for x, yy in m}
    base = "U6" if flicker < 0.5 else "U5"
    halo = "U3"
    px = img.load()
    for x, y in lit:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in lit and px[q][:3] in (P.rgb("U1"), P.rgb("U0")):
                px[q] = C(halo)
    for x, y in lit:
        px[x, y] = C(base)
        if (x, y - 1) not in lit:
            px[x, y] = C("U7" if flicker < 0.5 else "U6")
    # scanlines (every other row one step down) + a slow roll band
    roll = (frame * 3) % (sy1 - sy0 + 12) + sy0 - 6
    for y in range(sy0 + 1, sy1, 2):
        for x in range(sx0 + 1, sx1):
            p = px[x, y]
            if p[:3] in _U:
                px[x, y] = shift(p[:3], -1) + (255,)
    for y in range(max(sy0, roll), min(sy1, roll + 3) + 1):
        for x in range(sx0 + 1, sx1):
            p = px[x, y]
            if p[:3] in _U:
                px[x, y] = shift(p[:3], 1) + (255,)
    if accent:
        accent(img, d, px)
    # housing details: grille, power lamp, brand plate, mount
    for x in range(10, 40, 3):
        d.line([x, CRT_H - 8, x, CRT_H - 5], fill=C("P06"))
    d.rectangle([CRT_W - 16, CRT_H - 8, CRT_W - 10, CRT_H - 5], fill=C("P06"))
    d.point((CRT_W - 13, CRT_H - 7), fill=C("P56" if frame % 8 < 6 else "P55"))
    d.rectangle([CRT_W // 2 - 14, CRT_H - 8, CRT_W // 2 + 14, CRT_H - 5], fill=C("P45"))
    d.line([CRT_W // 2 - 14, CRT_H - 8, CRT_W // 2 + 14, CRT_H - 8], fill=C("P46"))
    d.line([CRT_W // 2 - 10, CRT_H - 6, CRT_W // 2 + 10, CRT_H - 6], fill=C("P49"))
    if graffiti:
        graffiti(img, frame)
    return img


_U = {P.rgb(f"U{i}") for i in range(8)}


def _spray(img, mask, ox, oy, rnd, col="P53", dark="P52", mist="P51", drips=4):
    px = img.load()
    W, Hh = img.size
    m = {(x + ox, y + oy) for x, y in mask}
    for x, y in m:
        for _ in range(1):
            q = (x + rnd.randint(-2, 2), y + rnd.randint(-2, 2))
            if q not in m and 0 <= q[0] < W and 0 <= q[1] < Hh and px[q][3] and rnd.random() < 0.18:
                px[q] = C(mist)
    for x, y in m:
        if 0 <= x < W and 0 <= y < Hh:
            px[x, y] = C(col if (x, y + 1) in m or rnd.random() < 0.6 else dark)
    bottoms = sorted({(x, y) for x, y in m if (x, y + 1) not in m and px[x, y][3]})
    for x, y in rnd.sample(bottoms, min(drips, len(bottoms))):
        ln = rnd.randint(2, 6)
        for i in range(1, ln + 1):
            if y + i < Hh and px[x, y + i][3]:
                px[x, y + i] = C(dark if i < ln else col)


def _scrawl(text, rnd, tilt=-0.07):
    """graffiti letters: full-weight glyphs on a tilted, wobbling baseline, each letter a little rotated by shear."""
    S, x = set(), 0
    for i, ch in enumerate(text):
        if ch == " ":
            x += 5
            continue
        g = H.glyph(ch)
        sh = rnd.choice((-1, 0, 0, 1))
        dy = round(x * tilt) + rnd.randint(-1, 1)
        S |= {(gx + x + (sh * (7 - gy)) // 8, gy + dy) for gx, gy in g}
        x += H.advance(ch) - 1
    miny = min(y for _, y in S)
    return {(gx, gy - miny) for gx, gy in S}, x


def s07_screens(frame=0):
    """the four S-07 screens. ① 성적이 곧 미래다 ② 오버시어님께 / 감사합니다 ③ 4막 점령판: ②에 붉은 줄 + '누구의 오버시어?'
    낙서, 화면 금 ④ 적성 평가 D-3 / 연수생은 교무과로 (D-day 숫자 깜박)."""
    out = []
    f = (frame % 12) / 12
    out.append(crt([("성적이 곧 미래다", 20)], frame=frame))
    out.append(crt([("오버시어님께", 11), ("감사합니다", 29)], frame=frame + 4))

    def occupied(img, frame_):
        rnd = random.Random(23)
        px = img.load()
        # glass crack radiating from a hit at the right
        cx, cy = 128, 16
        dd = ImageDraw.Draw(img)
        for ang_pts in ([(cx, cy), (138, 8), (146, 6)], [(cx, cy), (116, 10), (104, 6)], [(cx, cy), (134, 28), (140, 44)],
                        [(cx, cy), (120, 24), (112, 38)]):
            dd.line(ang_pts, fill=C("P02"))
            dd.line([(x - 1, y) for x, y in ang_pts], fill=C("U3"))
        px[cx, cy] = C("P00"); px[cx + 1, cy] = C("P01")
        # red strike through line 1, sprayed, slightly uphill
        strike = set()
        for x in range(16, 146):
            y = 14 - (x - 16) // 26 + (1 if x % 37 < 3 else 0)
            for k in range(3):
                strike.add((x, y + k))
        _spray(img, strike, 0, 0, rnd, drips=6)
        m, w = _scrawl("누구의 오버시어?", rnd, tilt=-0.03)
        ox, oy = (CRT_W - w) // 2 + 2, 39
        px2 = img.load()
        for x, y in {(x + ox + 1, y + oy + 1) for x, y in m} - {(x + ox, y + oy) for x, y in m}:
            if 0 <= x < CRT_W and 0 <= y < CRT_H:
                px2[x, y] = C("P51")
        _spray(img, m, ox, oy, rnd, col="P54", dark="P53", mist="P52", drips=6)
    out.append(crt([("오버시어님께", 7), ("감사합니다", 23)], frame=frame + 8, graffiti=occupied))

    def countdown(img, d, px):
        if frame % 8 >= 6:              # the D-day number blinks off two frames in eight
            for y in range(9, 26):
                for x in range(98, 110):
                    if px[x, y][:3] in _U and px[x, y][:3] != P.rgb("U0"):
                        px[x, y] = C("U1")
    out.append(crt([("적성 평가 D-3", 9), ("연수생은 교무과로", 29)], frame=frame + 2, accent=countdown))
    return out


# ------------------------------------------------------------------------------------------------ sheets
F9 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)


def _label(d, xy, s, col="P08"):
    d.fontmode = "1"
    x, y = xy
    d.text((x + 1, y + 1), s, font=F9, fill=C("P00"))
    d.text((x, y), s, font=F9, fill=C(col))


def wall(w, h, seed=3):
    """painted-concrete shop front band: P05 base, form seams, stains (the signs' real backdrop in 봉천)."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (w, h), C("P05"))
    px = img.load()
    for y in range(h):
        for x in range(w):
            r = rnd.random()
            if r < 0.06:
                px[x, y] = C("P04")
            elif r < 0.09:
                px[x, y] = C("P06")
    d = ImageDraw.Draw(img)
    for y in range(31, h, 32):
        d.line([0, y, w - 1, y], fill=C("P04")); d.line([0, y + 1, w - 1, y + 1], fill=C("P06"))
    for y in range(0, h, 32):
        water_stain(img, 0, w - 1, y + 2, rnd, length=(2, 14), every=(2, 10))
    return img


def _window(d, x0, y0, x1, y1, broken=False, lit=None):
    """aluminium window: frame, two sashes, glass with a diagonal sky reflection. broken: jagged hole."""
    d.rectangle([x0, y0, x1, y1], fill=C("P04"))
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C("P07"))
    gx0, gy0, gx1, gy1 = x0 + 3, y0 + 3, x1 - 3, y1 - 3
    d.rectangle([gx0, gy0, gx1, gy1], fill=C(lit or "P11"))
    if not lit:
        for k in range(gx0 - (gy1 - gy0), gx1, 14):
            d.line([(max(gx0, k), gy1 - max(0, gx0 - k)), (min(gx1, k + (gy1 - gy0)), gy0 + max(0, k + (gy1 - gy0) - gx1))],
                   fill=C("P13"))
            d.line([(max(gx0, k + 2), gy1 - max(0, gx0 - k - 2)), (min(gx1, k + 2 + (gy1 - gy0)), gy0 + max(0, k + 2 + (gy1 - gy0) - gx1))],
                   fill=C("P12"))
    else:
        d.rectangle([gx0, gy0, gx1, gy0 + 4], fill=C("P58"))              # curtain head
        for x in range(gx0, gx1 + 1, 3):
            d.line([x, gy0 + 5, x, gy1], fill=C("P59"))
    mx = (x0 + x1) // 2
    d.rectangle([mx - 1, y0 + 1, mx + 1, y1 - 1], fill=C("P07")); d.line([mx + 1, y0 + 2, mx + 1, y1 - 2], fill=C("P05"))
    d.line([gx0, gy0, gx1, gy0], fill=C("P03"))                              # head shadow
    d.line([x0, y1 + 1, x1, y1 + 1], fill=C("P08")); d.line([x0, y1 + 2, x1, y1 + 2], fill=C("P05"))   # sill
    water_stain(d._image, x0 + 1, x1 - 1, y1 + 3, random.Random(x0 * 7 + y0), length=(2, 10), every=(2, 6))
    if broken:
        cx, cy = (gx0 + mx) // 2, (gy0 + gy1) // 2
        pts = [(cx - 7, cy - 6), (cx - 2, cy - 9), (cx + 1, cy - 5), (cx + 6, cy - 7), (cx + 4, cy - 1), (cx + 7, cy + 4),
               (cx + 1, cy + 3), (cx - 3, cy + 8), (cx - 4, cy + 2), (cx - 8, cy + 1)]
        d.polygon(pts, fill=C("P01"))
        d.line(pts[:5], fill=C("P14"))


NIGHT = ["P00", "P01", "P10", "P02", "P11", "P03", "P12"]
_NL = {}


def night_rgb(rgb):
    """night remap: luminance -> 9-step dark cool ramp; saturated paint keeps a hint of its hue one step down."""
    if rgb in _NL:
        return _NL[rgb]
    r, g, b = rgb
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255
    out = P.rgb(NIGHT[min(len(NIGHT) - 1, int(lum * len(NIGHT)))])
    if max(rgb) - min(rgb) > 70 and rgb in _POS:             # coloured paint: its own ramp, 3 steps down
        out = shift(rgb, -3)
        if sum(out) > sum(P.rgb("P12")):
            out = shift(out, -1)
    _NL[rgb] = out
    return out


def facade(night=False):
    """봉천 상가 정면 320×360: 3층 상가 + 옥상 물탱크·원자력 온수기 돔, 층마다 간판(간판 숲), 1층 번개24와 약국.
    night: 전체를 두 단계 어둡게 내리고, 지금도 켜는 번개24 라이트박스와 가게 유리만 원래 밝기 + 번짐."""
    W, Hh = 320, 360
    img = Image.new("RGBA", (W, Hh), C("P14"))
    d = ImageDraw.Draw(img)
    rnd = random.Random(11)
    for y in range(0, 34):
        for x in range(W):
            if y > 20 or (y > 16 and (x + y) % 2 == 0):
                img.putpixel((x, y), C("P15"))
    bx0, bx1 = 6, 313
    # roof: tank, fission water-heater dome, parapet
    d.rectangle([236, 8, 270, 30], fill=C("P45")); d.line([236, 8, 270, 8], fill=C("P46")); d.line([270, 9, 270, 30], fill=C("P44"))
    for y in (14, 21):
        d.line([237, y, 269, y], fill=C("P44"))
    d.line([240, 30, 240, 33], fill=C("P03")); d.line([266, 30, 266, 33], fill=C("P03"))
    d.pieslice([196, 14, 222, 40], 180, 360, fill=C("P08")); d.arc([196, 14, 222, 40], 200, 250, fill=C("P09"))
    d.arc([196, 14, 222, 40], 300, 350, fill=C("P06")); d.rectangle([207, 12, 210, 15], fill=C("P05"))
    d.point((216, 20), fill=C("P56"))
    d.rectangle([bx0, 33, bx1, 41], fill=C("P08")); d.line([bx0, 33, bx1, 33], fill=C("P09"))
    d.line([bx0, 41, bx1, 41], fill=C("P05"))
    # walls
    d.rectangle([bx0, 42, bx1, 309], fill=C("P07"))
    for x in range(bx0 + 30, bx1, 38):
        d.line([x, 42, x, 309], fill=C("P06"))
    for y in range(52, 309, 10):
        for x in range(bx0, bx1, 2):
            if rnd.random() < 0.05:
                img.putpixel((x, y), C("P06"))
    for y in (42, 122, 202):
        water_stain(img, bx0 + 1, bx1 - 1, y + (5 if y > 42 else 0), rnd, length=(2, 16), every=(2, 11))
    d.line([bx1, 42, bx1, 309], fill=C("P05")); d.line([bx0, 42, bx0, 309], fill=C("P08"))
    for y in (121, 201):                                       # floor slabs
        d.rectangle([bx0, y, bx1, y + 4], fill=C("P08")); d.line([bx0, y + 4, bx1, y + 4], fill=C("P05"))
        d.line([bx0, y + 5, bx1, y + 5], fill=C("P06"))
    # 3F
    _window(d, 176, 58, 236, 104); _window(d, 244, 58, 304, 104, broken=True)
    img.alpha_composite(sign_academy(), (14, 54))
    for x in (40, 120):
        rust_streak(img, x, 104, 16, rnd)
    # 2F
    _window(d, 182, 136, 262, 184, lit=("P60" if night else None))
    img.alpha_composite(sign_laundry(), (14, 136))
    # 1F storefronts
    glass = (10, 238, 176, 309)
    d.rectangle([glass[0], glass[1], glass[2], glass[3]], fill=C("P04"))
    for k, gx in enumerate(range(12, 176, 33)):
        x1 = min(gx + 30, 174)
        if k >= 4:                                              # boarded panes (plywood, nails)
            d.rectangle([gx, 240, x1, 307], fill=C("P19"))
            for yy in range(240, 308, 7):
                d.line([gx, yy, x1, yy], fill=C("P18")); d.line([gx, yy + 1, x1, yy + 1], fill=C("P20"))
            for yy in range(243, 308, 7):
                d.point((gx + 2, yy), fill=C("P03")); d.point((x1 - 2, yy), fill=C("P03"))
            continue
        d.rectangle([gx, 240, x1, 307], fill=C("P15" if night else "P11"))
        for yy in (258, 276, 294):                                 # shelves seen through the glass
            d.line([gx + 2, yy, x1 - 2, yy], fill=C("P05"))
            for xx in range(gx + 3, x1 - 2, 3):
                col = ("P27", "P46", "P09", "P49")[(xx // 3 + yy) % 4]
                if (xx * 7 + yy) % 5:
                    d.rectangle([xx, yy - 4, xx + 1, yy - 1], fill=C(col))
        if not night:
            d.line([(gx + 4, 307), (x1 - 2, 244)], fill=C("P13"))
        if k == 2:                                               # door
            d.rectangle([gx + 13, 252, gx + 15, 270], fill=C("P07"))
    d.line([10, 238, 176, 238], fill=C("P02"))
    # pharmacy: roller shutter half down
    d.rectangle([180, 238, 311, 309], fill=C("P01"))
    for yy in range(238, 282, 3):
        d.line([180, yy, 311, yy], fill=C("P06")); d.line([180, yy + 1, 311, yy + 1], fill=C("P05"))
        d.line([180, yy + 2, 311, yy + 2], fill=C("P04"))
    d.rectangle([180, 282, 311, 284], fill=C("P07")); d.line([180, 285, 311, 285], fill=C("P02"))
    water_stain(img, 181, 310, 238, rnd, length=(3, 14), every=(2, 7))
    for x in (200, 236, 290):
        rust_streak(img, x, 240, 30, rnd)
    for x in range(184, 308, 9):                                 # medicine shelves in the dark
        d.line([x, 294, x + 5, 294], fill=C("P03"))
    img.alpha_composite(sign_bungae(), (6, 206))
    img.alpha_composite(sign_pharmacy(), (179, 206))
    img.alpha_composite(sign_terminal(), (bx1 - 33, 106))
    # pavement + curb + road
    d.rectangle([0, 310, W - 1, 341], fill=C("P06"))
    for y in range(310, 342, 8):
        d.line([0, y, W - 1, y], fill=C("P05"))
        for x in range((y // 8 % 2) * 8, W, 16):
            d.line([x, y, x, y + 7], fill=C("P05"))
    d.line([0, 310, W - 1, 310], fill=C("P03"))
    d.rectangle([0, 342, W - 1, 345], fill=C("P08")); d.line([0, 346, W - 1, 346], fill=C("P04"))
    d.rectangle([0, 347, W - 1, Hh - 1], fill=C("P03"))
    for x in range(8, W, 40):
        d.line([x, 353, x + 18, 353], fill=C("P07"))
    for x, y in ((30, 309), (154, 309), (300, 309), (230, 309)):  # weeds at the wall foot
        for k in range(5):
            d.line([x + k, y, x + k - 1 + (k % 2) * 2, y - 2 - (k * 3) % 5], fill=C("P30" if k % 2 else "P31"))
    for x, y in ((92, 322), (246, 330)):                         # rubble
        d.polygon([(x, y), (x + 5, y - 3), (x + 9, y), (x + 6, y + 2)], fill=C("P05"))
        d.line([x + 1, y - 1, x + 5, y - 3], fill=C("P08"))
    if not night:
        d.polygon([(bx1 + 1, 42), (W - 1, 50), (W - 1, 309), (bx1 + 1, 309)], fill=C("P06"))
        return img
    # ---- night pass: every colour falls onto a cool night ramp by luminance (moonlight from the upper left)
    day = img.copy()
    px = img.load()
    for y in range(Hh):
        for x in range(W):
            px[x, y] = night_rgb(px[x, y][:3]) + (255,)
    for y in range(0, 33):                                      # night sky behind the roof props
        for x in range(W):
            if px[x, y][:3] in (P.rgb("P11"), P.rgb("P12")):
                px[x, y] = C("P10") if y > 14 or (x + y) % 2 else C("P01")
    for sx, sy in ((22, 6), (70, 14), (130, 4), (162, 20), (288, 11), (300, 24)):
        px[sx, sy] = C("P13")
    keep = [(6 + LIT_BUNGAE[0], 206 + LIT_BUNGAE[1], 6 + LIT_BUNGAE[2], 206 + LIT_BUNGAE[3]),
            (12, 240, 141, 307)]
    dpx = day.load()
    for x0, y0, x1, y1 in keep:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px[x, y] = dpx[x, y]
    # window on 2F stays warm
    for y in range(139, 182):
        for x in range(185, 260):
            if dpx[x, y][:3] in (P.rgb("P58"), P.rgb("P59"), P.rgb("P60")):
                px[x, y] = dpx[x, y]
    # spill: halo round the lightbox, a light pool on the pavement under the glass
    for y in range(196, 246):
        for x in range(0, 186):
            inside = any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in keep)
            if inside:
                continue
            dx = max(keep[0][0] - x, 0, x - keep[0][2])
            dy = max(keep[0][1] - y, 0, y - keep[0][3])
            dist = max(dx, dy)
            if dist <= 2 or (dist <= 5 and (x + y) % 2 == 0):
                px[x, y] = shift(px[x, y][:3], 1) + (255,)
    for y in range(310, 342):
        spread = (y - 310) // 2
        for x in range(12 - spread, 142 + spread):
            if 0 <= x < W:
                f = (y - 310) / 32
                if (f < 0.5) or (x + y) % 2 == 0:
                    px[x, y] = shift(px[x, y][:3], 2 if f < 0.3 else 1) + (255,)
    return img


def bongcheon_sheet():
    W, Hh = 640, 360
    sh = Image.new("RGBA", (W, Hh), C("P00"))
    sh.alpha_composite(facade(False), (0, 0))
    sh.alpha_composite(facade(True), (320, 0))
    d = ImageDraw.Draw(sh)
    _label(d, (4, 346), "낮", "P09"); _label(d, (324, 346), "밤 — 번개24만 켜짐", "P09")
    return sh


def detail_sheet():
    """the five signs alone on a wall band, with captions (shown ×3)."""
    W, Hh = 420, 168
    sh = wall(W, Hh, seed=8)
    d = ImageDraw.Draw(sh)
    items = [(sign_bungae(), (6, 6), "① 번개24 — 덧댄 함석"),
             (sign_pharmacy(), (6, 56), "② 봉천약국 — 깨진 아크릴"),
             (sign_academy(), (6, 104), "③ 원자학원 — 총알 자국"),
             (sign_laundry(), (196, 6), "④ 아토믹 빨래방 — '래' 떨어짐"),
             (sign_terminal(), (380, 6), "⑤ 단말기실")]
    for img, (x, y), lab in items:
        sh.alpha_composite(img, (x, y))
    for img, (x, y), lab in items:
        if "단말기실" in lab:
            _label(d, (x - 14, y + img.height + 2), lab)
        else:
            _label(d, (x, y + img.height + 1), lab)
    return sh


def s07_sheet(frame=0):
    W, Hh = 360, 172
    sh = Image.new("RGBA", (W, Hh), C("P44"))
    d = ImageDraw.Draw(sh)
    for y in range(0, Hh, 32):                               # vault wall panels (P44 with P43 seams, yellow band)
        d.line([0, y, W - 1, y], fill=C("P43"))
    for x in range(0, W, 32):
        d.line([x, 0, x, Hh - 1], fill=C("P43"))
    d.rectangle([0, Hh - 10, W - 1, Hh - 6], fill=C("P48")); d.line([0, Hh - 10, W - 1, Hh - 10], fill=C("P49"))
    scr = s07_screens(frame)
    pos = [(12, 8), (188, 8), (12, 92), (188, 92)]
    for img, xy in zip(scr, pos):
        sh.alpha_composite(img, xy)
    return sh


def glyph_sheet():
    cols = 25
    rows = len(H.SET150) // cols
    W, Hh = cols * 18 + 8, rows * 20 + 8 + 40
    sh = Image.new("RGBA", (W, Hh), C("P01"))
    d = ImageDraw.Draw(sh)
    for i, ch in enumerate(H.SET150):
        cx, cy = 4 + (i % cols) * 18, 4 + (i // cols) * 20
        d.rectangle([cx, cy, cx + 15, cy + 15], fill=C("P02"))
        stamp(sh, H.glyph(ch), cx, cy, "P09")
    y = 4 + rows * 20 + 2
    m, w = text_mask("0123456789 D-3 S 97% ?!", 1)
    stamp(sh, m, 4, y, "P49")
    _label(d, (4, y + 20), f"간판 대 16×16 · 초판 {len(H.SET150)}자 + 숫자·기호. 자모 조합(초19·중21·종27) — 11,172자 전부 조합 가능", "P07")
    return sh


def x(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def main():
    os.makedirs(OUT, exist_ok=True)
    allowed = P.allowed_set("UI")
    bad = []
    a = bongcheon_sheet()
    a.save(os.path.join(OUT, "20_signs_bongcheon.png")); x(a, 2).save(os.path.join(OUT, "20_signs_bongcheon_x2.png"))
    bad += check(a, allowed)
    det = detail_sheet()
    bad += check(det, allowed)
    x(det, 3).save(os.path.join(OUT, "20_signs_bongcheon_detail_x3.png"))
    frames = [s07_sheet(f) for f in range(16)]
    frames[0].save(os.path.join(OUT, "20_signs_s07.png")); x(frames[0], 2).save(os.path.join(OUT, "20_signs_s07_x2.png"))
    for f in frames:
        bad += check(f, allowed)
    g = [x(f, 2).convert("P", palette=Image.ADAPTIVE, colors=255) for f in frames]
    g[0].save(os.path.join(OUT, "20_signs_s07.gif"), save_all=True, append_images=g[1:], duration=120, loop=0, disposal=1)
    gs = glyph_sheet()
    gs.save(os.path.join(OUT, "20_sign_glyphs_150.png")); x(gs, 3).save(os.path.join(OUT, "20_sign_glyphs_150_x3.png"))
    bad += check(gs, allowed)
    print("signs off-palette:", sorted(set(bad)) or 0)


if __name__ == "__main__":
    main()
