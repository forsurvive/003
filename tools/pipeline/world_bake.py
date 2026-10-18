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
import road_net as RN

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
    river_lines = {"한강": (P, wid / 2 + 7)}                              # 강변 고속도로가 따라갈 선(제방 바깥 기준)
    for r in src["rivers"]:
        nm = r["name"]
        if nm.startswith("한강"):
            continue
        wv = next((v for k, v in RIVER_W.items() if nm.startswith(k)), 4)
        Q = line_of(r["path"], 60)
        if nm.startswith("샛강"):                                          # 샛강은 한강 남쪽 갈래: 여의도 남쪽 끝을 따라 양끝이 한강에 닿게
            Q = np.vstack([[Q[0][0] - 30, Q[0][1] - 25], Q, [Q[-1][0] + 40, Q[-1][1] - 30]])
        river_lines[nm] = (Q, np.full(len(Q), wv / 2.0))
        d = dist_field(Q, wv)
        water = (d <= wv / 2) & (kind > 0) & (kind != 2) & (kind != 3)
        kind[water & ~river] = 4
        hgt[water] = np.minimum(hgt[water], 20)
    for lid, (rx, ry) in ISLANDS.items():
        p = next(q for q in src["places"] if q["lid"] == lid)
        isl = ((xs - p["tx"]) / rx) ** 2 + ((ys - p["ty"]) / ry) ** 2 <= 1.0
        kind[isl & (kind >= 2) & (kind <= 4)] = 12

    # ③ 간선도로(SD-21 §4): 실제 노선 근사(road_net) · 위계별 단면(차도·중앙분리대·보도). 강물 위는 다리가 아니면 끊긴다
    elevated = np.zeros((H, W), bool)
    roads = RN.arterials(river_lines)
    order = {"H4": 0, "H3": 1, "H2": 2, "H1": 3}
    roads.sort(key=lambda a: order[a["cls"]])                            # 높은 위계가 나중에 덮는다(교차로에서 큰길이 이어진다)
    cls_map = np.zeros((H, W), np.uint8)                                 # 칸의 간선 위계(1~4, 0 = 간선 아님)
    land = (kind == 1) | (kind == 5) | (kind == 6)
    for a in roads:
        car, med, walk = RN.SECTION[a["cls"]]
        full = car + 2 * walk
        Q = a["pts"]
        if len(Q) < 2:
            continue
        el = np.zeros((H, W), np.float32)
        d = dist_field(Q, full + 2, el, a["elev"].astype(np.float32))
        road = (d <= car / 2) & land
        kind[road] = 7
        cls_map[road] = 4 - order[a["cls"]]
        if med:
            kind[(d <= med / 2 + 0.1) & land] = 9
        if walk:
            side = (d > car / 2) & (d <= full / 2) & land & (kind != 7)
            kind[side] = 8
        elevated |= road & (el > 0.5)
        a["width"] = full
    # 철도: 지상 구간만    # 철도: 지상 구간만(SD-08 §6.4). 2호선 순환은 지상·지하가 섞여 있으나 원문이 구간을 나누지 않았다 → 지상 1호선만(구현 정합)
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
    # 도심 밀폐(SD-08 §9.1): 성곽을 넘는 길은 없고, 대로 끝·성문 자리는 관제망 차단벽(38곳)으로 닫혀 있다 → 고리를 끊지 않는다.
    # 도심 안(D1~D9)은 별도 외부 맵이고 진입은 G1~G10(지하철·터널·차단벽·공중)뿐이다(§9.2·§9.3)
    wall = (d <= 1.0) & (kind > 0)
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
            "play": play, "band": band, "roads": roads, "cls": cls_map}


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


