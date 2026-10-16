"""아이작풍 타일(SD-16 §6 v2.0): R01 바깥(관악산 비탈)·S-07 실내. 이름·순서는 이전 판과 같다(지도 데이터 그대로).
면은 '이어지는 부드러운 얼룩'(타일 경계에서 맞물리는 값 잡음) + 굵은 먹선 이음매 + 때. 소품은 굵은 외곽선과 둥근 덩어리.
"""
import os, sys, math, random
from PIL import Image, ImageDraw
import numpy as np

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


# ================================================================ 바닥 타일 = 바닥 합성 텍스처에서 잘라 낸 한 칸(SD-16 §6.10)
# 게임 바닥은 합성 층(ground.py)이 그린다. 이 함수들은 같은 텍스처에서 32px 한 칸을 잘라, 타일 시트·장면 견본·컷신이
# 게임과 같은 바닥 그림을 쓰게 한다(쯔꾸르식 평평한 바탕 + 또렷한 무늬).
def _gcrop(set_name, mat, seed, decal=None):
    import ground as G
    gs = G.load(set_name)
    m = gs.names.index(mat)
    tx, ty = (seed * 3) % (G.CELL // 32), (seed * 5 + 1) % (G.CELL // 32)
    a = gs.atlas[m * G.CELL + ty * 32:m * G.CELL + ty * 32 + 32, tx * 32:tx * 32 + 32].copy()
    if decal is not None:
        _, did = G.decals()
        dv = gs.decal[0:32, did[decal] * 32:did[decal] * 32 + 32]
        a = np.where(dv != 255, dv, a)
    rgba = np.zeros((32, 32, 4), np.uint8)
    rgba[..., :3] = G.PAL[a]
    rgba[..., 3] = 255
    return Image.fromarray(rgba, "RGBA")


def dirt(seed=1, grass=0):
    return _gcrop("r01", "dirt" if grass == 0 else "grass_sparse" if grass < 4 else "grass_dense", seed)


def asphalt(seed=2, lane=False):
    return _gcrop("r01", "asphalt", seed, "lane" if lane else None)


def pavers(seed=3, broken=2):
    return _gcrop("r01", "pavers", seed)


def grate(seed=0):
    return _gcrop("s07", "grate", seed)


def panel_floor(seed=0, sheen=False):
    return _gcrop("s07", "panel", seed)


def lino(seed=0):
    return _gcrop("s07", "lino", seed)


def clinic_tile(seed=0):
    return _gcrop("s07", "clinic", seed)


# ================================================================ R01 바깥
def P_up(tok):
    n = int(tok[1:])
    return f"P{min(n + 1, 9 if n <= 9 else n + 1):02d}"


def stairs():
    img = new()
    d = ImageDraw.Draw(img)
    for k in range(4):                                                # 디딤판 5px(밝음) + 챌판 3px(어두움)
        y = k * 8
        d.rectangle([0, y, 31, y + 4], fill=C("P07"))                  # 쯔꾸르식: 평평한 디딤판 + 밝은 모서리 + 어두운 챌판
        d.line([0, y, 31, y], fill=C("P09"))
        d.line([0, y + 1, 31, y + 1], fill=C("P08"))
        d.rectangle([0, y + 5, 31, y + 7], fill=C("P04"))
        d.line([0, y + 5, 31, y + 5], fill=C("P03"))
        d.line([0, y + 7, 31, y + 7], fill=C("P02"))
    for x, y in ((6, 3), (21, 11), (13, 27)):                          # 닳은 자리 몇 점
        d.line([x, y, x + 3, y], fill=C("P06"))
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
    """콘크리트 옹벽(쯔꾸르식): 평평한 바탕 + 거푸집 이음매(어두운 선 + 밝은 선) + 폼타이 구멍 + 위 갓돌 + 아래 때 띠."""
    img = new("P06")
    d = ImageDraw.Draw(img)
    for x in (0, 16):
        d.line([x, 0, x, 31], fill=C("P04"))
        d.line([x + 1, 0, x + 1, 31], fill=C("P07"))
    for y in (13, 23):
        for x in (6, 22):
            d.point((x, y), fill=C("P03")); d.point((x, y + 1), fill=C("P07"))
    rnd = random.Random(seed)
    if rnd.random() < 0.5:                                            # 가끔 녹물 한 줄(폼타이 구멍에서)
        x = rnd.choice((6, 22))
        d.line([x, 15, x, 15 + rnd.randint(4, 8)], fill=C("P19"))
    d.rectangle([0, 28, 31, 30], fill=C("P05"))                       # 아래 때 띠
    d.line([0, 31, 31, 31], fill=C("P03"))
    if top:
        d.rectangle([0, 0, 31, 4], fill=C("P08"))
        d.line([0, 0, 31, 0], fill=C("P09"))
        d.line([0, 4, 31, 4], fill=C("P07"))
        d.line([0, 5, 31, 5], fill=C("P02"))
        d.line([0, 6, 31, 6], fill=C("P05"))
        for x in (0, 16):
            d.line([x, 0, x, 4], fill=C("P06"))
    return img


def brick_wall(window=False):
    """벽돌 벽(쯔꾸르식): 8×4 벽돌을 엇갈려, 벽돌마다 윗줄 밝게·아랫줄 어둡게, 밝은 줄눈."""
    img = new("P05")
    d = ImageDraw.Draw(img)
    rnd = random.Random(21)
    for row in range(8):
        y = row * 4
        off = 4 if row % 2 else 0
        for col in range(-1, 4):
            x = col * 8 + off
            r = rnd.random()
            base, hi, lo = ("P25", "P26", "P24") if r < 0.8 else (("P24", "P25", "P23") if r < 0.9 else ("P26", "P27", "P25"))
            x0, x1 = max(0, x), min(31, x + 6)
            if x1 < x0:
                continue
            d.rectangle([x0, y, x1, y + 2], fill=C(base))
            d.line([x0, y, x1, y], fill=C(hi))
            d.line([x0, y + 2, x1, y + 2], fill=C(lo))
    if window:
        d.rectangle([7, 6, 24, 25], fill=C("P01"))
        d.rectangle([8, 7, 23, 24], fill=C("P10"))
        d.rectangle([9, 8, 22, 12], fill=C("P11"))                    # 유리에 비친 하늘(위쪽 한 띠)
        for x in (11, 15, 19):                                        # 방범창 살
            d.line([x, 7, x, 24], fill=C("P06"))
            d.line([x + 1, 7, x + 1, 24], fill=C("P03"))
        d.rectangle([6, 25, 25, 26], fill=C("P08"))
        d.line([6, 27, 25, 27], fill=C("P03"))
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
        "concrete_o": _gcrop("r01", "concrete", 0),                  # 0-10 덧붙임(앞 번호는 그대로)
        # 1-1 월드 바닥(앞 번호는 그대로): 바닥 합성 재질에서 32px 한 칸을 잘라 쓴다
        "water_deep": _gcrop("r01", "water_deep", 0), "water_mid": _gcrop("r01", "water_mid", 0),
        "water_shallow": _gcrop("r01", "water_shallow", 0), "mud": _gcrop("r01", "mud", 0),
        "rock_floor": _gcrop("r01", "rock", 0), "rubble": _gcrop("r01", "rubble", 0), "ballast": _gcrop("r01", "ballast", 0),
    }


