"""전역 기본 지형 굽기(단계 1-1, SD-19 §5.4 '전역 기본 지형 1,230청크 자동 굽기', SD-16 §6.7, SD-08 §3·§6).
원자료 game/data/world/source.json(world_extract.py) → 월드 래스터(2,120×1,720타일) → 미리보기·청크 자료.
굽기 순서(SD-16 §6.7): 지형 고도 → 수면 → 도로 → 블록(필지) → 프리팹 → 소품 → 다듬기. 이 파일은 1~3단계(고도·수면·도로·철도·성곽·땅 쓰임).

래스터 칸 종류(kind):
  0 맵 밖 · 1 땅 · 2 깊은 물 · 3 중간 물 · 4 얕은 물 · 5 둔치 · 6 제방(콘크리트 사면) · 7 차도 · 8 보도 · 9 중앙분리대
  10 철로 · 11 성곽 · 12 섬(한강 안의 땅)
땅 쓰임(use): 0 시가지 · 1 구릉(50~149m, 경사만) · 2 산지(150m+, 암벽 단) · 3 도심 밀폐(R05) · 4 평야(R10) · 5 강(HR 물·둔치)
python3 tools/pipeline/world_bake.py [--preview art/samples/43_world_bake.png]
"""
import os, sys, json, math
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "game", "data", "world", "source.json")
CS = 40
W, H = 53 * CS, 43 * CS
REG_CODES = ["", "R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "HR"]

# 간선도로 차로 수(SD-16 §6.7 '차로 1개 = 2타일, 왕복 8차로 = 16타일 + 중앙분리대 1 + 보도 각 2').
# 원문은 차로 수를 적지 않았다 — 실제 도로 규모를 따른 값(구현 정합, STAGE_1.md 1-1). 자동차 전용도로는 보도가 없다.
ROAD_LANES = {"올림픽대로": (8, False), "강변북로": (8, False), "내부순환로": (4, False), "동부간선도로": (6, False),
              "서부간선도로": (6, False), "경부고속도로": (8, False), "남부순환로": (6, True), "세종대로": (10, True),
              "종로": (6, True), "통일로": (6, True), "도봉로": (6, True), "천호대로": (6, True), "강남대로": (10, True),
              "테헤란로": (10, True)}
# 지천 수면 폭(SD-08 §6.2): 안양·중랑·탄천 6~10 · 홍제·불광·도림·양재·우이 3~5 · 청계천 협곡 10~14 · 샛강 4~6
RIVER_W = {"안양천": 8, "중랑천": 9, "탄천": 8, "홍제천": 4, "불광천": 4, "도림천": 4, "양재천": 4, "우이천": 4, "청계천": 12, "샛강": 5}
# 한강 섬(SD-08 §8.7): 장소 좌표 중심 타원(반지름 타일)
ISLANDS = {"L-HR-01": (10, 5), "L-R04-19": (8, 4), "L-R04-01": (9, 6)}


def chaikin(pts, n=3):
    p = np.asarray(pts, float)
    for _ in range(n):
        q = 0.75 * p[:-1] + 0.25 * p[1:]
        r = 0.25 * p[:-1] + 0.75 * p[1:]
        mid = np.empty((len(q) * 2, 2))
        mid[0::2] = q
        mid[1::2] = r
        p = np.vstack([p[:1], mid, p[-1:]])
    return p


def chunk_path(path):
    return [(x * CS + CS / 2, y * CS + CS / 2) for x, y in path]


def densify(p, step=4.0):
    out = [p[0]]
    for a, b in zip(p[:-1], p[1:]):
        d = np.hypot(*(b - a))
        n = max(1, int(d / step))
        for k in range(1, n + 1):
            out.append(a + (b - a) * k / n)
    return np.array(out)


def smooth(p, win):
    """이동 평균(양끝 고정): 청크 경로의 계단 모양을 편다. win = 점 수(홀수)"""
    p = np.asarray(p, float)
    if len(p) < 3 or win < 3:
        return p
    k = win // 2
    pad = np.vstack([np.repeat(p[:1], k, 0), p, np.repeat(p[-1:], k, 0)])
    c = np.cumsum(np.vstack([np.zeros((1, 2)), pad]), 0)
    out = (c[win:] - c[:-win]) / win
    out[0], out[-1] = p[0], p[-1]
    return out


def line_of(path, win_tiles):
    """청크 경로 → 칸 폴리선: 3타일 간격으로 펴고 win_tiles 길이 이동 평균"""
    return smooth(densify(np.asarray(chunk_path(path), float), 3.0), max(3, int(win_tiles / 3) | 1))


def dist_field(poly, reach, field=None, value=None):
    """폴리선에서의 거리(reach 안만 계산). field가 주어지면 더 가까운 칸에 value(폴리선 위치별 값 배열)를 적는다."""
    d = np.full((H, W), np.inf, np.float32)
    for i, (a, b) in enumerate(zip(poly[:-1], poly[1:])):
        x0, x1 = int(max(0, min(a[0], b[0]) - reach)), int(min(W - 1, max(a[0], b[0]) + reach))
        y0, y1 = int(max(0, min(a[1], b[1]) - reach)), int(min(H - 1, max(a[1], b[1]) + reach))
        if x1 < x0 or y1 < y0:
            continue
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1].astype(np.float32)
        xs += 0.5
        ys += 0.5
        ab = b - a
        L2 = float(ab @ ab) or 1e-6
        t = np.clip(((xs - a[0]) * ab[0] + (ys - a[1]) * ab[1]) / L2, 0, 1)
        dd = np.hypot(xs - (a[0] + t * ab[0]), ys - (a[1] + t * ab[1]))
        sub = d[y0:y1 + 1, x0:x1 + 1]
        better = dd < sub
        sub[better] = dd[better]
        if field is not None:
            fv = value[i] + (value[i + 1] - value[i]) * t
            fs = field[y0:y1 + 1, x0:x1 + 1]
            fs[better] = fv[better]
    return d


