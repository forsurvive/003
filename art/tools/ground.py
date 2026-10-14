"""바닥 합성 v2 — 쯔꾸르풍 (SD-16 §6.10): 타일 한 장씩 찍지 않고, 재질 텍스처를 월드 좌표로 깔고 재질 경계를 오토타일처럼 그린다.

왜: 32px 타일 한 장을 되풀이하면 같은 무늬가 타일마다 보이고(반복), 재질이 바뀌는 곳이 타일 선에서 직선으로 끊긴다(단절).
그림은 쯔꾸르(RPG 만들기) 타일 문법: 평평한 바탕 한 색 + 간격을 둔 또렷한 작은 무늬, 픽셀 잡음·디더 없음.
어떻게(실행 중 셰이더 game/systems/world/ground.gdshader와 픽셀 단위로 같은 정수 계산):
  ① 재질마다 256×256 이음매 없는 텍스처(유기 재질은 같은 바탕 2벌 A·B)와 한·두 단계 어두운 벌. 월드 픽셀 좌표로 읽는다.
     A·B는 아주 큰 얼룩(B 채널)으로 고르고 B는 어긋난 자리에서 읽어 되풀이 주기를 깬다. 판·줄눈 재질은 한 벌.
  ② 경계: 가까운 타일 중심 4곳의 이중선형 가중치(정수, 합 4096) + 재질마다 다른 자리의 매끈한 큰 얼룩 잡음(R) → 가장 큰 재질.
     물결선 경계, 색을 섞지 않으므로 팔레트 밖 색이 없다.
  ③ 오토타일식 테: 높이(pri)가 높은 재질은 1px 어두운 테두리, 낮은 재질은 (위 재질이 테두리를 가질 때) 그늘 띠. 같은 높이는 그늘.
  ④ 벽 아래 또렷한 2단 그늘 띠, 소품(바위·드럼통·장벽) 아래 타원 그림자.
  ⑤ 얼룩 덩어리·자갈·꽃·기름 얼룩 등 잔 소품은 타일 좌표 해시로 통째로 찍는다(위치·좌우 반전도 해시). 차선·유도선은 고정 소품.
  ⑥ 단단한 재질(보도·계단·실내 바닥)은 섞지 않는다(곧은 가장자리 + 테).
출력: game/assets/ground/ground_<set>.png(재질 아틀라스) · ground_decals_<set>.png · ground_noise.png · ground_<set>.json.
"""
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CELL = 256
NZ = 256
PAL = np.array([P.rgb(f"P{i:02d}") for i in range(64)], dtype=np.uint8)
TOK = {f"P{i:02d}": i for i in range(64)}
DARK = np.array([TOK["P%02d" % [j for j in range(64) if P.rgb(f"P{j:02d}") == P.step(P.rgb(f"P{i:02d}"), -1)][0]] for i in range(64)],
                dtype=np.uint8)


def t(tok):
    return TOK[tok]


# ---------------------------------------------------------------- 잡음 (주기 = 크기, 이음매 없음)
def vnoise(size, sc, seed):
    n = size // sc
    lat = np.random.default_rng(seed).random((n, n))
    c = np.arange(size) / sc
    i0 = np.floor(c).astype(int)
    f = c - i0
    f = f * f * (3 - 2 * f)
    i0 %= n
    i1 = (i0 + 1) % n
    a = lat[np.ix_(i0, i0)] * (1 - f)[None, :] + lat[np.ix_(i0, i1)] * f[None, :]
    b = lat[np.ix_(i1, i0)] * (1 - f)[None, :] + lat[np.ix_(i1, i1)] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]                      # [y, x]


def fbm(size, octaves, seed):
    v = sum(w * vnoise(size, sc, seed + k * 101) for k, (sc, w) in enumerate(octaves))
    return v / sum(w for _, w in octaves)


def equalize(v):
    """분포를 고르게(0..1): 문턱값 = 면적 비율."""
    r = v.ravel().argsort().argsort()
    return (r / (r.size - 1)).reshape(v.shape)


def noise_tex():
    """R: 큰 얼룩(경계 모양), G: 잔 얼룩(경계 거칠기), B: 아주 큰 얼룩(A·B 벌 섞기). 0..255 고른 분포."""
    r = equalize(fbm(NZ, [(32, 0.6), (16, 0.3), (8, 0.1)], 11))
    g = equalize(fbm(NZ, [(4, 0.7), (2, 0.3)], 23))
    b = equalize(fbm(NZ, [(128, 0.55), (64, 0.3), (32, 0.15)], 37))
    out = np.zeros((NZ, NZ, 4), np.uint8)
    out[..., 0] = np.round(r * 255)
    out[..., 1] = np.round(g * 255)
    out[..., 2] = np.round(b * 255)
    out[..., 3] = 255
    return out


# ---------------------------------------------------------------- 그리기 도구 (팔레트 인덱스 배열, 감아 돌기)
def quant(v, toks, cuts, dither=0.10, seed=0):
    """v(0..1, 고른 분포) → 램프. cuts = 누적 비율. 단계 경계는 픽셀 잡음으로 흩는다(얼룩 가장자리가 딱딱하지 않게)."""
    if dither:
        v = v + (np.random.default_rng(seed + 991).random(v.shape) - 0.5) * dither
    out = np.full(v.shape, t(toks[-1]), np.uint8)
    for tok, c in reversed(list(zip(toks, cuts))):
        out[v < c] = t(tok)
    return out


def put(a, x, y, tok):
    a[y % a.shape[0], x % a.shape[1]] = t(tok) if isinstance(tok, str) else tok


def stamp(a, x, y, rows, key):
    """문자 격자 찍기(감아 돌기). key: 문자 → 토큰, '.'은 건너뜀."""
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != "." and ch in key:
                put(a, x + i, y + j, key[ch])


PEBBLES = [[".ab.", "abbc", ".kk."], ["ab", "bc", "kk"], [".a.", "abc", "kkk"], ["ab.", "bbc", ".kk"]]


def pebble(a, rnd, x, y, ramp=("P08", "P07", "P06", "P02")):
    key = {"a": ramp[0], "b": ramp[1], "c": ramp[2], "k": ramp[3]}
    stamp(a, x, y, PEBBLES[rnd.integers(len(PEBBLES))], key)


def blob(a, cx, cy, rx, ry, tok, noise=None, thr=1.0):
    h, w = a.shape
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            q = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if noise is not None:
                q += (noise[y % h, x % w] - 0.5) * 0.9
            if q <= thr:
                put(a, x, y, tok)


def walk_line(a, rnd, x, y, n, tok, hi=None, dirs=((1, 0), (1, 1), (1, -1), (0, 1))):
    """감아 도는 균열: 먹선 + 오른쪽 밝은 가장자리."""
    for _ in range(n):
        put(a, x, y, tok)
        if hi:
            put(a, x + 1, y, hi) if a[(y) % a.shape[0], (x + 1) % a.shape[1]] != t(tok) else None
        dx, dy = dirs[rnd.integers(len(dirs))]
        x, y = x + dx, y + dy