def vnoise(shape, cell, rng, octaves=2):
    """값 잡음 0~1(격자 cell칸마다 난수, 사이는 부드럽게 보간 — 옥타브마다 칸 반으로). 전이 띠를 조각조각 깨는 데 쓴다"""
    hh, ww = shape
    out = np.zeros(shape, np.float32)
    amp, tot = 1.0, 0.0
    ys = np.arange(hh, dtype=np.float32)[:, None]
    xs = np.arange(ww, dtype=np.float32)[None, :]
    for _ in range(octaves):
        g = rng.random((hh // cell + 3, ww // cell + 3)).astype(np.float32)
        fy, fx = ys / cell, xs / cell
        y0, x0 = fy.astype(np.int32), fx.astype(np.int32)
        ty, tx = fy - y0, fx - x0
        ty, tx = ty * ty * (3 - 2 * ty), tx * tx * (3 - 2 * tx)
        a = g[y0, x0]; b = g[y0, x0 + 1]; c = g[y0 + 1, x0]; d = g[y0 + 1, x0 + 1]
        out += amp * ((a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty)
        tot += amp
        amp *= 0.5
        cell = max(1, cell // 2)
    return out / tot


def ramp(x, a, b):
    """a 이하 0 → b 이상 1, 사이는 부드러운 S자(smoothstep). 바이옴 전이에 쓴다(경계선 대신 띠)"""
    t = np.clip((x - a) / float(b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def box_blur(m, rad):
    """정사각 상자 흐림(누적합, 반지름 rad칸): 0/1 마스크 → 0~1 '얼마나 안쪽인가' — 구역 가장자리를 띠로 푼다"""
    a = np.pad(m.astype(np.float32), rad, mode="edge")
    c = a.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    k = 2 * rad + 1
    hh, ww = m.shape
    tot = c[k:k + hh, k:k + ww] - c[0:hh, k:k + ww] - c[k:k + hh, 0:ww] + c[0:hh, 0:ww]
    return tot / float(k * k)


def soft_height(r, seed=91):
    """바이옴 판정용 높이(m): 실제 높이에 저주파 잡음(±30m)을 더해 등고선 한 줄이 경계가 되지 않게 한다(배치·높이 단은 실제 높이 그대로)"""
    if "hsoft" not in r:
        rng = np.random.default_rng(seed)
        r["hsoft"] = r["hgt"].astype(np.float32) + wave(r["hgt"].shape, rng, 34.0, 30.0, 4) + wave(r["hgt"].shape, rng, 11.0, 9.0, 3)
    return r["hsoft"]


def rock_frac(r):
    """화강암 노출(300m+)의 '안쪽 정도' 0~1: 바위 구역을 6칸 상자로 흐린 값 — 전이 띠 폭이 경사와 상관없이 12칸쯤"""
    if "rockf" not in r:
        r["rockf"] = box_blur(soft_height(r) >= 298.0, 10)
    return r["rockf"]


def city(r, src, seed=4120, anchors=()):
    """anchors: [(x, y, 양식)] — 손 실내 문이 붙을 장소에 반드시 세울 건물(SD-21 §8 재접속). 길·골목 위면 그 칸을 땅으로 되돌린다"""
    kind, use, region, level = r["kind"], r["use"], r["region"], r["level"]
    rng = np.random.default_rng(seed)
    buildable = (kind == 1) & ((use == 0) | (use == 1) | (use == 3) | (use == 4)) & (level == 0)
    # 동네 길(SD-21 §5): 바둑판 대신 시가지 결(F1~F7)별 생성 — 구도심 유기형 · 언덕 등고선형 · 계획 격자 · 공업 대블록 ·
    # 아파트 단지 순환로 · 시장 미로 · 황무지 흙길. 결은 큰길로 나뉜 큰 블록마다 정한다
    hs = soft_height(r)
    fab = RN.fabric_map(r, src, hs)
    land_ok = buildable | ((kind == 1) & (level == 0))
    street, alley, track = RN.local_streets(r, fab, land_ok, hs)
    street &= buildable
    alley &= land_ok & ~street
    track &= land_ok & ~street
    kind[street] = 7
    buildable &= ~street & ~alley & ~track
    # 양식 구역: 결이 정한다(아파트 = 단지 · 공장 = 공단 · 업무 = 계획 시가지 · 상가 = 시장). 구도심·도심·기지·외곽 권역은 권역 비율로
    zone = np.full((H, W), -1, np.int8)
    zc = 48
    znoise = wave(((H + zc - 1) // zc, (W + zc - 1) // zc), rng, 3.0, 1.0)
    F1_DROP = {"apt", "factory", "office"}
    for cy in range((H + zc - 1) // zc):
        for cx in range((W + zc - 1) // zc):
            sl = (slice(cy * zc, (cy + 1) * zc), slice(cx * zc, (cx + 1) * zc))
            rc = np.bincount(region[sl].ravel(), minlength=len(REG_CODES))
            rc[0] = 0
            if rc.sum() == 0:
                continue
            code = REG_CODES[int(rc.argmax())]
            mix = {k: v for k, v in MIX[code].items() if k not in F1_DROP or code in ("R05", "R06", "R11")} or {"villa": 1}
            names = list(mix)
            cum = np.cumsum(np.array(list(mix.values()), float))
            q = (znoise[cy, cx] * 0.5 + 0.5) * 0.6 + rng.random() * 0.4
            zone[sl] = STYLES.index(names[int(np.searchsorted(cum / cum[-1], min(q, 0.999)))])
    pick = vnoise((H, W), 24, rng, 2)
    reg_keep = np.isin(region, [REG_CODES.index(c) for c in ("R05", "R06", "R11")])
    zone[(fab == 1) & ~reg_keep] = np.where(pick[(fab == 1) & ~reg_keep] < 0.68, STYLES.index("villa"), STYLES.index("house"))
    yeo = np.zeros((H, W), bool)
    yeo[YEOUIDO[1]:YEOUIDO[3], YEOUIDO[0]:YEOUIDO[2]] = True
    zone[(fab == 2)] = np.where(yeo[fab == 2] | (pick[fab == 2] < 0.45), STYLES.index("office"), STYLES.index("apt"))
    zone[(fab == 3)] = np.where(pick[fab == 3] < 0.86, STYLES.index("factory"), STYLES.index("shop"))
    zone[(fab == 4)] = STYLES.index("apt")
    zone[(fab == 5)] = STYLES.index("shop")
    zone[(fab == 6) & ~reg_keep] = STYLES.index("house")
    # 황무지(F7): 집은 띄엄띄엄 모여 있다(농가·폐가 무리) — 저주파 잡음 높은 곳만 짓는다
    cluster = vnoise((H, W), 40, rng, 3)
    buildable &= ~((fab == 6) & (cluster < 0.66))
    r["fabric"] = fab
    r["track"] = track
    major = (kind == 7) & ~street
    near = np.zeros((H, W), bool)
    for dy in range(-12, 13, 4):
        for dx in range(-12, 13, 4):
            near |= np.roll(np.roll(major, dy, 0), dx, 1)
    shopband = near & np.isin(zone, [STYLES.index("villa"), STYLES.index("house")])   # 아파트 단지·공단은 큰길 옆이어도 그대로
    zone[shopband] = STYLES.index("shop")
    # 빽빽이 채우기: 2칸 간격으로 훑으며 그 자리 양식의 발자국이 들어가면 놓는다(골목 폭만큼 띄움)
    occ = ~buildable.copy()
    bid = np.zeros((H, W), np.int32)
    blds = []
    arter = r.get("cls", np.zeros((H, W), np.uint8)) > 0
    for ax, ay, st in anchors:                                            # 고정 건물 먼저(간선·물·성곽·단 위는 피해 가장 가까운 자리)
        gap, wr, hr, fr = FORM[st]
        bw, bh = (wr[0] + wr[1]) // 2, (hr[0] + hr[1]) // 2
        best = None
        for rr in range(0, 24):
            for yy in range(ay - rr - bh, ay + rr + 1):
                for xx in range(ax - rr - bw // 2, ax + rr - bw // 2 + 1):
                    if not (2 <= xx < W - bw - 2 and 2 <= yy < H - bh - 3):
                        continue
                    win = (slice(yy, yy + bh + 2), slice(xx, xx + bw))
                    ok = (kind[win] == 1) | ((kind[win] == 7) & ~arter[win])        # 땅 또는 동네 길(간선·물·성곽·철로는 안 됨)
                    if not ok.all() or (level[win] != 0).any():
                        continue
                    if bid[yy:yy + bh, xx:xx + bw].any():
                        continue
                    dd = (xx + bw // 2 - ax) ** 2 + (yy + bh - ay) ** 2
                    if best is None or dd < best[0]:
                        best = (dd, xx, yy)
            if best is not None:
                break
        if best is None:
            print("고정 건물 자리를 못 찾았다:", ax, ay, st)
            continue
        _, xx, yy = best
        sl = (slice(yy, yy + bh), slice(xx, xx + bw))
        kind[sl][kind[sl] == 7] = 1                                       # 동네 길·골목이 지나던 칸은 땅으로(건물이 길을 끊는다)
        street[sl] = False
        alley[sl] = False
        track[sl] = False
        front = (slice(yy + bh, yy + bh + 2), slice(xx, xx + bw))          # 문 앞 두 줄은 비워 걸어서 닿게
        alley[front] |= (kind[front] == 1)
        blds.append({"x": int(xx), "y": int(yy), "w": int(bw), "h": int(bh), "style": st,
                     "floors": int(min(fr[1], bh - 2)), "seed": int(_h(ax, ay, 77))})
        bid[sl] = len(blds)
        occ[max(0, yy - gap):yy + bh + gap + 2, max(0, xx - gap):xx + bw + gap] = True
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
                # 크기 · 층 · 씨앗은 그 자리(x, y) 해시로(난수 한 줄기로 뽑으면 고정 건물 하나만 더해도 그 뒤 도시 전체가 다시 짜인다 —
                # 생성 실내 ID · 은닉처가 흔들림. 1-D8에서 고침): 바뀐 자리 둘레만 바뀐다
                bw = wr[0] + _h(x, y, 11) % (wr[1] - wr[0] + 1)
                bh = hr[0] + _h(x, y, 13) % (hr[1] - hr[0] + 1)
                x1, y1 = min(x + bw, W), min(y + bh, H)
                win = occ[y:y1, x:x1]
                if win.any():
                    free_w = int(np.argmax(win.any(0))) if win.any(0).any() else bw
                    if free_w < wr[0] or occ[y:y1, x:x + free_w].any():
                        continue
                    x1 = x + free_w
                blds.append({"x": int(x), "y": int(y), "w": int(x1 - x), "h": int(y1 - y), "style": st,
                             "floors": int(fr[0] + _h(x, y, 17) % (fr[1] - fr[0] + 1)), "seed": int(_h(x, y, 19) & ((1 << 30) - 1))})
                bid[y:y1, x:x1] = len(blds)
                g = gap if st != "apt" else 6 + _h(x, y, 23) % 3          # 아파트는 동 사이(앞뒤) 간격이 넓다
                occ[max(0, y - gap):min(H, y1 + g), max(0, x - gap):min(W, x1 + gap)] = True
                last = x1 + gap
    r["bid"] = bid
    r["street"] = street
    r["alley"] = alley
    r["zone"] = zone
    r["buildings"] = blds
    # 나무: 산지·구릉 숲(SD-16 §6.7 '숲은 마른 침엽 오브젝트 밀도'), 빈 땅 드문드문
    # 밀도는 높이(잡음 섞은 바이옴 높이)에 따라 이어진다: 평지 0.01 → 구릉 0.04 → 산지 0.10(등고선 한 줄에서 숲이 뚝 끊기지 않게).
    # 놀이 구역 밖(경계 띠)은 바깥으로 갈수록 숲이 짙어진다(네모난 맨땅 대신 숲 가장자리)
    tree = np.zeros((H, W), bool)
    rnd = rng.random((H, W))
    hs = soft_height(r)
    dens = 0.01 + 0.03 * ramp(hs, 25.0, 95.0) + 0.06 * ramp(hs, 115.0, 205.0)
    clump = wave((H, W), rng, 14.0, 1.0, 3)                                    # 덤불 덩어리(고르게 흩뿌리지 않는다)
    dens = dens * (0.55 + 0.9 * ramp(clump, -0.6, 0.6)) * (1.0 - 0.75 * rock_frac(r))   # 맨바위 위엔 나무가 드물다
    out = ~r["play"]
    deep = 1.0 - box_blur(r["play"], 10)                                     # 구역 밖으로 들어갈수록 1
    dens = np.where(out, np.maximum(dens, 0.04 + 0.16 * deep), dens)
    dens = np.where(fab == 6, dens + 0.035, dens)                               # 황무지: 덤불·잡목이 짙다
    land = ((kind == 1) | (kind == 0) | (kind == 12)) & (bid == 0) & ~alley & ~street & ~track
    tree |= land & (rnd < dens)
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
    fine = np.clip((vnoise(kind.shape, 4, rng, 3) - 0.5) * 4.4, -1.0, 1.0)   # 잔 얼룩 −1~1(4 · 2 · 1칸 옥타브, 대비를 키워 띠 안에 섬이 생긴다)
    hs = soft_height(r)
    # 바이옴 전이(리드 지시 2026-10-15 '경계선 없이 점진적으로'): 쓰임(use) 구역을 바로 재질로 바꾸지 않고, 높이에 따라 이어지는
    # 푸름 점수 = 얼룩 + 구릉일수록 +0.6 − 산지 숲 바닥(낙엽·흙) −0.35. 점수로 흙 · 마른 풀 · 풀을 고른다
    land = (kind == 1) | (kind == 12) | (kind == 0)
    green = box_blur(blobs + 0.6 * ramp(hs, 30.0, 95.0) - 0.35 * ramp(hs, 140.0, 225.0), 3) + 0.12 * fine   # 공간으로도 한 번 흐린다(급경사에서 띠가 좁아지지 않게)
    f[land & (green > 0.15)] = ix["dirt_grass_b"]
    f[land & (green > 0.45)] = ix["dirt_grass_a"]
    # 화강암 노출(SD-08 §6.1, 300m+): 가장자리 12칸쯤의 띠에서 바위 조각이 안쪽으로 갈수록 늘어난다
    rock = ramp(rock_frac(r), 0.1, 0.9)
    f[land & (rock > 0.0) & ((fine * 0.5 + 0.5) < rock)] = ix["rock_floor"]
    # 도심 밀폐(R05) 잔해: 구역 가장자리 8칸 띠에서 잔해 조각이 안쪽으로 갈수록 늘어난다
    inner = box_blur(use == 3, 8)
    f[land & (inner > 0.05) & ((fine * 0.5 + 0.5) < ramp(inner, 0.1, 0.75))] = ix["rubble"]
    f[(kind == 2)] = ix["water_deep"]
    f[(kind == 3)] = ix["water_mid"]
    f[(kind == 4)] = ix["water_shallow"]
    f[(kind == 5)] = np.where(blobs[kind == 5] > 0.0, ix["mud"], ix["dirt_grass_a"])
    f[(kind == 6)] = ix["rubble"]                                        # 제방: 무너진 콘크리트 사면(잔해 재질 — 대각선에서도 경계가 부드럽다)
    f[(kind == 7)] = ix["asphalt"]
    if "street" in r:
        lane = (kind == 7) & ~r["street"] & (r.get("lane", np.zeros_like(kind, bool)))
        f[lane] = ix["asphalt_lane"]
    if "alley" in r:                                                     # 골목(H6): 시가지는 낡은 콘크리트, 언덕·황무지는 흙 · 흙길(F7)
        fab = r.get("fabric", np.zeros_like(kind))
        al = r["alley"] & (kind == 1)
        f[al & ~np.isin(fab, [1, 6])] = ix["concrete_o"]
        f[al & np.isin(fab, [1, 6])] = ix["dirt_a"]
        f[r.get("track", np.zeros_like(al)) & (kind == 1)] = ix["dirt_a"]
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
    if "alley" in r:
        img[r["alley"] & (kind == 1)] = (150, 146, 136)
        img[r["track"] & (kind == 1)] = (160, 140, 100)
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
