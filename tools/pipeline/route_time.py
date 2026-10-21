"""1막 동선 시간 재기(단계 1-Rg, SD-21 §7.2): 구운 월드(world.bin)를 읽어 거점 사이 걸어서 닿는 가장 짧은 길을 잰다.
  · 길: 8방향(대각 1.414, 모서리 끼어 지나가기 없음), 높이 단은 계단 칸으로만 잇는다(InteriorMap.level_link와 같다).
  · 두 가지로 잰다 — 땅(층 0)만 · 고가 포함(램프·비상계단으로 층 1에 올라 상판을 탄다, InteriorMap._blocked_floor와 같은 규칙).
  · 시간 = 길이 ÷ 기본 이동 4.0타일/초(SD-11 §2.4, SD-08 §3.7). 목표와 ±20%를 벗어나면 '고칠 것'으로 적는다(장소는 옮기지 않는다 — R6).
실행: python3 tools/pipeline/route_time.py  → 표 출력 + game/data/world/route_times.json
"""
import os, json, zlib, heapq
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WD = os.path.join(ROOT, "game", "data", "world")
SPEED = 4.0
# (출발, 도착, 목표 초, 이름) — SD-21 §7.2
LEGS = [("L-R01-01", "L-R01-09", 52, "볼트 → 봉천"),
        ("L-R01-09", "L-R01-24", 80, "봉천 → 노량진(24)"),
        ("L-R01-09", "L-R01-25", 80, "봉천 → 노량진(25)"),
        ("L-R01-09", "L-R02-11", 120, "봉천 → 영등포 지하시장"),
        ("L-R02-11", "L-R02-02", 60, "지하시장 → 여의도 벙커"),
        ("L-R02-11", "L-R02-19", 100, "지하시장 → 새벽인력 본소"),
        ("L-R02-11", "L-R01-25", 60, "지하시장 → 수산시장(FQ-JH-03 지상 배달)")]
DK_NONE, DK_DECK, DK_RAIL, DK_RAMP, DK_WALL, DK_PILLAR, DK_BROKEN, DK_STAIR, DK_JUNK = range(9)
TOP = {DK_DECK, DK_RAIL, DK_PILLAR, DK_BROKEN, DK_JUNK}
LINK = {DK_RAMP, DK_STAIR}


