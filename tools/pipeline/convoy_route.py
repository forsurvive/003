"""FQ-SB-02 「현장 운송」 행렬 경로 굽기(단계 1-12f, 계획 docs/seoul-fallout/_plans/1-12f_FQ-SB-01-02_plan.md §5).
  구운 월드(world.bin)에서 도로 칸(아스팔트 · 차선 · 보도블록)을 우대하는(그 밖 칸 ×3) 최단 길을 경유점 차례로 이어 잰다.
  본소 정문 → E-02 서부간선 고가 남 램프 → 상판(층 1) → 북 램프 끝('고가 끝', 사건 ①) → 신도림(쉬는 박자) → 노량진로 → 한강철교 남단 인계 지점.
  우회(정찰로 방범대를 먼저 봤을 때): 신도림 → 대방 남쪽 큰길(DETOUR_VIA) → 방범대 자리 둘레(반경 PATROL_R)를 피해 → 인계 지점.
  경로는 6칸마다 한 점(층 포함)으로 줄여 game/data/world/convoy_sb02.json에 쓴다 — 진행기 FqSb가 선두를 한 점씩 걷게 한다.
실행: python3 tools/pipeline/convoy_route.py (build_data.sh에 포함)
"""
import os, json, zlib, heapq, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import route_time as rt

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WD = os.path.join(ROOT, "game", "data", "world")
OUT = os.path.join(WD, "convoy_sb02.json")
BOX = (590, 1130, 980, 1370)
ROAD = {4, 5, 6, 7}                       # asphalt · asphalt_lane · pavers · pavers_b (ts_r01_ext 지도책 번호 — WorldMap.road_rank와 같은 바닥)
OFF = 3.0                                 # 길 아닌 칸 값
STEP = 6                                  # 경유점 간격(칸)
GATE = (628, 1346)                        # X-SB 정문 밖(손 맵 원점 606,1307 + gate_out 22,39)
RAMP_S = (628, 1275)                      # E-02 남 램프 아래(땅)
DECK = (628, 1250)                        # 상판 가운데(층 1)
RAMP_N = (628, 1224)                      # 북 램프 끝 아래(땅) — '고가 끝'
SINDORIM = (664, 1199)                    # L-R02-24 도착 칸 — 쉬는 박자
HANDOVER = (930, 1164)                    # 한강철교 남단 인계 지점(L-HR-03 남쪽 둔치)
PATROL_BACK = 40                          # 방범대는 인계 지점 40칸 전 길 위
PATROL_R = 30                             # 우회가 피하는 반경
DETOUR_VIA = (840, 1225)                  # 우회 경유: 대방 남쪽 큰길 — 노량진로 방범대 자리를 남쪽으로 돈다


