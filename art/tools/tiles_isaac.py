"""아이작풍 타일(SD-16 §6 v2.0): R01 바깥(관악산 비탈)·S-07 실내. 이름·순서는 이전 판과 같다(지도 데이터 그대로).
면은 '이어지는 부드러운 얼룩'(타일 경계에서 맞물리는 값 잡음) + 굵은 먹선 이음매 + 때. 소품은 굵은 외곽선과 둥근 덩어리.
"""
import os, sys, math, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

T = 32
CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)
INK = C("P01")
L = (-0.45, -0.65, 0.62)


def new(fill=None, w=1, h=1):
    return Image.new("RGBA", (w * T, h * T), C(fill) if fill else CLEAR)


def _cell(ix, iy, n, k):
    return random.Random((ix % n) * 7919 + (iy % n) * 104729 + k * 1299709).random()


def tnoise(x, y, sc, k):
    """타일(32px)에서 이어지는 값 잡음. sc는 32의 약수."""
    n = T // sc
    fx, fy = x / sc, y / sc
    ix, iy = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = _cell(ix, iy, n, k) * (1 - tx) + _cell(ix + 1, iy, n, k) * tx
    b = _cell(ix, iy + 1, n, k) * (1 - tx) + _cell(ix + 1, iy + 1, n, k) * tx
    return a * (1 - ty) + b * ty


def mottle(img, ramp, seed, box=(0, 0, 32, 32), lo=0.34, hi=0.68, fine=0.3):
    """면 칠하기: 큰 얼룩(16px) + 잔 얼룩(8px) → 램프 [어두움, 바탕, 밝음]."""
    px = img.load()
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            v = tnoise(x, y, 16, seed) * (1 - fine) + tnoise(x, y, 8, seed + 1) * fine
            px[x, y] = C(ramp[0]) if v < lo else C(ramp[2]) if v > hi else C(ramp[1])


def grime(img, seed, amount=0.8, box=(0, 0, 32, 32), sc=8):
    """때: 잡음이 높은 곳을 램프 한 단계 어둡게."""
    px = img.load()
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[x, y][3] and tnoise(x, y, sc, seed + 7) > amount:
                px[x, y] = P.step(px[x, y][:3], -1) + (255,)


def specks(img, seed, n, tok, box=(0, 0, 32, 32)):
    rnd = random.Random(seed)
    for _ in range(n):
        x, y = rnd.randrange(box[0], box[2]), rnd.randrange(box[1], box[3])
        img.putpixel((x, y), C(tok))


def outline(img, col=INK, thick_bottom=True):
    w, h = img.size
    src = img.load()
    out = img.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                o[x, y] = col
    if thick_bottom:
        o2 = out.copy().load()
        for y in range(2, h):
            for x in range(w):
                if not o2[x, y][3] and o2[x, y - 1] == col and o2[x, y - 2][3] and o2[x, y - 2] != col:
                    o[x, y] = col
    return out


def crack(d, rnd, x, y, n, col, w=32, h=32):
    for _ in range(n):
        nx, ny = x + rnd.randint(-4, 4), y + rnd.randint(1, 4)
        d.line([x % w, y % h, nx % w, ny % h], fill=col) if abs(nx % w - x % w) < 8 and abs(ny % h - y % h) < 8 else None
        x, y = nx, ny


def lump(img, cx, cy, rx, ry, ramp, hi=0.62):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            q = nx * nx + ny * ny
            if q <= 1:
                nz = math.sqrt(1 - q)
                dd = nx * L[0] + ny * L[1] + nz * L[2]
                k = 0 if dd < -0.3 else 1 if dd < 0.15 else 2 if dd < hi else 3
                px[x, y] = C(ramp[min(k, len(ramp) - 1)])


