"""바닥 합성 v1 (SD-16 §6.10): 타일 한 장씩 찍지 않고, 재질 텍스처를 월드 좌표로 깔고 재질 경계를 섞는다.

왜: 32px 타일 한 장을 되풀이하면 같은 금·자갈이 타일마다 보이고(반복), 재질이 바뀌는 곳은 타일 경계에서 직선으로 끊긴다(단절).
어떻게(실행 중 셰이더 game/systems/world/ground.gdshader와 픽셀 단위로 같은 정수 계산):
  ① 재질마다 128×128 이음매 없는 텍스처 2벌(A·B)과 각각 한 단계 어두운 벌. 월드 픽셀 좌표로 바로 읽는다(타일 경계와 무관).
     A·B는 아주 낮은 주파수 잡음(B 채널)으로 넓은 얼룩처럼 섞인다 → 같은 무늬가 4타일마다 되풀이돼도 눈에 띄지 않는다.
  ② 경계: 픽셀마다 가까운 타일 중심 4곳의 이중선형 가중치(정수, 합 4096)를 재질별로 모으고, 재질마다 다른 위치의 잡음
     (R 큰 얼룩 + G 잔 얼룩)과 4×4 베이어 디더를 더해 가장 큰 재질을 고른다. 결과: 경계가 타일 선을 따르지 않고 흙이
     보도블록 위로 번지듯 들쭉날쭉, 가장자리는 디더 점으로 흩어지는 '그라데이션'. 색을 섞지 않으므로 팔레트 밖 색이 없다.
  ③ 가장자리 때: 1등과 2등의 차이가 작은 곳(경계 띠)은 재질에 따라 한 단계 어두운 벌을 디더 확률로 쓴다(선형 감쇠).
  ④ 벽 아래 그늘(북쪽·옆 벽 → 몇 px 디더 감쇠), 소품(바위·드럼통·장벽) 아래 타원 그림자.
  ⑤ 잔 소품(자갈·뼈·깡통·꽃·기름 얼룩…)을 타일 좌표 해시로 흩뿌린다(타일 안 위치·좌우 반전도 해시). 차선·유도선은 고정 소품.
  ⑥ 단단한 재질(계단 등 구조물)은 섞지 않는다(자기 타일 그대로, 이웃도 번지지 않음).
출력: game/assets/ground/ground_<set>.png(재질 아틀라스) · ground_decals.png · ground_noise.png · ground_<set>.json.
"""
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CELL = 256
NZ = 256
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.int64)
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


# ---------------------------------------------------------------- R01 바깥 재질
def dirt_tex(seed, damp=False):
    v = equalize(fbm(CELL, [(32, 0.5), (16, 0.3), (4, 0.2)], seed))
    a = quant(v, ["P17", "P18", "P19"], [0.09, 0.985] if damp else [0.025, 0.90], dither=0.3 if damp else 0.1, seed=seed)
    rnd = np.random.default_rng(seed)
    fine = equalize(fbm(CELL, [(2, 1.0)], seed + 5))
    a[(fine > 0.985)] = t("P16")
    a[(fine < 0.008)] = t("P20")
    cl = equalize(fbm(CELL, [(32, 1.0)], seed + 9))                   # 자갈은 무리 지어
    for _ in range(64 if damp else 48):
        x, y = rnd.integers(CELL), rnd.integers(CELL)
        if cl[y, x] > 0.55:
            pebble(a, rnd, x, y)
    for _ in range(14):                                              # 마른 흙 금(밝은 곳에만)
        x, y = rnd.integers(CELL), rnd.integers(CELL)
        if v[y, x] > 0.5 and not damp:
            walk_line(a, rnd, x, y, rnd.integers(3, 7), "P17")
    return a


