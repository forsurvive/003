"""월드 청크 굽기·내보내기(단계 1-1, SD-08 §3.8·SD-16 §6.5~6.7·SD-19 §6.5).
world_bake(지형·도시 래스터) → 칸마다 게임 자료(바닥·덮개·막힘·엄폐·높이·계단·구조 타일·덧층) → 청크 40×40씩 압축해 한 파일로.

  ① 손 맵 끼우기: 0-10의 관악산 비탈(X-S07)·봉천 계단마을(X-BC)을 실제 좌표(볼트 S-07 문 959,1503 · 봉천 892,1362)에 찍는다.
     손 맵은 사방이 막힌 상자라 열린 길목(테두리의 걷는 칸)에서 가장 가까운 월드 길까지 흙길을 낸다(그 길의 건물·나무는 치운다).
  ② 물(깊은·중간 = 막힘), 한양도성(정면·위 길), 건물(조립 타일, 발자국 전체 막힘·높은 엄폐), 나무(R01 소품, 막힘·낮은 엄폐), 다리 상판.
  ③ 높이 단(150m부터 50m마다 1단): 높은 땅 바로 남쪽 칸 = 정면 암벽(막힘), 동·서·북 테두리 = 벼랑 끝 덧층(높이 규칙으로 막힘).
     도로·철길이 단을 넘는 칸은 비탈(계단 칸)로 잇는다.
  ④ 이어 주기: 높이가 같은 걷는 칸끼리 묶은 덩어리 사이 암벽에 돌계단을 28칸 간격으로 깎아 모든 덩어리를 잇는다.
     남북으로 맞닿지 않는 덩어리는 옆 비탈(계단 칸)로 잇는다. 끝나면 볼트 문에서 걸어서 닿는 놀이 청크 수를 센다.
  ⑤ 내보내기: game/data/world/world.bin(청크마다 zlib) + world.json(색인·손 맵 자리·소품 이름).

python3 tools/pipeline/world_chunks.py [--sample X Y W H 출력.png]
"""
import os, sys, json, zlib, struct, time
from collections import deque
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import world_bake as WB

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "world")
TIL = os.path.join(ROOT, "game", "assets", "tiles")
CS = 40
W, H = WB.W, WB.H
NCX, NCY = W // CS, H // CS
# 월드 → 실내 문(1-4, 지하로 내려가는 계단): 장소 L-ID · 요청 자리(타일) · 갈 실내 맵·표지 · 상호작용 이름
DOORS = [{"lid": "L-R02-11", "near": (720, 1147), "to": "J-01", "mark": "from_W", "name": "영등포 지하상가 북쪽 출구", "prop": "subway_stairs"},
         {"lid": "L-R02-13", "near": (734, 1156), "to": "J-02", "mark": "from_mall", "name": "역사 쇼핑몰 지하 통로", "prop": "subway_stairs_mall"},
         {"lid": "L-UG-13", "near": (672, 1099), "to": "J-09", "mark": "from_W", "name": "영등포구청역 지하 통로", "prop": "subway_stairs_st"},
         {"lid": "L-R02-02", "near": (812, 1086), "to": "Y-00", "mark": "from_W", "name": "환승센터 터 승강장 해치", "prop": "bunker_hatch"},     # 1-5 여의도 지하 벙커
         {"lid": "L-R02-10", "near": (826, 1134), "to": "Y-05", "mark": "from_W", "name": "윤중제 배수구", "prop": "drain_outlet", "hint": "쇠창살이 뜯긴 틈으로 기어 들어가면 배수로다."},
         # 1-5e 손 장소: 건물 1층 문(kind facade — gen_interiors가 가장 가까운 1층 문에 붙인다) · 계곡 배수구
         {"lid": "L-R01-06", "near": (938, 1488), "to": "K-01", "mark": "from_W", "name": "관악 행정 연수원 본관", "kind": "facade"},
         {"lid": "L-R02-29", "near": (700, 1105), "to": "K-29", "mark": "from_W", "name": "영등포 경찰서", "kind": "facade"},
         {"lid": "L-R02-06", "near": (777, 1101), "to": "K-06", "mark": "from_W", "name": "여의도 공영방송", "kind": "facade"},
         {"lid": "L-R01-08", "near": (887, 1494), "to": "K-08", "mark": "from_W", "name": "관악 계곡 배수 암거", "prop": "drain_outlet",
          "hint": "콘크리트 암거 입구. 물비린내와 곰팡이 냄새가 흘러나온다."}]
INSETS = [{"id": "X-S07", "mark": "from_vault", "at": (959, 1503)},          # 볼트 S-07 정문(L-R01-01)
          {"id": "X-BC", "center": (892, 1362)},                             # 봉천 계단마을(L-R01-09)
          {"id": "X-SB", "center": (632, 1329), "lid": "L-R02-19", "arrive": "arrive"}]   # 새벽인력 본소(1-6): 도착 칸 = 정문 앞 길
START = (959, 1503)                                                          # 도달성 검사 출발점 = 볼트 정문
WALKK = (1, 5, 6, 7, 8, 9, 10, 12, 13)                                       # 걷는 땅 종류(13 = 다리 상판)
STAIR_GAP = 28


def log(*a):
    print(*a, flush=True)


def load_inset(spec):
    d = json.load(open(os.path.join(ROOT, "game", "data", "maps", spec["id"] + ".json"), encoding="utf-8"))
    w, h = d["size"]
    if "mark" in spec:
        m = d["marks"][spec["mark"]]
        ox, oy = spec["at"][0] - int(m[0]), spec["at"][1] - int(m[1])
    else:
        ox, oy = spec["center"][0] - w // 2, spec["center"][1] - h // 2
    return d, (ox, oy, w, h)


def inset_openings(d, rect):
    """테두리의 걷는 칸과 그 바깥 칸(월드 좌표)"""
    ox, oy, w, h = rect
    out = []
    for y in range(h):
        for x in range(w):
            if d["solid"][y][x] == "1" or not (x in (0, w - 1) or y in (0, h - 1)):
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                if not (0 <= x + dx < w and 0 <= y + dy < h):
                    out.append(((ox + x, oy + y), (ox + x + dx, oy + y + dy)))
    return out


def carve_to_road(kind, start_cells, block):
    """바깥 칸들에서 가장 가까운 도로(차도·보도)까지 4방향 너비 우선 탐색 → 경로 칸 목록"""
    prev = {}
    q = deque()
    for c in start_cells:
        prev[c] = None
        q.append(c)
    goal = None
    while q:
        c = q.popleft()
        x, y = c
        if kind[y, x] in (7, 8) and not block[y, x]:
            goal = c
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in prev or not (0 <= n[0] < W and 0 <= n[1] < H) or block[n[1], n[0]]:
                continue
            if kind[n[1], n[0]] not in WALKK:
                continue
            prev[n] = c
            q.append(n)
    path = []
    while goal is not None:
        path.append(goal)
        goal = prev[goal]
    return path[::-1]


# ---------------------------------------------------------------- 덩어리 묶기(행 구간 union-find)
class DSU:
    def __init__(self, n):
        self.p = np.arange(n, dtype=np.int64)

    def find(self, a):
        p = self.p
        r = a
        while p[r] != r:
            r = p[r]
        while p[a] != r:
            p[a], a = r, p[a]
        return r

    def union(self, a, b):
        a, b = self.find(a), self.find(b)
        if a != b:
            if a < b:
                a, b = b, a
            self.p[a] = b


def label(walk, key):
    """walk 칸을 4방향으로 묶는다. key가 같은 이웃끼리 묶이고, key -1(계단)은 어느 이웃과도 묶인다. → 칸마다 덩어리 번호(-1 = 못 걷는 칸)"""
    k = np.where(walk, key.astype(np.int32), -999)
    runs = []                                                                # 행마다 (시작, 끝, key, 번호)
    rid = 0
    for y in range(H):
        row = k[y]
        ch = np.nonzero(np.diff(row))[0] + 1
        starts = np.concatenate([[0], ch])
        ends = np.concatenate([ch - 1, [W - 1]])
        rr = []
        for s, e in zip(starts, ends):
            v = int(row[s])
            if v != -999:
                rr.append((int(s), int(e), v, rid))
                rid += 1
        runs.append(rr)
    dsu = DSU(rid)
    for y in range(H):
        rr = runs[y]
        for i in range(len(rr) - 1):                                         # 가로: 맞닿은 다른 key 구간(한쪽이 계단)
            a, b = rr[i], rr[i + 1]
            if a[1] + 1 == b[0] and (a[2] == -1 or b[2] == -1):
                dsu.union(a[3], b[3])
        if y + 1 < H:                                                        # 세로: 겹치는 구간
            nr = runs[y + 1]
            i = j = 0
            while i < len(rr) and j < len(nr):
                a, b = rr[i], nr[j]
                if a[0] <= b[1] and b[0] <= a[1] and (a[2] == b[2] or a[2] == -1 or b[2] == -1):
                    dsu.union(a[3], b[3])
                if a[1] < b[1]:
                    i += 1
                else:
                    j += 1
    lab = np.full((H, W), -1, np.int64)
    for y in range(H):
        for (s, e, v, i) in runs[y]:
            lab[y, s:e + 1] = dsu.find(i)
    return lab