# ================================================================ R01 바깥
def dirt(seed=1, grass=0):
    img = new()
    mottle(img, ["P17", "P18", "P19"], seed, lo=0.12, hi=0.9, fine=0.5)
    grime(img, seed, 0.92)
    specks(img, seed + 3, 10, "P16")
    specks(img, seed + 4, 4, "P20")
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    for _ in range(2):                                                # 자갈: 먹선 두른 작은 돌
        x, y = rnd.randint(3, 27), rnd.randint(3, 27)
        d.ellipse([x, y, x + 2, y + 1], fill=C("P06"))
        d.point((x, y), fill=C("P08"))
        d.line([x, y + 2, x + 2, y + 2], fill=C("P02"))
    for _ in range(grass * 3):                                        # 마른 풀 포기
        x, y = rnd.randint(2, 28), rnd.randint(6, 29)
        for k, (dx, h) in enumerate(((-2, 3), (0, 5), (2, 4), (1, 2))):
            col = C("P30") if k % 2 else C("P31")
            d.line([x, y, x + dx, y - h], fill=col)
            d.point((x + dx, y - h), fill=C("P32"))
        d.line([x - 2, y + 1, x + 2, y + 1], fill=C("P16"))
    return img


def asphalt(seed=2, lane=False):
    img = new()
    mottle(img, ["P03", "P04", "P05"], seed, lo=0.3, hi=0.78, fine=0.45)
    specks(img, seed + 1, 14, "P02")
    specks(img, seed + 2, 6, "P06")
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    x, y = rnd.randint(6, 12), 0
    pts = [(x, y)]
    while y < 31:                                                     # 굵은 균열(먹선 + 밝은 가장자리)
        x += rnd.choice((-2, -1, 0, 1, 1, 2))
        y += rnd.randint(2, 4)
        pts.append((max(1, min(30, x)), min(31, y)))
    d.line(pts, fill=C("P01"), width=1)
    d.line([(px + 1, py) for px, py in pts], fill=C("P05"))
    if lane:
        for yy in range(0, 32, 12):                                   # 바랜 차선(끊긴 점선)
            d.rectangle([22, yy + 1, 23, yy + 7], fill=C("P07"))
            d.point((22, yy + 1), fill=C("P08"))
            if (yy // 12) % 2:
                d.point((23, yy + 5), fill=C("P05"))
    return img


def pavers(seed=3, broken=2):
    img = new()
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    tones = [["P05", "P06", "P07"], ["P05", "P06", "P07"], ["P05", "P06", "P07"]]
    missing = set()                                                   # 깨진 판: 구멍 대신 금(되풀이가 눈에 띄지 않게)
    for py in (0, 16):
        for px_ in (0, 16):
            key = (px_ // 16, py // 16)
            if key in missing:
                sub = dirt(seed + 11).crop((px_, py, px_ + 16, py + 16))
                img.paste(sub, (px_, py))
                d.line([px_, py, px_ + 15, py], fill=C("P01"))
                d.line([px_, py, px_, py + 15], fill=C("P01"))
                d.line([px_ + 1, py + 1, px_ + 14, py + 1], fill=C("P16"))
                continue
            tone = tones[(key[0] * 2 + key[1] + seed) % 3]
            mottle(img, tone, seed + key[0] * 3 + key[1], box=(px_, py, px_ + 16, py + 16), lo=0.18, hi=0.85, fine=0.5)
            d.line([px_ + 1, py + 1, px_ + 14, py + 1], fill=C(P_up(tone[2])))      # 윗변 밝게
            d.line([px_ + 1, py + 14, px_ + 14, py + 14], fill=C(tone[0]))
            d.line([px_, py, px_ + 15, py], fill=C("P02"))                          # 이음매
            d.line([px_, py, px_, py + 15], fill=C("P02"))
    if broken:
        k = rnd.randint(0, 1)
        x0, y0 = 16 * k + 3, 16 * (1 - k) + 3
        d.line([x0, y0, x0 + 4, y0 + 5, x0 + 3, y0 + 9, x0 + 8, y0 + 11], fill=C("P02"))
        d.point((x0 + 5, y0 + 5), fill=C("P07"))
    grime(img, seed, 0.86)
    return img


def P_up(tok):
    n = int(tok[1:])
    return f"P{min(n + 1, 9 if n <= 9 else n + 1):02d}"


def stairs():
    img = new()
    d = ImageDraw.Draw(img)
    for k in range(4):                                                # 디딤판 5px(밝음) + 챌판 3px(어두움)
        y = k * 8
        mottle(img, ["P06", "P07", "P08"], 40 + k, box=(0, y, 32, y + 5), lo=0.3, hi=0.8)
        d.line([0, y, 31, y], fill=C("P09"))
        d.rectangle([0, y + 5, 31, y + 7], fill=C("P04"))
        d.line([0, y + 5, 31, y + 5], fill=C("P03"))
        d.line([0, y + 7, 31, y + 7], fill=C("P01"))
    grime(img, 5, 0.82)
    specks(img, 41, 5, "P05")
    return img


def stairs_rail():
    img = stairs()
    d = ImageDraw.Draw(img)
    for y in (2, 18):                                                 # 녹슨 난간 기둥 + 손잡이
        d.rectangle([3, y, 4, y + 12], fill=C("P25"))
        d.line([3, y, 3, y + 12], fill=C("P26"))
    d.rectangle([2, 0, 5, 31], outline=None)
    d.line([4, 0, 4, 31], fill=C("P24"))
    d.line([3, 0, 3, 31], fill=C("P26"))
    d.line([5, 0, 5, 31], fill=C("P01"))
    d.line([2, 0, 2, 31], fill=C("P01"))
    return img


def wall_face(seed=5, top=True):
    img = new()
    mottle(img, ["P04", "P05", "P06"], seed, lo=0.24, hi=0.8, fine=0.4)
    d = ImageDraw.Draw(img)
    for x in (0, 16):                                                 # 거푸집 이음매
        d.line([x, 0, x, 31], fill=C("P03"))
        d.line([x + 1, 0, x + 1, 31], fill=C("P06"))
    for y in (11, 22):
        for x in (5, 21):
            d.point((x, y), fill=C("P02"))                           # 폼타이 구멍
    rnd = random.Random(seed)
    for _ in range(3):                                                # 녹물 줄
        x = rnd.randint(3, 28)
        d.line([x, rnd.randint(4, 10), x, rnd.randint(16, 30)], fill=C("P18"))
    grime(img, seed, 0.76)
    if top:
        mottle(img, ["P07", "P08", "P09"], seed + 9, box=(0, 0, 32, 5), lo=0.35, hi=0.8)
        d.line([0, 5, 31, 5], fill=C("P01"))
        d.line([0, 6, 31, 6], fill=C("P03"))
    d.line([0, 31, 31, 31], fill=C("P02"))
    return img


def brick_wall(window=False):
    img = new()
    d = ImageDraw.Draw(img)
    br = [["P24", "P25", "P25"], ["P24", "P25", "P26"], ["P23", "P24", "P25"]]
    for row in range(5):
        y = row * 7 - 1
        off = 6 if row % 2 else 0
        for col in range(-1, 3):
            x = col * 12 + off
            tone = br[(row + col) % 3]
            box = (max(0, x + 1), max(0, y + 1), min(32, x + 12), min(32, y + 7))
            if box[2] <= box[0] or box[3] <= box[1]:
                continue
            mottle(img, tone, row * 5 + col + 20, box=box, lo=0.3, hi=0.78)
            d.line([box[0], box[1], box[2] - 1, box[1]], fill=C(tone[2]))
    for row in range(5):                                              # 줄눈(어두운 모르타르)
        y = row * 7 - 1
        if 0 <= y < 32:
            d.line([0, y, 31, y], fill=C("P02"))
        off = 6 if row % 2 else 0
        for col in range(-1, 3):
            x = col * 12 + off
            if 0 <= x < 32:
                d.line([x, max(0, y), x, min(31, y + 6)], fill=C("P02"))
    grime(img, 21, 0.8)
    if window:
        d.rectangle([7, 6, 24, 25], fill=C("P01"))
        d.rectangle([8, 7, 23, 24], fill=C("P10"))
        mottle(img, ["P10", "P10", "P11"], 30, box=(9, 8, 23, 24), lo=0.5, hi=0.85)
        for x in (11, 15, 19):                                        # 방범창 살
            d.line([x, 7, x, 24], fill=C("P05"))
            d.line([x + 1, 7, x + 1, 24], fill=C("P02"))
        d.rectangle([6, 25, 25, 26], fill=C("P07"))
        d.line([6, 27, 25, 27], fill=C("P01"))
    return img


def granite_rock(seed=7):
    img = new()
    rnd = random.Random(seed)
    lump(img, 16, 19, 12.5, 10, ["P04", "P05", "P06", "P07"])
    for _ in range(2):
        lump(img, rnd.uniform(10, 22), rnd.uniform(13, 18), rnd.uniform(5, 7), rnd.uniform(4, 6), ["P04", "P05", "P06", "P07"])
    d = ImageDraw.Draw(img)
    cx = rnd.randint(13, 18)
    d.line([cx, 12, cx + 2, 17, cx + 1, 22], fill=C("P03"))
    d.point((cx - 4, 14), fill=C("P08"))
    return outline(img)


def scrap_barrier(seed=9):
    img = new()
    d = ImageDraw.Draw(img)
    sheets = [(1, 12, ["P24", "P25", "P26"]), (11, 21, ["P04", "P05", "P06"]), (20, 31, ["P25", "P26", "P27"])]
    for x0, x1, tone in sheets:
        top = 4 + (x0 % 3)
        for x in range(x0, x1):
            col = C(tone[2]) if (x - x0) % 3 == 0 else C(tone[1]) if (x - x0) % 3 == 1 else C(tone[0])
            d.line([x, top, x, 27], fill=col)                         # 골판(세로 골)
        grime(img, seed + x0, 0.72, box=(x0, top, x1, 28))
        d.line([x0, top, x1 - 1, top], fill=C(tone[2]))
    for x in (4, 15, 26):
        d.point((x, 9), fill=C("P02")); d.point((x, 22), fill=C("P02"))  # 못
    for x in (0, 30):                                                 # 말뚝
        d.rectangle([x, 2, x + 1, 30], fill=C("P17"))
    return outline(img)


def drum():
    img = new()
    d = ImageDraw.Draw(img)
    rust = [C("P24"), C("P25"), C("P26"), C("P27")]
    for x in range(8, 25):
        nx = (x + 0.5 - 16.5) / 8.5
        d.line([x, 11, x, 28], fill=rust[0] if nx > 0.55 else rust[1] if nx > 0.0 else rust[2] if nx > -0.6 else rust[3])
    for y in (16, 23):
        d.line([8, y, 24, y], fill=rust[0])
    d.ellipse([8, 6, 24, 15], fill=rust[2])
    d.ellipse([10, 8, 22, 13], fill=rust[1])
    d.ellipse([12, 9, 15, 11], fill=C("P02"))
    d.point((19, 18), fill=C("P49")); d.point((20, 18), fill=C("P49")); d.point((19, 19), fill=C("P48"))
    return outline(img)


def r01_tiles():
    return {
        "dirt_a": dirt(1), "dirt_b": dirt(4), "dirt_grass_a": dirt(2, grass=1), "dirt_grass_b": dirt(6, grass=2),
        "asphalt": asphalt(2), "asphalt_lane": asphalt(5, lane=True), "pavers": pavers(3, broken=0), "pavers_b": pavers(8, broken=2),
        "stairs": stairs(), "stairs_rail": stairs_rail(), "wall_face_cap": wall_face(5, True), "wall_face": wall_face(6, False),
        "brick": brick_wall(), "brick_window": brick_wall(True), "granite_rock": granite_rock(), "scrap_barrier": scrap_barrier(),
        "drum": drum(),
    }


# ================================================================ S-07 실내
def grate(seed=0):
    img = new("P02")
    d = ImageDraw.Draw(img)
    for py in (0, 16):
        for px_ in (0, 16):
            mottle(img, ["P04", "P05", "P06"], seed * 4 + px_ + py, box=(px_ + 1, py + 1, px_ + 15, py + 15), lo=0.3, hi=0.8)
            d.line([px_ + 1, py + 1, px_ + 14, py + 1], fill=C("P07"))
            horiz = ((px_ + py) // 16 + seed) % 2 == 0
            for k in range(4, 13, 4):
                if horiz:
                    d.line([px_ + 3, py + k, px_ + 12, py + k], fill=C("P01"))
                    d.line([px_ + 3, py + k + 1, px_ + 12, py + k + 1], fill=C("P06"))
                else:
                    d.line([px_ + k, py + 3, px_ + k, py + 12], fill=C("P01"))
                    d.line([px_ + k + 1, py + 3, px_ + k + 1, py + 12], fill=C("P06"))
            for x, y in ((px_ + 2, py + 2), (px_ + 13, py + 13)):
                d.point((x, y), fill=C("P08"))
    if seed % 3 == 2:
        for k in range(4, 12):
            img.putpixel((16 + k, 22), C("P24"))
        grime(img, seed, 0.7)
    return img


def panel_floor(seed=0, sheen=False):
    img = new()
    mottle(img, ["P12", "P13", "P14"], 70 + seed, lo=0.16, hi=0.9, fine=0.3)
    d = ImageDraw.Draw(img)
    for x in (0, 16):
        d.line([x, 0, x, 31], fill=C("P11"))
        d.line([x + 1, 0, x + 1, 31], fill=C("P14"))
    d.line([0, 0, 31, 0], fill=C("P11"))
    d.line([0, 1, 31, 1], fill=C("P14"))
    if sheen:
        for k in range(6):                                            # 천장 조명 반사
            d.point((8 + k, 22 - k), fill=C("P15"))
            d.point((9 + k, 22 - k), fill=C("P15"))
    if seed == 3:
        for k in range(5):
            d.point((20 + k, 9 + (k % 2)), fill=C("P11"))
        grime(img, seed, 0.74)
    return img


def guide_line(axis="h"):
    img = panel_floor(0)
    d = ImageDraw.Draw(img)
    if axis == "h":
        d.rectangle([0, 13, 31, 18], fill=C("P48"))
        d.line([0, 13, 31, 13], fill=C("P49"))
        d.line([0, 12, 31, 12], fill=C("P01")); d.line([0, 19, 31, 19], fill=C("P01"))
    else:
        d.rectangle([13, 0, 18, 31], fill=C("P48"))
        d.line([13, 0, 13, 31], fill=C("P49"))
        d.line([12, 0, 12, 31], fill=C("P01")); d.line([19, 0, 19, 31], fill=C("P01"))
    return img


def lino(seed=0):
    img = new()
    mottle(img, ["P19", "P20", "P21"], 80 + seed, lo=0.24, hi=0.84, fine=0.4)
    d = ImageDraw.Draw(img)
    for x in (0, 16):
        d.line([x, 0, x, 31], fill=C("P18"))
    for y in (0, 16):
        d.line([0, y, 31, y], fill=C("P18"))
    grime(img, 80 + seed, 0.8)
    return img


def clinic_tile(seed=0):
    img = new()
    mottle(img, ["P07", "P08", "P09"], 90 + seed, lo=0.25, hi=0.7, fine=0.2)
    d = ImageDraw.Draw(img)
    for k in range(0, 32, 8):
        d.line([k, 0, k, 31], fill=C("P06"))
        d.line([0, k, 31, k], fill=C("P06"))
    if seed == 2:
        d.rectangle([17, 9, 23, 15], fill=C("P14"))                  # 갈아 끼운 타일
        d.line([18, 10, 22, 14], fill=C("P06"))
    return img


def wall_top(edges):
    img = new()
    mottle(img, ["P10", "P10", "P11"], 99, lo=0.3, hi=0.82)
    d = ImageDraw.Draw(img)
    for e, line_ in (("s", [0, 31, 31, 31]), ("n", [0, 0, 31, 0]), ("w", [0, 0, 0, 31]), ("e", [31, 0, 31, 31])):
        if e in edges:
            d.line(line_, fill=C("P13"))
    if "s" in edges:
        d.line([0, 30, 31, 30], fill=C("P01"))
    if "w" in edges:
        d.line([1, 0, 1, 31], fill=C("P01"))
    return img


def wall_face_in(part, variant="plain", seed=0):
    img = new()
    mottle(img, ["P12", "P13", "P14"], 110 + seed + (0 if part == "top" else 5), lo=0.2, hi=0.88, fine=0.3)
    d = ImageDraw.Draw(img)
    for x in (0, 16):
        d.line([x, 0, x, 31], fill=C("P11"))
        d.line([x + 1, 0, x + 1, 31], fill=C("P14"))
    if part == "top":
        d.line([0, 0, 31, 0], fill=C("P01"))
        d.line([0, 1, 31, 1], fill=C("P11"))
        for x in (3, 13, 19, 29):
            d.point((x, 4), fill=C("P15"))
        if variant == "pipe":
            d.rectangle([0, 6, 31, 9], fill=C("P05")); d.line([0, 6, 31, 6], fill=C("P07"))
            d.line([0, 10, 31, 10], fill=C("P01"))
            for x in (8, 24):
                d.rectangle([x, 5, x + 1, 10], fill=C("P04"))
        if variant == "vent":
            d.rectangle([7, 9, 24, 22], fill=C("P01"))
            d.rectangle([8, 10, 23, 21], fill=C("P11"))
            for y in range(12, 21, 2):
                d.line([9, y, 22, y], fill=C("P02"))
    else:
        d.rectangle([0, 4, 31, 9], fill=C("P48"))
        d.line([0, 4, 31, 4], fill=C("P49")); d.line([0, 3, 31, 3], fill=C("P01")); d.line([0, 10, 31, 10], fill=C("P01"))
        mottle(img, ["P11", "P12", "P12"], 120 + seed, box=(0, 11, 32, 29), lo=0.35, hi=0.85)
        for x in (0, 16):
            d.line([x, 11, x, 29], fill=C("P10"))
        for x in (5, 21):
            d.point((x, 14), fill=C("P14"))
        d.rectangle([0, 29, 31, 31], fill=C("P10"))
        d.line([0, 29, 31, 29], fill=C("P01"))
        if variant == "outlet":
            d.rectangle([19, 17, 26, 24], fill=C("P01"))
            d.rectangle([20, 18, 25, 23], fill=C("P08")); d.point([(22, 20), (23, 20)], fill=C("P03"))
    grime(img, 130 + seed, 0.84)
    return img


def balcony_band(seed=0, door=False, num=None):
    img = new()
    mottle(img, ["P11", "P12", "P12"], 140 + seed, box=(0, 0, 32, 16), lo=0.35, hi=0.85)
    d = ImageDraw.Draw(img)
    d.line([0, 0, 31, 0], fill=C("P01"))
    d.line([0, 9, 31, 9], fill=C("P47"))
    if door:
        d.rectangle([8, 2, 23, 15], fill=C("P10"))
        d.rectangle([8, 2, 23, 15], outline=C("P01"))
    d.rectangle([0, 16, 31, 17], fill=C("P06")); d.line([0, 16, 31, 16], fill=C("P08"))
    mottle(img, ["P12", "P13", "P14"], 150 + seed, box=(0, 18, 32, 32), lo=0.3, hi=0.8)
    d.line([0, 18, 31, 18], fill=C("P01"))
    d.line([0, 28, 31, 28], fill=C("P12"))
    for x in (2, 18):
        d.rectangle([x, 4, x + 1, 15], fill=C("P15")); d.point((x + 1, 15), fill=C("P07"))
        d.line([x + 2, 4, x + 2, 15], fill=C("P01"))
    d.line([0, 5, 31, 5], fill=C("P15")); d.line([0, 6, 31, 6], fill=C("P01"))
    d.line([0, 11, 31, 11], fill=C("P14")); d.line([0, 12, 31, 12], fill=C("P01"))
    return img


def s07_tiles():
    return {
        "grate_a": grate(0), "grate_b": grate(1), "grate_c": grate(2),
        "panel": panel_floor(0), "panel_sheen": panel_floor(1, sheen=True), "panel_scuff": panel_floor(3),
        "guide_h": guide_line("h"), "guide_v": guide_line("v"), "lino_a": lino(0), "lino_b": lino(1),
        "clinic_a": clinic_tile(0), "clinic_b": clinic_tile(2),
        "wall_top_s": wall_top({"s"}), "wall_top_w": wall_top({"w"}), "wall_top_ws": wall_top({"w", "s"}), "wall_top": wall_top(set()),
        "face_top": wall_face_in("top"), "face_top_pipe": wall_face_in("top", "pipe"), "face_top_vent": wall_face_in("top", "vent"),
        "face_bot": wall_face_in("bot"), "face_bot_outlet": wall_face_in("bot", "outlet"),
        "balcony": balcony_band(0), "balcony_door": balcony_band(1, door=True, num="B-12"),
    }


def sheet(tiles, cols=9, bg="P19"):
    names = list(tiles)
    rows = (len(names) + cols - 1) // cols
    out = Image.new("RGBA", (cols * 34 + 2, rows * 34 + 2), C(bg))
    for i, n in enumerate(names):
        out.alpha_composite(tiles[n], (2 + (i % cols) * 34, 2 + (i // cols) * 34))
    return out


if __name__ == "__main__":
    o = sys.argv[1] if len(sys.argv) > 1 else "/tmp"
    a = sheet(r01_tiles())
    b = sheet(s07_tiles(), 12)
    a.resize((a.width * 4, a.height * 4), Image.NEAREST).save(o + "_r01.png")
    b.resize((b.width * 3, b.height * 3), Image.NEAREST).save(o + "_s07.png")