def tuft(a, rnd, x, y, big=False):
    blades = [(-2, 3), (0, 5), (2, 4), (1, 2), (-1, 4)] if big else [(-1, 2), (0, 4), (1, 3)]
    for k, (dx, h) in enumerate(blades):
        for s in range(h):
            xx = x + (dx * s) // max(h, 1)
            put(a, xx, y - s, "P31" if (k + s) % 2 else "P30")
        put(a, x + dx, y - h, "P32")
    put(a, x - 1, y + 1, "P29"); put(a, x, y + 1, "P29"); put(a, x + 1, y + 1, "P29")


def grass_tex(seed, dense, dry=False):
    if not dense:
        a = dirt_tex(seed)
        rnd = np.random.default_rng(seed + 1)
        fz = equalize(fbm(CELL, [(16, 0.6), (2, 0.4)], seed + 3))
        a[fz > (0.90 if not dry else 0.94)] = t("P30")
        a[fz > (0.975 if not dry else 0.985)] = t("P31")
        cl = equalize(fbm(CELL, [(32, 1.0)], seed + 4))
        for _ in range(150):
            x, y = rnd.integers(CELL), rnd.integers(CELL)
            if cl[y, x] > (0.4 if not dry else 0.6):
                tuft(a, rnd, x, y, big=rnd.random() < 0.3)
        return a
    v = equalize(fbm(CELL, [(32, 0.3), (8, 0.35), (2, 0.35)], seed))
    a = quant(v, ["P18", "P29", "P30", "P31"], [0.012, 0.09, 0.93] if not dry else [0.02, 0.08, 0.86], seed=seed)
    rnd = np.random.default_rng(seed + 2)
    for _ in range(700):                                             # 풀잎 결: 짧은 세로 획(밝은 끝 + 어두운 뿌리)
        x, y = rnd.integers(CELL), rnd.integers(CELL)
        if v[y, x] > 0.2:
            put(a, x, y, "P31" if not dry else "P32"); put(a, x, y - 1, "P32" if rnd.random() < 0.5 else "P31")
            put(a, x, y + 1, "P29")
    for _ in range(80):
        x, y = rnd.integers(CELL), rnd.integers(CELL)
        tuft(a, rnd, x, y, big=True)
    if dry:                                                          # 마른 풀: 밝은 지푸라기 점
        a[(fbm(CELL, [(2, 1.0)], seed + 8) > 0.72) & (a == t("P31"))] = t("P32")
    return a


def asphalt_tex(seed, worn=False):
    v = equalize(fbm(CELL, [(32, 0.35), (8, 0.25), (2, 0.4)], seed))
    a = quant(v, ["P03", "P04", "P05"], [0.20, 0.82] if not worn else [0.12, 0.66], seed=seed)
    rnd = np.random.default_rng(seed)
    fine = equalize(fbm(CELL, [(2, 1.0)], seed + 7))
    a[fine > 0.975] = t("P02")
    a[fine < 0.02] = t("P06")
    if worn:                                                         # 닳아 드러난 골재
        a[(fine > 0.4) & (fine < 0.46) & (v > 0.6)] = t("P06")
    for _ in range(9 if not worn else 11):                           # 이어지는 균열망(타일 경계를 넘는다)
        x, y = rnd.integers(CELL), rnd.integers(CELL)
        walk_line(a, rnd, x, y, rnd.integers(30, 70), "P01", "P05",
                  dirs=((1, 0), (1, 1), (0, 1), (1, -1), (-1, 1)))
    # 보수한 자리(어두운 덧칠 사각, 먹선 테)
    for _ in range(3):
        px, py, w, h = rnd.integers(CELL), rnd.integers(CELL), rnd.integers(14, 30), rnd.integers(9, 18)
        for y in range(py, py + h):
            for x in range(px, px + w):
                edge = y in (py, py + h - 1) or x in (px, px + w - 1)
                put(a, x, y, "P02" if edge else ("P03" if fine[y % CELL, x % CELL] < 0.8 else "P04"))
    return a


PAVER_TONES = [("P05", "P06", "P07"), ("P05", "P06", "P07"), ("P05", "P06", "P07"), ("P05", "P06", "P06"), ("P06", "P07", "P07")]