def bake(src):
    rng = np.random.default_rng(277)
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    xs += 0.5
    ys += 0.5

    # 권역(청크 → 칸)
    reg_chunk = np.zeros((43, 53), np.uint8)
    for k, code in src["region"].items():
        x, y = map(int, k.split(","))
        reg_chunk[y, x] = REG_CODES.index(code)
    region = np.repeat(np.repeat(reg_chunk, CS, 0), CS, 1)
    play = region > 0
    # 경계 띠(SD-08 §4.5): 플레이 영역 바깥 1청크 — 경계 지형, 그 밖은 그리지 않음
    band_chunk = np.zeros_like(reg_chunk, bool)
    pc = reg_chunk > 0
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            band_chunk |= np.roll(np.roll(pc, dy, 0), dx, 1)
    band_chunk &= ~pc
    band = np.repeat(np.repeat(band_chunk, CS, 0), CS, 1)

    # ① 고도: 산 정상 원뿔 h = H × max(0, 1 − d/R), R(km) = 0.6 + H/1000 × 2.4 (SD-08 §6.1), 1타일 = 18.5m
    peaks = [(p["tx"], p["ty"], p["h"]) for p in src["peaks"] if "h" in p]
    by_name = {p["name"]: p for p in src["peaks"]}
    ridges = [("북한산 백운대", "북한산 보현봉"), ("북한산 백운대", "북한산 비봉"), ("북한산 보현봉", "북한산 비봉"),
              ("관악산 연주봉", "삼성산"), ("도봉산 자운봉", "수락산"), ("수락산", "불암산"), ("청계산 매봉", "구룡산"),
              ("우면산", "구룡산"), ("구룡산", "대모산")]                      # 보조 능선점 9개(SD-08 §6.1) — 같은 산줄기 두 봉우리 사이
    for a, b in ridges:
        if a in by_name and b in by_name:
            pa, pb = by_name[a], by_name[b]
            peaks.append(((pa["tx"] + pb["tx"]) / 2, (pa["ty"] + pb["ty"]) / 2, 0.72 * min(pa["h"], pb["h"])))
    hgt = np.zeros((H, W), np.float32)
    for px, py, hh in peaks:
        R = (0.6 + hh / 1000.0 * 2.4) * 1000.0 / 18.5
        x0, x1 = int(max(0, px - R)), int(min(W, px + R + 1))
        y0, y1 = int(max(0, py - R)), int(min(H, py + R + 1))
        d = np.hypot(xs[y0:y1, x0:x1] - px, ys[y0:y1, x0:x1] - py)
        np.maximum(hgt[y0:y1, x0:x1], hh * np.clip(1 - d / R, 0, 1), out=hgt[y0:y1, x0:x1])
    # 원문 고도 격자(청크 중심 등급)에 맞춘다: 청크 중심의 어긋남을 등급 범위로 끌어오는 보정장을 이중선형으로 펴서 더한다
    cls = src["elev_class"]
    corr = np.zeros((43, 53), np.float32)
    for k, ch in src["elev_grid"].items():
        x, y = map(int, k.split(","))
        lo, hi = cls.get(ch, [0, 900])
        c = hgt[y * CS + CS // 2, x * CS + CS // 2]
        corr[y, x] = (lo + 10 - c) if c < lo else ((hi - 10 - c) if c > hi else 0)
    gy = (ys / CS - 0.5).clip(0, 42)
    gx = (xs / CS - 0.5).clip(0, 52)
    iy, ix = gy.astype(int), gx.astype(int)
    fy, fx = gy - iy, gx - ix
    iy1, ix1 = np.minimum(iy + 1, 42), np.minimum(ix + 1, 52)
    cf = (corr[iy, ix] * (1 - fx) * (1 - fy) + corr[iy, ix1] * fx * (1 - fy) + corr[iy1, ix] * (1 - fx) * fy + corr[iy1, ix1] * fx * fy)
    hgt = np.maximum(0, hgt + cf)

    kind = np.where(play | band, 1, 0).astype(np.uint8)

    # ② 수면: 한강(청크 경로 + 다리 25곳의 중점으로 당김), 지천, 섬
    han = next(r for r in src["rivers"] if r["name"].startswith("한강"))
    P = line_of(han["path"][::-1], 150)                                  # 서 → 동
    s = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(P, axis=0).T))])
    pulls = []
    for b in src["bridges"]:
        M = (np.array(b["n"], float) + np.array(b["s"], float)) / 2
        i = int(np.argmin(np.hypot(*(P - M).T)))
        pulls.append((s[i], M - P[i], float(np.clip(b["len"] - 14, 36, 44))))
    pulls.sort()
    ss = np.array([p[0] for p in pulls])
    off = np.stack([np.interp(s, ss, [p[1][0] for p in pulls]), np.interp(s, ss, [p[1][1] for p in pulls])], 1)
    wid = np.interp(s, ss, [p[2] for p in pulls])
    P = smooth(P + off, 9)
    s2 = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(P, axis=0).T))])
    wid = np.interp(s2 / s2[-1] * s[-1], s, wid)
    half = np.zeros((H, W), np.float32)
    dh = dist_field(P, 40, half, wid / 2)
    river = dh <= half
    deep = dh <= half * 0.45
    mid = (dh <= half * 0.78) & ~deep
    bank = (dh <= half + 5) & ~river                                       # 둔치 5타일(SD-08 §6.2: 4~7)
    levee = (dh <= half + 7) & ~river & ~bank                              # 제방 2타일
    kind[bank & (kind > 0)] = 5
    kind[levee & (kind > 0)] = 6
    kind[river] = 4
    kind[mid] = 3
    kind[deep] = 2
    hgt[river | bank] = 0
    for r in src["rivers"]:
        nm = r["name"]
        if nm.startswith("한강"):
            continue
        wv = next((v for k, v in RIVER_W.items() if nm.startswith(k)), 4)
        Q = line_of(r["path"], 60)
        if nm.startswith("샛강"):                                          # 샛강은 한강 남쪽 갈래: 여의도 남쪽 끝을 따라 양끝이 한강에 닿게
            Q = np.vstack([[Q[0][0] - 30, Q[0][1] - 25], Q, [Q[-1][0] + 40, Q[-1][1] - 30]])
        d = dist_field(Q, wv)
        water = (d <= wv / 2) & (kind > 0) & (kind != 2) & (kind != 3)
        kind[water & ~river] = 4
        hgt[water] = np.minimum(hgt[water], 20)
    for lid, (rx, ry) in ISLANDS.items():
        p = next(q for q in src["places"] if q["lid"] == lid)
        isl = ((xs - p["tx"]) / rx) ** 2 + ((ys - p["ty"]) / ry) ** 2 <= 1.0
        kind[isl & (kind >= 2) & (kind <= 4)] = 12

    # ③ 도로(SD-16 §6.7): 차로 2타일 · 중앙분리대 1 · 보도 각 2. 강물 위는 다리가 아니면 끊긴다(다리는 다음 단계)
    elevated = np.zeros((H, W), bool)
    for r in src["roads"]:
        lanes, walk = next((v for k, v in ROAD_LANES.items() if r["name"].startswith(k)), (4, True))
        Q = line_of(r["path"], 90)
        carriage = lanes * 2 + (1 if lanes >= 6 else 0)
        full = carriage + (4 if walk else 0)
        d = dist_field(Q, full)
        land = (kind == 1) | (kind == 5) | (kind == 6)
        road = (d <= carriage / 2) & land
        kind[road] = 7
        if lanes >= 6:
            kind[(d <= 0.6) & land] = 9
        if walk:
            kind[(d > carriage / 2) & (d <= full / 2) & land] = 8
        if "고가" in r["name"]:
            elevated[(d <= carriage / 2) & (play | band)] = True
    # 철도: 지상 구간만(SD-08 §6.4). 2호선 순환은 지상·지하가 섞여 있으나 원문이 구간을 나누지 않았다 → 지상 1호선만(구현 정합)
    for r in src["rails"]:
        if "지상" not in r["name"]:
            continue
        Q = line_of(r["path"], 90)
        d = dist_field(Q, 6)
        kind[(d <= 2.5) & (kind == 1)] = 10
    # 한양도성: 성문 8 + 내사산 4를 잇는 고리(성문 좌표 SD-08 §5.3 — 청크 경로보다 정밀)
    ring_names = ["숭례문", "소의문 터", "돈의문 터", "인왕산", "창의문", "북악산", "숙정문", "혜화문", "낙산", "흥인지문", "광희문", "남산"]
    allp = {p["name"]: p for p in src["boundary"] + src["peaks"]}
    ring = [(allp[n]["tx"], allp[n]["ty"]) for n in ring_names if n in allp]
    ring.append(ring[0])
    Q = densify(chaikin(ring, 2), 2.0)
    d = dist_field(Q, 3)
    wall = (d <= 1.0) & (kind > 0) & ~np.isin(kind, (7, 8, 9))            # 도로가 지나는 곳은 성벽이 끊겨 있다(현대 서울과 같다)
    for n in ring_names:                                                   # 성문 자리(SD-08 §5.3 '문' 8곳): 문 칸 3타일은 지나간다
        if n.endswith("문") or n.endswith("문 터"):
            p = allp.get(n)
            if p:
                wall &= ((xs - p["tx"]) ** 2 + (ys - p["ty"]) ** 2) > 2.6 ** 2
    kind[wall] = 11

    # 땅 쓰임
    use = np.zeros((H, W), np.uint8)
    use[hgt >= 50] = 1
    use[hgt >= 150] = 2
    use[region == REG_CODES.index("R05")] = 3
    use[(region == REG_CODES.index("R10")) & (hgt < 50)] = 4
    use[(kind >= 2) & (kind <= 6)] = 5
    # 높이 단(SD-08 §6.1·SD-16 §6.5): 150m 미만은 경사만(단 0), 150m부터 50m마다 암벽 1단
    level = np.where(hgt >= 150, ((hgt - 150) // 50 + 1), 0).astype(np.int8)
    return {"kind": kind, "hgt": hgt.astype(np.int16), "level": level, "use": use, "region": region, "elevated": elevated,
            "play": play, "band": band}


# ④ 블록·필지(SD-16 §6.6 프리팹 층의 자리): 동네 길로 블록을 나누고 권역 성격대로 건물 발자국을 놓는다.
# 건물 양식(style): 빌라·아파트(판상형)·상가·업무(유리)·공장·관청(석조)·기지(군)·주택(평야)
STYLES = ["villa", "apt", "shop", "office", "factory", "gov", "base", "house"]
# 권역별 양식 비율(SD-08 §7 지형·분위기·지면 팔레트에서 읽은 값 — 구현 정합)
MIX = {"R01": {"villa": 62, "apt": 14, "shop": 18, "house": 6}, "R02": {"factory": 30, "shop": 25, "villa": 25, "apt": 12, "office": 8},
       "R03": {"villa": 40, "apt": 20, "shop": 20, "factory": 20}, "R04": {"villa": 30, "house": 40, "shop": 30},
       "R05": {"gov": 70, "shop": 30}, "R06": {"base": 55, "villa": 25, "shop": 20}, "R07": {"apt": 55, "office": 20, "shop": 20, "villa": 5},
       "R08": {"villa": 40, "factory": 25, "apt": 20, "shop": 15}, "R09": {"apt": 48, "villa": 40, "shop": 12},
       "R10": {"house": 55, "apt": 25, "villa": 20}, "R11": {"base": 50, "house": 50}, "HR": {"house": 100}}
# 양식 → (블록 안 간격 길 폭, 건물 가로 범위, 세로(지붕+정면) 범위, 정면 단 수 범위)
FORM = {"villa": (1, (7, 11), (6, 8), (3, 4)), "apt": (3, (16, 28), (8, 9), (5, 6)), "shop": (1, (5, 10), (5, 6), (2, 3)),
        "office": (3, (10, 16), (10, 12), (6, 6)), "factory": (2, (10, 18), (7, 10), (2, 3)), "gov": (3, (10, 16), (8, 10), (3, 4)),
        "base": (3, (8, 14), (6, 8), (2, 2)), "house": (2, (4, 6), (4, 5), (1, 2))}
GRID = {"R01": 30, "R02": 36, "R03": 34, "R04": 30, "R05": 40, "R06": 44, "R07": 48, "R08": 34, "R09": 36, "R10": 44, "R11": 44, "HR": 40}
YEOUIDO = (700, 1050, 930, 1145)                                         # 섬 상자: 여의도는 업무 지구(SD-08 §7.2)


def wave(shape, rng, scale, amp, n=3):
    """부드러운 저주파 잡음(사인 합): 길 격자를 휘게 하는 변위장"""
    ys_, xs_ = np.mgrid[0:shape[0], 0:shape[1]].astype(np.float32)
    out = np.zeros(shape, np.float32)
    for k in range(n):
        f = (k + 1) / scale
        a1, a2, p1, p2 = rng.random(4) * np.pi * 2
        out += np.sin(xs_ * f * np.cos(a1) + ys_ * f * np.sin(a1) + p1) * np.cos(xs_ * f * np.sin(a2) - ys_ * f * np.cos(a2) + p2)
    return out * amp / n


def city(r, src, seed=4120):
    kind, use, region, level = r["kind"], r["use"], r["region"], r["level"]
    rng = np.random.default_rng(seed)
    buildable = (kind == 1) & ((use == 0) | (use == 1) | (use == 3) | (use == 4)) & (level == 0)
    ys_, xs_ = np.mgrid[0:H, 0:W].astype(np.float32)
    # 동네 길: 휜 격자. 언덕(구릉)일수록 더 휘고 촘촘하다(봉천식 계단 골목). 간격은 권역별(GRID), 언덕은 0.6배
    wx = wave((H, W), rng, 320.0, 34.0) + np.where(use == 1, wave((H, W), rng, 90.0, 12.0), 0)
    wy = wave((H, W), rng, 320.0, 34.0) + np.where(use == 1, wave((H, W), rng, 90.0, 12.0), 0)
    gmap = np.zeros((H, W), np.float32)
    for code in REG_CODES[1:]:
        gmap[region == REG_CODES.index(code)] = GRID[code]
    gmap = np.where(use == 1, gmap * 0.6, gmap).clip(16, 60)
    u = (xs_ + wx) / gmap
    v = (ys_ + wy) / gmap
    du = np.abs(u - np.round(u)) * gmap
    dv = np.abs(v - np.round(v)) * gmap
    street = ((du < 2.0) | (dv < 2.0)) & buildable                       # 동네 길 4타일(2차로)
    alley = ((np.abs(u * 2 - np.round(u * 2)) * gmap / 2 < 1.0) | (np.abs(v * 2 - np.round(v * 2)) * gmap / 2 < 1.0)) & buildable & ~street
    kind[street] = 7
    buildable &= ~street
    # 양식 구역: 48타일 칸마다 권역 비율로 하나(이웃 칸끼리 이어지게 저주파 잡음으로 고른다), 간선도로 옆 띠는 상가
    zone = np.full((H, W), -1, np.int8)
    zc = 48
    znoise = wave(((H + zc - 1) // zc, (W + zc - 1) // zc), rng, 3.0, 1.0)
    for cy in range((H + zc - 1) // zc):
        for cx in range((W + zc - 1) // zc):
            sl = (slice(cy * zc, (cy + 1) * zc), slice(cx * zc, (cx + 1) * zc))
            rc = np.bincount(region[sl].ravel(), minlength=len(REG_CODES))
            rc[0] = 0
            if rc.sum() == 0:
                continue
            code = REG_CODES[int(rc.argmax())]
            mix = MIX[code]
            names = list(mix)
            cum = np.cumsum(np.array(list(mix.values()), float))
            q = (znoise[cy, cx] * 0.5 + 0.5) * 0.6 + rng.random() * 0.4
            st = names[int(np.searchsorted(cum / cum[-1], min(q, 0.999)))]
            if YEOUIDO[0] <= cx * zc + zc // 2 <= YEOUIDO[2] and YEOUIDO[1] <= cy * zc + zc // 2 <= YEOUIDO[3]:
                st = "office"
            zone[sl] = STYLES.index(st)
    major = (kind == 7) & ~street
    near = np.zeros((H, W), bool)
    for dy in range(-12, 13, 4):
        for dx in range(-12, 13, 4):
            near |= np.roll(np.roll(major, dy, 0), dx, 1)
    shopband = near & np.isin(zone, [STYLES.index("villa"), STYLES.index("house"), STYLES.index("apt")])
    zone[shopband] = STYLES.index("shop")
    # 빽빽이 채우기: 2칸 간격으로 훑으며 그 자리 양식의 발자국이 들어가면 놓는다(골목 폭만큼 띄움)
    occ = ~buildable.copy()
    bid = np.zeros((H, W), np.int32)
    blds = []
    order = rng.permutation(4)
    for oy in (order[0] % 2, 1 - order[0] % 2):
        for y in range(oy, H - 4, 2):
            row = occ[y]
            xs_free = np.nonzero(~row)[0]
            last = -99
            for x in xs_free:
                if x < last or occ[y, x]:
                    continue
                z = zone[y, x]
                if z < 0:
                    continue
                st = STYLES[z]
                gap, wr, hr, fr = FORM[st]
                bw = int(rng.integers(wr[0], wr[1] + 1))
                bh = int(rng.integers(hr[0], hr[1] + 1))
                x1, y1 = min(x + bw, W), min(y + bh, H)
                win = occ[y:y1, x:x1]
                if win.any():
                    free_w = int(np.argmax(win.any(0))) if win.any(0).any() else bw
                    if free_w < wr[0] or occ[y:y1, x:x + free_w].any():
                        continue
                    x1 = x + free_w
                blds.append({"x": int(x), "y": int(y), "w": int(x1 - x), "h": int(y1 - y), "style": st,
                             "floors": int(rng.integers(fr[0], fr[1] + 1)), "seed": int(rng.integers(1 << 30))})
                bid[y:y1, x:x1] = len(blds)
                g = gap if st != "apt" else int(rng.integers(6, 9))      # 아파트는 동 사이(앞뒤) 간격이 넓다
                occ[max(0, y - gap):min(H, y1 + g), max(0, x - gap):min(W, x1 + gap)] = True
                last = x1 + gap
    r["bid"] = bid
    r["street"] = street
    r["alley"] = alley
    r["zone"] = zone
    r["buildings"] = blds
    # 나무: 산지·구릉 숲(SD-16 §6.7 '숲은 마른 침엽 오브젝트 밀도'), 빈 땅 드문드문
    tree = np.zeros((H, W), bool)
    rnd = rng.random((H, W))
    forest = (kind == 1) & ((use == 1) | (use == 2)) & (bid == 0) & ~alley
    tree |= forest & (rnd < np.where(use == 2, 0.10, 0.04))
    tree |= (kind == 1) & (use == 0) & (bid == 0) & ~alley & (rnd < 0.01)
    tree |= (kind == 5) & (rnd < 0.02)
    r["tree"] = tree
    return r


# ⑤-1 건물 조립(SD-16 §6.5): 발자국 w×h = 위쪽 옥상 R행 + 아래 정면 F행(F = 층 단, 최대 6). 칸마다 타일 이름을 고른다.
# 스킨 표(art/tools/tiles_world.py → game/assets/tiles/ts_world_bld.json "skins")의 부위 목록에서 씨앗으로 고른다.
SKIN_OF = {"villa": ["villa_brick", "villa_brickdk", "villa_plaster", "villa_tile"], "apt": ["apt_blue", "apt_green", "apt_red"],
           "shop": ["shop_tile", "shop_plaster"], "office": ["office"], "factory": ["factory_steel", "factory_rust"],
           "gov": ["gov"], "base": ["base"], "house": ["house_mint", "house_plaster", "house_brick"]}


def _h(*a):
    v = 2166136261
    for k in a:
        v = ((v ^ (int(k) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return v


def bld_cells(b, skins):
    """건물 하나 → ([(dx, dy, 이름)] 몸통 층, [(dx, dy, 이름)] 옥상 덧층, 스킨 이름)"""
    seed, w, h, st = b["seed"], b["w"], b["h"], b["style"]
    pool = SKIN_OF[st]
    skin = pool[_h(seed, 1) % len(pool)]
    sk = skins[skin]
    F = max(1, min(b["floors"], h - 1, 6))
    R = h - F
    if F == 1:
        rows = ["solo"]
    elif st == "apt" and F >= 3:
        rows = ["top"] + ["mid"] * (F - 3) + ["low", "bot"]
    else:
        rows = ["top"] + ["mid"] * (F - 2) + ["bot"]
    pick = lambda lst, *k: lst[_h(seed, *k) % len(lst)]
    body, deco = [], []
    sp = sk["special"]
    # 1층 특수 칸 자리
    mid = list(range(1, w - 1)) or [0]
    door_at, pipe_at, extra = {}, None, {}
    bot = rows[-1]
    if st in ("villa", "house"):
        c = mid[_h(seed, 3) % len(mid)]
        door_at[c] = pick(sp[bot + "_door"], 4)
        if st == "villa" and w >= 4:
            cand = [x for x in mid if abs(x - c) > 1] or mid
            pipe_at = cand[_h(seed, 5) % len(cand)]
    elif st == "apt":
        for c in range(2, w - 2, 6):                                     # 동 현관(계단실)마다 하나
            door_at[c] = sp["bot_door"][0]
    elif st == "factory":
        c = mid[_h(seed, 3) % len(mid)]
        if c + 1 < w - 1 and _h(seed, 6) % 3:
            door_at[c] = sp[bot + "_shutter_l"][0]
            door_at[c + 1] = sp[bot + "_shutter_r"][0]
        else:
            door_at[c] = sp[bot + "_steel"][0]
    elif st == "gov":
        c = w // 2
        door_at[c] = sp[bot + "_door"][0]
        for x in (1, w - 2):
            if x != c and _h(seed, x, 8) % 2:
                door_at[x] = sp[bot + "_barrier"][0]
        extra[(w // 2 - 2 if w > 5 else 0, rows[0])] = sp[rows[0] + "_lamp"][0] if rows[0] + "_lamp" in sp else None
    elif st == "base":
        door_at[w // 2] = sp[bot + "_door"][0]
    sign = {}
    for j, row in enumerate(rows):
        y = R + j
        if st == "shop" and row != "bot":
            sign[row, j] = _h(seed, j, 11) % 5
        for x in range(w):
            col = "l" if x == 0 else ("r" if x == w - 1 else "m")
            if row == bot and x in door_at:
                nm = door_at[x]
            elif pipe_at == x and (row + "_pipe") in sp:
                nm = sp[row + "_pipe"][0]
            elif extra.get((x, row)):
                nm = extra[(x, row)]
            else:
                lst = sk["rows"][row + "_" + col]
                if (row, j) in sign:
                    lst = [n for n in lst if n.endswith("s%d" % sign[row, j])]
                nm = pick(lst, x, j, 21)
            body.append((x, y, nm))
    rf = sk["roof"]
    if rf["kind"] == "pitch":
        nn = (R + 1) // 2
        for j in range(R):
            part = ("n" if j == 0 else "ns") if j < nn else ("ridge" if j == nn else "ss")
            for x in range(w):
                col = "l" if x == 0 else ("r" if x == w - 1 else "m")
                body.append((x, j, pick(rf[part + "_" + col], x, j, 23)))
    else:
        for j in range(R):
            for x in range(w):
                pos = ("n" if j == 0 else "c") if 0 < x < w - 1 else (("nw" if j == 0 else "w") if x == 0 else ("ne" if j == 0 else "e"))
                lst = rf[pos]
                hv = _h(seed, x, j, 25)
                nm = lst[0] if (len(lst) == 1 or hv % 10 < 6) else lst[1 + (hv >> 8) % (len(lst) - 1)]   # 평면 60%
                body.append((x, j, nm))
        # 옥상 설비(덧층): 난간 안쪽(1..w-2, 1..R-1)
        free = {(x, j) for x in range(1, w - 1) for j in range(1, R)}

        def put(name, x, j, ww=1, hh=1):
            cells = [(x + a, j + c) for c in range(hh) for a in range(ww)]
            if all(c in free for c in cells):
                for (a, c) in cells:
                    free.discard((a, c))
                if ww == 1:
                    deco.append((x, j, "rd:" + name))
                else:
                    for c in range(hh):
                        for a in range(ww):
                            deco.append((x + a, j + c, "rd:%s%d%d" % (name, c, a)))
                return True
            return False
        r = _h(seed, 31)
        if st in ("apt", "office", "gov", "shop") and R >= 3 and w >= 6:      # 계단실(넓은 옥상)
            put("pent", 1 + r % max(1, w - 4), 1 + (r >> 4) % max(1, R - 2), 3, 2)
        if st in ("gov", "shop", "office") and R >= 3 and w >= 8 and (r >> 6) % 2:
            put("sky", w // 2 - 1 + (r >> 9) % 3 - 1, 1 + (r >> 12) % max(1, R - 2), 2, 2)
        if st == "apt":
            put("dome", 2 + r % 3, 1, 2, 2)
            put("tank", w - 4 - r % 3, 1, 2, 2)
            for k in range(w // 6):
                put(["ac", "vent", "antenna", "debris"][(r >> k) % 4], 1 + _h(seed, k, 40) % max(1, w - 2), 1 + _h(seed, k, 41) % max(1, R - 1))
        else:
            n = {"villa": 2, "shop": 2, "office": 4, "gov": 2, "base": 2, "factory": 2}.get(st, 1)
            if st in ("villa", "shop") and r % 3 == 0:
                put("tank", 1 + r % max(1, w - 3), 1, 2, 2)
            kinds = {"villa": ["garden0", "garden1", "ac", "hatch", "dish"], "shop": ["ac", "ac", "vent", "hatch", "antenna"],
                     "office": ["ac", "vent", "vent", "antenna", "dish"], "gov": ["antenna", "vent", "hatch"],
                     "base": ["sandbag", "antenna", "hatch"], "factory": ["vent", "vent"]}[st]
            for k in range(n * max(1, w // 6)):
                put(kinds[_h(seed, k, 50) % len(kinds)], 1 + _h(seed, k, 51) % max(1, w - 2), 1 + _h(seed, k, 52) % max(1, R - 1))
    return body, deco, skin


# ⑤ 바닥 타일(ts_r01_ext 이름): 굽기 결과 → 바닥 합성 층의 타일 번호. 청크 내보내기·견본 그림이 같은 표를 쓴다
def floor_names(r, seed=77):
    """반환: 칸마다 타일 이름 번호 배열(0..len(FLOOR)-1)과 이름 목록"""
    kind, use, level, hgt = r["kind"], r["use"], r["level"], r["hgt"]
    rng = np.random.default_rng(seed)
    names = ["dirt_a", "dirt_grass_b", "dirt_grass_a", "asphalt", "asphalt_lane", "pavers", "concrete_o", "water_deep", "water_mid",
             "water_shallow", "mud", "rock_floor", "rubble", "ballast"]
    ix = {n: i for i, n in enumerate(names)}
    f = np.full(kind.shape, ix["dirt_a"], np.uint8)
    blobs = wave(kind.shape, rng, 40.0, 1.0, 4)                          # 흙·풀 얼룩(넓게)
    land = (kind == 1) | (kind == 12)
    f[land & (blobs > 0.15)] = ix["dirt_grass_b"]
    f[land & (blobs > 0.45)] = ix["dirt_grass_a"]
    f[land & (use == 1)] = np.where(blobs[land & (use == 1)] > -0.2, ix["dirt_grass_a"], ix["dirt_grass_b"])
    f[land & (use == 2)] = np.where(blobs[land & (use == 2)] > 0.2, ix["dirt_grass_a"], ix["dirt_a"])
    f[land & (hgt >= 300)] = ix["rock_floor"]                               # 300m+ 화강암 노출(SD-08 §6.1)
    f[land & (use == 3)] = ix["rubble"]                                     # 도심 밀폐(R05)
    f[(kind == 2)] = ix["water_deep"]
    f[(kind == 3)] = ix["water_mid"]
    f[(kind == 4)] = ix["water_shallow"]
    f[(kind == 5)] = np.where(blobs[kind == 5] > 0.0, ix["mud"], ix["dirt_grass_a"])
    f[(kind == 6)] = ix["concrete_o"]
    f[(kind == 7)] = ix["asphalt"]
    if "street" in r:
        lane = (kind == 7) & ~r["street"] & (r.get("lane", np.zeros_like(kind, bool)))
        f[lane] = ix["asphalt_lane"]
    f[(kind == 8)] = ix["pavers"]
    f[(kind == 9)] = ix["dirt_grass_a"]
    f[(kind == 10)] = ix["ballast"]
    f[(kind == 11)] = ix["rock_floor"]
    return f, names


def preview(r, src, path, scale=1):
    from PIL import Image
    kind, use, level, hgt = r["kind"], r["use"], r["level"], r["hgt"]
    img = np.zeros((H, W, 3), np.uint8)
    land = kind == 1
    img[land] = (176, 162, 132)                                          # 시가지 땅
    img[land & (use == 1)] = (128, 150, 96)
    img[land & (use == 2)] = (92, 118, 78)
    img[land & (use == 4)] = (186, 176, 120)
    img[land & (use == 3)] = (150, 120, 110)
    for lv in range(2, 18):                                              # 산지 단마다 밝게(화강암 노출 300m+)
        m = land & (level == lv)
        img[m] = (np.array((92, 118, 78)) + np.array((14, 10, 12)) * (lv - 1)).clip(0, 235)
    img[kind == 2] = (34, 58, 92)
    img[kind == 3] = (46, 82, 120)
    img[kind == 4] = (70, 112, 146)
    img[kind == 5] = (146, 152, 100)
    img[kind == 6] = (150, 150, 146)
    img[kind == 7] = (70, 70, 74)
    img[kind == 8] = (196, 192, 184)
    img[kind == 9] = (110, 120, 90)
    img[kind == 10] = (120, 88, 64)
    img[kind == 11] = (226, 214, 182)
    img[kind == 12] = (120, 150, 92)
    img[r["elevated"] & (kind == 7)] = (40, 40, 46)
    if "bid" in r:                                                       # 건물: 양식 색 + 아래 정면 띠
        col = {"villa": (168, 92, 74), "apt": (222, 214, 196), "shop": (190, 150, 110), "office": (120, 150, 170),
               "factory": (150, 80, 60), "gov": (200, 196, 186), "base": (110, 118, 84), "house": (180, 130, 96)}
        for b in r["buildings"]:
            c = np.array(col[b["style"]])
            img[b["y"]:b["y"] + b["h"], b["x"]:b["x"] + b["w"]] = c
            f = b["y"] + b["h"] - min(b["floors"], b["h"] - 1)
            img[f:b["y"] + b["h"], b["x"]:b["x"] + b["w"]] = (c * 0.7).astype(np.uint8)
        img[r["tree"]] = (52, 86, 50)
    edge = np.zeros((H, W), bool)                                         # 단 경계(암벽)
    edge[:, 1:] |= level[:, 1:] != level[:, :-1]
    edge[1:, :] |= level[1:, :] != level[:-1, :]
    img[edge & (kind == 1)] = (60, 60, 56)
    img[~(r["play"] | r["band"])] = (12, 11, 14)
    img[r["band"] & (kind == 1)] = (img[r["band"] & (kind == 1)] * 0.55).astype(np.uint8)
    for p in src["places"]:                                              # 장소 425: 점
        x, y = p["tx"], p["ty"]
        if 0 <= x < W - 2 and 0 <= y < H - 2:
            img[y - 1:y + 2, x - 1:x + 2] = (230, 60, 40) if p["grade"] in ("S", "A") else (240, 200, 60)
    im = Image.fromarray(img)
    if scale != 1:
        im = im.resize((W // scale, H // scale), Image.NEAREST)
    im.save(path)
    return im.size


def main():
    src = json.load(open(SRC, encoding="utf-8"))
    r = bake(src)
    city(r, src)
    kind = r["kind"]
    n = {k: int((kind == v).sum()) for k, v in (("땅", 1), ("깊은 물", 2), ("중간 물", 3), ("얕은 물", 4), ("둔치", 5), ("제방", 6),
                                                ("차도", 7), ("보도", 8), ("철로", 10), ("성곽", 11), ("섬", 12))}
    print("월드 래스터 %d×%d: %s · 최고 단 %d · 최고 %dm" % (W, H, n, int(r["level"].max()), int(r["hgt"].max())))
    cnt = {}
    for b in r["buildings"]:
        cnt[b["style"]] = cnt.get(b["style"], 0) + 1
    print("건물 %d동 %s · 나무 %d그루" % (len(r["buildings"]), cnt, int(r["tree"].sum())))
    out = None
    for i, a in enumerate(sys.argv):
        if a == "--preview" and i + 1 < len(sys.argv):
            out = sys.argv[i + 1]
    if out:
        print("미리보기:", out, preview(r, src, os.path.join(ROOT, out), 1))
    return r


if __name__ == "__main__":
    main()