# ================================================================ S-07 실내
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


def guide_cross(down=True):
    img = guide_line("h")
    v = guide_line("v")
    for y in list(range(0, 12)) + (list(range(20, 32)) if down else []):
        for x in range(12, 20):
            img.putpixel((x, y), v.getpixel((x, y)))
    for x in range(13, 19):                                           # 가운데는 노란 칠이 이어진다
        img.putpixel((x, 12), C("P49") if x == 13 else C("P48"))
        if down:
            img.putpixel((x, 19), C("P48"))
    return img


def wall_top(edges):
    """벽 윗면(방 바깥): 포켓몬 골드식 — 방 밖은 아무것도 보이지 않는 검정(P01). 방과 맞닿은 쪽에만 벽 두께 띠(어두운 청회 4px)와
    밝은 모서리 1px을 그어 방의 윤곽만 읽히게 한다(1-T3, 리드 지시: 실내에 들어가면 바깥이 보이지 않는다)."""
    img = new("P01")
    d = ImageDraw.Draw(img)
    band = {"s": [0, 27, 31, 31], "n": [0, 0, 31, 4], "w": [0, 0, 4, 31], "e": [27, 0, 31, 31]}
    for e in ("n", "e", "s", "w"):
        if e in edges:
            d.rectangle(band[e], fill=C("P10"))
    for e, line_ in (("s", [0, 31, 31, 31]), ("n", [0, 0, 31, 0]), ("w", [0, 0, 0, 31]), ("e", [31, 0, 31, 31])):
        if e in edges:
            d.line(line_, fill=C("P13"))
    if "s" in edges:
        d.line([0, 30, 31, 30], fill=C("P01"))
    if "w" in edges:
        d.line([1, 0, 1, 31], fill=C("P01"))
    return img


def wall_face_in(part, variant="plain", seed=0):
    img = new("P13")                                                   # 쯔꾸르식: 평평한 판 + 경사 테
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
        d.rectangle([0, 11, 31, 28], fill=C("P12"))
        d.line([0, 11, 31, 11], fill=C("P13"))
        for x in (0, 16):
            d.line([x, 11, x, 29], fill=C("P10"))
        for x in (5, 21):
            d.point((x, 14), fill=C("P14"))
        d.rectangle([0, 29, 31, 31], fill=C("P10"))
        d.line([0, 29, 31, 29], fill=C("P01"))
        if variant == "outlet":
            d.rectangle([19, 17, 26, 24], fill=C("P01"))
            d.rectangle([20, 18, 25, 23], fill=C("P08")); d.point([(22, 20), (23, 20)], fill=C("P03"))
    return img