# ---------------------------------------------------------------- 쯔꾸르풍 재질 (v2: 평평한 바탕 + 부드러운 큰 얼룩 + 드문드문 또렷한 무늬)
# 원칙: 픽셀 잡음·디더 점을 쓰지 않는다. 바탕 한 색 + 밝은/어두운 큰 얼룩(가장자리 매끈) + 간격을 둔 작은 무늬(풀포기·자갈·금).
def soft(seed, scale=64):
    """매끈한 큰 얼룩 값(0..1 고른 분포)."""
    return equalize(fbm(CELL, [(scale, 0.65), (scale // 2, 0.35)], seed))


def scatter(seed, spacing, mask=None, jitter=None):
    """간격을 둔 흩뿌림(떨린 격자): 무늬끼리 붙지 않는다. mask[y, x]가 참인 곳만."""
    rnd = np.random.default_rng(seed)
    j = jitter if jitter is not None else spacing // 2
    pts = []
    for gy in range(0, CELL, spacing):
        for gx in range(0, CELL, spacing):
            x = (gx + rnd.integers(-j, j + 1)) % CELL
            y = (gy + rnd.integers(-j, j + 1)) % CELL
            if mask is None or mask[y, x]:
                pts.append((x, y, rnd))
    return pts


def tuft(a, rnd, x, y, big=False):
    """잔 소품용 풀 덤불(쯔꾸르식: 어두운 잎 덩어리 + 밝은 잎끝)."""
    rows = [".a.a.a.", "abababa", ".bbbbb.", "..kkk.."] if big else [".a.a.", "ababa", ".kkk."]
    stamp(a, x - len(rows[0]) // 2, y - len(rows) + 1, rows, {"a": "P31", "b": "P30", "k": "P29"})


# 쯔꾸르 풀 무늬: 작은 'ᐱ' 풀포기(어두운 잎 + 밝은 끝)
GRASS_MOTIFS = [
    [".a.a.", "ab.ba", ".b.b."],
    ["a...a", ".a.a.", ".bab."],
    [".a.", "aba", ".b."],
    ["a.a", ".b."],
]


def grass_motif(a, rnd, x, y, dark="P29", light="P31"):
    stamp(a, x, y, GRASS_MOTIFS[rnd.integers(len(GRASS_MOTIFS))], {"a": light, "b": dark})


def small_pebble(a, rnd, x, y):
    stamp(a, x, y, [["ab", "kk"], [".ab", "abk", ".kk"], ["ab."], ["a", "k"]][rnd.integers(4)],
          {"a": "P08", "b": "P07", "k": "P17"})


def dirt_tex(seed, damp=False):
    a = np.full((CELL, CELL), t("P18"), np.uint8)
    # 밝은·어두운 얼룩은 잔 소품(통째로 찍는 덩어리)으로: A·B 경계에서 잘리지 않게
    for x, y, rnd in scatter(seed + 3, 14):                         # 자갈(간격 14px 안팎)
        if rnd.random() < 0.45:
            small_pebble(a, rnd, x, y)
    for x, y, rnd in scatter(seed + 4, 11):                         # 작은 흙 알갱이(한 점, 어둡게)
        if rnd.random() < 0.5:
            put(a, x, y, "P17")
    return a


def grass_tex(seed, dense, dry=False):
    if not dense:                                                   # 성긴 풀: 흙 바탕 + 풀 무리
        a = dirt_tex(seed)
        clump = soft(seed + 2, 32)
        for x, y, rnd in scatter(seed + 5, 9, clump > 0.5):
            grass_motif(a, rnd, x, y, dark="P29", light="P31")
        return a
    a = np.full((CELL, CELL), t("P30"), np.uint8)                   # 마른 벌도 같은 바탕(넓게 섞여도 얼룩져 보이지 않게)
    for x, y, rnd in scatter(seed + 5, 10):                         # 풀포기 무늬(간격 10px 안팎)
        if rnd.random() < 0.7:
            under = a[y % CELL, x % CELL]
            if under == t("P29"):
                grass_motif(a, rnd, x, y, dark="P28", light="P30")
            elif under == t("P31") or under == t("P32"):
                grass_motif(a, rnd, x, y, dark="P30", light="P32")
            else:
                grass_motif(a, rnd, x, y, dark="P29", light="P31")
    return a


def asphalt_tex(seed, worn=False):
    a = np.full((CELL, CELL), t("P04"), np.uint8)
    for x, y, rnd in scatter(seed + 3, 6):                          # 골재 점(드문드문)
        if rnd.random() < 0.35:
            put(a, x, y, "P05" if a[y % CELL, x % CELL] == t("P04") else "P04")
    rnd = np.random.default_rng(seed)
    for _ in range(6 if not worn else 9):                           # 깔끔한 1px 균열 + 밝은 가장자리
        x, y = rnd.integers(CELL), rnd.integers(CELL)
        dx = rnd.choice((-1, 1))
        for k in range(rnd.integers(14, 34)):
            put(a, x, y, "P02"); put(a, x, y + 1, "P05")
            x += dx if rnd.random() < 0.6 else 0
            y -= 0 if rnd.random() < 0.5 else 1
            if rnd.random() < 0.12:
                dx = -dx
    return a                                                        # 보수 자리는 잔 소품(patch)으로: A·B 경계에서 잘리지 않게


PAVER_TONES = [("P07", "P06", "P05")] * 9 + [("P08", "P07", "P06")]


def paver_tex(seed, weathered=False):
    """보도블록: 16px 판을 엇갈려 깐다. 판 = 한 색 + 윗·왼 밝은 테 + 아래·오른 어두운 테(쯔꾸르식 경사), 이음매 한 줄."""
    a = np.zeros((CELL, CELL), np.uint8)
    rnd = np.random.default_rng(seed)
    wr = np.random.default_rng(seed + 1)
    for row in range(CELL // 16):
        off = 8 if row % 2 else 0
        for col in range(CELL // 16):
            x0, y0 = col * 16 + off, row * 16
            r = rnd.random()
            hi, base, lo = PAVER_TONES[rnd.integers(len(PAVER_TONES))]
            if weathered and wr.random() < 0.05:                    # 때 탄 판(한 단계 어둡게)
                hi, base, lo = "P%02d" % DARK[t(hi)], "P%02d" % DARK[t(base)], "P%02d" % DARK[t(lo)]
            for y in range(y0, y0 + 16):
                for x in range(x0, x0 + 16):
                    put(a, x, y, base)
            for i in range(1, 16):
                put(a, x0 + i, y0 + 1, hi); put(a, x0 + 1, y0 + i, hi)
                put(a, x0 + i, y0 + 15, lo); put(a, x0 + 15, y0 + i, lo)
            for i in range(16):
                put(a, x0 + i, y0, "P04"); put(a, x0, y0 + i, "P04")
            if r > 0.98:                                            # 금 간 판(깔끔한 꺾은선)
                x, y = x0 + 4 + rnd.integers(6), y0 + 3
                for k in range(9):
                    put(a, x, y, "P04")
                    x += (1 if k % 3 == 0 else 0) * (1 if rnd.random() < 0.5 else -1)
                    y += 1
            elif r > 0.965:                                         # 귀퉁이 깨짐
                stamp(a, x0 + 12, y0 + 12, [".kk", "kkd", "kdd"], {"k": "P04", "d": "P05"})
    if weathered:                                                   # 이음매에 난 풀
        for _ in range(60):
            row, col = rnd.integers(CELL // 16), rnd.integers(CELL // 16)
            x0, y0 = col * 16 + (8 if row % 2 else 0), row * 16
            x = x0 + rnd.integers(3, 12)
            stamp(a, x, y0 - 1, [".a.", "bab"], {"a": "P31", "b": "P30"})
    return a


def tile_tex(img32):
    """구조물 타일(계단 등): 32px 타일을 되풀이(월드 좌표 & 31 = 타일 안 좌표)."""
    arr = np.array(img32.convert("RGB"))
    lut = {tuple(c): i for i, c in enumerate(PAL)}
    idx = np.zeros((32, 32), np.uint8)
    for y in range(32):
        for x in range(32):
            idx[y, x] = lut[tuple(arr[y, x])]
    return np.tile(idx, (CELL // 32, CELL // 32))


# ---------------------------------------------------------------- S-07 실내 재질 (쯔꾸르 실내: 깔끔한 판·줄눈·경사 테)
def panel_tex(seed, worn=False):
    """철판 바닥: 16×32 판을 열마다 엇갈려, 한 색 + 밝은 윗·왼 테 + 어두운 아래·오른 테 + 귀퉁이 리벳."""
    a = np.full((CELL, CELL), t("P13"), np.uint8)
    rnd = np.random.default_rng(seed)
    for col in range(CELL // 16):
        x0 = col * 16
        y00 = (col * 37 + seed * 11) % 32
        for k in range(CELL // 32):
            y0 = y00 + k * 32
            tone = "P13" if rnd.random() < 0.85 else "P12"
            if worn and rnd.random() < 0.15:
                tone = "P12"
            for y in range(y0, y0 + 32):
                for x in range(x0, x0 + 16):
                    put(a, x, y, tone)
            for i in range(1, 16):
                put(a, x0 + i, y0 + 1, "P14")
                put(a, x0 + i, y0 + 31, "P12")
            for i in range(1, 32):
                put(a, x0 + 1, y0 + i, "P14")
                put(a, x0 + 15, y0 + i, "P12")
            for i in range(16):
                put(a, x0 + i, y0, "P11")
            for i in range(32):
                put(a, x0, y0 + i, "P11")
            for rx, ry in ((3, 3), (12, 3), (3, 28), (12, 28)):     # 리벳
                put(a, x0 + rx, y0 + ry, "P15"); put(a, x0 + rx, y0 + ry + 1, "P11")
    if worn:                                                        # 긁힌 자국 몇 줄(깔끔한 짧은 대각선)
        for _ in range(14):
            x, y = rnd.integers(CELL), rnd.integers(CELL)
            for k in range(5):
                put(a, x + k, y + k // 2, "P14")
    return a


def grate_tex(seed, rusty=False):
    a = np.zeros((CELL, CELL), np.uint8)
    rnd = np.random.default_rng(seed)
    for gy in range(CELL // 16):
        for gx in range(CELL // 16):
            x0, y0 = gx * 16, gy * 16
            horiz = (gx + gy) % 2 == 0
            base = "P05" if not (rusty and rnd.random() < 0.15) else "P04"
            for y in range(y0, y0 + 16):
                for x in range(x0, x0 + 16):
                    put(a, x, y, base)
            for i in range(16):
                put(a, x0 + i, y0, "P02"); put(a, x0, y0 + i, "P02")
            for i in range(1, 15):
                put(a, x0 + i, y0 + 1, "P07"); put(a, x0 + 1, y0 + i, "P06")
            for k in (4, 8, 12):
                for i in range(3, 13):
                    if horiz:
                        put(a, x0 + i, y0 + k, "P01"); put(a, x0 + i, y0 + k + 1, "P06")
                    else:
                        put(a, x0 + k, y0 + i, "P01"); put(a, x0 + k + 1, y0 + i, "P06")
            put(a, x0 + 2, y0 + 2, "P08"); put(a, x0 + 13, y0 + 13, "P08")
    return a


def lino_tex(seed, worn=False):
    """교실 장판: 16px 바둑판(두 색) + 줄눈 + 윗변 밝은 테."""
    a = np.zeros((CELL, CELL), np.uint8)
    rnd = np.random.default_rng(seed)
    for gy in range(CELL // 16):
        for gx in range(CELL // 16):
            x0, y0 = gx * 16, gy * 16
            base, hi = (("P21", "P22") if (gx + gy) % 2 == 0 else ("P20", "P21"))
            if worn and rnd.random() < 0.12:
                base, hi = "P20", "P21"
            for y in range(y0, y0 + 16):
                for x in range(x0, x0 + 16):
                    put(a, x, y, base)
            for i in range(1, 16):
                put(a, x0 + i, y0 + 1, hi)
            for i in range(16):
                put(a, x0 + i, y0, "P19"); put(a, x0, y0 + i, "P19")
    return a


def clinic_tex(seed, worn=False):
    a = np.zeros((CELL, CELL), np.uint8)
    rnd = np.random.default_rng(seed)
    for gy in range(CELL // 8):
        for gx in range(CELL // 8):
            x0, y0 = gx * 8, gy * 8
            base = "P08" if not (rnd.random() < (0.03 if not worn else 0.08)) else "P14"
            for y in range(y0, y0 + 8):
                for x in range(x0, x0 + 8):
                    put(a, x, y, base)
            for i in range(1, 8):
                put(a, x0 + i, y0 + 1, "P09")
            for i in range(8):
                put(a, x0 + i, y0, "P07"); put(a, x0, y0 + i, "P07")
    return a


def concrete_tex(seed):
    """설비 구역 콘크리트: 한 색 바탕 + 64px 판 줄눈(밝은 윗테) + 부드러운 얼룩 + 짧은 금 몇 줄."""
    a = np.full((CELL, CELL), t("P06"), np.uint8)
    rnd = np.random.default_rng(seed)
    nz = equalize(fbm(CELL, [(32, 0.6), (16, 0.4)], seed))
    a[nz < 0.06] = t("P05")                                         # 얼룩은 작고 드물게(쯔꾸르식 평평한 바탕)
    for k in range(0, CELL, 64):
        for i in range(CELL):
            put(a, i, k, "P04"); put(a, i, k + 1, "P07")
            put(a, k, i, "P04"); put(a, k + 1, i, "P07")
    for _ in range(10):
        walk_line(a, rnd, int(rnd.integers(CELL)), int(rnd.integers(CELL)), int(rnd.integers(4, 9)), "P04", hi="P07")
    for _ in range(18):
        x, y = int(rnd.integers(CELL)), int(rnd.integers(CELL))
        put(a, x, y, "P05")
    return a


def concrete_out_tex(seed):
    """바깥 콘크리트 포장(골목·데크): 실내 판보다 거칠게 — 64px 타설 이음매, 가장자리 때, 금, 풀 난 이음매."""
    a = np.full((CELL, CELL), t("P06"), np.uint8)
    rnd = np.random.default_rng(seed + 7)
    for k in range(0, CELL, 64):                                       # 타설 이음매(어두운 선 + 밝은 선)
        for i in range(CELL):
            put(a, i, k, "P04"); put(a, i, k + 1, "P07")
            put(a, k, i, "P04"); put(a, k + 1, i, "P07")
    for _ in range(14):                                               # 짧은 금
        walk_line(a, rnd, int(rnd.integers(CELL)), int(rnd.integers(CELL)), int(rnd.integers(4, 9)), "P04", hi="P07")
    for _ in range(90):                                               # 자잘한 자갈 박힌 점(밝음·어두움)
        x, y = int(rnd.integers(CELL)), int(rnd.integers(CELL))
        put(a, x, y, "P05" if rnd.random() < 0.6 else "P07")
    for _ in range(40):                                               # 이음매에 난 풀
        k = int(rnd.integers(CELL // 64)) * 64
        i = int(rnd.integers(CELL))
        if rnd.random() < 0.5:
            stamp(a, i, k - 1, [".a.", "bab"], {"a": "P31", "b": "P30"})
        else:
            stamp(a, k - 1, i, [".a", "ab", ".b"], {"a": "P31", "b": "P30"})
    return a


def mold_tex(base, seed):
    """곰팡이병 바닥(수경 농장 2277): 바탕 재질 위에 불규칙하게 번진 검은 반점(큰 얼룩 문턱 + 가장자리 한 단 밝게)."""
    a = base.copy()
    nz = equalize(fbm(CELL, [(24, 0.6), (8, 0.4)], seed))
    big = equalize(fbm(CELL, [(96, 1.0)], seed + 5))
    m = (nz > 0.80) & (big > 0.35)
    edge = (nz > 0.74) & (big > 0.35) & ~m
    a[edge] = t("P03")
    a[m] = t("P01")
    a[(nz > 0.93) & (big > 0.35)] = t("P02")
    return a


def carpet_tex(seed):
    """오버시어실·회의실 카펫: 짙은 자주 바탕 + 8px 마름모 점무늬(밝은 점·어두운 점이 엇갈림)."""
    a = np.full((CELL, CELL), t("P52"), np.uint8)
    for y in range(0, CELL, 8):
        for x in range(0, CELL, 8):
            ox = 4 if (y // 8) % 2 else 0
            put(a, x + ox, y, "P53"); put(a, x + ox + 1, y, "P53")
            put(a, x + ox, y + 4, "P51")
    return a


def wood_tex(seed):
    """체육관 마루: 8px 널 + 밝은 윗테 + 어두운 이음매(열마다 엇갈림) + 옹이 몇 개."""
    a = np.zeros((CELL, CELL), np.uint8)
    rnd = np.random.default_rng(seed)
    for row in range(CELL // 8):
        y0 = row * 8
        off = (row * 41 + seed) % 64
        base = "P20" if rnd.random() < 0.8 else "P19"
        for y in range(y0, y0 + 8):
            for x in range(CELL):
                put(a, x, y, base)
        for x in range(CELL):
            put(a, x, y0, "P18"); put(a, x, y0 + 1, "P21")
        for x in range(off, CELL + off, 64):
            for y in range(y0, y0 + 8):
                put(a, x, y, "P18")
        for _ in range(2):
            kx = int(rnd.integers(CELL))
            put(a, kx, y0 + 4, "P18"); put(a, kx + 1, y0 + 4, "P19")
    return a


def jangpan_tex(seed):
    """봉천 장판(콩댐 장판지, 0-10c): 콩물 먹인 누런 한지를 엇갈려 바른 칸(32px, 줄마다 반 칸 어긋남) + 겹친 가장자리
    (어두운 한 줄 + 밝은 반짝임 한 줄) + 옅은 얼룩(기름 먹은 곳은 진하고 닳은 곳은 밝다) + 담뱃불 자국 몇 개."""
    a = np.full((CELL, CELL), t("P21"), np.uint8)
    nz = equalize(fbm(CELL, [(6, 1.0)], seed))
    a[nz > 0.97] = t("P22")                                           # 기름 먹은 반짝임(잔 점만 — 큰 얼룩은 위장무늬가 된다)
    for row in range(CELL // 32):
        y0 = row * 32
        off = 16 if row % 2 else 0
        for x in range(CELL):
            put(a, x, y0, "P20"); put(a, x, y0 + 1, "P22")
        for x in range(off, CELL + off, 32):
            for y in range(y0, y0 + 32):
                put(a, x % CELL, y, "P20"); put(a, (x + 1) % CELL, y, "P22")
    rnd = np.random.default_rng(seed)
    for _ in range(4):                                                # 담뱃불·인두 자국
        x, y = int(rnd.integers(8, CELL - 8)), int(rnd.integers(8, CELL - 8))
        stamp(a, x - 1, y - 1, [".b.", "bab", ".b."], {"a": "P17", "b": "P19"})
    for _ in range(60):                                               # 종이 결 점
        put(a, int(rnd.integers(CELL)), int(rnd.integers(CELL)), "P20")
    return a


# ---------------------------------------------------------------- 잔 소품 (32×32, 투명, 먹선)
def decals():
    D = []

    def cell():
        return np.full((32, 32), 255, np.uint8)                     # 255 = 투명

    def add(a):
        D.append(a)
        return len(D) - 1

    rnd = np.random.default_rng(7)
    ids = {}
    a = cell()                                                       # 자갈 무리
    for x, y in ((12, 14), (17, 16), (14, 19), (20, 13)):
        pebble(a, rnd, x, y)
    ids["pebbles"] = add(a)
    a = cell()                                                       # 작은 바위
    stamp(a, 11, 12, [".kkkkk..", "kaabbbk.", "kabbbcck", "kbbbccck", ".kcccck.", "..kkkk.."],
          {"k": "P01", "a": "P09", "b": "P07", "c": "P05"})
    ids["rock"] = add(a)
    a = cell()                                                       # 뼈
    stamp(a, 9, 14, ["kk......kk", "kabbbbbbak", ".kbbbbbbk.", "kak....kak", "kk......kk"],
          {"k": "P01", "a": "P09", "b": "P08"})
    ids["bone"] = add(a)
    a = cell()                                                       # 녹슨 깡통(누운)
    stamp(a, 11, 13, [".kkkkkk.", "kaabbbck", "kddeeefk", "kbbbbbck", ".kkkkkk."],
          {"k": "P01", "a": "P27", "b": "P26", "c": "P24", "d": "P07", "e": "P05", "f": "P24"})
    ids["can"] = add(a)
    a = cell()                                                       # 마른 잎·잔가지
    stamp(a, 8, 12, ["..a.....", "...a..b.", "aaaab.b.", ".....bbb", "..b..b..", ".bbb...."],
          {"a": "P17", "b": "P26"})
    stamp(a, 18, 18, ["cc.", "ccd", ".d."], {"c": "P27", "d": "P25"})
    ids["leaves"] = add(a)
    a = cell()                                                       # 축축한 자국
    nz = equalize(fbm(32, [(8, 1.0)], 5))
    blob(a, 16, 16, 7, 4, "P17", nz)
    ids["damp"] = add(a)
    a = cell()                                                       # 꽃 포기
    tuft(a, rnd, 15, 18, big=True)
    for x, y in ((12, 13), (18, 12), (15, 11)):
        stamp(a, x - 1, y - 1, [".a.", "aba", ".a."], {"a": "P49", "b": "P27"})
    ids["flowers"] = add(a)
    a = cell()                                                       # 큰 풀 포기
    tuft(a, rnd, 13, 19, big=True); tuft(a, rnd, 18, 20, big=True); tuft(a, rnd, 16, 17)
    ids["bush"] = add(a)
    a = cell()                                                       # 토끼풀
    for x, y in ((12, 14), (16, 16), (19, 13), (14, 18)):
        stamp(a, x - 1, y - 1, ["ab.", "bbb", ".c."], {"a": "P56", "b": "P55", "c": "P29"})
    ids["clover"] = add(a)
    a = cell()                                                       # 기름 얼룩
    nz = equalize(fbm(32, [(8, 1.0)], 9))
    blob(a, 16, 16, 9, 6, "P03", nz)
    blob(a, 17, 16, 6, 4, "P02", nz)
    put(a, 13, 14, "P12"); put(a, 14, 14, "P13")                    # 무지갯빛 반사 한 점
    ids["oil"] = add(a)
    a = cell()                                                       # 콘크리트 부스러기
    for x, y in ((11, 15), (17, 13), (19, 18)):
        stamp(a, x, y, ["ab", "bk"], {"a": "P08", "b": "P06", "k": "P02"})
    ids["debris"] = add(a)
    a = cell()                                                       # 팬 구멍(포트홀): 먹선 테 + 고인 흙
    stamp(a, 9, 11, ["..kkkkkkkk..", ".kddeeeeddk.", "kddeeffeeddk", "kdeeffffeedk", ".kddeeeeddk.", "..kkkkkkkk.."],
          {"k": "P01", "d": "P02", "e": "P17", "f": "P18"})
    ids["pothole"] = add(a)
    a = cell()                                                       # 아스팔트 덧씌운 보수 자리(먹선 테)
    for y in range(10, 22):
        for x in range(7, 26):
            edge = y in (10, 21) or x in (7, 25)
            put(a, x, y, "P02" if edge else ("P04" if y == 11 else "P03"))
    ids["patch"] = add(a)
    # 바닥 얼룩 덩어리(쯔꾸르식: 평평한 바탕 위에 통째로 찍는 부드러운 얼룩, 모양 두 가지씩)
    for name, tok, rx, ry, seed in (("dirt_lt1", "P19", 9, 5, 31), ("dirt_lt2", "P19", 6, 4, 32), ("dirt_dk1", "P17", 5, 3, 33),
                                    ("grass_lt1", "P31", 9, 5, 34), ("grass_lt2", "P31", 6, 4, 35), ("grass_dk1", "P29", 5, 3, 36),
                                    ("asph_lt1", "P05", 8, 4, 37), ("asph_dk1", "P03", 6, 3, 38)):
        a = cell()
        nz = equalize(fbm(32, [(8, 1.0)], seed))
        blob(a, 16, 16, rx, ry, tok, nz, 0.85)
        ids[name] = add(a)
    a = cell()                                                       # 종이 쓰레기
    stamp(a, 12, 13, ["kkkkkk.", "kaaabk.", "kabaabk", ".kaaabk", ".kkkkkk"], {"k": "P05", "a": "P09", "b": "P08"})
    ids["paper"] = add(a)
    a = cell()                                                       # 꽁초 몇 개
    for x, y in ((12, 15), (17, 17), (15, 12)):
        stamp(a, x, y, ["aab"], {"a": "P09", "b": "P27"})
    ids["butts"] = add(a)
    a = cell()                                                       # 얼룩(보도)
    nz = equalize(fbm(32, [(8, 1.0)], 13))
    blob(a, 16, 16, 7, 5, "P05", nz)
    ids["stain"] = add(a)
    a = cell()                                                       # 차선(가로 점선, 닳음)
    wear = equalize(fbm(32, [(4, 1.0)], 17))
    for x in range(3, 29):
        for y in (15, 16):
            if wear[y, x] < 0.82:
                put(a, x, y, "P08" if y == 15 else "P07")
    ids["lane"] = add(a)
    for axis in ("h", "v"):                                          # 실내 바닥 유도선(타일 끝까지 이어짐)
        a = cell()
        for i in range(32):
            for j, tok in enumerate(("P01", "P49", "P48", "P48", "P48", "P48", "P48", "P01")):
                x, y = (i, 12 + j) if axis == "h" else (12 + j, i)
                put(a, x, y, tok)
        ids["guide_" + axis] = add(a)
    for name, arms in (("guide_x", (range(0, 12), range(20, 32))), ("guide_t", (range(0, 12),))):   # 유도선 교차(+)·T자(위로)
        a = cell()
        for i in range(32):
            for j, tok in enumerate(("P01", "P49", "P48", "P48", "P48", "P48", "P48", "P01")):
                put(a, i, 12 + j, tok)
        for arm in arms:
            for i in arm:
                for j, tok in enumerate(("P01", "P49", "P48", "P48", "P48", "P48", "P48", "P01")):
                    put(a, 12 + j, i, tok)
        for x in range(13, 19):                                      # 가운데는 노란 칠이 이어진다(가로선 테를 끊는다)
            put(a, x, 12, "P49" if x == 13 else "P48")
            if len(arms) == 2:
                put(a, x, 19, "P48")
        ids[name] = add(a)
    a = cell()                                                       # 실내 긁힘·발자국
    for k in range(9):
        put(a, 10 + k, 14 + k // 3, "P11")
    for k in range(6):
        put(a, 14 + k, 19 + k // 2, "P15")
    ids["scuff"] = add(a)
    a = cell()                                                       # 볼트 판
    stamp(a, 11, 11, ["kkkkkkkkkk", "kabbbbbbak", "kbbbbbbbbk", "kbbbbbbbbk", "kabbbbbbak", "kkkkkkkkkk"],
          {"k": "P11", "a": "P15", "b": "P13"})
    ids["plate"] = add(a)
    a = cell()                                                       # 물 고인 자국
    nz = equalize(fbm(32, [(8, 1.0)], 21))
    blob(a, 16, 17, 9, 5, "P12", nz)
    blob(a, 15, 16, 5, 3, "P13", nz)
    put(a, 13, 15, "P15")
    ids["puddle"] = add(a)
    a = cell()                                                       # 녹물 자국
    nz = equalize(fbm(32, [(8, 1.0)], 25))
    blob(a, 16, 16, 7, 6, "P24", nz, 0.7)
    ids["rust"] = add(a)
    a = cell()                                                       # 검은 곰팡이 반점(수경 농장 2277, SD-09a V-06)
    nz = equalize(fbm(32, [(8, 1.0)], 41))
    for cx, cy, rx, ry in ((12, 13, 5, 4), (20, 18, 4, 3), (14, 21, 3, 2), (22, 10, 2, 2)):
        blob(a, cx, cy, rx + 1, ry + 1, "P03", nz)
        blob(a, cx, cy, rx, ry, "P01", nz)
    put(a, 11, 12, "P02"); put(a, 19, 17, "P02")
    ids["mold"] = add(a)
    return D, ids


# ---------------------------------------------------------------- 세트 정의
def sets():
    import tiles_isaac as TI
    D, did = decals()
    r01 = {
        "materials": [
            # spread: 경계 물결 폭(px) · pri: 위아래(높은 재질이 위) · rim: 위 재질 테두리(px) · shade: 아래 재질 그늘(px)
            # vthr: B 벌 문턱(클수록 B가 적다) · dens: 잔 소품 밀도(%) · hard: 섞지 않음 · boff: B 벌을 읽는 어긋남
            dict(name="dirt", A=dirt_tex(101), B=dirt_tex(101, damp=True), spread=6, pri=0, rim=0, shade=2, vthr=160, dens=16,
                 decals=["dirt_lt1", "dirt_lt2", "dirt_dk1", "pebbles", "rock", "leaves", "bone", "can"], hard=0, boff=(97, 61)),
            dict(name="grass_sparse", A=grass_tex(111, False), B=grass_tex(111, False, dry=True), spread=6, pri=1, rim=0, shade=1,
                 vthr=150, dens=14, decals=["dirt_lt1", "grass_dk1", "flowers", "pebbles", "clover", "bush"], hard=0, boff=(141, 83)),
            dict(name="grass_dense", A=grass_tex(121, True), B=grass_tex(121, True, dry=True), spread=6, pri=2, rim=1, shade=1,
                 vthr=165, dens=16, decals=["grass_lt1", "grass_lt2", "grass_dk1", "bush", "flowers", "clover"], hard=0, boff=(59, 173)),
            dict(name="asphalt", A=asphalt_tex(131), B=asphalt_tex(131, worn=True), spread=2, pri=3, rim=1, shade=1, vthr=140, dens=14,
                 decals=["asph_lt1", "asph_dk1", "oil", "debris", "pothole", "patch", "paper"], hard=0, boff=(113, 37)),
            dict(name="pavers", A=paver_tex(141, weathered=True), B=paver_tex(141, weathered=True), spread=0, pri=4, rim=1, shade=0, vthr=256, dens=6,
                 decals=["paper", "butts", "leaves"], hard=1),                # 인공 바닥: 곧은 연석 가장자리(섞지 않음)
            dict(name="stairs", A=tile_tex(TI.stairs()), B=tile_tex(TI.stairs()), spread=0, pri=5, rim=0, shade=0, vthr=255, dens=0,
                 decals=[], hard=1),
            dict(name="stairs_rail", A=tile_tex(TI.stairs_rail()), B=tile_tex(TI.stairs_rail()), spread=0, pri=5, rim=0, shade=0, vthr=255,
                 dens=0, decals=[], hard=1),
            # 0-10: 골목·데크 콘크리트(64px 타설 이음매 + 미끄럼 홈 대신 얼룩·금) — 봉천 골목·볼트 데크
            dict(name="concrete", A=concrete_out_tex(151), B=None, spread=0, pri=4, rim=1, shade=1, vthr=256, dens=8,
                 decals=["paper", "butts", "leaves"], hard=1),
        ],
        "mat_of": {"dirt_a": 0, "dirt_b": 0, "dirt_grass_a": 2, "dirt_grass_b": 1, "asphalt": 3, "asphalt_lane": 3,
                   "pavers": 4, "pavers_b": 4, "stairs": 5, "stairs_rail": 6, "concrete_o": 7},
        "force": {"asphalt_lane": "lane"},
        "flag_of": {"brick": 1, "brick_window": 1, "wall_face": 1, "wall_face_cap": 1, "granite_rock": 2, "scrap_barrier": 2, "drum": 2},
    }
    s07 = {
        "materials": [
            dict(name="panel", A=panel_tex(201, worn=True), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=5,
                 decals=["plate", "paper", "puddle"], hard=1),
            dict(name="grate", A=grate_tex(211, rusty=True), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=3,
                 decals=["paper"], hard=1),
            dict(name="lino", A=lino_tex(221, worn=True), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=4,
                 decals=["paper", "butts"], hard=1),
            dict(name="clinic", A=clinic_tex(231), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=3,
                 decals=["paper"], hard=1),
            dict(name="concrete", A=concrete_tex(241), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=3,
                 decals=["debris", "rust", "puddle", "stain"], hard=1),
            dict(name="carpet", A=carpet_tex(251), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=0,
                 decals=[], hard=1),
            dict(name="wood", A=wood_tex(261), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=2,
                 decals=["scuff"], hard=1),
            dict(name="panel_mold", A=mold_tex(panel_tex(201, worn=True), 271), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256,
                 dens=6, decals=["mold", "puddle"], hard=1),
            dict(name="grate_mold", A=mold_tex(grate_tex(211, rusty=True), 281), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256,
                 dens=6, decals=["mold"], hard=1),
            dict(name="jangpan", A=jangpan_tex(291), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=1,
                 decals=["scuff"], hard=1),
        ],
        "mat_of": {"panel": 0, "panel_sheen": 0, "panel_scuff": 0, "guide_h": 0, "guide_v": 0, "guide_x": 0, "guide_t": 0, "grate_a": 1, "grate_b": 1, "grate_c": 1,
                   "lino_a": 2, "lino_b": 2, "clinic_a": 3, "clinic_b": 3, "concrete_a": 4, "carpet_a": 5, "wood_a": 6,
                   "panel_mold": 7, "grate_mold": 8, "jangpan_a": 9},
        "force": {"guide_h": "guide_h", "guide_v": "guide_v", "guide_x": "guide_x", "guide_t": "guide_t"},
        "flag_of": {k: 1 for k in ("wall_top_s", "wall_top_w", "wall_top_ws", "wall_top", "face_top", "face_top_pipe", "face_top_vent",
                                   "face_bot", "face_bot_outlet", "balcony", "balcony_door")},
    }
    return {"r01": r01, "s07": s07}, D, did


class GroundSet:
    """한 세트(타일셋)의 합성 자료: 아틀라스(재질 × [A, B, A어둠, B어둠]), 잔 소품, 잡음, 표."""

    def __init__(self, name, spec, D, did, tile_ids):
        self.name = name
        mats = spec["materials"]
        self.M = len(mats)
        self.atlas = np.zeros((CELL * self.M, CELL * 6), np.uint8)                # [A, B, A어둠, B어둠, A더어둠, B더어둠]
        for m, d in enumerate(mats):
            bb = d["B"] if d["B"] is not None else d["A"]                       # 구조가 있는 바닥(판·줄눈)은 한 벌만: 경계에서 판이 잘리지 않게
            for k, a in enumerate((d["A"], bb, DARK[d["A"]], DARK[bb], DARK[DARK[d["A"]]], DARK[DARK[bb]])):
                self.atlas[m * CELL:(m + 1) * CELL, k * CELL:(k + 1) * CELL] = a
        self.spread = np.array([2 * d["spread"] for d in mats], np.int64)
        self.pri = np.array([d["pri"] for d in mats], np.int64)
        self.rim = np.array([d["rim"] for d in mats], np.int64)
        self.shade = np.array([d["shade"] for d in mats], np.int64)
        self.vthr = np.array([d["vthr"] for d in mats], np.int64)
        self.dens = np.array([d["dens"] * 256 // 100 for d in mats], np.int64)
        self.hard = np.array([d["hard"] for d in mats], np.int64)
        self.boff = np.array([d.get("boff", (0, 0)) for d in mats], np.int64)
        self.dlist = np.full((self.M, 8), 0, np.int64)
        self.dcount = np.zeros(self.M, np.int64)
        for m, d in enumerate(mats):
            for i, n in enumerate(d["decals"][:8]):
                self.dlist[m, i] = did[n]
            self.dcount[m] = len(d["decals"][:8])
        n_ids = max(tile_ids.values()) + 1
        self.mat_of = np.zeros(32, np.int64)
        self.force = np.full(32, -1, np.int64)
        self.flag_of = np.zeros(32, np.int64)
        for k, i in tile_ids.items():
            self.mat_of[i] = spec["mat_of"].get(k, 0)
            if k in spec["force"]:
                self.force[i] = did[spec["force"][k]]
            self.flag_of[i] = spec["flag_of"].get(k, 0)
        self.n_ids = n_ids
        nd = len(D)
        self.decal = np.full((64, 32 * nd), 255, np.uint8)               # 0..31 보통, 32..63 어둠
        for i, a in enumerate(D):
            self.decal[0:32, i * 32:(i + 1) * 32] = a
            self.decal[32:64, i * 32:(i + 1) * 32] = np.where(a == 255, 255, DARK[np.minimum(a, 63)])
        self.noise = noise_tex()
        self.names = [d["name"] for d in mats]

    # ---------------- 정수 합성(셰이더와 같은 식)
    def render(self, ids, deco, ox, oy, x0, y0, w, h, flags=None):
        """ids·deco: 타일 격자 [ty][tx](deco = 덮개 아틀라스 번호, 없으면 -1), 격자 (0,0) = 월드 타일 (ox, oy).
        flags를 주면 deco 대신 덮개 값(0 없음 · 1 벽 · 2 소품 · 3 평평한 구조물: 섞지 않고 그늘도 없음)을 바로 쓴다.
        반환: 월드 픽셀 (x0..x0+w, y0..y0+h) RGBA."""
        ids = np.asarray(ids, np.int64)
        flags = np.asarray(flags, np.int64) if flags is not None else self.flag_of_tile(np.asarray(deco, np.int64))
        gh, gw = ids.shape

        def at(arr, tx, ty):
            return arr[np.clip(ty - oy, 0, gh - 1), np.clip(tx - ox, 0, gw - 1)]

        Y, X = np.mgrid[y0:y0 + h, x0:x0 + w].astype(np.int64)
        ax = (X - 16) >> 5
        ay = (Y - 16) >> 5
        u = (X - 16) - ax * 32
        v = (Y - 16) - ay * 32
        wx1, wy1 = 2 * u + 1, 2 * v + 1
        wx0, wy0 = 64 - wx1, 64 - wy1
        corners = [(ax, ay, wx0 * wy0), (ax + 1, ay, wx1 * wy0), (ax, ay + 1, wx0 * wy1), (ax + 1, ay + 1, wx1 * wy1)]
        tx, ty = X >> 5, Y >> 5
        fx, fy = X & 31, Y & 31
        own_id = at(ids, tx, ty)
        m0 = self.mat_of[own_id]
        # 벽에 덮인 타일의 바닥은 보이지 않으므로 섞지 않는다(자기 재질로 본다)
        mats = [np.where(np.isin(at(flags, cx, cy), (1, 3)), m0, self.mat_of[at(ids, cx, cy)]) for cx, cy, _ in corners]
        ws = [c[2] for c in corners]
        hard0 = self.hard[m0] == 1
        R, B = self.noise[..., 0].astype(np.int64), self.noise[..., 2].astype(np.int64)
        NEG = -(1 << 40)
        raw, scores = [], []
        for k in range(4):
            mk = mats[k]
            W = sum(np.where(mats[j] == mk, ws[j], 0) for j in range(4))
            oxm, oym = (mk * 73) & 255, (mk * 151) & 255
            n = 3 * (R[(Y + oym) & 255, (X + oxm) & 255] - 128)          # 매끈한 큰 얼룩만(물결 경계, 잔 점 없음)
            s = 3 * W + self.spread[mk] * n
            raw.append(s)
            scores.append(np.where((self.hard[mk] == 1) & (mk != m0), NEG, s))   # 단단한 이웃은 번지지 않는다
        best_s = np.full(X.shape, NEG, np.int64)
        best_m = np.full(X.shape, 99, np.int64)
        for k in range(4):
            better = (scores[k] > best_s) | ((scores[k] == best_s) & (mats[k] < best_m))
            best_s = np.where(better, scores[k], best_s)
            best_m = np.where(better, mats[k], best_m)
        own_s = np.full(X.shape, NEG, np.int64)                       # 단단한 자기 타일은 그대로
        for k in range(4):
            own_s = np.where(mats[k] == m0, np.maximum(own_s, raw[k]), own_s)
        win_m = np.where(hard0, m0, best_m)
        win_s = np.where(hard0, own_s, best_s)
        second = np.full(X.shape, NEG, np.int64)                      # 경계: 다른 재질의 원래 점수 중 최고와 그 재질
        sec_m = np.full(X.shape, 99, np.int64)
        for k in range(4):
            better = (mats[k] != win_m) & ((raw[k] > second) | ((raw[k] == second) & (mats[k] < sec_m)))
            second = np.where(better, raw[k], second)
            sec_m = np.where(better, mats[k], sec_m)
        has2 = second != NEG
        margin = win_s - np.where(has2, second, 0)
        sec_c = np.where(has2, sec_m, 0)
        pw, ps = self.pri[win_m], self.pri[sec_c]
        # 쯔꾸르 오토타일: 위 재질은 테두리, 아래 재질은 (위 재질이 테두리를 가질 때만) 그늘, 같은 높이(실내 이음매)는 그늘
        band = np.where(pw > ps, self.rim[win_m], np.where((pw == ps) | (self.rim[sec_c] > 0), self.shade[win_m], 0))
        dark = has2 & (band > 0) & (margin < band * 768)
        # 벽 그늘·소품 그림자(또렷한 띠·타원, 디더 없음)
        fN = at(flags, tx, ty - 1)
        fW = at(flags, tx - 1, ty)
        fE = at(flags, tx + 1, ty)
        f0 = at(flags, tx, ty)
        deep = (fN == 1) & (fy < 2)
        dark |= (fN == 1) & (fy < 5)
        dark |= (fW == 1) & (fx < 2)
        dark |= (fE == 1) & (fx > 29)
        q0 = (fx - 16) ** 2 * 36 + (fy - 29) ** 2 * 169                  # 소품 그림자 타원(가로 13 · 세로 6, 아래 타일로 3px 넘친다)
        q1 = (fx - 16) ** 2 * 36 + (fy + 3) ** 2 * 169
        dark |= ((f0 == 2) & (q0 <= 6084)) | ((fN == 2) & (q1 <= 6084))
        # A·B 벌
        oxm, oym = (win_m * 73) & 255, (win_m * 151) & 255
        var = (B[(Y + oym) & 255, (X + oxm) & 255] > self.vthr[win_m]).astype(np.int64)
        level = np.where(deep, 2, np.where(dark, 1, 0))
        col = var + 2 * level
        bx, by = self.boff[win_m, 0] * var, self.boff[win_m, 1] * var        # B 벌은 어긋난 자리에서 읽는다(되풀이 주기 깨기)
        out = self.atlas[win_m * CELL + ((Y + by) & (CELL - 1)), col * CELL + ((X + bx) & (CELL - 1))].astype(np.int64)
        # 잔 소품
        hsh = thash(tx, ty)
        force = self.force[own_id]
        has = (win_m == m0) & ((force >= 0) | (((hsh & 255) < self.dens[m0]) & (self.dcount[m0] > 0)))
        di = np.where(force >= 0, force, self.dlist[m0, (hsh >> 8) % np.maximum(self.dcount[m0], 1)])
        dox = np.where(force >= 0, 0, ((hsh >> 16) & 7) - 4)
        doy = np.where(force >= 0, 0, ((hsh >> 19) & 7) - 4)
        flip = np.where(force >= 0, 0, (hsh >> 22) & 1)
        sx, sy = fx - dox, fy - doy
        sx = np.where(flip == 1, 31 - sx, sx)
        inside = (sx >= 0) & (sx < 32) & (sy >= 0) & (sy < 32)
        dv = self.decal[np.clip(sy, 0, 31) + 32 * dark.astype(np.int64), di * 32 + np.clip(sx, 0, 31)].astype(np.int64)
        use = has & inside & (dv != 255)
        out = np.where(use, dv, out)
        rgba = np.zeros((h, w, 4), np.uint8)
        rgba[..., :3] = PAL[out]
        rgba[..., 3] = 255
        return Image.fromarray(rgba, "RGBA")

    def flag_of_tile(self, deco_id):
        return np.where(deco_id >= 0, self.flag_of[np.maximum(deco_id, 0)], 0)

    def export(self, out_dir):
        os.makedirs(out_dir, exist_ok=True)
        idx_img = lambda a: Image.fromarray(np.dstack([PAL[np.minimum(a, 63)], np.where(a == 255, 0, 255).astype(np.uint8)]), "RGBA")
        idx_img(self.atlas).save(os.path.join(out_dir, f"ground_{self.name}.png"))
        idx_img(self.decal).save(os.path.join(out_dir, f"ground_decals_{self.name}.png"))
        Image.fromarray(self.noise, "RGBA").save(os.path.join(out_dir, "ground_noise.png"))
        meta = {"set": self.name, "cell": CELL, "materials": self.names, "spread": self.spread.tolist(), "pri": self.pri.tolist(),
                "rim": self.rim.tolist(), "shade": self.shade.tolist(),
                "vthr": self.vthr.tolist(), "boff": self.boff.ravel().tolist(), "dens": self.dens.tolist(), "hard": self.hard.tolist(),
                "dlist": self.dlist.ravel().tolist(), "dcount": self.dcount.tolist(), "mat_of": self.mat_of.tolist(),
                "force": self.force.tolist(), "flag_of": self.flag_of.tolist()}
        json.dump(meta, open(os.path.join(out_dir, f"ground_{self.name}.json"), "w"), indent=1)


def thash(tx, ty):
    """타일 좌표 해시(uint32, 셰이더와 같은 식)."""
    M = 0xFFFFFFFF
    h = ((tx & M) * 0x8DA6B343 & M) ^ ((ty & M) * 0xD8163841 & M)
    h ^= h >> 13
    h = (h * 0x85EBCA6B) & M
    h ^= h >> 16
    return h


def tile_ids(name):
    p = os.path.join(ROOT, "game", "assets", "tiles", f"ts_{name}.json")
    return {k: v["atlas"][0] for k, v in json.load(open(p)).items()}


_CACHE = {}


def load(name):
    """name: 'r01' 또는 's07'."""
    if name not in _CACHE:
        spec, D, did = sets()
        tid = tile_ids({"r01": "r01_ext", "s07": "s07_int"}[name])
        _CACHE[name] = GroundSet(name, spec[name], D, did, tid)
    return _CACHE[name]


def demo_ids():
    """재질 경계 견본 지도(20×12): 흙 바탕, 풀밭(빽빽 + 둘레 성긴 풀), 비탈 아스팔트 길, 보도블록 마당, 바위·드럼통·담."""
    tid = tile_ids("r01_ext")
    W_, H_ = 20, 12
    ids = np.full((H_, W_), tid["dirt_a"])
    deco = np.full((H_, W_), -1)
    for y in range(H_):
        for x in range(W_):
            d = ((x - 4.5) / 4.6) ** 2 + ((y - 8.0) / 3.4) ** 2
            if d < 0.55:
                ids[y, x] = tid["dirt_grass_a"]
            elif d < 1.15:
                ids[y, x] = tid["dirt_grass_b"]
            if abs(y - (1 + x * 0.45)) < 1.3:
                ids[y, x] = tid["asphalt_lane"] if abs(y - (1 + x * 0.45)) < 0.5 and x % 4 < 2 else tid["asphalt"]
            if 11 <= x <= 18 and 7 <= y <= 11:
                ids[y, x] = tid["pavers"]
    for x in range(11, 19):
        deco[6, x] = tid["wall_face_cap"] if x != 15 else -1
    for (x, y), k in (((15, 1), "granite_rock"), ((16, 1), "granite_rock"), ((16, 2), "granite_rock"), ((9, 8), "drum"), ((12, 9), "drum"),
                      ((7, 11), "scrap_barrier"), ((8, 11), "scrap_barrier")):
        deco[y, x] = tid[k]
    return ids, deco


def samples():
    """samples/03_ground_r01(·_x2): 실제 시험 구역 한 화면, 03_ground_blend(·_x2): 재질 경계 견본, 10_ground_s07(·_x2): 실내."""
    from grid import upscale
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "samples")
    ts = Image.open(os.path.join(ROOT, "game", "assets", "tiles", "ts_r01_ext.png")).convert("RGBA")
    gs = load("r01")

    def with_deco(img, deco, ox, oy):
        for (y, x), d in np.ndenumerate(deco):
            if d >= 0:
                img.alpha_composite(ts.crop((d * 32, 0, d * 32 + 32, 32)), ((x - ox) * 32, (y - oy) * 32))
        return img

    ids, deco = demo_ids()
    img = gs.render(np.pad(ids, 1, mode="edge"), np.pad(deco, 1, mode="constant", constant_values=-1), -1, -1, 0, 0, 640, 360)
    img = with_deco(img, deco, 0, 0)
    img.save(os.path.join(out, "03_ground_blend.png"))
    upscale(img, 2).save(os.path.join(out, "03_ground_blend_x2.png"))
    D = os.path.join(ROOT, "game", "data", "chunks")
    cs = json.load(open(os.path.join(D, "_index.json")))["chunk_size"]
    ox, oy, w, h = 158, 164, 20, 12                                     # 볼트 정문 마당 + 비탈길 + 흙·풀
    gi = np.zeros((h + 2, w + 2), int)
    gd = np.full((h + 2, w + 2), -1)
    cache = {}
    for ty in range(oy - 1, oy + h + 1):
        for tx in range(ox - 1, ox + w + 1):
            cid = f"C-{tx // cs:02d}-{ty // cs:02d}"
            if cid not in cache:
                cache[cid] = json.load(open(os.path.join(D, cid + ".json")))
            i = (ty % cs) * cs + tx % cs
            gi[ty - oy + 1, tx - ox + 1] = cache[cid]["ground"][i]
            gd[ty - oy + 1, tx - ox + 1] = cache[cid]["deco"][i]
    img = gs.render(gi, gd, ox - 1, oy - 1, ox * 32, oy * 32, 640, 360)
    img = with_deco(img, gd[1:-1, 1:-1], 0, 0)
    img.save(os.path.join(out, "03_ground_r01.png"))
    upscale(img, 2).save(os.path.join(out, "03_ground_r01_x2.png"))
    sys.path.insert(0, os.path.join(ROOT, "tools", "screens"))
    import ground_check
    img = ground_check.ref_s07().convert("RGBA").crop((0, 0, 640, 360))
    img.save(os.path.join(out, "10_ground_s07.png"))
    upscale(img, 2).save(os.path.join(out, "10_ground_s07_x2.png"))
    print("ground samples written")


if __name__ == "__main__":
    samples()
