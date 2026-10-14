"""첫 풍경 컷신(MQ-P4 S7, SD-03a §7.4, 단계 0-9 다시 그림): 볼트 S-07 방폭문을 나선 자리에서 북쪽(서울)을 본다.
게임 그래픽 콘셉트(아이작풍 먹선 소품 + 쯔꾸르식 위에서 본 타일)에 맞춘다. 사람은 그리지 않는다 — 게임이 실제 페이퍼돌(주인공)을 세운다.
  far  640×280: 키아트의 먼 풍경(하늘·북한산·강북·남산·여의도·한강·강남·아파트 숲)만(keyart.FAR_ONLY).
  near 640×250: 위에서 본 관악산 북쪽 능선 — R01 흙·풀 지면(게임과 같은 텍스처), 능선 끝 바위 테두리(위쪽은 비어 먼 풍경이 보인다),
                가운데 흙길, 아래쪽 볼트 바깥 콘크리트 턱(노란·검은 경고 띠, 양옆 옹벽 윗면)과 계단, 먹선 두른 화강암·관목·마른 풀.
  합치면 높이 540(near는 y 290부터). 화면 360 — 컷신은 아래(주인공)에서 위(서울)로 180px 올라간다.
  far 아랫단(262~300)에는 관악산 아래 비탈 숲을 겹겹이 그려, 능선 너머로 산이 내려가는 깊이를 준다.
python3 tools/first_view.py   → samples/30_first_view(_x2).png(견본), tools/pipeline/ui_export.py가 game/assets/ui/first_view_*.png로 낸다."""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import tiles_isaac as TI
import ground as G

ROOT = os.path.dirname(os.path.dirname(__file__))
W, NH, FAR_H, NEAR_Y = 640, 250, 330, 290
C = lambda t: P.rgb(t) + (255,)


def far():
    import keyart as K
    K.FAR_ONLY = True
    img = K.build()
    cv = K.Canvas()
    cv.img = img
    cv.px = img.load()
    for y in range(266, K.H):                                                # 숲 바닥(멀리서 본 비탈의 그늘)
        for x in range(W):
            cv.put(x, y, "P28" if (x + y) % 2 or y > 284 else "P29")
    K.tree_clump(cv, 0, W, 268, 71, K.PINE, size=(2, 4), density=0.95, jitter=2)
    K.tree_clump(cv, 0, W, 276, 72, K.MAPLE, size=(2, 4), density=0.18, jitter=3)
    K.tree_clump(cv, 0, W, 284, 73, K.PINE, size=(3, 6), density=0.9, jitter=3)
    K.tree_clump(cv, 0, W, 294, 74, K.OAK, size=(4, 7), density=0.75, jitter=3)
    K.tree_clump(cv, 0, W, 302, 75, K.PINE, size=(5, 8), density=0.85, jitter=3)
    K.tree_clump(cv, 0, W, 314, 76, K.OAK, size=(5, 9), density=0.8, jitter=3)
    K.tree_clump(cv, 0, W, 326, 77, K.PINE, size=(6, 9), density=0.9, jitter=3)
    return img.crop((0, 0, W, FAR_H))


def _mat(name):
    gs = G.load("r01")
    m = gs.names.index(name)
    a = gs.atlas[m * G.CELL:(m + 1) * G.CELL, 0:G.CELL]
    reps = (math.ceil(NH / G.CELL) + 1, math.ceil(W / G.CELL) + 1)
    return np.tile(a, reps)[:NH, :W]


def _noise(seed, scale):
    rnd = np.random.default_rng(seed)
    gw, gh = W // scale + 3, NH // scale + 3
    g = rnd.random((gh, gw))
    ys, xs = np.mgrid[0:NH, 0:W] / scale
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def rim_y(x):
    """능선 끝(위쪽 경계) 높이: 가운데가 조금 낮고(길이 넘어가는 자리) 바위가 튀어나온다."""
    return int(12 + 6 * math.sin(x / 41.0) + 4 * math.sin(x / 13.0 + 1.3) - 5 * math.exp(-((x - 330) / 60.0) ** 2))


def path_x(y):
    """흙길 가운데(아래 계단 → 위 능선 고개)."""
    return 320 + 22 * math.sin(y / 46.0) + (y - NH) * 0.05