def balcony_band(seed=0, door=False, num=None):
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 31, 15], fill=C("P12"))
    d.line([0, 0, 31, 0], fill=C("P01"))
    d.line([0, 9, 31, 9], fill=C("P47"))
    if door:
        d.rectangle([8, 2, 23, 15], fill=C("P10"))
        d.rectangle([8, 2, 23, 15], outline=C("P01"))
    d.rectangle([0, 16, 31, 17], fill=C("P06")); d.line([0, 16, 31, 16], fill=C("P08"))
    d.rectangle([0, 18, 31, 31], fill=C("P13"))
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
        "guide_x": guide_cross(), "guide_t": guide_cross(down=False),  # 뒤에 덧붙임(앞 번호는 그대로)
        "concrete_a": _gcrop("s07", "concrete", 0), "carpet_a": _gcrop("s07", "carpet", 0), "wood_a": _gcrop("s07", "wood", 0), "jangpan_a": _gcrop("s07", "jangpan", 0),
        "panel_mold": _gcrop("s07", "panel_mold", 0),             # 단계 0-5 덧붙임(바닥 합성 번호는 32칸 안)
        "grate_mold": _gcrop("s07", "grate_mold", 0),
        "terrazzo_a": _gcrop("s07", "terrazzo", 0),               # 1-4 지하시장 덧붙임
        "tunnel_a": _gcrop("s07", "tunnel", 0),
        "steps_a": _gcrop("s07", "steps", 0),                     # 1-5 벙커 덧붙임
        "epoxy_a": _gcrop("s07", "epoxy", 0),
        "turf_a": _gcrop("s07", "turf", 0),                       # 1-11i 고척 돔 그라운드
    }


# 실내 벽 자동 타일(단계 0-5): 바닥 합성과 따로 둔 타일셋 ts_s07_wall. wt_<m> m = 테를 그을 방향 비트(n 1 · e 2 · s 4 · w 8)
WALL_BITS = (("n", 1), ("e", 2), ("s", 4), ("w", 8))


def s07_wall_tiles():
    out = {f"wt_{m}": wall_top({e for e, b in WALL_BITS if m & b}) for m in range(16)}
    out.update({"face_top": wall_face_in("top"), "face_top_pipe": wall_face_in("top", "pipe"),
                "face_top_vent": wall_face_in("top", "vent"), "face_bot": wall_face_in("bot"),
                "face_bot_outlet": wall_face_in("bot", "outlet")})
    return out


