"""동네 길 연결 후처리(SD-21 §5 '연결 보장' — 사용자 지적 2026-10-21 '끊긴 도로가 너무 많다').

결(F1~F7)마다 다른 보로노이를 결 마스크로 자르고 변을 해시로 지우는 생성기(road_net.local_streets)는 그래프를 보지 않는다 —
결 경계 · 지운 변 끝에서 길이 흙으로 뚝 끊기고, 언덕 등고선 길은 서로 안 닿는 고리 섬이 된다. 여기서 그 결과를 그래프로 읽어 고친다:
  ① 막다른 끝(골격 끝점, 꼬리 4칸 이상): 진행 방향 앞(±70°) 반경 22칸 안의 다른 길 · 간선 가장자리로 곧은 길을 잇는다.
     이을 데가 없으면 꼬리를 8칸까지 줄인다(집 앞 막다른 길 정도만 남긴다).
  ② 간선에 닿지 않는 섬: 너비 우선으로 가장 가까운 '간선에 닿은 길'까지 잇는다(언덕 결이면 계단 골목 폭). 못 이으면 지운다.
  ③ 아무 데도 안 닿는 6칸 이하 골목 부스러기는 지운다.
이은 길은 선분 목록으로 돌려준다 — 굽기가 칸 꼭짓점 거리장(도로 경계 v3)에 같은 선분을 더해 곧은 가장자리로 그린다.
순수 numpy + 파이썬(scipy 없음)."""
from collections import deque

import numpy as np

N8 = ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1))
TIP_R = 22                     ## 막다른 끝에서 이을 곳을 찾는 반경(칸)
TIP_COS = 0.34                 ## 진행 방향과 이루는 각 cos 하한(약 70°)
TAIL_MIN = 4                   ## 이보다 짧은 꼬리는 골격 잔가지(굵은 길 모서리)로 본다
TAIL_KEEP = 8                  ## 이을 데 없는 꼬리는 이 길이까지 줄인다
ISLAND_R = 26                  ## 섬을 이을 때 너비 우선 탐색 깊이
ISLAND_DROP = 40               ## 이보다 작은 섬은 잇지 않고 지운다
HILL_DROP = 160                ## 언덕 결(F2)에서는 이보다 작은 섬(작은 등고선 고리)을 지운다
CRUMB = 6                      ## 이하 골목 부스러기는 지운다
W_STREET = 2.4                 ## 이은 동네 길 폭
W_ALLEY = 1.2                  ## 이은 골목(언덕 계단 골목) 폭


def _nb_count(m):
    p = np.pad(m, 1).astype(np.uint8)
    H, W = m.shape
    return sum(p[1 + dy:1 + dy + H, 1 + dx:1 + dx + W] for dy, dx in N8)


