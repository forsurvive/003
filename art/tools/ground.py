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


# ---------------------------------------------------------------- 단계 1-1 월드 재질(SD-16 §6.7·§6.10, SD-08 §6.2)
WAVES = [["aaa", ".bb."], [".aaaa", "bb..."], ["aa", ".b"], ["aaaa.", "..bbb"]]


def water_tex(seed, base, lt, dk):
    """수면: 한 색 바탕 + 간격 둔 잔물결(밝은 윗줄 + 어두운 아랫점). 깊을수록 물결이 드물다."""
    a = np.full((CELL, CELL), t(base), np.uint8)
    for x, y, rnd in scatter(seed + 3, 13):
        if rnd.random() < 0.55:
            stamp(a, x, y, WAVES[rnd.integers(len(WAVES))], {"a": lt, "b": dk})
    return a


def mud_tex(seed):
    """둔치 진흙(갈대흙): 젖은 흙 바탕 + 마른 금 + 작은 물기 자국. 갈대는 잔 소품."""
    a = np.full((CELL, CELL), t("P17"), np.uint8)
    for x, y, rnd in scatter(seed + 3, 12):
        r = rnd.random()
        if r < 0.35:
            stamp(a, x, y, ["ab", ".b"], {"a": "P18", "b": "P16"})          # 마른 흙 덩이
        elif r < 0.55:
            stamp(a, x, y, ["aa."], {"a": "P16"})                           # 젖은 금
    return a


def rubble_tex(seed):
    """잔해: 회색 콘크리트 부스러기 바탕 + 덩이(윗·왼 밝게, 아래·오른 어둡게)."""
    a = np.full((CELL, CELL), t("P05"), np.uint8)
    for x, y, rnd in scatter(seed + 3, 9):
        r = rnd.random()
        if r < 0.45:
            stamp(a, x, y, [["aab", "acb", "bbk"], ["ab", "bk"], ["aaab", "accb", ".bkk"]][rnd.integers(3)],
                  {"a": "P07", "c": "P06", "b": "P04", "k": "P03"})
        elif r < 0.6:
            put(a, x, y, "P04")
    return a


def rock_tex(seed):
    """화강암 암반(R01·R09 흰 화강암, SD-08 §7): 밝은 판 + 꺾은 금(어두운 선 + 밝은 아래 가장자리) + 운모 점."""
    a = np.full((CELL, CELL), t("P08"), np.uint8)
    rnd = np.random.default_rng(seed)
    for _ in range(7):
        x, y = rnd.integers(CELL), rnd.integers(CELL)
        dx = rnd.choice((-1, 1))
        for k in range(rnd.integers(10, 26)):
            put(a, x, y, "P06"); put(a, x, y + 1, "P09")
            x += dx if rnd.random() < 0.7 else 0
            y += 0 if rnd.random() < 0.6 else 1
            if rnd.random() < 0.1:
                dx = -dx
    for x, y, rnd2 in scatter(seed + 5, 10):
        if rnd2.random() < 0.4:
            put(a, x, y, "P07")
    return a


def ballast_tex(seed):
    """철로 자갈: 회갈 바탕 + 자갈 알(밝은 점 + 그늘 점) 촘촘히."""
    a = np.full((CELL, CELL), t("P06"), np.uint8)
    for x, y, rnd in scatter(seed + 3, 5):
        if rnd.random() < 0.6:
            stamp(a, x, y, [["ab"], ["a", "b"], ["ab", "bb"]][rnd.integers(3)], {"a": "P07", "b": "P04"})
    return a


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