def near():
    gs = G.load("r01")
    dirt, sparse, dense = _mat("dirt"), _mat("grass_sparse"), _mat("grass_dense")
    n1, n2 = _noise(11, 40), _noise(12, 9)
    v = n1 * 0.75 + n2 * 0.25
    idx = np.where(v > 0.26, 2, np.where(v > 0.12, 1, 0))                    # 풀 짙음 · 듬성 · 흙(가을 산비탈이라 풀이 많다)
    ys, xs = np.mgrid[0:NH, 0:W]
    px = np.vectorize(path_x)(ys)
    dpath = np.abs(xs - px)
    idx = np.where(dpath < 16 + 4 * n2, 0, np.where(dpath < 28 + 8 * n2, np.minimum(idx, 1), idx))   # 흙길과 길섶
    dith = ((xs + ys) % 2 == 0) & ((np.abs(v - 0.12) < 0.02) | (np.abs(v - 0.26) < 0.02))                  # 경계 디더(게임 지면과 같은 체커)
    idx = np.where(dith, np.maximum(idx - 1, 0), idx)
    a = np.where(idx == 2, dense, np.where(idx == 1, sparse, dirt))
    rgba = np.zeros((NH, W, 4), np.uint8)
    rgba[..., :3] = G.PAL[a]
    rgba[..., 3] = 255
    img = Image.fromarray(rgba, "RGBA")
    d = ImageDraw.Draw(img)
    px_ = img.load()
    # 볼트 바깥 콘크리트 턱(아래 가운데 8칸 × 3줄) + 양옆 옹벽 윗면 + 북쪽 끝 경고 띠 + 계단 2칸
    ax0, ax1, ay0 = 192, 448, NH - 70
    crnd = random.Random(3)
    for y in range(ay0, NH):                                                 # 부은 콘크리트 슬래브(이음매 32px · 얼룩 · 금)
        for x in range(ax0, ax1):
            t = "P06"
            if (x - ax0) % 64 == 0 or (y - ay0) % 32 == 0:
                t = "P05"
            elif (x - ax0) % 64 == 1 or (y - ay0) % 32 == 1:
                t = "P07"
            elif _noise_v(x, y) > 0.72 and (x + y) % 2 == 0:
                t = "P05"
            px_[x, y] = C(t)
    for _ in range(5):
        cx, cy = crnd.randint(ax0 + 8, ax1 - 8), crnd.randint(ay0 + 10, NH - 4)
        for k in range(crnd.randint(5, 12)):
            px_[cx, cy] = C("P04")
            cx += crnd.choice((-1, 0, 1)); cy += crnd.choice((0, 1))
            if not (ax0 <= cx < ax1 and ay0 < cy < NH):
                break
    for x in range(ax0, ax1):                                                # 경고 띠(노랑·검정 사선) — 방폭문 앞 문턱 표시
        for y in range(ay0, ay0 + 6):
            px_[x, y] = C("P49") if ((x + y) // 4) % 2 == 0 else C("P01")
        px_[x, ay0 - 1] = C("P02")
        px_[x, ay0 + 6] = C("P04")
    for side in (ax0 - 32, ax1):                                             # 옹벽 윗면(위에서 본 콘크리트 띠, 먹선)
        d.rectangle([side, ay0 - 26, side + 31, NH - 1], fill=C("P06"))
        d.rectangle([side + 3, ay0 - 23, side + 28, NH - 1], fill=C("P07"))
        d.line([side + 3, ay0 - 23, side + 28, ay0 - 23], fill=C("P08"))
        for yy in range(ay0 - 14, NH, 18):
            d.line([side + 3, yy, side + 28, yy], fill=C("P05"))
        d.rectangle([side, ay0 - 26, side + 31, NH - 1], outline=C("P02"))
    st = TI.stairs()
    for k in range(2):                                                       # 계단: 턱에서 흙길로
        for j in range(2):
            img.alpha_composite(st, (288 + j * 32, ay0 - 64 + k * 32))
    for y in range(ay0 - 64, ay0):
        px_[287, y] = C("P02"); px_[352, y] = C("P02")
    # 능선 끝: 위쪽을 비우고, 가장자리에 밝은 흙 턱 + 먹선, 바로 아래 그늘
    for x in range(W):
        r = rim_y(x)
        for y in range(0, r):
            px_[x, y] = (0, 0, 0, 0)
        px_[x, r] = C("P02")
        px_[x, r + 1] = C("R01.a") if x % 3 else C("P21")
        px_[x, r + 2] = C("P20")
        if (x // 2) % 2 == 0:
            px_[x, r + 3] = C("P19")
    rnd = random.Random(7)
    props = []
    # 능선 끝 바위: 큰 바위 무리 둘(왼쪽·오른쪽 어깨) + 작은 돌 몇, 가운데 고개는 비운다
    for x, rx, ry in ((70, 26, 15), (104, 14, 9), (40, 12, 8), (512, 30, 17), (548, 13, 9), (476, 11, 7), (600, 16, 10)):
        props.append((rim_y(x) + ry + 8, "boulder", x, (rx, ry, rnd.randint(0, 99))))
    for x, y, rx, ry in ((150, 120, 18, 11), (166, 128, 8, 6), (505, 150, 22, 13), (480, 158, 9, 6), (88, 196, 12, 8),
                         (576, 206, 10, 7), (250, 214, 7, 5), (410, 226, 8, 5)):    # 비탈 바위(크기·무리 섞어)
        props.append((y + ry, "boulder", x, (rx, ry, rnd.randint(0, 99))))
    for x, y, col in ((205, 60, "a"), (436, 52, "g"), (270, 118, "g"), (388, 104, "a"), (140, 178, "g"), (500, 196, "a"),
                      (128, 240, "g"), (522, 244, "g")):                     # 관목(초록·가을 단풍)
        props.append((y + 10, "bush", x, (col, rnd.randint(0, 99))))
    for x, y, r, col in ((-6, 128, 46, "g"), (650, 116, 50, "g"), (26, 262, 40, "a"), (622, 268, 42, "g"),
                         (238, 30, 22, "a"), (402, 24, 20, "g")):            # 나무(위에서 본 수관, 가장자리는 화면 밖으로)
        props.append((y, "tree", x, (r, col, rnd.randint(0, 99))))
    props.sort(key=lambda p: p[0])
    for base, kind, x, s in props:
        if kind == "boulder":
            b = _boulder(*s)
            _shadow(img, x, base, s[0])
            img.alpha_composite(b, (x - b.width // 2, base - b.height + 2))
        elif kind == "bush":
            b = _bush(*s)
            _shadow(img, x, base, b.width // 2 - 2)
            img.alpha_composite(b, (x - b.width // 2, base - b.height + 2))
        else:
            t = _tree(*s)
            _shadow(img, x + 6, base, int(s[0] * 0.8))
            img.alpha_composite(t, (x - t.width // 2, base - t.height + 6))
    a2 = np.array(img)                                                       # 마른 풀 포기(길섶·바위 둘레)
    for _ in range(140):
        x, y = rnd.randint(4, W - 5), rnd.randint(20, NH - 6)
        if a2[y, x, 3] == 0 or (ax0 - 32 <= x < ax1 + 32 and y > ay0 - 28) or abs(x - path_x(y)) < 16:
            continue
        _tuft(img, rnd, x, y)
    return img


def _tuft(img, rnd, x, y):
    px = img.load()
    cols = ["P29", "P30", "P31", "P21", "P20"]
    for k in range(rnd.randint(3, 5)):
        dx = k - 2
        h = rnd.randint(2, 5)
        col = cols[rnd.randrange(len(cols))]
        for t in range(h):
            xx, yy = x + dx + (t // 3) * (1 if dx > 0 else -1 if dx < 0 else 0), y - t
            if 0 <= xx < W and 0 <= yy < NH and px[xx, yy][3]:
                px[xx, yy] = C(col)


def _shadow(img, x, base, rx):
    """발밑 그림자: 바닥을 한 단 어둡게(디더 타원), 반투명 없이."""
    px = img.load()
    dark = {P.rgb(t): n for t, n in (("P19", "P18"), ("P20", "P19"), ("P21", "P20"), ("P18", "P17"), ("P17", "P16"),
                                     ("P29", "P28"), ("P30", "P29"), ("P31", "P30"), ("P32", "P31"), ("P22", "P21"),
                                     ("P05", "P04"), ("P06", "P05"), ("P07", "P06"))}
    for yy in range(base - 3, base + 3):
        for xx in range(x - rx, x + rx + 1):
            if 0 <= xx < W and 0 <= yy < NH and ((xx - x) / rx) ** 2 + ((yy - base) / 3.2) ** 2 <= 1.0:
                c = px[xx, yy]
                if c[3] and c[:3] in dark and ((xx + yy) % 2 == 0 or abs(yy - base) < 2):
                    px[xx, yy] = C(dark[c[:3]])


def _bush(col, seed):
    """관목(아이작풍): 둥근 덩이 셋 + 밝은 쪽(왼쪽 위) + 먹선. g 초록 · a 가을(단풍)."""
    ramp = ["P28", "P29", "P30", "P31"] if col == "g" else ["P24", "P25", "P26", "P27"]
    w, h = 30, 24
    img = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    rnd = random.Random(seed)
    for cx, cy, rx, ry in ((10, 15, 9, 8), (21, 14, 9, 8), (15, 9, 9, 7)):
        TI.lump(img, cx + 1 + rnd.uniform(-1, 1), cy + 1, rx, ry, ramp)
    return TI.outline(img)


def _noise_v(x, y):
    return ((x * 73856093) ^ (y * 19349663)) % 997 / 997.0


def _boulder(rx, ry, seed):
    """화강암 바위(아이작풍): 덩이 둘셋 + 금 + 먹선. 크기는 rx·ry."""
    w, h = int(rx * 2 + 6), int(ry * 2 + 8)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rnd = random.Random(seed)
    ramp = ["P04", "P05", "P06", "P07"]
    TI.lump(img, w / 2, h / 2 + 1, rx, ry, ramp)
    for _ in range(2 if rx > 12 else 1):
        TI.lump(img, w / 2 + rnd.uniform(-rx * 0.4, rx * 0.4), h / 2 - rnd.uniform(0, ry * 0.4), rx * rnd.uniform(0.4, 0.6),
                ry * rnd.uniform(0.4, 0.6), ramp)
    d = ImageDraw.Draw(img)
    cx = int(w / 2 + rnd.uniform(-rx * 0.3, rx * 0.3))
    d.line([cx, h / 2 - ry * 0.5, cx + 2, h / 2, cx + 1, h / 2 + ry * 0.4], fill=C("P03"))
    d.point((int(w / 2 - rx * 0.5), int(h / 2 - ry * 0.45)), fill=C("P08"))
    return TI.outline(img)


def _tree(r, col, seed):
    """나무(위에서 본 수관): 큰 덩이 여럿 + 밝은 왼쪽 위 + 먹선. g 소나무·참나무 초록 · a 단풍."""
    ramp = ["P28", "P29", "P30", "P31"] if col == "g" else ["P23", "P24", "P25", "P26"]
    w = h = int(r * 2 + 8)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rnd = random.Random(seed)
    TI.lump(img, w / 2, h / 2, r * 0.8, r * 0.75, ramp)
    for k in range(6):
        a = k * math.pi / 3 + rnd.uniform(-0.3, 0.3)
        TI.lump(img, w / 2 + math.cos(a) * r * 0.45, h / 2 + math.sin(a) * r * 0.4, r * 0.48, r * 0.42, ramp)
    TI.lump(img, w / 2 - r * 0.2, h / 2 - r * 0.25, r * 0.4, r * 0.35, ramp[1:] + [ramp[-1]])
    return TI.outline(img)


def build():
    f = far()
    n = near()
    out = Image.new("RGBA", (W, NEAR_Y + NH), C("P14"))
    out.alpha_composite(f, (0, 0))
    out.alpha_composite(n, (0, NEAR_Y))
    return f, n, out


if __name__ == "__main__":
    from grid import check, upscale
    f, n, out = build()
    bad = check(out, P.allowed_set(*P.REGION.keys()))
    out.convert("RGB").save(os.path.join(ROOT, "samples", "30_first_view.png"))
    upscale(out, 2).convert("RGB").save(os.path.join(ROOT, "samples", "30_first_view_x2.png"))
    print("off-palette:", bad if bad else 0, out.size)
