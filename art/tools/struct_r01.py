"""R01 바깥 구조물(단계 0-10, SD-16 §6.3·§6.5·§7): 관악산 비탈·봉천 계단마을의 정면·지붕·옹벽·암벽·고철 장벽.
맵마다 구조물 층 한 장으로 굽는다(쯔꾸르 '패럴랙스 맵핑'식 — 같은 무늬가 되풀이되지 않게 건물·벽마다 따로 그린다).
바닥은 바닥 합성 셰이더(ground.py)가 그리고, 이 층은 그 위·인물 아래에 놓인다(인물·소품은 y 정렬로 그 위).

규칙(SD-16):
  · 저층 건물 1층 = 정면 1타일(32px), 4층 이상은 압축(정면 최대 6타일). 정면은 남쪽만 그린다(3/4 시점).
  · 콘크리트 옹벽 = 평평한 바탕 + 거푸집 이음매(어두운 선 + 밝은 선) + 폼타이 구멍 + 갓돌·아래 때 띠.
  · 벽돌 = 8×4 벽돌 엇갈림, 윗줄 밝게·아랫줄 어둡게 + 밝은 줄눈. 산지 높이 차 = 정면 암벽 1~3타일.
  · 빛은 왼쪽 위. 먹선(P01)으로 큰 덩어리를 두른다(아이작풍). 반투명·팔레트 밖 색 없음.
모든 함수는 (w, h) 타일 크기의 RGBA 그림을 돌려준다. 씨앗(seed)이 같으면 같은 그림.
"""
import os, sys, math, random
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import tiles_isaac as TI

T = 32
ROOT = os.path.dirname(os.path.dirname(__file__))
C = lambda t: P.rgb(t) + (255,)
INK = "P01"
_FONTS = {}


def _font(size=8, name="Galmuri7"):
    k = (name, size)
    if k not in _FONTS:
        _FONTS[k] = ImageFont.truetype(os.path.join(ROOT, "fonts", name + ".ttf"), size)
    return _FONTS[k]


def text_px(s, size=8, name="Galmuri7"):
    """픽셀 글꼴 글자 마스크(안티에일리어스 없음): (점 집합, 폭, 높이)."""
    f = _font(size, name)
    l, t_, r, b = f.getbbox(s)
    im = Image.new("1", (r - l + 2, b - t_ + 2), 0)
    ImageDraw.Draw(im).text((-l, -t_), s, font=f, fill=1)
    px = im.load()
    pts = {(x, y) for y in range(im.height) for x in range(im.width) if px[x, y]}
    return pts, im.width, im.height


def put_text(img, s, x, y, col, size=8, name="Galmuri7", shadow=None):
    pts, w, h = text_px(s, size, name)
    px = img.load()
    if shadow:
        for (a, b) in pts:
            q = (x + a + 1, y + b + 1)
            if 0 <= q[0] < img.width and 0 <= q[1] < img.height and (a + 1, b + 1) not in pts:
                px[q] = C(shadow)
    for (a, b) in pts:
        if 0 <= x + a < img.width and 0 <= y + b < img.height:
            px[x + a, y + b] = C(col)
    return w, h


def vnoise(W, H, sc, seed):
    """매끈한 값 잡음 [H, W] 0..1(이중선형 + 스무스스텝)."""
    import numpy as np
    rng = np.random.default_rng(seed)
    gw, gh = W // sc + 3, H // sc + 3
    g = rng.random((gh, gw))
    ys, xs = np.mgrid[0:H, 0:W] / sc
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def new(w, h, fill=None):
    return Image.new("RGBA", (w * T, h * T), C(fill) if fill else (0, 0, 0, 0))