def floors(box):
    meta = json.load(open(os.path.join(WD, "world.json"), encoding="utf-8"))
    cs = meta["chunk_size"]
    ncx, _ = meta["chunks"]
    x0, y0, x1, y1 = box
    fl = np.zeros((y1 - y0, x1 - x0), np.uint8)
    blob = open(os.path.join(WD, "world.bin"), "rb").read()
    n = cs * cs
    for cy in range(y0 // cs, (y1 - 1) // cs + 1):
        for cx in range(x0 // cs, (x1 - 1) // cs + 1):
            o = meta["offsets"][cy * ncx + cx]
            if o[1] == 0:
                continue
            a = np.frombuffer(zlib.decompress(blob[o[0]:o[0] + o[1]]), np.uint8)
            f = a[0:2 * n:2].reshape(cs, cs)
            gx, gy = cx * cs, cy * cs
            ax0, ay0 = max(gx, x0), max(gy, y0)
            ax1, ay1 = min(gx + cs, x1), min(gy + cs, y1)
            fl[ay0 - y0:ay1 - y0, ax0 - x0:ax1 - x0] = f[ay0 - gy:ay1 - gy, ax0 - gx:ax1 - gx]
    return fl


def search(grid, fl, a, b, fa, fb, avoid=None):
    """a(층 fa) → b(층 fb) 도로 우대 최단 길. avoid=(중심, 반경)이면 그 둘레를 막는다. 돌려주는 값: [(x, y, 층)…] (상자 좌표)"""
    solid, level, stair, deck = grid
    H, W = solid.shape

    def ground_block(t, h):
        x, y = t
        if not (0 <= x < W and 0 <= y < H) or solid[y, x]:
            return True
        if avoid is not None and (x - avoid[0][0]) ** 2 + (y - avoid[0][1]) ** 2 <= avoid[1] ** 2:
            return True
        if stair[y, x] or stair[h[1], h[0]]:
            return False
        return level[y, x] != level[h[1], h[0]]

    def blocked(t, h, f):
        x, y = t
        if not (0 <= x < W and 0 <= y < H):
            return True
        d, hd = int(deck[y, x]), int(deck[h[1], h[0]])
        if f >= 1 or (hd in rt.LINK and d in rt.TOP):
            if d in (rt.DK_DECK, rt.DK_PILLAR, rt.DK_BROKEN) or d in rt.LINK:
                return False
            if d in (rt.DK_RAIL, rt.DK_WALL, rt.DK_JUNK):
                return True
            return hd not in rt.LINK or ground_block(t, h)
        if d in (rt.DK_WALL, rt.DK_PILLAR):
            return True
        if d in rt.LINK and hd in rt.TOP:
            return True
        return ground_block(t, h)

    def after(h, t, f):
        d = int(deck[t[1], t[0]])
        if d in rt.LINK:
            return f
        if d in rt.TOP:
            return 1 if f >= 1 or int(deck[h[1], h[0]]) in rt.LINK else 0
        return 0

    start = (a[0], a[1], fa)
    dist = {start: 0.0}
    prev = {}
    pq = [(0.0, start)]
    goal = None
    while pq:
        c, s = heapq.heappop(pq)
        if c > dist.get(s, 1e18):
            continue
        if (s[0], s[1]) == (b[0], b[1]) and s[2] == fb:
            goal = s
            break
        h = (s[0], s[1])
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
            t = (h[0] + dx, h[1] + dy)
            if blocked(t, h, s[2]):
                continue
            if dx and dy and (blocked((h[0] + dx, h[1]), h, s[2]) or blocked((h[0], h[1] + dy), h, s[2])):
                continue
            nf = after(h, t, s[2])
            ns = (t[0], t[1], nf)
            w = (1.414 if dx and dy else 1.0) * (1.0 if (nf >= 1 or int(fl[t[1], t[0]]) in ROAD) else OFF)
            nc = c + w
            if nc < dist.get(ns, 1e18):
                dist[ns] = nc
                prev[ns] = s
                heapq.heappush(pq, (nc, ns))
    if goal is None:
        return None
    path = [goal]
    while path[-1] in prev:
        path.append(prev[path[-1]])
    return path[::-1]


def thin(path):
    """6칸마다 · 층이 바뀌는 자리 · 마지막 칸"""
    out = [path[0]]
    for i in range(1, len(path)):
        p = path[i]
        if i == len(path) - 1 or p[2] != out[-1][2] or (i % STEP) == 0:
            out.append(p)
    return out


def main():
    grid = rt.load(BOX)
    fl = floors(BOX)
    x0, y0 = BOX[0], BOX[1]

    def loc(p):
        return (p[0] - x0, p[1] - y0)

    legs = [(GATE, 0, RAMP_S, 0), (RAMP_S, 0, DECK, 1), (DECK, 1, RAMP_N, 0), (RAMP_N, 0, SINDORIM, 0), (SINDORIM, 0, HANDOVER, 0)]
    full = []
    marks = {}
    tiles = 0
    road = 0
    for a, fa, b, fb in legs:
        p = search(grid, fl, loc(a), loc(b), fa, fb)
        if p is None:
            print("경로 없음: %s → %s" % (a, b))
            sys.exit(1)
        if full:
            p = p[1:]
        for q in p:
            tiles += 1
            if q[2] >= 1 or int(fl[q[1], q[0]]) in ROAD:
                road += 1
        full += p
        if b == RAMP_N:
            marks["ramp_n_raw"] = len(full) - 1
        if b == SINDORIM:
            marks["sindorim_raw"] = len(full) - 1
    # 방범대 자리: 인계 지점 40칸 전(경로 위)
    pi = max(0, len(full) - 1 - PATROL_BACK)
    patrol = (full[pi][0] + x0, full[pi][1] + y0)
    # 우회: 신도림 → 방범대 둘레를 피해 → 인계 지점
    av = ((patrol[0] - x0, patrol[1] - y0), PATROL_R)
    d1 = search(grid, fl, loc(SINDORIM), loc(DETOUR_VIA), 0, 0, avoid=av)
    d2 = search(grid, fl, loc(DETOUR_VIA), loc(HANDOVER), 0, 0, avoid=av)
    det = (d1 + d2[1:]) if d1 and d2 else None
    pts = thin(full)
    wp = [[q[0] + x0, q[1] + y0, q[2]] for q in pts]

    def idx_near(t):
        return min(range(len(wp)), key=lambda i: abs(wp[i][0] - t[0]) + abs(wp[i][1] - t[1]) + (0 if wp[i][2] == 0 else 5))

    deck_n = sum(1 for q in full if q[2] >= 1)
    out = {"route": wp, "ramp_n": idx_near(RAMP_N), "sindorim": idx_near(SINDORIM), "patrol": idx_near(patrol), "patrol_at": list(patrol),
           "handover": len(wp) - 1, "tiles": tiles, "road_pct": round(100.0 * road / max(1, tiles)), "deck_tiles": deck_n}
    if det is not None:
        dw = thin(det)
        out["detour"] = [[q[0] + x0, q[1] + y0, q[2]] for q in dw]
        out["detour_tiles"] = len(det)
    # 고가 밑(층 0, 위에 상판) — 오태수가 숨는 칸: 북 램프 끝에서 땅으로 걸어 닿는 가장 가까운 칸
    solid, level, stair, deck = grid
    best = None
    for y in range(1243 - y0, 1260 - y0):
        for x in range(622 - x0, 636 - x0):
            if solid[y, x] or int(deck[y, x]) not in (rt.DK_DECK, rt.DK_BROKEN, rt.DK_JUNK) or int(deck[y, x]) in rt.LINK:
                continue
            p = search(grid, fl, loc(RAMP_N), (x, y), 0, 0)
            if p is not None and (best is None or len(p) < best[0]):
                best = (len(p), x + x0, y + y0)
    if best is not None:
        out["hide"] = [best[1], best[2]]
    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False)
    walk = 2.5                                            # FqSb.PACE(행렬 걸음 칸/초)
    print("운송 경로(FQ-SB-02): %d칸 · 도로 %d%% · 상판 %d칸 · 경유점 %d · 걸음 %.0f초(게임 %.0f분)%s" % (
        tiles, out["road_pct"], deck_n, len(wp), tiles / walk, tiles / walk / 2.0,
        (" · 우회 신도림→인계 %d칸(본길 %d칸)" % (len(det), len(full) - marks["sindorim_raw"])) if det else " · 우회 없음"))
    print("  고가 끝 #%d %s · 신도림 #%d · 방범대 #%d %s · 인계 #%d %s · 숨는 칸 %s" % (out["ramp_n"], wp[out["ramp_n"]], out["sindorim"], out["patrol"], patrol, out["handover"], wp[-1], out.get("hide")))


if __name__ == "__main__":
    main()