def wall_face_bc(part, variant="plain", seed=0):
    """빌라 방 벽(봉천 실내, 0-10): 바랜 꽃무늬 벽지(위) + 나무 걸레받이(아래). 쯔꾸르식 평평한 면 + 테."""
    img = new("P21")
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed * 7 + (1 if part == "top" else 2))
    if part == "top":
        d.line([0, 0, 31, 0], fill=C("P01"))
        d.line([0, 1, 31, 1], fill=C("P19"))
        d.rectangle([0, 2, 31, 4], fill=C("P20"))                    # 몰딩
        d.line([0, 5, 31, 5], fill=C("P19"))
        for y in range(10, 32, 8):                                     # 벽지 무늬(작은 꽃 점, 엇갈림)
            for x in range(4 if (y // 8) % 2 else 0, 32, 8):
                d.point((x + 2, y), fill=C("P22")); d.point((x + 1, y + 1), fill=C("P20")); d.point((x + 3, y + 1), fill=C("P20"))
        if variant == "stain":
            for k in range(3):
                d.line([6 + k * 9, 6, 6 + k * 9, 6 + rnd.randint(8, 20)], fill=C("P20"))
        if variant == "calendar":
            d.rectangle([10, 9, 21, 24], fill=C("P09")); d.rectangle([10, 9, 21, 12], fill=C("P53"))
            for yy in (15, 18, 21):
                d.line([12, yy, 19, yy], fill=C("P06"))
            d.rectangle([10, 9, 21, 24], outline=C("P05"))
    else:
        for y in range(0, 20, 8):
            for x in range(0 if (y // 8) % 2 else 4, 32, 8):
                d.point((x + 2, y + 2), fill=C("P22")); d.point((x + 1, y + 3), fill=C("P20")); d.point((x + 3, y + 3), fill=C("P20"))
        d.rectangle([0, 20, 31, 28], fill=C("P18"))                   # 걸레받이(나무)
        d.line([0, 20, 31, 20], fill=C("P01")); d.line([0, 21, 31, 21], fill=C("P20"))
        d.rectangle([0, 29, 31, 31], fill=C("P17")); d.line([0, 29, 31, 29], fill=C("P01"))
        if variant == "outlet":
            d.rectangle([20, 12, 26, 18], fill=C("P01")); d.rectangle([21, 13, 25, 17], fill=C("P09"))
            d.point((22, 15), fill=C("P04")); d.point((24, 15), fill=C("P04"))
    return img


def bc_wall_tiles():
    """봉천 빌라 실내 벽(ts_bc_wall): s07 벽과 같은 이름(윗면 wt_m은 같고 벽면만 벽지)."""
    out = {f"wt_{m}": wall_top({e for e, b in WALL_BITS if m & b}) for m in range(16)}
    out.update({"face_top": wall_face_bc("top"), "face_top_pipe": wall_face_bc("top", "calendar", 1),
                "face_top_vent": wall_face_bc("top", "stain", 2), "face_bot": wall_face_bc("bot"),
                "face_bot_outlet": wall_face_bc("bot", "outlet")})
    return out


def wall_face_sb(part, variant="plain", seed=0):
    """새벽인력 창고동 벽(1-3 H-03): 옛 공구상가 철골동 — 녹슨 골함석(세로 골 4px) + 위 H빔·리벳 + 아래 콘크리트 턱. 쯔꾸르식 평평한 면."""
    img = new("P12")
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed * 13 + (1 if part == "top" else 2))
    for x in range(0, 32, 4):                                          # 골: 그늘 · 면 · 빛 · 면
        d.line([x, 0, x, 31], fill=C("P11"))
        d.line([x + 2, 0, x + 2, 31], fill=C("P13"))
    if part == "top":
        d.rectangle([0, 0, 31, 6], fill=C("P10"))                     # H빔
        d.line([0, 0, 31, 0], fill=C("P01")); d.line([0, 1, 31, 1], fill=C("P13")); d.line([0, 6, 31, 6], fill=C("P01"))
        d.line([0, 4, 31, 4], fill=C("P11"))
        for x in (4, 12, 20, 28):
            d.point((x, 3), fill=C("P14"))
        for k in range(2 if variant != "rust" else 5):                  # 리벳 아래로 흘러내린 녹
            x = rnd.randrange(1, 31, 4) + 1
            d.line([x, 7, x, 7 + rnd.randint(4, 16)], fill=C("P25"))
            d.point((x, 7), fill=C("P24"))
        if variant == "num":                                          # 칸 번호 스텐실
            d.rectangle([11, 12, 21, 24], fill=C("P11"))
            for yy in (14, 18, 22):
                d.line([13, yy, 19, yy], fill=C("P08"))
            d.line([19, 14, 19, 18], fill=C("P08")); d.line([13, 18, 13, 22], fill=C("P08"))
    else:
        for k in range(2):
            x = rnd.randrange(1, 31, 4) + 1
            d.line([x, 0, x, rnd.randint(6, 14)], fill=C("P25"))
        d.rectangle([0, 20, 31, 31], fill=C("P05"))                   # 콘크리트 턱
        d.line([0, 20, 31, 20], fill=C("P01")); d.line([0, 21, 31, 21], fill=C("P07"))
        for x in (6, 19, 27):
            d.point((x, 25), fill=C("P04")); d.point((x + 1, 26), fill=C("P06"))
        d.line([0, 29, 31, 29], fill=C("P04")); d.line([0, 31, 31, 31], fill=C("P01"))
        if variant == "outlet":                                       # 굵은 전선관과 배전함
            d.rectangle([18, 6, 27, 16], fill=C("P11")); d.rectangle([19, 7, 26, 15], fill=C("P13"))
            d.point((24, 9), fill=C("P54"))
    return img


def sb_wall_tiles():
    """새벽인력 창고동 실내 벽(ts_sb_wall, 1-3): s07 벽과 같은 이름(윗면 wt_m은 같고 벽면만 골함석)."""
    out = {f"wt_{m}": wall_top({e for e, b in WALL_BITS if m & b}) for m in range(16)}
    out.update({"face_top": wall_face_sb("top"), "face_top_pipe": wall_face_sb("top", "num", 1),
                "face_top_vent": wall_face_sb("top", "rust", 2), "face_bot": wall_face_sb("bot"),
                "face_bot_outlet": wall_face_sb("bot", "outlet")})
    return out


def wall_face_jm(part, variant="plain", seed=0):
    """영등포 지하상가 벽(1-4 지하시장 J-01~J-11): 2077년 상가의 크림색 8px 벽 타일(줄눈 · 왼쪽 위 빛) + 위 천장 반자 띠 +
    아래 짙은 인조석 걸레받이. 200년 물때가 줄눈을 타고 흐른다. 쯔꾸르식 평평한 면."""
    img = new("P08")
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed * 17 + (1 if part == "top" else 2))
    y0 = 7 if part == "top" else 0
    y1 = 31 if part == "top" else 18
    for y in range(y0, y1 + 1, 8):                                     # 타일 줄눈 + 빛
        d.line([0, y, 31, y], fill=C("P07"))
        if y + 1 <= y1:
            d.line([0, y + 1, 31, y + 1], fill=C("P09"))
    for x in range(0, 32, 8):
        d.line([x, y0, x, y1], fill=C("P07"))
        d.line([x + 1, y0 + 1, x + 1, y1], fill=C("P09"))
    for _ in range(3):                                                 # 빛바랜 타일 몇 장
        tx, ty = rnd.randrange(0, 32, 8), rnd.randrange(y0, max(y0 + 1, y1 - 6), 8)
        d.rectangle([tx + 2, ty + 2, tx + 7, ty + 7], fill=C("P07"))
    if part == "top":
        d.rectangle([0, 0, 31, 5], fill=C("P04"))                     # 천장 반자 띠
        d.line([0, 0, 31, 0], fill=C("P01")); d.line([0, 1, 31, 1], fill=C("P06")); d.line([0, 5, 31, 5], fill=C("P02"))
        d.line([0, 6, 31, 6], fill=C("P05"))
        for x in (5, 21):
            d.point((x, 3), fill=C("P03"))
        if variant == "sign":                                          # 2077 상가 안내 띠(청록 바탕 흰 화살표)
            d.rectangle([0, 10, 31, 21], fill=C("P61"))
            d.line([0, 10, 31, 10], fill=C("P62")); d.line([0, 21, 31, 21], fill=C("P01"))
            d.line([5, 15, 15, 15], fill=C("P09")); d.line([12, 12, 15, 15], fill=C("P09")); d.line([12, 18, 15, 15], fill=C("P09"))
            for x in (20, 23, 26):
                d.line([x, 13, x, 17], fill=C("P09"))
        if variant == "stain":                                         # 물때가 줄눈을 타고 흐른다
            for k in range(4):
                x = rnd.randrange(2, 30)
                d.line([x, 7, x, 7 + rnd.randint(8, 22)], fill=C("P06"))
                d.point((x, 7), fill=C("P25"))
    else:
        for k in range(2):
            x = rnd.randrange(2, 30)
            d.line([x, 0, x, rnd.randint(4, 14)], fill=C("P06"))
        d.rectangle([0, 19, 31, 28], fill=C("P04"))                   # 인조석 걸레받이
        d.line([0, 19, 31, 19], fill=C("P01")); d.line([0, 20, 31, 20], fill=C("P06"))
        for x in (4, 13, 22, 27):
            d.point((x, 23 + (x % 3)), fill=C("P05"))
        d.rectangle([0, 29, 31, 31], fill=C("P03")); d.line([0, 29, 31, 29], fill=C("P01"))
        if variant == "outlet":                                       # 옥내 소화전함(붉은 철함 + 유리창)
            d.rectangle([17, 2, 29, 18], fill=C("P52")); d.rectangle([18, 3, 28, 17], fill=C("P53"))
            d.rectangle([20, 5, 26, 11], fill=C("P02")); d.line([20, 5, 26, 5], fill=C("P06"))
            d.line([18, 3, 28, 3], fill=C("P54")); d.point((27, 14), fill=C("P09"))
            d.line([17, 18, 29, 18], fill=C("P01"))
    return img


def jm_wall_tiles():
    """지하시장 실내 벽(ts_jm_wall, 1-4): s07 벽과 같은 이름(윗면 wt_m은 같고 벽면만 상가 타일)."""
    out = {f"wt_{m}": wall_top({e for e, b in WALL_BITS if m & b}) for m in range(16)}
    out.update({"face_top": wall_face_jm("top"), "face_top_pipe": wall_face_jm("top", "sign", 1),
                "face_top_vent": wall_face_jm("top", "stain", 2), "face_bot": wall_face_jm("bot"),
                "face_bot_outlet": wall_face_jm("bot", "outlet")})
    return out


def wall_face_bk(part, variant="plain", seed=0):
    """여의도 지하 벙커 벽(1-5 MQ-104 Y-00~Y-04): 1970년대 군 시설 콘크리트 — 위는 미색 수성 칠, 허리 아래는 국방색 칠 + 짙은 경계 띠,
    천장은 노출 콘크리트 보. 200년 습기에 칠이 일어나 회색 콘크리트가 드러나고 물이 줄지어 흘렀다. 쯔꾸르식 평평한 면."""
    img = new("P22")
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed * 19 + (1 if part == "top" else 2))
    if part == "top":
        d.rectangle([0, 0, 31, 6], fill=C("P05"))                     # 천장 보(노출 콘크리트)
        d.line([0, 0, 31, 0], fill=C("P01")); d.line([0, 1, 31, 1], fill=C("P07")); d.line([0, 6, 31, 6], fill=C("P02"))
        for x in (3, 11, 24):
            d.point((x, 3 + x % 2), fill=C("P04"))                     # 거푸집 자국
        d.line([0, 7, 31, 7], fill=C("P20"))
        for y in range(9, 32, 6):                                      # 미색 칠의 붓 결
            x = rnd.randrange(0, 24)
            d.line([x, y, x + rnd.randint(4, 9), y], fill=C("P21"))
        if variant == "sign":                                          # '관계자 외 출입 금지' 철판 표지(흰 바탕 붉은 글 줄)
            d.rectangle([5, 11, 26, 25], fill=C("P01"))
            d.rectangle([6, 12, 25, 24], fill=C("P09"))
            d.rectangle([6, 12, 25, 15], fill=C("P53"))
            for yy in (18, 21):
                d.line([8, yy, 23, yy], fill=C("P53"))
            for x, y in ((6, 12), (25, 12), (6, 24), (25, 24)):
                d.point((x, y), fill=C("P05"))
            d.line([24, 25, 24, 29], fill=C("P25"))                    # 볼트 녹
        if variant == "stain":                                         # 칠이 일어나 콘크리트가 드러나고 물이 흐른다
            d.polygon([(9, 12), (17, 10), (20, 17), (12, 21), (7, 17)], fill=C("P06"))
            d.line([9, 12, 17, 10], fill=C("P09")); d.point((12, 15), fill=C("P05"))
            for k in range(3):
                x = rnd.randrange(3, 29)
                d.line([x, 8, x, 8 + rnd.randint(10, 23)], fill=C("P20"))
    else:
        d.rectangle([0, 0, 31, 3], fill=C("P22"))
        d.rectangle([0, 4, 31, 6], fill=C("P28"))                     # 경계 띠(짙은 국방색)
        d.line([0, 4, 31, 4], fill=C("P01"))
        d.rectangle([0, 7, 31, 28], fill=C("P29"))                    # 허리 아래 국방색
        d.line([0, 7, 31, 7], fill=C("P31"))
        x, y = rnd.randrange(4, 26), rnd.randrange(12, 22)              # 칠 일어남(작은 회색 조각 하나 — 되풀이가 눈에 띄지 않게)
        d.rectangle([x, y, x + 2, y + 1], fill=C("P05")); d.point((x, y), fill=C("P07"))
        x = rnd.randrange(2, 30)
        d.line([x, 8, x, 8 + rnd.randint(4, 9)], fill=C("P28"))
        d.rectangle([0, 29, 31, 31], fill=C("P03")); d.line([0, 29, 31, 29], fill=C("P01"))   # 걸레받이(콘크리트 턱)
        if variant == "outlet":                                       # 쇠 전선관 + 2077 이전 스위치 함
            d.line([22, 0, 22, 10], fill=C("P04")); d.line([23, 0, 23, 10], fill=C("P06"))
            d.rectangle([18, 10, 27, 20], fill=C("P02")); d.rectangle([19, 11, 26, 19], fill=C("P05"))
            d.rectangle([21, 13, 24, 17], fill=C("P03")); d.point((22, 14), fill=C("P54"))
            d.line([19, 11, 26, 11], fill=C("P07"))
    return img


def bk_wall_tiles():
    """여의도 벙커 실내 벽(ts_bk_wall, 1-5): s07 벽과 같은 이름(윗면 wt_m은 같고 벽면만 군 시설 칠)."""
    out = {f"wt_{m}": wall_top({e for e, b in WALL_BITS if m & b}) for m in range(16)}
    out.update({"face_top": wall_face_bk("top"), "face_top_pipe": wall_face_bk("top", "sign", 1),
                "face_top_vent": wall_face_bk("top", "stain", 2), "face_bot": wall_face_bk("bot"),
                "face_bot_outlet": wall_face_bk("bot", "outlet")})
    return out


def wall_face_sd(part, variant="plain", seed=0):
    """사당역 대합실 벽(1-8f 사당 환승촌 D-01~D-06): 2077년 역사의 미색 법랑 패널(16×12 줄눈) + 허리 높이 노선 띠
    (2호선 녹색 위 · 4호선 하늘색 아래, 환승역이라 두 줄) + 아래 짙은 화강석 걸레받이. 200년 그을음과 물때. 쯔꾸르식 평평한 면."""
    img = new("P08")
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed * 23 + (1 if part == "top" else 2))
    if part == "top":
        d.rectangle([0, 0, 31, 5], fill=C("P05"))                     # 천장 반자(그을음)
        d.line([0, 0, 31, 0], fill=C("P01")); d.line([0, 1, 31, 1], fill=C("P06")); d.line([0, 5, 31, 5], fill=C("P02"))
        d.line([0, 6, 31, 6], fill=C("P07"))
        for y in (18, 30):                                             # 법랑 패널 줄눈
            d.line([0, y, 31, y], fill=C("P07"))
        for x in (0, 16):
            d.line([x, 7, x, 31], fill=C("P07")); d.line([x + 1, 7, x + 1, 31], fill=C("P09"))
        d.line([2, 8, 14, 8], fill=C("P09")); d.line([18, 8, 30, 8], fill=C("P09"))
        for _ in range(2):                                             # 그을음 얼룩
            x = rnd.randrange(2, 26)
            d.rectangle([x, 7, x + rnd.randint(3, 6), 7 + rnd.randint(1, 3)], fill=C("P07"))
        if variant == "sign":                                          # 역 이름 판: 흰 바탕 '사당' + 2·4호선 동그라미
            d.rectangle([2, 11, 29, 25], fill=C("P01")); d.rectangle([3, 12, 28, 24], fill=C("P09"))
            d.ellipse([4, 14, 10, 20], fill=C("P55")); d.ellipse([21, 14, 27, 20], fill=C("P62"))
            d.point((7, 17), fill=C("P09")); d.point((24, 17), fill=C("P09"))
            d.line([11, 22, 20, 22], fill=C("P02")); d.line([12, 15, 19, 15], fill=C("P02"))
            d.line([12, 18, 19, 18], fill=C("P04"))
        if variant == "stain":                                         # 물때가 패널 줄눈을 타고 흐른다
            for k in range(3):
                x = rnd.choice([1, 16, 17, rnd.randrange(3, 29)])
                d.line([x, 7, x, 7 + rnd.randint(10, 24)], fill=C("P06"))
                d.point((x, 7), fill=C("P25"))
    else:
        d.line([0, 2, 31, 2], fill=C("P07"))
        d.line([0, 0, 0, 2], fill=C("P07")); d.line([16, 0, 16, 2], fill=C("P07"))
        d.rectangle([0, 4, 31, 6], fill=C("P55")); d.line([0, 4, 31, 4], fill=C("P56"))   # 2호선 띠(녹)
        d.rectangle([0, 7, 31, 9], fill=C("P62")); d.line([0, 9, 31, 9], fill=C("P61"))   # 4호선 띠(하늘)
        d.line([0, 10, 31, 10], fill=C("P09"))
        for x in (0, 16):
            d.line([x, 11, x, 20], fill=C("P07"))
        x = rnd.randrange(3, 27)
        d.line([x, 11, x, 11 + rnd.randint(3, 8)], fill=C("P06"))
        d.rectangle([0, 21, 31, 28], fill=C("P03"))                   # 화강석 걸레받이
        d.line([0, 21, 31, 21], fill=C("P01")); d.line([0, 22, 31, 22], fill=C("P05"))
        for k in range(3):
            d.point((rnd.randrange(1, 31), rnd.randrange(23, 28)), fill=C("P04"))
        if variant == "outlet":                                       # 소화전 함(빨강, 유리 깨짐)
            d.rectangle([18, 8, 29, 20], fill=C("P01")); d.rectangle([19, 9, 28, 19], fill=C("P53"))
            d.rectangle([20, 10, 27, 15], fill=C("P02")); d.line([20, 10, 24, 14], fill=C("P07"))
            d.line([20, 17, 27, 17], fill=C("P09"))
    return img