def walk_route(solid, level, stair, a, b, margin=80):
    """a → b 걷는 길(4방향, 높이가 같거나 계단 칸으로만). 봇·자동 시험의 경유점(12칸마다)."""
    x0, x1 = max(0, min(a[0], b[0]) - margin), min(W - 1, max(a[0], b[0]) + margin)
    y0, y1 = max(0, min(a[1], b[1]) - margin), min(H - 1, max(a[1], b[1]) + margin)
    prev = {a: None}
    q = deque([a])
    while q:
        c = q.popleft()
        if c == b:
            break
        x, y = c
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in prev or not (x0 <= n[0] <= x1 and y0 <= n[1] <= y1) or solid[n[1], n[0]]:
                continue
            if level[n[1], n[0]] != level[y, x] and not stair[n[1], n[0]] and not stair[y, x]:
                continue
            prev[n] = c
            q.append(n)
    if b not in prev:
        return []
    path = []
    c = b
    while c is not None:
        path.append(c)
        c = prev[c]
    path.reverse()
    pts = path[::12]
    if pts[-1] != path[-1]:
        pts.append(path[-1])
    return [list(map(int, p)) for p in pts]


def build():
    t0 = time.time()
    src = json.load(open(WB.SRC, encoding="utf-8"))
    r = WB.bake(src)
    WB.city(r, src)
    kind = r["kind"]
    lvl = r["level"].astype(np.int16)
    play = r["play"]
    log("굽기 %.1fs · 건물 %d" % (time.time() - t0, len(r["buildings"])))
    tw = json.load(open(os.path.join(TIL, "ts_world.json"), encoding="utf-8"))
    pos, cols, skins = tw["tiles"], tw["cols"], tw["skins"]

    def tid(n):
        return pos[n][1] * cols + pos[n][0] + 1
    r01 = json.load(open(os.path.join(TIL, "ts_r01_ext.json"), encoding="utf-8"))
    rid = {k: v["atlas"][0] for k, v in r01.items()}
    fl, names = WB.floor_names(r)
    floor = np.array([rid[n] for n in names], np.uint8)[fl]
    solid = np.zeros((H, W), np.uint8)
    cover = np.zeros((H, W), np.uint8)
    stair = np.zeros((H, W), np.uint8)
    gflag = np.zeros((H, W), np.uint8)
    body = np.zeros((H, W), np.uint16)
    deco = np.zeros((H, W), np.uint16)
    tree = r["tree"].copy()

    # ① 손 맵 자리 · 길목 연결로
    insets = []
    inmask = np.zeros((H, W), bool)
    keep_out = np.zeros((H, W), bool)                                        # 건물·나무를 비울 곳
    carve = np.zeros((H, W), bool)
    for spec in INSETS:
        d, rect = load_inset(spec)
        ox, oy, w, h = rect
        inmask[oy:oy + h, ox:ox + w] = True
        keep_out[oy - 2:oy + h + 2, ox - 2:ox + w + 2] = True
        ops = inset_openings(d, rect)
        outs = [o for (_, o) in ops if not inmask[o[1], o[0]]]
        base = int(lvl[outs[0][1], outs[0][0]]) if outs else 0
        lo = min(int(c) for row in d["level"] for c in row if c != ".")
        insets.append({"id": spec["id"], "data": d, "rect": rect, "base": base - lo, "outs": outs, "spec": spec})
    for ins in insets:                                                       # 길목 무리(맞닿은 바깥 칸)마다 길 하나
        groups = []
        for o in ins["outs"]:
            for g in groups:
                if any(abs(o[0] - p[0]) + abs(o[1] - p[1]) <= 1 for p in g):
                    g.append(o)
                    break
            else:
                groups.append([o])
        ins["paths"] = 0
        for g in groups:
            path = carve_to_road(kind, g, inmask)
            for (x, y) in path:
                for dx in (0, 1):
                    carve[y, x + dx] = True
                    keep_out[y - 1:y + 2, x - 1 + dx:x + 2 + dx] = True
            for (x, y) in g:
                carve[y, x] = True
            ins["paths"] += 1
            ins.setdefault("len", []).append(len(path))
    carve &= ~inmask
    blds = []
    for b in r["buildings"]:
        if keep_out[b["y"]:b["y"] + b["h"], b["x"]:b["x"] + b["w"]].any():
            continue
        blds.append(b)
    tree &= ~keep_out
    log("손 맵: " + ", ".join("%s 자리 %s 기준 높이 %+d 길 %d개 %s칸" % (i["id"], i["rect"][:2], i["base"], i["paths"], i.get("len")) for i in insets))

    # ② 물 · 성곽 · 건물 · 나무 · 다리
    water = (kind == 2) | (kind == 3)
    solid[water] = 1
    solid[~play] = 1                                                         # 놀이 구역 밖(경계 띠): 막힘(H-13 경계 처리 시안 전까지)
    fort = kind == 11
    solid[fort] = 1
    cover[fort] = 2
    gflag[fort] = 1
    fy, fx = np.nonzero(fort)
    fort_ext = np.zeros((H, W), bool)                                        # 성곽 정면 3타일(SD-08 §9.1): 여장 + 남쪽 두 칸 돌 쌓기
    for y, x in zip(fy, fx):
        if y + 1 < H and fort[y + 1, x]:
            body[y, x] = tid("tr:fort_top")
            continue
        body[y, x] = tid("tr:fort_face%d" % ((x * 7 + y) % 2))
        for k, part in ((1, "mid"), (2, "bot")):
            yy = y + k
            if yy < H and not fort[yy, x] and kind[yy, x] in WALKK and not inmask[yy, x]:
                body[yy, x] = tid("tr:fort_%s%d" % (part, (x + k) % 2))
                fort_ext[yy, x] = True
            else:
                break
    solid[fort_ext] = 1
    cover[fort_ext] = 2
    gflag[fort_ext] = 1
    tree &= ~fort_ext
    # 다리 상판(SD-08 §5.4): 표시 안 함(성수·청담) 제외, 붕괴는 가운데가 끊긴다
    deck = np.zeros((H, W), bool)
    brk = np.zeros((H, W), bool)
    nb = 0
    for br in src["bridges"]:
        if "표시 안 함" in br["state"]:
            continue
        nb += 1
        a, b = np.array(br["n"], float), np.array(br["s"], float)
        v = b - a
        u = v / np.hypot(*v)
        M = (a + b) / 2                                                      # 가운데에서 양쪽으로: 물(섬 포함)이 끝나는 땅까지 늘린다
        reach_ = []                                                          # (수면을 다리 중점 쪽으로 당겨 다듬어 강폭이 원문 다리보다 넓은 곳이 있다)
        for sgn in (-1, 1):
            k_, dry = 0, 0
            while k_ < 120 and dry < 3:
                k_ += 1
                q = M + u * sgn * k_
                kk = kind[int(round(q[1])), int(round(q[0]))]
                dry = dry + 1 if not (2 <= kk <= 4 or kk == 12) else 0
            reach_.append(k_)
        a2, b2 = M - u * (reach_[0] + 1), M + u * (reach_[1] + 1)
        L = np.hypot(*(b2 - a2)) - 16
        br["_ends"] = [(int(round(c[0])), int(round(c[1]))) for c in (a2 - u * 2, b2 + u * 2)]
        x0, x1 = int(min(a2[0], b2[0])) - 4, int(max(a2[0], b2[0])) + 5
        y0, y1 = int(min(a2[1], b2[1])) - 4, int(max(a2[1], b2[1])) + 5
        ys_, xs_ = np.mgrid[y0:y1, x0:x1]
        px, py = xs_ - a2[0], ys_ - a2[1]
        t = (px * u[0] + py * u[1]) / (L + 16)
        dperp = np.abs(px * u[1] - py * u[0])
        on = (dperp <= 2.6) & (t >= 0) & (t <= 1)
        wsub = (kind[y0:y1, x0:x1] >= 2) & (kind[y0:y1, x0:x1] <= 4)
        if "붕괴" in br["state"]:
            gap = (t > 0.44) & (t < 0.56)
            near = (t > 0.41) & (t < 0.59) & ~gap
            brk[y0:y1, x0:x1] |= on & near & wsub
            on &= ~gap
        deck[y0:y1, x0:x1] |= on & wsub
    kind[deck] = 13
    solid[deck] = 0
    dy_, dx_ = np.nonzero(deck)
    for y, x in zip(dy_, dx_):
        m = 0
        for bit, (ddx, ddy) in ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0))):
            k2 = kind[y + ddy, x + ddx]
            if 2 <= k2 <= 4:
                m |= bit
        body[y, x] = tid(("tr:deckb%d" if brk[y, x] else "tr:deck%d") % m)
    # 건물
    shadows = []
    entries = []                                                             # 1층 문 후보(1-5e 들어가 보는 건물): 문·셔터 타일, 가게·사무동은 정면 가운데
    blds = [b for b in blds if not fort_ext[b["y"]:b["y"] + b["h"], b["x"]:b["x"] + b["w"]].any()]
    for b in blds:
        cells, dcells, skin = WB.bld_cells(b, skins)
        for (dx, dy, nm) in cells:
            body[b["y"] + dy, b["x"] + dx] = tid(nm)
        doors_b = sorted((b["x"] + dx, b["y"] + dy) for (dx, dy, nm) in cells
                         if dy == b["h"] - 1 and ("_door" in nm or "_shutter_l" in nm or nm.endswith("_steel")))
        if not doors_b and b["style"] in ("shop", "office") and b["w"] >= 3:
            doors_b = [(b["x"] + b["w"] // 2, b["y"] + b["h"] - 1)]
        if doors_b:
            dx_, dy_ = doors_b[WB._h(b["seed"], 31) % len(doors_b)]
            entries.append({"x": int(dx_), "y": int(dy_), "style": b["style"], "seed": int(b["seed"])})
        for (dx, dy, nm) in dcells:
            deco[b["y"] + dy, b["x"] + dx] = tid(nm)
        sl = (slice(b["y"], b["y"] + b["h"]), slice(b["x"], b["x"] + b["w"]))
        solid[sl] = 1
        cover[sl] = 2
        gflag[sl] = 1
        tree[sl] = False
        shadows.append((b["x"], b["y"], b["w"], b["h"], max(1, min(b["floors"], b["h"] - 1, 6))))
    # 나무(R01 소품): 산지 = 소나무, 시가지 = 은행·단풍·고목, 둔치 = 작은 나무·고목
    tree &= (solid == 0) & np.isin(kind, (1, 5, 12)) & ~carve & ~inmask
    props = ["tree_pine", "tree_pine2", "tree_oak", "tree_oak2", "tree_ginkgo", "tree_maple", "tree_dead", "tree_small"]
    ty_, tx_ = np.nonzero(tree)
    use = r["use"]
    hh = (tx_ * 73856093 ^ ty_ * 19349663) & 0xFFFF
    pid = np.where(use[ty_, tx_] == 2, np.where(hh % 5 == 0, 1, np.where(hh % 11 == 0, 6, 0)),
                   np.where(kind[ty_, tx_] == 5, np.where(hh % 2 == 0, 7, 6),
                            np.choose(hh % 6, [4, 5, 2, 3, 6, 7])))
    tree_list = np.stack([tx_, ty_, pid], 1)
    solid[ty_, tx_] = 1
    cover[ty_, tx_] = 1
    gflag[ty_, tx_] = 2

    # 길목 연결로: 흙길(바닥만), 높이가 바뀌는 칸은 계단 칸
    floor[carve & ((kind == 1) | (kind == 12))] = rid["dirt_a"]
    solid[carve] = 0
    cy_, cx_ = np.nonzero(carve)
    for y, x in zip(cy_, cx_):
        for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if carve[y + ddy, x + ddx] and lvl[y + ddy, x + ddx] != lvl[y, x]:
                stair[y, x] = 1

    # ③ 높이 단: 정면 암벽 · 비탈 · 벼랑 끝
    up = np.zeros((H, W), bool)
    up[1:] = lvl[:-1] > lvl[1:]
    face = up & play & ~inmask & ~carve & (body == 0) & ~water & ~deck
    ramp = face & np.isin(kind, (7, 8, 9, 10))
    stair[ramp] = 1
    face &= ~ramp
    solid[face] = 1
    cover[face] = 2
    gflag[face] = 1
    fy, fx = np.nonzero(face)
    for y, x in zip(fy, fx):
        l = face[y, x - 1]
        rr = face[y, x + 1]
        col = "m" if (l and rr) or (not l and not rr) else ("l" if not l else "r")
        body[y, x] = tid("tr:cliff_%s%d" % (col, ((x * 31 + y * 17) % 3) if col == "m" else 0))
    walk = (solid == 0)
    bm = np.zeros((H, W), np.uint8)
    bm[1:] |= np.where((lvl[1:] > lvl[:-1]), 1, 0).astype(np.uint8)          # 북쪽이 낮다
    bm[:, :-1] |= np.where((lvl[:, :-1] > lvl[:, 1:]), 2, 0).astype(np.uint8)  # 동쪽이 낮다
    bm[:, 1:] |= np.where((lvl[:, 1:] > lvl[:, :-1]), 4, 0).astype(np.uint8)   # 서쪽이 낮다
    bm[~walk | inmask | (body > 0) | (stair == 1)] = 0
    by_, bx_ = np.nonzero(bm)
    for y, x in zip(by_, bx_):
        deco[y, x] = tid("tr:brink%d" % bm[y, x])
    log("다리 %d곳(상판 %d칸) · 암벽 %d칸 · 비탈 %d칸 · 벼랑 끝 %d칸 · 나무 %d" % (nb, deck.sum(), face.sum(), ramp.sum(), len(by_), len(tree_list)))

    # 손 맵 찍기. 손 맵 테두리의 막힘 띠(가장자리 4칸 안, 바깥과 이어진 막힘 칸 — 예전엔 카메라 한계로 가려졌다)는 월드 지형으로 두고,
    # 그 안쪽 경계에 봉천은 고철 장벽(정착지 담), 볼트 비탈은 숲을 둘러 잇는다.
    level = lvl.copy()
    tree_list = tree_list[~inmask[tree_list[:, 1], tree_list[:, 0]]]
    extra_trees = []
    for ins in insets:
        d = ins["data"]
        ox, oy, w, h = ins["rect"]
        sol = np.array([[c == "1" for c in row] for row in d["solid"]])
        band = np.zeros((h, w), bool)
        q = deque()
        for y in range(h):
            for x in range(w):
                if sol[y, x] and (x in (0, w - 1) or y in (0, h - 1)):
                    band[y, x] = True
                    q.append((x, y))
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and sol[ny, nx] and not band[ny, nx] and min(nx, ny, w - 1 - nx, h - 1 - ny) <= 3:
                    band[ny, nx] = True
                    q.append((nx, ny))
        line = np.zeros((h, w), bool)
        for y in range(h):
            for x in range(w):
                if band[y, x] and any(0 <= x + dx < w and 0 <= y + dy < h and not band[y + dy, x + dx]
                                      for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    line[y, x] = True
        ins["band"] = band
        for y in range(h):
            frow, grow, srow, crow, lrow, trow = d["floor"][y], d["gflag"][y], d["solid"][y], d["cover"][y], d["level"][y], d["stair"][y]
            for x in range(w):
                X, Y = ox + x, oy + y
                if band[y, x]:
                    body[Y, X] = deco[Y, X] = 0
                    solid[Y, X] = 0 if play[Y, X] and kind[Y, X] in WALKK else 1
                    cover[Y, X] = stair[Y, X] = gflag[Y, X] = 0
                    if line[y, x]:
                        solid[Y, X] = 1
                        cover[Y, X] = 2
                        if ins["id"] == "X-BC":                              # 고철 장벽: 남북 구간은 윗면, 나머지는 정면
                            vert = y + 1 < h and line[y + 1, x]
                            body[Y, X] = tid("tr:scrap_top%d" % (y % 2)) if vert else tid("tr:scrap_face%d" % (x % 6))
                            gflag[Y, X] = 1
                        else:
                            extra_trees.append((X, Y, (X * 7 + Y * 3) % 3 and 0 or 1))
                            cover[Y, X] = 1
                            gflag[Y, X] = 2
                    elif ins["id"] != "X-BC" and solid[Y, X] == 0 and (X * 31 + Y * 17) % 5 < 2:
                        extra_trees.append((X, Y, 0 if (X + Y) % 3 else 1))  # 비탈 숲
                        solid[Y, X] = 1
                        cover[Y, X] = 1
                        gflag[Y, X] = 2
                    continue
                floor[Y, X] = int(frow[x])
                gflag[Y, X] = int(grow[x])
                solid[Y, X] = 1 if srow[x] == "1" else 0
                cover[Y, X] = int(crow[x])
                level[Y, X] = (int(lrow[x]) + ins["base"]) if lrow[x] != "." else ins["base"]
                stair[Y, X] = 1 if trow[x] == "1" else 0
                body[Y, X] = 0
                deco[Y, X] = 0
        for (o_in, o_out) in inset_openings(d, ins["rect"]):                 # 길목 바깥 칸 = 계단 칸(높이를 맞춘다)
            stair[o_out[1], o_out[0]] = 1
    if extra_trees:
        tree_list = np.concatenate([tree_list, np.array(extra_trees, tree_list.dtype)])

    # 거리 소품(R01 소품, SD-16 §6.6 '소품' 층): 막는 소품은 발 칸 + 둘레 1칸이 모두 같은 높이의 걷는 칸일 때만(좁은 길을 막지 않는다)
    pm = json.load(open(os.path.join(ROOT, "game", "assets", "props", "r01_props.json"), encoding="utf-8"))["props"]
    free = (solid == 0) & (stair == 0) & ~inmask & ~carve & play & (body == 0)
    near_in = np.zeros((H, W), bool)
    for ins in insets:
        ox, oy, iw, ih = ins["rect"]
        near_in[max(0, oy - 8):oy + ih + 8, max(0, ox - 8):ox + iw + 8] = True
    free &= ~near_in
    hsh = lambda x, y, k: ((x * 73856093) ^ (y * 19349663) ^ (k * 83492791)) & 0xFFFFFF
    placed = []

    def try_put(name, x, y):
        fw, fh = pm[name]["foot"]
        if fw == 0:                                                          # 바닥 덧그림(풀포기·맨홀): 막지 않는다
            if free[y, x]:
                placed.append((x, y, name))
            return
        x0_, y0_, x1_, y1_ = x - 1, y - 1, x + fw + 1, y + fh + 1
        if x0_ < 0 or y0_ < 0 or x1_ > W or y1_ > H:
            return
        win = free[y0_:y1_, x0_:x1_]
        if not win.all() or (level[y0_:y1_, x0_:x1_] != level[y, x]).any():
            return
        free[y:y + fh, x:x + fw] = False
        solid[y:y + fh, x:x + fw] = 1
        cover[y:y + fh, x:x + fw] = 2 if pm[name]["rect"][3] - fh * 32 > 24 else 1
        gflag[y:y + fh, x:x + fw] = 2
        placed.append((x, y, name))

    road = kind == 7
    side = kind == 8
    yy, xx = np.nonzero(free & road & ~r["street"])                         # 간선도로: 차량 잔해 · 방호벽 · 맨홀
    for y, x in zip(yy, xx):
        h_ = hsh(x, y, 1)
        if h_ % 380 == 0:
            try_put("car_wreck" if h_ & 1024 else "car_wreck2", x, y)
        elif h_ % 900 == 7:
            try_put("jersey", x, y)
        elif h_ % 700 == 11:
            try_put("manhole", x, y)
    yy, xx = np.nonzero(free & side)                                         # 보도: 가로등(14칸 격자) · 버스 정류장
    for y, x in zip(yy, xx):
        if (x % 14 == 0 and y % 14 == 0) or (x % 14 == 7 and y % 14 == 7):
            try_put("streetlamp", x, y)
        elif hsh(x, y, 2) % 2600 == 0:
            try_put("bus_stop", x, y)
    st_ = r["street"]
    edge = (kind == 1) & (np.roll(st_, 1, 1) | np.roll(st_, -1, 1) | np.roll(st_, 1, 0) | np.roll(st_, -1, 0))
    yy, xx = np.nonzero(free & edge)                                         # 동네 길 가: 전신주
    for y, x in zip(yy, xx):
        if hsh(x, y, 3) % 23 == 0:
            try_put("utility_pole", x, y)
        elif hsh(x, y, 3) % 61 == 5:
            try_put("drum", x, y)
    use = r["use"]
    land = free & (kind == 1)
    yy, xx = np.nonzero(land)
    junk = ["rubble", "rubble2", "scrap_pile", "scrap_pile2", "tarp_pile", "drum"]
    green = ["bush_a", "bush_g", "bush_y"]
    for y, x in zip(yy, xx):
        h_ = hsh(x, y, 4)
        u_ = use[y, x]
        if u_ == 2:                                                          # 산: 바위·그루터기·덤불
            if h_ % 70 == 0:
                try_put(["boulder_s", "boulder_m", "boulder_l", "stump"][h_ >> 12 & 3], x, y)
            elif h_ % 45 == 3:
                try_put(green[h_ >> 10 & 1], x, y)
            elif h_ % 13 == 5:
                try_put("tuft" if h_ & 256 else "tuft2", x, y)
        else:                                                                # 시가지·구릉 빈 땅: 잔해 · 덤불 · 풀포기
            if h_ % 150 == 0:
                try_put(junk[(h_ >> 10) % len(junk)], x, y)
            elif h_ % 110 == 9:
                try_put(green[(h_ >> 10) % 3], x, y)
            elif h_ % 19 == 4:
                try_put("tuft" if h_ & 256 else "tuft2", x, y)
    yy, xx = np.nonzero(free & (kind == 5))                                  # 둔치: 갈대 덤불·풀포기·고철
    for y, x in zip(yy, xx):
        h_ = hsh(x, y, 5)
        if h_ % 60 == 0:
            try_put(green[(h_ >> 10) % 3], x, y)
        elif h_ % 15 == 2:
            try_put("tuft2", x, y)
        elif h_ % 400 == 7:
            try_put("scrap_pile", x, y)
    cnt = {}
    for (_, _, n) in placed:
        cnt[n] = cnt.get(n, 0) + 1
    log("거리 소품 %d: %s" % (len(placed), cnt))

    # ④ 이어 주기
    t1 = time.time()
    walk = solid == 0
    key = np.where(stair == 1, -1, level)
    lab = label(walk, key)
    sx, sy = START
    main = lab[sy, sx]
    up_l = np.zeros((H, W), np.int64)
    dn_l = np.zeros((H, W), np.int64)
    cand = face & (solid == 1)
    cand[0] = cand[-1] = False
    up_l[1:-1] = lab[:-2]
    dn_l[1:-1] = lab[2:]
    cand &= (up_l >= 0) & (dn_l >= 0) & (up_l != dn_l)
    cy_, cx_ = np.nonzero(cand)
    pairs = {}
    for y, x in zip(cy_, cx_):
        a, b = int(up_l[y, x]), int(dn_l[y, x])
        pairs.setdefault((min(a, b), max(a, b)), []).append((x, y))
    nst = 0
    for k, cells in pairs.items():
        cells.sort()
        chosen = []
        mid = cells[len(cells) // 2]
        order = [mid] + cells
        for c in order:
            if all(abs(c[0] - q[0]) + abs(c[1] - q[1]) >= STAIR_GAP for q in chosen):
                chosen.append(c)
        for (x, y) in chosen:
            solid[y, x] = 0
            cover[y, x] = 0
            stair[y, x] = 1
            body[y, x] = tid("tr:cstair")
            nst += 1
    side = 0
    for it in range(6):                                                      # 남북으로 안 맞닿은 덩어리: 옆 비탈
        walk = solid == 0
        key = np.where(stair == 1, -1, level)
        lab = label(walk, key)
        main = lab[sy, sx]
        reach = lab == main
        # 닿은 칸과 가로로 맞닿은, 높이가 다른 못 닿은 걷는 칸
        e = np.zeros((H, W), bool)
        e[:, 1:] |= reach[:, :-1] & walk[:, 1:] & ~reach[:, 1:]
        e[:, :-1] |= reach[:, 1:] & walk[:, :-1] & ~reach[:, :-1]
        e[1:] |= reach[:-1] & walk[1:] & ~reach[1:]
        e[:-1] |= reach[1:] & walk[:-1] & ~reach[:-1]
        if not e.any():
            break
        ey, ex = np.nonzero(e)
        seen = set()
        for y, x in zip(ey, ex):
            c = int(lab[y, x])
            if c in seen:
                continue
            seen.add(c)
            stair[y, x] = 1
            deco[y, x] = 0
            side += 1
    walk = solid == 0
    key = np.where(stair == 1, -1, level)
    lab = label(walk, key)
    main = lab[sy, sx]
    reach = (lab == main)
    log("이어 주기 %.1fs: 돌계단 %d · 옆 비탈 %d · 걷는 칸 %d 중 닿는 칸 %d (%.2f%%)" % (
        time.time() - t1, nst, side, walk.sum(), reach.sum(), 100.0 * reach.sum() / max(1, walk.sum())))

    # 어디서도 닿지 않는 걷는 칸(건물 사이 갇힌 틈, 놀이 구역 경계에 잘린 둔치 조각)은 막는다 — 스폰·길찾기가 고르지 않게.
    # 도심 밀폐 구역(R05 성곽 안)은 별도 구획 맵(D1~D9)이 쓸 땅이라 그대로 둔다(SD-08 §9.2)
    r05 = r["region"] == WB.REG_CODES.index("R05")
    sealed = walk & ~reach & ~r05
    solid[sealed] = 1
    walk = solid == 0
    # 도달성: 놀이 청크마다 닿는 칸이 있나(SD-19 §10 '1,230청크 도달성'). 걷는 칸이 하나도 없는 청크는 물 청크(한강만 허용)
    region = json.load(open(WB.SRC, encoding="utf-8"))["region"]
    miss, wet, core = [], [], []
    for k in region:
        cx, cy = map(int, k.split(","))
        sl = (slice(cy * CS, cy * CS + CS), slice(cx * CS, cx * CS + CS))
        if not reach[sl].any():
            (wet if region[k] == "HR" else (core if region[k] == "R05" else miss)).append((k, region[k]))
    log("도달성: 놀이 청크 %d 중 걸어서 닿는 청크 %d · 도심 밀폐(별도 구획 맵 D1~D9, 진입 G1~G10) %d · 물 청크(한강) %d %s · 못 닿는 %d %s · 봉합한 칸 %d" % (
        len(region), len(region) - len(miss) - len(wet) - len(core), len(core), len(wet), [w[0] for w in wet], len(miss), miss[:12], sealed.sum()))
    # 횡단로 검사(SD-08 §5.4·§8.2): 통행 다리는 양 끝(제방 밖 땅)이 다리 상판으로 이어지고, 붕괴 다리는 끊겨 있어야 한다
    cross = []
    for br in src["bridges"]:
        if "표시 안 함" in br["state"]:
            continue
        a_, b_ = np.array(br["n"], float), np.array(br["s"], float)
        ends = br["_ends"]
        ok_ = all(0 <= e[0] < W and 0 <= e[1] < H and solid[e[1], e[0]] == 0 for e in ends)
        if ok_:
            sub = walk_route(solid, level, stair, ends[0], ends[1], margin=12)
            linked = bool(sub) and len(sub) * 12 < np.hypot(ends[1][0] - ends[0][0], ends[1][1] - ends[0][1]) * 2.2 + 40
        else:
            linked = False
        want = "붕괴" not in br["state"]
        cross.append((br["name"], br["state"], linked, linked == want))
    bad = [c for c in cross if not c[3]]
    log("다리 검사: %d곳 중 기대대로 %d (통행 %d · 끊김 %d)%s" % (len(cross), len(cross) - len(bad), sum(1 for c in cross if c[2]),
        sum(1 for c in cross if not c[2]), " · 어긋남 " + str([(c[0], c[1], "이어짐" if c[2] else "끊김") for c in bad]) if bad else ""))

    # 길 위 발견물(1-4f, SD-08 §13.2 '소형 관심 지점' · §14.1 경고 장치): 굽기 때 규칙으로 흩고, 용기·조사 글은 pois.json으로 낸다
    pois = place_pois(src, solid, cover, gflag, stair, level, kind, r["use"], reach, inmask, carve, play, body, insets, placed, pm)
    reach &= solid == 0

    # 손 맵 사이 걷는 길(봇 경유점): 비탈 첫 칸 → 봉천 동쪽 골목 끝
    routes = {}
    ins_of = {i["id"]: i for i in insets}
    def mk(iid, name):
        i = ins_of[iid]
        m = i["data"]["marks"][name]
        return (i["rect"][0] + int(m[0]), i["rect"][1] + int(m[1]))
    a, b = mk("X-S07", "start"), mk("X-BC", "from_X-S07")
    rt = walk_route(solid, level, stair, a, b)
    routes["X-S07>X-BC"] = rt
    log("봇 길 X-S07 → X-BC: 경유점 %d (약 %d칸)" % (len(rt), len(rt) * 12))
    names = list(props)
    for (_, _, n) in placed:
        if n not in names:
            names.append(n)
    extra = np.array([(x, y, names.index(n)) for (x, y, n) in placed], tree_list.dtype).reshape(-1, 3)
    tree_list = np.concatenate([tree_list, extra])
    props = names
    reg_grid = [[0] * NCX for _ in range(NCY)]
    for k_, code in src["region"].items():
        cx_, cy_ = map(int, k_.split(","))
        reg_grid[cy_][cx_] = code
    return {"pois": pois, "r05": r05, "region_grid": reg_grid, "street": r["street"], "bridges": cross, "routes": routes, "floor": floor, "gflag": gflag, "solid": solid, "cover": cover, "level": level, "stair": stair, "body": body,
            "deco": deco, "trees": tree_list, "props": props, "shadows": shadows, "insets": insets, "play": play, "band": r["band"],
            "reach": reach, "miss": miss, "wet": wet, "core": core, "kind": kind, "entries": entries}

DIR8 = ["동", "남동", "남", "남서", "서", "북서", "북", "북동"]
NOTES_SRC = os.path.join(ROOT, "script", "world", "road_notes.txt")


def read_notes():
    """길 위 쪽지 원고(script/world/road_notes.txt): [(머리 — 장소 ID · 권역 · *, 본문)]"""
    out, head = [], None
    for ln in open(NOTES_SRC, encoding="utf-8").read().split("\n"):
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        if ln.startswith("@"):
            head = ln[1:].strip()
        elif head is not None:
            out.append((head, ln))
            head = None
    return out


def place_pois(src, solid, cover, gflag, stair, level, kind, use, reach, inmask, carve, play, body, insets, placed, pm):
    """청크마다 소형 관심 지점(SD-08 §13.2): 시가지 3~5 · 산지 1~2 · 도심 5~8.
    유해(떠돌이 소지품 corpse_scav, 쪽지가 붙기도 한다) · 버려진 배낭(bag) · 나무 상자(crate, 가끔 잠김) · 차 트렁크(이미 놓인 차량 잔해) ·
    고물 더미(이미 놓인 고철 더미) · 2077 민방위 대피소 표지(가장 가까운 장소 방면을 가리킨다).
    위협도가 2단 이상 오르는 경계(§14.1)에는 낮은 쪽 청크 가장자리에 손글씨 경고판 + 뼈 무더기.
    소품은 청크 소품 목록(placed)에 더하고 발 칸을 막는다(둘레 1칸이 모두 빈 같은 높이 땅일 때만 — 길을 끊지 않는다)."""
    import random as _rnd
    places = json.load(open(os.path.join(OUT, "places.json"), encoding="utf-8"))
    enc = json.load(open(os.path.join(OUT, "encounters.json"), encoding="utf-8"))
    threat = enc["threat"]
    near_in = np.zeros((H, W), bool)
    for ins in insets:
        ox, oy, iw, ih = ins["rect"]
        near_in[max(0, oy - 8):oy + ih + 8, max(0, ox - 8):ox + iw + 8] = True
    pfree = (solid == 0) & (stair == 0) & ~inmask & ~carve & play & (body == 0) & reach & ~near_in
    for d in DOORS:                                                          # 지하로 내려가는 문 자리 둘레는 비워 둔다
        nx, ny = d["near"]
        pfree[max(0, ny - 6):ny + 7, max(0, nx - 6):nx + 7] = False
    sp_path = os.path.join(OUT, "spots_src.json")                           # 손으로 둔 발견 자리(파수 등) 둘레는 비워 둔다
    for spec in (json.load(open(sp_path, encoding="utf-8"))["spots"] if os.path.exists(sp_path) else []):
        tx, ty = spec["tile"]
        pfree[max(0, ty - 10):ty + spec["h"] + 10, max(0, tx - 10):tx + spec["w"] + 10] = False
    boxes, texts = [], []
    cnt = {}

    def put(name, x, y):
        fw, fh = pm[name]["foot"]
        if fw == 0:
            if not pfree[y, x]:
                return False
            pfree[y, x] = False
            placed.append((x, y, name))
            return True
        x0_, y0_, x1_, y1_ = x - 1, y - 1, x + fw + 1, y + fh + 1
        if x0_ < 0 or y0_ < 0 or x1_ > W or y1_ > H:
            return False
        if not pfree[y0_:y1_, x0_:x1_].all() or (level[y0_:y1_, x0_:x1_] != level[y, x]).any():
            return False
        pfree[y:y + fh, x:x + fw] = False
        solid[y:y + fh, x:x + fw] = 1
        cover[y:y + fh, x:x + fw] = 2 if pm[name]["rect"][3] - fh * 32 > 24 else 1
        gflag[y:y + fh, x:x + fw] = 2
        placed.append((x, y, name))
        return True

    def cells_of(cx, cy, rng):
        sl = (slice(cy * CS, cy * CS + CS), slice(cx * CS, cx * CS + CS))
        yy, xx = np.nonzero(pfree[sl])
        order = list(range(len(yy)))
        rng.shuffle(order)
        return [(int(xx[i]) + cx * CS, int(yy[i]) + cy * CS) for i in order]

    def remains_at(x, y, rng, note=None):
        if not put("remains" if rng.random() < 0.5 else "remains2", x, y):
            return False
        boxes.append({"x": x, "y": y, "w": 1, "h": 1, "kind": "corpse_scav", "name": "떠돌이의 유해", "owner": "", "lock": 0})
        cnt["유해"] = cnt.get("유해", 0) + 1
        if note:
            for (dx, dy) in rng.sample([(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1)], 6):
                if 0 <= x + dx < W and 0 <= y + dy < H and put("note_ground", x + dx, y + dy):
                    texts.append({"x": x + dx, "y": y + dy, "text": "땅에 떨어진 쪽지 — " + note})
                    cnt["쪽지"] = cnt.get("쪽지", 0) + 1
                    break
        return True

    def nearest_place(x, y):
        best = None
        for lid, p in places.items():                                        # 2077 민방위 대피소 = 지하철역 · 주민센터 · 구청 · 학교 · 지하 시설
            nm = p["name"]
            station = nm.endswith("역") and not nm.endswith(("묘역", "구역", "방역", "지역", "영역"))
            if not (station or any(w in nm for w in ("주민센터", "구청", "학교", "지하상가", "대피소"))):
                continue
            d = (p["tx"] - x) ** 2 + (p["ty"] - y) ** 2
            if 64 < d < 120 ** 2 and (best is None or d < best[0]):
                best = (d, lid, p)
        return best

    # ① 쪽지(원고): 장소 머리면 그 장소에서 20~70칸 떨어진 길가, 권역 머리면 그 권역 아무 청크, *면 R01·R02
    region_chunks = {}
    for k_, code in src["region"].items():
        region_chunks.setdefault(code, []).append(tuple(map(int, k_.split(","))))
    used_chunks = {}
    for i, (head, body_t) in enumerate(read_notes()):
        rng = _rnd.Random(9000 + i)
        ok = False
        for attempt in range(60):
            if head.startswith("L-"):
                if head not in places:
                    raise SystemExit("길 위 쪽지 머리의 장소를 모른다: " + head)
                p = places[head]
                ang = rng.random() * 6.283
                rad = rng.randint(20, 70)
                x, y = int(p["tx"] + np.cos(ang) * rad), int(p["ty"] + np.sin(ang) * rad)
                if not (0 <= x < W and 0 <= y < H):
                    continue
                c = (x // CS, y // CS)
                cand = [q for q in cells_of(c[0], c[1], rng) if abs(q[0] - x) < 12 and abs(q[1] - y) < 12]
            else:
                pool = region_chunks.get(head, []) if head != "*" else region_chunks.get("R01", []) + region_chunks.get("R02", [])
                c = rng.choice(pool)
                cand = cells_of(c[0], c[1], rng)
            for (x, y) in cand[:20]:
                if remains_at(x, y, rng, body_t):
                    used_chunks[c] = used_chunks.get(c, 0) + 1
                    ok = True
                    break
            if ok:
                break
        if not ok:
            raise SystemExit("길 위 쪽지를 놓을 자리가 없다: %s %s" % (head, body_t[:20]))

    # ② 청크 밀도(§13.2)
    by_chunk = {}
    for (x, y, n) in placed:
        by_chunk.setdefault((x // CS, y // CS), []).append((x, y, n))
    for k_, code in sorted(src["region"].items()):
        cx, cy = map(int, k_.split(","))
        if code == "HR":
            continue
        rng = _rnd.Random(cx * 7919 + cy * 104729)
        sl = (slice(cy * CS, cy * CS + CS), slice(cx * CS, cx * CS + CS))
        if not pfree[sl].any():
            continue
        mount = (use[sl] == 2).mean() > 0.5
        want = rng.randint(5, 8) if code == "R05" else (rng.randint(1, 2) if mount else rng.randint(3, 5))
        have = used_chunks.get((cx, cy), 0)
        for (x, y, n) in by_chunk.get((cx, cy), []):                       # 이미 놓인 차량 잔해·고철 더미에 용기를 붙인다
            if have >= want:
                break
            if n in ("car_wreck", "car_wreck2") and rng.random() < 0.45:
                boxes.append({"x": x, "y": y, "w": 3, "h": 2, "kind": "car", "name": "차량 잔해 트렁크", "owner": "", "lock": 25 if rng.random() < 0.2 else 0})
                cnt["트렁크"] = cnt.get("트렁크", 0) + 1
                have += 1
            elif n in ("scrap_pile", "scrap_pile2") and rng.random() < 0.35:
                boxes.append({"x": x, "y": y, "w": 2, "h": 1, "kind": "trash", "name": "고물 더미", "owner": "", "lock": 0})
                cnt["고물"] = cnt.get("고물", 0) + 1
                have += 1
        weights = [("remains", 40), ("backpack", 35), ("crate", 25)] if mount else \
                  [("remains", 30), ("backpack", 18), ("crate", 24), ("evac", 10)]
        evac_done = False
        tries = 0
        cells = cells_of(cx, cy, rng)
        ci = 0
        while have < want and ci < len(cells) and tries < 40:
            tries += 1
            x, y = cells[ci]
            ci += 7
            r_ = rng.random() * sum(w for _, w in weights)
            pick = weights[0][0]
            for nm, w in weights:
                if r_ < w:
                    pick = nm
                    break
                r_ -= w
            if pick == "remains":
                okp = remains_at(x, y, rng)
            elif pick == "backpack":
                okp = put("backpack", x, y)
                if okp:
                    boxes.append({"x": x, "y": y, "w": 1, "h": 1, "kind": "bag", "name": "버려진 배낭", "owner": "", "lock": 0})
                    cnt["배낭"] = cnt.get("배낭", 0) + 1
            elif pick == "crate":
                okp = put("crate_o", x, y)
                if okp:
                    boxes.append({"x": x, "y": y, "w": 1, "h": 1, "kind": "crate", "name": "나무 상자", "owner": "", "lock": 25 if rng.random() < 0.15 else 0})
                    cnt["상자"] = cnt.get("상자", 0) + 1
            elif pick == "evac" and not evac_done:
                np_ = nearest_place(x, y)
                okp = np_ is not None and put("evac_sign", x, y)
                if okp:
                    _, lid, p = np_
                    ang = np.degrees(np.arctan2(p["ty"] - y, p["tx"] - x)) % 360
                    texts.append({"x": x, "y": y, "text": "2077년 민방위 대피소 표지. 화살표가 %s쪽 '%s' 방면을 가리킨다. 녹이 흘러 글씨가 반쯤 지워졌다." % (DIR8[int((ang + 22.5) // 45) % 8], p["name"])})
                    evac_done = True
                    cnt["대피소 표지"] = cnt.get("대피소 표지", 0) + 1
                    if rng.random() < 0.5:                                    # 표지 곁 민방위 비상함(구급·식수·신호탄 — SD-13 §9.4 civil)
                        for (ox, oy) in ((2, 0), (-2, 0), (0, 2), (2, 1)):
                            if put("civil_box", x + ox, y + oy):
                                boxes.append({"x": x + ox, "y": y + oy, "w": 1, "h": 1, "kind": "civil", "name": "민방위 비상함", "owner": "", "lock": 0})
                                cnt["비상함"] = cnt.get("비상함", 0) + 1
                                break
            else:
                okp = False
            if okp:
                have += 1

    # ③ 경고 장치(§14.1): 위협도가 2단 이상 오르는 이웃 청크 쪽 가장자리
    WARN = ["손글씨 경고판. '여기서부터 곰.'", "손글씨 경고판. '돌아가. 이 앞은 우리 땅이 아니다.'", "손글씨 경고판. '이 앞에서 세 명 죽음. — 감시조'",
            "손글씨 경고판. '물 마시지 마시오. 가이거가 운다.'", "손글씨 경고판. '밤에 지나가지 마라.'"]
    nwarn = 0
    for cy, row in enumerate(threat):
        for cx, ch in enumerate(row):
            if not ch.isdigit():
                continue
            t = int(ch)
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx_, ny_ = cx + dx, cy + dy
                if not (0 <= ny_ < len(threat) and 0 <= nx_ < len(threat[ny_])) or not threat[ny_][nx_].isdigit():
                    continue
                if int(threat[ny_][nx_]) - t < 2:
                    continue
                rng = _rnd.Random(cx * 31 + cy * 977 + dx * 7 + dy * 13)
                band = [q for q in cells_of(cx, cy, rng)
                        if (dx == 1 and q[0] % CS >= CS - 7) or (dx == -1 and q[0] % CS < 7) or (dy == 1 and q[1] % CS >= CS - 7) or (dy == -1 and q[1] % CS < 7)]
                for (x, y) in band[:30]:
                    if put("warn_board", x, y):
                        texts.append({"x": x, "y": y, "text": WARN[rng.randrange(len(WARN))]})
                        for (ox, oy) in ((2, 0), (-2, 0), (0, 2), (2, 1)):
                            if put("bone_pile", x + ox, y + oy):
                                texts.append({"x": x + ox, "y": y + oy, "text": "뼈 무더기. 이빨 자국이 남아 있다."})
                                break
                        nwarn += 1
                        break
    log("길 위 발견물: 용기 %d · 조사 글 %d · 경고 장치 %d · %s" % (len(boxes), len(texts), nwarn, cnt))
    return {"boxes": boxes, "texts": texts}



def export(R):
    os.makedirs(OUT, exist_ok=True)
    trees = R["trees"]
    tree_chunk = (trees[:, 1] // CS) * NCX + trees[:, 0] // CS
    shadows = {}
    for s in R["shadows"]:
        shadows.setdefault((s[1] // CS) * NCX + s[0] // CS, []).append(s)
    live = R["play"] | R["band"]
    offs = []
    blob = bytearray()
    raw_total = 0
    for cy in range(NCY):
        for cx in range(NCX):
            sl = (slice(cy * CS, cy * CS + CS), slice(cx * CS, cx * CS + CS))
            if not live[sl].any():
                offs.append([0, 0])
                continue
            fg = np.stack([R["floor"][sl].astype(np.uint8), R["gflag"][sl].astype(np.uint8)], -1)   # 바닥·덮개 교대(바닥 층 RG8 그대로 — 행 복사로 붙인다)
            parts = [fg.tobytes()] + [R[k][sl].astype(np.uint8).tobytes() for k in ("solid", "cover", "level", "stair")]
            parts += [R[k][sl].astype("<u2").tobytes() for k in ("body", "deco")]
            ci = cy * NCX + cx
            tl = trees[tree_chunk == ci]
            pb = struct.pack("<H", len(tl)) + b"".join(struct.pack("<BBH", int(t[0]) - cx * CS, int(t[1]) - cy * CS, int(t[2])) for t in tl)
            sh = shadows.get(ci, [])
            sb = struct.pack("<H", len(sh)) + b"".join(struct.pack("<hhBBBB", *s, 0) for s in sh)
            raw = b"".join(parts) + pb + sb
            raw_total += len(raw)
            z = zlib.compress(raw, 9)
            offs.append([len(blob), len(z), len(raw)])
            blob += z
    open(os.path.join(OUT, "world.bin"), "wb").write(bytes(blob))
    json.dump(R["pois"], open(os.path.join(OUT, "pois.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), default=int)
    meta = {"chunks": [NCX, NCY], "chunk_size": CS, "tile": 32, "size": [W, H], "layers": ["floor+gflag 교대", "solid", "cover", "level", "stair", "body16", "deco16", "trees", "shadows"],
            "offsets": offs, "props": R["props"], "start": list(START),
            "regions": json.load(open(WB.SRC, encoding="utf-8"))["region"],
            "region_names": {"R01": "관악", "R02": "여의도·영등포", "R03": "마포·상암", "R04": "서강·선유도", "R05": "도심",
                             "R06": "용산·남산", "R07": "강남", "R08": "동부", "R09": "북부 산악", "R10": "서부 평야", "R11": "청계산",
                             "HR": "한강"},                                   # SD-08 §7 권역 이름(배너·장소 표시)
            "insets": [{"id": i["id"], "origin": list(i["rect"][:2]), "size": list(i["rect"][2:]), "base": i["base"]} for i in R["insets"]],
            "unreached": [m[0] for m in R["miss"]], "routes": R["routes"], "bridges": [{"name": c[0], "state": c[1], "linked": bool(c[2])} for c in R["bridges"]], "water_chunks": [m[0] for m in R["wet"]], "sealed_core": [m[0] for m in R["core"]]}
    json.dump(meta, open(os.path.join(OUT, "world.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    log("내보내기: 청크 %d · 원자료 %.1fMB → 압축 %.2fMB" % (sum(1 for o in offs if o[1]), raw_total / 1e6, len(blob) / 1e6))


def map_art(R, r_kind, region_codes):
    """월드 지도 원화(SD-12 §5.1 '2077년 공무용 단색 선화에 한강만 짙게'): 1px = 1타일, 흰색 + 알파(세기). 게임이 CRT 색으로 칠한다.
    땅 옅게 · 산 점묘 · 등고선 · 간선도로 · 동네 길 · 철길 점선 · 지천 · 한강 짙게 · 다리 · 성곽 굵게 · 도심 밀폐 빗금 · 권역 경계 점선."""
    from PIL import Image
    kind, level = R["kind"], R["level"]
    a = np.zeros((H, W), np.uint8)
    play = R["play"]
    a[play] = 26
    ys, xs = np.mgrid[0:H, 0:W]
    mount = play & (level > 0)
    a[mount & ((xs + ys * 3) % 5 == 0)] = 70
    cont = np.zeros((H, W), bool)
    cont[:, 1:] |= level[:, 1:] != level[:, :-1]
    cont[1:] |= level[1:] != level[:-1]
    a[cont & play] = 95
    st_ = R["street"]
    a[st_ & play] = 62
    a[(kind == 7) & ~st_] = 150
    a[(kind == 8)] = 110
    a[(kind == 10) & ((xs + ys) % 4 < 2)] = 140
    trib = (kind == 4)
    a[trib] = 190
    a[(kind == 2) | (kind == 3)] = 235
    a[kind == 13] = 255
    core = R["r05"] & ~((kind >= 2) & (kind <= 4))
    a[core & ((xs - ys) % 6 == 0)] = np.maximum(a[core & ((xs - ys) % 6 == 0)], 85)
    fort = kind == 11
    thick = fort.copy()
    thick[1:] |= fort[:-1]
    thick[:, 1:] |= fort[:, :-1]
    a[thick] = 255
    reg = R["region_grid"]                                                   # 권역 경계 점선(청크 경계, 2타일 칠 · 2타일 비움)
    for cy in range(NCY):
        for cx in range(NCX):
            c = reg[cy][cx]
            if not c:
                continue
            if cx + 1 < NCX and reg[cy][cx + 1] and reg[cy][cx + 1] != c:
                x = (cx + 1) * CS
                for y in range(cy * CS, cy * CS + CS, 4):
                    a[y:y + 2, x - 1:x + 1] = np.maximum(a[y:y + 2, x - 1:x + 1], 170)
            if cy + 1 < NCY and reg[cy + 1][cx] and reg[cy + 1][cx] != c:
                y = (cy + 1) * CS
                for x in range(cx * CS, cx * CS + CS, 4):
                    a[y - 1:y + 1, x:x + 2] = np.maximum(a[y - 1:y + 1, x:x + 2], 170)
    img = np.zeros((H, W, 4), np.uint8)
    img[..., :3] = 255
    img[..., 3] = a
    out = os.path.join(ROOT, "game", "assets", "ui", "world_map.png")
    Image.fromarray(img, "RGBA").save(out, optimize=True)
    log("월드 지도 원화: %s (%d×%d)" % (out, W, H))


def place_geo(R):
    """장소마다 강변(SD-12 §5.6 '남안·북안 두 구역')과 도착 칸(빠른 이동, 장소 중심에서 가장 가까운 걸어서 닿는 칸).
    강변 = 한강 본류(깊은·중간 물) 세로 가운데보다 위면 북안. 섬 소속은 SD-08 §8.7(노들섬 북안 · 선유도·서래섬 남안 · 밤섬 없음)."""
    kind, reach = R["kind"], R["reach"]
    deep = (kind == 2) | (kind == 3)
    cols = np.arange(W)
    yc = np.full(W, np.nan)
    for x in range(W):
        yy = np.nonzero(deep[:, x])[0]
        if len(yy):
            yc[x] = yy.mean()
    ok = ~np.isnan(yc)
    yc = np.interp(cols, cols[ok], yc[ok])
    places = json.load(open(os.path.join(OUT, "places.json"), encoding="utf-8"))
    geo = {}
    for lid, p in places.items():
        tx, ty = p["tx"], p["ty"]
        bank = "N" if ty < yc[min(W - 1, max(0, tx))] else "S"
        nm = p["name"]
        if "노들섬" in nm:
            bank = "N"
        elif "선유도" in nm or "서래섬" in nm:
            bank = "S"
        elif "밤섬" in nm:
            bank = ""
        arrive = None
        if p["region"] != "UG":
            for rr in range(0, 13):
                y0, y1, x0, x1 = max(0, ty - rr), min(H, ty + rr + 1), max(0, tx - rr), min(W, tx + rr + 1)
                win = reach[y0:y1, x0:x1]
                if win.any():
                    yy, xx = np.nonzero(win)
                    k = int(np.argmin((yy + y0 - ty) ** 2 + (xx + x0 - tx) ** 2))
                    arrive = [int(xx[k] + x0), int(yy[k] + y0)]
                    break
        geo[lid] = {"bank": bank, "arrive": arrive}
    for ins in R["insets"]:                                                  # 손 맵 장소의 도착 칸 = 그 맵의 표지(본소는 정문 앞 길)
        sp = ins.get("spec", {})
        if sp.get("lid") and sp.get("arrive"):
            m = ins["data"]["marks"][sp["arrive"]]
            geo.setdefault(sp["lid"], {"bank": "S", "arrive": None})["arrive"] = [ins["rect"][0] + int(m[0]), ins["rect"][1] + int(m[1])]
    # 월드 → 실내 문(1-4): 지하로 내려가는 계단 입구 2칸. 요청 자리에서 가장 가까운, 문 2칸과 그 아래 2칸이 모두 걸어서 닿는 곳.
    # 그 장소의 도착 칸은 문 바로 아래(실내에서 나오면 문 앞에 선다 — 문 칸에 서면 다시 들어가 버린다).
    doors = []
    for spec in DOORS:
        if spec.get("kind") == "facade":                                     # 손으로 만든 건물 실내(1-5e)는 건물 1층 문에 붙인다(gen_interiors)
            continue
        nx, ny = spec["near"]
        best = None
        for rr in range(0, 16):
            for yy in range(ny - rr, ny + rr + 1):
                for xx in range(nx - rr, nx + rr + 1):
                    if not (1 <= xx < W - 2 and 1 <= yy < H - 2):
                        continue
                    if reach[yy, xx] and reach[yy, xx + 1] and reach[yy + 1, xx] and reach[yy + 1, xx + 1]:
                        dd = (xx - nx) ** 2 + (yy - ny) ** 2
                        if best is None or dd < best[0]:
                            best = (dd, xx, yy)
            if best is not None:
                break
        if best is None:
            raise SystemExit("문 자리를 못 찾았다: %s" % spec)
        _, xx, yy = best
        doors.append({"lid": spec["lid"], "at": [xx, yy], "to": spec["to"], "mark": spec["mark"], "name": spec["name"], "prop": spec["prop"],
                      "hint": spec.get("hint", "계단을 내려가면 지하다.")})
        geo.setdefault(spec["lid"], {"bank": "S", "arrive": None})["arrive"] = [xx, yy + 1]
    import gen_interiors                                                     # 들어가 보는 건물(1-5e): 문 앞 칸이 걸어서 닿는 1층 문 일부 → 실내 'G-x-y'
    enc = json.load(open(os.path.join(OUT, "encounters.json"), encoding="utf-8"))
    reg = R["region_grid"]

    def region_at(x, y):
        cy_, cx_ = y // CS, x // CS
        return reg[cy_][cx_] if 0 <= cy_ < len(reg) and 0 <= cx_ < len(reg[cy_]) else 0
    taken_g = [tuple(ins["rect"]) for ins in R["insets"]] + [(d["at"][0] - 3, d["at"][1] - 3, 8, 7) for d in doors]
    fixed = [d for d in DOORS if d.get("kind") == "facade"]
    gdoors = gen_interiors.run(R["entries"], reach, enc["threat"], region_at, taken_g, log=log, fixed=fixed)
    for d in gdoors:
        if d.get("lid"):                                                     # 손 장소의 도착 칸 = 그 건물 문 앞(실내 출구 'W 장소 ID'가 여기로 나온다)
            geo.setdefault(d["lid"], {"bank": "S", "arrive": None})["arrive"] = [d["at"][0], d["at"][1] + 1]
    doors += gdoors
    geo["_doors"] = doors
    # 월드 발견 자리(1-4, maps/world/*.spots → map_compile → spots_src.json): 요청 칸에서 가장 가까운, w×h가 모두 걸어서 닿고
    # 손 맵·문 자리와 겹치지 않는 곳(장소 없는 '@x,y' 자리는 그 칸 그대로여야 한다 — 어긋나면 굽기 오류)
    sp_path = os.path.join(OUT, "spots_src.json")
    spots = []
    taken = [tuple(ins["rect"]) for ins in R["insets"]] + [(d["at"][0], d["at"][1] - 1, 2, 3) for d in doors]
    for spec in (json.load(open(sp_path, encoding="utf-8"))["spots"] if os.path.exists(sp_path) else []):
        nx, ny = spec["tile"]
        w, h = spec["w"], spec["h"]

        def fits(xx, yy):
            if not (1 <= xx and 1 <= yy and xx + w < W - 1 and yy + h < H - 1):
                return False
            if not reach[yy:yy + h, xx:xx + w].all():
                return False
            return not any(xx < ox + ow and xx + w > ox and yy < oy + oh and yy + h > oy for (ox, oy, ow, oh) in taken)
        best = None
        for rr in range(0, 1 if "lid" not in spec else 20):
            for yy in range(ny - rr, ny + rr + 1):
                for xx in range(nx - rr, nx + rr + 1):
                    if fits(xx, yy):
                        dd = (xx - nx) ** 2 + (yy - ny) ** 2
                        if best is None or dd < best[0]:
                            best = (dd, xx, yy)
            if best is not None:
                break
        if best is None:
            raise SystemExit("발견 자리를 못 놓았다(%s:%d %s %d×%d — 걸어서 닿는 빈 땅이 없다)" % (spec["file"], spec["line"], spec["key"], w, h))
        _, xx, yy = best
        taken.append((xx, yy, w, h))
        if spec.get("lid") and spec["lid"] in geo:                       # 장소의 도착 칸 = 발견 자리 앞(빠른 이동·지도 표시)
            geo[spec["lid"]]["arrive"] = [int(xx + w // 2), int(yy + h - 1)]
        spots.append({"key": spec["key"], "lid": spec.get("lid", ""), "at": [int(xx), int(yy)], "cond": spec.get("cond", ""), "data": spec["data"]})
    geo["_spots"] = spots
    geo["_han"] = [int(round(v)) for v in yc]                             # 한강 본류 세로 가운데(가로 칸마다): 주인공 강변 판정
    json.dump(geo, open(os.path.join(OUT, "place_geo.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    n_arr = sum(1 for k, g in geo.items() if not k.startswith("_") and g["arrive"])
    log("발견 자리 %d곳: %s" % (len(spots), ", ".join("%s@%d,%d" % (s_["key"], s_["at"][0], s_["at"][1]) for s_ in spots)))
    log("장소 지리: 북안 %d · 남안 %d · 소속 없음 %d · 도착 칸 %d / 지상 %d" % (
        sum(1 for k, g in geo.items() if not k.startswith("_") and g["bank"] == "N"), sum(1 for k, g in geo.items() if not k.startswith("_") and g["bank"] == "S"),
        sum(1 for k, g in geo.items() if not k.startswith("_") and g["bank"] == ""), n_arr, sum(1 for p in places.values() if p["region"] != "UG")))


def sample(R, x0, y0, w, h, out):
    """월드 한 구역을 게임처럼(바닥 합성 + 그림자 + 구조 타일 + 덧층 + 나무) 그린다."""
    from PIL import Image, ImageDraw
    sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
    import ground as G
    pad = 2
    sl = (slice(y0 - pad, y0 + h + pad), slice(x0 - pad, x0 + w + pad))
    gs = G.load("r01")
    img = gs.render(R["floor"][sl].astype(np.int64), None, x0 - pad, y0 - pad, x0 * 32, y0 * 32, w * 32, h * 32,
                    flags=R["gflag"][sl].astype(np.int64)).convert("RGBA")
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    for (bx, by, bw, bh, F) in R["shadows"]:
        if bx > x0 + w + 8 or bx + bw < x0 - 8 or by > y0 + h + 8 or by + bh < y0 - 8:
            continue
        s = F * 16
        X1, Y0, Y1 = (bx + bw - x0) * 32, (by - y0) * 32, (by + bh - y0) * 32
        d.polygon([(X1, Y0), (X1 + s, Y0 + s), (X1 + s, Y1), (X1, Y1)], fill=(0, 0, 0, 89))
    img.alpha_composite(sh)
    for ins in R["insets"]:                                                  # 손 맵 구조물 한 장(0-10 패럴랙스 그림)
        ox, oy, iw, ih = ins["rect"]
        sp = os.path.join(ROOT, "game", "assets", "maps", ins["id"] + "_struct.png")
        if os.path.exists(sp) and ox < x0 + w and ox + iw > x0 and oy < y0 + h and oy + ih > y0:
            st = Image.open(sp).convert("RGBA")
            lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
            lay.paste(st, ((ox - x0) * 32, (oy - y0) * 32))
            img.alpha_composite(lay)
    atlas = Image.open(os.path.join(TIL, "ts_world.png")).convert("RGBA")
    cols = atlas.width // 32
    for layer in ("body", "deco"):
        a = R[layer][y0:y0 + h, x0:x0 + w]
        for yy, xx in zip(*np.nonzero(a)):
            i = int(a[yy, xx]) - 1
            tile = atlas.crop(((i % cols) * 32, (i // cols) * 32, (i % cols) * 32 + 32, (i // cols) * 32 + 32))
            img.alpha_composite(tile, (int(xx) * 32, int(yy) * 32))
    pm = json.load(open(os.path.join(ROOT, "game", "assets", "props", "r01_props.json"), encoding="utf-8"))["props"]
    pa = Image.open(os.path.join(ROOT, "game", "assets", "props", "r01_props.png")).convert("RGBA")
    sm = json.load(open(os.path.join(ROOT, "game", "assets", "props", "s07_props.json"), encoding="utf-8"))["props"]
    sa = Image.open(os.path.join(ROOT, "game", "assets", "props", "s07_props.png")).convert("RGBA")
    spr = []                                                                 # (정렬 y, 그림, 위치)
    for ins in R["insets"]:
        ox, oy = ins["rect"][:2]
        for p in ins["data"]["props"]:
            if p.get("cond"):
                continue
            e = pm.get(p["name"]) or sm.get(p["name"])
            atl = pa if p["name"] in pm else sa
            rx, ry, rw, rh = (e["frames"][0] if "frames" in e else e["rect"])
            spr.append((p["sort_y"] + oy * 32, atl.crop((rx, ry, rx + rw, ry + rh)), (p["px"][0] + ox * 32 - x0 * 32, p["px"][1] + oy * 32 - y0 * 32)))
    tl = R["trees"]
    sel = tl[(tl[:, 0] >= x0 - 2) & (tl[:, 0] < x0 + w + 2) & (tl[:, 1] >= y0 - 1) & (tl[:, 1] < y0 + h + 3)]
    for t in sel.tolist():
        e = pm[R["props"][t[2]]]
        rx, ry, rw, rh = e["rect"]
        fh = e["foot"][1]
        spr.append(((t[1] * 32 + 16) if fh == 0 else (t[1] + fh) * 32, pa.crop((rx, ry, rx + rw, ry + rh)), ((t[0] - x0) * 32 + e["off"][0], (t[1] - y0) * 32 + e["off"][1])))
    lay = Image.new("RGBA", (img.width + 256, img.height + 256), (0, 0, 0, 0))
    for (_, im2, (px_, py_)) in sorted(spr, key=lambda q: q[0]):
        if -128 < px_ < img.width and -128 < py_ < img.height:
            lay.alpha_composite(im2, (px_ + 128, py_ + 128))
    img.alpha_composite(lay.crop((128, 128, 128 + img.width, 128 + img.height)))
    img.save(out)
    log("견본:", out, img.size)


if __name__ == "__main__":
    R = build()
    if "--sample" in sys.argv:
        for i, a in enumerate(sys.argv):
            if a == "--sample":
                q = sys.argv[i + 1:i + 6]
                sample(R, int(q[0]), int(q[1]), int(q[2]), int(q[3]), q[4])
    else:
        export(R)
        map_art(R, None, None)
        place_geo(R)
