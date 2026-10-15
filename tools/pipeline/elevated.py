"""고가 도로 굽기(단계 1-Rd·1-Re, SD-21 §6.1~6.3): road_net의 고가 구간(elev)을 칸 단위 구조로 만든다.

  · 상판(층 1): 차도 폭 노면 + 둘레 한 칸 방호벽. 그 아래 땅(층 0)은 그대로 걸을 수 있다(그늘 통로).
  · 램프: 고가 구간 양 끝 8~14칸. 층 0 ↔ 1을 잇는 유일한 길. 옆은 옹벽(두 층 다 막힘), 아래 끝은 땅 도로로 열린다.
  · 기둥: 가운데 줄 6~10칸 간격(층 0 막힘·높은 엄폐).
  · 끊긴 경간: 140칸마다 45%로 4~12칸 무너짐 — 위에서는 끝에서 선다(낙하 없음). 아래 땅에는 잔해(일부는 막힌 더미).
  · 비상계단: 32~49칸마다(30%는 무너져 없음 — 밑에 부서진 계단 잔해). 무너진 경간으로 나뉜 토막마다 오르내릴 곳이 하나는 있다.
  · 버려진 차: 상판 위 2칸(층 1 막힘·엄폐) — 고가 위 교전의 엄폐물.
결과는 칸 배열 셋: code(상판 부호, game InteriorMap.DK_*) · top(위층 그림 타일 번호) · low(아래층 그림 타일 번호)와
땅 쪽 막힘·엄폐 바꿈, 건물·소품을 비울 자리.
"""
import math
import numpy as np

DK_NONE, DK_DECK, DK_RAIL, DK_RAMP, DK_WALL, DK_PILLAR, DK_BROKEN, DK_STAIR, DK_JUNK = range(9)
# SD-21 §6.3 '2277 상태'를 맞춘다: 노선 이름 → 최소 무너진 경간 수 · 끊긴 램프 수(구간 전체에서)
STATE = {"서부간선도로": {"gaps": 2}, "올림픽대로": {"broken_ramps": 1}}
SURF = (DK_DECK, DK_PILLAR, DK_BROKEN, DK_JUNK)