def wall_face_cv(part, variant="plain", seed=0):
    """하수·빗물 암거 벽(TS-I10, 1-T3 — 관악 계곡 배수로 K-08 · 윤중제 배수로 Y-05): 거푸집 자국이 줄진 회색 콘크리트 상자 암거.
    위는 둥근 모서리 그늘과 천장에서 번진 검은 곰팡이(S-07 수경 농장과 같은 곰팡이, H-R01-02), 허리에 물때 줄(평소 수위),
    아래는 늘 젖은 짙은 띠와 물방울. 변형: pipe 옛 관 구멍(물이 흘러나옴) · vent 철근이 드러난 깨진 면 · stain 곰팡이 군락 · outlet 배수 창살."""
    img = new("P05")
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed * 31 + (1 if part == "top" else 2))
    if part == "top":
        d.rectangle([0, 0, 31, 5], fill=C("P02"))                     # 천장 모서리 그늘(둥근 헌치)
        d.line([0, 0, 31, 0], fill=C("P01")); d.line([0, 6, 31, 6], fill=C("P04"))
        d.line([0, 7, 31, 7], fill=C("P06"))
        for y in (16, 26):                                             # 거푸집 판 자국
            d.line([0, y, 31, y], fill=C("P04")); d.line([0, y + 1, 31, y + 1], fill=C("P06"))
        for x in (0, 20):
            d.line([x, 8, x, 31], fill=C("P04"))
        for _ in range(3):                                             # 천장에서 번진 검은 곰팡이 점
            x = rnd.randrange(1, 30)
            d.rectangle([x, 6, x + rnd.randint(1, 3), 6 + rnd.randint(1, 3)], fill=C("P01"))
            d.point((x + rnd.randint(-1, 3), 10 + rnd.randint(0, 3)), fill=C("P02"))
        for _ in range(4):
            d.point((rnd.randrange(0, 32), rnd.randrange(9, 31)), fill=C("P06"))
        if variant == "pipe":                                          # 옛 관 구멍: 녹슨 테 · 안은 깜깜 · 흘러내린 물줄기
            d.ellipse([9, 11, 22, 24], fill=C("P01")); d.ellipse([9, 11, 22, 24], outline=C("P24"))
            d.arc([10, 12, 21, 23], 200, 340, fill=C("P25"))
            d.line([15, 24, 15, 31], fill=C("P11")); d.line([16, 24, 16, 31], fill=C("P12"))
        if variant == "vent":                                          # 깨진 면: 철근 둘이 드러남
            d.polygon([(6, 12), (24, 10), (27, 22), (8, 25)], fill=C("P03"))
            d.line([7, 16, 25, 15], fill=C("P24")); d.line([8, 20, 26, 19], fill=C("P25"))
            d.point((5, 13), fill=C("P06")); d.point((26, 23), fill=C("P06"))
        if variant == "stain":                                         # 곰팡이 군락
            for _ in range(9):
                x, y = rnd.randrange(3, 27), rnd.randrange(8, 26)
                r = rnd.randint(1, 3)
                d.ellipse([x - r, y - r, x + r, y + r], fill=C("P01"))
                d.point((x + r, y - r), fill=C("P29"))
    else:
        d.line([0, 2, 31, 2], fill=C("P04")); d.line([0, 3, 31, 3], fill=C("P06"))
        d.line([0, 0, 0, 13], fill=C("P04")); d.line([20, 0, 20, 13], fill=C("P04"))
        d.rectangle([0, 9, 31, 11], fill=C("P29"))                    # 평소 수위 물때 줄(이끼 녹)
        d.line([0, 9, 31, 9], fill=C("P30")); d.line([0, 12, 31, 12], fill=C("P04"))
        d.rectangle([0, 13, 31, 28], fill=C("P03"))                    # 늘 젖은 아래 띠
        d.line([0, 13, 31, 13], fill=C("P02"))
        for _ in range(4):                                             # 물방울 · 흐른 자국
            x = rnd.randrange(1, 31)
            d.line([x, 13, x, 13 + rnd.randint(3, 10)], fill=C("P11"))
            d.point((x, 14), fill=C("P13"))
        d.rectangle([0, 29, 31, 31], fill=C("P02")); d.line([0, 29, 31, 29], fill=C("P01"))
        if variant == "outlet":                                       # 배수 창살(바닥 쪽 네모 구멍)
            d.rectangle([9, 17, 24, 28], fill=C("P01"))
            for x in range(10, 24, 3):
                d.line([x, 17, x, 28], fill=C("P12"))
            d.line([9, 17, 24, 17], fill=C("P13"))
    return img