def paver_tex(seed, weathered=False):
    a = np.zeros((CELL, CELL), np.uint8)
    rnd = np.random.default_rng(seed)
    mot = equalize(fbm(CELL, [(8, 0.6), (2, 0.4)], seed + 1))
    stain = equalize(fbm(CELL, [(32, 0.7), (8, 0.3)], seed + 2))
    for row in range(CELL // 16):
        off = 8 if row % 2 else 0                                    # 엇갈려 깐 보도블록(16px 판)
        for col in range(CELL // 16):
            x0, y0 = col * 16 + off, row * 16
            r = rnd.random()
            tone = PAVER_TONES[rnd.integers(len(PAVER_TONES))]
            for y in range(y0, y0 + 16):
                for x in range(x0, x0 + 16):
                    m = mot[y % CELL, x % CELL]
                    tok = tone[0] if m < 0.06 else tone[2] if m > 0.93 else tone[1]
                    if weathered and stain[y % CELL, x % CELL] > 0.84:
                        tok = "P%02d" % DARK[t(tok)]
                    put(a, x, y, tok)
            for i in range(1, 15):                                   # 윗변·왼변 밝게, 아랫변·오른변 어둡게
                put(a, x0 + i, y0 + 1, "P%02d" % min(t(tone[2]) + 1, 9))
                put(a, x0 + 14, y0 + i, tone[0])
                put(a, x0 + i, y0 + 14, tone[0])
            for i in range(16):                                      # 이음매
                put(a, x0 + i, y0, "P02"); put(a, x0, y0 + i, "P02")
            if r > 0.96:                                             # 금 간 판
                x, y = x0 + 3 + rnd.integers(6), y0 + 3
                for k in range(rnd.integers(6, 10)):
                    put(a, x, y, "P02")
                    x += rnd.integers(-1, 2); y += 1
                    if y >= y0 + 14:
                        break
            elif r > 0.93:                                           # 귀퉁이 깨짐
                cx, cy = (x0 + 13, y0 + 13) if rnd.random() < 0.5 else (x0 + 2, y0 + 13)
                stamp(a, cx - 1, cy - 1, ["kk", "kd"], {"k": "P02", "d": "P03"})
    if weathered:                                                    # 이음매에 난 풀
        for _ in range(90):
            row, col = rnd.integers(CELL // 16), rnd.integers(CELL // 16)
            x0, y0 = col * 16 + (8 if row % 2 else 0), row * 16
            if rnd.random() < 0.5:
                x = x0 + rnd.integers(2, 14)
                for k, tok in enumerate(("P30", "P31", "P30")):
                    put(a, x + k, y0, tok)
                put(a, x + 1, y0 - 1, "P32")
            else:
                y = y0 + rnd.integers(2, 14)
                put(a, x0, y, "P30"); put(a, x0, y + 1, "P31"); put(a, x0 - 1, y, "P31")
    return a


def tile_tex(img32):
    """구조물 타일(계단 등): 32px 타일을 4×4로 되풀이(월드 좌표 & 31 = 타일 안 좌표)."""
    arr = np.array(img32.convert("RGB"))
    lut = {tuple(c): i for i, c in enumerate(PAL)}
    idx = np.zeros((32, 32), np.uint8)
    for y in range(32):
        for x in range(32):
            idx[y, x] = lut[tuple(arr[y, x])]
    return np.tile(idx, (CELL // 32, CELL // 32))


# ---------------------------------------------------------------- S-07 실내 재질
def panel_tex(seed, worn=False):
    v = equalize(fbm(CELL, [(32, 0.55), (8, 0.3), (2, 0.15)], seed))
    a = quant(v, ["P12", "P13", "P14"], [0.05, 0.96] if not worn else [0.10, 0.98], dither=0.12, seed=seed)
    rnd = np.random.default_rng(seed)
    for col in range(CELL // 16):                                    # 16px 판, 가로 이음매는 판마다 엇갈림
        x0 = col * 16
        for y in range(CELL):
            put(a, x0, y, "P11"); put(a, x0 + 1, y, "P14")
        y0 = (col * 37 + seed * 11) % 32
        for k in range(CELL // 32):
            yy = y0 + k * 32
            for x in range(x0 + 1, x0 + 16):
                put(a, x, yy, "P11"); put(a, x, yy + 1, "P14")
            for dx in (4, 12):                                       # 리벳
                put(a, x0 + dx, yy + 3, "P15"); put(a, x0 + dx, yy + 4, "P11")
    sc = equalize(fbm(CELL, [(32, 0.7), (4, 0.3)], seed + 3))
    a[(sc > (0.95 if not worn else 0.90)) & (a == t("P13"))] = t("P12")       # 닳은 자국(한 단계만)
    for _ in range(10 if not worn else 20):                          # 긁힌 자국
        x, y = rnd.integers(CELL), rnd.integers(CELL)
        for k in range(rnd.integers(4, 9)):
            put(a, x + k, y + (k // 3), "P15" if k % 3 else "P12")
    return a


def grate_tex(seed, rusty=False):
    a = np.zeros((CELL, CELL), np.uint8)
    rnd = np.random.default_rng(seed)
    mot = equalize(fbm(CELL, [(8, 0.5), (2, 0.5)], seed + 1))
    rust = equalize(fbm(CELL, [(32, 0.8), (4, 0.2)], seed + 2))
    for gy in range(CELL // 16):
        for gx in range(CELL // 16):
            x0, y0 = gx * 16, gy * 16
            horiz = rnd.random() < 0.5
            for y in range(y0, y0 + 16):
                for x in range(x0, x0 + 16):
                    edge = x == x0 or y == y0
                    m = mot[y, x]
                    tok = "P02" if edge else ("P04" if m < 0.2 else "P06" if m > 0.85 else "P05")
                    if not edge and rusty and rust[y, x] > 0.80 and tok == "P05":
                        tok = "P04"
                    put(a, x, y, tok)
            for i in range(1, 15):
                put(a, x0 + i, y0 + 1, "P07")
            for k in (4, 8, 12):
                for i in range(3, 13):
                    if horiz:
                        put(a, x0 + i, y0 + k, "P01"); put(a, x0 + i, y0 + k + 1, "P06")
                    else:
                        put(a, x0 + k, y0 + i, "P01"); put(a, x0 + k + 1, y0 + i, "P06")
            put(a, x0 + 2, y0 + 2, "P08"); put(a, x0 + 13, y0 + 13, "P08")
    return a


def lino_tex(seed, worn=False):
    v = equalize(fbm(CELL, [(32, 0.5), (8, 0.3), (2, 0.2)], seed))
    a = quant(v, ["P19", "P20", "P21"], [0.04, 0.93] if not worn else [0.09, 0.97], dither=0.14, seed=seed)
    rnd = np.random.default_rng(seed)
    tone = rnd.random((CELL // 16, CELL // 16))
    for gy in range(CELL // 16):                                     # 16px 장판 조각: 몇 장은 한 단계 밝거나 어둡게(갈아 붙인 자국)
        for gx in range(CELL // 16):
            blk = a[gy * 16 + 1:gy * 16 + 16, gx * 16 + 1:gx * 16 + 16]
            if tone[gy, gx] > 0.93:
                blk[blk == t("P20")] = t("P21")
            elif tone[gy, gx] < 0.05:
                blk[blk == t("P20")] = t("P19")
    for k in range(0, CELL, 16):
        a[:, k] = t("P19"); a[k, :] = t("P19")
    for k in range(0, CELL, 16):                                     # 이음매 아래·오른쪽 1px 밝게(살짝 뜬 장판)
        a[(k + 1) % CELL, :][a[(k + 1) % CELL, :] == t("P20")] = t("P21")
    return a


def clinic_tex(seed, worn=False):
    v = equalize(fbm(CELL, [(16, 0.5), (2, 0.5)], seed))
    a = quant(v, ["P07", "P08", "P09"], [0.06, 0.94] if not worn else [0.14, 0.95], seed=seed)
    for k in range(0, CELL, 8):
        a[:, k] = t("P06"); a[k, :] = t("P06")
    rnd = np.random.default_rng(seed)
    for _ in range(12):
        x, y = rnd.integers(CELL // 8) * 8, rnd.integers(CELL // 8) * 8
        a[y + 1:y + 8, x + 1:x + 8] = t("P14")                       # 갈아 끼운 타일
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
    return D, ids


# ---------------------------------------------------------------- 세트 정의
def sets():
    import tiles_isaac as TI
    D, did = decals()
    r01 = {
        "materials": [
            # name, A, B, spread(px), edge(px), B 문턱(0..255, 클수록 B가 적다), 잔 소품 밀도(%), 잔 소품, 단단함
            dict(name="dirt", A=dirt_tex(101), B=dirt_tex(101, damp=True), spread=9, edge=0, vthr=150, dens=14,
                 decals=["pebbles", "pebbles", "rock", "leaves", "pebbles", "damp", "bone", "can"], hard=0, boff=(97, 61)),
            dict(name="grass_sparse", A=grass_tex(111, False), B=grass_tex(111, False, dry=True), spread=10, edge=0, vthr=140,
                 dens=16, decals=["bush", "flowers", "pebbles", "clover", "leaves"], hard=0, boff=(141, 83)),
            dict(name="grass_dense", A=grass_tex(121, True), B=grass_tex(121, True, dry=True), spread=11, edge=0, vthr=150,
                 dens=18, decals=["bush", "flowers", "clover", "bush"], hard=0, boff=(59, 173)),
            dict(name="asphalt", A=asphalt_tex(131), B=asphalt_tex(131, worn=True), spread=4, edge=3, vthr=130, dens=12,
                 decals=["oil", "debris", "pothole", "debris", "paper"], hard=0, boff=(113, 37)),
            dict(name="pavers", A=paver_tex(141), B=paver_tex(141, weathered=True), spread=5, edge=3, vthr=120, dens=10,
                 decals=["paper", "butts", "stain", "leaves", "debris"], hard=0),
            dict(name="stairs", A=tile_tex(TI.stairs()), B=tile_tex(TI.stairs()), spread=0, edge=0, vthr=255, dens=0, decals=[], hard=1),
            dict(name="stairs_rail", A=tile_tex(TI.stairs_rail()), B=tile_tex(TI.stairs_rail()), spread=0, edge=0, vthr=255, dens=0,
                 decals=[], hard=1),
        ],
        "mat_of": {"dirt_a": 0, "dirt_b": 0, "dirt_grass_a": 2, "dirt_grass_b": 1, "asphalt": 3, "asphalt_lane": 3,
                   "pavers": 4, "pavers_b": 4, "stairs": 5, "stairs_rail": 6},
        "force": {"asphalt_lane": "lane"},
        "flag_of": {"brick": 1, "brick_window": 1, "wall_face": 1, "wall_face_cap": 1, "granite_rock": 2, "scrap_barrier": 2, "drum": 2},
    }
    s07 = {
        "materials": [
            dict(name="panel", A=panel_tex(201), B=panel_tex(201, worn=True), spread=2, edge=4, vthr=150, dens=9,
                 decals=["scuff", "plate", "paper", "puddle", "scuff"], hard=1),
            dict(name="grate", A=grate_tex(211), B=grate_tex(211, rusty=True), spread=2, edge=4, vthr=140, dens=6,
                 decals=["rust", "paper"], hard=1),
            dict(name="lino", A=lino_tex(221), B=lino_tex(221, worn=True), spread=2, edge=4, vthr=150, dens=6,
                 decals=["paper", "butts", "paper"], hard=1),
            dict(name="clinic", A=clinic_tex(231), B=clinic_tex(231, worn=True), spread=2, edge=3, vthr=160, dens=5,
                 decals=["scuff", "paper"], hard=1),
        ],
        "mat_of": {"panel": 0, "panel_sheen": 0, "panel_scuff": 0, "guide_h": 0, "guide_v": 0, "guide_x": 0, "guide_t": 0, "grate_a": 1, "grate_b": 1, "grate_c": 1,
                   "lino_a": 2, "lino_b": 2, "clinic_a": 3, "clinic_b": 3},
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
            for k, a in enumerate((d["A"], d["B"], DARK[d["A"]], DARK[d["B"]], DARK[DARK[d["A"]]], DARK[DARK[d["B"]]])):
                self.atlas[m * CELL:(m + 1) * CELL, k * CELL:(k + 1) * CELL] = a
        self.spread = np.array([2 * d["spread"] for d in mats], np.int64)
        self.edge = np.array([d["edge"] for d in mats], np.int64)
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
        R, G, B = (self.noise[..., c].astype(np.int64) for c in range(3))
        bay = lambda dx, dy: BAYER[(Y + dy) & 3, (X + dx) & 3]
        NEG = -(1 << 40)
        raw, scores = [], []
        for k in range(4):
            mk = mats[k]
            W = sum(np.where(mats[j] == mk, ws[j], 0) for j in range(4))
            oxm, oym = (mk * 73) & 255, (mk * 151) & 255
            n = 2 * (R[(Y + oym) & 255, (X + oxm) & 255] - 128) + (G[(Y + oym) & 255, (X + oxm) & 255] - 128)
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
        second = np.full(X.shape, NEG, np.int64)                      # 경계 띠: 다른 재질의 원래 점수 중 최고
        for k in range(4):
            second = np.where(mats[k] != win_m, np.maximum(second, raw[k]), second)
        margin = np.where(second == NEG, 1 << 30, win_s - second)
        b1 = bay(1, 2)
        e = self.edge[win_m]
        dark = (e > 0) & (margin * 16 <= (b1 + 1) * e * 768)
        # 벽 그늘·소품 그림자
        fN = at(flags, tx, ty - 1)
        fW = at(flags, tx - 1, ty)
        fE = at(flags, tx + 1, ty)
        f0 = at(flags, tx, ty)
        b2 = bay(3, 1)
        deep = (fN == 1) & (fy * 16 <= (b2 + 1) * 2)                      # 벽 발치: 2단(더 어둠 → 어둠) 디더 감쇠
        dark |= (fN == 1) & (fy * 16 <= (b2 + 1) * 6)
        dark |= (fW == 1) & (fx * 16 <= (b2 + 1) * 3)
        dark |= (fE == 1) & ((31 - fx) * 16 <= (b2 + 1) * 3)
        q0 = (fx - 16) ** 2 * 36 + (fy - 29) ** 2 * 169                  # 소품 그림자 타원(가로 13 · 세로 6, 아래 타일로 3px 넘친다)
        q1 = (fx - 16) ** 2 * 36 + (fy + 3) ** 2 * 169
        dark |= (f0 == 2) & (q0 * 32 <= (b2 + 17) * 6084)
        dark |= (fN == 2) & (q1 * 32 <= (b2 + 17) * 6084)
        deep |= (f0 == 2) & (q0 * 64 <= (b2 + 9) * 6084)
        deep |= (fN == 2) & (q1 * 64 <= (b2 + 9) * 6084)
        # A·B 벌
        oxm, oym = (win_m * 73) & 255, (win_m * 151) & 255
        vv = B[(Y + oym) & 255, (X + oxm) & 255] + ((G[(Y + oym) & 255, (X + oxm) & 255] - 128) >> 3)
        var = (vv > self.vthr[win_m]).astype(np.int64)
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
        meta = {"set": self.name, "cell": CELL, "materials": self.names, "spread": self.spread.tolist(), "edge": self.edge.tolist(),
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