def sidewalk_tex(seed):
    """보도(1-R 도로 경계 v2, 리드 지시 2026-10-18 '벽돌 모양은 도로 경계로 어울리지 않는다'): 16px 네모 콘크리트 판을 줄 맞춰 깐다.
    판마다 경사 테 없이 한 색(낮은 대비) + 위·왼 이음매 한 줄(판보다 한 단 어둡게) · 골재 점 · 드문 금 · 빠진 판(흙) · 이음매 풀.
    차도 쪽 가장자리는 화강암 연석 띠가 따로 그린다(재질 curb — 셰이더 · render 같은 식)."""
    a = np.zeros((CELL, CELL), np.uint8)
    rnd = np.random.default_rng(seed)
    tones = ["P07"] * 15 + ["P06"]                                     # 거의 한 톤(바둑판으로 보이지 않게) — 드물게 한 단 어두운 판
    for row in range(CELL // 16):
        for col in range(CELL // 16):
            x0, y0 = col * 16, row * 16
            base = tones[rnd.integers(len(tones))]
            joint = "P%02d" % DARK[t(base)]
            r = rnd.random()
            if r < 0.012:                                              # 빠진 판: 흙이 드러났다
                for y in range(y0, y0 + 16):
                    for x in range(x0, x0 + 16):
                        put(a, x, y, "P18" if rnd.random() < 0.8 else "P17")
                for i in range(16):
                    put(a, x0 + i, y0, "P05"); put(a, x0, y0 + i, "P05")
                    put(a, x0 + i, y0 + 15, "P19"); put(a, x0 + 15, y0 + i, "P19")
                continue
            for y in range(y0, y0 + 16):
                for x in range(x0, x0 + 16):
                    put(a, x, y, base)
            for i in range(16):
                put(a, x0 + i, y0, joint); put(a, x0, y0 + i, joint)
            for _ in range(2):                                         # 골재 점(아주 옅게 — 판보다 한 단 어둡게만)
                put(a, x0 + 2 + rnd.integers(12), y0 + 2 + rnd.integers(12), joint)
            if r > 0.955:                                              # 금 간 판(꺾은선 하나)
                x, y = x0 + 3 + rnd.integers(8), y0 + 1
                for k in range(13):
                    put(a, x, y, joint)
                    if k % 3 == 2:
                        x += 1 if rnd.random() < 0.5 else -1
                    y += 1
    for _ in range(40):                                                # 이음매에 난 풀(가로 이음매에 두세 포기)
        x0, y0 = 16 * rnd.integers(CELL // 16), 16 * rnd.integers(CELL // 16)
        stamp(a, x0 + rnd.integers(2, 13), y0 - 1, [".a.", "bab"], {"a": "P31", "b": "P30"})
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


def turf_tex(seed):
    """고척 돔 그라운드 인조 잔디(1-11i): 바랜 올리브 잔디 + 128px 깎은 결 줄무늬(짙은 띠, 경계만 2px 디더) +
    성긴 세로 털 획 + 드문 닳아 빠진 자리(갈색 바닥천에 검은 고무 알갱이) + 볕에 마른 누런 털 조각. 쯔꾸르식 평평한 바탕."""
    a = np.full((CELL, CELL), t("P30"), np.uint8)
    rnd = np.random.default_rng(seed)
    fine = rnd.random((CELL, CELL))
    yy, _ = np.mgrid[0:CELL, 0:CELL]
    ph = (yy % 128)
    band = (ph >= 64) & (ph < 128)
    edge = ((ph == 64) | (ph == 65) | (ph == 126) | (ph == 127)) & (fine < 0.5)
    a[band & ~edge] = t("P29")                                          # 짙은 결(깎은 방향이 다른 줄)
    dry = equalize(fbm(CELL, [(64, 0.7), (24, 0.3)], seed + 2))
    a[(dry > 0.90) & (fine < 0.40)] = t("P31")                          # 볕에 바랜 털(성긴 디더)
    a[(dry > 0.96) & (fine < 0.30)] = t("P32")
    for _ in range(260):                                               # 털 획(세로 2px)
        x, y = int(rnd.integers(CELL)), int(rnd.integers(CELL))
        c = "P31" if a[y, x] == t("P30") else "P30"
        put(a, x, y, c); put(a, x, (y + 1) % CELL, c)
    big = equalize(fbm(CELL, [(48, 0.6), (16, 0.4)], seed + 1))
    bald = big < 0.035
    a[(big >= 0.035) & (big < 0.06) & (fine < 0.5)] = t("P28")          # 빠진 자리 테두리: 짓눌린 털
    a[bald] = t("P18")                                                  # 바닥천
    a[bald & (fine < 0.25)] = t("P17")
    a[bald & (fine > 0.88)] = t("P02")                                  # 고무 알갱이
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


def terrazzo_tex(seed):
    """지하상가 인조석 물갈기 바닥(1-4 지하시장): 밝은 회백 바탕에 잔 돌 조각(어두운·밝은·벽돌색 드물게) + 128px 판마다 줄눈.
    판 이음매 몇 곳은 깨져 시멘트로 땜질했다."""
    a = np.full((CELL, CELL), t("P07"), np.uint8)
    rnd = np.random.default_rng(seed)
    # 발길 얼룩은 두지 않는다(1-4 화면 검수: 256px 그림이 되풀이되면 같은 얼룩이 줄지어 보인다)
    for _ in range(CELL * CELL // 22):                                # 돌 조각: 1~2px
        x, y = int(rnd.integers(CELL)), int(rnd.integers(CELL))
        r = rnd.random()
        tok = "P05" if r < 0.45 else "P08" if r < 0.80 else "P04" if r < 0.93 else "P18" if r < 0.985 else "P53"
        put(a, x, y, tok)
        if rnd.random() < 0.3:
            put(a, x + 1, y, tok)
    for k in range(0, CELL, 128):                                     # 놋쇠 줄눈(1px 금빛 + 그 아래 그림자, 128px 판)
        for i in range(CELL):
            put(a, i, k, "P08"); put(a, i, k + 1, "P06")
            put(a, k, i, "P08"); put(a, k + 1, i, "P06")
    for _ in range(6):                                                # 땜질 자국
        x, y = int(rnd.integers(8, CELL - 20)), int(rnd.integers(8, CELL - 20))
        w, h = int(rnd.integers(5, 12)), int(rnd.integers(4, 9))
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                put(a, xx, yy, "P06")
        for xx in range(x, x + w):
            put(a, xx, y, "P05")
    return a


def steps_tex(seed):
    """콘크리트 계단(1-5 벙커 입구 28단): 16px마다 디딤판 — 위 모서리 밝은 줄(논슬립 쇠띠) · 디딤면 · 아래 챌판 그늘.
    가운데가 닳아 밝고, 모서리 군데군데 깨졌다."""
    a = np.full((CELL, CELL), t("P05"), np.uint8)
    rnd = np.random.default_rng(seed)
    for y0 in range(0, CELL, 16):
        for x in range(CELL):
            put(a, x, y0, "P07")                                      # 논슬립 띠(빛)
            put(a, x, y0 + 1, "P06")
            for yy in (y0 + 12, y0 + 13):
                put(a, x, yy, "P04")                                  # 챌판 그늘
            put(a, x, y0 + 14, "P03"); put(a, x, y0 + 15, "P03")
        for _ in range(3):                                            # 닳은 가운데
            x = int(rnd.integers(CELL))
            for xx in range(x, x + int(rnd.integers(6, 18))):
                put(a, xx, y0 + 4 + int(rnd.integers(0, 5)), "P06")
        if rnd.random() < 0.5:                                        # 깨진 모서리
            x = int(rnd.integers(CELL - 6))
            for xx in range(x, x + int(rnd.integers(2, 6))):
                put(a, xx, y0, "P03"); put(a, xx, y0 + 1, "P04")
    for _ in range(30):
        x, y = int(rnd.integers(CELL)), int(rnd.integers(CELL))
        put(a, x, y, "P04")
    return a


def epoxy_tex(seed):
    """벙커 칠 바닥(1-5): 회청색 에폭시 칠. 큰 얼룩 대신 잔 점묘로 바랜 결 — 걷던 자리만 성기게 밝고(디더),
    칠이 벗겨진 콘크리트는 손톱만 한 조각뿐. 64px마다 신축 줄눈(어두운 줄 + 아래 밝은 턱), 군데군데 끌린 자국."""
    a = np.full((CELL, CELL), t("P12"), np.uint8)
    rnd = np.random.default_rng(seed)
    big = equalize(fbm(CELL, [(96, 0.7), (40, 0.3)], seed))
    fine = rnd.random((CELL, CELL))
    a[(big < 0.30) & (fine < 0.10)] = t("P11")                         # 그늘진 결: 점묘만
    a[(big > 0.72) & (fine < 0.16)] = t("P13")                         # 닳아 밝은 결: 성긴 디더
    a[(big > 0.90) & (fine < 0.05)] = t("P14")
    for _ in range(10):                                                # 칠이 벗겨진 작은 조각(2~4px)
        x, y = int(rnd.integers(CELL)), int(rnd.integers(CELL))
        w, h = int(rnd.integers(2, 5)), int(rnd.integers(1, 3))
        for yy in range(h):
            for xx in range(w):
                put(a, (x + xx) % CELL, (y + yy) % CELL, "P06" if (xx + yy) % 3 else "P05")
    for _ in range(8):                                                 # 끌린 자국: 짧은 가로 획
        x, y = int(rnd.integers(CELL)), int(rnd.integers(CELL))
        for xx in range(int(rnd.integers(5, 12))):
            put(a, (x + xx) % CELL, y, "P11")
    for k in range(0, CELL, 64):                                       # 신축 줄눈
        for i in range(CELL):
            put(a, i, k, "P10"); put(a, i, k + 1, "P13")
            put(a, k, i, "P10"); put(a, k + 1, i, "P13")
    return a


def flood_tex(seed, deep=False):
    """침수 바닥(1-D 던전 · SD-09f §3.5 침수 단계): 발목 물 = 터널 콘크리트가 비치는 탁한 물(바닥 이음매가 일렁여 보인다) ·
    허리 물 = 바닥이 안 보이는 짙은 녹회색 물 + 기름막 · 떠다니는 부스러기. 잔물결은 가로로 길게(흐름 방향)."""
    base = tunnel_tex(seed)
    a = base.copy()
    rnd = np.random.default_rng(seed + 7)
    nz = equalize(fbm(CELL, [(48, 0.6), (12, 0.4)], seed + 11))
    if not deep:
        ys, xs = np.mgrid[0:CELL, 0:CELL]
        veil = ((xs + ys) % 2 == 0) | (nz > 0.55)                          # 얇은 물막: 바닥 절반이 비친다
        a[veil] = t("P12")
        a[(nz > 0.82) & veil] = t("P13")
        a[base == t("P03")] = t("P11")                                     # 이음매 홈은 물 아래 더 짙게
    else:
        a[:, :] = t("P11")
        a[nz > 0.62] = t("P12")
        a[nz < 0.12] = t("P10")
        for x, y, r2 in scatter(seed + 23, 7):                             # 기름막(무지갯빛 대신 탁한 황록 한 줄)
            if r2.random() < 0.35:
                stamp(a, x, y, ["aab"], {"a": "P43", "b": "P12"})
    for x, y, r2 in scatter(seed + 5, 11):                                 # 가로 잔물결(밝은 윗줄 + 짙은 아랫점)
        if r2.random() < (0.7 if deep else 0.45):
            stamp(a, x, y, ["aaa.", ".bb."], {"a": "P14" if deep else "P15", "b": "P10"})
    for x, y, r2 in scatter(seed + 31, 5):                                 # 떠다니는 부스러기
        if r2.random() < 0.3:
            put(a, x, y, "P19")
    return a


def soil_tex(seed):
    """실내 흙 칸(1-D3 독산 — 무너진 벽 너머 쥐 굴 · 꺼진 냉동실 바닥, SD-14 L423 굴쥐 땅속 이동 칸): 축축한 짙은 흙 + 부서진
    콘크리트 조각 + 쥐가 판 작은 구멍과 긁힌 자국 + 젖은 얼룩. 바깥 흙(dirt)보다 한 단 어둡고 거칠다 — 바닥 타일 사이에서 '여기는 판다'가 읽히게."""
    a = np.full((CELL, CELL), t("P17"), np.uint8)
    nz = equalize(fbm(CELL, [(32, 0.6), (10, 0.4)], seed))
    a[nz < 0.2] = t("P16")
    a[nz > 0.86] = t("P18")
    for x, y, rnd in scatter(seed + 3, 16):                         # 부서진 콘크리트 조각(밝은 윗면 + 그늘)
        if rnd.random() < 0.35:
            stamp(a, x, y, [".aa", "abb", ".cc"], {"a": "P06", "b": "P05", "c": "P03"})
    for x, y, rnd in scatter(seed + 7, 23):                         # 쥐구멍(검은 타원 + 흙 테)
        if rnd.random() < 0.3:
            stamp(a, x, y, [".dd.", "deed", ".dd."], {"d": "P19", "e": "P01"})
    for x, y, rnd in scatter(seed + 11, 9):                         # 발톱 긁힘(짧은 세 줄)
        if rnd.random() < 0.25:
            stamp(a, x, y, ["f.f.f", ".f.f."], {"f": "P16"})
    for x, y, rnd in scatter(seed + 13, 7):                         # 흙 알갱이
        if rnd.random() < 0.5:
            put(a, x, y, "P19" if rnd.random() < 0.5 else "P16")
    return a


def tunnel_tex(seed):
    """지하 연결 통로·배수구 콘크리트(1-4 J-09·J-10): 어둡고 축축한 판 + 물때 얼룩 + 거푸집 이음매 + 짧은 금."""
    a = np.full((CELL, CELL), t("P05"), np.uint8)
    rnd = np.random.default_rng(seed)
    nz = equalize(fbm(CELL, [(40, 0.5), (16, 0.5)], seed))
    a[nz < 0.16] = t("P04")
    a[nz > 0.93] = t("P06")
    # 거푸집 이음매(1-11d 손질): 물길을 가로지르는 세로 줄(암거 · 통로는 가로로 긴 맵 — 이음매는 흐름에 수직),
    # 64px마다 · 줄마다 ±2px 어긋남 · 마디마다 1px 휨 · 군데군데 끊기고 모서리가 떨어져 나간 자국 — 화면 전체를 긋는 곧은 실선(렌더 이음새처럼 보임)이 되지 않게
    for k in range(0, CELL, 64):
        x0 = k + int(rnd.integers(-2, 3))
        y = 0
        while y < CELL:
            seg = int(rnd.integers(6, 22))
            gap = int(rnd.integers(2, 7)) if rnd.random() < 0.6 else 0
            dx = int(rnd.integers(-1, 2)) if rnd.random() < 0.35 else 0
            deep = rnd.random() < 0.35                                    # 깊게 팬 마디만 짙게, 나머지는 바탕보다 한 단만 어둡게
            for j in range(seg):
                yy = y + j
                if yy >= CELL:
                    break
                put(a, (x0 + dx) % CELL, yy, "P03" if deep else "P04")
                if j % 3 != 2:
                    put(a, (x0 + dx + 1) % CELL, yy, "P06")
            if rnd.random() < 0.3:                                    # 모서리 떨어진 자국(이음매 옆 2~3px 홈)
                cy = y + int(rnd.integers(0, max(1, seg)))
                for q in range(int(rnd.integers(2, 4))):
                    put(a, (x0 + dx - 1 - q % 2) % CELL, (cy + q) % CELL, "P04")
            y += seg + gap
    for _ in range(14):
        walk_line(a, rnd, int(rnd.integers(CELL)), int(rnd.integers(CELL)), int(rnd.integers(4, 10)), "P03", hi="P06")
    for _ in range(40):
        x, y = int(rnd.integers(CELL)), int(rnd.integers(CELL))
        put(a, x, y, "P04")
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
    a = cell()                                                       # 수면 반짝임(긴 물결 한 줄)
    stamp(a, 8, 14, [".aaaaaaa.", "b.......b"], {"a": "P37", "b": "P35"})
    stamp(a, 14, 19, ["aaaa"], {"a": "P36"})
    ids["glint"] = add(a)
    a = cell()                                                       # 떠다니는 쓰레기(스티로폼 조각)
    stamp(a, 12, 14, ["kkkkk", "kaabk", "kbbbk", ".kkk."], {"k": "P04", "a": "P09", "b": "P07"})
    ids["float"] = add(a)
    a = cell()                                                       # 갈대 포기(SD-08 §7.4 갈대 둔치)
    stamp(a, 9, 9, ["a..a...a", "a.ba..ba", "ab.a.b.a", ".bab.ba.", ".bbbbbb.", "..kkkk.."],
          {"a": "P21", "b": "P31", "k": "P16"})
    ids["reeds"] = add(a)
    a = cell()                                                       # 잔해 철근
    stamp(a, 8, 13, ["a.......", ".a......", "..aaaaaa", ".......b"], {"a": "P24", "b": "P23"})
    stamp(a, 18, 18, ["kkkk", "kaak", "kkkk"], {"k": "P03", "a": "P07"})
    ids["rebar"] = add(a)
    return D, ids


# ---------------------------------------------------------------- 세트 정의
def sets():
    import tiles_isaac as TI
    D, did = decals()
    r01 = {
        "materials": [
            # spread: 경계 물결 폭(px) · pri: 위아래(높은 재질이 위) · rim: 위 재질 테두리(px) · shade: 아래 재질 그늘(px)
            # vthr: B 벌 문턱(클수록 B가 적다) · dens: 잔 소품 밀도(%) · hard: 섞지 않음 · boff: B 벌을 읽는 어긋남
            dict(name="dirt", A=dirt_tex(101), B=dirt_tex(101, damp=True), spread=8, soft=1, pri=4, rim=0, shade=2, vthr=160, dens=16,
                 decals=["dirt_lt1", "dirt_lt2", "dirt_dk1", "pebbles", "rock", "leaves", "bone", "can"], hard=0, boff=(97, 61)),
            dict(name="grass_sparse", A=grass_tex(111, False), B=grass_tex(111, False, dry=True), spread=8, soft=1, pri=6, rim=0, shade=1,
                 vthr=150, dens=14, decals=["dirt_lt1", "grass_dk1", "flowers", "pebbles", "clover", "bush"], hard=0, boff=(141, 83)),
            dict(name="grass_dense", A=grass_tex(121, True), B=grass_tex(121, True, dry=True), spread=8, soft=1, pri=7, rim=1, shade=1,
                 vthr=165, dens=16, decals=["grass_lt1", "grass_lt2", "grass_dk1", "bush", "flowers", "clover"], hard=0, boff=(59, 173)),
            dict(name="asphalt", A=asphalt_tex(131), B=asphalt_tex(131, worn=True), spread=2, pri=9, rim=1, shade=2, vthr=140, dens=14,
                 decals=["asph_lt1", "asph_dk1", "oil", "debris", "pothole", "patch", "paper"], hard=0, boff=(113, 37)),
            dict(name="pavers", A=sidewalk_tex(141), B=None, spread=0, pri=10, rim=1, shade=0, vthr=256, dens=6, curb=4,
                 decals=["paper", "butts", "leaves"], hard=1),                # 보도: 네모 콘크리트 판 + 차도 쪽 화강암 연석 4px(1-R v2)
            dict(name="stairs", A=tile_tex(TI.stairs()), B=tile_tex(TI.stairs()), spread=0, pri=11, rim=0, shade=0, vthr=255, dens=0,
                 decals=[], hard=1),
            dict(name="stairs_rail", A=tile_tex(TI.stairs_rail()), B=tile_tex(TI.stairs_rail()), spread=0, pri=11, rim=0, shade=0, vthr=255,
                 dens=0, decals=[], hard=1),
            # 0-10: 골목·데크 콘크리트(64px 타설 이음매 + 미끄럼 홈 대신 얼룩·금) — 봉천 골목·볼트 데크
            dict(name="concrete", A=concrete_out_tex(151), B=None, spread=0, pri=10, rim=1, shade=1, vthr=256, dens=8,
                 decals=["paper", "butts", "leaves"], hard=1),
            # 1-1 월드(높이: 수면 < 진흙 < 흙 < 암반 < 풀 < 잔해·자갈 < 아스팔트 < 보도, SD-16 §6.4)
            dict(name="water_deep", A=water_tex(161, "P33", "P34", "P33"), B=None, spread=8, pri=0, rim=0, shade=0, vthr=256, dens=6,
                 decals=["glint", "float"], hard=0),
            dict(name="water_mid", A=water_tex(171, "P34", "P35", "P33"), B=None, spread=8, pri=1, rim=0, shade=0, vthr=256, dens=7,
                 decals=["glint", "float"], hard=0),
            dict(name="water_shallow", A=water_tex(181, "P35", "P36", "P34"), B=None, spread=6, pri=2, rim=0, shade=1, vthr=256, dens=8,
                 decals=["glint", "float", "reeds"], hard=0),
            dict(name="mud", A=mud_tex(191), B=None, spread=8, soft=1, pri=3, rim=1, shade=2, vthr=256, dens=14,
                 decals=["reeds", "reeds", "damp", "pebbles", "can"], hard=0),
            dict(name="rock", A=rock_tex(195), B=None, spread=6, soft=1, pri=5, rim=1, shade=1, vthr=256, dens=8,
                 decals=["rock", "pebbles", "leaves"], hard=0),
            dict(name="rubble", A=rubble_tex(197), B=None, spread=6, soft=1, pri=8, rim=1, shade=1, vthr=256, dens=12,
                 decals=["rebar", "rock", "debris", "can", "paper"], hard=0),
            dict(name="ballast", A=ballast_tex(199), B=None, spread=2, pri=8, rim=1, shade=1, vthr=256, dens=4,
                 decals=["can", "paper"], hard=0),
        ],
        "mat_of": {"dirt_a": 0, "dirt_b": 0, "dirt_grass_a": 2, "dirt_grass_b": 1, "asphalt": 3, "asphalt_lane": 3,
                   "pavers": 4, "pavers_b": 4, "stairs": 5, "stairs_rail": 6, "concrete_o": 7,
                   "water_deep": 8, "water_mid": 9, "water_shallow": 10, "mud": 11, "rock_floor": 12, "rubble": 13, "ballast": 14},
        "force": {"asphalt_lane": "lane"},
        "road": {"asphalt": 3, "pavers": 4, "median": 2, "concrete": 7},
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
            # 1-4 지하시장: 인조석 물갈기 바닥 · 지하 통로 콘크리트
            dict(name="terrazzo", A=terrazzo_tex(301), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=2,
                 decals=["paper", "butts"], hard=1),
            dict(name="tunnel", A=tunnel_tex(311), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=4,
                 decals=["puddle", "debris", "rust"], hard=1),
            # 1-5 여의도 벙커: 콘크리트 계단 · 회녹색 칠 바닥
            dict(name="steps", A=steps_tex(321), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=1,
                 decals=["debris"], hard=1),
            dict(name="epoxy", A=epoxy_tex(331), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=2,
                 decals=["paper", "debris"], hard=1),
            # 1-11i 고척 돔: 그라운드 인조 잔디
            dict(name="turf", A=turf_tex(341), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=3,
                 decals=["paper", "debris", "can"], hard=1),
            # 1-D 던전: 침수 바닥(발목 · 허리) — 이동 ×0.8 · ×0.6(웅크림 불가), SD-09f §3.5
            dict(name="flood", A=flood_tex(351), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=2,
                 decals=["debris"], hard=1),
            dict(name="flood_deep", A=flood_tex(361, deep=True), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=1,
                 decals=[], hard=1),
            # 1-D3 독산: 실내 흙 칸(굴쥐가 파고드는 바닥)
            dict(name="soil", A=soil_tex(371), B=None, spread=0, pri=0, rim=0, shade=1, vthr=256, dens=3,
                 decals=["debris"], hard=1),
        ],
        "mat_of": {"panel": 0, "panel_sheen": 0, "panel_scuff": 0, "guide_h": 0, "guide_v": 0, "guide_x": 0, "guide_t": 0, "grate_a": 1, "grate_b": 1, "grate_c": 1,
                   "lino_a": 2, "lino_b": 2, "clinic_a": 3, "clinic_b": 3, "concrete_a": 4, "carpet_a": 5, "wood_a": 6,
                   "panel_mold": 7, "grate_mold": 8, "jangpan_a": 9, "terrazzo_a": 10, "tunnel_a": 11, "steps_a": 12, "epoxy_a": 13, "turf_a": 14,
                   "flood_a": 15, "flood_b": 16, "soil_a": 17},
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
        self.soft = np.array([d.get("soft", 0) for d in mats], np.int64)
        self.curb = np.array([d.get("curb", 0) for d in mats], np.int64)      # 연석 띠(px): 낮은 재질과 만나는 가장자리 — 차도 쪽 테 · 화강암 · 점 · 안쪽 이음매      # 자연 재질(흙·풀·진흙·바위·잔해): 서로 만나면 테 없이 디더로 섞는다
        self.boff = np.array([d.get("boff", (0, 0)) for d in mats], np.int64)
        self.dlist = np.full((self.M, 8), 0, np.int64)
        self.dcount = np.zeros(self.M, np.int64)
        for m, d in enumerate(mats):
            for i, n in enumerate(d["decals"][:8]):
                self.dlist[m, i] = did[n]
            self.dcount[m] = len(d["decals"][:8])
        n_ids = max(tile_ids.values()) + 1
        self.mat_of = np.zeros(64, np.int64)                             # 타일 번호 → 재질(1-4: 32 → 64칸, 셰이더 mat_of[64])
        self.force = np.full(64, -1, np.int64)
        self.flag_of = np.zeros(64, np.int64)
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
        rd = spec.get("road")                                            # 도로 경계 v3: 차도 · 보도 · 분리대 화단 재질과 위계별 차도 반폭 · 분리대 반폭(px)
        self.rd_mat = (rd["asphalt"], rd["pavers"], rd["median"], rd["concrete"]) if rd else None
        self.rd_car = np.array(RD_CAR, np.int64)
        self.rd_med = np.array(RD_MED, np.int64)

    # ---------------- 정수 합성(셰이더와 같은 식)
    def render(self, ids, deco, ox, oy, x0, y0, w, h, flags=None, edge=None):
        """ids·deco: 타일 격자 [ty][tx](deco = 덮개 아틀라스 번호, 없으면 -1), 격자 (0,0) = 월드 타일 (ox, oy).
        flags를 주면 deco 대신 덮개 값(0 없음 · 1 벽 · 2 소품 · 3 평평한 구조물: 섞지 않고 그늘도 없음)을 바로 쓴다.
        flags 위 3비트 = 도로 위계(도로 경계 v3), edge = (연석선 거리 바이트, 보도 바깥선 거리 바이트) — 칸 왼쪽 위 꼭짓점 값.
        반환: 월드 픽셀 (x0..x0+w, y0..y0+h) RGBA."""
        ids = np.asarray(ids, np.int64)
        flags_raw = np.asarray(flags, np.int64) if flags is not None else self.flag_of_tile(np.asarray(deco, np.int64))
        flags = flags_raw & 3
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
        # 자연 재질끼리(바이옴 전이, 리드 지시 2026-10-15 '경계선 없이 점진적으로'): 테두리·그늘 띠 없이, 경계에서 10px 안쪽까지
        # 2×2px 조각 디더로 섞는다(경계 위 50% → 멀어질수록 0%). 길·포장·물가는 오토타일 테 그대로
        both_soft = has2 & (self.soft[win_m] == 1) & (self.soft[sec_c] == 1)
        band = np.where(both_soft, 0, band)
        dark = has2 & (band > 0) & (margin < band * 768) & (self.curb[win_m] == 0)   # 연석 재질은 연석 띠가 테두리를 대신한다
        DB = 7680
        p_mix = np.where(both_soft & (margin < DB), ((DB - np.minimum(margin, DB)) * 128) // DB, 0)
        hp = (thash(X >> 1, Y >> 1) >> 5) & 255
        win_m = np.where(hp < p_mix, sec_c, win_m)
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
        walld = deep | ((fN == 1) & (fy < 5)) | ((fW == 1) & (fx < 2)) | ((fE == 1) & (fx > 29)) | ((f0 == 2) & (q0 <= 6084)) | ((fN == 2) & (q1 <= 6084))
        # 연석(1-R v2): 자기 타일이 연석 재질이고 이웃 타일이 더 낮은 재질(벽 · 구조물 덮개 제외)이면 그 쪽 타일 가장자리에서 cw px — 곧은 띠 · 바깥 모서리는 네모
        cw = self.curb[m0]

        def lowp(cx, cy):
            return (self.pri[self.mat_of[at(ids, cx, cy)]] < self.pri[m0]) & ~np.isin(at(flags, cx, cy), (1, 3))
        lN, lS, lW, lE = lowp(tx, ty - 1), lowp(tx, ty + 1), lowp(tx - 1, ty), lowp(tx + 1, ty)
        dd = np.full(X.shape, 99, np.int64)
        dd = np.where(lN, np.minimum(dd, fy), dd)
        dd = np.where(lS, np.minimum(dd, 31 - fy), dd)
        dd = np.where(lW, np.minimum(dd, fx), dd)
        dd = np.where(lE, np.minimum(dd, 31 - fx), dd)
        for (ox_, oy_, a_, b_) in ((-1, -1, lN, lW), (1, -1, lN, lE), (-1, 1, lS, lW), (1, 1, lS, lE)):
            cd = np.maximum(fx if ox_ < 0 else 31 - fx, fy if oy_ < 0 else 31 - fy)
            dd = np.where(lowp(tx + ox_, ty + oy_) & ~a_ & ~b_, np.minimum(dd, cd), dd)
        curb_on = (cw > 0) & (win_m == m0) & (dd < cw)
        ck = np.where(dd == 0, 0, np.where(dd == cw - 1, 3, np.where(((thash(X, Y) >> 7) & 7) == 0, 2, 1)))
        curb_px = np.array(CURB_COL + [int(DARK[k]) for k in CURB_COL], np.int64)[ck + 4 * walld.astype(np.int64)]
        # 도로 경계 v3(리드 지시 2026-10-18 '실제 도로 경계처럼'): 간선 둘레 칸은 꼭짓점 거리(연석선 E · 보도 바깥선 S)를 이중선형으로 이어
        # 차도 · 배수 그늘 · 연석(곧은 한 줄) · 같은 폭 보도 · 바깥 테 · 중앙분리대(양쪽 연석 + 화단) · 노란 겹 중앙선(닳음)을 픽셀마다 정한다
        paint = np.zeros(X.shape, bool)
        pcol = np.zeros(X.shape, np.int64)
        if edge is not None and self.rd_mat is not None:
            eb, ea = np.asarray(edge[0], np.int64), np.asarray(edge[1], np.int64)
            rc = (at(flags_raw, tx, ty) >> 2) & 7
            on = (rc > 0) & (rc <= 5)
            ex1, ey1 = 2 * fx + 1, 2 * fy + 1
            ex0, ey0 = 64 - ex1, 64 - ey1
            q = [(tx, ty, ex0 * ey0), (tx + 1, ty, ex1 * ey0), (tx, ty + 1, ex0 * ey1), (tx + 1, ty + 1, ex1 * ey1)]
            E = sum(wq * (at(eb, cx, cy) - 96) for cx, cy, wq in q)               # 연석선까지 px × 2048(음수 = 차도)
            S = sum(wq * (at(ea, cx, cy) - 96) for cx, cy, wq in q)               # 보도 바깥선까지 px × 2048
            K = 2048
            asp, pav, medm = self.rd_mat[:3]
            car = self.rd_car[rc]
            mh = self.rd_med[rc]
            sg = [1 - 2 * ((at(flags_raw, cx, cy) >> 5) & 1) for cx, cy, _ in q]   # 꼭짓점이 중앙선 어느 쪽 — 부호 있는 거리로 이어야 분리대 · 중앙선이 곧다
            c = np.abs(sum(wq * sg[i] * (at(eb, cx, cy) - 96 + car // 2) for i, (cx, cy, wq) in enumerate(q)))   # 중앙선까지
            road = on & (E < 0)
            med = road & (mh > 0) & (c < mh * K)
            m_in = mh * K - c
            med_curb = med & (m_in < 2 * K)
            cline = road & ~med & (mh == 0) & (rc <= 4) & (c >= K) & (c < 3 * K) & (R[(Y >> 2) & 255, (X >> 2) & 255] >= 70)
            gutter = road & ~med & (E >= -2 * K)
            CW = RD_CURB
            kerb = on & (E >= 0) & (E < CW * K)
            walk = on & (E >= CW * K) & (S < 0)
            edging = walk & (S >= -K)
            outside = on & ~road & ~kerb & ~walk
            isrd = lambda m: (m == asp) | (m == pav)
            a00, a10, a01, a11 = at(ea, tx, ty), at(ea, tx + 1, ty), at(ea, tx, ty + 1), at(ea, tx + 1, ty + 1)
            gx, gy = (a10 + a11) - (a00 + a01), (a01 + a11) - (a00 + a10)
            hx = np.abs(gx) >= np.abs(gy)
            m_out = self.mat_of[at(ids, tx + np.where(hx, np.sign(gx), 0), ty + np.where(hx, 0, np.sign(gy)))]
            sub = np.where(isrd(m0), m_out, m0)
            sub = np.where(isrd(sub), 0, sub)
            nm = np.where(road & ~med, asp, win_m)
            nm = np.where(med, medm, nm)
            nm = np.where(walk, pav, nm)
            local = ((at(flags_raw, tx, ty) >> 6) & 1) == 1                  # 동네 길 칸: 보도 바깥 아스팔트는 그 길 몫
            nm = np.where(outside & isrd(win_m) & ~local, sub, nm)
            win_m = np.where(on, nm, win_m)
            dark = np.where(on, walld | gutter | edging | (outside & dark), dark)
            curb_on = curb_on & ~on
            kd = np.maximum(E, 0) // K
            kk = np.where(kd == 0, 0, np.where(kd == CW - 1, 3, np.where(((thash(X, Y) >> 7) & 7) == 0, 2, 1)))
            md = np.maximum(m_in, 0) // K
            wd = 4 * walld.astype(np.int64)
            rgb = np.array(CURB_COL + [int(DARK[k]) for k in CURB_COL] + [RD_LINE, int(DARK[RD_LINE])], np.int64)
            pcol = np.where(kerb, rgb[kk + wd], pcol)
            pcol = np.where(med_curb, rgb[np.where(md == 0, 0, 1) + wd], pcol)
            pcol = np.where(cline, rgb[8 + walld.astype(np.int64)], pcol)
            paint = kerb | med_curb | cline
            # 동네 길 · 콘크리트 골목(위계 6): B = 길 가장자리, A = 골목 가장자리 — 곧은 가장자리 + 길 쪽 3px 콘크리트 측구(바깥 1px 이음 그늘)
            lo = rc == 6
            conc = self.rd_mat[3]
            L, LA = E, S
            st = lo & (L < 0)
            gut = lo & (L >= 0) & (L < RD_GUT * K)
            al = lo & ~st & ~gut & (LA < 0)
            lout = lo & ~st & ~gut & ~al
            isl = lambda m: (m == asp) | (m == pav) | (m == conc)
            b00, b10, b01, b11 = at(eb, tx, ty), at(eb, tx + 1, ty), at(eb, tx, ty + 1), at(eb, tx + 1, ty + 1)
            useb = L <= LA
            lgx = np.where(useb, (b10 + b11) - (b00 + b01), gx)
            lgy = np.where(useb, (b01 + b11) - (b00 + b10), gy)
            lhx = np.abs(lgx) >= np.abs(lgy)
            l_out = self.mat_of[at(ids, tx + np.where(lhx, np.sign(lgx), 0), ty + np.where(lhx, 0, np.sign(lgy)))]
            lsub = np.where(isl(m0), l_out, m0)
            lsub = np.where(isl(lsub), 0, lsub)
            nm = np.where(st, asp, win_m)
            nm = np.where(gut | al, conc, nm)
            nm = np.where(lout & isl(win_m), lsub, nm)
            win_m = np.where(lo, nm, win_m)
            dark = np.where(lo, walld | (gut & (L < K)) | (al & (LA >= -K)) | (lout & dark), dark)
            curb_on = curb_on & ~lo
        # A·B 벌
        oxm, oym = (win_m * 73) & 255, (win_m * 151) & 255
        var = (B[(Y + oym) & 255, (X + oxm) & 255] > self.vthr[win_m]).astype(np.int64)
        level = np.where(deep, 2, np.where(dark, 1, 0))
        col = var + 2 * level
        bx, by = self.boff[win_m, 0] * var, self.boff[win_m, 1] * var        # B 벌은 어긋난 자리에서 읽는다(되풀이 주기 깨기)
        out = self.atlas[win_m * CELL + ((Y + by) & (CELL - 1)), col * CELL + ((X + bx) & (CELL - 1))].astype(np.int64)
        out = np.where(curb_on, curb_px, out)
        out = np.where(paint, pcol, out)
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
        use = has & inside & (dv != 255) & ~paint
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
                "rim": self.rim.tolist(), "shade": self.shade.tolist(), "curb": self.curb.tolist(),
                "curb_rgb": [int(c) for i in CURB_COL + [int(DARK[k]) for k in CURB_COL] + [RD_LINE, int(DARK[RD_LINE])] for c in PAL[i]],
                "rd_mat": list(self.rd_mat) if self.rd_mat else [-1, -1, -1, -1], "rd_car": RD_CAR, "rd_med": RD_MED, "rd_curb": RD_CURB,
                "vthr": self.vthr.tolist(), "boff": self.boff.ravel().tolist(), "dens": self.dens.tolist(), "hard": self.hard.tolist(), "soft": self.soft.tolist(),
                "dlist": self.dlist.ravel().tolist(), "dcount": self.dcount.tolist(), "mat_of": self.mat_of.tolist(),
                "force": self.force.tolist(), "flag_of": self.flag_of.tolist()}
        json.dump(meta, open(os.path.join(out_dir, f"ground_{self.name}.json"), "w"), indent=1)


CURB_COL = [t("P04"), t("P08"), t("P07"), t("P06")]                  # 연석: 차도 쪽 테 · 화강암 몸 · 점 · 안쪽 이음매(그늘 벌은 DARK로 한 단씩)
RD_CURB = 4                                                          # 도로 경계 v3 연석 폭(px)
RD_GUT = 3                                                           # 동네 길 측구(L형 콘크리트) 폭(px)
RD_LINE = t("P48")                                                   # 노란 겹 중앙선(바랜 황토 — 닳은 자리는 비움)
# 위계(0 없음 · 1 H4 · 2 H3 · 3 H2 · 4 H1 · 5 교차로)별 차도 반폭 · 분리대 반폭(px) — road_net.SECTION(칸) × 16
RD_CAR = [0, 64, 80, 96, 160, 0, 0, 0]
RD_MED = [0, 0, 0, 16, 16, 0, 0, 0]


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