def load(box):
    meta = json.load(open(os.path.join(WD, "world.json"), encoding="utf-8"))
    cs = meta["chunk_size"]
    ncx, ncy = meta["chunks"]
    x0, y0, x1, y1 = box
    W, H = x1 - x0, y1 - y0
    solid = np.ones((H, W), np.uint8)
    level = np.zeros((H, W), np.int16)
    stair = np.zeros((H, W), np.uint8)
    deck = np.zeros((H, W), np.uint8)
    blob = open(os.path.join(WD, "world.bin"), "rb").read()
    n = cs * cs
    for cy in range(y0 // cs, (y1 - 1) // cs + 1):
        for cx in range(x0 // cs, (x1 - 1) // cs + 1):
            o = meta["offsets"][cy * ncx + cx]
            if o[1] == 0:
                continue
            a = np.frombuffer(zlib.decompress(blob[o[0]:o[0] + o[1]]), np.uint8)
            def lay(off, k=1):
                return a[off:off + n * k]
            sl = lay(2 * n).reshape(cs, cs)
            lv = lay(4 * n).reshape(cs, cs).astype(np.int8)
            st = lay(5 * n).reshape(cs, cs)
            dk = lay(10 * n).reshape(cs, cs) if meta.get("deck") else np.zeros((cs, cs), np.uint8)
            gx, gy = cx * cs, cy * cs
            ax0, ay0 = max(gx, x0), max(gy, y0)
            ax1, ay1 = min(gx + cs, x1), min(gy + cs, y1)
            src = (slice(ay0 - gy, ay1 - gy), slice(ax0 - gx, ax1 - gx))
            dst = (slice(ay0 - y0, ay1 - y0), slice(ax0 - x0, ax1 - x0))
            solid[dst] = sl[src]
            level[dst] = lv[src]
            stair[dst] = st[src]
            deck[dst] = dk[src]
    return solid, level, stair, deck


def route(grid, a, b, use_deck):
    solid, level, stair, deck = grid
    H, W = solid.shape

    def ground_block(t, h):
        x, y = t
        if not (0 <= x < W and 0 <= y < H) or solid[y, x]:
            return True
        if stair[y, x] or stair[h[1], h[0]]:
            return False
        return level[y, x] != level[h[1], h[0]]

    def blocked(t, h, f):
        x, y = t
        if not (0 <= x < W and 0 <= y < H):
            return True
        if not use_deck:
            return ground_block(t, h)
        d, hd = int(deck[y, x]), int(deck[h[1], h[0]])
        if f >= 1 or (hd in LINK and d in TOP):
            if d in (DK_DECK, DK_PILLAR, DK_BROKEN) or d in LINK:
                return False
            if d in (DK_RAIL, DK_WALL, DK_JUNK):
                return True
            return hd not in LINK or ground_block(t, h)
        if d in (DK_WALL, DK_PILLAR):
            return True
        if d in LINK and hd in TOP:
            return True
        return ground_block(t, h)

    def after(h, t, f):
        if not use_deck:
            return 0
        d = int(deck[t[1], t[0]])
        if d in LINK:
            return f
        if d in TOP:
            return 1 if f >= 1 or int(deck[h[1], h[0]]) in LINK else 0
        return 0

    start = (a[0], a[1], 0)
    dist = {start: 0.0}
    pq = [(0.0, start)]
    up = 0
    while pq:
        c, s = heapq.heappop(pq)
        if c > dist.get(s, 1e18):
            continue
        if (s[0], s[1]) == (b[0], b[1]):
            return c
        h = (s[0], s[1])
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
            t = (h[0] + dx, h[1] + dy)
            if blocked(t, h, s[2]):
                continue
            if dx and dy and (blocked((h[0] + dx, h[1]), h, s[2]) or blocked((h[0], h[1] + dy), h, s[2])):
                continue
            nf = after(h, t, s[2])
            ns = (t[0], t[1], nf)
            nc = c + (1.414 if dx and dy else 1.0)
            if nc < dist.get(ns, 1e18):
                dist[ns] = nc
                heapq.heappush(pq, (nc, ns))
    return None


def main():
    geo = json.load(open(os.path.join(WD, "place_geo.json"), encoding="utf-8"))
    pts = {k: tuple(geo[k]["arrive"]) for leg in LEGS for k in leg[:2] if geo.get(k, {}).get("arrive")}
    xs = [p[0] for p in pts.values()]
    ys = [p[1] for p in pts.values()]
    box = (max(0, min(xs) - 120), max(0, min(ys) - 120), max(xs) + 120, max(ys) + 120)
    grid = load(box)
    out = []
    print("1막 동선(SD-21 §7.2) — 기본 이동 %.1f타일/초" % SPEED)
    for a, b, goal, name in LEGS:
        if a not in pts or b not in pts:
            print("  %s: 도착 칸 없음(%s %s)" % (name, a in pts, b in pts))
            continue
        pa = (pts[a][0] - box[0], pts[a][1] - box[1])
        pb = (pts[b][0] - box[0], pts[b][1] - box[1])
        r0 = route(grid, pa, pb, False)
        r1 = route(grid, pa, pb, True)
        t0 = r0 / SPEED if r0 else None
        t1 = r1 / SPEED if r1 else None
        best = min(x for x in (t0, t1) if x is not None) if (t0 or t1) else None
        straight = ((pts[a][0] - pts[b][0]) ** 2 + (pts[a][1] - pts[b][1]) ** 2) ** 0.5
        geo_goal = straight * 1.3 / SPEED                                   # 판정 기준: 실제 장소 좌표 직선 × 1.3 ÷ 기본 이동(SD-08 §3.7 방식, 구현 정합)
        ok = best is not None and abs(best - geo_goal) <= geo_goal * 0.2
        print("  %s %s: 직선 %d칸 · 땅 %s · 고가 포함 %s · 기준 %.0f초 ±20%% (문서 어림 %d초) %s" % (
            "○" if ok else "×", name, straight,
            "%.0f칸 %.0f초" % (r0, t0) if r0 else "못 감", "%.0f칸 %.0f초" % (r1, t1) if r1 else "못 감", geo_goal, goal,
            "" if ok else "(길을 고칠 것)" if best is not None and best > geo_goal * 1.2 else "(곧은 길)"))
        out.append({"leg": name, "from": a, "to": b, "goal_doc": goal, "goal": round(geo_goal, 1), "ground": t0, "deck": t1, "ok": ok, "straight": straight})
    json.dump(out, open(os.path.join(WD, "route_times.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