def _densify(P, step=0.5):
    out = [P[0]]
    for a, b in zip(P[:-1], P[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(L / step))
        for k in range(1, n + 1):
            out.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
    Q = np.array(out, np.float64)
    s = np.concatenate([[0.0], np.cumsum(np.hypot(*(np.diff(Q, axis=0).T)))])
    return Q, s


def _runs(elev):
    out, i = [], 0
    while i < len(elev):
        if elev[i]:
            j = i
            while j + 1 < len(elev) and elev[j + 1]:
                j += 1
            out.append((i, j))
            i = j + 1
        else:
            i += 1
    return out


def _h(x, y, k):
    return ((int(x) * 73856093) ^ (int(y) * 19349663) ^ (k * 83492791)) & 0xFFFFFF


N4 = ((0, -1, 1), (1, 0, 2), (0, 1, 4), (-1, 0, 8))
D4 = ((1, -1, 1), (1, 1, 2), (-1, 1, 4), (-1, -1, 8))


def build(roads, section, land_ok, H, W, tid, seed=2277, log=print, ramp_ok=None):
    """roads: road_net 간선(pts·elev·cls·name) · section: 위계 → (차도, 분리대, 보도) · land_ok: 상판·램프를 놓아도 되는 칸(H×W bool)
    tid: 타일 이름 → ts_world 번호. 돌려줌: dict(code, top, low, solid_on, solid_off, cover, noprop, stats)"""
    rng = np.random.default_rng(seed)
    ramp_ok = land_ok if ramp_ok is None else ramp_ok
    lane_o = np.full((H, W), -1, np.int8)                                  # 차선 그림: 방향(0 동서 · 1 남북 · 2 북동 · 3 북서), 굵기(1 점선 · 2 중앙선)
    lane_k = np.zeros((H, W), np.uint8)
    code = np.zeros((H, W), np.uint8)
    top = np.zeros((H, W), np.uint16)
    low = np.zeros((H, W), np.uint16)
    ramp_h = np.full((H, W), -1.0, np.float32)
    gapz = np.zeros((H, W), bool)                                          # 무너진 경간 자리(층 1 없음, 방호벽도 두르지 않는다)
    opening = np.zeros((H, W), bool)                                       # 램프 아래 끝 너머(옹벽을 두르지 않는다)
    pillar_s = np.zeros((H, W), bool)                                      # 기둥 줄(아래층 그늘 앞 칸에 기둥 그림)
    rubble = []
    wrecks = []
    boxes = []                                                             # 상판 위 차 트렁크(층 1 용기 — 'car' 루팅표, T2 상한: SD-21 §7.3)
    stats = {"runs": 0, "deck": 0, "ramps": 0, "gaps": 0, "stairs": 0, "stairs_broken": 0, "pillars": 0, "cars": 0, "names": []}
    stair_plan = []
    for a in roads:
        el = np.asarray(a.get("elev", []), bool)
        if not el.any():
            continue
        car = section[a["cls"]][0]
        half = car / 2.0
        for (i0, i1) in _runs(el):
            P = [tuple(p) for p in np.asarray(a["pts"], float)[i0:i1 + 1]]
            if len(P) < 2:
                continue
            Q, s = _densify(P)
            S = s[-1]
            Lr = [int(rng.integers(8, 15)), int(rng.integers(8, 15))]
            if S < Lr[0] + Lr[1] + 12:
                continue
            stats["runs"] += 1
            stats["names"].append(a.get("name", "?"))
            x0 = int(max(0, Q[:, 0].min() - half - 4)); x1 = int(min(W, Q[:, 0].max() + half + 5))
            y0 = int(max(0, Q[:, 1].min() - half - 4)); y1 = int(min(H, Q[:, 1].max() + half + 5))
            ys, xs = np.mgrid[y0:y1, x0:x1]
            cx, cy = xs + 0.5, ys + 0.5
            dmin = np.full(xs.shape, 1e9)
            smin = np.zeros(xs.shape)
            kmin = np.zeros(xs.shape, np.int64)
            R = half + 2.5
            for k in range(0, len(Q)):
                qx, qy = Q[k]
                bx0, bx1 = int(qx - R) - x0, int(qx + R) + 1 - x0
                by0, by1 = int(qy - R) - y0, int(qy + R) + 1 - y0
                bx0, by0 = max(0, bx0), max(0, by0)
                if bx1 <= bx0 or by1 <= by0:
                    continue
                sl = (slice(by0, by1), slice(bx0, bx1))
                d = np.hypot(cx[sl] - qx, cy[sl] - qy)
                m = d < dmin[sl]
                dmin[sl][m] = d[m]
                smin[sl][m] = s[k]
                kmin[sl][m] = k
            t0 = Q[min(4, len(Q) - 1)] - Q[0]; t0 /= max(1e-6, np.hypot(*t0))
            t1 = Q[-1] - Q[max(0, len(Q) - 5)]; t1 /= max(1e-6, np.hypot(*t1))
            pre = (cx - Q[0][0]) * t0[0] + (cy - Q[0][1]) * t0[1] < -0.3          # 시작 끝 너머
            post = (cx - Q[-1][0]) * t1[0] + (cy - Q[-1][1]) * t1[1] > 0.3        # 끝 너머
            ok = land_ok[y0:y1, x0:x1]
            surf = (dmin <= half) & ~pre & ~post & ok
            win = (slice(y0, y1), slice(x0, x1))
            opening[win] |= (pre | post) & (dmin <= half + 1.6)
            # 램프(양 끝) — 땅에서 상판까지 높이 단 0~1
            rmp = surf & ((smin < Lr[0]) | (smin > S - Lr[1]))
            rmp &= ramp_ok[y0:y1, x0:x1]                                       # 램프는 땅에만(물 위는 상판만 지난다)
            surf &= ~((smin < Lr[0]) | (smin > S - Lr[1])) | rmp
            # 차선: 가운데 노란 겹선 + 2칸(차로 하나)마다 흰 점선(3칸 칠 · 3칸 비움)
            kk = np.clip(kmin, 0, len(Q) - 2)
            tx_ = Q[kk + 1, 0] - Q[kk, 0]
            ty_ = Q[kk + 1, 1] - Q[kk, 1]
            ln = np.maximum(1e-6, np.hypot(tx_, ty_))
            lat = ((cx - Q[kk, 0]) * -ty_ + (cy - Q[kk, 1]) * tx_) / ln
            ang = (np.degrees(np.arctan2(ty_, tx_)) + 180.0) % 180.0
            ori = np.where((ang < 22.5) | (ang >= 157.5), 0, np.where((ang >= 67.5) & (ang < 112.5), 1, np.where(ang < 67.5, 3, 2)))
            cen = surf & ~rmp & (np.abs(lat) < 0.5) & (car >= 6)
            dash = surf & ~rmp & ~cen & (np.abs(lat) < half - 0.8) & (np.abs(np.abs(lat) - np.round(np.abs(lat) / 2.0) * 2.0) < 0.5) & (np.abs(lat) > 1.0) \
                & ((smin // 3).astype(np.int64) % 2 == 0)
            lo_ = lane_o[y0:y1, x0:x1]
            lk_ = lane_k[y0:y1, x0:x1]
            lo_[cen | dash] = ori[cen | dash]
            lk_[cen] = 2
            lk_[dash] = 1
            hh = np.where(smin < Lr[0], smin / Lr[0], (S - smin) / Lr[1])
            sub = code[win]
            sub[surf & ~rmp & (sub == DK_NONE)] = DK_DECK
            sub[rmp & (sub == DK_NONE)] = DK_RAMP
            rh = ramp_h[win]
            rh[rmp] = np.maximum(rh[rmp], np.clip(hh[rmp], 0, 0.999))
            stats["ramps"] += 2
            stats.setdefault("where", []).append("%s %d,%d→%d,%d(%d칸)" % (a.get("name", "?"), int(Q[0][0]), int(Q[0][1]), int(Q[-1][0]), int(Q[-1][1]), int(S)))
            # 무너진 경간
            gaps = []
            lo, hi = Lr[0] + 20, S - Lr[1] - 20
            pos = lo
            while pos + 140 < hi:
                if rng.random() < 0.45:
                    g0 = pos + float(rng.uniform(20, 110))
                    gl = float(rng.integers(4, 13))
                    if g0 + gl < hi:
                        gaps.append((g0, g0 + gl))
                pos += 140
            need = STATE.get(a.get("name", ""), {}).get("gaps", 0) - sum(1 for r_ in stats.setdefault("by", {}).get(a.get("name", ""), []) for _ in r_)
            tries = 0
            while len(gaps) < need and tries < 40 and hi - lo > 30:
                tries += 1
                g0 = float(rng.uniform(lo, hi - 12))
                gl = float(rng.integers(4, 13))
                if all(g0 + gl + 25 < a0 or g0 > a1 + 25 for (a0, a1) in gaps):
                    gaps.append((g0, g0 + gl))
            gaps.sort()
            stats["by"].setdefault(a.get("name", ""), []).append(gaps)
            for (g0, g1) in gaps:
                gz = (smin >= g0) & (smin <= g1) & (dmin <= half + 1.6) & ~pre & ~post
                gapz[win] |= gz
                sub[gz & np.isin(sub, (DK_DECK,))] = DK_NONE
                edge = surf & ~gz & (((smin >= g0 - 1.3) & (smin < g0)) | ((smin > g1) & (smin <= g1 + 1.3)))
                sub[edge & (sub == DK_DECK)] = DK_BROKEN
                yy, xx = np.nonzero(gz & (dmin <= half))
                for y, x in zip(yy, xx):
                    rubble.append((x + x0, y + y0, float(dmin[y, x]) < half - 0.5))
                stats["gaps"] += 1
            # 끊긴 램프(SD-21 §6.3 E-01 '램프 일부 끊김'): 시작 쪽 램프의 아래 절반이 무너져 막힌 끝이 된다(남은 위 절반은 끊긴 상판)
            nm_ = a.get("name", "")
            cut_start = False
            if STATE.get(nm_, {}).get("broken_ramps", 0) > stats.setdefault("ramp_cut", {}).get(nm_, 0):
                stats["ramp_cut"][nm_] = stats["ramp_cut"].get(nm_, 0) + 1
                cut_start = True
                cut = rmp & (smin < Lr[0] * 0.5)
                keep = rmp & ~cut & (smin < Lr[0])
                sub[cut & (sub == DK_RAMP)] = DK_NONE
                gapz[win] |= cut | (pre & (dmin <= half + 1.6))
                sub[keep & (sub == DK_RAMP)] = DK_DECK
                sub[keep & (smin < Lr[0] * 0.5 + 1.3) & (sub == DK_DECK)] = DK_BROKEN
                rh[cut | keep] = -1.0
                yy, xx = np.nonzero(cut & (dmin <= half))
                for y, x in zip(yy, xx):
                    rubble.append((x + x0, y + y0, float(dmin[y, x]) < half - 0.5))
                stats["ramps"] -= 1
            # 기둥
            sp = Lr[0] + 3.0
            while sp < S - Lr[1] - 3:
                if not any(g0 - 2 <= sp <= g1 + 2 for (g0, g1) in gaps):
                    pm = surf & (np.abs(smin - sp) < 0.75) & (dmin < 1.1)
                    sub[pm & (sub == DK_DECK)] = DK_PILLAR
                    pillar_s[win] |= surf & (np.abs(smin - sp) < 0.9)
                    stats["pillars"] += 1
                sp += float(rng.integers(6, 11))
            # 버려진 차(2칸, 방향은 노선 방향)
            cp = Lr[0] + 6.0
            while cp < S - Lr[1] - 6:
                if rng.random() < 0.5 and not any(g0 - 4 <= cp <= g1 + 4 for (g0, g1) in gaps):
                    k = int(np.searchsorted(s, cp))
                    k = min(k, len(Q) - 2)
                    tx, ty = Q[k + 1] - Q[k]
                    nx, ny = -ty, tx
                    nn = max(1e-6, math.hypot(nx, ny))
                    off = float(rng.uniform(-(half - 1.6), half - 1.6))
                    px_, py_ = Q[k][0] + nx / nn * off, Q[k][1] + ny / nn * off
                    ew = abs(tx) >= abs(ty)
                    c1 = (int(px_), int(py_))
                    c2 = (c1[0] + 1, c1[1]) if ew else (c1[0], c1[1] + 1)
                    wrecks.append((c1, c2, ew, int(rng.integers(0, 4))))
                cp += float(rng.uniform(14, 30))
            # 비상계단 자리(나중에 방호벽이 정해진 뒤 놓는다)
            st = Lr[0] + float(rng.integers(12, 24))
            secs = []
            bounds = [Lr[0]] + [v for g in gaps for v in g] + [S - Lr[1]]
            for i in range(0, len(bounds), 2):
                secs.append((bounds[i], bounds[i + 1]))
            plan = []
            while st < S - Lr[1] - 10:
                if not any(g0 - 3 <= st <= g1 + 3 for (g0, g1) in gaps):
                    plan.append([st, rng.random() < 0.3])
                st += float(rng.integers(32, 50))
            for si, (a0, a1) in enumerate(secs):                               # 램프가 없는 토막(무너진 경간 사이)엔 계단 하나는 남긴다
                has_ramp = (si == 0 and not cut_start) or si == len(secs) - 1
                mine = [p for p in plan if a0 < p[0] < a1]
                if not has_ramp:
                    if not mine and a1 - a0 > 8:
                        plan.append([(a0 + a1) / 2, False])
                    elif mine and all(p[1] for p in mine):
                        mine[0][1] = False
            for p in plan:
                k = min(int(np.searchsorted(s, p[0])), len(Q) - 2)
                stair_plan.append((Q[k], Q[k + 1] - Q[k], half, p[1]))
    # 상판 위 차(층 1 막힘): 두 칸이 모두 노면이고 방호벽에서 떨어져 있을 때만
    for (c1, c2, ew, v) in wrecks:
        if all(0 <= c[0] < W and 0 <= c[1] < H and code[c[1], c[0]] == DK_DECK for c in (c1, c2)):
            if all(code[c[1] + dy, c[0] + dx] in (DK_DECK, DK_PILLAR, DK_JUNK) for c in (c1, c2) for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0))):
                code[c1[1], c1[0]] = DK_JUNK
                code[c2[1], c2[0]] = DK_JUNK
                top[c1[1], c1[0]] = tid("ev:car_%s%d" % ("l" if ew else "t", v))
                top[c2[1], c2[0]] = tid("ev:car_%s%d" % ("r" if ew else "b", v))
                stats["cars"] += 1
                if _h(c1[0], c1[1], 13) % 100 < 60:
                    boxes.append({"x": int(c1[0]), "y": int(c1[1]), "w": 2 if ew else 1, "h": 1 if ew else 2, "kind": "car", "fl": 1,
                                  "name": "고가 위 버려진 차 트렁크", "owner": "", "lock": 25 if _h(c1[0], c1[1], 14) % 100 < 20 else 0})
    # 방호벽·옹벽 고리: 노면·램프 둘레 8이웃(무너진 경간·램프 아래 끝 너머는 열어 둔다)
    walk = np.isin(code, SURF + (DK_RAMP,))
    dil = walk.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            dil |= np.roll(np.roll(walk, dy, 0), dx, 1)
    ring = dil & ~walk & ~gapz & ~opening & (code == DK_NONE)
    rampm = code == DK_RAMP
    near_ramp = np.zeros((H, W), bool)
    near_deck = np.zeros((H, W), bool)
    deckm = np.isin(code, SURF)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            near_ramp |= np.roll(np.roll(rampm, dy, 0), dx, 1)
            near_deck |= np.roll(np.roll(deckm, dy, 0), dx, 1)
    code[ring & near_ramp & ~near_deck] = DK_WALL
    code[ring & ~(near_ramp & ~near_deck)] = DK_RAIL
    # 비상계단: 노선 옆 방호벽 칸(층계참) + 바깥으로 2칸(디딤판·끝) — 끝 너머 땅이 걸을 수 있어야 한다
    for (q, tv, half, brk) in stair_plan:
        tx, ty = tv / max(1e-6, np.hypot(*tv))
        nx, ny = -ty, tx
        if abs(nx) >= abs(ny):
            d4 = (1 if nx > 0 else -1, 0)
        else:
            d4 = (0, 1 if ny > 0 else -1)
        if abs(tx) >= abs(ty):                                             # 동서로 달리는 상판: 남쪽으로 내려간다(남북 계단만 정면으로 — SD-16 §6.5)
            d4 = (0, 1)
        x, y = int(q[0]), int(q[1])
        k = 0
        while k < 12 and 0 <= x < W and 0 <= y < H and code[y, x] != DK_RAIL:
            x += d4[0]; y += d4[1]; k += 1
        if not (0 <= x < W and 0 <= y < H) or code[y, x] != DK_RAIL:
            continue
        cells = [(x + d4[0] * i, y + d4[1] * i) for i in range(3)]
        land = (x + d4[0] * 3, y + d4[1] * 3)
        if not all(0 <= c[0] < W and 0 <= c[1] < H for c in cells + [land]):
            continue
        if any(code[c[1], c[0]] != DK_NONE for c in cells[1:] + [land]) or not all(land_ok[c[1], c[0]] for c in cells[1:] + [land]):
            continue
        if brk:
            rubble.append((cells[2][0], cells[2][1], False))
            stats["stairs_broken"] += 1
            continue
        o = "ns" if d4[0] == 0 else "ew"
        for i, c in enumerate(cells):
            code[c[1], c[0]] = DK_STAIR
            low[c[1], c[0]] = tid("ev:stair_%s%s" % (o, ("top", "mid", "bot")[i]))
        stats["stairs"] += 1
    # 그림: 위층(상판) · 아래층(그늘·기둥·램프·옹벽·잔해)
    ys, xs = np.nonzero(code)
    is_surf = lambda x, y: 0 <= x < W and 0 <= y < H and code[y, x] in SURF
    is_gap = lambda x, y: 0 <= x < W and 0 <= y < H and gapz[y, x]
    for y, x in zip(ys, xs):
        c = code[y, x]
        h_ = _h(x, y, 7)
        if c in (DK_DECK, DK_PILLAR):
            r_ = h_ % 100
            v = 1 if r_ < 4 else (2 if r_ < 7 else (4 if r_ < 9 else (3 if r_ < 10 else 0)))   # 균열 4% · 땜질 3% · 기름 2% · 포트홀 1%
            if lane_k[y, x] and v == 0:
                top[y, x] = tid(("ev:lane%d" if lane_k[y, x] == 1 else "ev:cline%d") % int(lane_o[y, x]))
            else:
                top[y, x] = tid("ev:deck%d" % v)
        elif c == DK_BROKEN:
            g = sum(b for dx, dy, b in N4 if is_gap(x + dx, y + dy))
            top[y, x] = tid("ev:brk%d_%d" % (g, h_ & 1)) if g else tid("ev:deck1")
        elif c == DK_RAIL:
            sm = sum(b for dx, dy, b in N4 if is_surf(x + dx, y + dy) or (0 <= x + dx < W and 0 <= y + dy < H and code[y + dy, x + dx] == DK_STAIR))
            if sm:
                top[y, x] = tid("ev:rail%d" % sm)
            else:
                cm = sum(b for dx, dy, b in D4 if is_surf(x + dx, y + dy))
                if cm:
                    top[y, x] = tid("ev:railc%d" % cm)
        elif c == DK_RAMP:
            hb = int(min(3, max(0, ramp_h[y, x] * 4)))
            low[y, x] = tid("ev:ramp%d%d" % (hb, 1 if h_ % 9 == 0 else 0))
        elif c == DK_WALL:
            sm = sum(b for dx, dy, b in N4 if 0 <= x + dx < W and 0 <= y + dy < H and code[y + dy, x + dx] == DK_RAMP)
            hs = [ramp_h[y + dy, x + dx] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                  if 0 <= x + dx < W and 0 <= y + dy < H and code[y + dy, x + dx] == DK_RAMP]
            hb = int(min(3, max(0, (max(hs) if hs else 0) * 4)))
            low[y, x] = tid("ev:rwall%d_%d" % (sm, hb))
        if c in (DK_DECK, DK_RAIL, DK_BROKEN, DK_JUNK):
            low[y, x] = tid("ev:shade")
        elif c == DK_PILLAR:
            low[y, x] = tid("ev:pbase")
    stats["deck"] = int(np.isin(code, SURF).sum())
    # 상판 남쪽 끝 앞 칸: 상판 아래 빈 공간(그늘 + 안쪽 기둥 그림자)
    topm = np.isin(code, (DK_DECK, DK_RAIL, DK_PILLAR, DK_BROKEN, DK_JUNK))
    south = np.roll(topm, 1, 0) & ~topm & (code == DK_NONE)
    yy, xx = np.nonzero(south)
    for y, x in zip(yy, xx):
        pil = pillar_s[y - 1, x] or pillar_s[max(0, y - 2), x]
        low[y, x] = tid("ev:under%s%d" % ("_p" if pil else "", _h(x, y, 9) & 1))
        if y + 1 < H and code[y + 1, x] == DK_NONE and low[y + 1, x] == 0:
            low[y + 1, x] = tid("ev:shade2")                                   # 그림자 끝 한 줄 더(높이 1단 = 그림자 16px 남짓, SD-16 §3.9)
    solid_on = np.isin(code, (DK_PILLAR, DK_WALL))
    cover = np.zeros((H, W), np.uint8)
    cover[solid_on] = 2
    heap = np.zeros((H, W), bool)
    for (x, y, centre) in rubble:
        if code[y, x] == DK_NONE and low[y, x] == 0:
            low[y, x] = tid("ev:rubble%d" % (_h(x, y, 11) % 4))
            if centre and _h(x, y, 12) % 100 < 35:                             # 잔해 더미 일부는 막는다(땅 길은 남긴다)
                heap[y, x] = True
    cover[heap] = 1
    noprop = np.isin(code, (DK_RAMP, DK_WALL, DK_STAIR, DK_RAIL)) | heap
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            noprop |= np.roll(np.roll(np.isin(code, (DK_RAMP, DK_STAIR)), dy, 0), dx, 1)
    clear = code > 0
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            clear |= np.roll(np.roll(code > 0, dy, 0), dx, 1)
    for w_ in stats.get("where", []):
        log("  고가 구간: " + w_)
    log("고가: 구간 %d(%s) · 상판 %d칸 · 램프 %d · 기둥 %d · 무너진 경간 %d · 비상계단 %d(무너짐 %d) · 버려진 차 %d" % (
        stats["runs"], ", ".join(sorted(set(stats["names"]))), stats["deck"], stats["ramps"], stats["pillars"], stats["gaps"],
        stats["stairs"], stats["stairs_broken"], stats["cars"]))
    return {"code": code, "top": top, "low": low, "solid_on": solid_on | heap, "cover": cover, "noprop": noprop, "clear": clear,
            "ramp": code == DK_RAMP, "stats": stats, "boxes": boxes}
