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
    kind[(d <= 1.0) & (kind > 0)] = 11

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
    kind = r["kind"]
    n = {k: int((kind == v).sum()) for k, v in (("땅", 1), ("깊은 물", 2), ("중간 물", 3), ("얕은 물", 4), ("둔치", 5), ("제방", 6),
                                                ("차도", 7), ("보도", 8), ("철로", 10), ("성곽", 11), ("섬", 12))}
    print("월드 래스터 %d×%d: %s · 최고 단 %d · 최고 %dm" % (W, H, n, int(r["level"].max()), int(r["hgt"].max())))
    out = None
    for i, a in enumerate(sys.argv):
        if a == "--preview" and i + 1 < len(sys.argv):
            out = sys.argv[i + 1]
    if out:
        print("미리보기:", out, preview(r, src, os.path.join(ROOT, out), 1))
    return r


if __name__ == "__main__":
    main()