def hsh(*a):
    v = 2166136261
    for k in a:
        v = ((v ^ (int(k) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return v


def step_px(img, x, y, k):
    """그 점 색을 자기 램프에서 k단 옮긴다(투명은 그대로)."""
    if 0 <= x < img.width and 0 <= y < img.height:
        c = img.getpixel((x, y))
        if c[3]:
            img.putpixel((x, y), P.step(c[:3], k) + (255,))


def shade_rect(img, box, k=-1, every=1):
    x0, y0, x1, y1 = box
    for y in range(max(0, y0), min(img.height, y1)):
        for x in range(max(0, x0), min(img.width, x1)):
            if every == 1 or (x + y) % every == 0:
                step_px(img, x, y, k)


def streak(img, x, y, n, k=-1, rnd=None, wobble=0.0):
    """물 얼룩·녹물: 아래로 흘러내린 1px 줄(끝으로 갈수록 끊긴다)."""
    for i in range(n):
        if rnd is not None and i > n * 0.6 and rnd.random() < 0.4:
            continue
        xx = x + (int(round(math.sin(i * 0.7) * wobble)) if wobble else 0)
        step_px(img, xx, y + i, k)


# ================================================================================================ 빌라 정면
WALL_STYLES = {
    # 바탕 · 밝음 · 어두움 · 줄눈(벽돌) — 빌라마다 하나
    "brick": ("P25", "P26", "P24", "P05"),          # 붉은 벽돌(1980년대 빌라 원형, 2077년까지 같은 공법)
    "brick_dk": ("P24", "P25", "P23", "P04"),       # 그을린 벽돌
    "plaster": ("P21", "P22", "P20", None),         # 미장(누런 크림)
    "concrete": ("P07", "P08", "P06", None),        # 노출 콘크리트
    "tile": ("P08", "P09", "P07", None),            # 흰 외장 타일(4px 격자)
    "mint": ("P14", "P15", "P13", None),            # 바랜 하늘색 페인트
}


def _wall_fill(img, box, style, seed):
    base, hi, lo, joint = WALL_STYLES[style]
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=C(base))
    rnd = random.Random(seed)
    if style.startswith("brick"):
        d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=C(joint))
        for row, y in enumerate(range(y0, y1, 4)):
            off = 4 if row % 2 else 0
            for x in range(x0 - 8 + off, x1, 8):
                r = rnd.random()
                b, h_, l_ = (base, hi, lo) if r < 0.82 else ((lo, base, P_dn(lo)) if r < 0.93 else (hi, P_up(hi), base))
                a0, a1 = max(x0, x), min(x1 - 1, x + 6)
                if a1 < a0:
                    continue
                d.rectangle([a0, y, a1, min(y1 - 1, y + 2)], fill=C(b))
                d.line([a0, y, a1, y], fill=C(h_))
                if y + 2 < y1:
                    d.line([a0, y + 2, a1, y + 2], fill=C(l_))
    elif style == "tile":
        for y in range(y0, y1, 4):
            d.line([x0, y, x1 - 1, y], fill=C(lo))
        for x in range(x0, x1, 4):
            d.line([x, y0, x, y1 - 1], fill=C(lo))
        for _ in range((x1 - x0) * (y1 - y0) // 120):                    # 떨어져 나간 타일(시멘트 바탕)
            tx, ty = x0 + rnd.randrange(0, max(1, (x1 - x0) // 4)) * 4, y0 + rnd.randrange(0, max(1, (y1 - y0) // 4)) * 4
            d.rectangle([tx + 1, ty + 1, tx + 3, ty + 3], fill=C("P06"))
    else:                                                                # 미장·콘크리트·페인트: 큰 얼룩 두어 개(평평한 바탕 유지)
        for _ in range(max(1, (x1 - x0) * (y1 - y0) // 2600)):
            cx, cy = rnd.randrange(x0, x1), rnd.randrange(y0, y1)
            rx, ry = rnd.randint(6, 14), rnd.randint(3, 7)
            for y in range(cy - ry, cy + ry + 1):
                for x in range(cx - rx, cx + rx + 1):
                    if x0 <= x < x1 and y0 <= y < y1 and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                        img.putpixel((x, y), C(lo))
        if style == "concrete":
            for x in range(x0 + 15, x1, 16):
                d.line([x, y0, x, y1 - 1], fill=C("P06"))
                d.line([x + 1, y0, x + 1, y1 - 1], fill=C("P08"))


def P_up(tok):
    return "P%02d" % min(63, int(tok[1:]) + 1)


def P_dn(tok):
    return "P%02d" % max(0, int(tok[1:]) - 1)


def window(img, x, y, w=18, h=16, kind="glass", rnd=None, frame="P08"):
    """미닫이 알루미늄 창 + 방범창 살(한국 빌라). kind: glass · dark(열린 창) · board(판자) · broken · curtain · laundry · plant."""
    rnd = rnd or random.Random(0)
    d = ImageDraw.Draw(img)
    d.rectangle([x - 1, y - 1, x + w, y + h], fill=C(INK))
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=C(frame))
    gx0, gy0, gx1, gy1 = x + 1, y + 1, x + w - 2, y + h - 2
    if kind in ("glass", "laundry", "plant", "curtain"):
        d.rectangle([gx0, gy0, gx1, gy1], fill=C("P11"))
        d.rectangle([gx0, gy0, gx1, gy0 + 3], fill=C("P12"))              # 위쪽에 비친 하늘
        for k in range(3):                                                # 사선 반사
            d.line([gx0 + 3 + k * 5, gy1, gx0 + 3 + k * 5 + 4, gy1 - 4], fill=C("P13")) if k != 1 else None
        d.line([x + w // 2, gy0, x + w // 2, gy1], fill=C(frame))         # 미닫이 두 짝
        if kind == "curtain":
            col = rnd.choice(["P26", "P36", "P21", "P45"])
            d.rectangle([gx0, gy0, gx0 + 4, gy1], fill=C(col))
            d.rectangle([gx1 - 4, gy0, gx1, gy1], fill=C(col))
            d.line([gx0 + 4, gy0, gx0 + 4, gy1], fill=C(P_dn(col)))
    elif kind == "dark":
        d.rectangle([gx0, gy0, gx1, gy1], fill=C("P02"))
        d.rectangle([gx0, gy0, gx0 + (w - 4) // 2, gy1], fill=C("P11"))    # 한 짝만 남은 유리
        d.line([x + w // 2, gy0, x + w // 2, gy1], fill=C(frame))
    elif kind == "lit":                                                   # 불 켜진 창(진공관 스탠드 — 호박색 유리 · 책상 그림자 · 창턱 아래 빛 번짐)
        d.rectangle([gx0, gy0, gx1, gy1], fill=C("P59"))
        d.rectangle([gx0, gy0, gx1, gy0 + 2], fill=C("P60"))
        d.rectangle([gx0 + 2, gy1 - 5, gx0 + 7, gy1], fill=C("P49"))        # 책상 · 사람 그림자
        d.rectangle([gx0 + 4, gy1 - 9, gx0 + 6, gy1 - 5], fill=C("P49"))
        d.line([x + w // 2, gy0, x + w // 2, gy1], fill=C(frame))
        for k in range(4):
            yy = y + h + 3 + k
            for xx in range(x - 2 - k, x + w + 2 + k):
                if (xx + yy) % 2 == 0 and 0 <= xx < img.width and 0 <= yy < img.height and img.getpixel((xx, yy))[3] == 0:
                    img.putpixel((xx, yy), C("P58"))
    elif kind == "board":
        d.rectangle([gx0, gy0, gx1, gy1], fill=C("P02"))
        for k, yy in enumerate(range(gy0, gy1, 4)):
            col = ["P19", "P18", "P20"][k % 3]
            d.rectangle([gx0 - 1, yy, gx1 + 1, yy + 2], fill=C(col))
            d.line([gx0 - 1, yy + 2, gx1 + 1, yy + 2], fill=C("P17"))
            d.point((gx0 + 1, yy + 1), fill=C("P04")); d.point((gx1 - 1, yy + 1), fill=C("P04"))
    elif kind == "broken":
        d.rectangle([gx0, gy0, gx1, gy1], fill=C("P01"))
        pts = [(gx0, gy0), (gx0 + 6, gy0), (gx0 + 3, gy0 + 4), (gx0 + 5, gy0 + 8), (gx0, gy0 + 6)]
        d.polygon(pts, fill=C("P11"))
        d.polygon([(gx1, gy1), (gx1 - 5, gy1), (gx1 - 2, gy1 - 5)], fill=C("P11"))
    if kind != "board":                                                   # 방범창 살(세로 넷 + 가로 하나)
        for k in range(1, 5):
            xx = x + k * w // 5
            d.line([xx, y, xx, y + h - 1], fill=C("P04"))
        d.line([x, y + h // 2, x + w - 1, y + h // 2], fill=C("P04"))
    d.rectangle([x - 2, y + h, x + w + 1, y + h + 1], fill=C("P08"))       # 창턱
    d.line([x - 2, y + h + 2, x + w + 1, y + h + 2], fill=C(INK))
    if kind == "laundry":                                                 # 방범창에 넌 빨래
        for k, col in enumerate(rnd.sample(["P26", "P45", "P09", "P49", "P36", "P53"], 3)):
            xx = x + 2 + k * (w - 4) // 3
            d.rectangle([xx, y + h - 3, xx + 3, y + h + 4], fill=C(col))
            d.line([xx, y + h + 5, xx + 3, y + h + 5], fill=C(INK))
    if kind == "plant":
        for k in range(2):
            xx = x + 3 + k * (w - 8)
            d.rectangle([xx, y + h - 4, xx + 3, y + h - 1], fill=C("P25"))
            d.point((xx + 1, y + h - 6), fill=C("P30")); d.point((xx, y + h - 5), fill=C("P31")); d.point((xx + 2, y + h - 5), fill=C("P29"))


def door(img, x, y, w=18, h=26, kind="steel", rnd=None, num=None):
    """현관문: 콘크리트 차양 + 철문(steel) / 유리 미닫이(shop) / 셔터(shutter) / 빈 출입구(open)."""
    d = ImageDraw.Draw(img)
    d.rectangle([x - 4, y - 5, x + w + 3, y - 2], fill=C("P07"))             # 차양
    d.line([x - 4, y - 5, x + w + 3, y - 5], fill=C("P09"))
    d.line([x - 4, y - 1, x + w + 3, y - 1], fill=C(INK))
    d.line([x - 3, y, x + w + 2, y], fill=C("P05"))
    d.rectangle([x - 1, y, x + w, y + h], fill=C(INK))
    if kind == "steel":
        d.rectangle([x, y + 1, x + w - 1, y + h], fill=C("P05"))
        d.rectangle([x + 2, y + 3, x + w - 3, y + 11], fill=C("P06"))
        d.rectangle([x + 2, y + 14, x + w - 3, y + h - 3], fill=C("P06"))
        d.line([x + 2, y + 3, x + w - 3, y + 3], fill=C("P07"))
        d.line([x + 2, y + 14, x + w - 3, y + 14], fill=C("P07"))
        d.rectangle([x + w - 5, y + 13, x + w - 3, y + 14], fill=C("P48"))   # 손잡이
        if rnd is not None:
            for _ in range(3):
                streak(img, rnd.randint(x + 2, x + w - 3), y + rnd.randint(3, 10), rnd.randint(4, 9), -1, rnd)
    elif kind == "shop":
        d.rectangle([x, y + 1, x + w - 1, y + h], fill=C("P11"))
        d.rectangle([x, y + 1, x + w - 1, y + 4], fill=C("P12"))
        d.line([x + w // 2, y + 1, x + w // 2, y + h], fill=C("P07"))
        d.rectangle([x, y + 1, x + w - 1, y + h], outline=C("P07"))
        for k in range(2):                                               # 진열장 안 약병·상자
            yy = y + 8 + k * 7
            d.line([x + 2, yy + 3, x + w - 3, yy + 3], fill=C("P05"))
            for i, col in enumerate(["P09", "P53", "P49", "P15", "P09", "P37"][: (w - 4) // 3]):
                d.rectangle([x + 2 + i * 3, yy, x + 3 + i * 3, yy + 2], fill=C(col))
    elif kind == "shutter":
        d.rectangle([x, y + 1, x + w - 1, y + h], fill=C("P06"))
        for yy in range(y + 2, y + h, 2):
            d.line([x, yy, x + w - 1, yy], fill=C("P05"))
        d.rectangle([x, y + h - 9, x + w - 1, y + h], fill=C("P02"))        # 반쯤 올린 셔터 아래 어둠
        d.line([x, y + h - 9, x + w - 1, y + h - 9], fill=C("P08"))
    elif kind == "open":
        d.rectangle([x, y + 1, x + w - 1, y + h], fill=C("P01"))
        d.rectangle([x + 1, y + h - 6, x + w - 2, y + h], fill=C("P02"))
        for k in range(3):                                               # 안쪽 계단 디딤판(어둠 속)
            d.line([x + 2, y + h - 6 + k * 2, x + w - 3, y + h - 6 + k * 2], fill=C("P03"))
    if num:
        d.rectangle([x + w + 1, y + 2, x + w + 9, y + 7], fill=C("P44"))
        d.rectangle([x + w + 1, y + 2, x + w + 9, y + 7], outline=C(INK))
        put_text(img, num, x + w + 2, y + 2, "P09", 8, "Galmuri7")


def gas_pipe(img, x, y0, y1, meter_y=None):
    """노란 가스관(한국 빌라 외벽의 상징) — 세로 2px + 받침쇠, 아래 계량기 상자."""
    d = ImageDraw.Draw(img)
    d.line([x, y0, x, y1], fill=C("P49"))
    d.line([x + 1, y0, x + 1, y1], fill=C("P48"))
    d.line([x + 2, y0, x + 2, y1], fill=C(INK))
    for yy in range(y0 + 6, y1, 14):
        d.rectangle([x - 1, yy, x + 2, yy + 1], fill=C("P05"))
    if meter_y is not None:
        d.rectangle([x - 4, meter_y, x + 5, meter_y + 7], fill=C(INK))
        d.rectangle([x - 3, meter_y + 1, x + 4, meter_y + 6], fill=C("P07"))
        d.rectangle([x - 2, meter_y + 2, x + 3, meter_y + 4], fill=C("P10"))
        d.point((x, meter_y + 3), fill=C("P49"))


def facade(w, h, style="brick", seed=0, doors=(), shop=None, name=None, num=None, pipe=True, wear=1.0, windows=None, lit=()):
    """빌라 정면 w×h 타일(층 = 1타일, 맨 아래 = 1층). doors: 문 칸(열 번호) 목록 [(열, 종류)],
    shop: (열0, 열1, '간판 글') 1층 가게(약국 등), name: 옥상 갓돌 아래 빌라 이름(작은 칠 글자), num: 동 번호판.
    lit: 불 켜진 창 [(열, 아래서부터 층)] — 1-12i UQ-62 '200년 켜 둔 방'(밤 cond 그림으로 겹쳐 굽는다)."""
    lit = {tuple(p) for p in lit}
    rnd = random.Random(hsh(seed, w, h, 71))
    img = new(w, h)
    W, H = w * T, h * T
    _wall_fill(img, (0, 0, W, H), style, seed)
    d = ImageDraw.Draw(img)
    base, hi, lo, _ = WALL_STYLES[style]
    # 층마다 슬래브 띠(바닥 선) — 층의 리듬
    for f in range(1, h):
        y = f * T
        d.rectangle([0, y - 2, W - 1, y], fill=C("P07"))
        d.line([0, y - 2, W - 1, y - 2], fill=C("P08"))
        d.line([0, y + 1, W - 1, y + 1], fill=C(P_dn(lo)) if not style.startswith("brick") else C("P23"))
    # 갓돌(옥상 난간 앞면)
    d.rectangle([0, 0, W - 1, 5], fill=C("P08"))
    d.line([0, 0, W - 1, 0], fill=C("P09"))
    d.line([0, 5, W - 1, 5], fill=C("P06"))
    d.line([0, 6, W - 1, 6], fill=C(INK))
    for x in range(rnd.randint(4, 20), W - 4, rnd.randint(18, 30)):        # 갓돌에서 흘러내린 검은 물때
        streak(img, x, 7, rnd.randint(6, 18 if h > 1 else 10), -1, rnd)
    door_cols = {c: k for c, k in doors}
    shop_cols = set(range(shop[0], shop[1] + 1)) if shop else set()
    kinds = ["glass"] * 5 + ["curtain", "laundry", "plant", "dark", "board", "broken"]
    if windows:
        kinds = windows
    for f in range(h):                                                    # 위층부터: f = 0 맨 위
        floor_from_bottom = h - 1 - f
        y = f * T
        for col in range(w):
            x = col * T
            if floor_from_bottom == 0 and (col in door_cols or col in shop_cols):
                continue
            pick = rnd.random()
            if pick < 0.12 * wear:                                        # 창 없는 벽(배관·환기구)
                if rnd.random() < 0.5:
                    d.rectangle([x + 12, y + 12, x + 19, y + 17], fill=C(INK))
                    d.rectangle([x + 13, y + 13, x + 18, y + 16], fill=C("P05"))
                    for yy in (y + 14, y + 15):
                        d.line([x + 13, yy, x + 18, yy], fill=C("P03")) if yy % 2 == 0 else None
                continue
            k = rnd.choice(kinds)
            if floor_from_bottom == 0 and k in ("laundry",):
                k = "glass"
            if (col, floor_from_bottom) in lit:
                k = "lit"
            wy = y + (9 if f == 0 else 6)
            window(img, x + 7, wy, 18, 14 if f == 0 else 16, k, rnd)
            if rnd.random() < 0.5 * wear:                                 # 창 아래 녹물
                streak(img, x + rnd.randint(8, 23), wy + 19, rnd.randint(3, 8), -1, rnd)
    # 1층: 문·가게
    yb = (h - 1) * T
    for c, k in doors:
        door(img, c * T + 7, yb + 6, 18, 25, k, rnd, num=num if k == "steel" else None)
    if shop:
        c0, c1, label = shop
        x0, x1 = c0 * T + 3, (c1 + 1) * T - 4
        d.rectangle([x0, yb + 12, x1, yb + 31], fill=C(INK))
        d.rectangle([x0 + 1, yb + 13, x1 - 1, yb + 31], fill=C("P11"))
        d.rectangle([x0 + 1, yb + 13, x1 - 1, yb + 15], fill=C("P12"))
        for xx in range(x0 + 1, x1, 12):
            d.line([xx, yb + 13, xx, yb + 31], fill=C("P07"))
        for xx in range(x0 + 3, x1 - 2, 3):                               # 진열장 약병
            col = ["P09", "P53", "P49", "P15", "P37", "P26"][(xx // 3) % 6]
            d.rectangle([xx, yb + 20, xx + 1, yb + 22], fill=C(col))
            d.rectangle([xx, yb + 26, xx + 1, yb + 28], fill=C(["P15", "P09", "P53"][(xx // 3) % 3]))
        d.line([x0 + 1, yb + 23, x1 - 1, yb + 23], fill=C("P05"))
        d.line([x0 + 1, yb + 29, x1 - 1, yb + 29], fill=C("P05"))
        # 간판(정면 1층 위 띠, 흰 판 + 붉은 '약' 원 + 글자)
        sx0, sx1 = x0 - 1, x1 + 1
        d.rectangle([sx0, yb + 1, sx1, yb + 10], fill=C(INK))
        d.rectangle([sx0 + 1, yb + 2, sx1 - 1, yb + 9], fill=C("P09"))
        d.line([sx0 + 1, yb + 9, sx1 - 1, yb + 9], fill=C("P07"))
        tx = sx0 + 3
        if label.endswith("약국"):
            d.ellipse([tx, yb + 2, tx + 7, yb + 9], fill=C("P53"))
            put_text(img, "약", tx + 1, yb + 2, "P09", 8, "Galmuri7")
            tx += 10
        put_text(img, label, tx, yb + 2, "P02", 8, "Galmuri7")
        for _ in range(3):                                                # 바랜 간판 귀퉁이
            step_px(img, rnd.randint(sx0 + 1, sx1 - 1), rnd.randint(yb + 2, yb + 9), -1)
    if name:                                                              # 빌라 이름(갓돌 아래 칠 글자, 바램)
        pts, tw, th = text_px(name, 8, "Galmuri7")
        nx = max(2, (W - tw) // 2 + rnd.randint(-8, 8))
        for (a, b) in pts:
            if rnd.random() < 0.88:
                img.putpixel((nx + a, 8 + b), C("P02" if style not in ("brick", "brick_dk") else "P08"))
    if pipe and w >= 2:                                                   # 가스관: 위에서 아래까지 + 1층 계량기
        px_ = rnd.choice([c for c in range(w) if c not in door_cols and c not in shop_cols] or [0]) * T + rnd.choice((2, 28))
        gas_pipe(img, px_, 7, H - 3, meter_y=yb + 14)
    # 아래 때 띠·물튐·이끼
    for x in range(W):
        for k in range(3):
            if (x * 7 + k * 3) % 5 != 0 or k == 0:
                step_px(img, x, H - 1 - k, -1)
        if rnd.random() < 0.06 * wear:
            for k in range(rnd.randint(1, 3)):
                img.putpixel((x, H - 2 - k), C(rnd.choice(["P29", "P30"])))
    # 균열 몇 줄
    for _ in range(int(w * h * 0.35 * wear)):
        cx, cy = rnd.randrange(4, W - 4), rnd.randrange(10, H - 4)
        for i in range(rnd.randint(4, 9)):
            if 0 <= cx < W and 0 <= cy < H:
                img.putpixel((cx, cy), C(P_dn(P_dn(base))))
            cx += rnd.choice((-1, 0, 1))
            cy += 1
    # 모서리: 왼쪽 밝은 1px, 오른쪽 어두운 2px, 바깥 먹선
    for y in range(7, H):
        step_px(img, 1, y, 1)
        step_px(img, W - 2, y, -1)
        step_px(img, W - 3, y, -1)
    d.line([0, 0, 0, H - 1], fill=C(INK))
    d.line([W - 1, 0, W - 1, H - 1], fill=C(INK))
    d.line([0, H - 1, W - 1, H - 1], fill=C(INK))
    return img


# ================================================================================================ 옥상(위에서 본 면)
def roof(w, h, seed=0, edges="new", paint="green", drains=True, hatch=None):
    """옥상 바닥(초록 방수 페인트) + 가장자리 난간 띠(edges 글자 n/e/w/s가 있는 쪽). hatch=(열, 행): 옥상 출입구 자리(소품이 덮음)."""
    rnd = random.Random(hsh(seed, w, h, 13))
    W, H = w * T, h * T
    ramp = {"green": ("P35", "P36", "P37", "P34"), "grey": ("P06", "P07", "P08", "P05"), "red": ("P24", "P25", "P26", "P23")}[paint]
    img = new(w, h, ramp[1])
    d = ImageDraw.Draw(img)
    nz = vnoise(W, H, 24, hsh(seed, 3)) * 0.7 + vnoise(W, H, 9, hsh(seed, 4)) * 0.3     # 바랜 자리(밝음)·때(어두움): 매끈한 큰 얼룩
    for y in range(H):
        for x in range(W):
            v = nz[y, x]
            if v > 0.72:
                img.putpixel((x, y), C(ramp[2]))
            elif v < 0.22:
                img.putpixel((x, y), C(ramp[0]))
    for _ in range(max(1, w * h // 4)):                                   # 벗겨진 방수층(회색 콘크리트)
        cx, cy = rnd.randrange(W), rnd.randrange(H)
        pts = []
        r = rnd.randint(3, 7)
        for y in range(cy - r, cy + r):
            for x in range(cx - r - 2, cx + r + 2):
                if 0 <= x < W and 0 <= y < H and abs(x - cx) * 0.6 + abs(y - cy) + rnd.random() * 1.5 < r:
                    img.putpixel((x, y), C("P06"))
                    pts.append((x, y))
        for (x, y) in pts:
            if (x, y - 1) not in pts and y - 1 >= 0:
                img.putpixel((x, y - 1), C(ramp[3]))
    for x in range(0, W, 64):                                             # 신축 줄눈
        for y in range(H):
            if img.getpixel((min(W - 1, x + 31), y))[:3] != P.rgb("P06"):
                img.putpixel((min(W - 1, x + 31), y), C(ramp[0]))
    for _ in range(w * h // 3 + 1):                                       # 금
        cx, cy = rnd.randrange(W), rnd.randrange(H)
        for i in range(rnd.randint(5, 12)):
            if 0 <= cx < W and 0 <= cy < H:
                img.putpixel((cx, cy), C(ramp[3]))
            cx += rnd.choice((-1, 0, 1, 1))
            cy += rnd.choice((0, 1))
    bw = 5
    def band(x0, y0, x1, y1, side):
        d.rectangle([x0, y0, x1, y1], fill=C("P07"))
        if side == "n":
            d.line([x0, y0, x1, y0], fill=C(INK)); d.line([x0, y1, x1, y1], fill=C("P08")); d.line([x0, y1 + 1, x1, y1 + 1], fill=C("P05"))
            d.line([x0, y1 + 2, x1, y1 + 2], fill=C("P05")) if rnd.random() < 2 else None
        elif side == "w":
            d.line([x0, y0, x0, y1], fill=C(INK)); d.line([x1, y0, x1, y1], fill=C("P08")); d.line([x1 + 1, y0, x1 + 1, y1], fill=C(ramp[0]))
        elif side == "e":
            d.line([x1, y0, x1, y1], fill=C(INK)); d.line([x0, y0, x0, y1], fill=C("P06")); d.line([x0 - 1, y0, x0 - 1, y1], fill=C(ramp[0]))
        elif side == "s":
            d.line([x0, y1, x1, y1], fill=C(INK)); d.line([x0, y0, x1, y0], fill=C("P08"))
    if "n" in edges:
        band(0, 0, W - 1, bw, "n")
    if "w" in edges:
        band(0, 0, bw - 1, H - 1, "w")
    if "e" in edges:
        band(W - bw, 0, W - 1, H - 1, "e")
    if "s" in edges:
        band(0, H - bw, W - 1, H - 1, "s")
    if "n" in edges and "w" in edges:
        d.rectangle([0, 0, bw - 1, bw], fill=C("P07")); d.line([0, 0, bw - 1, 0], fill=C(INK)); d.line([0, 0, 0, bw], fill=C(INK))
    if "n" in edges and "e" in edges:
        d.rectangle([W - bw, 0, W - 1, bw], fill=C("P07")); d.line([W - bw, 0, W - 1, 0], fill=C(INK)); d.line([W - 1, 0, W - 1, bw], fill=C(INK))
    if drains:                                                            # 배수구(구석)
        for (cx, cy) in ((bw + 4, bw + 4), (W - bw - 8, bw + 4)):
            if 0 < cx < W - 4 and 0 < cy < H - 4 and h > 1:
                d.rectangle([cx, cy, cx + 3, cy + 3], fill=C(INK))
                d.point((cx + 1, cy + 1), fill=C("P04")); d.point((cx + 2, cy + 2), fill=C("P04"))
    return img


# ================================================================================================ 옹벽(콘크리트)
POSTERS = [("충성", "등록"), ("등록", "하라"), ("물표", "20캡"), ("봉천", "반상회")]


def poster(img, x, y, kind=0, rnd=None):
    """벽보(바랜 종이 12×16): 비상정부 충성 등록 포스터 등. 귀퉁이가 찢겼다."""
    rnd = rnd or random.Random(kind)
    d = ImageDraw.Draw(img)
    top, bot = POSTERS[kind % len(POSTERS)]
    paper, ink_ = ("P09", "P53") if kind % 2 == 0 else ("P08", "P44")
    d.rectangle([x, y, x + 13, y + 17], fill=C(paper))
    d.rectangle([x, y, x + 13, y + 5], fill=C(ink_))
    put_text(img, top, x + 1, y - 1, "P09", 8, "Galmuri7")
    put_text(img, bot, x + 1, y + 7, ink_ if kind % 2 == 0 else "P02", 8, "Galmuri7")
    d.rectangle([x, y, x + 13, y + 17], outline=C("P05"))
    d.polygon([(x + 13, y + 17), (x + 8, y + 17), (x + 13, y + 12)], fill=(0, 0, 0, 0))   # 찢긴 귀퉁이
    for _ in range(6):
        step_px(img, x + rnd.randint(1, 12), y + rnd.randint(1, 16), -1)


def retaining_wall(w, h, seed=0, posters=(), outlets=True, vines=True, paint=None, cap=True):
    """콘크리트 옹벽 정면 w×h(1~3타일): 거푸집 판(64×32) 이음매 + 폼타이 구멍 + 갓돌 + 아래 때 띠 + 물빼기 구멍·녹물·덩굴·벽보.
    paint = [(x, y, '글', 색)]: 손으로 칠한 글씨."""
    rnd = random.Random(hsh(seed, w, h, 29))
    W, H = w * T, h * T
    img = new(w, h, "P06")
    d = ImageDraw.Draw(img)
    for x in range(0, W, 48):                                             # 거푸집 판 세로 이음매(어두운 선 + 밝은 선)
        d.line([x, 0, x, H - 1], fill=C("P04"))
        d.line([x + 1, 0, x + 1, H - 1], fill=C("P07"))
    for y in range(T - 4, H, 24):                                         # 가로 이음매
        d.line([0, y, W - 1, y], fill=C("P05"))
        d.line([0, y + 1, W - 1, y + 1], fill=C("P07"))
    for y in range(12, H - 6, 24):                                        # 폼타이 구멍
        for x in range(12, W, 24):
            d.point((x, y), fill=C("P03")); d.point((x, y + 1), fill=C("P07"))
    for _ in range(max(1, W * H // 1800)):                                # 큰 얼룩(밝음·어두움)
        cx, cy = rnd.randrange(W), rnd.randrange(H)
        rx, ry = rnd.randint(8, 18), rnd.randint(4, 9)
        k = 1 if rnd.random() < 0.4 else -1
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if 0 <= x < W and 0 <= y < H and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and (x + y) % 3:
                    if img.getpixel((x, y))[:3] == P.rgb("P06"):
                        step_px(img, x, y, k)
    if cap:                                                               # 갓돌(위에서 보이는 윗면 + 앞 모서리)
        d.rectangle([0, 0, W - 1, 4], fill=C("P08"))
        d.line([0, 0, W - 1, 0], fill=C("P09"))
        d.line([0, 4, W - 1, 4], fill=C("P07"))
        d.line([0, 5, W - 1, 5], fill=C(INK))
        d.line([0, 6, W - 1, 6], fill=C("P05"))
        for x in range(0, W, 48):
            d.line([x, 0, x, 4], fill=C("P07"))
    for x in range(rnd.randint(3, 15), W, rnd.randint(9, 17)):            # 갓돌 아래 물때
        streak(img, x, 7, rnd.randint(4, H // 2), -1, rnd)
    if outlets:                                                           # 물빼기 구멍(PVC 관) + 녹물·이끼
        for x in range(rnd.randint(14, 30), W - 8, rnd.randint(52, 80)):
            y = H - rnd.randint(14, 20) if h > 1 else 14
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C(INK))
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=C("P08"))
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=C("P02"))
            for k in range(rnd.randint(5, 12)):
                if y + 4 + k < H:
                    img.putpixel((x, y + 4 + k), C("P29" if k < 3 else "P05"))
                    if k < 5:
                        img.putpixel((x + 1, y + 4 + k), C("P30"))
    if vines:                                                             # 갓돌에서 늘어진 덩굴(담쟁이)
        for x in range(rnd.randint(4, 40), W, rnd.randint(40, 90)):
            n = rnd.randint(6, min(H - 8, 26))
            xx = x
            for i in range(n):
                yy = 6 + i
                for dx in (-1, 0, 1) if i < n - 3 else (0,):
                    if 0 <= xx + dx < W:
                        img.putpixel((xx + dx, yy), C(rnd.choice(["P29", "P30", "P30", "P31"])))
                if i % 4 == 2 and 0 <= xx + 2 < W:
                    img.putpixel((xx + 2, yy), C("P31")); img.putpixel((xx - 2, yy), C("P29")) if xx - 2 >= 0 else None
                xx += rnd.choice((-1, 0, 0, 1))
    for i, (px_, py_, kind) in enumerate(posters):
        poster(img, px_, py_, kind, rnd)
    for (x, y, s, col) in (paint or []):
        pts, tw, th = text_px(s, 8, "Galmuri9")
        for (a, b) in pts:
            if rnd.random() < 0.9 and 0 <= x + a < W and 0 <= y + b < H:
                img.putpixel((x + a, y + b), C(col))
    for x in range(W):                                                    # 아래 때 띠
        for k in range(4):
            if k < 2 or (x + k) % 2 == 0:
                step_px(img, x, H - 1 - k, -1)
    for _ in range(max(1, W // 40)):                                      # 균열
        cx, cy = rnd.randrange(4, W - 4), rnd.randrange(8, H - 4)
        for i in range(rnd.randint(5, 12)):
            if 0 <= cx < W and 0 <= cy < H:
                img.putpixel((cx, cy), C("P04"))
                if cx + 1 < W:
                    step_px(img, cx + 1, cy, 1)
            cx += rnd.choice((-1, 0, 1))
            cy += 1
    d.line([0, H - 1, W - 1, H - 1], fill=C(INK))
    return img


# ================================================================================================ 화강암 암벽(관악산)
def rock_face(w, h, seed=0, grass_top=True, rubble=True):
    """관악산 화강암 정면 w×h: 비스듬히 갈라진 바위 덩이(밝은 윗면·왼쪽, 어두운 틈) + 위쪽 풀 처마 + 아래 부스러기."""
    rnd = random.Random(hsh(seed, w, h, 37))
    W, H = w * T, h * T
    img = new(w, h, "P04")
    ramp = ["P03", "P04", "P05", "P06", "P07", "P08"]
    # 판상 절리(화강암 덩이): 비스듬히 늘인 보로노이 면. 면마다 기울기(빛 왼쪽 위)로 한 색, 가장자리 위·왼쪽은 밝은 테
    import numpy as np
    n = max(4, W * H // 520)
    sx = np.array([rnd.uniform(-8, W + 8) for _ in range(n)])
    sy = np.array([rnd.uniform(-6, H + 6) for _ in range(n)])
    tilt = [rnd.uniform(-1, 1) for _ in range(n)]
    ys, xs = np.mgrid[0:H, 0:W]
    shear = 0.45                                                          # 절리가 오른쪽 아래로 비스듬하다
    dx = (xs[None] - sx[:, None, None]) - shear * (ys[None] - sy[:, None, None])
    dy = (ys[None] - sy[:, None, None]) * 1.6
    dist = dx * dx + dy * dy
    order = np.argsort(dist, axis=0)
    own = order[0]
    d1 = np.take_along_axis(dist, order[0:1], 0)[0]
    d2 = np.take_along_axis(dist, order[1:2], 0)[0]
    edge = (np.sqrt(d2) - np.sqrt(d1)) < 1.6
    px = img.load()
    for y in range(H):
        for x in range(W):
            i = own[y, x]
            k = 3 + (1 if tilt[i] > 0.35 else 0) - (1 if tilt[i] < -0.4 else 0)
            # 면 안에서 위쪽은 한 단 밝게(둥근 덩이 느낌), 아래쪽 끝은 어둡게
            rel = (y - sy[i]) / 14.0
            if rel < -0.7:
                k += 1
            elif rel > 0.9:
                k -= 1
            px[x, y] = C(ramp[max(0, min(5, k))])
    for y in range(1, H):
        for x in range(1, W):
            if edge[y, x]:
                px[x, y] = C("P02")
                if y + 1 < H and not edge[y + 1, x]:
                    px[x, y + 1] = C(ramp[4])                            # 틈 아래 면의 밝은 윗테
    for _ in range(W * H // 160):                                         # 화강암 알갱이(흰 장석·검은 운모 점)
        x, y = rnd.randrange(W), rnd.randrange(H)
        if px[x, y][:3] not in (P.rgb("P02"),):
            px[x, y] = C("P09" if rnd.random() < 0.5 else "P03")
    for _ in range(W * H // 500):                                         # 이끼·지의류 반점
        x, y = rnd.randrange(W), rnd.randrange(H)
        if px[x, y][:3] in (P.rgb("P06"), P.rgb("P07")):
            px[x, y] = C(rnd.choice(["P31", "P32", "P30"]))
    for _ in range(max(1, W // 24)):                                      # 깊은 세로 틈
        x = rnd.randrange(4, W - 4)
        y = rnd.randrange(0, H // 2)
        for i in range(rnd.randint(8, H)):
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = C("P02")
                if x + 1 < W and px[x + 1, y][:3] != P.rgb("P02"):
                    px[x + 1, y] = C("P05")
            y += 1
            x += rnd.choice((-1, 0, 0, 1))
    if grass_top:                                                         # 위쪽 풀 처마(능선 풀이 벼랑 끝으로 넘어온다)
        for x in range(W):
            n = 2 + int(2 * (1 + math.sin(x * 0.37 + seed)) + rnd.random() * 2)
            for k in range(n):
                px[x, k] = C(["P30", "P29", "P30", "P31", "P28"][min(k, 4)] if k < n - 1 else "P28")
            if rnd.random() < 0.18:
                for k in range(n, n + rnd.randint(2, 5)):
                    if k < H:
                        px[x, k] = C("P29")
        for x in range(W):
            if rnd.random() < 0.25:
                px[x, 0] = C("P31")
    if rubble:                                                            # 아래 부스러기 띠
        for x in range(0, W, 3):
            if rnd.random() < 0.5:
                y = H - 1 - rnd.randint(0, 2)
                for dx in range(rnd.randint(1, 3)):
                    if x + dx < W:
                        px[x + dx, y] = C(rnd.choice(["P06", "P07", "P05"]))
    for x in range(W):
        px[x, H - 1] = C(INK)
    return img


def cave_mouth(w, h, seed=0, opening=(1, 2), grass_top=True):
    """암굴 입구(1-11a 관악산 들개 바위굴): 화강암 정면 w×h에 opening 칸(x0~x1, 구조물 안 칸 번호)만큼 아치 모양 굴 입구.
    입구 칸은 걷는 칸이다 — 위쪽은 짙은 그늘(굴 안), 아래로 갈수록 디더로 옅어져 바닥 흙이 비친다. 아치 테두리는 밝은 바위 테 + 먹선,
    입구 바닥엔 굴에서 끌려 나온 뼛조각과 털 뭉치."""
    rnd = random.Random(hsh(seed, w, h, 53))
    img = rock_face(w, h, seed, grass_top=grass_top, rubble=False)
    W, H = w * T, h * T
    px = img.load()
    x0, x1 = opening[0] * T, (opening[1] + 1) * T
    cx = (x0 + x1) / 2.0
    rx = (x1 - x0) / 2.0 - 1
    top = 8 if grass_top else 3
    arch = (H - top) * 0.62                                                 # 둥근 머리 높이
    jag = [rnd.uniform(-1.6, 1.6) for _ in range(H + 2)]
    BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(top, H):
        u = (y - top) / arch
        if u < 1.0:
            half = rx * math.sqrt(max(0.0, 1.0 - (1.0 - u) ** 2))            # 반타원 머리
        else:
            half = rx + 1.5 * (u - 1.0)                                      # 아래는 조금 벌어진다
        half += jag[y] + 0.8 * math.sin(y * 0.9 + seed)                      # 거친 바위 가장자리
        if half < 1:
            continue
        t = (y - top) / max(1.0, H - top)
        dark = 1.0 - max(0.0, (t - 0.35) / 0.65)                             # 굴 안 그늘: 위 1 → 아래 0
        for x in range(int(cx - half), int(cx + half) + 1):
            if not (0 <= x < W):
                continue
            if abs(x - cx) > half - 1.2:
                px[x, y] = C(INK)
                continue
            depth = dark * (1.0 - 0.35 * (abs(x - cx) / max(1.0, half)) ** 2)   # 가장자리는 빛이 조금 든다
            thr = (BAYER[y % 4][x % 4] + 0.5) / 16.0
            if depth > 0.85:
                px[x, y] = C("P00")
            elif depth > thr:
                px[x, y] = C("P01" if depth > 0.5 else "P02")
            else:
                px[x, y] = (0, 0, 0, 0)
        if u < 0.25:
            for x in (int(cx - half) - 1, int(cx + half) + 1):
                if 0 <= x < W:
                    px[x, y] = C("P07")                                      # 아치 이마의 밝은 바위 테
    for _ in range(int(rx // 3) + 2):                                       # 입구 바닥: 뼛조각 · 털 뭉치
        bx = int(cx + rnd.uniform(-rx * 0.8, rx * 0.8))
        by = H - rnd.randint(2, 7)
        if rnd.random() < 0.6:
            for k in range(rnd.randint(2, 4)):
                if 0 <= bx + k < W:
                    px[bx + k, by] = C("P09" if k % 3 else "P08")
        else:
            px[bx, by] = C("P06"); px[min(W - 1, bx + 1), by] = C("P07")
    return img


# ================================================================================================ 고철 장벽(정착지)
def scrap_wall(w, h=2, seed=0, gate=None, banner=None):
    """고철 장벽 정면 w×h: 골함석·자동차 문·철판·드럼통을 말뚝에 엮고 위에 가시철사. gate=(열0, 열1): 문 자리(비움).
    banner=(열0, 열1, '글'): 덧댄 분양 현수막(2077년 '분양' 광고 천을 뒤집어 철판에 덧댐)."""
    rnd = random.Random(hsh(seed, w, h, 53))
    W, H = w * T, h * T
    img = new(w, h)
    d = ImageDraw.Draw(img)
    skip = set()
    if gate:
        skip = set(range(gate[0] * T, (gate[1] + 1) * T))
    x = 0
    tones = [("P24", "P25", "P26"), ("P04", "P05", "P06"), ("P12", "P13", "P14"), ("P25", "P26", "P27"), ("P17", "P18", "P19")]
    while x < W:
        pw = rnd.randint(12, 26)
        if any(xx in skip for xx in range(x, x + pw)):
            x += 1
            continue
        kind = rnd.random()
        top = rnd.randint(4, 12)
        tone = rnd.choice(tones)
        x1 = min(W, x + pw)
        if kind < 0.6:                                                    # 골함석(세로 골)
            for xx in range(x, x1):
                col = tone[2] if (xx - x) % 4 == 0 else tone[1] if (xx - x) % 4 in (1, 3) else tone[0]
                d.line([xx, top, xx, H - 2], fill=C(col))
            d.line([x, top, x1 - 1, top], fill=C(tone[2]))
        elif kind < 0.8:                                                  # 자동차 문짝(창틀 구멍 + 손잡이)
            d.rectangle([x, top, x1 - 1, H - 2], fill=C(tone[1]))
            d.rectangle([x + 2, top + 2, x1 - 3, top + 9], fill=C("P02"))
            d.line([x, top, x1 - 1, top], fill=C(tone[2]))
            d.rectangle([x1 - 7, top + 13, x1 - 4, top + 14], fill=C("P07"))
        else:                                                             # 철판 + 리벳
            d.rectangle([x, top, x1 - 1, H - 2], fill=C(tone[1]))
            d.line([x, top, x1 - 1, top], fill=C(tone[2]))
            d.line([x, top, x, H - 2], fill=C(tone[2]))
            for yy in range(top + 4, H - 4, 8):
                d.point((x + 2, yy), fill=C(INK)); d.point((x1 - 3, yy), fill=C(INK))
        for _ in range(pw * (H - top) // 60):                             # 녹 반점
            xx, yy = rnd.randrange(x, x1), rnd.randrange(top, H - 2)
            img.putpixel((xx, yy), C(rnd.choice(["P24", "P23", "P25"])))
        d.line([x1 - 1, top, x1 - 1, H - 2], fill=C(INK))
        x = x1
    for xx in range(0, W, rnd.randint(30, 40)):                           # 말뚝(나무·쇠파이프) + 가로 각목
        if xx in skip or xx + 3 in skip:
            continue
        d.rectangle([xx, 2, xx + 3, H - 1], fill=C("P18"))
        d.line([xx, 2, xx, H - 1], fill=C("P19"))
        d.line([xx + 3, 2, xx + 3, H - 1], fill=C(INK))
    yy = H // 2
    segs = []
    cur = None
    for xx in range(W):
        if xx in skip:
            if cur is not None:
                segs.append((cur, xx - 1)); cur = None
        elif cur is None:
            cur = xx
    if cur is not None:
        segs.append((cur, W - 1))
    for (a, b) in segs:
        d.rectangle([a, yy, b, yy + 2], fill=C("P18"))
        d.line([a, yy, b, yy], fill=C("P19"))
        d.line([a, yy + 3, b, yy + 3], fill=C(INK))
        for xx in range(a, b, 6):                                         # 가시철사(위)
            d.line([xx, 2, xx + 3, 0], fill=C("P04")); d.line([xx + 3, 0, xx + 6, 2], fill=C("P04"))
            d.point((xx + 3, 1), fill=C("P07"))
    if banner:
        c0, c1, s = banner
        x0, x1 = c0 * T + 2, (c1 + 1) * T - 3
        d.rectangle([x0, 6, x1, 21], fill=C(INK))
        d.rectangle([x0 + 1, 7, x1 - 1, 20], fill=C("P09"))
        d.rectangle([x0 + 1, 7, x1 - 1, 9], fill=C("P53"))
        tx = x0 + 3
        put_text(img, s, tx, 9, "P52", 8, "Galmuri7")
        for _ in range(12):
            step_px(img, rnd.randint(x0 + 1, x1 - 1), rnd.randint(7, 20), -1)
        for xx in (x0 + 1, x1 - 1):
            d.point((xx, 7), fill=C("P07")); d.point((xx, 20), fill=C("P07"))
    for x in range(W):
        if x not in skip:
            img.putpixel((x, H - 1), C(INK))
    return img


# ================================================================================================ 그 밖
def gap(w, h, seed=0):
    """건물 사이 좁은 틈(위에서 내려다본 깊은 골목): 어둠 + 아래로 갈수록 바닥이 비친다."""
    img = new(w, h, "P02")
    d = ImageDraw.Draw(img)
    W, H = w * T, h * T
    for x in range(0, W, 7):
        d.line([x, 0, x, H - 1], fill=C("P01"))
    d.rectangle([0, H - 6, W - 1, H - 1], fill=C("P03"))
    return img


def ladder(h, seed=0):
    """철 사다리(벽면에 붙임) 1×h: 레일 둘 + 가로대(4px마다)."""
    img = new(1, h)
    d = ImageDraw.Draw(img)
    H = h * T
    for x in (8, 22):
        d.rectangle([x, 0, x + 1, H - 1], fill=C("P05"))
        d.line([x, 0, x, H - 1], fill=C("P07"))
        d.line([x + 2, 0, x + 2, H - 1], fill=C(INK))
    for y in range(3, H - 1, 6):
        d.line([10, y, 21, y], fill=C("P06"))
        d.line([10, y + 1, 21, y + 1], fill=C(INK))
    return img


def bridge(w, h, seed=0, axis="h"):
    """판자 다리(위에서 본 면): axis h = 동서로 건너는 다리(널은 남북으로 놓임). 양옆에 밧줄 난간."""
    rnd = random.Random(hsh(seed, w, h, 61))
    img = new(w, h)
    d = ImageDraw.Draw(img)
    W, H = w * T, h * T
    if axis == "h":
        x = 0
        while x < W:
            bw = rnd.randint(5, 7)
            col = rnd.choice(["P19", "P20", "P18", "P19"])
            d.rectangle([x, 3, x + bw - 1, H - 4], fill=C(col))
            d.line([x, 3, x, H - 4], fill=C(P_up(col)))
            d.line([x + bw - 1, 3, x + bw - 1, H - 4], fill=C("P16"))
            d.point((x + 2, 6), fill=C("P04")); d.point((x + 2, H - 7), fill=C("P04"))
            x += bw + (1 if rnd.random() < 0.3 else 0)
        for y in (2, H - 3):
            d.line([0, y, W - 1, y], fill=C("P21"))
            d.line([0, y + 1, W - 1, y + 1], fill=C(INK))
    else:
        y = 0
        while y < H:
            bh = rnd.randint(5, 7)
            col = rnd.choice(["P19", "P20", "P18", "P19"])
            d.rectangle([3, y, W - 4, y + bh - 1], fill=C(col))
            d.line([3, y, W - 4, y], fill=C(P_up(col)))
            d.line([3, y + bh - 1, W - 4, y + bh - 1], fill=C("P16"))
            y += bh
        for x in (2, W - 3):
            d.line([x, 0, x, H - 1], fill=C("P21"))
            d.line([x + 1, 0, x + 1, H - 1], fill=C(INK))
    return img


def ledge(w, h, seed=0, side="w", stuff="concrete"):
    """높이 차가 동·서로 나는 곳의 턱(위에서 본 가장자리 띠): side 쪽에 4px 턱 + 먹선."""
    img = new(w, h)
    d = ImageDraw.Draw(img)
    W, H = w * T, h * T
    hi, base, lo = ("P08", "P07", "P05") if stuff == "concrete" else ("P07", "P06", "P04")
    if side == "w":
        d.rectangle([0, 0, 4, H - 1], fill=C(base)); d.line([4, 0, 4, H - 1], fill=C(hi)); d.line([0, 0, 0, H - 1], fill=C(INK))
    else:
        d.rectangle([W - 5, 0, W - 1, H - 1], fill=C(base)); d.line([W - 5, 0, W - 5, H - 1], fill=C(hi)); d.line([W - 1, 0, W - 1, H - 1], fill=C(INK))
    return img


def deck_edge(w, h, seed=0, hazard=True):
    """볼트 데크 윗면 테(첫 풍경과 같은 노랑·검정 경고 띠) — 맨 윗줄에만."""
    img = new(w, h)
    W = w * T
    px = img.load()
    if hazard:
        for x in range(W):
            for y in range(0, 6):
                px[x, y] = C("P49") if ((x + y) // 4) % 2 == 0 else C(INK)
            px[x, 6] = C("P04")
    return img


def vault_portal(w, h, seed=0):
    """볼트 정문 옹벽 윗면(남쪽 끝 — 방폭문은 북쪽을 보므로 3/4 시점에서 문 자체는 보이지 않는다):
    두꺼운 콘크리트 윗면 + 동판('서울 볼트 S-07 관악 / 한결건설 시공') + 옹벽 양끝."""
    img = new(w, h, "P07")
    d = ImageDraw.Draw(img)
    W, H = w * T, h * T
    d.rectangle([0, 0, W - 1, H - 1], fill=C("P07"))
    for x in range(0, W, 32):
        d.line([x, 0, x, H - 1], fill=C("P06"))
    d.line([0, 0, W - 1, 0], fill=C("P09"))
    d.line([0, 1, W - 1, 1], fill=C("P08"))
    d.rectangle([0, H - 7, W - 1, H - 1], fill=C("P06"))
    d.line([0, H - 7, W - 1, H - 7], fill=C("P05"))
    d.line([0, H - 1, W - 1, H - 1], fill=C(INK))
    _, tw, _ = text_px("서울 볼트 S-07 관악", 8, "Galmuri7")
    bx0, bx1 = W // 2 - tw // 2 - 5, W // 2 + tw // 2 + 5                 # 동판(글자 폭에 맞춘다)
    d.rectangle([bx0, 6, bx1, 24], fill=C(INK))
    d.rectangle([bx0 + 1, 7, bx1 - 1, 23], fill=C("P26"))
    d.rectangle([bx0 + 2, 8, bx1 - 2, 22], fill=C("P25"))
    d.line([bx0 + 2, 8, bx1 - 2, 8], fill=C("P27"))
    put_text(img, "서울 볼트 S-07 관악", bx0 + 4, 8, "P23", 8, "Galmuri7")
    _, tw2, _ = text_px("한결건설 시공", 8, "Galmuri7")
    put_text(img, "한결건설 시공", (bx0 + bx1) // 2 - tw2 // 2, 15, "P23", 8, "Galmuri7")
    for (x, y) in ((bx0 + 2, 9), (bx1 - 3, 9), (bx0 + 2, 21), (bx1 - 3, 21)):
        d.point((x, y), fill=C("P27"))
    rnd = random.Random(seed)
    for _ in range(12):                                                   # 동판 녹(청록)
        d.point((rnd.randint(bx0 + 2, bx1 - 2), rnd.randint(9, 22)), fill=C("P36"))
    return img


def slab(w, h, seed=0):
    """콘크리트 윗면(위에서 본 옹벽 머리·볼트 절개면 양옆): 첫 풍경의 옹벽 윗면과 같은 그림."""
    img = new(w, h, "P06")
    d = ImageDraw.Draw(img)
    W, H = w * T, h * T
    d.rectangle([3, 3, W - 4, H - 1], fill=C("P07"))
    d.line([3, 3, W - 4, 3], fill=C("P08"))
    for yy in range(12, H, 18):
        d.line([3, yy, W - 4, yy], fill=C("P05"))
    d.rectangle([0, 0, W - 1, H - 1], outline=C("P02"))
    rnd = random.Random(seed)
    for _ in range(W * H // 300):
        step_px(img, rnd.randrange(4, W - 4), rnd.randrange(4, H), -1)
    return img


def brink(w, h=1, seed=0):
    """북쪽으로 내려가는 비탈 끝(3/4 시점에서 아래로 꺾이는 면은 보이지 않는다): 바위·풀 턱 띠 + 북쪽 끝 어두운 그늘선."""
    rnd = random.Random(hsh(seed, w, 83))
    W, H = w * T, h * T
    img = new(w, h)
    import numpy as np
    for x in range(W):
        top = 6 + int(3 * math.sin(x * 0.21 + seed) + 2 * math.sin(x * 0.07))
        for y in range(top, H):
            k = y - top
            col = "P02" if k < 2 else ("P30" if k < 5 else "P29")
            img.putpixel((x, y), C(col))
    for x in range(2, W - 6, 9):                                          # 턱에 박힌 바위
        if rnd.random() < 0.55:
            rx, ry = rnd.randint(4, 7), rnd.randint(3, 5)
            TI.lump(img, x + rx, H - ry - 3, rx, ry, ["P04", "P05", "P06", "P07"])
    for x in range(0, W, 2):                                              # 풀 끝
        if rnd.random() < 0.5:
            y = rnd.randint(H - 12, H - 3)
            img.putpixel((x, y), C("P31"))
    return TI.outline(img)


# ================================================================================================ 새벽인력 본소(1-6, SD-09a L-R02-19)
# 2077년 구로 공구상가 철골 2층 동을 200년 덧대 쓴 인력사무소. 골함석 외벽·H형강 기둥·1층 공구 가게 셔터·2층 띠창,
# 정면 위 큰 간판. 둘레는 칠이 벗겨진 철판 담 + 가시철사 코일, 정문 옆 번호표 창구.
SHOPS_SB = ["공구", "기계", "볼트", "용접", "철물", "모터", "체인", "배관"]       # 셔터에 칠한 업종(가게마다 한 단어)


def _corrugate(img, box, tones, rnd, pitch=4, rust=0.05):
    """세로 골함석: 골 4px(빛·몸·그늘·먹) + 판 이음(48~80px마다 겹친 자리) + 녹 얼룩."""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    seam = x0 + rnd.randint(30, 60)
    for x in range(x0, x1):
        k = (x - x0) % pitch
        col = tones[2] if k == 0 else tones[1] if k == 1 else tones[0] if k == 2 else tones[1]
        d.line([x, y0, x, y1 - 1], fill=C(col))
        if x == seam:                                                     # 판 이음: 겹친 판 끝의 그늘선 + 리벳
            d.line([x, y0, x, y1 - 1], fill=C(INK))
            for yy in range(y0 + 3, y1 - 2, 9):
                d.point((x + 1, yy), fill=C(tones[2]))
            seam += rnd.randint(48, 80)
    nz = vnoise(x1 - x0, y1 - y0, 12, rnd.randint(0, 9999)) * 0.6 + vnoise(x1 - x0, y1 - y0, 4, rnd.randint(0, 9999)) * 0.4
    thr = 1 - rust * 3
    for y in range(y0, y1):
        for x in range(x0, x1):
            v = nz[y - y0, x - x0]
            if v > thr:                                                   # 녹 얼룩(골을 따라 번진다 — 골 그늘에 짙게)
                img.putpixel((x, y), C(RUST_SB[0 if (x - x0) % pitch == 3 else 1 if v > thr + 0.05 else 2]))
    for _ in range((x1 - x0) // 9):                                       # 녹물 줄
        streak(img, rnd.randrange(x0, x1), y0 + rnd.randint(0, max(1, (y1 - y0) // 3)), rnd.randint(5, 14), -1, rnd)


RUST_SB = ["P24", "P25", "P26"]


def _hbeam(img, x, y0, y1):
    """H형강 기둥(정면 7px): 플랜지 둘 + 웨브 그늘, 녹."""
    d = ImageDraw.Draw(img)
    d.rectangle([x - 1, y0, x + 7, y1], fill=C(INK))
    d.rectangle([x, y0, x + 6, y1], fill=C("P24"))
    d.line([x, y0, x, y1], fill=C("P26"))
    d.line([x + 1, y0, x + 1, y1], fill=C("P25"))
    d.rectangle([x + 2, y0, x + 4, y1], fill=C("P23"))
    d.line([x + 5, y0, x + 5, y1], fill=C("P25"))
    for yy in range(y0 + 5, y1, 11):                                      # 볼트 판
        d.point((x + 1, yy), fill=C("P27")); d.point((x + 5, yy), fill=C("P27"))


def _ribbon(img, x0, x1, y, h, rnd):
    """2층 띠창: 철 창틀 + 철망 유리(격자) · 깨짐 · 합판 덧댐 · 안쪽 어둠."""
    d = ImageDraw.Draw(img)
    d.rectangle([x0 - 1, y - 1, x1 + 1, y + h], fill=C(INK))
    x = x0
    while x < x1:
        pw = min(x1 - x, rnd.randint(14, 20))
        kind = rnd.random()
        if kind < 0.55:                                                   # 철망 유리(뿌연 녹청)
            d.rectangle([x, y, x + pw - 1, y + h - 1], fill=C("P12"))
            d.rectangle([x, y, x + pw - 1, y + 2], fill=C("P13"))
            for xx in range(x + 2, x + pw, 3):
                for yy in range(y + 1, y + h, 3):
                    d.point((xx, yy), fill=C("P11"))
        elif kind < 0.78:                                                 # 깨져 안이 보인다
            d.rectangle([x, y, x + pw - 1, y + h - 1], fill=C("P02"))
            d.polygon([(x, y), (x + pw // 2, y), (x + 2, y + h // 2)], fill=C("P12"))
        else:                                                             # 합판 덧댐
            d.rectangle([x, y, x + pw - 1, y + h - 1], fill=C("P19"))
            d.line([x, y, x + pw - 1, y], fill=C("P20"))
            d.line([x + pw // 2, y, x + pw // 2, y + h - 1], fill=C("P18"))
            d.point((x + 2, y + 2), fill=C("P04")); d.point((x + pw - 3, y + h - 3), fill=C("P04"))
        d.line([x + pw - 1, y, x + pw - 1, y + h - 1], fill=C("P05"))       # 창살 기둥
        x += pw
    d.line([x0 - 2, y + h + 1, x1 + 2, y + h + 1], fill=C("P06"))           # 창턱(철)
    d.line([x0 - 2, y + h + 2, x1 + 2, y + h + 2], fill=C(INK))


def _tool_shutter(img, x, y, w, h, label, rnd, up=0):
    """1층 공구 가게 셔터: 가로 골 + 칠 바랜 상호(2077년 그대로) + 자물쇠 고리. up>0이면 그만큼 올라가 안이 어둡다."""
    d = ImageDraw.Draw(img)
    d.rectangle([x - 1, y - 4, x + w, y + h], fill=C(INK))
    d.rectangle([x, y - 3, x + w - 1, y], fill=C("P05"))                  # 셔터 통
    d.line([x, y - 3, x + w - 1, y - 3], fill=C("P07"))
    d.rectangle([x, y + 1, x + w - 1, y + h - 1], fill=C("P06"))
    for yy in range(y + 2, y + h, 2):
        d.line([x, yy, x + w - 1, yy], fill=C("P05" if (yy // 2) % 2 else "P07"))
    if up:
        d.rectangle([x, y + h - up, x + w - 1, y + h - 1], fill=C("P01"))
        d.line([x, y + h - up - 1, x + w - 1, y + h - up - 1], fill=C("P08"))
    else:
        d.rectangle([x + w // 2 - 2, y + h - 4, x + w // 2 + 1, y + h - 2], fill=C("P04"))
    if label:                                                             # 칠 바랜 상호(셔터에 페인트)
        pts, tw, th = text_px(label, 8, "Galmuri7")
        lx = x + max(1, (w - tw) // 2)
        for (a, b) in pts:
            if rnd.random() < 0.88 and lx + a < x + w - 1:
                img.putpixel((lx + a, y + 4 + b), C(rnd.choice(["P44", "P45", "P44"])))
    for _ in range(w // 6):
        streak(img, rnd.randrange(x, x + w), y + 1, rnd.randint(3, 9), -1, rnd)


def big_sign(img, x0, x1, y, text, rnd, sub=None):
    """정면 위 큰 간판: 흰 철판 + 붉은 글(16px) + 녹 번짐 + 받침 쇠. sub = 아래 작은 글."""
    d = ImageDraw.Draw(img)
    hgt = 22 if sub else 18
    d.rectangle([x0 - 1, y - 1, x1 + 1, y + hgt], fill=C(INK))
    d.rectangle([x0, y, x1, y + hgt - 1], fill=C("P09"))
    d.line([x0, y, x1, y], fill=C("P08"))
    d.rectangle([x0, y + hgt - 3, x1, y + hgt - 1], fill=C("P08"))
    pts, tw, th = text_px(text, 12, "Galmuri11-Bold")
    tx = (x0 + x1 - tw) // 2
    for (a, b) in pts:                                                    # 붉은 칠 글자(군데군데 벗겨짐) + 아래 그늘
        if (a, b + 1) not in pts and x0 <= tx + a <= x1 and y + 3 + b < y + hgt - 3:
            img.putpixel((tx + a, y + 3 + b), C("P07"))
        if rnd.random() < 0.94 and x0 <= tx + a <= x1:
            img.putpixel((tx + a, y + 2 + b), C("P53"))
    if sub:
        put_text(img, sub, (x0 + x1) // 2 - text_px(sub)[1] // 2, y + hgt - 10, "P04", 8, "Galmuri7")
    for _ in range((x1 - x0) // 8):                                       # 녹 번짐(볼트 구멍에서 흘러내림)
        sx = rnd.randint(x0 + 1, x1 - 1)
        streak(img, sx, y + rnd.randint(1, hgt - 2), rnd.randint(3, 8), -2, rnd)
    for sx in (x0 + 6, x1 - 8):                                           # 받침 쇠
        d.rectangle([sx, y + hgt, sx + 2, y + hgt + 4], fill=C("P04"))
        d.line([sx + 2, y + hgt, sx + 2, y + hgt + 4], fill=C(INK))


def steel_shed(w, h, seed=0, doors=(), shutters=None, sign=None, sub=None, beams=4):
    """철골 2층 공구상가 정면 w×h(h=2: 2층 띠창 + 1층 셔터). doors = [(열, 종류)] (steel·open·shutter),
    shutters = 셔터 둘 열 목록(None이면 문 아닌 1층 칸에 하나 걸러), sign = 2층 위 큰 간판 글, beams = 기둥 간격(칸)."""
    rnd = random.Random(hsh(seed, w, h, 97))
    img = new(w, h)
    W, H = w * T, h * T
    tones = rnd.choice([("P12", "P13", "P14"), ("P05", "P06", "P07"), ("P12", "P13", "P14")])
    _corrugate(img, (0, 0, W, H), tones, rnd, rust=0.06)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, 4], fill=C("P05"))                          # 처마 철판(골 위 덮개)
    d.line([0, 0, W - 1, 0], fill=C("P07"))
    d.line([0, 5, W - 1, 5], fill=C(INK))
    yb = (h - 1) * T
    d.rectangle([0, yb - 3, W - 1, yb], fill=C("P05"))                    # 층 띠(철골 보)
    d.line([0, yb - 3, W - 1, yb - 3], fill=C("P07"))
    d.line([0, yb + 1, W - 1, yb + 1], fill=C(INK))
    for f in range(h - 1):                                                # 위층: 띠창(간판 자리는 비움)
        y = f * T + (16 if (sign and f == 0) else 9)
        _ribbon(img, 6, W - 7, y, 10 if (sign and f == 0) else 12, rnd)
    door_cols = {c: k for c, k in doors}
    if shutters is None:
        shutters = [c for c in range(w) if c not in door_cols and c % 2 == 0]
    for i, c in enumerate(shutters):
        if c in door_cols:
            continue
        lab = SHOPS_SB[(seed + i) % len(SHOPS_SB)] if rnd.random() < 0.55 else None
        _tool_shutter(img, c * T + 3, yb + 9, 26, 22, lab, rnd, up=8 if rnd.random() < 0.15 else 0)
    for c, k in doors:
        door(img, c * T + 7, yb + 6, 18, 25, k, rnd)
    for c in range(0, w + 1, beams):                                      # H형강 기둥(문 칸은 피한다)
        x = min(W - 8, max(0, c * T - 4))
        if any(abs(x - (dc * T + 7)) < 22 for dc in door_cols):
            continue
        _hbeam(img, x, 6, H - 2)
    if sign:
        big_sign(img, max(8, W // 2 - len(sign) * 7 - 10), min(W - 9, W // 2 + len(sign) * 7 + 10), 3, sign, rnd, sub)
    for x in range(W):                                                    # 아래 때 띠·물튐
        for k in range(3):
            if (x * 5 + k) % 4 != 0 or k == 0:
                step_px(img, x, H - 1 - k, -1)
    for y in range(6, H):
        step_px(img, 1, y, 1)
        step_px(img, W - 2, y, -1)
    d.line([0, 0, 0, H - 1], fill=C(INK))
    d.line([W - 1, 0, W - 1, H - 1], fill=C(INK))
    d.line([0, H - 1, W - 1, H - 1], fill=C(INK))
    return img


def tin_roof(w, h, seed=0, edges="nsew", skylights=True, patches=True):
    """골함석 지붕(위에서 본 면): 남북으로 흐르는 골 · 채광판(바랜 녹색 반투명 판) · 녹 · 덧댄 합판 · 용마루 · 가장자리 물받이."""
    rnd = random.Random(hsh(seed, w, h, 101))
    W, H = w * T, h * T
    img = new(w, h)
    _corrugate(img, (0, 0, W, H), ("P05", "P06", "P07"), rnd, pitch=4, rust=0.06)
    d = ImageDraw.Draw(img)
    if skylights:                                                         # 채광판: 골 폭 맞춰 짧은 판(바랜 연두 · 금), 두 줄
        rows = [(8, min(H - 8, 8 + T + 8))] + ([(H - T - 16, H - 8)] if h >= 4 else [])
        for c in range(1, w - 1, 3):
            for (y0, y1) in rows:
                x = c * T + 8 + (hsh(seed, c, y0) % 3) * 4
                d.rectangle([x - 1, y0 - 1, x + 12, y1 + 1], fill=C(INK))
                for xx in range(x, x + 12):
                    d.line([xx, y0, xx, y1], fill=C("P32" if (xx - x) % 4 == 0 else "P31"))
                for _ in range(2):
                    cx, cy = rnd.randint(x, x + 11), rnd.randint(y0, y1)
                    for i in range(rnd.randint(4, 9)):
                        if y0 <= cy + i <= y1:
                            img.putpixel((min(x + 11, cx + (i % 2)), cy + i), C("P29"))
    if patches:                                                           # 덧댄 합판·철판 조각
        for _ in range(max(1, w * h // 6)):
            px, py = rnd.randrange(4, W - 20), rnd.randrange(4, H - 14)
            pw, ph = rnd.randint(10, 18), rnd.randint(8, 12)
            col = rnd.choice(["P19", "P20", "P13"])
            d.rectangle([px - 1, py - 1, px + pw, py + ph], fill=C(INK))
            d.rectangle([px, py, px + pw - 1, py + ph - 1], fill=C(col))
            d.line([px, py, px + pw - 1, py], fill=C(P_up(col)))
            for (qx, qy) in ((px + 1, py + 1), (px + pw - 2, py + 1), (px + 1, py + ph - 2), (px + pw - 2, py + ph - 2)):
                d.point((qx, qy), fill=C("P04"))
    if h >= 3:                                                            # 용마루(동서)
        ym = H // 2
        d.rectangle([0, ym - 2, W - 1, ym + 2], fill=C("P06"))
        d.line([0, ym - 2, W - 1, ym - 2], fill=C("P08"))
        d.line([0, ym + 3, W - 1, ym + 3], fill=C(INK))
    for side in edges:                                                    # 물받이(먹선 + 녹 띠)
        if side == "n":
            d.rectangle([0, 0, W - 1, 2], fill=C("P24")); d.line([0, 0, W - 1, 0], fill=C(INK))
        elif side == "s":
            d.rectangle([0, H - 3, W - 1, H - 1], fill=C("P24")); d.line([0, H - 1, W - 1, H - 1], fill=C(INK))
        elif side == "w":
            d.rectangle([0, 0, 2, H - 1], fill=C("P05")); d.line([0, 0, 0, H - 1], fill=C(INK))
        elif side == "e":
            d.rectangle([W - 3, 0, W - 1, H - 1], fill=C("P04")); d.line([W - 1, 0, W - 1, H - 1], fill=C(INK))
    return img


def _razor(img, x0, x1, y):
    """가시철사 코일(정면): 겹친 고리 + 반짝 날."""
    d = ImageDraw.Draw(img)
    for x in range(x0, x1, 5):
        d.arc([x, y, x + 7, y + 6], 180, 360, fill=C("P05"))
        d.arc([x, y + 1, x + 7, y + 7], 0, 180, fill=C("P04"))
        d.point((x + 3, y), fill=C("P08"))


def steel_fence(w, h=2, seed=0, gate=None, booth=None, sign=None, stencil=None):
    """철판 담 정면 w×h: 칠한 철판(녹청) + 리벳 + 녹 + 위 가시철사 코일. gate=(열0, 열1) 비움(문짝은 소품),
    booth=열: 번호표 창구(작은 미닫이 + '번호표' 글 + 번호판), sign=(열0, 열1, 글): 담 위 간판, stencil=(열, 글): 흰 스텐실."""
    rnd = random.Random(hsh(seed, w, h, 113))
    W, H = w * T, h * T
    img = new(w, h)
    d = ImageDraw.Draw(img)
    skip = set(range(gate[0] * T, (gate[1] + 1) * T)) if gate else set()
    top = 9
    x = 0
    while x < W:
        pw = rnd.randint(28, 44)
        x1 = min(W, x + pw)
        cols = [c for c in range(x, x1) if c not in skip]
        if cols:
            a, b = cols[0], cols[-1]
            tone = rnd.choice([("P11", "P12", "P13"), ("P34", "P35", "P36"), ("P11", "P12", "P13")])
            d.rectangle([a, top, b, H - 2], fill=C(tone[1]))
            d.line([a, top, b, top], fill=C(tone[2]))
            d.line([a, top + 1, a, H - 2], fill=C(tone[2]))
            d.line([b, top, b, H - 2], fill=C(INK))
            for yy in range(top + 4, H - 4, 10):                          # 리벳
                d.point((a + 2, yy), fill=C(tone[0])); d.point((b - 2, yy), fill=C(tone[0]))
            d.line([a + 1, H // 2 + 4, b - 1, H // 2 + 4], fill=C(tone[0]))  # 가로 보강띠 그늘
            nz = vnoise(b - a + 1, H - top, 9, rnd.randint(0, 9999))
            for yy in range(top + 1, H - 2):
                for xx in range(a + 1, b):
                    v = nz[yy - top, xx - a]
                    if v > 0.8:
                        img.putpixel((xx, yy), C(RUST_SB[2 if v < 0.85 else 1 if v < 0.9 else 0]))
                    elif v < 0.1:
                        img.putpixel((xx, yy), C(tone[0]))
            for _ in range((b - a) // 7):
                streak(img, rnd.randint(a + 1, b - 1), top + rnd.randint(1, 8), rnd.randint(6, 20), -1, rnd)
        x = x1
    segs, cur = [], None
    for xx in range(W):
        if xx in skip:
            if cur is not None:
                segs.append((cur, xx - 1)); cur = None
        elif cur is None:
            cur = xx
    if cur is not None:
        segs.append((cur, W - 1))
    for (a, b) in segs:
        for px_ in range(a, b, 40):                                       # 기둥(각관) + 코일 받침
            d.rectangle([px_, 2, px_ + 3, H - 1], fill=C("P05"))
            d.line([px_, 2, px_, H - 1], fill=C("P07"))
            d.line([px_ + 3, 2, px_ + 3, H - 1], fill=C(INK))
        _razor(img, a, b - 6, 1)
        for xx in range(a, b + 1):
            img.putpixel((xx, H - 1), C(INK))
    if gate:                                                              # 문 기둥(굵은 H형강)
        for gx in (gate[0] * T - 6, (gate[1] + 1) * T - 2):
            _hbeam(img, max(0, min(W - 8, gx)), 0, H - 1)
    if booth is not None:                                                 # 번호표 창구
        bx = booth * T + 4
        d.rectangle([bx - 1, top + 6, bx + 24, top + 30], fill=C(INK))
        d.rectangle([bx, top + 7, bx + 23, top + 29], fill=C("P07"))
        d.rectangle([bx + 3, top + 14, bx + 20, top + 25], fill=C("P02"))  # 작은 미닫이(안은 어둡다)
        d.line([bx + 11, top + 14, bx + 11, top + 25], fill=C("P06"))
        d.rectangle([bx + 2, top + 26, bx + 21, top + 28], fill=C("P05"))  # 받침
        put_text(img, "번호표", bx + 3, top + 7, "P53", 8, "Galmuri7")
        d.rectangle([bx + 25, top + 10, bx + 31, top + 20], fill=C(INK))   # 번호판(붉은 숫자)
        put_text(img, "7", bx + 26, top + 11, "P54", 8, "Galmuri7")
    if stencil:
        c, s = stencil
        pts, tw, _ = text_px(s, 8, "Galmuri7")
        sx = c * T + 4
        for (a, b) in pts:
            if rnd.random() < 0.85 and sx + a < W:
                img.putpixel((sx + a, top + 14 + b), C("P08"))
    if sign:
        c0, c1, s = sign
        big_sign(img, c0 * T + 2, (c1 + 1) * T - 3, 0, s, rnd)
    return img


def fence_top(w, h, seed=0, axis="v"):
    """철판 담(위에서 본 세로 줄): 칸 가운데 6px 철판 머리 + 각관 기둥 + 가시철사 코일 — 양옆은 비어 바닥이 보인다."""
    rnd = random.Random(hsh(seed, w, h, 127))
    W, H = w * T, h * T
    img = new(w, h)
    d = ImageDraw.Draw(img)
    if axis == "v":
        x = W // 2 - 3
        d.rectangle([x - 1, 0, x + 6, H - 1], fill=C(INK))
        d.rectangle([x, 0, x + 5, H - 1], fill=C("P12"))
        d.line([x, 0, x, H - 1], fill=C("P13"))
        d.line([x + 5, 0, x + 5, H - 1], fill=C("P11"))
        for y in range(0, H, 2):
            if rnd.random() < 0.18:
                d.line([x + 1, y, x + 4, y], fill=C(rnd.choice(RUST_SB)))
        for y in range(4, H, 40):                                         # 기둥 머리
            d.rectangle([x - 2, y, x + 7, y + 5], fill=C("P05"))
            d.rectangle([x - 2, y, x + 7, y + 5], outline=C(INK))
        for y in range(0, H, 5):                                          # 코일(위에서: 지그재그 고리)
            d.arc([x - 3, y, x + 8, y + 6], 0, 360, fill=C("P06") if (y // 5) % 2 else C("P04"))
        for y in range(0, H):                                             # 동쪽 그늘(빛은 왼쪽 위)
            if 0 <= x + 7 < W:
                img.putpixel((x + 7, y), C("P02")) if img.getpixel((x + 7, y))[3] == 0 else None
    return img


KINDS = {
    "steel_shed": steel_shed, "tin_roof": tin_roof, "steel_fence": steel_fence, "fence_top": fence_top,
    "slab": slab, "brink": brink,
    "facade": facade, "roof": roof, "wall": retaining_wall, "rock": rock_face, "cave": cave_mouth, "scrap": scrap_wall, "gap": gap,
    "bridge": bridge, "ledge": ledge, "deck_edge": deck_edge, "portal": vault_portal,
}


def draw(kind, w, h, seed=0, **kw):
    if kind == "ladder":
        return ladder(h, seed)
    return KINDS[kind](w, h, seed=seed, **kw)


if __name__ == "__main__":
    from grid import upscale, check
    out = Image.new("RGBA", (16 * T, 15 * T), C("P19"))
    out.alpha_composite(roof(5, 3, 1, "new"), (0, 0))
    out.alpha_composite(facade(5, 4, "brick", 1, doors=[(1, "steel")], name="봉천 그린빌라", num="3"), (0, 3 * T))
    out.alpha_composite(roof(4, 2, 2, "nwe", paint="grey"), (6 * T, 0))
    out.alpha_composite(facade(4, 3, "plaster", 2, shop=(1, 3, "봉천약국"), doors=[(0, "steel")]), (6 * T, 2 * T))
    out.alpha_composite(retaining_wall(6, 2, 3, posters=[(20, 22, 0), (120, 20, 1)], paint=[(70, 30, "312계단", "P53")]), (0, 8 * T))
    out.alpha_composite(rock_face(5, 2, 4), (6 * T, 6 * T))
    out.alpha_composite(scrap_wall(8, 2, 5, gate=(3, 4), banner=(5, 7, "새봄 분양")), (0, 11 * T))
    out.alpha_composite(facade(3, 2, "tile", 3, doors=[(2, "open")]), (11 * T, 0))
    out.alpha_composite(facade(3, 2, "concrete", 4, doors=[(0, "shutter")]), (11 * T, 2 * T))
    out.alpha_composite(bridge(3, 1, 6), (11 * T, 5 * T))
    out.alpha_composite(ladder(2), (15 * T, 3 * T))
    out.alpha_composite(vault_portal(8, 1, 7), (8 * T, 13 * T))
    out.alpha_composite(retaining_wall(5, 1, 8), (8 * T, 9 * T))
    out.alpha_composite(rock_face(3, 3, 9), (13 * T, 9 * T))
    bad = check(out, P.allowed_set())
    os.makedirs(os.path.join(ROOT, "out"), exist_ok=True)
    upscale(out, 2).save(os.path.join(ROOT, "out", "struct_r01_test_x2.png"))
    print("off-palette:", bad[:5] if bad else 0)