def cv_wall_tiles():
    """하수·빗물 암거 벽(ts_cv_wall, TS-I10 — 1-T3): s07 벽과 같은 이름(윗면 wt_m은 같고 벽면만 젖은 콘크리트 암거)."""
    out = {f"wt_{m}": wall_top({e for e, b in WALL_BITS if m & b}) for m in range(16)}
    out.update({"face_top": wall_face_cv("top"), "face_top_pipe": wall_face_cv("top", "pipe", 1),
                "face_top_vent": wall_face_cv("top", "stain", 2), "face_bot": wall_face_cv("bot"),
                "face_bot_outlet": wall_face_cv("bot", "outlet")})
    return out


def sd_wall_tiles():
    """사당역 실내 벽(ts_sd_wall, 1-8f): s07 벽과 같은 이름(윗면 wt_m은 같고 벽면만 역사 법랑 패널)."""
    out = {f"wt_{m}": wall_top({e for e, b in WALL_BITS if m & b}) for m in range(16)}
    out.update({"face_top": wall_face_sd("top"), "face_top_pipe": wall_face_sd("top", "sign", 1),
                "face_top_vent": wall_face_sd("top", "stain", 2), "face_bot": wall_face_sd("bot"),
                "face_bot_outlet": wall_face_sd("bot", "outlet")})
    return out