def dilate(m, k=1):
    o = m.copy()
    for _ in range(k):
        p = np.pad(o, 1)
        H, W = o.shape
        q = o.copy()
        for dy, dx in N8:
            q |= p[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
        o = q
    return o


def thin(m):
    """Zhang-Suen 가늘게 하기(벡터화) — 길 마스크의 골격"""
    img = np.pad(m.astype(np.uint8), 1)
    while True:
        changed = False
        for step in (0, 1):
            P = img
            p2, p3, p4 = P[:-2, 1:-1], P[:-2, 2:], P[1:-1, 2:]
            p5, p6, p7 = P[2:, 2:], P[2:, 1:-1], P[2:, :-2]
            p8, p9 = P[1:-1, :-2], P[:-2, :-2]
            c = P[1:-1, 1:-1]
            B = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9
            seq = [p2, p3, p4, p5, p6, p7, p8, p9, p2]
            A = sum(((seq[i] == 0) & (seq[i + 1] == 1)).astype(np.uint8) for i in range(8))
            if step == 0:
                cond = (p2 * p4 * p6 == 0) & (p4 * p6 * p8 == 0)
            else:
                cond = (p2 * p4 * p8 == 0) & (p2 * p6 * p8 == 0)
            rm = (c == 1) & (B >= 2) & (B <= 6) & (A == 1) & cond
            if rm.any():
                changed = True
                img[1:-1, 1:-1][rm] = 0
        if not changed:
            break
    return img[1:-1, 1:-1].astype(bool)


def label8(m):
    """8방향 연결 성분(행 구간 합치기) → (번호 배열, 개수)"""
    H, W = m.shape
    par = []

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a
    runs = []
    n = 0
    for y in range(H):
        d = np.diff(np.concatenate([[0], m[y].astype(np.int8), [0]]))
        st = np.nonzero(d == 1)[0]
        en = np.nonzero(d == -1)[0] - 1
        rr = []
        for s, e in zip(st.tolist(), en.tolist()):
            rr.append((s, e, n))
            par.append(n)
            n += 1
        runs.append(rr)
    for y in range(H - 1):
        a_, b_ = runs[y], runs[y + 1]
        i = j = 0
        while i < len(a_) and j < len(b_):
            a, b = a_[i], b_[j]
            if a[0] <= b[1] + 1 and b[0] <= a[1] + 1:
                ra, rb = find(a[2]), find(b[2])
                if ra != rb:
                    par[max(ra, rb)] = min(ra, rb)
            if a[1] < b[1]:
                i += 1
            else:
                j += 1
    roots = {}
    lab = np.zeros((H, W), np.int32)
    for y in range(H):
        for (s, e, i) in runs[y]:
            r = find(i)
            if r not in roots:
                roots[r] = len(roots) + 1
            lab[y, s:e + 1] = roots[r]
    return lab, len(roots)


def seg_cells(x0, y0, x1, y1, hw, H, W):
    """선분(연속 좌표 — 칸 (x, y) 중심 = (x + .5, y + .5))에서 hw 안의 칸"""
    bx0, bx1 = int(max(0, np.floor(min(x0, x1) - hw - 1))), int(min(W, np.ceil(max(x0, x1) + hw + 1)))
    by0, by1 = int(max(0, np.floor(min(y0, y1) - hw - 1))), int(min(H, np.ceil(max(y0, y1) + hw + 1)))
    ys, xs = np.mgrid[by0:by1, bx0:bx1].astype(np.float32)
    d = seg_dist(xs + 0.5, ys + 0.5, x0, y0, x1, y1)
    return (slice(by0, by1), slice(bx0, bx1)), d < hw


def seg_dist(px, py, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    L2 = max(1e-6, dx * dx + dy * dy)
    t = np.clip(((px - x0) * dx + (py - y0) * dy) / L2, 0.0, 1.0)
    return np.hypot(px - (x0 + t * dx), py - (y0 + t * dy))


def _line_ok(ok, x0, y0, x1, y1):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2.5) + 1
    for k in range(n + 1):
        t = k / n
        x, y = int(x0 + (x1 - x0) * t), int(y0 + (y1 - y0) * t)
        if not ok[y, x]:
            return False
    return True


def link(street, alley, track, hub, passable, fab, keep=None, log=print):
    """street · alley · track: 동네 길 마스크(제자리에서 고친다). hub: 간선(차도 · 보도 · 분리대 — 닿으면 연결된 것).
    passable: 새 길을 낼 수 있는 칸(땅 · 높이 0 · 건물 없음). fab: 결 번호(언덕 = 1). keep: 지우지 않을 칸(고정 건물 문 앞).
    반환: 이은 선분 [(x0, y0, x1, y1, 폭, "street"|"alley"|"track")]와 지운 칸 마스크"""
    H, W = street.shape
    keep = np.zeros((H, W), bool) if keep is None else keep
    net0 = street | alley | track
    segs = []
    removed = np.zeros((H, W), bool)
    hub_e = dilate(hub, 1) & ~hub
    ok = passable | net0 | hub

    def paint(x0, y0, x1, y1, w, layer):
        sl, m = seg_cells(x0, y0, x1, y1, w / 2.0, H, W)
        m &= ok[sl] & ~hub[sl]
        tgt = street if layer == "street" else (alley if layer == "alley" else track)
        tgt[sl] |= m
        segs.append((float(x0), float(y0), float(x1), float(y1), float(w), layer))

    # ---- ① 막다른 끝
    net = street | alley | track
    sk = thin(net)
    nb = _nb_count(sk) * sk
    tips = np.argwhere((nb == 1) & ~dilate(hub, 2))
    skl = sk.tolist()
    n_link = n_cut = 0
    cut = np.zeros((H, W), bool)
    for ty, tx in tips.tolist():
        # 꼬리 따라가기: 갈래(이웃 3+) · 간선 · 다른 끝까지
        trail = [(ty, tx)]
        prev = None
        cy, cx = ty, tx
        while len(trail) < 80:
            nxt = [(cy + dy, cx + dx) for dy, dx in N8 if 0 <= cy + dy < H and 0 <= cx + dx < W and skl[cy + dy][cx + dx] and (cy + dy, cx + dx) != prev and (cy + dy, cx + dx) not in trail[-3:]]
            if len(nxt) != 1:
                break
            prev = (cy, cx)
            cy, cx = nxt[0]
            if nb[cy, cx] >= 3:
                break
            trail.append((cy, cx))
        L = len(trail)
        if L < TAIL_MIN:
            continue
        by, bx = trail[min(L - 1, 6)]
        dvx, dvy = tx - bx, ty - by
        dn = max(1e-6, (dvx * dvx + dvy * dvy) ** 0.5)
        dvx, dvy = dvx / dn, dvy / dn
        # 골격 위 거리(꼬리 쪽으로 되돌아 닿는 곳은 빼려고): 끝점에서 골격 너비 우선 90걸음
        dist = {(ty, tx): 0}
        q = deque([(ty, tx)])
        while q:
            y, x = q.popleft()
            d = dist[(y, x)]
            if d >= 90:
                continue
            for dy, dx in N8:
                yy, xx = y + dy, x + dx
                if 0 <= yy < H and 0 <= xx < W and skl[yy][xx] and (yy, xx) not in dist:
                    dist[(yy, xx)] = d + 1
                    q.append((yy, xx))
        y0, y1, x0, x1 = max(0, ty - TIP_R), min(H, ty + TIP_R + 1), max(0, tx - TIP_R), min(W, tx + TIP_R + 1)
        cand = np.argwhere(sk[y0:y1, x0:x1] | hub_e[y0:y1, x0:x1]) + (y0, x0)
        best = None
        for cy_, cx_ in cand.tolist():
            vx, vy = cx_ - tx, cy_ - ty
            e = (vx * vx + vy * vy) ** 0.5
            if e < 2.0 or e > TIP_R:
                continue
            cs = (vx * dvx + vy * dvy) / e
            if cs < TIP_COS:
                continue
            if not hub_e[cy_, cx_]:
                dd = dist.get((cy_, cx_))
                if dd is not None and dd < 2.5 * e + 8:
                    continue                                              # 제 꼬리 · 바로 옆 갈래로 되돌아오는 길
            cost = e * (1.6 - 0.6 * cs)
            if best is None or cost < best[0]:
                best = (cost, cx_, cy_)
        done = False
        if best is not None:
            _, gx, gy = best
            if _line_ok(ok, tx + 0.5, ty + 0.5, gx + 0.5, gy + 0.5):
                layer = "street" if street[ty, tx] else ("alley" if alley[ty, tx] else "track")
                w = W_STREET if layer == "street" else (W_ALLEY if layer == "alley" else 2.0)
                ex, ey = gx + 0.5 + dvx * 0.8, gy + 0.5 + dvy * 0.8          # 닿는 쪽 길 안으로 조금 더(이음매 틈 없게)
                paint(tx + 0.5, ty + 0.5, ex, ey, w, layer)
                n_link += 1
                done = True
        if not done and L > TAIL_KEEP and not keep[ty, tx]:
            for (y, x) in trail[:L - TAIL_KEEP]:
                cut[y, x] = True
            n_cut += 1
    if cut.any():
        kept_sk = sk & ~cut
        rm = dilate(cut, 2) & ~dilate(kept_sk, 2) & ~keep
        rm &= street | alley | track
        for m in (street, alley, track):
            m &= ~rm
        removed |= rm
    log("길 연결: 막다른 끝 %d · 이음 %d · 꼬리 줄임 %d" % (len(tips), n_link, n_cut))

    # ---- ② 간선에 안 닿는 섬
    hub_d = dilate(hub, 1)
    n_isl = n_join = n_drop = 0
    for rnd in range(6):
        net = street | alley | track
        lab, n = label8(net)
        if n == 0:
            break
        touch = np.zeros(n + 1, bool)
        touch[np.unique(lab[hub_d & net])] = True
        touch[0] = False
        size = np.bincount(lab.ravel(), minlength=n + 1)
        main = touch[lab] | hub
        isl = [i for i in range(1, n + 1) if not touch[i]]
        if rnd == 0:
            n_isl = len(isl)
        if not isl:
            break
        progress = False
        okl = ok.tolist()
        mainl = main.tolist()
        idx = {}
        ys_, xs_ = np.nonzero(lab)
        lv = lab[ys_, xs_]
        order = np.argsort(lv, kind="stable")
        ys_, xs_, lv = ys_[order], xs_[order], lv[order]
        starts = np.searchsorted(lv, np.arange(n + 2))
        for i in sorted(isl, key=lambda i: -size[i]):
            cells = list(zip(ys_[starts[i]:starts[i + 1]].tolist(), xs_[starts[i]:starts[i + 1]].tolist()))
            if size[i] < ISLAND_DROP and not any(keep[y, x] for y, x in cells):
                continue
            if size[i] < HILL_DROP and sum(1 for y, x in cells if fab[y, x] == 1) * 2 > len(cells):
                continue                                                  # 언덕의 작은 고리 섬(타원 하나)은 잇지 않고 지운다

            seen = {c: c for c in cells}                                 # 칸 → 출발 칸
            depth = {c: 0 for c in cells}
            q = deque(cells)
            hit = None
            while q:
                c = q.popleft()
                d = depth[c]
                if d >= ISLAND_R:
                    continue
                y, x = c
                for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    yy, xx = y + dy, x + dx
                    if not (0 <= yy < H and 0 <= xx < W) or (yy, xx) in seen or not okl[yy][xx]:
                        continue
                    seen[(yy, xx)] = seen[c]
                    depth[(yy, xx)] = d + 1
                    if mainl[yy][xx]:
                        hit = (yy, xx)
                        break
                    q.append((yy, xx))
                if hit:
                    break
            if hit is None:
                continue
            sy, sx = seen[hit]
            hy, hx = hit
            hill = fab[sy, sx] == 1
            layer = "alley" if (hill or not street[sy, sx]) and not track[sy, sx] else ("track" if track[sy, sx] else "street")
            w = W_ALLEY if layer == "alley" else (2.0 if layer == "track" else W_STREET)
            if _line_ok(ok, sx + 0.5, sy + 0.5, hx + 0.5, hy + 0.5):
                vx, vy = hx - sx, hy - sy
                e = max(1e-6, (vx * vx + vy * vy) ** 0.5)
                paint(sx + 0.5, sy + 0.5, hx + 0.5 + vx / e * 0.8, hy + 0.5 + vy / e * 0.8, w, layer)
            else:                                                         # 곧게 못 가면 너비 우선 길을 꺾은선으로(되짚기)
                path = [hit]
                c = hit
                while depth[c] > 0:
                    y, x = c
                    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        p = (y + dy, x + dx)
                        if p in depth and depth[p] == depth[c] - 1 and seen.get(p) == seen[hit]:
                            c = p
                            break
                    else:
                        break
                    path.append(c)
                pts = _simplify(path[::-1])
                for (ay, ax), (by_, bx_) in zip(pts[:-1], pts[1:]):
                    paint(ax + 0.5, ay + 0.5, bx_ + 0.5, by_ + 0.5, w, layer)
            n_join += 1
            progress = True
            for c in cells:                                               # 이 섬은 이제 본망(다음 섬이 여기에 닿아도 된다)
                mainl[c[0]][c[1]] = True
        if not progress:
            break
    net = street | alley | track
    lab, n = label8(net)
    touch = np.zeros(n + 1, bool)
    touch[np.unique(lab[hub_d & net])] = True
    touch[0] = False
    keep_lab = np.zeros(n + 1, bool)
    keep_lab[np.unique(lab[keep & net])] = True
    drop = ~touch & ~keep_lab
    drop[0] = False
    rm = drop[lab]
    n_drop = int(np.count_nonzero(np.unique(lab[rm])))
    for m in (street, alley, track):
        m &= ~rm
    removed |= rm
    log("길 연결: 섬 %d · 이음 %d · 지움 %d(%d칸)" % (n_isl, n_join, n_drop, int(rm.sum())))
    # ---- ③ 골목 부스러기(간선 · 길에 닿아도 6칸 이하 골목 덩어리는 칸 모양 콘크리트 판으로만 보인다)
    lab, n = label8(alley & ~dilate(street | track, 1))
    size = np.bincount(lab.ravel(), minlength=n + 1)
    small = size <= CRUMB
    small[0] = False
    rm = small[lab] & ~keep
    alley &= ~rm
    removed |= rm
    # 길 · 골목 · 흙길 마스크마다 3칸 이하 점(이은 길이 골목을 덮고 남은 꼬투리 · 꼬리 줄임 가장자리)
    n_dot = 0
    for m in (street, alley, track):
        lab, n = label8(m)
        size = np.bincount(lab.ravel(), minlength=n + 1)
        small = size <= 3
        small[0] = False
        rm = small[lab] & ~keep
        m &= ~rm
        removed |= rm
        n_dot += int(rm.sum())
    log("길 연결: 부스러기 %d칸 · 점 %d칸 지움" % (int(removed.sum()), n_dot))
    return segs, removed


def _simplify(pts, eps=1.2):
    """더글러스-포이커(칸 좌표 (y, x) 목록)"""
    if len(pts) < 3:
        return pts
    a, b = np.array(pts[0], float), np.array(pts[-1], float)
    ab = b - a
    L = max(1e-6, float(np.hypot(*ab)))
    dmax, k = 0.0, 0
    for i in range(1, len(pts) - 1):
        p = np.array(pts[i], float) - a
        d = abs(ab[0] * p[1] - ab[1] * p[0]) / L
        if d > dmax:
            dmax, k = d, i
    if dmax <= eps:
        return [pts[0], pts[-1]]
    return _simplify(pts[:k + 1], eps)[:-1] + _simplify(pts[k:], eps)


def vertex_field(segs, shape_v, layer_set):
    """선분 목록 → 칸 꼭짓점 거리장(꼭짓점 (i, j) = 점 (j, i), 길 안 음수). shape_v = (H + 1, W + 1)"""
    Hv, Wv = shape_v
    f = np.full(shape_v, np.inf, np.float32)
    for x0, y0, x1, y1, w, layer in segs:
        if layer not in layer_set:
            continue
        hw = w / 2.0
        bx0, bx1 = int(max(0, np.floor(min(x0, x1) - hw - 2))), int(min(Wv, np.ceil(max(x0, x1) + hw + 3)))
        by0, by1 = int(max(0, np.floor(min(y0, y1) - hw - 2))), int(min(Hv, np.ceil(max(y0, y1) + hw + 3)))
        ys, xs = np.mgrid[by0:by1, bx0:bx1].astype(np.float32)
        d = seg_dist(xs, ys, x0, y0, x1, y1) - hw
        np.minimum(f[by0:by1, bx0:bx1], d, out=f[by0:by1, bx0:bx1])
    return f