def sheet(tiles, cols=9, bg="P19"):
    names = list(tiles)
    rows = (len(names) + cols - 1) // cols
    out = Image.new("RGBA", (cols * 34 + 2, rows * 34 + 2), C(bg))
    for i, n in enumerate(names):
        out.alpha_composite(tiles[n], (2 + (i % cols) * 34, 2 + (i // cols) * 34))
    return out


def samples():
    """samples/03_tiles_r01(·_x4), 10_tiles_s07(·_x3), 10_gear_door(.gif·_8f) — 아이작풍 판."""
    import tiles_s07 as S
    from grid import upscale
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "samples")
    a = sheet(r01_tiles(), 9)
    a.save(os.path.join(out, "03_tiles_r01.png"))
    upscale(a, 4).save(os.path.join(out, "03_tiles_r01_x4.png"))
    props = [S.door_slide("closed", "교무"), S.door_slide("open"), S.slogan_crt("성적이 곧 미래다", 3), S.rank_board(), S.wall_clock(),
             S.blackboard(), S.ration_window(), S.emblem(), S.canteen_table(3), S.stool(), S.exam_desk(), S.teacher_desk(),
             S.bunk(), S.locker_row(2), S.exam_bed(), S.med_cabinet(), S.overseer_desk(), S.safe(), S.planter()]
    tiles = sheet(s07_tiles(), 12)
    W = max(tiles.width, 640)
    b = Image.new("RGBA", (W, 520), C("P19"))
    b.alpha_composite(tiles, (0, 0))
    x, y, rowh = 8, tiles.height + 10, 0
    for im in props:
        im = outline(im)
        if x + im.width + 6 > W:
            x, y, rowh = 8, y + rowh + 8, 0
        b.alpha_composite(im, (x, y))
        x += im.width + 8
        rowh = max(rowh, im.height)
    b = b.crop((0, 0, W, y + rowh + 8))
    b.save(os.path.join(out, "10_tiles_s07.png"))
    upscale(b, 3).save(os.path.join(out, "10_tiles_s07_x3.png"))
    strip = Image.new("RGBA", (8 * 198, 198), C("P10"))
    frames = []
    for f in range(8):
        g = outline(S.gear_door(f))
        strip.alpha_composite(g, (f * 198 + 2, 2))
    strip.save(os.path.join(out, "10_gear_door_8f.png"))
    for f in list(range(8)) + [7] * 6:
        bg = Image.new("RGBA", (198 + S.ROLL_PX, 198), C("P10"))
        bg.alpha_composite(outline(S.gear_door(f)), (2 + int(S.ROLL_PX * f / 7), 2))
        frames.append(upscale(bg, 2).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "10_gear_door.gif"), save_all=True, append_images=frames[1:], duration=110, loop=0)


if __name__ == "__main__":
    samples()
